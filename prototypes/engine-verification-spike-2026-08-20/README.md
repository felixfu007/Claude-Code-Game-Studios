# Spike:引擎行為驗證 —— 解鎖 ADR-0002 進入 `Accepted`

> **PROTOTYPE — NOT FOR PRODUCTION / 拋棄式技術驗證,不是實作,不進 `src/`**
>
> **日期**:2026-08-20
> **Status**:**in-progress** —— 已建置完成,**尚未執行**。等待人類測試者在 Godot 中跑 Phase 1。
> 結果回填於本檔末尾「Findings」節;該節填妥後本 spike 即轉為 **concluded**。
>
> **執行者分工**:agent 寫這份 spike;**人類測試者在 Godot 裡執行**,把輸出貼回對話。
> 本 agent 的環境沒有安裝 Godot(`which godot` 無結果),無法自行執行 ——
> 比照 `prototypes/cursor-reclaim-godot-spike-2026-08-05/` 的既有分工。

---

## 為什麼有這份 spike

六輪 `/architecture-review` 下來,五份 ADR **全部停在 `Proposed`**,而依 `docs/CLAUDE.md`,
引用 `Proposed` ADR 的 story 會被**自動阻擋** —— 這是比任何單一涵蓋缺口都更接近實作路徑的
結構性阻擋,且已連續四輪未動。

`ADR-0002`(好感度數值池)是五份裡最接近可核准的一份:

| 條件 | 狀態 |
|---|---|
| `Depends On` | **None** —— 無任何上游 `Proposed` 阻擋 |
| 需求涵蓋 | 24 項 `TR-affinity-*`:22 ✅ / 2 ⚠️ / **0 缺口**(第五輪獨立推導) |
| 那 2 項 ⚠️ | 成因都在**別的系統**,不是 ADR-0002 修得掉的 |
| 跨 ADR 銜接缺口 | C1 / C3 已關閉(第五輪覈實) |
| `godot-specialist` 覆核 | 2026-08-18 執行,零 BLOCKING 級機制問題 |
| **唯一硬阻擋** | **5 項 Verification Required,其中 3 項真的擋、2 項 ADR 自己宣告不影響可實作性** |

那 3 項全部是純腳本、可 headless 跑、加起來不到二十行 GDScript。**這份 spike 就是那三項。**

順帶把 ADR-0005 幾項同樣不需要完整實作就能驗的項目一起打掉,以及測試基礎設施的六項未驗證。

### 一項必須先講清楚的更正

ADR-0002(第 22、254 行)、ADR-0003(第 17 行)、**ADR-0005(第 121 行,寫在 `Constraints` 裡)**、
`tests/README.md` 都寫了「**本專案**無 Godot 執行環境可實測」。

**這句話是錯的。** `prototypes/cursor-reclaim-godot-spike-2026-08-05/` 裡有一個完整可跑的
Godot 4.7 專案,含 shader cache 與 editor layout —— 它真的被開起來跑過,E1 那個
「100% 可重現」的結論就是這樣得到的。該 spike 的 README 寫得很精確:

> **執行者**:人類測試者於 Godot Editor 手動執行(**本 agent 的環境沒有安裝 Godot**)

**「agent 跑不了」在後續被壓縮成了「跑不了」。** 前者是分工問題,後者是能力問題,
差別是「等實作才能驗」還是「現在就能驗」。ADR-0005 第 121 行把它列為**架構約束** ——
那是決策內容,已列入第四次修訂待改清單。

---

## Phase 1 —— 零外部依賴(先跑這個)

### 怎麼跑

**路徑 A(建議,比照 2026-08-05 先例)**

1. 開 Godot 4.7.1 → Import → 選 `prototypes/engine-verification-spike-2026-08-20/project.godot`
2. 按 **F5**(主場景已設為 `VerificationScene.tscn`)
3. 程式會自己跑完並結束
4. 把 **Output 面板的全部內容**貼回對話 —— **包含紅色錯誤訊息**

**路徑 B(headless,不開編輯器)**

```bash
<Godot 執行檔路徑> --headless --path prototypes/engine-verification-spike-2026-08-20
```

### 如果 Debugger 分頁自己跳出來

**那是預期行為,不是壞掉。** 有幾個檔案是刻意寫成編譯失敗的,Godot 的偵錯器會攔截 parser error
並切到 Debugger 分頁。處理方式:**直接切回 Output 分頁**,報告在那裡。若程式停住,按繼續(F7)或
停止(F8)都可以 —— 已經印出來的部分就是資料。

### ⚠️ 貼回來時最重要的一件事

**引擎的紅色錯誤訊息是這份 spike 的主要產出,不是雜訊。**

有六個檔案是**刻意寫成可能編譯失敗**的(四個 `@abstract` 變體 + 兩個錯誤型別的
Dictionary 寫入)。「哪幾個失敗、錯誤訊息怎麼說」就是答案本身。看到 error 不要以為
spike 壞了 —— 報告會逐項印出 `COMPILED OK` / `FAILED TO COMPILE` 幫你對照。

還有兩項**可能讓程式硬中止**,各自前面有 `RISKY 1/2`、`RISKY 2/2` 橫幅。
**報告在橫幅之後就斷掉,本身就是答案**(代表該操作造成硬中止)。照樣把輸出貼回來。

### 這一批驗什麼

| 檢查 | 對應項 | 為什麼重要 |
|---|---|---|
| **A1** 型別化 `Dictionary[K,V]` 的鍵值檢查在**哪一層**生效 | ADR-0002 VR #1 | 分辨「編譯期擋下 / 執行期擋下 / 靜默接受」。若是靜默接受,ADR-0002 機制四所謂的型別安全只是靜態分析,執行期沒有防線 |
| **A2** `enum` 當 `Dictionary` 鍵的雜湊/相等語意 | ADR-0002 VR #2 | 真正的問題是**「用裸 `int` 查得到嗎」**。若 enum 鍵底層就是 int,型別化字典的鍵檢查對此無能為力。另驗兩個不同 enum 家族的相同序數值會不會互相覆蓋 |
| **A3** `pow(0.0, 0.0)` 與 `0.0 ** 0.0` | ADR-0002 VR #3 | GDD Formulas 明文「不可依賴引擎預設行為」。**即使回傳 1.0,公式一/二仍應顯式特判** —— 這一項決定的是特判的*理由*怎麼寫 |
| **C1** `@abstract func` 回傳 `bool`/`float`/`void`/`Vector2` 各一檔 + `Array[T]` 對照組 + 「類別內同時有 signal」的組合 | ADR-0005 VR #1、**R4-2** | 第五輪明文要求「三種各建一檔分別編譯,不是只測一種」。`Vector2` 那一檔最關鍵 —— R4-2 這個 BLOCKING 修法就是把 `diagnostic_seed_position()` 改標 `@abstract` 回傳 `Vector2` |
| **C2** `Callable.is_valid()` 對已釋放綁定物件的行為,**具名綁定 vs lambda 隱式捕獲 `self`** | ADR-0005 **VR #15**、S-1、發現 G | S-1 的整套防禦(`_safe_mouse_position()` 每次取值前 `is_valid()`)完全押在這上面。兩者若行為**不一致**,就證實發現 G,且證明第三次修訂改採具名綁定是**必要**而非只是比較明確 |
| **C3** Agile Event Flushing 的設定鍵**真名** | ADR-0005 VR #3 | 不只驗證推測值,而是**列舉 `input_devices/` 底下所有實際存在的鍵**,直接找出真名。機制七的 `has_setting()` 防衛無論結果如何都不移除 |

### 結果回寫到哪

| 檢查 | 回寫目標 |
|---|---|
| A1 / A2 / A3 | `docs/architecture/adr-0002-...md` 的 `Engine Compatibility → Verification Required` 欄,逐項標為已查證並附結果 |
| C1 | ADR-0005 VR #1、ADR-0004 共用的同一項風險 |
| C2 | ADR-0005 VR #15;連帶決定 Validation Criteria #18 驗的假設成不成立 |
| C3 | ADR-0005 VR #3;若掃出真名就換掉推測值(**防衛不移除**) |

**A1 / A2 / A3 三項有結果之後,ADR-0002 就沒有已知的技術阻擋了** ——
剩下的是「核准準則」這個流程問題(見下)。

---

## Phase 2 —— 需要先裝 GdUnit4

對應 `tests/README.md`「待驗證項」六項中的 **1 / 3 / 4 / 5 / 6**。
(第 2 項 `gdUnit4-action@v1` 對 4.7.1 的支援只能在 CI 上驗,不在本 spike 範圍。)

### 怎麼跑

1. 在**本 spike 專案**裡:AssetLib → 搜尋 `gdUnit4` → 下載安裝
   (或從 https://github.com/MikeSchulze/gdUnit4 下載,解壓到 `addons/`)
2. Project → Project Settings → Plugins → 啟用 GdUnit4
3. 在 FileSystem 面板點 `scenes/Phase2GdUnitProbe.tscn`,按 **F6**(執行目前場景)
4. 把 Output 全部貼回

**沒裝也可以跑** —— 探針會如實回報「未安裝」,並列出 `res://addons/` 的實際內容,不會失敗。

### 為什麼是純內省、不寫真的測試

寫測試需要先假設 `GdUnitTestSuite` 這個名字、以及 `assert_failure(Callable).is_failed()`
這個簽章 —— 而**那兩件事正是待驗證項本身**。假設錯了會得到編譯期錯誤,而編譯期錯誤
沒辦法告訴我們「正確的名稱是什麼」。內省則會直接把實際存在的東西列出來。

探針會印出:`res://addons/` 的實際目錄結構(**含大小寫**,四個候選路徑差別就在這)、
所有含 "gdunit" 的全域 `class_name` 及其 `base`、CLI 入口的完整方法清單與 `run_tests()`
的**實際回傳型別**、以及 `GdUnitTestSuite` 上所有含 "assert" 的方法簽章。

### 這一批的用途

跑出結果後就能**拆掉 CI 那個暫時性守衛** —— 目前 `.github/workflows/tests.yml` 在
`project.godot` 不存在時跳過測試並直接成功,**綠燈不代表測試通過**。

---

## 這份 spike 不是什麼

- **不是** `AffinityDataPool` 的實作。沒有 `append_record()`、沒有公式、沒有權杖、沒有
  `Mutex`。只抽出三個開放問題各自需要的最小骨架。
- **不是** ADR-0005 的實作。`@abstract` 那六檔只有簽章,沒有任何行為。
- **不涵蓋** ADR-0005 Day-1 spike 的第一項:「`_input()` 是否保證整幀派發完畢才進
  `_process()` 鏈」。那一項是**全案最該優先驗證的單點失效點**(不成立則機制五與機制六
  一併瓦解),但它需要真實輸入事件與逐幀儀器化,規模接近 2026-08-05 那份 spike,
  應獨立成一份。**不要因為它不在這裡就以為它不重要 —— 恰恰相反。**

## 檔案

```
project.godot
scenes/
  VerificationScene.tscn        # Phase 1 主場景(F5)
  Phase2GdUnitProbe.tscn        # Phase 2(F6)
scripts/
  verification_runner.gd        # Phase 1 主控;逐項即時列印,風險項排最後
  affinity_types.gd             # 逐字照抄 ADR-0002 機制二
  affinity_record.gd            # 逐字照抄 ADR-0002 機制三
  a1_v_a_simple_dict.gd         # A1(a):Dictionary[enum, int] 非巢狀
  a1_v_b_typed_array.gd         # A1(b):Array[自訂類別] 單獨使用
  a1_v_c_untyped_inner.gd       # A1(c):候選替代——內層裸 Array
  a1_v_d_wrapper_class.gd       # A1(d):候選替代——內層包進 RefCounted(兩層型別都保住)
  a1_v_e_nested_known_fail.gd   # A1(e):**故意保留的失敗案例**,機制四原宣告(永久證據)
  affinity_record_list.gd       # (d) 用的包裝類別
  a1_typed_dict_bad_key_static.gd     # A1:靜態可見的錯誤鍵(只 load 不執行)
  a1_typed_dict_bad_value_static.gd   # A1:靜態可見的錯誤值(只 load 不執行)
  a1_typed_dict_bad_dynamic.gd        # A1:經 Variant 藏起來的錯誤(RISKY 2)
  a1_introspect.gd              # A1:容器內省,隔離成一檔以免拖垮 runner
  a2_enum_key_probe.gd          # A2
  a3_pow_zero_probe.gd          # A3
  c1_pass_body_record.gd        # C1:**故意保留的錯誤寫法**,參考庫範例的逐字照抄(永久證據)
  c1_bare_array_control.gd      # C1 對照組:裸簽章形式
  c1_bare_bool.gd
  c1_bare_float.gd
  c1_bare_void.gd
  c1_bare_vector2.gd            # C1:R4-2 BLOCKING 修法所依賴者
  c1_bare_with_signal.gd        # C1:MouseReclaimPolicy 的實際形狀(signal + 多個抽象方法)
  c1_syntax_inline.gd           # C1:@abstract 與 func 同一行的變體
  c1_subclass_complete.gd       # C1:ADR-0004 VR #6a 對照組
  c1_subclass_incomplete.gd     # C1:ADR-0004 VR #6a,故意漏實作
  c2_callable_probe.gd          # C2 探針節點
  phase2_gdunit_probe.gd        # Phase 2 主控
```

### 四條刻意的設計原則(別「順手優化」掉)

1. **逐項即時列印,不緩衝。** 有兩項可能硬中止;緩衝輸出會讓中止把前面全部結果一起吃掉。
2. **風險項排最後並加橫幅。** 報告斷在哪裡本身就是資料。
3. **任何「是否存在於 4.7.1」未經查證的 API,一律隔離到獨立檔案用 `load()` 動態載入。**
   靜態型別下呼叫不存在的方法是*編譯期*錯誤,會把整個 runner 弄爆。
   隔離後,「那一檔編譯失敗」是一筆乾淨的結果。
4. **`load()` 的回傳值一律用未標型別的 `var` 承接。** `load()` 的靜態回傳型別是
   `Resource`,對它呼叫 `build()`/`run()` 會編譯失敗;用 Variant 承接才走執行期動態派發。

> 第 3、4 條是寫這份 spike 的過程中實際踩到的 —— 初版把內省寫在 runner 裡、
> 用 `:=` 承接 `load()`,兩者都會讓「驗證工具自己」犯下它要驗證的那類錯誤。

---

## 跑完之後

1. **把結果回寫進各 ADR 的 Verification Required 欄**(見上方對照表)
2. **`/architecture-decision` 把 ADR-0002 推上 `Accepted`** —— 這會是全專案第一份
3. **補一份 ADR 核准準則** ——目前全框架**五個消費者、零個生產者**:
   `/gate-check` 要求 `Accepted`、`/story-readiness` 遇 `Proposed` 一律 BLOCKED、
   `/create-control-manifest` 只讀 `Accepted`、`/create-stories` 依此分支,
   而 `/architecture-decision` 明文「**新 ADR 一律 `Proposed`,不要問使用者狀態**」。
   **沒有任何 skill 會產生 `Accepted`。** 用 ADR-0002 這一份實際走一遍,
   把真正遇到的條件寫成準則,比憑空先寫一份準則再套上去可靠。

---

## Findings

> **狀態:尚未執行,本節為空。**
>
> 依 `.claude/rules/prototype-code.md`,結論寫進這一節之後,本 spike 即轉為 **concluded**,
> 且**不得再擴充** —— 後續若需要驗證別的東西,另開一份新 spike。
>
> 填寫時每一項請保留三欄:**實測輸出原文** / **判定** / **回寫到哪一份文件的哪一欄**。
> 原文必須保留,不要只寫結論 —— 六輪審查的經驗是「結論被壓縮後失真」出現過四次
> (最近一次就是「agent 跑不了 Godot」被壓縮成「本專案跑不了 Godot」,寫進了三份 ADR)。

### 已確定的結果(第一次執行,2026-08-20)

#### F-1 · 參考庫的 `@abstract` 範例在 4.7.1 是 parser error · **高**

**實測輸出原文**(Godot 4.7.1.stable,編輯器 F5):

```
Error at (8, 5): An abstract function cannot have a body.
Parser Error: An abstract function cannot have a body.
  res://scripts/c1_abstract_array_control.gd
```

失敗的那一檔是**逐字照抄** `docs/engine-reference/godot/current-best-practices.md`
第 41–49 行的範例:

```gdscript
@abstract
func get_attack_pattern() -> Array[Attack]:
    pass  # Subclasses MUST override
```

**判定**:該範例**錯誤**。`@abstract func` 不得有函式主體,連 `pass` 都不行。

**影響面(實查)**:

| 位置 | 事實 |
|---|---|
| `current-best-practices.md` 第 41–49 行 | 錯誤範例本身 |
| ADR-0004 | 10 處 `@abstract`,其中 5 處帶 `pass` 主體(機制一 `SaveIOBackend`) |
| ADR-0005 | 29 處 `@abstract`,其中 8 處帶 `pass` 主體(機制八 + Key Interfaces) |
| ADR-0004 第 44、71 行 | 明文寫「唯一依據是 `current-best-practices.md` 的範例」 |
| **第三輪 `/architecture-review`** | **把該假設由「印象」升級為「已查證」,依據就是逐字比對這個錯誤範例** |

**兩件事因此成立**:

1. **ADR-0004 的 VR #6 問對了問題。** 它明文寫「機制一採無冒號裸簽章形式,但參考庫範例採
   冒號 + `pass`,**兩者互斥**,無法在本環境確認何者正確」——現在確認:**裸簽章是對的**。
2. **第三輪那次「升級為已查證」是無效的。** 它比對的對象本身是錯的。這是六輪來第一次抓到
   **參考庫本身有錯**,而非 ADR 有錯 —— 先前所有輪次都預設參考庫是可信基準。

**回寫目標**:`current-best-practices.md`(修正範例並註記實測日期)、ADR-0004 VR #6 與機制一、
ADR-0005 VR #1 與機制八 + Key Interfaces、`docs/architecture/architecture-review-*` 的
「已查證」宣稱。**以上皆屬決策/參考文件內容,不在本 spike 動。**

> **仍待確認**:裸簽章形式本身是否對全部四種回傳型別都合法。第一次執行時全部六檔都用了
> 錯誤形式,所以**回傳型別那一問等於還沒被回答**。第二次執行才會有答案。

#### F-2 · `pow(0.0, 0.0)` 回傳 `1.0`,與 `0^0 := 1` 慣例一致 · **已關閉** · ADR-0002 VR #3

**實測輸出原文**(Godot 4.7.1.stable):

```
pow(0.0, 0.0)              = 1.0
0.0 ** 0.0                 = 1.0
pow(0, 0)                  = 1.0
is_equal_approx_to_1       = true
pow(0.0, 1.0)              = 0.0
pow(1.0, 0.0)              = 1.0
```

**判定**:三種寫法(`pow(float,float)`、`**` 運算子、`pow(int,int)`)全部回傳 `1.0`,
相鄰邊界行為正常。

**但這不解除顯式特判的義務。** GDD Formulas 邊界值測試總表明文要求「不可依賴引擎預設行為」,
該要求管的是**依賴關係**而非**數值是否碰巧相符**。本項改變的是特判的**理由措辭**:
由「引擎行為未知,必須自己定義」改為「引擎行為經 2026-08-20 實測與慣例一致,但本專案不
建立對它的依賴」。

**回寫目標**:ADR-0002 VR #3 標為已查證;公式一/二的特判保留,理由改寫。

---

#### F-3 · 型別化 `Dictionary` 的 enum 鍵在執行期**沒有任何型別保證** · **中高** · ADR-0002 VR #2

**實測輸出原文**:

```
lookup_with_enum           = inserted_with_enum
lookup_with_raw_int_0      = inserted_with_enum
enum_C1_C2_int_value       = 0
typeof_enum_key            = 2
typeof_int_literal         = 2
hash_enum                  = 720020139
hash_int_0                 = 720020139
stored_key_typeof          = 2
cross_enum_family_size     = 1
cross_enum_final_value_at_0 = from_Character
```

**判定**,三項各自獨立成立:

1. **裸 `int` 直接命中 enum 鍵** —— `lookup_with_raw_int_0` 取回了以 `Pair.C1_C2` 插入的值。
2. **enum 在執行期就是 `int`** —— `typeof` 皆為 `2`(`TYPE_INT`),`hash()` 完全相同
   (`720020139`),儲存後取回的鍵型別也是 `int`。沒有任何執行期資訊可用來區分兩者。
3. **不同 enum 家族的相同序數值會互相覆蓋** —— `cross_enum_family_size = 1`:
   `Pair.C1_C2`(=0)與 `Character.CHARACTER_1`(=0)是**同一個鍵**,後插入者勝出。

**對 ADR-0002 的意義**:`Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]` 的鍵型別檢查
**只到靜態分析為止**。機制四目前安全,是因為 `_records`(以 `Pair` 為鍵)與 `_death_marks`
(以 `Character` 為鍵)**剛好是兩張結構獨立的表** —— 那是設計碰巧帶來的安全,不是型別系統
保證的安全。ADR-0002 若在任何地方把兩個 enum 家族放進同一張表,會靜默資料損毀。

**這正是本 ADR 自己反覆主張的「結構保證優於紀律要求」的反例**:目前靠的是「沒有人會把兩種
鍵混在一起」這條紀律,而型別標註看起來像是結構保證,實際上不是。

**回寫目標**:ADR-0002 VR #2 標為已查證;機制四新增明文限制「兩張表必須維持結構獨立,
不得合併,亦不得引入第三個以其他 enum 家族為鍵的表與之共用容器」;
考慮登記為 registry 的 forbidden pattern。

---

#### F-4 · Agile Event Flushing 的鍵名 ADR 猜對了 · **已關閉** · ADR-0005 VR #3

**實測輸出原文**:

```
ADR-0005 推測的鍵名 : input_devices/buffering/agile_event_flushing
has_setting(推測值)  : true
...
input_devices/buffering/agile_event_flushing = false
```

**判定**:鍵名**正確**,且現值為 `false` —— 正是機制七要求的狀態(Agile Event Flushing 必須關閉)。

**`has_setting()` 防衛不移除。** 機制七的防衛存在理由是「鍵名未經查證」,現在理由變成
「鍵名可能隨版本改變」——防衛的價值不變,只是理由更新。ADR 可把推測值升格為已查證值。

**順帶掃到、沒人問過但相關的鍵**:`input_devices/compatibility/legacy_just_pressed_behavior = false`。
ADR-0005 機制四/六大量依賴 `is_action_just_pressed()` 語意,這個相容性開關的存在與預設值
值得記一筆,但本 spike 未探測其影響。

---

#### F-5 · spike 自身的排序缺陷(記錄下來,因為它是同一類錯誤)· 流程

第二次執行在 C1 的第 (0) 項就停住 —— 那一項是**已知會編譯失敗**的檔案,debugger 攔截
parser error 並暫停執行,後面全部檢查沒跑到。

**這違反了本 spike 自己 README 寫的設計原則第 2 條**(「風險項排最後」)。我把「可能硬中止」
理解成只有執行期崩潰,漏掉了「載入一個編譯失敗的檔案也會讓 debugger 暫停」。

**修法**:四個預期失敗的 `load()`(參考庫錯誤形式、漏實作子類別、兩個錯誤型別字面量)
全部移到新增的 `RISKY 0` 區,乾淨區段因此可以完整跑完。並在進入 RISKY 區前明文提示
「debugger 會暫停,按繼續(F7)」。

**留下這筆記錄的理由**:這與 ADR 系列四輪來反覆出現的模式同型 ——
**規則寫對了,但套用時漏掉一種情境**。

#### F-6 · ADR-0002 機制四的核心資料結構在 4.7.1 **無法編譯** · **BLOCKING** · ADR-0002 VR #1

**實測輸出原文**(Godot 4.7.1.stable,第三次執行):

```
ERROR: res://scripts/a1_typed_dict_ok.gd:10 - Parse Error: Nested typed collections are not supported.
ERROR: modules/gdscript/gdscript_resource_format.cpp:46 - Failed to load script
       "res://scripts/a1_typed_dict_ok.gd" with error "Parse error".
```

失敗的宣告是 ADR-0002 機制四的逐字照抄:

```gdscript
var _records: Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]
```

**判定**:**4.7.1 不支援巢狀型別容器。** 型別化 `Dictionary` 的值型別不能是型別化 `Array`。

**這是 ADR-0002 的核心儲存結構** —— `TR-affinity-001` 明文要求「須用具型別類別而非
`Array[Dictionary]`」,而機制四對該要求的答案就是這一行。它寫不出來。

**與本次作業目的的關係(必須誠實記錄)**:這份 spike 的目的是關掉 ADR-0002 最後三項 VR、
好讓它成為全專案第一份 `Accepted` 的 ADR。結果發現它的核心宣告無法編譯。

**這不是壞消息,這正是「核准前必須實測」的證據。** 若當初照原計畫直接把 ADR-0002 推上
`Accepted`,再由 `/create-stories` 產出 story、`/dev-story` 開始實作,這一行會在第一天就爆,
而那時它已經是「已核准的架構決策」,回頭修的成本遠高於現在。

**候選替代方案(第四次執行測)**:

| 選項 | 宣告 | 代價 |
|---|---|---|
| (a) | `Dictionary[Character, int]` | 非巢狀,`_death_marks` 本來就是這個形式,應可用 |
| (b) | `Array[AffinityRecord]` 單獨使用 | 確認型別化陣列本身沒問題 |
| (c) | `Dictionary[Pair, Array]` | **放棄內層元素型別**,append 任何東西都不被擋 |
| (d) | `Dictionary[Pair, AffinityRecordList]` | 內層包進 `RefCounted`,值型別是「類別」而非「容器」→ 理論上不觸發巢狀限制,**兩層型別都保住**;代價是多一層 `.items` 與一個額外 `class_name` |

**若 (d) 成立,那就是機制四應改採的形式** —— 它是唯一同時保住外層鍵型別與內層元素型別的選項。

**但無論選哪一個,都不改變 F-3 的結論**:enum 鍵在執行期就是 `int`,外層鍵的型別保證
本來就只到靜態分析為止。**兩項合起來看,機制四所宣稱的「型別安全」需要整段重寫**,
而不是換個宣告就好。

**回寫目標**:ADR-0002 機制四(宣告形式 + 型別安全宣稱)、VR #1、`TR-affinity-001` 的
涵蓋判定;registry 的相關 state ownership 條目。**屬決策內容,不在本 spike 動。**

---

#### F-7 · `@abstract` 裸簽章對全部回傳型別皆合法 · **已關閉** · ADR-0005 VR #1 / R4-2、ADR-0004 VR #6

**實測輸出原文**(第三次執行):

```
  ── (1) 裸簽章形式,各回傳型別分別編譯 ──
    [COMPILED OK       ]  Array[T]   ←對照組
    [COMPILED OK       ]  bool
    [COMPILED OK       ]  float
    [COMPILED OK       ]  void
    [COMPILED OK       ]  Vector2    ←R4-2 BLOCKING 修法所依賴者
    [COMPILED OK       ]  類別內同時有 signal + 兩個 @abstract func(MouseReclaimPolicy 的實際形狀)

  ── (2) 語法變體:@abstract 與 func 同一行 ──
    [COMPILED OK       ]  @abstract func inline_declared() -> bool

  ── (3) ADR-0004 VR #6a 的對照組 ──
    [COMPILED OK       ]  完整實作全部抽象方法
```

**判定**,四項各自成立:

1. **裸簽章形式(無冒號、無主體)對四種回傳型別全部合法** —— 第五輪明文要求的
   「各建一檔分別編譯,不可只測一種外推」已滿足。
2. **`Vector2` 合法 → ADR-0005 的 R4-2 修法(BLOCKING)成立。** 該修法把
   `diagnostic_seed_position()` 改標 `@abstract` 回傳 `Vector2`,語法基礎確認無誤。
3. **`@abstract` 類別內可同時宣告 `signal` 與多個 `@abstract func`** —— 這是
   `MouseReclaimPolicy` 的實際形狀,第五輪標為「印象-中、組合未查證」,現已查證。
4. **`@abstract` 與 `func` 同一行也合法** —— 兩種寫法皆可,ADR 有選擇自由。
   建議仍明文指定一種,理由是一致性而非合法性。

**回寫目標**:ADR-0005 VR #1 標為已查證(並註明第三輪那次「已查證」是基於錯誤範例,
本次才是真的);ADR-0004 VR #6 標為已查證,機制一的 `SaveIOBackend` 五處 `pass` 主體須刪除;
`current-best-practices.md` 修正範例。

> **VR #6a 仍未答**(漏實作抽象方法是編譯期還是執行期錯誤)—— 對照組通過,
> 但故意漏實作的那一檔在 RISKY 區,第三次執行未跑到。

### Phase 1

| 檢查 | 實測輸出 | 判定 | 回寫目標 |
|---|---|---|---|
| A1 型別化容器宣告形式 | 見 **F-6** | **BLOCKING —— 原宣告無法編譯**;替代方案待第四次執行 | ADR-0002 VR #1、機制四 |
| A2 `enum` 當鍵的雜湊/相等語意 | 見 **F-3** | **已關閉(中高發現)** | ADR-0002 VR #2 |
| A3 `pow(0.0, 0.0)` | 見 **F-2** | **已關閉** | ADR-0002 VR #3 |
| C1 `@abstract` 四種回傳型別 | _(待填)_ | _(待填)_ | ADR-0005 VR #1、ADR-0004 同項 |
| C2 `Callable.is_valid()` 具名 vs lambda | _(待填)_ | _(待填)_ | ADR-0005 VR #15、VC #18 |
| C3 Agile Event Flushing 鍵真名 | 見 **F-4** | **已關閉** | ADR-0005 VR #3 |

### Phase 2

| 檢查 | 實測輸出 | 判定 | 回寫目標 |
|---|---|---|---|
| P2-1 CLI 入口路徑 | _(待填)_ | _(待填)_ | `tests/README.md` #1、`tests/gdunit4_runner.gd` |
| P2-3 `run_tests()` 回傳型別 | _(待填)_ | _(待填)_ | `tests/README.md` #3 |
| P2-4 GdUnit4 對 4.7.1 相容性 | _(待填)_ | _(待填)_ | `tests/README.md` #4 |
| P2-5 `GdUnitTestSuite` 真名 | _(待填)_ | _(待填)_ | `tests/README.md` #5、自我檢查測試 |
| P2-6 `assert_failure()` 簽章 | _(待填)_ | _(待填)_ | `tests/README.md` #6 |

### 未涵蓋(明文記錄,避免被誤讀為已驗)

- **`_input()` 是否保證整幀派發完畢才進 `_process()` 鏈** —— ADR-0005 Day-1 spike 第一項,
  **全案最該優先驗證的單點失效點**。需要真實輸入事件與逐幀儀器化,規模接近
  `cursor-reclaim-godot-spike-2026-08-05`,應獨立成一份 spike。
- **`gdUnit4-action@v1` 對 4.7.1 的支援**(`tests/README.md` #2)—— 只能在 CI 上驗。
- **滑鼠奪權子機制的 E1 / E2** —— 使用者 2026-08-11 明文凍結,待手把硬體。
