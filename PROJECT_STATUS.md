# Rebirth 2048
# PROJECT STATUS
# Last updated: 2026-09-14

> **CANONICAL RECOVERY CHECKPOINT:** Read this root `PROJECT_STATUS.md` first when continuing after a conversation interruption. Detailed historical status is in `docs/PROJECT_STATUS.md` and security details are in `docs/GAME_SESSION_SECURITY.md` / `docs/SECURITY_ANTI_CHEAT.md`.

## 1. Current Project State

Rebirth 2048 is a 4×4 creature evolution / ecosystem revival game built with Flutter.

Core identity:
- Player is a revival AI restoring a dead planet.
- Creature images are the main tile visuals; numeric values are internal game values.
- Core movement and merging remain 2048-style.
- Six chapters are authoritative.
- Local save is for recovery only; server state is authoritative for protected progression/resources.
- Chrome is the current practical desktop test target.

Current branch:
- `feature/chapter1-spec-implementation`

Current phase:
- Launch Security / Anti-Cheat hardening, following the Personal Information + Shop phase.

## 2. Authoritative Chapter Rules

Do NOT restore the old 18-stage system.

| Chapter | Theme | Stages | Tools |
|---|---|---:|---|
| 1 | Ocean | 12 | 0 |
| 2 | Land | 13 | 1 |
| 3 | Sky | 14 | 2 |
| 4 | History | 15 | 3 |
| 5 | Technology | 16 | 4 |
| 6 | Space / Universe | 17 | disabled |

Chapter 6 is the final chapter.

Current internal tool identifiers:
- `revive`
- `timeRewind`
- `positionSwap`
- `duplicate`

Current user-facing tool names:
- REMOVE
- UNDO
- SWAP
- DUPLICATE

## 3. Personal Information / Shop

Foundation completed:
- Personal Information and Shop are separate.
- Avatar is the direct Player Info entry point; no standalone Player Info menu is required.
- Current avatar system uses 54 independent avatar files. Do not restore the old avatar-sheet system.
- Player name/profile uniqueness and Firebase account association are implemented.
- Creature Collection is account-specific, additive, permanent achievement history.
- Settings supports English / Traditional Chinese.
- GAME DATA removal is permanent.
- Gold is visible in Personal Information; Shop remains the purchase entry.
- Life is NOT a separate shop product.
- Golden Membership is USD 5.99/month.

Paid categories:
- Gold
- Premium
- Golden
- four tool types

## 4. Server Authority

Server-authoritative foundation is implemented for:
- Gold
- Membership
- Tool inventory / spending
- Golden infinite lives
- Purchases
- Chapter progression

Relevant callable functions include:
- `getGoldBalance`
- `spendGold`
- `getMembershipStatus`
- `grantMembership` (Admin-only)
- `getToolInventory`
- `purchaseTool`
- `useTool`
- `createPurchaseIntent`
- `submitPurchaseForVerification`
- `startGameSession`
- `completeChapter`

Firestore production client writes are locked down for sensitive wallet, membership, game-session, and security-event data.

Real Google/Apple payment verification remains intentionally paused unless explicitly requested.

## 5. Game Session Security

Implemented:
- Authenticated server-created session IDs.
- Chapter validation and server target validation.
- Session ownership and one-time completion checks.
- Session expiry.
- Suspicious completion/security-event logging.
- `users/{uid}/game_sessions/{sessionId}` is client-inaccessible.
- `security_events` is server-write/admin-read only.

Important current limitation:
- The existing `completeChapter` implementation still accepts client-reported `highestValue` and `score` after session validation.
- A session ID alone cannot prove genuine 2048 gameplay.
- This is NOT considered final anti-cheat protection.

Final design decision:
- Local Replay/Event Log + server-side deterministic replay.
- Do NOT send every move to Firebase.
- Gameplay stays local; only the session start and final replay submission need Firebase traffic.

## 6. Replay / Anti-Cheat Progress

### Completed

`lib/game/models/replay_event.dart`
- Version-independent event model currently supports:
  - move
  - revive
  - positionSwap
  - duplicate
  - timeRewind

`lib/game/services/replay_log.dart`
- Versioned local replay container.
- Stores chapter, initial 4×4 tile state, and ordered events.
- Validates basic shape/value structure when restoring.
- Explicitly untrusted; server must validate it.

`lib/game/services/replay_recorder.dart`
- Records the exact random spawn position/value supplied by the game engine.
- Previous unsafe idea of inferring random spawns from before/after board differences was removed.

Relevant commits:
- `b930228a4bad928d6f574e455df59c9b85a688c8` — add replay event model
- `294f0a0a4afc0582f10be8fb3578ade9b9c40a0b` — add local replay log container
- `fe66cda93f789be57c0cb5fc92f7e6cd8f1878ab` — record explicit replay spawn events

### NOT completed

- [ ] Connect `GameEngine` to `ReplayRecorder`.
- [ ] Record every successful normal move from `GameEngine`.
- [ ] Record exact spawn index/value for each move.
- [ ] Record successful tool operations.
- [ ] Define and implement exact time-rewind replay semantics.
- [ ] Make replay log survive active-board save/restore correctly end-to-end.
- [ ] Implement server-side replay verifier.
- [ ] Remove trust in client-submitted final score/highest value.
- [ ] Deploy/test the final authoritative completion path.

## 7. Immediate Next Task — GameEngine Integration

The next coding step is ONLY the ReplayRecorder integration into:

`lib/game/services/game_engine.dart`

Required behavior:
1. Initialize a recorder for the current chapter.
2. Start a fresh replay when a genuinely new board is created.
3. Restore the replay log together with a resumed active board.
4. Record each successful move with its direction and exact random spawn.
5. Record successful REMOVE / UNDO / SWAP / DUPLICATE operations.
6. Preserve replay data in local save for interruption recovery.
7. Do not introduce per-move Firebase writes.

Important implementation caution:
- `game_engine.dart` is a large source file.
- Never replace it with truncated content.
- Obtain the complete current file before a GitHub full-file replacement.
- Never claim the integration is complete until the actual commit exists and local `flutter analyze` passes.

## 8. Planned Server Replay Verification

After GameEngine integration, the server must replay the submitted event stream and independently calculate:
- initial board validity;
- move legality/order;
- spawn position/value;
- merge results and score;
- chapter target;
- tool ownership and use count;
- tool score penalties;
- time-rewind semantics;
- final score;
- final highest value;
- session ownership/expiry/one-time completion.

The server, not the client, decides whether chapter completion is valid.

## 9. Life Rules — Do Not Regress

- Normal maximum lives: 5.
- Genuinely new board: consume 1 life.
- Resume the same active saved board: consume 0 additional lives.
- Leaving Home / app pause / UI rebuild: consume 0 additional lives.
- Game Over: actual death; no refund.
- Restart: new board and normal life deduction.
- Chapter completion: not death; refund the life consumed by that board.
- Next Chapter: genuinely new board and normal life deduction.
- Re-entering a completed/terminal chapter: new board and normal life deduction.
- Golden Membership can provide infinite lives based on server membership state.

## 10. Collection Rules

Collection is permanent achievement history, separate from mutable board save.

Firebase path:
- `users/{uid}/progress/collection`

Rules:
- discoveries are additive;
- losing/restarting does not remove discoveries;
- switching Firebase accounts switches collection data;
- no second competing progress system;
- actual gameplay evolution events must eventually feed the collection data layer.

## 11. Cross-Device / Release Hardening — Later

After replay anti-cheat is complete:
1. Safe Area / notch / Dynamic Island audit.
2. Responsive layout and small/large screen audit.
3. Timer / AnimationController / listener / lifecycle cleanup audit.
4. Image/resource performance and compression audit.
5. Android/iOS minimum OS confirmation.
6. Firebase Test Lab.
7. Google Play Pre-launch testing.
8. Real-device stress testing.

Object pooling is not a priority because the game is only a 4×4 board with at most 16 tiles.

## 12. Development Rules

- Prefer direct PowerShell commands for local verification.
- Prefer GitHub inspection/updates when safe.
- Do not use stale old project data or the old 18-tier creature system.
- Do not overwrite large files with truncated content.
- Do not mark a feature complete before it is actually committed and verified.
- Keep unrelated changes intact.
- Never force-push.
- Before committing Flutter code, run `flutter analyze` and require `No issues found!`.

## 13. Recovery Procedure

If a conversation is interrupted or context appears missing:

1. Read **root `PROJECT_STATUS.md` first**.
2. Confirm branch `feature/chapter1-spec-implementation`.
3. Inspect the latest relevant commits.
4. Read `docs/GAME_SESSION_SECURITY.md` for session/replay security details.
5. Read `docs/SECURITY_ANTI_CHEAT.md` for the broader security model.
6. Only then inspect source files.
7. Treat this root file as the short current checkpoint; `docs/PROJECT_STATUS.md` is historical/detail context.

This root file intentionally exists so the project can be recovered quickly even when the longer documentation is difficult to locate.
