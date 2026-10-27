import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MAX_CHECKPOINT_BYTES = 262144;

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
    const eventSequence = body["eventSequence"];
    const checkpoint = body["checkpoint"];
    if (!UUID_PATTERN.test(gameId) || typeof eventSequence !== "number" ||
      !Number.isSafeInteger(eventSequence) || eventSequence < 1 ||
      !checkpoint || typeof checkpoint !== "object" || Array.isArray(checkpoint)) {
      return jsonResponse({ error: "INVALID_GAME_CHECKPOINT" }, 400);
    }

    const encoded = JSON.stringify(checkpoint);
    if (new TextEncoder().encode(encoded).byteLength > MAX_CHECKPOINT_BYTES) {
      return jsonResponse({ error: "CHECKPOINT_TOO_LARGE" }, 413);
    }

    const service = createServiceClient();
    const { data, error } = await service.rpc("save_game_checkpoint", {
      p_user_id: user.id,
      p_game_id: gameId,
      p_event_sequence: eventSequence,
      p_checkpoint: checkpoint,
    });

    if (error) {
      const message = error.message ?? "";
      if (message.includes("GAME_SESSION_NOT_FOUND")) {
        return jsonResponse({ error: "GAME_SESSION_NOT_FOUND" }, 404);
      }
      if (message.includes("GAME_SESSION_NOT_ACTIVE")) {
        return jsonResponse({ error: "GAME_SESSION_NOT_ACTIVE" }, 409);
      }
      if (message.includes("CHECKPOINT_SEQUENCE_CONFLICT")) {
        return jsonResponse({ error: "CHECKPOINT_SEQUENCE_CONFLICT" }, 409);
      }
      if (message.includes("INVALID_GAME_CHECKPOINT")) {
        return jsonResponse({ error: "INVALID_GAME_CHECKPOINT" }, 400);
      }
      console.error("save_game_checkpoint_failed", {
        userId: user.id,
        code: error.code,
      });
      return jsonResponse({ error: "CHECKPOINT_SAVE_UNAVAILABLE" }, 503);
    }

    return jsonResponse(data);
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("save_game_checkpoint_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
