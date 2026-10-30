# Story 034:戊「騎牆 + 留一手」

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-10-30)
> **Type**: Logic + UI
> **Estimate**: M
> **權威規格**:`docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md`(相對 amend1 的修訂;本單不複述規則)。
> **依據**(管理者裁決逐字,2026-10-30):「交設計師重想戊的機制」(非推薦)→「騎牆,先給創意總監審再做(推薦)」→「騎牆+留一手(推薦)」→「今天做到哪算哪,未完下次接(推薦)」。審查:`docs/reviews/straddle-pillar4-review-2026-10-30.md`。

## Acceptance Criteria

- [ ] **AC1** 戊獨行新表(amend2 第 1 節):d=1 → −1、d=2 → +2、d≥3 或無存活隊友 → 0;出手條件取消。依 amend2 建議**保留介面**(`lone_guard_if_at` 的 `will_attack`、`lone_guard_effective`)但不再影響結果;三處文件註解標「已棄用,忽略」;一條測試證明 `will_attack` true/false 結果相同。
- [ ] **AC2** 留一手(amend2 第 2 節):戊作為攻擊方、攻擊當下所在格 d=2 時,最終傷害 −1(最小 0),傷害式獨立一項;資料驅動沿用名冊第 12 欄旗標;敵方與非旗標單位不適用。常數沿用 `CombatRules` 現行做法。
- [ ] **AC3** `BattleState` 傷害拆解加 `hold_back` 欄;預覽/結算單一出處。
- [ ] **AC4** 我方攻擊預覽(`battle_screen.gd` `_build_attack_preview_text`)在 hold_back ≠ 0 時顯示「留一手 −N」列(新字串鍵)。
- [ ] **AC5** 既有測試受影響者逐條列舊值→新值,不得放寬;敏感度證明 2 次(拿掉留一手、d=2 減傷改錯)並還原。

## 🔴 防過擬合

不得以新規則在第 1 場(vs01)跑對局或自動對戰;attempt-4 預先登記(H4)提交前,本單程式**不得提交**。

## Affected Files

`src/gameplay/combat/combat_rules.gd`、`src/gameplay/battle/battle_state.gd`、`src/ui/battle/battle_screen.gd`(只動攻擊預覽列)、`assets/data/locales/strings.csv`、`tests/unit/core/i18n/locale_data_integrity_test.gd`(只改列數)、受影響既有測試(逐一列出)、新測試檔。
