# Story 002: `reachable_tiles()` 雙開關(`ignore_occupancy`/`ignore_passability`)+ 有界前緣展開

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M2
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M(1 個完整 session)
> **Manifest Version**: 2026-09-09

## Context

**GDD**: `design/gdd/tactical-combat-system.md` —— Formulas 公式三(`reachable_set` 完整簽章
`reachable_set(u, ignore_occupancy=false, ignore_passability=false)`)、AC-2/AC-13/AC-14、
UI Requirements OQ-16(有界前緣展開,不得全盤展開後過濾)。

**Requirement**: `TR-tactical-006`(現行文字待更正,見下方 🔴)、`TR-tactical-008`(有界前緣展開)

🔴 **`TR-tactical-006` 現行文字尚未反映本 story 的範圍**:
```
$ grep -n "TR-tactical-006" docs/architecture/tr-registry.yaml
41:  - {id: TR-tactical-006, ..., requirement: "reachable_set(u, ignore_occupancy) 須為單一函式;移動合法性只能用集合 A,不得用 B(AC-14)", ...}
```
現行文字只寫**單一** `ignore_occupancy` 參數,未涵蓋 GDD 已於 2026-09-29 新增的第二個獨立開關
`ignore_passability`。此更正義務(EPIC.md C5)由 `technical-director` 擁有,**截至本 story
切出時尚未完成**(與 story-001 同一狀況,見 `story-index.md`)。**本 story 的驗收條件一律以
GDD 公式三原文(含 `ignore_occupancy`、`ignore_passability` 兩個獨立參數,四種布林組合)為準**,
不以 `TR-tactical-006` 現行文字為準。

**ADR Governing Implementation**: `ADR-0001`(戰棋查詢介面原子性契約,**Accepted**)——
本 story 產出的 `reachable_tiles()` 是 M3b(story-007)移動範圍四態查詢介面的直接輸入,
`BattleController`/`BattleState` 層須遵守 ADR-0001 的即時性/單一快照原子性義務,但**本 story
本身停留在 `Board`(純資料層/演算法層),不直接暴露對外查詢介面**——ADR-0001 的查詢介面
契約義務由 story-007 承接。本 story 需注意的是**效能取捨的邊界**:GDD UI Requirements §2 明訂
「不得以合併為單一趟、放棄成因區分作為最佳化方式」——即使本 story 的目標包含「有界前緣展開」
這項效能改善,**不得**因此把 `A`(合法移動)與 `B`(忽略佔位)、`C`(忽略可通行)的計算合併成
單一趟而讓 story-007 拿不到區分三種不可達成因所需的原始資料。

**Engine**: Godot 4.7.1 | **Risk**: LOW

**Control Manifest Rules**:
- 效能護欄:「`reachable_set` 雙趟展開……成本未量化——ADR-0001 明確不解決此問題,只讓跨幀
  攤分合法。單幀 16.6ms 內能容納多少格 × 多少敵,本專案未作任何宣稱」——本 story **不需要**
  達成任何量化效能門檻,「有界前緣展開」的驗收標準是**演算法性質**(提前終止、不全盤展開),
  不是實測毫秒數。

## 現況(2026-09-29 實測)

```
$ grep -n "func reachable_tiles" src/gameplay/board/board.gd
106:func reachable_tiles(origin: Vector2i, mp: int) -> Array[Vector2i]:
```
現行簽章**沒有** `ignore_occupancy`/`ignore_passability` 任一參數。全函式已讀(見 `board.gd`
第 101-141 行):現行演算法是 Dijkstra 變體,以 `frontier`(Array)+ `best_cost`(Dictionary)
逐步展開,**在展開時就用 `if candidate_cost > mp: continue` 提前剪枝**——這已經是有界前緣展開
的形狀(不是全盤展開後過濾),但**現行程式碼裡佔位檢查(`has_occupant`)是寫死的,無法關閉**:

```gdscript
for neighbor: Vector2i in _get_orthogonal_neighbors(current):
	if not is_in_bounds(neighbor):
		continue
	if has_occupant(neighbor):
		continue
	var candidate_cost: int = best_cost[current] + get_move_cost(neighbor)
	if candidate_cost > mp:
		continue
	...
```

本 story 的演算法骨架可以沿用,但需要：①讓佔位檢查依 `ignore_occupancy` 參數可關閉；
②新增依 `passable()`(story-001 產出)可關閉的通行檢查（`ignore_passability`）；
③確認提前剪枝（`candidate_cost > mp` continue）在四種布林組合下依然成立，不因新增檢查而
退化成先展開全盤再過濾。

## Acceptance Criteria

*直接依 GDD 公式三 + AC-2 + AC-13 + AC-14,不引用 `TR-tactical-006` 現行文字:*

- [ ] `reachable_tiles(origin, mp, ignore_occupancy: bool = false, ignore_passability: bool = false)`
      —— 新簽章,預設值皆 `false`,呼叫端不變參時行為與現況完全一致(向下相容)
- [ ] 四種布林組合皆良定義(GDD AC-13):
      `A = reachable_set(ignore_occupancy=false, ignore_passability=false)`、
      `B = reachable_set(ignore_occupancy=true, ignore_passability=false)`、
      `C = reachable_set(ignore_occupancy=true, ignore_passability=true)`——
      `A ⊆ B ⊆ C` 恆成立
- [ ] 路徑**不得**穿越 `passable=false` 的格子(不論是否為路徑終點),除非 `ignore_passability=true`
- [ ] 路徑**不得**穿越已佔位格(不論敵我,路徑終點除外的既有規則不變),除非 `ignore_occupancy=true`
- [ ] `origin` 恆屬於 `A`(公式三既有輸出範圍保證,`passable(origin)` 恆為 `true` 的隱性不變量)
- [ ] `MP=0` 時 `A={origin}`(GDD AC-2/AC-13 邊界向量)
- [ ] **演算法為有界前緣展開**:提前終止於 `accumulated_cost > mp` 的分支,不得先展開全盤座標
      再事後過濾(TR-tactical-008、OQ-16)——驗收方式見下方 QA Test Cases 的效能特徵測試
- [ ] `ignore_occupancy=true`/`ignore_passability=true` 的輸出**僅供成因標示**,呼叫端不得將其
      用於移動合法性判定(此為介面契約,實際的合法性判定守門由 story-007/`BattleController`
      執行,本 story 只需確保 `Board` 層本身不混淆兩種用途——例如不提供任何名稱暗示這是
      「合法移動集合」的別名)

## Implementation Notes

1. **不要合併成單一趟展開就丟棄成因區分**——如果為了效能把三個開關合併為「全部忽略」的
   單一展開,會讓 story-007 無法取得 `A`/`B`/`C` 三者的個別集合。若要共用同一次展開的中間
   結果以節省重複運算,展開過程本身可以只跑一次「最寬鬆」的版本(`ignore_occupancy=true,
   ignore_passability=true` 即 `C`),但**必須**在展開過程中同時記錄「若不忽略佔位/可通行,
   這格是否仍會被排除」的資訊,讓呼叫端能重建 `A`/`B`——這是實作層的最佳化空間,不是驗收
   條件本身要求的做法,實作者可自行選擇最直觀的寫法(例如四次獨立呼叫,只要整體演算法性質
   仍是有界前緣展開即可)。
2. **提前剪枝的位置**:現行 `if candidate_cost > mp: continue` 已經是正確位置(在展開到該
   鄰居格、算出候選成本之後、加入 frontier 之前就剪掉)。新增的 `passable` 檢查應該放在同一層
   級——在計算 `candidate_cost` 之前就先判斷「這格能不能走」(不論是佔位還是不可通行),
   避免對本來就走不到的格子做多餘的成本計算,但這只是風格建議,不是驗收條件。
3. `get_move_cost()` 對 `passable=false` 地形回傳的佔位成本(story-001 產出,建議沿用平地 `1`)
   **不得**在本 story 的展開演算法中被誤用為「這格真的只要 1 點 MP 就走得到」——`passable`
   檢查必須先於/獨立於成本累加生效,不能只靠成本表達到「不可通行」的效果(這正是 GDD 明文
   警告的「不得用極大成本模擬」在演算法層的對應)。

## Out of Scope

- **移動範圍四態查詢介面**(`A`/`B\A`/`C\B`/`Grid\C` 的呈現層切面)——story-007,依賴本 story。
- **`BattleController.move_targets()` 的呼叫端變更**——若其簽章需要跟著調整,屬 story-007 範圍。
- **效能量化測試**(是否壓進 16.6ms)——OQ-16 明文列為 Performance ADVISORY,不在本 story 範圍。

## QA Test Cases

⚠️ 本節由 `lead-programmer` 直接撰寫(QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過,
見 story-001 同一說明)。

- **開放地形基本案例**(AC-2 向量)
  - Given: `origin=(0,0)`、`MP=2`、全格成本 1、無佔位、全 `passable=true`
  - When: 呼叫 `reachable_tiles(origin, 2)`(預設參數)
  - Then: 回傳曼哈頓半徑 2 菱形,共 13 格(不含 origin,依現行函式文件註解——⚠️ 未查證:
    GDD AC-2 的「13 格」計數是否含 origin,現行 `board.gd` 文件註解明寫「origin 本身從不
    包含在回傳結果中」,若 GDD 期望值含 origin 需在測試中對齊到現行既有慣例並記錄差異)
- **`MP=0` 邊界**(AC-2/AC-13 向量)
  - Given: `MP=0`
  - When: 呼叫 `reachable_tiles(origin, 0)`
  - Then: 回傳空陣列(現行函式排除 origin,故此為既有慣例下的正確空集合)
- **佔位擋死無繞路,`ignore_occupancy` 差集**(AC-13/AC-14 向量)
  - Given: 唯一最短路徑上有佔位格,無等成本繞路
  - When: 分別呼叫 `ignore_occupancy=false` 與 `=true`
  - Then: 前者不含該格,後者含該格 —— 差集非空
- **地形不可通行擋死,`ignore_passability` 差集**(AC-13 向量,2026-09-29 新增)
  - Given: 目的格本身 `passable=false`,或所有路徑皆須經過至少一格 `passable=false`
  - When: 分別呼叫 `ignore_passability=false` 與 `=true`(`ignore_occupancy` 皆為 `true` 以隔離
    佔位因素)
  - Then: `=false` 不含該格,`=true` 含該格
- **四集合聯集窮盡且無殘留**(AC-13「窮盡性全盤掃描」向量)
  - Given: 小型混合盤面(含佔位、地形成本變化、`passable=false` 格)
  - When: 分別計算 `A`、`B\A`、`C\B`、`Grid\C`
  - Then: 逐格掃描,每一格恰好屬於四者之一,無未分類或重複分類
- **有界前緣展開的演算法特徵**(TR-tactical-008/OQ-16 向量,⚠️ 未查證測試撰寫細節)
  - Given: 一個遠大於任何合理 `MP` 值的棋盤,或可觀察展開步數的探針
  - When: 以小 `MP` 值查詢
  - Then: 展開的節點數量應隨 `MP` 增長而增長,不應是固定的「全盤展開」——**具體斷言方式
    未查證**,下一個人可考慮在函式內插入診斷計數器(`diagnostic_*`,依控制清單「診斷欄位
    為 QA/測試專用」慣例)來斷言實際造訪節點數與 `MP` 的關係,而非只驗證輸出正確性

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/board/board_reachable_tiles_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: story-001(需要 `passable()` 查詢方法先存在)
- Unlocks: story-007(移動範圍四態查詢介面直接建立在本 story 的四種布林組合輸出之上)
