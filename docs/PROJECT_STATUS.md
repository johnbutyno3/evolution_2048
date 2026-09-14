# Rebirth 2048 - Project Status

## Current Phase
Personal Information + Shop / Marketplace -> Launch Security / Anti-Cheat

## Canonical Progress Rules
- This file is the canonical project-progress source.
- Only committed GitHub state counts as completed.
- Do not restore the old 18-tier system or change the six-chapter rules.

## Latest Committed Status (2026-09-14)
- Personal Information + Shop / Marketplace architecture is established.
- Player profile uniqueness and secure profile indexes are implemented.
- Remote Shop Config, purchase-intent records, and transaction uniqueness protections are established.
- Server-authoritative Gold foundation is implemented: authenticated reads, atomic spending, protected wallet writes, and no client Gold grant.
- Membership status reads are server-side; Golden Infinite Lives is derived from server membership.
- Tool inventory reads, tool purchases, and tool-use inventory validation are server-side.
- Deterministic replay validation and replay-session tool validation are implemented in the latest security commits.
- Real Google Play / Apple receipt verification, server-authoritative reward grants, and full anti-cheat audit/admin alert implementation remain pending.
- Golden membership price is USD 5.99/month.
- Life is NOT sold as a separate shop product.

## Latest Security Commits
- `0eaefc4` - security: validate replay tool usage against session
- `eba6c11` - security: wire deterministic replay validation
- `675a9bf` - security: add deterministic replay validator
- `29b4424` - fix: avoid invalid null-aware replay map elements
- `9119892` - docs: add security and anti-cheat specification

## Completed Areas
### Personal Information
- Personal Page, Player Info, Evolution Progress, permanent Creature Collection entry, Settings, Game Guide, Version Info, and Log Out entries established.
- Shop remains separate from Personal Information.
- Player profile uniqueness and secure indexes implemented.

### Shop / Marketplace
- Shop Page established.
- Gold is used for purchases.
- Tool purchases and owned quantities are established.
- Life is not a separate purchasable product.
- Remote Shop Config is established at `shop_config/global`.
- Real store payment verification and authoritative resource granting remain pending.

### Creature Collection
- Firebase-account-scoped, additive collection data layer exists at `users/{uid}/progress/collection`.
- Collection history is separate from mutable game save state.
- Direct gameplay achievement/event wiring and verified Collection Page display remain pending.

### Security / Anti-Cheat
- Security specification exists in `docs/SECURITY_ANTI_CHEAT.md`.
- Server-authoritative direction is defined for Gold, Membership, Tools, Lives, Purchases, and Chapter Progress.
- Gold spending and tool-use validation are implemented server-side.
- Deterministic replay validator and session-bound replay tool checks are implemented.
- Cheat audit logging, admin alerts, risk scoring enforcement, and receipt verification remain pending.

## Current Functional Findings (2026-09-14)
- Personal Page avatar entry/layout still requires correction.
- Avatar and player-name persistence still requires authenticated Firebase persistence verification.
- Home six-chapter display still requires correction/testing.
- Creature Collection Page still requires correction/testing.
- Separate Gold menu removal still requires correction/testing.
- Settings language selection and complete removal of GAME DATA still require verification.
- Detailed Game Guide still requires expansion.
- Version Information must show the actual app version.
- Dedicated Game Information / Credits section is still required.
- Shop Gold/tool icon presentation still requires verification.

## Next Explicit Task
Continue launch security hardening, in this order:
1. Complete server-authoritative Gold grants for verified payments/rewards.
2. Complete server-authoritative Membership state and receipt verification.
3. Complete server-authoritative Tool inventory grants/deductions.
4. Make Golden Infinite Lives depend on verified server membership.
5. Tighten `users/{uid}` Firestore update permissions.
6. Isolate production-reachable developer unlimited/reset capabilities.
7. Implement Cheat Audit logging, risk-score enforcement, and administrator alerts.
8. Integrate Creature Collection writes with actual gameplay evolution events and verify the Collection Page.

## Game Rules Consistency
- `docs/GAME_RULES.md` remains authoritative for the 4x4 board, 2048 merge behavior, six chapters, cumulative tool inventory, chapter-specific tool locks, and Chapter 6 UNDO-only usage.
- Latest security work validates sessions/tools/replays and does not change game rules.
- No conflict found between the latest security implementation and the six-chapter rules.

## Git / Development
Branch: `feature/chapter1-spec-implementation`
Before committing: `flutter analyze` must pass. Do not force-push. Keep unrelated changes intact.

Branch:
`feature/chapter1-spec-implementation`

Before committing:
- `flutter analyze` must pass.
- Do not force push.
- Keep unrelated existing changes intact.

## Functional Test Findings - 2026-09-14

The following issues were identified during Chrome functional testing and are now the active correction list.

### 1. Personal Page Layout / Avatar Entry

Required behavior:

- Avatar remains on the left side.
- The `PLAYER INFO` menu item must not appear.
- The avatar itself is the direct entry point to Personal Information / Player Info.
- Player Info must not be moved to a center menu position.

### 2. Avatar and Player Name Persistence

Current problem:

- Selecting/changing the avatar does not currently persist correctly.
- Changing the player name does not currently persist correctly.

Required behavior:

- Avatar selection must be saved to the authenticated Firebase account.
- Player name must be saved to the authenticated Firebase account.
- Re-entering Personal Information must display the saved values.
- Re-login must restore the saved values.
- Profile persistence must not rely only on temporary local UI state.

### 3. Home Chapter Screen

Current problem:

- The game chapter screen does not currently load/display correctly.

Required behavior:

- Home must display the six authoritative game chapters.
- Chapter 1 remains the initial unlocked chapter.
- Chapter progression must continue to use the current six-chapter architecture.
- Do not restore the old 18-tier chapter system.

### 4. Creature Collection Page

Current problem:

- Creature Collection currently does not load/display correctly.

Required behavior:

- Collection Page must display the permanent six-chapter collection.
- Collection data must come from the authenticated Firebase account.
- Previously discovered creatures must remain permanent.
- Collection must remain separate from mutable game save state.
- Do not create a second competing progress system.

### 5. Gold Menu Removal

Required behavior:

- Remove the separate Gold menu item from Personal Information.
- Gold balance remains visible inside Personal Information.
- The existing direct purchase / Go to Shop entry remains available.

### 6. Settings / Language / Game Data

Required behavior:

- Settings must provide language selection.
- Language selection must be functional.
- `GAME DATA` must be completely removed.
- Do not recreate or restore a Game Data menu in future revisions.

### 7. Detailed Game Guide

Current state:

- Game Guide entry exists but is not sufficiently detailed.

Required content should explain, at minimum:

- Core 2048 gameplay rules.
- Creature evolution / merge concept.
- Chapter progression.
- Scoring.
- Lives.
- Tools.
- Tool usage and costs.
- Chapter completion.
- Creature Collection.
- Gold and Shop.
- Membership.
- Saving and account-related behavior.
- Basic gameplay tips.

The guide should be suitable for an international player and support future localization.

### 8. Version Information

Required behavior:

- Version Information must display the actual application version number.
- The displayed version must correspond to the version defined by the application/package configuration.
- Do not display only a generic `Version Info` label without the version number.

### 9. Game Information / Credits

Required:

Create a dedicated Game Information / Credits section.

It should provide appropriate project credits, including:

- Game title: Rebirth 2048
- Game designer / creator
- Music provider / music credits
- Art / asset credits where applicable
- Technology / framework information where appropriate
- Third-party licenses or attribution where required

This is separate from the Game Guide.

### 10. Shop Tool and Gold Icons

Required behavior:

- Tools must retain their existing tool images.
- Tool entries should have an appropriate visual symbol/icon before the relevant purchase/value information where needed.
- Gold should have a clear Gold symbol/icon.
- The presentation should be visually consistent between Gold, Lives, and Tools.
- Do not remove the existing tool artwork.

### 11. Project Status Documentation

- All current functional findings must be recorded in this document.
- Completed features and unresolved functional issues must remain clearly separated.
- Do not mark the above unresolved items as completed until they are actually tested and working.
- Every future major phase change should update this document.

## Server-Authoritative Gold

Server-authoritative Gold foundation is implemented:

- Gold reads use `getGoldBalance` and keep only a UI cache in Flutter.
- Gold spending uses the atomic `spendGold` Cloud Function.
- Client Gold grant/reset APIs were removed.
- No callable client Gold grant exists.
- Firestore denies client writes to `users/{uid}/wallet/{walletId}`.

Not yet implemented:

- Server-authoritative Gold grants for verified payments or rewards.
- Server-authoritative Tools inventory.
- Server-authoritative Membership state.
- Migration of any legacy local Gold balances; local values are not trusted.

## Collection Integration Requirement

Connect the Creature Collection data layer to the actual game achievement/evolution event.

When a creature/stage is actually reached during gameplay:

1. Record it in the current Firebase account's collection.
2. Never remove previously discovered creatures.
3. Keep discoveries across replay and game-over.
4. Make Collection Page display the permanent six-chapter collection.
5. Do not create a second competing progress system.
## Monetization / Rewarded Ads - Formal Product Rules

The following monetization rules are now the current product decision:

- Rewarded Ads are opt-in.
- Life = 0: player may wait 40 minutes for +1 Life or watch a Rewarded Ad for +1 Life.
- Game Over with Life > 0: normal Restart consumes 1 Life; no ad revive is offered.
- Game Over with Life = 0: Rewarded Ad revive may be offered once for that Game Over.
- Insufficient tools: normal purchase path is Gold.
- Rewarded Ad tool reward is limited to UNDO.
- Each game allows at most one Rewarded Ad UNDO.
- REMOVE, SWAP, and DUPLICATE do not have Rewarded Ad tool rewards.
- Forced interstitial advertising is not the core monetization mechanism.
- Membership provides No Ads + Infinite Lives.
- Rewarded Ads do not directly grant Gold unless a future product decision explicitly adds such a reward.

## Payment Integration Status

- International paid amounts use USD.
- Golden membership price remains USD 5.99/month.
- Google Play and Apple real-payment verification / authoritative purchase granting are intentionally deferred.
- Store payment integration will be implemented later after the store-account and payment-verification application/setup work is completed.

## Active Development - Pending Commit

The following work is currently local/uncommitted and must not be treated as completed until tested and committed:

- Bind server tool usage to the active game `sessionId`.
- Reuse the active game session during chapter completion.
- Submit the engine-generated `replayLog` for server-side chapter completion validation.
- Avoid creating an unnecessary second game session during completion.

These changes must pass functional testing, `flutter analyze`, and `git diff --check` before being considered completed.
