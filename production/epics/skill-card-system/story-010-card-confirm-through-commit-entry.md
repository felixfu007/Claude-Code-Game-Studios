# Story 010:卡牌確認走 ADR-0001 提交入口(路徑⑥)

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: ✅ Done(2026-11-17,提交 `2137de1`)(原狀態:Ready(前置;與卡牌改版獨立,可立刻做)—— ⚠️ 事實前提經 lead-programmer 2026-11-17 重新 grep 一次,工單開工第一步仍須當場重查)
> **Type**: Logic
> **Estimate**: S~M(約 0.5~1 天)
> **依據**:
> - `docs/reviews/card-rework-data-format-2026-11-12.md` 第 4 節 S0、第 5 節 F2:ADR-0001 路徑表第 6 條要求「卡牌打出第 4 步『確認』」走提交入口並遞增 `combat_state_version`,且「遞增必須無條件,不得依卡牌類別判斷」。
> - 現況查證(2026-11-17):`grep -n "commit_authoritative" src/gameplay/cards/card_play_session.gd` 無命中(`CardPlaySession.confirm()` 在該檔 `func confirm() -> bool:`,內部 `if 丙類 … else: add_modifier`);提交入口定義在 `src/gameplay/battle/battle_state.gd` 的 `func commit_authoritative_change`。「別處是否補遞增」**未驗證**(沒逐檔找 `combat_state_version`)。
> - 為何現在要做:卡牌改版的付血、補血、直傷全是 `Unit.hp` 寫入,而 `hp` setter 受守衛、窗口外賦值會被拒(F2 第 3 點,讀 `unit.gd` 所得,**未實機驗**)。不先做,後面 011~019 每張都會在這裡撞牆。

## 派工前須先決定

**無。** 協調者派工時請注意:本單**不新增任何卡牌效果**,行為對玩家應完全不變,唯一可觀察差異是 `combat_state_version` 在每次卡牌確認後 +1(ADR-0001 契約本來就要求)。

## 規則

- `CardPlaySession.confirm()` 的全部寫入(甲類 `add_modifier`、丙類 `PermanentAffinityWriteRules.play`、卡牌離手/進棄牌)包進**同一個** `_state.commit_authoritative_change(...)`,使用 `BattleController` 與 `BattleLoop` 共用的那一個入口(ADR 明文),**不得在 Session 另寫一個提交包裝**。
- 提交內不得有任何會失敗的步驟:**驗證全部在進窗口之前**(後續 015 的「先驗證、後扣款」依賴此形狀)。窗口內若遇到不可能的情況用 `push_error` + 明確 `return false`,**不用 `assert`**(`coding-standards.md` 兩條 assert 規則)。
- 「遞增不得依卡牌類別判斷」:甲類、丙類**同樣**遞增一次(恰好 +1,不是各 +1)。
- 失敗路徑(`confirm()` 回 `false`、未進窗口)版本號**不變**。
- 順手:`confirm()` 的 `else:`(把一切非丙類當甲類)**本單不改**(留給 011 的 `match`),但在回報中列出現況 else 之後是否還有別的分支。

## Acceptance Criteria

- [ ] **AC1 恰好 +1**:甲類確認、丙類確認各一條測試:確認前後 `combat_state_version` 差恰為 1(預言機取 `BattleState` 的公開讀取,不另設計數器)。
- [ ] **AC2 失敗不遞增**:`confirm()` 回 `false`(例:非確認步驟、點名限制不符)時版本號不變。
  > 🔴 **2026-11-17 technical-director 裁決加註(AC2 原文不改)**:本條只涵蓋**進窗口之前**的失敗路徑。
  > **丙類卡在窗口內被 `PermanentAffinityWriteRules.play()` 拒絕**(`INVALID_PAIR` / `DEAD_PAIR_FORBIDDEN` /
  > `ZERO_MAGNITUDE` / `NO_PORT_CONFIGURED`)時,`confirm()` 回 `false`、Session 留在 `CONFIRMING`、牌不離手,
  > **但版本號 +1** —— 這是已知且接受的保守多算(提交入口沒有中止機制,與 `battle_controller.gd`
  > 的 `_apply_move` / `end_unit_turn` 同形)。多算只會造成查詢結果被判過期而重算,不會造成漏判。
  > 該路徑的測試(`test_commit_entry_affinity_port_rejection_keeps_session_and_card_state`)釘住牌仍在手、步驟仍為 `CONFIRMING`;**版本號未釘**(實作者刻意不把有爭議行為寫死,2026-11-17 協調者依實際測試更正 TD 原稿此句)。
  > 🔴 **前提**:窗口內 `play()` 必須是丙類分支的第一個寫入,之前不得有任何寫入(否則拒絕時會部分寫入)。
  > 裁決全文:`docs/reviews/story-010-version-bump-on-reject-ruling-2026-11-17.md`
- [ ] **AC3 窗口內寫入被接受**:對 `Unit.hp` 的受守衛賦值**在確認的提交內**不被拒(用一條測試性探針卡/注入 mutator 證明窗口確實開著;`diagnostic_*` 讀取 `write_window_is_open()` 在 mutator 內為 true、離開後為 false)。
- [ ] **AC4 共用同一入口**:測試以掛載的守衛 `Callable`(`authoritative_write_in_progress_check`)觀察到卡牌確認期間窗口為開;同時 `BattleController` 既有攻擊路徑測試不受影響。
- [ ] **AC5 不新增提交包裝**:`grep -rn "commit_authoritative_change" src --include=*.gd | grep -v "##"` 回報原始輸出,Session 內只有**呼叫**、沒有**定義**第二個同名入口。🔴 搜尋指令不得寫進被搜尋檔的註解。
- [ ] **AC6 敏感度證明**(常駐 `test_sensitivity_proof_*`,mutant 子類別/內嵌替身,不要求手動注入;一個 mutant 一次獨立執行):①Session 不進提交 → AC1/AC4 紅 ②只在丙類進提交、甲類不進 → AC1(甲類)紅 ③甲類丙類各自進一次提交(+2) → AC1 紅 ④失敗路徑也遞增 → AC2 紅。交付前掃殘留注入標記。
- [ ] 既有測試全綠;既有 `card_play_session_*`、`battle_controller_*` 測試若因版本號斷言需調整,**逐條說明,不得刪斷言換綠**。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行(2026-10-12 裁決;協調者自行重跑複驗)。

## 未涵蓋(刻意)

- 任何新卡牌效果、新類別、付款(011 起)。
- 「是否另有別處補遞增」若查到,停下回報,不自行刪除。

## Affected Files

- `src/gameplay/cards/card_play_session.gd`(`confirm()`)
- 新測試:`tests/unit/gameplay/cards/card_play_session_commit_entry_test.gd`
- 既有 `tests/unit/gameplay/cards/card_play_session_*` 若需調整(逐條說明)

超出此清單先問。

## 與其他工單的順序

- **第一張,011~019 全部依賴它**(011 資料模型本身不依賴,但可與本單並行;015 起必須先有本單)。
