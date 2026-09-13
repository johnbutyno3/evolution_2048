# REBIRTH 2048｜正式發布準備待辦

最後更新：2026-09-13
目前版本：App Icon 已正式產生 Android / iOS 圖示；第 2 項 Logo 待確認獨立 Logo 素材
分支：feature/chapter1-spec-implementation

## 階段 1｜產品素材
- [x] 1. 確認 App Icon
  - 已確認設計包含「REBIRTH 2048」字樣。
  - 已使用 `assets/icon/app_icon.png` 產生 Android 與 iOS 多尺寸 App Icon。
  - `flutter analyze` 已通過；`git diff --check` 僅有 Windows LF/CRLF 提示。
- [ ] 2. 確認 REBIRTH 2048 Logo
  - 目前尚未找到可獨立使用的 Logo 素材；現有 App Icon 不能直接視為透明背景 Logo。
  - 2026-09-10 再次檢查目前分支與檔案搜尋結果，仍未找到獨立 Logo 檔案。
  - 2026-09-12 檢查 GitHub 分支 `feature/chapter1-spec-implementation` 的 `assets/icon/`，目前仍只有 `app_icon.png`，沒有獨立 Logo 檔案。
  - 下一步需確認／提供獨立 Logo 圖檔，再進行尺寸、透明背景與版面檢查。
- [ ] 3. 整理開場介紹
- [ ] 4. 整理遊戲玩法說明
- [ ] 5. 整理工具說明
- [ ] 6. 整理六章世界介紹

## 階段 2｜App 完整流程
- [ ] 7. 開場畫面
- [ ] 8. 遊戲介紹頁
- [ ] 9. 註冊／登入
- [ ] 10. 基本設定
- [ ] 11. 六章大廳
- [ ] 12. 個人／設定／圖鑑
- [ ] 13. 存檔與恢復流程完整測試

## 階段 2A｜個人資訊與商城

### A. 玩家資料與身份
- [ ] A1. 頭像 Firebase 同步
  - 個人頁選擇頭像後寫入 Firebase。
  - 遊戲首頁同步顯示相同頭像。
  - 重新登入後仍保留。
- [ ] A2. PLAYER NAME
  - 新玩家首次建立時自動產生隨機名稱。
  - 絕對不可顯示 `PLAYER`。
  - 名稱必須唯一，不可與其他玩家重複。
  - 玩家可以修改名稱。
  - 修改時再次檢查唯一性。
  - Firebase 保存正式名稱。
- [ ] A3. PLAYER ID
  - Firebase 建立唯一 Player ID。
  - 不可重複。
  - 玩家不可修改。
  - 建立後永久固定。
- [ ] A4. 會員資料
  - 個人頁顯示目前會員狀態。
  - 點擊會員進入商城會員購買區。
  - 會員價格使用既有正式規格，不重新猜測或硬編碼。

### B. 個人頁功能
- [ ] B1. Creature Collection
  - 修復點擊後無法開啟的問題。
  - 顯示已解鎖／未解鎖生物。
  - 六章資料正確對應。
  - 生物圖片正常載入。
  - 與遊戲實際解鎖進度同步。
- [ ] B2. Gold
  - 個人頁只顯示 Gold 圖示與餘額。
  - 移除 Life 顯示。
  - 點擊 Gold 直接進入商城 Gold 購買區。
  - Gold 與遊戲實際數值同步。
- [ ] B3. Settings
  - 可選擇並切換語言。
  - 中文／English 正常切換。
  - 保存語言設定，重新啟動後仍維持。
  - 不重新加入 Game Data。
- [ ] B4. Game Guide
  - 擴充為完整遊戲指南。
  - 包含基本玩法、2048 合成規則、六章、關卡、生物演化、工具、Gold、會員、過關、Game Over、手機滑動與鍵盤操作等說明。
- [ ] B5. Version Info / Update
  - 建立正式版本號管理。
  - 每次正式更新產生新的版本號。
  - Firebase／管理中心保存最新版本資訊。
  - 玩家啟動 App 時先檢查更新。
  - 有更新時先顯示更新資訊，必要時要求更新後才進入 App／遊戲。
- [ ] B6. Additional Info
  - 新增遊戲開發者資訊。
  - 新增遊戲介紹、音樂、音效、美術素材、版權等資訊。
- [ ] B7. Logout
  - 登出前顯示確認視窗。
  - 確認後 Firebase Sign Out 並返回登入頁。
  - 取消後返回原頁面。

### C. 商城
- [ ] C1. 正式商城價格
  - 找出專案既有的正式商城價格／規格文件。
  - Gold、Membership、Life、Tools 等價格以既有規格為唯一依據。
  - 不自行猜測或修改既定價格。
- [ ] C2. 商城 Tool 文字／亂碼
  - 修正目前 Tool 區域亂碼。
  - 檢查中文 localization、Tool 名稱與 Tool 說明。
  - 確認商品名稱、價格與數量正常顯示。
- [ ] C3. 商城參數 Firebase 化
  - 商城價格與參數不可硬編碼於遊戲畫面。
  - Gold、Membership、Life、Tools 等商品參數由 Firebase／管理中心提供。
  - 支援商品價格、數量、啟用／停用與會員方案等參數調整。

### D. 獨立管理中心
- [ ] D1. 管理系統架構
  - 管理中心與玩家遊戲 App 分離。
  - 管理員可以安全管理玩家及遊戲參數。
- [ ] D2. 玩家管理
  - 查詢玩家。
  - 查詢 Player ID、Player Name、會員狀態、Gold 等資料。
  - 修改管理員允許修改的資料。
- [ ] D3. 商城管理
  - 管理 Gold、Membership、Life、Tools 等商品價格與參數。
  - 支援商品啟用／停用。
- [ ] D4. 玩家訊息
  - 玩家可以發送訊息。
  - 管理中心接收、查詢與回覆。
  - 保留訊息紀錄。
- [ ] D5. Q&A
  - 玩家端 Q&A。
  - 管理員新增、修改與管理問題及答案。
  - 玩家端讀取最新內容。
- [ ] D6. 留言板
  - 玩家留言。
  - 管理員查看、回覆及必要的管理／隱藏。
  - 玩家端顯示留言與回覆。

### E. 資料同步與安全
- [ ] E1. Firebase 玩家正式資料結構
  - `users/{uid}` 統一管理 `playerId`、`playerName`、`avatarIndex`、會員等玩家資料。
- [ ] E2. 唯一性保護
  - Player ID 唯一。
  - Player Name 唯一。
  - 修改名稱時重新檢查唯一性。
  - 不依賴單純本機 SharedPreferences 判斷唯一性。
- [ ] E3. 個人頁／遊戲同步
  - Avatar、Player Name、Player ID、Gold、Membership、Creature Collection 使用一致的正式資料來源。

### F. 遊戲主畫面
- [ ] F1. 黃黑警告條
  - 查明遊戲畫面底部黃黑條的來源。
  - 檢查是否為 Flutter `RenderFlex overflow`。
  - 找出實際超出畫面的 Widget。
  - 修正手機／Chrome 不同尺寸下的版面問題。
  - 確認正式畫面不再出現黃黑警告條。

### G. 階段測試
- [ ] G1. 新玩家測試
  - 註冊後自動取得唯一 Player ID。
  - 自動取得唯一 Player Name。
  - 不出現 `PLAYER`。
  - 頭像正常保存與同步。
- [ ] G2. 舊玩家測試
  - 舊帳號資料正常保留。
  - 舊的 `PLAYER` 名稱可安全遷移為唯一名稱。
  - 既有 Player ID 不重新產生。
- [ ] G3. 個人頁完整測試
  - Player Info、Collection、Gold、Settings、Guide、Version、Additional Info、Logout 全部可正常使用。
- [ ] G4. 商城完整測試
  - 正式價格、Tool 文字、Gold、Membership、Life、Tools 與購買後資料全部正確。
- [ ] G5. 遊戲相容性測試
  - 個人／商城功能完成後，不影響六章遊戲流程與既有遊戲規則。

## 階段 3｜發布準備
- [ ] 14. App 名稱與 Package ID
- [ ] 15. App 版本號
- [ ] 16. Android Icon / Splash
- [ ] 17. Android Release Signing
- [ ] 18. 建立 APK / AAB
- [ ] 19. Windows 實機測試
- [ ] 20. 最終完整遊戲測試

## 階段 4｜商店
- [ ] 21. Google Play 商店資料
- [ ] 22. App Store 資料（如發布 iOS）
- [ ] 23. 商店截圖
- [ ] 24. 隱私權政策
- [ ] 25. 服務條款
- [ ] 26. 年齡分級
- [ ] 27. 正式發布

## 每日進度紀錄

### 2026-09-13
- 新增「階段 2A｜個人資訊與商城」完整待辦事項。
- 納入玩家身份、頭像同步、Creature Collection、Gold、Settings、Game Guide、Version / Update、Additional Info、Logout、商城價格、Tool 亂碼、Firebase 商城參數、獨立管理中心、玩家訊息、Q&A、留言板、資料同步、安全性與黃黑警告條等工作。
- 商城價格明確要求以 Rebirth 2048 專案既有正式規格文件為唯一依據，不自行猜測。
- 不重新加入 Game Data。
- 不改變既定六章遊戲規則。

### 2026-09-12
- 依序處理第 2 項「確認 REBIRTH 2048 Logo」。
- 檢查 GitHub 分支 `feature/chapter1-spec-implementation` 的 `assets/icon/` 資料夾。
- 目前資料夾只有 `app_icon.png`，未找到可獨立使用的 Logo 圖檔。
- 第 2 項維持未完成，未跳到第 3 項，也未改變任何既定遊戲規則。
- 下一步：確認或加入獨立 Logo 圖檔後，完成尺寸、透明背景與版面檢查。

### 2026-09-10
- 依序處理第 2 項「確認 REBIRTH 2048 Logo」。
- 再次檢查目前分支的資產與檔名，未找到可獨立使用的 Logo 圖檔。
- 搜尋結果沒有發現 `logo` 相關獨立素材；目前只有含有「REBIRTH 2048」字樣的 App Icon。
- 第 2 項維持未完成，未跳到第 3 項，也未改變任何既定遊戲規則。
- 下一步：確認或加入獨立 Logo 圖檔後，完成尺寸、透明背景與版面檢查。

### 2026-09-06
- 依序處理第 2 項「確認 REBIRTH 2048 Logo」。
- 檢查目前分支資產結構，確認已有 `assets/icon/`，但未發現可獨立使用的 Logo 素材資料夾或檔案。
- App Icon 雖含有「REBIRTH 2048」字樣，但不直接作為透明背景 Logo 使用，以避免後續商店素材與畫面版面受限。
- 第 2 項暫維持未完成，等待獨立 Logo 素材確認。
- 下一步：完成第 2 項 Logo 確認後，再進入第 3 項「整理開場介紹」。

### 2026-09-05
- 完成第 1 項「確認 App Icon」。
- 使用者確認最終圖示包含清楚可辨識的「REBIRTH 2048」。
- 已在本機產生 Android 與 iOS App Icon 資源。
- 驗證結果：`flutter analyze` 無問題；`git diff --check` 無內容錯誤，只有換行格式提示。
- 下一步：第 2 項「確認 REBIRTH 2048 Logo」。

### 2026-09-04
- 建立正式發布準備待辦清單。
- 目前從第 1 項「確認 App Icon」開始。
- 遊戲核心、六章內容、工具布局與現有素材列為已完成基礎，不重複製作。
