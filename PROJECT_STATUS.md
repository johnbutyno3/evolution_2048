# Evolution 2048 / rebirth_2048
# PROJECT STATUS
# Last updated: 2026-09-08

## 1. Current project baseline

- 4x4 Evolution 2048 board.
- Creature/life-stage images instead of numeric tile display.
- Six chapters: Ocean, Land, Sky, History, Technology, Universe.
- Mobile swipe gameplay.
- Local save/restore exists.
- Chapter-specific tool configuration already exists and must be preserved.
- Internationalization architecture exists.
- Audio assets for chapter/gameplay/system/tool/UI flows are present in the repository.

## 2. Confirmed chapter rules

| Chapter | Name | Tiers | Current target | Existing tool configuration |
|---|---|---:|---:|---|
| 1 | Ocean | 12 | 4096 | UNDO |
| 2 | Land | 13 | 8192 | UNDO + SWAP |
| 3 | Sky | 14 | 16384 | UNDO + SWAP + REMOVE |
| 4 | History | 15 | 32768 | UNDO + SWAP + REMOVE + DUPLICATE |
| 5 | Technology | 16 | 65536 | UNDO + SWAP + REMOVE + DUPLICATE |
| 6 | Universe | 17 | 131072 | UNDO |

Important: the table above records the existing chapter tool configuration found in the current code. Do not redesign it while implementing the new reward system.

Chapter progression is now intended to be simple normal gameplay → chapter complete → next chapter unlock. There is no separate Challenge Mode.

## 3. Chapter 1 Ocean sequence

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

Do not restore the old 18-tier Chapter 1 design.

## 4. Tool naming and UI

User-facing tool names:
- UNDO
- REMOVE
- SWAP
- DUPLICATE

Internal identifiers may remain:
- timeRewind = UNDO
- revive = REMOVE
- positionSwap = SWAP
- duplicate = DUPLICATE

Existing tool UI requirements:
- Four tools in one horizontal row.
- Square normal/pressed image assets.
- Selected tool remains in the row.
- Selected tool uses pressed/selected visual and CANCEL label behavior already implemented.
- No separate Cancel button.
- No vibration requirement; this was tested on Android and cancelled by decision.

Current tool assets include:
- tool_undo.png / tool_undo_pressed.png
- tool_swap.png / tool_swap_pressed.png
- tool_remove.png / tool_remove_pressed.png
- tool_duplicate.png / tool_duplicate_pressed.png

## 5. Tool-use reward system — NEW confirmed rule

When a chapter is successfully completed:

**Only the tools available in the NEXT chapter receive +1 use each.**

Rules:
- Each eligible next-chapter tool gets exactly +1 use.
- Existing unused uses are retained.
- New reward uses accumulate with previous unused uses.
- No other chapter-clear reward is granted.
- No gold reward.
- No life reward.
- No achievement reward.
- No collection reward.
- No 2048/4096 challenge reward.
- Chapter 6 has no next chapter, so it grants no next-chapter tool reward.

The reward must be applied by the actual chapter-complete flow, not by Menu UI.

## 6. 2048 / 4096 Challenge removal — NEW confirmed rule

Remove the old challenge concepts completely from the active game flow:
- 2048-based chapter unlock logic.
- 4096 Challenge.
- Challenge Mode.
- Challenge Mode tool locking.
- Any UI offering a 4096 challenge.
- Any chapter progression branch based on optional challenge mode.

The numeric values still exist as normal tile/evolution values where required by the chapter content; they are not special unlock/challenge triggers.

## 7. Life system — NEW confirmed rule

Normal life:
- Automatic-life storage/refill cap = 5.
- General member and High-level member use the normal life system.
- Every 40 minutes, +1 life while life is below 5.
- At 5 or above, the automatic timer stops.
- After consuming life and dropping below 5, a fresh 40-minute countdown starts.

Purchased life:
- Life +1 costs gold.
- Purchased life can raise the current life count above 5.
- Example: 2 lives + purchase 5 = 7 lives.
- If the count later falls to 4, automatic refill only goes to 5.
- To exceed 5 again, purchase life again.

Gameplay UI:
- Life count must be visible during gameplay.
- Show a regeneration countdown next to the life count.
- Recommended format: `生命 ♥ 5   ⏱ --:--`.
- When life <5, countdown runs from 40:00.
- When life >=5, countdown stops and may show `--:--`.
- Golden member displays `∞` and does not use the countdown.

## 8. Membership — NEW confirmed rule

Exactly three membership states:

### 一般會員
- Free.
- Ads enabled.
- After 30 accumulated minutes of actual gameplay, automatically show one ad.
- Normal life system.
- Automatic +1 life every 40 minutes, refill cap 5.

### 高級會員
- NT$99/month.
- Ad-free.
- Normal life system.
- Automatic +1 life every 40 minutes, refill cap 5.

### 黃金會員
- NT$299/month.
- Ad-free.
- Infinite lives.
- Display `∞`.
- No 40-minute wait.
- No 5-life cap.
- Normal life is not consumed.

Do not use the old names「訂閱會員」or「高級會員」for the NT$299 tier.

## 9. Gold packages — NEW confirmed rule

Real-money gold packages:
- 500 gold / NT$49
- 1,000 gold / NT$89
- 5,000 gold / NT$399
- 10,000 gold / NT$799

Tools and life purchases remain gold-only.

## 10. Gold purchase prices

| Item | 1 | 5 | 10 | 20 | 50 |
|---|---:|---:|---:|---:|---:|
| 生命 +1 | 50 | 225 | 400 | 700 | 1,500 |
| UNDO | 50 | 225 | 400 | 700 | 1,500 |
| REMOVE | 100 | 450 | 800 | 1,400 | 3,000 |
| SWAP | 200 | 900 | 1,600 | 2,800 | 6,000 |
| DUPLICATE | 500 | 2,250 | 4,000 | 7,000 | 15,000 |

Discounts: 1 = full price, 5 = 90%, 10 = 80%, 20 = 70%, 50 = 60%.

## 11. Chapter completion / Menu

- Menu reads the existing chapter completion/unlock state.
- Menu must not create a second unlock state.
- Next chapter unlocks only after previous chapter completion.
- Six chapters only.
- Chapter 6 completion leads to final completion screen with 回到首頁.
- No Chapter 7.

## 12. Personal Profile / Shop

Profile contains:
- 玩家資料
- 進化進度
- 收藏
- 金幣
- 設定

No Achievements feature.

Shop:
- Top: real-money gold packages and memberships.
- Bottom: gold-only life/tools.
- All five gold-purchase items remain listed regardless of current chapter.
- Shop cannot buy chapter unlocks, collection entries, challenge modes, or skip chapter completion.
- When a tool has zero uses, its game UI should route directly to that tool's purchase page.

## 13. Audio implementation status

Repository contains the chapter BGM structure and gameplay/system/tool/UI audio assets.

Confirmed audio behavior already specified:
- Tool click: `tool_select.mp3` only.
- Tool cancel: `button_cancel.mp3`.
- Game Over: stop BGM, play `game_over.mp3`, then existing Game Over UI.
- Chapter Complete: stop BGM, play/wait for `chapter_unlock.mp3`, then existing completion screen.
- General UI actions use `button_click.mp3` where appropriate.

Do not add a drawer/menu-open behavior solely to consume audio assets.

## 14. Current code gap — IMPORTANT

The latest repository inspection shows the newly confirmed rules are **documented but not yet fully implemented in code**.

Confirmed gaps found in current source:
- `GameEngine` still contains legacy milestone flags such as hasReached2048/4096/8192/16384.
- `GameEngine` still persists those legacy milestone flags.
- Current tool manager is constructed with `unlimitedTools = true`, so actual tool uses do not currently behave as accumulating finite uses.
- Existing chapter tool distribution must be preserved while changing the use-count behavior.
- A gameplay life/countdown system was not found in the inspected current game engine/page code.
- Membership, gold packages, and shop purchase behavior are not yet represented as the finalized system in the inspected game-engine code.

These are implementation tasks, not new rules.

## 15. Implementation order

1. Implement persistent life count + 40-minute countdown + Golden member infinity behavior.
2. Add life display/countdown to gameplay UI.
3. Convert tool uses from unlimited debug behavior to persistent finite accumulated uses while preserving existing chapter configuration.
4. Implement chapter-clear next-chapter tool reward: +1 for each tool available in the next chapter.
5. Remove legacy 2048/4096 challenge branches and related UI.
6. Implement finalized membership names/benefits.
7. Implement finalized gold package prices and gold-only life/tool purchases.
8. Verify zero-use tool routing to the corresponding Shop purchase page.
9. Run Flutter analyzer and formatting checks.
10. Build/test Android and web as appropriate.
11. Commit and push only after verification.

## 16. Do Not Regress

Do not:
- restore the old 18-tier Chapter 1 list.
- rename REMOVE to REVIVE in the UI.
- rename UNDO to REWIND in the UI.
- change the existing chapter tool distribution.
- add tool vibration back.
- restore Challenge Mode.
- make 2048 or 4096 a chapter-unlock trigger.
- give extra chapter-clear rewards beyond next-chapter tool +1.
- cap purchased life at 5.
- let automatic refill exceed 5.
- call the NT$99 tier 訂閱會員.
- call the NT$299 tier 高級會員.

This document is the continuity reference for the current implementation phase.
