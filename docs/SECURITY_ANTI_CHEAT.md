# Rebirth 2048 — Security & Anti-Cheat Specification

## 1. Purpose

This document defines the security requirements for the production release of Rebirth 2048. It is the source of truth for server authority, purchase security, anti-cheat auditing, administrator alerts, and account accountability.

## 2. Server Authority

The following data must be authoritative on the server / Firestore and must not be controlled by Flutter or SharedPreferences:

- Gold balance
- Membership status and entitlement
- Tool inventory
- Life entitlement
- Chapter unlock / progression
- Purchase records

Flutter and local storage may only be used as client cache/state. Modifying the APK, Flutter code, SharedPreferences, or local cache must not modify authoritative server data.

## 3. Verification Timing

The client must not contact the server for every normal board move. Server verification is required at security-sensitive points:

- App startup / authenticated session initialization: synchronize authoritative economy and entitlement state.
- App foreground resume: refresh authoritative state when the configured sync interval has elapsed or when entitlement-sensitive state is needed.
- Tool use: server validates ownership/availability before the tool operation is accepted.
- Tool purchase: server validates Gold balance and product price, then atomically deducts Gold and grants the tool quantity.
- Purchase completion: server validates the store transaction before granting Gold or Membership.
- Membership-sensitive actions: server validates Premium / Golden entitlement when required.
- Chapter completion / unlock: server remains authoritative for chapter progression.
- Ordinary board movement: no per-move server request is required.

## 4. Cheat Audit

All suspected cheating or security anomalies must be recorded by the server.

A cheat/security event should contain, where applicable:

- eventId
- uid
- playerId
- eventType
- severity
- reason
- clientValue
- serverValue
- productId
- toolType
- transactionId
- requestId
- platform
- appVersion
- timestamp
- status

Players must not be able to create, modify, or delete their own security audit records.

## 5. Severity Levels

### WARNING

Examples:

- Client/server state mismatch
- Non-critical suspicious state

Action: record the event.

### SUSPICIOUS

Examples:

- Abnormally high request frequency
- Repeated abnormal tool operations

Action: record the event and alert administrators.

### CONFIRMED

Examples:

- Illegal Gold state
- Illegal tool inventory state
- Illegal membership state
- Explicit attempt to bypass server authority

Action: reject the operation, record the event, and alert administrators.

### CRITICAL

Examples:

- Forged purchase/receipt attempt
- Reused or conflicting transaction ID
- Attempt to modify authoritative data
- Large abnormal resource increase

Action: reject the operation, record the event, and immediately alert administrators.

## 6. Risk Score

Risk score is calculated by the server. The client must never provide or modify the authoritative risk score.

Initial scoring rules:

- Data mismatch: +10
- Abnormal request frequency: +20
- Illegal tool quantity: +50
- Illegal Gold: +80
- Forged transaction: +100

Initial thresholds:

- 0–29: Normal
- 30–59: Warning
- 60–99: Admin Alert
- 100+: Critical

Risk scoring rules may be extended by the server without changing the client application.

## 7. Administrator Alerts and Accountability

SUSPICIOUS, CONFIRMED, and CRITICAL events must create an administrator alert.

Administrators must be able to identify and investigate the affected account and related event data, including:

- Player ID
- Firebase UID
- Event type
- Severity
- Reason
- Client value, when available
- Server value, when available
- Timestamp
- App version
- Platform
- Related transaction ID / request ID

Audit records must be retained for accountability and investigation. Players must not be able to erase their own security history.

A single suspicious event must not automatically result in an account ban. Server-side rejection and audit logging are automatic; account suspension, resource recovery, or other disciplinary action is an administrator decision unless a later explicit production policy defines an automatic enforcement rule.

## 8. Purchase Security

All real-money Gold and Membership purchases must be server-authoritative.

Requirements:

- The server validates the authenticated user.
- The server validates the product ID against the authoritative shop configuration.
- The server validates the store transaction / receipt when store integration is enabled.
- transactionId must be unique.
- Transaction processing must be idempotent.
- A transaction must not grant resources more than once.
- The client must never mark a purchase completed by itself.
- The client must never directly grant Gold.
- The client must never directly activate Premium or Golden.

Current purchase-intent flow may remain pending until Google Play / Apple verification is integrated. No fake purchase success or test resource grant is permitted in production code.

## 9. Tool Security

Tool inventory and Gold spending are server-authoritative.

For a tool purchase, the server must:

1. Authenticate the player.
2. Validate the requested tool type and package.
3. Read the authoritative Gold balance.
4. Validate sufficient Gold.
5. Atomically deduct Gold.
6. Atomically grant the purchased tool quantity.
7. Return the authoritative resulting state.

For tool use, the server must validate that the player owns/has available uses before accepting the operation. Attempts to use unavailable tools must be rejected and may generate a security event according to severity.

## 10. Membership Security

Premium and Golden membership status must be server-authoritative.

Requirements:

- The server determines current membership status.
- The server determines subscription validity / expiration when payment integration is enabled.
- The client must not be trusted to set membership.
- Golden Infinite Lives is a server-derived entitlement.
- Membership-sensitive operations must use the server entitlement rather than a locally modified membership value.

## 11. Lives Security

Life is not sold as a separate shop product.

Golden membership grants Infinite Lives as an entitlement.

Normal players use the normal Life rules.

The client must not obtain Infinite Lives by modifying local membership state.

## 12. Chapter Progress Security

Chapter unlock and completion are server-authoritative.

The client must not be trusted to grant chapter unlocks by changing local progress values.

The existing server-side chapter completion flow must remain the authority for unlock state.

## 13. Firestore Security

Ordinary players must not directly write authoritative economy, entitlement, purchase, or security-audit data.

In particular, player-accessible rules must prevent direct client modification of:

- Gold balance
- Membership status
- Tool inventory
- Purchase status
- Purchase amount / product identity
- grantedAt / verification state
- transaction uniqueness records
- Cheat/security audit records
- Risk score

Trusted server code using Admin SDK is responsible for authoritative writes.

The `users/{uid}` update rule must not remain broad enough to permit future authoritative fields to be client-controlled. Any authoritative fields placed on the user document must be protected explicitly.

## 14. Admin Security

Shop configuration may be changed by authorized administrators through the server-controlled administrative path.

Ordinary players may read the public shop configuration but may not write it.

Administrative authorization must be enforced by backend security rules / trusted server checks, not merely by hiding an Admin UI in the Flutter client.

## 15. Production Requirements

Before production release, the following must be completed and verified:

1. Server-authoritative Gold
2. Server-authoritative Membership
3. Server-authoritative Tool Inventory
4. Server-authoritative Life entitlement
5. Anti-Cheat Audit Logging
6. Administrator Alerts
7. Server Risk Scoring
8. Secure Firestore Rules
9. Google Play purchase verification
10. Apple App Store purchase verification
11. Server-side transaction idempotency
12. Removal or isolation of production-reachable developer unlimited/reset capabilities
13. Verification that client-modified local state cannot grant authoritative resources

## 16. Current Implementation Status

As of this specification:

- Chapter progression has server-side completion handling.
- Shop configuration is remote-configured through Firestore.
- Purchase intent and purchase transaction uniqueness are server-side.
- Real store receipt verification is not yet integrated.
- Gold, Membership, Tools, and Lives still require the planned server-authoritative migration.
- Anti-cheat audit and administrator alert implementation is specified here but is not yet implemented.

This status section must be updated as implementation progresses.
