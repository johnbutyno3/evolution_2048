import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);
  }

  try {
    const user = await authenticateRequest(req);
    const service = createServiceClient();

    const [profileResult, membershipResult, walletResult, toolsResult] = await Promise.all([
      service.from("profiles")
        .select("display_name, locale_code, account_status, updated_at")
        .eq("user_id", user.id).maybeSingle(),
      service.from("memberships")
        .select("tier, status, verified_at, updated_at")
        .eq("user_id", user.id).maybeSingle(),
      service.from("gold_wallets")
        .select("balance, updated_at")
        .eq("user_id", user.id).maybeSingle(),
      service.from("tool_inventory")
        .select("tool_code, quantity, updated_at")
        .eq("user_id", user.id),
    ]);

    const firstError = profileResult.error ?? membershipResult.error ??
      walletResult.error ?? toolsResult.error;
    if (firstError) {
      console.error("account_snapshot_read_failed", {
        userId: user.id,
        code: firstError.code,
      });
      return jsonResponse({ error: "ACCOUNT_SNAPSHOT_UNAVAILABLE" }, 503);
    }

    const profile = profileResult.data;
    const membership = membershipResult.data;
    const wallet = walletResult.data;
    if (!profile || !membership || !wallet) {
      // This is an integrity issue, not permission to invent client-side balances.
      console.error("account_snapshot_missing_required_row", { userId: user.id });
      return jsonResponse({ error: "ACCOUNT_SETUP_INCOMPLETE" }, 503);
    }

    if (profile.account_status !== "active") {
      return jsonResponse({
        error: "ACCOUNT_RESTRICTED",
        accountStatus: profile.account_status,
        supportAvailable: true,
      }, 423);
    }

    if (membership.status !== "active") {
      return jsonResponse({
        error: "MEMBERSHIP_REQUIRES_REVIEW",
        accountStatus: profile.account_status,
        membershipStatus: membership.status,
        supportAvailable: true,
      }, 423);
    }

    const tools: Record<string, number> = {
      UNDO: 0,
      REMOVE: 0,
      SWAP: 0,
      DUPLICATE: 0,
    };
    for (const row of toolsResult.data ?? []) {
      if (Object.hasOwn(tools, row.tool_code)) {
        tools[row.tool_code] = Number(row.quantity);
      }
    }

    return jsonResponse({
      userId: user.id,
      displayName: profile.display_name,
      localeCode: profile.locale_code,
      accountStatus: profile.account_status,
      membership: {
        tier: membership.tier,
        status: membership.status,
        verifiedAt: membership.verified_at,
      },
      gold: Number(wallet.balance),
      tools,
      serverTime: new Date().toISOString(),
    });
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("account_snapshot_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
