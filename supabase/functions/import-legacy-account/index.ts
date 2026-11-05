import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const MAX_BODY_BYTES = 256 * 1024;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const operator = await authenticateRequest(req);
    if (operator.app_metadata?.role !== "admin") {
      return jsonResponse({ error: "ADMIN_ACCESS_REQUIRED" }, 403);
    }

    const raw = await req.text();
    if (new TextEncoder().encode(raw).length > MAX_BODY_BYTES) {
      return jsonResponse({ error: "IMPORT_PAYLOAD_TOO_LARGE" }, 413);
    }

    let body: Record<string, unknown>;
    try {
      const parsed: unknown = JSON.parse(raw);
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
      }
      body = parsed as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
    }

    const legacyUid = typeof body["legacyUid"] === "string" ? body["legacyUid"].trim() : "";
    const sourceSha256 = typeof body["sourceSha256"] === "string"
      ? body["sourceSha256"].toLowerCase()
      : "";
    const payload = body["payload"];
    if (!legacyUid || legacyUid.length > 128 ||
      !/^[a-f0-9]{64}$/.test(sourceSha256) ||
      !payload || typeof payload !== "object" || Array.isArray(payload)) {
      return jsonResponse({ error: "INVALID_IMPORT_REQUEST" }, 400);
    }

    const service = createServiceClient();
    const { data, error } = await service.rpc("import_legacy_firebase_account", {
      p_legacy_uid: legacyUid,
      p_source_sha256: sourceSha256,
      p_payload: payload,
      p_imported_by: operator.id,
    });

    if (error) {
      console.error("legacy_account_import_rejected", {
        operatorId: operator.id,
        legacyUid,
        code: error.code,
        message: error.message,
      });
      const knownErrors: Record<string, number> = {
        "LEGACY_IDENTITY_NOT_VERIFIED": 409,
        "LEGACY_IMPORT_ALREADY_EXISTS_WITH_DIFFERENT_SOURCE": 409,
        "SUPABASE_ACCOUNT_ALREADY_LINKED_TO_LEGACY_IMPORT": 409,
        "SUPABASE_ACCOUNT_NOT_PRISTINE_FOR_IMPORT": 409,
        "INVALID_LEGACY_IMPORT": 400,
        "INVALID_LEGACY_IMPORT_SHAPE": 400,
        "INVALID_LEGACY_GOLD_BALANCE": 400,
        "INVALID_LEGACY_LIFE_COUNT": 400,
        "INVALID_LEGACY_REGENERATION_TIME": 400,
        "INVALID_LEGACY_TOOL_INVENTORY": 400,
        "INCOMPLETE_LEGACY_TOOL_INVENTORY": 400,
        "INVALID_LEGACY_CHAPTER_PROGRESS": 400,
        "INVALID_LEGACY_COLLECTION_ENTRY": 400,
      };
      const message = error.message || "";
      const matched = Object.entries(knownErrors).find(([key]) => message.includes(key));
      return jsonResponse({
        error: matched?.[0] ?? "LEGACY_IMPORT_FAILED",
      }, matched?.[1] ?? 500);
    }

    if (!data || typeof data !== "object" || Array.isArray(data)) {
      return jsonResponse({ error: "EMPTY_IMPORT_RESULT" }, 500);
    }

    const result = data as Record<string, unknown>;
    const userId = typeof result["userId"] === "string" ? result["userId"] : "";
    const expected = payload as Record<string, unknown>;
    const expectedProfile = (expected["profile"] ?? {}) as Record<string, unknown>;
    const expectedMembership = (expected["membership"] ?? {}) as Record<string, unknown>;
    const expectedGold = (expected["gold"] ?? {}) as Record<string, unknown>;
    const expectedLives = (expected["lives"] ?? {}) as Record<string, unknown>;
    const expectedTools = (expected["tools"] ?? {}) as Record<string, unknown>;

    const [profile, membership, gold, lives, tools, chapters, collection] = await Promise.all([
      service.from("profiles").select("display_name,avatar_index,account_status").eq("user_id", userId).maybeSingle(),
      service.from("memberships").select("tier,status").eq("user_id", userId).maybeSingle(),
      service.from("gold_wallets").select("balance").eq("user_id", userId).maybeSingle(),
      service.from("life_wallets").select("life_count,next_regen_at").eq("user_id", userId).maybeSingle(),
      service.from("tool_inventory").select("tool_code,quantity").eq("user_id", userId),
      service.from("game_progress").select("chapter_code,highest_stage,best_score").eq("user_id", userId),
      service.from("creature_collection").select("chapter_code,creature_value").eq("user_id", userId),
    ]);
    const readError = profile.error ?? membership.error ?? gold.error ??
      lives.error ?? tools.error ?? chapters.error ?? collection.error;
    if (readError) {
      console.error("legacy_import_verification_read_failed", {
        operatorId: operator.id, userId, code: readError.code,
      });
      return jsonResponse({ error: "IMPORT_VERIFICATION_UNAVAILABLE", imported: result["imported"] }, 503);
    }

    const expectedName = typeof expectedProfile["playerName"] === "string"
      ? expectedProfile["playerName"].trim().replace(/\\s+/g, " ").slice(0, 40)
      : "";
    const expectedAvatar = typeof expectedProfile["avatarIndex"] === "number"
      ? Math.max(0, Math.min(53, Math.trunc(expectedProfile["avatarIndex"])))
      : 0;
    const expectedAccountStatus = expectedProfile["accountStatus"] === "locked" ||
      expectedProfile["accountStatus"] === "under_review"
      ? expectedProfile["accountStatus"]
      : "active";
    const expectedTier = typeof expectedMembership["tier"] === "string"
      ? expectedMembership["tier"].toUpperCase()
      : "FREE";
    const expectedMembershipStatus = expectedMembership["status"] === "revoked" ||
      expectedMembership["status"] === "under_review"
      ? expectedMembership["status"]
      : "active";
    const expectedLifeCount = Number(expectedLives["count"]);
    const actualLifeCount = Number(lives.data?.life_count);
    const actualNextRegen = lives.data?.next_regen_at
      ? Date.parse(lives.data.next_regen_at)
      : null;
    const requestedNextRegen = typeof expectedLives["nextRegenAt"] === "string"
      ? Date.parse(expectedLives["nextRegenAt"])
      : null;
    const regenMatches = expectedLifeCount >= 5
      ? actualNextRegen === null
      : requestedNextRegen === null
        ? actualNextRegen !== null && actualNextRegen >= Date.now() - 5000 &&
          actualNextRegen <= Date.now() + 40 * 60 * 1000 + 5000
        : actualNextRegen !== null && Math.abs(actualNextRegen - requestedNextRegen) <= 1000;

    const actualTools: Record<string, number> = { UNDO: 0, REMOVE: 0, SWAP: 0, DUPLICATE: 0 };
    for (const row of tools.data ?? []) actualTools[row.tool_code] = Number(row.quantity);

    const expectedChapters = Array.isArray(expected["chapters"])
      ? expected["chapters"] as Record<string, unknown>[]
      : [];
    const actualChapterMap = new Map((chapters.data ?? []).map((row) => [
      row.chapter_code, [Number(row.highest_stage), Number(row.best_score)],
    ]));
    const chaptersMatch = expectedChapters.length === actualChapterMap.size &&
      expectedChapters.every((row) => {
        const actual = actualChapterMap.get(String(row["chapterCode"]));
        return actual !== undefined &&
          actual[0] === Number(row["highestStage"]) &&
          actual[1] === Number(row["bestScore"]);
      });

    const expectedCollection = Array.isArray(expected["collection"])
      ? expected["collection"] as Record<string, unknown>[]
      : [];
    const expectedCollectionKeys = expectedCollection.map((row) =>
      `${String(row["chapterCode"])}:${String(row["creatureValue"])}`,
    ).sort();
    const actualCollectionKeys = (collection.data ?? []).map((row) =>
      `${row.chapter_code}:${row.creature_value}`,
    ).sort();
    const collectionMatches = expectedCollectionKeys.length === actualCollectionKeys.length &&
      expectedCollectionKeys.every((key, index) => key === actualCollectionKeys[index]);

    const verification = {
      profile: profile.data?.display_name === expectedName &&
        Number(profile.data?.avatar_index) === expectedAvatar &&
        profile.data?.account_status === expectedAccountStatus,
      membership: membership.data?.tier === (expectedMembershipStatus === "active" ? expectedTier : "FREE") &&
        membership.data?.status === expectedMembershipStatus,
      gold: Number(gold.data?.balance) === Number(expectedGold["balance"]),
      lives: actualLifeCount === expectedLifeCount && regenMatches,
      tools: Object.keys(actualTools).every((key) => actualTools[key] === Number(expectedTools[key])),
      chapters: chaptersMatch,
      collection: collectionMatches,
    };
    const verified = Object.values(verification).every(Boolean);
    if (!verified) {
      console.error("legacy_import_reconciliation_failed", {
        operatorId: operator.id, userId, legacyUid, verification,
      });
      return jsonResponse({
        error: "IMPORT_RECONCILIATION_FAILED",
        imported: result["imported"],
        duplicate: result["duplicate"],
        verification,
      }, 409);
    }

    return jsonResponse({ ...result, verified: true, verification });
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("legacy_account_import_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
