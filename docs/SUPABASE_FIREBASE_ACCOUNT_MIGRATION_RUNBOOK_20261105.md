# Firebase to Supabase Account Migration Runbook

**Created:** 2026-11-05  
**Status:** Preparation only — no production account data has been imported.

## 1. Safety boundary

The Firebase project remains the source of legacy account records until a controlled export and reconciliation are complete. Do not delete Firebase Authentication, Firestore data, Cloud Functions, `firebase.json`, or `firestore.rules` during this phase.

The Supabase project is the destination for new account operations. A successful code migration does not mean legacy accounts or entitlements have been migrated.

Never match accounts by email alone and never copy Firebase password hashes into Supabase Auth as if they were compatible. Each legacy Firebase UID must be explicitly and verifiably linked to one Supabase Auth UUID. Prefer a user-controlled sign-in/linking flow with proof of control of both identities. If that is unavailable, use a separately verified support-assisted process. Do not create a Supabase account and attach legacy assets solely because an email string matches.

## 2. Verified legacy Firebase data layout

The checked-in Firebase Functions and Firestore rules establish these relevant locations:

| Data | Legacy location / fields |
|---|---|
| User profile | `users/{uid}`: `playerName`, `playerId`, `avatarIndex`, `isAdmin` |
| Membership | `users/{uid}/membership/current`: `type` (`premium` / `golden`), `expiresAt` |
| Gold | `users/{uid}/wallet/gold`: `balance`, `lifetimeGranted`, `lifetimeSpent` |
| Tools | `users/{uid}/wallet/tools`: `revive`, `timeRewind`, `positionSwap`, `duplicate` |
| Lives | `users/{uid}/life/current`: `lives`, `regenStartAt` |
| Chapter progress | `users/{uid}/progress/game`: `unlockedChapterIndex`, `highestValue`, `score`, `chapterProgress` |
| Creature collection | `users/{uid}/progress/collection`: chapter arrays `ocean`, `land`, `sky`, `history`, `technology`, `space` |

Legacy tool-code mapping:
- `revive` → `REMOVE`
- `timeRewind` → `UNDO`
- `positionSwap` → `SWAP`
- `duplicate` → `DUPLICATE`

Legacy chapter-name mapping:
- `ocean` → `C1`
- `land` → `C2`
- `sky` → `C3`
- `history` → `C4`
- `technology` → `C5`
- `space` → `C6`

## 3. Supabase destination verified in migrations

The current schema has:
- `auth.users` as the destination identity.
- `profiles` (including `display_name` and `avatar_index`).
- `memberships` with `FREE`, `PREMIUM`, `GOLDEN` and status.
- `gold_wallets`, `tool_inventory`, `life_wallets`.
- `game_progress` keyed by chapter code.
- `creature_collection` keyed by chapter code and creature value.
- `wallet_ledger` and `life_ledger` for future authoritative transactions.

The new-auth trigger creates default profile, membership, wallet, life, and tool rows. An import must update those existing defaults rather than assume the rows are absent.

## 4. Mapping and normalization rules

1. Map a legacy Firebase UID to exactly one verified Supabase `auth.users.id`; preserve the old UID in a restricted migration manifest for audit and reconciliation, not in a client-editable profile field.
2. Map only a currently valid permanent entitlement to `PREMIUM` or `GOLDEN`. The product rules define permanent memberships; inspect the actual legacy `expiresAt` and transaction evidence. An expired or unverifiable entitlement must not be promoted.
3. Copy the Gold balance as a non-negative integer after validating the export. Do not fabricate historical ledger rows if their event-level source records do not exist.
4. Copy each tool inventory as a non-negative integer using the tool mapping above. Do not apply the old “initial UNDO” grant a second time.
5. Normalize lives to 0–5. Translate `regenStartAt` to the destination `next_regen_at` using the remaining regeneration interval and the authoritative migration time; do not copy a client clock value as a future server timestamp without validation. If the legacy timestamp is missing or invalid, reconcile the life count and set a safe regeneration schedule.
6. Convert chapter progress from the legacy chapter object into one row per C1–C6. Preserve highest stage / score only when the source values are valid non-negative integers. Do not infer a completion timestamp that is absent.
7. Convert collection arrays to one row per valid power-of-two creature value, bounded by that chapter's target.
8. Do not import `isAdmin` as a client profile attribute or grant Supabase `app_metadata.role=admin` from an unverified Firestore field. Admin grants require a separate operator-controlled allowlist and review.
9. Active game sessions are not migrated as resumable sessions unless a separately tested state conversion is implemented. Keep the legacy export for support; require a clean new session after cutover.

## 5. Required migration procedure

1. Freeze destructive Firebase changes and take a timestamped export/backup of Firebase Auth and the relevant Firestore collections.
2. Produce an inventory report: account count, missing subdocuments, duplicate player IDs/names, invalid balances, invalid timestamps, membership status, and per-table counts. Keep PII and raw exports in restricted storage; do not commit them to Git.
3. Establish and verify the UID mapping for every account. Unlinked accounts remain unmigrated; do not guess.
4. Transform a copy of the export into a reviewed import manifest. Include source UID, destination Auth UUID, source export checksum, validation results, and per-account asset values.
5. Run a dry-run comparison and reconcile every rejected or ambiguous record before applying anything.
6. Apply through a one-time service-role-only importer with per-source-account idempotency and an audit record. The importer must refuse to overwrite an account already imported from a different source UID or to reapply an already completed import.
7. Reconcile totals and sample accounts (membership, Gold, all tools, lives, six chapters, collection) against the frozen export.
8. Only after sign-off, direct existing users to Supabase sign-in/linking and monitor account snapshot failures. Retain Firebase backups and read-only access for a defined rollback/support period.

## 6. Current blockers and non-claims

- No Firebase Auth / Firestore export has been supplied or processed in this repository workflow.
- No verified Firebase-UID-to-Supabase-UUID mapping exists here.
- No account import function or data import has been deployed.
- Firebase legacy resources have not been decommissioned.
- No production reconciliation, Flutter test, Edge Function deployment, or APK/device validation is claimed by this runbook.

**Cutover gate:** Do not announce existing-account migration as complete, remove Firebase backups, or disable legacy Firebase access until sections 5.1–5.8 have been completed and reconciled.
