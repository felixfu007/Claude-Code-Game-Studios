# Story 053:滑鼠「結束角色行動」按鈕 + 結束畫面隱藏空提示底條

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-13,依 ux 定稿與命名/段落序裁決更新)—— 文案與禁用態**已由 ux-designer 定稿**(`docs/reviews/story-053-copy-final-2026-11-13.md`,**第 8 節取代前文**);🔴 兩項【未驗】須實作者落字前實測(AC7),不符停下回報
> **Type**: UI + Logic(按鈕可用狀態、提示列段落序)
> **Estimate**: L-(約 3 天:按鈕 + 禁用三層 + 可用狀態 0.9、矩形 8 em 與 `compact_hint_available_width` 改扣 0.5、提示列段落序與 `controls_hint_content_test` 改寫含敏感度 0.6、兩處實測(✕ 字形/tooltip)0.3、底條隱藏與恢復 0.25、在地化與列數 0.15、測試 0.3)。原估 M(2 天)。
> **依據**:
> - 管理者 2026-11-13 裁決:「**畫面上加「結束行動」按鈕(介面設計師推薦)**」、「**隱藏(介面設計師推薦)**」(結束畫面空底條)、命名「**統一叫結束角色行動**」、段落序「**把它往前移,改成「確認→取消→結束角色行動→移動…」(介面設計師推薦)**」。紀錄:`active.md` 第一百批節(當場查 `grep -n "統一叫結束角色行動" production/session-state/active.md`;找不到以派工訊息為準並於回報註明)。
> - 方案與事實:`docs/reviews/mouse-end-unit-options-2026-11-13.md` 方案 A;文案/禁用態/寬度算術:`docs/reviews/story-053-copy-final-2026-11-13.md`(第 8 節為準,**8 節的寬度是算術不是量測**)。

## 現況(讀自 ux 文件;實作者動工前須自行當場驗證,不採信本單)

- 單位結束行動的 UI 唯一觸發是動作 `battle_end_unit_turn`(鍵盤 Q / 手把 Back)→ `_controller.end_unit_turn(_controller.selected_unit())`;沒選單位時安全拒絕。滑鼠完全沒入口。
- 現有 HUD 按鈕 `_menu_button`、`_hand_button`(`_make_hud_action_button`)皆 `focus_mode = FOCUS_NONE`,靠熱鍵直達;**它們的 disabled 樣式與平常相同**(ux 發現 2),**敵方回合/勝敗不隱藏也不灰化**,只是按下處理被 `phase == PLAYER_INPUT` 擋掉。滑鼠右鍵 = `battle_cancel`(只取消選取)——**不可動**。
- 結束畫面路徑 `_on_battle_ended` 不隱藏 `_controls_hint_bg`;只有 `_fail_load` 隱藏它。
- `compact_hint_available_width`(`hud_layout.gd`)目前只扣到 index 1 那顆按鈕的左緣。

## 規則

1. **命名**:全案統一「結束角色行動」。按鈕啟用 =「結束角色行動」,禁用 =「✕ 結束角色行動」(前綴重用 `battle.menu.disabled_row_prefix_glyph`,切換文字不疊字)。提示列 `strings.csv` 的 `battle.hud.hint.end_unit.keyboard` / `.gamepad`(當場 `grep -n "hint.end_unit" assets/data/locales/strings.csv` 查現行行號;ux 文件記 195/210 行)改值為「結束角色行動 Q」「結束角色行動 Back」。**`end_unit.*` 鍵名、程式與測試內的段落名 `end_unit`、鍵名 Q/Back 皆不改**。
2. **按下 = 與 Q/Back 完全同一路徑**(呼叫同一個處理函式,不得另寫一份結束邏輯)。
3. **焦點(ux 定稿取代舊規則)**:新按鈕 `focus_mode = FOCUS_NONE`,與「手牌」「選單」完全相同(Tab 已是跳目標、方向鍵是棋盤游標,給焦點會互搶)。**不存在「焦點順序」**。三裝置可達 = 滑鼠點、鍵盤 Q、手把 Back,三者結果逐項相同。視覺並排順序:選單 | 手牌 | 結束角色行動(新按鈕 index 2,既有兩顆不位移)。
4. **可用狀態(ux 2.1 逐狀態表為準)**:可按 ⇔ `phase()==PLAYER_INPUT` 且有選取單位,且無出牌進行中/待棄牌/攻擊確認面板/猜測選擇器。其餘禁用。「手牌展開未選牌」以 `is_card_play_in_progress` **實測當下值**為準,**不自行猜**。選單開啟不為此寫規則(樹暫停)。勝敗(FINISHED)禁用且**不給原因句**。載入失敗隱藏(加進既有隱藏迴圈)。選取中的單位必然還能行動,**不為「已做完」設規則**。
5. **禁用三層,缺一不可**:①文字前綴「✕ 」②disabled 外框寬 1(啟用 2),外框與底色不亮於啟用態(色值在既有 `HUD_BUTTON_*` 常數家族內取,不另定色)③`Button.disabled = true` 且無 hover 加亮。🔴 黑白截圖下須能靠「✕」與「外框粗細」看出差異。**不得**用 modulate/透明度當禁用。
6. **原因句**:主通道 `tooltip_text`(滑鼠停留);重用既有鍵 `battle.menu.reason_not_player_turn` / `battle.menu.reason_card_play_in_progress` / `battle.menu.rejection_forced_discard`;新增 1 條無選取句「先選一個單位」。無原因句狀態(啟用、FINISHED)`tooltip_text` 設空字串。**不得複製既有文字**。
7. **寬度與矩形**:新按鈕寬 **8 em**(僅新按鈕;其他兩顆維持 5 em 不動),`hud_action_button_rect` 須能回傳不同寬度的第三顆;啟用/禁用同矩形、**不隨狀態變尺寸**。以「✕ 結束角色行動」最寬態、**用真實 HUD 字型量**(8 em 是 ux 的算術估值,與量測不符以量測為準並回報)。
8. **`compact_hint_available_width` 改為算到「最左那顆按鈕的左緣」**(單一出處,不得在呼叫端另算)。
9. **提示列段落序(只改鍵盤/手把 UNIT_SELECTED,滑鼠不變)**:改為 **確認 → 取消 → 結束角色行動 → 移動 → 跳目標 → 手牌 → 選單**。動 story-045 的 `controls_hint_content.gd` 段落序。其他狀態(NO_SELECTION、ENEMY_PHASE、FINISHED…)與滑鼠 UNIT_SELECTED 序**不動**。本單**不新增提示列字串**,提示列也不為按鈕另加「結束角色行動」說明(滑鼠 UNIT_SELECTED 不加)。
10. **結束畫面隱藏空底條**:`_on_battle_ended` 設 `_controls_hint_bg.visible = false`(與 `_fail_load` 同做法)。🔴 **下一場開始必須恢復可見**——最易漏的邊緣情況,寫成 AC。
11. 新按鈕須加入 ux 2.4 點名的**四處既有清單**,否則會漏:版面迴圈、棋盤蓋住時的變淡(`_set_frame_alpha`)、滑鼠在 HUD 按鈕上的判斷(否則游標/高亮穿過按鈕)、載入失敗隱藏。當場 grep `_menu_button` / `_hand_button` 找全。

## Acceptance Criteria

- [ ] **AC1 三路徑逐項相同**:對真實 `BattleScreen`(載入真實場景檔,注入合成資料):選單位 →(a)點按鈕(b)送 `battle_end_unit_turn` 動作(Q)(c)手把 Back 對應事件 → 該單位結束(`_order.is_done`)、選取清除,**同一組斷言跑三條路徑,結果逐項相同**。補一條:**禁用時按 Q 的既有行為不變**(無選取時安全拒絕、不丟錯)。
- [ ] **AC2 可用狀態表(逐格斷言)**:無選取 / 已選單位 / 敵方回合 / 手牌展開(依實測值)/ 出牌中 / 待棄牌 / 勝敗,各狀態 `disabled`、可見性、**文字(含/不含 ✕ 前綴)**、外框寬(2 vs 1)、`tooltip_text`(對應重用鍵或空字串)符合規則;防空洞:至少一個狀態可按、至少一個不可按,且兩者的**非顏色呈現**(前綴與外框寬)確實不同。
- [ ] **AC3 三裝置可達**:滑鼠點擊觸發 = Q 觸發 = Back 觸發;禁用時三者皆不結束單位。**不測 Tab/方向鍵焦點**(按鈕 `FOCUS_NONE`,斷言這一點本身:`focus_mode == FOCUS_NONE`)。
- [ ] **AC4 版面**:`HudLayout` 新增矩形函式(單一出處)。在 960×540、1366×768、1920×1080、2560×1440、3840×2160:第三顆(8 em)與前兩顆**互不相交**;依 `HudLayout.cell_overlaps_frame` 對 vs01 全部單位起始格不蓋(比照 story-043 測法,**用真實字型/真實矩形量,不估**);「✕ 結束角色行動」放得進該矩形(量文字寬 ≤ 矩形寬扣內縮);`compact_hint_available_width` 等於「提示列起點到最左按鈕左緣」且提示文字不畫到按鈕底下。1080p/4K 邊區為零,按鈕須疊在棋盤上方且不遮單位。算不出零重疊 → 停下回報,不自選位置。
- [ ] **AC5 結束畫面底條**:勝/敗畫面 `_controls_hint_bg.visible == false`;**下一場開始後 `visible == true`**(跑一次真實「結束 → 重開/下一關」流程,不得只測單一方法);防空洞:同一測試先斷言戰鬥中為 true。(戰敗重打流程由 story-056 提供,可與其路徑共用。)
- [ ] **AC6 文案與提示列**:
  1. `strings.csv`:新增 2 列(`battle.hud.end_action_button` = 結束角色行動;`battle.hud.end_action_reason.no_selection` = 先選一個單位);`battle.hud.hint.end_unit.keyboard/.gamepad` 兩條**改值**不增列。🔴 新增 2 列後 `tests/unit/core/i18n/locale_data_integrity_test.gd` 列數斷言同步(當場 `grep -n "is_equal(" tests/unit/core/i18n/locale_data_integrity_test.gd` 取現值,不抄本單)。資料檔副檔名規則:本單不新增資料檔。
  2. `tests/unit/ui/controls_hint_content_test.gd`:原 72/73 行 `contains("結束單位 Q")` / `contains("結束單位 Back")` 改新字樣;🔴 **原 55/64/80 行的「不得含」清單(`_assert_lacks`)原含「結束單位」,必須改成「結束角色行動」**(行號當場 grep 核對 `grep -n "結束單位" tests/unit/ui/controls_hint_content_test.gd`)。只改字串不改這三處,三條斷言會**永遠通過**。**須做敏感度證明**:暫時讓 ENEMY_PHASE / NO_SELECTION 的文字含「結束角色行動 Q」,對應斷言須紅(常駐 `test_sensitivity_proof_*`,一次一個 mutant;證明不了的逐條寫下理由)。
  3. 段落序斷言:鍵盤/手把 UNIT_SELECTED 序為 確認→取消→結束角色行動→移動…;滑鼠 UNIT_SELECTED 序不變(一條斷言鎖住「滑鼠沒被動到」)。
  4. 960/1920/2560 下 UNIT_SELECTED 三裝置的 `fit_text` 結果**含「取消」/「Esc」「B」「右鍵」**與結束角色行動段(鍵盤/手把),並以**刻意縮窄寬度**證明被丟的是最右端段、不是取消。
  5. 全庫 `grep -rn "結束單位" src/ tests/ assets/`(用 `| grep -v ":#"` 避免註解自我命中,範圍排除本單檔)的剩餘命中逐條列於回報:**預期只剩**舊鍵 `battle.hud.controls_hint` 與 `i18n_migrated_strings_test.gd` 的逐字斷言(**不在本單,另案**)與玩法層註解(`commit_authoritative_change_version_test.gd`,不改)。多出來的須說明。
- [ ] **AC7 兩項落字前實測(ux【未驗】,不符停下回報,不自行採用備案)**:①`✕` 在 `HUD_FONT`(Cubic 11)是否有字形(缺字會變豆腐塊)②`tooltip_text` 在 960×540 與 1920×1080 的字型/縮放是否可讀(原生 tooltip 吃預設主題字型,不吃 `HUD_FONT`)。兩解析度實拍,依截圖規則判類別、人開圖確認。若 tooltip 不可讀,**備案(提示列暫換原因句)會新增提示列行為,須回到 ux 與管理者,不得自行採用**。
- [ ] **AC8 敏感度證明**(🔴 一個 mutant 一次獨立執行,常駐 `test_sensitivity_proof_*`,進樹前 `set_script()`):①按鈕處理改成另寫一份結束邏輯 → AC1 紅 ②禁用判定恆 false → AC2 紅 ③禁用態漏掉 ✕ 前綴或外框仍為 2 → AC2「非顏色呈現」紅 ④`_on_battle_ended` 隱藏漏掉 → AC5 紅 ⑤恢復漏掉 → AC5 後半紅 ⑥`compact_hint_available_width` 仍只扣到 index 1 → AC4 紅 ⑦UNIT_SELECTED 段落序退回舊序 → AC6-3/4 紅。交付前掃殘留注入標記。
- [ ] **AC9 像素層待補拍**:960×540 與 1920×1080 各拍:已選單位(按鈕可按)、無選取(按鈕灰化)、勝利畫面(底條消失)、鍵盤 UNIT_SELECTED 提示列(取消與結束角色行動段在、未畫到按鈕底下)。按鈕裁切圖屬 Category C,須用真實矩形函式取樣。人開圖確認灰化態不只靠顏色、不遮敵兵。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 未涵蓋(刻意)

- 「已移動過再點自己毫無反應」的死點擊回饋、右鍵提示句、原地移動誤觸預覽 —— 未經管理者裁決,不在本單。
- 單位動作選單(方案 B)—— 不做。
- 舊鍵 `battle.hud.controls_hint` 與 `i18n_migrated_strings_test.gd` 的「結束單位」逐字斷言 —— 另案(「移除舊鍵 + 該測試」小單)。
- 設計文件 `design/gdd/skill-card-system.md`、`design/ux/tactical-combat-screen.md` 各 1 處「結束單位」—— **屬文件,本單不改**,待協調者請示;`tactical-combat-screen.md` 管理者核可後由 ux-designer 改。
- ux 7 節登記:「選單」按鈕敵方回合點了沒反應(與鍵盤 M 不對等)、「手牌」「選單」禁用樣式與平常相同 —— 範圍外,待 producer 登記。

## Affected Files

- `src/ui/battle/battle_screen.gd`(建立按鈕、可用狀態、禁用三層、tooltip、四處既有清單、`_on_battle_ended` 隱藏底條、新場開始恢復)
- `src/ui/battle/hud_layout.gd`(第三顆矩形函式與寬度、`compact_hint_available_width` 改扣最左按鈕)
- `src/ui/battle/controls_hint_content.gd`(story-045;鍵盤/手把 UNIT_SELECTED 段落序)—— 實際路徑當場 `Glob **/controls_hint_content.gd` 核對
- `assets/data/locales/strings.csv`(新增 2 列、`hint.end_unit.keyboard/.gamepad` 改值)
- `tests/unit/core/i18n/locale_data_integrity_test.gd`(列數)
- `tests/unit/ui/controls_hint_content_test.gd`(72/73 行斷言、55/64/80 行「不得含」清單、段落序、敏感度證明)
- 新測試檔:`tests/integration/ui/battle_screen_end_action_button_test.gd`、`tests/unit/ui/hud_layout_end_action_rect_test.gd`
- 既有 HUD 版面測試(`tests/integration/ui/battle/battle_screen_story_028_minor_hud_test.gd`、story-043 的 `hand_bar_enemy_occlusion_test.gd`)及任何斷言 `compact_hint_available_width` 的既有測試,若斷言隨新增按鈕調整,逐條說明

超出此清單先問。

## 與其他工單的順序

動 `battle_screen.gd`/`hud_layout.gd`/`controls_hint_content.gd`,與 046、056(戰敗重打,同動 `battle_screen.gd`、`strings.csv`)、048、049 須序列。**056 之後**(056 進行中,056 又排在 046 之後),048 之前。AC5 的「重開/下一關」流程可利用 056 已交付的戰敗重打路徑。
