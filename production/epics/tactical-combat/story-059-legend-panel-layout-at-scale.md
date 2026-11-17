# Story 059:圖例面板在各解析度下的版面修正(圖示錯位、列距過擠)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-17)—— 鞋/劍示範併入本單:管理者 2026-11-17 約 12:20 裁決「一起修(主程式推薦)」(紀錄 `production/session-state/active.md` grep「一起修(主程式推薦)」)。⚠️ 鞋/劍**本身的尺寸**另由 art 提放大方案再決(同日裁決),本單圖例示範沿用 BoardView 現行常數,日後放大自動同源。(原狀態:Draft —— 「派工前須先決定」一項待裁決後轉 Ready)
> **Type**: UI(版面幾何)+ Visual(開窗實拍)
> **Estimate**: S~M(約 1 天:修成因 0.25、幾何測試與預言機 0.25、常駐敏感度證明 0.25、四解析度開窗實拍 0.25;若含鞋/劍示範列加 0.25~0.5)
> **依據**:story-047(`f877533`)開窗實拍缺陷。證據圖:`prototypes/lunch-capture-2026-11-17/out/15_1920x1080_s047_legend_open.png`(嚴重)、`06_960x540_s047_legend_open.png`(較輕仍擠);美術審 `docs/reviews/lunch-capture-art-review-2026-11-17.md` 第 3 節。

## 缺陷

1920×1080 下,每列「標題+說明」兩行文字與左側圖示錯位:圖示偏右下、文字壓在圖示上、列與列之間無空隙。960×540 較輕但同樣擠。047 自動測試全綠。

## 成因(lead-programmer 讀碼推得;未經引擎重跑)

**主因(讀碼加算術,與截圖座標吻合,但未開窗量測驗證)**:圖例面板假設範例節點的圖示區原點是 `LEGEND_SAMPLE_ORIGIN = (0, 8)`,實際 `BoardView.build_legend_sample()` 把底磚與標記畫在 `BoardCoords.grid_to_local_center(Vector2i.ZERO)`,而該函式含 `BoardCoords.BOARD_ORIGIN = (32, 39)`(`grep -n "BOARD_ORIGIN" src/ui/battle/board_coords.gd`;`grep -n "grid_to_local_center(cell)" src/ui/battle/board_view.gd` 的 `build_legend_sample` 段)。面板端只擺 `sample.position = LEGEND_SAMPLE_ORIGIN * iscale`(`legend_panel.gd` `apply_layout()`),**沒有扣掉棋盤原點**。結果圖示實際畫在圖示區原點再加 `(32,39) * iscale`:1080p(iscale=2)為 (+64, +78) px。
對照截圖:左欄圖示左緣約 x=160 = 安全區 96 + 64;文字起點 `text_x = x + icon_w + fpx*0.5` = 96+64+22 = 182 —— 圖示(160~224)與文字(182 起)重疊,與截圖一致。960×540(iscale=1)為 (+32,+39),圖示區寬 32、文字從 +43 起,圖示畫到 +64,同樣重疊,只是較輕。

**次因(讀碼,同樣未開窗驗證)**:`apply_layout()` 的 `row_h = max(fpx*2, 40*iscale)` 恰為兩行字高,名稱/說明 Label 各高 `fpx` 且無任何行距或列間距;1080p 實測列距 = 88 px = 2×44,文字像素塊逐行相接 → 「擠成一片」。圖示再偏下 78px 後,同列圖示與下一列文字相疊。

**不是**:Label 離樹字級覆寫導致最小尺寸錯(story-055 那一型)—— 本面板的 Label 都用顯式 `size`,位置/大小與截圖列距吻合,沒有證據指向該型。

## 為什麼 047 的測試沒抓到(`tests/integration/ui/legend_panel_test.gd`)

- `test_ac4_layout_fits_window_and_text_fits_label_at_all_sizes` 只驗:Label 矩形被視窗包住、字串寬 ≤ Label 寬、內容區被視窗包住。**從未比較任何兩個矩形互不相交**(文字 vs 圖示、列 vs 列),也**從未取圖示實際畫出的範圍**。
- `test_ac2_*` 只驗圖示節點是否等於 `BoardView.build_legend_sample` 的輸出、整數倍、顏色常數 —— 驗**內容與縮放倍率**,不驗**位置**。
- 即「圖示位置」與「圖示實際像素範圍」這兩個量,整份測試檔沒有一條斷言碰過;`LEGEND_SAMPLE_ORIGIN` 的常數正確性只靠註解宣稱。結構測試全綠、幾何錯,正是 coding-standards 所說「假設是錯的、測試只證明沒壞掉」。

## 規則

- **圖示位置單一出處**:面板擺位須由 `BoardView`/`BoardCoords` 提供的「範例實際外框」推得(例如 `BoardView` 暴露範例相對於其根節點的實際像素外框,面板據此對齊到圖示區左上),**不得另寫死偏移常數**;`LEGEND_SAMPLE_ORIGIN` 若保留,其值須由同一出處算出而非手填。
- **列高含間距**:`row_h` 須明確大於兩行字高(留列間距,數值為版面常數,依字級 N 倍數取整);名稱與說明之間亦須有可辨識的行距。
- **文字起點** = 圖示區右緣 + 明確間距,圖示區寬取實際外框寬(含縮放),不取 32 的假設值。
- 單位:所有字級仍走 `HudLayout.font_size`、倍率仍走 `WorldLayout.compute_scale`(不複製公式)。
- 視窗放不下時(列數 × 列高 > 安全區高):不得縮到重疊。行為由實作者提案、先問(可選:縮圖示倍率、增欄數、或 `row_h` 降到最小可讀值但仍不重疊)。

## Acceptance Criteria

- [ ] **AC1 幾何互不相交(核心)**:對 960×540 / 1280×720 / 1920×1080 / 2560×1440 四個尺寸,圖例每一列:①名稱 Label 矩形、說明 Label 矩形、圖示實際外框三者**兩兩不相交**;②相鄰列之間(同欄)名稱/說明/圖示矩形**互不重疊**;③所有矩形被安全區包住。預言機取真實版面函式(`apply_layout()` 的結果、`HudLayout.safe_rect()`、`BoardView` 的範例外框),不另設座標。圖示實際外框以「範例子節點全部圖形矩形的聯集 × 縮放 + 擺位」算出,**不用 `LEGEND_SAMPLE_SIZE` 假設值**。
- [ ] **AC2 文字落在圖示區右側**:每列文字矩形的左緣 ≥ 圖示實際外框右緣 + 間距常數;間距常數單一出處、測試讀同一常數。
- [ ] **AC3 開窗像素實拍(只能開窗)**:真實 `BattleScreen`(第 5 點規則,log 留 `WorldViewportContainer` 的 position/size/stretch_shrink 與 `WorldViewport.size`),四個尺寸各一張圖例開啟截圖,存 `production/qa/evidence/`。截圖類別先判:圖例為全視窗遮罩 → 以 `panel_rect`/`content_rect()` 面積判 Category B(內容區 <50%)否則 A;Check 4 為「沒有可測對象(N/A)」,須寫 N/A 不得寫「通過」。
- [ ] **AC4 常駐敏感度證明(一個 mutant 一次執行)**:`test_sensitivity_proof_*` 形式(間諜/突變子類別,於 `add_child()` 前 `set_script()`,**先 `set_script()` 再設任何屬性**,見 test-standards 陷阱一),至少:①圖示不扣範例原點偏移(重現本缺陷)→ AC1 紅 ②`row_h` 降回 `2*fpx` 無間距 → AC1 ②紅 ③文字起點回到 `x + 32*iscale` → AC2 紅 ④只在 960×540 正確、1920×1080 偏移(以尺寸相依的錯誤)→ AC1 逐尺寸紅。不可證者逐條寫理由。交付前掃殘留注入標記。
- [ ] **AC5 既有測試不退**:`legend_panel_test.gd` 既有斷言一條不刪;AC4 舊測試可保留並補,不得換綠。
- [ ] **AC6 Check 5 人眼確認**:管理者開四張圖確認「每列讀得出、圖示與文字不重疊」。受測者只有管理者本人,紀錄須寫此限定。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 🔴 派工前須先決定:鞋/劍符號示範是否併入本單

**問題**:美術審指出圖例「已移動」「已攻擊」兩列沒有示範棋子角落真正會出現的鞋/劍符號(目前圖示是方塊/棋子剪影,看不出符號長什麼樣),讀者無法把圖例對回棋盤上的實物。

**推薦:併入本單**。理由:①兩者改的是同一組範例建構(`BoardView.build_legend_sample` 的 `ACTION_MOVED` / `ACTION_ATTACKED` 分支)與同一個面板擺位;分開做會讓幾何測試與實拍做兩次。②本單的「實際外框」預言機本來就要重算這兩列的範例外框,順手讓範例畫出真實角落符號成本小(約 +0.25~0.5 天)。③風險:符號範例畫在棋子角落,外框含棋子與符號,AC1 的外框聯集要涵蓋它 —— 做在本單內,測試一次到位。
**不併入的代價**:兩列繼續誤導,另開單再動同一段並重拍。**若不併入**,本單 AC 不變,另開 story-060 專做符號示範。
範例必須**呼叫與棋盤同一組建構函式/常數**(047 的明文要求),不得在圖例另畫。符號形狀/位置的對錯屬美術判斷,實作前須先確認 `art-director` 對「示範列怎樣算正確」的描述。

## 未涵蓋(刻意)

- 圖例內容集合、文案、開關與輸入攔截(047 範圍,不動)。
- 其他面板的版面。

## Affected Files

- `src/ui/battle/legend_panel.gd`(`apply_layout()`、常數)
- `src/ui/battle/board_view.gd`(僅:暴露範例實際外框的單一出處;若併入符號示範則含 `build_legend_sample` 兩分支)
- `tests/integration/ui/legend_panel_test.gd`(補測);新測試檔 `tests/integration/ui/legend_panel_geometry_test.gd`
- `prototypes/story-059-legend-layout-evidence-<日期>/`(開窗驅動 + log + 截圖,不進 `src/`)

超出此清單先問。

## 與其他工單的順序

- 依賴 story-047 已併入(`f877533`);與 story-058(可攻擊環加上邊)同動 `attack_ring_rects_in_cell()` 的圖例範例:058 先做則本單外框自動含上邊,不衝突;順序不限,但同檔(`board_view.gd`)不同批。
