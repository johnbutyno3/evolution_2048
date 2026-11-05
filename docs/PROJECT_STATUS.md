# Rebirth 2048 — Project Status

最後更新：2026-11-05
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
- 章節完成由 server replay validator 驗證後才更新永久進度、結算工具使用及符合條件的 Life 獎勵。

## 必須優先修正的規則不一致

**Restart 是否扣 Life 與已確認遊戲規則不一致。**

目前 `supabase/migrations/20261103030000_atomic_restart_game_session_rpc.sql` 的 `restart_game_session` 先結算舊 Session，再呼叫 `start_game_session`；而 `start_game_session` 會對 FREE 帳戶執行 `NEW_GAME_DEBIT`。因此目前 restart 會扣除 1 Life。

既定遊戲規則為：
- 新開一局扣 1 Life。
- Resume 不扣 Life。
- Restart 不扣 Life。
- 放棄不退 Life；Game Over 不額外扣 Life。
- PREMIUM / GOLDEN 無限生命。

下一個資料庫修正必須讓 restart 在單一交易內結算舊 Session 並建立新 Session，但不產生第二筆 `NEW_GAME_DEBIT`；一般 start 仍必須扣 1 Life。需同時補上 SQL contract / integration tests，涵蓋 FREE、PREMIUM、GOLDEN、重試冪等、舊 Session 結算失敗及新 Session 建立失敗回滾。修正前不可宣稱 restart Life 規則已符合要求。

## Firebase 遺留項目與保留原則

目前程式碼搜尋未發現 active `lib/` Dart runtime 仍匯入 Firebase Flutter SDK；但下列遺留項目仍存在：
- `functions/`：Firebase Admin / Cloud Functions legacy account export tooling，仍需用於舊帳戶資料匯出及對照。
- `firebase.json`、`firestore.rules`：舊 Firebase 專案設定與規則。
- `lib/screens/personal_page.dart.bak`、`personal_page.dart.backup`：舊 Firebase client 的備份程式碼，不屬於 active Dart build。
- `pubspec.lock` 搜尋仍見 Firebase platform-interface 套件項目；需在可用 Flutter 環境執行 `flutter pub get` 後確認 lockfile 是否自然清除。

在 Firebase Auth 使用者匯出、身份 mapping、Supabase import、筆數與權益核對完成前，不得刪除 Firebase Auth 帳戶、Firestore 資料、舊 Cloud Functions 或匯出所需設定。不得把 Firebase 舊 runtime 當作新功能開發目標。

## 仍未完成／尚未驗證

- Restart 不扣 Life 的資料庫交易修正及測試。
- Firebase Auth / Firestore 完整匯出、身份 mapping、Supabase import、reconciliation。
- Supabase migrations 與 Edge Functions 尚未以目標 production project 完成部署核對；不得由 source files 推定已部署。
- Google / Apple OAuth provider credentials、redirect allow-list 及實機登入流程。
- Apple / Google Play 收據伺服器驗證、退款／撤銷及會員權益發放。
- Supabase SQL integration / concurrency tests、Edge Function tests、Flutter `pub get` / `analyze` / `test`。
- APK 安裝與實機 E2E：新局扣命、restart/resume、Game Over、過關獎勵、Gold 購買工具、跨裝置登入與帳戶隔離。
- Firebase 資料完成遷移後的正式 cutover 與舊服務退役。

## 驗證邊界

本輪為 GitHub source inspection 與 repository-level 更新；目前工作環境沒有可執行此 repo 的 Flutter / Dart / Supabase CLI 與 production credentials。因此沒有宣稱 Flutter analyze、測試、migration apply、Edge Function deploy、APK 或實機驗證成功。

## 下一個工作順序

1. 修正 restart RPC：舊 Session settlement + 新 Session create 原子化，但不扣 Life；一般新局維持扣 1。
2. 增補 restart SQL contract / integration tests，確認冪等與 rollback。
3. 逐項核對 Supabase migration、Edge Function、RLS、交易與權益規則。
4. 執行 Firebase 舊帳戶 export → identity mapping → import → reconciliation；保留舊資料直到核對通過。
5. 在正確 Supabase project 完成 migration / Edge Function deployment，再進行 Flutter 與實機 QA。
6. 完成 cutover 後才退役 Firebase runtime；不提前刪除舊帳戶或資料。

