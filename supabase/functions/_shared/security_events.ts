import { createServiceClient } from "./auth.ts";

type SecuritySeverity = "low" | "warning" | "high" | "critical";

export async function recordSecurityEvent(
  service: ReturnType<typeof createServiceClient>,
  userId: string,
  gameId: string,
  eventId: string,
  severity: SecuritySeverity,
  reason: string,
  message: string,
): Promise<boolean> {
  const { error } = await service.from("security_events").insert({
    user_id: userId,
    game_id: gameId,
    idempotency_key: `${eventId}:${reason}`,
    severity,
    reason,
    details: { message: message.slice(0, 240) },
  }, {
    onConflict: "user_id,idempotency_key",
    ignoreDuplicates: true,
  });

  if (error) {
    console.error("security_event_record_failed", {
      userId,
      gameId,
      reason,
      code: error.code,
    });
    return false;
  }
  return true;
}
