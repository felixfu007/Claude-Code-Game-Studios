# Story 055:傷害預覽血量字被截(「23→7」最後一字被裁)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: 🔴 **Blocked(2026-11-13)—— 步驟 1 量測可先做;步驟 2 修法若動三帶版面,須 art-director + ux-designer 先選修法**(選項見下)
> **Type**: Visual/UI(世界層);story-041 後續
> **Estimate**: S~M:步驟 1 開窗量測 S(0.25~0.5 天);步驟 2 修法 S(縮字級/去箭頭,約 0.5 天)或 M(改兩行/動三帶,約 1.5~2 天)
> **依據**:
> - `docs/reviews/lunch-capture-code-facts-2026-11-13.md` 第 3 項:午休截圖 02 號圖人眼可見文字條內為「23→」+ 被切一半的「7」;判定為常態性 bug(兩位數對兩位數如 `30→15` 更長更嚴重)。
> - 上游:`production/epics/tactical-combat/story-041-hp-text-vs-piece-label-overlap.md`(三帶版面算術:文字條 y0~8、首字、血條)。

## 事實與未驗證項(動工前須知)

- 預覽字串 `board_view.gd` 約 1174~1176 行 `"%d→%d"`;字級 `HP_TEXT_FONT_SIZE = 8`;文字條 `hp_text_rect_in_cell()` = `Rect2(0,0,32,8)`;Label 外包 `clip_contents` 容器。
- 041 檔內註解自稱實測「22/22 = 22px、22→15 = 27px」,放得進 32px;**截圖直接反證**。lead-programmer 探針(headless、未帶遊戲主題)量得 `Label.get_minimum_size()` 寬:`22/22` 43、`23→7` 44、`30→15` 53、`9→0` 35,全部 > 32,**但探針高度與註解不符 → 字型環境不同,數字不是 (A) 級**。
- 成因推測(**未驗證**):Label 最小寬 > 32 時被引擎夾回、置中失效、右側被 `clip_contents` 切掉。
- 現有測試 `board_view_hp_text_label_layout_test.gd` 只驗節點幾何,headless 不 rasterize,抓不到。

## 步驟 1(先做,不需等裁決):開窗量實際字寬

- 寫拋棄式量測(放 `prototypes/`),**載入真實 `BattleScreen.tscn`**(依 technical-preferences 第 5 點物證規則,原始 log 要留真實宿主鏈量測值:`WorldViewportContainer` 的 position/size/stretch_shrink 與 `WorldViewport.size`),在 960×540 與 1920×1080 開窗,對 `22/22`、`23→7`、`30→15`、`9→0`、`30/30`、預覽最長情境,讀 Label 的**實際渲染寬**與文字條可用寬。
- 回報:每個字串「實際寬 / 32」與是否被截;**沒有 log 的結論降為 (C)**。步驟 1 結果決定步驟 2 要不要動三帶。
- 若量測顯示只有預覽字串(含箭頭)過寬而常態 `22/22` 不截 → 範圍縮小到預覽路徑。

## 步驟 2 修法選項(須 art-director + ux-designer 先選,實作者不自選)

| 修法 | 內容 | 動三帶版面? | 優點 | 缺點 |
|---|---|---|---|---|
| **甲 去箭頭** | 預覽改「23 7」之類(以顏色/符號區隔)或只顯示結果值「→7」/「7」 | 否 | 最小改動 | 預覽語意變弱,「不只靠顏色」須另想辦法;ux 須同意文案 |
| **乙 縮字級** | 預覽時字級降(例 8→6) | 否 | 不動版面 | Cubic 11 點陣 6px 難讀,art 須驗;與 `22/22` 字級不一致會跳 |
| **丙 兩行** | 預覽兩行顯示(現值 / 預覽值) | **是**:文字條高 8→16,擠首字/棋子圖區 | 資訊完整可讀 | 動 041 三帶算術;48 格改版前不宜大動 |
| **丁 預覽值移出棋子** | 預覽字改畫在資訊卡/游標旁小浮標 | 否(棋子上不再有預覽字) | 棋子上最乾淨 | 與資訊卡(story-048)面板位置/框語言耦合,須序列在 048 後 |

lead-programmer 傾向:**甲或乙(不動三帶),量測後再說**;丙只在量測證明甲乙都不夠時才選。此為建議,非裁決。

## Acceptance Criteria

- [ ] **AC1 量測物證**:步驟 1 的 log 附在 `production/qa/evidence/`,含真實宿主鏈量測值與每字串的實際寬;結論標證據等級並附腳本路徑(缺路徑降 (C))。
- [ ] **AC2 不截字**:修後 `22/22`、`30/30`、`23→7`、`30→15`、`9→0` 與預覽最長情境,在 960×540、1920×1080 開窗實測**實際渲染寬 ≤ 文字條可用寬**(或所選修法的新可用寬),**用真實字型量,不得估算**。人開圖確認每個字元完整可見(依截圖規則先判類別;文字條裁切屬 Category C,取樣點由真實矩形函式推出)。
- [ ] **AC3 防回歸測試(非僅幾何)**:新增一條測試用 `Label` 真實最小寬/`Font.get_string_size` 與文字條可用寬比較,對 hp_max 上限(30)的最壞預覽字串斷言放得下;**資料取自真實常數**(`HP_TEXT_FONT_SIZE`、`hp_text_rect_in_cell()`),預言機不得自設。headless 取不到 rasterize,故本條只證「字寬 ≤ 容器」,**像素層證據仍靠 AC2 開窗**,兩者都要,測試檔頭須如實揭露「不證渲染結果」。
- [ ] **AC4 041 契約不退化**:`board_view_hp_text_label_layout_test.gd` 與 041 全部既有測試全綠;若修法改了三帶(丙),逐條說明哪些斷言隨之改、為何不是換綠。
- [ ] **AC5 敏感度證明**(🔴 一個 mutant 一次獨立執行):①字級改回舊值/預覽字串改回含箭頭長格式 → AC3 紅 ②Label 寬度設定放大超過容器 → AC3 紅。交付前掃殘留注入標記。
- [ ] **AC6 說明註解更正**:board_view.gd 內 story-041「22/22 = 22px…放得下」的註解宣稱,依量測結果改為真實數字或刪除(該註解已被截圖反證);註解內不得含會自我命中的搜尋指令。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 乙(徐培恩)首字對比(art-director 決定,另案)。
- 48 格改造後的文字條重算(改版時一起)。

## Affected Files

- `src/ui/battle/board_view.gd`(`_build_hp_text`、常數、註解)
- 修法丙/丁才可能涉及 `src/ui/battle/battle_screen.gd`(資訊卡)—— 先問
- `tests/integration/ui/board_view_hp_text_label_layout_test.gd`(路徑當場 `ls tests -R | grep hp_text_label` 確認)
- 新測試檔:`tests/integration/ui/board_view_hp_text_width_test.gd`
- `prototypes/story-055-hp-text-width-measure-<日期>/`(步驟 1 腳本 + log,不進 `src/`)

超出此清單先問。

## 與其他工單的順序

動 `board_view.gd`;若選修法丁則與 `battle_screen.gd`(048)耦合。步驟 1 可隨時插入(不改既有檔);步驟 2 排在 story-054 之前或之後皆可,但**不可與 054 同批**(同動 `render_pieces`/文字層,042/044 已有衝突前例)。
