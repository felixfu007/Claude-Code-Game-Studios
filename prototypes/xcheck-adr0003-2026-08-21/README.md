# 探針 F — ADR-0003 序列化格式與型別安全的實機驗證(2026-08-21)

**目的**:關閉 `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`
Engine Compatibility 表的五項 Verification Required(VR#1 / #2 / #3 / #3a / #4 / #5),
外加一項 ADR **從未列為 VR、但整條 manifest-only 路徑押在其上**的前提(本 README 稱 F4'-a/b)。

**執行者**:`godot-gdscript-specialist`(`.gd` 依 `technical-preferences.md` File Extension Routing 表委派)。
**引擎**:`Godot 4.7.1.stable.official.a13da4feb`,headless,**兩階段皆 exit code 0**。
**目標 ADR**:ADR-0003(狀態 `Proposed`)。

> ### ⚠️ 本探針推翻了 ADR-0003 的一項全文級寫法
>
> `bytes_to_var(bytes, false)` —— ADR-0003 **全文逐字採用**的呼叫形狀 —— 在 4.7.1
> 是 **Parse Error**,不是 runtime 問題,是**根本不編譯**。
> 這是本專案第二次由實機驗證擊落已寫下的 ADR 內容(第一次是 2026-08-20 的
> ADR-0002 巢狀型別容器)。詳見下方「結果 / 階段 1」。
>
> **但**:ADR 的**型別安全論證本身(核心洞見)經實測成立** —— 只是達成它的
> API 形狀寫錯了。兩件事必須分開讀,不可互相牽連。

---

## 如何重跑

```bash
# Godot 執行檔不在 PATH 上 —— which godot 找不到不代表沒有
GODOT="$HOME/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"

# 步驟 1(必要):乾淨 checkout 沒有 .godot/global_script_class_cache.cfg
#   → 所有 class_name 解析失敗(本探針有 F2CustomRef / F2CustomRes 兩個 class_name)
"$GODOT" --headless --path . --editor --quit

# 步驟 2:跑探針
"$GODOT" --headless --path .
```

**切換階段的方式是改 `project.godot` 的 `run/main_scene`,不是傳參數**：

| 階段 | main_scene | runner | 內容 |
|---|---|---|---|
| 1 | `res://scenes/F1.tscn` | `scripts/runner_f1.gd` | F1 簽章 / arity |
| 2 | `res://scenes/F.tscn` | `scripts/runner_f.gd` | F2 / F4' / F3 / F5 |

本目錄提交時 `main_scene` 停在 `res://scenes/F.tscn`(最後執行的一支)。

**為何拆兩階段**:F1 的結果決定階段 2 的測試碼「該怎麼下筆」。若照 ADR 寫法
(兩引數)下筆而該形狀不編譯,會**整檔 Parse Error 而一項都跑不出來** ——
那正是本專案探針 C 第一版踩過的坑(見 `prototypes/xcheck-round7-2026-08-20/README.md`
「過程失誤」節)。**先量簽章、再寫測試**是本探針的刻意順序,不是分兩次想到。

---

## 判讀陷阱(前人踩過 + 本輪新增,務必避開)

1. **`project.godot` 必須有 `application/run/flush_stdout_on_print=true`** —— 否則 `print()` 全被緩衝,程式不退出就一個字都看不到。
2. **乾淨 checkout 沒有 class cache** —— 必須先跑 `--editor --quit`,否則 `class_name` 解析失敗。
3. **`load(path) != null` 不能用來判定編譯成功** —— `load()` 對 parse error **不回傳 `null`**。正確做法是 `ResourceLoader.load(..., CACHE_MODE_IGNORE)` + `reload()` 的 `Error` 回傳值。
4. **🆕 ADR-0003 全文的 `bytes_to_var(buf, false)` 兩引數寫法不編譯** —— 任何照 ADR 逐字抄的測試碼會整檔 Parse Error。4.7.1 的正確形狀是 1 引數,見下。
5. **🆕 判定「回傳 null」vs「中止函式」不能只看有沒有印出東西** —— 本探針一律讓測試函式宣告 `-> String`、最後一行才 `return` sentinel;呼叫端收到 `""`(String 的零值)才是「中止」的可靠證據。三個 sentinel(呼叫前 / 呼叫後 / 回傳值)缺一不可。
6. **🆕 log 裡大量的 `ERROR: Condition "!p_allow_objects" is true` 是預期的量測結果,不是探針故障** —— 那正是 VR#2 要問的「是否伴隨 console/log 錯誤訊息」的答案本身。
7. **🆕 不可用浮點「字面量」當位元級測試向量** —— 同一 `.gd` 檔內所有**值為零**的 float 編譯期常數會被去重成同一個,先出現者的符號勝出(見 F4'-c 補測)。要測精確位元必須用 `PackedByteArray.decode_double()` 從位元組樣式構造。

---

## log 歸檔(全部未過濾)

| 檔案 | 內容 |
|---|---|
| `logs/probeF1-signatures-unfiltered.txt` | 階段 1 —— F1 簽章 / arity(含步驟 1 完整輸出) |
| `logs/probeF2-main-unfiltered.txt` | 階段 2 —— F2 / F4' / F3 / F5(含步驟 1 完整輸出) |

**執行者自陳:兩份 log 皆為 `2>&1` 合併重導,未經 `grep`/`head`/`tail` 過濾或截斷。**

---

## 結果 / 階段 1 —— F1 簽章(VR#1)

| 呼叫形狀 | 結果 |
|---|---|
| `bytes_to_var(b)` | **COMPILED OK**,回傳解碼值 |
| **`bytes_to_var(b, false)`** ← **ADR-0003 全文寫法** | **🔴 Parse Error**:`Too many arguments for "bytes_to_var()" call. Expected at most 1 but received 2.` |
| `var_to_bytes(v)` | **COMPILED OK** |
| **`var_to_bytes(v, false)`** | **🔴 Parse Error**:同上,`var_to_bytes()` |
| `var_to_bytes_with_objects(v)` | **COMPILED OK**,可編出 Object(40 bytes / `RefCounted`) |
| `bytes_to_var_with_objects(b)` | **COMPILED OK**,回傳 `typeof=24`(TYPE_OBJECT),`is Object = true` |

**判讀**:Godot 4 把 Godot 3 的 `allow_objects` **布林參數**拆成了**兩個獨立的全域函式**。
`_with_objects` 變體存在且可用,即為此拆分的結構性證據。ADR-0003 寫的
`bytes_to_var(bytes: PackedByteArray, allow_objects: bool = false)` 是 **Godot 3 的簽章**。

**「`allow_objects` 預設值是否為 `false`」這個問題在 4.7.1 不成立** —— 該參數不存在。
語意上的等價物是「選哪一個函式」:`bytes_to_var()` 即不允許 Object 的那一個(F2 已實測其行為)。

**內省路徑走不通(明確記為此路不通,非未做)**:
`ClassDB.class_exists("@GlobalScope")` 與 `ClassDB.class_exists("@GDScript")` **皆為 `false`**,
`class_get_method_list("@GlobalScope")` 回傳空陣列 —— 全域工具函式不是 Object 方法,
未登記於 `ClassDB`。**因此 F1 的 arity 是以「編譯測試」確定的,不是以內省確定的。**
編譯測試的證據力對本問題而言是充分的(parse error 訊息逐字給出 `Expected at most 1`),
但它取得的是 arity 與錯誤訊息,**不是完整的形式簽章(參數名、預設值、回傳型別標註)** ——
那部分**未查證**。對比之下 F3 的 `HashingContext` 是登記類別,`ClassDB` 內省可用,故有完整簽章。

---

## 結果 / 階段 2

### F2 —— `bytes_to_var()` 對本應解碼出 Object 的輸入(VR#2,ADR 自陳最高優先)

> ★ 這一節同時回答了 F1 發現所連帶產生的新問題:**1 引數的 `bytes_to_var(b)` 是否真的拒絕 Object?**
> **答案:是。** 所有 Object 輸入一律 `typeof=0`(TYPE_NIL)、`is_null=true`,無一回傳 Object。

| 測項 | 輸入 | 結果 |
|---|---|---|
| 對照組 | 乾淨 Dictionary | `typeof=27`(DICTIONARY),與來源 `==` 為 `true` |
| **F2-a** | 頂層即 `RefCounted` | **回傳 `null`,不中止**。三個 sentinel **全部印出**,函式回傳 `S3-F2a-REACHED-END` |
| **F2-b** | Dict:3 合法鍵 + 1 Object 值 | **整包失敗,回傳 `null`** —— **無部分解碼**,拿不到那 3 個合法鍵 |
| **F2-c** | Dict → Array → Object(第 3 層) | 與第 1 層**同行為**:回傳 `null`,不中止 |
| **F2-g** | 內建 `RefCounted` | 回傳 `null` |
| **F2-g** | 自訂 `class_name` 的 `RefCounted` 子類 | 回傳 `null`(同行為) |
| **F2-g** | 自訂 `class_name` 的 `Resource` 子類 | 回傳 `null`(同行為) |

**F2-d 錯誤訊息(逐字抄錄)**:

```
ERROR: Condition "!p_allow_objects" is true. Returning: ERR_UNAUTHORIZED
   at: decode_variant (core/io/marshalls.cpp:718)
ERROR: Error when trying to decode Variant.
   at: decode_variant (core/io/marshalls.cpp:860)
```

巢狀越深,`Error when trying to decode Variant.` 越多層(F2-c 出現 2 次,F4'-b2 出現 3 次)——
每一層容器各報一次,最內層是 `ERR_UNAUTHORIZED` 那一行。

**F2-e 非 Object 的壞位元組**(**全部回傳 `null`,無一中止、無一回傳垃圾**):

| 輸入 | 引擎錯誤 |
|---|---|
| 空 `PackedByteArray` | `Condition "len < 4" is true. Returning: ERR_INVALID_DATA` |
| 截斷至一半 | `Condition "strlen < 0 \|\| strlen + pad > len" ... ERR_FILE_EOF` |
| 只剩 4 bytes 型別標頭 | `Condition "len < 4" ... ERR_INVALID_DATA` |
| 64 bytes 固定 `0xDEADBEEF` 樣式 | `Condition "(header & 0xFF) >= Variant::VARIANT_MAX" ... ERR_INVALID_DATA` |
| 合法型別標頭 + 假造超大長度 | `Condition "count < 0 \|\| count > len" ... ERR_INVALID_DATA` |
| 16 個零位元組 | **無錯誤訊息**,乾淨回傳 `null`(type 0 = NIL 是合法編碼) |

⚠️ **最後一列值得注意**:全零位元組是**合法的 NIL 編碼**,回傳 `null` 且**不報錯**。
也就是說 `null` 這個回傳值**無法區分**「解碼失敗」與「成功解碼出一個 NIL」。
ADR 機制三第 5 步「解碼失敗視為 `DATA_CORRUPTED`」若以 `== null` 判定,
會把一份全零的損毀檔案與合法的 NIL payload 混為一談(實務上 payload 應為 Dictionary,
故建議以 `is Dictionary` 而非 `!= null` 判定 —— 但**這是本探針的觀察,不是 ADR 現行寫法**)。

#### 🔴 F2-f 寫入側 —— 本探針最重要的**非預期**發現

`var_to_bytes()`(**不帶** `_with_objects`)對含 Object 的 Dictionary:
**不報錯、不丟棄、不寫 `null`,而是把 Object 編碼成它的 ObjectID。**

```
var_to_bytes({"alpha": 1, "poison": RefCounted.new()})
  → size=60,成功,零錯誤訊息
bytes_to_var(該緩衝區)
  → typeof=27,{ "alpha": 1, "poison": <EncodedObjectAsID#-9223372005078727208> }
  → dd["poison"] 的 typeof = 24(TYPE_OBJECT),值為 EncodedObjectAsID
```

頂層直接是 Object 時同理(12 bytes,回傳 `EncodedObjectAsID`)。

**這條路徑完全靜默** —— 寫入端不報錯、讀取端也不報錯,而且**繞過了型別白名單**:
`bytes_to_var()` 對 `EncodedObjectAsID` **不觸發** `ERR_UNAUTHORIZED`,`typeof` 是 24
(TYPE_OBJECT)而非 27/NIL。ADR-0003 機制一(第 66 行)要求 payload
「不含任何自訂 `Object`/`Resource`」,但**引擎在寫入側不強制這件事**,
上游 `export_state()` 若漏掉一個 Object,會靜默寫進存檔並在讀回時變成一個無意義的
物件 ID。**這是紀律要求,不是結構保證** —— 與 ADR-0002 `AffinityRecordList.items`
那一項同形狀(GDScript 無真正私有成員,故該項亦為紀律而非結構保證)。

### F4' —— manifest 分層(ADR 機制二,第 88–97 行)

| 測項 | 結果 |
|---|---|
| **F4'-a 不遞迴** | ✅ 外層一次 `bytes_to_var()` 得到 `typeof=27`;`blocks['affinity_data_pool']` 為 `typeof=29`(**TYPE_PACKED_BYTE_ARRAY,未解碼**);與 `inner_buf` **`==` 為 `true`、hex 逐位元組相同、長度皆 160**;第二階段解碼後 `== 原 payload` 為 `true` |
| **F4'-b 毒區塊** | ✅ **外層解碼成功** —— manifest(`ruleset_version` / `block_manifest`)**完整可讀**,好區塊二次解碼正常(`{ "k": 42 }`),壞區塊二次解碼回傳 `null` 且行為與 F2-a **一致** |
| **F4'-b2 對照組** | 扁平巢狀寫法(ADR Alternative 3,已被拒)整包 `null` —— **manifest 一併讀不到**,確認 ADR 拒絕該方案的理由在位元組層面成立 |

**F4'-b 是本探針對 ADR 最有利的一項**:一個含 Object 的損毀區塊**不會**污染 manifest 讀取,
`TR-save-012` 的 manifest-only 路徑安全前提**成立**。

### F4'-c 浮點位元保真

**第一版(浮點字面量)13 個向量全部 `BIT_IDENTICAL=true`,但其中 2 個向量無效** ——
`+0.0` 與 `5e-324` 印出的 `bits_in` 與 `-0.0` 完全相同(`0000000000000080`),
表示那兩個值**在進入序列化之前就已經不是我想測的值**。這是探針缺陷,不是序列化缺陷,
但既然那兩格沒測到宣稱在測的東西,就補了一版不依賴字面量的:

**補測(`f4c2`,以 `PackedByteArray.decode_double()` 從明確位元組樣式構造)——
12 個向量,`CONSTRUCT_OK` 與 `ROUNDTRIP_BIT_IDENTICAL` **全部 `true`**:**

`+0.0` / `-0.0` / min subnormal / max subnormal / min normal / `0.1` / `+INF` / `-INF` /
quiet NaN / **NaN with payload** / **signaling NaN** / max double

另:`int` 與 `float` 的型別區分往返後保住(`typeof` 各為 2 / 3)。

#### 🆕 順帶量到的 GDScript 事實(範圍外,但與 AC-24 直接相關)

判別性測試 `f4c3`(唯一自變數:哪個零值字面量先出現):

| 檔案 | 先出現 | 後出現 | 結果 |
|---|---|---|---|
| `f4c2` | `-0.0` | `0.0`、`5e-324`、`float(0)`、`1.0 - 1.0` | **後者全部印出 `-0.0` 的位元** |
| `f4c3` | `0.0` | `-0.0` | **後者印出 `+0.0` 的位元**(`1.0/x` 獨立驗證為 `inf`,非 `-inf`) |

**結論:同一 `.gd` 檔內所有「值為零」的 float 編譯期常數會被去重成同一個常數,
先出現者的符號勝出。** 也就是說 **原始碼裡寫 `-0.0` 不保證拿到 `-0.0`。**
(推測成因為常數池以 Variant 相等性去重,而 IEEE754 下 `-0.0 == 0.0` 為 `true`;
**成因屬推測,未查證** —— 已量到的是上表的行為本身。)

**與本專案的關聯**:GDD AC-24 要求「位元完全相同」。若驗收測試以浮點字面量
寫期望值,`-0.0` 這類向量可能**測不到它宣稱在測的東西**。序列化層是乾淨的(上面 12/12),
風險在**測試碼的寫法**。

### F3 —— `HashingContext`(VR#3 / #3a)

**`ClassDB` 內省(HashingContext 是登記類別,內省可用)取得的真實簽章**:

| 方法 | 參數 | 回傳 |
|---|---|---|
| `start` | `type: HashingContext.HashType` (type 2) | **`Error`**(type 2) |
| `update` | `chunk: PackedByteArray` (type 29) | **`Error`**(type 2) |
| `finish` | 無 | **`PackedByteArray`**(type 29) |

| 測項 | 結果 |
|---|---|
| `HashingContext.HASH_SHA256`(短形式) | ✅ 可用,值 = **2** |
| `HashingContext.HashType.HASH_SHA256`(完整路徑) | ✅ **也可用**,值 = 2 —— **兩個都可用** |
| enum 成員 | `HashType -> ["HASH_MD5", "HASH_SHA1", "HASH_SHA256"]`;整數常數 `HASH_MD5=0` / `HASH_SHA1=1` / `HASH_SHA256=2` |
| 三段式實測 | `start()` → `typeof=2` 值 `0`(OK);`update()` → `typeof=2` 值 `0`;`finish()` → `typeof=29` size **32** |
| **演算法身分獨立確認** | `SHA-256("abc")` = `ba7816bf...f20015ad`,**與已知標準答案逐字相符**;空輸入 = `e3b0c442...7852b855`,亦相符 |
| **F3b 分段一致性** | one-shot / 2 段 / 4 段 `update()` 三者 digest **完全相同** —— ADR 機制四的逐段 `update()` 成立 |
| 未 `start()` 就 `update()` | 不中止,回傳 `Error` **3**(`ERR_UNCONFIGURED`),並報 `Parameter "ctx" is null.` |
| 未 `start()` 就 `finish()` | 不中止,回傳 **size=0 的空 `PackedByteArray`** ⚠️ |

⚠️ **`finish()` 的失敗回傳值是空 `PackedByteArray`,不是 `null`** —— 若實作忽略
`start()`/`update()` 的 `Error` 回傳值,會拿到一個長度 0 的「雜湊」而非明確失敗。
`start`/`update` 皆回傳 `Error`,**應檢查**。

**F3a 一次性便利方法(VR#3a)**:

| 方法 | 結果 |
|---|---|
| `PackedByteArray.sha256_buffer()` | **🔴 不存在** —— `Parse Error: Cannot find member "sha256_buffer" in base "PackedByteArray".` |
| `String.sha256_buffer()` | ✅ 存在,輸出 = `ba7816bf...`,**與三段式位元相同**,size 32 |
| `String.sha256_text()` | ✅ 存在,輸出為 hex **String**,`ba7816bf...`,與三段式相同 |

**判讀**:便利方法**只在 `String` 上有,`PackedByteArray` 上沒有**。而 ADR 機制四的雜湊輸入
**正是 `PackedByteArray`**(區塊緩衝區)。因此 **VR#3a 的簡化機會對本 ADR 不適用** ——
`HashingContext` 三段式是 `PackedByteArray` 輸入的唯一路徑,ADR 現行設計不需要也不能簡化。

### F5 —— 大緩衝區(VR#5)

| 情境 | 編碼後大小 | `var_to_bytes` | `bytes_to_var` | SHA-256 |
|---|---|---|---|---|
| **實際規模對照**:500 筆記錄 | 52.7 KB | 1 ms | 1 ms | 0 ms |
| 32 MB `PackedByteArray` | 32 MB | 7 ms | 14 ms | 138 ms |
| 64 MB `PackedByteArray` | 64 MB | 15 ms | 30 ms | 259 ms |
| 100,000 筆記錄(3 鍵 Dict) | 7.63 MB | 111 ms | 116 ms | 28 ms |
| **500,000 筆記錄**(3 鍵 Dict) | 38.13 MB | 425 ms | 497 ms | 114 ms |

全部往返 **byte-identical / size preserved / 抽樣核對通過**,**無失敗、無效能懸崖**。
呈線性:64MB 約為 32MB 的 2 倍;500k 筆約為 100k 筆的 4~5 倍。
**GDD 估計的單槽數十 KB 規模,三項操作合計 < 2 ms。**

⚠️ 未逼近 2GB 上限(會 OOM),**大小上限本身未查證**。

---

## 對 ADR-0003 的影響分類

### (a) 已實測確認 ADR 宣稱成立

- **核心洞見(第 62 行)成立**:該解碼路徑**確實**在引擎層級拒絕產生任何 `Object` 衍生實例,內建/自訂 `RefCounted`/自訂 `Resource` 三者一致,深層巢狀同行為。型別白名單「結構性地不存在」的論證**站得住**。
- **VR#2 的三個子宣稱全部成立**:①「整個容器解碼呼叫**原子性失敗**」— 成立(F2-b 無部分解碼);②「回傳 `null`」— 成立(**不中止呼叫函式**,機制三第 5 步可實作);③「伴隨 console/log 錯誤訊息」— 成立(逐字見上)。
- **VR#4 成立**:巢狀 `PackedByteArray` 往返保真,外層解碼**不遞迴解讀**其內容。
- **VR#3 成立**:短形式與完整路徑**兩者皆可用**;三段式簽章與 ADR 描述一致;分段 `update()` 一致性成立;演算法確為標準 SHA-256。
- **VR#5 成立**:無效能懸崖。
- **機制二對 Alternative 3 的拒絕理由成立**(F4'-b2 對照組)。
- **manifest-only 路徑的安全前提成立**(F4'-b,ADR 未列為 VR 但整條路徑押在此)。
- **拒絕 JSON 的浮點理由成立**:12 個位元向量往返全部 bit-identical,含 subnormal 與 NaN payload。

### (b) 🔴 已實測推翻 ADR 宣稱

| # | 推翻內容 | 受影響位置 |
|---|---|---|
| **B-1** | **`bytes_to_var(buffer, false)` / `var_to_bytes(v, false)` 兩引數形狀在 4.7.1 是 Parse Error。** 正確形狀為 1 引數;Godot 4 已把 `allow_objects` 拆成獨立的 `*_with_objects()` 函式 | **全文 18 處**(16 行):第 **17、20(×2)、58、62、66、95(×2)、103、107、151、181、191、218、290、297、308、338** 行 |
| **B-2** | **「`allow_objects` 參數預設即為 `false`,本 ADR 一律顯式傳入 `false`(不依賴預設值)」這段縱深防禦論述,其前提(該參數存在)不成立。** 4.7.1 無此參數 | 第 **66** 行(論述本體)、第 **20** 行 VR#1(簽章)、第 **309** 行(`allow_objects=false` 措辭) |
| **B-3** | **VR#3a 的簡化機會對本 ADR 不適用** —— 便利方法只存在於 `String`,而 ADR 的雜湊輸入是 `PackedByteArray`。ADR 第 302 行 Risks 表把它列為「潛在的實作簡化機會」,實測為**不存在的機會** | 第 **20** 行 VR#3a、第 **302** 行 Risks 表 |

> **B-1 的性質須說清楚**:這是**寫法錯誤,不是決策錯誤**。ADR 選定的格式、型別安全論證、
> 分層結構、雜湊機制**全部經實測成立**。需要修的是 API 形狀,不是任何一項決策。
> 但它**不能只當成筆誤**:第 66 行的「顯式傳 `false` 作為縱深防禦」是一段**實質論述**,
> 其前提已不成立(B-2),必須改寫而非只刪兩個字元。

### (b') 🟠 已實測、ADR 未涵蓋的新風險(不是推翻,是缺口)

| # | 內容 | 建議去處 |
|---|---|---|
| **N-1** | **`var_to_bytes()` 在寫入側不拒絕 Object,而是靜默編成 `EncodedObjectAsID`,讀回為 `typeof=24` 且不觸發 `ERR_UNAUTHORIZED`** —— 機制一第 66 行「payload 不含任何自訂 Object」是**紀律要求,無引擎強制**。這條路徑繞過型別白名單且**兩側全靜默** | 機制一須明文;可考慮登記 forbidden pattern |
| **N-2** | **全零位元組是合法 NIL 編碼,回傳 `null` 且不報錯** → `== null` 無法區分「解碼失敗」與「合法 NIL」。機制三第 5 步宜以 `is Dictionary` 判定 | 機制三第 5 步 |
| **N-3** | **`HashingContext.finish()` 在未 `start()` 時回傳空 `PackedByteArray` 而非 `null`**;`start`/`update` 回傳 `Error` 應檢查,否則會拿到長度 0 的「雜湊」 | 機制四 |
| **N-4** | **同一 `.gd` 檔內值為零的 float 編譯期常數會被去重,先出現者符號勝出**(`-0.0` 寫了不保證拿到 `-0.0`)。序列化層乾淨,風險在 **AC-24 驗收測試的寫法** | 測試標準 / GDD AC-24 註記 |

### (c) 未查證(明說卡在哪,不編造)

| # | 項目 | 卡在哪 |
|---|---|---|
| 1 | `var_to_bytes` / `bytes_to_var` 的**完整形式簽章**(參數名、回傳型別標註) | `ClassDB` 對 `@GlobalScope`/`@GDScript` 皆 `class_exists() = false`,全域工具函式未登記,**內省此路不通**。已取得的是 arity 與 parse error 訊息,足以判定 B-1,但不等於完整簽章 |
| 2 | `var_to_bytes` 的**大小上限**(理論 ~2GB) | 刻意未測 —— 逼近會 OOM 並可能讓整支探針失去其餘結果。已測到 64MB 線性無懸崖 |
| 3 | **release build** 行為 | 全部量測皆在 debug/headless。`ERR_UNAUTHORIZED` 的錯誤訊息在 release 是否仍輸出、回傳值是否仍為 `null`,**未查證**(與 ADR-0002 三層圖像的「層二 release 未查證」同性質) |
| 4 | F4'-c 的**成因**(常數池以 Variant 相等性去重) | 行為已由 `f4c3` 判別性測試量到且方向明確,但**機制本身屬推測**,未讀引擎原始碼確認 |
| 5 | `EncodedObjectAsID` 值在**跨行程/跨存檔**時的行為 | N-1 只測了同一行程內的往返。該 ID 顯然無跨行程意義,但**未實測**其在重新啟動後的解碼結果 |
| 6 | ADR 機制五的 `SaveEnumRegistry`、機制六的 `SaveBlockRegistry` | **不在本探針範圍** —— 兩者是本專案自訂的概念契約,不是引擎行為,無可實機驗證的引擎宣稱 |

---

## 本探針自身的過程失誤(執行者主動自陳,證據保留)

**F4'-c 第一版用浮點字面量當位元級測試向量,其中 2 個向量(`+0.0`、`5e-324`)無效** ——
它們的 `bits_in` 與 `-0.0` 完全相同,即該向量在進入序列化前就已不是預期值。
第一版全部 13 列都印 `BIT_IDENTICAL=true`,**若不逐列核對 `bits_in` 就會直接當成 13/13 通過**。

**修法**:新增 `f4c2`(以 `decode_double()` 從位元組樣式構造,不經任何浮點字面量)
與 `f4c3`(判別性測試,唯一自變數是字面量出現順序)。**第一版刻意保留在 `f4c_float_fidelity.gd`
與 log 中**,作為「用字面量測位元」這個錯誤本身的證據,而非事後刪除 —— 沿用
`prototypes/xcheck-round7-2026-08-20` 對探針 C 第一版的處理方式。

**教訓(可推廣)**:`BIT_IDENTICAL=true` 這種「比較輸入與輸出」的斷言,
**在輸入本身就錯的情況下仍然會通過**。位元級測試必須額外斷言「輸入確實等於指定位元」
(`f4c2` 的 `CONSTRUCT_OK` 欄就是為此而加)。

---

## 檔案清單

```
project.godot                     # 含 flush_stdout_on_print=true
scenes/F1.tscn                    # 階段 1
scenes/F.tscn                     # 階段 2
scripts/runner_f1.gd              # 階段 1 runner
scripts/runner_f.gd               # 階段 2 runner
scripts/f1a..f1f_*.gd             # F1 簽章 / arity(每個 arity 各自一檔)
scripts/f2_custom_ref.gd          # class_name F2CustomRef  (F2-g)
scripts/f2_custom_res.gd          # class_name F2CustomRes  (F2-g)
scripts/f2_object_decode.gd       # F2-a/b/c/f/g
scripts/f2e_bad_bytes.gd          # F2-e
scripts/f3a_hash_ctx_returns.gd   # F3 回傳型別(指派回傳值 → void 會整檔失敗)
scripts/f3b_hash_qualified_enum.gd# F3 完整路徑 enum
scripts/f3c1/f3c2/f3c3_*.gd       # F3a 便利方法(各自一檔:不存在即 parse error)
scripts/f3d_hash_segmented.gd     # F3 ClassDB 內省 / 已知答案 / 分段一致性
scripts/f4_manifest_layering.gd   # F4'-a / F4'-b / F4'-b2
scripts/f4c_float_fidelity.gd     # F4'-c 第一版(含已知缺陷,刻意保留)
scripts/f4c2_float_from_bits.gd   # F4'-c 補測(位元構造)
scripts/f4c3_zero_order.gd        # F4'-c 判別性測試
scripts/f5_large_buffer.gd        # F5
logs/probeF1-signatures-unfiltered.txt
logs/probeF2-main-unfiltered.txt
```

**決定性**:全探針零 RNG —— 「隨機」壞位元組用固定 `0xDEADBEEF` 樣式,
大緩衝區填充用 `(i / 65536) % 251` 固定式,浮點向量為明確位元組常數。重跑結果應逐字相同
(F5 的毫秒數除外)。
