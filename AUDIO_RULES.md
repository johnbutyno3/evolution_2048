# Evolution 2048 — Audio Rules

## 1. Audio Folder Structure

assets/audio/
├── ui/
├── gameplay/
├── tools/
├── evolution/
├── chapter/
└── system/

## 2. UI Audio

### button_click.mp3
Path:
assets/audio/ui/button_click.mp3

用途：
- 一般按鈕
- 四個工具按鈕全部使用
- UNDO
- SWAP
- REMOVE
- DUPLICATE

### button_cancel.mp3
Path:
assets/audio/ui/button_cancel.mp3

用途：
- 工具 CANCEL

### menu_open.mp3
Path:
assets/audio/ui/menu_open.mp3

用途：
- 開啟選單／面板

### menu_close.mp3
Path:
assets/audio/ui/menu_close.mp3

用途：
- 關閉選單／面板

## 3. Gameplay Audio

### tile_move.mp3
Path:
assets/audio/gameplay/tile_move.mp3

用途：
- 一般棋盤滑動
- 物件移動
- 合併但沒有產生新物種／新階段

### tile_merge.mp3
Path:
assets/audio/gameplay/tile_merge.mp3

用途：
- 合併後產生新的物種／新的進化階段

規則：
- 不區分新舊物種
- 只有產生新物種／新階段才播放 tile_merge
- 不需要 tile_spawn
- 不需要 invalid_move

## 4. Tool Audio

### 四個工具
四個工具按鈕全部播放：
assets/audio/ui/button_click.mp3

### UNDO
- button_click.mp3
- 按下後立即執行
- 不需要 tool_select
- 不需要 execute 音效

### SWAP
使用：
- button_click.mp3
- assets/audio/tools/tool_select.mp3

點 SWAP 後進入選擇狀態。
第二次點物件不另外播放音效。

### REMOVE
使用：
- button_click.mp3
- assets/audio/tools/tool_select.mp3

點 REMOVE 後進入選擇狀態。
點選要移除的物件時不另外播放音效。

### DUPLICATE
使用：
- button_click.mp3
- assets/audio/tools/tool_select.mp3

點 DUPLICATE 後進入選擇狀態。
後續選擇物件不另外播放音效。
不論需要一次或兩次點選，都不增加其他音效。

### tool_select.mp3
Path:
assets/audio/tools/tool_select.mp3

用途：
- SWAP
- REMOVE
- DUPLICATE

三者共用同一個音效。

## 5. 不需要的音效

- button_confirm.mp3
- tool_execute.mp3
- undo_select.mp3
- undo_execute.mp3
- swap_select.mp3
- swap_execute.mp3
- remove_select.mp3
- remove_execute.mp3
- duplicate_select.mp3
- duplicate_execute.mp3
- tool_cancel.mp3
- tile_spawn.mp3
- invalid_move.mp3

## 6. Game Over

### game_over.mp3
Path:
assets/audio/system/game_over.mp3

確定進入 Game Over 時播放。

完全無法移動但尚未判定 Game Over：
- 不播放 invalid_move
- 不播放其他移動音效

## 7. Audio Format

目前先使用 MP3。

固定檔名以 .mp3 為主。

不要只修改副檔名將 MP3 假裝成 OGG。
若日後需要 OGG，必須真正轉換格式。

## 8. Development Principle

音效不過度細分。

button_click
→ 四個工具按鈕

tool_select
→ SWAP / REMOVE / DUPLICATE 選擇模式

tile_move
→ 一般移動及沒有產生新階段的合併

tile_merge
→ 產生新物種／新進化階段

game_over
→ Game Over
