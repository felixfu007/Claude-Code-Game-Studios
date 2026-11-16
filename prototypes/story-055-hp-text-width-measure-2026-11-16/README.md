# story-055 步驟 1:血量文字寬度量測(拋棄式)

**狀態**:in-progress(headless 已跑通;開窗截圖待協調者執行)

## 假說
預覽字串(含箭頭)在 32px 文字條內被截。檢驗:用真實字型/字級量字串寬,並讀場上實際 HP Label 的 size。

## 執行(開窗)
```
timeout 120 "C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --path . --audio-driver Dummy --title=x --position 0,0 -s res://prototypes/story-055-hp-text-width-measure-2026-11-16/driver.gd > prototypes/story-055-hp-text-width-measure-2026-11-16/run_output_windowed.txt 2>&1; echo EXIT=$?
```
截圖輸出到 `out/`(`960x540_normal.png`、`960x540_preview_30to15.png`、1920x1080 同)。

## 要看的行
`HOST`(真實宿主鏈:WorldViewportContainer position/size/stretch_shrink、WorldViewport.size)、`CONST`、`FONT`、`MEASURE`、`REAL_LABEL`、`SHOT`。

## headless 結果(run_output_headless.txt,EXIT=0)
- 字串寬(Font.get_string_size,字級 8,字型 Open Sans SemiBold):22/22=22、23→7=22、30→15=27、9→0=18、30/30=22、30→30=27;可用寬 32。**全部放得下。**
- 場上實際 HP Label(`30/30`):**size=(43,23)、position=(0,-7.5)**,但 `get_minimum_size()`=(22,12)。父容器(clip)size=(32,8)。
- 兩種視窗大小結果相同(960:stretch_shrink=2;1920:stretch_shrink=4;WorldViewport.size 皆 480x270)。

## 判讀(未驗證成因,待開窗截圖)
字串本身不超寬,但 Label 節點實際 size 寬 43 > 容器 32,且水平置中 → 文字依 43 寬置中,右側落在 clip 外被切。43x23 與 lead-programmer 探針量到的「預設 16px 字型」最小寬吻合,推測是 `label.size` 在 theme 字級覆寫生效前被撐大(程式碼 `label.size = Vector2(32, label.get_minimum_size().y)` 後 size 仍為 43x23)。此為 (C) 推論,僅 REAL_LABEL 數字為 log 物證。

## 已知限制
- headless 下 `get_image()` 為 null(log 會有 `Parameter "t" is null` 錯誤行,屬預期)。
- 場上只有 1 個 HP Label(游標啟用才畫?)。為真實節點,預覽字串以改該 Label 文字模擬(非真實預覽路徑),且未重算 size。
- 探針 Label 的字型取自掛進 board_view 的主題,與 `_build_hp_text` 同為只覆寫 font_size。
- 未走真實預覽路徑(`hp_preview >= 0`)產生 Label。
