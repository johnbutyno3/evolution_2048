import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const PRICE_FIELDS: Record<string, { product: string; field: "priceUsd" | "priceGold"; integer: boolean }> = {
  gold300UsdPrice: { product: "gold_300", field: "priceUsd", integer: false },
  gold1000UsdPrice: { product: "gold_1000", field: "priceUsd", integer: false },
  gold4000UsdPrice: { product: "gold_4000", field: "priceUsd", integer: false },
  gold10000UsdPrice: { product: "gold_10000", field: "priceUsd", integer: false },
  premiumUsdPrice: { product: "membership_premium", field: "priceUsd", integer: false },
  goldenUsdPrice: { product: "membership_golden", field: "priceUsd", integer: false },
  undo1Price: { product: "tool_undo_1", field: "priceGold", integer: true },
  undo5Price: { product: "tool_undo_5", field: "priceGold", integer: true },
  undo20Price: { product: "tool_undo_20", field: "priceGold", integer: true },
  undo50Price: { product: "tool_undo_50", field: "priceGold", integer: true },
  remove1Price: { product: "tool_remove_1", field: "priceGold", integer: true },
  remove5Price: { product: "tool_remove_5", field: "priceGold", integer: true },
  remove20Price: { product: "tool_remove_20", field: "priceGold", integer: true },
  remove50Price: { product: "tool_remove_50", field: "priceGold", integer: true },
  swap1Price: { product: "tool_swap_1", field: "priceGold", integer: true },
  swap5Price: { product: "tool_swap_5", field: "priceGold", integer: true },
  swap20Price: { product: "tool_swap_20", field: "priceGold", integer: true },
  swap50Price: { product: "tool_swap_50", field: "priceGold", integer: true },
  duplicate1Price: { product: "tool_duplicate_1", field: "priceGold", integer: true },
  duplicate5Price: { product: "tool_duplicate_5", field: "priceGold", integer: true },
  duplicate20Price: { product: "tool_duplicate_20", field: "priceGold", integer: true },
  duplicate50Price: { product: "tool_duplicate_50", field: "priceGold", integer: true },
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const user = await authenticateRequest(req);
    if (user.app_metadata?.role !== "admin") {
      return jsonResponse({ error: "ADMIN_REQUIRED" }, 403);
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

    const prices = body["prices"];
    if (!prices || typeof prices !== "object" || Array.isArray(prices)) {
      return jsonResponse({ error: "INVALID_SHOP_PRICES" }, 400);
    }

    const service = createServiceClient();
    const { data: config, error: readError } = await service
      .from("shop_config").select("products").eq("id", "global").single();
    if (readError || !config || !config.products || typeof config.products !== "object") {
      return jsonResponse({ error: "SHOP_CONFIG_UNAVAILABLE" }, 503);
    }

    const products = { ...(config.products as Record<string, Record<string, unknown>>) };
    for (const [key, raw] of Object.entries(prices as Record<string, unknown>)) {
      const spec = PRICE_FIELDS[key];
      if (!spec) return jsonResponse({ error: "UNKNOWN_PRICE_FIELD" }, 400);
      const value = typeof raw === "number" ? raw : Number(raw);
      if (!Number.isFinite(value) || value <= 0 ||
        (spec.integer && !Number.isSafeInteger(value)) ||
        (!spec.integer && !/^\d{1,6}(\.\d{1,2})?$/.test(String(raw)))) {
        return jsonResponse({ error: "INVALID_PRICE_VALUE" }, 400);
      }
      const product = products[spec.product];
      if (!product || typeof product !== "object") {
        return jsonResponse({ error: "SHOP_PRODUCT_MISSING" }, 409);
      }
      products[spec.product] = { ...product, [spec.field]: spec.integer ? value : Number(value).toFixed(2) };
    }

    const { error } = await service.rpc("admin_update_shop_products", { p_products: products });
    if (error) {
      console.error("admin_shop_config_update_failed", { userId: user.id, code: error.code });
      return jsonResponse({ error: "SHOP_CONFIG_UPDATE_FAILED" }, 503);
    }
    return jsonResponse({ saved: true });
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("admin_shop_config_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
