# Godot 二進位序列化與核心型別 — Quick Reference

Last verified: 2026-08-21 | Engine: Godot 4.7.1

> **格式偏離說明(刻意,非疏漏)**:本檔案超出 `docs/engine-reference/README.md` 訂的
> 150 行 context-budget 建議上限,且每個小節下方帶「**證據**:」引用行——這兩者都是
> `modules/input.md`/`modules/physics.md` 既有範本沒有的格式。理由:(1) 序列化領域在
> 2026-08-21 之前於本參考庫完全零涵蓋,而本專案先後有多份技術設計文件的核心引擎宣稱
> 因此各自被實機驗證推翻;(2) 本檔每一條宣稱都要求可追溯到具體探針與 log 檔案,省略
> 引用等於重演本庫曾發生過的「錯誤範例擴散」事故(見 `current-best-practices.md` 的
> `@abstract` 條目)。這不是對 150 行規則的靜默違反,是記錄在案的例外。

## 為什麼這份文件存在

本檔記載 2026-08-21 一系列實機探針(headless, `Godot 4.7.1.stable.official.a13da4feb`)
量測到的二進位序列化 API 行為。所有宣稱皆可追溯至 `prototypes/` 下的未過濾 log,拒絕
任何「應該」「理論上」的外推——查不到證據的項目一律列在文末「未查證」節。

## 1. 二進位 Variant 序列化的四個全域函式

### 正確形狀(1 引數,Godot 4)

```gdscript
var bytes: PackedByteArray = var_to_bytes(value)
var value: Variant = bytes_to_var(bytes)

# 允許 Object/Resource 通過的變體 —— 僅在完全信任來源時使用
var bytes2: PackedByteArray = var_to_bytes_with_objects(value)
var value2: Variant = bytes_to_var_with_objects(bytes2)
```

### 錯誤形狀(Godot 3 的兩引數寫法,4.7.1 不存在)

```gdscript
# 🔴 Parse Error —— 編譯期,不是執行期
var bytes: PackedByteArray = var_to_bytes(value, false)
var value: Variant = bytes_to_var(bytes, false)
```

逐字錯誤訊息:`Too many arguments for "bytes_to_var()" call. Expected at most 1 but
received 2.`(`var_to_bytes()` 同型訊息)。Godot 3 的 `allow_objects` 布林參數在
Godot 4 被拆成了兩個獨立的全域函式,不是保留參數。

**證據**:探針 F1,`prototypes/xcheck-adr0003-2026-08-21/logs/probeF1-signatures-unfiltered.txt`;
`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 F1 結果表。

### 這個錯誤最可能的來源:`FileAccess` 與全域函式是兩種不同的 API 形狀

`FileAccess` 的方法**保留了**兩引數布林參數形狀,而且第二參數在 `store_var()` 上的
名字是 `full_objects`,不是 `allow_objects`:

| API | 真實簽章(ClassDB 內省) | 預設值 |
|---|---|---|
| `FileAccess.get_var` | `get_var(allow_objects: bool) -> Variant` | `[false]` |
| `FileAccess.store_var` | `store_var(value: Variant, full_objects: bool) -> bool` | `[false]` |
| `var_to_bytes`(全域函式) | `var_to_bytes(value: Variant) -> PackedByteArray` | 無第二參數 |
| `bytes_to_var`(全域函式) | `bytes_to_var(bytes: PackedByteArray) -> Variant` | 無第二參數 |

也就是說,Godot 4 把 Godot 3 的 `allow_objects` 布林參數,在 `FileAccess` 上原樣保留,
卻在全域函式上拆成了 `_with_objects` 獨立函式——**同一件事在引擎裡有兩種不同的 API
形狀**。一個記得 `FileAccess.get_var(false)` 可用的開發者,會很自然地以為
`bytes_to_var(bytes, false)` 也可用。**這是本專案先前把兩引數寫法誤植進技術設計文件
全文十餘處的最可能來源,也是它最可能被重新加回去的路徑**——任何審核序列化程式碼時,
看到 `bytes_to_var(..., false)` 這種寫法都值得先假設它是把兩套 API 記混了。

**證據**:探針 H-1,`prototypes/xcheck-adr0003-2026-08-21/xcheck-stepdotfive-2026-08-21/logs/probeH-run1-unfiltered.txt`。

## 2. 寫入側對 Object/Resource 的靜默行為

**引擎事實**:plain `var_to_bytes()`(不帶 `_with_objects`)對含有 `Object` 或
`Resource` 的資料——內建 `RefCounted`、自訂 `class_name` 子類別、內建與自訂
`Resource` 皆同——**不會報錯、不會拒絕、不會回傳空值**。它會靜默把該 Object 編碼成
`EncodedObjectAsID`:一段固定長度的位元組,內容是型別碼加上 8 bytes 的 ObjectID。

```gdscript
var d := {"alpha": 1, "poison": RefCounted.new()}
var bytes := var_to_bytes(d)        # 成功,size=60,零錯誤訊息
var back = bytes_to_var(bytes)      # 成功,typeof=27 (Dictionary)
# back["poison"] 的 typeof 是 24 (TYPE_OBJECT),值是一個 EncodedObjectAsID
```

讀回的 `EncodedObjectAsID` 上,原物件的欄位一律讀出為 `<null>`(資料靜默遺失,只剩
一個 ID 號碼)。**同一行程內**可用 `instance_from_id(id)` 把它復活成原物件(欄位齊全、
同一實例);對不存在的 id,`instance_from_id()` 回傳 `null` 且不中止呼叫函式。

⚠️ **跨行程**:ObjectID 號碼確實會跨行程原樣寫進檔案,但已測得在同一新行程內配置
2,000 個物件、slot 範圍涵蓋舊 slot 之後,`instance_from_id(舊id)` **仍回傳 `null`**——
這是觀察到的行為,**不是引擎保證**,不可依賴它作為安全機制。

**證據**:探針 F2-f(`probeF2-main-unfiltered.txt`)、探針 G(G-2a/b/c/d/d2,
`probeG-callable-resource-unfiltered.txt`)、
`prototypes/save-format-skeleton-2026-08-21/README.md` F-1。

## 3. bytes_to_var() 對 Object 衍生型別的拒絕行為(型別白名單的核心依據)

plain `bytes_to_var()`(1 引數版)遇到 Object 衍生型別的位元組時:

- **整包解碼原子性失敗**——巢狀容器裡有一個 Object,整個容器都拿不到,沒有部分解碼。
- **回傳 `null`,但不中止呼叫函式**——呼叫端可以安全地檢查回傳值。
- **伴隨明確的錯誤/log 輸出**(內建/自訂型別、任意巢狀深度皆同,巢狀越深下面第二行
  重複次數越多):

```
ERROR: Condition "!p_allow_objects" is true. Returning: ERR_UNAUTHORIZED
   at: decode_variant (core/io/marshalls.cpp:718)
ERROR: Error when trying to decode Variant.
   at: decode_variant (core/io/marshalls.cpp:860)
```

**證據**:探針 F2(F2-a/b/c/g),`probeF2-main-unfiltered.txt`。

### `size()==0` 是可靠的失敗訊號,`== null` 不是

| 判定方式 | 全零 16 bytes(合法 NIL 編碼) | 空 `PackedByteArray` | 截斷/偽造壞位元組 |
|---|---|---|---|
| `bytes_to_var()` 回傳值 | `null`,**無任何錯誤訊息** | `null`(`Condition "len < 4" ... ERR_INVALID_DATA`) | `null`(各自不同的 `Condition ... ERR_INVALID_DATA/ERR_FILE_EOF` 訊息) |
| `== null` 能否區分「損毀」與「合法值」 | **不能**——全零就是合法的 NIL,`== null` 兩者都命中 | 能(空值本身就是壞) | 能 |
| `is Dictionary`(若契約規定頂層型別)能否區分 | **能**——全零解出的 `null` 不是 `Dictionary`,正確判為損毀 | 能 | 能 |

`var_to_bytes()` 合法輸出的最短長度:`{}`/`[]`/空 `PackedByteArray` 皆 **8 bytes**;
`null` 是 **4 bytes**。也就是說**合法編碼永遠不會是 0 bytes**——`size()==0` 在
4.7.1 是一個可靠、無歧義的失敗訊號;而單純比較 `== null` 會把「一份全零的損毀檔案」
和「合法解碼出一個 NIL」混為一談。若 payload 契約規定頂層必須是特定型別(例如
`Dictionary`),應改用 `is <ExpectedType>` 判定,不要只判 `!= null`。

**證據**:探針 F2-e、探針 H-8(`xcheck-stepdotfive-2026-08-21/logs/probeH-run3-unfiltered.txt`)。

## 4. Callable / Signal / RID —— 三者命運完全不同,不可合併敘述

這三個型別**全部不受 `allow_objects` 那道閘門管控**——plain `bytes_to_var()` 對三者
一律零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗,`_with_objects` 變體與 1 引數版逐位元
組相同。但「通過閘門」之後的命運完全不同,必須分開看:

### Callable

| 項目 | 結果 |
|---|---|
| 編碼是否成功 | 成功,但裸值只有 **4 bytes**(僅型別標頭) |
| 綁定資訊是否寫入位元組流 | **否**——bound method 與 lambda 編碼結果逐位元相同 |
| 還原後 | `typeof=25`,`is Callable=true`,但 `is_valid()=false`、`get_object()=<Object#null>`——空殼 |
| 呼叫還原物會怎樣 | **中止呼叫端函式**:`Attempt to call function "null::null (Callable)" on a null instance.` |

### Signal

| 項目 | 同行程 | 跨行程 |
|---|---|---|
| 編碼 | 成功,24 bytes(型別 + 訊號名 + 8 bytes ObjectID) | 同上(位元組本身不變) |
| 還原後 `get_object()` | **活體物件** | `<Object#null>` |
| `connect()` | 回 `0`(OK) | 回 `3`(`ERR_UNCONFIGURED`),報 `Parameter "obj" is null.` |
| `emit()` | **處理函式真的執行** | 沒有送達 |
| `is_null()` | `false` | ⚠️ **仍是 `false`**——不可當守衛,要用 `get_object() != null` |

### RID

| 項目 | 同行程 | 跨行程(已實測,非推測) |
|---|---|---|
| 編碼 | 成功,12 bytes(型別 + 8 bytes RID id) | 同上 |
| 還原後 | `is_valid=true`,`get_id()` 與來源逐位元相同,`== 來源` 為 `true` | `is_valid=true`,id 與行程 1 存下的號碼**完全相同** |
| 跨行程風險 | — | ⚠️ **已實測成立且具決定性**:行程 2 第一個 `PhysicsServer2D.body_create()` 配到的 id 與行程 1 存檔裡的 id **完全相同**,`還原的RID == 本行程新配的RID` 為 `true`——存檔裡的 RID 會指向一個真實存在、屬於別人的活體資源,不是機率碰撞 |

**危險程度排序**:`Signal`(同行程時是全功能物件)> `RID`(跨行程仍是有效的伺服器
handle)> `Callable`(空殼,但誤用會中止呼叫端函式)。

**證據**:探針 G(G-1),`probeG-callable-resource-unfiltered.txt`;跨行程部分:
`prototypes/save-format-skeleton-2026-08-21/README.md` F-2/F-3。

## 5. HashingContext 狀態機

真實簽章(`HashingContext` 是登記類別,`ClassDB` 內省可用):

| 方法 | 簽章 | 回傳 |
|---|---|---|
| `start` | `start(type: HashingContext.HashType) -> Error` | `Error` |
| `update` | `update(chunk: PackedByteArray) -> Error` | `Error` |
| `finish` | `finish() -> PackedByteArray` | `PackedByteArray` |

狀態機實測(`ERR_ALREADY_IN_USE=22`、`ERR_UNCONFIGURED=3`、`FAILED=1`、`OK=0`):

| 操作序列 | 結果 |
|---|---|
| `start()` 後,**未 `update()`** 就再 `start()` | 第二次回 `ERR_ALREADY_IN_USE(22)` |
| `start()` → `update()` 後,再 `start()`(已餵資料) | 同樣回 `ERR_ALREADY_IN_USE(22)`,**且不重置**——後續 `update()` 會**接續累積**在原資料之後(實測 `finish()` 結果等於 `SHA256("abc"+"abc")`,不是重新開始的 `SHA256("abc")`) |
| `finish()` 之後再 `update()` | `ERR_UNCONFIGURED(3)` |
| `finish()` 呼叫第二次(不重新 `start`) | 回**空** `PackedByteArray`(`size=0`) |
| 未 `start()` 就 `finish()` | 同樣回空 `PackedByteArray` |
| `finish()` 後重新 `start()` + `update()` + `finish()` | 正常運作,可重用同一個 `HashingContext` 實例 |
| `update()` 傳入空 `PackedByteArray` | 回 `FAILED(1)`,但**不影響** `finish()` 的正確性——若這是唯一一次 `update()`,`finish()` 仍給出空輸入的標準 SHA-256(`e3b0c442...`) |

⚠️ 上表「已餵資料後再 `start()` 被拒但不重置」這一格值得特別注意:如果呼叫端不檢查
`start()` 的 `Error` 回傳值,很容易誤以為呼叫了 `start()` 就代表雜湊器已重新開始,
實際上它會靜默沿用舊狀態繼續累積。

`PackedByteArray` **沒有** `sha256_buffer()` 方法(`Parse Error: Cannot find member
"sha256_buffer" in base "PackedByteArray".`)——這個便利方法只存在於 `String`
(`sha256_buffer()`/`sha256_text()`)。若雜湊輸入是 `PackedByteArray`(區塊緩衝區的
常見情境),三段式 `HashingContext` 是唯一路徑,無法用便利方法簡化。

**證據**:探針 F3(`probeF2-main-unfiltered.txt` 尾段)、探針 J6/J7
(`prototypes/xcheck-adr0003-2026-08-21/xcheck-gdscript-shape-2026-08-21/logs/probeJ-run1-unfiltered.txt`、
`probeJ-run2-unfiltered.txt`、`probeJ-run3-unfiltered.txt`)。

## 6. 循環引用容器

GDScript 允許構造自我參照的 `Dictionary`/`Array`(它們是參照型別,`d["self"] = d`
合法)。

**引擎自己有防護**:`var_to_bytes()` 對循環引用會印出
`ERROR: Potential infinite recursion detected. Bailing.`(加上巢狀每層各一次的
`Condition "err" is true`),**回傳 `size=0` 的 `PackedByteArray`——不是 `null`,
行程不崩潰、不卡死**。

**自行寫的無防護遞迴閘門沒有這種保護**:若程式碼自己寫一個遞迴函式去掃描 payload
(例如驗證型別白名單)而不設深度上限,對同樣的循環引用會導致 GDScript 自身的呼叫
堆疊耗盡:`SCRIPT ERROR: Stack overflow. Check for infinite recursion in your
script.`,接著約 1024 行 `ERROR: Stack underflow! (Engine Bug)`。GDScript 遞迴
上限約 1024 個堆疊框(由 1024 行 `Stack underflow` 推得,非直接量測)。堆疊溢位
中止最內層呼叫框後,每一層展開拿到的都是函式宣告回傳型別的零值——若該值恰好在
目前的判定極性下代表「拒絕」,看起來像是安全的 fail-closed。

⚠️ **這個 fail-closed 是巧合,不是設計出來的保證**:它純粹來自「布林零值恰好是
`false`」這個巧合。若判定極性反過來寫(例如改用「找到合法值回 `true`」這種寫法,
零值變成假的「合法」),或若回傳型別換成物件(例如一個帶 `rejection` 欄位的結果
物件),堆疊溢位展開時拿到的零值會是 `null`,呼叫端接著讀取 `result.rejection`
就會在 `null` 實例上取屬性,反而中止呼叫端函式——同一個機制在不同寫法下會從
「巧合安全」變成「呼叫端無聲中止」。**不可依賴它作為防護手段,必須自行設深度上限
或已訪節點集合。**

**證據**:探針 H-5(引擎自身行為)、探針 H-7(無防護遞迴閘門)。

## 7. Dictionary 序列化對鍵插入順序敏感

兩個 `==` 相等、鍵值完全相同、但**插入順序不同**的 `Dictionary`,`var_to_bytes()`
編碼出的位元組**不同**(逐位元組不同 hex);若改用 `Array` 承載相同資料(位置決定
順序而非插入順序),編碼結果相同。

**影響**:任何依賴「先比較 Variant 相等性(`==`),再推論位元組層面相同」的斷言都
不成立,反之亦然。若序列化格式的頂層雜湊要涵蓋一個 `Dictionary` 型別的欄位,必須
先正規化鍵順序(例如轉成排序過的 `Array[Dictionary]`),否則邏輯相同的資料會產生
不同雜湊,誤判資料損毀。

**證據**:`prototypes/save-format-skeleton-2026-08-21/README.md` 階段 0 x3。

## 8. 效能量測(供預算參考,非規格值)

| 情境 | `var_to_bytes` | `bytes_to_var` | SHA-256 |
|---|---|---|---|
| 500 筆記錄(GDD 估計規模,52.7 KB) | 1 ms | 1 ms | 0 ms |
| 32 MB `PackedByteArray` | 7 ms | 14 ms | 138 ms |
| 64 MB `PackedByteArray` | 15 ms | 30 ms | 259 ms |
| 100,000 筆記錄(7.63 MB) | 111 ms | 116 ms | 28 ms |
| 500,000 筆記錄(38.13 MB) | 425 ms | 497 ms | 114 ms |

線性成長,無效能懸崖,全部往返 byte-identical。⚠️ 未逼近 2GB 上限(會 OOM),大小
上限本身未查證。

**證據**:探針 F5。

## 9. Variant 型別枚舉全表與 TYPE_MAX

`TYPE_MAX = 39`。`type_string(0..38)` 全部有效;`type_string(39..63)` 一律
`ERROR: Invalid type argument to type_string()` 並回傳 `<invalid type>`。

| # | 型別 | # | 型別 | # | 型別 | # | 型別 |
|---|---|---|---|---|---|---|---|
| 0 | Nil | 10 | Vector3i | 20 | Color | 30 | PackedInt32Array |
| 1 | bool | 11 | Transform2D | 21 | StringName | 31 | PackedInt64Array |
| 2 | int | 12 | Vector4 | 22 | NodePath | 32 | PackedFloat32Array |
| 3 | float | 13 | Vector4i | 23 | **RID** | 33 | PackedFloat64Array |
| 4 | String | 14 | Plane | 24 | **Object** | 34 | PackedStringArray |
| 5 | Vector2 | 15 | Quaternion | 25 | **Callable** | 35 | PackedVector2Array |
| 6 | Vector2i | 16 | AABB | 26 | **Signal** | 36 | PackedVector3Array |
| 7 | Rect2 | 17 | Basis | 27 | Dictionary | 37 | PackedColorArray |
| 8 | Rect2i | 18 | Transform3D | 28 | Array | 38 | PackedVector4Array |
| 9 | Vector3 | 19 | Projection | 29 | PackedByteArray | 39 | *(TYPE_MAX 哨兵,`typeof()` 永不回傳)* |

**證據**:探針 H-2/H-3(`probeH-run1-unfiltered.txt`)。

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

1. **`load(path) != null` 不能判斷編譯成功**——`load()` 對 Parse Error **不回傳
   `null`**。正確做法:`ResourceLoader.load(path, "GDScript",
   ResourceLoader.CACHE_MODE_IGNORE)` 取得 `GDScript` 資源後呼叫 `.reload()`,檢查
   其 `Error` 回傳值。
2. **乾淨 checkout 沒有 `.godot/global_script_class_cache.cfg` 會讓所有
   `class_name` 解析失敗**——必須先跑一次
   `godot --headless --path . --editor --quit`(或 `--import`)建立快取,否則會
   誤判為「API 不存在」。這對 CI 用乾淨 checkout 跑 headless 測試有直接影響。
3. **一個檔案裡一個存在性/arity 未經查證的方法呼叫,會讓同檔其他完全無關的測項
   全部測不到**——GDScript 對未知方法是**整檔 Parse Error**,不是該行的執行期
   錯誤。凡是存在性或 arity 未經確認的呼叫,應獨立成自己的檔案。
4. **同一 `.gd` 檔內所有「值為零」的 float 編譯期常數會被去重成同一個常數,先出現
   者的符號勝出**——原始碼裡寫 `-0.0` 不保證真的拿到 `-0.0`,若某個常數已先以
   `0.0` 出現過。位元級測試應以 `PackedByteArray.decode_double()` 從明確位元組樣式
   構造,不依賴浮點字面量。
5. **`project.godot` 需要 `application/run/flush_stdout_on_print=true`**——否則
   `print()` 全被緩衝,程式不退出就什麼都看不到。
6. **`==` 相等的 `Dictionary` 不保證位元組相同**(見第 7 節)——反之,位元組相同
   也不能單靠 `==` 推論。
7. **「plain `var_to_bytes()` 對 Object 會序列化失敗」是常見的誤記**——實際行為
   方向相反:它不報錯、不拒絕,靜默編碼成 `EncodedObjectAsID`,真正發生的是欄位
   資料靜默遺失,不是序列化失敗。任何依賴「Object 會導致寫入失敗」這個假設的程式
   碼都會踩空。

## 未查證

| # | 項目 | 為何查不了 |
|---|---|---|
| 1 | **release build 下上述所有行為** | 全部量測皆在 debug/headless 建置下進行。本專案環境的 `%APPDATA%/Godot/export_templates/` 目錄存在但完全是空的,系統上找不到任何 `.tpz` export template 檔案,因此無法匯出 release 建置來源測。唯一決定性測法是下載約 1 GB 的 export template(需使用者決定)後重新匯出、重跑本檔案列出的探針。`ERR_UNAUTHORIZED` 的錯誤訊息、`Condition` 系列訊息是否仍輸出、堆疊溢位訊息是否仍產生、`bytes_to_var()` 的回傳值是否仍為 `null`——這些在 release 下是否維持一致,目前無法確認。 |
| 2 | `var_to_bytes` 的大小上限(理論值 ~2GB) | 刻意未逼近測試——逼近會導致 OOM 並可能讓整支探針失去其餘結果。已測到 64MB 線性無效能懸崖。 |
| 3 | `EncodedObjectAsID`/`Signal`/`RID` 在**大量物件配置或長時間執行後**的跨行程行為邊界 | 已測 2,000 次配置仍未命中舊 slot,但未讀引擎原始碼確認 ObjectID 的 validator 計數規則,不能宣稱是保證。 |
| 4 | 還原出來的 valid `RID` 拿去對伺服器發送實際指令會怎樣 | 刻意未測——對物理伺服器餵入來自位元組流的 RID 有崩潰風險,且會污染後續測項。已量到的是「號碼相同且 `==` 為 `true`」,已足以判定第 4 節的跨行程風險結論。 |
| 5 | `Callable` 的**綁定引數**(`bind()` 過的 Callable)是否也一併被丟棄 | 未測——已量到零綁定引數的來源案例往返後為空殼,未測非零綁定引數的情形。 |
