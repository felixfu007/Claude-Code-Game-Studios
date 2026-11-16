# story-053 結束角色行動按鈕截圖驅動(2026-11-16)

**假設**:禁用態(灰字 + 空心 + 1px 框,無叉叉;管理者 2026-11-16 裁決)在黑白下仍可與啟用態區分,且與「高亮壓框變淡」不混淆。

**執行(開窗,約 15 秒)**:
```
timeout 180 "<Godot console exe>" --audio-driver Dummy --title=x --position 0,0 --path . -s res://prototypes/story-053-end-action-capture-2026-11-16/driver.gd > prototypes/story-053-end-action-capture-2026-11-16/run_output_windowed.txt 2>&1
```
載入真實 `BattleScreen.tscn`;拍 啟用/禁用/啟用+變淡/禁用+變淡 × 960×540、1920×1080,另存按鈕裁切 `crop_*`。headless 下 `get_image()` 為 null 屬正常。

**已知限制**:「變淡」是直接設按鈕 alpha 0.35,不是真的用高亮格壓框。

**狀態**:結案(2026-11-16 12:00 開窗執行,EXIT 0、16 張)。

**發現**:ux(`docs/reviews/lunch-capture-ux-review-2026-11-16.md`)四項目測皆通過;art(`docs/reviews/lunch-capture-art-review-2026-11-16.md`)判禁用灰 (0.5,0.54,0.6) 維持,禁用 + 變淡時字幾乎看不見(短暫態可接受)。
