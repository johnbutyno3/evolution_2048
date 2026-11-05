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
| Chapter progress | `users/{uid}/progress/game`: `unlockedChapterIndex`, `chapterProgress` with `ocean/land/sky/history/tech/universe` entries containing `highestValue` and `score` |
| Creature collection | `users/{uid}/progress/collection`: chapter arrays `ocean`, `land`, `sky`, `history`, `technology`, `space` |

Legacy tool-code mapping:
- `revive` → `REMOVE`
- `timeRewind` → `UNDO`
- `positionSwap` → `SWAP`
- `duplicate` → `DUPLICATE`

Legacy chapter-name mapping differs by source document:
- Game progress: `ocean` → `C1`, `land` → `C2`, `sky` → `C3`, `history` → `C4`, `tech` → `C5`, `universe` → `C6`.
- Creature collection: `ocean` → `C1`, `land` → `C2`, `sky` → `C3`, `history` → `C4`, `technology` → `C5`, `space` → `C6`.

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
5. Normalize lives to 0–5. The legacy field is `regenStartAt` (start of the current 40-minute interval), while Supabase stores `next_regen_at` (the next life arrival). Transform it to `regenStartAt + 40 minutes`, then validate against authoritative migration time. If lives are below 5 and the timestamp is missing, schedule the next life 40 minutes after import. If the timestamp is outside the accepted window, reject the record for manual reconciliation; never trust a device clock.
6. Convert the legacy game-progress keys (`ocean/land/sky/history/tech/universe`) into one row per C1–C6. Convert `highestValue` to `highestStage = log2(highestValue)` for valid power-of-two values; keep 0 as 0. Preserve `score` as `best_score` only when it is a valid non-negative safe integer. Leave `completed_at` null because the legacy source does not provide a reliable completion timestamp.
7. Convert collection arrays to one row per valid power-of-two creature value, bounded by that chapter's target.
8. Do not import `isAdmin` as a client profile attribute or grant Supabase `app_metadata.role=admin` from an unverified Firestore field. Admin grants require a separate operator-controlled allowlist and review.
9. Active game sessions are not migrated as resumable sessions unless a separately tested state conversion is implemented. Keep the legacy export for support; require a clean new session after cutover.

## 5. Import implementation committed to Git

The controlled import foundation is now present in this branch:
- `supabase/migrations/20261105120000_legacy_account_import.sql` creates service-role-only identity-link and import audit tables, plus an atomic idempotent import RPC. It validates balances, all four tool keys, life count/regeneration timestamp, chapter limits, and collection values.
- `supabase/functions/register-legacy-identity-link/index.ts` allows an authenticated Supabase admin to register a one-time verified Firebase UID → Supabase UUID link. It rejects duplicate links.
- `supabase/functions/import-legacy-account/index.ts` allows an authenticated Supabase admin to submit the transformed account payload and source-record SHA-256. The database RPC refuses unverified links, duplicate/different-source imports, and any Supabase account that is no longer pristine. After the transaction, the Edge Function reads back the profile, membership, Gold, lives, all tools, chapter progress, and collection; it returns `verified: true` only when the destination matches the submitted payload.

Expected payload fields are `profile` (`playerName`, `avatarIndex`, optional `accountStatus`), `membership` (`tier`, `status`, `expiresAt`), `gold` (`balance`), `lives` (`count`, `nextRegenAt`), `tools` (all four canonical keys `UNDO`, `REMOVE`, `SWAP`, `DUPLICATE`), `chapters` (array of `{chapterCode, highestStage, bestScore}`), and `collection` (array of `{chapterCode, creatureValue}`). This is a transformed per-account record, not a raw Firebase export. `sourceSha256` is the lowercase SHA-256 of the exact frozen source record used for transformation.

The exporter deliberately sets every legacy membership to `FREE` by default. A Firestore `type` field alone is not proof of a paid purchase, and a time-limited legacy `expiresAt` must never be converted into the current permanent membership product. The CSV may approve `PREMIUM` or `GOLDEN` only when the legacy record is non-expiring and the operator has separately verified purchase/support evidence; `membershipApprovalReference` is then written into the import audit summary. The SQL RPC independently rejects a paid tier without that approval reference. The importer intentionally does not import Firebase `playerId` (the current app uses the Supabase Auth UUID as its player ID), admin flags, password material, or active sessions. `completed_at` remains null because the legacy source does not provide a reliable completion timestamp. Zero balances and inventories remain represented by the destination rows without inventing zero-delta ledger entries.

## 6. Deployment and operator execution

Before importing any account, deploy the schema and both Edge Functions to the intended Supabase project. From the repository root, after confirming the linked project reference:

`supabase link --project-ref <SUPABASE_PROJECT_REF>`

`supabase db push`

`supabase functions deploy register-legacy-identity-link`

`supabase functions deploy import-legacy-account`

Then confirm both functions are deployed and that the invoking Supabase Auth account has the trusted `app_metadata.role=admin` claim. Never put the service-role key in Flutter, PowerShell scripts, CSV files, or Git. The Edge Functions use the server-side service-role environment supplied by Supabase.

### Windows PowerShell data preparation and import

1. Use a restricted Firebase service account with read-only access to Firebase Authentication and the listed Firestore paths. Keep its JSON key outside the repository.
2. From the repository root, install only the legacy export tool dependencies: `npm --prefix functions ci`.
3. Set the Firebase service-account path and project ID in the current PowerShell session, then export to a new restricted local path:

   ` $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\\secure\\firebase-readonly-service-account.json' `

   ` $env:GCLOUD_PROJECT = 'your-firebase-project-id' `

   ` node functions/scripts/export_legacy_account_snapshot.js 'C:\\secure\\legacy-export-20261105.json' `

4. Review every `validationErrors` array in the export. Any non-empty array blocks that account from the batch script; resolve it manually and regenerate a fresh export rather than editing its checksum-bearing source record.
5. Create a local UTF-8 CSV with these headers: `legacyUid,userId,verificationMethod,approvedMembershipTier,membershipApprovalReference`. Include only accounts whose Firebase and Supabase identities have been verified. Use `FREE` (or leave the approval fields empty) unless permanent paid entitlement evidence has been separately reviewed. For `PREMIUM` or `GOLDEN`, the legacy record must have no `expiresAt` and the approval reference must identify the verified receipt/support decision. Do not create this mapping by matching email addresses.
6. Set `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, and `SUPABASE_ACCESS_TOKEN` in the current PowerShell session. The access token must belong to a Supabase Auth user whose `app_metadata.role` is `admin`.
7. Run the importer first without `-Execute` for a dry run. After reviewing the count and mapping file, rerun with `-Execute`. The script registers the verified identity link, then imports each account. It counts an account only when the server-side read-back reconciliation returns `verified: true`. Re-running a successfully imported account is idempotent; a different source checksum or a non-pristine Supabase account is rejected.

Example dry run:

` .\\tools\\import_legacy_accounts.ps1 -ExportPath 'C:\\secure\\legacy-export-20261105.json' -MappingPath 'C:\\secure\\verified-account-map.csv' `

Example execution (only after review and deployment):

` .\\tools\\import_legacy_accounts.ps1 -ExportPath 'C:\\secure\\legacy-export-20261105.json' -MappingPath 'C:\\secure\\verified-account-map.csv' -Execute `

The exporter includes a normalized `importPayload`, a `membershipReview` object, and a SHA-256 checksum for each exact source record. The PowerShell script never sends accounts with validation errors, and only processes UIDs present in the mapping CSV. Both local files contain sensitive account data and must never be committed or uploaded to the project file library.

## 7. Required migration procedure

1. Freeze destructive Firebase changes and take a timestamped export/backup of Firebase Auth and the relevant Firestore collections.
2. Produce an inventory report: account count, missing subdocuments, duplicate player IDs/names, invalid balances, invalid timestamps, membership status, and per-table counts. Keep PII and raw exports in restricted storage; do not commit them to Git.
3. Establish and verify the UID mapping for every account. Unlinked accounts remain unmigrated; do not guess.
4. Transform a copy of the export into a reviewed import manifest. Include source UID, destination Auth UUID, source export checksum, validation results, and per-account asset values.
5. Run a dry-run comparison and reconcile every rejected or ambiguous record before applying anything.
6. Apply through the admin-gated Edge Function backed by the service-role-only RPC, with per-source-account idempotency and an audit record. The importer must refuse to overwrite a Supabase account already in use, an account already imported from a different source UID, or a completed import with a different source checksum.
7. Reconcile totals and sample accounts (membership, Gold, all tools, lives, six chapters, collection) against the frozen export.
8. Only after sign-off, direct existing users to Supabase sign-in/linking and monitor account snapshot failures. Retain Firebase backups and read-only access for a defined rollback/support period.

## 8. Current blockers and non-claims

- No Firebase Auth / Firestore export has been supplied or processed in this repository workflow.
- No verified Firebase-UID-to-Supabase-UUID mapping exists here.
- The import SQL migration and two admin-gated Edge Functions are committed but have not been deployed or executed.
- The Firebase export/normalization tool and PowerShell dry-run/import script are committed but have not been run against the production Firebase project.
- No verified Firebase-UID-to-Supabase-UUID mapping CSV has been prepared.
- Firebase legacy resources have not been decommissioned.
- No production reconciliation, Flutter test, Edge Function deployment, or APK/device validation is claimed by this runbook.

**Cutover gate:** Do not announce existing-account migration as complete, remove Firebase backups, or disable legacy Firebase access until sections 5.1–5.8 have been completed and reconciled.
