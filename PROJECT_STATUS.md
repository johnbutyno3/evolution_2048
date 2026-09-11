# Rebirth 2048
# PROJECT STATUS
# Last updated: 2026-09-11

## 1. Current Project State

Rebirth 2048 is a 4×4 evolution/ecosystem revival game built with Flutter.

Core identity:
- Player is a creator/revival AI restoring a dead planet.
- Creature images are the main tile visuals; numeric values are internal game values.
- Core movement and merging remain 2048-style.
- Backgrounds and music change by chapter/evolution stage.
- Mobile uses swipe controls.
- Chrome is the current practical desktop test target.
- Local save/restore is implemented.
- Firebase project/auth integration is in progress.
- Internationalization structure exists; English is the current UI language target. Do not add extra languages until the game is stable.

Current branch:
- feature/chapter1-spec-implementation

Latest verified commit:
- 87cc97d — fix: add chapter completion next and home actions

Latest analyzer result:
- flutter analyze → No issues found!

---

## 2. Authoritative Chapter Rules

The current design is the six-chapter structure below. Do NOT restore the old 18-tier Chapter 1 design.

| Chapter | Theme | Stages | Tools usable in chapter | Result |
|---|---|---:|---|---|
| 1 | Ocean | 12 | None | Unlock Chapter 2 |
| 2 | Land | 13 | 1 tool type | Unlock Chapter 3 |
| 3 | Sky | 14 | 2 tool types | Unlock Chapter 4 |
| 4 | History | 15 | 3 tool types | Unlock Chapter 5 |
| 5 | Technology | 16 | 4 tool types | Unlock Chapter 6 |
| 6 | Space / Universe | 17 | Tools disabled | Ultimate challenge |

Current tool identifiers used internally:
- revive → REMOVE
- timeRewind → UNDO
- positionSwap → SWAP
- duplicate → DUPLICATE

User-facing tool names:
- UNDO
- REMOVE
- SWAP
- DUPLICATE

Chapter 6 is the final challenge and does not allow normal tool usage.

---

## 3. Creature / Asset Progress

### Chapter 1 — Ocean

The current Ocean progression is 12 stages, ending at the 2048 target stage for chapter completion, with the future seabed-human visual retained as the chapter-ending/future concept asset.

Assets are under:
- assets/creatures/chapter_01_ocean/
- assets/backgrounds/chapter_01_ocean/

### Chapter 2 — Land

Land chapter assets and progression are implemented as part of the current six-chapter structure.

### Chapter 3 — Sky

Sky backgrounds are implemented with the intended altitude progression:
1. low altitude
2. mid altitude
3. high altitude
4. space

Chapter-complete background is separate and uses the completion-screen format.

### Chapter 4 — History

History creature assets are present under:
- assets/creatures/chapter_04_history/

History progression currently contains the 15-stage sequence through Internet.

History backgrounds are present under:
- assets/backgrounds/chapter_04_history/

including the chapter completion background.

### Chapter 5 — Technology

Technology creature/background asset paths are already integrated into the project structure and are the next major chapter implementation area.

### Chapter 6 — Space / Universe

Chapter 6 is the final/ultimate challenge chapter. Chapter music/background resources exist and tools are disabled by rule.

---

## 4. Audio

All six chapter background music tracks are now available.

Audio architecture includes:
- chapter BGM
- UI SFX
- gameplay SFX
- tool-selection SFX
- game-over/chapter-unlock system sounds

Current decision:
- Tool vibration is CANCELLED as a requirement.
- Do not reintroduce vibration.
- Keep pressed-image/tool feedback instead.

---

## 5. Life System — Confirmed Rules

Persistent life pool:
- Maximum normal life count: 5.
- Starting a genuinely NEW board consumes 1 life.
- Returning to the same active saved board does NOT consume another life.
- Leaving Home, app pause, or UI rebuild does NOT consume another life.

Chapter completion:
- Completing a chapter is NOT death.
- The life consumed when starting that chapter's board is refunded when the chapter is completed.
- Life remains capped at 5.

After chapter completion, the completion screen has exactly two actions:
1. Next Chapter
2. Home

Next Chapter:
- Starts a genuinely NEW board in the next chapter.
- Uses the normal new-board rule.
- Therefore it consumes 1 life.
- There is NO special no-deduction exception.

Home:
- Returns to Home.
- Does not consume another life.

Re-entering a completed chapter:
- A completed chapter has no active board to resume.
- Re-entering it later creates a genuinely NEW board and consumes 1 life.

Game Over:
- Game Over is actual death.
- Game Over does NOT refund life.
- Restart creates a genuinely NEW board and therefore consumes another life.

Saved terminal states:
- Saved Game Over board is not restored as an active board.
- Saved Chapter Complete board is not restored as an active board.
- Re-entry from either terminal state creates a new board under the normal life rule.

Implementation status:
- Life deduction for genuinely new boards is implemented.
- Active-board restoration without extra deduction is implemented.
- Chapter-completion life refund is implemented.
- Forced new-board flow for Next Chapter is implemented.
- Terminal saved-board reset behavior is implemented.

---

## 6. Chapter Completion Screen — Current State

The chapter completion screen has been corrected.

Current behavior:
- Shows chapter-specific completion background.
- Shows chapter title/subtitle.
- Shows SCORE / BEST / HIGHEST values without the previous malformed text/garbled separator.
- Provides exactly two actions:
  - Next Chapter
  - Home
- Next Chapter returns a `next` result to the game page.
- Home returns a `home` result to the game page.
- Next Chapter uses `forceNewBoard: true` for the next chapter so the next board is genuinely new and life deduction is applied normally.

Latest commit implementing this UI:
- 87cc97d — fix: add chapter completion next and home actions

---

## 7. Save / Restore

Local save is implemented.

Saved game state includes the active game information needed to resume, including:
- chapter
- board tile values
- score
- best score
- tool state/penalties
- milestone flags
- highest evolution value
- gameOver
- chapterComplete
- life-related state

Important behavior:
- Active saved board resumes without consuming another life.
- Terminal saved states are treated as ended boards and do not resume as active boards.

Save key:
- rebirth_2048_local_save_v1

---

## 8. Input / Controls

Implemented/current:
- Keyboard arrow keys for Chrome/desktop testing.
- Touch swipe for mobile.
- Keyboard input is blocked while Game Over, Chapter Complete, completion animation, or tool-selection mode is active.

Recent keyboard handling fix is complete.

---

## 9. Tool UI / Tool Architecture

The project has the four tool assets and the four-tool UI architecture:

assets/tools/
- tool_undo.png
- tool_undo_pressed.png
- tool_swap.png
- tool_swap_pressed.png
- tool_remove.png
- tool_remove_pressed.png
- tool_duplicate.png
- tool_duplicate_pressed.png

UI rules currently retained:
- Four tools use one horizontal row where the tool UI is shown.
- Locked tools are visually locked and cannot be used.
- Pressed state uses the corresponding *_pressed.png asset.
- Selecting a tool does not remove it from the row.
- Selected tool becomes semi-transparent.
- Selected tool shows CANCEL.
- Tapping the selected tool again cancels the mode.
- No separate Cancel button.

Important:
- The chapter rule decides which tools are usable.
- Do not confuse tool inventory persistence with chapter usability.

---

## 10. Firebase / Auth / Onboarding

Firebase project:
- rebirth-2048

FlutterFire configuration has been generated for:
- Android
- iOS
- macOS
- Web
- Windows

Required authentication options:
- Email/password
- Phone number + SMS code
- Google
- Apple
- Skip for testing

Current product flow:
1. Onboarding
2. Login/register/profile flow
3. Directly enter the game

Do NOT reintroduce an unnecessary demo/home screen between onboarding/auth and the game.

Localization:
- app_en.arb
- app_zh.arb
- Keep English as the current implementation target.
- Do not add extra languages or modify Chinese localization while the core game is still being stabilized.

---

## 11. Current Important Source Files

Main game:
- lib/main.dart
- lib/game/models/creature.dart
- lib/game/models/game_board.dart
- lib/game/models/game_tile.dart
- lib/game/models/tools/game_tool.dart
- lib/game/services/game_engine.dart
- lib/game/services/tool_manager.dart
- lib/game/services/save_manager.dart
- lib/game/services/life_manager.dart
- lib/game/services/audio_manager.dart
- lib/game/screens/evolution_2048_page.dart
- lib/game/screens/evolution_2048_chapters_page.dart

Documentation:
- PROJECT_STATUS.md
- docs/GAME_RULES.md
- docs/GAME_SPEC_V1.md
- MEMBERSHIP_AND_LIFE_RULES.md
- SAVE_SYSTEM_SPEC.md
- AUDIO_RULES.md
- CREATURE_PROGRESSION_SPEC.md
- GAME_CONTENT.md
- GAME_SCORING_AND_FEEDBACK.md
- MENU_RULES.md

---

## 12. Current Development State

### Completed / implemented

- [x] Six-chapter project structure
- [x] Chapter progression architecture
- [x] Creature-based 4×4 board
- [x] Chapter backgrounds
- [x] Six chapter BGM resources
- [x] Local save/restore
- [x] Active-board life preservation
- [x] Chapter completion life refund
- [x] Terminal saved-board reset handling
- [x] Next Chapter starts a new board and deducts life normally
- [x] Chapter completion screen has Next Chapter + Home only
- [x] Completion score display cleaned up
- [x] Keyboard arrow control
- [x] Mobile swipe control
- [x] Tool pressed-image feedback
- [x] Tool selection/CANCEL behavior
- [x] REMOVE final-tile safety behavior
- [x] Firebase project configuration
- [x] Onboarding/auth/profile structure
- [x] Flutter analyze currently clean

### Not yet considered finished

- [ ] Full end-to-end play test of life rules
- [ ] Full end-to-end test of all chapter transitions
- [ ] Full verification of chapter-specific tool usability/locking against the latest six-chapter rules
- [ ] Full verification of Chapter 5 Technology
- [ ] Full verification of Chapter 6 Space/Universe
- [ ] Final visual polish of all chapters
- [ ] Final auth flow verification for all four sign-in methods + Skip
- [ ] Final release validation

---

## 13. Immediate Next Work

Do not start another large feature yet.

First:
1. Run the game in Chrome.
2. Verify the chapter-complete screen visually.
3. Verify life refund on chapter completion.
4. Verify Home does not deduct life.
5. Verify Next Chapter creates a new board and deducts 1 life.
6. Verify active-board re-entry does not deduct life.
7. Verify Game Over/restart deducts life correctly.

After that:
8. Continue Chapter 5 / Chapter 6 implementation and verification.
9. Reconcile any remaining old documentation with the current authoritative rules.
10. Run flutter analyze and git diff --check before the next code commit.

---

## 14. Do Not Regress

Do NOT:
- restore the old 18-tier Chapter 1 design
- reintroduce old chapter/tool distributions
- make chapter completion consume a permanent life
- make Next Chapter free of life cost
- deduct life when merely reopening an active saved board
- refund life after Game Over
- restore a terminal saved board as an active board
- add a third button to the chapter completion screen
- reintroduce a Continue-only completion flow
- reintroduce tool vibration
- rename REMOVE back to REVIVE in the UI
- rename UNDO back to REWIND in the UI
- add a separate Cancel button for tools
- remove the selected tool from the tool row
- break local save/restore
- allow REMOVE to leave the board permanently empty
- modify extra localization files before the core game is stable

This file is the current continuity reference for future Rebirth 2048 development sessions.
