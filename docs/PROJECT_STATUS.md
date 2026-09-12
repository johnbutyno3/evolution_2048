# Rebirth 2048 - Project Status

## Current Phase
Personal Information + Shop / Marketplace

## Completed

### Personal Information
- Personal Page established.
- Player Info section established.
- Evolution Progress section established.
- Creature Collection section established as the permanent collection entry.
- Gold section established.
- Settings / Game Guide / Version Info / Log Out entries established.
- Shop is kept separate from Personal Page.

### Shop / Marketplace
- Shop Page established.
- Life purchases implemented.
- Tool purchases implemented.
- Owned tool quantities are displayed in Shop.
- Gold balance is used for purchases.
- Gold Page includes a direct Go to Shop entry.
- Current shop prices remain provisional and are not treated as final economy values.

### Creature Collection - Data Layer
- Added `lib/services/creature_collection_service.dart`.
- Creature collection is associated with the Firebase account UID.
- Collection data is stored separately for each account.
- Collection records are additive only.
- Previously discovered creatures are not removed when replaying, losing, restarting, or replaying a chapter.
- Switching Firebase accounts naturally switches to that account's collection data.
- Firestore `arrayUnion` is used so existing discoveries remain permanent.

## Current Collection Architecture

Firebase:

users/{uid}/progress/collection

Each chapter stores discovered creature values.

The collection is intended to represent permanent achievement history, not the current mutable game board/save state.

## Next Task

Connect the Creature Collection data layer to the actual game achievement/evolution event.

When a creature/stage is actually reached during gameplay:
1. Record it in the current Firebase account's collection.
2. Never remove previously discovered creatures.
3. Keep discoveries across replay and game-over.
4. Make Collection Page display the permanent six-chapter collection.
5. Do not create a second competing progress system.

## Important Rules

- Do not restore or use the old 18-tier system.
- Six current chapters remain authoritative.
- Collection is permanent achievement history.
- Game save state and Collection history are separate concepts.
- Collection changes only for the currently authenticated Firebase account.
- Do not show Gold, Lives, tool quantities, Email, or sign-in method in Player Info.
- Shop remains a separate page.
- Do not modify avatar cropping during this phase.

## Git / Development

Branch:
`feature/chapter1-spec-implementation`

Before committing:
- `flutter analyze` must pass.
- Do not force push.
- Keep unrelated existing changes intact.
