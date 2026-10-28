import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const CHAPTER_CODES = new Set(["C1", "C2", "C3", "C4", "C5", "C6"]);

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

    const requestId = typeof body["requestId"] === "string" ? body["requestId"] : "";
    const gameId = typeof body["gameId"] === "string" ? body["gameId"] : "";
    const chapterCode = typeof body["chapterCode"] === "string" ? body["chapterCode"] : "";
    const previousRaw = body["previousGameId"];
    const previousGameId = typeof previousRaw === "string" && previousRaw.length > 0
      ? previousRaw
      : null;
    const initialTiles = body["initialTiles"];

    if (!UUID_PATTERN.test(requestId) || !UUID_PATTERN.test(gameId) ||
      (previousGameId !== null && !UUID_PATTERN.test(previousGameId)) ||
      !CHAPTER_CODES.has(chapterCode) ||
      !Array.isArray(initialTiles) || initialTiles.length !== 16 ||
      initialTiles.filter((value) => value !== null).length !== 2 ||
      initialTiles.some((value) => value !== null && value !== 2 && value !== 4)) {
      return jsonResponse({ error: "INVALID_GAME_SESSION_REQUEST" }, 400);
    }

    const service = createServiceClient();
    const { data, error } = await service.rpc("start_game_session", {
      p_user_id: user.id,
      p_request_id: requestId,
      p_game_id: gameId,
      p_chapter_code: chapterCode,
      p_previous_game_id: previousGameId,
      p_initial_tiles: initialTiles,
    });

    if (error) {
      const message = error.message ?? "";
      if (message.includes("ACCOUNT_RESTRICTED")) {
        return jsonResponse({ error: "ACCOUNT_RESTRICTED", supportAvailable: true }, 423);
      }
      if (message.includes("MEMBERSHIP_REQUIRES_REVIEW")) {
        return jsonResponse({ error: "MEMBERSHIP_REQUIRES_REVIEW", supportAvailable: true }, 423);
      }
      if (message.includes("CHAPTER_LOCKED")) {
        return jsonResponse({ error: "CHAPTER_LOCKED" }, 403);
      }
      if (message.includes("LIFE_BALANCE_INSUFFICIENT_OR_MISSING")) {
        return jsonResponse({ error: "OUT_OF_LIVES" }, 402);
      }
      if (message.includes("ACTIVE_SESSION_EXISTS")) {
        return jsonResponse({ error: "ACTIVE_SESSION_EXISTS" }, 409);
      }
      if (message.includes("PREVIOUS_SESSION_NOT_FOUND")) {
        return jsonResponse({ error: "PREVIOUS_SESSION_NOT_FOUND" }, 409);
      }
      if (message.includes("REQUEST_ID_REUSED_WITH_DIFFERENT_PAYLOAD")) {
        return jsonResponse({ error: "IDEMPOTENCY_CONFLICT" }, 409);
      }
      console.error("start_game_session_failed", {
        userId: user.id,
        code: error.code,
      });
      return jsonResponse({ error: "GAME_SESSION_UNAVAILABLE" }, 503);
    }

    return jsonResponse(data);
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("start_game_session_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
