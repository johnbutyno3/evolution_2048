# Rebirth 2048 — Project Status

最後更新：2026-09-24 23:15（Asia/Taipei）
專案：`johnbutyno3/evolution_2048`
分支：`feature/chapter1-spec-implementation`
主要事實來源：GitHub branch 最新已提交程式、最新 commit、timestamped canonical progress。

> 本文件只記錄已提交到 GitHub 的實際狀態。尚未提交的本機修改不得視為完成。舊 `RELEASE_PREPARATION_TODO.md` 不作主要進度來源。

## 目前階段

**Personal Information + Shop / Marketplace → Life / Game Session runtime correctness → Chapter / Tool / Collection runtime correctness → Launch Security / Anti-Cheat hardening**

目前仍以實機測試發現的 Life、Session、Restart、會員／工具同步與章節流程問題為主要工作，不回頭修改已確立的遊戲核心規則。

## 最新 GitHub 狀態

目前 branch 最新已提交修正：`d2588f4d0a60262ff105d6ef5ecbf8f30a170c61`

近期重要提交：

- `0a533be0` — `docs: record completion lost-response recovery`
- `023d4cf5` — `fix: recover committed chapter completion`
- `51fb8952` — `docs: record authoritative session pointer reconciliation`
- `1df259ff` — `fix: reconcile local session pointer on refresh`
- `c57bdf5f` — `docs: record start lost-response recovery`
- `832226b8` — `fix: recover committed start after lost response`
- `bf723e0e` — `fix: discard stale life reads after local mutation`
- `ffa84f39` — `docs: add canonical project status`
- `a91ecd4e` — `docs: record restart lost-response recovery`
- `3f5776a7` — `fix: recover committed restart after lost response`
- `5fec1c8d` — `docs: record life stale-read protection`
- `bf723e0e` — `fix: discard stale life reads after local mutation`
- `96014ed4` — `docs: record completion preflight change`
- `7dbcea20` — `fix: restore gameplay page and preflight chapter completion`
- `29fbb907` — `fix: start chapter completion verification with animation`
- `ee493de7` — `docs: record life regeneration stale response fix`

## 本輪新修正

### Life reconcile stale-read 防護

- `LifeManager.refreshFromServer()` 現在以 life-state generation 綁定每次 Firebase read。
- 本機扣命、生命倒數補命、Firebase mutation 都會使舊 read 失效。
- 舊的 `getLifeState` 回應若在本機生命狀態更新後才返回，直接捨棄，不再把新狀態覆蓋回舊值。
- 生命倒數到期仍先本機立即增加生命，再背景向 Firebase 驗證。
- 這一層直接針對先前觀察到的 `4 → 5 → 又回 4` 類型競態加強。

## 已完成／已提交修正

### Life / Game Session

- 新局進入採本機優先扣除 Life，不等待 Firebase 才建立棋盤。
- Firebase `startGameSession` 背景驗證仍保留。
- `membershipRef is not defined` 導致 `startGameSession` 500 的問題已修正並部署。
- Life regeneration countdown 到期的舊回應覆蓋問題已加入防護。
- Start / Resume / Restart session response 有 generation / stale-response 防護。
- Restart 新局會建立新的 server session 並重新綁定 local save。
- Restart callable response 遺失時，會重新讀取 server active session；若確認 transaction 已建立新 session，不再錯誤 rollback 舊棋盤。
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

- 程式面的 Restart lost-response race 已修正；尚未完成最終實機確認 Restart 不閃回舊棋盤。
- 尚未完成最終實機確認 Game Over → Restart 不閃回舊遊戲。
- 尚未完成最終實機確認 Restart / Game Over Restart 的 Life 顯示始終正確。

### 2. Life reconcile

程式的 stale-response 防護已進一步完成，但仍未完成完整 E2E 實機確認：

- `3 → 4` 或 `5 → 4 → 5` 不再由舊 Firebase read 覆蓋。
- 背景 reconcile 必須始終對應目前 life-state generation。
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

## 本輪 Session 進一步檢查

### Start response 遺失恢復

- `startGameSession` 與 Restart 同樣存在「Server transaction 已提交、callable response 遺失」的競態。
- 已於 `832226b8` 修正：錯誤後先重新讀取 authoritative active session。
- 只有確認 active Session ID 從 Start 前狀態變成符合本次章節的新 Session，才視為 Start 已提交並保留本機新局。
- 單純網路失敗且 Server 沒有新 Session 時，不會偽造成功。
- `c57bdf5f` 已將此修正寫入 cumulative progress。

### TEST CONTROLS 資料流檢查結果

目前程式資料流已確認：

- Membership：`adminSetMembershipMode` 寫入 `users/{uid}/membership/current`；`getLifeState` / Home 可重新讀取 authoritative membership。
- Gold：`adminSetGoldBalance` 寫入 `users/{uid}/wallet/gold`；Admin Test Page 隨後呼叫 `getGoldBalance` 更新 `GoldManager`。
- Tools：`adminSetAllToolsEnabled` 目前寫入的是 `users/{uid}.allToolsEnabledForTest`，用途是「解除章節工具種類限制」，**不是發放工具使用次數**。
- `getToolInventory` 仍以 `wallet/tools` 為 authoritative inventory，C1 初始 UNDO 由 `ensureInitialUndo` 保證 +1。
- 因此「Tools enabled 但 inventory 是 0」在目前語意下不是 Firebase 寫入失敗，而是 TEST toggle 與「工具數量發放」兩個概念不同。不能直接把 toggle 改成 999999，否則會破壞 server-authoritative inventory 與正式扣除規則。

## 本輪新增 Session pointer 修正

- `PlayerProgressService.refresh()` 現在同步 Server authoritative active Session 與 `SaveManager.gameSessionId`。
- Server 已無 active session 時，會清除本機舊 Session ID。
- Server 有 active session 且本機 ID 不同時，會同步本機 ID。
- 修正 `abandonGameSession` / Game Over response 遺失後，舊 Session ID 殘留在本機的競態。
- Session ID 寫入仍走 SaveManager queue，不改變 local-first 遊戲操作。

## 本輪 Chapter Completion 修正

- `completeChapter` 現在具備 transaction response 遺失後的 authoritative recovery。
- 若 Server 已完成指定 Session、active session 已清除、章節最高值已達 target，Client 可確認 completion 已提交。
- completion 同樣受 operation generation 保護。
- 已補齊 Start / Restart / Completion 三條主要交易流程的 response-lost recovery。

## 本輪新增工具同步修正

- `127e7c72`：從商城返回遊戲後，重新讀取 authoritative tool inventory，並同步目前掛載中的 GameEngine ToolState。
- 修正購買工具／Rewarded Tool 後 Server inventory 已更新、但當前遊戲畫面仍顯示舊數量的問題。
- 不改變正式工具庫存規則，也不讓正常遊戲操作等待 Firebase。

## 本輪新增帳號工具快取隔離修正

- `4b104705`：ToolManager 新增 account-scoped inventory cache 清除。
- `380952f9`：登出前清除工具 cache，避免帳號 A 的工具數量短暫出現在帳號 B。
- 新帳號仍以 Firebase authoritative inventory 重新同步。

## 下一個明確工作項目

**先完成 Restart / Game Over → Restart 與 Life reconcile 的完整 runtime correctness；之後若需要測試所有工具，另外建立明確的 TEST inventory grant，不把「all tools enabled」混成正式工具庫存。**

執行順序不可跳過底層 Session / Life 驗證直接進行最後 E2E。

## 文件狀態差異

- `docs/PROJECT_STATUS.md`：現在作為每日實際狀態摘要，已同步本輪 Life reconcile 修正。
- `docs/GAME_RULES.md`：目前 GitHub branch 不存在；不可假裝存在，也不可自行創造規則取代既有規則來源。
- 目前規則／進度的詳細歷史仍保留於 timestamped canonical progress 文件。
- 不使用舊 `RELEASE_PREPARATION_TODO.md` 作主要進度來源。
