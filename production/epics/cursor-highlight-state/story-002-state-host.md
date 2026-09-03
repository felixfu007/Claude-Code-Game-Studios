# Story 002:Autoload 薄殼 + 依賴注入核心 + 三欄位狀態

> **Epic**:單一游標/高亮狀態系統
> **Status**:Complete
> **Layer**:Core
> **Type**:Logic
> **Estimate**:M(約 5–6 小時)
> **Manifest Version**:2026-09-02
> **Last Updated**:2026-09-02

## Context

**GDD**:`design/gdd/cursor-highlight-state.md`(2026-08-13 第十六輪 Approved)
**Requirement**:TR-cursor-001
*(需求原文在 `docs/architecture/tr-registry.yaml`,審查時請當場讀最新版)*

**Governing ADR**:ADR-0005 單一游標/高亮狀態系統:裝置權威輸入架構(**Accepted** 2026-09-01)
**本 story 對應的機制**:機制一(`CursorStateHost` Autoload 薄殼 + `CursorState` RefCounted 核心)

**Engine**:Godot 4.7.1 | **Risk**:HIGH
**引擎注意事項**:本系統的兩個核心領域(Input、UI)在 4.6 與 4.7 **各有一項直接相關的破壞性變更**。
🔴 **引擎判斷一律以 `docs/engine-reference/godot/breaking-changes.md` 與 `current-best-practices.md` 為準**
—— `modules/input.md` 與 `modules/ui.md` 停在 4.6,對這兩項變更**各自零命中**。

**控制清單規則(本 story 適用)**:
- **必須**:Autoload **只做薄殼**,邏輯放在依賴注入的核心。
- **必須**:滑鼠座標一律走**單一注入管道**(`_mouse_position_provider`),不得三條路徑並存。
- **必須**:每次取值前 `is_valid()` 守衛。
- **禁止**:`logic_in_cursor_autoload_shell`
- **禁止**:`autoload_singleton_for_testable_data_layers` —— 專案編碼標準明文要求公開方法可單元測試。
- **禁止**:`silent_freeze_fallback_for_invalid_provider` —— provider 失效不得靜默凍結。
- **禁止**:`external_access_to_cursor_reclaim_instance` —— `_reclaim` 私有、**無 getter、不得外流**。

---

## Implementation Notes

*出自 ADR-0005 機制一、機制十:*

1. **`CursorStateHost`** 是 Autoload,只負責生命週期與 `_process` 掛載;`process_priority = −100`。
2. **`CursorState`** 是 `RefCounted`,由宿主以依賴注入建構。**持有恰 3 個頂層欄位**:目前游標目標、目前裝置權威、滑鼠奪權進度(`_reclaim`)。
   ⚠️ **AC-1 驗證的是「不存在第四個未被文件承認的隱藏欄位」,不是「只能有兩個欄位」。** 有效性旗標是目標欄位的內部結構,不算第四欄。
3. **`mouse_position_provider` 以 `Callable` 建構子注入** —— 讓 `RefCounted` 核心在無場景樹的情況下仍能取得滑鼠座標,同時讓單元測試可直接假造。**採具名方法綁定,不用 lambda 字面量**。
   🔴 **`is_valid()` 守衛是必需,不是防禦性冗餘**:已實測**對已釋放物件呼叫 `.call()` 會讓所在函式整段中止**(中止範圍只到直接呼叫的函式,不往上傳播)。
   ⚠️ **該實測只在 debug 建置成立。release 建置未查證**(本機無匯出範本)—— 見 EPIC 的「層 B」登記。

---

## Out of Scope

- Story 005:緩衝與裁決的時序(本 story 只建狀態容器與宿主)
- Story 007:寫入/讀取介面的七個公開入口
- Story 010:宿主持有的 `CanvasLayer`

---

## Acceptance Criteria

*以下為 `design/gdd/cursor-highlight-state.md` 的條文**原文轉錄**,未改寫:*

- **AC-1**(2026-08-04 第五輪修訂,回應 systems-designer、ui-programmer 審查發現的欄位數矛盾——原版本斷言「僅兩個欄位」與 Core Rules #3 奪權機制實際需要的累積位移量欄位矛盾,本次承認第三欄位為公開、非隱藏狀態): **GIVEN** 系統的全域狀態物件,**WHEN** 檢視其結構,**THEN** 恰包含三個頂層欄位——目前游標目標(含表面類型標籤與有效性旗標,見 Core Rules #1)、目前裝置權威、滑鼠奪權累積位移量(見 Core Rules #3)——沒有第四個會影響任何 UI 表面高亮顯示決策的隱藏欄位或分散狀態。三者皆為本文件明文承認、非隱藏的狀態,本 AC 驗證的是「不存在第四個未被文件承認的隱藏欄位」,不是「只能有兩個欄位」。**(驗證方式:程式碼審查/靜態分析,非執行期黑盒測試——本 AC 斷言的是「不存在」,無法透過執行期觀察窮舉證明。)**
- **AC-2**: **GIVEN** 任一具游標目標的 UI 表面組合已掛載(棋盤格、關係圖迷你地圖等),**WHEN** 檢視連續任一影格(**含未初始化狀態**,見 States and Transitions 與 AC-15),**THEN** 跨全部表面加總,恰有一個 **hover/游標高亮**存在,不為 0 也不為 2(或以上)。**範圍澄清**:此處「高亮視覺」specifically 指本系統仲裁的 hover/游標高亮,不含下游系統自行維護的釘選/多選標記視覺(見 Core Rules #7 範圍界定)——釘選標記可與 hover 高亮同時存在多個,不違反本不變式。
- **AC-15**(2026-08-03,qa-lead 審查後補強,原版本未鎖定高亮是否實際顯示,與 AC-2 的恆一不變式產生落實缺口): **GIVEN** 一個純手把 session,自畫面載入以來尚未有任何裝置產生過 `ui_*` action,**WHEN** 查詢游標狀態,**THEN** 目前游標目標等於呼叫方(戰棋移動與交戰系統)指定的可操作單位所在格,裝置權威欄位標示為未初始化(不指向任何已生效裝置),且此讀取過程未讀取任何裝置的原生 hover 位置作為判斷依據。**且對應的高亮視覺已顯示於該目標**——不存在「目標值已設定但高亮尚未顯示」的過渡窗口;呼叫方須保證在需要游標的畫面首次可互動前,初始目標已透過本系統的寫入介面設定完畢,此為規範行為(見 States and Transitions 表的未初始化狀態列)。
- **AC-16**: **GIVEN** 系統處於未初始化狀態(AC-15),**WHEN** 任一裝置(滑鼠或鍵盤/手把)產生第一個 `ui_*` action,**THEN** 系統立即離開未初始化狀態,依該裝置類別進入對應的權威狀態,後續行為依 Group B/C 的一般規則運作。


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

**無效能影響預期** —— 狀態物件為三欄位讀寫,O(1);Autoload 薄殼本身每幀不做事(邏輯在依賴注入的核心)。

*權威來源:ADR-0005 `Performance Implications` 節。*

---

## Test Evidence

**Story Type**:Logic
**必要證據**:`tests/unit/cursor/state_host_test.gd`

**Status**:[ ] 尚未建立

---

## Dependencies

- **Depends on**:001, **003**
- **Unlocks**:005, 007, 008, 010, 014

> 🔴 **本欄於 2026-09-03 相依稽核更正。** 這條相依只存在於 ADR-0005 的簽章裡,本工作單內文
> 從未出現該型別名稱 —— `/story-readiness` 檢查的是「工作單本身完不完整」與「ADR 核准了沒」,
> **結構上不會檢查「ADR 契約是否需要別張工作單的產出」**,故抓不到。全文見
> `docs/reviews/story-dependency-audit-2026-09-03.md`。
>
> **依據**:Key Interfaces L.1376-1377 `func _init(reclaim: MouseReclaimPolicy,
> registry: CursorSurfaceRegistry, mouse_position_provider: Callable) -> void` —— 建構子直接注入。
>
> ⚠️ **這一張的漏列已於 2026-09-02 實際造成專家開工卡死、105 分鐘零產出。** 本次為補正。

---

## Completion Notes(2026-09-02 結案)

**Status:Complete。** 走完 `/story-readiness` → `/dev-story` → `/code-review`(三方)→ 修正 → `/story-done`。

### 交付物

| 檔案 | 內容 |
|---|---|
| `src/ui/cursor/cursor_state.gd` | `CursorState`,`RefCounted` 依賴注入核心。**本階段只有建構子** —— 七個公開入口屬 Story 007、緩衝裁決屬 Story 005 |
| `src/ui/cursor/cursor_state_host.gd` | `CursorStateHost`,Autoload 薄殼,`process_priority = -100` |
| `project.godot` | 新增 `[autoload]` 節。**專案第一個 Autoload** |
| `tests/unit/cursor/state_host_test.gd` | 14 條,全過 |

**實測(主 session 獨立複跑)**:`tests/unit/cursor` 48 條 exit 0;全套 `tests/unit` 289 條、
0 orphans,唯一失敗是既有那條刻意紅且已核准的 `affinity_phi_provider` 測試。
**註冊 Autoload 沒有弄壞任何既有測試。**

### 四條驗收標準的誠實涵蓋狀態

- **AC-1(恰三個頂層欄位)—— 充分。** 用 `get_script_property_list()` 反射,排除兩個具名協作者
  欄位後斷言剩餘**恰為**三個;另有一條反向測試確認被排除的名字**確實存在**,防止排除清單指到
  不存在的名字而假陽性通過。
- **AC-2 / AC-15 / AC-16 —— 不足,已登記。** 此階段系統裡沒有任何已掛載表面、沒有高亮視覺、
  沒有裁決邏輯,三條只能對測試替身斷言。**沒有造假湊數**(測試涵蓋覆核逐條查證確認)。
  補驗時機見 `docs/tech-debt-register.md`。

### 🔴 本 story 產生的一項事故與其教訓

程式碼註解一度寫著「這是管理者 2026-09-02 的裁決」—— **那項裁決從未發生**。成因是派工單寫的
「**我的理解**(你可以推翻)」被升格成了「管理者裁決」。三處(程式碼、本檔、測試檔)現已改為
明寫「**本問題上不存在管理者裁決 —— 不要引用一個**」,主動擋住下一個人再犯。
📌 **凡寫下「已裁決」,必須同時指出它記錄在哪個檔案的哪一行。指不出來就不是裁決。**
(該判斷本身經兩位覆核者獨立查證成立,要改的是措辭不是行為。)

### 🔴 相依圖缺陷(影響後續排程,務必傳下去)

**本 story 宣告 `Depends on: 001`,實際還需要 003 的 `CursorSurfaceRegistry`** ——
ADR 契約段的 `CursorState._init(reclaim, registry, mouse_position_provider)` 需要它。
該相依**只存在於 ADR 簽章,本檔內文從未出現過該類別名**,因此
**`/story-readiness` 結構上抓不到** —— 它不檢查「ADR 契約是否需要別張 story 的產出」。
**代價:一位專家 105 分鐘、零產出。** 交接文件原寫「002/003/004 可平行開」是錯的。

### 覆核結論

三方:測試涵蓋 INCOMPLETE → 修正後關閉;GDScript 品質 CHANGES REQUIRED → 修正後關閉;
引擎/ADR 契約 **APPROVED**(0 BLOCKING)。五項修正全數完成,見提交 `eda2225`。
