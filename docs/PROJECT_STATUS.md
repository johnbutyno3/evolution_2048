# Rebirth 2048 — Project Status

最後更新：2026-10-02 21:42（Asia/Taipei）
專案：`johnbutyno3/evolution_2048`
分支：`feature/chapter1-spec-implementation`
主要事實來源：GitHub branch 最新已提交程式、最新 commit、timestamped canonical progress。

> 本文件只記錄已提交到 GitHub 的實際狀態。尚未提交的本機修改不得視為完成。舊 `RELEASE_PREPARATION_TODO.md` 不作主要進度來源。

## 目前階段

**Personal Information + Shop / Marketplace → Life / Game Session runtime correctness → Chapter / Tool / Collection runtime correctness → Launch Security / Anti-Cheat hardening**

目前主線仍是 Life、Session、Restart、會員／工具同步與章節流程的 runtime correctness；不回頭修改已確立的遊戲核心規則。

## 最新 GitHub 狀態

目前 branch 最新已提交 commit：`3291d8d5107de741a41e0dccc50a722afd4290b8`

2026-10-02 最新變更：

- `3291d8d5`、`e18b1f2f`、`559c58ea`、`10bf2b28`：progress / admin lint cleanup。
- `a8d6f9d5`：恢復 start timeout recovery 的 previous-session guard。
- `3cd0e14c`：paused save resume 的 nullable guard。
- `82bb52de`：BACK 後保留 paused session binding。
- `b4cbffb2`：reset 時清除 paused continuation。
- `5136ee6d`、`96965422`：paused continuation exclusive persistence / enforcement。

本批變更主要強化 paused-game continuation、BACK、Reset、timeout recovery 與 null-safety，沒有改變既定遊戲規則。

## 已完成／已提交修正

### Life / Game Session

- 新局進入採本機優先扣除 Life，不等待 Firebase 才建立棋盤。
- 第一次進入遊戲也採 local-first。
- Firebase `startGameSession` 背景驗證仍保留；Server transaction 仍是 authoritative Life / Session 來源。
- Start / Resume / Restart / Completion response 遺失時，會重新讀取 authoritative state。
- LifeManager 已加入 life-state generation，舊 Firebase read 不得覆蓋較新的本機或 mutation 狀態。
- Restart 會建立新的 server session、標記舊 session replaced、重新綁定 local save。
- BACK 後的 paused continuation 只保留唯一可恢復 session；reset 時清除 paused continuation。
- Start timeout recovery 會檢查 previous session，避免錯誤 session 被視為新局。
- Home / SaveManager 仍有 active session 與 stale snapshot 防護。
- Server replay 驗證已綁定 session `initialTiles`。

### Chapter / Collection / Tools

- Completion verification 與動畫平行開始；response 遺失可做 authoritative recovery。
- Chapter progress、tool reward、inventory refresh 已接通。
- Tool inventory cache 已做 account-scoped 清除。
- Provider login failure 會暴露可診斷錯誤細節。
- `allToolsEnabledForTest` 不等同正式工具庫存數量。
- Admin / progress lint cleanup 已完成。

## 目前仍未完成／未經最終實機驗證

- BACK 後重新進入是否只恢復唯一 paused 棋盤。
- Reset 後是否不會恢復舊 paused continuation。
- Restart / Game Over → Restart 是否不閃回舊棋盤且 Life 只扣一次。
- Life regeneration / Firebase reconcile 是否不被舊狀態回滾。
- Golden membership、Gold wallet、正式工具 inventory 與測試 toggle 的實機一致性。
- C1 UNDO +1、跨章工具累積、Collection / Chapter progress 完整 E2E。

## 下一個明確工作項目

**完成 consolidated runtime QA：BACK / paused continuation、Reset、Restart、Game Over → Restart、Game Over → Back、重新進入遊戲、UNDO 後盤面與分數、Life reconcile。**

只有在實機出現確定性錯誤後，才改動對應程式；不重做已完成的遊戲核心規則。

## 文件狀態差異

- `docs/PROJECT_STATUS.md`：同步至 `3291d8d5`。
- `docs/GAME_RULES.md`：目前 GitHub branch 不存在。
- 不使用舊 `RELEASE_PREPARATION_TODO.md` 作主要進度來源。
