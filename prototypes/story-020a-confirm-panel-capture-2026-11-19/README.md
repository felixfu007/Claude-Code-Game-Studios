# story-020a 出牌確認面板截圖驅動(拋棄式)

狀態:in-progress(headless 已驗證可走到截圖前一步;開窗截圖尚未執行)

## 用途
供 story-020 AC5(管理者人眼確認出牌確認面板)拍 3 態 x 2 解析度 = 6 張 PNG:
1. `1_single_hp` 單人付血  2. `2_duo_fray` 雙人好感「配合折損」  3. `3_unaffordable` 付不起(✕ 列 + 鈕面「無法出牌」)
解析度 1280x720、1920x1080。輸出到 `out/<態>_<寬>x<高>.png`。

夾具與輸入路徑照抄 `tests/integration/ui/battle/battle_screen_card_confirm_cost_panel_test.gd`
(真實 `BattleScreen.tscn`,場景預設真實資料,未設任何 `*_path_override`;`battle_open_hand` / `battle_confirm` 走真實 `_input`)。
載入順序:`instantiate()` -> `get_tree().root.call_deferred("add_child")` -> 等 2 幀。

## 為何是 .tscn 而不是 `-s` 腳本
`-s capture_driver.gd`(extends SceneTree)實測 compile 失敗:`Identifier not found: CursorStateHost`
(`-s` 模式下 Autoload 對被引用腳本尚未註冊)。改為驅動節點掛在 `capture_driver.tscn`,由引擎以主場景啟動,Autoload 已就緒。

## 執行(協調者午休 12:00 後開窗)
```
cd C:/Users/felixfu007/Documents/Claude-Code-Game-Studios
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . res://prototypes/story-020a-confirm-panel-capture-2026-11-19/capture_driver.tscn --audio-driver Dummy
```
(headless 版:加 `--headless`,會印 `HEADLESS: skip capture` 且不寫檔,自行 quit。)

## 預期輸出
- 6 行 `HOSTCHAIN ...`(物證:`WorldViewportContainer` position/size/stretch_shrink、`WorldViewport.size`、`CardConfirmPanel.panel_rect()`)、6 行 `SAVED ...`、最後 `DONE (headless=false)`,行程自行結束。
- headless 實測值(宿主鏈由 `world_viewport_scaler.gd` 算出):
  - 1280x720:WVC pos (160,90) size (960,540) shrink 2,WV (480,270),panel_rect P(376,118) S(528,484)
  - 1920x1080:WVC pos (0,0) size (1920,1080) shrink 4,WV (480,270),panel_rect P(432,56) S(1056,968)
  - 6 態皆 `confirming=true`。
- 開窗後若視窗被作業系統限制尺寸,看 HOSTCHAIN 的 `window=` 是否等於目標;不等就該張作廢。

## Check 分類(依 `coding-standards.md` 截圖分類)
- 全視窗尺寸 -> 非 Category C。
- 面板 `panel_rect()`(真實函式)面積 / 視窗面積:1280x720 = 528x484/921600 = 27.7%;1920x1080 = 1056x968/2073600 = 49.3%,兩者 < 50%,餘為單色遮罩 -> **Category B**(1920x1080 僅差 0.7 個百分點,貼近門檻,Check 5 人眼確認時請一併確認遮罩是否真為單色全覆蓋;若協調者認為遮罩並非全窗單色,則依規定退回 A)。
- B 的檢查:尺寸、盲格+`panel_rect` 目標取樣 >= 3 色、四角+四邊中點遮罩色一致、Check 4 世界層(讀 `WorldViewport` 原生緩衝區;今日世界層無縮放節點 -> 寫 N/A,不得寫通過)、Check 5 人眼。本驅動只產圖,不做 Check 1~4 的自動量測。
- headless 無法取像素(`get_image()` 為 null),故驅動在 headless 跳過寫檔。
