# Story 041:修正血量數字與棋子首字/敵兵編號互相重疊(story-039 回歸)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)
> **Type**: Logic + UI(世界層)
> **Estimate**: S
> **優先序**: 畫面可讀性批次 T1 —— **最優先,先做**(今天 story-039 引進、管理者眼前可見的回歸)
> **依據**:
> - 管理者 2026-11-12 核准畫面可讀性工單範圍,選項逐字「**修今天的字重疊 + 介面 + 重做高亮層次 + 圖例(UX 專家推薦)**」
>   (= `docs/reviews/screen-readability-ticket-plan-2026-11-12.md` 選項 2)。
> - 管理者 2026-11-12 就 T1 修法裁決,選項逐字「**血量數字移到血條旁,跟首字上下分開(UX 專家推薦)**」
>   (= 計畫第二節 T1 的「方案乙」)。被跳過:方案甲(游標停留時隱藏首字框)。
>   紀錄:`production/session-state/active.md` 第九十九批節(grep「重做高亮層次」)。
> - 缺陷證據:`docs/reviews/screen-readability-verified-art-2026-11-12.md` 新發現 1 與第二節第 3 項;
>   `docs/reviews/screen-readability-verified-ux-2026-11-12.md`。圖:`prototypes/readability-capture-2026-11-12/out/` 的
>   `00_960x540_01_open.png`(藍10/30)、`21_1920x1080_02_selected_ranges.png`(董2/22)、`12_1440x810_03_...`(敵兵 3「318/18」)。
> - art-director 自承其樣式文件 `docs/reviews/piece-initial-label-style-2026-11-12.md` 第 1 節的「HP 文字在格底」假設是錯的
>   (實機 HP 條在格頂)。**該文件的避讓座標不得再當依據**,以本單 AC 與實測為準。

## 為什麼

story-039 在每個棋子格左下(格內 y 8~22、x 0~12)畫了姓名首字/敵兵編號。血量文字條畫在**格頂**(格內 y 1~11、整格寬 32),
兩者在 y 8~11 垂直重疊,且血量文字置中、字形跨到左側 x 0~12。凡 `show_hp_text` 為真的單位(游標停留、選取、傷害預覽)字都疊在一起。

## 現況幾何(lead-programmer 2026-11-12 讀 `src/ui/battle/board_view.gd` 所得,格 32×32,座標為格內)

| 元素 | 矩形 | 來源 |
|---|---|---|
| 首字/編號 Label | x 0~12、y 8~22(含 1px 描邊) | `PIECE_LABEL_SIZE` / `PIECE_LABEL_TOP_OFFSET_IN_CELL` |
| 血量文字襯底 + Label | x 0~32、y 1~11 | `HP_TEXT_TOP_MARGIN` / `HP_TEXT_HEIGHT`(10)、`_build_hp_text()` |
| 血條 | x 6~26、y 26~29 | `HP_BAR_WIDTH` / `HP_BAR_HEIGHT` / `HP_BAR_BOTTOM_MARGIN` |
| 動作旗標小方塊(常駐) | 棋子圖右上、格上緣之外 | `ACTION_FLAG_PIP_*`(與本單無關,**不得被新文字壓到**) |

🔴 **算術前提(實作者必須先自己驗,不要採信本表)**:首字底(y 22)與血條頂(y 26)之間只剩 **4px**,放不下 10px 高的文字條。
故「移到血條旁」**不是改一個常數**,必須在下列方向中擇一並在回報中寫出算術:
(a) 文字條放在血條**下方**/與血條合併成一個底部區塊(血條上移或文字放進條內),
(b) 文字放在首字**右側**(x 12~32、y 8~22,寬 20px,需實測「22/22」「22→15」在 8px 字下放不放得下),
(c) 其他自行提出的版面。**無論哪種:首字 Label 的位置、大小、樣式一律不動**(那是 art-director 在 story-039 定的;要動它須先問,
不得為了讓出空間自行改 `PIECE_LABEL_*`)。

⚠️ **歷史陷阱(不先查會白做)**:`_build_hp_text()` 的註解寫明,血量文字**當初從格底搬到格頂**,是因為格底的字被 y=231 的操作提示列
切掉一半(第 5 列棋子),而被切掉的恰是傷害預覽數字。**任何落在格底的新位置,實作者須先實測第 5 列棋子在 960×540 與目前 HUD 版面下是否又被切。**
若無法在不被切、不重疊的前提下實現「血量在血條旁」:**停下來回報(附算術與實測),不得自行退回方案甲**(管理者已跳過甲;退回是新裁決)。

## Acceptance Criteria

- [ ] **AC1 版面規則(可測)**
      `BoardView` 的首字 Label 矩形、血量文字矩形(襯底與 Label)、血條矩形,三者在任何 `show_hp_text` 為真的單位上**兩兩不相交**,
      且全部落在 32×32 格內(血量文字與血條不得伸進棋子圖上緣超出格頂的 8px 區,那裡是動作旗標小方塊的帶)。
      實作方式:把三個矩形收斂成 `BoardView` 內**單一出處**的函式(例如 `static func hp_text_rect_in_cell()` 等),
      **`_build_hp_text()` / `_build_hp_bar()` / `_apply_piece_label()` 自己就呼叫它們來定位**,不得另存一份常數複本
      (專案已登記「同一公式兩份實作」失效模式)。
- [ ] **AC2 預言機不得為重言式**
      測試**不得**只斷言「函式回傳的三個矩形不相交」(它們同出自一處,改壞版面常數時會一起漂移而仍綠)。
      須另有一條測試對**實際渲染出的節點樹**(`render_pieces()` 之後走訪 `_stats_layer` 與首字 Label 池,取各節點 `position`/`size` 換算為格內座標)
      斷言不相交。兩條各自為何不是空洞,寫進測試檔頭。
- [ ] **AC3 涵蓋四種 HP 文字狀態**
      對下列四種各一條斷言不重疊:一般 `hp/hp_max`、傷害預覽 `hp→hp_preview`(琥珀色)、`card_target_illegal` 為真(襯底 alpha 0.90)、
      我方與敵方各一(首字寬度不同:漢字 vs 數字)。**防空洞**:測試須斷言這四種各實際渲染了血量 Label(否則「沒畫就不重疊」會綠)。
- [ ] **AC4 既有契約不變**
      `HP_TEXT_BG_COLOR` / `HP_TEXT_BG_COLOR_TARGET_ILLEGAL` 的值與「整條襯底一起變深」規則不變
      (`design/art/hp-readout-contrast-fix.md`,2026-09-23 管理者裁決);`tests/integration/ui/card_target_selection_test.gd`
      以「襯底高度 == `HP_TEXT_HEIGHT`」辨識襯底 —— **若新版面改了襯底高度,同步更新該測試的辨識方式並在回報說明**,不得讓它因找不到節點而空轉為綠。
      首字顯示規則(story-039 AC)不變,`battle_screen_unit_name_and_piece_initials_test.gd` 全綠。
- [ ] **AC5 敏感度證明**(🔴 一個 mutant 一次獨立執行;GdUnit4 第一個失敗斷言會中止同檔後續測試)
      至少:①把血量文字矩形移回舊位置(格頂 y 1~11) → AC2 紅 ②把首字 Label 的 y 位移改回與血量文字相交 → AC2 紅
      ③`_build_hp_text()` 改成不呼叫單一出處函式(自帶舊常數) → AC1 一致性測試紅。
      守衛類用常駐間諜子類別形式(`.claude/rules/test-standards.md`),**不得手動注入後忘記還原**;交付前掃描殘留注入標記。
- [ ] **AC6 像素層待補拍(非單元測試門檻)**
      960×540、1440×810、1920×1080 各一張「游標停留我方單位」與「游標停留敵兵」(共 6 張):首字/編號與血量文字不重疊、血量數字完整可讀、
      **第 5 列單位的血量文字未被操作提示列切到**。截圖須依 `coding-standards.md` 截圖證據規則先判類別;由人開圖確認。
      ⚠️ 960 的驅動須真的讓游標落在目標格(上一輪 960 兩張為無效證據,見計畫第三節第 1 項)。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行
      (CLAUDE.md 2026-10-12 硬性義務;協調者會自行重跑)。

## 未涵蓋(刻意)

- 首字在筆畫多的字(藍/董/麥/徐)糊成灰團 → 延後 D3,待 48 格棋子到位後放大實機確認。
- 48 格改版後的座標重算:本單只保證**版面分區邏輯與單一出處**,48 格時只改常數(`design/art/art-suite-48-640x360-2026-11-12.md` 為草稿)。
- 棋子頭部超出棋盤上緣(D4)。
- 動作旗標小方塊(B1)的尺寸問題。

## Affected Files

- `src/ui/battle/board_view.gd`(`_build_hp_text` / `_build_hp_bar` / `_apply_piece_label` 的定位、新增矩形單一出處函式與常數)
- 新測試檔:`tests/integration/ui/board_view_hp_text_label_layout_test.gd`
- 可能需小改:`tests/integration/ui/card_target_selection_test.gd`(僅當襯底高度改變,見 AC4)
- (`battle_screen.gd`、首字樣式 `PIECE_LABEL_*` 預期**不需**修改;要動先問。)

超出此清單先問。

## 與其他工單的順序

與 T5(story-044 高亮層級)**同檔 `board_view.gd`,須序列**:本單先。T5 的「框線不得壓字框區」會引用本單的首字矩形單一出處函式。
