# Rebirth 2048 — Project Status

最後更新：2026-09-24 21:20（Asia/Taipei）
專案：`johnbutyno3/evolution_2048`
分支：`feature/chapter1-spec-implementation`
主要事實來源：GitHub branch 最新已提交程式、最新 commit、timestamped canonical progress。

> 本文件只記錄已提交到 GitHub 的實際狀態。尚未提交的本機修改不得視為完成。舊 `RELEASE_PREPARATION_TODO.md` 不作主要進度來源。

## 目前階段

**Personal Information + Shop / Marketplace → Life / Game Session runtime correctness → Chapter / Tool / Collection runtime correctness → Launch Security / Anti-Cheat hardening**

目前仍以實機測試發現的 Life、Session、Restart、會員／工具同步與章節流程問題為主要工作，不回頭修改已確立的遊戲核心規則。

## 最新 GitHub 狀態

目前 branch HEAD：`96014ed4d78fda4492919d04f02114359047138f`

近期重要提交：

- `96014ed4` — `docs: record completion preflight change`
- `7dbcea20` — `fix: restore gameplay page and preflight chapter completion`
- `29fbb907` — `fix: start chapter completion verification with animation`
- `ee493de7` — `docs: record life regeneration stale response fix`

## 已完成／已提交修正

### Life / Game Session

- 新局進入採本機優先扣除 Life，不等待 Firebase 才建立棋盤。
- Firebase `startGameSession` 背景驗證仍保留。
- `membershipRef is not defined` 導致 `startGameSession` 500 的問題已修正並部署。
- Life regeneration countdown 到期的舊回應覆蓋問題已加入防護。
- Start / Resume / Restart session response 有 generation / stale-response 防護。
- Restart 新局會建立新的 server session 並重新綁定 local save。
- 舊 active session 由 server transaction 標記 replaced。
- Home 同時依 local unfinished session 與 server active session 限制章節切換。
- SaveManager 不再讓未綁定舊 snapshot 污染新的 server session。

### Chapter completion

- 最高階達成時，`completeChapter` Firebase 驗證會與 280ms completion animation 同時開始。
- 不再先播放動畫、再等待 Firebase completion verification 才開始轉場。
- Session、replay、chapter progress、tool reward 的 server verification 仍保留。
- Gameplay page 已恢復為完整版本，並保留 completion preflight。

### Chapter / Collection / Tools

- Chapter progress 已改為顯示最高演化 value / 最高分，而不是 stage index。
- Chapter completion reward 的 tool refresh 已修正。
- 各章 completion tool reward 已加入。
- Chapter 未完成時 Home 已限制只能繼續目前章節。
- 第一階 creature unlock 的條件已補正。

## 目前仍未完成／未經最終實機驗證

### 1. Restart / Game Over

- 尚未完成最終實機確認 Restart 不閃回舊棋盤。
- 尚未完成最終實機確認 Game Over → Restart 不閃回舊遊戲。
- 尚未完成最終實機確認 Restart / Game Over Restart 的 Life 顯示始終正確。

### 2. Life reconcile

- 尚未完成完整 E2E 驗證，確認舊 Firebase response 不會造成 `3 → 4` 或 `5 → 4 → 5`。
- 需要確認背景 reconcile 必須以目前 session / attempt 為條件。
- 暫時性 Firebase 錯誤不可用舊 server state 覆蓋正確本機狀態。

### 3. TEST CONTROLS / Membership / Gold / Tools

實機曾確認：TEST CONTROLS 設為 Golden、Gold 10000、Tools enabled 後，回 Home 仍顯示一般會員、Gold 0。

尚未完成：

- Golden authoritative membership 寫入 Firebase。
- Gold 10000 authoritative wallet 寫入 Firebase。
- Tools authoritative inventory 寫入 Firebase。
- Home reload 正確讀取 authoritative state。
- 防止舊 local cache 覆蓋 server test state。

### 4. 各章工具初始 +1 / 累積

正式規則為各章可使用工具各送 1 個，並可跨章累積；目前仍需完成實機驗證：

- C1 開始即有 UNDO +1。
- C1 未使用時進 C2 累積為 2。
- 每章各自的工具 reward 正確。
- Tool inventory 在進入遊戲時立即正確顯示。

### 5. Collection 第一階

程式已補正第一階解鎖條件，但尚未完成最終實機確認第一階圖片不再顯示未解鎖。

### 6. Chapter progress / completion

程式修正已提交，但尚未完成一次完整 E2E：

- C1 顯示 `4096/44384`。
- C2 顯示 `1024/18616`。
- Chapter complete transition 穩定快速顯示。

## 下一個明確工作項目

**先完成 Restart / Game Over → Restart 與 Life reconcile 的完整 runtime correctness，再處理 TEST CONTROLS authoritative membership / Gold / Tools 資料流。**

執行順序不可跳過底層 Session / Life 驗證直接進行最後 E2E。

## 文件狀態差異

- `docs/PROJECT_STATUS.md`：本次建立，現在作為每日實際狀態摘要。
- `docs/GAME_RULES.md`：目前 GitHub branch 不存在；不可假裝存在，也不可自行創造規則取代既有規則來源。
- 目前規則／進度的詳細歷史仍保留於 timestamped canonical progress 文件。
- 不使用舊 `RELEASE_PREPARATION_TODO.md` 作主要進度來源。
