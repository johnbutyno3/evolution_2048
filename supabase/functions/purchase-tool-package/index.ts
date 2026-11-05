import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const TOOL_CODES = new Set(["UNDO", "REMOVE", "SWAP", "DUPLICATE"]);
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

    const toolCode = typeof body["toolCode"] === "string" ? body["toolCode"] : "";
    const quantity = body["quantity"];
    const idempotencyKey = typeof body["idempotencyKey"] === "string"
      ? body["idempotencyKey"]
      : "";

    if (!TOOL_CODES.has(toolCode) ||
      typeof quantity !== "number" ||
      !Number.isSafeInteger(quantity) ||
      ![1, 5, 20, 50].includes(quantity) ||
      !UUID_PATTERN.test(idempotencyKey)) {
      return jsonResponse({ error: "INVALID_TOOL_PURCHASE_REQUEST" }, 400);
    }

    const service = createServiceClient();
    const { data, error } = await service.rpc("purchase_tool_package", {
      p_user_id: user.id,
      p_tool_code: toolCode,
      p_quantity: quantity,
      p_idempotency_key: idempotencyKey,
    });

    if (error) {
      const message = error.message ?? "";
      if (message.includes("ACCOUNT_RESTRICTED")) {
        return jsonResponse({ error: "ACCOUNT_RESTRICTED", supportAvailable: true }, 423);
      }
      if (message.includes("MEMBERSHIP_REQUIRES_REVIEW")) {
        return jsonResponse({ error: "MEMBERSHIP_REQUIRES_REVIEW", supportAvailable: true }, 423);
      }
      if (message.includes("INSUFFICIENT_GOLD")) {
        return jsonResponse({ error: "INSUFFICIENT_GOLD" }, 402);
      }
      if (message.includes("FREE_SINGLE_TOOL_ONLY") ||
        message.includes("GOLDEN_UNDO_UNLIMITED") ||
        message.includes("TOOL_PACKAGE_UNAVAILABLE") ||
        message.includes("TOOL_PRICE_UNAVAILABLE")) {
        return jsonResponse({ error: message }, 409);
      }
      if (message.includes("IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD")) {
        return jsonResponse({ error: "IDEMPOTENCY_CONFLICT" }, 409);
      }
      console.error("purchase_tool_package_failed", {
        userId: user.id,
        code: error.code,
      });
      return jsonResponse({ error: "TOOL_PURCHASE_UNAVAILABLE" }, 503);
    }

    return jsonResponse(data);
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("purchase_tool_package_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
