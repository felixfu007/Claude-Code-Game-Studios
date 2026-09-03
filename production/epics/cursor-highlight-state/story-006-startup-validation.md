# Story 006:載入期設定驗證(Input Map + Agile Flushing)

> **Epic**:單一游標/高亮狀態系統
> **Status**:Ready
> **Layer**:Core
> **Type**:Logic
> **Estimate**:S(約 2–3 小時)
> **Manifest Version**:2026-09-02
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-005, TR-cursor-007
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制七(`CursorStartupValidator`)

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- 🔴 **必須**:Agile Event Flushing 驗證在**鍵不存在時回報 UNKNOWN,不得視為通過**。
- **必須**:錯誤不得靜默。

---

## Implementation Notes

*出自 ADR-0005 機制七:*

1. **(a) Input Map 約束**:`CursorStartupValidator` 遍歷 `InputMap.get_actions()` / `action_get_events()`,檢查「除非語意為懸停/游標移動,`ui_*` action 不得綁定滑鼠」。**執行期重新綁定明文排除在範圍外。**
   ✅ 該二 API 已由第十輪覆核為 4.5→4.6→4.7 穩定、未變更、未棄用。
2. **(b) Agile Event Flushing 必須關閉** —— 整個「一幀一批次」假設依賴於此。
   ✅ **鍵名已實測確認**為 `input_devices/buffering/agile_event_flushing`,現值 `false`。
   🔴 **但 `has_setting()` 防衛不要移除。** 若鍵名寫錯,`get_setting()` 對不存在的鍵回傳 `null`,驗證會**靜默通過** —— 那**比不驗證更危險**,因為它製造假的安全感。防衛現在是冗餘,不是不必要。
   ⚠️ **這個鍵其實是第二次被確認**:2026-08-20 就測出同一結論,而 ADR 的該欄整整 12 天仍寫著「未經查證」。**這是本專案已登記的「做完了沒人寫回去」失效模式。**
3. **(c) 導覽類 action 白名單完整性** —— 見 Story 004。

---

## Out of Scope

- Story 004:action 的執行期語意分類(本 story 只做載入期的設定檢查)

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-26**(2026-08-04 修訂驗證方式,回應 godot-specialist 審查發現的假陽性風險——原版本要求靜態掃描 `project.godot`,但 Godot 僅在 action 綁定被從引擎編譯內建預設值修改過時才會將其序列化進該檔案的 `[input]` 區塊;仍使用引擎預設綁定的 `ui_*` action〔即使預設綁定本身就含滑鼠觸發〕不會出現在靜態檔案掃描中,會讓本 AC 產生假陽性通過,反而讓 Core Rules #3 前提約束的唯一驗證手段失效): **GIVEN** 專案的 Input Map 設定,**WHEN** 於 headless 專案載入後,依序呼叫 `InputMap.get_actions()` 取得所有已註冊的 action、再對每個 action 呼叫 `InputMap.action_get_events(action)` 檢視其綁定的 `InputEvent` 型別(此查詢會同時反映引擎編譯內建預設值與專案自訂覆寫,不遺漏任何一方),**THEN** 除語意上屬於懸停/游標移動用途的 action 外,沒有任何 `ui_*` action 綁定 `InputEventMouseButton` 或 `InputEventMouseMotion` 作為觸發輸入——這是 Core Rules #3 前提約束本身的驗證,不是 AC-8 描述的下游後果(AC-8 只驗證「若前提被違反,是否至少在未觸發 ui_* 時不轉移權威」這個較弱的子情況)。**(驗證方式:執行期 API 查詢〔非傳統黑盒遊玩測試,也非單純靜態檔案掃描〕——透過 headless 專案載入後呼叫 InputMap 查詢 API,確保涵蓋未被覆寫、仍在使用引擎預設綁定的 action。)**
- **AC-46**(回應 qa-lead 審查發現的覆蓋缺口——Tuning Knobs 對 `mouse_reclaim_threshold_px_by_surface_type` 表中每個表面類型常數「必須嚴格大於 0」的硬性約束此前從未有對應 AC 驗證其初始化階段是否真的被檢查,與 AC-39/AC-40 曾補上的同類缺口同構): **GIVEN** `mouse_reclaim_threshold_px_by_surface_type` 表中任一表面類型的常數被配置為 0 或負值,**WHEN** 系統初始化,**THEN** 系統於初始化階段偵測到此非法配置並採取明確處理(拒絕載入/assert/回退安全預設值,具體手段留待 `/create-architecture`),不放任非法值流入 Formulas 公式導致除以零或靜默死鎖。
- **AC-46b(2026-08-05 第十輪新增,回應 systems-designer、qa-lead、ui-programmer 三方獨立收斂發現——AC-46 只驗證「常數已存在但為非法值」,未驗證「查表未命中」這個 Formulas 自稱同位階的硬性約束)**: **GIVEN** Core Rules #7 共用列舉中存在一個表面類型成員,但 `mouse_reclaim_threshold_px_by_surface_type` 表未包含該成員的對應常數(查表未命中,而非命中一個非法值),**WHEN** 系統初始化或首次對該表面類型查詢 `reclaim_threshold_px`,**THEN** 系統偵測到此缺漏並採取明確處理(拒絕載入/assert/回退安全預設值,具體手段留待 `/create-architecture`),不放任查表未命中的結果(例如 null/未定義行為)流入 Formulas 公式。**同一原子變更約束(2026-08-05 第十輪新增)**:本 AC 與 AC-53(表面類型共用列舉型別契約驗證)共同驗證同一條原子約束的兩半——列舉新增成員與門檻表新增對應常數須視為單一原子變更,兩個 AC 合併執行可一次確認該原子性未被違反。**(驗證方式:程式碼審查/整合測試——確認初始化流程包含「列舉成員 ⊆ 門檻表鍵值集合」的完整性檢查。)**

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

## 效能影響

**不在逐幀路徑** —— ADR 明載 `CursorStartupValidator.validate()` 遍歷全部 `ui_*` action 一次,發生於啟動。

📌 它計入的是**載入時間**,不是幀預算。

*權威來源:ADR-0005 `Performance Implications` 節。*

---

## Test Evidence

**Story Type**:Logic
**必要證據**:`tests/unit/cursor/startup_validation_test.gd`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:001, **004**
- **Unlocks**:無

> 🔴 **本欄於 2026-09-03 相依稽核更正。** 這條相依只存在於 ADR-0005 的簽章裡,本工作單內文
> 從未出現該型別名稱 —— `/story-readiness` 檢查的是「工作單本身完不完整」與「ADR 核准了沒」,
> **結構上不會檢查「ADR 契約是否需要別張工作單的產出」**,故抓不到。全文見
> `docs/reviews/story-dependency-audit-2026-09-03.md`。
>
> **依據**:ADR-0005 L.617 —— 機制七 (c) 分類完整性驗證須比對機制四之二的三份清單;
> Key Interfaces L.1346 `const NAVIGATION_ACTIONS / CONFIRM_ACTIONS / ACKNOWLEDGED_OTHER_ACTIONS`。
> 三份清單雖與 001 的 `CursorTypes` 同檔案,但產出者是 Story 004。
