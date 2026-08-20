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
  a1_typed_dict_ok.gd           # A1 對照組:真實宣告 + 正確插入
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

### Phase 1

| 檢查 | 實測輸出 | 判定 | 回寫目標 |
|---|---|---|---|
| A1 型別化 `Dictionary` 鍵值檢查層級 | _(待填)_ | _(待填)_ | ADR-0002 VR #1 |
| A2 `enum` 當鍵的雜湊/相等語意 | _(待填)_ | _(待填)_ | ADR-0002 VR #2 |
| A3 `pow(0.0, 0.0)` | _(待填)_ | _(待填)_ | ADR-0002 VR #3 |
| C1 `@abstract` 四種回傳型別 | _(待填)_ | _(待填)_ | ADR-0005 VR #1、ADR-0004 同項 |
| C2 `Callable.is_valid()` 具名 vs lambda | _(待填)_ | _(待填)_ | ADR-0005 VR #15、VC #18 |
| C3 Agile Event Flushing 鍵真名 | _(待填)_ | _(待填)_ | ADR-0005 VR #3 |

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
