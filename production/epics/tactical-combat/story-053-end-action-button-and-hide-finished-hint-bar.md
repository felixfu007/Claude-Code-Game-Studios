# Story 053:滑鼠「結束行動」按鈕 + 結束畫面隱藏空提示底條

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-13)—— 🔴 **按鈕文字與提示列新增字樣須 ux-designer 覆核後才落字串**(見 AC6)
> **Type**: UI + Logic(按鈕可用狀態)
> **Estimate**: M(約 2 天:按鈕 + 可用狀態 0.75、焦點/手把可達 0.5、底條隱藏與恢復 0.25、在地化 0.1、測試 0.5)
> **依據**:
> - 管理者 2026-11-13 裁決,逐字「**畫面上加「結束行動」按鈕(介面設計師推薦)**」與「**隱藏(介面設計師推薦)**」(結束畫面空底條)。紀錄:`active.md` 第一百批節(當場查 `grep -n "結束行動」按鈕" production/session-state/active.md`)。
> - 方案與事實:`docs/reviews/mouse-end-unit-options-2026-11-13.md` 方案 A、第四節、第六節(方案 C 已撤回:點自己 = 原地移動,不可改)。

## 現況(讀自 ux 文件;實作者動工前須自行當場驗證,不採信本單)

- 單位結束行動的 UI 唯一觸發是動作 `battle_end_unit_turn`(鍵盤 Q / 手把 Back),`battle_screen.gd` 約 2653 行 → `_controller.end_unit_turn(_controller.selected_unit())`;沒選單位時安全拒絕。滑鼠完全沒入口。
- 現有 HUD 按鈕:`_menu_button`、`_hand_button`(`_make_hud_action_button`);滑鼠右鍵 = `battle_cancel`(只取消選取)——**不可動**。
- 結束畫面路徑 `_on_battle_ended`(約 5450 行)不隱藏 `_controls_hint_bg`;只有 `_fail_load` 隱藏它。

## 規則

1. 新增 HUD 按鈕「結束行動」,與選單/手牌並排,走同一個建立函式與同一套焦點機制(滑鼠點、游標/手把焦點皆可到達;鍵盤 Q、手把 Back 保留不變)。**按下 = 與 Q 完全同一路徑**(呼叫同一個處理函式,不得另寫一份結束邏輯)。
2. **可用狀態**:有選取單位且該單位仍可行動 → 可按。其餘(無選取、敵方回合、手牌/選單開啟、勝敗)→ **灰化且不可按**。🔴 **不得只靠顏色**:灰化同時要有形狀/文字層次的差異(例:disabled 時文字改為帶括號或加鎖形,具體由 ux 在 AC6 定;**實作者不自選**),並讓滑鼠停留或焦點到時,提示列顯示原因(「先選一個單位」)。
3. **敵方回合與勝敗期間**按鈕隱藏或灰化由 ux 定(建議隱藏,與選單/手牌現行行為對齊,實作者先查它們現在怎麼做並照辦)。
4. **結束畫面隱藏空底條**:`_on_battle_ended` 設 `_controls_hint_bg.visible = false`(與 `_fail_load` 同做法)。🔴 **下一場開始(重開局/下一關進入)必須恢復可見** —— 這是最易漏的邊緣情況,寫成 AC。

## 與 story-045 提示列的關係

045 已落地(`278fb77`):提示列依狀態與裝置顯示相關按鍵。本單**不新增提示列狀態**,但:
- 滑鼠裝置、`UNIT_SELECTED` 狀態的片段,是否加「結束行動」字樣(說明可點按鈕,而非 Q)—— **須 ux 覆核**。lead-programmer 建議:**不加**,因為按鈕本身可見、有字,加字會擠掉其他片段(story-045 AC4 寬度退路是依段落位置丟尾段,加字等於把「取消/選單」往外擠)。若 ux 要加,須先驗 960×540 `compact_hint_available_width` 下不擠掉「取消」(ux 先前已提過取消優先)。
- 鍵盤/手把片段保留現有 Q / Back 字樣,不變。
- `docs/reviews/mouse-end-unit-options-2026-11-13.md` 第六節建議的「已選單位時補一句『右鍵=取消選取(動作不會復原)』」**不在本單範圍**(未經管理者裁決),如要做另開單。

## Acceptance Criteria

- [ ] **AC1 滑鼠可結束**:對真實 `BattleScreen`(載入真實場景檔,注入合成資料):選單位 → 點按鈕 → 該單位結束(`_order.is_done`)、選取清除;與按 `battle_end_unit_turn` 動作的結果**逐項相同**(同一組斷言跑兩條路徑)。
- [ ] **AC2 可用狀態表(逐格斷言)**:無選取 / 已選單位 / 敵方回合 / 手牌開啟 / 選單開啟 / 勝敗,各狀態按鈕的 `disabled` 與可見性符合規則;防空洞:至少一個狀態可按、至少一個不可按、且兩者的**非顏色呈現**(文字或形狀)確實不同。
- [ ] **AC3 三裝置可達**:鍵盤焦點(Tab/方向鍵)與手把焦點能移到按鈕並以確認鍵觸發;滑鼠點擊可觸發。禁用時三者皆不觸發。(焦點鍊測法比照 `_menu_button`/`_hand_button` 現有測試。)
- [ ] **AC4 不蓋棋盤、不擠既有按鈕**:`HudLayout` 新增一個矩形函式(單一出處),在 960×540、1366×768、1920×1080、2560×1440、3840×2160 與 `_menu_button`/`_hand_button` 矩形互不相交,且依 `HudLayout.cell_overlaps_frame` 對 vs01 全部單位起始格不蓋(比照 story-043 的測法,**用真實字型/真實矩形量,不估**);1080p/4K 邊區為零,按鈕必須疊在棋盤上方且不遮單位。算不出零重疊 → 停下回報,不自選位置。
- [ ] **AC5 結束畫面底條**:勝/敗畫面 `_controls_hint_bg.visible == false`;**下一場開始後 `visible == true`**(跑一次真實的「結束 → 重開/下一關」流程斷言,不得只測單一方法);防空洞:同一測試先斷言戰鬥中為 true。
- [ ] **AC6 文案覆核**:按鈕文字、禁用態呈現、提示原因句,字串走 `assets/data/locales/strings.csv`,**落字前由 ux-designer 覆核**;實作者不得自擬。新增列後 `tests/unit/core/i18n/locale_data_integrity_test.gd` 列數斷言同步(當場 `grep -n "is_equal(1" tests/unit/core/i18n/locale_data_integrity_test.gd` 取現值)。🔴 資料檔副檔名:本單不新增資料檔;若新增一律 `.txt`。
- [ ] **AC7 敏感度證明**(🔴 一個 mutant 一次獨立執行):①按鈕處理改成另寫一份結束邏輯(不走同一處理函式)→ AC1「兩路徑逐項相同」紅 ②禁用判定恆 false → AC2 紅 ③`_on_battle_ended` 隱藏漏掉 → AC5 紅 ④恢復漏掉 → AC5 後半紅。交付前掃殘留注入標記。
- [ ] **AC8 像素層待補拍**:960×540 與 1920×1080 各拍:已選單位(按鈕可按)、無選取(按鈕灰化)、勝利畫面(底條消失);依截圖規則先判類別(按鈕裁切圖屬 Category C,須用真實矩形函式取樣)。人開圖確認灰化態不只靠顏色辨識、不遮敵兵。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 「已移動過再點自己毫無反應」的死點擊回饋、右鍵提示句、原地移動誤觸預覽 —— ux 文件第六節建議,**未經管理者裁決**,不在本單。
- 單位動作選單(方案 B)—— 不做。

## Affected Files

- `src/ui/battle/battle_screen.gd`(建立按鈕、可用狀態、`_on_battle_ended` 隱藏底條、新場開始恢復)
- `src/ui/battle/hud_layout.gd`(按鈕矩形函式)
- `assets/data/locales/strings.csv`
- `tests/unit/core/i18n/locale_data_integrity_test.gd`(列數)
- 新測試檔:`tests/integration/ui/battle_screen_end_action_button_test.gd`、`tests/unit/ui/hud_layout_end_action_rect_test.gd`
- 既有 HUD 版面測試(`tests/integration/ui/battle/battle_screen_story_028_minor_hud_test.gd`、story-043 的 `hand_bar_enemy_occlusion_test.gd`)若斷言隨新增按鈕調整,逐條說明

超出此清單先問。

## 與其他工單的順序

動 `battle_screen.gd`/`hud_layout.gd`,與 046(選單入口按鈕,同區域)、048、049 須序列。建議 **046 之後**(046 改選單入口,按鈕排版要在它定案後排),048 之前。
