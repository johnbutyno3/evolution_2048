# Rebirth 2048 — Supabase backend

Supabase is the target backend for this project. Firebase is legacy during migration and must not receive new backend features.

## Client configuration

Flutter receives only the Supabase project URL and publishable/anon key through build-time defines:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Use the actual project URL and public publishable/anon key from the Supabase dashboard. Do not commit them if your repository policy requires configuration to remain external. Never put the Supabase service-role key in Flutter, web assets, or committed source.

## Supabase Auth provider configuration

The native OAuth callback URI registered by the Android intent filter and iOS URL scheme is:

```text
io.supabase.rebirth2048://login-callback/
```

Before enabling Google or Apple sign-in in the app:

1. Open Supabase Dashboard for the intended project.
2. In **Authentication → URL Configuration**, add the exact callback URI above to the Redirect URLs allow-list.
3. Configure the Google provider with the OAuth client credentials and authorized redirect/callback URL shown by the Supabase provider settings.
4. Configure the Apple provider with the required Services ID, Team ID, Key ID and private key; ensure the Apple return URL matches the Supabase provider settings.
5. Test sign-in, app return from the external browser, session restoration after force-closing the app, and sign-out on both Android and iOS.

The shared native callback is not a substitute for provider credentials or the Supabase Dashboard allow-list. Web OAuth must use a separately configured HTTPS redirect URL; do not reuse the native URI for web builds. The Flutter login/register screen now calls Supabase Auth for email/password and OAuth. Provider credentials and redirect allow-lists still need to be configured and tested in the target Supabase project before OAuth sign-in can be considered operational.

## Database migration

First link the intended Supabase project. Run commands from the repository root:

```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

Review the migration plan before applying it to production. Apply and test migrations in a development Supabase project first. Current migration files are under `migrations/`; they are versioned in Git and must be applied in filename order.

## Edge Functions

The initial server endpoints are:
- `account-snapshot` — authoritative membership, Gold, life and tool snapshot; idempotent daily Gold claim and server-time life regeneration.
- `start-game-session` — idempotent new-game creation with atomic FREE life debit and initial-board binding.
- `resume-game-session` — authenticated read of an active session and its recovery checkpoint; checkpoint data is not completion proof.
- `restart-game-session` — replay-validates and settles the old session, then starts the replacement and charges its Life in one database transaction. If the new start fails (including insufficient Life), the old session and its inventory remain unchanged.
- `save-game-checkpoint` — monotonic checkpoint persistence for recovery.
- `finish-game-chapter` — replay validation, tool settlement, permanent progress and eligible life refund.
- `abandon-game-session` — replay validation and idempotent tool settlement for Game Over / player exit; it never refunds the Life charged at game start.

An additional database trigger rejects any `ACTIVE` → `ABANDONED` transition unless a `SESSION_ABANDON` settlement event exists in the same transaction. This prevents new-game replacement from silently bypassing replay validation and tool settlement.

Deploy only after the migrations are successfully applied and integration-tested:

```powershell
supabase functions deploy account-snapshot
supabase functions deploy start-game-session
supabase functions deploy resume-game-session
supabase functions deploy restart-game-session
supabase functions deploy save-game-checkpoint
supabase functions deploy finish-game-chapter
supabase functions deploy abandon-game-session
supabase functions deploy discover-creature
supabase functions deploy purchase-tool-package
supabase functions deploy admin-update-shop-config
supabase functions deploy register-legacy-identity-link
supabase functions deploy import-legacy-account
```

Edge Functions use the server-side service-role key only within the trusted runtime. Never expose that key to the Flutter client. Sensitive database RPCs explicitly revoke execution from `public`, `anon`, and `authenticated`, and grant it only to `service_role`.

## Initial schema scope

- Profiles, membership status, account lock status and account timezone
- Gold wallet, tool inventory, immutable wallet ledger and atomic wallet mutation
- Life wallet, life ledger, server-time regeneration and idempotent daily Gold claims
- Game sessions bound to an initial board, monotonic checkpoints, replay-validated chapter completion and idempotent abandonment settlement
- Purchase transaction records (the client-side real-money purchase flow and store receipt verification are not yet implemented; Gold and membership purchase buttons remain intentionally disabled)
- Creature collection discovery and atomic Gold-to-tool purchases
- Support tickets, two-way message schema, security events and admin notification queue
- Row Level Security with default-deny writes for authoritative account/economy tables

## Tests and validation

Run the pure replay-validator contract tests where Deno is installed:

```powershell
deno test supabase/functions/_shared/replay_validator_test.ts
```

Then run Flutter dependency resolution and tests:

```powershell
flutter pub get
flutter analyze
flutter test
```

Also verify the migrations against a real disposable Supabase project, exercise concurrent duplicate requests and rollback paths, and run authenticated end-to-end tests. Source-file existence or a successful Flutter compile alone is not acceptance.

## Migration status and remaining work

This is an in-progress migration, not a finished production cutover. The Flutter application bootstrap and login/register flow now use Supabase Auth, and the active account, game-session, profile, collection, shop-configuration and tool-purchase client services use Supabase. Firebase Admin SDK remains in the isolated legacy export tooling under `functions/` because it is still needed to read old account data. The legacy Firebase project, Auth records, Firestore data and Cloud Functions must remain available until export, verified identity mapping, import and reconciliation are complete. The Supabase SQL migrations and Edge Functions are committed to GitHub but have not yet been applied to the live project in this workflow.

Still to implement and validate:
- Configure and live-test Supabase email/password, Google and Apple Auth providers, redirects, session restoration and account linking
- Apple App Store and Google Play server-side receipt verification, refunds/revocations, membership upgrades and Gold grants; real-money purchase buttons remain disabled until this is complete
- Admin notification delivery, support replies and ticket status workflows
- Apply every migration to a disposable Supabase project first, then production; run SQL/RLS integration, concurrency, replay, account-lock appeal and device E2E tests
- Complete the Firebase account export, verified UID-to-Supabase UUID mapping, controlled import and reconciliation before any Firebase decommission

Never claim a deployment or test passed unless the command or live test was actually run and its result recorded.
