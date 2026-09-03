# Story 012:已註冊表面禁用原生 focus/hover(兩項條件)

> **Epic**:單一游標/高亮狀態系統
> **Status**:🔴 **Blocked**(2026-09-03 開工前查核 —— 驗收標準的定義域目前是空集合,見文末)
> **Layer**:Core
> **Type**:UI
> **Estimate**:S(約 2–3 小時)
> **Manifest Version**:2026-09-02
> **Last Updated**:[由 /dev-story 於實作開始時設定]

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-018
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制十四(已註冊表面禁用原生 Control focus/hover)

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- 🔴 **必須**:已註冊表面的根 Control **同時**滿足兩項條件(見下)。
- **禁止**:`native_control_hover_or_focus_on_registered_surface`

---

## Implementation Notes

*出自 ADR-0005 機制十四:*

**兩項條件,缺一不可**:

1. **`focus_mode = FOCUS_NONE`** —— 關掉鍵盤/手把的焦點通道。
2. **不得帶有內建滑鼠 hover 主題狀態** —— 根 Control 不得是 `Button` 或任何在主題中內建 hover StyleBox 的節點型別;若因其他理由**必須**使用此類型別,**必須顯式清空其 hover/focus StyleBox**。

🔴 **第 2 項是硬性要求,不是防禦性建議 —— 這是實測結論,不是推測。**
已實測(2026-09-01,非 headless):`Button` 設 `FOCUS_NONE` 後滑鼠懸停,`is_hovered()` 由 false 轉 **true**、`get_draw_mode()` 由 0(NORMAL)轉 **2(HOVER)**。
**焦點與懸停確為兩條獨立管線** —— 只設 `focus_mode` **只封住兩條管線中的一條**。
證據:`prototypes/adr0005-engine-probes-2026-09-01/logs/probe9_windowed.txt`

**未註冊表面仍可用原生 focus**(GDD AC-60 明文承認),且其上的方向鍵導覽**仍會轉移裝置權威** —— 這是**正確行為**,裝置權威是全域的。

**高亮只讀 `CursorState`**,不得各表面自行維護。

---

## ⚠️ 本 story 無專屬 AC —— 這是刻意的,不是漏掉

機制十四的效果由 **AC-2**(任一影格跨全部表面恰有一個 hover/游標高亮,不為 0 也不為 2)
這條不變式**間接**驗證:若原生 hover 也在畫,就會出現兩個高亮。

**因此本 story 的驗收方式是**:
1. **程式碼審查/靜態分析** —— 逐一確認每個已註冊表面的根 Control 兩項條件皆成立;
2. **執行期** —— 在每個已註冊表面上重跑 AC-2,含滑鼠懸停情境。

⚠️ **AC-2 的主要歸屬在 Story 002。本 story 是它的另一條必要條件。**
**兩張都過,AC-2 才真的成立。**

---

## Out of Scope

- Story 003:註冊表本體
- Story 011:白名單例外表面的原生指標恢復

---

## Acceptance Criteria

*本 story 在 GDD 中無專屬 AC —— **這是刻意的**,理由見上方該節。*
*以下 2 條是把上方已定的驗收方式寫成可驗收的形式,編號 `AC-S012-*`,不佔用 GDD 的 AC 號碼。*
*⚠️ **內容未新增任何新要求** —— 只是換一種寫法,讓「做完了沒有」變成可以逐條打勾的。*

- **AC-S012-a(兩項條件的靜態符合性)** —— *源自 ADR-0005 機制十四的型別分流表*:
  **GIVEN** 全部已註冊游標表面的根節點,**WHEN** 逐一檢視其型別,**THEN** 凡屬 `Control` 及其子類別者,**皆同時**滿足:①`focus_mode == Control.FOCUS_NONE`;②不帶內建滑鼠 hover 主題狀態(非 `Button` 等型別,或已顯式清空 hover / focus StyleBox,使 hover 狀態與 normal 狀態在視覺上不可區分)。**AND** 凡屬非 `Control` 型別者(`Node2D` / `Area2D` 等),記錄為**結構性不適用**,不得視為違規。

- **AC-S012-b(執行期單一高亮不變式,含滑鼠懸停情境)** —— *AC-2 在本 story 的必要條件面;AC-2 的主要歸屬在 Story 002*:
  **GIVEN** 任一已註冊表面已掛載,**WHEN** 將滑鼠移至該表面上並停留,**THEN** 跨全部表面在任一影格恰有 **1 個** hover / 游標高亮 —— 不為 0,**也不為 2**。
  🔴 **失敗長相是「兩個高亮同時存在」** —— 那正是 GDD Player Fantasy 明訂的最高風險失敗情境,也是機制十四存在的唯一理由。
  ⚠️ **本條與 Story 002 兩張都過,AC-2 才真的成立。**

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

**無效能影響預期,方向反而是正向的** —— 本 story 只設定節點屬性(`focus_mode`、清空 hover / focus StyleBox),設定一次,不在逐幀路徑。

📌 它的實際效果是**移除**原生 hover 的繪製工作,不是新增。

*權威來源:ADR-0005 `Performance Implications` 節。*

---

## Test Evidence

**Story Type**:UI
**必要證據**:`production/qa/evidence/disable-native-focus-evidence.md`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:003
- **Unlocks**:無
---

## 🔴 2026-09-03 開工前查核:**本張現在開工必然假性通過,狀態改為 Blocked**

**查核人**:協調者(主 session),於管理者裁決「開下一張工作單」後的前置查證。

### 事實(實測,非推論)

```
grep -rn '\.register(' --include='*.gd' src/ tests/
```
**正式程式碼(`src/`)零命中。** 全部命中都在 `tests/unit/cursor/surface_registry_test.gd`。
亦即 **`CursorSurfaceRegistry` 目前是空的,沒有任何真實 UI 表面註冊進去。**
現存的 `src/ui/battle/BattleScreen.tscn` / `BoardView.tscn` 都不是已註冊游標表面。

### 後果

本張的兩條驗收標準**都以「全部已註冊表面」為定義域**:

- **AC-S012-a**:「**GIVEN** 全部已註冊游標表面的根節點,**WHEN** 逐一檢視其型別…」
- **AC-S012-b**:「**GIVEN** 任一已註冊表面已掛載,**WHEN** 將滑鼠移至該表面上…」

🔴 **定義域為空集合時,全稱斷言恆真。** 現在寫測試會全綠,而機制十四要防的
「畫面上同時出現兩個高亮」**一次都沒有被驗到**。

⚠️ **這與本專案已登記兩次的失效形狀完全相同**:
- Story 003 的 **AC-51**(「每個下游表面」目前是空集合)—— 已登記於 `docs/tech-debt-register.md`
- Story 007 的 **AC-32**(測試斷言的「仍為無效」有第二個成因,由測試自己的輸入保證)

**三次都是同一件事:一條在它要防的東西出現之前就會變綠的測試。**

### 這張要能真的做,需要一個裁決(協調者不代為決定)

ADR-0005 機制十四**定義了約束,但沒有說在哪裡強制執行**。
而且它明文記載 `register(surface, node: Node)` **刻意收通用 `Node` 而不強制 `Control`**
(專家發現 F 的定案:按型別分流,非 `Control` 為結構性不適用)。

因此「兩項條件」目前是一條**寫在文件裡、沒有任何程式會檢查**的紀律。可能的落點:

| 方案 | 內容 | 現在就能寫出會失敗的測試嗎 |
|---|---|---|
| **甲** | 在 `CursorSurfaceRegistry.register()` 內建檢查:註冊的若是 `Control` 而違反兩項條件之一,**拒絕註冊或報錯** | ✅ 可以 —— 用合成的 `Control` / `Button` / `Node2D` 三種輸入直接驗,不需要真實表面存在 |
| **乙** | 放到 Story 006 的載入期驗證 | ⚠️ 同樣受制於「目前沒有表面可驗」 |
| **丙** | 不動,等四個下游 UI 表面真的存在時再做 | ❌ 不能,而且這張單會一直掛著 |

🔴 **甲案是一項契約變更,不是實作細節** —— 它改變 `register()` 的行為(可能新增一個
`RegisterResult` 列舉值),屬 ADR-0005 管轄。**需要架構層裁決,不由本工作單決定。**

📌 **協調者建議甲案**,理由是本專案今天剛驗證過的同一個原則:
**把「靠紀律遵守」換成「結構上不可能違反」,比任何事後檢查都有效。**
但這是建議,不是裁決。

