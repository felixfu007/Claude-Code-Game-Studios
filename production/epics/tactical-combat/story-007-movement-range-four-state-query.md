# Story 007: 移動範圍四態查詢介面(`A`/`B\A`/`C\B`/`Grid\C`)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M3b(切面 1)
> **Status**: Ready(⚠️ 依賴 story-001/002 完成)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: UI Requirements §2(移動範圍呈現與不可達成因,四種互斥且窮盡的呈現狀態)、
Visual/Audio §1.1(可達/不可達-移動力不足/不可達-被佔位擋死 三態)、AC-13、AC-14。

**Requirement**: `TR-tactical-006`(現行文字待更正——已於 story-001/002 記載,本 story 沿用
同一保險條款:以 GDD 原文為準)

**ADR Governing Implementation**: `ADR-0001`(**Accepted**)—— 本查詢是對外呈現層查詢,
須遵守即時性 + 單一快照原子性(AC-20:「移動範圍/攻擊範圍疊加圖同樣必須讀取即時狀態」)。

**Engine**: Godot 4.7.1 | **Risk**: LOW

## 現況

story-002 完成後,`Board.reachable_tiles()` 已支援 `ignore_occupancy`/`ignore_passability`
兩個獨立開關,但**呼叫端**(`BattleController.move_targets()`)目前只呼叫一次、只回傳
合法移動集合 `A`——UX 規格 6.3 節:「`battle_controller.move_targets()` 只回傳可達集合 A,
`_refresh_view()` 只呼叫 `set_move_highlights(move_cells)`——未選中的格子一律不畫任何東西,
玩家看不到『不可達』本身」。

## Acceptance Criteria

*依 GDD UI Requirements §2 + AC-13 + AC-14:*

- [ ] 新增查詢(暫名 `move_targets_blocked()`/`move_targets_out_of_range()`,或回傳一個含
      三個切面的 Dictionary/Resource——**介面形狀由本 story 決定**,GDD 明文「三個方法 vs
      一個回傳多切面的結構,由本模組定案,UX 規格只定案『三個切面必須都查得到』」)
- [ ] 三集合互斥且窮盡:`A`(合法移動)、`B\A`(不可達——被佔位擋死,含地形不可通行導致的
      `C\B`,若採四態完整分類則為四者)、`Grid\B`(不可達——移動力不足)——**四態完整版本**
      (依 AC-13 新增 `C`):`A`、`B\A`(佔位擋死)、`C\B`(地形不可通行擋死)、`Grid\C`
      (移動力不足),四者聯集恆等於 `Grid`,無第五類殘留
- [ ] `A ⊆ B ⊆ C` 恆成立(公式三既有保證,解除障礙只會擴大或維持集合)
- [ ] `origin` 恆屬於 `A`,不落入任何不可達分類
- [ ] **合法性守門**:`ignore_occupancy=true`/`ignore_passability=true` 的輸出**僅供成因標示**,
      `BattleController` 的移動確認邏輯**必須且只能**接受屬於 `A` 的格子作為合法目的地
      (AC-14 禁止型)——即使 UI 已標示某格的不可達成因,移動確認請求仍必須被拒絕
- [ ] 遵守 ADR-0001:輸出攜帶 `combat_state_version`,即時性義務(AC-20)——顯示中的移動範圍
      疊加圖若在盤面變化後未重繪,至少須標記為過期,不得以過期輸出接受下一個玩家輸入(AC-22(a))

## Implementation Notes

1. **本 story 是 story-002 的直接消費端**——`Board.reachable_tiles()` 的四種布林組合是原始
   資料,本 story 的工作是在 `BattleController`/`BattleState` 層把四次(或等效的一次合併)呼叫
   包裝成一個對呈現層友善的介面,並套用 AC-14 的合法性守門(禁止呼叫端誤用 `B`/`C` 判定合法性)。
2. **效能取捨提醒(GDD UI Requirements §2 原文)**:「每次刷新需兩趟 Dijkstra 展開……不得以
   合併為單一趟、放棄成因區分作為最佳化方式——那是拿硬性需求換效能」。四態版本理論上需要
   最多三次獨立展開(或一次「最寬鬆」展開 + 差集運算,依 story-002 的實作方式而定),
   本 story **不得**為了效能犧牲任何一種成因的可區分性。
3. **與 story-005(`threat_targets`)的介面設計一致性**:兩者都面臨「多個方法 vs 一個回傳多切面
   結構」的形狀選擇,建議(非強制)採用一致的設計慣例,方便呼叫端與測試維護,但不強制要求
   完全相同的資料結構(兩者查詢的語意不同:移動範圍是單一單位、威脅範圍是敵方單位/多敵聯集)。

## Out of Scope

- **世界層的四態繪製**——story-014(M4),消費本 story 的輸出。
- **`Board.reachable_tiles()` 本身的簽章/演算法**——story-002,本 story 的前置依賴。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過。

- **四集合互斥窮盡(AC-13 對照)**
  - Given: 小型混合盤面(佔位 + 地形成本變化 + `passable=false` 格)
  - When: 呼叫四態查詢
  - Then: 逐格掃描,每一格恰好屬於 `A`/`B\A`/`C\B`/`Grid\C` 四者之一
- **合法性守門(AC-14 禁止型)**
  - Given: 目的格屬於 `B\A`(佔位擋死,`ignore_occupancy=true` 下可達)
  - When: 玩家嘗試確認移動至該格
  - Then: 移動確認請求被拒絕,不論 UI 是否已標示該格的不可達成因
- **地形不可通行守門**
  - Given: 目的格屬於 `C\B`(`passable=false`)
  - When: 玩家嘗試確認移動至該格
  - Then: 移動確認請求被拒絕
- **即時性(AC-20 對照)**
  - Given: 移動範圍疊加圖顯示期間,另一單位移動改變佔位狀態
  - When: 觸發重繪
  - Then: 重繪後的四態分類反映新佔位狀態,不得沿用變化前的分類結果

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/gameplay/battle/move_range_four_state_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001(`passable()`)、story-002(`reachable_tiles()` 四種布林組合)
- Unlocks: story-014(M4 世界層四態繪製)

## 執行層序列化

本 story 屬 M3b,不受 M6→M5→M4 序列化約束(該約束僅適用於改動 `battle_screen.gd` 的
M4/M5/M6 三模組)。但**規劃層 story-014(M4)依賴本 story 的產出**,見該 story 的
Dependencies 節。
