# Rebirth 2048 — Game Specification v1.0

> This document is the baseline game-design specification. Development must follow this document unless a newer version explicitly replaces it.

## 1. Core Game

- Genre: biological evolution × 2048 puzzle game.
- Board: 4 × 4.
- Core actions: swipe, merge identical life forms, evolve to the next life stage.
- Tiles represent stages of life evolution rather than ordinary numeric tiles.
- Each chapter has its own evolution chain.
- The game is not simply about reaching 2048; chapters contain a normal progression and a later ultimate challenge.

## 2. Chapter 1 — Ocean

The official Chapter 1 chain contains exactly 12 stages:

| Tile | Creature | Stage |
|---:|---|---:|
| 2 | 矽藻 | 01 |
| 4 | 鞭毛蟲 | 02 |
| 8 | 磷蝦 | 03 |
| 16 | 小丑魚 | 04 |
| 32 | 水母 | 05 |
| 64 | 魷魚 | 06 |
| 128 | 海龜 | 07 |
| 256 | 黃鰭鮪魚 | 08 |
| 512 | 鯊魚 | 09 |
| 1024 | 虎鯨 | 10 |
| 2048 | 藍鯨 | 11 |
| 4096 | 海底人類 | 12 |

The previous 18-stage data is obsolete and must not be reused.

## 3. Reaching 2048

2048 = 藍鯨.

Reaching 2048 does **not** end the entire game.

When 2048 is achieved:

1. The normal Chapter 1 progression is completed.
2. The next chapter is unlocked.
3. Chapter 1's 4096 Ultimate Challenge is unlocked.

The player can then choose between continuing to a newly unlocked chapter or returning to Chapter 1's 4096 Ultimate Challenge.

## 4. 4096 Ultimate Challenge

4096 = 海底人類.

4096 is Chapter 1's ultimate challenge and final evolution stage.

Rules:

- The challenge continues from the player's 2048 藍鯨 state.
- The player does not restart from 2 for this challenge.
- All tools are disabled during the 4096 challenge.
- Reaching 4096 completes Chapter 1 completely.
- 4096 is not followed by 8192, 16384, or additional Chapter 1 evolution stages.

## 5. Chapter Unlocking

Chapters are unlocked progressively.

For Chapter 1:

`2048 藍鯨` → unlock next chapter + unlock `Chapter 1 / 4096 Ultimate Challenge`.

Locked chapters must not be presented as playable content before they are unlocked.

## 6. Tools / Items

Tools are a supporting system and must not replace the core 2048 skill challenge.

- Earlier chapters may allow tools.
- Tool availability is progressively restricted in later chapters.
- Chapter 7 has no tools.
- The 4096 Ultimate Challenge has no tools.

## 7. Tutorial and Flow

- Tutorial is shown only once.
- After the player completes the tutorial, it disappears automatically.
- Tutorial must not repeatedly interrupt normal gameplay.
- Do not introduce unnecessary repeated Continue/dialogue flows.

## 8. Creature Asset Rules

Creature assets must:

- be real transparent PNG files;
- contain only the creature itself;
- have no background;
- have no scenery or ground;
- have no black/white checkerboard fake transparency;
- have no text;
- have no tile frame.

Animation is handled by Flutter/game-side presentation rather than baked into the source creature image.

## 9. 4096 Creature Asset

The 4096 海底人類 asset represents the final evolution of Chapter 1.

It follows the same transparent-PNG and creature-only rules, while being visually distinct enough to communicate that it is the chapter's ultimate life form.

## 10. Development Order

Development should proceed in this order:

1. Freeze and maintain the specification.
2. Correct the creature data model.
3. Implement and verify the 2048 core logic.
4. Implement chapter progression and unlock rules.
5. Implement the tool system.
6. Add creature assets.
7. Add evolution/transition animations.
8. Add intro and chapter transition sequences.
9. Run full gameplay and platform testing.

Do not change game rules merely to accommodate legacy code or assets.

## 11. Chapter 1 Completion Definition

Chapter 1 has two milestones:

### Normal milestone

`2048 藍鯨`

- Normal Chapter 1 progression complete.
- Next chapter unlocked.
- Chapter 1 4096 Ultimate Challenge unlocked.

### Full completion

`4096 海底人類`

- Ultimate Challenge completed.
- Chapter 1 fully completed.

## 12. Frozen Baseline

The following statements are mandatory baseline rules for v1.0:

- Chapter 1 has 12 evolution stages from 2 through 4096.
- 2048 is 藍鯨 and does not end the entire game.
- 2048 unlocks the next chapter and Chapter 1's 4096 challenge.
- The 4096 challenge continues from the 2048 state.
- Tools are forbidden during the 4096 challenge.
- 4096 is 海底人類 and is the end of Chapter 1's evolution chain.
- The obsolete 18-stage data must not be restored.
- No additional gameplay options or mechanics should be invented without explicitly updating this specification.
