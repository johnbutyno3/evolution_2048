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

    return jsonResponse(data ?? { imported: false, error: "EMPTY_IMPORT_RESULT" });
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
