import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";
import { allowedToolsForChapter, replayGame } from "../_shared/replay_validator.js";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CHAPTER_INDEX: Record<string, number> = {
  C1: 0,
  C2: 1,
  C3: 2,
  C4: 3,
  C5: 4,
  C6: 5,
};
const MAX_REPLAY_BYTES = 1024 * 1024;

async function lockForReplayViolation(
  service: ReturnType<typeof createServiceClient>,
  userId: string,
  gameId: string,
  reason: string,
  message: string,
): Promise<boolean> {
  const { error } = await service.rpc("lock_account_for_security_violation", {
    p_user_id: userId,
    p_game_id: gameId,
    p_reason: reason,
    p_details: { message: message.slice(0, 240) },
  });
  if (error) {
    console.error("security_lock_failed", {
      userId,
      gameId,
      reason,
      code: error.code,
    });
    return false;
  }
  return true;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const user = await authenticateRequest(req);
    let body: Record<string, unknown>;
    try {
      const parsed: unknown = await req.json();
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
      }
      body = parsed as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
    }

    const gameId = typeof body["gameId"] === "string" ? body["gameId"] : "";
    const eventId = typeof body["eventId"] === "string" ? body["eventId"] : "";
    const replayLog = body["replayLog"];
    if (!UUID_PATTERN.test(gameId) || !UUID_PATTERN.test(eventId) ||
      !replayLog || typeof replayLog !== "object" || Array.isArray(replayLog)) {
      return jsonResponse({ error: "INVALID_CHAPTER_COMPLETE_REQUEST" }, 400);
    }
    if (new TextEncoder().encode(JSON.stringify(replayLog)).byteLength > MAX_REPLAY_BYTES) {
      return jsonResponse({ error: "REPLAY_TOO_LARGE" }, 413);
    }

    const service = createServiceClient();
    const { data: session, error: sessionError } = await service
      .from("game_sessions")
      .select("game_id, chapter_code, state, initial_tiles")
      .eq("user_id", user.id)
      .eq("game_id", gameId)
      .maybeSingle();

    if (sessionError) {
      console.error("chapter_completion_session_read_failed", {
        userId: user.id,
        gameId,
        code: sessionError.code,
      });
      return jsonResponse({ error: "CHAPTER_COMPLETION_UNAVAILABLE" }, 503);
    }
    if (!session) return jsonResponse({ error: "GAME_SESSION_NOT_FOUND" }, 404);
    if (!session.initial_tiles) {
      return jsonResponse({ error: "SESSION_INITIAL_BOARD_MISSING" }, 409);
    }

    const chapterIndex = CHAPTER_INDEX[session.chapter_code];
    if (chapterIndex === undefined) {
      return jsonResponse({ error: "INVALID_SESSION_CHAPTER" }, 409);
    }

    let replayResult: ReturnType<typeof replayGame>;
    try {
      replayResult = replayGame({
        replayLog,
        chapterIndex,
        targetValue: 2 ** (chapterIndex + 12),
        expectedInitialTiles: session.initial_tiles,
        allowedTools: allowedToolsForChapter(chapterIndex),
        requireCompletion: true,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Replay validation failed.";
      const locked = await lockForReplayViolation(
        service,
        user.id,
        gameId,
        "forged_replay_detected",
        message,
      );
      if (!locked) {
        return jsonResponse({ error: "SECURITY_REVIEW_UNAVAILABLE" }, 503);
      }
      return jsonResponse({
        error: "ACCOUNT_RESTRICTED",
        reason: "REPLAY_VALIDATION_FAILED",
        supportAvailable: true,
      }, 423);
    }

    const payload = {
      score: replayResult.score,
      highestValue: replayResult.highestValue,
      eventCount: replayResult.eventCount,
      toolPenaltyTotal: replayResult.toolPenaltyTotal,
      toolUsage: replayResult.toolUsage,
    };
    const { data, error } = await service.rpc("finish_game_chapter", {
      p_user_id: user.id,
      p_game_id: gameId,
      p_event_id: eventId,
      p_payload: payload,
    });

    if (error) {
      const message = error.message ?? "";
      if (message.includes("TOOL_USAGE_REPLAY_CONFLICT") ||
        message.includes("ASSET_BALANCE_INSUFFICIENT_OR_MISSING")) {
        const reason = message.includes("TOOL_USAGE_REPLAY_CONFLICT")
          ? "tool_usage_replay_conflict"
          : "tool_inventory_overuse_detected";
        const locked = await lockForReplayViolation(
          service,
          user.id,
          gameId,
          reason,
          message,
        );
        if (!locked) return jsonResponse({ error: "SECURITY_REVIEW_UNAVAILABLE" }, 503);
        return jsonResponse({
          error: "ACCOUNT_RESTRICTED",
          reason: "TOOL_USAGE_VALIDATION_FAILED",
          supportAvailable: true,
        }, 423);
      }
      if (message.includes("GAME_SESSION_NOT_FOUND")) {
        return jsonResponse({ error: "GAME_SESSION_NOT_FOUND" }, 404);
      }
      if (message.includes("GAME_SESSION_NOT_ACTIVE") ||
        message.includes("CHAPTER_ALREADY_COMPLETED_WITH_DIFFERENT_EVENT")) {
        return jsonResponse({ error: "GAME_SESSION_NOT_ACTIVE" }, 409);
      }
      if (message.includes("ACCOUNT_RESTRICTED") ||
        message.includes("MEMBERSHIP_REQUIRES_REVIEW")) {
        return jsonResponse({ error: "ACCOUNT_RESTRICTED", supportAvailable: true }, 423);
      }
      if (message.includes("IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD")) {
        return jsonResponse({ error: "IDEMPOTENCY_CONFLICT" }, 409);
      }
      console.error("finish_game_chapter_failed", {
        userId: user.id,
        gameId,
        code: error.code,
      });
      return jsonResponse({ error: "CHAPTER_COMPLETION_UNAVAILABLE" }, 503);
    }

    return jsonResponse(data);
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("finish_game_chapter_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
