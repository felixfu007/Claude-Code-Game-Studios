# Story 007: 兩份曼哈頓距離實作數量的結構紀律守衛(M5)

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: Ready
> **Layer**: Gameplay(控制清單「核心層規則(Core)」涵蓋範圍)
> **Type**: Logic
> **Estimate**: XS～S(0.5 session——EPIC.md 已指出有現成的同類型測試可仿照)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`(R2、Acceptance Criteria 節「無法自動涵蓋
的兩項」)
**需求**: R2——「距離一律用曼哈頓距離,與戰鬥射程判定採用相同定義」,**本次裁決允許兩份
獨立實作,但必須測到一致**。GDD 自己標註:「②R2 的『兩份曼哈頓實作是否仍只有兩份』——
那是結構性質,黑箱測試看不到,須以 grep/程式碼審查守著」。
**TR-ID**: ⚠️ 本系統(#5)尚未登記進 `tr-registry.yaml`。

**Governing ADR**: `ADR: N/A`——本 story 守護的是本系統與 `combat_rules.gd` 之間刻意
**不合併**的架構決定(GDD R2 裁決理由:「合併會讓 Gameplay 橫向耦合到戰鬥模組,收益低於
成本」),這是 GDD 層級的裁決,不是跨系統契約,不需要 ADR。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純文字掃描,不執行任何程式碼)

**Engine Notes**: 無。

**Control Manifest Rules(此層)**: 不適用——本 story 是文字掃描測試,不觸及任何寫入路徑
或 production 執行期行為。

---

## 這是什麼樣的測試(先讀,再動手,避免重造一種新做法)

`AC-R2` 本身(兩份實作的**輸出**是否一致)**已經有測試**
(`affinity_rules_test.gd:537`,黑箱比對,已在 EPIC.md 第 4 節確認)——**本 story 不是
要驗證輸出是否一致,是要驗證「曼哈頓距離的獨立實作,今天是不是仍然只有兩份」**這個
結構性質。黑箱輸出比對**永遠無法區分「共用同一函式」與「兩份剛好碰巧一致」**,而 R2
明文要求「兩份」這個數量本身要被守住(既不能悄悄合併成一份導致模組耦合裁決失效而沒人
發現,也不能悄悄長出第三份導致「兩份」這個已知假設不再成立)。

本專案**已有同類型的先例測試**可直接仿照:
`tests/unit/gameplay/affinity/affinity_link_no_direct_return_test.gd`——這是一支
「唯讀掃描 `.gd` 檔案文字、斷言原始碼紀律」的測試,依 `.claude/rules/test-standards.md`
2026-09-16 裁決屬**乙類例外**(唯讀 `src/**/*.gd` 與 `tests/**/*.gd` 的文字,用於斷言
原始碼紀律)。本 story 的測試性質完全相同,**照那支的形狀寫,不要發明新做法**。

## Acceptance Criteria

- [ ] 新增一支測試,掃描 `res://src` 底下的 `.gd` 檔案,統計「曼哈頓距離計算」的獨立實作
  數量,斷言**恰好為 2**(`AffinityRules.manhattan_distance()` 與
  `CombatRules._manhattan_distance()` 或其等價物)。
  - 若掃到 **少於 2**:代表其中一份被悄悄移除或合併,R2「允許兩份但必須測到一致」的
    前提假設(兩份各自獨立)不再成立,測試應該失敗並提示需要重新評估 R2 的裁決是否
    仍然適用。
  - 若掃到 **多於 2**:代表悄悄長出了第三份獨立實作,同樣違反 R2 明文的「兩份」假設,
    測試應該失敗並提示需要讓第三份也納入 AC-R2 的一致性比對,或移除多餘的一份。
- [ ] 測試檔頭依 `.claude/rules/test-standards.md` 乙類例外的**兩項義務**撰寫揭露:
  1. **為什麼不能用依賴注入或執行期檢查取代**——這條守護的是「原始碼裡有幾份獨立實作」
     這個文字層級的性質,沒有物件可以注入,也沒有執行期行為可以斷言(兩份實作即使
     輸出一致,執行期看起來完全一樣)。
  2. **本測試斷言範圍不等於窮盡性**——例如:若曼哈頓距離的計算邏輯改用不同的變數名稱、
     拆成多個輔助函式再組合,或藏在一個更泛用的距離計算函式內部(不再有一個獨立可辨識
     的「曼哈頓距離函式」),本測試的掃描方式可能失去偵測能力,需在檔頭列出已知盲點,
     比照 `affinity_link_no_direct_return_test.gd` 檔頭「Known gaps this scan does NOT
     close」的揭露水準。

## Implementation Notes

- 掃描方式建議:比照既有先例,以固定的函式名稱字串(`manhattan_distance`、
  `_manhattan_distance`,或其他確認過的實際名稱)在 `res://src` 底下逐檔搜尋
  `static func` 宣告,統計符合特徵的函式數量。
  ⚠️ **本 story 撰寫時未重新查證這兩個函式名稱在今天的程式碼裡是否仍是這個拼法**——
  依 `affinity_rules.gd` 的既有文件註解(本批次撰寫其他 story 時讀過的內容),
  `AffinityRules.manhattan_distance()` 存在;`CombatRules` 那一份的確切名稱
  (`_manhattan_distance` 或其他)**建議實作時自行 grep 確認一次**,不要照抄本文件
  假設的名稱。
- 不要修改 `src/` 下任何 production 程式碼——本 story 純粹新增一支測試。
- 測試檔案位置建議:`tests/unit/gameplay/affinity/affinity_manhattan_implementation_count_test.gd`
  或加進既有的 `affinity_rules_test.gd`,依實作者判斷何者更符合本專案既有的檔案組織慣例。

## Out of Scope

- AC-R2 本身(兩份實作輸出是否一致)——已有測試,不在本 story 範圍。
- `CombatRules` 內部的任何重構——本 story 只讀取,不修改任何 production 程式碼。
- story-008(AC-PERF 效能基準)——雖然同屬 M5,但驗收條件完全獨立,分開成兩張故事。

## QA Test Cases

*同 story-001,`lean` 模式跳過 qa-lead 正式規格產生:*

- **結構計數測試**:
  - Given: `res://src` 底下今天的原始碼
  - When: 掃描曼哈頓距離的獨立實作數量
  - Then: 恰好等於 2
  - Edge cases: 掃描不應誤把「呼叫」曼哈頓距離函式的其他程式碼(而非「宣告」曼哈頓距離
    函式本身)算進計數——只統計函式宣告,不統計呼叫點。

## Test Evidence

**Story Type**: Logic
**Required evidence**: 新測試檔案存在且通過,含乙類例外的兩項揭露義務。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: None
