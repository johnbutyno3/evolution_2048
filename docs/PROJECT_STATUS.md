# Rebirth 2048 - Project Status

## Current Phase
Personal Information + Shop / Marketplace → Launch Security / Anti-Cheat

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
- `9119892` — `docs: add security and anti-cheat specification`
- `1a8d4b5` — `feat: complete personal and shop batch updates`
- `391694c` — `feat: secure player profile indexes`
- `cddcb19` — `feat: enforce unique player profiles`
- `da16705` — `docs: change golden membership price to USD 5.99`

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
