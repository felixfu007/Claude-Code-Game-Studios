# Story 001: AC-R1 反查與補齊 —— 極性/強度來自外部資料而非硬編碼

> **Epic**: 好感度—位置連鎖系統(#5)
> **Status**: Ready
> **Layer**: Gameplay(對照控制清單分層屬「核心層規則(Core)」——適用範圍含「好感度數值池、
> 核心玩法迴圈」,本系統雖非數值池本體,但同屬核心玩法迴圈的一部分)
> **Type**: Logic
> **Estimate**: S(0.5～1 session,含反查)
> **Manifest Version**: 2026-09-09(`docs/architecture/control-manifest.md` 檔頭)
> **Last Updated**: —(由 `/dev-story` 開工時填)

## Context

**GDD**: `design/gdd/affinity-position-chain.md`
**需求**: R1(Core Rules)+ AC-R1(Acceptance Criteria)
**TR-ID**: ⚠️ **本系統尚未登記進 `docs/architecture/tr-registry.yaml`**(EPIC.md 第 5 節判定的
真實缺口,擁有者待管理者裁決 3 指派下一批處理,不擋本 story)。本 story 以 GDD 自身的
`AC-R1` 代號追蹤,不使用 `TR-affinity-*` 前綴——那個前綴目前全部 24 項屬於系統 #1
(好感度數值池,`ADR-0002`),**不是本系統的**,誤用會造成追溯混淆。

**Governing ADR**: `ADR: N/A` —— 本系統刻意無治理 ADR(見 EPIC.md 第 5.3 節③,
`.claude/docs/coding-standards.md` 2026-09-01 裁決:ADR 只為跨系統契約而寫,
本 story 純粹是同一系統內部的測試覆蓋補完,不涉及跨系統契約)。

**Engine**: Godot 4.7.1 | **Risk**: LOW(EPIC.md 標註本系統無節點、無 Autoload、無跨幀狀態,
全為 headless 可測的純函式運算,不觸及 Godot 4.7 post-cutoff 風險項)

**Engine Notes**: 無——純 GDScript 靜態函式與資料物件,不涉及任何 4.7 post-cutoff 變更範圍
(輸入裝置 ID 重編號、Control offset transform、shader 前處理器限縮皆不適用)。

**Control Manifest Rules(此層,與本 story 相關者)**:
- Required:「所有呼叫端必須檢查 `get_at()` 回傳值是否為 `null`」——不直接適用本 story(本
  story 不碰資料池),但呼應本系統一貫的「不得假設輸入合法」紀律,反查測試時一併留意。
- 本 story 只動 `tests/`,不動 `src/`——因此控制清單裡「絕不可以」類的規則(多數是對
  production 程式碼的禁令)在本 story 範圍內不適用,列出僅供對照。

---

## 🔴 第一個動作是反查,不是補寫(EPIC.md 明文,務必先做)

`grep -rnoE "AC-R1([^0-9a-z]|$)" tests/ --include=*.gd` 目前 0 命中(EPIC.md 第 4 節已測,
本 story 開工時請自行重跑一次確認現況未變)。**0 命中不等於「沒有測試驗過這個行為」**——
可能已經有一條測試在驗證「極性/強度可從外部改變、輸出隨之改變」,只是沒有標上 `AC-R1` 這個
代號。EPIC.md 第 4 節誠實登記:「AC-R1 我沒有做同等強度的反查」(即沒有逐行讀完
`affinity_link_test.gd` / `affinity_rules_test.gd` 判斷是否有行為等價的測試)。

**開工第一步**:讀 `tests/unit/gameplay/affinity/affinity_link_test.gd` 與
`tests/unit/gameplay/affinity/affinity_rules_test.gd` 的既有測試函式,尋找是否已有「注入
兩組不同的極性/強度假資料(不改程式碼),斷言 `Φ` 或 `delta()` 輸出隨之改變」這個形狀的
測試。

- **若找到行為等價的測試** → 只需在該測試函式加一行註解標上 `AC-R1`(比照 EPIC.md 記載
  AC-R3 的處置方式),不必新寫測試。這是**優先選項**。
- **若確實沒有** → 補寫一條新測試,見下方 Acceptance Criteria。

## Acceptance Criteria

*來源:`design/gdd/affinity-position-chain.md` Acceptance Criteria 節,AC-R1 原文:*

- [ ] **AC-R1**:GIVEN 注入兩組強度不同的假資料(程式碼不變),WHEN 查詢 `Φ`,
  THEN 輸出隨資料改變——證明極性/強度來自外部而非硬編碼。
  - 具體做法建議(非強制):對 `AffinityRules.delta()` 或 `bonus_for_at()` 傳入兩份不同的
    `Array[AffinityLink]`(例如同一對單位、第一份 `polarity=POSITIVE`,第二份
    `polarity=NEGATIVE`,或同樣改變 `amp`),斷言兩次輸出不同。
  - 🔴 這一條驗的是「資料驅動」這個性質本身,不是驗證 R3 的曲線數值(那是 AC-R3 的職責,
    見 story-002)。測試重點是「換資料,結果跟著換」,不是「特定距離下數值對不對」。

## Implementation Notes

*本 story 沒有治理 ADR,以下指引取自 EPIC.md 與 GDD 本身:*

- 這是**測試專用 story**,`src/gameplay/affinity/` 下的正式程式碼**不應該有任何變更**——
  如果反查或補寫過程中發現需要改動 production 程式碼才測得到 AC-R1,代表現有 API
  結構上擋住了這個驗證,那已經超出本 story 範圍,請停下並回報,不要自行擴大範圍。
- 若走「補寫新測試」路線,測試檔案已存在
  (`tests/unit/gameplay/affinity/affinity_link_test.gd` 或 `affinity_rules_test.gd`),
  新增 `test_` 函式即可,依 `.claude/rules/test-standards.md` 命名慣例
  `test_[system]_[scenario]_[expected_result]`。

## Out of Scope

- AC-R3(距離—數值曲線四種組合的代號標註)——見 story-002,雖然方法論相同(先反查),
  但這是獨立的驗收條件,獨立成 story 以保持每張故事聚焦單一 AC。
- AC-R5(多夥伴同時解除負擔)——見 story-003,EPIC.md 已判定這條是真缺口而非反查問題。

## QA Test Cases

*⚠️ 本批次 `production/review-mode.txt` 不存在,依 `/create-stories` 步驟 1 預設為
`lean` 模式;步驟 4b 明文「lean → skip(not a PHASE-GATE)」,故本次未派 `qa-lead`
產生正式測試規格。以下為本 story 作者(lead-programmer)依 GDD AC 原文直接轉寫,
供實作者參考,非 qa-lead 覆核過的正式規格。*

- **AC-R1**:
  - Given: 同一對單位、同一站位,兩份輸入資料集(極性或強度不同)
  - When: 對兩份資料集分別呼叫 `AffinityRules.bonus_for_at()`(或等價的 `delta()`)
  - Then: 兩次輸出不相等
  - Edge cases: 若改變的是 `amp` 而非 `polarity`,注意現行 `delta()` 對非 `1` 的 `amp` 一樣
    會相乘(見 `affinity_rules.gd:81-93`),故任何非零 `amp` 差異都應反映在輸出上。

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/gameplay/affinity/affinity_link_test.gd` 或
`affinity_rules_test.gd` 內一條標註 `AC-R1` 的測試(新增或既有測試加註)——必須存在且通過。

**Status**: [ ] Not yet created

## Dependencies

- Depends on: None
- Unlocks: None(M1 三張故事彼此獨立,可任意順序或平行進行)
