# Security Audit Logging

Security Audit schema foundation for server-generated security events.

## Canonical fields

- `eventId`
- `uid`
- `playerId`
- `eventType`
- `severity`
- `reason`
- `clientValue`
- `serverValue`
- `productId`
- `toolType`
- `transactionId`
- `requestId`
- `platform`
- `appVersion`
- `timestamp`
- `status`
- `details`
- `auditSchemaVersion`

## Severity normalization

- `WARNING` — general mismatch or invalid state
- `SUSPICIOUS` — abnormal frequency or repeated abnormal tool operations
- `CONFIRMED` — illegal authoritative-resource operation or clear server-authority bypass
- `CRITICAL` — forged/reused payment transaction, authoritative data modification, or large abnormal resource increase

The helper maps the legacy `high` severity to `CONFIRMED` so existing callers can migrate without changing their business logic in the same step.

This foundation does **not** claim that every existing `recordSecurityEvent` call has been migrated yet. Integration into `functions/index.js` remains the next step.
