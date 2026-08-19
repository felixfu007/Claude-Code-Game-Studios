# 架構審查報告 — 第四輪

| 欄位 | 值 |
|---|---|
| **日期** | 2026-08-19(與第三輪同日,ADR-0005 修訂後) |
| **模式** | `/architecture-review`(full) |
| **引擎** | Godot 4.7.1 |
| **GDD** | 5 份 |
| **ADR** | 5 份(ADR-0001~0005,**全部 `Proposed`,無一 `Accepted`**) |
| **判定** | **CONCERNS**(第三輪亦為 CONCERNS) |
| **前一輪** | `architecture-review-2026-08-19.md`(第三輪) |

**本輪目的**:第三輪判定 ADR-0005 有 9 項待修訂(F1/F5 為 BLOCKING),`/architecture-decision` 於同日修訂該 ADR 並在 Status 明文聲明**不自陳修訂後的涵蓋分佈**,留給獨立 session 重新推導。本輪即為該項驗證,於**全新 session**、**未參與該次修訂**的脈絡下執行。

---

## 零、先更正一項現況自陳

`production/session-state/active.md` 開頭寫「**本次修訂尚未提交 git**」——**不成立**。實測:

- ADR-0005 修訂、`docs/registry/architecture.yaml`、`.claude/docs/technical-preferences.md`、`active.md` 四者全部在提交 `7bb033b`(2026-08-19 10:19)內
- 工作區乾淨(`git status --porcelain` 無輸出),與 `origin/main` 同步(`rev-list --count --left-right` 為 `0 0`)

---

## 一、需求基線的處理方式

`docs/architecture/tr-registry.yaml` 有 133 個 `id:`,其中 3 個(`TR-combat-001`~`-003`)在註解區、是 ID 格式範例 —— **實為 130 項 active**,與第二、三輪一致。

**本輪不重推 111 項非游標需求**,理由是可查證的構造性事實,不是省事:

| 檔案 | `db04895`(第三輪提交)以來的改動次數 |
|---|---|
| `affinity-data-pool.md` / `save-system.md` / `cursor-highlight-state.md` / `tactical-combat-system.md` / `game-concept.md` / `systems-index.md` | **全部 0** |
| `adr-0001` / `adr-0002` / `adr-0003` / `adr-0004` | **全部 0** |
| `adr-0005` | 1(`7bb033b`) |
| `docs/registry/architecture.yaml` | 1(`7bb033b`) |
| `tr-registry.yaml` | 0 |

需求文字與 ADR 決策內容皆為位元組相同,涵蓋判定**不可能因輸入改變而移動**。因此本輪重推 19 項 `TR-cursor-*`,另因 ADR-0005 的機制觸及 `game-concept.md` 的三列同義需求而一併重推(見第三節末的傳播遺漏修正),其餘 **108 項**沿用第三輪判定。

**新增 TR-ID:無。** 無改寫、無棄用。`tr-registry.yaml` 本輪不需任何改動。

---

## 二、涵蓋率總覽

| 狀態 | 首輪 | 第二輪 | 第三輪 | **第四輪** | 本輪變化 |
|---|---|---|---|---|---|
| ✅ 已涵蓋 | 5(4%) | 50(38%) | 61(47%) | **65(50%)** | +4 |
| ⚠️ 部分涵蓋 | 16(12%) | 24(18%) | 34(26%) | **33(25%)** | −1 |
| ❌ 缺口 | 109(84%) | 56(43%) | 35(27%) | **32(25%)** | **−3** |
| **合計** | **130** | **130** | **130** | **130** | |

其中 +2 ✅ 來自游標系統重推,另 +2 ✅ / +1 ⚠️ / −3 ❌ 來自**修正第三輪的一項傳播遺漏**(見第三節末)。

| GDD | 系統 | 層級 | GDD 狀態 | 需求 | ✅ | ⚠️ | ❌ |
|---|---|---|---|---|---|---|---|
| affinity-data-pool.md | 好感度數值池 | Foundation | Approved | 24 | 22 | 2 | **0** |
| save-system.md | 存檔系統 | Foundation | Approved | 30 | 22 | 7 | 1 |
| cursor-highlight-state.md | 單一游標/高亮狀態 | Foundation | Approved | 19 | **13** | **6** | **0** |
| tactical-combat-system.md | 戰棋移動與交戰 | Core | **未 Approved** | 43 | 5 | 13 | 25 |
| game-concept.md | (跨系統) | — | — | 14 | **3** | **5** | **6** |

---

## 三、游標系統 19 項 —— 修訂後獨立重推

**第三輪判定 11 完整 / 8 部分。本輪重推為 13 完整 / 6 部分 / 0 缺口。**

### 由 ⚠️ 升為 ✅(2 項)

| TR-ID | 判定依據 |
|---|---|
| `-010` | **F5 完整關閉。** 機制五 `_process()` 補上 `_arbitration_suspended` 檢查;機制九四個進出點(`suspend_arbitration()`/`resume_arbitration()`/FOCUS_OUT/FOCUS_IN)全數 `_frame_events.clear()`。修訂另外自行發現並修補一項相鄰缺口——`resume_arbitration()` 原本沒有比照 FOCUS_IN 重新播種累積起點。N2 已登記為 Verification Required #10 並排入 Day-1 spike |
| `-019` | **F4 關閉。** `diagnostic_reclaim_progress_history` 改為取樣自繪節點的 `_presented_alpha`(呈現值)而非 `reclaim_progress()`(判定值),量測對象與 `reclaim_visual_convergence_max_frames` 所約束的對象一致 |

### 仍為 ⚠️(6 項)

| TR-ID | 本輪判定理由 |
|---|---|
| `-001` | **關閉它的機制本身有編譯期錯誤**(R4-2)。修訂已依第三輪要求補上 `diagnostic_seed_position()` 並劃掉條件式待決文字——方向正確,但該方法寫在抽象基底 `MouseReclaimPolicy` 內卻 `return _seed`,而 `_seed` 只宣告於子類別。修法一行,但在修好之前這項不能算完整 |
| `-008` | **F1 只關一半**(R4-1)。機制六新增第②行為者(−50)與對下游的明文約束,`-008` 的 AC-52 面已成立;但步驟三仍融在 −100,實際定序為 1&3 → 2 → 4,與 GDD 明文的 1 → 2 → 3 → 4 相反。另 R4-4(重入閘門可能鎖死 `arbitrate_frame()` 自己)、R4-5(`ActionClass` 白名單靜默降級)、R4-6(`call_deferred()` 路線不等價)皆落在此機制 |
| `-009` | **判定與 ADR 一致。** F2 已關閉(`evaluate()` 改收目前滑鼠座標、策略內部持 `_seed` 相減,結構性杜絕路徑總和;座標空間假設已明文寫入 Constraints)。但門檻數學本身仍在使用者裁決凍結中,不因介面修好而變成完整涵蓋 |
| `-011` | **判定與 ADR 完全一致,處理方式正確。** 機制八隔離在單一檔案,明文不宣稱已緩解、不宣稱降低嚴重度、不宣稱構成圍堵 |
| `-015` | **第三輪的兩項發現完全未處理。** 該兩項在第三輪未被編號為 F/N 項,修訂 session 依 9 項清單作業,因此漏掉:(a) GDD Core Rules #7 明訂「滑鼠奪權累積位移量於甲/乙兩分支皆**重置為 0**」,機制十一全文對此零字;(b) 丙分支 GDD 明文「若原目標在取消後仍然有效,**得直接以原目標值重新設定,不需要重新計算**」,ADR 仍寫成無條件「依 Core Rules #6 重新計算」——這是對 GDD 義務的**收窄**,牴觸本 ADR 自己 Ordering Note 的單向修訂約束 |
| `-017` | **F3 修法引入新違反**(R4-3)。呈現層平滑器方向正確,但 `move_toward()` 對上升方向同樣限速,結構上無法滿足 GDD「達到門檻的當下透明度達 100%」。N3 已處理(機制十三之二),且正確地把設計裁決退回 GDD,未越權 |

### 維持 ✅(11 項)

`-002`、`-003`、`-004`、`-005`、`-006`、`-007`、`-012`、`-013`、`-014`、`-016`、`-018` —— 判定依據與第三輪相同,對應機制本輪零改動。

### 額外修正:第三輪的一項傳播遺漏(`game-concept.md` 三列)

更新追溯索引時發現:`TR-concept-005`/`-006`/`-007` 三列的理由欄仍留著**第二輪**寫下的「下游 `cursor-highlight-state.md` 已設計,但架構層 ADR 未見」,第三輪引入 ADR-0005 時只重推了 19 列 `TR-cursor-*` 與 2 列 `TR-tactical-*`,沒有回頭掃過 `game-concept.md` 這三列同義需求。這不是本次修訂造成的,是第三輪的遺漏。

| TR-ID | 第三輪 | **第四輪** | 依據 |
|---|---|---|---|
| `TR-concept-005` | ❌ | **✅** | 機制十四兩項條件封住原生 focus/hover 兩條管線;一般化由機制二列舉 + 機制三登記制承載(與 `TR-cursor-018` 同義) |
| `TR-concept-006` | ❌ | **⚠️** | 兩層機制由機制四 + 機制四之二承載,Input Map 約束由機制七(a);但語意分類是硬編碼白名單、無完整性驗證(R4-5) |
| `TR-concept-007` | ❌ | **✅** | 機制十 `set_target(target, from_ui_action)` 即呼叫方注入介面;機制十一乙分支明文複用 Core Rules #6 初始流程 |

**教訓**:第三輪的「只重推受影響系統」策略本身正確,但**受影響範圍的判定漏掉了跨系統 GDD 裡的同義需求**。下一輪若再有單一 ADR 修訂,重推範圍應以「該 ADR 的機制觸及哪些需求」為準,而非「該 ADR 服務哪一份 GDD」。

---

## 四、9 項待修訂的處置判定

| 項 | 級別 | 處置 |
|---|---|---|
| **F5** | BLOCKING | **完整關閉**(兩處修法齊備 + 自行補上相鄰缺口) |
| F2 | 高 | **完整關閉** |
| F4 | 中 | **完整關閉** |
| N1 | 中 | **關閉**,但白名單完整性無防線(R4-5) |
| N2 | 中 | **關閉**(VR #10 + Day-1 spike) |
| N4 | 中 | **關閉**,但引入 R4-4 |
| **F1** | BLOCKING | **只關一半**(R4-1) |
| F3 | 高 | 機制到位,**引入 R4-3** |
| N3 | 中 | **關閉**,處理方式正確(明文不越權替 GDD 裁決) |

**模式觀察**:第三輪抓到的是「自陳涵蓋膨脹」(16/3 → 11/8);本輪抓到的是**修法本身引入新缺陷**——R4-2、R4-3、R4-4 三項全部是 2026-08-19 修訂新產生的,不存在於修訂前的版本。這不否定修訂的價值(9 項中 6 項完整關閉,兩項 BLOCKING 中的 F5 徹底解決),但說明「修訂後須獨立重推」這條紀律在本輪同樣兌現了它的價值。

---

## 五、本輪 7 項發現

> R4-1 ~ R4-3、R4-5 由主審獨立推導,`godot-specialist` 逐項對抗性覆核**全部成立**(R4-2 由該專家升為 BLOCKING、R4-3 判 HIGH/BLOCKING)。R4-4 為該專家於五項之外自行發現。R4-7 為主審提出、該專家**部分推翻**後採納其更正版本。R4-6 由主審獨立推導,未經專家覆核。

### R4-1 — F1 只關一半:步驟二/三仍與 GDD 相反 · **高(視同 BLOCKING)**

GDD Core Rules #2「四方完整定序」原文的四步是:

```
裝置權威判定 → 呼叫方主動改標呼叫(「設定新目標」/「標記待重新解析」,不限是否由 ui_* 觸發)
→ 緩衝內導覽類 ui_* 寫入 → 緩衝內確認類 ui_* 讀取
```

且 GDD 明文寫下理由:「**把呼叫方主動改標呼叫排在緩衝分派之前**,確保本影格的確認讀取永遠讀到呼叫方最新宣告的有效性」,並稱「**此定序方向本身是硬性行為要求**」。

修訂後的機制六實際排序:

```
①(−100:裝置權威判定 + 緩衝內導覽類寫入,兩者融合為一次原子呼叫)
→ ②(−50:呼叫方主動改標)→ ③已註冊表面(0)→ ④全域視覺層(50)→ ⑤(100:含確認讀取)
```

即 **1&3 → 2 → 4**。ADR 的辯護是「步驟一、三皆為本系統內部運算,呼叫方看不到中間狀態」——該論證只處理**可觀察性**,未處理**先後權**。具體行為差異(專家獨立推導出同一結論):同一影格,呼叫方 `set_target(A)`(步驟二)與緩衝內導覽寫入 `ui_right`(步驟三)並存時,最後寫入者勝——ADR 排序下 ② 覆寫 ①,**玩家當幀的方向鍵輸入被系統主動改標整個蓋掉**;GDD 排序下則是導覽寫入在呼叫方改標的基礎上計算並勝出。

**AC-52 的 THEN 子句(②在⑤之前)沒有被違反**,這是與第三輪 F1 的差別;但 AC-52 明訂的驗證方式是「程式碼審查為主——確認實作的節點執行順序符合四步序列」,照現行機制六審查會不通過。且既有 Validation Criteria #9 測的是 ②→⑤ 那一組,**②→③ 這組沒有任何測試涵蓋**。

**修法方向**:把 `arbitrate_frame()` 拆成兩段——裝置權威判定留在 −100,緩衝內導覽寫入下放到 −25(介於 ② 與 ③ 之間);或明文向 GDD 提出「同影格系統主動改標與導覽寫入的衝突解決規則」並取得裁決。後者屬 GDD 修訂,不是 ADR 單方可決定的事。

### R4-2 — `diagnostic_seed_position()` 讀取未宣告識別符 · **BLOCKING**

機制八的基底類別:

```gdscript
@abstract
class_name MouseReclaimPolicy extends RefCounted
...
func diagnostic_seed_position() -> Vector2:
    return _seed          # ← _seed 只宣告在子類別
```

`var _seed: Vector2` 的唯一宣告在 `class_name ThresholdMouseReclaimPolicy`。GDScript 的靜態解析作用域是「本類別 + 祖先鏈」,不會往子類別查找;而該方法**沒有** `@abstract` 標記(與同檔案其餘三個方法不同),會被當作基底類別自身的完整方法編譯 → 編譯期在 `_seed` 上失敗。

專家指出兩處不一致本身就是訊號:Key Interfaces 段落寫的是**無主體**的簽章,機制八本文寫的是**有主體**的完整範例,兩處沒有一處明說它是抽象方法。

**建議修法(專家傾向)**:`diagnostic_seed_position()` 改標 `@abstract`,與同檔案其餘三方法一致——「起點」本就是門檻子機制特有的概念,不該假設每個未來策略實作都有。(另一選項是把 `_seed` 上移到基底,代價是 `ImmediateMouseReclaimPolicy` 等實作被迫攜帶一個對它無意義的欄位。)

**這是純靜態閱讀即可 100% 確認的邏輯錯誤**,不依賴任何引擎行為驗證,且它正是關閉 `TR-cursor-001` 的那個方法。

### R4-3 — F3 平滑器對上升方向也限速 · **高(視同 BLOCKING)**

GDD Core Rules #3「漸進回饋」硬性要求原文:「以與移動進度……**成正比**的透明度漸進顯示——0% 進度時完全不可見,**達到門檻的當下透明度達 100%、同時完成權威轉移**」。

而「收斂上限」規則的管轄範圍,原文限定在「**這類非玩家滑鼠動作直接造成的重置**」——全段語境都是下降方向(歸零、收斂、不得瞬間跳變)。GDD **從未**對「朝門檻累積」的上升方向設下限速。

機制十三的實作對任何方向套用同一個 `max_step`:

```gdscript
_presented_alpha = move_toward(_presented_alpha, target, max_step)
```

`reclaim_visual_convergence_max_frames` 依 GDD 必須嚴格大於 0,且配置為 1 即等於單影格瞬間歸零(自我矛盾)→ 實際下限為 2 → `max_step ≤ 0.5`。而 GDD 初步校準門檻 50–100px,常見滑鼠速度下 2–3 影格即可跨過 → `_presented_alpha` **結構上不可能**在跨過門檻的當下達到 1.0。這是純數學上必然發生的違規。

專家的總結值得原樣保留:F3 修法「解決下降方向說謊的同時,在上升方向重新引入了同一類『呈現值與判定值不同步』的說謊——只是方向相反」。

**修法方向**:上升方向立即同步,只對下降方向(非觸發點 (d) 的重置)套用 `move_toward()` 限速。

### R4-4 — N4 重入閘門可能鎖死 `arbitrate_frame()` 自己 · **高**(專家額外發現)

機制十 N4 明文:`arbitrate_frame()`、`set_target()`、`mark_pending_reresolve()`、`handoff_before_unload()` **四者皆受** `_mutation_in_progress` 保護,進入時若旗標已為真一律回傳 `REJECTED_REENTRANT`。

而機制六說明 `arbitrate_frame()` 內部「先決定本影格裝置權威、再依權威決定是否套用緩衝內的導覽類目標變更」——即內部需要執行一次等同「寫入新目標」的動作。若該內部動作重用公開的 `set_target()`(最自然的實作),`arbitrate_frame()` 進入時已把旗標設為 `true`,內部呼叫 `set_target()` 會被自己的閘門判為重入而拒絕 → **機制六「同一次原子呼叫內完成判定與導覽寫入」的導覽寫入那一半永遠不生效**。

ADR 完全沒說明內部導覽寫入走公開方法還是私有路徑。**修法**:明文寫死「`arbitrate_frame()` 的內部目標寫入透過不受 `_mutation_in_progress` 檢查的私有方法完成;`set_target()`/`mark_pending_reresolve()` 才是唯一掛閘門的公開入口」。

### R4-5 — `ActionClass` 硬編碼白名單與「絕不靜默」紀律不一致 · **中高**

GDD 對「導覽類 `ui_*` action」的定義是**語意性、開放式**的(「語意上代表『移動游標』的動作」),而機制四之二是封閉的六項硬編碼清單(`ui_up`/`ui_down`/`ui_left`/`ui_right`、`ui_accept`/`ui_cancel`)。機制七(a) 的載入期驗證器雖然遍歷全部 `ui_*` action,但驗證的是完全不同的屬性(是否誤綁滑鼠),**不做分類完整性的交叉檢查**。

後果:未來新增任何語意上屬於導覽的 `ui_*` action(專案自訂,或複用引擎內建的 `ui_focus_next`/`ui_page_up` 等),會被靜默歸為 `OTHER`、失去主張裝置權威的資格,**沒有任何啟動期或執行期檢查會攔下**。這與本 ADR 在別處反覆兌現的「絕不靜默」紀律(機制十的雙查詢、機制七(b) 的 `has_setting()` 防衛)不一致。

**修法**:機制七補一條驗證——遍歷全部 `ui_*` action,任一未出現在 `NAVIGATION_ACTIONS ∪ CONFIRM_ACTIONS` 者,回報為需人工分類確認的清單,而非靜默視為 `OTHER` 通過。

### R4-6 — `call_deferred()` 路線與旗標路線不等價 · **中**(未經專家覆核)

機制六為「觸發來源在 `_physics_process()` 的呼叫方」提出兩條路線:設旗標於 `_process()` 開頭執行,或「使用 `call_deferred()` 排入下一次 `_process()`」。

前者可行(Godot 主迴圈同一次迭代內物理步先於 idle 處理,−50 的 `_process()` 仍在當幀 ⑤ 之前)。後者是一個**未經查證的排程時點斷言**——ADR 從未驗證延後呼叫的沖洗點相對 `_process` 鏈的位置。若落點在 `_process` 鏈之後或次影格,當幀的確認讀取(⑤)會先於改標(②)發生,**重新打開 F1 剛關上的洞**。

**修法**:刪去 `call_deferred()` 選項,或把它的沖洗時點列為 Verification Required 並在驗證前不得作為建議路線。

### R4-7 — ②/⑤ 角色重疊未討論 · **中**(專家部分推翻主審初判後的採納版本)

主審初判為「優先序梯無解」。專家**推翻該結論**:`process_priority` 只決定跨節點的 `_process()` 呼叫先後,管不到函式內部;若同一系統身兼二職,把改標邏輯寫在確認讀取之前即可,不需拆節點。**採納此更正。**

殘留的是真實文件缺口:ADR 的行為者表與 Architecture Diagram 都暗示「一角色一節點」,而戰棋系統同時是改標呼叫方與確認讀取方幾乎是必然,ADR 對此一字未提。**修法**:補一段明文——「若同一系統身兼多個行為者角色,可於單一節點的單一 `_process()` 內以陳述順序保證相對順序,只需確保該節點整體晚於 −100」。

---

## 六、文件一致性(低嚴重度,但為同型別第三次)

| 項目 | 現況 | 應為 |
|---|---|---|
| `.claude/docs/technical-preferences.md` 第 51 行 | 「`forbidden_patterns` 節(目前 **17** 項)」 | **19** 項 |
| 同檔第 66 行 | 「其餘 **14** 項為 ADR-0001~0005……」 | **16** 項 |
| 同檔第 69 行 | 「**ADR-0005 新增 4 項**(游標系統)」 | **6 項**,新增 `confirm_action_read_in_unhandled_input`、`cursor_state_write_from_own_signal_handler` |
| `docs/registry/architecture.yaml` `state: mouse_reclaim_accumulator` 的 `interface:` | 「Read by the self-drawn progressive-feedback cursor node's `modulate.a`」 | F3 已改為呈現層平滑器 `_presented_alpha`,該欄未同步(`revised:` 亦空白) |
| ADR-0005 Consequences → Positive / Negative | 仍寫「19 項全部有機制支撐(其中 **3** 項為部分)」、Negative 仍只列 `-009/-010/-011` | 與 Status 宣告的「不自陳涵蓋分佈」及第三輪判定(8 項部分)互相矛盾 |

`7bb033b` 的 commit message 宣稱「technical-preferences.md and session-state/active.md counts synced」,實際只同步了 technical-preferences 第 88 行的 Registry 累計段,Forbidden Patterns 節三處未動。

**本輪已依使用者核准修正第 51/66/69 行**;registry 的 `interface:` 欄與 ADR-0005 的 Consequences 措辭留待 `/architecture-decision`(前者屬 registry 維護、後者會動到 ADR 本文)。

---

## 七、跨 ADR 衝突與銜接缺口

**零阻塞級衝突。** ADR-0001~0004 本輪零改動,第三輪的衝突面判定原樣成立。

| 缺口 | 狀態 |
|---|---|
| **C1**(`TOKEN_TIMEOUT_MS` 無人擁有:ADR-0002 委派給存檔系統,ADR-0004 退回「非本系統補償」) | **仍開**,自第二輪起未動 |
| **C3**(`TR-affinity-016` 條件已由 ADR-0004 判為「否」,ADR-0002 仍宣稱其 `Mutex` 是專案唯一執行緒安全義務) | **仍開**,自第二輪起未動 |
| **C6**(ADR-0005 機制十一宣稱與 ADR-0004 存檔讀取路徑「直接交接」,但 ADR-0004 全文對「游標」/「cursor」/「ADR-0005」**實測零命中**) | **仍開**,且因 R4-1 中 `-015` 的兩項未處理而**更值得注意**——被單方面宣稱交接的那一側,其分支行為本身就與 GDD 有兩處落差 |
| C2 / C4 / C5 | 已於 `a56dd10` 修正,第三輪覆核成立,本輪不重驗(相關檔案零改動) |

### ADR 依賴序(無環)

```
Foundation(無依賴):ADR-0001 戰棋查詢原子性 / ADR-0002 好感度數值池 / ADR-0005 游標裝置權威
依賴 Foundation:    ADR-0003 存檔序列化(requires ADR-0002)
Feature 層:         ADR-0004 存檔原子寫入與遷移(requires ADR-0003)
```

⚠️ **ADR-0003 依賴 ADR-0002、ADR-0004 依賴 ADR-0003,而全部 5 份皆為 `Proposed`** —— 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋。這是比任何單一涵蓋缺口都更接近實作路徑的結構性阻擋。

---

## 八、引擎相容性

### 版本一致性

5 份 ADR 皆宣告 Godot 4.7.1,無過期版本引用。

### 棄用 API

對 2026-08-19 修訂新增的全部 API(`InputMap.event_is_action()`、`Viewport.gui_get_hovered_control()`、`move_toward()`、`Input.mouse_mode`、`CanvasLayer`、`@abstract`、`signal`、`signal.connect(callable)`)逐列比對 `deprecated-apis.md` 全部條目 —— **零命中**(主審與 `godot-specialist` 各自獨立比對,結論一致)。

### 引擎專家對新增依賴的證據等級判定

| 依賴 | 等級 | 風險 |
|---|---|---|
| `move_toward()` | **已查證(高信心)** | 無。確為「目標值持續變動、非到達即停」的正確慣用工具,優於每幀重啟 `Tween` |
| `InputMap.event_is_action()` | 印象(中高) | **對 `InputEventMouseMotion` 必然回傳 `false`**(與設計一致但 ADR 未明講);**印象中不過濾 `InputEventKey.echo`** —— 按住方向鍵的重複事件會與初次按下同樣判為 NAVIGATION,ADR 完全未討論。**本項最值得回頭確認** |
| `Viewport.gui_get_hovered_control()` | 印象(中) | ADR 宣稱「O(1) 快取查詢、逐幀呼叫無虞」是**撰寫該 ADR 的同一 session 自我背書,不是獨立查證**;另需留意設 `MOUSE_FILTER_IGNORE` 的已註冊表面根節點是否會讓機制十三之二的回退路徑失效 |
| `@abstract` + `signal` 組合 | 印象(中) | 同意 ADR 立場:列為風險、Day-1 spike,不宜假設可行 |
| `Input.mouse_mode` 逐幀重複賦值 | 印象(中) | `VISIBLE`/`HIDDEN` 不涉位置搬移(不同於 `CAPTURED`/`CONFINED`),無座標副作用;但屬性 setter 印象中無「同值跳過」去重,每幀可能轉發一次 `DisplayServer` 呼叫。建議加 `if Input.mouse_mode != desired` 守衛(衛生性建議) |
| `CanvasLayer` + `get_viewport().get_mouse_position()` | 印象(中高) | **專家對 ADR 的 Verification Required #11 提出更正**,見下 |

### 專家對 Verification Required #11 的更正(應回頭拆項)

ADR 把兩個不同性質的問題綁在同一風險項:

- **機制八的淨位移數學**:全程只是兩個 viewport-space 座標相減求距離,從未轉進 `CanvasLayer` 的局部空間 → **結構上不受該層是否恆等變換影響**,此處為虛驚
- **機制十三/十三之二的視覺定位**:若把 viewport 座標直接指派給掛在該 `CanvasLayer` 底下的自繪節點 `position`,而該層帶非恆等變換 → **這裡才是真風險**

綁在一起會讓 Day-1 spike 的範圍設計過寬,或反過來稀釋真正該驗的那一半。**建議拆成兩條 Verification Required。**

### 新發現:引擎參考庫自相矛盾(專家發現,主審實測覆核成立)

| 文件 | 對 4.4→4.5 的風險分級 |
|---|---|
| `docs/engine-reference/godot/breaking-changes.md` 第 43 行 | `## 4.4 → 4.5 (Late 2025 — POST-CUTOFF, HIGH RISK)` |
| `docs/engine-reference/godot/VERSION.md` 版本時間軸 | `4.5 \| ~Late 2025 \| LOW (pre-cutoff)` |

兩份文件對同一版本的風險分級**相反**,而 ADR-0004 與 ADR-0005 的 `@abstract` 語法賭注正好押在 4.5。建議 technical-director 一併處理(與下方模組文件落後同一批)。

### 既有引擎參考庫缺口(自第三輪起未動)

- `modules/` 全部 8 份標記 `Engine: Godot 4.6`,專案釘選 4.7.1 —— 落後一個大版本
- ADR-0005 的 **11 項核心引擎依賴中 9 項在參考庫零命中**,另 2 項只存在於落後版本的文件裡(修訂新增 3 項依賴,全部零命中)
- 建議新增兩份模組文件:`core-scripting.md`(序列化/雜湊/檔案 I/O/並發原語)、以及一份涵蓋 Node 生命週期與輸入派發語意者(`process_priority`、`_input`/`_unhandled_input`/`_gui_input` 派發鏈與 `accept_event()`、Autoload 語意、`CanvasLayer`、雙焦點下的 `focus_mode`)

---

## 九、GDD 修訂旗標

**引擎現實層面無新旗標** —— 所有 GDD 假設與已查證的引擎行為一致。

第三輪登記的兩處**設計文件內部張力**維持開啟,且其中一項因本次修訂而更明顯:

| GDD | 張力 | 本輪變化 |
|---|---|---|
| `cursor-highlight-state.md` | Core Rules #1「恰 3 個頂層欄位」vs Core Rules #3「淨位移」隱含的累積起點 | ADR 已補 `diagnostic_seed_position()` 把起點納入契約 → **起點現在是契約明文的一部分,而 GDD 仍寫「恰 3 個頂層欄位」**。張力沒有消失,只是換到了 GDD 那一側 |
| `cursor-highlight-state.md` | Core Rules #5「原生指標必須被隱藏」vs Core Rules #7 / AC-60「未登記表面得用原生 hover」 | ADR 機制十三之二提出技術層解法,並**明文承認不越權替 GDD 做設計裁決**、要求 creative-director 或使用者回頭裁決。處理方式正確,但**裁決尚未發生** |

**未修改 `systems-index.md`**(第 28 列游標 GDD 狀態維持 `Approved`)—— 沿用第三輪立場:這兩項不是「GDD 假設與已驗證引擎行為衝突」型旗標,是否標記 `Needs Revision` 應由使用者裁決,審查 session 不逕自改動一份已 Approved 的 GDD 狀態。本輪已詢問使用者,使用者未選擇此項。

---

## 十、架構文件涵蓋度

`docs/architecture/architecture.md` **仍不存在** —— `/create-architecture` 尚未執行。架構知識分散於 5 份 ADR 與 `docs/registry/architecture.yaml`。

**Registry 本輪覈實(全部成立)**:

- 總計 **61 項立場**:10 state-ownership、10 interfaces、22 api_decisions、19 forbidden_patterns(逐節實數)
- 對照:58 項具 ADR 來源 + 3 項 `adr: none`(專案級裁決)= 61;另有 7 行 `adr: docs...` 位於註解區的範例,不計入
- ADR-0005 佔 **20 項**(第三輪為 14 項),與 registry 檔頭自陳的「3 state / 4 interface / 7 api / 6 forbidden」總數一致
- 本次修訂就地修訂 **3** 項既有條目(`contract: cursor_target_write`、`purpose: cursor_actor_process_priority_ladder`、`purpose: cursor_visual_carrier_split`,皆 `revised: 2026-08-19`)—— commit message 與 technical-preferences 皆只提「2 項 api_decisions」,漏記 `cursor_target_write` 這一項 interface

`docs/consistency-failures.md` **仍不存在** —— 依 skill 規定不主動建立,故四輪審查的 C1~C6 與 F/N/R4 系列發現只存在於各輪報告內,沒有跨輪的模式累積。

---

## 十一、判定

### **CONCERNS**

**為何不是 FAIL**:32 項 ❌ 中 **25 項在戰棋移動與交戰系統**,該 GDD 仍為「Designed,尚未 Approved」——沿用第二、三輪的同一隱含標準。三個 Foundation 層系統合計 73 項需求,**僅 1 項缺口**(`TR-save-030` 雲端存檔同步,自第二輪起未動);游標與好感度兩系統零缺口。32 項 ❌ 的分佈為:戰棋 25 + `game-concept` 6 + 存檔 1。無阻塞級跨 ADR 衝突。

**BLOCKING 級缺陷是 `Accepted` 的閘門,不是本審查判定的閘門** —— 本輪三項高/BLOCKING 級發現全部落在一份 `Proposed` ADR 內部,尚未進入任何 story 或程式碼。

**⚠️ 判定退回 FAIL 的條件(第三輪即已登記,本輪重申)**:若戰棋 GDD 在其演算法層 ADR 之前先達 `Approved`,25 項 Core 層缺口即符合 FAIL 條件。

### ADR-0005 進入 `Accepted` 前必須關閉

1. **R4-2**(BLOCKING,一行修法)
2. **R4-1**(高,視同 BLOCKING —— 與第三輪 F1 同一母問題)
3. **R4-3**(高,視同 BLOCKING —— 純數學上必然違反 GDD 硬性要求)
4. **R4-4**(高)
5. **`TR-cursor-015` 的兩項落差**(第三輪未編號,修訂 session 依 9 項清單作業而漏掉)
6. R4-5 / R4-6 / R4-7(中~中高)

### 下一步優先序

1. **`/architecture-decision` 修 ADR-0005 的 R4-1~R4-7 + `-015` 兩項落差** —— 五份 ADR 皆 `Proposed`,現在改動成本最低;建議與 C1/C3/C6 一併處理
2. **`/test-setup`** —— 與架構軌零依賴,pre-gate 五項中的三項
3. **`/ux-design`** —— pre-gate 剩餘兩項;注意 `cursor-highlight-state.md` 登記的孤兒義務(運動無障礙需求先前口頭轉交至一個不存在的檔案)
4. **戰棋盤面演算法層 ADR** —— 投入產出比最高的單一動作,一次移動 35 項 ❌ 中的大部分
5. **回合結構擁有權 + 缺席的 AI/遭遇系統 ADR** —— 全專案無人認領回合結構

### Pre-gate 檢查(2026-08-19 實測)

| 項目 | 狀態 |
|---|---|
| `tests/unit/` | ❌ 不存在 |
| `tests/integration/` | ❌ 不存在 |
| `.github/workflows/tests.yml` | ❌ 不存在 |
| `design/accessibility-requirements.md` | ❌ 不存在 |
| `design/ux/interaction-patterns.md` | ❌ 不存在 |

**五項全缺,`/gate-check pre-production` 目前不可執行。**
