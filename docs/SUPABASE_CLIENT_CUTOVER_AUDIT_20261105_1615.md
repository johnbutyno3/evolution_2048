# Supabase client cutover audit — 2026-11-05 16:15 +08:00

Branch audited: `feature/chapter1-spec-implementation`  
Repository: `johnbutyno3/evolution_2048`  
Head at audit start: `1a13f43ed319ab5f8de8bd22beab1a43bdc99429` (`build: add Supabase CLI project configuration`)

## Verified progress

- `pubspec.yaml` currently declares `supabase_flutter` and does not declare Firebase packages.
- `lib/main.dart` initializes Supabase and routes from `SupabaseAuthService.authStateChanges`.
- `lib/screens/login_register_page.dart` uses Supabase email/password and Google/Apple OAuth.
- `lib/services/supabase_auth_service.dart` provides Supabase Auth sign-in, registration, OAuth, and sign-out.
- `lib/services/supabase_account_service.dart` validates the account snapshot and applies the authoritative account values to local caches.
- `lib/services/supabase_game_session_service.dart` calls the Supabase game-session Edge Functions.
- `lib/services/player_progress_service.dart` uses Supabase account/session services for progress, game start, resume, restart, abandon, and chapter completion.
- Supabase migrations and Edge Functions exist for account snapshots, life wallets/regeneration, daily Gold, game sessions, tool-package purchases, and controlled legacy account import.
- The 2026-11-05 legacy migration runbook explicitly states that no production Firebase export, verified identity mapping, deployment, import, or reconciliation has been completed. Firebase must remain available as the legacy data source until a controlled cutover is approved.

## Blocking client defects found

### 1. Firebase imports remain after Firebase dependencies were removed

The checked-in `pubspec.yaml` has no Firebase dependencies, but these current source files still import Firebase packages or call Firebase APIs:

- `lib/game/services/life_manager.dart` — imports `cloud_functions`; uses `FirebaseFunctions` and Firebase callable names `getLifeState`, `consumeLife`, and `refundLife`.
- `lib/game/services/gold_manager.dart` — imports `cloud_functions`; uses Firebase callable names `getGoldBalance` and `spendGold`.
- Additional Firebase references were found by repository-wide code search in `lib/services/admin_service.dart`, `lib/screens/feedback_page.dart`, `lib/services/creature_collection_service.dart`, `lib/services/player_profile_service.dart`, `lib/screens/personal_page.dart`, `lib/services/player_progress_service.dart` search matches, and `lib/screens/admin_test_page.dart`. Some search hits may be stale backup files; each active source file must be inspected before removal.

Because `cloud_functions` is not declared in the current manifest, the active imports in LifeManager and GoldManager are a direct Flutter dependency inconsistency and are expected to prevent a clean dependency-resolved build. Do not re-add Firebase packages as a workaround; migrate these callers to the existing Supabase API.

### 2. Account bootstrap is not yet proven to be wired into every authenticated route

The main router recognizes a Supabase session, but the app must not enable gameplay until `SupabaseAccountBootstrapService.synchronize()` and the server progress refresh have completed successfully. Verify the actual HomePage initialization path and gate all play/shop/profile entry points on bootstrap state.

### 3. Remaining active services require file-by-file migration

Prioritize:
1. Life state reads and session-based life mutations.
2. Gold balance reads and server-authoritative spending.
3. Tool inventory reads and tool-package purchase service.
4. Profile/admin/support/feedback services.
5. Creature collection persistence.
6. Remove obsolete Firebase options, generated registrants, and unused Firebase configuration only after active imports and platform registrations are proven absent.

## Safety constraints

- Do not delete Firebase Auth, Firestore data, Cloud Functions, or Firebase project resources yet. Existing accounts have not been exported and reconciled.
- Do not re-add Firebase client dependencies just to make old code compile.
- Do not move membership, Gold, lives, or tool authority into client-side preferences.
- Do not deploy migrations/functions until the Supabase project ref and target environment are explicitly checked against the intended project.
- Do not claim the app is buildable, deployed, or migrated until Flutter analysis/tests, database migration checks, Edge Function tests, and a device build have actually run.

## Next implementation slice

Replace the Firebase-dependent `LifeManager` and `GoldManager` with Supabase-backed implementations, reusing the validated account snapshot for reads and trusted Supabase Edge Function/RPC mutations for writes. Preserve existing public method contracts only where their semantics remain correct. In particular, game-entry life deduction must remain atomic with the Supabase game-session start operation; do not introduce a second independent life charge. Then migrate tool inventory and the remaining active service callers before removing residual Firebase configuration.

## Verification status

This audit used the checked-in GitHub branch contents and repository code search. No local Flutter/Dart runtime, Supabase CLI, live Supabase credentials, production Firebase export, or Android device test was available in this audit session. No deployment or runtime test is claimed.
