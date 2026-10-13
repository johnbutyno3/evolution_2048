# Rebirth 2048 — Backend Rewrite API Contract

Status: implementation contract; not a deployment approval.
Target branch: feature/chapter1-spec-implementation
Rewrite work branch: rewrite/backend-api-contract

## Non-negotiable architecture

- Gameplay moves and board presentation are local-first. A normal move must not wait for a callable.
- Server-authoritative operations: account identity, Life ledger, Gold ledger, tool purchases/settlement, membership, session ownership, chapter progression, collection discovery, security enforcement and admin actions.
- Every callable requires authenticated ownership checks; callable exports use Functions region `us-central1` and App Check enforcement in production.
- Never grant currency, lives, tool inventory, membership, or chapter unlocks solely because a client claims a value.
- Use Firestore transactions for coupled balance/inventory changes and idempotency keys for retryable mutations.
- Do not deploy until callable contract tests, rules tests, Flutter analysis, and emulator/integration checks pass.

## Client-required callable surface

### Identity and profile
- `getCallerIdentity()`
- `ensurePlayerProfile()` → `{ playerId, playerName, avatarIndex }`
- `updatePlayerProfile({ playerName })` → canonical profile fields
- `updatePlayerAvatar({ avatarIndex })` → canonical profile fields

### Life
- `getLifeState()` → `{ lives, infiniteLives, membership, lifeMode, nextLifeAtMillis }`
- `consumeLife()` → authoritative Life state; idempotent against duplicate request IDs
- `refundLife()` → authoritative Life state; must require a server-verifiable eligible completion/refund reason, not an unrestricted client refund

Rules: normal cap is 5; regenerate one Life every 40 minutes while below cap; purchased Lives may exceed 5 but regeneration must never increase above 5; Golden membership has unlimited Lives. Local optimistic display is allowed, but server result or later reconciliation is authoritative.

### Gold and tools
- `getGoldBalance()` → `{ balance, lifetimeSpent }`
- `spendGold({ amount, requestId })` → authoritative wallet state; positive bounded amount, transactionally checked
- `getToolInventory()` → `{ inventory, allToolsEnabledForTest }`
- `purchaseTool({ toolType, amount, requestId })` → `{ uses, balance, lifetimeSpent }`; debit and grant must commit atomically
- `consumeTool({ toolType, sessionId, eventId })` or validated session replay settlement; no client-supplied inventory overwrite

Tool types are `revive`, `timeRewind`, `positionSwap`, `duplicate`. Golden membership grants unlimited UNDO only; it must not grant unlimited uses of other tools. A purchase amount is a quantity, not a client-supplied price. Prices are read from trusted server configuration.

### Sessions and progression
- `startGameSession({ chapterIndex, replaceActiveSession, initialTiles, requestId })` → `{ sessionId, chapterIndex, life }`
- `resumeGameSession({ sessionId })`
- `restartGameSession({ sessionId, initialTiles, requestId })`
- `abandonGameSession({ sessionId, requestId })`
- `completeChapter({ sessionId, chapterIndex, highestValue, score, replayLog, requestId })`

A session must belong to the authenticated UID, have a bounded lifetime (2 hours unless a documented extension policy applies), and be settled at most once. Chapter unlocks are derived from server-verified progression; valid chapter indices are 0–5. Restart/abandon/completion must define exactly whether the Life is retained/refunded and whether pending tool uses are settled. Retries must not charge or settle twice.

### Collection
- `discoverCreature({ chapterKey, value, requestId })`
- Allowed chapter keys normalize to `ocean`, `land`, `sky`, `history`, `technology`, `space`. Values must be powers of two in the supported stage range and discovery must be idempotent.

### Membership, purchases, security and administration
- `getMembershipStatus()`
- `grantMembership(...)` must be restricted to trusted purchase verification/admin flows, never a general client grant
- `createPurchaseIntent(...)`, `submitPurchaseForVerification(...)`
- `adminSetMembershipMode`, `adminSetGoldBalance`, `adminSetAllToolsEnabled`, `adminGetTestAccountState`, `adminGetSecurityState`, `adminGetSecurityEvents`, `adminResetSecurityState`, `adminSetUnlockedChapter`

Every admin callable must verify a trusted admin claim/allowlist on the server and emit an audit event. Client-side visibility of an admin screen is not authorization.

## Firestore ownership and rules requirements

- Player documents and account-owned subcollections must be scoped to `request.auth.uid`.
- Client writes to authoritative wallet, Life, membership, tool inventory, session, security, and progression documents are denied; callable transactions own these mutations.
- Feedback: signed-in players may create their own feedback records only; cannot read other players' feedback, update, or delete records.
- Admin reads/writes require a server-verifiable admin claim/allowlist and must not rely on a client-set `isAdmin` field.
- Rules must explicitly enumerate allowed paths. Do not use a permissive wildcard to authorize arbitrary subcollections.
- Firestore rules are not filters and must be tested against actual client query paths before release.

## Current migration gap

The rewrite backend prototype currently exports only six callables: `getCallerIdentity`, `startGameSession`, `purchaseToolWithGold`, `consumeTool`, `abandonGameSession`, `completeChapter`. Existing Flutter services also require the additional callables listed above. The prototype is therefore not API-compatible and must not be deployed as a replacement yet.

## Release gate

1. Every callable above has input validation, authentication, App Check policy, ownership checks, and unit tests.
2. Firestore rules tests cover both allowed owner reads and denied cross-account/authoritative writes.
3. Flutter callable names and payload/result shapes match this contract.
4. `npm test`, backend syntax/lint, `flutter analyze`, `git diff --check`, and emulator integration tests pass.
5. Only then commit the implementation and plan deployment; do not deploy a partially compatible backend.
