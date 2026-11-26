# Rebirth 2048 — Localization Source Inventory

Audit branch: `feature/localization-purchase-audit-20261124`
Base branch: `feature/chapter1-spec-implementation`
Audit date: 2026-11-24

## Supported locales and generation

- Locale identifiers: `en` and `zh` (Traditional Chinese).
- Source of truth: `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb`.
- Generator configuration: `l10n.yaml`.
- Flutter localization generation is enabled by `flutter: generate: true` in `pubspec.yaml`.
- Generated runtime files: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_zh.dart`.
- Future locale additions must add a complete ARB file, update the supported-locale configuration, run `flutter gen-l10n`, and add locale parity tests. Do not edit generated Dart files manually in normal development; generated files are committed only as the output of the generator.

## User-visible screen inventory

### Game and chapter flow
- `lib/game/screens/evolution_2048_page.dart`: active board, score/best score, life/time indicators, tool actions, tool-unavailable sheet, restart confirmation, chapter-completion and next-chapter error states.
- `lib/game/screens/evolution_2048_chapters_page.dart`: chapter selection, Game Over dialog, legacy tool error messages and chapter progression.
- `lib/screens/home_page.dart`: home navigation, chapter cards, shop entry, game continuation.
- `lib/screens/onboarding_page.dart`: onboarding slides and first-run navigation.
- `lib/screens/profile_setup_page.dart`: player name/profile setup.
- No sign-in or registration screen is part of the guest-first app flow. The app opens the local game after onboarding.

### Account, collection and settings
- `lib/screens/personal_page.dart`: personal menu, player profile, avatar picker, creature collection, Gold summary, settings, game guide, version and about pages.
- `lib/screens/feedback_page.dart`: support category, message input, sending and result states.
- `lib/screens/qa_page.dart`: FAQ questions and answers.

### Shop and membership
- `lib/screens/shop_page.dart`: shop categories.
- `lib/screens/gold_page.dart`: Gold balance, packages and payment availability.
- `lib/screens/membership_page.dart`: General/Premium/Golden comparison, prices and current plan.
- `lib/screens/tools_page.dart`: tool inventory, package prices, purchase result and failure states.

### Administrator-only screens
- `lib/screens/admin_page.dart`: administrator dashboard, shop parameters, Q&A and player messages.
- `lib/screens/admin_test_page.dart`: test-control access and disabled legacy controls.

## Non-screen text sources that must be localized or intentionally excluded

- Game/domain labels: `lib/game/models/creature.dart`, `lib/game/models/tools/game_tool.dart`, `lib/game/models/game_tile.dart`.
- Game state and tool flows: `lib/game/services/game_engine.dart`, `tool_manager.dart`, `life_manager.dart`, `gold_manager.dart`, `save_manager.dart`, `audio_manager.dart`, `haptic_service.dart`.
- Account and profile errors: `lib/services/supabase_account_service.dart`, `supabase_player_profile_service.dart`, `player_profile_service.dart`, `player_progress_service.dart`. Guest profile and chapter progress are stored locally.
- Purchase/configuration: `lib/services/supabase_tool_purchase_service.dart`, `shop_config_service.dart`, `admin_service.dart`.
- Backend error identifiers and messages: Supabase Edge Functions under `supabase/functions/`, shared auth validators under `supabase/functions/_shared/`, and SQL/RPC errors under `supabase/migrations/`. Machine-readable codes remain stable identifiers; user-facing messages must be translated in the Flutter UI.
- Assets: image/audio filenames and internal asset IDs are not UI translations. Any text embedded inside artwork must be reviewed separately.
- Logs, analytics keys, database enum values, API payload keys, product codes (UNDO/REMOVE/SWAP/DUPLICATE), protocol names and source-code identifiers are not translated unless rendered to the player. Their displayed labels must come from ARB.

## Locale parity policy

- Every non-metadata key in `app_en.arb` must exist in `app_zh.arb`, and vice versa.
- Placeholder names and placeholder types must match exactly.
- Every new visible string must be added to both ARB files in the same change.
- Dynamic text must use typed ARB placeholders rather than concatenating translated sentence fragments.
- Avoid hard-coded English in widget text, labels, tooltips, dialogs, SnackBars, empty states, validation errors and navigation labels.
- Brand names and gameplay codes may remain unchanged only when they are intentional product terminology, not untranslated UI copy.

## Purchase and entitlement verification inventory

- Tool purchase request: `SupabaseToolPurchaseService.purchase` -> `purchase-tool-package` Edge Function -> `purchase_tool_package` database RPC.
- Successful tool purchase response is validated before `ToolManager` updates its local account cache and `GoldManager` balance.
- Account entitlement bootstrap: `SupabaseAccountService.fetchSnapshot` -> `SupabaseAccountSnapshot.parse` -> `SupabaseAccountBootstrapService.synchronize` -> `LifeManager`, `GoldManager`, and `ToolManager`.
- Membership and Gold real-money purchase are currently not connected to a payment provider. Their buttons must not simulate a real transaction or grant a paid membership. The visible message must clearly state that payment is unavailable.
- Local entitlement tests must use validated snapshot application methods. They must verify FREE owned-tool gating, PREMIUM unlimited lives, GOLDEN unlimited lives and UNDO, and zero-inventory denial.
- A client-only mock must never be mistaken for a real, server-authoritative paid entitlement.

## Current audit status

- Current ARB parity is 382 keys in each locale; no missing keys or placeholder-name/type mismatches were found.
- Bilingual shop, membership, tool, gameplay-dialog, all 87 creature names, legacy chapter tool actions, account/authentication, administrator, feedback and FAQ strings have been added in this branch.
- `test/localization_arb_test.dart` enforces locale key and placeholder parity.
- `test/creature_localization_test.dart` verifies all 87 creature names across all six chapters exist in both languages.
- `test/shop_entitlement_test.dart` covers validated FREE/PREMIUM/GOLDEN entitlements, debug-only simulated purchases, Gold deductions, FREE package limits, and unlocking a tool in an already active game manager.
- `test/guest_mode_test.dart` covers guest startup, unlimited local play, local session persistence/resume, and local chapter unlock without an authenticated Supabase session.
- `lib/services/shop_purchase_simulator.dart` and `AdminTestPage` provide an administrator-only, debug-build-only local simulator for membership, Gold and tool purchases. Simulated tool purchases deduct local Gold and enforce FREE package limits; no simulator action writes to Supabase or records a real-money transaction.
- Verification on commit `7c4e923615b3c69975d0f03a3757132703b5ce3b`: Flutter analyze passed; all 48 Flutter tests passed; Supabase source audit, Functions audit and disposable local Supabase migration/database integration tests passed. Android Debug APK build initially hit Maven Central HTTP 429 rate limiting, then passed on retry. Artifact `rebirth-2048-android-supabase-debug` was uploaded successfully (artifact ID `14902692833`, SHA-256 `97e2a5830e07ae9112140aab4559c7fc7f9a55e61eaae985cb1fa5d8b2e91487`, expires 2026-12-08).

## Guest-first single-player change (2026-11-25)

- The app no longer routes to a Google/Apple/email sign-in page. The sign-in screen and its auth facade have been removed from the Flutter client.
- Supabase initialization is optional; an unconfigured client no longer prevents local gameplay from starting. The Android guest APK workflow builds without injecting Supabase URL or publishable-key secrets.
- Guest gameplay uses the existing local save namespace, local session IDs, local chapter completion progress, and unlimited lives. No sign-in or account snapshot is required for guest game entry/resume/restart/completion.
- Guest profile name and avatar changes are stored locally. Cloud collection and account inventory refreshes are skipped for guests.
- Account-backed tool purchases are disabled in guest mode. Gold and membership real-money purchase buttons remain unavailable because no payment provider is integrated; they must not imply a completed transaction.
- Android and iOS OAuth callback deep links have been removed.
- This change is under CI validation; do not install or distribute an APK until the latest Android Debug APK workflow succeeds and the guest gameplay test passes.
