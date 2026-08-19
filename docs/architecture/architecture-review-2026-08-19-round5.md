# 架構審查報告 — 第五輪

| 欄位 | 值 |
|---|---|
| **日期** | 2026-08-19(與第三、四輪同日,ADR-0005 **第二次修訂**後) |
| **模式** | `/architecture-review`(full) |
| **引擎** | Godot 4.7.1 |
| **GDD** | 5 份 |
| **ADR** | 5 份(ADR-0001~0005,**全部 `Proposed`,無一 `Accepted`**) |
| **判定** | **CONCERNS**(第三、四輪亦為 CONCERNS) |
| **前一輪** | `architecture-review-2026-08-19-round4.md`(第四輪) |
| **引擎專家覆核** | **已執行**(`godot-specialist`,使用者明文核准) |

**本輪目的**:第四輪判定 ADR-0005 的第一次修訂「9 項中 6 項完整關閉,F1 只關一半、F3 修法引入新違反」,並新增 R4-1~R4-7 共 7 項發現與 `TR-cursor-015` 兩項落差。`/architecture-decision` 同日第二次修訂該 ADR 處理全部 9 項,並一併關閉自第二輪起懸置的跨 ADR 銜接缺口 C1/C3/C6,且**明文不自陳修訂後的涵蓋分佈**。本輪即為該項驗證,於**全新 session**、**未參與該次修訂**的脈絡下執行。

---

## 一、需求基線與重推範圍

`docs/architecture/tr-registry.yaml` 有 133 個 `id:`,其中 3 個(`TR-combat-001`~`-003`)在檔頭註解區、為 ID 格式範例 —— **實為 130 項 active**,與第二~四輪一致。

`git diff --stat 829554c HEAD`(第四輪提交至今)實測:

| 檔案 | 改動 |
|---|---|
| `design/gdd/` **全部 5 份 + `systems-index.md`** | **0**(`git log 829554c..HEAD -- design/gdd/` 無輸出) |
| `adr-0001` / `adr-0003` | **0** |
| `adr-0002`(C1/C3)/ `adr-0004`(C1/C6)/ `adr-0005`(第二次修訂) | 各 1(`cc22e1d`) |
| `docs/registry/architecture.yaml` / `.claude/docs/technical-preferences.md` | 各 1(`cc22e1d`) |
| `tr-registry.yaml` | **0** |

需求文字位元組相同,故**重推範圍**為:19 項 `TR-cursor-*`(ADR-0005 第二次修訂)+ 3 列 `TR-concept-005/-006/-007`(第四輪確立的傳播規則:以「該 ADR 的機制觸及哪些需求」為準,非「服務哪一份 GDD」)+ C1/C3/C6 觸及的 affinity/save 列。其餘依構造沿用。

**新增 TR-ID:無。** 無改寫、無棄用。`tr-registry.yaml` 本輪不需任何改動。

**工作區狀態**:`git status --porcelain` 無輸出,與 `origin/main` 同步(`rev-list --count --left-right` 為 `0 0`)。

---

## 二、涵蓋率總覽

| 狀態 | 首輪 | 第二輪 | 第三輪 | 第四輪 | **第五輪** | 本輪變化 |
|---|---|---|---|---|---|---|
| ✅ 已涵蓋 | 5(4%) | 50(38%) | 61(47%) | 65(50%) | **68(52%)** | +3 |
| ⚠️ 部分涵蓋 | 16(12%) | 24(18%) | 34(26%) | 33(25%) | **30(23%)** | −3 |
| ❌ 缺口 | 109(84%) | 56(43%) | 35(27%) | 32(25%) | **32(25%)** | 0 |
| **合計** | **130** | **130** | **130** | **130** | **130** | |

| GDD | 系統 | 層級 | GDD 狀態 | 需求 | ✅ | ⚠️ | ❌ |
|---|---|---|---|---|---|---|---|
| affinity-data-pool.md | 好感度數值池 | Foundation | Approved | 24 | 22 | 2 | 0 |
| save-system.md | 存檔系統 | Foundation | Approved | 30 | 22 | 7 | 1 |
| cursor-highlight-state.md | 單一游標/高亮狀態 | Foundation | Approved | 19 | **15** | **4** | **0** |
| tactical-combat-system.md | 戰棋移動與交戰 | Core | **未 Approved** | 43 | 5 | 13 | 25 |
| game-concept.md | (跨系統) | — | — | 14 | **4** | **4** | 6 |

**C1/C3/C6 不移動任何涵蓋判定**:affinity 的 2 項 ⚠️ 是 `TR-affinity-008`(呼叫順序決定性歸戰棋系統,`TR-tactical-023` 仍無 ADR)與 `-020`(記憶化契約的擁有者無 GDD 亦無 ADR),兩者成因皆在別的系統,與 `TOKEN_TIMEOUT_MS` 擁有權或 `Mutex` 措辭無關。save 的 7 項 ⚠️ 與 1 項 ❌ 同理。C1/C3/C6 是**擁有權與措辭修正**,不是機制新增 —— 修訂本身也如此自陳,本輪覈實成立。

---

## 三、游標系統 19 項 —— 第二次修訂後獨立重推

**第四輪 13 完整 / 6 部分。本輪重推為 15 完整 / 4 部分 / 0 缺口。**

### 由 ⚠️ 升為 ✅(游標 2 項 + 傳播列 1 項)

> `TR-concept-006` 不計入 19 項游標基數,列於此處是因為關閉它的機制(R4-5)與 `-008` 同屬機制四之二/機制七。

| TR-ID | 判定依據 |
|---|---|
| `-001` | **R4-2 完整關閉。** `diagnostic_seed_position()` 已改標 `@abstract`、實作下放 `ThresholdMouseReclaimPolicy`,基底只留簽章;`ImmediateMouseReclaimPolicy` 亦被要求實作(原樣回存 `reset()` 收到的座標),診斷契約對所有策略一致。**Key Interfaces 與機制八兩處現已一致**(第四輪點名的「一處無主體、一處有主體」矛盾已消失)。三頂層欄位的計數論證不變 |
| `-008` | **R4-1 完整關閉。** `arbitrate_frame()` 拆為 `arbitrate_device_authority()`(−100,步驟一,不碰目標欄位、不清緩衝)與 `apply_buffered_navigation()`(−25,步驟三,兼任緩衝最後消費者),後者掛在 `CursorStateHost` 於 `_ready()` 內 `add_child()` 的專屬子節點 `CursorNavigationApplier`。定序自 1&3→2→4 改為 ①−100 → ②−50 → ③−25 → ⑥100,即 GDD 明文的 1→2→3→4。R4-4(公開/私有寫入路徑)、R4-5(三分割 + 機制七 (c))、R4-6(刪 `call_deferred()`)、R4-7(多角色拆節點)四項同機制發現一併關閉。Validation Criteria 新增 9b(②→③ 這組,第四輪明文指出「沒有任何測試涵蓋」)與 9c(節點優先序靜態斷言)。殘留 R5-2 為區間端點措辭問題,不足以推翻機制成立 |
| `TR-concept-006` | **R4-5 完整關閉。** 機制四之二改為 `NAVIGATION_ACTIONS` / `CONFIRM_ACTIONS` / `ACKNOWLEDGED_OTHER_ACTIONS` 明文三分割,機制七新增 (c) 分類完整性驗證 —— 遍歷全部 `ui_*` action,三份皆未命中即回報 `UI_ACTION_UNCLASSIFIED` **並附帶 action 名稱**,不靜默降級為 `OTHER`。ADR 並明文交代為何採三分割而非「未命中即回報」(後者會把數十個引擎內建 action 全報成待分類,噪音大到會被關掉,反而比靜默更糟)—— 這個取捨的推導本身是本次修訂的品質證據 |

### 由 ✅ 降為 ⚠️(1 項)

| TR-ID | 判定依據 |
|---|---|
| `-017` | **R4-3 確已關閉**(上升立即同步、只對下降限速、`_pending_snap` 分支排最前),但**機制十三之二存在一個未被討論的失效路徑(R5-6,引擎專家發現)**:`gui_get_hovered_control()` 對設 `MOUSE_FILTER_IGNORE` 的節點不回傳該節點,若任一已註冊表面的根節點或其祖先鏈上任一節點因其他理由設為 `IGNORE`,`is_part_of_registered_surface()` 會比對不到 → 誤判「滑鼠在未登記表面上」→ **在應隱藏原生指標時將其恢復可見**,直接違反 Core Rules #5。機制十四對已註冊表面只約束 `focus_mode` 與 hover 主題兩項,**未約束 `mouse_filter`**,因此這個配置是本 ADR 目前允許的。**判定說明**:此降級是本輪的判斷取捨 —— 缺陷為條件式(依賴一個 ADR 既未強制也未禁止的配置),第六輪若認為條件式缺陷不足以降級,可據此推翻本判定 |

### 仍為 ⚠️(3 項)

| TR-ID | 本輪判定理由 |
|---|---|
| `-009` | **判定與 ADR 一致。** F2 已關閉且第四輪的 #11a 更正成立(淨位移全程停留在 viewport 座標系,不受 `CanvasLayer` 變換影響);但門檻數學本身仍在使用者第十二輪裁決的凍結中,不因介面修好而變成完整涵蓋 |
| `-011` | **判定與 ADR 完全一致,處理方式正確。** 機制八明文不宣稱已緩解、不宣稱降低嚴重度、不宣稱構成圍堵。E1/E2 兩項缺陷維持未修復,待手把硬體 |
| `-015` | **落差 (b) 完整關閉**(丙分支已改為 GDD AC-63b 原文的條件式沿用,有效性判定歸呼叫方),**但落差 (a) 只關了甲分支** —— **乙分支的 `SURFACE_HANDOFF` 在目前定案的介面形狀下沒有任何合法呼叫路徑**(R5-1,引擎專家判為 BLOCKING)。詳見第五節 |

### 維持 ✅(13 項)

`-002`、`-003`、`-004`、`-005`、`-006`、`-007`、`-010`、`-012`、`-013`、`-014`、`-016`、`-018`、`-019` —— 判定依據與第四輪相同,對應機制本輪零改動或僅受連帶修訂(`-006` 承 R4-1 拆呼叫、`-019` 承 R4-3 的「只採計下降區段」)。

---

## 四、第四輪 9 項待修訂的處置判定

| 項 | 第四輪級別 | 本輪處置 |
|---|---|---|
| **R4-2** | BLOCKING | **完整關閉**(`@abstract` + 實作下放,兩處文字已同步) |
| **R4-1** | 高(視同 BLOCKING) | **完整關閉**(拆 −25 子節點,四步序列逐步對齊;新增 9b/9c 測試) |
| **R4-3** | 高(視同 BLOCKING) | **完整關閉**(上升立即同步;機制十五量測改為只採計下降區段) |
| R4-4 | 高 | **完整關閉**(明文公開入口 vs `_write_target_internal()`;新增 forbidden pattern) |
| R4-5 | 中高 | **完整關閉**(三分割 + 機制七 (c) 載入期完整性驗證) |
| R4-6 | 中 | **完整關閉**(刪除 `call_deferred()` 路線,並與機制十 N4 建議的 `call_deferred()` 用法做明文對照表區辨) |
| R4-7 | 中 | **完整關閉,且本 ADR 的反向更正正確 —— 見下** |
| `-015`(b) | — | **完整關閉** |
| **`-015`(a)** | — | **只關甲分支,乙分支未關**(R5-1) |

**8 項完整關閉,1 項只關一半。**

### R4-7:本輪確認 ADR-0005 對第四輪的部分推翻是**對的**

第四輪的 `godot-specialist` 推翻主審初判(「優先序梯無解」),提出「同節點內把改標寫在確認讀取之前即可,不需拆節點」,該輪主審採納。ADR-0005 第二次修訂**部分推翻該修法方向**,改為「相鄰角色可合併、不相鄰必須拆節點」。

**本輪獨立推導確認 ADR 是對的**:單一節點只有一個 `process_priority` 值 P。

- 若 P = −50:該節點的確認讀取(⑥)發生在 −50,**早於** ③(−25)的緩衝內導覽寫入 → 違反 GDD 步驟 3→4。
- 若 P = 100:該節點的改標(②)發生在 100,**晚於** ③(−25) → 違反 GDD 步驟 2→3。

②與⑥之間隔著 ③(−25)與 ④(0),兩者非相鄰,單節點方案不論設哪個值都會違反四步序列的一段。**第四輪採納的修法方向錯誤,本次修訂的更正成立。** 陳述順序方案仍適用於相鄰角色(例如同時是 ④ 與 ⑤ 的系統)。

### 模式觀察

第三輪抓到的是**自陳膨脹**(16/3 → 11/8);第四輪抓到的是**修法本身引入新缺陷**(R4-2/R4-3/R4-4 三項皆為第一次修訂新產生)。**第二次修訂對第四輪的模式做出了有效回應** —— 引擎專家獨立覆核 R4-3/R4-4 的修法本身,**未抓到新問題**,且本次修訂在各機制內留下的「這個修法會不會製造下一個 R4-x」逐項自問(機制五的中間狀態、機制十三的三點自問、機制十的公開入口互呼禁令)確實給了本輪可直接反駁的標的。

**但模式沒有消失,只是移動了位置**:本輪最嚴重的 R5-1 落在**本次修訂新增的機制**(甲/乙/丙三分支的具體重置呼叫點)上,而它的根因正是本次修訂自己診斷出的「新發現 A」—— 補了列舉與訊號、沒補呼叫點地圖 —— 在修 `-015`(a) 的過程中對乙分支原樣複製了一次。

---

## 五、本輪 6 項發現

> R5-1 ~ R5-5 由主審獨立推導,`godot-specialist` 逐項對抗性覆核**全部 CONFIRMED**,其中 **R5-1 由該專家升為 BLOCKING**、R5-3 由中升為中高。R5-6 為該專家於五項之外自行發現(任務二第 7 問)。另有 S-1~S-5 五項專家發現列於第八節。

### R5-1 — `TR-cursor-015` 乙分支的 `SURFACE_HANDOFF` 沒有任何合法呼叫路徑 · **BLOCKING**

機制十一的修法文字:

> 「`handoff_before_unload()`(甲)於完成標記後、**乙分支的 `set_target()`** 於寫入後,各自呼叫 `_reclaim.reset(_mouse_position_provider.call(), CursorTypes.ResetTrigger.SURFACE_HANDOFF)`」

全文 grep `SURFACE_HANDOFF`:**只有一個程式碼層呼叫點**(機制十一第 709 行,語境為甲分支),Key Interfaces 第 986 行也只在 `handoff_before_unload` 那一行註明。**兩個分支的可實作性完全不同**:

- **甲分支合法**:`handoff_before_unload()` 是 `CursorState` 的專屬方法,只為這一個用途存在,在自己的方法體內固定呼叫 `reset(pos, SURFACE_HANDOFF)`,無歧義。
- **乙分支不合法**:乙分支重用的是**通用**的 `set_target(target, from_ui_action)`,而該入口正是機制十的 `_write_target_internal()` 已明訂「若目標確實改變則 `_reclaim.reset(pos, TARGET_CHANGED)`(觸發點 (b))」的同一條路徑。要讓乙分支改發 `SURFACE_HANDOFF` 只有兩條路,兩條都不通:
  - **(a) 呼叫方自己呼叫 `_reclaim.reset(...)`** —— `_reclaim` 是 `CursorState` 的私有欄位,`CursorState` 沒有任何 getter,下游系統結構上拿不到這個參照。該段虛擬碼字面上要求外部呼叫方碰觸另一個物件的私有欄位。
  - **(b) `set_target()` 內部判斷「這次是不是乙分支」** —— 該方法只有兩個參數,而 `from_ui_action` 對乙分支與丙分支失效重算路徑**同樣傳 `false`**(ADR 自己明訂「甲/乙/丙三分支 `from_ui_action` 一律 `false`」),無法用它分辨。

**三種讀法皆不成立**:

1. 若 `set_target()` 無條件發 `SURFACE_HANDOFF` → 一般改標與**丙分支**都會誤發,而 GDD Core Rules #7 只要求甲/乙重置(專家已核對 GDD 第 98 行原文確認丙不在內)。
2. 若發 `TARGET_CHANGED` → **Validation Criteria #16 必然失敗**(該項明文斷言甲/**乙**皆須帶 `SURFACE_HANDOFF`、不是 `TARGET_CHANGED`)。
3. 若乙分支算出的目標**恰等於**當下目標 → `_write_target_internal()` 依「若目標確實改變」直接不重置,**GDD 強制的乙分支歸零靜默不發生**。

**專家的嚴重度判定(本輪採納)**:這不是「修法只關一半」的漸進式缺口,而是**目前定案的介面形狀根本沒有寫的空間**。修復需要新增介面面(`set_target()` 第三參數 `is_surface_handoff: bool`,或新增乙分支專用方法如 `set_initial_target_after_handoff()`),而非 R4-2 那種一行改標記。**應與 R4-2 同級(BLOCKING,純靜態可證)**。

**注意這是本 ADR 自己診斷出的「新發現 A」的原樣複製**:上一版 `ResetTrigger` 四個觸發點中 (a)(b)(d) 三者零呼叫點,本次修訂補上了它們,卻在新增第五個值 `SURFACE_HANDOFF` 時對乙分支重犯同一個錯誤。

### R5-2 — ② 的優先序範圍與 ③ 的固定值相撞 · **中**

機制六表格中 ② 標「−50(架構強制;**−100 與 −25 之間任一值**皆滿足排序,此為參考值)」,③ 標「−25(架構強制;必須嚴格介於 ② 與 ④ 之間)」。若下游取區間端點 `−25`,即與 `CursorNavigationApplier` 同優先序,且此時 ③「嚴格介於 ② 與 ④ 之間」變為不可滿足。

ADR 內部對「同優先序怎麼辦」有兩處立場不同的措辭:機制六 ⑤ 與機制十三之二說「同層級同優先序節點無 tie-break 保證」(視為風險),機制六另一處說「`process_priority` 是數值小者先執行」(暗示嚴格全序)。

**專家判定(印象-中,非已查證)**:對 Godot 同 `process_priority` 節點的印象是「同優先序桶內依登記進處理鏈的順序穩定排序」,但無官方文件或本專案參考庫佐證(ADR 自己 grep 出零命中),**無法從印象升為已查證**。

**修法**:兩列可交叉讀出正確解(③ 的「嚴格介於」反推 ② 必須 < −25),因此是**措辭欠明確而非矛盾**;但字面允許一個會破壞四步定序的配置。建議把 ② 的建議值訂為一個與 −100/−25 都有安全間距的具體值(專家建議 `−60`),並把區間寫成端點排除。

### R5-3 — `MouseReclaimPolicy` 實例的擁有權與取得管道從未定義 · **中高**

`_reclaim` 在機制一宣告為 `CursorState`(`RefCounted`)的欄位、經建構子注入。但全文有**三個**消費方:

| 位置 | 寫法 | 問題 |
|---|---|---|
| 機制一 / 機制十 | `_reclaim: MouseReclaimPolicy`,`CursorState._init(reclaim, ...)` | 擁有者 |
| **機制九**(第 581/591/596 行) | `CursorStateHost` 直接寫 `_reclaim.reset(get_viewport().get_mouse_position(), ...)` | 把 `_reclaim` 當成 Host **自己的欄位**在用,但機制一明訂 Host「本身不持有任何狀態」。要嘛是筆誤,要嘛意味 Host 事實上雙重持有 —— 兩者都與機制一的宣稱矛盾,也逼近 forbidden pattern `logic_in_cursor_autoload_shell`(觸發點的選擇是裁定邏輯) |
| **機制十三**(第 746 行) | 自繪節點 `reclaim.reset_triggered.connect(_on_reset_triggered)` | 把 `reclaim` 當成已存在的可存取欄位,但全文沒有任何段落說明它是經建構子注入、`@export`、還是某個 getter 取得 |

`CursorState` 的 Key Interfaces **沒有任何 `_reclaim` getter**。三個消費方對「這個實例怎麼流通」各自假設了不同的存取路徑,ADR 從未把這條線畫清楚。

**附帶(專家指出)**:滑鼠座標存取有同一類「兩套並行管道」問題 —— 機制九用 `get_viewport().get_mouse_position()` 直呼,機制八/十用注入的 `_mouse_position_provider.call()`。ADR 自己寫「兩處不得分歧」,但字面上就是**三條**不同呼叫路徑;即使目前數值通常相等,這是紀律要求而非結構保證,**正是本 ADR 在別處反覆批評別人的同一種毛病**。

### R5-4 — Validation Criteria 編號錯誤(兩份 ADR) · **低**

- **ADR-0005**:編號序列為 1,2,3,4,5,6,7,8,9(9a–9d),10,11,**13**,14,15,16,17 —— **#12 被跳過**(專家逐字核對確認)。
- **ADR-0004**:條列依序為 1,2,3,4,5,**7**,**6** —— 第 7 項印在第 6 項之前(C1 修訂新增第 7 項時插錯位置)。

兩者皆不影響機制正確性,但 Validation Criteria 是實作者的檢查清單,跳號會讓「是不是漏了一項」無法一眼判斷。

### R5-5 — Architecture Diagram 未同步 R4-5 的新增驗證 · **低**

圖中「載入期一次性:`CursorStartupValidator`」區塊只列兩條(Input Map 約束、Agile Event Flushing),機制七 (c) 在同一次修訂新增的 `UI_ACTION_UNCLASSIFIED` 完整性驗證未出現。**這是本 ADR 反覆出現的「同一批修訂,散文區塊改了、示意圖沒跟著改」模式的又一實例**(第四輪已在 registry `interface:` 欄與 Consequences 自陳上抓到同型別兩次)。

### R5-6 — `gui_get_hovered_control()` 對 `MOUSE_FILTER_IGNORE` 的行為使機制十三之二可能誤判 · **中高**(引擎專家發現)

`MOUSE_FILTER_IGNORE` 的既定語意是「該 Control 不參與滑鼠事件/懸停判定,事件穿透給下方節點」(**專家證據等級:印象-高信心**)。因此:

若任一**已註冊表面**的根節點,或其祖先鏈上任一節點,因其他理由被設為 `MOUSE_FILTER_IGNORE`(背景裝飾層的點擊穿透設計是常見做法),`gui_get_hovered_control()` 回傳的就不會是該表面的一部分 → `is_part_of_registered_surface()` 沿祖先鏈比對**永遠比對不到** → 機制十三之二誤判「滑鼠在未登記表面上」→ **在應隱藏原生指標時把它恢復可見**,直接違反 Core Rules #5,且該失敗與本系統邏輯是否正確完全無關。

**機制十四對已註冊表面只約束兩項**(`focus_mode = FOCUS_NONE`、根 Control 不得帶內建 hover 主題),**未約束 `mouse_filter`** —— 因此這個配置是本 ADR 目前允許的。

**修法方向**:機制十四新增第 3 項條件(已註冊表面的根 Control 及其祖先鏈不得設 `MOUSE_FILTER_IGNORE`),或機制十三之二改用不依賴 GUI hover 管線的判定(例如以已註冊表面節點的 `get_global_rect()` 對滑鼠座標做幾何比對)。前者成本低但把約束推給下游,後者結構性但需重新驗證座標空間。**建議一併列入 Day-1 spike**,與 VR #11b 同批。

---

## 六、跨 ADR 衝突與銜接缺口

**零阻塞級衝突。**

| 缺口 | 第四輪 | **第五輪** | 覈實依據 |
|---|---|---|---|
| **C1**(`TOKEN_TIMEOUT_MS` 無人擁有) | 仍開 | **已關閉** | ADR-0004 機制六新增「C1 銜接缺口」段落,**接下定值責任**,定死推導規則(`≥ SAFETY_FACTOR × (MAX_MIGRATION_CHAIN_DEPTH × FRAME_BUDGET_MS + WORST_CASE_TWO_PHASE_REWRITE_MS)`,`SAFETY_FACTOR ≥ 10`,並論證兩側代價不對稱)而非具體毫秒數;新增 Validation Criteria 的版本連動測試(`SaveFormat` 版本 +1 時以失敗測試強制回頭重算)。ADR-0002 的 Risks 表與「明確未定案」兩處已同步改為指向 ADR-0004。路徑(三)註解原本的「非本系統補償」也已改寫,明文區分「機制的執行」與「參數的定值責任」 |
| **C3**(`Mutex` 過度宣稱) | 仍開 | **已關閉** | ADR-0002 機制七新增 C3 段落:條件已由 ADR-0004 判為「否」(同步阻塞式 `SaveIOBackend` + 主執行緒斷言),**決策不變、理由由「必要」改為縱深防禦**,措辭不再宣稱是「全專案唯一已成立的執行緒安全義務」,並明文寫「它是一個目前無競爭對手的鎖」。`TR-affinity-016` 的 Requirements Addressed 列同步修訂 |
| **C6**(ADR-0004 對游標零命中) | 仍開 | **已關閉** | ADR-0004 `Related Decisions` 新增回指 ADR-0005 機制十一的條目,並明文寫出義務歸屬:游標交接義務歸**呼叫方**(戰棋系統),不歸存檔系統;ADR-0004 不呼叫游標系統任何介面、也不需要知道它存在。並補上「路徑〔四〕依 GDD 第十三輪裁決**不落入丙分支**」這項具體銜接事實 |
| C2 / C4 / C5 | 已於 `a56dd10` 關閉 | 沿用 | 相關檔案零改動,不重驗 |

**這是四輪以來第一次沒有任何懸置的跨 ADR 銜接缺口。**

**另覈實**:ADR-0004 `Related Decisions` 殘留的**第四處**「`TR-save-*` 至此全數覆蓋」過度宣稱已改為「22 完整 / 7 部分 / 1 缺口」,與同檔第 27/421 行(`1c3d5d0` 已改)一致 —— 該過度宣稱**至此四處全數清除**。

### ADR 依賴序(無環)

```text
Foundation(無依賴):ADR-0001 戰棋查詢原子性 / ADR-0002 好感度數值池 / ADR-0005 游標裝置權威
依賴 Foundation:    ADR-0003 存檔序列化(requires ADR-0002)
Feature 層:         ADR-0004 存檔原子寫入與遷移(requires ADR-0003)
```

⚠️ **五份全部 `Proposed`,無一 `Accepted`** —— 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋。ADR-0003 依賴 ADR-0002、ADR-0004 依賴 ADR-0003,兩條依賴都指向仍為 `Proposed` 的上游。**這仍是比任何單一涵蓋缺口都更接近實作路徑的結構性阻擋,且已連續三輪未動。**

---

## 七、引擎相容性

### 版本一致性

5 份 ADR 皆宣告 Godot 4.7.1,無過期版本引用。

### 棄用 API:**零命中**(主審與 `godot-specialist` 各自獨立比對,結論一致)

對第二次修訂新增的全部依賴(`Node.add_child()`、子節點 `process_priority`、`Callable` 建構子注入、`Callable.is_valid()`/`call()`、`@abstract func` 回傳 `Vector2`、`move_toward()`、`InputMap.event_is_action()`、`Viewport.gui_get_hovered_control()`)逐一比對 `deprecated-apis.md` 全部條目(Nodes & Classes 7 項、Methods & Properties 10 項、Patterns 7 項)—— 全部未命中。

**誤報防範已執行**:該檔第 25 行 `connect("signal", obj, "method")` → `signal.connect(callable)`、第 29 行 `OS.get_ticks_msec()` → `Time.get_ticks_msec()`,**左欄才是棄用項,右欄是建議取代者**。ADR 使用的正是右欄形式,不構成命中。

**專家額外指出**:`deprecated-apis.md` 的 Patterns 表列有「Hardcoded keyboard/mouse device IDs → Query device ID at runtime」,而 ADR-0005 機制四**結構性地完全不讀 `.device`** —— 比「執行期查詢」更進一步,不只是沒踩到,是主動免疫。

### 引擎專家對第二次修訂新增假設的加壓判定

第二次修訂的**全部定序論證**都押在拆節點的優先序假設上,而參考庫對 `process_priority` **零命中**。逐項判定:

| # | 假設 | 證據等級 | 判定 |
|---|---|---|---|
| 1 | `process_priority` 為**全樹全域**排序,凌駕父在子之前的預設遍歷序 | **印象-高信心** | ADR 的父(−100)在子(−25)之前剛好與預設遍歷序一致,**不構成本案風險點**;但若未來有人誤以為「子節點必然晚於父節點」而省略顯式設定,會踩坑 |
| 2 | `_ready()` 內 `add_child()` **之後**才設 `process_priority` 是否正確重排 | **印象-中** | **ADR 完全沒明講實作順序** —— 機制一虛擬碼只寫「於 `_ready()` 內 `add_child()`」。專家印象是 setter 在樹上仍會正確觸發重排,但未確認是否有一幀延遲。**建議把「`add_child()` 前設定優先序」訂為強制寫法**,不依賴事後重排 |
| 3 | Autoload 與一般場景節點落在同一條 `_process` 鏈 | **印象-高信心** | ADR 假設方向正確 |
| 4 | `_input()` 保證整幀派發完畢才進入 `_process` 鏈 | **印象-高** | **全案最該優先驗證的單點失效點** —— 不成立則機制六六行為者排序與機制五「一幀=一批原子事件」前提**一併瓦解**。ADR 已列為 VR #2、Day-1 spike 第一項,排序正確 |
| 5 | `@abstract` 類別內 `signal` + 四種回傳型別的 `@abstract func` | `pass` 主體形式:**已查證**(專案自己的範例逐字);**組合:印象-中** | 維持 UNVERIFIABLE-FLAG-AS-RISK。**四種回傳型別須各建一檔分別編譯**,不可只測一種外推 |
| 6 | `InputMap.event_is_action()` 是否過濾 `InputEventKey.echo` | **印象-中** | **傾向同意 ADR 的「不過濾」猜測** —— `event_is_action()` 語意是事件內容與繫結的比對,`echo` 通常只在 `is_action_just_pressed()` 這類邊緣觸發查詢才特別處理。維持 VR #13 / Day-1 spike |
| 7 | `gui_get_hovered_control()` 對 `MOUSE_FILTER_IGNORE` 的行為 | **印象-高信心** | **發現新風險,見 R5-6** |
| 8 | `move_toward()` + 上升立即同步 | **已查證(API)+ 邏輯推理(組合)** | **未抓到破綻。** 唯一邊界情況:同影格 `VETOED_SAME_FRAME` 觸發 `_pending_snap` 後又發生後續滑鼠移動 → snap 到觸發當下的 `reclaim_progress()` 讀值而非保證為 0。邏輯上仍忠實反映判定值,不算錯誤,但應加入測試向量 |

### 引擎參考庫既有缺口(自第三輪起未動)

- `modules/` 全部 8 份標記 `Engine: Godot 4.6`,專案釘選 4.7.1 —— 落後一個大版本
- **參考庫自相矛盾仍開**:`breaking-changes.md` 第 43 行標 4.4→4.5 為 `POST-CUTOFF, HIGH RISK`,`VERSION.md` 版本時間軸標 4.5 為 `LOW (pre-cutoff)`,兩份對同一版本的風險分級相反,而 ADR-0004/0005 的 `@abstract` 語法賭注正好押在 4.5。ADR-0005 已在 VR #1 明文採較保守的一側,但**矛盾本身未修**
- ADR-0005 的 **13 項核心引擎依賴中 11 項在參考庫零命中**,另 2 項只存在於落後版本的文件裡
- 建議新增兩份模組文件:`core-scripting.md`(序列化/雜湊/檔案 I/O/並發原語)、以及一份涵蓋 Node 生命週期與輸入派發語意者(`process_priority`、`_input`/`_unhandled_input`/`_gui_input` 派發鏈與 `accept_event()`、Autoload 語意、`CanvasLayer`、雙焦點下的 `focus_mode`)

---

## 八、引擎專家自行發現(S-1 ~ S-5)

| 項 | 嚴重度 | 內容與修法 |
|---|---|---|
| **S-1** | 中 | **`mouse_position_provider: Callable` 只在建構時檢查一次有效性。** 機制十的 Negative 已承認 `_init()` 內斷言 `is_valid()`,但那只執行一次。若該 Callable 綁定的物件在測試情境下被釋放,後續每幀 `call()` 不再檢查,可能靜默失敗,且錯誤時間點與成因脫節。**修法**:每次呼叫前快速 `is_valid()` 檢查,無效時回傳明確哨兵值。**注意**:正式 Autoload 生命週期下此風險趨近於零,主要影響單元測試自訂假物件 |
| **S-2** | 低 | **`Input.mouse_mode` 逐幀無條件賦值 —— 第四輪的衛生性建議未被本次修訂採納。** 機制十三之二每幀無條件寫入,不論值是否與上一幀相同。第四輪已建議加 `if Input.mouse_mode != desired` 守衛。成本低,但值得記錄「先前輪次的非阻擋建議未被回頭處理」這個模式本身 |
| **S-3** | 中 | **`_notification()` 的派發順序是樹序,不是 `process_priority` 序,ADR 未明講。** 這是獨立於 VR #10(時序未定義)之外、更基礎的事實:即使 #10 驗證完成,同一次通知廣播對不同節點的呼叫順序仍是樹序。**修法**:機制九補一句「`_notification()` 派發順序為樹序,與本表的 `process_priority` 是兩個獨立排序機制」—— 這正是機制六自己對 `CanvasLayer.layer` vs `process_priority` 做過的同一類澄清,**這裡少做了一次** |
| **S-4** | 低 | **舊 `_reclaim` 實例的訊號連線是否需要顯式 `disconnect()` 未討論。** ADR 已承認「訊號連接不隨物件替換自動轉移」,但未談舊連線殘留。若替換只發生在測試,影響低;若未來子機制重啟允許執行期熱替換,訂閱方會透過連線持有舊策略物件參照直到顯式 `disconnect()`。建議補入「凍結子機制未來重啟」的待辦 |
| **S-5** | 低 | **`class_name` 全域命名空間無範圍限制。** `CursorState`/`CursorTarget` 等名稱在一個 49 個子代理人共同貢獻的專案裡有日後碰撞風險(例如某個「文字游標」功能)。建議在 registry 或某份文件維護一份「已註冊 `class_name` 清單」。純防禦性,不阻塞 |

---

## 九、GDD 修訂旗標

**引擎現實層面無新旗標** —— 所有 GDD 假設與已查證的引擎行為一致。

第三輪登記的兩處**設計文件內部張力**維持開啟:

| GDD | 張力 | 本輪變化 |
|---|---|---|
| `cursor-highlight-state.md` | Core Rules #1「恰 3 個頂層欄位」vs Core Rules #3「淨位移」隱含的累積起點 | 無變化。`diagnostic_seed_position()` 已改標 `@abstract` 並計入契約寬度,起點仍是契約明文的一部分,而 GDD 仍寫「恰 3 個頂層欄位」。張力停留在 GDD 那一側,**待 AC-1 的窮盡檢視實測** |
| `cursor-highlight-state.md` | Core Rules #5「原生指標必須被隱藏」vs Core Rules #7 / AC-60「未登記表面得用原生 hover」 | ADR 機制十三之二的技術層解法**本輪被發現有失效路徑**(R5-6)。ADR 明文承認不越權替 GDD 做設計裁決、要求 creative-director 或使用者回頭裁決 —— 處理方式仍正確,但**裁決尚未發生**,且現在多了一個技術層面的理由需要一併考慮 |

**未修改 `systems-index.md`**(第 28 列游標 GDD 狀態維持 `Approved`)—— 沿用第三、四輪立場:這兩項不是「GDD 假設與已驗證引擎行為衝突」型旗標,是否標記 `Needs Revision` 應由使用者裁決,審查 session 不逕自改動一份已 Approved 的 GDD 狀態。

---

## 十、架構文件涵蓋度與 Registry 覈實

`docs/architecture/architecture.md` **仍不存在** —— `/create-architecture` 尚未執行。架構知識分散於 5 份 ADR 與 `docs/registry/architecture.yaml`。

### Registry 本輪逐節實測 —— **全部對帳成立**

| 節 | 實測 | 檔頭自陳 |
|---|---|---|
| `state_ownership` | 10 | 10 ✅ |
| `interfaces` | 10 | 10 ✅ |
| `api_decisions` | 23 | 23 ✅ |
| `forbidden_patterns` | 22 | 22 ✅ |
| **合計** | **65** | **65** ✅ |

依 `adr:` 欄分佈:ADR-0001 13、ADR-0002 12、ADR-0003 6、ADR-0004 8、**ADR-0005 23**、`adr: none` 3(專案級裁決)= 65。ADR-0005 逐節為 **3 state / 4 interface / 7 api / 9 forbidden**,與檔頭自陳完全一致。

**第四輪點名的全部文件一致性問題已修正**:

- `technical-preferences.md` 第 51/66/69 行的三處計數 —— 現為「22 項」「其餘 19 項」「ADR-0005 共 9 項」,**實測正確**
- registry `state: mouse_reclaim_accumulator` 的 `interface:` 欄 —— 已同步 F3/R4-3 的方向拆分(明文寫出「rising: synced immediately; falling: converged via `move_toward()`; trigger (d): snapped」),`revised` 已填
- ADR-0005 Consequences 殘留的「19 項全部有機制支撐(其中 3 項為部分)」舊自陳 —— **已刪除**,並在原處寫明刪除理由

**這是四輪以來第一次 registry 與三份文件的計數完全對帳,零落差。**

`docs/consistency-failures.md` **仍不存在** —— 依 skill 規定不主動建立,故五輪審查的 C1~C6 與 F/N/R4/R5 系列發現只存在於各輪報告內,沒有跨輪的模式累積。**這已是第三輪起的同一項建議**;考慮到本專案已累積五輪、每輪都在辨識「同型別缺陷第 N 次出現」,這份檔案的缺席正在讓模式辨識完全依賴人工回讀歷史報告。

---

## 十一、判定

### **CONCERNS**

**為何不是 FAIL**:32 項 ❌ 中 **25 項在戰棋移動與交戰系統**,該 GDD 仍為「Designed,尚未 Approved」—— 沿用第二~四輪的同一隱含標準。三個 Foundation 層系統合計 73 項需求,**僅 1 項缺口**(`TR-save-030` 雲端存檔同步,自第二輪起未動);游標與好感度兩系統零缺口。32 項 ❌ 的分佈為:戰棋 25 + `game-concept` 6 + 存檔 1。**無阻塞級跨 ADR 衝突,且本輪起零銜接缺口。**

**BLOCKING 級缺陷是 `Accepted` 的閘門,不是本審查判定的閘門** —— R5-1 落在一份 `Proposed` ADR 內部,尚未進入任何 story 或程式碼。

**⚠️ 判定退回 FAIL 的條件(第三輪起登記,本輪重申)**:若戰棋 GDD 在其演算法層 ADR 之前先達 `Approved`,25 項 Core 層缺口即符合 FAIL 條件。

### ADR-0005 進入 `Accepted` 前必須關閉

1. **R5-1**(BLOCKING —— 需新增介面面,非一行修法)
2. **R5-6**(中高 —— 機制十四缺 `mouse_filter` 約束,或機制十三之二改判定方式)
3. **R5-3**(中高 —— `_reclaim` 三方持有管線;連帶滑鼠座標的三條路徑)
4. R5-2(中)、S-1(中)、S-3(中)
5. R5-4 / R5-5 / S-2 / S-4 / S-5(低,文件與衛生性)

### 下一步優先序

1. **`/architecture-decision` 修 ADR-0005 的 R5-1~R5-6 + S-1~S-5** —— 五份 ADR 皆 `Proposed`,改動成本最低。**本輪無銜接缺口需一併處理**(C1~C6 全關),範圍比前兩輪乾淨
2. **`/test-setup`** —— 與架構軌零依賴,pre-gate 五項中的三項
3. **`/ux-design`** —— pre-gate 剩餘兩項;注意 `cursor-highlight-state.md` 登記的孤兒義務(運動無障礙需求先前口頭轉交至一個不存在的檔案)
4. **戰棋盤面演算法層 ADR** —— 投入產出比最高的單一動作,一次移動 25 項 ❌ 中的大部分
5. **回合結構擁有權 + 缺席的 AI/遭遇系統 ADR** —— 全專案無人認領回合結構
6. **(建議)建立 `docs/consistency-failures.md`** —— 五輪下來已有足夠的同型別重複(自陳膨脹 ×3、修法引入新缺陷 ×2、示意圖/registry 未同步散文修訂 ×3)值得沉澱為可查的模式清單

### Pre-gate 檢查(2026-08-19 實測)

| 項目 | 狀態 |
|---|---|
| `tests/unit/` | ❌ 不存在 |
| `tests/integration/` | ❌ 不存在 |
| `.github/workflows/tests.yml` | ❌ 不存在 |
| `design/accessibility-requirements.md` | ❌ 不存在 |
| `design/ux/interaction-patterns.md` | ❌ 不存在 |

**五項全缺,`/gate-check pre-production` 目前不可執行。**
