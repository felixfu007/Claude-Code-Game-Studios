# Story 003: 「射程內但視線被擋」查詢(攻擊疊加圖第三層資料源)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M3a(切面 2)
> **Status**: ✅ Done(2026-09-30,`gameplay-programmer`)——見下方「實作進度」節逐條 AC 現況、
> 已知未完成範圍(`combat_state_version` 僅部分合規)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: 2026-09-09

## Context

**GDD**: Visual/Audio §1.3(視線遮蔽三層:無疊加/合法可攻擊/範圍內但不可攻擊)、
Core Rules #4(視線遮蔽規則)、AC-5/AC-16(視線判定演算法、穿角規則)、UX 規格
`design/ux/tactical-combat-screen.md` 6.3 節(「沒有單獨的『範圍內但視線被擋』查詢」)。

**Requirement**: `TR-tactical-019`(視線純格狀幾何 Bresenham 類演算法)、`TR-tactical-020`
(曼哈頓用於射程/移動,Bresenham 用於視線,絕不混用)

**ADR Governing Implementation**: `ADR-0001`(戰棋查詢介面原子性契約,**Accepted**)——
本查詢是「本文件對外提供的查詢介面」之一(GDD Core Rules #10 總則),須遵守即時性 + 單一
快照原子性義務(AC-22)。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純幾何演算法,無 post-cutoff API 依賴——現有
`LineOfSight`/`line_of_sight.gd` 已實作 Bresenham 類穿角規則,本 story 是在既有演算法上
新增一個回傳形狀,不是重新實作視線判定本身)

**Control Manifest Rules(Core 層)**:
- 「合成查詢的所有子結果必須攜帶同一版本號(`assert_same_version`)」—— 若本 story 的輸出
  與既有 `attack_targets()` 合併判讀為單一畫面(GDD AC-22(b)「並存疊加圖共用快照」),
  兩者須共用同一份 `combat_state_version` 快照
- 「每個查詢結果攜帶它所計算的版本號;有效性判準以 `result.is_stale()` 為準」

## 現況(2026-09-29 實測)

```
$ grep -n "_attack_targets_for" -A 15 src/gameplay/battle/battle_controller.gd
```
（見 UX 規格 6.3 節已附之現況引用,本 story 不重新貼出全文,依單一定義來源規則——已核對
`_attack_targets_for()` 回傳的是「距離在射程內**且**視線暢通」的最終合法集合,**沒有**
「範圍內但視線被擋」的獨立查詢。GDD Visual/Audio §1.3 要求的第三層目前無資料來源可畫。

## Acceptance Criteria

*依 GDD Visual/Audio §1.3、AC-5、AC-16,不新增規則,只新增查詢介面暴露既有判定的中間結果:*

- [x] 新增查詢(暫名 `attack_targets_blocked_by_los(unit_id)` 或等效方法,**介面形狀由本 story
      決定**,UX 規格與 GDD 皆只定案「必須有這個切面可查」,不定案方法簽章)——回傳「距離在
      `[min_range, max_range]` 內,但視線被地形遮蔽阻擋」的座標集合
- [x] 與現有 `attack_targets()`(合法可攻擊)、純距離判斷(範圍內/外)三者**互斥**:任一格
      恰好屬於「無疊加」「合法可攻擊」「範圍內但不可攻擊」三者之一(GDD Visual/Audio §1.3)
- [x] 近戰(`max_range=1`)**不需要**第三態——GDD 明文「近戰不受視線檢查,其範圍疊加圖只需
      二元狀態,不需實作第三態」,本查詢對近戰武器應恆回傳空集合(結構性保證,非特判)
- [x] 視線判定沿用既有 `LineOfSight`/Bresenham 類穿角規則(AC-16),**不得**另建一套視線演算法
      —— 本專案已登記「同一公式兩份實作」是高風險形狀(見 `.claude/docs/technical-preferences.md`
      對此類問題的多次記載),本 story 必須呼叫既有的視線判定函式,不得重新推導
- [x] 遵守 ADR-0001 查詢原子性:輸出攜帶 `combat_state_version`,與 `attack_targets()` 若同時
      呈現則共用同一份快照 ⚠️**部分實作,見下方「實作進度」節的阻擋項與逐條 AC 現況表——
      `combat_state_version` 已存在且本 story 相關的兩個 mutator 已遞增,但完整 ADR-0001
      合規(寫入守衛、`TurnOrder`/`Board` 全部 mutator 遞增)不在本 story 範圍內**

## Implementation Notes

1. **本 story 是暴露既有判定的中間結果,不是新增規則**——`_attack_targets_for()` 內部必然已經
   在某處算過「距離合法但視線不合法」這個中間狀態(否則無法產生最終的合法集合),本 story
   的核心工作是把這個中間狀態變成一個可獨立呼叫的公開查詢,而不是重新設計視線判定邏輯。
   ⚠️ **未查證**:`_attack_targets_for()` 內部是否已經用某種形式暫存了「距離合法但視線被擋」
   的候選集合,或是否需要重構才能暴露——下一個人應先讀該函式的實作,而非假設現成資料結構
   已存在。
2. **與盲區的邊界(GDD 明文的一致性要求)**:遠程近身盲區(距離 `< min_range`)**不屬於**
   「射程內但視線被擋」——盲區格根本不落在 `[min_range, max_range]` 區間內,不應被本查詢的
   輸出涵蓋。GDD UI Requirements §1a 已明文「盲區格本來就不在敵方的威脅範圍內……因此威脅
   範圍疊加圖與盲區的呈現裁決不衝突」,本 story 的第三層查詢同理須排除盲區距離。

## Out of Scope

- **世界層的實際繪製(第三層高亮圖形)**——story-014(M4),依賴本 story 的查詢輸出。
- **威脅範圍(`threat_range`)本身刻意省略視線的設計**——GDD 公式四已定案威脅範圍不檢查視線,
  這是刻意的保守近似,與本 story 的「合法攻擊範圍」查詢是不同介面,不得混淆或合併。
- **近戰武器的視線檢查**——結構性不適用,不需要任何特判程式碼路徑,只需確保不會產生非空
  輸出即可(依演算法本身:`max_range < 2` 時視線判定本就不會被觸發)。

## QA Test Cases

⚠️ QL-STORY-READY 覆核關卡因 Task 工具不可用而跳過,本節由 `lead-programmer` 直接撰寫。

- **三層互斥且窮盡**
  - Given: 一個含遮蔽地形的小型盤面、一名遠程單位
  - When: 分別查詢無疊加/合法可攻擊/範圍內但視線被擋 三個切面
  - Then: 每一格恰好屬於三者之一,無重複、無殘留
- **視線暢通格不進入第三層**
  - Given: 距離合法且視線暢通的格
  - When: 呼叫第三層查詢
  - Then: 該格不在輸出中(應出現在合法可攻擊集合)
- **近戰武器恆回傳空集合**
  - Given: `(1,1)` 近戰武器
  - When: 呼叫第三層查詢
  - Then: 回傳空集合,不論盤面遮蔽狀況
- **盲區格不計入第三層**
  - Given: 遠程武器 `(2,4)`,目標距離 `1`(在盲區內)
  - When: 呼叫第三層查詢
  - Then: 該格不在輸出中(不屬於本查詢的定義域,屬「無疊加」)
- **穿角規則沿用既有實作(AC-16 對照)**
  - Given: 穿角偏移案例(參照 GDD AC-16 向量表,例如 `(1,1)` 偏移、兩側恰一格遮蔽)
  - When: 呼叫第三層查詢與既有 `attack_targets()`/視線判定
  - Then: 兩者對同一輸入的視線判定結果一致(交叉驗證未重新實作視線演算法)

## 實作進度(進行中,2026-09-30,`gameplay-programmer`)

> 本節是中途查證產出的落地,不是最終交付摘要 —— 撞回合上限前寫入,之後每完成一段會再更新。

### 已讀檔案與確認事實(實測)

- **`src/gameplay/board/line_of_sight.gd`**(`class_name LineOfSight`,`extends RefCounted`):
  唯一公開介面 `static func is_clear(from: Vector2i, to: Vector2i, is_occluding: Callable) -> bool`。
  純幾何、無棋盤知識,遮蔽完全由呼叫端傳入的 `is_occluding` callback 決定。已含穿角規則
  (兩側恰一格遮蔽時視「兩側皆遮蔽才算擋」)。**本 story 不得重新實作這支,只能呼叫它。**
- **`src/gameplay/combat/combat_rules.gd`**(`class_name CombatRules`):
  - `static func is_in_range(from, to, min_range, max_range) -> bool`——曼哈頓距離落在
    `[min_range, max_range]` 內;距離 0 恆 `false`。
  - `static func is_attack_legal(from, to, min_range, max_range, is_occluding) -> bool`——
    先呼叫 `is_in_range`;**只有曼哈頓距離 `>= 2` 才額外呼叫 `LineOfSight.is_clear`**,
    距離 1(近戰/中程最短距離)**結構性跳過視線檢查**。這正是 AC 第三條「近戰恆回傳空集合」
    的結構性保證來源:若 `max_range=1` 則唯一合法距離是 1,永遠不會走到視線分支。
- **`src/gameplay/battle/battle_state.gd`**(465 行):
  - `func can_attack(attacker_id, target_id) -> bool`——先查存活+非同陣營,再呼叫
    `is_attack_reachable(attacker_id, position_of(attacker_id), position_of(target_id))`。
  - `func is_attack_reachable(attacker_id, from, to) -> bool`——**純幾何/佔位無關的
    predicate**,建構 `is_occluding = func(cell): return board.blocks_sight(cell)`,
    呼叫 `CombatRules.is_attack_legal(from, to, attacker.min_range, attacker.max_range,
    is_occluding)`。`from` 允許是假設性座標,不要求等於單位目前站位——**這支方法是本 story
    新查詢最自然的複用點**,因為它已經把「距離+視線」兩件事都算好了,只是回傳單一 bool
    而非分辨「哪一半不合法」。
  - `func position_of(id)` / `func unit_by_id(id)` / `func units_of(faction)` 皆為既有可用查詢。
  - 🔴 **`grep -rn "combat_state_version" src tests` 零命中**(見下方「阻擋項」)。
- **`src/gameplay/battle/battle_controller.gd`**(1126 行):
  - `func attack_targets() -> Array[Vector2i]` 委派 `_attack_targets_for(_selected_unit_id)`——
    只回傳「距離合法**且**視線暢通」的最終合法集合,只列有敵人站立的格子(遍歷
    `_state.units_of(opposing)`,逐一呼叫 `_state.can_attack(unit_id, enemy.id)`)。
  - `func threat_targets() -> Array[Vector2i]` 委派 `_threat_targets_for()`——**這支是本 story
    最接近的既有範例**:遍歷**整個棋盤**(`for y in range(Board.BOARD_HEIGHT): for x in
    range(Board.BOARD_WIDTH)`),對每一格呼叫 `_state.is_attack_reachable(unit_id, origin,
    cell)`,不要求該格有敵人站立。本 story 的第三層查詢性質上更接近這支(逐格幾何查詢),
    不是 `attack_targets()`(逐敵查詢)——**已與 GDD Visual/Audio §1.3 交叉核對**:三層模型
    定義在「格」上,不在「敵人」上,故新查詢必須比照 `_threat_targets_for()` 遍歷整個棋盤,
    而非遍歷 `units_of(opposing)`。
  - 現有 `_tile_less()` 靜態比較器(ascending y,x)可直接複用排序。
  - 現有 `_opposing_faction()` 靜態方法可複用,但**本查詢是否需要陣營觀念待定**——見下方
    「未查證」。

### GDD/設計面已核對事實

- GDD Visual/Audio §1.3(`design/gdd/tactical-combat-system.md`)三層表:
  `無疊加`=距離不在 `[min_range,max_range]`;`合法可攻擊`=距離在區間內且視線暢通;
  `範圍內但不可攻擊`=距離在區間內但視線被擋。**近戰(§1.3 明文)**:「近戰不受視線檢查,
  其範圍疊加圖只需二元狀態,不需實作第三態」。
- UX 規格 `design/ux/tactical-combat-screen.md` 6.3 節列出候選改動檔案包含
  `battle_state.gd`(或 `LineOfSight` 相關檔)新增「距離在射程內但視線被擋」的判斷,以及
  `battle_controller.gd` 新增對外查詢——**兩者都在允許修改範圍內,不需要動 `board.gd`**。

### 打算改的檔案與簽章(草案,尚未寫入程式碼)

1. **`src/gameplay/combat/combat_rules.gd`**——新增
   `static func is_attack_in_range_but_blocked(from, to, min_range, max_range, is_occluding)
   -> bool`,邏輯:`is_in_range(...)` 為真,且(距離 `>=2` 時)`not LineOfSight.is_clear(...)`。
   這樣「合法可攻擊」「範圍內但不可攻擊」兩個判斷共用同一份 `is_in_range`/`LineOfSight` 呼叫,
   不重新推導視線演算法。
2. **`src/gameplay/battle/battle_state.gd`**——新增
   `func is_attack_range_blocked_by_los(attacker_id: int, from: Vector2i, to: Vector2i) -> bool`,
   鏡射 `is_attack_reachable()` 的簽章與 `is_occluding` 建構方式,呼叫上面新增的
   `CombatRules.is_attack_in_range_but_blocked`。
3. **`src/gameplay/battle/battle_controller.gd`**——新增
   `func attack_targets_blocked_by_los() -> Array[Vector2i]`(比照 `attack_targets()`/
   `threat_targets()` 的「無參數走 `_selected_unit_id`」慣例)+ 私有
   `func _attack_targets_blocked_by_los_for(unit_id: int) -> Array[Vector2i]`,遍歷整個棋盤
   (比照 `_threat_targets_for()` 的雙層 for),排除單位自己當前格,呼叫
   `_state.is_attack_range_blocked_by_los(unit_id, position_of(unit_id), cell)`,
   `_tile_less` 排序。**Gating 比照 `_attack_targets_for()`**:phase/selection/
   `_order.can_attack(unit_id)`。

### 未查證(動手前必須確認)

- **本查詢的原點(`from`)是否只用「單位目前站位」,還是也要比照 `threat_targets()` 納入
  「移動後」的假設站位?** AC 原文只講「距離在 `[min_range,max_range]` 內」,對照的是
  `attack_targets()`(只用目前站位,不含移動後),而非 `threat_targets()`。**傾向只用目前
  站位**(與 `attack_targets()` 對稱,兩者是同一份疊加圖的兩個互斥切面),但尚未在程式碼
  或回報前最終確認——這會決定新方法是否需要 `origins` 陣列或只需單一 `current_pos`。
- **是否需要排除「該格已被己方或敵方單位佔據」以外的任何格?**——第三層定義是純幾何
  (距離+視線),不看佔位;`_threat_targets_for()` 同樣不看佔位(只排除單位自己的格)。
  傾向沿用同一原則,但尚未寫測試驗證。
- **`CombatModifier` 是否能改變 `min_range`/`max_range`?** 尚未讀 `card_modifier_rules.gd`/
  `card_modifier.gd` 確認——若可以,`combat_state_version` 遞增時機清單需涵蓋modifier tick,
  但這不影響本查詢的「讀取」邏輯本身(它讀 `attacker.min_range`/`attacker.max_range` 現值,
  自動反映任何已生效的改動;唯一有影響的是下面 ADR-0001 版本戳記怎麼算)。

### 增量進度更新(第二次寫檔)

**已完成(實測——已寫入程式碼,尚未跑測試)**:
- `src/gameplay/combat/combat_rules.gd`:新增 `static func is_attack_blocked_by_los(from, to,
  min_range, max_range, is_occluding) -> bool`,緊接在 `_manhattan_distance` 之前。組合既有
  `is_in_range` + `LineOfSight.is_clear`,未新增任何幾何演算法。
- `src/gameplay/battle/battle_state.gd`:
  1. 新增 `_combat_state_version: int`(私有)+ `combat_state_version` 對外唯讀 property
     (外部賦值觸發 `push_error()`,值不變)——依 ADR-0001 給的確切寫法。**明文標註這是
     Mechanism One 的部分實作,非完整合規**(理由與範圍已寫入該變數的文件註解)。
  2. `move_unit()` 成功路徑結尾、`resolve_attack()` 結尾各新增一行 `_combat_state_version += 1`。
  3. 新增 `func is_attack_range_blocked_by_los(attacker_id, from, to) -> bool`,鏡射
     `is_attack_reachable()` 的形狀,呼叫新增的 `CombatRules.is_attack_blocked_by_los`。

**尚未開始**:~~`battle_controller.gd` 的對外查詢方法(`attack_targets_blocked_by_los()` +
`_attack_targets_blocked_by_los_for()`)、測試檔案 `tests/unit/gameplay/battle/
attack_los_blocked_query_test.gd`。**下一步就是這兩項。**~~

### 第三次寫檔(交付):已完成

- `battle_controller.gd` 新增 `func attack_targets_blocked_by_los() -> Array[Vector2i]`
  (無參數,走 `_selected_unit_id`,比照 `attack_targets()`/`threat_targets()` 慣例)+
  私有 `func _attack_targets_blocked_by_los_for(unit_id: int) -> Array[Vector2i]`。
- 測試檔 `tests/unit/gameplay/battle/attack_los_blocked_query_test.gd` 已建立,15 條測試,
  涵蓋全部 5 條 QA Test Case + 排序 + 3 種空集合情境 + `combat_state_version` 最小範圍行為
  (外部寫入拒絕、move/resolve_attack 各遞增一次、被拒絕的 move 不遞增、純讀取不遞增)。
- **測試執行結果(2026-09-30,原始輸出,見下方 Test Evidence 節)**:993 test cases,
  0 errors,1 failures(既有已核准的 `affinity_phi_provider_test.gd` 那條),0 orphans,
  exit code 100。**978(協調者提供的基線)+ 15(本檔新增測試數)= 993,吻合**——本 story
  新增的 15 條測試全數通過,失敗數未從基線的 1 上升。

### 逐條 AC 現況

| AC | 現況 |
|---|---|
| 新增查詢 `attack_targets_blocked_by_los(unit_id)` 或等效方法 | ✅ **通過**——`BattleController.attack_targets_blocked_by_los()`(無參數,走 `_selected_unit_id`,與 `attack_targets()`/`threat_targets()` 同慣例) |
| 與 `attack_targets()`、純距離判斷三者互斥 | ✅ **通過**——測試 `test_los_blocked_cell_in_third_layer_clear_cell_in_attack_targets_mutually_exclusive`(互斥交叉核對)+ `test_third_layer_cells_are_always_within_the_min_max_range_band`(第三層恆為射程內子集,不殘留盲區/範圍外格子)。⚠️ **範圍界定**:「合法可攻擊」層依 AC 原文字面等同既有 `attack_targets()`(只列有敵人站立且合法的格子),不是「距離內+視線暢通」的完整幾何集合——後者目前沒有對應的既有查詢可比對,若未來需要,是另一次決策 |
| 近戰恆回傳空集合(結構性保證) | ✅ **通過**——測試 `test_melee_weapon_always_returns_empty_regardless_of_terrain`(緊鄰格刻意標記遮蔽仍回傳空集合,證明是結構性保證而非碰巧)。`CombatRules.is_attack_blocked_by_los` 對距離 <2 直接 `return false`,不呼叫 `is_occluding`,與 `is_attack_legal` 共用同一個「距離 2 以上才查視線」分支 |
| 沿用既有 `LineOfSight`/視線判定,不重新實作 | ✅ **通過**——新增的 `CombatRules.is_attack_blocked_by_los` 只組合既有 `is_in_range` + `LineOfSight.is_clear`,未新增任何幾何演算法;測試 `test_corner_clip_both_flanks_blocked_matches_existing_is_attack_reachable`/`test_corner_clip_only_one_flank_blocked_matches_existing_is_attack_reachable` 逐一交叉核對新查詢與既有 `BattleState.is_attack_reachable()` 對同一輸入回報相反布林值(同一份判定的兩面) |
| 遵守 ADR-0001:輸出攜帶 `combat_state_version`,與 `attack_targets()` 若同時呈現則共用同一份快照 | **⚠️ 部分實作,非完整合規**——`combat_state_version` 已存在(`BattleState`,對外唯讀,`move_unit()`/`resolve_attack()` 各遞增一次,已有測試覆蓋),兩個查詢都是純讀取、無中間寫入,故同步呼叫時結構上必然讀到同一個版本號。**未實作**:`authoritative_write_in_progress` 寫入守衛、`commit_authoritative_change()` 單一入口、`TurnOrder` 五個 mutator 與 `Board` 兩個 mutator 的遞增(後者需改 `board.gd`,本次派工明文禁止)。見下方阻擋項全文,**標記為需要 `lead-programmer`/`technical-director` 裁決的跨 story 架構問題**,不影響本 story 其餘 AC 通過 |

### 🔴 阻擋項:`combat_state_version` 在全專案零實作,完整 ADR-0001 合規範圍遠大於本 story

`grep -rn "combat_state_version\|QueryResult\|is_stale\|assert_same_version" src/ tests/` **零命中**——
與 `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` 自己記載的「三個契約欄位零命中」
現況一致,尚未被任何story建立。已讀該 ADR 的機制一/機制二/五條硬性義務段落,確認完整合規包含:

1. `combat_state_version` 計數器(讀碼判定:**應掛在 `BattleState`**,不得掛在 `Board`——ADR
   自己有專節推導「為什麼不能留在 Board」)。
2. **六條已提交寫入路徑的遞增時機**,其中 `Board.set_occupant/clear_occupant` 與
   `TurnOrder.use_move/use_attack/end_unit_turn/advance_faction/remove_unit` 都在清單內。
3. `authoritative_write_in_progress` 寫入守衛(機制二,防重入)。
4. `Unit` 的裸公開欄位(`hp`/`atk`/`def`/`mp`/`min_range`/`max_range`)需要先長出 setter。
5. 🔴 **五條硬性義務第 4 條明文要求「`Board.set_occupant()`/`clear_occupant()` 收進提交方法內部,
   不再對外公開」——這需要修改 `board.gd`**,而本次派工單明文禁止本人修改該檔(另一位正在改
   story-002)。

**這代表完整 ADR-0001 合規不是本 story 能獨立完成的範圍**——它是 story-004/005/006/007(同批
M3a,同樣受 ADR-0001 管轄、同樣列「依賴:無」)全部都會撞到的同一件事,若各自獨立生出一份
"combat_state_version" 實作,正是本專案已多次登記的「同一份東西兩份實作」風險形狀。

**目前傾向的處置(尚未定案,待回報後由派工方決定)**:本 story 只在 `BattleState` 新增
`combat_state_version` 計數器本體(單調遞增整數 + 對外唯讀 property,依 ADR-0001 給的確切
寫法)與最小可重用的 `QueryResult`-like 回傳形狀(`cells` + `version` + `is_stale()`),並只在
`battle_state.gd` 自己已有的兩個 mutator(`move_unit()`、`resolve_attack()`)遞增——**不**在本
story 內嘗試把遞增串到 `TurnOrder` 的五個 mutator 或 `Board` 的兩個 mutator(後者被禁改)。
**這是刻意的部分實作,不是完整 ADR-0001 合規**,會在回報中明確標出,並標記為需要
`lead-programmer`/`technical-director` 裁決的跨 story 架構問題(4 張手足 story 都會需要同一份
東西)。

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/battle/attack_los_blocked_query_test.gd` —— BLOCKING

**Status**: [x] Created,15 條測試,全數通過

**執行指令**:
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s tests/gdunit4_runner.gd
```

**2026-09-30 原始輸出(`Overall Summary` 整行)**:
```
Overall Summary: 993 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (80/80)
Executed test cases : (993/993)
```
**Exit code: 100**(依 `.claude/docs/coding-standards.md`:`errors + failures > 0` → 100;
唯一失敗是既有已核准的 `affinity_phi_provider_test.gd > test_phi_reflects_a_pairing_polarity_flip_made_after_construction`,非本 story 造成)。978(基線)+15(本檔新增)=993,吻合。

## Dependencies

- Depends on: None(不依賴 M2,可與 story-001/002 同日開工)
- Unlocks: story-014(M4 世界層第三層高亮繪製)
