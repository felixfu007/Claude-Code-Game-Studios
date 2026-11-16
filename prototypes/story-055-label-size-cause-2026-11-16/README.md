# story-055 血量文字 Label 尺寸成因探針(2026-11-16)

**假設**:傷害預覽「30→15」被切,不是字太長,而是 Label 節點被撐得比 32px 文字條寬。

**執行**:`godot --headless --path . -s res://prototypes/story-055-label-size-cause-2026-11-16/probe.gd`(probe2.gd 同)。

**狀態**:結案。

**發現**(原始輸出見 `run_output.txt` / `run_output2.txt`):Label 離樹時 `add_theme_font_size_override` 不影響 `get_minimum_size()`,最小尺寸按預設字型算成 (43,23),之後設 `size=(32,…)` 被撐回 43 寬,置中後右端出 clip。改用 `LabelSettings` 後 min=(22,12)、size=(32,12)。修法已進 `src/ui/battle/board_view.gd`(story-055);開窗複驗 `../story-055-hp-text-width-measure-2026-11-16/run_output_windowed_after_fix.txt`。全專案同形狀掃描:`docs/reviews/label-offtree-size-scan-2026-11-16.md`(無其他實例)。
