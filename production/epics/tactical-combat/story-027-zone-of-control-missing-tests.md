# Story 027:阻擋規則補測試(ZoC-5~9)

> **Epic**: `production/epics/tactical-combat/EPIC.md`
> **Status**: Ready(2026-10-29)
> **Type**: Logic
> **Estimate**: S
> **依據**: 管理者 2026-10-29 裁決,選項逐字「**照提案寫進去,並補上缺的測試(推薦)**」。
> 規格:`design/gdd/tactical-combat-system.md` 的 Core Rules #2a 與 AC-2a(ZoC-1~9)。

## 為什麼

阻擋規則是 10/28 晚間試玩時直接寫進程式的;GDD 已補條文(`507d839`),但 AC-2a 中 ZoC-5~8 沒有測試、ZoC-9 未查證。
沒有測試的行為,日後被改壞不會有人發現。

## Acceptance Criteria

- [ ] **ZoC-5** 單向:我方單位移動**不受**敵方鄰格阻擋。
- [ ] **ZoC-6** 只算上下左右四格:斜角不構成阻擋;棋盤邊界不出錯。
- [ ] **ZoC-7** 陣亡的我方單位不產生阻擋區。
- [ ] **ZoC-8** 多個我方單位阻擋區重疊時去重,行為與單一阻擋格相同。
- [ ] **ZoC-9** 先查證:`move_unit`(或實際的移動寫入入口)是否拒絕穿越阻擋格。**查證結果照實寫入回報**;若程式不拒絕,**只寫測試記錄現況並回報,不要改正式程式**(是否該拒絕是新的設計問題)。
- [ ] 每條測試附前提斷言(例:先斷言該格確實在敵人原本的可達範圍內,再斷言加入我方單位後被截斷)。
- [ ] 敏感度證明:ZoC-5、ZoC-7 各一條。

## 實作提示

測的是 `BattleState.legal_moves` / `zone_of_control_cells` 與 `Board.reachable_tiles(stop_cells)`。既有測試 `tests/unit/gameplay/board/board_zone_of_control_test.gd`(ZoC-1~4)。

## Affected Files

新測試檔(`tests/unit/gameplay/battle/` 底下);**不改任何正式程式**。
