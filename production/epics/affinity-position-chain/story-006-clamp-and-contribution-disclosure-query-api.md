# Story 006: 夾限狀態與逐條貢獻總和查詢 API(M3 本系統側)

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: Ready
> **Layer**: Gameplay(控制清單「核心層規則(Core)」涵蓋範圍)
> **Type**: Logic
> **Estimate**: S(0.5～1 session)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`(UI Requirements、Edge Cases「原始和超出
夾限」條)
**需求**: GDD UI Requirements 逐字:「原始和被夾限壓回時,必須明示『已達上限/下限』」——
**本 story 只交付系統側的查詢能力,不交付畫面呈現**(見下方「本批範圍邊界」)。
**TR-ID**: ⚠️ 本系統(#5)尚未登記進 `tr-registry.yaml`。

**Governing ADR**: `ADR: N/A`——這是本系統內部新增的查詢介面,不是跨系統契約
(`.claude/docs/coding-standards.md` 2026-09-01 裁決:ADR 只為跨系統契約而寫)。
**具體 API 形狀由 lead-programmer 決定,EPIC.md 明文不指定**——本 story 即該決定的產出,
見下方 Implementation Notes。

**Engine**: Godot 4.7.1 | **Risk**: LOW

**Engine Notes**: 無 post-cutoff 風險,純函式新增。

**Control Manifest Rules(此層)**: 本 story 新增查詢函式,不涉及任何寫入路徑或跨幀狀態,
控制清單的寫入端規則(版本戳記、`authoritative_write_in_progress` 等)不適用。

---

## 🔴 本批範圍邊界(必須先讀,避免做超出範圍的事)

**本 story 只交付「系統側」——即 `affinity_rules.gd` / `affinity_line_status.gd`
新增的查詢能力,讓呼叫端能夠知道「原始和是多少、有沒有被夾限、夾到哪一邊」而不必自己
重新加總一次。**

**本 story 明確不交付**:
- 畫面上怎麼顯示「已達上限/下限」(顏色、圖示、文字提示)——那是 M3 消費端,依
  2026-09-29 管理者裁決 2,等 #5 的畫面規格(`design/ux/` 目前無好感度相關檔案,
  且 `tactical-combat-screen.md` 明文把好感度貢獻面板排除、歸給 #10)。
- `src/ui/battle/battle_screen.gd` 的任何修改——依本 epic `story-index.md` 的判斷,
  本 story 範圍結構上不需要碰這個檔案(新增的查詢函式在本批次不會被任何呼叫端使用)。
  ⚠️ **但這是判斷,不是保證**——若實作過程中發現需要在 `battle_screen.gd` 加一行呼叫
  才能驗證新 API,請先停下確認是否真的必要,不要順手加入(見下方排程限制)。

## Acceptance Criteria

*本 story 沒有現成的 GDD 驗收條件代號可用(GDD 的 UI Requirements 是敘述性需求,不是
BLOCKING 的自動化 AC),以下由本 story 作者依 GDD 原文轉寫為可測試的系統側行為:*

- [ ] 新增一個查詢函式(或擴充既有回傳型別),對給定的單位與站位,回傳:
  1. **原始和**(夾限前的逐條貢獻總和,可能超出 `[PHI_MIN, PHI_MAX]`)
  2. **是否被夾限**(布林值或等價表示——原始和是否落在 `[PHI_MIN, PHI_MAX]` 之外)
  3. **夾到哪一邊**(若被夾限,是撞到上界 `PHI_MAX` 還是下界 `PHI_MIN`)
- [ ] 呼叫端(未來的 UI 消費端)**不需要自行呼叫 `lines_for()` 再手動加總一次**來判斷
  是否被夾限——這正是 EPIC.md 風險 R-2 要防止的「UI 層長出第二份加總實作」。
- [ ] 新查詢的「原始和」與現有 `bonus_for_at()` 的「夾限後總和」在同一組輸入下必須一致
  (夾限前 vs 夾限後只差在有沒有套 `clampi()`,兩者的關係必須可驗證)。

## Implementation Notes

*具體 API 形狀由本 story 決定,以下是建議做法,非唯一解:*

- 最小改動路線:在 `affinity_rules.gd` 新增一個函式,例如
  `bonus_breakdown_for_at(unit_id, origin, positions, links) -> AffinityBonusBreakdown`,
  回傳一個小型資料物件(仿照 `AffinityLineStatus` 的風格,`RefCounted` 純資料持有者),
  含 `raw_sum: int`、`clamped_sum: int`(即現有 `bonus_for_at()` 的回傳值)、
  `is_clamped: bool`、`clamped_direction`(enum,例如 `NONE` / `UPPER` / `LOWER`)。
- **不要修改 `bonus_for_at()` 現有的回傳型別簽章**(`-> int`)——GDD Edge Cases 明文
  這是正常合法狀態,現有呼叫端(`battle_screen.gd` 6 處既有呼叫)預期收到一個
  `int`,改動簽章會是一次破壞性變更且超出本 story 範圍。新查詢應該是**額外新增**的
  函式,不是取代現有函式。
- 計算「原始和」與「是否被夾限」的邏輯應該**直接複用** `bonus_for_at()` 內部已經在做的
  加總(`for status in lines_for_at(...): total += status.delta`),不應該是第二份
  獨立實作——否則就是把 EPIC.md 風險 R-2 要防止的問題,從「UI 層」搬到「系統層自己
  內部」重犯一次。建議做法:讓 `bonus_for_at()` 內部呼叫新函式取得 breakdown,
  再從 breakdown 取 `clamped_sum` 回傳,確保只有一份加總邏輯。

## Out of Scope

- 畫面呈現(見上方「本批範圍邊界」)。
- `battle_screen.gd` 的任何修改。
- 陣亡回饋的快照(OQ-6,M4,本批不切)。

## QA Test Cases

*同 story-001,`lean` 模式跳過 qa-lead 正式規格產生,以下為作者依 GDD 原文直接轉寫:*

- **原始和與夾限狀態一致性**:
  - Given: 6 條正向距1線(理論和 +18,已知會被夾限——見 GDD AC-R7)
  - When: 呼叫新的 breakdown 查詢
  - Then: `raw_sum == 18`、`clamped_sum == 12`、`is_clamped == true`、
    `clamped_direction == UPPER`
- **未被夾限的情況**:
  - Given: 單條正向距1線(`+3`,遠低於上界 `+12`)
  - When: 呼叫新的 breakdown 查詢
  - Then: `raw_sum == clamped_sum == 3`、`is_clamped == false`
- **下界夾限**:
  - Given: 5 條負向距1線(理論和 −5)
  - When: 呼叫新的 breakdown 查詢
  - Then: `raw_sum == -5`、`clamped_sum == -4`、`is_clamped == true`、
    `clamped_direction == LOWER`

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/affinity/affinity_rules_test.gd` 內新增測試,
涵蓋上述三種情況(未夾限、上界夾限、下界夾限),今天會跑且通過。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None(本 story 不依賴 story-004/005 的任何產出——是否被夾限的計算邏輯
  與配對資料來源是靜態檔還是即時查詢無關)。
- Unlocks: 未來 M3 消費端(畫面呈現,本批不切)的前置能力。
- 🔴 **排程限制(協調者派工單明文要求,即使本 story 作者判斷結構上不需要碰
  `battle_screen.gd`)**:**本 story 與 story-005 不可同時派人**——見 story-005 的
  Dependencies 節,理由是 EPIC.md 風險 R-4 記載的共用檔案疑慮。建議待 story-005 Done
  後再排本 story,以策安全,即使本 story 作者的判斷是兩者的檔案接觸面並不真的重疊。
