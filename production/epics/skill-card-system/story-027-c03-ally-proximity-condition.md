# Story 027:c03 出牌站位條件 —— 付款人 2 格內須有另一名存活我方

> **Epic**: `production/epics/skill-card-system/EPIC.md`
> **Status**: ✅ Done(2026-11-19,提交 `3611c49`)(原狀態:Ready(2026-11-19 管理者裁決「借用現成距離欄(推薦)」;選項分析 `docs/reviews/c03-distance-condition-options-2026-11-19.md` 選項 B))
> **Type**: Logic
> **Estimate**: S(半天內,粗估未驗證)
> **依據**:`design/quick-specs/card-rework-cost-and-pool-2026-11-12.md`(c03「成立條件:付款人與另一名我方單位距離 ≤2」,當場 grep「成立條件」);創意審查 `docs/reviews/card-rework-creative-review-2026-11-12.md`(至少一張直傷卡綁站位);UX 提示文案 `design/ux/card-rework-ui-2026-11-17.md`(「需有隊友在 2 格內」)。

## 背景(協調者 2026-11-19 實查)

- 牌表第 15 欄 `target_range` 已被解析(`src/gameplay/cards/card.gd`,grep `card.target_range =`)。
- `card_play_session.gd` 只在**雙人卡付代價**(grep `if card.target_range >= 1:`)與 **c07 選隊友過濾**(grep `func _ranged_pick_candidates` 或 `2026-11-18 ruling`)兩處讀它;**直傷卡路徑完全不讀** —— 故 c03 即使資料填 2,條件也不會生效。

## 規則

- 直傷卡(`DIRECT_DAMAGE`)`target_range >= 1` 時,意思是「**付款人 `target_range` 格內有另一名存活我方**」;`-1` = 無站位條件(c01/c02)。距離一律 `AffinityRules.manhattan_distance`,不得另寫一份。
- 不成立時出牌被拒、零寫入,回報可觀測的原因(UX 文案「需有隊友在 2 格內」;鍵名 `battle.card_reason.need_ally_within_2`,見 `docs/reviews/card-rework-loc-keys-2026-11-19.md` 第 1.3 節第 3 列;本單只需讓原因可被讀出,把鍵加進 `strings.csv` 與顯示屬 020b)。
- 牌表不新增欄位、解析器不動。

## Acceptance Criteria

- [ ] **AC1** 付款人 2 格內有存活我方 → 可打;3 格 → 拒;唯一鄰近隊友陣亡 → 拒(單元測試)。
- [ ] **AC2** 直傷卡 `target_range = -1` 行為不變(既有 018 測試全綠)。
- [ ] **AC3** 拒絕原因可由 015 結果物件/不可打原因讀出(供 020 手牌與面板顯示)。
- [ ] **AC4** 敏感度證明(常駐 `test_sensitivity_proof_*`,一個 mutant 一次獨立執行):①拿掉檢查 → AC1「3 格拒」紅 ②陣亡隊友仍計入 → AC1「陣亡拒」紅。交付前掃殘留注入標記。
- [ ] 交付前全套 `GODOT_BIN=<路徑> bash tools/build/run_tests_with_import.sh`,回報貼 `ENGINE EXIT` 與 `Overall Summary` 原始三行。

## 連帶(不在本單)

- 022 須加一條資料測試鎖死 c03 的 `target_range == 2`(填錯 -1 會靜默失去條件)。
- 規格須補一句「直傷的 `target_range ≥ 1` = 另需隊友條件」(既有文件,另行請示)。
- **本單 Done 之前,c03 不得進任何試玩關。**

## Affected Files

- `src/gameplay/cards/card_play_session.gd`(必要時 `card_cost_plan.gd` 新增拒絕原因)、`tests/unit/gameplay/cards/` 新測試。超出先問。

## 與其他工單的順序

- 與 022 無檔案重疊,可平行;020b(手牌不可打原因)會顯示本單的原因 → 本單先於 020b 較順。
