# 第七輪審查探針 — 2026-08-20

**目的**:關閉 `/architecture-review` 第七輪對 ADR-0002 提出的四項未查證項 —— R7E-1、R7E-2、R7E-4、R7E-13。
**執行者**:`godot-gdscript-specialist`(`.gd` 依 `technical-preferences.md` File Extension Routing 表委派)。探針 D 的 4 個 `.gd` 檔為該 specialist 於 2026-08-20 中斷前的交付;`D.tscn`(6 行、照 `C.tscn` 複製)、執行、log 歸檔與本 README 更新由協調者完成。
**探針 D(2026-08-21 追加)**:關閉探針 A/B/C 執行者自陳的殘留未查證項 **#1 / #2**,兩者是 R7-P1 與 R7-P3 建議修法的地基。
**引擎**:`Godot 4.7.1.stable.official.a13da4feb`,headless,**四支探針皆 exit code 0**。
**上游報告**:`docs/architecture/architecture-review-2026-08-20-round7.md` 第四之二節。

> **本 README 由審查協調者於探針交付後補寫** —— 探針執行者交付了完整結果但未建立 README,而本專案的紀律是「原始 log 檔頭自帶指令、exit code、判讀陷阱,**下一輪不需回讀對話**」。此處補齊該層。

---

## 如何重跑

```bash
# Godot 執行檔不在 PATH 上 —— which godot 找不到不代表沒有
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"

# 步驟 1(必要):乾淨 checkout 沒有 .godot/global_script_class_cache.cfg
#   → 所有 class_name 解析失敗。必須先建快取。
"$GODOT" --headless --path . --editor --quit

# 步驟 2:跑探針
"$GODOT" --headless --path .
```

**切換探針的方式是改 `project.godot` 的 `run/main_scene`,不是傳參數** —— 四支各有一個 6 行場景
(`scenes/A.tscn` ~ `scenes/D.tscn`),根節點腳本各指向對應的 `scripts/runner_*.gd`。
本目錄提交時 `main_scene` 停在 `res://scenes/D.tscn`(最後執行的一支)。

**兩個判讀陷阱(前人踩過,務必避開)**

1. **`project.godot` 必須有 `application/run/flush_stdout_on_print=true`** —— 否則 `print()` 全被緩衝,程式不退出就一個字都看不到。
2. **`load(path) != null` 不能用來判定編譯成功** —— `load()` 對 parse error **不回傳 `null`**。本專案的正確做法是 `ResourceLoader.load(..., CACHE_MODE_IGNORE)` + `reload()` 的 `Error` 回傳值。

---

## log 歸檔(全部未過濾)

| 檔案 | 內容 |
|---|---|
| `logs/00-editor-cache-build.txt` | 步驟 1 的 class cache 建置 |
| `logs/probeA-unfiltered.txt` | 探針 A —— R7E-1 / R7E-2 |
| `logs/probeB-unfiltered.txt` | 探針 B —— R7E-4(最高優先) |
| `logs/probeC-v1-flawed-unfiltered.txt` | 探針 C **第一版(失敗)** —— **刻意保留**,見下方「過程失誤」 |
| `logs/probeC-v2-unfiltered.txt` | 探針 C 第二版 —— R7E-13 |
| `logs/probeD-unfiltered.txt` | 探針 D(2026-08-21)—— 殘留未查證項 #1 / #2 |

**執行者自陳:log 全部未經 `grep`/`head`/`tail` 過濾或截斷。**

---

## 結果

### 探針 A — R7E-1(關閉)/ R7E-2(確認為缺口)

| 項目 | 結果 |
|---|---|
| `var _records: Dictionary[Pair, AffinityRecordList]`,class member **無初始化** | **編譯成功** |
| 同上,**`= {}`** 初始化 | **編譯成功** |
| 存入後 `_records[pair].items.is_typed()` | **兩形皆 `true`**;`read_back is AffinityRecordList` 為 `true`;`get_script().get_global_name()` 為 `AffinityRecordList` |
| **讀取從未寫入的鍵** | **`SCRIPT ERROR` 並中止呼叫函式**:`Out of bounds get index '1' (on base: 'Dictionary[int, AffinityRecordList]')` |
| 同上,`Dictionary[Character, int]` 形式 | **同一行為** |

⚠️ **不可用 `get_class()` 做兩層型別斷言** —— 它回傳原生類別,任何 `RefCounted` 子類都印 `RefCounted`。本探針用的是 `get_script().get_global_name()` 與 `is`。

**R7E-1 結論**:ADR-0002 2026-08-20 修訂的核心產出(包裝類別 `AffinityRecordList`)**經實機確認成立**,兩層型別皆保住。ADR 的 Validation Criteria #11 可標為已查證。

**R7E-2 結論**:型別化 `Dictionary` 對從未寫入的鍵做 subscript 讀取**既不是 `null`、也不是靜默預設值,而是中止呼叫函式**。GDScript 無 try/catch,呼叫端拿不到任何可判斷的回傳值。而 ADR-0002 機制二明文「首次對某配對寫入時才建立 `AffinityRecordList`」→ **任何發生在寫入之前的讀取都會當場中止**,而 `n(p) = 0` 是 GDD 明文要求處理的合法情境。**ADR 必須二選一並明文寫下**:(a) 建構子預先為 10 對配對各建一個空 `AffinityRecordList`;或 (b) 每個讀取入口一律先 `_records.has(pair)` 守衛。`_death_marks` / `t_death()` 同理(ADR 目前只給簽章、沒給函式體,看不出是否已隱含守衛)。

**附帶佐證**:錯誤訊息把容器印成 `Dictionary[int, AffinityRecordList]` —— **enum 鍵在容器層被抹成 `int`**,這是 ADR-0002 VR #2 結論在「缺鍵讀取」這條全新路徑上的再次確認。

### 探針 B — R7E-4(確認成立,並推翻機制四的一句宣稱)

`func f(p: AffinityTypes.Pair)` 經 `Variant` 夾帶呼叫,對照 `func g(n: int)`:

| 夾帶值 | `f(p: Pair)` | `g(n: int)`(對照) |
|---|---|---|
| `3.7`(float,合法序數範圍) | **不中止**,`typeof(p)=2`(TYPE_INT),`p=3`(**截斷**,非四捨五入) | 相同:`n=3` |
| `3.0` | **不中止**,`p=3` | 相同 |
| `"3"`(String) | **中止**:`Cannot convert argument 1 from String to int.` | 相同(錯誤訊息家族一致) |
| `true`(bool) | **不中止**,靜默轉 `p=1` | 相同 |
| `-1`(合法 int / **非法 enum 序數**) | **不中止,`p=-1` 原封不動傳入,零錯誤零檢查** | 相同 |
| `999`(同上) | **不中止,`p=999` 原封不動傳入** | 相同 |

**判讀**:`AffinityTypes.Pair` 型別化參數在「值經 `Variant` 於呼叫端夾帶」這個情境下,與裸 `int` 參數**逐項同行為**。enum 型別標註在這個邊界上**只抹平了 `String` 那一類**。

**三項對 ADR-0002 的影響**

1. **R7E-4 確認成立** —— `TR-affinity-011`(寫入驗證須 fail-loud、不自動糾正)的 ⚠️ 判定成立,不回復 ✅。上游傳入 `Variant(3.7)` 會靜默變成合法序數 3、記錄寫進**錯誤配對**、`append_record()` 回傳 `NONE`。
2. **R7-P1(高,新)—— 推翻機制四的宣稱** —— 步驟 4/5 的註解寫「`INVALID_SOURCE`/`INVALID_PAIR`(GDScript enum 本身型別化後這條**理論上不可達**,但保留作為防禦層)」。實測證偽:越界 int 完全能抵達函式本體。**這兩個拒絕碼不是防禦層,是唯一防線。** ADR 須刪掉該推論句,並明訂步驟 4/5 的實際檢查手段(探針 C 已確認 `Pair.values().has(int)` 可用)。
3. **R7-P2(中高,新)** —— float/bool 若截斷後**剛好落在合法序數範圍內**,會**靜默通過任何值域檢查** —— 檢查看到的已經是「合法的 3」,無從得知它原本是型別錯誤的浮點數。失敗模式因此精確化為:**寫入成功、回傳 `NONE`、資料落在錯誤配對,且任何下游檢查都看不出異常。**

**這同時收窄了 ADR 型別安全論證的適用範圍**:「型別錯誤在呼叫端整段中止」對 enum 參數**只對 `String` 成立,對 `float`/`bool` 不成立** —— 比 `XCHECK-4` 只驗 `m: float` 邊界所得的結論**範圍更窄**,不能沿用同一句「型別化參數安全」籠統套到 enum 參數上。

### 探針 C — R7E-13(關閉,但衍生一條新規則)

| 操作 | 結果 |
|---|---|
| `AffinityTypes.Pair.find_key(0)` | 可用,回傳 `"C1_C2"`(String) |
| `AffinityTypes.Pair["C1_C2"]` | 可用,回傳 `0`(int) |
| `AffinityTypes.Pair.values().has(0)` | 可用,回傳 `true` |
| `Pair["NO_SUCH_PAIR"]`(**字面量**,編譯期已知) | **Parse Error,整檔編譯失敗** |
| **同一非法鍵,執行期動態組出** | **`SCRIPT ERROR`,中止呼叫函式**:`Invalid access to property or key 'NO_SUCH_PAIR' on a base object of type 'Dictionary'.` |
| `Pair.find_key(999)`(值不存在) | **不中止,乾淨回傳 `null`** |

**判讀**:enum 在底層確實是常數 `Dictionary`,`find_key`/`values`/字串 subscript 全部繼承 `Dictionary` 的方法。**字面量與動態非法字串索引是兩種不同的失敗模式** —— 前者擋在 parse 階段(對原始碼打錯字友善),後者(`from_dict()` 實際會遇到的情境,字串來自外部資料)是**執行期中止**。`find_key(999)` 是三者中**唯一可以安全用回傳值判斷**的一個。

**R7-P3(中高,新)—— 對 ADR-0002 機制八的影響**:目前寫「先 `typeof()` 內省、後值域運算」,但**沒有涵蓋「型別合法的字串,卻不是任何 enum 成員名稱」這一類輸入** —— 而那正是存檔還原遇到打錯字或版本不相容時最可能出現的錯誤。若 `validate_semantics()` 直接用 `Pair[name]` 做轉換,遇非法名稱會在走到自己的拒絕碼邏輯**之前**就中止,契約承諾的結構化 `ImportResult` 永遠回不去。**正確寫法**:先做存在性檢查(`values().has()` / `keys().has()`),或改用已驗證會乾淨回傳 `null` 的 `find_key()`。**絕不對不可信字串裸用 `Pair[name]`。**

### 探針 D — 殘留未查證項 #1 / #2(兩項皆關閉)

2026-08-21 追加執行。`main_scene` 指向 `scenes/D.tscn`,exit code 0,**六項判定無一中止**。

| 操作 | 結果 |
|---|---|
| **D0** `d1` / `d2` / `d3` 三檔逐檔 `reload()` 編譯檢查 | **三檔皆 `COMPILED OK`** |
| `Pair.values().has(-1)`(越界但合法 int) | **不中止,回傳 `false`** |
| `Pair.values().has(999)`(同上) | **不中止,回傳 `false`** |
| `Pair.keys().has("C1_C2")`(合法成員名,字面量) | **不中止,回傳 `true`** |
| `Pair.keys().has("NO_SUCH_PAIR")`(非法名,**靜態字面量**) | **編譯通過、不中止,回傳 `false`** |
| 同一非法名,**執行期 `"".join()` 組出**(不可常數摺疊) | **不中止,回傳 `false`** |

**#1 結論(關閉)**:`values().has(int)` 對越界輸入**乾淨回傳 `false`**,不中止呼叫函式。**R7-P1 的建議修法地基成立** —— 機制四步驟 4/5 可以用 `Pair.values().has(ordinal)` 作為 `INVALID_PAIR`/`INVALID_SOURCE` 的實際檢查手段,回傳值可安全判讀。

**#2 結論(關閉)**:`keys().has(String)` 與 `values().has(int)` **對稱可用** —— 對非法名回傳 `false` 而非中止。**R7-P3 的建議修法地基成立**,機制八 `from_dict()` 可用 `keys().has(name)` 做存在性檢查後再轉換。

**本探針最有價值的一項對比(探針 C 未區分,本輪首次量到)**:同一個非法名字串,走 **`.has()` 方法呼叫**與走 **`[]` subscript** 是**兩種完全不同的命運** ——

| 形狀 | 字面量 | 執行期動態組出 |
|---|---|---|
| `Pair["NO_SUCH_PAIR"]`(subscript) | **Parse Error,整檔編譯失敗**(探針 C) | **`SCRIPT ERROR`,中止呼叫函式**(探針 C) |
| `Pair.keys().has("NO_SUCH_PAIR")`(方法呼叫) | **編譯通過,回傳 `false`**(D2) | **回傳 `false`**(D3) |

探針 D 的檔頭註解明文寫下「即使 `.has(字串)` 是普通 Array 方法呼叫、不是造成 c2 Parse Error 的 enum-as-Dictionary 字面量 subscript,**在量到之前不假設這個差別是安全的**」,因此仍拆成 d2/d3 兩檔。**量完的結論是那個差別確實存在且方向有利** —— 但拆檔的紀律不因結果良好而追認為多餘:d2 若與 d1 同檔而結果相反,會重演探針 C 第一版的整檔封鎖。

**因此 ADR-0002 的規則措辭必須點名形狀,不能只點名輸入來源**:「不對不可信字串裸用 `Pair[name]`」是正確的;而「改用 `keys().has()` 先檢查」現已有實測支撐,兩者不是同一件事的兩種說法。

---

## 過程失誤(執行者主動自陳,證據刻意保留)

探針 C 第一版把 C1/C2/C3/C5(預期會過)與 C4-literal(字面量非法字串索引,預期可能失敗)寫在**同一個檔案**。結果 C4-literal 是 Parse Error,導致整檔 `reload()` 失敗,**連帶把同檔四項全部擋掉、一個都沒跑出來** —— 這正是 spike F-5 的教訓、也是本輪委派 brief 明文警告過的坑。

**修法**:拆成三個檔案(會過的測試 / 字面量 / 動態組出的非法字串),runner 一律先以 `CACHE_MODE_IGNORE` + `reload()` 的 `Error` 回傳值逐檔編譯檢查,再決定要不要呼叫,**絕不裸 `load()` 已知有風險的檔案**。

**第一版的失敗 log 刻意保留**(`logs/probeC-v1-flawed-unfiltered.txt`)作為「同檔混裝已知失敗測試」這個錯誤本身的證據,而非事後刪除。

---

## 殘留未查證項(執行者自陳,不以推論填空)

| # | 項目 | 為何重要 |
|---|---|---|
| ~~**1**~~ | ~~`Pair.values().has(-1)` / `.has(999)` 在**越界輸入**下的實際回傳值~~ | **✅ 2026-08-21 探針 D 關閉** —— 乾淨回傳 `false`,不中止。R7-P1 修法地基成立 |
| ~~**2**~~ | ~~`Pair.keys().has(name)` 是否與 `values().has()` 對稱可用~~ | **✅ 2026-08-21 探針 D 關閉** —— 對稱,非法名回傳 `false` 不中止。R7-P3 修法地基成立 |
| 3 | 只測單一配對(`C1_C2`)存入,未測多配對或 `_death_marks` 的功能性存讀(只測了它的缺鍵讀取) | 覆蓋面 |
| 4 | 只對 `Pair` 一個 enum 測試 —— `Source`/`Character` 同行為屬**合理外推,非直接測量** | 覆蓋面 |

**第 1、2 項已於 2026-08-21 由探針 D 關閉**(見上方「探針 D」節),ADR-0002 修訂的前置條件因此解除。
**第 3、4 項仍開** —— 兩者皆屬覆蓋面,不阻擋 ADR-0002 修訂:

- **#3**(多配對 / `_death_marks` 功能性存讀)—— 影響的是實作期的單元測試設計,非 ADR 決策內容。ADR-0002 對 `_death_marks` 的缺鍵讀取已有探針 A 的實測(同一行為),二選一裁決不需要 #3 的結果。
- **#4**(只測 `Pair`,`Source`/`Character` 屬外推)—— 探針 B 已對 `Pair` 與裸 `int` 做逐項對照並得出「enum 標註只抹平 `String`」的機制級結論,該機制不依賴特定 enum 的成員數。**但這仍是外推,不得記為已測。**
