# Story 023:攻擊不再跳確認框(鍵盤與滑鼠皆直接攻擊)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-10-29)
> **Type**: UI / Integration
> **Estimate**: S
> **依據**: 管理者 2026-10-29 裁決,選項逐字「**鍵盤也拿掉確認框**」(非推薦項);
> 被跳過:「要,跟鍵盤一致(推薦)」、「不要,滑鼠直接打」。
> 來源問題:`production/qa/playtest-report-2026-10-28.md` 第四節問題 B。

## 為什麼

10/28 晚間加入全程滑鼠後,鍵盤攻擊走 story-013 的二段確認(選目標 → 確認框 → 再確認),
滑鼠點敵人卻直接攻擊。管理者裁決兩邊統一為**直接攻擊**。
🔴 **這取代 story-013 的「二段確認」**(story-013 本身不改寫;其 Status 與 UX 規格的加註另案請管理者核准)。

## Acceptance Criteria

- [ ] **AC1** 鍵盤:游標選定可攻擊目標後按確認 → **立即結算攻擊**,不開 `AttackConfirmPanel`。
- [ ] **AC2** 滑鼠:點可攻擊的敵人 → 立即結算攻擊(與 AC1 走同一條結算路徑,不得兩份實作)。
- [ ] **AC3** 手把確認鍵行為同 AC1。
- [ ] **AC4** 一次確認恰好結算一次攻擊(`combat_state_version` 恰好 +1;沿用 story-013 測試的量法)。
- [ ] **AC5** **出牌確認框不受影響**(本裁決只涵蓋攻擊)。
- [ ] **AC6** 斷言「會開確認框」的既有測試:改為斷言新行為;每一處在測試內註明「2026-10-29 管理者裁決取代 story-013」。**逐一列在交付報告**(檔名 + 測試名 + 改了什麼)。
- [ ] 敏感度證明:至少 AC1、AC2 各一條,把直接結算改回開面板時要轉紅。

## 實作提示(非規定)

- `AttackConfirmPanel` 元件類別與其自身的元件測試可以留著(元件本身沒壞);移除的是戰鬥畫面**開啟它的路徑**。
  若留下的節點/狀態欄位(`_attack_confirming` 等)已完全無用,一併移除;若移除會擴散到範圍外檔案,停下來回報。

## Affected Files

`src/ui/battle/battle_screen.gd`;`tests/integration/ui/battle/` 底下斷言攻擊確認框行為的既有測試(含 story-013 與 `battle_screen_playtest_feedback_2026_10_28_test.gd`);新測試檔。
**範圍外**:`src/ui/battle/attack_confirm_panel.gd` 與 `BattleScreen.tscn` 的節點刪除 —— 不要動,回報即可。
