# Label 離樹字級覆寫 × size / 最小尺寸 掃描(2026-11-16)

> 只讀掃描,程式未改。範圍:`src/` 全部 `.gd`。作者:lead-programmer。

## 背景
story-055 實測(物證 `prototypes/story-055-label-size-cause-2026-11-16/run_output.txt`、`run_output2.txt`,本掃描未重讀,引用交辦訊息):Label【離樹時】`add_theme_font_size_override` 不影響 `get_minimum_size()`,按預設字型算(例 (43,23));之後設比它小的 `size` 會被撐回,置中文字超出 clip 被切。`LabelSettings` 則正確。

## 搜尋指令(照實)
```
grep -rn "add_theme_font_size_override\|add_theme_font_override" src --include=*.gd | grep -v ":\s*##"
grep -rn "Label.new()\|Button.new()\|RichTextLabel.new()" src --include=*.gd | grep -v ":\s*##" | grep -v ":\s*#"
```
第一條命中 46 行(含 1 行 board_view.gd:1282 是註解,以 `#` 開頭的單 # 註解未被 `##` 過濾排除,已人工剔除)。第二條命中 18 處建構點。再逐處讀上下文判斷「覆寫時是否在樹內」。

## 判斷準則
1. 「離樹覆寫」= 覆寫那一刻,該 Label 或其祖先尚未 add 進已在樹內的節點。
2. 只有「離樹覆寫字級 + 之後 size 被設成小於預設字級最小尺寸的值」才會被切。預設字級 16 px;本專案 `HudLayout.font_size = 11 × N`(N≥2 時 ≥22),即設定字級多半【大於】預設,陳舊最小尺寸偏小,不會撐也不會被切。只有 small_font_size / 0.7 倍字級之類可能 <16 才有風險。

## 逐處清單

### 結論:未找到任何「離樹字級覆寫 + 之後設 size」的實例
所有 `add_theme_font_size_override` 呼叫點,執行時節點都已在樹內:

| 檔案:函式 | 建構位置 | 字級覆寫時是否在樹內 | clip 容器 | 風險 |
|---|---|---|---|---|
| attack_confirm_panel.gd:`_build_label` / `_apply_layout` | 離樹只設【字型】(214);字級在 `_apply_layout`(239),由 `_ready` 呼叫,標籤已在 VBox 內 | 樹內 | 否;VBox 決定尺寸 | 無 |
| card_confirm_panel.gd:`_build_label` / `_apply_layout` | 同上(519/544) | 樹內 | 否 | 無 |
| legend_panel.gd:`_make_label` / `apply_layout` | `_init` 內離樹建構,只設字型(211,71);字級與 size 在 `open()`→`apply_layout`(164-192),此時面板已進樹 | 字級在樹內;僅字型離樹 | name/desc 有 `clip_text=true`(209) | 低(字型離樹但字級在樹內;clip_text 使最小寬≈0)。未驗證:`open()` 是否可能在面板進樹前被呼叫(既有測試未查) |
| hand_bar.gd:`_position_detail_panel`、`_position_count_label`、`_position_caption_and_lock_glyph` | 標籤為 .tscn 的 `@onready`,或 `_ensure_detail_panel` 建後 add;覆寫由 `_apply_layout` 觸發 | 樹內 | 否 | 無(見下方「樹內順序」旁註) |
| battle_screen.gd:1105-1126 guess 按鈕 | `layer.add_child(btn)` 後才覆寫 | 樹內 | 否 | 無 |
| battle_screen.gd:1236/1288 `_relation_toggle_button` | 先 add 到 `$UILayer`,字級在 layout 內且已先換字級再 `update_minimum_size` 再設 size | 樹內 | 否 | 無(已有正確順序與註解) |
| battle_screen.gd:1399-1428 HUD 動作鈕 | 同上,先字級→`update_minimum_size`→size | 樹內 | 否 | 無 |
| battle_screen.gd:1642-1659 `_consistency_label` | 建後立即 add 進 `$UILayer`;字級在 layout | 樹內 | 否 | 無(離樹)。旁註見下 |
| battle_screen.gd:5575 tile info label | .tscn 節點 | 樹內 | 否(`autowrap_mode=0`) | 無 |
| battle_screen.gd:6004-6045 objective / result_detail | 建後先 add 再覆寫 | 樹內 | 否(autowrap 任意字元換行) | 無 |
| battle_menu.gd:1095-1167 列/標籤/按鈕 | 場景或 `_ready` 建好後的 layout;無直接 `size` 設定(用 `custom_minimum_size`/offset) | 樹內 | 否 | 無 |
| hud_layout_scaler.gd:83-86 | .tscn 節點,`_ready` 內 | 樹內 | InfoLabel 有 `clip_text=true` | 無(離樹);旁註見下 |
| title_screen.gd:108/154 | .tscn 節點 `@onready` | 樹內 | 否 | 無 |
| support_conversation_screen.gd:547-548 `_apply_layout` | `_build_nodes` 內全部 add 完才套(須確認 `_apply_layout` 呼叫時機);用錨點非 size | 樹內(未驗證呼叫時機) | 否 | 無/低 |
| board_view.gd:1198 / 1281 | 1281 已用 `LabelSettings`(story-055 修法);1198 無任何字級覆寫 | 不適用 | 1281 在 clip 容器內 | 無(已修) |

## 旁註:另一個同族但機制不同的疑慮(樹內「先 size 後換字級」)
battle_screen.gd 的 HUD 動作鈕在 2026-10-29 已因此被修(程式註解:視窗縮小時先設 size 會被舊大字級最小尺寸卡住)。下列【樹內】Label 仍是「先設 size、後覆寫字級」的順序,且無 `clip_text` / autowrap,視窗由大縮小時理論上同形狀:
- `hud_layout_scaler.gd:_apply_layout`:StatusLabel、ControlsHintLabel、LoadErrorLabel(有 autowrap=3,較不受影響)、ResultLabel(autowrap=1)——`_apply_rect` 先於字級(76-86)
- `battle_screen.gd:_apply_consistency_counter_layout`(1656-1659):`size` 先於字級
- `hand_bar.gd:_position_count_label` / `_position_caption_and_lock_glyph`:`size` 先於字級
- `battle_screen.gd:_apply_objective_layout`:autowrap 任意字元,最小寬小,風險低

風險判斷:中低。這是「縮窗後版面撐住不回縮」而非「文字被切」;**未驗證** Label(非 Button)是否真的會因此卡住——Label 最小寬取決於文字寬(無 autowrap 時),理論上會,但沒有跑引擎量測,也未看是否有現行試玩回報。

## 建議
- **不必開單(離樹字級覆寫)**:全 `src/` 零命中此形狀。story-055 的 board_view 已是唯一實例且已改 LabelSettings。
- **建議開一張低優先小單**(可選):把上面「旁註」那 4 組的順序比照 HUD 動作鈕改成「先字級、`update_minimum_size()`、再 size」,並用視窗由 1920×1080 縮到 960×540 的開窗截圖驗證;動手前先用一支探針確認 Label 真的會卡住(目前為假說)。
- 防再犯(可選):coding-standards 補一句「程式建的 Label 一律用 LabelSettings,或確保進樹後再覆寫字級」——由 lead-programmer 另行提案,本掃描不改文件。

## 未驗證項(逐字)
- 本掃描【未重讀】story-055 的 run_output;機制描述全引自派工單。
- 未跑引擎,所有判斷為讀碼推論。
- legend_panel `open()` 是否可能在進樹前被呼叫:未查呼叫端與測試。
- support_conversation_screen `_apply_layout` 的呼叫時機:未查。
- 預設字級 16 為 Godot 預設,未於本專案主題檔核對是否有自訂預設字級。
- 樹內「先 size 後換字級」對 Label(非 Button)的實際影響:未驗證。
- 只掃 `add_theme_font_size_override` / `add_theme_font_override`;未掃 `theme =` 整組指派、`.tscn` 內 theme_override 屬性與 `RichTextLabel`(程式端 `RichTextLabel.new()` 零命中)。
