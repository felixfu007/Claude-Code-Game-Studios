# Story 054:行動狀態圖示(鞋 = 已移動、劍 = 已攻擊,做過才出現)+ 做完變暗

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-13,art 補遺已到)—— ⚠️ 兩項小待決不擋開工,但須在對應 AC 處停下回報:「做完變暗」的觸發定義(待 game-designer,見「派工前須確認」1)、DONE 單位被選取時是否恢復亮度(待 ux)
> **Type**: Visual/UI(世界層)+ Logic(顯示規則)
> **Estimate**: M(約 2 天:字元陣列→貼圖 0.5、顯示規則 + 敵方不畫 0.5、變暗 0.25、替換舊小方塊與測試 0.5、補拍/盲測 0.25)
> **依據**:
> - 管理者 2026-11-13 裁決(逐字):顯示 =「**改成「做過才出現」,位置不變(美術總監推薦)**」;變暗 =「**要**」;敵方 =「**不畫**」;左右 =「**鞋左、劍右**」。紀錄:`active.md` 第一百批節(當場查 `grep -n "做過才出現" production/session-state/active.md`;12:0x「還能做的才出現」已被取代,勿用)。
> - 規格(權威):`docs/reviews/art-addendum-icons-contrast-salience-2026-11-13.md` **第 1 節**(取代前份評估 `action-state-icons-sword-shoe-2026-11-13.md` 的位置與「圖示畫在血條之下」建議;該檔其餘仍可參考)。第 2、3 節(首字襯底、可攻擊環加粗)**不屬本單**。
> - 盲測限制:管理者 2026-11-12 裁決「盲測只有我」(當場查 `grep -n "盲測只有我" production/session-state/active.md`)。

## 派工前須確認

1. **「做完」(變暗觸發)定義 —— 實作者先讀 `src/gameplay/battle/turn_order.gd` 的 `is_done`,不採信本單**。lead-programmer 讀到:`is_done(id)` = 「兩個旗標都用掉**或被明確結束(`end_unit_turn`)**」(該函式文件註解逐字)。art 補遺 1.5 寫的觸發是「移動、攻擊都已用」,**與 `is_done` 不完全相同**:被結束但旗標未全用的單位,`is_done`=真、但圖示只會畫已用的旗標。
   - lead-programmer 建議:**變暗以 `is_done`(被結束也算做完)為準** —— 變暗答的是「全場還有誰沒動」(art 前份評估原話),被結束的單位同樣是「不會再動」;圖示則忠實反映旗標(art 補遺 1.3),兩者各管各的。副作用:被結束但沒用旗標的單位會變暗、頭上無圖示,**須 ux/art 確認這不會讓玩家困惑**。
   - 🔴 這是設計判斷,**標為待 game-designer(+ art 確認觀感)**。預設實作 `is_done`;若裁決為「只算兩旗標都用」,改用 `_action_state == DONE` 類四態查詢(`TurnOrder` 的四態 getter,實作者當場找名稱)。AC4 的預言機須隨裁決。
2. **DONE 單位被選取時是否恢復亮度**(art 偏好:選取恢復、停留不恢復;若 DONE 單位本來就不能被選取則題目消失 —— 控制器 `_select_unit_internal` 對 `is_done` 單位回 false,**故預期此題自然消失**,實作者查證並寫入回報)。
3. 圖示與頭像徽章的層序:ux 定,art 偏好圖示在徽章之上;未定前採 art 偏好,回報中明寫。

## 規則(art 補遺第 1 節,32 格版)

- **只畫我方**(`render_pieces` 輸入字典已有 `faction`);敵方不畫、不變暗。
- **做過才畫**:移動旗標已用(`ATTACK_ONLY` 或 `DONE`)→ 畫鞋;攻擊旗標已用(`MOVE_ONLY` 或 `DONE`)→ 畫劍;兩者都用 → 兩個都畫;都沒用 → 不畫。語意沿用現行 `_build_action_flag_marker` 的推導,不改。
- **位置(取代前份評估)**:鞋 6×7,左上 **(0,-7)**,即 x0~5、y-7~-1;劍 5×7,左上 **(27,-7)**,即 x27~31、y-7~-1。頂端在棋子圖頂下 1px(沿用 `ACTION_FLAG_PIP_MARGIN`),底緣 y-1。**落在上方單位血條(x6~25)兩側空檔,零重疊,不依賴圖層順序。** 沿用現行 `ActionFlagLayer`(在 `StatsLayer` 之上),不搬層。
- 像素與色:**用補遺 1.4 的字元陣列逐字**(劍 5×7、鞋 6×7;符號 O/L/G → `metal_outline_01` #26303D、劍 L=`metal_highlight_01` #A9B2BD、鞋 L=`cloth_neutral_highlight_01` #B0A897、G=`cloth_neutral_base_01` #7D766A;全不透明)。實作者不得改像素或色。字元陣列以常數寫在程式內建 `Image` → 貼圖,**啟動時建一次、重複使用**;不用 PNG、不逐像素 `ColorRect`。
- **變暗**:只對**棋子貼圖本身**(`PiecesLayer` 內 Sprite)乘 `modulate = Color(0.65, 0.65, 0.65, 1.0)`(常數,可調 0.60~0.70,盲測定);**alpha 恆 1**。首字與襯底、HP 文字條與血量字、血條、劍/鞋圖示、所有高亮**不暗**。
- 取代並移除現行 `ACTION_FLAG_PIP_*` 兩個 5×5 小方塊。資訊卡「狀態:皆未用/只剩攻擊/只剩移動/已行動」文字行保留(不屬本單)。
- 48 格版(劍 7×9、鞋 8×9、鞋右緣 x7 與劍左緣 x41 不得落入 48 版血條 x 範圍)**不在本單**;48 格改版時另做,補遺已記條件。

## Acceptance Criteria

- [ ] **AC1 顯示表(逐格斷言)**:我方棋子 × {皆未用, 只移動, 只攻擊, 兩者皆做} → 圖示節點集合 = {∅, {鞋}, {劍}, {鞋,劍}};鞋 x 範圍嚴格在劍左側。敵方任何狀態皆 ∅。防空洞:四種狀態集合彼此不同,且至少渲染過一次鞋與一次劍。
- [ ] **AC2 貼圖來源與重用**:兩張貼圖尺寸分別 6×7(鞋)、5×7(劍),像素與色等於補遺 1.4 字元陣列(預言機取自該常數,測試不得另設像素);重畫 100 次貼圖物件 id 不變。
- [ ] **AC3 位置與零重疊**:鞋矩形 = (0,-7,6,7)、劍矩形 = (27,-7,5,7)(取自常數/函式,不寫死在測試);將兩矩形平移 +1 格高(`CELL_SIZE`)後與 `hp_bar_rect_in_cell()` 交集為空(art 指定測法,對應「正上方單位的血條」);與本格 HP 文字條、首字框、被擋章矩形不相交。**不得再出現「蓋血條 30%/45%」之類說法**(該代價因位置改變已不存在)。
- [ ] **AC4 變暗**:觸發依「派工前須確認」1 的裁決;被判定「做完」的我方棋子,**棋子貼圖** `modulate` = `Color(c, c, c, 1.0)`,c = 常數(起點 0.65);首字、HP 文字、血條、圖示、高亮 `modulate` 不變;敵方棋子不變。防空洞:同測試先斷言未做完時為 `Color.WHITE`;且至少含一個「被結束但旗標未全用」的案例,依裁決斷言變暗與否。
- [ ] **AC5 舊小方塊移除**:`grep -rn "ACTION_FLAG_PIP" src/` 零命中(實作者當場跑,貼原始輸出;🔴 不得把搜尋字串寫進被搜尋檔的註解)。
- [ ] **AC6 既有測試調整(逐條說明)**:`tests/integration/ui/action_flag_impassable_terrain_test.gd`、`tests/integration/ui/battle_screen_impassable_terrain_scan_test.gd` 引用舊旗標,實作者讀懂其性質後改為斷言新圖示節點的同一性質,**不得刪斷言換綠**;其他引用當場 `grep -rln "ACTION_FLAG_PIP\|action_flag" tests`。
- [ ] **AC7 敏感度證明**(🔴 一個 mutant 一次獨立執行):①敵方也畫 → AC1 紅 ②鞋劍左右對調 → AC1 紅 ③出現語意反轉 → AC1 紅 ④變暗連血量文字一起暗 → AC4 紅 ⑤貼圖每次重建 → AC2 紅 ⑥圖示 x 位置挪進血條範圍 → AC3 紅。交付前掃殘留注入標記。
- [ ] **AC8 像素層待補拍 + 盲測(管理者本人受測)**:
      - 做法(補遺 1.6):用午休截圖驅動(**載入真實 `BattleScreen`**,宿主鏈物證 log 照第 5 點規則留真實量測值),擺**我方四人縱列真實排法**,四人狀態各不同(全新、只移動、只攻擊、做完),在 **960×540(最嚴苛)** 與 1920×1080 各拍一張。
      - 過關:管理者不看說明、約 3 秒內四人狀態全答對;做完的單位不被當成「陣亡/不能選」;縱列中每人血條長短仍看得出。
      - 🔴 **結論強度**:受測者只有管理者本人且知道此設計,**只證明「他在這個尺寸讀得出」,不證明新玩家讀得懂**;紀錄須明寫「結論強度較低」,並註記將來若有第二位未被告知的受測者請補測。**不得寫成「盲測通過」而不加限定。**
      - 未過:只有變暗未過 → 先調 c 於 0.60~0.70,不整個退回;圖示未過 → 退回「小方塊 + 提示列說明」(須管理者重新裁決)。補遺另載:若只有劍沒過,先試把劍刃上端 `O` 改 `L` 再回 art 判。
      - 像素量測依截圖規則先判類別;Check 4 依 2026-09-23 裁決,圖示為原生貼圖無縮放 → 「沒有可測對象(N/A)」須寫 N/A,不得寫「通過」。人開圖確認 Check 5。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 48 格版圖示與血條寬度條件;敵方回合短暫顯示敵方行動;首字襯底、可攻擊環加粗(補遺第 2、3 節,另案)。

## Affected Files

- `src/ui/battle/board_view.gd`(`render_pieces` 內旗標繪製、貼圖建立、變暗)
- `tests/integration/ui/action_flag_impassable_terrain_test.gd`、`tests/integration/ui/battle_screen_impassable_terrain_scan_test.gd`(調整)
- 新測試檔:`tests/integration/ui/board_view_action_state_icons_test.gd`
- `prototypes/story-054-action-icons-blind-test-<日期>/`(截圖驅動 + log,不進 `src/`)
- 若 `render_pieces` 輸入字典缺「做完」欄位而需動 `battle_screen.gd`,先問

超出此清單先問。

## 與其他工單的順序

主要動 `board_view.gd` 的 `render_pieces`。排在 story-051(同動敵我棋子顯示)之後;與 052、055 同檔,須序列,不可與 055 同批。不依賴 053。
