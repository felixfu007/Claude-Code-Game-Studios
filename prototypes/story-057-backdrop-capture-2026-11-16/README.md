# story-057 首字襯底截圖驅動(2026-11-16)

拍**真實實作**(`BoardView` 的 `PieceLabelBackdropLayer`),不用 ColorRect 模擬;載入真實 `BattleScreen.tscn`,
骨架取自 `prototypes/label-backdrop-compare-2026-11-13/driver.gd`。兩狀態(overview 無游標 / cursor_xu 游標停徐培恩)x 960x540 / 1920x1080。

開窗執行(截圖寫入 `out/`):
`Godot_v4.7.1-stable_win64_console.exe --path . -s res://prototypes/story-057-backdrop-capture-2026-11-16/driver.gd`

目前只做過 headless(`run_output_headless.txt`):跑通、TOTAL shots=4,headless 取不到像素故無 PNG;
宿主鏈量測值(WVC position/size/stretch_shrink、WorldViewport.size)已留在 log 的 HOST 行。
**開窗像素與 AC2 像素層、AC7 人眼確認尚未做**(協調者開窗)。

## 2026-11-16 AC2 像素層退回後的查證(協調者開窗發現游標格首字底被「洗淡」)
- `probe_cursor_cover.gd` / `probe_output.txt`(headless):游標在徐培恩 (0,3) 時,襯底節點 visible、位置 (32,143)、size 12x14、modulate 白、
  color (0.0549,0.0588,0.0784,0.72),層序 `PieceLabelBackdropLayer`(idx11) < `PieceLabelLayer`(12) < `ActionFlagLayer`(13) < `CursorSprite`(14)。
  **襯底節點沒有被隱藏或移位。**
- 成因:`CursorSprite` 的貼圖 `cursor_outline.png` 中心像素 = (1,1,1,**0.149**)(白色 15% 填色,32x32 整格),畫在最上層,
  把襯底與首字一起疊亮。`probe_pixels.gd` / `probe_pixels_output.txt`(讀協調者開窗截圖 1920x1080):
  襯底左上角內側像素 徐 有游標 0.282,無游標(overview 同位置)0.157;藍 有游標(overview)0.251,無游標 0.122 —— 同一個襯底,游標在上時亮約 +0.13~0.17。
  結論:不是襯底沒畫,是游標填色疊在其上,對比被削弱(首字白底差變小)。
- 驅動現會在 log 印 `BACKDROP_PX` 行(游標格與非游標格的襯底角像素)供開窗比對。
