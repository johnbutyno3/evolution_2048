# Rebirth 2048 — Supabase backend

Supabase is the target backend for this project. Firebase is legacy during migration and must not receive new backend features.

## Client configuration

Flutter receives only the Supabase project URL and publishable/anon key through build-time defines:

```powershell
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Use the actual project URL and public publishable/anon key from the Supabase dashboard. Do not commit them if your repository policy requires configuration to remain external. Never put the Supabase service-role key in Flutter, web assets, or committed source.

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
- `save-game-checkpoint` — monotonic checkpoint persistence for recovery.
- `finish-game-chapter` — replay validation, tool settlement, permanent progress and eligible life refund.

Deploy only after the migrations are successfully applied and integration-tested:

```powershell
supabase functions deploy account-snapshot
supabase functions deploy start-game-session
supabase functions deploy save-game-checkpoint
supabase functions deploy finish-game-chapter
```

Edge Functions use the server-side service-role key only within the trusted runtime. Never expose that key to the Flutter client. Sensitive database RPCs explicitly revoke execution from `public`, `anon`, and `authenticated`, and grant it only to `service_role`.

## Initial schema scope

- Profiles, membership status, account lock status and account timezone
- Gold wallet, tool inventory, immutable wallet ledger and atomic wallet mutation
- Life wallet, life ledger, server-time regeneration and idempotent daily Gold claims
- Game sessions bound to an initial board, monotonic checkpoints and replay-validated chapter completion
- Purchase transaction records
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

This is an in-progress migration, not a finished backend. The SQL migrations and Edge Functions have been committed to GitHub, but they have not been applied to a live Supabase project or run in a Deno/Supabase runtime in this workflow. Flutter still has Firebase imports and packages. Firebase dependencies must not be removed until all Firebase call sites have been migrated and tested.

Still to implement and validate:
- Supabase Auth migration for Google, Apple and email/password
- Complete Flutter service migration for profile, life, Gold, tools, game lifecycle, collection, admin and support
- Apple App Store and Google Play server-side purchase verification, refunds/revocations and grant reconciliation
- Admin notification delivery, support replies and ticket status workflows
- Full RLS, SQL integration, concurrency, replay, account-lock appeal and device E2E tests

Never claim a deployment or test passed unless the command or live test was actually run and its result recorded.
