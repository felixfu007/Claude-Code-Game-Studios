# Story 033:戊獨行減傷條件化(本回合未出手才有)+ 負向 Φ 減傷改進位

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-10-30)
> **Type**: Logic
> **Estimate**: M
> **權威規格**:`docs/reviews/affinity-core-redesign-spec-amend1-2026-10-30.md` 第 1、2 節(修訂),其餘沿用 `docs/reviews/affinity-core-redesign-spec-2026-10-30.md`。本單不複述規則。
> **依據**(管理者裁決逐字,2026-10-30):「照建議補代價,重新登記重測(推薦)」(依 `docs/reviews/lone-guard-pillar4-review-2026-10-30.md` 第 3 節候選甲 + 附帶建議)。

## Acceptance Criteria

- [ ] **AC1** `CombatRules.guard()`:負向改為 `−ceil(|Φ|/2)`(Φ=−1 → −1)。更新 story-031 測試中受影響的負向斷言(逐條列舊值→新值)。
- [ ] **AC2** 戊「剛結束的我方階段是否出手」旗標:定義依修訂規格第 1 節;歸戰棋戰鬥狀態(`BattleState`);每個我方階段開始清為 false;戊作為攻擊方完成攻擊結算時設 true。旗標寫入必須遵守 ADR-0001 提交入口規則(實作者查證寫入點在提交窗內,寫明)。
- [ ] **AC3** `lone_guard` 生效值 = 出手過 ? `min(lone, 0)` : `lone`(+2 被取消、−1 保留)。`_lone_guard_of` 與 `lone_guard_if_at` 都要套用,且仍只有一份計算。`lone_guard_if_at` 是否需要新增「假設本回合出手」的參數:依修訂規格第 4 節與 attempt-3 登記(qa-lead 同時撰寫 `docs/reviews/protocol2-attempt3-registration-2026-10-30.md`)—— **若登記要求的介面與你的設計不同,以登記為準;登記未完成前先做預設參數 `assume_attacked := <讀旗標>`,並在回報中說明**。
- [ ] **AC4** 測試:敵先手第 1 回合視為未出手;出手後 d=3 時 guard 0;未出手 d=3 時 +2;貼隊友 −1 不受旗標影響;新我方階段旗標重置。敏感度證明 1 次並還原。

## 🔴 防過擬合

不得以新規則在第 1 場(vs01)跑對局或自動對戰。

## Affected Files

`src/gameplay/combat/combat_rules.gd`、`src/gameplay/battle/battle_state.gd`、`src/gameplay/battle/battle_loop.gd` / `battle_controller.gd`(只動「我方階段開始」與「攻擊結算」掛點,實作者逐一列出)、受影響的既有測試檔(逐一列出)、新測試檔。
