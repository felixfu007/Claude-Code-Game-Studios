# Story 021:自動對戰迴圈接上好感度加成

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-10-28)
> **Type**: Logic
> **Estimate**: S
> **依據**: 管理者 2026-10-28 裁決,選項逐字「**改善自動對戰(開好感度、教它集火)再量一次**」;
> 被跳過:「派數值設計師算紙上分析,並等我今晚打第 1 場(推薦)」、「先不處理,等我今晚實際打過」。

## 為什麼

`prototypes/autoplay-balance-2026-10-28/` 的第一版量測 5 場 × 2 打法全敗,但
`src/gameplay/battle/battle_loop.gd` 的 `_process_unit()` 呼叫
`_state.resolve_attack(id, attack_target, 0)` —— **好感度加成恆為 0**,本作核心機制在量測裡從未生效。
戰鬥畫面側(`BattleController`)早已有 `_phi_provider: Callable` 契約(`AffinityPhiProvider.phi(attacker_id, target_id) -> int` 即依此簽章寫成)。

## Acceptance Criteria

- [ ] **AC1 可選注入**:`BattleLoop._init()` 新增**最後一個**可選參數 `phi_provider: Callable = Callable()`,
      簽章比照 `BattleController` 的 `_phi_provider`(grep 確認,不要自行發明)。
      攻擊時:有效則 `phi_provider.call(attacker_id, target_id)`,無效則 0。
- [ ] **AC2 預設行為逐字不變**:未注入時傳 0。既有 `BattleLoop.new(...)` 呼叫點(tests 中 4 處以上)**零修改**且全綠。
- [ ] **AC3 生效**:注入一個固定回傳 +N 的 provider,同一攻擊造成的傷害與 `BattleState.preview_damage(attacker, target, N)` 一致(不得自寫傷害公式)。
- [ ] **AC4 雙方都適用**:敵方攻擊同樣經過 provider(與 `BattleController` 行為一致;若 BattleController 只對一方套用,照它的規則並在註解寫明出處)。
- [ ] 敏感度證明:常駐變種(例如覆寫成永遠傳 0)讓 AC3 測試變紅。

## Affected Files

`src/gameplay/battle/battle_loop.gd`、`tests/unit/gameplay/battle/...`(新)。
其餘 `src/` 檔不動。
