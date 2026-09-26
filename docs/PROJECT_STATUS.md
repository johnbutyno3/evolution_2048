# Rebirth 2048 — Project Status

最後更新：2026-09-26 09:42（Asia/Taipei）
專案：`johnbutyno3/evolution_2048`
分支：`feature/chapter1-spec-implementation`
主要事實來源：GitHub branch 最新已提交程式、最新 commit、timestamped canonical progress。

> 本文件只記錄已提交到 GitHub 的實際狀態。尚未提交的本機修改不得視為完成。舊 `RELEASE_PREPARATION_TODO.md` 不作主要進度來源。

## 目前階段

**Personal Information + Shop / Marketplace → Life / Game Session runtime correctness → Chapter / Tool / Collection runtime correctness → Launch Security / Anti-Cheat hardening**

目前主線仍是 Life、Session、Restart、會員／工具同步與章節流程的 runtime correctness；不回頭修改已確立的遊戲核心規則。

## 最新 GitHub 狀態

目前 branch 最新已提交 commit：`46cbad67346e4197d5cc6bfb3ce7d58cef29f8f7`

本次新增／修正：

- `46cbad67` — `fix: remove obsolete tool manager logout call`
- `c266c543` — `fix: correct evolution page build syntax`
- `8a304e61` — `docs: record fully local-first game entry`
- `497b0b68` — `fix: avoid progress refresh blocking game entry`
- `a00b110c` — `fix: keep first game entry local-first`
- `c22e2109` — `docs: record complete local-first game entry fix`

這批變更延續並收尾 local-first 進入遊戲：遊戲頁先建立可玩的本機棋盤與 Life 顯示，Progress refresh / Firebase session 驗證在背景進行，不再讓進入遊戲被網路延遲卡住；另修正 evolution page build 語法，並移除已不存在的 ToolManager logout API 呼叫，恢復 PersonalPage 登出流程可編譯。

## 已完成／已提交修正

### Life / Game Session

- 新局進入採本機優先扣除 Life，不等待 Firebase 才建立棋盤。
- 第一次進入遊戲也採 local-first，不再先等待完整 progress refresh。
- Firebase `startGameSession` 背景驗證仍保留；Server transaction 仍是 authoritative Life / Session 來源。
- Start / Resume / Restart / Completion response 遺失時，會重新讀取 authoritative state 判斷 transaction 是否已提交。
- LifeManager 已加入 life-state generation，舊 Firebase read 不得覆蓋較新的本機或 mutation 狀態。
- Restart 會建立新的 server session、標記舊 session replaced、重新綁定 local save。
- Home 會依 local unfinished session 與 server active session 限制章節切換。
- SaveManager 會拒絕未綁定舊 snapshot 污染新的 server session。
- Server replay 驗證已綁定 session `initialTiles`。

### Chapter completion

- Completion verification 與 280ms completion animation 平行開始。
- Completion response 遺失時可依 active session、chapter progress、target 做 authoritative recovery。
- Session、replay、chapter progress、tool reward 的 server verification 仍保留。

### Chapter / Collection / Tools

- Chapter progress 顯示最高演化 value / 最高分。
- Chapter completion tool reward 與工具 inventory refresh 已接通。
- 第一階 creature unlock 條件已補正。
- Tool inventory cache 已做 account-scoped 清除；登出不會把前一帳號工具數量帶到下一帳號。
- `allToolsEnabledForTest` 維持「解除章節工具種類限制」語意，不等同正式工具庫存數量。

## 目前仍未完成／未經最終實機驗證

### 1. Restart / Game Over

程式面的 lost-response / stale-session race 已修正，但仍需一次完整實機確認：

- Restart 不閃回舊棋盤。
- Game Over → Restart 建立新棋盤且不恢復舊 session。
- Restart 與 Game Over Restart 的 Life 顯示始終正確。

### 2. Life reconcile

需完成 E2E 實機確認：

- 生命扣除後不被舊讀取回應寫回。
- 倒數補命後不被舊 server state 回滾。
- 暫時性 Firebase 錯誤不會造成錯誤的舊狀態覆蓋。

### 3. TEST CONTROLS / Membership / Gold / Tools

程式資料流已區分 membership、gold wallet、tool inventory 與 `allToolsEnabledForTest`；仍需實機確認：

- Golden authoritative membership 寫入 Firebase 後，Home reload 顯示正確。
- Gold authoritative wallet 寫入 Firebase 後，Home reload 顯示正確。
- 正式工具 inventory 與測試 toggle 不互相混淆。
- 舊 local cache 不會覆蓋 server test state。

### 4. 各章工具初始 +1 / 累積

仍需實機確認：

- C1 開始即有 UNDO +1。
- 進入後續章節時工具可依規則跨章累積。
- 進入遊戲時工具數量立即正確顯示。

### 5. Collection / Chapter progress

仍需一次完整 E2E 確認第一階圖片、章節最高值、完成轉場與回首頁狀態。

## 下一個明確工作項目

**先完成一輪 consolidated runtime QA：第一次進入遊戲 Life 顯示、Restart、Game Over → Restart、Game Over → Back、重新進入遊戲、UNDO 後盤面與分數、Life reconcile。**

只有在這輪實機結果出現確定性錯誤後，才再改動對應程式；不重做已完成的遊戲核心規則。

## 文件狀態差異

- `docs/PROJECT_STATUS.md`：本次更新後同步至目前最新 branch HEAD `46cbad67`。
- `docs/GAME_RULES.md`：目前 GitHub branch 不存在；不可假裝存在，也不可自行創造規則取代既有規則來源。
- 詳細歷史仍保留於 timestamped canonical progress 文件。
- 不使用舊 `RELEASE_PREPARATION_TODO.md` 作主要進度來源。
