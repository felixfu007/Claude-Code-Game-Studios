# Story 001: 地形 `passable` 布林旗標與未知地形字元明確失敗

> **Epic**: 戰棋移動與交戰系統(#4)—— `production/epics/tactical-combat/EPIC.md` M2
> **Status**: ✅ **Complete**(2026-09-29 —— 實作 + 6 條測試皆完成,協調者**獨立重跑全套測試驗證**:`969 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans`,exit 100。基線 963 → 969 正好是本 story 新增的 6 條;唯一失敗是既有那條刻意紅且已核准的 `affinity_phi_provider` 測試,非本 story 造成)
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S(半天內)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)

## Context

**GDD**: `design/gdd/tactical-combat-system.md` —— Formulas 公式三(`passable(tile)` 變數定義)、
Tuning Knobs #4(`terrain_cost` 與 `passable` 地形表)、Core Rules #2(可否通行為與移動成本正交的
獨立地形屬性)。

**Requirement**: `TR-tactical-002`(現行文字待更正,見下方 🔴)

⚠️ **`TR-tactical-002` 現行文字尚未反映本 story 的範圍,且更正義務(EPIC.md C5 擁有者指派)
截至本次派工**尚未執行****:
```
$ grep -n "TR-tactical-002" docs/architecture/tr-registry.yaml
37:  - {id: TR-tactical-002, ..., requirement: "地形須有兩個正交逐格屬性(terrain_cost>=1、遮蔽布林值),並有載入時驗證", ...}
```
現行文字只寫「兩個」屬性(`terrain_cost`、遮蔽布林值),未涵蓋本 story 新增的第三個屬性
`passable`。EPIC.md 已登記此更正屬 `technical-director` 擁有,期限「M2 的 story 切出來之前」——
**該義務未在本 story 切出前完成**,已在 `story-index.md` 誠實記錄。**本 story 的驗收條件
一律以 GDD 公式三/Tuning Knobs #4 原文為準,不以 `TR-tactical-002` 現行文字為準**
(EPIC.md 明文的保險條款)。

**ADR Governing Implementation**: 無直接管轄 ADR —— 本 story 只動 `Board`(資料層),
不涉及 `BattleController`/`BattleState` 的查詢原子性契約(ADR-0001 管轄範圍見 M3/M3b)。
`ADR: N/A —— 純資料表擴欄與資料驗證,無跨系統契約`

**Engine**: Godot 4.7.1 | **Risk**: LOW(純 GDScript 資料結構,無 post-cutoff API)

**Control Manifest Rules(Core 層)**:
- Forbidden:「絕不以節點樹/`get_node()` 導出佔位」—— 不適用本 story(本 story 不碰佔位),
  僅供下一位讀者確認本 story 未觸及該範圍
- 一般紀律(`.claude/docs/coding-standards.md`):**絕不用 `assert()` 保護「不可達」分支** ——
  本 story 的核心風險(R1)正是這一條的具體案例,見下方 Implementation Notes

## 現況(2026-09-29 實測,逐指令)

```
$ grep -c "passable" src/gameplay/board/board.gd
0
```
`passable` 概念在 `Board` 中完全不存在。現行 `board.gd`(166 行)全文已讀,關鍵現況:

```gdscript
const TERRAIN_OPEN: String = "."
const TERRAIN_BRUSH: String = ","
const TERRAIN_FALLEN_LOG: String = "#"

const MOVE_COST: Dictionary = {
	TERRAIN_OPEN: 1,
	TERRAIN_BRUSH: 2,
	TERRAIN_FALLEN_LOG: 3,
}

func get_move_cost(pos: Vector2i) -> int:
	var terrain: String = get_terrain(pos)
	return MOVE_COST.get(terrain, MOVE_COST[TERRAIN_OPEN])
```

`get_terrain()` 對未登記地形字元回傳 `TERRAIN_OPEN`(見其文件註解「Defaults to TERRAIN_OPEN
if the tile was never set」),`get_move_cost()` 對未登記地形字元靜默取平地成本 —— **這是 R1
風險的確切位置**:新增 `passable` 資料表若與 `MOVE_COST` 不同步,新地形會同時「成本當平地」
且「`passable` 取預設 `true`」,一面牆會變成一片可以走過去的空地,且畫面上完全正常。

## Acceptance Criteria

*直接依 GDD 公式三 + Tuning Knobs #4,不引用 TR 文字(見上方保險條款):*

- [ ] `Board` 新增 `passable(tile: Vector2i) -> bool` 查詢方法,依地形字元查表,**與 `terrain_cost`
      同一張表的第二欄**(GDD Tuning Knobs #4 明文:「未來新增牆壁/水域/懸崖等不可通行地形時,
      只需在本表新增一列並將該欄設為 `false`」——**不新增第二個字元平面、不新增檔案**,
      `Board.from_ascii(rows: PackedStringArray)` 簽章不變)
- [ ] 三個既有地形種類(平地/森林/山地)皆為 `passable=true`(GDD Tuning Knobs #4 起始值)
- [ ] `passable(origin)` 恆為 `true` 這一隱性不變量在本 story 範圍內成立(GDD 公式三變數表
      明文;地形中途改變的邊界屬 Edge Cases「地形動態演變的邊界」既有待補項,**不在本 story
      範圍**——本 story 只保證靜態地形表下的不變量)
- [ ] **未登記地形字元須明確失敗**,不得靜默取平地成本或 `passable=true`(R1 緩解,GDD 未明文
      要求但屬本 story 判斷的資料完整性義務——理由見下方 Implementation Notes)。**失敗方式
      必須是 `push_error()` + 顯式非成功回傳值,絕不可用 `assert()`**(`.claude/docs/coding-standards.md`
      2026-09-15 記載:`assert()` 失敗會中止呼叫函式,並讓函式回傳其宣告回傳型別的序數 `0`——
      若該型別的成功值恰為序數 `0`〔近乎普遍慣例〕,失敗的斷言會靜默回傳「成功」)
- [ ] `passable=false` 的地形,其 `terrain_cost` 欄位仍須是合法值(建議沿用平地 `1`)作為佔位,
      不得留空造成資料驗證歧義(GDD Tuning Knobs #4 明文)

## Implementation Notes

1. 🔴 **R1 緩解是本 story 存在的直接理由,不是順手加的防禦性程式碼。** 現行 `get_move_cost()`
   對未登記地形字元的 fallback 行為,若不同步處理,會讓「新增一列 `passable=false` 卻忘了同步
   `MOVE_COST`」這個操作失誤變成靜默漏洞——牆會變成可通行的平地。本 story 必須讓「地形字元未登記」
   這件事本身變成一個會被看見的錯誤,而不是讓它繼續靜默 fallback。
2. **資料表擴欄的具體形狀由本 story 決定**,GDD 只定案「二欄查表、不新增字元平面」。建議:
   將現行 `MOVE_COST: Dictionary`(單值)擴充為每個地形字元對映一個結構(例如
   `{cost: int, passable: bool}` 的巢狀 `Dictionary`,或新增一個平行的 `PASSABLE: Dictionary`)——
   兩種寫法皆滿足 GDD 要求,取捨屬本 story 實作者判斷,無需另外裁決。
3. **不得**新增 `TERRAIN_WALL` 一類的「第四地形階層」,也**不得**用 `terrain_cost = 極大值`
   模擬不可通行——GDD Tuning Knobs #4 原文明文兩者皆未採用,`passable` 是與 `terrain_cost`
   正交的獨立布林屬性。
4. `blocks_sight(pos)` 與 `passable(pos)` 是兩個不同的地形屬性(視線 vs 通行),不得合併查詢或
   共用同一張表的同一欄——現行 `BLOCKS_SIGHT: Dictionary` 已是獨立表,`passable` 應比照同一模式
   新增為第三張獨立表(或欄),不與前兩者混用。
5. ⚠️ **未查證**:GDD Tuning Knobs #4 提到「`passable=false` 格數佔比過高的風險」與
   `max_occlusion_ratio` 的雙重壓縮交互,但明文「本節暫不比照 `max_occlusion_ratio` 訂出具體
   佔比上限」——本 story 不需要為此新增任何驗證,僅供實作者知悉此為刻意留白,非遺漏。

## Out of Scope

- **`reachable_tiles()` 本身的簽章與演算法變更**——見 story-002,依賴本 story 的 `passable()`
  查詢方法先存在。
- **`ignore_passability` 參數**——同上,屬 story-002。
- **地形中途動態改變的行為**——GDD Edge Cases 明文「本系統目前不定義行為」,待系統 #14。
- **`TR-tactical-002` 文字本身的更正**——擁有者為 `technical-director`,不由本 story 代為修改
  `docs/architecture/tr-registry.yaml`。

## QA Test Cases

⚠️ **本節由 `lead-programmer` 依 GDD AC 直接撰寫,非 `qa-lead` 產出** —— 本次派工的執行環境
未提供 Task 工具,無法依 `/create-stories` Step 4b 執行 QL-STORY-READY 覆核關卡與 qa-lead
測試規格產出。下一次有 Task 工具可用時,建議對本節內容補跑一次 QL-STORY-READY 覆核。

- **`passable()` 起始三地形皆為 true**
  - Given: 由 `from_ascii()` 建構,含平地/森林/山地三種字元的棋盤
  - When: 對每一格呼叫 `passable(pos)`
  - Then: 全部回傳 `true`
- **`passable=false` 新地形正確排除**
  - Given: 資料表新增一個 `passable=false` 的地形字元(測試專用,不需要正式美術/關卡資料)
  - When: 對該地形格呼叫 `passable(pos)`
  - Then: 回傳 `false`;同格呼叫 `get_move_cost(pos)` 回傳一個合法佔位值(非崩潰、非負值)
- **未登記地形字元明確失敗**
  - Given: 一個不在資料表中的地形字元
  - When: 呼叫 `passable(pos)` 或 `get_move_cost(pos)`
  - Then: 觸發 `push_error()`,回傳值為明確定義的非成功哨兵(不得是靜默 fallback 到平地)
  - Edge cases: 驗證該路徑**不使用** `assert()`——可用「呼叫後函式仍正常返回一個可檢查的哨兵值」
    作為測試斷言,若函式改用 `assert()` 實作,此測試在 `--headless` 下應能偵測到序數 `0` 被
    誤讀為成功這件事(視實際回傳型別設計,若回傳 `bool`,`assert()` 誤用會使測試讀到 `false`
    的序數 `0`,恰好可能與「正確的失敗值」混淆——**建議回傳型別避開 `bool`,改用具名 enum 使
    序數 0 不代表「地形不可通行」這個合法値以外的任何東西**,以確保這條測試向量有意義)
- **`passable=false` 地形 `terrain_cost` 佔位值合法**
  - Given: `passable=false` 的地形
  - When: 呼叫 `get_move_cost(pos)`
  - Then: 回傳一個 `≥1` 的合法整數(佔位值,不具運算意義,但不得是哨兵/負值/崩潰)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/board/board_passable_test.gd` —— 必須存在且通過(BLOCKING)

**Status**: [x] ✅ 已建立並通過 —— `tests/unit/gameplay/board/board_passable_test.gd`(6 條測試,涵蓋 QA Test Cases 全部 4 組 + 2 條額外:`passable(origin)` 不變量、`push_error` 而非 `assert()` 的路徑)。**未改動 `const` 字典**,以測試專用子類別 `_BoardWithImpassableTestTerrain` 注入 `passable=false` 地形,符合測試隔離紀律

## Dependencies

- Depends on: None(⚠️ 但 EPIC.md C5 擁有者義務——`technical-director` 更正 `TR-tactical-002`——
  截至本 story 切出時**尚未完成**,見上方 Context 節。本 story 未因此暫停,已改採 GDD 原文
  為驗收依據)
- Unlocks: story-002(`reachable_tiles()` 改寫需要本 story 的 `passable()` 查詢方法)、
  story-007(移動範圍四態查詢需要 `passable()`/`ignore_passability` 兩者皆已落地)、
  story-015(不可通行地形的世界層呈現)
