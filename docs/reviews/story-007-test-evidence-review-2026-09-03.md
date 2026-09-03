# Story 007 測試證據覆核(qa-lead)— 2026-09-03

> **覆核者**:qa-lead(測試證據涵蓋與品質)
> **受審對象**:`tests/unit/cursor/write_read_interface_test.gd`、`tests/unit/cursor/state_host_test.gd` 的 AC-1 排除名單改動
> **不在本覆核範圍**:`src/ui/cursor/cursor_state.gd` 正式程式碼的引擎/ADR 合規(由另一位覆核者負責)
> **狀態**:✅ 完成(2026-09-03)

## 整體判定

# 🟡 INCOMPLETE

**不是 MISSING** —— 證據存在且品質高於本專案既往水準;
**也還不到 ADEQUATE** —— 有兩個便宜的缺口,其中一個涵蓋的正好是**今天正式建置實際跑的那個組態**。

**先講好的部分,因為這會影響你怎麼看下面的缺口。**
本檔 36 條、0 空殼、0 orphans、實跑全綠。它**主動封死了本專案兩種既往失效模式**:
零斷言迴圈(六個迴圈全部用 `contains_exactly` 釘死長度與內容,第 1 節)、
空路徑假性通過(`reclaim_progress()` 的轉發測試刻意只用非零值,第 2 節)。
十條 AC 裡凡宣稱「部分」的都附了**明確的界線說明**,而且我逐條複查後認定**界線都守住了**。
**撰寫者沒有在任何一處假裝證明了他沒證明的東西。**

### 阻擋結案的兩項(都便宜,合計約一小時)

| | 缺口 | 為什麼阻擋 |
|---|---|---|
| **B-1** | `_reclaim` 為 `null` 時的六個守衛零測試(第 8 節 G-1) | **`null` 是今天正式建置的實際組態。** 唯一被測過的是一個 getter。守衛若失效,後果是「整個游標系統永久且靜默地死掉」——這是程式碼自己寫下的描述,不是我的推測 |
| **B-2** | 甲分支「沒有有效目標時仍須無條件重播種」零測試(第 8 節 G-2) | 把 reset 搬進 `if result == APPLIED` 裡,**36 條測試全綠**,而 GDD Core Rules #7 F2-2 強制的歸零靜默消失 |

### 應更正的三處文字(不是測試問題,是記述問題)

| | 位置 | 問題 |
|---|---|---|
| **T-1** | `write_read_interface_test.gd` 第 1562 行 | 「Story 005 落地時這條會轉紅」**不成立**。它永遠不會轉紅。逐項論證見第 4.5 節,**替代措辭已備好** |
| **T-2** | AC-25 的涵蓋標記 | 應與 AC-29 同標為**部分**。依據是 AC 原文第 66 行的「或任一掛載的 UI 表面渲染」子句,見第 4.3 節 |
| **T-3** | `state_host_test.gd` 第 144–145、151–154 行 | 兩句排除理由與事實不符。逐字引用與替代寫法見第 5 節 |

🔴 **T-1 的優先度高於兩個 B 項。** 缺口本身不危險,**宣稱自己會守住卻不會守住的東西才危險** ——
它會讓下一個人停止擔心。本專案已為這種形狀付過代價。

### 不阻擋、但應登記在案的五項

G-3(閘門中止路徑落旗,與引擎覆核者的 CONCERNS 同一處)、G-4(乙分支從未跨表面測過)、
G-5(`INVALID_SURFACE_TYPE` 整個成員零涵蓋)、G-6(只在 release 生效的分支 debug 測不到)、
G-7(`arbitrate` 的 provider 失效路徑零涵蓋)。
另:AC-32 登記為 **UNCOVERED**、AC-54 登記為**延後**(ADVISORY 證據不存在且目前不可能存在)。

📌 **本覆核刻意不開更多項。** 本專案有明文的流程劑量上限,而上面兩條測試 + 三處文字更正
是「能改變結果的最小集合」。G-3~G-7 逐條都有價值,但**它們該進 backlog,不該擋這張。**

## 1. 零斷言迴圈

**判定:未發現 Story 004 那種零斷言迴圈。全檔 6 個迴圈逐個查過。**

| 行號 | 迴圈 | 斷言在迴圈內? | 迴圈可能跑零次? | 判定 |
|---|---|---|---|---|
| 415 | `for _i in range(3)` | 否(收集,外部斷言) | 否(字面常數) | 安全 |
| 457 | `for _i in range(4)` | 否 | 否 | 安全 |
| 499 | `for _i in range(3)` | 否 | 否 | 安全 |
| 1344 | `for _i in range(3)` | 否 | 否 | 安全 |
| 1534 | `for _i in range(3)` | 否 | 否 | 安全 |
| 1457 | `for method in _state.get_script().get_script_method_list()` | 否 | **理論上可以**(執行期取得的清單) | 安全,見下 |

**關鍵在於它用的是 `contains_exactly(expected)` 而不是「非空」**:第 426–434、462–470、506–519、
1346–1349、1467–1490、1536–1537 行的 `expected` 皆為**寫死長度的字面陣列**。
迴圈若跑零次,收集到的陣列為空,`contains_exactly` 會因長度不符而**紅**;
內容被改成別的值,同樣紅。**這正是派工單要求的「不要只接受非空斷言」那一層,撰寫者做到了。**
第 1464–1466 行還特別把這個理由寫在測試裡。

⚠️ **一項弱形式(不阻擋,S4)**:第 1114、1146 行用的是 `not_contains([...])`。
**空陣列會讓 `not_contains` 真空通過。** 實際執行時該陣列不會是空的
(外層 `set_target(50→60)` 必然產生一次 `TARGET_CHANGED`),但**沒有任何斷言把這件事釘住**。
若日後 `_write_target_internal` 的 reset 條件改動,這兩條會**無聲地退化成真空斷言**。
建議(非阻擋):補一條 `contains([TARGET_CHANGED])`,或改用 `contains_exactly`。
它們各自都有強斷言(`writer.result` 為 `REJECTED_REENTRANT`)撐著,故不影響本項判定。


## 2. 空路徑假性通過(`_reclaim` / `reclaim_progress()`)

**判定:已守住,且是本檔最紮實的一項。**

- `before_test()`(第 164–178 行)一律注入 **非 null** 的 `_RecordingReclaimPolicy`
  (第 167、169 行);全檔 36 條測試中**只有第 346 行那一條**刻意用 `null` 建構
  (第 348–352 行),而它驗的正是 fallback 本身。
- **`reclaim_progress()` 的 0.0 歧義有被正面處理**:第 321 行的轉發測試**刻意只用非零值**
  (0.42、1.0,第 326–332 行),doc comment(第 313–320 行)明寫「0.0 無法區分轉發與 fallback」。
  這正是派工單指出的第二種失效模式,撰寫者**先一步識別並封死**。
- 凡斷言 `reset()` 有沒有被呼叫的測試,**逐條都在測試本體上方標註了對非 null 替身的依賴**:
  第 852–854、907–912、950–952、987 行。第 906 行那條另外斷言 seed 座標等於
  `_MOUSE_POSITION`(第 933–936 行),而 `_MOUSE_POSITION` 刻意非零(第 29–34 行),
  **因此也擋掉了「走了 `_safe_mouse_position()` fallback」的假性通過**。

⚠️ **一項殘留(不阻擋,屬正式程式碼的既有缺口,非測試缺陷)**:
`CursorStateHost` 目前注入 `null`,所以**正式執行路徑上整個 reclaim 子機制是啞的**,
而本檔全部 reset 斷言都是對替身做的。`cursor_state.gd` 第 51–54 行自己承認
「no test can catch that」。這不是本張的錯,但**Story 014 落地前,任何人不得引用本檔的
reset 測試當作「正式建置上 reclaim 會動」的證據**。

## 3. 通過原因可各自歸因

**判定:大多數做得比本專案既往水準好,但有兩條的通過原因可被另一個機制完整解釋。**

### 做得好的部分(逐條標明,因為這是本檔的主要品質來源)

四條有回傳值的重入測試(第 1023、1058、1090、1122 行)**刻意讓內層呼叫在沒有閘門時會成功**:
第 1027–1029 行(已註冊且確實不同的目標)、第 1059–1062 行(payload 與當下持有值相符,
避免退化成 `STALE_NOT_APPLIED`)、第 1091–1093、1123–1124 行同理。
**這是把「閘門擋下」與「驗證失敗」分離的正確做法** —— 沒有這層設計,
`REJECTED_REENTRANT` 與一般拒絕在觀測上不可區分。
另外每條都斷言 `writer.invocations == 1`(第 1042、1075、1105、1137、1174、1209、1252 行),
**擋掉「handler 根本沒跑,測試卻綠」** —— 這是同一家族失效模式的另一個入口,已封。

第 717 行那條在斷言訊號之前**先斷言前提**(第 729–735 行:`equals()` 確實看不見 is_valid),
沒有這對斷言,訊號有沒有發就無法歸因到 OR 的第二個條件。第 781 行則是反向對照,
擋掉「永遠發訊號」的錯誤實作。**三條合起來才能各自歸因,少任何一條都不行。**

### 🔴 發現 1:R6-10 延遲重播測試(第 1225 行)無法區分「有閘門且重播」與「這個入口根本沒閘門」

`reseed_reclaim_on_focus_regained()` 回傳 `void`,測試以 `_reclaim.triggers()` 的內容與**順序**
作為觀測(第 1258–1266 行)。實際比對兩種實作:

- **現行(閘門 + `_pending_reseed` + drain)**:`_write_target_internal` 先 `reset(TARGET_CHANGED)`
  (`cursor_state.gd` 第 729 行)→ 再 `emit`(第 735 行)→ handler 設旗標返回 →
  entry 尾端 drain `reset(FOCUS_LOST_REGAINED)`(第 896 行)。
  觀測序列:`[TARGET_CHANGED, FOCUS_LOST_REGAINED]`。
- **假想:這個入口完全沒有閘門**,handler 當場執行 reset。
  觀測序列:**同樣是 `[TARGET_CHANGED, FOCUS_LOST_REGAINED]`。**

**兩者在本測試的全部斷言下不可區分** —— 含第 1263 行「必須是最後一個」那條。
唯一能分辨的觀測是 `diagnostic_reentrant_rejection_count`(實作於 `cursor_state.gd` 第 592 行
會 +1),而**測試在第 1233–1237 行刻意不斷言它**,理由是 ADR-0005 未規定 R6-10 這個入口
是否仍計數 —— 該理由本身成立(屬第 6 項那類未定義邊界)。

**但有一個不需要任何 ADR 裁決就能歸因的觀測被漏掉了**:在 handler 內部、呼叫
`reseed_reclaim_on_focus_regained()` **之後立刻**讀 `_reclaim.reset_calls.size()`。
延遲時為 1(只有 TARGET_CHANGED),無閘門時為 2。`_ReentrantWriter` 第 147 行已經有這個
「呼叫後立刻記錄」的鉤子位置,補一個欄位即可。
**建議補上;在補上之前,「這個入口的閘門存在」在本檔沒有任何測試證明。**

### 🔴 發現 2:AC-32 的 tripwire 不會在 Story 005 落地時變紅(見第 4.5 節)

其 doc comment 第 1562 行宣稱「When Story 005 lands, this test goes red on purpose」。
**這句話不成立**,理由與量測見第 4.5 節。歸因層面的問題是:該測試的綠燈可由
**兩個機制**解釋 ——(a)接縫還空著(它宣稱的那個),(b)接縫已填好但本次傳入的是
空事件陣列且 `_device_authority` 從未被設為 `KEYBOARD_GAMEPAD`。

## 4. 十條 AC 涵蓋度(獨立重算)

**重算方式**:先讀 story 檔第 64–74 行的 AC 原文,拆出其 THEN 子句的每一個可觀測宣稱,
再回頭找哪一條測試的哪一行斷言涵蓋它。**未照抄撰寫者的 `_partial_` 自評。**

### 4.0 涵蓋表

| AC | 撰寫者自評 | **本覆核判定** | 界線 |
|---|---|---|---|
| AC-3 | 部分 | **部分** | 只驗到公開方法清單(11 個)。AC 的主體「兩種輸入來源皆呼叫同一介面」**完全未觸及** —— 兩條輸入路徑都還不存在 |
| AC-24 | (未標) | **完整** | 本系統可觀測範圍內無缺口 |
| AC-25 | (未標) | **部分** | 查詢介面全覆蓋;AC 原文的「或任一掛載的 UI 表面渲染」子句未涵蓋 |
| AC-29 | 部分 | **部分** | 訊號側完整;渲染側未涵蓋(Story 010/011) |
| AC-32 | 未涵蓋(blocked) | **未涵蓋** —— 判斷正確,但 tripwire 無效 | 見 4.5 |
| AC-33 | (未標) | **完整** | AC 原文自己把範圍限縮在本系統的查詢回傳值 |
| AC-37 | (未標) | **完整** | 兩個半邊 + 值語意 + 第三個邊界值皆有 |
| AC-39 | (未標) | **完整** | AC 只點名兩個介面,兩個都驗了 |
| AC-50 | (未標) | **完整(本系統義務)** | AC 原文自帶分工條款,同 AC-33 |
| AC-54 | 部分 | **部分(ADVISORY)** | 只有結構前提;感知可區分那一半在程式碼裡還不存在 |

**合計:完整 5 / 部分 4 / 未涵蓋 1。**

🔴 **與撰寫者自評的差異只有一處實質分歧:AC-25。** 見 4.3。

### 4.1 AC-3 —— 部分(**撰寫者守住了界線**)

驗到的:第 1450 行以 `get_script_method_list()` 反射列舉,`contains_exactly` 釘死 11 個公開方法
(第 1467–1490 行)。
**未驗到、而且測試也沒宣稱驗到**:第 1444–1449 行的 doc comment 明寫
「What it CANNOT verify: that no bypass path exists」,並引用 AC 原文那句
「無法窮舉證明『不存在』」。**沒有超出 AC 自己的宣稱,判定守住。**

⚠️ **但本覆核認為界線比撰寫者說的更窄一層,值得寫下來**:AC-3 的 GIVEN 是
「滑鼠懸停/移動」與「d-pad/類比搖桿導覽」兩種來源。**這兩條路徑目前一條都不存在**
(滑鼠仲裁在 機制六/Story 005,渲染面在 Story 010/011),所以本測試連
「兩者皆呼叫同一介面」這個正面宣稱都**沒有機會被觀測**,更談不上反例。
它實質是一條**介面表面 tripwire**,不是 AC-3 的部分驗證。名稱裡的 `_partial_` 略為樂觀,
doc comment 第 1447–1449 行倒是講對了(「The other half ... needs the presentation layer」)。

### 4.2 AC-24 —— 完整

- 「不自動清空」:第 445 行測試,四次讀取 id 恆為 4(第 455–470 行)。
- 「不自動重新解析成其他目標」:第 471–473 行 `equals(target)`。
- 「不拋出例外」:GDScript 無例外,等價命題是「不中止函式」;斷言在讀取之後仍執行,即為證明。
- 「座標值與有效性旗標皆維持失效前的原始值」的**另一側**(已標記後座標仍保留):
  第 484 行測試,連 `surface` 也一併釘住(第 514–516 行)。
- 額外:第 474–479 行斷言「只是讀取」不會發訊號、不會 reset —— **這是 AC 沒要求但該有的**。

### 4.3 AC-25 —— 部分(🔴 **與撰寫者自評分歧;本覆核主張我方算法正確,依據為 AC 原文**)

#### 驗到的部分(這部分雙方沒有爭議,而且做得好)

第 370 行:座標立即等於呼叫方傳入的新值、旗標立即翻回有效。
第 401 行:「此後任何時間點查詢」—— 三次重讀,**外加一次被拒絕的寫入之後再讀**
(第 419–422 行)。最後這一步 AC 沒要求,但它抓得到「拒絕路徑把舊值救回來」這種錯誤,是加分項。

#### 分歧本身

| | 算法 | 結論 |
|---|---|---|
| **撰寫者** | 測試名稱未帶 `_partial_`,檔頭第 5–12 行也未把 AC-25 列入「不完全可驗證」的例外 | AC-25 **完整** |
| **本覆核** | 把 AC-25 原文的 THEN 子句拆成可觀測宣稱逐一比對 | AC-25 **部分** |

#### 依據:story 檔第 66 行的原文,逐字

> 「…**且此後任何時間點查詢游標狀態、或任一掛載的 UI 表面渲染,皆讀取到此新值與有效旗標**,
> 不殘留失效前的舊座標值或無效旗標…」

**「或任一掛載的 UI 表面渲染」是 THEN 的一部分,不是背景說明。**
本張沒有任何掛載的 UI 表面存在(渲染面是 Story 010/011),
**這個子句零涵蓋,而且無法在本層涵蓋。**

#### 為什麼是我方算法對,而不是「兩種讀法都可以」

關鍵不在「這個子句能不能測」,在於**這條 AC 有沒有自帶分工條款**。同一批十條 AC 裡,
有兩條明文把本系統的義務切出來:

- **AC-33**(第 70 行):「本 AC 驗證的範圍限於本系統的有效性旗標查詢介面本身回傳正確結果,
  呼叫方是否真的遵守查詢結果屬於呼叫方系統自己的驗收範圍」
- **AC-50**(第 73 行):「本系統僅負責正確回傳有效性旗標查詢結果;下游預覽是否遵守屬於
  各下游系統自身的驗收範圍」

**AC-25 沒有這種條款。AC-29 也沒有 —— 而撰寫者把 AC-29 標成了 `_partial_`。**
AC-29 之所以被標部分,理由寫在第 1499–1502 行:「Nothing renders yet — that is Stories 010/011」。
**那個理由對 AC-25 的渲染子句同樣成立,一字不改。**
所以這不是我方多算了一條,而是**撰寫者對兩條結構相同的 AC 套用了兩套標準**。

#### 這件事的實際後果(不是文書潔癖)

story 檔第 118–122 行寫明本張 `Unlocks` **005 / 008 / 009 / 011**,是關鍵路徑上最壅塞的一張。
**AC-25 若在結案文件裡登記為「完整」,Story 010/011 的人不會知道還有一半掛在他們身上。**
📌 **建議**:AC-25 與 AC-29 同列為**部分**,界線寫成同一句
(「查詢介面已完整;『任一掛載的 UI 表面渲染』子句待 Story 010/011」)。
**不需要改動任何測試** —— 測試本身沒有錯,錯的是它被記成什麼。

### 4.4 AC-29 —— 部分(**撰寫者守住了界線**)

驗到的:第 1503 行。**用兩個獨立訂閱者**(第 1504–1510 行)—— doc comment 自己指出
單一訂閱者無法區分「每個訂閱者各一次」與「總共只發一次」。**這正是派工單第 3 項要的歸因紀律。**
另驗持續性(第 1533–1540 行:三次讀取恆為 false 且無額外通知)。

未涵蓋且未宣稱:「所有掛載的 UI 表面皆呈現統一視覺」。第 1499–1502 行明寫
「Nothing renders yet — that is Stories 010/011, and no test here fakes a surface to
pretend otherwise」。**守住。**

### 4.5 AC-32 —— 未涵蓋。撰寫者的**判斷正確**;但他的 **tripwire 無效**

#### (a) 「`apply_buffered_navigation()` 只有閘門/診斷/drain,無實際寫入」—— ✅ 查證屬實

`src/ui/cursor/cursor_state.gd` 第 374–396 行,逐行:
第 375–377 行閘門與診斷計數 → 第 378 行拉閂 → 第 380–393 行**整段是註解**
(`STORY 005 SEAM`)→ 第 395 行 `_drain_pending_reseed()` → 第 396 行清閂。
**函式體內沒有任何一行寫入 `_target`,也沒有呼叫 `_write_target_internal()`。**
AC-32 的 THEN(座標變成新導覽值、旗標翻回有效)在本層**結構上不可觀測**。
**撰寫者的判斷正確,而且他拒絕用 `set_target()` 湊一條(第 1556–1560 行)是對的** ——
AC-32 的整個重點就是「不需要任何呼叫方系統介入」,用呼叫方路徑冒充會是一次典型的假綠燈。

#### (b) 🔴 但「When Story 005 lands, this test goes red on purpose」(第 1562 行)**不成立**

##### 它為什麼攔不住:**斷言的對象不對**

該測試唯一的 tripwire 斷言是第 1586–1594 行 ——「`is_current_target_valid()` 仍為 `false`」。
這是一個**結果**,而這個結果有**兩個成因**:

- 成因一(它宣稱在測的):導覽入口的主體還是空的。
- 成因二(它沒排除的):主體已經填好了,**但這次呼叫的輸入到不了寫入路徑**。

而**成因二由測試自己的輸入所保證**,有兩個各自獨立就足夠的理由:

1. **傳入的是空事件陣列**(第 1577 行 `_no_events()`,定義在第 240–242 行)。
   任何正確的 機制六 實作,從**零個事件**裡都推導不出新目標,必然什麼都不寫。
2. **`_device_authority` 在本測試中從未被設定**,故為 `UNINITIALIZED`。
   接縫註解第 382–383 行自己寫明:「if `_device_authority` is not `KEYBOARD_GAMEPAD`
   this is a no-op」。

**亦即:這條斷言對它宣稱要偵測的那個變化(主體被填好)完全不敏感。**
Story 005 落地當天它會照樣是綠的,而下一個人讀到第 1562 行那句話,會相信自己已經被保護了。
🔴 **這正是本專案最怕的那種形狀:一條看起來會保護你、實際不會的測試,比沒有測試更危險。**

##### 有沒有一個真的會攔住的寫法?

我找了三種,**沒有一種是可靠的**,逐一說明理由(**以下皆為報告內容,未動測試檔**):

**寫法 A —— 把輸入補到「正確實作必須寫入」的強度。**
在 Arrange 追加 `_state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)`,
並傳入一個真的 NAVIGATION 類 `ui_*` 事件而非空陣列,然後仍斷言旗標維持 `false`。

- **會攔住的情況**:Story 005 填好主體且事件形狀符合它的預期 → 旗標翻回 `true` → 紅。
- 🔴 **不可靠的原因**:「事件形狀符合它的預期」今天是猜的。Story 005 尚未決定它吃
  `InputEventAction` 還是實體按鍵事件、是否用 `event_is_action()` 過濾、是否要求
  `InputEventKey.echo` 已被濾掉(ADR-0005 核准時附帶的硬性義務之一)。
  **猜錯的代價正好是最壞的那種**:測試維持綠燈,而且看起來比現在更有說服力
  (因為它現在「有傳事件了」)。**把一個弱 tripwire 換成一個看起來強的弱 tripwire,是負向改動。**

**寫法 B —— 對正式程式碼的原始碼文字下斷言。**
用 `FileAccess` 讀 `res://src/ui/cursor/cursor_state.gd`,斷言 `STORY 005 SEAM` 這個標記
仍出現在檔案裡。Story 005 要填主體就得刪掉那段接縫註解,刪掉即紅。

- **會攔住的情況**:接縫註解被移除。
- 🔴 **不可靠的原因**:①它測的是註解文字,不是行為 —— 有人只是重寫註解措辭就會**假紅**;
  ②反過來,主體填好了但註解沒刪,就**假綠**;③本專案有兩個 `STORY 005 SEAM` 標記
  (`arbitrate_device_authority` 第 332 行、`apply_buffered_navigation` 第 381 行),
  只刪其中一個時整檔搜尋仍命中。**這是把「文件有沒有被更新」偽裝成測試。**

**寫法 C —— 對私有狀態下斷言(例如驗證 `_target` 的物件同一性未變)。**
與現行斷言等價,同樣被上述成因二解釋掉。**無改善。**

##### 🔴 結論(這一句請直接用在結案文件裡)

> **AC-32 這個缺口沒有可靠的自動防線,只能靠文件與流程。**
> 現行 `test_ac32_blocked_...` 應被理解為**寫在程式碼裡的缺口聲明**(它的失敗訊息
> 第 1587–1593 行把該補什麼寫得很完整,這部分有價值),**而不是一個會在 Story 005
> 落地時提醒任何人的機制**。

因此建議三件事(皆不需動本張的程式碼):

1. 把 story 007 的 `## Test Evidence` 節明文寫上 **AC-32 = UNCOVERED,阻擋原因:Story 005 未實作**。
2. 把「補上真正的 AC-32 測試」寫進 **Story 005 自己的 Definition of Done**,
   並在 Story 005 工作單的 Acceptance Criteria 區塊列出 AC-32 原文。
   **這是唯一真的會被執行到的防線** —— 因為 Story 005 的驗收本來就會被讀。
3. 把第 1562 行那句「When Story 005 lands, this test goes red on purpose」**改掉**,
   改成據實的措辭,例如:
   > `This test does NOT go red when Story 005 lands — its inputs (empty event array,`
   > `UNINITIALIZED authority) produce no write under any correct 機制六 body. It is a`
   > `written-down gap declaration, not a tripwire. The real AC-32 test is registered in`
   > `Story 005's Definition of Done.`

   🔴 **這句話的殺傷力不在測試,在於它會讓下一個人停止擔心。**
   **本項不阻擋 Story 007** —— 缺口的成因不在本張,但那句話的成因在。

### 4.6 AC-33 —— 完整

第 1320 行。有效時為 true(第 1334–1336 行,**這一半不可省**:少了它,
「永遠回傳 false」的錯誤實作也會通過)、待重新解析時為 false(第 1337–1340 行)、
三次重讀答案穩定(第 1343–1349 行)。AC 原文第 70 行自己把範圍限縮在
「本系統的有效性旗標查詢介面本身回傳正確結果」,呼叫方是否遵守明文屬呼叫方驗收範圍。**完整。**

### 4.7 AC-37 —— 完整

- 不相符 → `STALE_NOT_APPLIED` 且**什麼都不變**:第 529 行,座標/旗標/裝置權威/兩個訊號/
  reclaim reset 全部斷言(第 558–576 行)。
- 相符 → `APPLIED` 且旗標翻轉:第 580 行。
- **回傳值可程式化區分**(AC-37 2026-08-06 修訂新增的那半句):第 553–555 行
  明確斷言 `is_not_equal(APPLIED)`。
- **值語意**(而非物件同一性):第 585–594 行刻意傳入重建的等值實例並先斷言 `is_not_same`。
  **沒有這一步,一個用 `==` 比較的錯誤實作會讓上面全部通過。**

### 4.8 AC-39 —— 完整

`set_target`(第 661 行)與 `mark_pending_reresolve`(第 691 行)兩個介面各一條,
另外第 567–569 行在被拒絕的 mark 路徑上也斷言權威不動。
**前置設計正確**:兩條都先把 `_device_authority` 設成**非預設值**(第 666、693 行),
doc comment 第 662–664 行講明理由 —— 否則「沒變」與「本來就沒設過」不可區分。
⚠️ 該設定用 `_state.set(&"_device_authority", ...)` 反射寫私有欄位。
**這裡沒有無聲失敗風險**:若欄位改名,`set()` 靜默不生效,但第 684、709、1417 行的
正面斷言會立刻紅。**查過了,是安全的。**

### 4.9 AC-50 —— 完整(本系統義務)

第 1355 行的 `[true, false, true]` 往返(第 1364–1382 行)。
**第三個值是重點** —— 只驗 false 方向的測試看不到「旗標再也翻不回來、下游預覽永遠被抑制」。
AC-50 原文第 73 行自帶分工條款(「本系統僅負責正確回傳有效性旗標查詢結果」),
故本系統這一側判**完整**。下游預覽消費者屬各下游系統驗收範圍。

### 4.10 AC-54 —— 部分,ADVISORY(**撰寫者守住了界線**)

驗到的**只有結構前提**:第 1399 行建構 (a)(b) 兩種拒絕情境,各讀兩個查詢,
最後第 1431–1434 行斷言 `cause_a != cause_b`。
**這正是主 session 事先給的那條界線 ——「兩個獨立查詢能讓呼叫方區分兩種拒絕原因」—— 一字不差。**

未驗、且明文拒絕宣稱:第 1392–1398 行寫明感知可區分屬 Visual/Feel、
音色與震動「does not exist in code yet」、「No automated test can reach it, and none here tries」。
**守住。**

📌 **連帶提醒**:AC-54 依 coding-standards.md 屬 ADVISORY,證據形式是
`production/qa/evidence/` 的錄音 + lead sign-off。**該證據目前不存在,也不可能存在**
(回饋形式尚未設計)。故 AC-54 應登記為**延後**,不得因本測試綠燈而視為已滿足。

## 5. AC-1 排除名單放寬幅度(`state_host_test.gd`)

**放寬幅度:排除名單從 2 個名字擴大到 8 個(2 個協作者 + 6 個新增機制欄位),4 倍。**
`CursorState` 現有 11 個宣告欄位,AC-1 實際比對的只剩 3 個。
**亦即 AC-1 現在證明的是「在一份 8 個名字的白名單之外,恰好只有 3 個欄位」。**

### 存在性斷言:**有,而且擋掉了錯字**

第 203–222 行的 `test_ac1_known_mechanism_fields_are_excluded_..._by_design` 對六個名字逐個
`contains` 斷言。名單裡一個錯字會讓該測試**紅**,不會無聲放行。
第 175 行與第 214 行的兩個迴圈也不會真空通過(空清單會讓 `contains` 失敗)。
**派工單擔心的那個具體失效模式已被封住。**

### 🔴 但存在性斷言有一個它擋不住的缺口

第 162–166 行的名單與第 218–222 行的斷言是**兩份手抄的複本**。
**新增第七個排除名字時,只改上面那份、不改下面那份,兩個測試都會綠** ——
存在性測試只檢查它自己列的那六個,AC-1 的過濾器則已悄悄變寬。
這正是本專案 `consistency-failures.md` 反覆記載的手抄漂移,只是這次發生在同一個檔案裡。
**建議(可立即做,不需任何裁決)**:把名單提為 script 層 `const`,兩處共用同一個識別字,
使「只改一處」在語法上不可能。

### 六個理由逐條判定

| 欄位 | 判定 | 依據 |
|---|---|---|
| `_mutation_in_progress` | **成立**,但理由措辭有誤 | 結論對(重入閂不是游標狀態)。第 144–145 行寫「always false when any caller can observe it」**與事實不符** —— 訊號正是在閂拉起時發出的,下游 handler 觀測得到它的效果(`REJECTED_REENTRANT`),整個第 1023–1219 行的重入測試群就建立在這件事上。**措辭應改**,否則這句話會被拿來替未來的排除背書 |
| `_pending_reseed` | **成立** | 「never outlives one call」經查為真:`_drain_pending_reseed()`(`cursor_state.gd` 第 883–897 行)在七個入口清閂前必被呼叫,且 drain 內部再度被設起的請求也在第 897 行被清掉 |
| `_provider_error_reported` | **成立** | 一次性 log 記帳。⚠️ 它確實**跨呼叫存續**(與上一項不同),但 AC-1 問的是「有沒有第四個 GDD 狀態欄位」,不是「有沒有第四個會存續的變數」,故判成立 |
| `_last_mouse_position` | **成立,但這是六個裡最弱的一個** | 它跨呼叫存續、被讀回、且**會影響行為**(`_reclaim.reset()` 的 seed,`cursor_state.gd` 第 839 行)。理由裡「owned by no one here」**不正確** —— 本類別宣告它、寫它(第 841 行)、讀它(第 839 行)。判成立的真正理由不是那句,而是 Core Rules #1 的第三個欄位是**累計位移**(由 `_reclaim` 持有),而本欄位是 seed 輸入而非累計值。🔴 **若日後 機制八 把 seed 收進 `CursorState`,這條排除必須重新檢討** |
| `diagnostic_reentrant_rejection_count` | **成立** | 機制十五 慣例,比照 ADR-0002 `diagnostic_visited_count`;`cursor_state.gd` 第 207–209 行明文「下游不得依賴」 |
| `diagnostic_invalid_mouse_provider_count` | **成立** | 同上 |

### 🔴 兩處措辭錯誤 —— 逐字引出與替代寫法

引擎/ADR 覆核者獨立撞到同一處(他判「六個理由五強一弱」)。以下是本覆核認為**與事實不符**
的兩句原文,附替代寫法,可直接下修正指令。

**措辭錯誤 1 —— `tests/unit/cursor/state_host_test.gd` 第 144–145 行**

現行原文(逐字):

> `#                                entry's own call; always false when any`
> `#                                caller can observe it. Control flow, not state.`

🔴 **「always false when any caller can observe it」與事實不符。**
`target_changed` 正是在閂拉起時發出的(`cursor_state.gd` 第 734–735 行,
第 855 行 `_mutation_in_progress` 仍為 `true`),下游 handler 觀測得到它的效果
(`REJECTED_REENTRANT` / 診斷計數 +1)。**整個第 1023–1219 行的重入測試群就建立在這件事上** ——
若這句話為真,那七條測試全部不可能存在。

替代寫法:

> `# · _mutation_in_progress      — reentrancy latch. Observable BY EFFECT while it is`
> `#                                raised (signals are emitted inside the latched`
> `#                                region — that is what the reentrancy tests exercise),`
> `#                                but it is control flow, not cursor state: nothing`
> `#                                downstream reads it to decide what the cursor points`
> `#                                at, and it is always false between calls.`

**措辭錯誤 2 —— `tests/unit/cursor/state_host_test.gd` 第 151–154 行**

現行原文(逐字):

> `# · _last_mouse_position       — cache of the last coordinate the provider`
> `#                                returned (S-1 fallback). Derived from an`
> `#                                injected collaborator, owned by no one here,`
> `#                                and not a cursor target.`

🔴 **「owned by no one here」不正確。** 本類別宣告它(`cursor_state.gd` 第 205 行)、
寫它(第 841 行)、讀它(第 839 行),而且**讀回來的值會影響行為**
(`_reclaim.reset()` 的 seed)。它是本類別擁有的、跨呼叫存續、且會影響輸出的狀態。
判它可排除的**真正理由不是那句** —— 而是 Core Rules #1 的第三個欄位是**累計位移**
(由 `_reclaim` 持有),本欄位是 seed 輸入,不是累計值。

替代寫法:

> `# · _last_mouse_position       — last coordinate the provider returned (S-1`
> `#                                fallback). It IS owned, written and read here and`
> `#                                it does outlive a call — the reason it is excluded`
> `#                                is narrower: Core Rules #1's third field is the`
> `#                                ACCUMULATED displacement, which _reclaim owns.`
> `#                                This is a seed INPUT, not that accumulator.`
> `#                                🔴 Revisit if 機制八 ever moves the seed into`
> `#                                CursorState — it would then shadow the third field.`

### 🔴 手抄複本在哪(今天第四次遇到同型問題)

**同一份名單在 `tests/unit/cursor/state_host_test.gd` 一個檔案裡有三份手抄複本:**

| 複本 | 行號 | 形式 |
|---|---|---|
| ① 散文理由 | 143–161 | 六個名字 + 各自理由的註解區塊 |
| ② 實際生效的排除名單 | 162–166 | `known_mechanism_fields` 陣列 |
| ③ 存在性斷言 | 218–222 | `contains([...])` 的字面陣列 |

**同一個檔案裡的第二組(協作者名單)也是兩份**:第 127 行 `known_collaborator_fields`
與第 200 行 `contains([&"_registry", &"_mouse_position_provider"])`。

**失效方式**:新增第七個排除名字時只改 ②,①③ 不動 → **兩個測試都綠**,
AC-1 的過濾器已悄悄變寬。反過來刪掉一個欄位時只改 ②,③ 會紅(這個方向有防護)。
**危險的是加,不是減。**

**修法(不需任何裁決)**:把 ② 提為 script 層 `const EXCLUDED_MECHANISM_FIELDS`,
③ 直接引用同一個識別字,`contains(EXCLUDED_MECHANISM_FIELDS)`。
協作者名單同法。**這讓「只改一處」在語法上不可能。**
① 是散文,無法用同一手段綁定,但它只要不再是唯一的真值來源就沒有致命性。

### 判定

**放寬幅度可接受,但 AC-1 的防護力確實下降,而且下降的部分無法用測試補回來** ——
白名單由新增欄位的同一個人維護,測試只能查「名字存在」,查不了「這個名字該不該在名單上」。
**唯一的防線是第 143–161 行那份逐條書面理由**,而它有兩處措辭與事實不符(見上表)。
📌 **本項不阻擋,但那兩處措辭應更正**;第七個名字被加進去之前,`const` 共用那項建議應先做掉。

## 6. 三處 ADR 未定義邊界的措辭確認

**判定:三處**逐字查過,**沒有一處被寫成契約測試**。撰寫者的自述屬實。
**但三處的形式不同,其中兩處是「根本沒有測試」而非「有測試但措辭謹慎」** —— 這個差別會影響
下一個人怎麼處理,故逐處分開記。另**另有第四處**,見 6.4。

### 6.1 `MarkResult.NO_CURRENT_TARGET` 的觸發條件 —— ✅ 有測試,措辭正確

唯一一處「有測試在釘實作選擇」的邊界。逐字查核三個位置:

**測試 doc comment(`write_read_interface_test.gd` 第 622–624 行)**:

> `## 🔴 [b]ADR-0005 DOES NOT DEFINE THIS BOUNDARY — this test pins the current`
> `## implementation's chosen reading, NOT a contract.[/b]`

**同一 doc comment 第 632–635 行**,指出裁決權在誰、以及日後怎麼處理:

> `## If the architecture owner rules differently, [b]change this test rather`
> `## than treating it as a regression[/b].`

**失敗訊息本身(第 649–651 行)** —— 這一處最關鍵,因為 CI 紅燈時人只讀失敗訊息、不讀 doc comment:

> `"IMPLEMENTATION-DEFINED, NOT CONTRACT: expected NO_CURRENT_TARGET for "`
> `+ "'nothing valid to invalidate'. ADR-0005 does not specify when this "`
> `+ "member is returned; if the reading changed, update this test."`

📌 **判定:措辭正確且放在對的三個位置。** 特別是失敗訊息也帶了免責,
**沒有這一句,紅燈時的人會以為自己撞壞了契約而去改正式程式碼。**
正式程式碼側(`cursor_state.gd` 第 747–757 行)同樣以
`⚠️ BOUNDARY NOT DEFINED BY ADR-0005 — reported, not silently chosen.` 開頭,兩側一致。

### 6.2 `_validate_target_writable()` 收 `null` 的回傳 —— ⚠️ **沒有測試**

**查證結果:全檔沒有任何一條測試對任何入口傳入 `null` 目標。**
(`grep "set_target(null\|handoff_after_mount(null\|mark_pending_reresolve(null"` → 零命中。)

因此「不得寫成契約測試」這條要求是**真空滿足**的 —— 沒東西可寫成契約。
措辭只存在於正式程式碼側(`cursor_state.gd` 第 791–800 行):

> `# ⚠️ BOUNDARY NOT DEFINED BY ADR-0005 — reported, not silently chosen.`
> `# SetTargetResult has no member for "you passed null", and the ADR froze`
> `# the member list. Mapping null onto INVALID_SURFACE_TYPE is the`
> `# least-wrong of the three available members ..., NOT an ADR decision.`

**判定:措辭正確。** 但**沒有測試這件事本身有一個具體後果**,登記在第 8 節:
第 802–803 行的 `if target == null: return INVALID_SURFACE_TYPE` 這條分支
**在 debug 下不可能被測到** —— 第 801 行的 `assert()` 會先中止。
而那條 `if` 存在的唯一理由,正是「release 建置會把 `assert()` 剝掉」。
**亦即:唯一會執行到它的建置組態,正好是唯一測不到它的組態。**

### 6.3 `set_target()` 的 `from_ui_action == true` —— ⚠️ **沒有測試**

**查證結果:全檔 `set_target()` 的每一次呼叫都傳 `false`,零次 `true`。**
同 6.2,要求真空滿足。措辭在 `cursor_state.gd` 第 430–440 行:

> `# 🔴 The TRUE case is NOT implemented, because ADR-0005 does not define it.`
> `# 機制十一 says only "set_target() transfers device authority when`
> `# from_ui_action is true" and never says TO WHICH device ...`
> `# Raised as an open question for the architecture owner; do not close it by guessing.`

📌 **判定:措辭正確,而且「do not close it by guessing」這句是對的處理**。
本覆核**不建議**為它補測試 —— 補了就等於用測試把一個未定義行為釘成契約,
正是本節要防的事。**正確處理是登記為開放問題,由架構擁有者裁決後再寫測試。**

### 6.4 🔴 **第四處未定義邊界:R6-10 入口的診斷計數**(你點名要判定的那一處)

**ADR 內部矛盾屬實,已逐字查證:**

`docs/architecture/adr-0005-...md` 第 934 行(「三個回傳 `void` 的入口如何表達拒絕」段)寫:

> 「三者的閘門語意是『偵測到重入即整段 no-op、不寫任何欄位、不發任何訊號』…
> 因此三者在 **no-op 時**應遞增一個 `diagnostic_reentrant_rejection_count`」

**而 R6-10 把 `reseed_reclaim_on_focus_regained()` 的重入行為從「no-op」改成「延後重播」** ——
它不再是 no-op,所以「在 no-op 時應遞增」這個條件**字面上不再成立**,
而 ADR **從未回頭說明計數還算不算**。

**三方現況**:
- **ADR**:矛盾,未解。
- **實作**:照舊遞增(`cursor_state.gd` 第 592 行),並在第 588–590 行註明理由
  (「with a void return that is the only trace there is」)。
- **測試**:第 1233–1237 行**刻意不斷言**,逐字:
  > `# ⚠️ This test deliberately does NOT assert on`
  > `# diagnostic_reentrant_rejection_count for this entry: ADR-0005 line ~934`
  > `# says the three void entries count a rejection, while R6-10 replaces the`
  > `# rejection with a deferral for this one, and never says whether the count`
  > `# still applies. Registered as an open boundary in this story's report.`

📌 **本覆核對「這個處理是否恰當」的判定:恰當,但代價沒有被補上。**

- **恰當的部分**:不斷言是對的。斷言等於把一個 ADR 自相矛盾的點釘成契約,
  與 6.1–6.3 同一個原則。而且他**主動登記**了,沒有靜默略過。
- 🔴 **沒補上的代價**:`diagnostic_reentrant_rejection_count` **同時是唯一能證明
  「這個入口的閘門存在」的觀測**(見第 3 節發現 1)。放棄斷言它,就同時放棄了那個歸因。
  結果是:**七個公開入口裡,`reseed_reclaim_on_focus_regained()` 的閘門是唯一沒有任何測試
  證明其存在的。**
- **而這個代價有一個不需要任何裁決就能付掉的補法**(第 3 節發現 1 已寫):
  在 `_ReentrantWriter.on_target_changed()` 內、呼叫之後立刻記錄 `_reclaim.reset_calls.size()`。
  延後時為 1,無閘門時為 2。**這個觀測與 ADR 的矛盾完全無關。**

## 7. Testing Standards 合規

**實跑結果(2026-09-03,本覆核親自執行)**:
`tests/unit/cursor` → **5 suites / 102 test cases / 0 errors / 0 failures / 0 flaky / 0 skipped /
0 orphans / exit code 0**。其中 `write_read_interface_test.gd` 單獨 **36 條全過、0 orphans、8.087 秒**。
指令為 `coding-standards.md` 的直接呼叫式,帶 `--ignoreHeadlessMode`,引擎絕對路徑。
**注意:退出碼是引擎自己的(`${PIPESTATUS[0]}`),不是管線的** —— 本專案明文要求這樣查。

| 項目 | 判定 | 依據 |
|---|---|---|
| **命名(檔案)** | ✅ | `tests/unit/cursor/write_read_interface_test.gd` —— system 由目錄承載,與既有 `state_host_test.gd` 一致 |
| **命名(函式)** | ✅(小偏差) | 多數為 `test_[scenario]_[expected]`。部分以 AC 編號起頭(`test_ac25_...`)、部分以區塊起頭(`test_read_...`)。**這是可追溯性換來的偏差,判可接受** |
| **決定性** | ✅ | 全檔零命中 `await` / `rand*` / `Time.` / `OS.` / `Input.` / `get_tree`。唯一的座標來源是第 183–184 行的具名方法,回傳常數 |
| **隔離(執行順序)** | ✅ **含 Autoload 專項查核,見下** | 第 164–178 行 `before_test()` 重建全部 fixture |
| **無硬編魔數** | ✅ | 表面標籤、滑鼠座標皆為 `const`(第 34、38、43 行)。目標 id(1…77)是**不透明識別碼**,值本身無語意,且一律經 `_registered_target()` / `_unregistered_target()` 工廠產生 |
| **0 orphans** | ✅ | 全檔只建立一個 `Node`,包在 `auto_free()` 裡(第 166 行)。實跑 0 orphans |

### 🔴 Autoload 隔離專項(`technical-preferences.md` 點名的風險)

`technical-preferences.md` 的 Autoloads 節記著一句**針對本張的預警**:
「Story 005/007 一旦出現會改寫全域狀態的測試,就會產生順序相依風險」。

**查核結果:Story 007 沒有踩到。**

- `write_read_interface_test.gd` **完全不碰** `CursorStateHost`(全檔僅第 23、347、1159 行的
  註解提及),每條測試自建 `CursorState`。檔頭第 21–25 行明文寫下這個決定。
- 對照組:`state_host_test.gd` 確實會取用 Autoload(第 319、329、338、356、366、376 行),
  但**全部是 `get_node_or_null()` + 唯讀斷言**;該檔唯一的 `set()`(第 288 行)寫的是
  當場 `_make_state()` 出來的區域實例,不是 Autoload。
- **結論:兩個測試檔對全域狀態皆為唯讀,無跨測試污染,執行順序無關。**
  📌 **預警仍對 Story 005 有效**,本張不觸發。

### ⚠️ 兩項小缺陷(S4,不阻擋)

1. **`writer.release()` 的位置**(第 1055、1087、1119、1150、1189、1219、1271 行)在**全部斷言之後**。
   `_ReentrantWriter` 與 `CursorState` 之間是 RefCounted 循環參考
   (`_state` →訊號→ writer,`writer.state` → `_state`),`release()` 就是拿來斷開它的。
   **若某條斷言先紅,`release()` 不會執行,該循環洩漏。**
   這不會被 GdUnit4 的 orphan 計數抓到(orphan 只算 `Node`),所以**是一個不會留下痕跡的洩漏**。
   建議:改用 `after_test()` 統一釋放,或讓 `_ReentrantWriter` 持弱參考。
   (現況全綠,故實測 0 orphans 是真的乾淨;這是**失敗路徑**才發作的問題。)
2. **第 1488–1490 行的 `is_equal(11)`** 與第 1467–1479 行那份 11 元素清單是同一個事實的兩份複本。
   清單增減時 `11` 必須同步改。**危害有限**(`contains_exactly` 會先紅),但它與第 5 節的
   手抄複本是同一類形狀。可改為 `.is_equal(expected.size())`。

## 8. 該測而未測的缺口

**先講結論**:派工單點名的六個項目裡,**四個涵蓋良好**、**兩個有實質缺口**;
另外**獨立找到四個派工單沒點到的缺口**,其中 **G-1 是本次覆核最重要的一項發現**。

### 派工單點名的六項,逐項

| 項目 | 判定 | 依據 |
|---|---|---|
| 七個入口的閘門**進出配對** | ⚠️ **半個缺口** | 進(重入拒絕)7/7 有:第 1023、1058、1090、1122、1155、1192、1225 行。出(落旗)由第 1276 行一條循序呼叫七入口的測試整體涵蓋。**但只涵蓋正常退出路徑** —— 見 G-3 |
| 三個 `void` 入口的**診斷計數** | ⚠️ **2/3** | `arbitrate`(第 1177–1181 行)、`apply_buffered_navigation`(第 1212–1214 行)有;`reseed` 刻意不驗(第 6.4 節,判定恰當但代價未補) |
| `get_current_target()` 的**複本語意** | ✅ **良好** | 第 249 行(三個相異實例,含「不是呼叫方傳進來的那一個」)+ 第 282 行(改寫複本不影響內部,連 `is_current_target_valid()` 一併查)。**這兩條合起來才成立,少了第 282 行只證明了位址不同** |
| **甲/乙分支** | ⚠️ **兩個缺口** | 甲:第 868、906 行;乙:第 832、949、986 行。品質好,但見 G-2 與 G-4 |
| `_target_changed_from()` 的 **OR 雙條件** | ✅ **良好** | 條件二兩個方向皆有(第 717 行 true→false、第 748 行 false→true),第 781 行反向對照擋掉「永遠發訊號」。條件一由第 986、1023 行的變更寫入涵蓋 |
| **`_reclaim` null 的降級行為** | 🔴 **重大缺口** | 見 G-1 |

---

### 🔴 G-1(最重要)—— `_reclaim` 為 `null` 時,**只有一個 getter 被測過**

**現況**:唯一涵蓋 null 組態的測試是第 346 行,而它只呼叫 `reclaim_progress()`。
`cursor_state.gd` 另有**六個** `_reclaim` 呼叫點,各自套著 `if _reclaim != null` 守衛:
第 277(`_init` 接線)、519(甲)、600(reseed)、727、729(`_write_target_internal` 的 if/elif)、
895(`_drain_pending_reseed`)行。**這六個守衛,一個都沒有測試。**

**缺了會漏掉什麼 —— 這不是理論風險,是本檔自己寫下的災難模式**:
`cursor_state.gd` 第 110–116 行明文記載,若拿掉守衛而 `_reclaim` 為 null,
呼叫會**中止所在函式**,而**六個呼叫點裡有六個坐在已拉起的重入閂內** ——
中止會跳過清閂那一行,**此後每一次公開呼叫都永遠回傳 `REJECTED_REENTRANT`**。
原文形容為「a loud one-off error followed by a permanently and silently dead system」。

🔴 **而 `null` 正是今天正式建置的實際組態**:`CursorStateHost` 現在就是用
`reclaim = null` 建構這個類別(Story 014 未做,`technical-preferences.md` Autoloads 節有登記)。
**亦即:唯一有測試的組態(注入替身)不是正式執行的組態;正式執行的組態幾乎沒有測試。**

**補法(便宜、無需任何裁決)**:一條測試,建 `CursorState.new(null, registry, provider)`,
依序呼叫全部七個入口,斷言(a)四個有回傳值的入口都不是 `REJECTED_REENTRANT`,
(b)**最後再呼叫一次 `set_target()` 仍被接受** —— (b) 才是重點,它證明閂每次都清乾淨了。
📌 **本覆核建議把這一條列為 Story 007 結案前應補**(見整體判定)。

### 🔴 G-2 —— 甲分支「沒東西可標記時仍必須無條件重播種」未測

`cursor_state.gd` 第 509–519 行明寫:reset **刻意放在 result 檢查之外**,
因為 GDD Core Rules #7 F2-2 要求「**regardless of whether there was anything to mark**」。

**現況**:第 868、906 行兩條甲測試**都先寫入了有效目標**。
**「沒有有效目標時呼叫甲」這條路徑零涵蓋。**

**缺了會漏掉什麼**:有人把第 518–519 行搬進 `if result == MarkResult.APPLIED:` 裡面,
**全部 36 條測試照樣全綠**,而 GDD 強制的歸零在最需要它的情境(舊表面正要拆掉、
而當下沒有有效目標)靜默不發生。
**補法**:全新 state(不 seed)→ `handoff_before_unload()` →
斷言 `result == NO_CURRENT_TARGET` **且** `triggers() == [SURFACE_HANDOFF]`。

### 🔴 G-3 —— 閘門的**中止路徑**落旗未測(與引擎覆核者的 CONCERNS 同一處)

第 1276 行只走**正常退出**。引擎/ADR 覆核者已判 CONCERNS:「閘門內有兩條中止路徑會跳過落旗」。
**測試側對應的事實是:沒有任何一條測試證明中止之後閂會被清掉,或證明它不會。**

**可觀測性是有的**:中止只終結正式程式碼的那個函式,控制權回到測試;
因此「中止後再呼叫一次公開入口,看它回不回 `REJECTED_REENTRANT`」就是判準。
📌 **中止該怎麼觸發屬引擎覆核者的領域,本覆核不越界下結論** ——
但無論他的 CONCERNS 最後判成缺陷或判成可接受,**這件事目前沒有測試證據,只有論證。**

### ⚠️ G-4 —— 乙分支從未跨表面測過(fixture 限制)

`before_test()` 只註冊**一個**表面(第 166 行)。
`_UNREGISTERED_SURFACE` 一律被驗證擋掉,所以**本檔結構上不可能寫出「目標換到另一個已註冊表面」**。

**後果**:`handoff_after_mount()`(乙)的存在理由就是「新表面剛掛載完成」,
而**每一條乙測試寫的都是同一個表面上的目標**。同理,`_target_changed_from()` 的條件一
只被「同表面、不同 id」驗過,**「同 id、不同表面」零涵蓋** ——
若 `CursorTarget.equals()` 漏比 `surface`,本檔一條都不會紅。
**補法**:`before_test()` 多註冊一個表面即可,現有測試不需改寫。
(⚠️ `equals()` 本身的正確性屬 Story 003 的驗收範圍,本覆核不重複計入。)

### ⚠️ G-5 —— `SetTargetResult.INVALID_SURFACE_TYPE` **整個列舉成員零涵蓋**

全檔對該成員 **0 次**斷言(對照:`SURFACE_NOT_REGISTERED` 4 次、`REJECTED_REENTRANT` 13 次、
`STALE_NOT_APPLIED` 6 次、`NO_CURRENT_TARGET` 3 次)。ADR 凍結的四個成員,**只涵蓋三個**。

產生它的兩條分支都沒測:
- `cursor_state.gd` 第 811–812 行(表面標籤超出 enum 值域)。
  **這條可測且該測** —— 註解第 806–807 行自己說明「GDScript 的 enum 型別欄位接受任何 int,
  所以這是真的可達情況,不是形式」。設 `target.surface = 9999` 即可。
  **缺了會漏掉什麼**:整條 `find_key()` 守衛可以被刪掉而測試全綠,
  而它同時是本專案禁止樣式 `enum_value_positional_string_conversion` 的合規證據。
- 第 802–803 行(`null` 目標)—— **在 debug 下不可測**,見 G-6。

### ⚠️ G-6 —— 只在 release 生效的那條分支,正好是 debug 測不到的那條

`_validate_target_writable()` 第 801 行 `assert()` 先擋,第 802–803 行的 `if target == null`
才是 release(assert 被剝除)下唯一的防線。**測試跑在 debug,所以永遠走不到第 802 行。**
**這不是撰寫者的疏失,是結構性的**;但它應該被登記,而不是被當成「已驗證」。
📌 對照 `docs/tech-debt-register.md` 已有的 assert-stripping 條目一併處理。

### ⚠️ G-7 —— `arbitrate_device_authority()` 的 provider 失效路徑零涵蓋

`cursor_state.gd` 第 345–352 行:`diagnostic_invalid_mouse_provider_count += 1`
+ 一次性 `push_error(ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED)`。
該方法自己的 doc comment 第 305–307 行明說 **「its up-front provider check」屬本 story 所有**。

**全檔對 `diagnostic_invalid_mouse_provider_count` 零斷言**(它只出現在 `state_host_test.gd` 的
AC-1 排除名單裡),對 `_safe_mouse_position()` 的 fallback(第 837–839 行)亦零斷言。

**缺了會漏掉什麼**:R6-11 的整個設計目的是「把無聲凍結變成大聲停用」——
「**錯誤只報一次、計數持續累加**」這組不變式(`ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED`
的 doc comment 與 S-1 測試向量 (c) 都明文寫著)**完全沒有測試**。
`_provider_error_reported` 這個一次性閂被刪掉、變成每幀洗版,沒有任何測試會紅。
另外 `_safe_mouse_position()` 的「回傳**最後一次成功取得**的座標」契約也未驗 ——
改成永遠回傳 `Vector2.ZERO`,36 條測試全綠。

### ✅ 正確地「缺」的一項(不要補)

`set_target(target, **true**)` 零涵蓋。**這是對的**,理由見第 6.3 節:
ADR 未定義該行為,補測試等於用測試把未定義行為釘成契約。
📌 **應登記為開放問題交架構擁有者裁決,不應補測試。**

## 9. 逐項涵蓋回報(含未查證項)

**本專案要求讓中斷表現成「少了某項」而非「某項沒問題」,故未查的一律列出並說明原因。**

| # | 派工項目 | 狀態 | 備註 |
|---|---|---|---|
| 1 | 零斷言迴圈 | ✅ **已查證** | 6 個迴圈逐個查(第 415/457/499/1344/1457/1534 行)+ 輔助類第 86 行 |
| 2 | 空路徑假性通過(`_reclaim`) | ✅ **已查證** | 全部 reset 斷言的注入來源逐條追過 |
| 3 | 通過原因可各自歸因 | ✅ **已查證** | 36 條逐條過;找到 2 條可被另一機制解釋 |
| 4 | 十條 AC 涵蓋度(獨立重算) | ✅ **已查證** | 未照抄自評;逐條回到 story 檔第 64–74 行原文拆 THEN 子句 |
| 4-特 | AC-3 / AC-54 / AC-29 / AC-32 界線是否守住 | ✅ **已查證** | 四條逐條驗;AC-32 另實地讀了 `cursor_state.gd` 第 374–396 行 |
| 5 | AC-1 排除名單放寬幅度 | ✅ **已查證** | 六個理由逐條判;存在性斷言逐行確認 |
| 6 | 三處 ADR 未定義邊界措辭 | ✅ **已查證** | 三處逐字引用;另找到第四處(R6-10 計數) |
| 7 | Testing Standards 合規 | ✅ **已查證** | 六項全查;實跑取得 0 orphans / exit 0 |
| 8 | 該測而沒測的 | ✅ **已查證** | 派工點名 6 項 + 獨立找到 7 項 |

### 🔴 明確未查證的四項

| 項目 | 為什麼沒查 |
|---|---|
| **`src/ui/cursor/cursor_state.gd` 的正式程式碼正確性** | **刻意不查** —— 派工單指定由引擎/ADR 覆核者負責,重複會浪費且可能與他的判定衝突。本覆核只在「測試有沒有驗到真東西」所需的範圍內讀它 |
| **中止路徑實際會不會跳過落旗(G-3 的機制層)** | 屬引擎覆核者領域(他已判 CONCERNS)。**本覆核只登記「這件事沒有測試證據」,不對機制本身下結論** |
| **`CursorTarget.equals()` / `CursorTarget.make()` / `CursorSurfaceRegistry` 本身的正確性** | 屬 Story 003 / 002 的驗收範圍。本檔對它們的依賴是**前提**,前提正確性不重複計入(唯一例外:G-4 指出本檔的 fixture 讓「同 id 不同 surface」無法被測到,那是本檔的限制而非 `equals()` 的問題) |
| **用「暫時破壞正式程式碼看會不會紅」實測 AC-32 tripwire** | **刻意不做。** 該結論用靜態論證即可確立(空事件陣列 + `UNINITIALIZED` 權威,兩個獨立理由各自就足夠 —— 見第 4.5 節),不需要動 `src/`。**未修改任何檔案,故無還原問題。** |

### 本覆核修改過的檔案

**只有一個**:`docs/reviews/story-007-test-evidence-review-2026-09-03.md`(本檔,新建)。
**未修改任何測試、任何 `src/` 程式碼、未執行任何 git 操作。**
執行過的唯一寫入型指令是測試執行,它產生了 `reports/report_135/`(該目錄已在 `.gitignore`)。

### 一句提醒

story 檔第 106–111 行的 `## Test Evidence` 節目前仍寫 **`Status:[ ] 尚未建立`**。
**測試檔已存在且全綠**,該節應更新 —— 並在更新時把 AC-32(UNCOVERED)與
AC-54(延後,ADVISORY 證據不存在)一併寫進去,**不要只打勾。**
