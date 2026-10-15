# U-T8 鍵位探針(2026-10-15)

**Story**: `production/epics/tactical-combat/story-011-input-gaps.md` U-T8 ——
新增一條輸入路徑呼叫 `end_unit_turn(_selected_unit_id)`,依 `P-I2` 須同時有鍵盤/手把可達。

## 假設

在新增 `project.godot` 的新動作前,先問引擎「候選鍵盤/手把鍵目前是否已被任何既有動作
(內建 `ui_*` 或本專案 `battle_*`)佔用」,而不是憑記憶假設它是空的——本專案已登記過
`EPIC.md` 陷阱九那次「以為沒人用、結果手把 Y 已經是 `ui_select` 的預設鍵」的教訓。

## 怎麼跑

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s prototypes/godot-gdscript-specialist-u-t8-key-probe-2026-10-15/probe_end_unit_turn_key.gd
```

原始輸出存於本目錄 `run_output.txt`(協調者代跑,126 行,含 `InputMap.get_actions()`
回傳的全部 98 個既有動作供人工覆核)。

## 結論

| 候選 | 結果 |
|---|---|
| 鍵盤 Backspace | 已被佔用(`ui_text_backspace`、`ui_filedialog_up_one_level`) |
| 鍵盤 Q | **未被佔用** |
| 鍵盤 V | **未被佔用** |
| 手把 Y(上動作鍵) | 已被佔用(`ui_select`)—— 與 `EPIC.md` 陷阱九登記的既有教訓同一個鍵 |
| 手把 Back/Select(button_index 4) | **未被佔用** |
| 手把 Misc1(button_index 15) | **未被佔用**,但部分手把(尤其較舊型號)可能沒有這顆鍵 |

**最終選擇:鍵盤 `Q` + 手把 `Back/Select`(button_index 4)。**

理由:
1. 兩者皆是「連引擎內建 `ui_*` 預設都沒有佔用」的乾淨候選,不像 Backspace/Y 那樣需要
   另外判斷「被引擎佔用算不算衝突」——沒有判斷空間就沒有判斷錯誤的空間。
2. `Back/Select` 比 `Misc1` 更通用:`Misc1` 常對應到部分新款手把才有的額外鍵
   (例如 Xbox Series 的 Share 鍵、PS5 DualSense 的 Mute/Create 鍵),舊款手把可能
   完全沒有這顆實體鍵;`Back/Select`(或 PS 的 Share、Switch Pro 的 `-`)幾乎所有
   支援的手把都有對應實體鍵。
3. `Back/Select` 刻意避開 Y——即使 `ui_select` 在這個專案的 UI(`BattleMenu` 的
   `Button` 列、`HandBar`)目前未必真的接了行為,比照 `ui_select` 是否會觸發
   `BaseButton` 的「次要啟動」這件事本專案從未驗證過,選一個連這個疑慮都不存在的鍵
   不需要再開一次驗證。

## 第二支探針:`probe_hint_width.gd`(提示文字版面是否放得下)

`TEXT_CONTROLS_HINT` 新增「結束單位 Q/Back」這段文字後,是否仍放得進
`HudLayout.controls_hint_bg_rect()` 的既有 2 行版面(`hud_layout.gd` 的
`CONTROLS_HINT_BG_HEIGHT_MULTIPLIER = 3.2` 是 U-016 當時為 2 行字算出的值)——
`hud_layout.gd` 不在本 story 允許修改的檔案清單內,所以答案若是「放不下」,
本 story 無法自行解決,必須誠實回報而非默默硬塞。

呼叫真實的 `HudLayout.font_size()` / `HudLayout.controls_hint_bg_rect()`
(間接呼叫 `WorldLayout.compute_scale()`),不自行重算倍率公式;字串寬度用真實引擎
`Font.get_string_size()`,比照 `prototypes/story-002-font-scale-spike-2026-09-04/`
已建立的量測方式。

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s prototypes/godot-gdscript-specialist-u-t8-key-probe-2026-10-15/probe_hint_width.gd
```

結果(8 個解析度,含 `screen-architecture.md` 登記的「已知未定義」邊界
1366×768/1600×900/2560×1080):**全部 `appended_fits = true`**——加了新段落的第二行
在每個解析度都仍在 `controls_hint_bg_rect()` 的寬度之內,不需要擴成 3 行、
不需要改動 `hud_layout.gd` 的任何常數。最窄的 960×540:新行寬 696px vs 可用寬 864px,
仍有約 168px 餘裕。

## 狀態

**Concluded** —— 結論已用於 `project.godot` 新增 `battle_end_unit_turn` 動作
(鍵盤 Q + 手把 Back/Select),以及 `assets/data/locales/strings.csv` 的
`battle.hud.controls_hint` 文字更新。本目錄為拋棄式探針,不應被正式程式碼引用。
