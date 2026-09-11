# Rebirth 2048 — Security / Data Authority Architecture

## Core rule

SharedPreferences is allowed for local/offline gameplay state, but it is never an authority for account value, paid value, or chapter unlock permission.

> Local data may be modified by the player. A local modification must not create server-recognized value.

## Local authority

SharedPreferences (`rebirth_2048_local_save_v1`) stores:
- active 4×4 board
- current score / best score
- temporary gameplay state
- active-board resume state
- game-over / chapter-complete terminal state
- local UI/onboarding/profile cache

The local board is intentionally kept offline-capable.

## Server authority

Firebase/Cloud Functions will be authoritative for:
- chapter unlock state
- chapter completion records
- coins / premium currency
- tool inventory
- VIP / premium entitlement
- purchase records
- paid rewards
- future leaderboard values

Clients must not directly write authoritative progress/economy documents.

## Current implementation foundation

Implemented in this phase:
- `lib/services/player_progress_service.dart`
- `functions/index.js`
- `functions/package.json`
- `firestore.rules`
- Firebase Functions + Firestore configuration in `firebase.json`
- `cloud_functions` Flutter dependency
- Home chapter cards now use server-authoritative unlock state.
- Local developer chapter-unlock controls were removed from the normal Home flow.

Firestore rule:
- authenticated users may read their own progress
- clients cannot write progress documents
- Cloud Functions perform authoritative writes

## Current callable operation

`completeChapter`

The server currently:
1. requires Firebase Authentication
2. accepts a chapter completion request
3. checks the requested chapter is already the player's currently unlocked chapter
4. checks the reported highest value reaches the configured chapter target
5. advances the unlock index by one chapter at most
6. writes the completion record transactionally

This is the first security layer, not the final anti-cheat layer.

## Final anti-cheat layer still required

Before launch, chapter completion must be based on a server-created game session rather than trusting a client-reported `highestValue` / `score`.

Planned flow:

```text
Server creates gameSessionId + seed
        ↓
Client plays locally
        ↓
Client records move/tool events
        ↓
Completion submits sessionId + result/replay data
        ↓
Server validates session ownership, sequence and plausibility
        ↓
Server marks chapter complete / unlocks next chapter
        ↓
Server grants rewards
```

For stronger protection, the final implementation should replay a deterministic game session on the server before granting valuable rewards.

Firebase App Check should also be enabled before public release to protect callable endpoints from unauthorized clients.

## Cost principle

Do not write every 2048 move to Firestore.

The intended cost-efficient design is:
- board and normal moves → local
- important account/progression events → Firebase
- economy / purchases / entitlements → Firebase
- rewards → server transaction

This keeps the Firebase workload small even at large user counts.
