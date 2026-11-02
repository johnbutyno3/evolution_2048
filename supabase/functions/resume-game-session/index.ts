import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

    const gameId = typeof body["gameId"] === "string" ? body["gameId"] : "";
    if (!UUID_PATTERN.test(gameId)) {
      return jsonResponse({ error: "INVALID_GAME_SESSION_ID" }, 400);
    }

    const service = createServiceClient();
    const [{ data: profile, error: profileError }, { data: membership, error: membershipError }] =
      await Promise.all([
        service.from("profiles").select("account_status").eq("user_id", user.id).maybeSingle(),
        service.from("memberships").select("tier,status").eq("user_id", user.id).maybeSingle(),
      ]);
    if (profileError || membershipError) {
      console.error("resume_game_account_check_failed", {
        userId: user.id,
        profileCode: profileError?.code,
        membershipCode: membershipError?.code,
      });
      return jsonResponse({ error: "SESSION_RESUME_UNAVAILABLE" }, 503);
    }
    if (!profile || profile.account_status !== "active" ||
      !membership || membership.status === "under_review") {
      return jsonResponse({ error: "ACCOUNT_RESTRICTED", supportAvailable: true }, 423);
    }

    const { data: session, error } = await service
      .from("game_sessions")
      .select("game_id,chapter_code,state,event_sequence,initial_tiles,checkpoint,checkpoint_version,tool_usage,final_score,final_highest_value,updated_at")
      .eq("user_id", user.id)
      .eq("game_id", gameId)
      .maybeSingle();

    if (error) {
      console.error("resume_game_session_read_failed", {
        userId: user.id,
        gameId,
        code: error.code,
      });
      return jsonResponse({ error: "SESSION_RESUME_UNAVAILABLE" }, 503);
    }
    if (!session) return jsonResponse({ error: "GAME_SESSION_NOT_FOUND" }, 404);
    if (session.state !== "ACTIVE") {
      return jsonResponse({
        error: "GAME_SESSION_NOT_ACTIVE",
        state: session.state,
      }, 409);
    }
    if (!session.initial_tiles) {
      return jsonResponse({ error: "SESSION_INITIAL_BOARD_MISSING" }, 409);
    }

    // The checkpoint is recovery metadata, not a completion proof. The client
    // keeps local gameplay responsive; finish/abandon still replay-validate
    // the complete event log on the server.
    return jsonResponse({
      gameId: session.game_id,
      chapterCode: session.chapter_code,
      state: session.state,
      eventSequence: session.event_sequence,
      initialTiles: session.initial_tiles,
      checkpoint: session.checkpoint,
      checkpointVersion: session.checkpoint_version,
      toolUsage: session.tool_usage,
      score: session.final_score,
      highestValue: session.final_highest_value,
      updatedAt: session.updated_at,
      membershipTier: membership.tier,
      membershipStatus: membership.status,
    });
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("resume_game_session_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
