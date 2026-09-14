# Rebirth 2048 - Project Status

## Current Phase
Personal Information + Shop / Marketplace ??Launch Security / Anti-Cheat

## Progress Update Protocol

- This file is the canonical project-progress source for daily status extraction.
- During active development, progress is updated continuously after each important completed task, milestone, major issue, or security finding.
- Do not wait for a fixed hourly background job; documentation updates are tied to actual work completed.
- Every meaningful completed batch should record the current state, latest commit, and next task.
- No uncommitted/local-only work is treated as completed here.

## Latest Committed Status (2026-09-14)

- Personal Information + Shop / Marketplace architecture is established.
- Player profile uniqueness and secure player-profile indexes are implemented.
- Remote Shop Config is established at `shop_config/global` with authenticated read and admin-only write rules.
- Purchase intent / verification-record architecture is established; authoritative grant flow remains pending real payment verification.
- Security and anti-cheat specification is documented in `docs/SECURITY_ANTI_CHEAT.md`.
- Golden membership price is USD 5.99/month.
- Life is NOT sold as a separate shop product.
- Current paid shop categories are Gold, Premium, Golden, and four tool types.

Latest relevant commits on `feature/chapter1-spec-implementation`:
- `9119892` ??`docs: add security and anti-cheat specification`
- `1a8d4b5` ??`feat: complete personal and shop batch updates`
- `391694c` ??`feat: secure player profile indexes`
- `cddcb19` ??`feat: enforce unique player profiles`
- `da16705` ??`docs: change golden membership price to USD 5.99`

## Completed

### Personal Information
- Personal Page established.
- Player Info section established.
- Evolution Progress section established.
- Creature Collection section established as the permanent collection entry.
- Gold section established.
- Settings / Game Guide / Version Info / Log Out entries established.
- Shop is kept separate from Personal Page.
- Player profile uniqueness is enforced.
- Secure player profile indexes are implemented.

### Shop / Marketplace
- Shop Page established.
- Life is not sold separately.
- Tool purchases are established.
- Owned tool quantities are displayed in Shop.
- Gold balance is used for purchases.
- Gold Page includes a direct Go to Shop entry.
- Remote Shop Config is established at `shop_config/global`.
- Purchase intent and transaction-lock architecture is established.
- Real store payment verification and authoritative resource granting remain pending.
- Golden membership price is USD 5.99/month.

### Creature Collection - Data Layer
- Added `lib/services/creature_collection_service.dart`.
- Creature collection is associated with the Firebase account UID.
- Collection data is stored separately for each account.
- Collection records are additive only.
- Previously discovered creatures are not removed when replaying, losing, restarting, or replaying a chapter.
- Switching Firebase accounts naturally switches to that account's collection data.
- Firestore `arrayUnion` is used so existing discoveries remain permanent.

### Security / Anti-Cheat
- `docs/SECURITY_ANTI_CHEAT.md` established as the security specification.
- Server-authoritative direction defined for Gold, Membership, Tools, Lives, Purchases, and Chapter Progress.
- Cheat Audit severity and risk-score model defined.
- Admin alert and accountability requirements defined.
- Purchase intent and transaction uniqueness protections implemented.

## Current Collection Architecture

Firebase:

users/{uid}/progress/collection

Each chapter stores discovered creature values.

The collection is intended to represent permanent achievement history, not the current mutable game board/save state.

## Next Task

Continue launch security hardening:
1. Make Gold server-authoritative.
2. Make Membership server-authoritative.
3. Make Tool inventory and Gold deduction server-authoritative.
4. Make Golden Infinite Lives depend on server membership.
5. Tighten `users/{uid}` Firestore update permissions.
6. Isolate production-reachable developer unlimited/reset capabilities.
7. Implement Cheat Audit logging and admin alerts.

After each meaningful implementation step, update this document with the actual committed state and next task.

## Important Rules

- Do not restore or use the old 18-tier system.
- Six current chapters remain authoritative.
- Collection is permanent achievement history.
- Game save state and Collection history are separate concepts.
- Collection changes only for the currently authenticated Firebase account.
- Do not show Gold, Lives, tool quantities, Email, or sign-in method in Player Info.
- Shop remains a separate page.
- Life is not a separate purchasable product.
- Do not modify avatar cropping during this phase.

## Git / Development

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
