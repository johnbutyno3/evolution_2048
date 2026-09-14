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
