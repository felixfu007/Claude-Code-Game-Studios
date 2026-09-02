# Story 003:表面註冊表(兩份獨立登記表)

> **Epic**:單一游標/高亮狀態系統
> **Status**:Ready
> **Layer**:Core
> **Type**:Logic
> **Estimate**:[待 sprint 規劃時填]
> **Manifest Version**:2026-09-02
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-003
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制三(`CursorSurfaceRegistry`,已註冊表面表 + AC-60 例外白名單表)

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- **必須**:遍歷已註冊表面一律透過 `registered_surfaces_sorted()`(依 enum 底層 int 值排序)。
- **必須**:`is_instance_valid(node)` 檢查必須在任何後續操作(**含 `connect()`**)之前執行。
- **禁止**:`relying_on_container_iteration_order` —— 不得直接迭代內部 `Dictionary`。
- **禁止**:`mutable_container_as_dictionary_key`

---

## Implementation Notes

*出自 ADR-0005 機制三:*

1. **`register()` 對已被占用的標籤回傳 `DUPLICATE_TAG_REJECTED`,不覆寫。**
2. 🔴 **兩張表必須結構獨立** —— ①已註冊表面表;②AC-60 例外白名單表(供機制十三之二的白名單判定)。
   **理由是兩者的生命週期擁有者不同。** ADR 內部曾出現「以獨立為由堅持,卻讓兩張表共用」的自我矛盾並已修正 —— **不要把它們合併回去。**
3. **白名單反轉的意義是改變失敗方向**:黑名單下任何比對失效都導向「錯誤顯示原生指標」,直接違反 Core Rules #5 這條硬性規則;白名單下任何失效都導向「錯誤隱藏」,後果僅是該表面的 AC-60 便利性失效。**這個方向不得反轉回去。**
4. **本 ADR 不強制已註冊表面必須是 `Control`** —— 強制統一型別會把一個純視覺層約束升級為對戰棋棋盤實作方式的架構限制。
5. **明文不約束 `mouse_filter`** —— 白名單反轉後與本系統任何判定無關。

---

## Out of Scope

- Story 011:白名單表的**消費端**(hover 時恢復原生指標)
- Story 012:已註冊表面的 focus/hover 停用

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-4**: **GIVEN** 棋盤格與關係圖迷你地圖(或任兩個具游標目標的獨立 UI 表面)同時掛載,**WHEN** 對其中一表面產生有效輸入,**THEN** 另一表面上原本顯示的高亮立即消失——證明兩表面共享同一狀態源,而非各自獨立維護高亮邏輯。
- **AC-5**: **GIVEN** 一個新增、先前不存在的第三方 UI 表面(例如卡牌選取)透過本系統的共用讀寫介面接入其**單一 hover/游標目標**,**WHEN** 對該表面產生有效輸入,**THEN** 該表面的 hover 高亮正確參與 AC-2 的單一高亮不變式,且不需要修改本系統本體程式碼——驗證 Core Rules #7(應用範圍一般化)未被綁死在棋盤格。**範圍排除**:若該表面另外維護多選/釘選集合(例如關係圖迷你地圖的多選釘選,見 Core Rules #7 範圍界定),該集合本身不屬於本系統管轄範圍,不受本 AC 保證涵蓋,新增或修改該集合的邏輯不算違反「不需修改本體程式碼」。

- **AC-47(單一實例契約,2026-08-05 第九輪新增,回應 ui-programmer 審查發現、綜合裁決收窄範圍,見 Core Rules #7「表面類型標籤禁止同標籤多實例掛載」)**: **GIVEN** 共用列舉中的任一表面類型標籤,**WHEN** 檢視場景樹中該標籤對應的已掛載表面實例數量,**THEN** 任一時刻至多為 1 個——若某類 UI 表面天生有多個同時存在的變體,驗證共用列舉中已為每個變體登記獨立成員,而非共用同一成員。**(驗證方式:程式碼審查/靜態分析,確認共用列舉的成員定義與場景樹掛載規則一致。)**
- **AC-51(表面卸載前的目標交接義務,回應 ui-programmer 審查發現,見 Core Rules #7「表面卸載前的目標交接義務」)**: **GIVEN** 一個 UI 表面實例是目前游標目標所屬的表面類型,**WHEN** 該表面即將卸載/關閉,**THEN** 卸載前已呼叫本系統的「標記目前目標為待重新解析」或「設定新目標」介面完成交接——卸載完成後查詢游標狀態,不存在「目前游標目標的表面類型標籤沒有任何已掛載實例」的情況,AC-2 的恆一高亮不變式在此路徑下不因表面生命週期而失守。**(驗證方式:程式碼審查/整合測試——確認每個下游表面的卸載邏輯皆包含此呼叫。)**

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
**必要證據**:`tests/unit/cursor/surface_registry_test.gd`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:001
- **Unlocks**:007, 011, 012
