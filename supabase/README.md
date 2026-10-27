# Rebirth 2048 — Supabase backend

Supabase is the target backend for this project. Firebase is legacy during migration and must not receive new backend features.

## Required environment

Flutter should receive only the Supabase project URL and publishable/anon key through the project's chosen build configuration. Never put the Supabase service-role key in Flutter, web assets, committed source, or client-visible environment variables.

Trusted operations must run in Supabase Edge Functions or another trusted server environment. This includes:
- Apple App Store / Google Play transaction verification and grants
- membership changes, Gold credits/debits, tool inventory changes, daily Gold
- life debit/refund events, chapter completion, and permanent progress updates
- idempotency checks and account locking
- admin notification delivery and support status changes

## Database migration

Apply migrations in order using the Supabase CLI linked to the intended project:

```powershell
supabase login
supabase link --project-ref <YOUR_PROJECT_REF>
supabase db push
```

The project reference is intentionally a placeholder; do not commit credentials or secrets.

Initial migration: `migrations/20261028000000_initial_schema.sql`.

## Initial schema scope

- Profiles and membership state
- Gold wallet, tool inventory, and immutable wallet ledger
- Chapter progress and game session/checkpoint records
- Store transaction records
- Support tickets, two-way messages, and admin notification queue
- Row Level Security policies with default-deny writes for authoritative account/economy tables

## Important migration status

This is a baseline schema, not a finished backend. It has not yet been applied to a live Supabase project, and SQL has not been executed against a Supabase database in this workflow. Flutter still contains Firebase imports and Firebase packages at this point.

Before release, add and test Edge Functions for atomic/idempotent operations, store receipt verification, daily rewards, game-session lifecycle, support/admin workflows, and account status enforcement. Add RLS and integration tests, then migrate Flutter services and remove Firebase only after all call sites have been replaced and validated.
