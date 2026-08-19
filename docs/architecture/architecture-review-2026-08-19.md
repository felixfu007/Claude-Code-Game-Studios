# 架構審查報告 — 第三輪

| 欄位 | 值 |
|---|---|
| **日期** | 2026-08-19 |
| **模式** | `/architecture-review`(full) |
| **引擎** | Godot 4.7.1 |
| **GDD** | 5 份 |
| **ADR** | 5 份(ADR-0001~0005,**全部 `Proposed`,無一 `Accepted`**) |
| **判定** | **CONCERNS**(第二輪為 FAIL) |
| **前一輪** | `architecture-review-2026-08-18-round2.md` |

**本輪目的**:第二輪判定 FAIL,唯一硬阻塞為單一游標/高亮狀態系統 19 項需求零涵蓋。ADR-0005 於同日撰寫並自陳「16 完整 / 3 部分」,但撰寫者自評不算數 —— 第二輪正是抓到三份文件都宣稱「30 項 `TR-save-*` 全覆蓋」而實為 22/7/1。本輪於**全新 session**、**未曾執行 `/architecture-decision`** 的脈絡下獨立重新推導。

---

## 需求基線的處理方式

`docs/architecture/tr-registry.yaml` 有 133 個 `id:` 條目,其中 3 個(`TR-combat-001`~`-003`)位於註解區、是 ID 格式範例而非真實需求 —— **實為 130 項 active**,與第二輪一致。

**5 份 GDD 自第二輪以來零修改**(實測:最新 GDD 提交為 `08bf6ff`,2026-08-18 10:16;第二輪審查提交 `1c3d5d0` 為 15:43,之後無任何 GDD 被改動)。因此 130 項基線原封不動:**無新增、無改寫、無棄用 TR-ID**。

涵蓋率的變動只可能來自第二輪之後的三處 ADR 變動:

| 變動 | 對涵蓋率的影響 |
|---|---|
| ADR-0005(新,720 行) | 本輪主要重推對象 |
| ADR-0003 `+6` 行(C2 型別名統一為 `ImportResult`) | **零格移動** —— 純命名一致化 |
| ADR-0004 `+13` 行(C4 拍板 `store_buffer()`、C5 弱化「已驗證先例」措辭) | **零格移動** —— C4 補的是兩份 ADR 之間的空白而非需求涵蓋;C5 是誠實化措辭,機制未變 |

## 涵蓋率總覽

| 狀態 | 首輪 | 第二輪 | **第三輪** | 變化 |
|---|---|---|---|---|
| ✅ 已涵蓋 | 5(4%) | 50(38%) | **61(47%)** | +11 |
| ⚠️ 部分涵蓋 | 16(12%) | 24(18%) | **34(26%)** | +10 |
| ❌ 缺口 | 109(84%) | 56(43%) | **35(27%)** | **−21** |
| **合計** | **130** | **130** | **130** | |

| GDD | 系統 | 層級 | GDD 狀態 | 需求 | ✅ | ⚠️ | ❌ |
|---|---|---|---|---|---|---|---|
| affinity-data-pool.md | 好感度數值池 | Foundation | Approved | 24 | 22 | 2 | **0** |
| save-system.md | 存檔系統 | Foundation | Approved | 30 | 22 | 7 | 1 |
| cursor-highlight-state.md | 單一游標/高亮狀態 | Foundation | Approved | 19 | **11** | **8** | **0** |
| tactical-combat-system.md | 戰棋移動與交戰 | Core | **未 Approved** | 43 | 5 | 13 | 25 |
| game-concept.md | (跨系統) | — | — | 14 | 1 | 4 | 9 |

**本輪由 ❌ 轉出的項目**:19 項 `TR-cursor-*`(全部,→ 11 ✅ / 8 ⚠️)、`TR-tactical-024`/`-025`(→ ⚠️,ADR-0005 機制十已定案介面側)。

---

## 一、游標系統 19 項 —— 獨立重推結果

**ADR-0005 自陳 16 完整 / 3 部分(`-009`/`-010`/`-011`)。本輪獨立重推為 11 完整 / 8 部分 / 0 缺口** —— 5 項(`-001`/`-008`/`-015`/`-017`/`-019`)由 ✅ 降為 ⚠️。

### ✅ 完整涵蓋(11 項)

| TR-ID | 判定依據 |
|---|---|
| `-002` | 機制二 `CursorTypes` 包裝類別。沿用 ADR-0002 已查證的 `AffinityTypes` 先例(裸 enum 跨檔無法編譯)。**關掉自 GDD 第四輪起懸置的「實作位置與擁有者未定案」** |
| `-003` | 機制三 `CursorSurfaceRegistry.register()` 對已占用標籤回傳 `DUPLICATE_TAG_REJECTED` 不覆寫;迭代一律經 `registered_surfaces_sorted()`,沿用 `relying_on_container_iteration_order` |
| `-004` | 機制四 `classify()` 純子類別 match,結構性不觸及 `.device`。對 4.7 裝置 ID 重新編號免疫;`-1` sentinel 列為下游警告項 |
| `-005` | 機制七(a) `CursorStartupValidator` 遍歷 `InputMap.get_actions()`/`action_get_events()`;執行期重新綁定明文排除(專案尚無該系統) |
| `-006` | 機制五 `_input()` 只 append、`_process()` 統一裁決。拒絕 `_unhandled_input()` 的因果鏈(被 `accept_event()` 消費的事件永不抵達緩衝區,是**遺漏**而非重排序)明文記錄 |
| `-007` | 機制七(b) 載入期驗證 + `has_setting()` 防衛:鍵不存在回報 `AGILE_FLUSHING_SETTING_KEY_UNKNOWN` 而非視為通過。**本輪唯一堪稱模範的一項** —— 唯一刻意讓未查證項在執行期自我暴露的設計 |
| `-012` | 機制十 `set_target(target, from_ui_action) -> SetTargetResult`。幾何查詢自 GDD 第九輪門檻改錨定表面類型常數後已完全不存在 |
| `-013` | 機制十 `mark_pending_reresolve(expected) -> MarkResult`,`STALE_NOT_APPLIED` 為明確回傳值;競態判定依賴 `CursorTarget.equals()` 值語意 |
| `-014` | 機制十刻意分為**兩個獨立查詢**而非合併布林。論證正確:兩種拒絕的正確補救動作相反(等待重解析 vs 移動滑鼠取回權威),合併會讓呼叫方結構上無法產生可區分回饋 |
| `-016` | 機制十二 Autoload 持有的全域 `CanvasLayer`。**結構性關掉擁有權缺口** —— 缺口成因是需求本身(存在於每個畫面)排除了任何畫面範圍擁有者,而 Autoload 是本專案第一個跨所有畫面的實體 |
| `-018` | 機制十四**兩項**條件(`focus_mode = FOCUS_NONE` **加上**根 Control 不得帶內建 hover 主題)。2026-08-18 Step 5.5 的修訂方向正確 —— 引擎專家本輪覆核同意兩條管線獨立,同意「不移除、只降級」的保守做法 |

### ⚠️ 部分涵蓋(8 項)

| TR-ID | ADR 自評 | 本輪判定理由 |
|---|---|---|
| `-001` | ✅ | ADR 機制一自己寫下「若 AC-1 的窮盡檢視認定策略物件內部另有累積起點構成第四個未承認欄位,則本 ADR 須回頭把起點也明文列入契約」。**條件未解,卻在涵蓋表記為完整** —— 這正是第二輪在 ADR-0004 身上抓到的宣稱膨脹模式。機制八現行三方法契約沒有任何起點 getter,起點在今日確實是隱藏狀態 |
| `-008` | ✅ | **F1(BLOCKING)**:機制六的「四個行為者」不是 GDD 的「四方完整定序」,且產生的順序違反 AC-52。詳見第二節 |
| `-009` | ⚠️ | 同意為部分,但 ADR 只歸因於子機制凍結。**另有 F2**:機制八介面對「累積起點」的擁有權自相矛盾,且參數命名邀請 GDD 明文禁止的路徑總和實作 |
| `-010` | ⚠️ | 同意為部分。**另有 F5(BLOCKING)**:失焦/暫停當幀已緩衝的事件仍會被裁定;四個進出點皆未清空 `_frame_events`。**另有 N2**:`_notification()` 相對 `process_priority` 的時序未定義且未列入 Verification Required |
| `-011` | ⚠️ | **判定與 ADR 完全一致,處理方式正確。** 機制八把缺陷隔離在單一檔案,明文不宣稱已緩解、不宣稱降低嚴重度、不宣稱構成圍堵措施。這是本 ADR 面對凍結項最誠實的一段 |
| `-015` | ✅ | 機制十一**漏掉 GDD Core Rules #7 明訂的「滑鼠奪權累積位移量於甲/乙兩分支皆重置為 0」**(2026-08-12 第九輪新增,理由:累積起點所依附的表面已不存在)。另:丙分支寫成無條件「依 Core Rules #6 重新計算」,但 GDD 明文「若原目標在取消後仍然有效,得直接以原目標值重新設定,不需要重新計算」 |
| `-017` | ✅ | **F3**:`modulate.a` 直綁 `reclaim_progress()`,結構上無法同時滿足 AC-41 與 AC-41b。**另有 N3**:`Input.mouse_mode` 是全域設定,與 AC-60 未登記表面 carve-out 未調和 |
| `-019` | ✅ | **F4**:收斂上限的量測儀器量錯對象。交接延遲 ≤1 幀那一項(`diagnostic_last_authority_change_frame`)判定正確 |

---

## 二、五項確認缺陷

全部經 `godot-specialist` 逐項對抗性覆核,**五項全部成立**,其中 F1/F5 判定比初審更嚴重。

### F1 — 機制六答錯了問題,且違反 AC-52 · **BLOCKING** · 證據:已查證

GDD Core Rules #2「四方完整定序」定案的四步是:

```
裝置權威判定 → 呼叫方主動改標呼叫 → 緩衝內導覽類 ui_* 寫入 → 緩衝內確認類 ui_* 讀取
```

**AC-52 的驗證方式明文就是核對這個序列**,GDD 稱此定序方向為硬性行為要求,只把具體 `process_priority` 數值留給 `/create-architecture`。

ADR 機制六列的卻是**節點渲染更新序**：①裁定者 −100 ②已註冊表面 0 ③全域視覺層 50 ④下游讀取方 100。表裡**根本沒有「呼叫方主動改標」這個行為者的位置**。而機制五把裁定 + 緩衝分派整批塞進 `_process()` 的 `arbitrate_frame()`(−100),呼叫方的主動改標必然落在 priority ≥ 0 —— **GDD 的第 2 步被排到第 4 步之後**,正是 AC-52 存在要防止的「單位死亡與玩家確認同幀」情境:確認讀取先發生,對一個本影格即將被標記失效的目標完成確認。

**AC-52 也不在 ADR 的 Validation Criteria 清單裡**(該清單列了 AC-2、AC-12、AC-15/16、AC-20、AC-59、AC-60、AC-61/63a/63b)。

**引擎專家的加重(兩點)**：

1. 「緩衝內確認類 `ui_*` 讀取」**由誰執行、掛在哪裡,ADR 從未定義**。若下游系統在自己的 `_input()`/`_unhandled_input()` 裡直接處理 `ui_accept` 並查詢 `is_current_target_valid()`,該讀取會發生在同影格 `_process()` **開始之前** —— 連「裁定者先跑」這個最基本保證都不成立。
2. `process_priority` **完全管不到 `_unhandled_input()`**。即使機制六加入第五個優先序,也無法約束一個在 `_unhandled_input()` 裡讀取確認動作的下游系統。

**修法方向(真實擴充,非措辭澄清)**：機制六須新增規則,要求呼叫方改標邏輯與確認動作判讀**都必須在 `_process()` 執行**,且優先序滿足 `裁定者(−100) < 呼叫方改標 < 確認讀取`。這等於把機制五「不得掛 `_unhandled_input()`」的紀律**擴張為對下游系統的約束** —— ADR 目前完全沒有把這條寫給下游。

### F2 — `MouseReclaimPolicy` 介面自相矛盾,且邀請被禁止的實作 · 證據:介面矛盾已查證 / 座標空間為印象

現行三方法契約:

```gdscript
func evaluate(mouse_motion_net_delta: Vector2, surface: CursorTypes.SurfaceType) -> bool
func reclaim_progress() -> float
func reset(seed_position: Vector2) -> void
```

- `reset(seed_position)` 代表**策略物件持有起點**;`evaluate(mouse_motion_net_delta)` 代表**呼叫方已算好淨位移**。兩種語意各沾一半,兩者都不完整。
- 若由呼叫方算,呼叫方必須自己持有起點 → 起點落在 `CursorState` 上 → 成為 `TR-cursor-001`「恰 3 個頂層欄位」的第 4 個欄位。
- **最危險的是命名本身**:`arbitrate_frame()` 手上只有 `InputEventMouseMotion`,看到 `_net_delta` 這個參數名、且每幀被呼叫一次,最自然的實作就是累加 `event.relative` —— **那正好是 GDD Core Rules #3 明文禁止的路徑總和**(禁止理由:路徑總和會讓原地抖動在零淨位移下跨過門檻,直接違反本規則存在的目的)。要算淨位移必須用絕對座標減起點。**這是介面本身設下的陷阱,不是實作者粗心的問題。**

**建議修法**:`evaluate()` 改收 `current_mouse_position: Vector2`(根視窗座標),由策略內部用自己持有的 `_seed` 相減。這同時讓 `reset(seed_position)` 的語意自洽、結構性杜絕路徑總和、並解決 `-001` 的第 4 欄位疑問。

**殘留未查證**:GDD 要求「根視窗/主視窗座標系」,但 ADR 從未明文哪個 API 建立這個座標空間;機制九用 `get_viewport().get_mouse_position()` 播種起點,與 `evaluate()` 的參數是否同一空間取決於「全程單一根 Viewport」這個**從未在 ADR 任何地方聲明的假設**。專案參考庫對此零涵蓋。**應補為 Verification Required 項,並補一句單一根 Viewport 的明文假設。**

### F3 — 呈現層平滑器缺失 · 證據:已查證

GDD 是**兩個值**的模型:

- `reclaim_progress` 本身**必須立即**反映全部四個重置觸發點 (a)(b)(c)(d),不因呈現層考量而延遲判定。
- **呈現層透明度**對觸發點 (a)(b)(c) **不得單影格瞬間歸零**,必須在 `reclaim_visual_convergence_max_frames`(硬性約束 > 0,見 AC-46b)內收斂;觸發點 (d) 是**唯一**允許同影格瞬間歸零的例外(AC-41b)。

ADR 機制十三只寫「自繪節點的 `modulate.a` 讀取 `MouseReclaimPolicy.reclaim_progress()`」—— **直接綁定、無任何平滑層**。`reclaim_progress()` 一歸零,`modulate.a` 就同影格歸零:對 (a)(b)(c) **必然違反 AC-41**,對 (d) 才恰好符合 AC-41b。且三方法契約**沒有任何管道**讓呈現層知道這次歸零是哪個觸發點造成的,無從決定該 snap 還是漸退。

**建議修法**:`reset()` 簽章擴充為 `reset(seed_position: Vector2, trigger: ResetTrigger)`(或發 `reset_triggered(trigger)` 訊號),自繪節點在 `_process()` 內對目標值做逐幀插值收斂,**除非** `trigger` 為原觸發點 (d) 才 snap。

> **⚠️ 連動影響**:此修法會擴充機制八的契約寬度,**動搖 ADR 自陳的 Validation Criteria #8「隔離邊界真的只有三個方法寬」**。這是連動修訂,不是局部小補丁。

### F4 — 收斂上限的量測儀器量錯對象 · 證據:已查證(F3 的下游症狀)

`diagnostic_reclaim_progress_history: Array[float]  # 供收斂上限驗證` 量的是**判定值**(依 GDD 必須瞬間歸零),但 `reclaim_visual_convergence_max_frames` 約束的是**呈現層透明度**。記錄判定值歷史無法驗證這個上限。

根因是機制十三根本沒有一個獨立於 `reclaim_progress()` 的「呈現值」存在,機制十五自然無從取樣。F3 修好後,此欄位應改為取樣自繪節點每幀實際的 `modulate.a`。

`diagnostic_last_authority_change_frame`(交接延遲 ≤1 幀)量測對象正確,無須修改。

### F5 — 兩個確定性程式漏洞 · **BLOCKING** · 證據:邏輯漏洞已查證

```gdscript
func _input(event: InputEvent) -> void:
    if _arbitration_suspended:        # ← 有檢查
        return
    _frame_events.append(event)

func _process(_delta: float) -> void:
    if _frame_events.is_empty():      # ← 沒檢查 _arbitration_suspended
        return
    _state.arbitrate_frame(_frame_events)
    _frame_events.clear()
```

1. **`_process()` 沒有比照 `_input()` 檢查 `_arbitration_suspended`。** 若同影格內 `_input()` 已 append 事件之後 `_arbitration_suspended` 才變 true,`_process()` 仍會裁定那批事件。**`suspend_arbitration()` 這條路徑的時序完全在專案自己控制之下**,不依賴任何未驗證引擎行為 —— **這個競窗 100% 確定存在**,不是假設性風險。
2. **suspend / resume / `FOCUS_IN` / `FOCUS_OUT` 四個進出點,沒有任何一個呼叫 `_frame_events.clear()`。** 暫停開始時緩衝區內的殘留事件會一直躺著,直到下次 `_process()`(可能已是復焦後的影格)被誤裁定,與復焦當下的新事件混在一起處理。

兩者合起來違反 GDD 觸發點 (c)「失焦期間**完全不運算**」與機制九自己宣稱的「暫停期間被動裁定路徑不參與」。

**修法**:`_process()` 改為 `if _arbitration_suspended or _frame_events.is_empty(): return`;`suspend_arbitration()` 與 `NOTIFICATION_APPLICATION_FOCUS_OUT` 兩條進入暫停的路徑都須 `_frame_events.clear()`。

---

## 三、引擎專家自行發現的四項

| # | 問題 | 影響 TR | 證據 |
|---|---|---|---|
| **N1** | **`ActionClass`(NAVIGATION/CONFIRM/OTHER)如何從原始 `InputEvent` 判定,ADR 完全沒給機制。** 機制四 `classify()` 只做裝置**類別**分類,不做動作**語意**分類;但機制六明文要求「只有 NAVIGATION 類 `ui_*` 具主張權威資格」。這必然需要查 `InputMap`(如 `InputMap.event_is_action()`),而**該依賴不在 ADR 自列的「8 項核心依賴涵蓋率」表裡** —— 與 `classify()` 同等重要卻被漏列 | `-008` | 已查證 |
| **N2** | `NOTIFICATION_APPLICATION_FOCUS_IN`/`_OUT` 相對 `process_priority` 排序的時序完全未定義,且**不在現有 9 項 Verification Required 內**(第 2 項只問 `_input()` vs `_process()`,不問 `_notification()`)。若 FOCUS_IN 在部分節點 `_process()` 已跑完、部分未跑的中途觸發,`force_redraw_current_authority()` / `reapply_native_cursor_visibility()` 可能讓部分下游在同影格讀到新舊混合的視覺狀態。**建議新增為 Verification Required 第 10 項** | `-010` | 印象(參考庫零涵蓋) |
| **N3** | **`Input.mouse_mode` 是全域設定**(整個應用程式視窗),依「裝置權威 ≠ 滑鼠」切為 `MOUSE_MODE_HIDDEN`。但裝置權威是全域欄位,與玩家當下實際用滑鼠操作哪個表面無關 —— 手把持權威操作棋盤時,玩家想用滑鼠點一個**未登記**側欄(GDD AC-60 明文允許未登記表面用原生 hover),OS 游標仍全域隱藏,玩家看不到指標(側欄自己的 hover StyleBox 仍會畫出來,因為 `mouse_entered` 不依賴游標可見性)。**真實體感落差,ADR 未處理也未承認** | `-017` | 已查證(規則衝突) |
| **N4** | **下游更新是輪詢還是訊號推送未定案。** 機制六的四層優先序假設全部行為者每幀輪詢 `_process()`;但 66+ 條 AC 裡不少屬「狀態一變就要反映」,更自然的實作是同步發訊號。若採訊號推送,下游實際更新時機是「訊號發出當下」(在 −100 的呼叫堆疊內),不是它自己宣稱的 `process_priority`。**且訊號處理函式若回頭寫入 `_state` 會造成重入,ADR 無對應閘門** —— ADR-0001 對同類問題設了 `settlement_in_progress` | `-008`/`-019` | 已查證 |

---

## 四、跨 ADR 衝突與銜接缺口

**無阻塞級跨 ADR 衝突。**

### C6 —(新)單向交叉引用:ADR-0004 對「游標」零提及

ADR-0005 `Related Decisions` 宣稱「機制十一的甲/乙/丙分支與 ADR-0004 的存檔讀取路徑**直接交接**」,但實測 **ADR-0002/0003/0004 全部對「游標」/「cursor」零命中**(ADR-0001 有 6 處,但全是「游標即檢視是高頻查詢路徑」的驅動因素描述,不涉及游標系統介面)。

**嚴重度:低。** GDD Core Rules #7 明文把交接義務歸給「呼叫存檔系統讀取介面、且擁有游標目標所在表面的下游系統」(最可能是戰棋系統),**不是存檔系統** —— 兩者皆已宣稱「不理解遊戲實體語意」,讓任一方跨界判斷都違反雙方設計哲學。所以這不是矛盾,是單向引用。

**處置建議**:ADR-0004 不宜在被單方面宣稱交接的狀態下逕行 `Accepted`;至少在其 `Related Decisions` 補一句指回 ADR-0005 機制十一,說明義務歸屬在呼叫方而非存檔系統。

### 承接自第二輪、仍未解決

| # | 項目 | 狀態 |
|---|---|---|
| **C1** | `TOKEN_TIMEOUT_MS` 無人擁有 —— ADR-0002 委派給「存檔系統 ADR」,ADR-0004 機制六退回「該系統的職責」。而 ADR-0004 的分步遷移跨越「數個至數十個影格」,正是 ADR-0002 預測會誤判為逾時回收的情境 | **仍開**。建議解:由 ADR-0004 接下(只有它掌握遷移鏈深度上界) |
| **C3** | `Mutex` 條件已解未回傳 —— `TR-affinity-016` 是條件式需求,ADR-0004 已把條件判為「否」,但 ADR-0002 仍宣稱其無條件 `Mutex` 是「專案唯一執行緒安全義務」 | **仍開**。建議解:保留為縱深防禦,但明文交叉引用 ADR-0004 |
| C2 / C4 / C5 | 型別名統一 / `store_buffer()` 拍板 / 措辭修正 | ✅ 已於 `a56dd10` 修正,本輪覆核成立 |

### ADR 依賴順序

```
Foundation(無依賴):
  1. ADR-0001:戰棋查詢介面原子性契約(Proposed)
  2. ADR-0002:好感度數值池資料結構與並發契約(Proposed)
  3. ADR-0005:單一游標裝置權威輸入架構(Proposed;Depends On: None)

依賴 Foundation:
  4. ADR-0003:存檔系統序列化格式與型別安全(Proposed;requires ADR-0002)

Feature 層:
  5. ADR-0004:存檔系統原子寫入與遷移執行模型(Proposed;requires ADR-0003、ADR-0002)
```

**無依賴循環。** ADR-0005 明文 `Depends On: None`(機制二借用 ADR-0002 的 `AffinityTypes` **先例**,但那是可獨立驗證的引擎事實,不是對該 ADR 決策的依賴)—— 本輪查證此聲明成立。

**未解決的依賴(3 項,同一成因)**:ADR-0003→0002、ADR-0004→0003、ADR-0004→0002,全因被依賴方仍為 `Proposed`。

**5 份 ADR 無一 `Accepted`。** 依 `docs/CLAUDE.md`,引用 `Proposed` ADR 的 story 會被自動阻擋 —— 目前整條鏈沒有任何一段可進入實作。

---

## 五、引擎相容性交叉核對

**版本一致性**:5 份 ADR 皆針對 Godot 4.7.1,與 `VERSION.md` 一致,無過時版本參照。

**棄用 API 檢查**:對 `deprecated-apis.md` 全表逐列比對 ADR-0005 —— **零命中**。`Engine.get_process_frames()` 非 `OS.get_ticks_msec()`;`CursorTarget` 用靜態工廠 `make()`/`invalidated()`,結構性避開巢狀 `duplicate()`;機制四結構性不讀 `.device`,避開硬編碼裝置 ID。

### 引擎專家查核結果

| 項目 | 判定 | 證據等級 |
|---|---|---|
| **`@abstract` 語法** | ADR 機制八寫法(`@abstract` 獨立一行 + `class_name X extends RefCounted`,各方法各自 `@abstract` + 冒號 + `pass`)與 `current-best-practices.md` 第 41–49 行的範例**逐字格式一致** | **已查證** —— 可從「印象」升級。**殘留風險**:文件範例只有 `Array[Attack]` 一種回傳型別,ADR 用到 `bool`/`float`/`void` 三種,Day-1 spike 應三種各建一檔分別編譯 |
| **Verification Required #2**(`_input()` 全數完成後才進 `_process()`) | Godot 主迴圈自 3.x 以來的既定架構,4.6/4.7 變更無一涉及主迴圈排程順序。**但本專案任何參考文件都沒有直接陳述這一點** | **印象(信心度偏高)** —— 不算已查證。**ADR 標記的「高風險、待驗證」不應被拿掉**,照排定的 Day-1 幀精準 spike 執行 |
| **Agile Event Flushing 鍵字串** | 6 份參考文件完全沒有出現 "Agile" 或 "agile_event_flushing" 字樣。對 `input_devices/buffering/agile_event_flushing` 有中等信心印象 | **查不到**。機制七的 `has_setting()` 防衛是正確風控,**不建議改成直接信任推測鍵名** |
| **`focus_mode = FOCUS_NONE` 是否也關 hover 主題繪製** | `modules/ui.md` 明文確認雙焦點是兩條獨立管線;`focus_mode` 歷史上只管鍵盤/手把可否經 Tab/方向鍵取得焦點,滑鼠 hover 一直由 `mouse_entered`/`mouse_exited` 驅動 | **推論(信心度中高)** —— 非直接查證 `focus_mode` 對 hover StyleBox 繪製的程式碼行為。同意機制十四改為兩項條件,同意「不移除、只降級」 |

### 參考庫的結構性缺口(承第二輪,未處理)

- **`modules/` 全部 8 份仍標記 `Engine: Godot 4.6`**,而專案釘選 4.7.1 —— 落後一個大版本。
- **ADR-0005 的 8 項核心引擎依賴中 6 項在參考庫零命中**(`process_priority`、Autoload、`focus_mode`/`FOCUS_NONE`、`accept_event()`、`CanvasLayer`、`Input.mouse_mode`),另 2 項只在 4.6 文件裡。本輪再確認 N1 的 `InputMap.event_is_action()` 類依賴**連 ADR 自己的涵蓋率表都漏列**。
- **建議新增兩份模組文件**:`core-scripting.md`(序列化/雜湊/檔案 I/O/並發原語,承 ADR-0004 審查建議)、以及一份涵蓋 **Node 生命週期與輸入派發語意**的文件(`process_priority`、`_input`/`_unhandled_input`/`_gui_input` 派發鏈與 `accept_event()`、`_notification()` 時序、Autoload 語意、`CanvasLayer`、雙焦點下的 `focus_mode`)。

---

## 六、GDD 修訂旗標

**引擎現實層面無新旗標** —— 所有 GDD 假設與已查證的引擎行為一致。

但獨立重推發現兩處**設計文件內部**的張力(來源是 GDD 本身,不是 ADR,也不是引擎):

| GDD | 假設 | 張力 | 建議 |
|---|---|---|---|
| `cursor-highlight-state.md` | Core Rules #1「恰 3 個頂層欄位」+ Core Rules #3「累積**淨**位移,**不是**路徑總和」 | 淨位移依定義需要一個累積起點,而起點是狀態。兩條規則合起來在結構上必然需要第 4 份狀態;AC-1 的窮盡檢視會撞到這個。ADR-0005 只看到一半(把它記為條件式待決)| 明文承認累積起點為契約的一部分(例如新增可查詢的 `diagnostic_seed_position()`),或明文宣告它不算頂層欄位並給出理由 |
| `cursor-highlight-state.md` | Core Rules #5「鍵盤/手把持權威時原生滑鼠指標必須被隱藏」 vs Core Rules #7 / AC-60「未登記表面得使用原生 focus/hover,不受本系統管轄」 | `Input.mouse_mode` 是全域的,而裝置權威也是全域欄位 —— 未登記表面上玩家用滑鼠操作時看不到指標。兩條規則從未調和(引擎專家 N3)| 補一條規則(例如未登記表面 hover 時暫時恢復指標),或明文登記為已知落差 |

**未修改 `systems-index.md`** —— 這兩項不是「GDD 假設與已驗證引擎行為衝突」型的旗標(Phase 5b 的原始定義),而是設計文件的內部張力,是否要把該 GDD 標記為 `Needs Revision` 應由使用者裁決,不宜由審查 session 逕自改動一份已 Approved 的 GDD 狀態。

---

## 七、架構文件涵蓋度

`docs/architecture/architecture.md` **不存在** —— `/create-architecture` 尚未執行。目前架構知識分散於 5 份 ADR 與 `docs/registry/architecture.yaml`(55 項立場:10 state-ownership、8 interface contracts、20 API decisions、17 forbidden patterns)。

**Registry 本輪覈實**:`adr: ...adr-0005...` 共 **14 個條目**,與 ADR 自陳一致;`logic_in_cursor_autoload_shell` 確實已登記(非僅「候選」);`forbidden_patterns` 共 **17 項**,與 `technical-preferences.md` 的宣稱一致。累計 52 項具 ADR 來源 + 3 項 `adr: none`(專案級裁決)= **55**,宣稱成立。

`docs/consistency-failures.md` **仍不存在** —— 依 skill 規定不主動建立,故三輪審查的 C1~C6 只存在於各輪審查報告內,沒有跨輪的模式累積。

---

## 判定:**CONCERNS**

### FAIL 解除的理由

第二輪的**唯一硬阻塞**是「`cursor-highlight-state.md` 的 19 項需求零涵蓋,且它是 Foundation 層系統」。本輪獨立重推為 **11 完整 / 8 部分 / 0 缺口** —— 該成因確實消滅。三份 **Approved** GDD(好感度、存檔、游標,合計 73 項需求)僅剩 1 項 ❌(`TR-save-030` 雲端存檔同步,已知且被 ADR-0004 明文限縮)。無阻塞級跨 ADR 衝突;新增的 C6 為單向引用,低嚴重度。

### 判定標準的一致性說明(必讀)

戰棋移動與交戰系統仍有 **25 項 ❌ 且屬 Core 層**,字面上符合 skill 的 FAIL 條件(「Foundation/Core layer requirements uncovered」)。但第二輪在同樣有 27 項戰棋缺口的情況下仍判定「游標系統是本輪**唯一**的硬阻塞」—— 隱含理由是**該 GDD 尚未 Approved**(狀態為 Designed,連續零 BLOCKING-NOW 輪數 = 0,距 Approved 尚需連續兩輪)。本輪沿用同一標準以維持跨輪可比性。

> **⚠️ 若戰棋 GDD 在其演算法層 ADR 之前先達 Approved,判定會退回 FAIL。**

### 阻塞項(必須解決)

1. **ADR-0005 不得在 F1 / F5 修好前進 `Accepted`。** 這兩項不是措辭問題:
   - **F1** 是違反一條硬性 AC(AC-52)的定序錯誤,且修法需要**新增對下游系統的約束**(確認動作判讀不得掛 `_unhandled_input()`),不是加一個優先序數字。
   - **F5** 是兩個**不依賴任何引擎假設**的確定性程式漏洞,其中 `suspend_arbitration()` 路徑的競窗 100% 存在。

   加上 F2 / F3(需要 `MouseReclaimPolicy` 簽章本身修訂,且 F3 會動搖「三方法契約」的自陳)、F4(隨 F3 解決)、以及 N1~N4,**共 9 項待修訂**。

2. **5 份 ADR 全為 `Proposed`,無一 `Accepted`** —— 次級阻塞,擋住全部 `/create-stories`/`/dev-story`。ADR-0002 對 24 項 `TR-affinity-*` 已達零缺口,仍是最接近可 `Accepted` 的一份,但 **C3 落在它身上**。

3. **C1 / C3 仍開**,與第二輪相同。5 份 ADR 皆 `Proposed`,現在調和成本最低。

### 建議的 ADR 清單(最基礎優先)

1. **戰棋盤面演算法層**(可達格 / 威脅範圍 / 視線)—— `TR-tactical-002`~`-010`、`-019`~`-021`、`-037`~`-039`
   `/architecture-decision 戰棋盤面演算法層`
   Domain:Algorithms / Performance · Engine Risk:**LOW**(純格狀幾何,不觸物理伺服器)
2. **回合結構擁有權 + 缺席的 AI/遭遇系統** —— `TR-tactical-034`、`-041`
   **全專案無人認領回合結構**,而 `tactical-combat-system.md` Core Rules #9 明文要求敵方回合消費這些查詢
   Domain:Architecture / Gameplay · Engine Risk:LOW

### 低成本修補項(不需要新 ADR)

| # | 項目 | 狀態 |
|---|---|---|
| R1 | 3 項專案級 forbidden pattern 登記 | ✅ 已於 `a56dd10` 完成,本輪覈實 17 項 |
| R2 | C1~C6 銜接缺口調和 | 部分 — C2/C4/C5 ✅;**C1/C3/C6 待處理** |
| R3 | ADR-0003 補 Validation Criteria(payload 不得含 `Callable`/`Signal`/`RID` —— 非 `Object` 衍生類,不受 `allow_objects=false` 管控);新增 `modules/core-scripting.md` 與 Node 生命週期/輸入派發文件;ADR-0002 Post-Cutoff 欄措辭 | ❌ 待處理 |
| R4 | (新)ADR-0005 補 Verification Required:`_notification()` 時序(N2)、`InputMap` 動作語意分類依賴(N1)、座標空間 API 與單一根 Viewport 假設(F2);`@abstract` spike 擴為三種回傳型別各一檔 | ❌ 待處理 |

### Pre-gate 檢查(全數 ❌,與第二輪相同)

| 項目 | 狀態 | 補救 |
|---|---|---|
| `tests/unit/` | ❌ 不存在 | `/test-setup` |
| `tests/integration/` | ❌ 不存在 | `/test-setup` |
| `.github/workflows/tests.yml` | ❌ 不存在 | `/test-setup` |
| `design/accessibility-requirements.md` | ❌ 不存在 | `/ux-design` |
| `design/ux/interaction-patterns.md` | ❌ 不存在 | `/ux-design` |

**`/gate-check pre-production` 目前不可執行。** 另注意 `cursor-highlight-state.md` 登記的一項**孤兒義務**:運動無障礙需求(奪權門檻可調整性、瞄準輔助)先前口頭轉交至一個不存在的檔案,待 `design/ux/accessibility-requirements.md` 實際建立時一併處理。

### 重跑建議

ADR-0005 完成 F1~F5 + N1~N4 的修訂後重跑 `/architecture-review`(**須於全新 session**,不得與 `/architecture-decision` 同 session)。戰棋演算法層 ADR 完成後亦應重跑 —— 那一份會一次移動 25 項 ❌ 中的大部分,是目前投入產出比最高的單一動作。
