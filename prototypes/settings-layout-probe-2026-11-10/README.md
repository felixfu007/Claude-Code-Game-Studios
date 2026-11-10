# SettingsScreen 版面探針 2026-11-10

假說:加入三條音量滑桿後,寫死約 320x300 的面板在 960x540 / 1920x1080 下內容溢出。
狀態:concluded。
執行:`timeout 60 <godot_console> --headless --path ../.. -s res://prototypes/settings-layout-probe-2026-11-10/probe.gd`
原始輸出:`run_output_headless.txt`(同目錄)。

方法:probe.gd `load()` 真實 SettingsScreen.tscn,instantiate,`root.call_deferred("add_child")`,等 2 個 process_frame。
`root.size` 設值於 headless 生效(輸出 `actual root.size=(960, 540)` / `(1920, 1080)`)。

## 結論 (A) 級,不溢出(結構層)
- 兩種解析度:Panel 皆 320x300(置中),內容最小高度 217 < 300,所有子控制項 inPanel=true、inWindow=true。
- 最下方葉節點 BackRow:960x540 下 y 306~337(面板底 420);1920x1080 下 y 576~607(面板底 690)。
- 面板餘裕約 83px 高;最小內容 217 對 300。

## 限制 (C)
- headless 取不到像素,只量結構;目視仍需在家。
- 量測當下 Label 文字可能尚未填入/字型為 headless 預設;真實中文字型與較長譯文會改變行高與 Label 寬(Label 最小寬 90 固定,滑桿吃剩餘寬度)。
- 面板在 stretch=disabled 下於 960x540 約佔視窗 1/3 寬,未做縮放;非本探針範圍。
