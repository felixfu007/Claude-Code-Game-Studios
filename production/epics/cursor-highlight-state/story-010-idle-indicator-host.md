# Story 010:全域待機指示宿主 + 專屬 CanvasLayer

> **Epic**:單一游標/高亮狀態系統
> **Status**:Ready
> **Layer**:Core
> **Type**:UI
> **Estimate**:S(約 3–4 小時)
> **Manifest Version**:2026-09-02
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-016
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制十二(Autoload 持有的全域 `CanvasLayer`)

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- 🔴 **必須**:**游標圖層獨佔一顆 `CanvasLayer`**,不得與介面圖層共用。
- **必須**:全域裝置指示須**色盲友善**。

---

## Implementation Notes

*出自 ADR-0005 機制十二:*

1. **`CursorStateHost` 持有的全域 `CanvasLayer` 為宿主。** 這個缺口的成因是**需求本身排除了畫面範圍的擁有者** —— 機制一建立的 Autoload 是本專案第一個跨所有畫面的實體。
2. 🔴 **必須拆成獨立節點,不可與自繪游標共用同一顆**:`modulate.a` 是**逐節點**屬性。機制十三會在 `_process()` 末尾寫 `modulate.a = _presented_alpha` —— 若三者是同一節點,那一行會把**待機指示一起淡出**。
3. ⚠️ **待機指示器的資料來源尚未定義(ADR 誠實登記的缺口)**:`TR-cursor-016` 要求「每裝置待機指示」,代表它至少要知道「當前哪個裝置閒置中」,而 `CursorState` 的頂層欄位裡**沒有任何 idle 概念**。
   **實作時碰到這一點請停下來問,不要自己加第四個欄位** —— 那會直接違反 AC-1。
4. **視覺樣式仍留 `/art-bible`,不在本 story 決定。**

---

## 🔴 本 story 綁定一條隨 ADR 核准生效的硬性義務

**「游標圖層 transform 恆等」必須寫成一條會執行的自動化測試**(ADR-0005 Validation Criteria #20),
**不得只靠紀律。**

**理由是實測數字**:誤把游標圖層與介面圖層混成同一顆節點時,偏差為
1080p **1440 px** / 2K **2178 px** / 4K **3304 px** —— **不是歪一點,是游標系統實質失效。**

✅ 已實測:專屬節點下四種解析度(1080p / 2K / 4K / 超寬)**全部恆等**;
該 Autoload 掛 `/root`、不在 `SubViewport` 內,四種解析度 `get_viewport() == get_tree().root` 皆為真。
證據:`prototypes/ui-canvas-scale-spike-2026-09-01/`

**這條測試沒過,本 story 不得結案。**

---

## Out of Scope

- Story 011:自繪游標本體與原生指標隱藏

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-27**(2026-08-05 第九輪修訂主體,回應 ui-programmer 審查發現、使用者裁決——待機指示改為每裝置一個全域指示,不再要求下游表面各自顯示): **GIVEN** 任一裝置目前未持有游標權威,**WHEN** 檢視全域裝置狀態指示元件的呈現,**THEN** 該元件顯示與「功能故障/無回應」視覺上可區分的待機狀態指示(見 Visual/Audio Requirements 的硬性行為要求)——具體視覺呈現(顏色/動畫/圖示/載體位置)留待 `/art-bible`,但指示本身的存在與可辨識性須驗證。**範圍澄清**:本 AC 驗證的是全域裝置狀態指示元件本身,不要求四個下游 UI 表面(好感度視覺呈現 UI、戰鬥 HUD、支援對話 UI、戰棋移動與交戰系統)各自額外顯示待機視覺——各表面只需遵守 Core Rules #5 的高亮抑制規則。**(驗證方式:Visual/Feel 類證據,screenshot + lead sign-off,依 coding-standards.md 的 ADVISORY 證據等級,由擁有此全域指示元件的下游系統的 GDD 落實,擁有者待定見 Open Questions。)**
- **AC-55(全域裝置指示色盲友善驗證,回應 ux-designer 審查發現,見 Visual/Audio Requirements「全域裝置指示的色盲友善 AC 缺口」)**: **GIVEN** 全域裝置狀態指示元件使用色彩區分裝置(滑鼠 vs. 鍵盤/手把),**WHEN** 檢視該元件的視覺呈現,**THEN** 裝置區分不僅依賴色彩本身,搭配線型、圖示、動畫或其他非色彩線索,比照 AC-36 系列的既有無障礙檢查標準。**(驗證方式:Visual/Feel 類證據,screenshot + lead sign-off,依 coding-standards.md 的 ADVISORY 證據等級,由擁有此全域指示元件的下游系統落實後執行。)**


---

## QA Test Cases

🔴 **本批未經 qa-lead 產生測試規格**(管理者 2026-09-02 裁決:精簡模式,覆核關卡不跑;
且本工作環境未經授權不得動用 Agent)。

> 🔴 **2026-09-03 更正:括號裡「不得動用 Agent」那半句已不成立。**
> 管理者於 2026-09-03 開工時明文授權派工,同日稍後再次確認「由你負責派工與監督」。
> 原文保留供追溯,**但不要照它跳過覆核** —— Story 004 正是在這句話仍寫在檔案裡的當天,
> 實際跑完了引擎覆核與測試涵蓋覆核兩關。前半句(qa-lead 精簡模式)是否仍適用,
> 依當次派工指示為準,不由本檔決定。

**替代做法**:上方驗收標準**本身就寫成 GIVEN / WHEN / THEN 形式**,直接作為測試規格使用。
這不是省略 —— 該 GDD 的 AC 是 qa-lead 於 2026-08-03 諮詢草擬、並經十六輪審查修訂的成果,
明文要求「所有標準以可觀測不變式書寫,避免『感覺清楚』等無法驗證的措辭」。

⚠️ **但有一項它不能替代**:AC 沒有列邊界值與失敗態。實作時若發現某條 AC 的邊界不明確,
**停下來問,不要自己選一個** —— 本專案已有「假設錯誤的腳本順利跑完、輸出漂亮數字」的前例。

---

## 效能影響

**有固定成本,已計入預算**:ADR 明載機制十二/十三的全域 `CanvasLayer` 合計新增**至多 3 個繪製元素**,對專案 `< 1000` 的 draw call 預算無實質影響。

📌 本 story 負責其中的待機指示元件。它常駐,但每幀不做運算。

*權威來源:ADR-0005 `Performance Implications` 節、`.claude/docs/technical-preferences.md`。*

---

## Test Evidence

**Story Type**:UI
**必要證據**:`production/qa/evidence/idle-indicator-host-evidence.md`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:002
- **Unlocks**:011
