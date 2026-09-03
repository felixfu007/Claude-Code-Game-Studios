# ADR-0005 第五次修訂落地覆核(2026-09-03)

覆核者:godot-specialist(架構覆核角色)
範圍:**僅覆核 2026-09-03 第五次修訂本身是否正確落地**,不重新覆核 Story 007。
Story 007 的引擎覆核見 `docs/reviews/story-007-engine-review-2026-09-03.md`(CONCERNS,必修已關閉)。

## 判定總表

| # | 項目 | 判定 |
|---|---|---|
| 1 | Validation Criteria #16 (iv) 四條不變式斷言 | **CONCERNS** — 方向對;但「2/2/2/1/0」實測為 {2,2,2,2,1,0,0},且 (b)(d) 兩條**目前沒有能區分對錯的斷言** |
| 2 | 「六個公開入口」→「七個」兩份複本 | **PASS** — 我獨立實測為七,兩份皆已改,無第三份帶數字的複本 |
| 3 | `architecture.yaml` 入口清單補齊 + 結構完整性 | **PASS** — 計數前後皆 10/13/29/35,結構未破壞 |
| 4 | 機制十診斷計數語意裁決一致性 | **CONCERNS** — 裁決與改動句皆正確;但**三處「三個 `void` 入口皆 no-op」未改**,其一就在同一段落內 |
| 5 | `set_target()` `from_ui_action == true` 暫不實作 | **CONCERNS** — ADR 內乾淨、doc comment 指標正確;但方法**體內註解仍寫「尚未裁決」**,且 **yaml `write_access` 把該路徑列為正式寫入權限** |
| ★ | 有沒有同型的第三份複本 | 🔴 **有 —— 3 類 6 份**,其中 2 份與本次裁決直接相反 |

### 一句話結論

**這次修訂改的五處,沒有一處改錯,也沒有一處改壞別的地方** —— 第一次 `sed` 事故的殘留為零
(我逐一比對 `git diff`,五處改動皆為預期形狀,無重複插入、無誤傷)。
**問題全部是「該一起改而沒改到的第三份」** —— 而這正是本次修訂自己要根治的病。
🔴 **五項裡有三項的 CONCERNS 是同一個成因**:改了結論句,沒改支撐它的前提句或另一個載體裡的同一句。

**沒有 FAIL。沒有任何一項需要回退。** 六份複本全部是「補改」而非「改錯」,合計約 8 行文字。

⚠️ **本報告未修改任何檔案,未動 git。** 測試套件未重跑(本次為文件覆核;協調者已獨立跑過
345 條 / 0 errors / 1 既有失敗 / 0 orphans)。

---

## 1. Validation Criteria #16 (iv) —— 四條不變式斷言

**判定:CONCERNS**

**改動方向正確**(拿掉會過期的次數斷言、改成不變式),**但四條裡只有兩條今天真的會在實作寫錯時變紅**,
而作為佐證的括號數字「2/2/2/1/0」**經實測是錯的**。以下逐項。

### 1-A. 「次數隨外層入口而異(實測 2/2/2/1/0)」—— 🔴 不正確

我依 `src/ui/cursor/cursor_state.gd` 逐一推導每個外層入口在重入情境下的 `_reclaim.reset()` 總次數
(= 該入口自己的 reset + `_drain_pending_reseed()` 補做的那次)。全部 reset 呼叫點只有四處:
L.615(甲)、L.703(復焦入口自己)、L.830/832(`_write_target_internal` 的 if/elif)、L.1005(drain)。

| # | 外層入口 | 自己的 reset | drain 補做 | **總計** |
|---|---|---|---|---|
| 1 | `set_target()`(目標確有改變) | L.832 `TARGET_CHANGED` | ✔ | **2** |
| 2 | `handoff_after_mount()`(`UNCONDITIONAL`) | L.830 `SURFACE_HANDOFF` | ✔ | **2** |
| 3 | `handoff_before_unload()` | L.615 `SURFACE_HANDOFF` | ✔ | **2** |
| 4 | `mark_pending_reresolve()` | 無(`_mark_pending_reresolve_internal` L.849-883 不碰 `_reclaim`) | ✔ | **1** |
| 5 | `arbitrate_device_authority()` | Story 005 空縫,今日不發訊號 → 無法誘發重入 | ✘ | **0** |
| 6 | `apply_buffered_navigation()` | 同上,空縫 | ✘ | **0** |
| 7 | **`reseed_reclaim_on_focus_regained()`** | **L.703 `FOCUS_LOST_REGAINED`** | **✔** | **2** |

實測分佈是 **{2, 2, 2, 2, 1, 0, 0}** —— **四個 2、一個 1、兩個 0**,共七項。
ADR 寫的「2/2/2/1/0」是 **三個 2、一個 1、一個 0**,共五項。**兩處具體錯誤:**

1. 🔴 **漏掉第 7 項這個 2。** 成因可以指出來:第 7 項**不是**經由 `target_changed()` 誘發重入的。
   它自己的 L.703 `reset()` 會發 `MouseReclaimPolicy.reset_triggered`,而 `cursor_state.gd` L.283
   把該訊號**直接轉發**成自己的 `reclaim_reset_triggered` —— 訂閱**那一條**的下游一樣能同步回頭呼叫
   `resume_arbitration()`。**只盯著 `target_changed()` 找重入路徑,就會剛好漏掉這一個。**
2. ⚠️ **那兩個 0 是暫時的,不是性質。** 它們為 0 **只因為 Story 005 的兩個縫還沒實作**。
   `arbitrate_device_authority()` 的規格註解自己就寫明它將來要做
   「the AUTHORITY_TRANSFER (a) reset call」(L.386)與「the VETOED_SAME_FRAME (d) reset call」(L.391)。
   **Story 005 一落地,這兩個 0 就會變。**

📌 **這不影響裁決方向,反而加強它。** 本項的結論是「不要斷言次數,因為次數會過期」,
而這串數字**在寫下的當天就已經不準,且其中兩個註定會再變** —— 正是該結論的最佳佐證。
**但它是以「實測」名義寫進 ADR 的手抄數字**,依本專案 (A) 級定義(必須執行專案自己的程式碼、
且文件須附上實際執行的檔案路徑),它沒有附任何 spike 或測試檔路徑,**現況應降為 (C)**。
**建議:刪掉這串數字,或改寫成不帶數字的理由**(例如「次數取決於外層入口自身是否也重置,
以及該入口是否已實作 —— 兩者都會變」)。留著它就是在剛修好的地方**種下下一個手抄複本**。

### 1-B. 四條斷言逐條:哪幾條真的會變紅

前提:`tests/unit/cursor/write_read_interface_test.gd` 以 `_RecordingReclaimPolicy`
(L.55,`extends MouseReclaimPolicy`)側錄,`triggers()`(L.84)回傳觸發點序列。
現行測試為 `test_reentrant_reseed_request_is_deferred_not_discarded_and_drained_before_the_gate_clears`(L.1397-)。

| 條 | 內容 | 可測? | 判定 |
|---|---|---|---|
| **(a)** | 補做確實發生,且該次 `reset()` 帶 `FOCUS_LOST_REGAINED` | ✅ 是 | **已被斷言**(L.1450 `contains([FOCUS_LOST_REGAINED])`)。錯誤實作(丟棄請求)會變紅 |
| **(b)** | 補做發生在**清除閘門旗標之前** | ⚠️ **可測,但現行斷言測不到** | **見下方,最值得注意的一條** |
| **(c)** | `diagnostic_reentrant_rejection_count` 遞增 | ✅ 是 | **已被斷言**(L.1439-1446,本次新解鎖)。計數器為 `public var`(L.222),直接可讀 |
| **(d)** | 兩次 reset 觸發點不同,不得合併或互相取代 | ✅ 是 | 🔴 **今天沒有任何斷言在檢查它**,見下方 |

#### 🔴 (b) —— 現行斷言**在結構上無法區分正確與錯誤實作**

現行最接近的斷言是 L.1452-1455:斷言 `triggers` 的**最後一個元素**是 `FOCUS_LOST_REGAINED`,
失敗訊息寫「the drained reseed must be the LAST thing the holding entry does before clearing the latch」。

**它證明的是「在 `set_target()` 返回之前」,不是「在清旗標之前」。** 兩者中間隔著
L.524(drain)→ L.525(清旗標)→ L.526(return)這一小段。
**把 L.524 與 L.525 對調的錯誤實作(先清旗標、再 drain),會產生一模一樣的觀測結果**:
同樣的 `triggers` 陣列、同樣的順序、同樣的最後一個元素、同樣的計數值。**這條斷言不會變紅。**
—— 這正是派工單點名的 AC-32 那種「斷言的對象不對」。

**最接近的可測版本(確實能區分,建議寫成這樣)**:
在**「`reclaim_reset_triggered` 的處理函式」**內(不是 `target_changed` 的)同步呼叫任一個
**有回傳值**的公開閘門入口(如 `mark_pending_reresolve()`),斷言它回傳 `REJECTED_REENTRANT`。
理由:那個處理函式**正好在 drain 的 `reset()` 當下執行**(L.1005 發訊號、L.1006 才清 `_pending_reseed`,
而 `_mutation_in_progress` 要到外層 L.525 才落)。
- 正確實作(drain 在清旗標前)→ 旗標仍為真 → `REJECTED_REENTRANT` ✅
- 對調後的錯誤實作(先清旗標)→ 旗標已落 → 回傳 `APPLIED`/其他碼 → **變紅** ✅

**這是唯一能把 (b) 與 (a) 分開驗的觀測點**,且不需要暴露 `_mutation_in_progress`。
在補上之前,**(b) 應誠實記為「已明文要求、尚無有效斷言」**,不得因為那條 last-element 斷言的
失敗訊息提到了 latch 就當它已被覆蓋 —— **失敗訊息的措辭不是斷言的效力。**

#### 🔴 (d) —— 失效方向明確,但同樣無斷言

(d) 要防的錯誤實作是:**把兩次 reset 合併成一次**(例如 drain 內判斷「剛剛已經 reset 過了就跳過」,
或外層改成只保留 drain 那次)。

現行兩條 `triggers` 斷言分別是 `contains([FOCUS_LOST_REGAINED])` 與「最後一個是 `FOCUS_LOST_REGAINED`」。
**一個丟掉外層 `TARGET_CHANGED`、只留下 drain 那次的實作,兩條都會通過** ——
`contains` 不檢查長度,也沒有任何斷言要求 `TARGET_CHANGED` 必須在場。

**建議改為序列全等**:`assert_array(triggers).contains_exactly([TARGET_CHANGED, FOCUS_LOST_REGAINED])`。
這一改同時解決三件事:(d) 有了斷言、順序被釘死、**長度被釘死**。
本專案自己的測試證據覆核(`docs/reviews/story-007-test-evidence-review-2026-09-03.md` L.17)
才剛把「六個迴圈全部用 `contains_exactly` 釘死長度與內容」列為優點 —— **這裡用的正是較弱的那一種。**

#### 附帶:四條漏了一個上界

(d) 只要求「兩次觸發點不同」,**沒有任何一條設上界**。而 `_drain_pending_reseed()` 的註解
(L.996-1000)自己就在討論「drain 內的 `reset()` 會發訊號 → 下游可在這一刻再度把 `_pending_reseed` 設起」,
並說明「之後才清旗標」把它丟掉是刻意且正確的。**這是一條被想過、有推理、但無人斷言的性質** ——
若哪天改成先清旗標再 reset,就會多出額外的 reset,而 (a)~(d) 四條**沒有一條會變紅**。
改用上面的 `contains_exactly` 即可一併蓋掉,**不需要新增第五條**。

### 1-C. 原文想防的東西有沒有被涵蓋

原文「只被 reset 一次」出自**專家發現 D**,要防的是**累積位移被重複歸零**。
R6-10 之後「兩次」變成正確行為,該保護的字面形式已失效 ——
新四條把它換成「兩次都必須發生、順序正確、觸發點各異」,**方向上是對的替代品,沒有丟掉原意**。
問題不在設計,**在於四條裡有兩條(b)(d) 目前沒有能區分對錯的斷言在背書。**

---

## 2. 「六個會發訊號的公開入口」→「七個」

**判定:PASS**

### 我自己重數的結果(未採信派工單的數字)

`src/ui/cursor/cursor_state.gd` 的公開閘門入口共 **7 個**,每一個都呼叫
`_drain_pending_reseed()` **恰一次**,且**都在清除 `_mutation_in_progress` 之前**:

| # | 入口(定義行) | 設旗標 | `_drain_pending_reseed()` | 清旗標 |
|---|---|---|---|---|
| 1 | `arbitrate_device_authority()` L.331 | L.335 | **L.403** | L.404 |
| 2 | `apply_buffered_navigation()` L.423 | L.427 | **L.444** | L.445 |
| 3 | `set_target()` L.494 | L.497 | **L.524** | L.525 |
| 4 | `mark_pending_reresolve()` L.558 | L.561 | **L.567** | L.568 |
| 5 | `handoff_before_unload()` L.589 | L.592 | **L.617** | L.618 |
| 6 | `handoff_after_mount()` L.644 | L.647 | **L.662** | L.663 |
| 7 | `reseed_reclaim_on_focus_regained()` L.689 | L.697 | **L.709** | L.710 |

`grep -n "_drain_pending_reseed" src/ui/cursor/cursor_state.gd` 的呼叫點恰為
403 / 444 / 524 / 567 / 617 / 662 / 709 —— **七個,無第八個,無重複**。

🔴 **我另外查了派工單沒要求的一項:提早返回路徑。**「恰一次」若有 early return 繞過 drain
就會破功。逐一檢查七個入口在「設旗標」與「清旗標」之間的 `return` 陳述:**七個全部沒有**。
唯一的 `return` 都在設旗標**之前**(重入拒絕路徑),那條路徑本來就不該 drain。
因此「各恰一次」不只是靜態呼叫點數目正確,**在所有執行路徑上都成立**。

### 兩份複本都已更正

- **Validation Criteria #13 (iv)** —— L.1632,已改為「**七個**公開入口」。
- **Key Interfaces 私有路徑註解 `(6) _drain_pending_reseed()`** —— L.1408,已改為「**七個公開入口**」。

### 第三份複本查核:沒有第三份帶數字的複本

`grep -rn "_drain_pending_reseed" docs/ src/ tests/ design/ production/` 命中的
ADR 內位置有四處,逐一判定:

- **L.45**(第四次修訂摘要)—— 只說私有路徑 4→6,**不涉及入口數**。非複本。
- **L.905**(Key Interfaces 的 R6-10 說明)—— 寫「由當前正在執行的公開入口在清除
  `_mutation_in_progress` **之前**經 `_drain_pending_reseed()` 補做一次」。
  🔴 **這是第三處描述同一義務的地方,但它刻意不寫數字**(說的是「當前正在執行的公開入口」,
  是變數不是常數)。**因此它不會漂移** —— 這反而是本 ADR 裡寫得最耐久的一處。**非複本。**
- **L.943**(私有路徑表)—— 講的是私有路徑六條,不是公開入口七個。非複本。
- **L.1408 / L.1632** —— 即上述兩份,皆已改。

### 一項附帶查核:更正後的段落自身是否自洽

L.1408 的標題已改成「七個」,但其下的括號列舉仍只點名六個方法
(`set_target` / `apply_buffered_navigation` / `handoff_after_mount` /
`arbitrate_device_authority` / `mark_pending_reresolve` / `handoff_before_unload`)。
**這不是漏改** —— 緊接的下一句明文寫「`reseed_reclaim_on_focus_regained()` 自己不需要,
但為避免『漏了一個』的疏漏,**七個一起做**」(L.1415-1416)。
六名列舉是「會誘發下游重入者」的子集,第七個另行交代其理由。**段落自洽,無矛盾。**

---

## 3. `docs/registry/architecture.yaml` 入口清單與結構完整性

**判定:PASS**

### 條目計數:修訂前後完全相同

| | state | interface | api | forbidden |
|---|---|---|---|---|
| HEAD(修訂前) | 10 | 13 | 29 | 35 |
| 工作區(修訂後) | 10 | 13 | 29 | 35 |

與派工單預期一致。**本次為純就地修訂,零新增、零刪除。**

### 結構完整性:未破壞

- `git diff` 僅動 `forbidden_patterns` 節內 `public_cursor_write_entry_calling_another`
  的 `description:` 折疊區塊(L.1929-1939),**+4 行 / 改 1 行**,未觸及任何鍵名。
- **全檔零 tab**(`grep -Pn "\t"` 無命中)。
- **縮排直方圖乾淨**:0 / 2 / 4 / 6 四級,加上兩行 indent-36 —— 後者經比對 HEAD
  為 **既有註解行(L.627-628),與本次修訂無關**。
- 新增的四行皆為 **6 空格縮排**,與該折疊區塊既有內容行同級 —— 折疊純量語法正確
  (若縮排更深會被 YAML 當「more-indented line」保留字面換行,雖不報錯但語意改變;
  此處沒有發生)。
- 新增文字**不含冒號**,括號配對平衡(開於 `(arbitrate_device_authority`,
  閉於 `reseed_reclaim_on_focus_regained)`)。
- 五個頂層鍵(`state_ownership` / `interfaces` / `performance_budgets` /
  `api_decisions` / `forbidden_patterns`)全部健在。

⚠️ **一項誠實揭露:本機無 YAML 解析器可用,故「能載入」未經真正的 parser 驗證。**
`python` 是 Microsoft Store 的假捷徑(執行即跳安裝提示)、`node` 不存在、
perl 無任何 YAML 模組。上述為**逐項結構檢查**,不是 parser 通過。
依本專案 (A)/(B)/(C) 三分法,**此項為 (C) 級推理,不得當成「已驗證可載入」引用**。
不過改動形狀極小且不碰鍵名,結構風險實質為低。

### 附帶發現:這一項修的正是「同檔兩份複本」

同一份 YAML 的 **L.392**(`interfaces` 節 `cursor_target_write` 的 `signal_signature`)
早已寫著 `PUBLIC GATED ENTRIES (7): …` 並完整列出七個名字,
而 **L.1929** 的 forbidden 描述停在五個 —— **同一檔案內兩份清單各說各話**。
本次把後者補齊,兩者現已一致。**這是本次修訂真正修掉的東西,值得記一筆。**

---

## 4. 機制十:重入重新播種被延後補做時診斷計數仍遞增

**判定:CONCERNS**

**裁決本身正確,改動的那一句也正確。問題全部在「這次沒去動的句子」** ——
而它們正是把三個 `void` 入口講成行為一致的那幾句。派工單擔心的事**確實發生了**,共三處。

### 4-A. 先確認改對的部分

改動把觸發條件由「三者在 **no-op 時**應遞增」改為「三者在**偵測到重入時**應遞增」。
**這句改對了,而且對三者皆為真** —— 實測三個入口的重入分支都無條件遞增:

| 入口 | 重入分支 | 遞增行 |
|---|---|---|
| `arbitrate_device_authority()` | L.332-334 | **L.333** |
| `apply_buffered_navigation()` | L.424-426 | **L.425** |
| `reseed_reclaim_on_focus_regained()` | L.690-696 | **L.695**(另 L.694 設 `_pending_reseed`) |

裁決的實質理由也成立:**這確實是唯一能證明第三個入口有閘門的觀測點。**
另外兩個入口的閘門有各自的專屬測試可證(重入時目標未被寫入),而復焦入口回傳 `void`、
重入時又**不再** no-op(請求會被補做),因此「有沒有被閘門擋下」在外部**只剩計數器看得見**。
不遞增等於該閘門零測試證據 —— 理由能站住。

### 4-B. 🔴 殘留矛盾(一):同一段落內,前提句沒改

L.934 這一段的**第三句**原封未動:

> 三者的閘門語意是「偵測到重入即整段 no-op、**不寫任何欄位**、不發任何訊號」。

而**同一段落再往下兩句**就是裁決:「R6-10 之後 `reseed_reclaim_on_focus_regained()` 重入時**已不再 no-op**」。
**同一段話前面說三者都是整段 no-op,後面說其中一個不是。**

而且前提句在事實上就是錯的,不只是措辭不一致 —— 「不寫任何欄位」對第三個入口**不成立**:
重入分支 **L.694 寫 `_pending_reseed = true`**、**L.695 寫計數器**。前者是貨真價實的狀態欄位,
正是 R6-10 的整個重點。

📌 **成因可以指出來:這次修訂改的是「條件子句」,沒改「前提子句」。**
「在 no-op 時 → 在偵測到重入時」修好了觸發條件,但那句話**為什麼**原本寫 no-op 的根據
(前提句宣告三者皆為整段 no-op)還留在原地。**這就是本次修訂要根治的「只改一半」,
在它自己修的那一段裡又發生了一次。**

⚠️ 減災因素:讀完整段的人會被裁決文字糾正。但該段是全 ADR 最長的段落之一,
而本專案自己記載的失效模式正是「照捷徑查完就停下的人」。

**建議修法**(不改決策,只改事實):把前提句改成分開敘述 ——
「`arbitrate_device_authority()` 與 `apply_buffered_navigation()` 兩者的閘門語意是整段 no-op、
不寫任何欄位、不發任何訊號;`reseed_reclaim_on_focus_regained()` 自 R6-10 起改為記下
`_pending_reseed` 由持閘門者補做,**不是** no-op。三者共通的只有:偵測到重入即遞增診斷計數。」

### 4-C. 🔴 殘留矛盾(二):八行之下的表格,第二份複本沒改

L.942 的「公開入口 / 私有路徑」表,公開入口列的最後一格:

> **是**。進入設旗標、離開清旗標,重入回傳 `REJECTED_REENTRANT`(**三個 `void` 入口則為 no-op + 診斷計數**)

**同樣把三者一律講成 no-op,同樣未改,而且距離 4-B 只有八行。**
這是與「六個/七個」**完全同型**的第二份複本 —— 只是這一次沒被發現。
表格比散文更容易被當成速查來源,**風險不低於 4-B。**

### 4-D. 🔴 殘留矛盾(三):`architecture.yaml` 裡從未被後續紀錄取代的那一句

`docs/registry/architecture.yaml` L.434-437(`interfaces` 節 `cursor_target_write` 的 `reason:` 欄):

> (2) **The two void-returning entries** CANNOT return REJECTED_REENTRANT; their gate
> semantics are **"no-op, no field write, no signal"**, plus an increment of a QA-only
> diagnostic_reentrant_rejection_count … **The three value-returning entries** are unchanged.

該欄位是**按日期堆疊的變更紀錄**,這段標記為 `REVISED 2026-08-19b`,所以「舊的敘述留在原地」
本身合理。**但要成立,後續紀錄必須把它更新掉 —— 而這一點只做了一半:**

- 入口總數**有**被更新:L.449 的 `REVISED 2026-08-19c` 第 (1) 點明寫
  「SEVEN public entries are now gated, not five」。✅
- **`void` 入口的閘門語意從未被更新。** 全檔唯一一次陳述就是上面那句 `no-op, no field write, no signal`,
  而 R6-10(2026-08-21)在同一欄位裡**只以「`_drain_pending_reseed()` 成為第六條私有路徑」的形式出現**
  (L.460-461),**從未說第三個入口的重入行為由 no-op 改成延後補做。**

亦即在被本專案指定為**架構立場權威來源**的那份檔案裡,`void` 入口的閘門語意**兩個數字與一項行為都是舊的**
(兩個→三個、`no-op` → 其中一個改為延後補做),而且**不像 L.433 的 FIVE 那樣有後續紀錄接手**。

⚠️ **本次修訂動了這個檔案**(補 `public_cursor_write_entry_calling_another` 的入口清單),
**但沒有動這一處** —— 兩處相距約 1500 行、分屬 `interfaces` 與 `forbidden_patterns` 兩節,
是很自然的漏法,不是疏忽級的錯誤。**但結果是:登記表現在對「七個入口」講對了,對「void 入口怎麼拒絕」仍講錯。**

### 4-E. 反向查核:程式碼側**沒有**這個問題

值得記一筆,因為它證明矛盾只在文件層:

- `arbitrate_device_authority()` 的 doc comment(L.326-327)寫
  「On reentry it is a **total no-op** and increments …」—— **對該入口為真**,正確。
- `apply_buffered_navigation()` 的 doc comment(L.421-422)寫「**same as** `arbitrate_device_authority`」
  —— 正確。
- `reseed_reclaim_on_focus_regained()` 的 doc comment(L.684-686)**單獨**描述延後補做語意
  (「…records `_pending_reseed`, and whichever entry currently holds the latch replays it via
  `_drain_pending_reseed()` before clearing」)—— 正確,**沒有跟另外兩個混講**。
- 計數器宣告處(L.217-222)指向
  「ADR-0005 機制十's "三個回傳 `void` 的入口如何表達拒絕" paragraph」
  —— **有指出記錄位置,符合本專案「不得寫『已裁決』而不指出記錄在哪」的規定。** ✅

**實作者照程式碼寫不會錯;照 ADR 或登記表寫會錯。**

---

## 5. `set_target()` 的 `from_ui_action == true` 明文暫不實作

**判定:CONCERNS**

裁決本身完整、期限明確,ADR 內文乾淨;**但另外兩份複本沒跟上,其中一份在登記表裡直接說反話。**

### 5-(a) ADR 內部:✅ 乾淨,無第二處描述 `true` 的行為

`grep -n "from_ui_action"` 在 ADR 內共 6 處,逐一判定:

| 行 | 內容 | 判定 |
|---|---|---|
| **1041** | **本次修訂的那一處** —— 「只在 `from_ui_action == true` 時連動裝置權威轉移」+ 裁決全文 | ✅ 已改 |
| 876 / 1388 | 簽章列(`func set_target(target, from_ui_action) -> SetTargetResult`) | ✅ 只是簽章,不宣稱行為 |
| 1020 | 「`from_ui_action` 對乙分支與丙分支**同樣傳 `false`**」 | ✅ 不衝突 |
| 1577 | TR-cursor-012 追溯列,僅列簽章 | ✅ |
| 1580 | TR-cursor-015 追溯列:「三分支 `from_ui_action` 一律 `false`,裝置權威不隨交接重置」 | ✅ 不衝突(只講 `false` 側) |

我另外用**不含該 token** 的說法再搜一次(`連動裝置權威` / `權威轉移` / `轉移裝置權威` / `AC-39`),
避免「用手上的已知字串去搜」的盲點 —— **命中的 7 行中,只有 L.1041 在講 `set_target()` 的權威轉移**,
其餘(L.388、752、1091、1206、1583)講的是別的機制。

**結論:ADR 內部沒有第二份描述 `true` 行為的複本。這一項在 ADR 層面是 PASS。**

### 5-(b) 程式碼 doc comment:✅ 指向正確 —— 但同一個方法裡留了一份說反話的舊註解

#### 指標本身正確

公開 doc comment(L.462-475,本次修訂改寫)寫:

> 🔴 **Ruled 2026-09-03: explicitly deferred, NOT implemented.** The ruling and its full
> reasoning are recorded in ADR-0005 機制十一, in the paragraph beginning
> `**裝置權威不隨目標交接重置**` — go read it there rather than trusting this summary.

**逐項核對,三個座標全部命中:**
- 機制十一 的標題確實在 **ADR L.984**(`### 機制十一:跨畫面交接生命週期(甲/乙/丙三分支)`),
  而 L.1041 落在該節內。✅
- 該段落確實以 `**裝置權威不隨目標交接重置**` 起始。✅
- 該段落確實載有裁決全文與 Story 005 期限。✅

**符合本專案「不得寫『已裁決』而不指出記錄在哪」的規定** —— 而且它指的是**段落起始字串**而非行號,
這比行號更耐改(行號會隨插入位移,本 ADR 已 1600+ 行且持續增修)。**這一點做得對,值得沿用。**

#### 🔴 但方法體內的舊註解沒改,而且它說「還沒裁決」

同一個方法的**體內註解 L.505-522**(本次修訂**未動**)仍寫著:

> 🔴 The TRUE case is NOT implemented, **because ADR-0005 does not define it.** …
> **Raised as an open question for the architecture owner; do not close it by guessing.**

**與上方 doc comment 直接牴觸的有兩點:**
1. 「**ADR-0005 does not define it**」 —— 現在 ADR **有**定義了(定義為「暫不實作、保留參數、
   Story 005 完成時必須定案」)。
2. 「**Raised as an open question for the architecture owner**」 —— 架構擁有者**已經裁決了**,
   就在同一天。這句話現在是在說一個已經發生的事還沒發生。

而且它**完全沒有提到 Story 005 的期限**,也沒提到「參數是刻意保留的」——
**裁決最重要的兩個可執行部分,在最可能被實作者讀到的那個位置是缺的。**

📌 **成因與 4-B 完全相同,只是換了檔案**:本次修訂把 doc comment 的
「Full reasoning in **this method's body**」改成指向 ADR —— **指標搬走了,被指向的舊內容卻留在原地**,
從「延伸說明」變成一份沒人維護的孤兒複本,而且它就在讀者往下捲 30 行必然會看到的地方。

⚠️ **嚴重度是本報告四處同型複本中最低的一處,理由要講清楚**:它**朝安全方向失效**
(「do not close it by guessing」會擋下亂猜的人,不會誘導錯誤實作)。
但它會讓讀者以為這件事還懸著、還沒有人管、也沒有期限 —— **而期限正是這次裁決的重點。**

**建議修法**:體內註解只保留「為什麼今天無法實作」的三項技術推理(那部分仍然正確且有價值),
把最後兩句換成與 doc comment 一致的指標,並補上 Story 005 期限。

### 5-(c) 🔴 `architecture.yaml` L.169:登記表把「暫不實作」的路徑列為正式寫入權限

`docs/registry/architecture.yaml` 的 `state_ownership` 節,`cursor_device_authority` 條目(L.164-):

> `write_access: cursor-highlight-state-only (only via arbitrate_frame, or set_target with from_ui_action == true)`

**這一行有兩處錯,而且它是「誰可以寫這個欄位」的權威宣告 —— 是 state 條目裡分量最重的欄位。**

1. 🔴 **`set_target with from_ui_action == true` 被列為裝置權威的合法寫入路徑** ——
   而 2026-09-03 裁決明訂該路徑**今天不存在**(`true` 與 `false` 行為完全相同,
   `set_target()` 全程不寫 `_device_authority`,實測 L.494-526 無任何 `_device_authority` 寫入)。
   **登記表現在承諾了一條不存在的寫入路徑。** 下游若照登記表推理「權威可能被 `set_target()` 改掉」,
   會為一個不會發生的情況寫防禦碼;反過來,Story 005 若真的實作它,登記表看起來卻像早就核准過了。
2. ⚠️ **`arbitrate_frame` 這個方法早就不存在** —— **同一個檔案自己的 L.430 就寫著**
   「(1) `arbitrate_frame()` **NO LONGER EXISTS.** It is split into `arbitrate_device_authority()`
   and `apply_buffered_navigation()`」(2026-08-19b round-4 R4-1)。
   **同一份 YAML,一處說它不存在,另一處把它列為唯一寫入路徑之一。**
   這一項與本次修訂無關,是**既有**漂移,但由本次查核順帶抓到。

📌 **本次修訂動了這個檔案卻沒動這一行,是可以理解的**:改的是 `forbidden_patterns` 節(L.1929),
這一行在 `state_ownership` 節(L.169),相距 1760 行。**但結果是登記表現在對這項裁決講的是反話。**

**這是本報告認為本次修訂最該補做的一項** —— 理由不是它最難修(改一行),
而是 `architecture.yaml` 被本專案明文指定為架構立場的**權威來源**,
其餘文件有疑義時會回頭查它,**而它在這一格是錯的。**

---

## ★ 同型第三份複本主動搜尋

**回答:有,而且不只一份 —— 找到 3 類、共 6 份未被發現的同型複本。**
其中 **2 份直接與本次兩項裁決講反話**,1 份是「宣告六個、只列出四個」的枚舉短缺。

搜尋方式:不用手上的已知字串,改以**實體名**掃(方法名、欄位名、`no-op`、`from_ui_action`、
入口/私有路徑的中英文數量詞),範圍涵蓋 `docs/` `design/` `src/` `tests/` `production/`
四個載體(ADR 內文 / Key Interfaces 註解區塊 / Validation Criteria / `architecture.yaml`)。

### 類別一:「三個 `void` 入口皆為整段 no-op」—— 3 份,全部未改 🔴

R6-10 之後這句話對第三個入口已不成立,而它在三處各有一份手抄副本:

| # | 位置 | 逐字 | 狀態 |
|---|---|---|---|
| 1 | **ADR L.934**(機制十,**與裁決同一段落**) | 「三者的閘門語意是『偵測到重入即整段 no-op、不寫任何欄位、不發任何訊號』」 | 🔴 未改,**兩句之後就被自己的裁決推翻** |
| 2 | **ADR L.942**(公開/私有路徑表) | 「(三個 `void` 入口則為 no-op + 診斷計數)」 | 🔴 未改,距 #1 僅八行 |
| 3 | **`architecture.yaml` L.434-437**(`interfaces` / `cursor_target_write` 的 `reason:`) | 「**The two** void-returning entries … gate semantics are **"no-op, no field write, no signal"**」 | 🔴 未改。入口總數有被 L.449 的 `2026-08-19c` 紀錄更新為 SEVEN,**但 `void` 入口的閘門語意從未被任何後續紀錄接手** |

詳見第 4 節。**三份都朝同一個危險方向錯**:讓人以為三個 `void` 入口行為一致。

### 類別二:`from_ui_action == true` —— 2 份,與 2026-09-03 裁決相反 🔴

| # | 位置 | 逐字 | 為何是反話 |
|---|---|---|---|
| 4 | **`cursor_state.gd` L.505-522**(`set_target()` **方法體內**註解) | 「ADR-0005 **does not define it** … **Raised as an open question for the architecture owner**」 | ADR 現在**有**定義(暫不實作 + Story 005 期限),架構擁有者**已裁決**。**本次只改了方法上方的 doc comment(L.462-475),體內這份沒改** |
| 5 | **`architecture.yaml` L.169**(`state_ownership` / `cursor_device_authority` 的 **`write_access`**) | 「only via **arbitrate_frame**, or **set_target with from_ui_action == true**」 | ①把裁決為「今天不存在」的路徑列為**正式寫入權限**;②`arbitrate_frame` 早已刪除 —— **同一份 YAML 的 L.430 自己就寫著它 NO LONGER EXISTS** |

詳見第 5 節。**#5 是本報告認為最該補的一項** —— `architecture.yaml` 被明文指定為架構立場的
權威來源,而 `write_access` 是 state 條目裡分量最重的欄位。

### 類別三:枚舉短缺 —— 1 份(既有缺陷,順帶抓到)⚠️

| # | 位置 | 問題 |
|---|---|---|
| 6 | **`architecture.yaml` L.464-467** | 逐字寫「**The six are:**」,接著**只列出四個**:`_write_target_internal` / `_mark_pending_reresolve_internal` / `_validate_target_writable` / `_safe_mouse_position`。**漏掉 `_target_changed_from()` 與 `_drain_pending_reseed()`** —— 而這兩個正是同一段話上方剛剛宣告「由四增為六」時新增的那兩個 |

🔴 **這一份的反諷值得記下來**:同一段話的前四行寫著
「Step 5.5 flagged this as a count that NECESSARILY changes; **at least 7 places declared "four"**」
—— **那個為了修正「到處寫著四」而寫的段落,自己列出了四個。**

⚠️ 與本次修訂**無關**(2026-08-21 就存在),但同型、同檔、同一個事實,故列入。

### 我查了但**乾淨**的部分(逐項列出,讓「沒查到」與「沒查」可以區分)

| 事實 | 掃過的位置 | 結果 |
|---|---|---|
| **公開入口 = 7** | ADR L.932 / 942 / 1288 / 1385 / 1410 / 1632;yaml L.392 / 449 / 1929(本次改) / 1953 / 1958;`cursor_state.gd` L.208 / 290 / 983;測試 L.1192 | ✅ **全部一致為七**。唯一的 `FIVE`(yaml L.433)是**有日期的歷史紀錄**,且被 L.449 明文接手,不算漂移 |
| **私有路徑 = 6** | ADR L.943 / 1393 / 1632;yaml L.459 / 1953 / 1959;原始碼實測 6 個 | ✅ **數字全部一致為六**(只有 #6 的**枚舉**短缺) |
| **計數器語意** | ADR L.934(裁決);`cursor_state.gd` L.217-222;測試 L.1411-1414 | ✅ **三處都指向「機制十『三個回傳 `void` 的入口如何表達拒絕』段落」,無人自行複述語意** —— 這是全案處理得最好的一處,**應作為往後的範本**。(yaml L.436 的例外已列為 #3) |
| `from_ui_action` 在 **ADR 內** | L.876 / 1020 / 1041 / 1388 / 1577 / 1580,另以 `連動裝置權威`/`權威轉移`/`AC-39` 反查 | ✅ **只有 L.1041 宣稱 `true` 的行為,且已改**。ADR 內部無第二份 |
| `design/gdd/` 是否有副本 | 全目錄掃上述全部樣式 | ✅ 零命中 |
| `control-manifest.md` L.105「七個入口」 | 讀上下文 | ✅ **假警報** —— 該行在「好感度數值池(**ADR-0002**)」節下,指的是別的系統的入口,與本案無關 |

### 這個模式為什麼一直復發 —— 一項可執行的觀察

本次三類複本的成因**完全相同,且都不是粗心**:

> **修訂改的是「結論句」,沒改「支撐該結論的前提句」,也沒改「另一個載體裡的同一句」。**

- 類別一:改了「在 no-op 時 → 偵測到重入時」(結論),沒改「三者皆為整段 no-op」(前提)。
- 類別二:改了方法上方的 doc comment(結論),沒改方法體內的推理(前提);
  而且 doc comment 原本寫「Full reasoning in **this method's body**」——
  **指標搬去指 ADR 之後,被指向的那份舊內容就變成孤兒。**

📌 **唯一在本案中沒有復發的地方,是計數器語意** ——
因為那三處**都沒有複述語意,只寫「去 ADR 機制十某某段落讀」**。
**同一份文件裡,有複述的三類全部漂移了,沒複述的那一類一份都沒漂。**
這不是巧合,而是**已經在本案中被對照組驗證過的做法**:
凡跨載體重複的事實,**寫指標、不寫副本**;真的需要摘要時,一併寫上「以那裡為準,不要相信這份摘要」
—— 本次 `set_target()` 的 doc comment(L.462-475)正是這樣寫的,而它是全案指標品質最高的一處。
