# Story 001:共用列舉、目標值型別與策略契約

> **Epic**:單一游標/高亮狀態系統
> **Status**:Ready
> **Layer**:Core
> **Type**:Logic
> **Estimate**:[待 sprint 規劃時填]
> **Manifest Version**:2026-09-02
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-002
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制二(`CursorTypes` 包裝類別)、機制三的 `CursorTarget` 值型別、機制八的 `MouseReclaimPolicy` 抽象基底

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- **必須**:跨檔共用列舉必須包在類別裡 —— GDScript **沒有**跨檔可見的裸列舉。這是 ADR-0002 撰寫時 `godot-specialist` 查核發現的 BLOCKING 級問題,本專案已有一個查證過的先例(`AffinityTypes`),**沒有理由讓第二個系統重蹈同一個錯誤**。
- **必須**:抽象方法宣告是**裸簽章**(`@abstract func f() -> T`,無冒號無主體)。
- **禁止**:`abstract_func_with_body` —— 帶 `pass` 主體是**編譯期錯誤**,已實機驗證。
- **禁止**:`enum_value_positional_string_conversion` —— 持久化一律 `find_key(value)` / `enum[name]`,不得 `keys()[value]`。

---

## Implementation Notes

*出自 ADR-0005 機制二、機制三、機制八:*

1. **`CursorTypes`(`cursor_types.gd`)** —— 表面類型標籤的單一集中定義,包裝於 `class_name CursorTypes`。
2. **`CursorTarget` 值型別** —— 目標識別為**值型別**,需實作 `equals()` 供機制十的競態判定使用(`mark_pending_reresolve()` 靠它判斷「呼叫方以為的目標」與「系統當下的目標」是否相符)。**不含碰撞箱幾何**。
3. **`MouseReclaimPolicy` 抽象基底** —— 一個 `signal reset_triggered` + 四個 `@abstract func`,回傳型別涵蓋 `bool` / `float` / `void` / `Vector2` **四種**。
   ✅ **已實機驗證**(2026-08-20,`prototypes/engine-verification-spike-2026-08-20/`):`@abstract` 類別內**可以**同時含 `signal` 與多個 `@abstract func`;漏實作抽象方法是編譯期錯誤且訊息會指名缺哪一個。
   🔴 **但該次只測了部分回傳型別。ADR 明文要求四種各建一檔分別編譯。** 本 story 應涵蓋這一步。

🔴 **ADR 的 Key Interfaces 示意程式碼刻意只有簽章、主體從略,直接貼上是 Parse Error。**
**不要「順手加個 `pass` 讓它能編譯」** —— 那會撞上上面那條禁令。
**本專案已為「照 ADR 示意碼直接寫」付過 18 處編譯錯誤的代價。**

---

## Out of Scope

- Story 002:狀態物件本體與 Autoload 宿主
- Story 003:註冊表的行為(本 story 只出型別)
- Story 014:`MouseReclaimPolicy` 的**具體實作**(本 story 只出抽象契約)

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-53(表面類型共用列舉型別契約驗證,回應 qa-lead 審查發現——AC-47 只驗證同標籤實例基數 ≤1,未驗證每個標籤本身確實來自同一份共用列舉,見 Core Rules #7「表面類型標籤的型別契約」)**: **GIVEN** 目前系統中所有已掛載 UI 表面所使用的表面類型標籤集合,**WHEN** 檢視每個標籤的宣告來源,**THEN** 全部標籤皆為 Core Rules #7 所定義之單一共用列舉的成員,不存在任何下游系統自行發明的獨立字串或型別。**(驗證方式:程式碼審查/靜態分析——確認共用列舉的成員定義與各下游系統實際使用的標籤來源一致。)**

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
**必要證據**:`tests/unit/cursor/shared_types_test.gd`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:無
- **Unlocks**:002, 003, 004, 006, 014
