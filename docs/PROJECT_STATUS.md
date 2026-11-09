# Rebirth 2048 — Project Status

最後更新：2026-11-07
專案：`johnbutyno3/evolution_2048`
主要分支：`feature/chapter1-spec-implementation`
版本權威：GitHub 此分支最新已提交內容。

> 本文件只記錄可由目前 GitHub 原始碼確認的狀態。未執行的測試、部署及實機驗證不標示為完成。

## 目前階段

**Supabase client cutover → Economy / Session rule alignment → Legacy account export & reconciliation → Backend deployment / integration QA → Device QA**

Firebase 已不再是 Flutter app 的目標 runtime backend。Supabase 是新帳戶、會員、Gold、Life、工具庫存、遊戲 Session、進度、收藏、商城與客服資料的目標權威來源。

## 已確認的 Supabase client 遷移

- `pubspec.yaml` 目前直接依賴 `supabase_flutter`，未宣告 Firebase Flutter SDK dependencies。
- `lib/main.dart` 初始化 Supabase；登入／註冊與 OAuth 使用 Supabase Auth。
- `SupabaseAccountBootstrapService.synchronize()` 在 Home 啟用遊戲前取得並驗證 account snapshot，再套用會員、Life、Gold、工具庫存並綁定帳戶本機存檔。
- `LifeManager` 已使用 Supabase account snapshot；新局 Life 扣除由 `start-game-session` 的資料庫交易負責，client optimistic count 僅供即時 UI。
- `GoldManager` 已改用 Supabase account snapshot，僅保存 UI cache；沒有把本機 Gold 當作交易權威。
- `ToolManager` 的庫存讀取使用 Supabase snapshot，購買透過 `purchase-tool-package`，Gold 扣除與工具增加由資料庫交易原子處理。
- `PlayerProgressService` 與 `SupabaseGameSessionService` 使用 Supabase Edge Functions 管理 start / resume / restart / checkpoint / completion / abandon。
- `account-snapshot` 會以 server time 執行 FREE Life regeneration，並呼叫冪等的 daily Gold claim。
- 每日 Gold 已新增裝置 IANA 時區同步：Flutter 以 `flutter_timezone` 取得裝置時區，`account-snapshot` 先經 service-role RPC `set_account_timezone` 由 PostgreSQL `pg_timezone_names` 驗證並寫入 `profiles.timezone_name`，之後才呼叫 `claim_daily_gold`。若最近 24 小時已領取，時區變更會延後，避免切換時區跨日期重複領取。無法取得時區或後端同步失敗時，帳戶同步 fail-closed，不使用 UTC offset／縮寫冒充 IANA 時區。
- 章節完成由 server replay validator 驗證後才更新永久進度、結算工具使用及符合條件的 Life 獎勵。

## Life / Session 扣除規則核對

依 2026-11-09 生效的唯一權威規則文件 `docs/Rebirth 2048 完整專案規則20261027`，Life／Session 規則更新如下：
- 建立真正的新局：FREE 扣除 1 Life。
- RESUME／重新進入同一局／APP 重啟：0，不得再次扣除。
- Restart 對話框選「NO」：0（取消，不呼叫 restart RPC）。
- Restart 對話框選「YES」：0 額外扣除；replacement session 延續原遊戲已扣除的 Life。
- GAME OVER 本身：0 額外扣除；玩家之後明確建立新局才依新局規則扣除。
- CHAPTER COMPLETE：若該遊戲曾扣除 FREE Life，成功過關退還原始 1 Life，最高 5；Premium／Golden 不增加有限生命。
- 下一章建立新局：依新局規則扣除 1 Life。
- PREMIUM / GOLDEN 依會員權益為無限生命。

舊版「Restart YES 扣 1 Life」決策已被 2026-11-09 唯一權威規則取代，不再適用。最新 migration `20261109130000_carry_life_debit_across_restarts.sql` 讓 replacement session 沿用原始 `NEW_GAME_DEBIT` ledger reference；成功完成時才能正確退還原始 Life，且只退還一次。尚待 PostgreSQL integration／E2E 實測，不能只依靜態原始碼宣稱驗收通過。

## Firebase 遺留項目與保留原則

目前程式碼搜尋未發現 active `lib/` Dart runtime 仍匯入 Firebase Flutter SDK；但下列遺留項目仍存在：
- `functions/`：Firebase Admin / Cloud Functions legacy account export tooling，仍需用於舊帳戶資料匯出及對照。
- `firebase.json`、`firestore.rules`：舊 Firebase 專案設定與規則。
- `lib/screens/personal_page.dart.bak`、`personal_page.dart.backup`：舊 Firebase client 的備份程式碼，不屬於 active Dart build。
- `pubspec.lock` 搜尋仍見 Firebase platform-interface 套件項目；需在可用 Flutter 環境執行 `flutter pub get` 後確認 lockfile 是否自然清除。

在 Firebase Auth 使用者匯出、身份 mapping、Supabase import、筆數與權益核對完成前，不得刪除 Firebase Auth 帳戶、Firestore 資料、舊 Cloud Functions 或匯出所需設定。不得把 Firebase 舊 runtime 當作新功能開發目標。

## 仍未完成／尚未驗證

- Restart YES / NO 的 SQL transaction 與實機 E2E 驗證；已新增 Node source-contract tests 並接入 Supabase Audit workflow，但尚未取得 CI 執行結果。
- Firebase Auth / Firestore 完整匯出、身份 mapping、Supabase import、reconciliation。
- Supabase migrations 與 Edge Functions 尚未以目標 production project 完成部署核對；不得由 source files 推定已部署。
- 裝置時區同步已提交原始碼與 source-contract test；新增 PostgreSQL IANA timezone RPC，並以 24 小時內已有領取紀錄時暫緩時區切換，降低跨日期重複領取風險。
- 已修正 timezone RPC 的 PL/pgSQL 變數宣告及 dollar-quote 邊界；測試新增對 SQL 區塊結構的明確檢查。
- 新增 membership / purchase_transactions 權限 migration：一般客戶端可讀自己的會員與交易紀錄，但不能新增、修改或刪除；寫入權限保留給 service_role。
- Premium → Golden 升級價 USD 3.00 已接通 shop config、管理員價格設定及會員頁；FREE → Golden 仍顯示 USD 5.99。商店收據驗證完成前，所有實際付款按鈕仍保持不可購買。
- GitHub Actions 在 commit `86446a9` 的四個 workflow 均成功：Flutter Analyze workflow（包含 Flutter tests、Supabase source contract tests）、Supabase Audit、Security Audit Migration、Functions Audit。這些 CI 不等同於真實 Supabase SQL integration 或裝置 E2E。
- CI 執行 `flutter pub get` 可成功解析新增套件，`flutter analyze` 與 `flutter test` 均通過；但 `pubspec.lock` 尚未由本機 Flutter 環境更新並提交，需在 `C:\Users\user\rebirth_2048` 執行 `flutter pub get` 後核對 lockfile。
- Google / Apple OAuth provider credentials、redirect allow-list 及實機登入流程。
- Apple / Google Play 收據伺服器驗證、退款／撤銷及會員權益發放。
- 商店整合前置阻塞：Android `applicationId` 仍為 `com.example.rebirth_2048`，iOS `PRODUCT_BUNDLE_IDENTIFIER` 仍為 `com.example.rebirth2048`；兩者都是範例識別碼，尚未確定正式商店 App ID。Apple／Google 商店商品 ID、App Store Server API 金鑰、Google Play Developer API service account、退款／撤銷通知設定也尚未提供或配置。
- `shop_config` 內的 `membership_premium`、`membership_golden`、`membership_upgrade_golden` 是遊戲內設定鍵，不等於 Apple／Google 商店商品 ID。未確認正式 bundle/package ID 與商店商品 ID 前，不建立假驗證端點，也不啟用付款按鈕。
- Supabase SQL integration / concurrency tests、完整 Edge Function tests、Flutter `pub get` / `analyze` / `test`；目前新增的 restart Node source-contract test 尚未在此工作階段執行。
- APK 安裝與實機 E2E：新局扣命、restart/resume、Game Over、過關獎勵、Gold 購買工具、跨裝置登入與帳戶隔離。
- Firebase 資料完成遷移後的正式 cutover 與舊服務退役。

## 驗證邊界

本輪為 GitHub source inspection 與 repository-level 更新；目前工作環境沒有可執行此 repo 的 Flutter / Dart / Supabase CLI 與 production credentials。因此沒有宣稱 Flutter analyze、測試、migration apply、Edge Function deploy、APK 或實機驗證成功。

## 下一個工作順序

1. 完成裝置時區依賴鎖定與 Flutter / Node CI 驗證，並在 Supabase 測試資料庫驗證 timezone RPC + 每日 Gold 日期邊界。
2. 驗證 Restart YES 原子結算舊 Session + 建立新 Session 並只扣 1 Life；Restart NO 完全不呼叫後端扣命流程。
3. 增補 restart SQL contract / integration tests，涵蓋 YES / NO、冪等與 rollback。
4. 逐項核對 Supabase migration、Edge Function、RLS、交易與權益規則。
5. 執行 Firebase 舊帳戶 export → identity mapping → import → reconciliation；保留舊資料直到核對通過。
6. 在正確 Supabase project 完成 migration / Edge Function deployment，再進行 Flutter 與實機 QA。
7. 完成 cutover 後才退役 Firebase runtime；不提前刪除舊帳戶或資料。

