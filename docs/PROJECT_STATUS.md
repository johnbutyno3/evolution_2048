# Rebirth 2048 — Project Status

> 本文件是開發進度紀錄，不取代 `docs/GAME_RULES.md` 的遊戲規則文件。
> 最後更新：2026-09-12

## 1. 目前開發階段

**目前不是重新製作遊戲核心，而是進入「個人資訊 + 商城」階段。**

目前工作順序：

1. Home / Menu
2. Player Info / Personal Info
3. Shop
4. Gold / Lives / Tool Inventory
5. Tool Purchase Flow
6. 完成後再清理舊的 challenge / achievement / 舊商城邏輯

## 2. Git / 專案狀態

- Repository: `johnbutyno3/evolution_2048`
- Branch: `feature/chapter1-spec-implementation`
- 最新已同步修正 commit：`fdaa3b9 fix: restore player info and shop navigation`
- 上一個 avatar sheet commit：`9f1b3c3`
- 目前舊電腦端確認：`git status` clean
- 目前舊電腦端確認：`flutter analyze` → `No issues found!`
- 新筆電路徑：`C:\Users\johny\rebirth_2048`
- 新筆電 Flutter：3.44.6 / Dart 3.12.2
- 新筆電目前應使用既有 branch clone，不要因 Flutter 有新版本就升級專案 Flutter。

## 3. Home / 導航

Home 已保留六章入口。

- 左上 Player Info → `PersonalPage`
- 右上 Shop → `/shop`
- Developer 入口保留
- 六章入口保留

## 4. Personal Info

目前個人資訊方向：

- 玩家名稱
- 玩家頭像
- Gold
- Lives
- 六章進度 / 解鎖狀態
- Creature Collection（之後完整製作）
- Shop 入口

### Avatar

- 使用單一檔案：`assets/avatars/avatar_sheet.png`
- 12 個頭像以 4×3 / 12 格 sprite sheet 方式保存
- **不要拆成 12 個圖片檔**
- UI 使用 runtime crop 顯示指定頭像
- 玩家選擇後保存 avatar index

## 5. Gold / Lives

### Gold 商品

| Gold | Price |
|---:|---:|
| 500 | US$1.49 |
| 1,000 | US$2.99 |
| 5,000 | US$12.99 |
| 10,000 | US$24.99 |

目前付款服務尚未接 App Store / Google Play，因此購買 UI 可以先完成，但正式付款流程暫不視為完成。

### Lives

- 普通玩家上限：5
- 每 +1 Life：50 Gold
- Gold Member 顯示：`∞`
- 生命恢復時間：40 分鐘 / 1 Life

## 6. 工具商城

程式內工具名稱與商城顯示名稱：

| Code | Store Name | 單個價格 |
|---|---|---:|
| `timeRewind` | UNDO | 50 Gold |
| `revive` | REMOVE | 100 Gold |
| `positionSwap` | SWAP | 200 Gold |
| `duplicate` | DUPLICATE | 500 Gold |

工具購買原則：

- 購買後直接加入永久工具庫存
- 不覆蓋原有數量
- 章節切換不清空已購買數量
- 章節鎖定只限制「使用」，不刪除庫存
- 數量為 0 時，遊戲應導向對應商城購買頁

### 購買數量

可選：

`1 / 5 / 10 / 20 / 50`

數量折扣：

| Quantity | Multiplier |
|---:|---:|
| 1 | 1.0 |
| 5 | 0.9 |
| 10 | 0.8 |
| 20 | 0.7 |
| 50 | 0.6 |

## 7. 工具互動 UI

- 保留工具按鈕 pressed / unpressed 圖片
- 保留 `tool_select.mp3`
- **取消工具震動效果**
- 工具操作不使用 `button_click.mp3`

## 8. 遊戲核心目前原則

這一階段不要無故修改遊戲核心。

除非明確要求，先不要重新改：

- 4×4 Engine
- 鍵盤方向鍵
- 觸控滑動
- 章節完成動畫
- 六章背景
- 六章背景音樂
- 生物演化素材

## 9. 六章架構

- Chapter 1 — Ocean — 12 stages
- Chapter 2 — Land — 13 stages
- Chapter 3 — Sky — 14 stages
- Chapter 4 — History — 15 stages
- Chapter 5 — Technology — 16 stages
- Chapter 6 — Space — 17 stages

舊版 18-tier 設計禁止重新導入。

## 10. 目前下一步

新筆電完成 clone + `flutter pub get` 後：

1. 確認 `git status`
2. 確認 `flutter analyze`
3. 檢查目前 `SaveManager` 是否保留 avatar index 儲存功能
4. 檢查 `PersonalPage` 現況
5. 檢查 `ShopPage` 現況
6. 接著繼續完善「個人資訊 → 商城 → 購買 → 庫存」流程

## 11. 重要開發原則

- 不要使用舊 18 階資料。
- 不要重建已完成的遊戲核心。
- 不要把 avatar sheet 拆成 12 張圖。
- 不要讓商城購買覆蓋原有工具庫存。
- 不要因章節鎖定而刪除工具庫存。
- 目前優先完成個人資訊與商城，再處理其他舊功能清理。
