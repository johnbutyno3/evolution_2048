import { authenticateRequest, corsHeaders, createServiceClient, jsonResponse } from "../_shared/auth.ts";

const CHAPTER_LIMITS: Record<string, number> = {
  C1: 4096,
  C2: 8192,
  C3: 16384,
  C4: 32768,
  C5: 65536,
  C6: 131072,
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "METHOD_NOT_ALLOWED" }, 405);

  try {
    const user = await authenticateRequest(req);
    let body: Record<string, unknown>;
    try {
      const value: unknown = await req.json();
      if (!value || typeof value !== "object" || Array.isArray(value)) {
        return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
      }
      body = value as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: "INVALID_REQUEST_BODY" }, 400);
    }

    const chapterCode = typeof body["chapterCode"] === "string" ? body["chapterCode"] : "";
    const creatureValue = body["value"];
    const limit = CHAPTER_LIMITS[chapterCode];
    if (limit === undefined || typeof creatureValue !== "number" ||
      !Number.isSafeInteger(creatureValue) || creatureValue < 2 ||
      creatureValue > limit || (creatureValue & (creatureValue - 1)) !== 0) {
      return jsonResponse({ error: "INVALID_CREATURE_DISCOVERY" }, 400);
    }

    const service = createServiceClient();
    const { error } = await service.from("creature_collection").upsert({
      user_id: user.id,
      chapter_code: chapterCode,
      creature_value: creatureValue,
    }, {
      onConflict: "user_id,chapter_code,creature_value",
      ignoreDuplicates: true,
    });
    if (error) {
      console.error("creature_discovery_write_failed", {
        userId: user.id,
        chapterCode,
        code: error.code,
      });
      return jsonResponse({ error: "COLLECTION_SYNC_UNAVAILABLE" }, 503);
    }
    return jsonResponse({ discovered: true, chapterCode, value: creatureValue });
  } catch (error) {
    if (error instanceof Error && error.message === "UNAUTHORIZED") {
      return jsonResponse({ error: "UNAUTHORIZED" }, 401);
    }
    console.error("creature_discovery_unexpected_error", {
      message: error instanceof Error ? error.message : "unknown",
    });
    return jsonResponse({ error: "INTERNAL_ERROR" }, 500);
  }
});
