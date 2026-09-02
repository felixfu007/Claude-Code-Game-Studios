# Story 013:幀精準量測儀器

> **Epic**:單一游標/高亮狀態系統
> **Status**:Ready
> **Layer**:Core
> **Type**:Logic
> **Estimate**:[待 sprint 規劃時填]
> **Manifest Version**:2026-09-02
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-019
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制十五(三個 QA-only 診斷欄位)

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- **必須**:診斷欄位為 **QA/測試專用,下游業務邏輯不得依賴**。

---

## Implementation Notes

*出自 ADR-0005 機制十五:*

1. **三個 QA-only 診斷欄位**,含 `diagnostic_last_authority_change_frame`。
2. 🔴 **機制六的定序讓交接在「同一影格」完成 —— 量測應驗證這個更強的保證**,而不只是 AC-12 的「最多 1 幀」。
3. 🔴 **`diagnostic_reclaim_progress_history` 必須量測機制十三呈現層的實際 `modulate.a`,不是判定值。**
   **理由**:`reclaim_progress()` 判定值**必須**瞬間歸零,而 `reclaim_visual_convergence_max_frames` 約束的是**呈現層透明度** —— **量錯對象會得到一個永遠通過的測試。**
   (ADR 原版本正是量錯了,已於第一次修訂更正。)
4. **量測只採計下降區段** —— 上升方向已改為立即同步(見 Story 011)。

---

## Out of Scope

- Story 005:定序本身(本 story 只量測它)
- Story 011:呈現層平滑器本身

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-12**(2026-08-03,qa-lead 審查後重寫,原版本未定義「影格」與「正確反映」的可觀測基準,不可測): **GIVEN** 裝置權威轉移事件發生的影格(定義:以視覺影格——即引擎每次 `_process` 邏輯更新週期——計數,轉移影格 = 該次 `_process` 迴圈內偵測到新裝置 `ui_*` action 觸發的影格),**WHEN** 量測新裝置對應高亮節點的可觀測渲染屬性(例如 `visible` 或 `modulate.a`)翻轉為呈現新權威狀態的影格,**THEN** 兩者相差 ≤ `max_handoff_visual_latency_frames`(見 Tuning Knobs,目前定案值 1)個影格——以明確的節點屬性變化作為量測依據,不依賴主觀肉眼判斷。

---

## QA Test Cases

🔴 **本批未經 qa-lead 產生測試規格**(管理者 2026-09-02 裁決:精簡模式,覆核關卡不跑;
且本工作環境未經授權不得動用 Agent)。

**替代做法**:上方驗收標準**本身就寫成 GIVEN / WHEN / THEN 形式**,直接作為測試規格使用。
這不是省略 —— 該 GDD 的 AC 是 qa-lead 於 2026-08-03 諮詢草擬、並經十六輪審查修訂的成果,
明文要求「所有標準以可觀測不變式書寫,避免『感覺清楚』等無法驗證的措辭」。

⚠️ **但有一項它不能替代**:AC 沒有列邊界值與失敗態。實作時若發現某條 AC 的邊界不明確,
**停下來問,不要自己選一個** —— 本專案已有「假設錯誤的腳本順利跑完、輸出漂亮數字」的前例。

---

## Test Evidence

**Story Type**:Logic
**必要證據**:`tests/unit/cursor/frame_instrumentation_test.gd`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:005, 011
- **Unlocks**:無
