# Evolution 2048 / rebirth_2048
# PROJECT STATUS
# Last updated: 2026-09-07

## 1. Project

Evolution 2048 is a 2048-based evolution game.

Core concept:
- 4x4 board
- Merge identical life stages to evolve
- Creature images instead of traditional numeric tiles
- Six chapters
- Mobile swipe gameplay
- Chapter progression and persistent local save
- Chapter-specific tools
- Chapter complete screen/background
- Internationalization readiness

---

## 2. Chapter Progression

| Chapter | Name | Tiers | Unlock / Target | Tools |
|---|---|---:|---:|---|
| 1 | Ocean | 12 | 2048 | UNDO |
| 2 | Land | 13 | 4096 | UNDO + SWAP |
| 3 | Sky | 14 | 8192 | UNDO + SWAP + REMOVE |
| 4 | History | 15 | 16384 | UNDO + SWAP + REMOVE + DUPLICATE |
| 5 | Technology | 16 | 32768 | UNDO + SWAP + REMOVE + DUPLICATE |
| 6 | Universe | 17 | Ultimate | UNDO |

Important:
- Do NOT change the above tool distribution.
- Chapter 6 is an ultimate challenge.
- Tools are disabled in challenge mode where specified by game rules.
- Internal identifiers may still use old names:
  - timeRewind = UNDO
  - revive = REMOVE
  - positionSwap = SWAP
  - duplicate = DUPLICATE
- User-facing names must use:
  - UNDO
  - REMOVE
  - SWAP
  - DUPLICATE

---

## 3. Chapter 1 Ocean Creature Sequence

1. 矽藻 - 2
2. 鞭毛蟲 - 4
3. 磷蝦 - 8
4. 小丑魚 - 16
5. 水母 - 32
6. 魷魚 - 64
7. 海龜 - 128
8. 黃鰭鮪魚 - 256
9. 鯊魚 - 512
10. 虎鯨 - 1024
11. 藍鯨 - 2048
12. 海底人類 - 4096

Do NOT revert to the older 18-tier Chapter 1 design.

---

## 4. Current Tool UI

Current required layout:

- Four tools in ONE horizontal row.
- Do NOT use 2x2 layout.
- Tool image is the main visual.
- Small label below the image.
- Locked tools are semi-transparent.
- Lock icon appears ON TOP OF the tool image.
- Locked tools cannot be used.
- Selecting a tool does NOT remove the tool from the row.
- Selected tool becomes semi-transparent.
- Selected tool displays international-language label:
  CANCEL
- Tapping the selected tool again cancels the tool mode.
- Do NOT add a separate Cancel button.
- Tool press image must switch to the corresponding pressed asset.

Tool assets:

assets/tools/
- tool_undo.png
- tool_undo_pressed.png
- tool_swap.png
- tool_swap_pressed.png
- tool_remove.png
- tool_remove_pressed.png
- tool_duplicate.png
- tool_duplicate_pressed.png

Old assets:
- tool_revive.png = deleted
- tool_rewind.png = deleted

---

## 5. Vibration Decision

IMPORTANT:
Tool vibration has been tested on the Android APK.

Result:
- No vibration was observed.
- Android VIBRATE permission was checked.
- User decided to CANCEL the vibration requirement.

Final decision:
- DO NOT continue implementing tool vibration.
- DO NOT replace it with native Android vibration.
- DO NOT modify unrelated vibration behavior elsewhere.
- Keep current pressed-image behavior only.

---

## 6. REMOVE Safety Fix

Problem found:
If REMOVE deletes the last remaining tile, the board becomes completely empty and the game can no longer continue.

Required behavior:
- When REMOVE deletes the final tile on the board:
  - immediately spawn one new tile
  - game remains playable
  - save the new board state

Current local change:
GameEngine.useRevive() has been modified to check:

    if (_board.tiles.every((tile) => tile == null)) {
      _spawnTile();
    }

This is the implementation of the user-facing REMOVE tool.

---

## 7. Pressed Tool Image

Required behavior:

Press tool:
- use *_pressed.png

Release tool:
- return to normal tool image

Mapping:
- UNDO -> tool_undo_pressed.png
- SWAP -> tool_swap_pressed.png
- REMOVE -> tool_remove_pressed.png
- DUPLICATE -> tool_duplicate_pressed.png

This has been added to the current tool UI implementation.

---

## 8. Save / Restore

Game state is locally saved.

Saved information includes:
- chapter
- board tile values
- score
- best score
- tool penalty
- milestone flags
- highest evolution value
- gameOver
- chapterComplete

Important behavior:
- Reopening the app restores the saved board/game state.
- Game Over state is restored.
- Game Over screen can be shown again after reopening.
- Restart remains available from Game Over.

---

## 9. Current Important Source Files

Main game files:

lib/main.dart
lib/game/models/creature.dart
lib/game/models/game_board.dart
lib/game/models/game_tile.dart
lib/game/models/tools/game_tool.dart
lib/game/services/game_engine.dart
lib/game/services/tool_manager.dart
lib/game/services/save_manager.dart
lib/game/screens/evolution_2048_page.dart
lib/game/screens/evolution_2048_chapters_page.dart

Assets:

assets/creatures/
assets/backgrounds/
assets/tools/

---

## 10. Current Development State

Recently completed / verified:

- Six-chapter structure implemented.
- Chapter progression implemented.
- Chapter-specific tool distribution implemented.
- Tool UI changed to four horizontal buttons.
- Lock overlay implemented.
- Tool selected state implemented.
- CANCEL behavior implemented.
- Pressed tool image behavior implemented.
- Game Over restore behavior implemented.
- Local save/restore implemented.
- REMOVE final-tile safety behavior added.
- Flutter analyzer previously verified with:
  No issues found!
- git diff --check previously verified successfully.
- Android APK was generated and tested.
- Tool vibration was tested and then explicitly cancelled as a requirement.

---

## 11. Current Testing Checklist

Before committing the latest local changes:

[ ] Four tools display in one horizontal row
[ ] Locked tools show lock over image
[ ] Locked tools cannot be tapped
[ ] Pressing a tool displays *_pressed.png
[ ] Releasing restores normal image
[ ] Selecting a tool keeps the tool visible
[ ] Selected tool becomes semi-transparent
[ ] Selected tool displays CANCEL
[ ] Tapping selected tool cancels the mode
[ ] REMOVE can delete a tile
[ ] REMOVE deleting the final tile creates a new tile
[ ] Game Over survives app restart
[ ] Restart remains available
[ ] No tool vibration requirement
[ ] Flutter analyze = No issues found!
[ ] git diff --check = clean

---

## 12. Current Known Local Changes

Expected current work includes:

M lib/game/screens/evolution_2048_page.dart
M lib/game/services/game_engine.dart

Do NOT commit .bak files.

Temporary .bak files must be deleted before commit.

---

## 13. Next Work

Priority order:

1. Complete Android APK test of the current tool UI.
2. Verify REMOVE final-tile recovery.
3. Verify Game Over restore/restart.
4. Verify all six chapter transitions.
5. Verify chapter-specific tools.
6. Verify assets and backgrounds for all chapters.
7. Verify chapter complete screens.
8. Run flutter analyze.
9. Run git diff --check.
10. Commit and push the verified state.
11. Continue remaining Chapter 5 / Chapter 6 implementation and polish.

---

## 14. Do Not Regress

Do NOT:
- restore the old 18-tier Chapter 1 list
- rename REMOVE back to REVIVE in the UI
- rename UNDO back to REWIND in the UI
- change the confirmed tool distribution
- change the tool row back to 2x2
- add a separate Cancel button
- remove the selected tool from the row
- add vibration again
- replace pressed images with text-only pressed states
- break local save/restore
- allow REMOVE to leave the board permanently empty

This file is the continuity reference for future development sessions.
