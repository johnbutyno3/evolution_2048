import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";
import { allowedToolsForChapter, replayGame } from "../_shared/replay_validator.js";

const CHAPTER_LIMITS: Record<string, number> = {
  C1: 4096,
  C2: 8192,
  C3: 16384,
  C4: 32768,
  C5: 65536,
  C6: 131072,
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const user = await authenticateRequest(req);
    let body: Record<string, unknown>;
    try {
      const value: unknown = await req.json();
      if (!value || typeof value !== "object" || Array.isArray(value)) {
        return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
      }
      body = value as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
    }

    const chapterCode = typeof body["chapterCode"] === "string" ? body["chapterCode"] : "";
    const gameId = typeof body["gameId"] === "string" ? body["gameId"] : "";
    const values = body["values"];
    const replayLog = body["replayLog"];
    const limit = CHAPTER_LIMITS[chapterCode];
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(gameId) ||
      limit === undefined || !Array.isArray(values) || values.length < 1 || values.length > 16 ||
      !values.every((value) => typeof value === "number" && Number.isSafeInteger(value) &&
        value >= 2 && value <= limit && (value & (value - 1)) === 0) ||
      !replayLog || typeof replayLog !== "object" || Array.isArray(replayLog)) {
      return jsonResponse({ error: "INVALID_CREATURE_DISCOVERY" }, 400);
    }
    if (new TextEncoder().encode(JSON.stringify(replayLog)).byteLength > 1024 * 1024) {
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
      console.error("creature_discovery_session_read_failed", {
        userId: user.id, gameId, code: sessionError.code,
      });
      return jsonResponse({ error: "COLLECTION_SYNC_UNAVAILABLE" }, 503);
    }
    if (!session || session.chapter_code !== chapterCode ||
      !["ACTIVE", "COMPLETED"].includes(session.state) || !session.initial_tiles) {
      return jsonResponse({ error: "GAME_SESSION_NOT_FOUND" }, 404);
    }

    let replayResult: ReturnType<typeof replayGame>;
    try {
      const chapterIndex = Number(chapterCode.slice(1)) - 1;
      replayResult = replayGame({
        replayLog,
        chapterIndex,
        targetValue: 2 ** (chapterIndex + 12),
        expectedInitialTiles: session.initial_tiles,
        allowedTools: allowedToolsForChapter(chapterIndex),
        requireCompletion: false,
      });
    } catch {
      return jsonResponse({ error: "REPLAY_VALIDATION_FAILED" }, 422);
    }
    const uniqueValues = [...new Set(values as number[])];
    if (uniqueValues.some((value) => value > replayResult.highestValue)) {
      return jsonResponse({ error: "CREATURE_NOT_REACHED" }, 409);
    }

    const rows = uniqueValues.map((creatureValue) => ({
      user_id: user.id,
      chapter_code: chapterCode,
      creature_value: creatureValue,
    }));
    const { error } = await service.from("creature_collection").upsert(rows, {
      onConflict: "user_id,chapter_code,creature_value",
      ignoreDuplicates: true,
    });
    if (error) {
      console.error("creature_discovery_write_failed", {
        userId: user.id,
        chapterCode,
        code: error.code,
      });
      return jsonResponse({ error: "COLLECTION_SYNC_UNAVAILABLE" }, 503);
    }
    return jsonResponse({ discovered: true, chapterCode, values: uniqueValues });
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("creature_discovery_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
