# Story 018:直傷卡(敵方目標步驟、擊殺鏈、勝負判定掛點)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: Ready(依序:010、011、015 完成後才可派工)—— F7 與「直傷擊殺是否有反擊」兩題已於 2026-11-17 決定(答案檔題 3、4),見「派工前須先決定」第 1、2 題。
> **Type**: Logic + Integration(控制器鏈);選敵 UI 部分見 020 的邊界
> **Estimate**: L(3~4 天,粗估未驗證;data-format S4,其稱風險最大之一)
> **依據**:規格 v1.0(直傷沿用 v0.3 卡池 c01~c03,無視 DEF 與 Φ、無隨機,符合 `rng_in_combat_settlement` 禁令);`docs/reviews/card-rework-data-format-2026-11-12.md` F4(死亡鏈三段在 `BattleState.resolve_attack()` → `BattleController._apply_attack()` → `_check_outcome_and_finish()`,Session 碰不到)、F10。

## 派工前須先決定

1. **F7 視線/控制區**:直傷是否受 `BattleState.is_attack_range_blocked_by_los()` 阻擋?c02(董振豪射程 2~6)的實際價值取決於此。**game-designer 裁決**,工單在回答前不得開工。
   - **已決:直傷尊重視線**(視線被擋的敵人不可選為目標;射程 = 施放者當前位置的單位攻擊射程 `min_range`~`max_range`)。(v0.3 第 3 節規則 7;答案檔題 3。)**控制區:直傷不受影響**(設計師直接定)。**必須沿用「一般攻擊的目標合法性」同一個函式,不得另寫第二份視線判斷**(格式審查 F7 的重點);實作者第一步確認該函式是哪一個並於回報說明。⚠️ 設計師只讀了 ZoC 邊界情況表、未讀其規則本文,「ZoC 另有影響攻擊的條款」為**未驗證**,實作者確認同一函式時順帶看。
2. **直傷擊殺有無反擊**:現行規則**未驗證**(沒讀 `combat_rules.gd` 全檔)。實作者第一步讀;若現行攻擊有反擊而直傷設計未定 → 停下問。
   - **已決:現行沒有反擊,直傷(擊殺與否)不引發反擊。** 依據:`src/` grep `retaliat|counter_attack|反擊` 零命中;`design/gdd/tactical-combat-system.md` 第 173 行「現階段核心戰鬥規則不含任何防守方自動迎擊/反擊機制」(答案檔題 4,設計師直接定)。⚠️ 設計師沒逐行讀 `battle_controller.gd` 攻擊流程,「是否有未用『反擊』字樣的迎擊邏輯」為**未驗證**——實作者讀 `_apply_attack()` 時順手確認,發現有迎擊邏輯才停下問。
3. **新訊號形狀**:`card_damage_resolved`(名稱暫定;snake_case 過去式)由 `BattleController` 發出、`BoardView` 播擊殺;與 020 的選敵 UI 邊界 —— 本單只做**邏輯與控制器鏈 + 訊號**,不做選敵畫面。
4. **「牌打出後戰鬥立刻結束(FINISHED)」**:`BattleScreen._apply_pending_card_confirm()` 現在是否預期 `FINISHED` **未驗證**。若不預期且修補需動 `battle_screen.gd`(大檔)→ 範圍超出時停下問。

## 規則

- `BattleState` 新增與 `resolve_attack()` 對稱的直傷結算方法,**共用清佔位/`_positions.erase` 的同一份邏輯**,不得複製貼上(否則「同一規則兩份實作」)。
- 直傷無視 DEF 與 Φ、不使用 RNG(`CombatRules.damage()` 一個字不改;新純函式)。
- `BattleController.confirm()` 在 `session.confirm()` 成功後補:`_order.remove_unit()`(若擊殺)、發新訊號、`_check_outcome_and_finish()`。
- 付款(HP/折損)走 015;直傷本身的 HP 寫入走窗口內受守衛路徑(010)。
- `CardPlaySession` 新增敵方目標步驟:`legal_targets()` 對直傷卡回傳射程內敵人。

## Acceptance Criteria

- [ ] **AC1 傷害**:直傷 = `effect_value`,無視 DEF 與 Φ;同輸入多次結果相同(無 RNG)。
- [ ] **AC2 擊殺鏈**:擊殺敵人 → 清佔位、移出行動序、發 `card_damage_resolved`;「全滅最後一個敵人」→ 戰鬥進入勝利結束;**不需要敵人行動就判定**。
- [ ] **AC3 共用清理**:直傷擊殺與一般攻擊擊殺走同一個清佔位內部函式(測試:兩條路徑擊殺後 `BattleState` 的佔位/位置表狀態相同;mutant 見 AC6)。
- [ ] **AC4 視線/射程**:依派工前第 1 題結論,在視線阻擋、射程邊界(max+1)各 1 條。
- [ ] **AC5 版本號與守衛**:確認提交內只遞增 +1;窗口外直接呼叫直傷結算方法被拒。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①擊殺不清佔位 → AC2 紅 ②擊殺不移出行動序 → AC2 紅 ③不呼叫勝負判定 → AC2 紅 ④直傷複製貼上一份清理 → AC3 紅 ⑤傷害套用 DEF → AC1 紅 ⑥視線檢查略過(或誤加)→ AC4 紅 ⑦窗口外可呼叫 → AC5 紅。交付前掃殘留注入標記。
- [ ] 既有 `battle_controller_*`、`battle_state_*` 測試全綠,斷言不改。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 選敵畫面與預覽(020 邊界/UX)、合擊(019)、播放動畫(視覺,另案)。

## Affected Files

- `src/gameplay/battle/battle_state.gd`、`src/gameplay/battle/battle_controller.gd`(路徑第一步確認)、`src/gameplay/cards/card_play_session.gd`、`src/gameplay/combat/combat_rules.gd`(僅新增純函式)
- 新測試:`tests/unit/gameplay/cards/card_direct_damage_test.gd`、`tests/integration/gameplay/battle/card_direct_damage_kill_chain_test.gd`

超出此清單先問(特別是 `battle_screen.gd`)。

## 與其他工單的順序

- **依賴 010、011、015**;019 依賴本單;020 的選敵 UI 依賴本單訊號。
