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

    const [profileResult, membershipResult, walletResult, lifeResult, toolsResult] = await Promise.all([
      service.from("profiles")
        .select("display_name, avatar_index, locale_code, account_status, updated_at")
        .eq("user_id", user.id).maybeSingle(),
      service.from("memberships")
        .select("tier, status, verified_at, updated_at")
        .eq("user_id", user.id).maybeSingle(),
      service.from("gold_wallets")
        .select("balance, updated_at")
        .eq("user_id", user.id).maybeSingle(),
      service.from("life_wallets")
        .select("life_count, next_regen_at, updated_at")
        .eq("user_id", user.id).maybeSingle(),
      service.from("tool_inventory")
        .select("tool_code, quantity, updated_at")
        .eq("user_id", user.id),
    ]);

    const firstError = profileResult.error ?? membershipResult.error ??
      walletResult.error ?? lifeResult.error ?? toolsResult.error;
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
    const lifeWallet = lifeResult.data;
    if (!profile || !membership || !wallet || !lifeWallet) {
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

    if (membership.status === "under_review") {
      return jsonResponse({
        error: "MEMBERSHIP_REQUIRES_REVIEW",
        accountStatus: profile.account_status,
        membershipStatus: membership.status,
        supportAvailable: true,
      }, 423);
    }

    // A revoked purchase entitlement does not itself lock the account.
    // Until a trusted verification flow restores an entitlement, expose FREE.
    const effectiveTier = membership.status === "revoked" ? "FREE" : membership.tier;

    // FREE life regeneration is computed from server time, not the device clock.
    let lifeCount = Number(lifeWallet.life_count);
    let nextRegenAt: string | null = lifeWallet.next_regen_at;
    if (effectiveTier === "FREE") {
      const regenResult = await service.rpc("regenerate_lives", {
        p_user_id: user.id,
      });
      if (regenResult.error) {
        console.error("life_regeneration_failed", {
          userId: user.id,
          code: regenResult.error.code,
        });
        return jsonResponse({ error: "ACCOUNT_SNAPSHOT_UNAVAILABLE" }, 503);
      }
      if (regenResult.data && typeof regenResult.data === "object") {
        const regen = regenResult.data as Record<string, unknown>;
        if (typeof regen["lives"] === "number") lifeCount = regen["lives"];
        if (typeof regen["nextRegenAt"] === "string" || regen["nextRegenAt"] === null) {
          nextRegenAt = regen["nextRegenAt"] as string | null;
        }
      }
    }

    // Daily reward is attempted only after the server confirms an active account
    // and membership row. The database RPC is idempotent by account-local date.
    let goldBalance = Number(wallet.balance);
    let dailyGold: Record<string, unknown> = {
      claimed: false,
      reason: "NOT_ELIGIBLE",
    };
    const dailyClaimResult = await service.rpc("claim_daily_gold", {
      p_user_id: user.id,
    });
    if (dailyClaimResult.error) {
      console.error("daily_gold_claim_failed", {
        userId: user.id,
        code: dailyClaimResult.error.code,
      });
      return jsonResponse({ error: "ACCOUNT_SNAPSHOT_UNAVAILABLE" }, 503);
    }
    if (dailyClaimResult.data && typeof dailyClaimResult.data === "object") {
      dailyGold = dailyClaimResult.data as Record<string, unknown>;
      const claimBalance = dailyGold["gold"];
      if (typeof claimBalance === "number" || typeof claimBalance === "string") {
        goldBalance = Number(claimBalance);
      }
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
      avatarIndex: profile.avatar_index,
      localeCode: profile.locale_code,
      accountStatus: profile.account_status,
      membership: {
        tier: effectiveTier,
        status: membership.status,
        verifiedAt: membership.verified_at,
      },
      gold: goldBalance,
      dailyGold,
      lives: {
        count: lifeCount,
        unlimited: effectiveTier === "PREMIUM" || effectiveTier === "GOLDEN",
        nextRegenAt,
      },
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
