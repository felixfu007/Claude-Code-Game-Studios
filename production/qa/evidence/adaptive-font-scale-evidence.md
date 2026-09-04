# Story 002（screen-scaling:自適應字級規則 + 套用到現有介面元件）測試證據

**Story Type**:UI(閘門等級 ADVISORY)
**日期**:2026-09-04
**執行者**:godot-specialist
**覆核**:協調者(獨立執行測試、獨立打開兩張擷圖)

## AC-S002-a(規則存在且可套用)— 自動化測試涵蓋

`tests/unit/ui/hud_layout_test.gd::test_font_size_matches_expected_value_at_every_defined_resolution`
逐一斷言 1080p/2K/4K/超寬四種螢幕的 HUD 字級為 44/55/88/55px(A 案:
`11 * WorldLayout.compute_scale()`),四者皆有明確數值,沒有現場判斷。

## AC-S002-b(點陣字整數倍)— 自動化測試涵蓋,且已證明「該紅會紅」

`test_font_size_is_integer_multiple_of_glyph_px_at_every_defined_resolution` 斷言
四種螢幕的字級皆為 Cubic 11(11px)整數倍;另一條
`test_font_size_equals_glyph_px_times_world_layout_compute_scale` 斷言
`HudLayout.font_size()` 逐字等於 `HudLayout.GLYPH_PX * WorldLayout.compute_scale()`
—— 這是「必須直接呼叫 `world_layout.gd`,不得複製一份公式」這條紀律唯一驗得到的地方。

### 靈敏度證明(兩輪注入,已還原)

**Run 1** —— 把 `HudLayout.font_size()` 暫時改為 `GLYPH_PX * WorldLayout.compute_scale() + 1`,
15 條測試全部啟用執行:

```
res://tests/unit/ui/hud_layout_test.gd > test_font_size_matches_expected_value_at_every_defined_resolution FAILED 95ms
Expecting: 44 but was 45   (1080p)
Expecting: 55 but was 56   (2K)
Expecting: 88 but was 89   (4K)
Expecting: 55 but was 56   (ultrawide)
Statistics: 1 test cases | 0 errors | 4 failures | 0 flaky | 0 skipped | 0 orphans
Executed test cases : (1/1)
```

只有宣告順序中的第一條測試執行並紅,其餘 14 條**完全沒有執行**——與
`.claude/docs/coding-standards.md` 記載的「一條失敗會中止同 suite 其餘測試」完全一致,
故需要第二輪才能證明 AC-S002-b 專屬測試本身的靈敏度。

**Run 2** —— 同一個 `+1` bug 仍在,暫時把第一條測試改名移出 GdUnit4 收集清單,讓
`test_font_size_is_integer_multiple_of_glyph_px_at_every_defined_resolution` 變成第一條執行:

```
res://tests/unit/ui/hud_layout_test.gd > test_font_size_is_integer_multiple_of_glyph_px_at_every_defined_resolution FAILED 8ms
Expecting: 0 but was 1
Additional info: 1080p: font_px 45 is not an integer multiple of GLYPH_PX 11
Additional info: 2K: font_px 56 is not an integer multiple of GLYPH_PX 11
Additional info: 4K: font_px 89 is not an integer multiple of GLYPH_PX 11
Additional info: ultrawide: font_px 56 is not an integer multiple of GLYPH_PX 11
Statistics: 1 test cases | 0 errors | 4 failures | 0 flaky | 0 skipped | 0 orphans
```

兩輪後皆已還原(`hud_layout.gd` 的 `+1` 移除、測試改名復原),`grep` 兩個檔案確認
零殘留標記,全套測試重跑回到 **386 test cases | 0 errors | 1 failures | 0 flaky |
0 skipped | 0 orphans | 30 suites | exit 100**(與注入前基線一致)。

## AC-S002-c(不超出安全區)— 自動化測試涵蓋 + 真實引擎換行量測

- `test_safe_rect_matches_ac_s002_c_worked_example_at_2560x1440`:逐字對應 AC-S002-c
  自己的範例(2560×1440 → 位置 (128,72)、尺寸 (2304,1296))。
- `test_status_label_rect_is_anchored_at_safe_rect_top_left_at_every_defined_resolution` /
  `test_info_label_rect_sits_right_of_status_label_and_ends_at_safe_rect_right_edge` /
  `test_controls_hint_bg_rect_spans_full_safe_width_and_bottom_edge_matches_safe_rect` /
  `test_load_error_label_rect_equals_safe_rect_at_every_defined_resolution` /
  `test_result_label_offset_rect_stays_within_safe_rect_half_extents`:六個節點的 rect
  全部落在(或緊貼)安全區內。
- 六條回歸基準測試:每個節點算出的框,寬高都必須容得下
  `prototypes/story-002-font-scale-spike-2026-09-04/logs/font_scale_probe_output.txt`
  裡 A 案候選、真實 `Font.get_string_size()` 量到的文字尺寸(960×540/1080p/2K/4K/超寬
  五組),不只是「有算出一個數字」。

### LoadErrorLabel 在 960×540 下換行後的總高度(派工單第五節,第一階段刻意排除、本階段已驗)

`test_load_error_label_wrapped_message_fits_within_rect_height_at_minimum_window`
直接呼叫真實 `assets/fonts/Cubic_11.ttf`、真實 `BattleScreen.load_failure_message()`
(`LoadFailure.MISSING` + 真實 `TERRAIN_PATH`,不是杜撰句子)與引擎的
`Font.get_multiline_string_size()`,在 960×540(font_px=22)實測:

| | 數值 |
|---|---|
| `LoadErrorLabel` 可用框(= `HudLayout.safe_rect()`) | 864.0 × 486.0 px |
| 換行後實際尺寸 | 493.0 × **189.0** px |
| 餘裕 | 486 − 189 = **297px(61%)** |

**撐得住,且餘裕充足** —— 不是壓線通過。

## AC-S002-d(現有元件已套用)— 真實視窗擷圖,人眼已確認

**這一條需要真的開視窗擷取畫面**(headless 沒有渲染目標)。

### 擷取方式

`prototypes/story-002-evidence-capture-2026-09-04/EvidenceDriver.tscn`(拋棄式驅動場景,
**直接載入正式場景 `res://src/ui/battle/BattleScreen.tscn` 本體,不是複本**),以
`godot --path . prototypes/story-002-evidence-capture-2026-09-04/EvidenceDriver.tscn`
執行(真實 GPU、非 headless)。流程:把正式場景掛進 `get_tree().root`、依序
`DisplayServer.window_set_size()` 到兩個目標尺寸、每次等待 15 個 frame 讓
`HudLayoutScaler`/`world_viewport_scaler.gd` 的版面穩定、`get_viewport().get_texture().get_image()`
擷取、存檔。逐字輸出:`prototypes/story-002-evidence-capture-2026-09-04/run_output.txt`。

### 機械檢查(`.claude/docs/coding-standards.md` Screenshot Evidence Rules)

| 檢查項 | 門檻 | 1920×1080 | 2560×1440 | 結果 |
|---|---|---|---|---|
| 擷圖尺寸 = 視窗尺寸 | 逐一相等 | **1920×1080** | **2560×1440** | ✅ 通過 |
| 12 點抽樣相異色數 | ≥ 3 | 4 | 4 | ✅ 通過 |
| 主導色佔比 | ≤ 80% | 43.06% | 38.67% | ✅ 通過 |
| PNG 檔頭實際尺寸(協調者獨立覆核) | 逐一相等 | 1920×1080 | 2560×1440 | ✅ 通過 |

存檔位置:
`production/qa/evidence/adaptive-font-scale-1080p-2026-09-04.png`、
`production/qa/evidence/adaptive-font-scale-2k-2026-09-04.png`。

### 人眼確認(規則第 5 條,機械檢查不能取代)

**已由本 agent 用 Read 工具開圖檢視、並由協調者獨立打開兩張圖檔覆核確認**:

- **`StatusLabel`**(左上角回合狀態):兩張圖裡皆位於安全區左上角,顯示
  「第 1 回合．我方行動」,字型明顯是 Cubic 11 像素字型,不再是引擎預設字型。
- **`ControlsHintBg` + `ControlsHintLabel`**(底部操作提示橫條):兩張圖裡皆回到
  螢幕底部、橫跨安全區全寬,文字「移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵　
  結束回合 Esc/B」完整可讀,**不再縮在左上角一小塊**(對照 Story 001 結案時的
  截圖,那時橫條被壓在左上角 `offset_top=231` 附近的一小塊區域)。
- **世界層(棋盤/單位/血條)**:置中,2K 下可見四周留白(對應 `WorldLayout`
  N=5 的裁決表),與本張無關但確認未受影響。
- **`InfoLabel`**:兩張圖裡皆為空白 —— 這是**預期行為**,不是缺陷。驅動腳本
  沒有送出任何 `InputEvent`,`_cursor_active` 從未變 `true`,`_refresh_view()` 的
  Mode A/B/C 皆不成立,`InfoLabel` 保持空字串。已在
  `production/session-state/screen-scaling-story-002/PROGRESS.md` 列為已知項。
- **`ResultLabel`**:兩張圖裡皆不可見(`visible = false`,battle 未結束)——
  符合預期,無法在這兩張圖裡直接驗證其新尺寸的視覺呈現;其尺寸修正由
  `test_result_label_offset_rect_fits_measured_text_width_and_height` 等自動化測試涵蓋
  (見 AC-S002-c 段落)。

## 6 個節點逐一:改了什麼、現在在哪、與原意圖是否相符

| 節點 | 原失效形狀 | 修法 | 現在的位置/尺寸 | 與原意圖相符? |
|---|---|---|---|---|
| `StatusLabel` | 絕對座標縮到左上角一小塊 | `HudLayout.status_label_rect()`:錨定安全區左上角,寬=安全區寬 30%,高=字級×1.5 | 安全區左上角,隨字級/螢幕縮放 | ✅ 左上角回合狀態 |
| `InfoLabel` | 絕對座標縮到左上角一小塊 | `HudLayout.info_label_rect()`:左邊緊接 `StatusLabel` 右邊(留一個字級高的間距),右邊到安全區右緣 | `StatusLabel` 右側,同一列,延伸到安全區右緣(右對齊文字) | ✅ 緊接其右,同一列 |
| `ControlsHintBg` | 絕對座標縮到左上角一小塊(`offset_top=231` 那個舊 480×270 座標,在大螢幕上只占畫面極小一角) | `HudLayout.controls_hint_bg_rect()`:寬=安全區全寬,底邊貼安全區底邊,高=字級×2.0 | 安全區底部橫條,橫跨安全區全寬 | ⚠️ **相符但有一處刻意偏離規格字面**——見下方「需要協調者確認的設計判斷」 |
| `ControlsHintLabel` | 隨 `ControlsHintBg` 一起縮到左上角 | 不需另外算 rect——`.tscn` 裡 `anchors_preset=15`(填滿父節點 `ControlsHintBg` 整個矩形,含 4/2px 內縮)本身沒問題,只要 `ControlsHintBg` 位置對了就自動跟著對;本張只套用其 Cubic 11 字型/字級 override | 填滿橫條 | ✅ 填滿橫條 |
| `LoadErrorLabel` | 絕對座標縮到左上角一小塊 | `HudLayout.load_error_label_rect()` = `safe_rect()` 本身 | 整個安全區(title-safe 5% 內縮) | ✅ 近全螢幕錯誤訊息 |
| `ResultLabel` | **位置本來就對**(錨點 0.5 置中),問題是固定 160×40 尺寸在大螢幕上小到不成比例 | **只改尺寸,不改位置**——`HudLayout.result_label_offset_rect()` 回傳以錨點為原點的對稱 rect(寬=字級×6、高=字級×2.2),套用時只覆寫 `offset_left/top/right/bottom` 四個值,`anchors_preset`(0.5,0.5,0.5,0.5)完全沒動 | 螢幕正中央,尺寸隨字級縮放(1080p 264×96.8px,4K 528×193.6px) | ✅ 正中央勝敗橫幅,尺寸與螢幕相稱 |

### `ResultLabel` 為什麼不能套用跟其他 5 個一樣的修法

其他 5 個節點的 `HudLayout.*_rect()` 函式回傳的是「相對安全區左上角」的 rect,因為
它們的 `anchors_preset` 在 `.tscn` 裡是 [Control] 預設值 (0,0,0,0)——`offset_left/top`
在該錨點下就是絕對位置。`ResultLabel` 的錨點是 (0.5,0.5,0.5,0.5)(單一置中點),
同一組 `offset_left/top/right/bottom` 在這個錨點下代表「相對錨點的距離」而非
「絕對位置」。如果套用其他 5 個節點的算法(相對安全區左上角的絕對座標),
會把 `ResultLabel` 的錨點語意整個打掉,等同於把它從「置中」改成「左上角」——
這正是規格表明確診斷為「本來就對,不要動」的那一半。因此 `result_label_offset_rect()`
回傳的是「以零點為中心、對稱的 rect」(`position = -size/2`),讓
`offset_left = -halfwidth`、`offset_right = +halfwidth`,在 0.5 錨點下映射回「置中,
尺寸放大」,而不是移動位置。`hud_layout_scaler.gd::_apply_rect()` 對五個節點呼叫的
是同一個函式,差別完全在 `HudLayout` 端算出的 rect 形狀,呼叫端不需要為
`ResultLabel` 寫特殊分支。

## 需要協調者/管理者確認的設計判斷(非規格逐字要求,已主動標記)

**`ControlsHintBg` 改為以安全區(非螢幕物理邊緣)為錨點,而非真正貼齊物理邊緣。**

規格原文是「螢幕底部滿版操作提示橫條」。若逐字理解為「橫條背景貼齊螢幕物理邊緣、
寬度等於整個視窗寬度」,那麼其子節點 `ControlsHintLabel`(用 `anchors_preset=15`
填滿父節點,僅 4/2px 內縮)的文字會落在安全區之外(5% 內縮線以外的區域)——
這會違反 AC-S002-c「文字不超出安全區」的要求,因為安全區存在的目的正是防止內容
碰到物理邊緣,若橫條背景本身貼齊邊緣,安全區保護對它形同虛設。

因此本張把 `ControlsHintBg` 的寬度與底邊都改為對齊**安全區**(而非螢幕物理邊緣)——
橫條仍然橫跨可用寬度、仍然貼近螢幕底部,只是整體内縮了 5%。這是本張唯一一處
偏離規格字面的地方,已於 `src/ui/battle/hud_layout.gd` 的
`controls_hint_bg_rect()` doc comment 記錄理由,現在再次於此標記,供管理者確認
是否需要改為「背景貼物理邊緣、僅文字內縮」的替代做法(該替代做法技術上可行,
但需要 `ControlsHintLabel` 改用相對視窗而非相對父節點的錨點計算,是一次額外的
版面判斷,故本張未預先假設管理者會選它)。

## 場景檔靜態內容 vs. 執行期實際版面(協調者覆核提出,已回答)

**現象**:直接讀 `BattleScreen.tscn`,`StatusLabel`/`InfoLabel`/`ControlsHintBg`/
`ResultLabel` 的 `offset_*` 仍是 Story 001 結案時記錄的舊 480×270 座標數字
(例:`ControlsHintBg` 的 `offset_top=231.0`),**不是**執行期實際呈現的位置。

**這是刻意的設計,理由是本專案已有兩個完全同形狀的既有先例,採用第三種不同做法
反而會製造不一致**:

1. `StatusLabel` 的 `text = "Round 1 | PLAYER phase"`——一個英文佔位字串,
   在 `BattleScreen._ready()`/`_update_status_label()` 執行後**必定**被覆寫成
   `TEXT_STATUS_FORMAT` 格式化出的中文文字,`.tscn` 裡的字面值從未在真實遊玩中出現過。
2. `WorldViewportContainer` 的 `anchors_preset`——`world_viewport_scaler.gd` 自己的
   doc comment 明文記載該節點的 `anchors_preset=15` 是「retired canvas_items 時代的
   殘留」,腳本的 `_ready()` 會呼叫 `set_anchors_preset(Control.PRESET_TOP_LEFT)`
   無條件覆寫掉它。

`hud_layout_scaler.gd` 對這 5 個節點的 `offset_*` 做的是同一件事:`_ready()`
與每次 `size_changed` 都無條件覆寫。已在該檔 doc comment 新增一段,明確點名
這是延續上述兩個既有先例的**同一套慣例**(在執行覆寫的腳本裡記錄「這些字面值
會被覆寫」),而不是引入第三種做法(例如把 `.tscn` 裡的數字歸零,或在 `.tscn`
本身加註解——Godot 的 `.tscn` 格式不支援可靠的行內註解,零值則會讓場景在
`_ready()` 尚未執行的情境下呈現為完全不可見而非「小但可見」,兩種呈現同樣會
讓人誤讀,零值不比舊數字更誠實)。

**取捨**:打開編輯器看到的數字確實不反映執行期版面,但這與 `StatusLabel` 的
英文佔位字串是同一種、本專案已經接受的權衡——真值來源在程式碼與其 doc comment,
不在 `.tscn` 的字面值。若管理者認為這個權衡在 UI 版面座標(相對於純文字佔位符)
的情境下風險更高、值得引入新的標記機制,這是一個待裁決的規範問題，超出本張的
實作範圍。

## 已知未涵蓋

- 只驗證 AC-S002-d 點名的兩種視窗(1080p/2K),不含 4K / ultrawide / 最小視窗
  960×540 的實機擷圖(這四種的 rect 數學由自動化測試涵蓋,見 AC-S002-c 段落,
  但沒有對應的真實擷圖人眼確認)。
- 不驗證真人拖曳視窗邊框改變尺寸的路徑(沿用既有 spike 的一貫揭露)。
- 對話正文字型仍未選定,不阻擋本張(`story-002-adaptive-font-scale.md` 自身已載明)。
- `InfoLabel` 三種預覽模式(Mode A/B/C)在新版面下的實際文字排版未經擷圖驗證
  (需要真人操作或注入 InputEvent 才能觸發,超出本張的擷圖驅動能力範圍)。
