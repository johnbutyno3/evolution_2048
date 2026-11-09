import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";
import { recordSecurityEvent } from "../_shared/security_events.ts";
import { allowedToolsForChapter, replayGame } from "../_shared/replay_validator.js";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CHAPTER_INDEX: Record<string, number> = {
  C1: 0, C2: 1, C3: 2, C4: 3, C5: 4, C6: 5,
};
const MAX_REPLAY_BYTES = 1024 * 1024;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);

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

    const requestId = typeof body["requestId"] === "string" ? body["requestId"] : "";
    const gameId = typeof body["gameId"] === "string" ? body["gameId"] : "";
    const previousGameId = typeof body["previousGameId"] === "string" ? body["previousGameId"] : "";
    const eventId = typeof body["eventId"] === "string" ? body["eventId"] : "";
    const chapterCode = typeof body["chapterCode"] === "string" ? body["chapterCode"] : "";
    const initialTiles = body["initialTiles"];
    const replayLog = body["replayLog"];

    if (![requestId, gameId, previousGameId, eventId].every((value) => UUID_PATTERN.test(value)) ||
      !Object.hasOwn(CHAPTER_INDEX, chapterCode) ||
      !Array.isArray(initialTiles) || initialTiles.length !== 16 ||
      initialTiles.filter((value) => value !== null).length !== 2 ||
      initialTiles.some((value) => value !== null && value !== 2 && value !== 4) ||
      !replayLog || typeof replayLog !== "object" || Array.isArray(replayLog)) {
      return jsonResponse({ error: "INVALID_RESTART_REQUEST" }, 400);
    }
    if (new TextEncoder().encode(JSON.stringify(replayLog)).byteLength > MAX_REPLAY_BYTES) {
      return jsonResponse({ error: "REPLAY_TOO_LARGE" }, 413);
    }

    const service = createServiceClient();
    const { data: previous, error: readError } = await service
      .from("game_sessions")
      .select("game_id,chapter_code,state,initial_tiles")
      .eq("user_id", user.id)
      .eq("game_id", previousGameId)
      .maybeSingle();
    if (readError) {
      console.error("restart_previous_session_read_failed", { userId: user.id, code: readError.code });
      return jsonResponse({ error: "RESTART_UNAVAILABLE" }, 503);
    }
    if (!previous) return jsonResponse({ error: "PREVIOUS_SESSION_NOT_FOUND" }, 404);
    // A retry after a committed restart must reach the idempotent RPC:
    // the prior SESSION_ABANDON event and start request return their stored results.
    if (previous.state !== "ACTIVE" && previous.state !== "ABANDONED") {
      return jsonResponse({ error: "GAME_SESSION_NOT_ACTIVE" }, 409);
    }
    const previousChapterIndex = CHAPTER_INDEX[previous.chapter_code];
    if (previousChapterIndex === undefined || !previous.initial_tiles) {
      return jsonResponse({ error: "INVALID_PREVIOUS_SESSION" }, 409);
    }

    let replayResult: ReturnType<typeof replayGame>;
    try {
      replayResult = replayGame({
        replayLog,
        chapterIndex: previousChapterIndex,
        targetValue: 2 ** (previousChapterIndex + 12),
        expectedInitialTiles: previous.initial_tiles,
        allowedTools: allowedToolsForChapter(previousChapterIndex),
        requireCompletion: false,
      });
    } catch (error) {
      return jsonResponse({
        error: "REPLAY_VALIDATION_FAILED",
        message: error instanceof Error ? error.message.slice(0, 160) : "Replay validation failed.",
      }, 422);
    }
    if (replayResult.finalBoard.includes(2 ** (previousChapterIndex + 12))) {
      return jsonResponse({ error: "CHAPTER_COMPLETION_REQUIRED" }, 409);
    }

    const abandonPayload = {
      reason: "PLAYER_ABANDONED",
      score: replayResult.score,
      highestValue: replayResult.highestValue,
      eventCount: replayResult.eventCount,
      toolPenaltyTotal: replayResult.toolPenaltyTotal,
      toolUsage: replayResult.toolUsage,
    };
    const { data, error } = await service.rpc("restart_game_session", {
      p_user_id: user.id,
      p_request_id: requestId,
      p_game_id: gameId,
      p_chapter_code: chapterCode,
      p_previous_game_id: previousGameId,
      p_initial_tiles: initialTiles,
      p_abandon_event_id: eventId,
      p_abandon_payload: abandonPayload,
    });
    if (error) {
      const message = error.message ?? "";
      if (message.includes("OUT_OF_LIVES")) return jsonResponse({ error: "OUT_OF_LIVES" }, 409);
      if (message.includes("CHAPTER_LOCKED")) return jsonResponse({ error: "CHAPTER_LOCKED" }, 403);
      if (message.includes("PREVIOUS_SESSION_NOT_FOUND") || message.includes("GAME_SESSION_NOT_FOUND")) {
        return jsonResponse({ error: "PREVIOUS_SESSION_NOT_FOUND" }, 404);
      }
      if (message.includes("GAME_SESSION_NOT_ACTIVE")) return jsonResponse({ error: "GAME_SESSION_NOT_ACTIVE" }, 409);
      if (message.includes("ACCOUNT_RESTRICTED") || message.includes("MEMBERSHIP_REQUIRES_REVIEW")) {
        return jsonResponse({ error: "ACCOUNT_RESTRICTED", supportAvailable: true }, 423);
      }
      if (message.includes("TOOL_USAGE_REPLAY_CONFLICT") || message.includes("ASSET_BALANCE_INSUFFICIENT_OR_MISSING")) {
        const reason = message.includes("TOOL_USAGE_REPLAY_CONFLICT")
          ? "tool_usage_replay_conflict"
          : "tool_inventory_settlement_conflict";
        const recorded = await recordSecurityEvent(
          service,
          user.id,
          gameId,
          "warning",
          reason,
          message,
        );
        if (!recorded) return jsonResponse({ error: "SECURITY_REVIEW_UNAVAILABLE" }, 503);
        return jsonResponse({
          error: "TOOL_USAGE_REQUIRES_REVIEW",
          supportAvailable: true,
        }, 409);
      }
      if (message.includes("ACTIVE_SESSION_EXISTS")) return jsonResponse({ error: "ACTIVE_SESSION_EXISTS" }, 409);
      if (
        message.includes("IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD") ||
        message.includes("REQUEST_ID_REUSED_WITH_DIFFERENT_PAYLOAD")
      ) {
        return jsonResponse({ error: "IDEMPOTENCY_CONFLICT" }, 409);
      }
      console.error("restart_game_session_failed", { userId: user.id, code: error.code });
      return jsonResponse({ error: "RESTART_UNAVAILABLE" }, 503);
    }

    const started = data && typeof data === "object" ? (data as Record<string, unknown>)["started"] : null;
    return jsonResponse(started ?? data);
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("restart_game_session_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
