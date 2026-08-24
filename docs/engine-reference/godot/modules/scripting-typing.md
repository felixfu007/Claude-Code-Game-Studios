# Godot GDScript 型別系統邊界 — Quick Reference

Last verified: 2026-08-24 | Engine: Godot 4.7.1

> **格式偏離說明(刻意,非疏漏)**:本檔案超出 `docs/engine-reference/README.md` 訂的
> 150 行 context-budget 建議上限,且每個小節下方帶「**證據**:」引用行——這兩者都是
> `modules/input.md`/`modules/physics.md` 既有範本沒有的格式。理由與姊妹檔
> `core-serialization.md` 相同:本檔記載的巢狀型別容器限制、enum 型別化參數的靜默
> 轉換行為,分別是本專案多份技術設計文件已被實機驗證推翻的位置,省略引用會讓
> 下一次修訂重蹈覆轍。這不是對 150 行規則的靜默違反,是記錄在案的例外。
>
> **2026-08-24 補充兩節(第 6、7 節,約 45 行)後,檔案來到約 260 行**——新增內容
> 是 `Callable`/`RefCounted` 生命週期與 `StringName`/`String` 鍵互通這兩項邊界事實,
> 借了本檔「型別/物件邊界行為」的定義域,詳見兩節各自開頭的範圍說明。

## 1. 巢狀型別容器不支援

Godot 4.7.1 **不支援**巢狀的型別化容器宣告——例如 `Dictionary[K, Array[V]]` 或
`Dictionary[K, Dictionary[K2,V2]]`。這在**class member 宣告、函式參數、函式回傳
型別**三種形狀下**完全一致**,錯誤逐字為:

```
Parse Error: Nested typed collections are not supported.
```

```gdscript
# 🔴 三種形狀皆 Parse Error
var _records: Dictionary[Pair, Array[AffinityRecord]]              # class member
func f(x: Dictionary[Pair, Array[AffinityRecord]]) -> void: pass   # 函式參數
func g() -> Dictionary[Pair, Array[AffinityRecord]]: pass          # 回傳型別

# ✅ 正確替代:包裝類別打斷巢狀,兩層型別各自保留
class_name AffinityRecordList extends RefCounted
var items: Array[AffinityRecord] = []
# ... 外層改為 Dictionary[Pair, AffinityRecordList]
```

包裝類別方案已實測**兩層型別皆保住**:存入後 `_records[pair].items.is_typed()` 為
`true`,讀回的物件 `is AffinityRecordList` 為 `true`。

**證據**:`prototypes/xcheck-gdscript-specialist-2026-08-20/logs/xcheck2-unfiltered.txt`
(三種形狀的原始錯誤訊息);`prototypes/xcheck-round7-2026-08-20/README.md` 探針 A
(包裝類別方案的兩層型別確認,兩個獨立專案重現)。

## 2. 型別化容器的邊界行為

### 缺鍵讀取:`[]` 中止,`.has()` 安全

```gdscript
# 🔴 對從未寫入的鍵做 subscript 讀取 —— 中止呼叫函式
var v = _records[unwritten_pair]
# SCRIPT ERROR: Out of bounds get index '1' (on base: 'Dictionary[int, AffinityRecordList]')

# ✅ 先用 .has() 守衛
if _records.has(pair):
    var v = _records[pair]
```

同一模式也出現在 enum-as-Dictionary 的字串查詢上,而且**字面量與動態組出的非法
字串是兩種不同的失敗模式**:

| 形狀 | 靜態字面量(編譯期已知) | 動態組出(執行期才知道) |
|---|---|---|
| `Pair["NO_SUCH_PAIR"]`(subscript) | **Parse Error,整檔編譯失敗** | **SCRIPT ERROR,中止呼叫函式**:`Invalid access to property or key 'NO_SUCH_PAIR' on a base object of type 'Dictionary'.` |
| `Pair.keys().has("NO_SUCH_PAIR")`(方法呼叫) | 編譯通過,乾淨回傳 `false` | 乾淨回傳 `false` |
| `Pair.values().has(999)`(越界序數) | — | 乾淨回傳 `false`,不中止 |

**規則**:對不可信的字串/數值一律用 `.keys().has()` / `.values().has()` 做存在性
檢查,**絕不對不可信輸入裸用 `[]` subscript**——這是形狀上的規則,不是「來源可信
與否」的規則:即使明知字串來自不可信來源,寫成方法呼叫就是安全的,寫成 subscript
就不是。

**證據**:`prototypes/xcheck-round7-2026-08-20/README.md` 探針 A(缺鍵讀取)、探針 C
(字面量 subscript)、探針 D(`.has()` 對稱可用)。

### 容器層的型別退化

型別化容器的**鍵**型別在容器層級的內省 API 上會被抹成底層內建型別——例如 enum 鍵
容器 `Dictionary[Pair, int]` 的 `get_typed_key_builtin()` 回傳 `2`(`TYPE_INT`),
不是 enum 本身。這是「subscript 路徑不會擋 enum 家族錯誤」這個結論的直接機制證據,
比從錯誤訊息字串推導更乾淨。

**證據**:`prototypes/xcheck-gdscript-specialist-2026-08-20/README.md`
(`x4_dict_introspect.gd`)。

### 序列化往返後仍保持型別化

`Array[int]`、`Dictionary[String, int]` 這類型別化容器經 `var_to_bytes()` →
`bytes_to_var()` 往返後,`is_typed()`/`get_typed_key_builtin()`/
`get_typed_value_builtin()` **維持不變**,可直接指派回同型別的變數而不中止。

**證據**:`prototypes/xcheck-adr0003-2026-08-21/xcheck-stepdotfive-2026-08-21/logs/probeH-run1-unfiltered.txt` 與 `probeH-run2-unfiltered.txt`(H-4;探針 H 分階段重跑,H-1~H-4 在兩份 log 都有,run1 是首次出現)、
`prototypes/xcheck-adr0003-2026-08-21/xcheck-gdscript-shape-2026-08-21/logs/probeJ-run2-unfiltered.txt`(J5)。

### `const Dictionary` 是唯讀

`const` 宣告的 `Dictionary`(例如用 `TYPE_*` 常數當鍵的白名單表)`is_read_only()`
為 `true`;需要可變副本必須先 `.duplicate()`(之後 `is_read_only()` 為 `false`)。

**證據**:`prototypes/save-format-skeleton-2026-08-21/README.md` 階段 0 pre5/pre6。

## 3. enum 型別化參數/欄位對數值的靜默轉換

`enum` 型別標註(無論是函式參數還是類別欄位)在「值經未型別化 `Variant` 夾帶傳入」
這個情境下,行為與裸 `int` **幾乎完全相同**:

| 夾帶值 | 函式參數 `f(p: SomeEnum)` | 欄位賦值 `obj.some_enum_field = v` |
|---|---|---|
| `float`(如 `3.7`) | 不中止,**靜默截斷**成 `3`(非四捨五入) | 同樣靜默截斷 |
| `bool` | 不中止,靜默轉 `0`/`1` | (未逐一測欄位版本,函式參數已確認) |
| 越界 int(如 `999`、`-1`) | **不中止,原樣傳入,零檢查** | **不中止,原樣接受,`typeof` 仍為 int** |
| `String` | **中止**:`Cannot convert argument 1 from String to int.` | (同一錯誤家族,函式參數已確認) |

**結論:enum 型別標註在這個邊界上只擋 `String` 這一類,對 `float`/`bool`/越界
`int` 完全不設防。** 任何「型別化參數已經安全」的論證,若套用在 enum 型別上,必須
明確排除 float/bool/越界值這三種情況——它們會靜默通過,不會被編譯器或執行期任何
內建檢查攔下。

**證據**:`prototypes/xcheck-round7-2026-08-20/README.md` 探針 B(函式參數);探針
J1d/J1e(`prototypes/xcheck-adr0003-2026-08-21/xcheck-gdscript-shape-2026-08-21/logs/probeJ-run2-unfiltered.txt`,欄位賦值)。

## 4. 一般型別化賦值/比較的中止 vs 靜默矩陣

當一個宣告為特定型別的變數,實際被指派或參與運算的值來自未型別化 `Variant` 且型別
不符時:

| 操作 | `String` vs 數值 | `float` vs `int` |
|---|---|---|
| `is_finite(v)` / `is_nan(v)` / `is_inf(v)` | **中止**:`Invalid type in utility function ... Cannot convert argument 1 from String to float.` | 不適用(這三個函式本身要 float) |
| 比較運算子(`==`、`>=`) | **中止**:`Invalid operands 'String' and 'float/int' in operator '==/>='.`——**不比內建函式寬容** | **不中止**,安全的混合比較 |
| 賦值進型別化區域變數(`var m: float = v`) | **中止**:`Trying to assign value of type 'String' to a variable of type 'float'.` | ⚠️ **不中止,靜默截斷**(`var t: int = 1.5` → `t=1`,`typeof(t)=2`,**無任何錯誤訊息**) |

**`var t: int = <float>` 的靜默截斷是本表唯一「不出錯,但也不安全」的情況**——所有
其他型別不符的操作都會中止(可被偵測),只有這一種會悄悄丟資料。字串「長得像數字」
(如 `"1.5"`、`"5"`)不會被隱式解析,一律按上表的 `String` 行為處理。中止只影響
直接呼叫的那一層函式,不會往呼叫鏈上層傳染。

**寫驗證邏輯的正確順序**:不能先用「賦值當作讀取」(例如
`var m: float = data.get("m")`)再指望某個檢查攔下錯誤——賦值本身就是會中止的
操作之一。正確順序是先對原始 `Variant` 做 `typeof(raw) == TYPE_FLOAT` 這類內省
檢查,確認型別後才允許賦值或做其他型別相關運算,且對 `int` 欄位必須明確要求
`typeof(raw) == TYPE_INT`,不能因為 `TYPE_FLOAT` 賦值不出錯就放寬接受。

**證據**:`prototypes/xcheck-gdscript-specialist-2026-08-20/README.md` XCHECK-4
(`logs/xcheck4-unfiltered.txt`)。

## 5. `@abstract`

> **本節只補 2026-08-21 新測出的事實。基本語法規則(裸簽章 vs 帶 `pass` 主體、
> 類別層 `@abstract` 寫法)已完整記載在
> `docs/engine-reference/godot/current-best-practices.md` 的 `@abstract` 條目,
> 請先讀那裡;那裡也有一段指回本節的交叉引用。**

新增於既有記載之外的事實:

- **已測回傳型別擴為 8 種**:既有記載的 `Array[T]`/`bool`/`float`/`void`/
  `Vector2` 之外,新確認 `Variant`、`String`、`PackedByteArray` 三種裸簽章皆
  `COMPILED OK`。`PackedByteArray` 特意單獨測過——它是打包陣列而非型別化
  `Array[T]`,不可從後者外推。
- **完整組合已逐字編譯通過**:`class_name` + `extends` + `@abstract` + 一個
  `signal` + 多個 `@abstract func`(4 個 `bool` 回傳 + 1 個 `Variant` 回傳)同檔
  並存,不只是單一語法點各自成立。
- **多型呼叫的執行期前提已確認**:具體子類別完整實作全部抽象方法後可 `.new()`;
  透過**靜態型別為抽象基底**的參數持有該實例,呼叫抽象方法兩個分支皆正常執行——
  這是「上層只持有抽象基底型別參照」這種設計的執行期基礎。
- **字面 `ClassName.new()` 構造抽象類別是編譯期錯誤,不是執行期**,即使寫在永不
  執行的分支上也一樣觸發:`Parse Error: Cannot construct abstract class "..."`。
  ⚠️ **但只驗證了這一條直接路徑**——`Object.new()` + `set_script()`、
  `load("...").new()`、透過 `ClassDB`/`ResourceLoader` 的間接構造路徑**既無實測
  亦無反證**,仍未查證。
- **漏實作抽象方法的錯誤訊息格式已修正**:實測格式為
  `must implement "Base.method()" and other inherited abstract methods`——
  **只指名其中一個方法**,其餘概括為 `and other inherited abstract methods`,
  不會逐一列舉所有缺漏的方法名。
- `is_abstract` 會被序列化進 `.godot/global_script_class_cache.cfg` 的結構化
  欄位,不只是編譯期的暫時旗標。

**證據**:`prototypes/engine-verification-spike-2026-08-20/logs/run-final-2026-08-20-headless.txt`;
`prototypes/xcheck-round7-2026-08-20/README.md` 探針 E。

## 6. `Callable` 綁定 `RefCounted` 實例方法的生命週期 —— 與序列化無關

> **範圍提醒**:本節與 `core-serialization.md` 第 4 節的 `Callable` 條目是**兩件不同的
> 事**。第 4 節談的是 `Callable` 經 `var_to_bytes()`/`bytes_to_var()` **序列化往返後**
> 的空殼行為;本節從頭到尾沒有呼叫任何序列化函式,是**同行程內、單純的 `RefCounted`
> 引用計數生命週期**對已綁定 `Callable` 的影響。放在本檔而非 `core-serialization.md`,
> 是因為它與本檔其他小節同屬「看起來安全但邊界有洞」的型別/物件行為類別,不是序列化
> 行為。

綁定到某個 `RefCounted` 實例方法的 `Callable`,常見的隱含假設是「只要還握著這個
`Callable`,它綁定的物件就還活著」。實測**不成立**:

| 時機 | `is_valid()` | `get_object()` | `get_method()` |
|---|---|---|---|
| 綁定來源的 `RefCounted` 實例仍在作用域內 | `true` | 該實例的活體參照 | 方法名稱 |
| **來源實例離開作用域並被回收後** | `false` | `<Object#null>` | **仍正確回傳方法名稱** |

`Callable` 本身**不會**讓它綁定的 `RefCounted` 續命(不增加引用計數)。⚠️
**`get_method()` 在物件已死之後仍然「看起來正常」**——它是這張表裡唯一一個不反映
失效狀態的查詢方法。若驗證邏輯誤用「`get_method()` 有沒有回傳值」判斷 Callable 是否
仍可用,會得出錯誤的「還活著」結論。正確的存活判斷必須用 `is_valid()`。

**證據**:`prototypes/save-format-skeleton-2026-08-21/scripts/t_h_callable_lifetime.gd`
第 7–26 行;`prototypes/save-format-skeleton-2026-08-21/logs/run1-unfiltered.txt` 第
7536–7540 行;`prototypes/save-format-skeleton-2026-08-21/README.md`「追加 H」表
(約第 226–235 行)。

## 7. `StringName`/`String` 當 `Dictionary` 鍵,序列化往返後仍互通

`Dictionary` 若同時混用 `String` 鍵與 `StringName` 鍵,查詢時**不需要**在乎當初插入
時是哪一種型別——`has("alpha")` 與 `has(&"alpha")` 對同一個鍵**都會**命中,不論該鍵
原本是用 `String` 還是 `StringName` 寫入的。這個互通性在**序列化往返後依然成立**:

```gdscript
var d: Dictionary = {}
d[&"alpha"] = 1       # StringName 鍵
d["beta"] = 2          # String 鍵

var back = bytes_to_var(var_to_bytes(d))
# back.has("alpha") == true, back.has(&"alpha") == true
# back.has("beta")  == true, back.has(&"beta")  == true
```

實測四種組合(寫入用哪種 × 查詢用哪種)**往返前後全部回傳 `true`**,且各鍵的
`typeof()` 在往返前後保持不變(`StringName` 鍵仍是 21,`String` 鍵仍是 4——不會被
互相轉型)。

**意義**:若某個型別化資料結構的鍵位置同時允許 `STRING` 與 `STRING_NAME`(例如
白名單式的型別閘門),混用兩種字串鍵型別在查詢層面是安全的——不會因為寫入端與
讀取端選用的字串型別不同而查不到鍵。

**證據**:`prototypes/save-format-skeleton-2026-08-21/scripts/x2_stringname_key.gd`;
`prototypes/save-format-skeleton-2026-08-21/logs/stage0-unfiltered.txt` 第 96–100
行;`prototypes/save-format-skeleton-2026-08-21/README.md` 階段 0 x2 列(約第 95
行)。

> ### ⚠️ 證據等級:探針 J 的引用與其他探針不同級
>
> 本檔引用的探針裡,**只有探針 J(`xcheck-gdscript-shape-2026-08-21/`)沒有 README** ——
> 也就是**沒有探針作者自己寫下的判讀**。標為 J1d / J1e / J5 / J6 / J7 的宣稱,是本檔
> 撰寫者直接讀 `runner_j.gd` 與三份 log 逐行反推出來的,並與 log 逐字輸出交叉核對過,
> 但**沒有第二份既有摘要可以對照**。
>
> 其餘所有探針的引用都有兩層:log(原始輸出)+ README(作者判讀)。探針 J 只有一層。
>
> **要覆核 J 系列的任何一條時,起點必須是 log 本身,不是任何摘要文件**(包含本檔)。
> 若覆核結果與本檔不符,以 log 為準。

## 判讀陷阱

1. **`get_class()` 回傳原生引擎類別,不能用來判斷 `RefCounted`/`Resource` 子類別
   的身分**——任何自訂子類別呼叫 `get_class()` 都只會印出 `RefCounted`/
   `Resource` 本身,無法區分。驗證「還原物是不是我的自訂類別」必須用
   `get_script().get_global_name()` 或 `is CustomClassName`。曾有一版驗證因為
   用了 `get_class()` 而得出「兩層型別都保住」的結論——結論湊巧為真,但證據本身
   無效,不能作為可信引用。
2. 缺鍵讀取、非法 enum 字串索引的中止行為,與巢狀型別容器的 Parse Error 是**不同
   層級**的失敗(前者執行期、後者編譯期)——寫測試或驗證邏輯時不要混為一談。

## 未查證

| # | 項目 | 為何查不了 |
|---|---|---|
| 1 | **release build 下容器型別驗證是否仍生效** | C++ 層的 `ERR_FAIL_COND_V` 系列巨集是否在 release 被編掉(從而讓「型別不符寫入被拒絕」失效),需要讀 4.7.1 引擎原始碼的 `container_type_validate.h` 才能確認,而本專案環境沒有可用的 export template——`%APPDATA%/Godot/export_templates/` 目錄存在但是空的,系統上找不到任何 `.tpz` 檔,無法匯出 release 建置實測。這一層與「GDScript VM 執行期錯誤回報在 release 是否仍中止函式」是兩個不同層級的問題,後者同樣只能在 debug/headless 下驗證,兩者皆待補測。 |
| 2 | `@abstract` 類別的三條間接構造路徑(`set_script()`、`load().new()`、`ClassDB`/`ResourceLoader`) | 尚未設計對應探針,已知的只有字面 `ClassName.new()` 這一條直接路徑。 |
| 3 | enum 欄位賦值對 `bool`/`String` 的行為 | 函式參數版本已測(第 3 節),欄位賦值僅測過 float、越界 int 兩項,`bool`/`String` 屬合理外推,非直接量測。 |

## 8. `class_name` 全域註冊依賴匯入產生的快取 —— headless 探針的假否證陷阱

**現象**:在一個**從未匯入過**的專案目錄直接跑 `godot --headless --path .`,任何
對 `class_name` 全域類別的參照都會失敗,逐字:

```
SCRIPT ERROR: Parse Error: Could not find type "SaveFormat" in the current scope.
SCRIPT ERROR: Parse Error: Identifier "SaveEnvelope" not declared in the current scope.
ERROR: Failed to load script "res://scripts/runner.gd" with error "Parse error".
```

**根因**:`class_name` 的全域註冊來自 `.godot/global_script_class_cache.cfg`,
該檔由**匯入階段**產生。全新目錄沒有 `.godot/`,於是沒有任何 `class_name` 被登記。

**正確做法**:先跑 `godot --headless --path . --import`,再執行。
匯入後 `global_script_class_cache.cfg` 會列出各 `class_name` 與其 `path`。

**證據**:`prototypes/xcheck-classname-cycle-2026-08-24/logs/run1-unfiltered.txt`
(未匯入,全盤失敗)對照 `logs/xcycle-unfiltered.txt`(匯入後,全部通過);
快取內容見同目錄 README「環境陷阱」節。

> ⚠️ **這是一個「假否證」陷阱,危險程度高於一般環境問題。** 錯誤訊息看起來斬釘截鐵
> 且完全合理,若據此下結論會得到「`class_name` 互相引用在本版本不可行」這種
> **方向相反**的判定,並可能據以把架構改成不必要的形狀。
> **後續任何用到 `class_name` 的 headless 探針都必須先 `--import`。**

**附帶可用的事實**:快取能成功生成,本身即代表**該目錄下所有腳本在匯入期都通過剖析** ——
這比執行期輸出更早、更硬的一道證據,可作為「這批腳本編譯得過」的獨立佐證。
