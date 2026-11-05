import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const METHODS = new Set(["dual_account_proof", "support_verified", "operator_verified"]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const operator = await authenticateRequest(req);
    if (operator.app_metadata?.role !== "admin") {
      return jsonResponse({ error: "ADMIN_ACCESS_REQUIRED" }, 403);
    }

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

    const legacyUid = typeof body["legacyUid"] === "string" ? body["legacyUid"].trim() : "";
    const userId = typeof body["userId"] === "string" ? body["userId"].trim() : "";
    const verificationMethod = typeof body["verificationMethod"] === "string"
      ? body["verificationMethod"]
      : "";
    if (!legacyUid || legacyUid.length > 128 ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(userId) ||
      !METHODS.has(verificationMethod)) {
      return jsonResponse({ error: "INVALID_IDENTITY_LINK" }, 400);
    }

    const service = createServiceClient();
    const { error } = await service.from("legacy_identity_links").insert({
      legacy_provider: "firebase",
      legacy_uid: legacyUid,
      user_id: userId,
      verification_method: verificationMethod,
      verified_by: operator.id,
    });

    if (error) {
      console.error("legacy_identity_link_rejected", {
        operatorId: operator.id,
        userId,
        code: error.code,
      });
      if (error.code === "23505") {
        return jsonResponse({ error: "IDENTITY_LINK_ALREADY_EXISTS" }, 409);
      }
      if (error.code === "23503") {
        return jsonResponse({ error: "SUPABASE_USER_NOT_FOUND" }, 404);
      }
      return jsonResponse({ error: "IDENTITY_LINK_FAILED" }, 500);
    }

    return jsonResponse({
      linked: true,
      legacyProvider: "firebase",
      legacyUid,
      userId,
      verificationMethod,
    });
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("legacy_identity_link_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
