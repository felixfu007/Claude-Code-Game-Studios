# Story 040:資訊卡顯示「無法攻擊:原因」

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-11-12)—— 🔴 須在 story-039 提交後才開工(同一個檔)
> **Type**: Logic + UI
> **Estimate**: S~M
> **依據**:
> - 管理者試玩回報(2026-11-11):「敵方明明在射程內,我方卻無法攻擊…不確定是BUG還是機制」;
>   管理者判定成因「應該是3(倒木擋視線),因為都是色塊,我根本看不出來這些色塊代表什麼」。
> - 管理者 2026-11-12 裁決,選項逐字「**A 資訊框多一行「無法攻擊:原因」(推薦)**」;
>   被跳過:「B 按攻擊被拒時跳短提示」「C 棋盤上標字或常駐圖例」。紀錄:`production/session-state/active.md` 第九十九批節。
> - 選項分析:`docs/reviews/tile-info-and-attack-reason-options-2026-11-12.md` 題二。

## 為什麼

攻擊不合法目前只有橘色「視線被擋」高亮(`set_attack_los_blocked_highlights`),沒有任何文字。
打不到的原因有四種,玩家無從分辨。

## Acceptance Criteria

- [ ] **AC1 判斷只在規則層**:新增一個回傳「無法攻擊原因」列舉的函式,放在 `CombatRules`(純幾何原因)/`BattleState`
      (含「本回合已攻擊」等狀態原因)。原因至少涵蓋:①可攻擊(無原因)②超出射程(含斜角算 2 格)③太近(低於最小射程)
      ④視線被擋 ⑤本回合已攻擊。
      🔴 **必須重用既有判斷**(`is_in_range` / `LineOfSight.is_clear` / 既有的已攻擊旗標判斷),**不得在 UI 層或新函式裡
      重算曼哈頓距離或視線** —— 專案已登記「同一公式兩份實作、只是今天答案一致」失效模式。
      並加一條一致性測試:對同一組輸入,「原因 == 可攻擊」⇔ `is_attack_legal(...)` 為真(多組輸入,含四種原因各一)。
- [ ] **AC2** 已選定我方單位、游標停在**敵方**單位上、且該敵兵不可攻擊時,資訊卡多一行「無法攻擊:<原因>」(在地化鍵,不得寫死)。
      可攻擊時不顯示此行;未選定我方單位時不顯示此行。
- [ ] **AC3** 資訊框高度要容得下多出的一行(現行 `_TILE_INFO_PANEL_LINE_COUNT` 寫死 8,已有「+1 減傷列」機制可參考);不得溢出或截斷。
- [ ] **AC4** 敏感度證明:AC1 一致性測試、AC2 各一條(改壞 → 紅 → 還原)。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,貼 `ENGINE EXIT` 與 `Overall Summary` 原始行。

## 未涵蓋(刻意)

- 文字放不放得進框寬(像素層)→ 開窗目視。
- 「按攻擊被拒時」的回饋(管理者跳過 B 案)。
- 文件同步(`tactical-combat-system.md` / UX 文件)→ 協調者另行請示。

## Affected Files

`src/gameplay/combat/combat_rules.gd`、`src/gameplay/battle/battle_state.gd`(若狀態原因放這裡)、`src/ui/battle/battle_screen.gd`、
`assets/data/locales/strings.csv`(新增原因字串鍵)、`tests/unit/core/i18n/locale_data_integrity_test.gd`(列數斷言)、新測試檔。
超出此清單先問。
