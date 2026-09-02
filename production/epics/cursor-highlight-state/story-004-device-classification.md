# Story 004:裝置分類 + 動作語意分類(含 echo 過濾)

> **Epic**:單一游標/高亮狀態系統
> **Status**:Ready
> **Layer**:Core
> **Type**:Logic
> **Estimate**:[待 sprint 規劃時填]
> **Manifest Version**:2026-09-02
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-004
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制四(裝置分類,依 `InputEvent` 子類別)、機制四之二(`ActionClass` 語意分類)

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- 🔴 **絕不讀取 `event.device`** —— 這是對 **4.7 鍵盤/滑鼠裝置 ID 重新編號**的**結構性免疫**,不只是紀律。
- **禁止**:`reading_input_event_device_id`
- **禁止**:`unhandled_input_for_device_authority`
- **禁止**:`confirm_action_read_in_unhandled_input`

---

## Implementation Notes

*出自 ADR-0005 機制四、機制四之二:*

1. **`classify()` 只做 `InputEvent` 子類別 match**,結構性不觸及 `.device`。
2. 🔴 **`classify_action()` 必須自行加 `event is InputEventKey and event.echo` 過濾。**
   **這是隨 ADR 核准生效的兩條硬性義務之一。** 已實測 `InputMap.event_is_action()` **不過濾** echo:
   `event_is_action(pressed=true, echo=true, ui_up)` 與 `echo=false` 回傳**相同**(皆 `true`)。
   **不濾的後果**:玩家**按住**方向鍵會每一影格都被判為 `NAVIGATION`、亦即**每一影格都在主張裝置權威**。
   證據:`prototypes/adr0005-engine-probes-2026-09-01/logs/probe13_and_3_headless.txt`
3. **`event_is_action()` 對 `InputEventMouseMotion` 必然回傳 `false`** —— 與本設計一致。
4. **白名單完整性驗證,不靜默降級** —— 導覽類 action 清單若有未涵蓋項,必須大聲失敗,不得默默當成非導覽。
5. ⚠️ **`-1` sentinel 警告**:`InputEvent.device` 在某些合成事件下可能回傳 `-1`。本系統結構性不受影響,但**下游若為除錯/記錄用途讀取裝置 ID,必須處理此值**。

---

## Out of Scope

- Story 005:分類結果如何進入緩衝與裁決
- Story 014:echo 過濾要不要套用於滑鼠奪權的同幀否決 —— **那在凍結區內,不在本 story 處理**

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-6**: **GIVEN** 一個原始輸入事件尚未對應到任何 `ui_*` action(例如滑鼠 `InputEventMouseMotion` 未觸發任何映射動作),**WHEN** 該事件被引擎處理,**THEN** 裝置權威與游標目標皆不變——原始輸入事件本身不足以觸發權威轉移。
- **AC-7**: **GIVEN** 同一實體裝置在事件流中的裝置 ID 發生變化(模擬 Godot 4.7 裝置 ID 重新編號情境),**WHEN** 該裝置持續產生同一類別的 `ui_*` action,**THEN** 裝置權威不因裝置 ID 改變而發生非預期的轉移或狀態重置——判定依據僅為 `ui_*` action 的來源裝置類別,不含裝置 ID。
- **AC-8**: **GIVEN** 一個非使用者直接操作的來源注入了合成滑鼠事件(例如 Steam Input 或觸控板模擬),**WHEN** 該注入未實際觸發對應的 `ui_*` action,**THEN** 裝置權威不轉移給該來源。
- **AC-9**: **GIVEN** 裝置 A 剛產生 `ui_*` action 取得權威,**WHEN** 在裝置 B 產生下一個 `ui_*` action 之前經過任意長時間、或裝置 A 停止產生任何輸入,**THEN** 裝置權威持續維持為 A——不存在逾時或閒置自動釋放權威的行為。**(驗證方式:優先以程式碼審查確認實作中不存在逾時/倒數計時器邏輯;若採執行期測試,建議以模擬至少 10,000 個影格、裝置 B 全程無輸入為操作化下限,確認裝置權威持續為 A 作為通過條件——「任意長時間」本身不可窮舉驗證,以此為可執行的下限替代。)**

- **AC-34**(2026-08-04 第七輪修訂縮小範圍,回應 game-designer 審查發現、creative-director 裁決——原版本斷言「任一」由 `InputEventKey`/`InputEventJoypadButton` 觸發的 `ui_*` action 皆零門檻奪權,但本輪已將反方向豁免範圍縮小至導覽類動作,原措辭若不修正會與新規則矛盾): **GIVEN** 滑鼠持有權威,**WHEN** 鍵盤或手把產生一個由 `InputEventKey` 或 `InputEventJoypadButton` 觸發的**導覽類** `ui_*` action(例如 `ui_up`/`ui_down`/`ui_left`/`ui_right` 等方向性動作),**THEN** 裝置權威於該影格內立即轉移至鍵盤/手把,不套用 Core Rules #3 的空間門檻或任何累積條件——驗證導覽類離散按鍵方向的零門檻豁免確實無條件生效。**確認類或其他非導覽類動作的對應行為見 AC-35(已改寫)。**
- **AC-34b**(2026-08-04 第五輪新增,回應 ux-designer 審查發現的類比搖桿飄移風險,見 Core Rules #3 反方向前提約束;2026-08-04 第七輪加註範圍說明): **GIVEN** 滑鼠持有權威,**WHEN** 手把類比搖桿產生一個由 `InputEventJoypadMotion` 觸發的 `ui_*` action(即該軸值已跨越 Input Map 設定的死區),**THEN** 裝置權威於該影格內立即轉移至鍵盤/手把,與 AC-34 受相同的零門檻待遇——本 AC 明確驗證類比搖桿位移事件確實被納入反方向零門檻豁免範圍內,不因其為連續訊號而被本系統另行施加門檻;死區本身是否足以濾除硬體飄移不在本 AC 驗證範圍內(見 Open Questions)。**類比搖桿位移訊號依其語意必然屬於導覽類動作,不受第七輪 AC-34 導覽類範圍限縮的影響。**
- **AC-35**(2026-08-04 第七輪改寫;**2026-08-05 第九輪修正一句不實的修訂註記,回應 qa-lead 審查發現的驗證回歸——第七輪改寫時宣稱「原驗證目的由下方新版取代」,但此陳述不成立:第六輪的原版 AC-35 驗證的是「滑鼠→鍵盤/手把方向轉移時累積起點確實歸零」〔即 Core Rules #3 觸發點 (a) 的其中一個方向〕,第七輪改寫後的新版只驗證「確認類動作不轉移裝置權威」,兩者是完全不同的斷言,前者的驗證覆蓋在第七輪改寫時被直接刪除、並非「由新版取代」。此驗證缺口已於本輪由新增的 AC-42 補回,見下方 Group G**): **GIVEN** 滑鼠持有權威,**WHEN** 鍵盤或手把產生一個確認類或其他非導覽類 `ui_*` action(例如確認鍵、取消鍵),**THEN** 該影格結束時,裝置權威欄位仍為滑鼠,未被改寫為鍵盤/手把——驗證 Core Rules #3「確認類動作與裝置權威的關係」規則確實生效,確認類動作不具備導覽類動作享有的零門檻奪權豁免。

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
**必要證據**:`tests/unit/cursor/device_classification_test.gd`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:001
- **Unlocks**:005
