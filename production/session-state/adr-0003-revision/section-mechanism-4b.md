# 機制四之二:雜湊計算規則

> 本節填補草案檔頭表格對「機制四之二」的前向引用(該引用目前指向空白章節,是本專案
> 記錄在案的失誤模式)。內容範圍:`HashingContext` 的完整使用契約、雜湊輸入的正規化
> 規則。**不重複定義欄位清單**——manifest 條目欄位清單的權威來源是
> `section-mechanism-1b.md`(`godot-gdscript-specialist` 同時撰寫中)的
> `MANIFEST_ENTRY_FIELDS`,本節只說明雜湊正規化如何消費它。
>
> 全部宣稱只採信 `docs/engine-reference/godot/modules/core-serialization.md` 第 5、7 節
> 與其引用的探針 log(2026-08-21,headless,`Godot 4.7.1.stable.official.a13da4feb`)。
> 無法附出處的一律明文標記為推論。

## 1. `HashingContext` 完整方法簽章

`HashingContext` 是登記類別,以下簽章來自 `ClassDB` 內省(非文件外推):

| 方法 | 簽章 | 回傳 |
|---|---|---|
| `start` | `start(type: HashingContext.HashType) -> Error` | `Error`(int) |
| `update` | `update(chunk: PackedByteArray) -> Error` | `Error`(int) |
| `finish` | `finish() -> PackedByteArray` | `PackedByteArray` |

本 ADR 採 `HashingContext.HASH_SHA256`。

**證據**:`docs/engine-reference/godot/modules/core-serialization.md` 第 5 節(168-176 行);
探針 F3(`prototypes/xcheck-adr0003-2026-08-21/logs/probeF2-main-unfiltered.txt` 尾段)。

## 2. 狀態機與誤用回傳碼(完整表)

錯誤碼數值(已由 log 逐字印出確認):`OK=0`、`FAILED=1`、`ERR_UNCONFIGURED=3`、
`ERR_ALREADY_IN_USE=22`。

**證據**:`prototypes/xcheck-adr0003-2026-08-21/xcheck-gdscript-shape-2026-08-21/logs/probeJ-run3-unfiltered.txt`
第 165 行逐字:`J7: ERR_ALREADY_IN_USE=22  ERR_UNCONFIGURED=3  FAILED=1`。

| # | 操作序列 | 回傳 / 結果 |
|---|---|---|
| 1 | 全新 `HashingContext` → `start()` | `OK(0)` |
| 2 | `start()` 後**未餵資料**就再 `start()` | 第二次回 `ERR_ALREADY_IN_USE(22)` |
| 3 | `start()` → `update()` 餵過資料後,再 `start()` | 同樣回 `ERR_ALREADY_IN_USE(22)`,**且不重置**——見下方 3a 的載重宣稱 |
| 4 | `finish()` 之後再 `update()` | `ERR_UNCONFIGURED(3)` |
| 5 | `finish()` 呼叫第二次(不重新 `start()`) | 回**空** `PackedByteArray`(`size=0`) |
| 6 | 未 `start()` 就 `finish()` | 同樣回空 `PackedByteArray`(`size=0`) |
| 7 | `finish()` 後重新 `start()` + `update()` + `finish()` | 正常運作,可重用同一個 `HashingContext` 實例 |
| 8 | `update()` 傳入空 `PackedByteArray` | 回 `FAILED(1)`,但**不影響**該次 `finish()` 的正確性——若這是唯一一次 `update()`,`finish()` 仍給出空輸入的標準 SHA-256(`e3b0c442...`) |

### 3a. 載重宣稱:「已餵資料後再 `start()` 被拒,但不重置,會接續累積」

這是本節唯一標記為載重(load-bearing)的宣稱,獨立驗證兩次:

- **探針 J6**(尚未餵資料就重複 `start()`):log 顯示
  `J6-D1: start() 第一次 err=0,第二次 err=22`,而
  `J6-D1: 二次 start 後 finish() size=32 hex=ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad`
  ——這個 hex 等於單次 `SHA256("abc")` 的標準值,說明**未餵資料時**重複 `start()`
  雖被拒絕,但狀態沒有被破壞。
- **探針 J7**(刻意補測「已餵資料後」的情境,J6 沒測到這格):
  ```
  J7a: start err=0
  J7a: update(abc) err=0
  J7a: 已餵資料後再 start() err=22
  J7a: update(abc) 第二次 err=0
  J7a: finish hex=bbb59da3af939f7af5f360f2ceb80a496e3bae1cd87dde426db0ae40677e1c2c
    對照 SHA256(abc)    = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
    對照 SHA256(abcabc) = bbb59da3af939f7af5f360f2ceb80a496e3bae1cd87dde426db0ae40677e1c2c
  ```
  `finish()` 的輸出與**同一行印出的獨立複算** `"abcabc".sha256_text()` 逐字元相同,
  而與單次 `SHA256("abc")` 不同。這代表第二次 `start()` 回 `ERR_ALREADY_IN_USE` 之後,
  context **沒有被重置**,後續 `update("abc")` 是接在第一次的 `"abc"` 之後繼續累積雜湊,
  而不是靜默開了一個新的雜湊。

**後果**:呼叫端若不檢查 `start()` 的 `Error` 回傳值,並誤以為「呼叫了 `start()`
就代表雜湊器已重新開始」,會在跨區塊重用同一個 `HashingContext` 實例時,把上一個
區塊的資料悄悄累積進下一個區塊的雜湊——雜湊值仍會「成功」算出來,但内容錯誤,
且沒有任何 `Error` 以外的訊號提示這件事。因此契約規定:**每個區塊的雜湊必須用
獨立的 `HashingContext.new()` 實例**,不得跨區塊重用同一個實例(即使呼叫端有檢查
`Error` 也不建議重用,重用只在明確需要「串接多個緩衝區算同一份雜湊」時使用)。

**證據**:`prototypes/xcheck-adr0003-2026-08-21/xcheck-gdscript-shape-2026-08-21/logs/probeJ-run3-unfiltered.txt`
第 128-129 行(J6-D1)、第 165-177 行(J7a,含逐字 hex 對照)。

### 3b. `size()==0` 與「兩個空陣列相等」的交互——為何 `hash_matches()` 要先比長度

探針 J6-D6 同時記錄了两件事:未 `start()` 就 `finish()` 得到 `size=0` 的
`PackedByteArray`,而且 `PackedByteArray() == PackedByteArray()` 為 **`true`**：

```
J6-D6: 未 start 就 finish size=0  == PackedByteArray() -> true
J6-D6: 兩個空 PackedByteArray 相等 -> true
```

這意味著:若某處雜湊計算因為任何原因失敗而回傳空陣列(例如契約 3a 提到的誤用,
或呼叫端忘記檢查 `HashingContext` 方法的 `Error` 回傳值),而比對的另一側也剛好因為
另一個獨立的原因回傳空陣列,單純寫 `computed_hash == stored_hash` 會得到 `true`——
兩邊都失敗,卻判定為「雜湊相符」。

**證據**:`prototypes/xcheck-adr0003-2026-08-21/xcheck-gdscript-shape-2026-08-21/logs/probeJ-run3-unfiltered.txt`
第 160-161 行。

因此本 ADR 規定雜湊比對一律走以下契約(先驗長度,長度不合法就直接判失敗,絕不
落入內容比較):

```gdscript
static func hash_matches(computed: PackedByteArray, stored: PackedByteArray) -> bool:
	# SHA-256 固定輸出 32 bytes;長度不對本身就是損毀或計算失敗的訊號,
	# 不可以落到下面的內容比較——兩邊都是空陣列時 `==` 會回 true,是假通過。
	if computed.size() != 32 or stored.size() != 32:
		return false
	return computed == stored
```

`godot-specialist` 與 `godot-gdscript-specialist` 在前一輪覆核中各自獨立寫出這個函式,
理由相同(`CROSSCHECK.md` 已記錄為兩軌獨立收斂項目)。本節將其正式收為機制四之二的
契約,所有雜湊比對(逐區塊雜湊、頂層雜湊)一律呼叫 `hash_matches()`,禁止直接寫
`==`。

## 3. `PackedByteArray` 沒有 `sha256_buffer()` —— 三段式是唯一路徑

`sha256_buffer()` / `sha256_text()` 只存在於 `String`,`PackedByteArray` 上呼叫會是
編譯期錯誤(逐字):

```
Parse Error: Cannot find member "sha256_buffer" in base "PackedByteArray".
```

本 ADR 的雜湊輸入是區塊序列化後的 `PackedByteArray` 緩衝區,不是 `String`,因此三段式
`start()`/`update()`/`finish()` 沒有更簡潔的便利方法可以替代——先前草案在
Verification Required 提過「`godot-specialist` 低信心度觀察,可能存在一次性便利方法」
一項,本節據此關閉:**不存在**,已用逐字錯誤訊息驗證,非推測。

**證據**:`docs/engine-reference/godot/modules/core-serialization.md` 第 5 節
(193-196 行);探針 F3c1/F3c2/F3c3
(`prototypes/xcheck-adr0003-2026-08-21/scripts/f3c1_pba_sha256_buffer.gd` 等三個腳本,
`prototypes/xcheck-adr0003-2026-08-21/logs/probeF2-main-unfiltered.txt`)。

## 4. 雜湊輸入必須是固定順序的陣列,不能是 Dictionary

**引擎事實**:兩個 `==` 相等、鍵值完全相同、但**插入順序不同**的 `Dictionary`,
`var_to_bytes()` 編碼出的位元組**不同**;改用 `Array`(位置決定順序而非插入順序)
承載相同資料,編碼結果**相同**。

**證據**:探針 x3(`prototypes/save-format-skeleton-2026-08-21/scripts/x3_dict_key_order.gd`),
結果記錄於 `prototypes/save-format-skeleton-2026-08-21/README.md` 階段 0 x3 與
「(b) 設計實測不成立」b-1:兩個 `Dictionary`(`{source_id, format_version}`,鍵值相同、
插入順序相反)`var_to_bytes()` 出來的 88 bytes 逐位元組不同;對照的 `Array` tuple
`["affinity_data_pool", 3]` 編碼結果相同。

**後果對本 ADR 是直接的**:機制四的頂層雜湊輸入涵蓋 `block_manifest`,而
`block_manifest` 的每個條目在記憶體中是一個 `Dictionary`(欄位由
`MANIFEST_ENTRY_FIELDS` 定義,見下節)。若正規化只處理了「條目之間」的順序
(例如依 `source_id` 字典序排列 `Array[Dictionary]`),卻沒有處理「條目**內部**
鍵的插入順序」,兩份邏輯相同、寫入時機不同(因此 Dictionary 字面量鍵插入順序不同)
的存檔會算出不同的頂層雜湊——**健康的存檔會被誤判為損毀**。這正是骨架驗證
b-1 指出的洞:草案原文宣稱「不依賴容器迭代順序」,但範圍只覆蓋了區塊間順序,
沒覆蓋條目內鍵序。

**正規化規則(本節的契約)**:

1. 雜湊計算前,每個 manifest 條目一律轉換成**固定欄位順序的 `Array`**
   (tuple),不得直接對條目 `Dictionary` 呼叫 `var_to_bytes()`。
2. 固定順序**必須**取自 `MANIFEST_ENTRY_FIELDS`(`section-mechanism-1b.md` 定義的
   共用常數,S1B 形狀檢查同樣消費它)——本節**不另定一份欄位清單**。理由:
   `CROSSCHECK.md` 已指出「兩份清單各自維護」正是本輪要杜絕的漂移形狀
   (衝突 3,協調者裁決「必須合併」)。任何新增欄位只需要改
   `MANIFEST_ENTRY_FIELDS` 一處,形狀檢查與雜湊正規化會同步生效。
3. 條目之間的順序維持既有決策:依 `source_id` 字典序排列成 `Array[Dictionary]`
   或等效的 tuple 陣列(骨架 c-15 的既有作法:回傳新陣列、手工插入排序,不用
   `sort_custom` + lambda——沿用該決策,原因同樣是「不賭靜態情境下 lambda 這個
   未查證形狀」)。
4. 頂層雜湊的輸入因此是:`Array`(依 `source_id` 排序的區塊)包著每條目的
   `Array`(依 `MANIFEST_ENTRY_FIELDS` 固定順序的欄位值)——兩層都是位置決定
   順序,零 `Dictionary` 直接進雜湊輸入。

## 5. 新開的未查證項

**HashingContext.update() 傳入空 `PackedByteArray` 之後,同一個 context 後續的
`update()` 是否仍正常累積?** 探針 J6-D5 只測了「單次空 `update()` 之後直接
`finish()`」這一種情境(`c3.start()` → `c3.update(PackedByteArray())` 回 `FAILED(1)`
→ 直接 `c3.finish()`,得到空輸入的標準 SHA-256)。**沒有測過**「空 `update()` 之後
再餵一次正常資料、再 `finish()`」的情境——也就是說,`FAILED` 回傳之後 context
是否仍處於可用狀態、後續正常 `update()` 是否會被正確累積,目前無出處可引用。
本 ADR 的實作規則因此保守處理:一旦任何 `update()` 呼叫回傳非 `OK` 的 `Error`,
呼叫端應視整個雜湊計算為失敗、捨棄該 `HashingContext` 實例重新開始,不依賴
「空 `update()` 之後還能繼續正常餵資料」這個未驗證的行為。

**證據(僅涵蓋已測部分)**:
`prototypes/xcheck-adr0003-2026-08-21/xcheck-gdscript-shape-2026-08-21/logs/probeJ-run3-unfiltered.txt`
第 148-154 行(J6-D5)。

## 未涵蓋 / 明確排除的宣稱

- **release build 下本節所有行為是否維持一致**:未查證。全部量測皆在 debug/headless
  建置下取得(`Godot 4.7.1.stable.official.a13da4feb`),本機無 export template 可匯出
  release 建置測試,見 `core-serialization.md` 文末「未查證」表第 1 項,同一限制適用
  於本節。
- 本節不重複列出 manifest 欄位清單本身——見開頭引言與第 4 節第 2 點。
