# MENU RULES

## 1. Home

Home 是遊戲主入口，固定顯示六個章節。

### Player Summary

左側顯示：

- Avatar
- Player Name
- Player ID
- GOLD 餘額
- Shop 入口

Gold 區域只負責：
- 顯示目前 GOLD 餘額
- 提供 Shop 選購入口

不得在 Gold 區域重複顯示會員權益。

Player ID 必須使用實際帳號 ID，不得顯示 `NOT AVAILABLE`。

### Chapter Cards

每個已解鎖章節顯示：

- Chapter
- Current Stage
- Current Score

未解鎖章節：

- 顯示鎖定狀態
- 不顯示虛假的 Stage / Score

Chapter Progress 只在 Home 顯示，不再建立獨立的 Evolution Progress 選單。

---

## 2. Personal Information

Personal Information 為獨立頁面。

第一層選單固定為：

1. Player Information
2. Membership
3. Creature Collection
4. Settings
5. Game Guide
6. About / Version Info
7. Log Out

不得加入 Evolution Progress。

### Player Information

顯示：

- Avatar
- Player Name
- Player ID
- Email / Account

Avatar 與 Name 可以修改。

按下 SAVE 後：

- Avatar 必須實際保存
- Name 必須實際保存
- Firebase 與本地資料必須同步
- 重複名稱必須阻止

未按 SAVE 離開時，不得覆蓋原本資料。

---

## 3. Membership

Membership 頁面只顯示會員等級與會員權益。

不得重複顯示：

- GOLD
- Gold Shop
- Gold 商品

### Membership Levels

| Level | Price | Forced Ads | Rewarded Ads | Lives | Daily Gold | UNDO |
|---|---:|---|---|---:|---:|---|
| FREE | $0 | Yes | Yes | 5 | 0 | Normal |
| PREMIUM | $2.99/month | No | Yes | 5 | 20 | Normal |
| GOLDEN | $5.99/month | No | No | Infinite | 50 | Unlimited |

### Rewarded Ad UNDO

FREE / PREMIUM：

- 每局最多完成 2 次 Rewarded Ad
- 每完成一次取得 1 次免費 UNDO
- 第 3 次不再提供免費 UNDO
- 新遊戲重新計算
- 購買的 UNDO 不受此限制

GOLDEN：

- 無廣告
- UNDO Unlimited

所有會員：

- 不允許連續使用 UNDO

---

## 4. Creature Collection

Creature Collection 為帳號專屬收藏。

- 收藏永久保存
- 與 Firebase 帳號綁定
- 只能增加，不因重新開始遊戲而消失

---

## 5. Settings

Settings 提供目前支援的語言與一般設定。

目前語言：

- English
- Traditional Chinese

---

## 6. Game Guide

提供遊戲規則、操作方式、工具與生命規則說明。

---

## 7. About / Version Info

顯示：

- Game Name
- Version
- About
- Copyright / basic information

---

## 8. Shop

Shop 為獨立選購入口。

Home 的 Gold 後方提供 Shop 入口。

Shop 包含：

- GOLD
- Membership
- Tools

### GOLD Packages

所有正式價格統一使用 USD。

| GOLD | Price | Availability |
|---:|---:|---|
| 300 | $0.99 | FREE / PREMIUM / GOLDEN |
| 1,000 | $2.99 | PREMIUM / GOLDEN |
| 4,000 | $9.99 | PREMIUM / GOLDEN |
| 10,000 | $19.99 | PREMIUM / GOLDEN |

不得販售 Life +1。

---

## 9. Tools

User-facing tool names：

- REMOVE
- UNDO
- SWAP
- DUPLICATE

Tool inventory 與消耗由伺服器管理。

原始價格：

| Tool | 1 | 5 | 20 | 50 |
|---|---:|---:|---:|---:|
| UNDO | 50 | 225 | 700 | 1500 |
| REMOVE | 100 | 450 | 1400 | 3000 |
| SWAP | 200 | 900 | 2800 | 6000 |
| DUPLICATE | 500 | 2250 | 7000 | 15000 |

數量折扣：

- 1：100%
- 5：90%
- 20：70%
- 50：60%

FREE 只能購買 1 個。

PREMIUM / GOLDEN 可購買全部數量。

---

## 10. Life Rules

FREE / PREMIUM：

- 最大 5 生命
- 正常新遊戲消耗 1 生命
- 恢復速度依正式 Life 規則
- Game Over 不退還生命
- Resume 不重複扣生命
- Chapter Complete 不視為死亡

GOLDEN：

- Infinite Lives

Life 不作為 Gold Shop 商品。

---

## 11. Chapter Progress

章節進度只在 Home Chapter Card 顯示。

不得建立：

- Evolution Progress 個人選單
- 重複的章節進度頁面
- 虛假的鎖定章節進度

六章為正式章節：

1. Ocean — 12 stages
2. Land — 13 stages
3. Sky — 14 stages
4. History — 15 stages
5. Technology — 16 stages
6. Space / Universe — 17 stages

不得恢復舊版 18-stage 資料。

---

## 12. Removed / Forbidden UI

以下內容不得恢復：

- Evolution Progress 個人選單
- 舊版 NT$99 / NT$299 會員價格
- 舊版 Premium / Golden 權益
- Gold Shop 中的 Life +1
- `NOT AVAILABLE` Player ID
- 舊版 18-stage Creature Progression
- 舊 Challenge Mode 選單
- 重複的 Membership / Gold / Shop UI
- 虛假的鎖定章節 Stage / Score
