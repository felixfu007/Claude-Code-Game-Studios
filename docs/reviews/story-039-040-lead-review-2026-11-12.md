# story-039 審查 + story-040 驗收條件審查(lead-programmer,2026-11-12)

> 範圍:只讀碼與跑測試,未改任何程式或工單。凡未實際讀碼/跑過者標「未驗證」。

## 一、story-039 審查

### 結論:可提交(附 3 條建議,皆不擋提交)

**我自己跑的證據(不採信回報)**
- 全套 `run_tests_with_import.sh`(含匯入):`ENGINE EXIT = 0`、`WRAPPER EXIT = 0`、
  `Overall Summary: 2020 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans`、
  `Executed test suites: (192/192)`。
- ⚠️ 該次全套總時間 `5min 54s`,與先前紀錄的 94 秒差 4 倍。本機負載會浮動,**我無法歸因於 039**,
  也沒有跑 039 前的基線對照 —— 「測試時間是否被 039 拖慢」**未驗證**。

**① 程式品質與架構**
- 姓名鍵拼接:實測 `character.name.%d` 現有寫法共 **4 處**(`battle_screen.gd` 戰敗名單、`relation_minimap.gd`
  `NAME_KEY_FORMAT`、`support_conversation_screen.gd` `SPEAKER_NAME_KEY_FORMAT`,加本單的 `player_display_name()`)。
  本單新增的是第四處,**不該在本單內收斂**(要動另外三個檔,超出 Affected Files)。
  建議:另開小工單,在 Loc 層(`src/core/i18n/`)加一個 `character_name(id)`,四處改呼叫它。
  本單的 `player_display_name()` 是單一出口,日後收斂只改這一個函式內部,不會再擴散。
- `build_tile_info_text` 加預設參數 `occupant_id = -1`:作為過渡**可接受**,保住既有呼叫端與既有測試。
  代價:正式路徑只剩 `>= 0` 一條,舊的「純陣營行」分支變成只有測試會走的死碼;而且 040 若再加第三個預設參數,
  這個簽章就開始發臭。建議:040 **不要**再往這個函式加參數(見下節),待兩單都落地後另開清理單把 id/code_name 改為必填。
- 敵兵編號從 `code_name` 解析:真實名冊是 `E1`/`E2`/`E3`…(已讀 `vs01_roster.txt`),而格式約定**只存在於這個
  解析函式裡**。容錯做得對(`push_error` + 退回舊行,沒用 `assert`,符合 release 匯出規則)。
  長期應由資料層提供欄位(`Unit.display_number` 或名冊多一欄),但那要動名冊格式與解析,**不屬本單,建議登記為技術債而非現在修**。
  現狀的風險:名冊把敵人改名(如 `Bandit_A`)時,畫面會安靜退回舊行並在 log 留 `push_error`,不會崩潰 —— 可接受。
- 小瑕疵(不擋):`locale_data_integrity_test.gd` 的列數註解把「163 → 165」插在「159 → 163」那行之上,
  時序顛倒,讀的人會困惑;功能無影響。

**② 效能結論是否成立:不成立為「已證明」,但結構上合理**
- 我重跑 `prototypes/piece-label-perf-2026-11-12/bench.gd`:`ENGINE EXIT = 0`,
  `no_label runs=[3694.8, 3477.1, 5907.8]`、`with_label runs=[3489.5, 6427.5, 8888.4]`、`median overhead = 74.0%`。
- 這組數字**不能拿來證明任何方向**:同一條件三次重複就差到 1.7~2.5 倍(with_label 最低 3489 比 no_label 最低 3477 幾乎相等,
  最高卻 8888),代表機器負載雜訊大於要量的差異;中位數的 74% 是雜訊,不是訊號。
  另外,基線本身 10 個棋子 × 100 次 = 37ms/次也偏高,說明這支微基準量到的主要是環境,不是標記字。
- 結構論證(讀碼得出,**非實測**):池化後每次重畫對每個標記只做 `text`/`position`/`visible` 賦值與一次參照比對,
  不新建節點(bench 輸出 `stats_layer nodes` 前後皆 52,池節點不隨重畫增長);Label 的 `text` 賦同值在引擎端應短路,
  故預期重畫成本增量接近零。這與「第一版每次新建 Label 才是 27→41 秒主因」的診斷方向一致。
  **「接近零」是推論,需要一個不受雜訊干擾的量法才能升格。**
- 建議(不擋提交):若要留下可信的效能結論,改用「同一程序內交錯跑 A/B、取最小值或多次中位數」,
  或乾脆只斷言「池節點數不隨重畫增長」(結構性斷言,不受負載影響)。

**③ 是否可提交:可以。** 條件:無須先修。已核對的另兩點:池節點置於 `StatsLayer` 之後、旗標層之前(`move_child`),
疊序合理;`render_pieces` 末尾把多餘池節點隱藏而非釋放,測試 `_piece_labels_in` 只計 visible,與之對得上。
**未驗證**:開窗像素層(字位置、描邊、與 HP 條是否遮擋)—— 工單與測試檔頭已明言留給目視,我同意。

## 二、story-040 驗收條件審查

### 結論:AC 方向正確,但有 1 個會讓實作者走錯路的歸屬錯誤、2 個缺漏,須修改後再派工

**依據:實際讀碼**
- `BattleController._attack_targets_for()`:攻擊合法的外層閘門是 ①`_phase == PLAYER_INPUT` 且有選取
  ②`_order.can_attack(unit_id)`(`TurnOrder.can_attack` = 單位屬現行陣營、未 done、攻擊旗標未用)
  ③`BattleState.can_attack()`(存活+敵對+`is_attack_reachable` → `CombatRules.is_attack_legal`)。
- `CombatRules` 已有 `is_in_range` / `is_attack_legal` / `is_attack_blocked_by_los`(後者是「範圍內被視線擋」的互補半,
  註解已寫明三態互斥)。`BattleState` **沒有** `TurnOrder` —— `TurnOrder` 住在 controller。
- `battle_screen.gd` 現況:選定單位 + 游標在 `attack_targets().cells` 內的敵兵 → 傷害預覽並 early return;
  其餘落入「單位資訊」分支。040 的新行應只掛在「落入單位資訊分支、且為敵兵、且有選取」的情況。

**問題與修改要點**

1. 🔴 **歸屬錯誤(AC1)**:工單寫「狀態原因(本回合已攻擊)放 `BattleState`」。**`BattleState` 不持有 `TurnOrder`,
   做不到。** 正確分層:
   - `CombatRules`:新增純函式,例如 `attack_block_reason(from, to, min_range, max_range, is_occluding) -> AttackBlockReason`,
     只回 `NONE / OUT_OF_RANGE / TOO_CLOSE / LOS_BLOCKED`。判斷以 `is_in_range` + `is_attack_blocked_by_los` 組合,
     區分過近/過遠只能比較距離,而 `_manhattan_distance` 是 `CombatRules` 自己的私有函式,在這個類別內呼叫合乎「不重算」。
   - `BattleController`:新增查詢(例如 `attack_block_reason_for(target_id)`),**複製 `_attack_targets_for` 的外層閘門**
     (phase、無選取、`_order.can_attack`)再委派給 `BattleState`→`CombatRules`。「已攻擊」歸這一層。
   - UI 只讀這個查詢,不自己判斷。
2. **漏的原因(AC1 的「四種原因是否涵蓋全部」)**:`_order.can_attack` 為假有兩種成因 —— 攻擊旗標已用,
   以及單位被 `end_unit_turn` 標為 done(`unit_action_state == DONE`)。`TurnOrder` 的攻擊旗標是私有字典,
   controller 外要區分得新開 API。**建議不區分**:合併為單一原因 `ACTION_SPENT`,文字用「本回合已無法再攻擊」,
   避免對「已結束行動」的單位誤說「已攻擊」。另外 phase 非 `PLAYER_INPUT`、或選取的不是可行動方時,
   應回「不適用」(不顯示該行),AC2 需寫明。
3. **優先序(工單完全未寫)**:多種原因同時成立時只顯示一個,規定:
   `ACTION_SPENT` > `TOO_CLOSE` / `OUT_OF_RANGE`(兩者互斥)> `LOS_BLOCKED`。理由:前者是整個單位的狀態,
   去移動/換位也解決不了;`LOS_BLOCKED` 只在「已在射程帶內」時才成立(`is_attack_blocked_by_los` 的定義),
   所以不可能與射程類原因並存,實際只需要排 `ACTION_SPENT` 在最前。AC 內明文寫下並加一條測試。
4. **AC1 的一致性測試寫法**(現行寫法只說「多組輸入,含四種原因各一」,有空洞風險):
   - 預言機(oracle)必須是既有函式:對掃過的所有 `from/to/min/max/遮蔽樣式`,斷言
     `(reason == NONE) == CombatRules.is_attack_legal(...)`,**且** `(reason == LOS_BLOCKED) == CombatRules.is_attack_blocked_by_los(...)`。
     測試內**不得**自己算曼哈頓距離或視線。
   - 防空洞:測試須統計掃描中四種原因各出現至少 1 次,否則失敗(避免輸入集恰好沒覆蓋某原因而「全綠」)。
   - 再加一條整合層:對一個真實 controller,每個敵兵斷言 `attack_targets().cells.has(pos) == (reason == NONE)`。
     這一條把 controller 閘門(`ACTION_SPENT`、phase)也綁進一致性。
   - 注意 GdUnit4 第一個失敗斷言會中止同檔後續測試:AC4 敏感度證明須「一個 mutant 一次執行」,
     建議列出具體 mutant:①互換 `<` / `>` ②拿掉 LOS 分支 ③拿掉 `ACTION_SPENT` 閘門。
5. **AC2 條件寫法**:建議改為「落入單位資訊分支(非傷害預覽)、佔位者為 `Unit.Faction.ENEMY`、`reason != NONE` 時顯示」,
   直接以查詢結果當唯一判斷來源,不重複條件。同時補:我方單位/空格/未選取 → 不顯示。
6. **AC3**:警告 `_TILE_INFO_PANEL_LINE_COUNT`/`_tile_info_extra_line` 現為「減傷列」專用的布林。
   減傷列只對我方出現、原因列只對敵方出現,**互斥**,所以可共用同一個「多一行」旗標而最大仍為 9 行 —— 工單應寫明,
   並要求測試斷言兩者不會同時為真。
7. **不要動 `build_tile_info_text` 簽章**:原因行應仿 `guard_text`,在 `_update_tile_info_panel()` 以 `"\n" + 原因行` 附加,
   避免該函式再長出第三個預設參數(見 039 審查)。
8. **Affected Files 漏列**:`src/gameplay/battle/battle_controller.gd`(必列,見第 1 點)、
   `tests/unit/gameplay/combat/` 下的 CombatRules 測試檔與 controller 測試檔(原寫「新測試檔」過泛,請列路徑)。
   另:新增在地化鍵會改 `strings.csv` 列數,除 `locale_data_integrity_test.gd` 外,還須確認
   `tests/integration/ui/battle_screen_tile_info_test.gd` 是否也有列數/鍵斷言 —— **未驗證**,實作者須先 grep。
9. **兩件須先確認(未驗證,不阻擋 AC 但派工前要看)**:
   - ADR-0001 的 `QueryResult` 契約(`docs/architecture/query-result-scope-boundary-2026-10-12.md`)是否要求「新的 controller
     查詢必須回 QueryResult 型別」。這個查詢只在同一幀內讀一次、直接餵 UI,我傾向不需要,但我沒有讀該文件,須實作者先查並在回報寫出結論。
   - 文案問題:原因是以「目前位置」計算,玩家可能打算先移動再攻擊。「超出射程」是否要寫成「目前位置超出射程」,
     這是設計/文案決定,請協調者請示,不是我能定的。
10. **前置**:工單已寫須在 039 提交後開工(同檔 `battle_screen.gd`),我同意;039 的 `identity_line` 與 040 的原因行同在
    `_update_tile_info_panel()` 單位分支內,先後次序務必固定,否則合併衝突。

### 建議改寫後的 AC 文字(供協調者請示後套用)

- **AC1(規則層)**:新增列舉 `AttackBlockReason { NONE, OUT_OF_RANGE, TOO_CLOSE, LOS_BLOCKED, ACTION_SPENT }`。
  `CombatRules.attack_block_reason(from, to, min_range, max_range, is_occluding)` 回前四者之一(僅純幾何),
  實作只呼叫既有 `is_in_range` / `is_attack_blocked_by_los` 與類內 `_manhattan_distance`,不新寫距離/視線算法。
  `BattleController` 新增查詢,外層閘門與 `_attack_targets_for` 相同(非 `PLAYER_INPUT`、無選取、`_order.can_attack` 為假 →
  後兩者分別回「不適用」、`ACTION_SPENT`),其餘委派上述函式。**優先序:`ACTION_SPENT` > 射程類 > `LOS_BLOCKED`。**
- **AC2(一致性)**:掃描測試以既有 `is_attack_legal` / `is_attack_blocked_by_los` 為預言機(測試內不得自算距離/視線),
  斷言 `reason == NONE ⇔ is_attack_legal`、`reason == LOS_BLOCKED ⇔ is_attack_blocked_by_los`,並統計四種原因各至少出現一次;
  另有整合測試:真實 controller 下每個敵兵 `attack_targets().cells.has(pos) ⇔ reason == NONE`。
- **AC3(顯示)**:資訊卡落入單位資訊分支(非傷害預覽)、佔位者為敵方、`reason != NONE` 時,於單位資訊後附加
  「無法攻擊:<原因>」一行(在地化鍵,不得寫死);可攻擊、我方單位、空格、未選取時不顯示。以 `"\n" + 行` 附加,不改 `build_tile_info_text` 簽章。
- **AC4(高度)**:原因列與減傷列互斥,共用「多一行」旗標,面板最大 9 行;測試斷言不溢出且兩列不同時出現。
- **AC5(敏感度)**:至少三個 mutant 各一次獨立執行(比較方向互換、移除 LOS 分支、移除 `ACTION_SPENT` 閘門),各自改壞 → 紅 → 還原。
- **交付**:全套 `run_tests_with_import.sh`,貼 `ENGINE EXIT` 與 `Overall Summary` 原始行。
- **Affected Files** 增列 `battle_controller.gd` 與兩個具名測試檔路徑。

## 三、總結
- 039:可提交;效能結論「推論合理、實測不成立」(基準雜訊過大);姓名鍵與敵兵編號解析各登記一筆後續,不在本單做。
- 040:AC 須先改(`BattleState` 做不到「已攻擊」、缺優先序、缺 done 單位原因、Affected Files 漏 controller)再派工。
