# U-016 hint bar fit probe (2026-09-29)

> PROTOTYPE — NOT FOR PRODUCTION / 拋棄式驗證探針
> **執行**：godot-specialist，本機 Godot 4.7.1 headless
> **log**：兩次執行都留存，見下方「RUN 2」「RUN 1」兩節各自指名的檔案。

## 🔴 RUN 2（重測，已解開 RUN 1 異常的位置 vs 尺寸問題 —— 960×540 本身是乾淨的）

**背景**：RUN 1（見下方原始各節）五個解析度依序 960×540、1366×768、1920×1080、
2560×1440、3440×1440 跑，只有**排在迴圈第一個**的 960×540 讀回 `(64, 64)`，
其餘四個全部乾淨。協調者指出「960×540 正是這次量測要回答的問題，不能用其餘四組
代替」，裁決**不先猜成因，先把解析度順序改掉重跑**，把「是不是尺寸的問題」與
「是不是排第一個的問題」分開驗證。

**新順序（`probe_hint_bar_fit.gd` 的 `RESOLUTIONS` 常數）**：
`1366×768`（暖機，數字丟掉）→ `960×540` → `1920×1080` → `960×540`（重複驗證）。
**同時新增**：每次量測前先斷言 `root.size` 讀回值等於設定值，不相等就印
`🔴 READBACK MISMATCH` 但繼續往下跑（不中止）；每一列輸出加上 `[iter=N]` 前綴。
log：`run_output_headless.txt`（本次執行，即本目錄現存的那份，逐字未編修）。

**結果 —— 原始輸出**：

```
[iter=1][1366x768] 🔴 READBACK MISMATCH: SET root.size=(1366, 768) -> READBACK root.size=(64, 64) -- continuing anyway, downstream numbers in this iteration are measuring the READBACK size, not the target
[iter=2][960x540] SET root.size=(960, 540) -> READBACK root.size=(960, 540) (match)
[iter=2][960x540] ITEM1 HudLayout.controls_hint_bg_rect pos=(48.0, 442.6) size=(864.0, 70.4) end=(912.0, 513.0) window=(960, 540) fits_within_window=true
[iter=2][960x540] ITEM2 HudLayout.font_size()=22 label.get_theme_font_size(font_size) readback=22
[iter=2][960x540] ITEM2 per_line_widths(font.get_string_size)=[638.0, 495.0]
[iter=2][960x540] ITEM2 font.get_multiline_string_size(text,width=-1)=(638.0, 54.0) cross_check(font.get_height*line_count)=54.0
[iter=2][960x540] ITEM3 content_height=54.0 bg_rect.height=70.4000015258789 diff(bg-content)=16.4000015258789 overflow=false
[iter=2][960x540] ITEM4 max_line_width=638.0 bg_rect.width=864.0 diff(bg-line)=226.0 window_width=960.0 diff(window-line)=322.0 overflow_bg=false overflow_window=false
[iter=2][960x540] ITEM5 label.clip_text=false label.autowrap_mode=0 label.text_overrun_behavior=0
[iter=3][1920x1080] SET root.size=(1920, 1080) -> READBACK root.size=(1920, 1080) (match)
[iter=3][1920x1080] ITEM3 content_height=104.0 bg_rect.height=140.800003051758 diff(bg-content)=36.8000030517578 overflow=false
[iter=4][960x540] SET root.size=(960, 540) -> READBACK root.size=(960, 540) (match)
[iter=4][960x540] ITEM1 HudLayout.controls_hint_bg_rect pos=(48.0, 442.6) size=(864.0, 70.4) end=(912.0, 513.0) window=(960, 540) fits_within_window=true
[iter=4][960x540] ITEM2 HudLayout.font_size()=22 label.get_theme_font_size(font_size) readback=22
[iter=4][960x540] ITEM2 per_line_widths(font.get_string_size)=[638.0, 495.0]
[iter=4][960x540] ITEM2 font.get_multiline_string_size(text,width=-1)=(638.0, 54.0) cross_check(font.get_height*line_count)=54.0
[iter=4][960x540] ITEM3 content_height=54.0 bg_rect.height=70.4000015258789 diff(bg-content)=16.4000015258789 overflow=false
[iter=4][960x540] ITEM4 max_line_width=638.0 bg_rect.width=864.0 diff(bg-line)=226.0 window_width=960.0 diff(window-line)=322.0 overflow_bg=false overflow_window=false
[iter=4][960x540] ITEM5 label.clip_text=false label.autowrap_mode=0 label.text_overrun_behavior=0
```

**判讀（異常是否重現）**：

- **異常重現的是「排在迴圈第一個位置」，不是「960×540 這個尺寸」。** 這次排第一個的是
  `1366×768`，結果它讀回 `(64,64)`；而排在第二、第四個的**兩次 960×540 完全乾淨**，
  且 `SET root.size=(960, 540) -> READBACK root.size=(960, 540) (match)`。
- **兩次 960×540（iter=2、iter=4）逐項數字完全相同**，可重現：`ITEM3
  content_height=54.0 bg_rect.height=70.4000015258789 diff(bg-content)=16.4000015258789
  overflow=false`（兩次逐字一致）；`ITEM4 max_line_width=638.0 bg_rect.width=864.0
  diff(bg-line)=226.0 window_width=960.0 diff(window-line)=322.0`（兩次逐字一致）。
  **960×540 在兩行提示文字下垂直與水平皆不溢出（`overflow=false`），數字穩定可重現。**
- RUN 1 的「960×540 異常」因此可以更正結論：**壞的不是 960×540，是探針自己迴圈第一次
  呼叫 `_measure_one()` 的那個時間點** —— 不論那個位置放的是哪個解析度，都會出現同樣的
  `(64,64)` 讀回值，以及同樣的字級內部不一致（`HudLayout.font_size()` 算出 11，但
  `label.get_theme_font_size` 讀回 22 —— 這次 iter=1 同樣重現了這個矛盾形狀，與 RUN 1
  逐字相同）。

**成因（初步推測，明文標示未驗證，未再開新的引擎執行去查證 —— 依協調者指示，量測本身
已回合完整，成因查證屬「排在之後」的選用項，本輪回合預算不足以再開一次引擎執行）**：
最可能的解釋是 `_initialize()` 一開始就對 `root.size` 賦值，發生在引擎自己完成開機期
第一次視窗初始化流程**之前** —— 也就是說，第一次 `await process_frame` 讓出的那一幀裡，
引擎自己的開機流程**也**在動 `root.size`（可能把它重置或覆寫成 `Window` 類別的預設
`min_size`，即 `(64,64)`），與我們的賦值競速，而我們的賦值先發生、引擎的開機覆寫後發生，
所以我們讀到的是被覆寫後的值。這**只會發生一次**（第二次以後引擎的開機流程已經跑完，
不會再覆寫），與量到的現象（只有 iter=1 出錯、無論該位置放哪個解析度）完全吻合。
**這是推測，不是驗證結果** —— 沒有為了驗證它另外執行引擎；若之後真的需要生產程式碼依賴
「探針/測試開場的第一次視窗尺寸賦值」這件事，應該另外驗證，不要引用本節的推測當作既定
事實。

**對後續量測的實務建議（登記，不代替管理者裁決）**：任何未來的 headless 探針只要需要
在迴圈中改變 `root.size` 逐一量測多個解析度，**在迴圈正式開始前，先丟一次「暖機」
`root.size` 賦值並等待至少一個 `process_frame`，再進入真正要量的迴圈** —— 本次 RUN 2
正是用這個做法讓 960×540 量到乾淨數字。

---

## RUN 1（原始執行，含未解開的 960×540 讀回異常 —— 歷史紀錄，結論已被 RUN 2 取代）

> log：`run_output_headless_run1.txt`（逐字輸出，未編修）

## 目的

Story U-016 把 `ControlsHintLabel` 的提示文字從一行改成兩行，並把
`HudLayout.CONTROLS_HINT_BG_HEIGHT_MULTIPLIER` 從 2.0 加到 3.2。管理者
2026-09-29 裁決先做 headless 結構量測（矩形、尺寸、字型度量），不做像素量測、
不開窗，再判斷是否需要進一步處理。

## 載入的場景與量測方法

- **場景**：`res://src/ui/battle/BattleScreen.tscn`，逐一 `load()` +
  `instantiate()`，`root.call_deferred("add_child", instance)` 後 `await`
  兩個 `process_frame`，符合 `technical-preferences.md` 第 5 點「量測腳本必須
  `load()` production 真正啟動的那份場景檔」的強制要求 — 沒有另組替身節點鏈。
- **視窗尺寸設定**：`root.size = Vector2i(w, h)`（**不是** `DisplayServer.
  window_set_size()`）— 依 `prototypes/story-010-headless-resolution-probe-
  2026-09-04` 的既有結論：後者在 headless 是靜默 no-op，只有 `root.size`
  真的有效。**設定時機在 `instantiate()` 之前**，讓 `BattleScreen` 的
  `_ready()` 鏈（含 `HudLayoutScaler._ready()` 自己呼叫一次
  `_apply_layout()`）在正確的視窗尺寸下跑。
- **版面數字一律呼叫真實函式，不自行重算**：`HudLayout.controls_hint_bg_rect
  (window_size)`、`HudLayout.font_size(window_size)`，兩者皆為
  `src/ui/battle/hud_layout.gd` 的 `static func`。量完之後**又額外顯式呼叫
  一次** `UILayer` 節點（腳本 `HudLayoutScaler`）的 `_apply_layout()` —— 這是
  呼叫真正的 production 方法本身（非重新實作），理由是不確定 headless dummy
  display driver 底下 `Window.size_changed` 訊號是否真的會在我們手動賦值
  `root.size` 時觸發；`_apply_layout()` 是冪等的，同一視窗尺寸下重複呼叫無副
  作用。
- **文字內容尺寸**：不用字元數估算，改用引擎自己的字型量測 API —— 對
  `label.get_theme_font(&"font")` 拿到的真實 `Font` 資源呼叫
  `get_string_size()`（逐行）與 `get_multiline_string_size()`（整段，含 `\n`
  換行，`autowrap_mode` 現值為 `0`/OFF 時不受 `width` 參數影響，故傳 `-1`）。
  另外用 `font.get_height(font_size) * line_count` 做交叉核對（見下方 log，
  兩者逐解析度數字一致）。
- 每個解析度跑完後 `instance.queue_free()` + 一個 `process_frame`，避免多次
  迭代之間互相污染（例如舊的 `UILayer` 訊號連線殘留）。

## 五項量測 —— RUN 1 原始輸出摘錄（完整見 `run_output_headless_run1.txt`）

```
[1366x768] SET root.size=(1366, 768) -> READBACK root.size=(1366, 768)
[1366x768] ITEM1 HudLayout.controls_hint_bg_rect pos=(68.3, 659.2) size=(1229.4, 70.4) end=(1297.7, 729.6) window=(1366, 768) fits_within_window=true
[1366x768] ITEM2 label.size=(1221.4, 66.40002) label.position=(4.0, 2.0) get_line_count()=2
[1366x768] ITEM2 HudLayout.font_size()=22 label.get_theme_font_size(font_size) readback=22
[1366x768] ITEM2 per_line_widths(font.get_string_size)=[638.0, 495.0]
[1366x768] ITEM2 font.get_multiline_string_size(text,width=-1)=(638.0, 54.0) cross_check(font.get_height*line_count)=54.0
[1366x768] ITEM3 content_height=54.0 bg_rect.height=70.4000015258789 diff(bg-content)=16.4000015258789 overflow=false
[1366x768] ITEM4 max_line_width=638.0 bg_rect.width=1229.40002441406 diff(bg-line)=591.400024414063 window_width=1366.0 diff(window-line)=728.0 overflow_bg=false overflow_window=false
[1366x768] ITEM5 label.clip_text=false label.autowrap_mode=0 label.text_overrun_behavior=0

[1920x1080] SET root.size=(1920, 1080) -> READBACK root.size=(1920, 1080)
[1920x1080] ITEM1 HudLayout.controls_hint_bg_rect pos=(96.0, 885.2) size=(1728.0, 140.8) end=(1824.0, 1026.0) window=(1920, 1080) fits_within_window=true
[1920x1080] ITEM2 label.size=(1720.0, 136.8) label.position=(4.0, 2.0) get_line_count()=2
[1920x1080] ITEM2 HudLayout.font_size()=44 label.get_theme_font_size(font_size) readback=44
[1920x1080] ITEM2 per_line_widths(font.get_string_size)=[1280.0, 996.0]
[1920x1080] ITEM2 font.get_multiline_string_size(text,width=-1)=(1280.0, 104.0) cross_check(font.get_height*line_count)=104.0
[1920x1080] ITEM3 content_height=104.0 bg_rect.height=140.800003051758 diff(bg-content)=36.8000030517578 overflow=false
[1920x1080] ITEM4 max_line_width=1280.0 bg_rect.width=1728.0 diff(bg-line)=448.0 window_width=1920.0 diff(window-line)=640.0 overflow_bg=false overflow_window=false
[1920x1080] ITEM5 label.clip_text=false label.autowrap_mode=0 label.text_overrun_behavior=0

[2560x1440] SET root.size=(2560, 1440) -> READBACK root.size=(2560, 1440)
[2560x1440] ITEM1 HudLayout.controls_hint_bg_rect pos=(128.0, 1192.0) size=(2304.0, 176.0) end=(2432.0, 1368.0) window=(2560, 1440) fits_within_window=true
[2560x1440] ITEM2 label.size=(2296.0, 172.0) label.position=(4.0, 2.0) get_line_count()=2
[2560x1440] ITEM2 HudLayout.font_size()=55 label.get_theme_font_size(font_size) readback=55
[2560x1440] ITEM2 per_line_widths(font.get_string_size)=[1599.0, 1242.0]
[2560x1440] ITEM2 font.get_multiline_string_size(text,width=-1)=(1599.0, 130.0) cross_check(font.get_height*line_count)=130.0
[2560x1440] ITEM3 content_height=130.0 bg_rect.height=176.0 diff(bg-content)=46.0 overflow=false
[2560x1440] ITEM4 max_line_width=1599.0 bg_rect.width=2304.0 diff(bg-line)=705.0 window_width=2560.0 diff(window-line)=961.0 overflow_bg=false overflow_window=false
[2560x1440] ITEM5 label.clip_text=false label.autowrap_mode=0 label.text_overrun_behavior=0

[3440x1440] SET root.size=(3440, 1440) -> READBACK root.size=(3440, 1440)
[3440x1440] ITEM1 HudLayout.controls_hint_bg_rect pos=(172.0, 1192.0) size=(3096.0, 176.0) end=(3268.0, 1368.0) window=(3440, 1440) fits_within_window=true
[3440x1440] ITEM2 label.size=(3088.0, 172.0) label.position=(4.0, 2.0) get_line_count()=2
[3440x1440] ITEM2 HudLayout.font_size()=55 label.get_theme_font_size(font_size) readback=55
[3440x1440] ITEM2 per_line_widths(font.get_string_size)=[1599.0, 1242.0]
[3440x1440] ITEM2 font.get_multiline_string_size(text,width=-1)=(1599.0, 130.0) cross_check(font.get_height*line_count)=130.0
[3440x1440] ITEM3 content_height=130.0 bg_rect.height=176.0 diff(bg-content)=46.0 overflow=false
[3440x1440] ITEM4 max_line_width=1599.0 bg_rect.width=3096.0 diff(bg-line)=1497.0 window_width=3440.0 diff(window-line)=1841.0 overflow_bg=false overflow_window=false
[3440x1440] ITEM5 label.clip_text=false label.autowrap_mode=0 label.text_overrun_behavior=0
```

### RUN 1 的 960×540 異常記錄（歷史 —— 已由 RUN 2 解出「位置問題非尺寸問題」，見上方）

```
[960x540] SET root.size=(960, 540) -> READBACK root.size=(64, 64)
[960x540] ITEM1 HudLayout.controls_hint_bg_rect pos=(3.2, 25.6) size=(57.6, 35.2) end=(60.8, 60.8) window=(64, 64) fits_within_window=true
[960x540] ITEM1b actual node ControlsHintBg.position=(48.0, 442.6) size=(864.0, 70.39999) (post _apply_layout)
[960x540] ITEM2 label.size=(856.0, 66.39999) label.position=(4.0, 2.0) get_line_count()=2
[960x540] ITEM2 HudLayout.font_size()=11 label.get_theme_font_size(font_size) readback=22
[960x540] ITEM2 per_line_widths(font.get_string_size)=[638.0, 495.0]
[960x540] ITEM3 content_height=54.0 bg_rect.height=35.2000007629395 diff(bg-content)=-18.7999992370605 overflow=true
[960x540] ITEM4 max_line_width=638.0 bg_rect.width=57.5999984741211 diff(bg-line)=-580.400001525879 window_width=64.0 diff(window-line)=-574.0 overflow_bg=true overflow_window=true
```

（保留原文供對照 —— 這組數字內部自相矛盾：`ITEM1` 用讀回的 `(64,64)` 算出
`HudLayout.font_size()=11`，但 `ITEM2` 的 `label.get_theme_font_size` 卻讀回 `22`
（那是 `1366×768`／N=2 那組才會出現的字級），暗示 `_ready()` 鏈第一次跑
`_apply_layout()` 時讀到的視窗尺寸與我事後讀回的 `(64,64)` 不是同一個數字。RUN 2
證實：這是探針迴圈第一次呼叫的位置問題，與 960×540 這個尺寸本身無關。）

## 刻意未計入的因素

- **完全未嘗試任何像素讀取** —— headless 下 `get_image()` 恆為 `null`
  （`prototypes/godot-specialist-scene-load-feasibility-2026-09-23` 已證實），
  這不是本次的量測範圍（管理者本輪裁決是「先做結構量測」）。
- **未驗證 `Window.size_changed` 訊號在 headless dummy driver 下是否真的觸發**
  —— 本探針繞過這個不確定性，改為量測後顯式呼叫一次真實的 `_apply_layout()`
  方法本身，不依賴訊號、也沒有重新實作它的邏輯。
- **未量測 `HandBar`、`CardConfirmPanel`、`BattleMenu` 等其他 `UILayer` 子節點**
  —— 與本次任務範圍（`ControlsHintBg`/`ControlsHintLabel`）無關，故未涵蓋。
- **迴圈第一次呼叫讀回異常的真正成因未經引擎驗證** —— 見上方 RUN 2 段落的
  「成因（初步推測）」，已明文標示為未驗證推測，不是既定事實。
- 未對 `label.autowrap_mode` / `text_overrun_behavior` 的整數值轉成可讀的
  enum 名稱（例如 `0` 對應 `AUTOWRAP_OFF` / `OVERRUN_TRIM_NOTHING` 等）——
  僅印出現值本身，轉譯與判定留給協調者。
- **RUN 2 未覆蓋 2560×1440、3440×1440** —— 協調者本輪只指定
  `1366×768→960×540→1920×1080→960×540` 這個順序用來拆解異常成因，
  這兩個解析度的乾淨數字仍以 RUN 1 為準（RUN 1 對它們沒有讀回異常）。
- **未修改 `src/` 底下任何檔案** —— 這是量測任務，不是修正任務。

## 環境事實記錄

- 本機 `godot` 不在 PATH 上，以下為完整路徑（兩次執行皆 `exit code = 0`，
  無殭屍行程，`quit()` 正常走到）：
  `"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s prototypes/godot-specialist-u016-hint-bar-fit-2026-09-29/probe_hint_bar_fit.gd`
