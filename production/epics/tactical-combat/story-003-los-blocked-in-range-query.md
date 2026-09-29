# Story 003: 「射程內但視線被擋」查詢(攻擊疊加圖第三層資料源)

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M3a(切面 2)
> **Status**: Ready
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

- [ ] 新增查詢(暫名 `attack_targets_blocked_by_los(unit_id)` 或等效方法,**介面形狀由本 story
      決定**,UX 規格與 GDD 皆只定案「必須有這個切面可查」,不定案方法簽章)——回傳「距離在
      `[min_range, max_range]` 內,但視線被地形遮蔽阻擋」的座標集合
- [ ] 與現有 `attack_targets()`(合法可攻擊)、純距離判斷(範圍內/外)三者**互斥**:任一格
      恰好屬於「無疊加」「合法可攻擊」「範圍內但不可攻擊」三者之一(GDD Visual/Audio §1.3)
- [ ] 近戰(`max_range=1`)**不需要**第三態——GDD 明文「近戰不受視線檢查,其範圍疊加圖只需
      二元狀態,不需實作第三態」,本查詢對近戰武器應恆回傳空集合(結構性保證,非特判)
- [ ] 視線判定沿用既有 `LineOfSight`/Bresenham 類穿角規則(AC-16),**不得**另建一套視線演算法
      —— 本專案已登記「同一公式兩份實作」是高風險形狀(見 `.claude/docs/technical-preferences.md`
      對此類問題的多次記載),本 story 必須呼叫既有的視線判定函式,不得重新推導
- [ ] 遵守 ADR-0001 查詢原子性:輸出攜帶 `combat_state_version`,與 `attack_targets()` 若同時
      呈現則共用同一份快照

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

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/battle/attack_los_blocked_query_test.gd` —— BLOCKING

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(不依賴 M2,可與 story-001/002 同日開工)
- Unlocks: story-014(M4 世界層第三層高亮繪製)
