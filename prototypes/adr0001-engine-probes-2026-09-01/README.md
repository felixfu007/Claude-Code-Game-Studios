# ADR-0001 核准門檻條件一:四支引擎探針 + GdUnit4 push_error 斷言可行性

> PROTOTYPE - NOT FOR PRODUCTION / 拋棄式技術驗證
> **日期**:2026-09-01
> **執行者**:`godot-specialist`,本機 Godot 4.7.1 headless(`--headless --script` / GdUnit4 CLI)
> **成因**:`docs/architecture/adr-0001-tactical-query-atomicity-contract.md` 核准門檻
> (`docs/architecture/adr-acceptance-criteria.md`)只剩**條件一**未成立——它自列的
> 6 項 Verification Required 裡,(1)(2)(3)(4) 需要跑引擎,(5)(6) 分屬「待寫的自動化測試」
> 與「程式碼審查檢查項」,系統尚無程式碼,現在無從做,不算條件一的缺口。本次任務就是把
> (1)(2)(3)(4) 補齊,並附帶查證 Validation Criteria 第 9 項自陳的未查證項
> (GdUnit4 如何斷言 `push_error()`)。

---

## 結論總覽(全部為實測,無一項推翻 ADR)

| # | ADR 待驗證項(原文摘要) | 結果 | 支撐 log |
|---|---|---|---|
| 1 | `queue_free()` 在 4.7.1 仍延後至幀尾生效 | **成立** | `probe1_queue_free/log.txt` 第 3–5 行 |
| 2 | 跨幀 `await get_tree().process_frame` 前後 `board_version` 讀取符合中止語意 | **成立** | `probe2_await_frame_version/log.txt` 全文 |
| 3 | 型別化 `Dictionary[Vector2i, int]` 在 4.7.1 編譯無警告 | **成立** | `probe3_typed_dict/log.txt` + `log_verbose.txt` |
| 4 | 「同幀可見性」順序保證(結算發生在 await 恢復點之前,恢復時必須讀到遞增後版本) | **成立** | `probe4_same_frame_ordering/log.txt` 全文,尤其第 14 行 `P4-CRITICAL-RESUME` |

**四項全部與 ADR 的說法一致,沒有一項被推翻。** 這本身就是本次任務要交付的結論之一——
不是因為沒仔細查(下方逐項附了 log 逐字引用與判定依據),而是查完之後結果確實吻合。

**附帶項(Validation Criteria 第 9 項的未查證項)**:GdUnit4 可以斷言 `push_error()`,
API 是 `assert_error(<Callable>).is_push_error(<expected message>)`,已用真實 GdUnit4 CLI
實際跑過 2 個測試案例,`0 errors | 0 failures | 0 orphans`,exit code 0。見下方第五節。

---

## 一、要驗證的假設(逐項對應 ADR 原文)

ADR-0001 第 20 行 `Verification Required` 欄:

> (1) 確認 `queue_free()` 在 4.7.1 實際仍延後至幀尾生效……
> (2) 跨幀展開若採 `await get_tree().process_frame`,須實測確認該 await 前後 `board_version`
>     的讀取行為符合本 ADR 的中止語意;
> (3) 確認型別化 `Dictionary[Vector2i, int]`……在 4.7.1 編譯無警告;
> (4) 實測「同幀可見性」順序保證——若結算發生在某跨幀查詢的 await 恢復點之前,該查詢恢復時
>     必須讀到遞增後的 `board_version`(本 ADR 的中止語意隱含此假設,但未經實測)。

以及 Validation Criteria 第 9 項的附註:

> ⚠️ 本條落地前有一個未查證項:GdUnit4 要如何斷言 `push_error()` 被觸發,本專案尚未確認。

---

## 二、怎麼重跑

引擎路徑為本開發機的值,**非專案常數**:

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
```

### 探針 1–4(單檔 `extends SceneTree` 腳本,不需要專案)

```bash
"$GODOT" --headless --script probe1_queue_free/probe1_queue_free.gd
"$GODOT" --headless --script probe2_await_frame_version/probe2_await_frame_version.gd
"$GODOT" --headless --script probe3_typed_dict/probe3_typed_dict.gd
"$GODOT" --headless --verbose --script probe3_typed_dict/probe3_typed_dict.gd   # 額外核對警告
"$GODOT" --headless --script probe4_same_frame_ordering/probe4_same_frame_ordering.gd
```

### GdUnit4 push_error 探針(借用主專案既有的 `addons/gdUnit4/`,不修改主專案任何檔案)

在**主專案根目錄**執行(`.claude/docs/coding-standards.md` 記載的指令形狀,`-a` 改指向本探針目錄):

```bash
"$GODOT" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
  -a prototypes/adr0001-engine-probes-2026-09-01/gdunit4_push_error
```

⚠️ 這條指令會在主專案根目錄產生 `reports/report_N/`(GdUnit4 每次執行自動產生的報告,
已在主專案 `.gitignore` 第 59 行登記,不進版控)。這是執行 GdUnit4 CLI 的正常副作用,
**不是本次任務對主專案檔案的修改**——`project.godot`、`src/`、`tests/` 均未被寫入或變更,
只有 gitignored 的 `reports/` 目錄多出報告檔案。

---

## 三、逐項實測結果與判定

### 項 1:`queue_free()` 幀尾延後生效 —— 成立

**探針**:`probe1_queue_free/probe1_queue_free.gd`(`--headless --script` 直接執行,無需專案)

**逐字 log**(`probe1_queue_free/log.txt` 第 3–5 行):

```
P1-1: before queue_free() -- is_instance_valid=true, is_child=true
P1-2: immediately after queue_free(), same call stack -- is_instance_valid=true, is_child=true, is_queued_for_deletion=true
P1-3: after one process_frame await -- is_instance_valid=false
```

**判定依據**:呼叫 `queue_free()` 後,在**同一個呼叫堆疊**(沒有任何 yield/await)裡,節點
仍是合法實例、仍是父節點的子節點(`is_queued_for_deletion()` 為 true,但尚未真的被移除)。
只有在**跨過至少一個 `process_frame`** 之後,`is_instance_valid()` 才變成 false。這正是
ADR §Constraints「`queue_free()` 的幀尾延後語意」與機制三攻擊面描述(「結算步④陣亡的單位,
其節點在同一結算步內仍掛在場景樹上」)所依賴的行為。**成立,與 ADR 一致。**

### 項 2:跨幀 `await get_tree().process_frame` 前後 `board_version` 讀取符合中止語意 —— 成立

**探針**:`probe2_await_frame_version/probe2_await_frame_version.gd`

**逐字 log**(`probe2_await_frame_version/log.txt` 全文):

```
P2-A0: scenario A (no settlement between suspend and resume)
P2-A1: query starts, start_version=0
P2-A2: query resumed, resumed_version=0, changed=false (ADR requires: abort_and_recompute == false)
P2-B0: scenario B (settlement commits while query is suspended)
P2-B1: query starts, start_version=0
P2-B-settle: committed settlement synchronously (no yield), version now=1
P2-B2: query resumed, resumed_version=1, changed=true (ADR requires: abort_and_recompute == true)
```

**判定依據**:場景 A(等待期間盤面未變)恢復後讀到與起始相同的版本,`changed=false`
——查詢應被允許正常完成。場景 B(等待期間發生一次已提交結算)恢復後讀到遞增後的版本,
`changed=true`——查詢應偵測到並中止重算。兩種分支都與 ADR 機制一「`board.board_version
!= start_version` 即中止並重算」的語意直接對應。**成立,與 ADR 一致。**

### 項 3:型別化 `Dictionary[Vector2i, int]` 編譯無警告 —— 成立

**探針**:`probe3_typed_dict/probe3_typed_dict.gd`(依 ADR Key Interfaces 原樣的欄位形狀
`var _occupied: Dictionary[Vector2i, int]`,**不帶初始化字面值**,與 ADR 逐字一致)

**逐字 log**(`probe3_typed_dict/log.txt` 全文):

```
P3-1: uninitialized typed Dictionary field -- b._occupied = {  } (size=0)
P3-2: is_occupied(1,2)=true occupant_of(1,2)=42
P3-3: is_occupied(9,9)=false occupant_of(9,9)=-1
P3-4: size=2
P3-5: key=(1, 2) (is Vector2i=true) value=42 (is int=true)
P3-5: key=(3, 4) (is Vector2i=true) value=7 (is int=true)
P3-6: local typed dict literal works, size=1
```

另以 `--verbose` 重跑一次(`probe3_typed_dict/log_verbose.txt`),對輸出做
`grep -ic "warn"` 逐字比對,**命中數為 0**——沒有任何一行包含 "warn"。

**判定依據**:(a) 未初始化的型別化 `Dictionary[Vector2i, int]` 欄位預設是空的**型別化**字典
(不是 `null`,`size()==0`);(b) 讀寫、`has()`、`get()`、迭代皆正常運作,鍵確實是 `Vector2i`
型別、值確實是 `int` 型別(用 `is` 逐一驗證,不是只看 `typeof()` 數字);(c) `--verbose` 模式
下逐字搜尋 "warn" 零命中。**成立,與 ADR 一致,且無警告。**

**附帶交叉核對**:`docs/engine-reference/godot/modules/scripting-typing.md` 記載 Godot
4.7.1 **不支援巢狀型別化容器**(如 `Dictionary[K, Array[V]]`),但 ADR 用的
`Dictionary[Vector2i, int]` 鍵值皆為內建簡單型別,不觸及該限制——兩份文件的說法沒有衝突。

### 項 4:同幀可見性順序保證 —— 成立(本次最重要的一項,見下方修正過程)

**探針**:`probe4_same_frame_ordering/probe4_same_frame_ordering.gd`

**逐字 log**(`probe4_same_frame_ordering/log.txt` 全文):

```
P4-start: start_version=0, will commit settlement on _process call #4, looping 8 resumes
P4-resume[0]: frame=1 version=0 settlement_committed_by_now=false
P4-resume[1]: frame=2 version=0 settlement_committed_by_now=false
P4-resume[2]: frame=3 version=0 settlement_committed_by_now=false
P4-settle (in _process chain): frame=4 committed, version now=1
P4-resume[3]: frame=4 version=1 settlement_committed_by_now=true
P4-resume[4]: frame=5 version=1 settlement_committed_by_now=true
P4-resume[5]: frame=6 version=1 settlement_committed_by_now=true
P4-resume[6]: frame=7 version=1 settlement_committed_by_now=true
P4-resume[7]: frame=8 version=1 settlement_committed_by_now=true
P4-query-loop-complete: final version=1, start_version was 0
P4-CRITICAL-RESUME: first resume after settlement -> frame=4 version=1 (expect 1) -> OK
P4-FINAL-VERDICT: settlement_committed_at_frame=4, first_post_settle_saw_increment=true, no_premature_leak=true, records=[[1, 0, false], [2, 0, false], [3, 0, false], [4, 1, true], [5, 1, true], [6, 1, true], [7, 1, true], [8, 1, true]]
```

**探針設計(為何是這個形狀)**:一個查詢在迴圈裡連續 `await get_tree().process_frame`
8 次(模擬一趟多幀展開的跨幀查詢,每次恢復都重新讀一次 `board_version`,對應 ADR 機制一的
恢復點檢查),而結算(`board_version += 1`)被安排在**第 4 次 `_process()` 呼叫**時、
透過 `_process` 鏈執行(對應 ADR 機制二「結算步執行於 `_process` 鏈」)——**刻意不擺在
第 1 次**,以避免只驗到一個可能是啟動時序巧合的特例。

**判定依據——逐點檢查兩個方向**:
- **有沒有「洩漏過早」**:結算前的三次恢復(frame 1–3)全部讀到 `version=0`,沒有任何一次
  提前看到還沒發生的結算。
- **有沒有「延遲一拍」**:結算發生在 `frame=4` 的 `_process()` 呼叫裡;**同一個 `frame=4`**
  的恢復(`P4-resume[3]`)已經讀到 `version=1`——不是要等到 `frame=5` 才看到。這是本項
  最關鍵的一行:它證明 `process_frame` 訊號(用來喚醒 await)在同一幀內**晚於**
  `_process()` 鏈執行,因此結算(`_process` 鏈)先於恢復點(`process_frame` 訊號)完成,
  查詢恢復時必然讀到已遞增的版本。
- 之後每一次恢復(frame 5–8)持續讀到 `version=1`,沒有任何回退或不一致。

**這個順序保證是 ADR 本身沒有明講、但撐起 ADR 中止語意成立的具體引擎機制**:ADR 只說
「結算執行於 `_process` 鏈」與「跨幀用 `await get_tree().process_frame`」,沒有明講這兩者
在同一幀內的相對順序——本探針把這個沒明講的假設變成一個有 log 佐證的事實。**成立,且是
支撐 ADR 機制一/二能夠協同運作的關鍵引擎行為,建議 ADR 或 `docs/engine-reference/godot/`
未來補上這條(不在本次任務的檔案權限內,僅在此登記)。**

#### 探針設計上的一次自我修正(誠實記錄,不是隱藏重跑)

本探針第一版設計有缺陷:它試圖用 5 個獨立 trial、各自只 `await` 一次,分別把結算安排在
第 1、2、3、4、5 次 `_process()` 呼叫上,想藉此測試「不同幀距」下順序是否都成立。但因為
每個 trial 的查詢是在**上一個 trial 恢復的同一個訊號處理鏈內**同步重啟,新查詢會直接
搭上「這一幀已經要發生、還沒發出的」`process_frame` 訊號,而不是等到下一幀——導致
trial 2–5 的查詢在結算真正發生前就已經恢復,回報「settlement had NOT happened yet at
resume time -- inconclusive」。**這是探針本身的時序假設寫錯,不是 ADR 或引擎的問題**——
5 個 trial 只有 trial 1(結算排在第 1 次 `_process()`)真的測到東西。已捨棄該版本,改寫成
本節描述的「單一查詢、迴圈 8 次恢復、結算安排在迴圈中段(第 4 次而非第 1 次)」的形狀,
這樣才真正測到「結算不是發生在查詢第一次恢復前」的情況。**兩版探針都留有可重跑的
`.gd` 檔**(目前目錄裡的是修正後的版本;第一版的問題與輸出已完整記錄在上一段,不再另外
保留失效的檔案,因為它會被誤認為是有效證據)。

---

## 四、對 ADR 文字本身的檢查結果

**沒有任何一句 ADR 原文被本次探針推翻。** 逐句對照如下(每項待驗證條目對應到 ADR 內文
的哪一句,以及該句是否仍然成立):

| ADR 內文位置 | 句子 | 本次探針結果 |
|---|---|---|
| 第 46 行(Constraints) | 「`queue_free()` 的幀尾延後語意……是引擎穩定的既有行為」 | 成立,見項 1 |
| 第 79 行(機制一) | 「跨幀恢復時比對 `board.board_version != start_version` 即中止並重算」 | 成立,見項 2、4 |
| 第 105 行(機制二) | 「結算步執行於 `_process` 鏈」 | 成立,且項 4 進一步確認了它與 `process_frame` 訊號的相對順序 |
| 第 125 行(機制三攻擊面) | 「一個在結算步④陣亡的單位,其節點在同一結算步內仍掛在場景樹上」 | 成立,見項 1 |
| 第 113 行(機制三) | `occupied` 由 `Dictionary[Vector2i, unit_id]` 承載(`unit_id` 即 `int`) | 成立,見項 3 |
| Validation Criteria 第 9 項附註 | 「GdUnit4 要如何斷言 push_error() 被觸發,本專案尚未確認」 | **已查證,見下方第五節**——不是推翻,是把「未查證」補成「已查證且可行」 |

---

## 五、附帶項:GdUnit4 斷言 `push_error()` 的做法(已實機驗證)

**API**:`GdUnitTestSuite` 內建的全域函式 `assert_error(<Callable>) -> GdUnitGodotErrorAssert`,
搭配 `.is_push_error(<expected message>)`。原始碼位置(`addons/gdUnit4/`,本專案既有安裝,
未修改):

- `addons/gdUnit4/src/GdUnitGodotErrorAssert.gd` 第 54–59 行:介面宣告
  `func is_push_error(expected_error: Variant) -> GdUnitGodotErrorAssert`
- `addons/gdUnit4/src/asserts/GdUnitGodotErrorAssertImpl.gd` 第 125–139 行:實作,內部呼叫
  `_callable.call()` 並攔截期間的 `push_error()` 記錄,比對訊息字串
- `addons/gdUnit4/src/GdUnitTestSuite.gd` 第 734 行:`assert_error(current: Callable)` 的
  全域進入點

**用法**(見 `gdunit4_push_error/board_write_guard_probe_test.gd`):

```gdscript
await assert_error(func() -> void: board.board_version = 999) \
    .is_push_error("board_version is read-only outside BoardProbe; rejected external write of 999")
```

**實際執行結果**(`gdunit4_push_error/log.txt`,指令見第二節):

```
res://prototypes/.../board_write_guard_probe_test.gd > test_external_write_triggers_push_error_and_value_unchanged PASSED 13ms
res://prototypes/.../board_write_guard_probe_test.gd > test_baseline_no_push_error_when_untouched PASSED 7ms
Statistics: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 45ms
Exit code: 0
```

**兩件事都在 log 裡被獨立確認**(不是只信任「PASSED」字樣本身):
1. log 裡直接印出了真實的 `push_error()` 輸出與完整 GDScript 呼叫堆疊
   (`ERROR: board_version is read-only outside BoardProbe; rejected external write of 999`
   ……`GdUnitGodotErrorAssertImpl.gd:132` → `is_push_error` → 測試函式本身),證明
   `is_push_error()` 底層真的攔截到了那次呼叫,不是字串比對巧合通過。
2. 第二個測試(`test_baseline_no_push_error_when_untouched`)作為對照組,驗證
   `assert_error(...).is_success()` 在**沒有** `push_error()` 發生時也能正確判斷「無錯誤」
   ——證明這個斷言機制不是恆為 pass。

**回應 exit code 誤讀風險**(`.claude/docs/coding-standards.md` 提醒過 exit 101 = 有警告、
exit 0 也可能是「根本沒跑到測試」的假綠燈):本次 log 明確印出 `2 test cases`、
`0 errors | 0 failures | 0 orphans`,`Statistics` 與 `Overall Summary` 兩處數字一致,
`Executed test suites: (1/1)`、`Executed test cases: (2/2)`——確認測試**真的被執行**,
不是掃描到空目錄後的靜默通過。

**結論**:ADR Validation Criteria 第 9 項自陳的未查證項**已解除**。落地時可直接沿用
`gdunit4_push_error/board_write_guard_probe_test.gd` 的斷言寫法。

---

## 六、逐項涵蓋範圍與已知簡化

| 項目 | 查了什麼 | 沒查什麼 |
|---|---|---|
| 項 1 | 同呼叫堆疊內是否延後、跨一次 `process_frame` 後是否真的釋放 | 只測了單一節點單一子層級;未測試巢狀多層節點樹、`queue_free()` 在同一幀內被呼叫多次、或節點自身持有其他跨幀協程時的交互 |
| 項 2 | 版本相等(場景 A)與版本不等(場景 B)兩個分支各跑一次 | 只跑一次而非多次重覆(單執行緒 GDScript 無競態,理論上結果應恆定,但沒有做多次重跑的統計佐證) |
| 項 3 | 欄位讀寫、迭代、鍵值型別、`--verbose` 警告掃描 | 沒有測試「指派錯誤型別的鍵/值」時的拒絕行為(例如塞入 `Vector3` 當鍵);ADR 未要求這一項,但落地實作前建議額外補一則 |
| 項 4 | 8 次恢復迴圈、結算安排在中段、洩漏方向與延遲方向都個別檢查 | 只測了「一個查詢 + 一次結算」;沒有測試多個並行查詢共享同一 board 時是否都同時看到遞增(理論上應該一致,因為都是讀同一個屬性,但沒有另外用多查詢並行的形狀複驗) |
| 附帶項(GdUnit4） | `is_push_error()` 的存在性、正確比對訊息、對照組驗證「非恆為 pass」 | 沒有測試 `is_push_error()` 對**多個** `push_error()` 呼叫、或訊息不完全比對(部分字串/正規表達式)時的行為;ADR 落地時若需要模糊比對,需另外查 `GdUnitArgumentMatchers` |

**已知簡化(全域)**:
- 全部在 **debug / headless** 下量測,**release 建置行為未查證**(與
  `prototypes/adr0001-board-property-spike-2026-09-01/README.md` 记载的既有限制同一類)。
- 所有探針都是**單機單次執行**,不是統計上嚴謹的多輪重跑;但項 1/3/4 測的是結構性
  引擎行為(非機率性競態),單次乾淨的正反面檢查足以支撐「成立」的判定。
- `gdunit4_push_error/` 的測試類別 `BoardProbe` 是鏡射 ADR 形狀的最小重現,不是真正的
  `Board` 類別(尚不存在於 `src/`),落地時斷言字串需要對照屆時 `board.gd` 的實際訊息。

---

## 七、狀態

**四項引擎待驗證項與附帶的 GdUnit4 查證項均已完成(2026-09-01)。** ADR-0001 核准門檻
條件一的引擎驗證缺口已補齊;是否核准仍待管理者依 `docs/architecture/adr-acceptance-criteria.md`
其餘條件(條件二至五)裁決,不在本次任務範圍內。
