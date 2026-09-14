# Rebirth 2048 — Launch Sprint

## 目標
7 天內完成可上架版本。

Repository: `johnbutyno3/evolution_2048`
Branch: `feature/chapter1-spec-implementation`

## Progress Update Workflow

- `docs/PROJECT_STATUS.md` is the canonical progress source for daily status extraction.
- During active development, update progress after each meaningful completed task, milestone, major issue, or security finding.
- Do not depend on a background hourly scheduler.
- Every completed task must leave the progress document consistent with the actual committed state.
- Record the latest commit and the next task whenever a meaningful batch is completed.

## Day 1 — Home + Personal + Shop 整合

### 已完成
- [x] Personal Page 基本架構
- [x] Player Info 頁面
- [x] Avatar 選擇與保存
- [x] Avatar Firebase / 本地保存架構
- [x] Shop Page 基本架構
- [x] Home → Personal
- [x] Home → Shop
- [x] Home Avatar 資產清單接入
- [x] Home 讀取目前 Avatar
- [x] `flutter analyze` 通過
- [x] Player profile uniqueness
- [x] Secure player profile indexes
- [x] Remote Shop Config
- [x] Purchase intent / transaction-lock architecture

## Day 2 — Shop + Tools + Membership
- [ ] Membership / Premium / Golden
- [ ] Gold balance and packages
- [ ] Tool packages and owned quantities
- [ ] Tool purchase / use / locked state
- [ ] Golden infinite lives / ad removal
- [ ] USD pricing
- [ ] Shop UI complete
- [ ] Real payment backend may be deferred if it blocks launch
- [x] Life is not sold separately

## Day 3 — Game Core + Collection
- [ ] Collection achievement/evolution events
- [ ] Collection unlocks
- [ ] Chapter unlocks
- [ ] Gold / score / tool inventory
- [ ] Life rules
- [ ] Game Over / Restart / Chapter Complete / Next Chapter / Home
- [ ] Firebase persistence after relogin
- [ ] New/existing account verification

## Day 4 — Settings + Guide + Account
- [ ] Music / SFX toggles
- [ ] Language selection
- [ ] Game Guide
- [ ] Version Info / build / creator / asset credits
- [ ] Update check
- [ ] Logout
- [ ] Name uniqueness
- [ ] Immutable Player ID
- [ ] No vibration
- [ ] No Game Data feature

## Day 5 — UI / Bug / Multi-platform
- [ ] Home / Personal / Player Info / Shop / Game / Collection / Settings
- [ ] Login / Register / Logout / Firebase
- [ ] Overflow and yellow/black stripe fixes
- [ ] Tool UI and locked state
- [ ] English / Chinese localization
- [ ] Navigation
- [ ] Windows / Web / Android

## Day 6 — Release Candidate
- [ ] Feature freeze
- [ ] `flutter analyze`
- [ ] Android release build
- [ ] Web build
- [ ] Firebase login test
- [ ] New/existing account test
- [ ] Game progression test
- [ ] Shop test
- [ ] Logout/relogin test
- [ ] Persistence test
- [ ] Final bug fixes

## Day 7 — Release
- [ ] Version number
- [ ] App icon / splash / onboarding
- [ ] Android AAB/APK
- [ ] Web release
- [ ] Store screenshots / description
- [ ] Privacy information
- [ ] Asset credits
- [ ] Final installation test
- [ ] Submit

## Security / Anti-Cheat

- [x] Security specification documented in `docs/SECURITY_ANTI_CHEAT.md`
- [x] Server-authoritative architecture defined
- [x] Purchase intent and transaction uniqueness protections
- [ ] Server-authoritative Gold
- [ ] Server-authoritative Membership
- [ ] Server-authoritative Tool inventory and purchase deduction
- [ ] Server-authoritative Golden Infinite Lives
- [ ] Tighten `users/{uid}` Firestore update permissions
- [ ] Production developer/reset capability isolation
- [ ] Cheat Audit Log
- [ ] Admin cheat alerts

## 開發規則
1. 不使用舊版 18 階 creature data。
2. 不使用舊 l10n / backup。
3. 不大範圍重寫現有檔案。
4. 修改前先讀取目前實際檔案。
5. 每次只完成一個明確任務。
6. 每次修改後必須執行 `flutter analyze`。
7. Analyze 有錯誤時，停止新增功能，先修錯。
8. 不使用 `git restore` 破壞目前工作。
9. 不 force push。
10. 不自行改變既定遊戲規則。
11. 所有付費價格使用 USD。
12. 國際版目前只維護 English / Chinese。
13. 非核心功能不得阻塞上架。
14. 真實付款與進階 Admin 等非核心項目可延後。
15. 目前優先順序以上架為準。
16. 每完成重要工作即同步更新 `docs/PROJECT_STATUS.md`。

## Copilot 接手規則
Copilot 必須先閱讀：
- `docs/GAME_RULES.md`
- `docs/LAUNCH_SPRINT.md`
- `docs/PROJECT_STATUS.md`
- `docs/SECURITY_ANTI_CHEAT.md`
- 相關目前實際程式檔案

Copilot 每次只完成一個任務；不得自行連做後續任務。修改前先讀目前實際檔案，不得假設舊版程式碼。修改後必須執行 `flutter analyze`，只有 `No issues found!` 才能進下一項。

## Current Handoff

Current phase: **Launch Security / Anti-Cheat hardening**.

Next task:
**Server-authoritative Gold**

完成後：
1. `flutter analyze`
2. 更新 `docs/PROJECT_STATUS.md`
3. 再進入下一個明確安全任務。
