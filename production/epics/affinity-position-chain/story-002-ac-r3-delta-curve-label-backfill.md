# Story 002: AC-R3 反查與標註 —— 距離—數值曲線四種組合

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: ✅ **Done(2026-10-12,協調者獨立驗收)** —— AC-R3 落地,**零新增測試**。
>
> **反查結論(協調者在派工前執行,原始輸出隨派工單交付):AC-R3 的 5 個斷言全部已有既有測試涵蓋**,
> 故走「加註代號」路線而非補寫。標註 **7 支**,比照同檔既有 `# AC-F1` 的形狀:
>
> | AC-R3 要求 | 標註的既有測試 |
> |---|---|
> | ①正向、距離 1 → `+3` | `test_delta_positive_distance_one_returns_plus_three` |
> | ②正向、距離 ≥3 → `−1` | `test_delta_positive_distance_three_returns_minus_one`、`test_delta_positive_distance_far_beyond_three_stays_minus_one` |
> | ③負向、距離 1 → `−1` | `test_delta_negative_distance_one_returns_minus_one` |
> | ④負向、距離 ≥3 → `+2` | `test_delta_negative_distance_three_returns_plus_two` |
> | ⑤任一極性、距離 2(死區)→ `0` | `test_delta_positive_distance_two_returns_zero`、`test_delta_negative_distance_two_returns_zero` |
>
> **刻意不標的一支**:`test_delta_distance_zero_returns_zero_for_both_polarities` —— 它驗的是**距離 0**
> (同格的邊界防呆),不是 AC-R3 第⑤項的**死區距離 2**。協調者先判定、實作者讀過內容後**獨立同意**。
> 📌 **「不標」這件事寫下來與「標了哪些」同等重要** —— 本專案已登記多次「只寫做了什麼、沒寫不做什麼,
> 下一個人無法分辨是刻意還是遺漏」。
>
> **協調者獨立複驗**:`grep -c "# AC-R3" affinity_rules_test.gd` → **7**;兩處插在既有說明性註解之前
> (未取代原註解);`git status --short src/` 零產品碼改動;全套 `1116 | 0 errors | 1 failures`、`EXIT 100`。
>
> ⚠️ **實作者誠實揭露的一項限制**:它是依協調者給的對照表核對,**沒有自己從 GDD 原文重新推導 AC-R3 的
> 完整定義** —— 若 GDD 原文有表格未列到的額外子句,它不會發現。**該對照表是協調者做的,出事找協調者。**
> **Layer**: Gameplay(控制清單「核心層規則(Core)」涵蓋範圍)
> **Type**: Logic
> **Estimate**: XS(< 0.5 session——EPIC.md 已判斷行為本身有測,只差代號)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`
**需求**: R3(Core Rules,距離—數值曲線)+ AC-R3(Acceptance Criteria)
**TR-ID**: ⚠️ 同 story-001——本系統尚未登記進 `tr-registry.yaml`,以 GDD 自身代號 `AC-R3` 追蹤。

**Governing ADR**: `ADR: N/A` —— 理由同 story-001(本系統刻意無治理 ADR)。

**Engine**: Godot 4.7.1 | **Risk**: LOW(純函式運算,無 post-cutoff 風險)

**Engine Notes**: 無。

**Control Manifest Rules(此層)**: 本 story 只動 `tests/`,不動 `src/`,控制清單的
production 端規則不適用。

---

## 🔴 這張故事的核心動作是「標註」,幾乎確定不需要「新寫」

EPIC.md 第 4 節已明文指出:AC-R3 對應的**行為本身已經有測試**——`affinity_rules_test.gd`
裡有 7 條 `test_delta_*` 測試涵蓋四種(極性×距離)組合,只是沒有任何一條的名字或註解標上
`AC-R3` 這個代號。`grep -rnoE "AC-R3([^0-9a-z]|$)" tests/ --include=*.gd` 目前 0 命中,
但 EPIC.md 第 4 節已明確區分:「行為本身有測(`test_delta_*` 共 7 條),只是沒有任何一條
標為 AC-R3」。

**這與 AC-R1 / AC-R5 不同**:EPIC.md 對 AC-R3 已經做過反查、確認命中,不是「不確定要不要
反查」的狀態。本 story 因此**預期範圍極小**:找到那 7 條 `test_delta_*` 測試,逐條核對
是否確實涵蓋 R3 的四種組合,加上 `AC-R3` 的代號註解。

⚠️ **仍要做的一步查核**:7 條測試是否真的涵蓋 R3 表格的全部四格(正向距1 → +3、正向距≥3 → −1、
負向距1 → −1、負向距≥3 → +2)以及死區(距2 → 0)。EPIC.md 只說「有 7 條」,沒有逐條列出
分別對應哪一格——**這是本 story 開工時要核對的事,不是可以假設已經完美對齊的事**。
若核對後發現某一格沒有測試涵蓋(例如 7 條裡有重複,實際只覆蓋 3 格),則那一格需要補寫,
按 Acceptance Criteria 處理。

## Acceptance Criteria

*來源:`design/gdd/affinity-position-chain.md` Acceptance Criteria 節,AC-R3 原文:*

- [x] **AC-R3**:GIVEN 四種(極性×距離)組合各自單獨存在,WHEN 查詢單線 `Φ`,
  THEN 依序回傳 +3/−1(正向距1/距≥3)與 −1/+2(負向距1/距≥3),距離 2 恆為 0。
  - 具體要求:找到(或確認)以下 5 個斷言各自有測試涵蓋,並在對應測試函式加上 `AC-R3`
    代號註解:
    1. 正向、距離 1 → `+3`
    2. 正向、距離 ≥3 → `−1`
    3. 負向、距離 1 → `−1`
    4. 負向、距離 ≥3 → `+2`
    5. 任一極性、距離 2(死區)→ `0`

## Implementation Notes

- 本 story 沒有治理 ADR,不涉及 production 程式碼變動。
- 若核對後確實 5 格全數命中,**只需加註解,不必新增任何 `test_` 函式**——
  在既有測試函式的文件字串或行內註解加上「(AC-R3)」字樣即可,比照 EPIC.md 記載的建議做法。
- 若發現遺漏,按 `.claude/rules/test-standards.md` 命名慣例
  `test_[system]_[scenario]_[expected_result]` 補寫缺的那一格,只補缺的,不重寫已存在的。

## Out of Scope

- AC-R1(資料驅動證明)——見 story-001,獨立驗收條件。
- AC-R5(多夥伴同時解除負擔)——見 story-003,獨立驗收條件。
- R3 曲線的數值本身(+3/−1/−1/+2)是否合理——那是遊戲設計裁決(GDD Tuning Knobs 已定案),
  本 story 只驗證「程式碼是否忠實反映已定案的曲線」,不評估曲線設計是否正確。

## QA Test Cases

*同 story-001,`lean` 模式跳過 qa-lead 正式規格產生,以下為作者依 GDD AC 原文直接轉寫:*

- **AC-R3**:
  - Given: 單線,極性與距離四種組合各自單獨測試(共 4 case + 1 死區 case)
  - When: 呼叫 `AffinityRules.delta(polarity, distance, amp=1)`
  - Then: 依序回傳 `+3` / `−1` / `−1` / `+2`,距離 2 時恆 `0`
  - Edge cases: 距離 ≥3 的「≥」語意需確認測試涵蓋距離 3 與距離 4+(至少一個大於 3 的值),
    不只測距離恰為 3。

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/affinity/affinity_rules_test.gd` 內 5 個斷言
(既有 `test_delta_*` 加註或新補)標註 `AC-R3`,今天會跑且通過。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: None
