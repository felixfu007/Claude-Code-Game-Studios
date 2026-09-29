# Story 004: 單位行動四態 getter(不選取也能查任一單位)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M3a(切面 3)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: 2026-09-09

## Context

**GDD**: Core Rules #9(雙旗標行動經濟)、States and Transitions(「可行動」是複合狀態,
四種可觀測值:皆未用/只剩攻擊/只剩移動/已行動)、UI Requirements §1(格位資訊面板「當前
狀態」欄不得只顯示二元狀態)、Visual/Audio §1.1(行動旗標指示)、AC-19(行動經濟)。

**Requirement**: `TR-tactical-035`(回合層級名冊查詢介面,持久化 vs 可切換面板未定案 OQ-21——
本 story 是其**逐單位**版本的先決條件,回合層級總覽本身歸屬 #10 戰鬥 HUD,Out of Scope)

**M1 查證依據**(`docs/reviews/tactical-combat-m1-current-state-audit-2026-09-29.md` U-T4):

> `TurnOrder.can_move(id)`/`can_attack(id)`/`is_done(id)` 三個方法都已接受任意 `id` 參數,
> 不需要先 `select_unit()`——但 `can_move`/`can_attack` 內部經 `_is_actionable(id)` 閘門,
> 只要 `id` 不屬於當前 `_current_side`,一律回傳 `false`,不論該單位真正的 move/attack 旗標值
> 為何——「非本回合單位」與「旗標已用完」被同一個 `false` 蓋掉,無法從外部區分。`is_done(id)`
> 不受此閘門影響。此外沒有任何方法把 `can_move`+`can_attack`+`is_done` 三者合併成單一「四態」
> 回傳值。`BattleController` 本身沒有轉發這三個查詢給任意 `id` 的公開方法——`battle_screen.gd`
> 目前是靠自己持有與 `BattleController` 相同的 `TurnOrder` 實例才繞得過去,這是巧合式耦合,
> 不是設計出來的介面。

**對本 story 的影響(M1 報告原文)**:「支持 M3 項目 3『單位行動四態 getter』維持在範圍內
……本次查證結果是『部分存在但形狀不對』,比『完全不存在』更精確,不改變 M3 要補這個 getter
的結論。」

**ADR Governing Implementation**: `ADR-0001`(**Accepted**)—— 本查詢是 GDD Core Rules #10
總則涵蓋的對外查詢介面之一(「現況盤點」列出的清單為非窮盡,新增介面自動落入涵蓋範圍)。

**Engine**: Godot 4.7.1 | **Risk**: LOW

## Acceptance Criteria

- [ ] 新增一個公開方法(暫名 `unit_action_state(id: int) -> ActionState` 或等效簽章,**介面
      形狀由本 story 決定**——GDD 只定案「四態必須可從外部查詢,不需先選取」),回傳四態之一:
      皆未用 / 只剩攻擊 / 只剩移動 / 已行動(GDD States and Transitions「可行動是複合狀態」)
- [ ] **不受 `_is_actionable(id)` 閘門影響**——查詢任一存活單位(不論是否屬於當前回合陣營)
      皆須回傳其真實旗標狀態,而非因「非本回合單位」被 `_is_actionable` 攔截而回傳與「旗標
      已用完」相同的假訊號(M1 查證明確指出此為現況缺口的核心)
- [ ] 陣亡單位的查詢行為須明確定義(建議比照 `is_done(id)` 現行對不存在 id 的處理:
      `if not _unit_side.has(id): return true`——但**本 story 不得沿用「回傳 true」這種與
      『已行動』狀態同值的處理方式讓呼叫端無法區分『已行動』與『不存在/陣亡』**,若沿用現行
      `is_done()` 邏輯,呼叫端需要能區分這兩種語意——由本 story 決定介面形狀時一併處理)
- [ ] 供 `BattleController` 轉發此查詢為公開方法,取代現況「`battle_screen.gd` 靠巧合持有
      同一個 `TurnOrder` 實例」這種未設計出來的耦合(M1 報告用詞:「巧合式耦合」)

## Implementation Notes

1. **`TurnOrder` 已有的三個底層方法可以重用,不需要重新實作旗標邏輯**——`can_move(id)`/
   `can_attack(id)`/`is_done(id)` 已經是正確的資料來源,問題只在於 `can_move`/`can_attack`
   內部的 `_is_actionable(id)` 閘門會遮蔽真實旗標值。本 story 需要的是一個**繞過該閘門**、
   直接讀取底層旗標 Dictionary(`_move_used`、`_attack_used`)的新路徑,或是在 `_is_actionable`
   之外新增一組不受陣營限制的查詢方法——**兩種寫法皆可,取捨屬本 story 判斷**。
2. 🔴 **不要直接修改 `can_move`/`can_attack` 移除 `_is_actionable` 閘門**——那兩個方法目前的
   陣營限制是既有行為的一部分(供 `BattleController` 判斷「這個單位現在能不能被操作」),
   本 story 要新增的是「不論當前陣營都能查真實旗標」這個**額外**能力,不是要改變既有方法的
   既有語意。
3. **`BattleController` 新增公開轉發方法**:現況 `BattleController` 沒有把 `TurnOrder` 的
   任意 `id` 查詢對外暴露(M1 報告:「`BattleController` 本身沒有轉發這三個查詢給任意 `id`
   的公開方法」)。本 story 應在 `BattleController` 新增一個公開方法呼叫 `TurnOrder` 的新
   查詢,讓 `battle_screen.gd` 未來可以透過正式介面取得四態,而不必繼續依賴「剛好持有同一個
   `_order` 實例」這個巧合。

## Out of Scope

- **回合層級剩餘旗標總覽(`P-D4`,GDD OQ-21)**——GDD Dependencies 表明文歸屬戰鬥 HUD(#10),
  本 story 只提供逐單位查詢,不提供「列出我方全部單位」的回合層級介面。
- **格位資訊面板本身如何呈現四態**——story-012(M5),消費本 story 的輸出。
- **世界層的持久非色彩標記**——story-015(M4),消費本 story 的輸出。
- **`battle_screen.gd` 移除對 `_order` 的直接持有**——是否要同步清理這個巧合式耦合,屬實作
  時的判斷(建議清理,但不強制列為本 story 的驗收條件,避免範圍蔓延到非本 story 目標的
  重構)。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **四態各自正確回傳**
  - Given: 分別建構「皆未用」「只剩攻擊(已用移動)」「只剩移動(已用攻擊)」「已行動(兩者皆用)」
    四種單位狀態
  - When: 呼叫 `unit_action_state(id)`
  - Then: 各自回傳對應的四態列舉值
- **不受陣營閘門影響(M1 查證缺口的直接回歸測試)**
  - Given: 一個屬於**非當前回合陣營**的單位,其移動旗標已用、攻擊旗標未用
  - When: 呼叫新查詢方法
  - Then: 回傳「只剩攻擊」,**不得**回傳與「已行動」相同的假訊號(此為 M1 查證發現的核心缺口,
    此測試專門攔截「複用 `can_move`/`can_attack` 而未繞過 `_is_actionable`」的錯誤實作)
- **`BattleController` 公開轉發**
  - Given: 任意存活單位 id(不要求先 `select_unit()`)
  - When: 呼叫 `BattleController` 的新公開方法
  - Then: 回傳值與直接查詢 `TurnOrder` 一致,且**不需要**任何前置選取動作

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/battle/unit_action_state_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: story-012(格位資訊面板「當前狀態」欄)、story-015(世界層行動旗標持久標記)
