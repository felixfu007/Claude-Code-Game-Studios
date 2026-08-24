# ADR-0003: 存檔系統序列化格式與型別安全

## Status

Proposed

## Date

2026-08-18(2026-08-24 修訂:六組必修 + 機制一之二、機制四之二)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core(序列化與資料完整性) |
| **Knowledge Risk** | **MEDIUM(2026-08-21 第一次修訂由 HIGH 下調,理由如下;⚠️ 此下調為本次修訂的提案,請覆核者明確確認或否決)**——原 HIGH 的兩項理由**其中一項已消滅、一項仍成立**。**已消滅**:「無專屬 core/scripting 模組參考文件可查」——2026-08-21 已建立 `docs/engine-reference/godot/modules/core-serialization.md` 與 `modules/scripting-typing.md`,兩份皆逐條附探針與未過濾 log 引用,涵蓋本 ADR 依賴的全部 API(四個全域序列化函式、`HashingContext` 完整狀態機、`EncodedObjectAsID`、`Callable`/`Signal`/`RID` 邊界、Variant 型別枚舉全表)。**仍成立**:`var_to_bytes`/`bytes_to_var`/`HashingContext` 在 `breaking-changes.md`/`deprecated-apis.md` 仍為零命中,即**官方仍未記錄這些 API 的任何版本變更**,故不能宣稱「已知穩定」,只能宣稱「本專案已在 4.7.1 實測」。**新增的第三項理由(支持不降到 LOW)**:全部量測皆在 **debug/headless** 下取得,**release 建置行為未查證且本機無法查證**(`%APPDATA%/Godot/export_templates/` 存在但完全是空的,全域零個 `.tpz`)——此缺口與 ADR-0002 第 7 項、ADR-0004 為同一個洞,可一次關三份。⚠️ **本 ADR 的歷史教訓必須保留在此欄**:2026-08-21 探針 F 實測推翻本文件**全文 18 處**逐字採用的呼叫寫法(`bytes_to_var(bytes, false)` 是 **Parse Error**),這是本專案第二次由實機驗證擊落已寫下的 ADR 內容。**該錯誤的根因不是引擎版本變更,而是過期的舊版記憶**——Godot 3 的單一布林參數在 Godot 4 已拆成兩個獨立函式,而 `FileAccess.get_var(allow_objects)`/`store_var(full_objects)` **仍保留第二個布林參數**,「**同一件事、兩種 API 形狀**」正是誤植來源(詳見 `modules/core-serialization.md` 第 1 節) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`deprecated-apis.md`、`current-best-practices.md`、**`modules/core-serialization.md`(2026-08-21 新增,逐條實機驗證)**、**`modules/scripting-typing.md`(2026-08-21 新增)** |
| **Post-Cutoff APIs Used** | 無直接依賴——本 ADR 的區塊緩衝區編解碼改採 `var_to_bytes()`/`bytes_to_var()`(2026-08-18 `godot-specialist` 驗證修訂,見機制一),不呼叫 `FileAccess.store_var()`/`get_var()` 本身。**修訂前的草稿曾誤植依賴 `FileAccess.store_var()`,`godot-specialist` 查核時發現 `breaking-changes.md` 4.3→4.4 表格已明文列出「`FileAccess.store_*` 回傳型別 `void`→`bool`」,原稿 Engine Compatibility 宣稱「無已知」並不準確**——此為過程提醒:「已查閱參考文件」不等於「逐項比對過」。此變更與本 ADR 現行決策(`var_to_bytes`/`bytes_to_var`)無直接交集,但下一份 ADR(原子寫入)若確實呼叫 `FileAccess.store_var()`/`store_buffer()` 寫入磁碟,須檢查其 `bool` 回傳值以偵測寫入失敗,已記入 Risks 表供交接 |
| **Verification Required** | **原五項(含 3a)於 2026-08-21 由探針 F/G/H/J 與存檔格式骨架全數關閉,其中第 1 項的答案是「推翻原假設」。** 證據為 `prototypes/xcheck-adr0003-2026-08-21/`(四支,皆 exit 0,log 未過濾)與 `prototypes/save-format-skeleton-2026-08-21/`(三階段皆 exit 0);整理後的引擎事實見 `docs/engine-reference/godot/modules/core-serialization.md`。**(1) ✅ 關閉,但答案是否定的**——`var_to_bytes` 與 `bytes_to_var` **各只接受一個引數**,Godot 4 已將 Godot 3 的布林參數拆成 `var_to_bytes`/`bytes_to_var`(拒絕 Object)與 `var_to_bytes_with_objects`/`bytes_to_var_with_objects`(允許 Object)兩組獨立函式;寫成兩引數是 **Parse Error**(逐字:`Too many arguments for "bytes_to_var()" call. Expected at most 1 but received 2.`)。本文件原全文 18 處採兩引數形狀,已於本次修訂全部改正。**(2) ✅ 關閉,且答案分兩半——原問法只涵蓋了其中一半。** 讀取側:對「由 `_with_objects` 產生、本應解碼出 Object」的位元組,plain `bytes_to_var()` **整包原子性失敗、回傳 `null`、不中止呼叫函式**,伴隨逐字 `ERROR: Condition "!p_allow_objects" is true. Returning: ERR_UNAUTHORIZED` 與 `Error when trying to decode Variant.`——與原推測相符。**寫入側:原問法完全沒問,而實測結果與直覺相反**——plain `var_to_bytes()` 對任何 `Object`/`Resource` **不報錯、不拒絕**,靜默編成 `EncodedObjectAsID`(4 bytes 型別碼 + 8 bytes ObjectID),還原後欄位全為 `null`,**整個往返無任何錯誤訊息**。內建 `RefCounted`、自訂 `class_name` 子類別、內建與自訂 `Resource` 行為一致。**這是機制一之二(寫入側型別閘門)存在的唯一理由:引擎在寫入側沒有任何安全網。** **(3) ✅ 關閉**——`start(type: HashingContext.HashType) -> Error`、`update(chunk: PackedByteArray) -> Error`、`finish() -> PackedByteArray`;完整狀態機(含各種誤用的回傳碼)見機制四之二。**(3a) ✅ 關閉,答案是不適用**——`PackedByteArray` **沒有** `sha256_buffer()`(`Parse Error: Cannot find member "sha256_buffer" in base "PackedByteArray".`),該便利方法只存在於 `String`。本 ADR 的雜湊輸入一律是 `PackedByteArray`,故三段式 `HashingContext` 是唯一路徑,無簡化空間。**(4) ✅ 關閉**——巢狀 `PackedByteArray` 往返保真,外層解碼不遞迴解讀其內容(`PackedByteArray` 在 Variant 編碼中為一級不透明型別);型別化容器往返後仍保持型別化。**(5) ✅ 關閉於實務範圍**——32MB/64MB 緩衝區與 100k/500k 筆記錄的編解碼與 SHA-256 皆線性成長、無效能懸崖、往返 byte-identical;**未逼近 ~2GB 理論上限**(會 OOM),而本專案估計規模為單槽數十 KB,差距六個數量級。**——以下為本次修訂新開的唯一一項——** **(6) ⛔ 未查證,且本機無法查證:release(export)建置下,上述全部行為是否一致。** 全部量測皆在 debug/headless 取得。卡點是純環境問題而非技術問題:`%APPDATA%/Godot/export_templates/` 目錄存在但完全是空的,全域零個 `.tpz`。**此項與 ADR-0002 第 7 項、ADR-0004 的同一疑問是同一個洞,補齊匯出範本後可一次關閉三份文件。** 依 `docs/architecture/adr-acceptance-criteria.md` 第四節第 1 項,本項**不阻擋核准**——因為不論答案是什麼,本 ADR 的設計都不改變(寫入側閘門本來就必須存在,不能依賴引擎行為) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | `docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`(消費其 `export_state()`/`import_state()` 通用 `Dictionary` 契約作為好感度區塊的 payload 來源;本 ADR 對其 Key Interfaces 做一個小幅回填修訂,新增 `validate_semantics()`,見下方機制六與 Consequences) |
| **Enables** | `docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md`(2026-08-18 已寫入,`TR-save-004~009、-015~021、-024~027、-029~030`)——該 ADR 的原子置換序列所寫入的位元組緩衝區,即本 ADR 機制二定義的逐區塊 `PackedByteArray`;`block_hash` 的輸入來源(本 ADR 機制四)也必須是該 ADR 實際寫入磁碟的同一份緩衝區 |
| **Blocks** | 存檔系統相關 story 中,任何觸及區塊讀寫、型別安全、雜湊驗證的部分;不阻擋純 UI 層(存檔槽瀏覽器介面設計等)的平行工作 |
| **Ordering Note** | 本 ADR 定案的是**位元組層級的內容格式**;寫入並發模型與多檔案原子置換(第 3 項 ADR 的範圍)在很大程度上與內容格式正交——Core Rules #14 的暫存檔寫入→重新命名序列本身不關心位元組內容是什麼。兩份 ADR 因此可以有限度地平行推進,但第 3 項 ADR 動筆前應先讀過本 ADR,確保其「寫入的緩衝區」與「雜湊輸入的緩衝區」引用的是同一個物件(機制四的操作原子性要求) |

## Context

### Problem Statement

`save-system.md`(Foundation 層,已 Approved,歷經 15 輪 `/design-review`、含 security-engineer 對抗性審查)在架構層完全零覆蓋。GDD 本身已經把序列化格式以外的幾乎每一件事鎖到極其精確的程度——manifest 結構、雙層雜湊鏈的涵蓋範圍、讀取路徑的檢查順序、enum 持久化規則——但**序列化格式本身**(`TR-save-001`)明文是唯一懸而未決的 Open Question,且是下游近三分之一需求的共同前提。GDD 自己在 Open Question 3 已留下一項關鍵技術發現(`godot-specialist` 於 GDD 第二輪審查提供):不同格式選項對 Core Rules #9(型別白名單)的實作成本差異巨大,這個差異必須在格式決策當下就可見,不能等到選定格式後才發現某個選項讓白名單「近乎無法強制執行」。本 ADR 的存在理由,就是把這個格式決策連同它牽動的型別安全機制一次做完,讓下游讀寫/遷移邏輯的 ADR 有確定的位元組層級基礎可以依循。

### Constraints

- **GDD 已鎖定、不受本 ADR 裁量的四項硬性規則**(GDD Open Question 3 原文明訂,不因格式選擇而改變):索引鍵與持久化 enum 欄位以字串名稱持久化(Core Rules #10)、manifest 自我完整性標記(Core Rules #8)、反序列化型別白名單(Core Rules #9)、跨平台原子置換為行為契約而非機制假設(Core Rules #14,本 ADR 不涉及,留給下一份 ADR)。
- **威脅模型範圍聲明**(Core Rules #8):本系統防護意外損毀與未經工具協助的手動編輯,**不是**反作弊或防止知情攻擊者竄改的保證——這個範圍界定本 ADR 的型別安全機制目標是「結構性防止誤用與意外」,不是「抵禦已理解本系統設計的攻擊者」。
- **ADR-0002 已建立的先例**:`AffinityDataPool` 採格式無關的 `Dictionary`(`export_state()`/`from_dict()`)而非 `Resource`,已登記於 `docs/registry/architecture.yaml` 的 `affinity_persistence_format` api_decision——本 ADR 的格式選擇若與此矛盾(例如選 `Resource`/.tres),會直接與已登記立場衝突,需要走衝突解決流程;若一致,則 ADR-0002 的決策等於已預先驗證過本 ADR 即將做的選擇。
- **`.claude/rules/design-docs.md` single source of truth**:本 ADR 不重述 GDD 已定義的規則細節(例如雙層雜湊涵蓋範圍的完整推導、四類拒絕代碼的完整語意),只在需要說明格式選擇如何實現這些規則時引用章節名稱。

### Requirements

本 ADR 須同時滿足 `save-system.md` 的下列義務群組(完整逐項對應見下方 GDD Requirements Addressed):

1. **序列化格式本身**(Open Question 3):須選定一個具體格式,且該選擇須讓下列四項硬性規則的實作成本可預見、可論證。
2. **manifest + 區塊結構**(Core Rules #1、#3):每份存檔一份 manifest,列出各資料區塊的來源、版本、完整性標記;支援「僅讀取 manifest」與「完整讀取」兩種路徑,前者不得反序列化任何區塊 payload。
3. **型別白名單**(Core Rules #9):任何實例化必須先通過白名單閘門,未登記型別視為 `DATA_CORRUPTED`,且此閘門必須先於反序列化本身生效。
4. **雙層雜湊鏈**(Core Rules #8):逐區塊雜湊(涵蓋 payload + 來源識別碼 + 格式版本)+ manifest 頂層雜湊(涵蓋規則集版本號 + 逐區塊 tuple 清單,固定順序、不依賴容器迭代順序),雜湊輸入須為寫入前的記憶體資料、且與實際寫入磁碟的是同一份序列化操作產出的同一份緩衝區。
5. **讀取路徑檢查順序**(Core Rules #16,本輪鎖定):頂層完整性標記 → 規則集版本比對(`VERSION_TOO_NEW` 短路)→ 型別白名單閘門 → 語意驗證/遷移鏈。
6. **enum/索引鍵字串化**(Core Rules #10):`Pair` 與任何持久化 enum 欄位(如 `source_i`)一律以字串名稱持久化,退役名稱永久保留、不得重新指派,須有自動化檢查。
7. **驗證器宣告 fail-closed**(Core Rules #7 擴充):每個持久化資料區塊的來源系統必須宣告其欄位語意合法性規則;manifest 列出一個無對應宣告的區塊視為 `DATA_CORRUPTED`。

## Decision

採用 **plain `var_to_bytes()`/`bytes_to_var()` 二進位 Variant 序列化**(拒絕 `Resource`/`.tres` 與 JSON)——搭配**逐區塊獨立序列化為 `PackedByteArray` 緩衝區**的 manifest 分層結構,**SHA-256 雙層雜湊鏈**,**寫入側與讀取側各一道遞迴型別閘門**(機制一之二,2026-08-21 新增——實測證明引擎在寫入側沒有任何安全網),以及**依賴注入的區塊驗證器登記表**。

> **⚠️ 本 ADR 範圍內的四個函式名是決策的一部分,不是實作細節。** 安全性來自**選了哪一個函式**,不是傳了什麼參數:
>
> | 允許 | 禁止 | 為什麼 |
> |---|---|---|
> | `var_to_bytes(v)` | `var_to_bytes_with_objects(v)` | 後者會把 Object 完整編碼進存檔 |
> | `bytes_to_var(b)` | `bytes_to_var_with_objects(b)` | 後者會從存檔實例化 Object——正是 Core Rules #9 要防的事 |
> | (不適用) | `FileAccess.store_var()` / `FileAccess.get_var()` | **見下方禁令範圍** |
>
> **禁令範圍涵蓋 `FileAccess`(2026-08-21 新增,E3)**:`FileAccess.get_var(allow_objects: bool = false)` 與 `FileAccess.store_var(value, full_objects: bool = false)` **確實接受第二個布林參數**。⚠️ **推論、本輪未實機量測**:底層是否與全域函式共用同一份 Variant 線格式,是沿用舊稿的推論——本輪沒有做位元組層級的探針去比對兩者輸出是否逐位元組相同,不可當成實測事實引用。這使它成為一條**外觀合理的等效繞道**:預設值雖然安全,但只要有人寫 `get_var(true)`,本 ADR 的整套型別安全論證就在那一行被繞過,而且**看起來完全像是正常的 Godot 用法**。因此本 ADR 明文禁止在存檔讀寫路徑上使用 `FileAccess.store_var()`/`get_var()`——存檔位元組一律經 `store_buffer()`/`get_buffer()` 以不透明位元組進出磁碟,Variant 編解碼只發生在本 ADR 定義的兩個函式裡(機制一)。
>
> **這兩組 API 的不對稱本身就是本文件出錯的根因**,務必讀 `docs/engine-reference/godot/modules/core-serialization.md` 第 1 節:同一件事、兩種形狀,而 `FileAccess` 兩個方法的第二參數**連名稱都不同**(`allow_objects` vs `full_objects`)。拿 `FileAccess` 當先例去推全域函式,就是那 18 處錯誤的來歷。

### 核心洞見:格式選擇擋下 Object 實例化這一整類風險,完整的型別安全仍需自建閘門補上

---

#### 1. 原宣稱錯在哪

本 ADR 修訂前宣稱「型別白名單問題結構性地不存在」。2026-08-21 的第一版修訂把它收窄
為「這個洞見在**讀取側**成立,在**寫入側**不成立」。**收窄後的版本仍然是假的。**

錯誤的根源是把問題當成**一維**的(「讀取側 vs 寫入側」),但實測顯示至少需要
**兩個維度**才描述得完整:**型別**(哪一個 Variant type)× **側**(寫入/讀取)。
一維框架把 39 個型別當成單一個體處理,而 `Object`(24)與
`RID`/`Callable`/`Signal`(23/25/26)在這兩個維度上的行為組合**互不相同**,
合併敘述必然漏掉其中一種组合。

**定義域檢查**:「讀取側成立」這句話,若指「`bytes_to_var()` 對含危險型別的輸入
一律拒絕」,其真實定義域是 **39 型別中的 1 個**(`Object`,含其所有子類別
`Resource`/`RefCounted`/`Node`),而不是「危險型別」這個措辭所暗示的全體
(`Object`/`RID`/`Callable`/`Signal` 四者)。這正是本專案第二次「收窄到看起來合理的
範圍,而該範圍仍然比實測範圍寬」的案例——第一次是原 ADR 的全稱宣稱本身。

---

#### 2. 二維框架:四象限實測結果

| 型別 | 寫入側(`var_to_bytes()`,plain) | 讀取側(`bytes_to_var()`,plain) |
|---|---|---|
| **`Object`(24)**,含所有 `Resource`/`RefCounted`/`Node` 子類別 | ❌ **不擋**——靜默編碼成 `EncodedObjectAsID`(型別碼 + 8 bytes ObjectID),零錯誤、零丟棄 | ✅ **整包原子性失敗**——回傳 `null`,不中止呼叫函式,伴隨 `ERR_UNAUTHORIZED` 錯誤訊息 |
| **`RID`(23)/`Callable`(25)/`Signal`(26)** | ❌ **不擋**——編碼成功,零錯誤 | ❌ **也不擋**——成功解碼出來,零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗 |

**證據(`Object` 列)**:
- 寫入側靜默編碼:`docs/engine-reference/godot/modules/core-serialization.md` 第 2 節;
  原始量測 `prototypes/xcheck-adr0003-2026-08-21/README.md` 「F2-f 寫入側」
  (`var_to_bytes({"alpha": 1, "poison": RefCounted.new()})` → size=60,零錯誤;
  `bytes_to_var()` 讀回得 `typeof=24` 的 `EncodedObjectAsID`,原欄位全部讀為 `<null>`)。
  同型行為在 `Resource` 上重現於探針 G:`prototypes/xcheck-adr0003-2026-08-21/README.md`
  「G-2a/b/c」(自訂 `class_name` 子類別與內建 `Resource.new()` 行為一致)。
- 讀取側原子失敗:`core-serialization.md` 第 3 節;原始量測同檔「F2 —— `bytes_to_var()`
  對本應解碼出 Object 的輸入」表(F2-a/b/c/g,含逐字錯誤訊息
  `ERROR: Condition "!p_allow_objects" is true. Returning: ERR_UNAUTHORIZED`)。

**證據(`RID`/`Callable`/`Signal` 列)**:
`core-serialization.md` 第 4 節逐字:「這三個型別**全部不受 `allow_objects` 那道閘門
管控**——plain `bytes_to_var()` 對三者一律零 `ERR_UNAUTHORIZED`、零丟鍵、零整包失敗,
`_with_objects` 變體與 1 引數版逐位元組相同。」原始量測見
`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「結果 / G-1」表格
(三型別「plain `var_to_bytes()` 是否成功」「plain `bytes_to_var()` 是否觸發
`ERR_UNAUTHORIZED`」兩列均為「✅ 成功」「❌ 完全不觸發」)。此結果在
`prototypes/save-format-skeleton-2026-08-21/README.md` 驗證 C 的讀取側毒藥向量表中
獨立重現(「`Signal`/`RID`/`Callable`」一列標註「✅ ✅ ✅ **對稱閘門**(引擎完全不擋)」)。

> **這張表本身即回答了指示中所附四象限表格是否有誤的問題**:核對後**未發現錯誤**——
> 指示中的表格與上述證據逐格相符,可直接採用。

---

#### 3. 三個「兩側都不擋」型別的實際危害(性質互不相同,不可合併敘述)

`RID`/`Callable`/`Signal` 雖然在「是否被閘門擋下」這一點上表現相同(都不擋),
但**通過閘門之後的命運完全不同**,危害性質也不同——這正是原 ADR 用單一句子
（「型別白名單問題結構性地不存在」）沒有能力表達的地方。

##### Signal —— 同行程內是全功能物件,`is_null()` 不能當守衛

- **同行程**:還原後 `get_object()` 拿到的是**活體物件**(與來源 `get_instance_id()`
  完全相同),`connect()` 回傳 `0`(OK),`emit()` **處理函式真的執行**
  (`emit_count` 從 0 變 1)。
  **證據**:`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「結果 / G-1」表
  Signal 欄;逐字 log 見
  `prototypes/xcheck-adr0003-2026-08-21/logs/probeG-callable-resource-unfiltered.txt`。
- **跨行程**:`get_object()` 變回 `<Object#null>`,`connect()` 回傳
  `3`(`ERR_UNCONFIGURED`,報 `Parameter "obj" is null."`),`emit()` 未送達。
  但 **`is_null()` 仍回傳 `false`**——這個守衛在跨行程情境下**會誤判為「非空」**,
  必須改用 `get_object() != null` 判定。
  **證據**:`prototypes/save-format-skeleton-2026-08-21/README.md` 階段 2「F-2 `Signal`」
  表,及「判讀陷阱」第 9 項(逐字:「`Signal.is_null()` 回 `false` 但 `get_object()`
  回 `null`——跨行程還原的 Signal 會通過 `is_null()` 這個守衛」)。

##### RID —— 跨行程 id 可重現,指向真實存在的活體資源

`RID` 沒有 `Signal`/`Object` 那種「跨行程變惰性」的降級行為——它的 id 直接是伺服器
配置計數器的產物,**沒有 validator 計數這種保護**。實測:行程 1 存下
`get_id()=94489280512`,行程 2 **第一個** `PhysicsServer2D.body_create()` 配到的 id
**完全相同**,`還原的RID == 本行程新配的RID` 為 `true`。

**證據**:`prototypes/save-format-skeleton-2026-08-21/README.md` 階段 2「F-3 `RID`」
(逐字:「這一格就是『最壞情況』,而且實測成立」「這不是機率碰撞——兩次獨立執行
逐字相同」),同行程對照見 `prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G
「G-1e 的 RID 來源」段(採用 `PhysicsServer2D.body_create()`,量到
`is_valid=true`/`get_id=94489280512`)。**⚠️ 範圍限定**:僅實測
`PhysicsServer2D`,`RenderingServer`/`NavigationServer` 等其他伺服器**未查證**
(見 skeleton README「(d) 未查證」第 4 項)。

##### Callable —— 空殼,但呼叫它會中止呼叫端函式

還原後是 `null::null` 空殼(`is_valid()=false`、`get_object()=<Object#null>`)——
綁定資訊(bound method 的目標物件、lambda 的閉包)從未寫進位元組流,裸值只有
4 bytes(僅型別標頭)。**呼叫這個空殼會中止呼叫端函式**:
`SCRIPT ERROR: Attempt to call function "null::null (Callable)" on a null instance.`,
且常見的守衛寫法(`has()`、`is Callable`)**兩者都會通過**,不會攔下這個中止。

**證據**:`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「結果 / G-1」表
Callable 欄與「G-N1」項;逐位元組編碼相同性見同檔「Callable 的細節」段。

##### 資料是垃圾 vs. 控制代碼跨界指向活體資源——兩種不同性質的問題

- **`Object`(EncodedObjectAsID)是「資料是垃圾」型**:寫入側靜默遺失欄位,讀出的
  ID **同行程內**可用 `instance_from_id()` 復活成完整原物件(欄位齊全、同一實例),
  但**跨行程**已測 2,000 次物件配置、slot 範圍涵蓋舊 slot 後仍回傳 `null`——
  這是觀察到的行為、非引擎保證,但至少目前**未觀察到**跨行程復活。
  **證據**:`core-serialization.md` 第 2 節;`prototypes/save-format-skeleton-2026-08-21/README.md`
  階段 2「F-1 `EncodedObjectAsID`」。
- **`RID`/`Signal` 是「控制代碼跨界指向活體資源」型**:`RID` 已實測**具決定性地**
  指向新行程裡一個真實存在、屬於別人的活體資源(非機率碰撞);`Signal` 同行程內
  是全功能物件,跨行程降級為指向 nothing,但守衛判定本身有陷阱(`is_null()`)。
  這一類問題**不是「資料遺失」,而是「存檔裡的一個號碼,在另一個行程裡恰好對應到
  一個目前正在使用中的真實資源」**——危害的機制與 `Object` 完全不同,不能用同一句
  「型別白名單擋得住」去涵蓋。

**危害排序(沿用探針 G/骨架的排序,附出處)**:`Signal`(同行程時全功能)>
`RID`(跨行程仍是有效的伺服器 handle,且已證實具決定性)> `Callable`(空殼,
但誤用會中止呼叫端函式)。**證據**:`core-serialization.md` 第 4 節「危險程度排序」列;
`prototypes/xcheck-adr0003-2026-08-21/README.md` 探針 G「E1 的一句話答案」段。

---

#### 4. 由此推導出的架構義務(推論,依 §2/§3 的實測結果推導)

1. **寫入側閘門不可省**:`Object` 在寫入側被引擎靜默放行(編成 `EncodedObjectAsID`),
   `RID`/`Callable`/`Signal` 在寫入側也被引擎靜默放行——**四個危險型別在寫入側全部
   沒有引擎層級的安全網**。若只做讀取側閘門,含這四種型別的存檔仍會被成功寫出。
2. **讀取側獨立掃描不可省,且不能只擋 `Object`**:`bytes_to_var()` 只在 `Object`
   一個型別上提供拒絕行為;`RID`/`Callable`/`Signal` 三者讀取側**全部靜默通過**。
   若讀取側只依賴引擎既有的 `ERR_UNAUTHORIZED` 機制(即只防 `Object`),存檔裡的
   `RID`/`Callable`/`Signal` 會被成功解碼並进入應用層,而其後果如 §3 所述並非均等
   ——`Signal`/`RID` 可能是活體資源的參照,`Callable` 呼叫會中止呼叫端函式。
3. **寫入側與讀取側閘門必須擋同一組型別(至少 {23 RID, 24 Object, 25 Callable, 26 Signal}),
   且建議共用同一份實作**——避免兩處清單各自維護、各自漂移成不同的集合(此為推論:
   已量到的是「引擎在兩側都不管這四個型別」,「共用實作可避免漂移」屬工程判斷而非
   量測結果。本次修訂中兩位專家(安全與 GDScript 領域)在互不知情的情況下
   獨立得出完全一致的必須拒絕型別集合,兩軌獨立收斂
   是此項的主要信心來源)。

---

### 機制一:二進位 Variant 序列化(`var_to_bytes`/`bytes_to_var`),拒絕 Resource 與 JSON

每個持久化資料區塊的 payload,由其擁有系統提供一個純 `Dictionary`(巢狀 `Array`/`String`/`int`/`float`/`bool`/`PackedByteArray` 等原生 Variant 型別,不含任何 `Object`/`Resource`——含內建與自訂子類別,兩者行為已實測一致,見機制一之二)——`AffinityDataPool.export_state()`(ADR-0002)已經是這個形狀,不需要任何轉接層。**編碼/解碼機制(2026-08-18 `godot-specialist` 驗證修訂,BLOCKING)**:此 `Dictionary` 透過全域函式 `var_to_bytes(payload) -> PackedByteArray` 序列化成一份記憶體中的位元組緩衝區,讀取時以 `bytes_to_var(buffer) -> Variant` 還原——**不使用** `FileAccess.store_var()`/`get_var()` 承載這一層:`godot-specialist` 查核時指出 GDScript 的 `FileAccess.open()` 只能開啟真實檔案路徑(`res://`/`user://`/絕對路徑),沒有暴露「純記憶體」開啟模式,原草稿「開一個記憶體內或暫存檔案」的描述技術上不成立。`var_to_bytes()`/`bytes_to_var()` 與 `FileAccess.store_var()`/`get_var()` 都是 Variant 編碼/解碼的呼叫介面,差別在於前者是全域函式、不需要 `FileAccess` 物件與暫存檔案——⚠️ **兩者底層是否共用同一份編碼/解碼核心邏輯、線格式是否相同,是沿用舊稿的推論,本輪未做位元組層級量測驗證**(與上方機制一開頭禁令範圍段落標記的是同一個未驗證宣稱),不影響本段落選用全域函式的理由。**本 ADR 的安全性不來自傳了什麼參數,而來自選了哪一個函式**(見上方允許/禁止函式表):`bytes_to_var()`(1 引數版)只接受一個引數,**沒有 `allow_objects` 這個形參可以傳**——會接受該布林參數的是 `FileAccess.get_var()`,本 ADR 已明文禁止在存檔路徑使用它。讀取側對 `Object`(24,含所有 `Resource`/`RefCounted`/`Node` 子類別)的拒絕是 `bytes_to_var()` 的原生行為(整包解碼原子性失敗,機制三步驟 5a);但 `RID`(23)/`Callable`(25)/`Signal`(26)不受這道原生行為管控,解碼一律成功,必須靠機制一之二的獨立掃描在語意驗證/遷移(機制三步驟 6)之前攔截(機制三步驟 5b)——細節不在此重述,見機制一之二與機制三。**外層 manifest 本身若最終確實需要以 `FileAccess` 寫入實體檔案(下一份 ADR 的原子寫入序列),屆時才會用到 `FileAccess` 相關 API**——本 ADR 的兩層緩衝區結構(機制二)全程只處理記憶體中的 `PackedByteArray`,與磁碟 I/O 解耦,兩者的介面交接點見 Related Decisions。

**與 `Resource`/`.tres` 的取捨**(拒絕理由):`ResourceLoader.load()` 的標準路徑無型別過濾參數,原生會依檔案聲明的類別實例化——這與 Core Rules #9「反序列化型別白名單」的存在目的直接衝突,除非另外實作自訂 `ResourceFormatLoader`,而那本身是一個需要獨立維護、且沒有先例可循的攻擊面。

**與 JSON 的取捨**(拒絕理由):JSON 為文字格式,雙精度浮點數無法保證位元級往返(見 GDD Open Question 18,AC-24 的「位元完全相同或誤差 <1e-12」容許誤差假設在 JSON 下不成立)——`AffinityDataPool` 的公式一/二讀值、Delta Log 的 `m_i` 幅度欄位皆為浮點,JSON 格式會直接讓 AC-24 的既有驗收標準失真,需要重新校準成一個較寬鬆、格式相依的容許誤差,這是一個不必要的複雜度來源。此外 JSON 原生沒有 `PackedByteArray`/型別化陣列的概念,巢狀雜湊值(見機制四)須額外編碼為字串(例如 base64 或 hex),增加不必要的轉換層。

### 機制一之二:序列化型別閘門(`SaveTypeGate`)

#### 為什麼需要獨立閘門

機制一「型別白名單問題結構性地不存在」只在**讀取側對 `Object`**成立。完整的二維
威脅模型(**證據**:`core-serialization.md` §2–4):

| 型別 | 寫入側 `var_to_bytes` | 讀取側 `bytes_to_var` |
|---|---|---|
| `Object`(24) | ❌ 靜默編成 `EncodedObjectAsID`,原欄位資料遺失,零錯誤 | ✅ 整包原子性失敗,`ERR_UNAUTHORIZED` |
| `RID`(23)/`Callable`(25)/`Signal`(26) | ❌ 不拒絕 | ❌ **也不拒絕** |

引擎在寫入側完全沒有安全網,讀取側只對 `Object` 一種型別有安全網。`SaveTypeGate`
是寫入/讀取兩側共用的獨立防線。**必須拒絕的型別恰為 4 個**:`RID`/`Object`/
`Callable`/`Signal`。`NodePath`(22)不拒絕(合法常用),但**消費端不得**直接把
存檔裡的 `NodePath` 餵給 `get_node()`——這是介面義務,型別閘門不強制此事,語意
驗證(機制六)才是負責處。

#### `SaveTypeGate` 契約

```gdscript
# ─── save_type_gate.gd ──────────────────────────────────────────
class_name SaveTypeGate extends RefCounted

# 比較式為 depth > MAX_PAYLOAD_DEPTH,語意見下方「深度上限」。
const MAX_PAYLOAD_DEPTH: int = 64

# 35 項:0–22 + 27–38。白名單制,判準恆為 .has(t),絕不寫黑名單 or 鏈。
const ALLOWED_TYPES: Dictionary = {
	TYPE_NIL: true, TYPE_BOOL: true, TYPE_INT: true, TYPE_FLOAT: true, TYPE_STRING: true,
	TYPE_VECTOR2: true, TYPE_VECTOR2I: true, TYPE_RECT2: true, TYPE_RECT2I: true,
	TYPE_VECTOR3: true, TYPE_VECTOR3I: true, TYPE_TRANSFORM2D: true,
	TYPE_VECTOR4: true, TYPE_VECTOR4I: true, TYPE_PLANE: true, TYPE_QUATERNION: true,
	TYPE_AABB: true, TYPE_BASIS: true, TYPE_TRANSFORM3D: true, TYPE_PROJECTION: true,
	TYPE_COLOR: true, TYPE_STRING_NAME: true, TYPE_NODE_PATH: true,
	TYPE_DICTIONARY: true, TYPE_ARRAY: true,
	TYPE_PACKED_BYTE_ARRAY: true, TYPE_PACKED_INT32_ARRAY: true,
	TYPE_PACKED_INT64_ARRAY: true, TYPE_PACKED_FLOAT32_ARRAY: true,
	TYPE_PACKED_FLOAT64_ARRAY: true, TYPE_PACKED_STRING_ARRAY: true,
	TYPE_PACKED_VECTOR2_ARRAY: true, TYPE_PACKED_VECTOR3_ARRAY: true,
	TYPE_PACKED_COLOR_ARRAY: true, TYPE_PACKED_VECTOR4_ARRAY: true,
}

const REJECTED_TYPES: Dictionary = {
	TYPE_RID: true, TYPE_OBJECT: true, TYPE_CALLABLE: true, TYPE_SIGNAL: true,
}

# 容器一律直接拒絕當鍵、不遞迴進去看內容。
const ALLOWED_KEY_TYPES: Dictionary = {
	TYPE_STRING: true, TYPE_STRING_NAME: true, TYPE_INT: true,
}

enum GateRejection { NONE, FORBIDDEN_TYPE, DEPTH_EXCEEDED }

# 回傳結果物件而非 bool,安全前提見下方程式碼後的說明。
class GateResult extends RefCounted:
	var rejection: GateRejection = GateRejection.NONE
	var path: String = ""
	func ok() -> bool:
		return rejection == GateRejection.NONE

static func scan(payload: Variant) -> GateResult:
	return _walk(payload, 0, "payload")

# 讀取側 deserialize_manifest() 必須呼叫這個入口,掃整個信封,見下方「巢狀
# PackedByteArray 的界線」。
static func scan_envelope(envelope: Variant) -> GateResult:
	return _walk(envelope, 0, "envelope")

# 薄殼:只做深度檢查,除了 MAX_PAYLOAD_DEPTH 這個數字外沒有其他理由被觸碰。
static func _walk(value: Variant, depth: int, path: String) -> GateResult:
	if depth > MAX_PAYLOAD_DEPTH:
		var result := GateResult.new()
		result.rejection = GateRejection.DEPTH_EXCEEDED
		result.path = "%s <depth %d > MAX %d>" % [path, depth, MAX_PAYLOAD_DEPTH]
		return result
	return _walk_body(value, depth, path)

# 型別判斷 + 遞迴。**任何遞迴呼叫一律呼叫 _walk(),絕不可呼叫 _walk_body()**——
# 呼叫錯的後果是深度檢查對該分支完全失效,由下方「深度回歸測試」把關這條規則。
static func _walk_body(value: Variant, depth: int, path: String) -> GateResult:
	var result := GateResult.new()
	var t: int = typeof(value)
	if not ALLOWED_TYPES.has(t):
		result.rejection = GateRejection.FORBIDDEN_TYPE
		result.path = "%s <typeof=%d>" % [path, t]
		return result
	if t == TYPE_DICTIONARY:
		var d: Dictionary = value
		for key in d:
			if not ALLOWED_KEY_TYPES.has(typeof(key)):
				result.rejection = GateRejection.FORBIDDEN_TYPE
				result.path = "%s.<KEY typeof=%d>" % [path, typeof(key)]
				return result
			var sub: GateResult = _walk(d[key], depth + 1, "%s[%s]" % [path, str(key)])  # _walk,非 _walk_body
			if not sub.ok():
				return sub
	elif t == TYPE_ARRAY:
		var a: Array = value
		for i in a.size():
			var sub: GateResult = _walk(a[i], depth + 1, "%s[%d]" % [path, i])  # _walk,非 _walk_body
			if not sub.ok():
				return sub
	return result  # PACKED_BYTE_ARRAY 等葉節點型別在此結束,不遞迴進去看內容

# 完整性斷言:單純比數量對「漏一個允許型別+多一個拒絕型別」的成對抵銷完全瞎
# (實測見骨架驗證 E)。唯一可靠的是逐一檢查每個索引恰好落在其中一個集合。
static func verify_type_table_sum(allowed: Dictionary, rejected: Dictionary) -> bool:
	return allowed.size() + rejected.size() == TYPE_MAX  # 僅供對照,不得單獨作為判準

static func verify_type_table_partition(allowed: Dictionary, rejected: Dictionary) -> String:
	for t in range(TYPE_MAX):
		var is_allowed: bool = allowed.has(t)
		var is_rejected: bool = rejected.has(t)
		if is_allowed and is_rejected:
			return "typeof=%d 同時在兩集合中(交集)" % t
		if not is_allowed and not is_rejected:
			return "typeof=%d 兩集合都沒列到" % t
	return ""

static func self_check() -> bool:
	var ok: bool = verify_type_table_sum(ALLOWED_TYPES, REJECTED_TYPES)
	var err: String = verify_type_table_partition(ALLOWED_TYPES, REJECTED_TYPES)
	if not ok or err != "":
		push_error("SaveTypeGate.self_check FAILED: sum_ok=%s partition_err=%s" % [ok, err])
	return ok and err == ""
```

##### `self_check()` 的接線義務(2026-08-24,M3)

`self_check()` 定義後若無任何呼叫處,等同於一句寫得比較好的散文,不構成
`docs/architecture/adr-acceptance-criteria.md` 第三項要求的「自動檢查」。`src/`
目前為空,故本節把接線寫成**實作義務**,不假裝已有接線:

1. **必須**由 CI-blocking 單元測試呼叫並斷言(依 `.claude/docs/coding-standards.md`
   「Logic」類型測試規則),見下方「測試層新增」的
   `save_type_gate_self_check_test.gd`。
2. **不**掛在遊戲啟動流程——`ALLOWED_TYPES`/`REJECTED_TYPES` 是編譯期常數,值不依賴
   任何執行期輸入,同一份原始碼建置出的任何執行檔重跑一次只會得到與 CI 相同的結果;
   啟動時額外重跑唯一可能多抓到東西的情境,是「同一份原始碼在不同建置模式下常數值
   不同」,而這件事未查證(與本 ADR 其餘 release build 缺口同性質),沒有已知理由
   支持,故不另外掛載。

**回傳物件而非 bool 的安全前提**:深度檢查是 `_walk()` 執行的第一件事,先於任何
型別判斷、更先於任何遞迴。遞迴因此鎖在 65 層內,遠低於 GDScript 堆疊上限(推論值
約 1024 層,`core-serialization.md` §6)。**這是結構性排除,不是「風險被推遠」**
——`_walk()` 在第 65 次呼叫就直接返回,不會嘗試第 66 次。窮盡的前提是「所有帶
`depth` 參數的呼叫都經過以下三條路徑」:Dictionary 的鍵不遞迴、容器當值是唯一遞迴
路徑且 depth 恰好 +1、公開入口 `scan()`/`scan_envelope()` depth 皆硬寫 0——經覆核
逐一排除(security-engineer,2026-08-24)。**2026-08-24 二次覆核發現第四條**:
寫入側 `_serialize_gated()` 原直接呼叫私有 `_walk()`,不經上述公開入口,三條窮盡
的前提當時不成立(數字小於定義域)。已改為與讀取側一致改呼叫 `scan()`/
`scan_envelope()`(見下方「寫入側接入點」),三條才真正窮盡全部呼叫點;統一呼叫
慣例同時修正了本專案命名慣例的一個小違例——`_walk()` 加底線前綴依慣例是私有成員,
不該被 `SaveFormat` 這個外部類別直接呼叫,而 `scan()`/`scan_envelope()` 本就是為此
存在的公開薄殼,兩側改走同一薄殼沒有引入任何新邏輯。若此前提被打破(深度
檢查移到遞迴之後),堆疊溢位會在 `null` 上取屬性,呼叫端無聲中止——這是給未來
維護者的顯性要求。為降低此前提被意外破壞的機率,`_walk()` 拆成薄殼(只做深度
檢查)+ `_walk_body()`(型別判斷與遞迴),薄殼極短、除了那個數字外沒有理由被
編輯到;殘餘風險是遞迴呼叫寫錯成 `_walk_body()`,由下方「深度回歸測試」把關。

**深度上限的精確語意**:比較式 `depth > MAX_PAYLOAD_DEPTH`,`depth` 從頂層 0 起算,
故「值所在深度」能通過的上限是 64、65 起被擋。測試工具 `_nested(d)` 的參數 `d`
與值深度相差 1,故以 `d` 計是 63 通過、64 起被擋——**兩種說法都對,差別只在量的
單位**,規格一律用比較式本身描述,不用裸數字。循環引用(`{self: 自己}`)落在
`DEPTH_EXCEEDED`,而非引擎自身的 `var_to_bytes()` 循環保護(該保護回傳 `size()==0`
且不崩潰,但因閘門先跑而不可達)。**證據**:骨架驗證 C,`prototypes/save-format-skeleton-2026-08-21/README.md` 第 158-163 行;`core-serialization.md` §6。

**巢狀 `PackedByteArray` 的界線(決策,非量測)**:已序列化的 `PackedByteArray` 值
一律視為葉節點,不打開來看內容——manifest-only 路徑的正確性依賴這個邊界。**代價**:
若某區塊從未被 `read_full` 實際解碼,藏在裡面的危險型別要到該區塊真正被
`deserialize_block()` 解碼時才會被查到。

#### 寫入側接入點

```gdscript
class SerializeResult extends RefCounted:
	var buffer: PackedByteArray = PackedByteArray()
	var rejection: SaveTypeGate.GateRejection = SaveTypeGate.GateRejection.NONE
	var offending_path: String = ""
	func ok() -> bool:
		return rejection == SaveTypeGate.GateRejection.NONE

static func serialize_block(payload: Dictionary) -> SerializeResult:
	return _serialize_gated(payload, "payload")

static func serialize_manifest(envelope: Dictionary) -> SerializeResult:
	return _serialize_gated(envelope, "envelope")

static func _serialize_gated(d: Dictionary, root: String) -> SerializeResult:
	var res := SerializeResult.new()
	# 2026-08-24 改呼叫公開入口(與 _deserialize_gated 同一慣例),不再直接呼叫
	# 私有 _walk()——見機制一之二「深度上限」段落的呼叫點盤點。
	var gate: SaveTypeGate.GateResult = SaveTypeGate.scan_envelope(d) if root == "envelope" else SaveTypeGate.scan(d)
	if not gate.ok():
		res.rejection = gate.rejection
		res.offending_path = gate.path
		return res
	var buf: PackedByteArray = var_to_bytes(d)
	if buf.size() == 0:  # 合法編碼永不為 0;備援防線,見上方深度上限段落
		res.rejection = SaveTypeGate.GateRejection.DEPTH_EXCEEDED
		res.offending_path = "%s <var_to_bytes returned size 0>" % root
		return res
	res.buffer = buf
	return res
```

**失敗行為**:fail-closed,拒絕整次寫入。寫入側失敗**不可**併入 `SaveFormat.ReadRejection`
(語意不同,見獨立 `SerializeResult`,本節唯一定義的寫入側結果型別)。拒絕發生在組裝
原子寫入序列**之前**,故傷害上限是「這次沒存到」,磁碟上既有存檔不受影響。

> **範圍澄清(修正前一版的 `WriteResult` 誤植)**:前一版此處寫「見獨立
> `SerializeResult`/`WriteResult`」,`WriteResult` 全文從未定義,查證後確認它**不是**
> `SerializeResult` 的舊名——它是骨架 `prototypes/save-format-skeleton-2026-08-21/scripts/save_writer.gd`
> 裡 `SaveWriter.WriteResult` 的殘留引用,那是一個**組裝多區塊、產生完整信封**的更高層
> 協調者(逐一呼叫 `serialize_block()`、算雙層雜湊、組 `block_manifest`、最後呼叫
> `serialize_manifest()`),失敗模式比單次型別閘門更多(`INPUT_INVALID`/`HASH_FAILED`/
> `ENVELOPE_REJECTED` 等)。**這個協調者屬於哪一份 ADR,目前沒有定論**:骨架自己的
> 發現(c)-2 指出它「落在 ADR-0003 與 ADR-0004 之間」——ADR-0003 的 Architecture
> Diagram 把組裝步驟畫在示意圖裡但沒有對應的 Key Interface,ADR-0004 明文只管「把
> buffer 換到磁碟」不管「怎麼組出 buffer」。本節(機制一之二)只定案型別閘門這一層
> 的結果型別(`SerializeResult`/`DeserializeResult`),**不替這個未認領的組裝層預先
> 命名或分派歸屬**——這正是本專案登記在案的「跨 ADR 單方面記帳」失敗模式,不應在
> 沒有裁決的情況下由單一小節單方面解決。是否需要新增一份機制(或回頭修訂 ADR-0004
> 的範圍聲明)來認領 `SaveWriter`/等效組裝角色,留待跨文件層級的裁決,不由本節決定。

#### 讀取側接入點

```gdscript
class DeserializeResult extends RefCounted:
	var payload: Dictionary = {}
	# 型別採 SaveFormat.ReadRejection(而非骨架原本各自獨立的 DecodeRejection),
	# 因為下方 _deserialize_gated() 直接指派 SaveFormat.ReadRejection.DATA_CORRUPTED——
	# 與 SaveEnvelope.ShapeCheckResult 用同一個列舉,避免讀取路徑上出現兩種不互通的
	# 「失敗」型別。
	var rejection: ReadRejection = ReadRejection.NONE  # 同檔,不繞全域類別名(探針實測形狀)
	# detail 不是拒絕碼,只是診斷字串——失敗一律 DATA_CORRUPTED,不新增拒絕碼
	var detail: String = ""
	var offending_path: String = ""
	func ok() -> bool:
		return rejection == ReadRejection.NONE

static func deserialize_block(buffer: PackedByteArray) -> DeserializeResult:
	return _deserialize_gated(buffer, "payload")

static func deserialize_manifest(buffer: PackedByteArray) -> DeserializeResult:
	return _deserialize_gated(buffer, "envelope")

static func _deserialize_gated(buffer: PackedByteArray, root: String) -> DeserializeResult:
	var res := DeserializeResult.new()
	if buffer.size() == 0:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "empty buffer"
		return res
	var decoded: Variant = bytes_to_var(buffer)
	if not (decoded is Dictionary):  # 絕不用 != null,見下方判定規則
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "decoded typeof=%d, not a Dictionary" % typeof(decoded)
		return res
	var gate: SaveTypeGate.GateResult = SaveTypeGate.scan_envelope(decoded) \
		if root == "envelope" else SaveTypeGate.scan(decoded)
	if not gate.ok():
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "type gate rejected on READ side (rejection=%d)" % gate.rejection
		res.offending_path = gate.path
		return res
	if root == "envelope":  # 2026-08-24 補上與下方順序圖一致的呼叫(M4a)
		var shape: SaveEnvelope.ShapeCheckResult = SaveEnvelope.check_shape(decoded)
		if not shape.ok():
			res.rejection = shape.rejection
			res.detail = shape.detail
			return res
	res.payload = decoded
	return res
```

`deserialize_manifest()` 的順序(不得調換):

```
bytes_to_var(buffer) → is Dictionary? → SaveTypeGate.scan_envelope(整個信封) → SaveEnvelope.check_shape(envelope)
```

型別閘門先跑、且掃**整個信封**——這是「未知欄位可以夾帶一般資料、但夾帶不了危險
型別」的機制來源。失敗一律回 `DATA_CORRUPTED`,不新增拒絕代碼。**證據**(讀取側
獨立掃描的必要性):`core-serialization.md` §3–4;骨架驗證 C 逐字確認
`EncodedObjectAsID`/`Signal`/`RID`/`Callable` 四種毒位元組 `bytes_to_var()` 全部
靜默成功,只有閘門會擋(`README.md` 第 165-181 行)。

**呼叫者裁決(2026-08-24,M4)**:`check_shape(envelope)` 由上方 `_deserialize_gated()`
在型別閘門通過後、`root == "envelope"` 時呼叫(`deserialize_block()` 不呼叫它,區塊
payload 沒有信封的固定形狀)。此呼叫使 `SaveFormat` 與 `SaveEnvelope` 兩個
`class_name` 腳本互相引用——已用探針實機驗證此形狀在 Godot 4.7.1 編譯與執行皆
成立(而非骨架原本的單向引用),見 `prototypes/xcheck-classname-cycle-2026-08-24/README.md`
(exit 0,未過濾 log `logs/xcycle-unfiltered.txt`)。⚠️ 探針記錄一項環境陷阱:全新
目錄未先執行 `--import` 產生 `global_script_class_cache.cfg` 前,任何 `class_name`
互相引用都會被誤判為「not declared in the current scope」——這是環境問題,不是雙向
引用本身不可行,後續任何用到 `class_name` 的 headless 探針都須先 `--import`。

#### `SaveEnvelope.check_shape()`

```gdscript
class_name SaveEnvelope extends RefCounted

const ENVELOPE_TOP_KEYS: Array[String] = [
	"ruleset_version", "block_manifest", "top_level_hash", "blocks",
]

class ShapeCheckResult extends RefCounted:
	var rejection: SaveFormat.ReadRejection = SaveFormat.ReadRejection.NONE
	var detail: String = ""
	func ok() -> bool:
		return rejection == SaveFormat.ReadRejection.NONE

static func check_shape(envelope: Dictionary) -> ShapeCheckResult:
	var res := ShapeCheckResult.new()
	for k in ENVELOPE_TOP_KEYS:
		if not envelope.has(k):
			return _fail(res, "信封缺少鍵 %s" % k)
	# 2026-08-24 管理者裁決:未知額外鍵不拒絕,故無「額外鍵一律視為損毀」的反向迴圈。
	if typeof(envelope["ruleset_version"]) != TYPE_INT:
		return _fail(res, "ruleset_version 應為 int")
	if typeof(envelope["block_manifest"]) != TYPE_ARRAY:
		return _fail(res, "block_manifest 應為 Array")
	if typeof(envelope["top_level_hash"]) != TYPE_PACKED_BYTE_ARRAY \
			or (envelope["top_level_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
		return _fail(res, "top_level_hash 型別或長度不符")
	if typeof(envelope["blocks"]) != TYPE_DICTIONARY:
		return _fail(res, "blocks 應為 Dictionary")
	return _check_manifest_entries(envelope["block_manifest"])

static func _fail(res: ShapeCheckResult, detail: String) -> ShapeCheckResult:
	res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
	res.detail = detail
	return res

static func _check_manifest_entries(block_manifest: Array) -> ShapeCheckResult:
	var res := ShapeCheckResult.new()
	var seen: Dictionary = {}
	for i in block_manifest.size():
		if typeof(block_manifest[i]) != TYPE_DICTIONARY:
			return _fail(res, "block_manifest[%d] 應為 Dictionary" % i)
		var entry: Dictionary = block_manifest[i]
		for field_name in SaveFormat.MANIFEST_ENTRY_FIELDS:  # 見下方共用常數
			if not entry.has(field_name):
				return _fail(res, "block_manifest[%d] 缺少鍵 %s" % [i, field_name])
		var type_error: String = _check_entry_field_types(entry, i)
		if type_error != "":
			return _fail(res, type_error)
		var sid: String = entry["source_id"]
		if seen.has(sid):
			return _fail(res, "重複的 source_id '%s'" % sid)
		seen[sid] = true
	return res

# 欄位名來自共用常數,但型別因欄位而異——這是共用常數無法消除的殘餘手動步驟
# (見下方誠實劃界)。
static func _check_entry_field_types(entry: Dictionary, index: int) -> String:
	if typeof(entry["source_id"]) != TYPE_STRING:
		return "source_id 應為 String"
	if typeof(entry["format_version"]) != TYPE_INT:
		return "format_version 應為 int"
	if typeof(entry["block_hash"]) != TYPE_PACKED_BYTE_ARRAY \
			or (entry["block_hash"] as PackedByteArray).size() != SaveFormat.HASH_LEN:
		return "block_hash 型別或長度不符"
	var mt: int = typeof(entry["migration_completion_marker"])
	if mt != TYPE_INT and mt != TYPE_NIL:
		return "migration_completion_marker 應為 int 或 null"
	return ""
```

**保留**:必要鍵存在、型別正確、雜湊長度恰為 32、`source_id` 不重複。**移除**:
額外鍵拒絕迴圈(管理者裁決)。此裁決只開放「夾帶任意資料」,沒開放「夾帶危險型別」
——`check_shape()` 在型別閘門通過**之後**才執行。**延後項**(非本節缺陷,應寫入
Consequences → Negative):信封層寬容 + `blocks` 額外條目被靜默忽略(機制三既有
設計)= 兩塊內容不受頂層雜湊涵蓋也不觸發拒絕的區域,是否擴大雜湊範圍留待實作階段。

#### `MANIFEST_ENTRY_FIELDS`(單一共用常數)

```gdscript
# save_format.gd 節錄。形狀檢查與雜湊 canonicalization 都從這裡讀取欄位清單,不得
# 另寫一份(修正前一輪「兩份清單各自漂移」)。選 Array[String] 而非 Dictionary:
# 雜湊側需固定順序(Dictionary 插入順序會改變 var_to_bytes() 輸出,見
# core-serialization.md §7),
# Array 天然保序且 .has() 已足夠支援存在性查詢。
const MANIFEST_ENTRY_FIELDS: Array[String] = [
	"source_id", "format_version", "block_hash", "migration_completion_marker",
]

# SHA-256 摘要長度(bytes)。check_shape() 與雜湊比對兩處共用此值,見機制四之二
# 的 hash_matches()(2026-08-24 已改讀此常數,修正原本並存的一份 32 字面量)。
const HASH_LEN: int = 32

static func compute_top_level_hash(ruleset_version: int, block_manifest: Array) -> PackedByteArray:
	var ordered: Array = canonical_block_order(block_manifest)
	if ordered.size() != block_manifest.size():
		return PackedByteArray()
	var chunks: Array = [var_to_bytes(ruleset_version)]
	for e in ordered:
		var entry: Dictionary = e
		var tuple: Array = []
		for field_name in MANIFEST_ENTRY_FIELDS:
			tuple.append(entry.get(field_name, null))
		chunks.append(var_to_bytes(tuple))
	return _sha256_of_chunks(chunks)  # SHA-256 三段式 HashingContext 實作,見下方

# 依機制四之二第 2/5 節的契約定義的私有輔助函式:每次呼叫使用一個全新的
# HashingContext 實例(不跨用途重用,重用會導致上一次的資料悄悄疊加進這一次,見機制
# 四之二 3a);start()/update() 任一步驟回傳非 OK 即視整個雜湊計算為失敗、立即捨棄該
# context,不嘗試繼續餵資料或重試——不依賴「update() 回傳 FAILED 之後 context 是否
# 仍可正常累積」這個未驗證行為(機制四之二第 5 節「新開的未查證項」)。失敗以空
# PackedByteArray(size()==0)回傳;呼叫端一律用 size()==0 判定失敗,不用 == null
# (與上方「size() == 0 / is Dictionary 判定規則」同一條規則,適用於雜湊輸出)。
static func _sha256_of_chunks(chunks: Array) -> PackedByteArray:
	var ctx := HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		return PackedByteArray()
	for chunk in chunks:
		if ctx.update(chunk) != OK:
			return PackedByteArray()
	return ctx.finish()
```

##### 誠實劃界:這個共用常數保證什麼、不保證什麼

**保證**:新增欄位只需改這一個陣列,存在性檢查與雜湊涵蓋範圍自動同步。**沒有保證**:
每個欄位的型別檢查分支(`_check_entry_field_types`)仍須手動新增——後果是「這個
欄位暫時不驗型別」(侷限、審查能一眼看出),不是「雜湊範圍與形狀檢查彼此不同步」
那種隱性不一致,兩種殘餘風險性質不同。

#### `size() == 0` / `is Dictionary` 判定規則

**證據**:`core-serialization.md` §3(全零 16 bytes 是合法 NIL 編碼,`bytes_to_var()`
回傳 `null` 且零錯誤;合法編碼最短 4 bytes,永不為 0)。契約規則:

1. 解碼前先查 `buffer.size() == 0`——可靠、無歧義的失敗訊號。
2. 解碼後一律用 `decoded is Dictionary` 判定成功,**絕不**用 `!= null`(全零位元組
   合法解出 `null`,`!= null` 判定會漏放這種損毀)。
3. 寫入側 `var_to_bytes()` 後查 `size() == 0`,歸為 `DEPTH_EXCEEDED`(唯一已知成因
   是循環引用繞過閘門直接抵達 `var_to_bytes`,理論上不可達,列為備援)。

#### 深度回歸測試(自動化偵測「深度檢查被移到遞迴之後」)

```gdscript
# ─── tests/unit/save_system/save_type_gate_depth_regression_test.gd ─────────
extends GdUnitTestSuite

const REGRESSION_DEPTH: int = 3000  # 理由見下方

func test_save_type_gate_extreme_depth_rejects_without_stack_overflow() -> void:
	# Arrange:迭代組裝,不遞迴——否則測試自己先溢位。
	var deep: Dictionary = _build_nested_iteratively(REGRESSION_DEPTH)
	# Act
	var result: SaveTypeGate.GateResult = SaveTypeGate.scan(deep)
	# Assert
	assert_int(result.rejection).is_equal(SaveTypeGate.GateRejection.DEPTH_EXCEEDED)
	# 第二項斷言(引擎沒有真的堆疊溢位)無法用 GdUnit4 的斷言 API 表達——
	# GDScript 的 SCRIPT ERROR/Stack overflow 不透過例外或回傳值傳遞。CI runner
	# 必須額外檢查本測試行程的 stderr 不含 "Stack overflow"/"Stack underflow"
	# 字串。這一層屬於 CI 設定而非本測試檔本身,已列為實作階段待辦。

func _build_nested_iteratively(depth: int) -> Dictionary:
	var root: Dictionary = {}
	var cur: Dictionary = root
	for i in depth:
		var nxt: Dictionary = {}
		cur["n"] = nxt
		cur = nxt
	cur["leaf"] = 1
	return root
```

**這條測試能抓到的範圍,精確界定**:它抓的是「深度檢查被移到遞迴之後」。若被移到
「型別判斷之後、但仍在遞迴之前」,本測試會通過——而那個位置仍然是安全的(沒有
遞迴就不會溢位)。涵蓋範圍恰好等於危險的那一種挪動,不是部分涵蓋,不要因為誤以為
它涵蓋不足而另外加測試。

**層數選擇(3000)**:落在建議區間 2,000–5,000 的中段,相對推論的 ~1024 層堆疊
上限有約 3 倍餘裕——若 `_walk_body()` 的遞迴分支誤呼叫 `_walk_body()` 而非
`_walk()`(繞過深度檢查),真正的 GDScript 遞迴會在遠低於 3000 層處(約 1024 層)
先行溢位,可靠觸發真正的堆疊錯誤;層數本身遠低於一般 CI 環境的其他資源限制,
迭代組裝的記憶體/時間成本可忽略。

#### 未查證 / 待覆核

- **release build 下本節全部行為是否一致**——全部測量僅限 debug/headless,不宣稱
  release 下維持一致(與 ADR-0002/-0004 共用同一缺口)。
- **`MANIFEST_ENTRY_FIELDS` 與型別檢查分支的一致性**是否需要 CI 層級強制比對,
  留待 `/create-architecture` 決定。


### 機制二:分層緩衝區的 manifest 結構

```gdscript
# ─── 概念契約,非單一檔案 ──────────────────────────────────
{
    "ruleset_version": int,          # Core Rules #5 的規則集版本號,單調遞增
    "block_manifest": [               # 固定順序:依 source_id 字典序排列(見機制四)
        {
            "source_id": String,       # 例如 "affinity_data_pool"
            "format_version": int,     # 該區塊自身的格式版本
            "block_hash": PackedByteArray,      # SHA-256,見機制四
            "migration_completion_marker": Variant,  # int 或 null,見 save-system.md Core Rules #13
        },
        # ... 其餘區塊
    ],
    "top_level_hash": PackedByteArray,  # SHA-256,見機制四
    "blocks": {
        "affinity_data_pool": PackedByteArray,  # 該區塊 payload 的獨立序列化緩衝區,尚未 decode
        # ... 其餘區塊,鍵與 block_manifest 的 source_id 一一對應
    },
}
```

**每個區塊的 payload 各自獨立序列化為一份 `PackedByteArray`**(而非把所有區塊的 `Dictionary` 直接攤平進外層結構),再把這些緩衝區當作值放進外層 `blocks` 字典——這個分層是本 ADR 對 `TR-save-012`(manifest-only vs 完整讀取雙路徑)的具體實現機制:外層結構透過**一次** `bytes_to_var(buffer)` 呼叫解碼,得到 `ruleset_version`/`block_manifest`/`top_level_hash` 與**尚未解碼的** `blocks` 字典(`PackedByteArray` 本身是原生型別,取得它不等於解讀它的內容)——「僅讀取 manifest」路徑到此為止,不對任何區塊的 `PackedByteArray` 再呼叫一次 `bytes_to_var()`;「完整讀取」路徑則對需要的區塊緩衝區各自再呼叫一次 `bytes_to_var(buffer)` 才真正取得該區塊的 payload `Dictionary`。

**理由**:若整份存檔以單一 `var_to_bytes()` 呼叫扁平序列化(所有區塊的 `Dictionary` 直接巢狀在同一個外層結構裡,沒有中間的 `PackedByteArray` 分層),`bytes_to_var()` 解碼外層結構時會**遞迴解碼全部區塊內容**,manifest-only 路徑將無法迴避解碼任何區塊——直接違反 Core Rules #5 對此介面「不反序列化任何資料區塊」的要求,也讓 Core Rules #16 鎖定的讀取順序(見機制三)在格式層面無法實現。

### 機制三:讀取路徑的鎖定順序(實作 Core Rules #16)

`save-system.md` Core Rules #16 本輪鎖定的完整讀取路徑順序——**#8 頂層完整性標記 → #5 規則集版本比對(`VERSION_TOO_NEW` 短路)→ #9 型別白名單閘門 → #7 語意驗證/#5 遷移鏈**——機制二的分層結構讓這個順序在位元組層級自然成立,不需要額外的流程控制邏輯去「假裝」某個步驟先發生:

1. `bytes_to_var(buffer)` 解碼外層結構,取得 `ruleset_version`、`block_manifest`(含逐區塊雜湊)、`top_level_hash`,以及尚未解碼的 `blocks` 字典(僅取得 `PackedByteArray` 參照,不解讀內容)。
2. 以 `(ruleset_version, block_manifest 依 source_id 字典序排列的 tuple 清單)` 重算頂層雜湊,與讀出的 `top_level_hash` 比對——不符則 `DATA_CORRUPTED`,**在此步驟終止,不繼續任何後續步驟**(不嘗試解碼任何區塊,不比對版本)。
3. 比對 `ruleset_version` 與目前遊戲版本——若前者較高,回傳 `VERSION_TOO_NEW`,**在此步驟終止**(不解碼任何區塊 payload,不觸發型別白名單閘門)。這個順序把 `VERSION_TOO_NEW` 判定完全建立在一個整數比較上,不依賴任何區塊解碼是否成功,直接消除 GDD 自陳的「新版本存檔在舊版本遊戲上被誤判為 `DATA_CORRUPTED`(因為含有未登記型別)」缺陷。
4. 對每個需要處理的區塊(格式版本不等於目前版本、或屬於完整讀取範圍者):先以其 `block_manifest` 條目的 `block_hash` 對該區塊**尚未解碼的原始位元組**(`blocks[source_id]` 本身的 `PackedByteArray` 內容)重算 SHA-256 比對——不符則該次讀取視為 `DATA_CORRUPTED`,**在嘗試 `bytes_to_var()` 解碼該區塊之前就終止**,即區塊層級的雜湊驗證先於該區塊的型別白名單解碼發生,把「可能觸發非預期解碼行為的位元組」阻擋在解碼呼叫之外。
5a. 通過雜湊驗證的區塊,以 `bytes_to_var(buffer)` 解碼其 `PackedByteArray`,取得結果 `decoded`。**這一步只擋一件事**:若位元組流本應解碼出一個 `Object`(typeof 24,含所有 `Resource`/`RefCounted`/`Node` 子類別),`bytes_to_var()` 對此整包解碼原子性失敗,回傳值不是 `Dictionary`。判定一律用 `decoded is Dictionary`,不用 `!= null`——全零 16 bytes 是合法的 NIL 編碼,`bytes_to_var()` 對它回傳 `null` 且零錯誤訊息,`!= null` 會把這種損毀誤判為成功。`decoded` 不是 `Dictionary`(涵蓋 Object 解碼失敗與任何其他非預期型別)一律視為 `DATA_CORRUPTED`。

5b. 對 5a 取得的 `decoded` payload,呼叫 `SaveTypeGate.scan(decoded)`(機制一之二)做獨立遞迴掃描,拒絕集合為 {23 `RID`、24 `Object`、25 `Callable`、26 `Signal`}。**這一步擋的是 5a 完全不擋的三個型別**:`RID`/`Callable`/`Signal` 在引擎讀取側不觸發任何拒絕行為,會被 `bytes_to_var()` 成功解碼並回傳,只有這道獨立掃描會擋。**這一步必須在步驟 6(語意驗證/遷移鏈)之前執行**——遷移函數操作的是已解碼的資料,型別閘控若晚於遷移鏈,危險型別會先被遷移函數讀取過一輪才被擋下(見機制七)。掃描結果是機制一之二定義的 `SaveTypeGate.GateResult`,其 `rejection` 欄位型別是 `GateRejection`——**不是** `SaveFormat.ReadRejection`;呼叫端讀到 `not gate.ok()` 時,對外一律轉譯為 `SaveFormat.ReadRejection.DATA_CORRUPTED`,兩個列舉本身不互通、不可混用其數值。

（步驟 6 內容不變,銜接 5b 的輸出。）
6. 解碼成功的區塊 payload,交由其擁有系統的 `validate_semantics()`(機制六)做語意驗證,或(若格式版本落後)進入遷移鏈——這部分屬於下一份 ADR(遷移執行模型)的範圍,本 ADR 只保證抵達這一步時,payload 已經是型別安全、雜湊驗證通過的 `Dictionary`。

### 機制四:雙層雜湊鏈與操作原子性

雜湊演算法採 **SHA-256**,透過 `HashingContext`(`start(HashingContext.HASH_SHA256)` → 逐段 `update()` → `finish()`,完整簽章與狀態機見機制四之二第 1、2 節(2026-08-21 實測關閉,非外推))。

- **逐區塊雜湊**:對該區塊**獨立序列化後、尚未寫入外層結構前**的 `PackedByteArray` 緩衝區本身計算,不含 `source_id`/`format_version`/`migration_completion_marker`(這三者由頂層雜湊涵蓋,見下)——直接對應 GDD「逐區塊雜湊只涵蓋 payload 本身」與「頂層雜湊才涵蓋來源身分與版本中繼資料」的兩層分工。
- **頂層雜湊**:輸入為 `(ruleset_version, block_manifest 依 source_id 字典序排列的 tuple 清單)`——每個 tuple 為 `(source_id, format_version, block_hash, migration_completion_marker)`。**固定順序採 `source_id` 字典序,不依賴 `block_manifest` 陣列本身的建構/迭代順序**——直接呼應 `docs/registry/architecture.yaml` 已登記的 `relying_on_container_iteration_order` forbidden pattern(ADR-0001 登記,原針對 `Dictionary`/`Array` 原生迭代順序不穩定的一般性風險,本 ADR 是該登記立場在 manifest 層級的具體應用)。
- **操作原子性**(GDD 第七輪新增規則,直接對應機制二的分層設計):逐區塊雜湊的輸入緩衝區,與最終寫入磁碟的**是同一個** `PackedByteArray` 物件——本 ADR 的設計天然滿足此規則,因為機制二本就要求每個區塊獨立序列化出一份緩衝區,該緩衝區同時是雜湊輸入與 `blocks[source_id]` 的值,不存在「為了算雜湊而重新序列化一次」的第二條路徑。
- **雜湊輸入來源為寫入前的記憶體資料**(GDD 第六輪新增規則):本 ADR 的雜湊計算天然發生在 `var_to_bytes()` 產生緩衝區之後、`FileAccess` 實際寫入磁碟之前的記憶體物件上——不涉及任何「寫入後讀回磁碟位元組」的路徑,這個順序由機制二的資料流本身保證,不需要額外的紀律要求。

**為何不用較廉價的非加密雜湊(例如 CRC32)**:雖然 Core Rules #8 明文的威脅模型是意外損毀而非知情攻擊者,GDD 本身仍明文要求「SHA-256 或等效強度演算法」,排除純檢查碼類別(CRC32 對特定樣式的多位元同時翻轉有已知的碰撞盲點,不符合「等效強度」的字面要求)。SHA-256 對本系統實際資料量(單槽估計數十 KB,見 GDD Tuning Knobs)的計算成本可忽略,沒有理由為了省下這個可忽略的成本而低於 GDD 鎖定的演算法強度門檻。

### 機制四之二:雜湊計算規則


#### 1. `HashingContext` 完整方法簽章

`HashingContext` 是登記類別,以下簽章來自 `ClassDB` 內省(非文件外推):

| 方法 | 簽章 | 回傳 |
|---|---|---|
| `start` | `start(type: HashingContext.HashType) -> Error` | `Error`(int) |
| `update` | `update(chunk: PackedByteArray) -> Error` | `Error`(int) |
| `finish` | `finish() -> PackedByteArray` | `PackedByteArray` |

本 ADR 採 `HashingContext.HASH_SHA256`。

**證據**:`docs/engine-reference/godot/modules/core-serialization.md` 第 5 節(168-176 行);
探針 F3(`prototypes/xcheck-adr0003-2026-08-21/logs/probeF2-main-unfiltered.txt` 尾段)。

#### 2. 狀態機與誤用回傳碼(完整表)

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

##### 3a. 載重宣稱:「已餵資料後再 `start()` 被拒,但不重置,會接續累積」

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

##### 3b. `size()==0` 與「兩個空陣列相等」的交互——為何 `hash_matches()` 要先比長度

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
	# SHA-256 固定輸出 HASH_LEN(32)bytes;長度不對本身就是損毀或計算失敗的訊號,
	# 不可以落到下面的內容比較——兩邊都是空陣列時 `==` 會回 true,是假通過。
	# 2026-08-24 修正:改讀 HASH_LEN 常數,不寫死字面量 32(本節同一個檔案的
	# MANIFEST_ENTRY_FIELDS 才剛為了杜絕這種漂移而設共用常數,此處先前反其道而行)。
	if computed.size() != HASH_LEN or stored.size() != HASH_LEN:
		return false
	return computed == stored
```

本次修訂中兩位專家(引擎與 GDScript 領域)在互不知情的情況下各自獨立寫出這個函式,
且理由相同——兩軌獨立收斂。本節將其正式收為機制四之二的
契約,所有雜湊比對(逐區塊雜湊、頂層雜湊)一律呼叫 `hash_matches()`,禁止直接寫
`==`。

#### 3. `PackedByteArray` 沒有 `sha256_buffer()` —— 三段式是唯一路徑

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

#### 4. 雜湊輸入必須是固定順序的陣列,不能是 Dictionary

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
(例如依 `source_id` 字典序排列 `Array`(元素為 `Dictionary`)),卻沒有處理「條目**內部**
鍵的插入順序」,兩份邏輯相同、寫入時機不同(因此 Dictionary 字面量鍵插入順序不同)
的存檔會算出不同的頂層雜湊——**健康的存檔會被誤判為損毀**。這正是骨架驗證
b-1 指出的洞:草案原文宣稱「不依賴容器迭代順序」,但範圍只覆蓋了區塊間順序,
沒覆蓋條目內鍵序。

**正規化規則(本節的契約)**:

1. 雜湊計算前,每個 manifest 條目一律轉換成**固定欄位順序的 `Array`**
   (tuple),不得直接對條目 `Dictionary` 呼叫 `var_to_bytes()`。
2. 固定順序**必須**取自 `MANIFEST_ENTRY_FIELDS`(機制一之二定義的
   共用常數,S1B 形狀檢查同樣消費它)——本節**不另定一份欄位清單**。理由:
   「兩份清單各自維護」正是本次修訂要杜絕的漂移形狀
   ——同一份清單被兩處消費,必須合併。任何新增欄位只需要改
   `MANIFEST_ENTRY_FIELDS` 一處,形狀檢查與雜湊正規化會同步生效。
3. 條目之間的順序維持既有決策:依 `source_id` 字典序排列成 `Array`(元素為 `Dictionary`)
   或等效的 tuple 陣列(骨架 c-15 的既有作法:回傳新陣列、手工插入排序,不用
   `sort_custom` + lambda——沿用該決策,原因同樣是「不賭靜態情境下 lambda 這個
   未查證形狀」)。
4. 頂層雜湊的輸入因此是:`Array`(依 `source_id` 排序的區塊)包著每條目的
   `Array`(依 `MANIFEST_ENTRY_FIELDS` 固定順序的欄位值)——兩層都是位置決定
   順序,零 `Dictionary` 直接進雜湊輸入。

#### 5. 新開的未查證項

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

#### 未涵蓋 / 明確排除的宣稱

- **release build 下本節所有行為是否維持一致**:未查證。全部量測皆在 debug/headless
  建置下取得(`Godot 4.7.1.stable.official.a13da4feb`),本機無 export template 可匯出
  release 建置測試,見 `core-serialization.md` 文末「未查證」表第 1 項,同一限制適用
  於本節。
- 本節不重複列出 manifest 欄位清單本身——見開頭引言與第 4 節第 2 點。

### 機制五:enum/索引鍵字串化——沿用 ADR-0002 已登記的慣例,推廣為專案級介面義務

Core Rules #10 要求 `Pair`(索引鍵)與任何持久化 enum 欄位(如 `source_i`)以字串名稱持久化。ADR-0002 已經在 `AffinityRecord.to_dict()`/`from_dict()` 中實作此規則,採 `enum.find_key(value)`(依值查鍵)與 `enum[name_string]`(依鍵查值)而非 `keys()[value]` 位置索引——`docs/registry/architecture.yaml` 已登記 `enum_value_positional_string_conversion` forbidden pattern。**本 ADR 不重新發明這個機制,而是把它從「`AffinityDataPool` 自己的實作選擇」提升為「本系統對所有持久化資料區塊的擁有系統的介面要求」**:任何區塊的 `to_dict()`/`from_dict()`(或等效轉接方法)若涉及 enum 欄位,一律採此慣例。**退役名稱治理與自動化檢查**(Core Rules #10 的強制項)由本系統集中提供一個輕量工具——`SaveEnumRegistry`(概念契約,見 Key Interfaces `submit_current_names(enum_id, current_names)`):各擁有系統於其 enum 定案時,呼叫此方法向登記表提交「目前合法的字串名稱集合」;`/create-architecture` 階段須提供一個建置期/CI 可執行的檢查,比對歷次提交記錄與目前集合,偵測任何「曾經存在、後消失、又重新出現」的名稱並使建置失敗——**此檢查本身的具體實作(例如比對歷史記錄檔案的存放方式)留待 `/create-architecture` 決定,本 ADR 只定案介面形狀與檢查必須存在這件事**,呼應 GDD「此規則必須有自動化檢查,不能只靠人工審查紀律」的硬性要求。

### 機制六:區塊驗證器登記表——依賴注入實例,回填修訂 ADR-0002

Core Rules #7(擴充)要求每個持久化資料區塊的來源系統宣告其語意合法性規則,manifest 列出一個無對應宣告的區塊視為 `DATA_CORRUPTED`(fail-closed)。本 ADR 定義:

```gdscript
# ─── save_block_registry.gd ──────────────────────────────────
class_name SaveBlockRegistry extends RefCounted

# validator: Callable(Dictionary) -> ImportResult — 純函式,不修改任何狀態,
# (2026-08-18 第二輪 /architecture-review 修正 C2:本行原寫 `ValidationResult`,但唯一的
#  具體驗證器 AffinityDataPool.validate_semantics()(ADR-0002 Key Interfaces)回傳
#  `ImportResult`,ADR-0004 機制五亦以該型別消費。統一採用 ADR-0002 已定案的型別名,
#  避免同一介面在三份 ADR 之間有兩個名字。)
# 僅檢查傳入的 payload Dictionary 是否滿足該區塊的欄位值域與跨結構不變量。
func register(source_id: String, validator: Callable) -> void
func get_validator(source_id: String) -> Variant   # Callable 或 null(未登記)
```

**依賴注入實例,非靜態類別**:`SaveBlockRegistry` 由存檔系統的擁有者(具體節點留待 `/create-architecture` 決定)於遊戲啟動時建構一次,各擁有系統(`AffinityDataPool` 等)於自己的初始化流程中呼叫 `register()` 提交驗證器。**理由**:與 ADR-0002 機制一「擁有模式」的論證一致——一個可以被 `new` 出乾淨實例、單元測試能自行控制登記哪些驗證器的物件,比一個全域靜態表更容易做隔離測試(例如測試「manifest 列出無對應驗證器宣告的區塊」這個 `DATA_CORRUPTED` 情境時,可以直接建構一個刻意留空的登記表,不需要清空/還原任何全域狀態)。

**回填修訂 ADR-0002**:`AffinityDataPool` 新增一個公開的 `validate_semantics(payload: Dictionary) -> ImportResult` 純函式,執行 ADR-0002 機制八原本內嵌在 `import_state()` 裡的逐欄位值域與 5 條跨結構不變量檢查,但**不**修改任何內部狀態;`import_state()` 的實作改為內部呼叫 `validate_semantics()`,通過才真正替換內部狀態。**理由**:遷移執行模型(下一份 ADR)需要對遷移鏈輸出的 payload 做語意驗證(GDD Core Rules #7「語意驗證同樣套用於遷移函數的輸出」),但遷移鏈執行期間的中繼 `Dictionary` 不必然對應一個已經存在、要被替換的 `AffinityDataPool` 活體實例——需要一個不綁定「替換活體狀態」副作用的純驗證呼叫。ADR-0002 目前仍是 Proposed 狀態,屬於同一波共同開發,此修訂範圍小(新增一個方法簽章、`import_state()` 內部重構),不改變 ADR-0002 已定案的任何資料結構或並發機制決策。

**驗證器未登記的處置**:讀取路徑(機制三步驟 6)查詢 `SaveBlockRegistry.get_validator(source_id)`,若回傳 `null`(未登記),**不進入語意驗證,直接回傳 `DATA_CORRUPTED`**——對應 GDD「manifest 列出一個沒有對應驗證器宣告的資料區塊,該 manifest 本身視為錯誤」的 fail-closed 規則,即使該區塊本身的雜湊驗證與型別白名單解碼都已通過。

### 機制七:型別白名單版本域範圍問題的釐清(Open Question 4)——「範圍不需分域」,不是「問題消失」

GDD Open Question 4 問的是:若採「扁平聯集」型別白名單,存在攻擊者宣告舊規則集 版本以繞過較新版本較嚴格檢查的理論風險;若採「依版本分域」,則需要額外的版本↔合法 型別集合對照機制。**型別這個維度沒有消失,只是換了承擔者與成員**:引擎的 `allow_objects` 閘門只擋 `Object`(24),`RID`(23)/`Callable`(25)/`Signal`(26) 三者完全不受它管控(見 `core-serialization.md` 第 4 節),因此本 ADR 自建機制一之二 (寫入側 + 讀取側各一道遞迴型別閘門,拒絕集合 = {23, 24, 25, 26})來補上引擎沒有 提供的閘門。**這份拒絕集合本身不需要依版本分域**:它錨定在 Godot 引擎的 Variant 型別列舉(結構性、與遊戲內容版本無關),對所有宣告的 `format_version` 一視同仁地 拒絕這四個型別,GDD 擔心的「宣告舊版本套用較寬鬆檢查」在這個設計下沒有「較寬鬆的 舊版本」可以宣告。機制六 `validate_semantics()` 的欄位值域檢查仍可、也應該依版本 分流,但那是語意層級的問題,與型別閘控是兩個不同的維度。⚠️ 原文引用 Core Rules #16 (「遷移鏈執行完成後仍須通過目前版本的語意驗證」)來佐證風險已涵蓋——這個引用不成立: 語意驗證發生在遷移鏈**之後**,而型別閘控必須發生在遷移鏈**之前**(遷移函數本身會 操作已解碼的資料),兩者順序不能對調,語意驗證不能替代型別閘控。

## Architecture Diagram

```
                    寫入路徑(概念流程,實際原子置換機制屬下一份 ADR):
                    ┌──────────────────────────────────────────┐
                    │ 各擁有系統的 export_state() -> Dictionary │
                    │ (AffinityDataPool 等,已有的 payload 契約) │
                    └───────────────────┬────────────────────────┘
                                         │ var_to_bytes(payload)
                                         ▼
                    ┌──────────────────────────────────────────┐
                    │  逐區塊 PackedByteArray 緩衝區             │
                    │  同一份緩衝區 ──┬─→ SHA-256 → block_hash  │
                    │                └─→ 寫入 blocks[source_id] │
                    └───────────────────┬────────────────────────┘
                                         │ 彙整 block_manifest
                                         ▼
                    ┌──────────────────────────────────────────┐
                    │  頂層 Dictionary:                          │
                    │  { ruleset_version, block_manifest[],      │
                    │    top_level_hash, blocks{} }              │
                    │  SHA-256(ruleset_version + 依 source_id     │
                    │  字典序排列的 tuple 清單) = top_level_hash  │
                    └───────────────────┬────────────────────────┘
                                         │ var_to_bytes()  →  交給下一份 ADR 的
                                         ▼                原子置換序列寫入磁碟

                    讀取路徑(Core Rules #16 鎖定順序):
                    bytes_to_var(外層 buffer) ──▶ ①頂層雜湊比對 ──▶ ②版本比對(VERSION_TOO_NEW 短路)
                                                              │
                                          ┌───────────────────┘
                                          ▼
                    manifest-only 路徑 ◀── 到此為止,不繼續 ──▶ 完整讀取路徑
                                                              │
                                                              ▼
                                          ③逐區塊雜湊比對(對尚未解碼的 PackedByteArray)
                                                              │
                                                              ▼
                                          ④bytes_to_var(buffer) 解碼
                                            (只擋 Object,見機制一之二)
                                                              │
                                                              ▼
                                          ⑤SaveTypeGate.scan(payload) 獨立遞迴掃描
                                            (擋 RID/Object/Callable/Signal,機制一之二)
                                                              │
                                                              ▼
                                          ⑥SaveBlockRegistry.get_validator(source_id)
                                            → validate_semantics() / 遷移鏈(下一份 ADR)
```

## Key Interfaces

以下為本 ADR 定案的契約形狀。**具體命名與型別簽章可在實作時微調,但語意不得改變**;任何改變語意的調整須回頭修訂本 ADR。

> **閱讀提醒**:以下為概念契約,不是可直接貼上的單一檔案。各類別應落在各自檔案。

```gdscript
# ─── save_format.gd ──────────────────────────────────────────
# 純函式工具集,不持有狀態
class_name SaveFormat extends RefCounted

enum ReadRejection {
    NONE,
    DATA_CORRUPTED,          # 頂層/逐區塊雜湊不符、型別白名單解碼失敗、驗證器未登記
    VERSION_TOO_NEW,         # ruleset_version 高於目前遊戲版本
    # MIGRATION_FAILED / SEMANTIC_VALIDATION_FAILED 由下一份 ADR(遷移執行模型)擴充此列舉,
    # 本 ADR 只定義格式/型別安全直接產生的兩種拒絕代碼
}

# serialize_block/serialize_manifest/deserialize_block/deserialize_manifest 內部委派
# SaveTypeGate 做型別閘控,對外暴露為本系統自己的函式名稱,不直接曝露底層全域函式,
# 方便未來若需要替換底層機制(例如 Verification Required 第 4 項若證實有問題)時只需
# 改動這幾個函式的實作。**回傳型別為機制一之二定義的 SerializeResult/DeserializeResult
# ——不是裸 PackedByteArray/Variant**(2026-08-24 修正:本表前一版仍留著回填
# SerializeResult/DeserializeResult 之前的舊簽章,`deserialize_block` 舊簽章的註解
# 「Dictionary 或 null」更是直接示範了本 ADR 明文禁止的 `!= null` 判定寫法——見「size()
# == 0 / is Dictionary 判定規則」——不可讓 Key Interfaces 這個最常被直接引用的段落,
# 教實作者寫出文件自己禁止的模式)。
static func serialize_block(payload: Dictionary) -> SerializeResult
static func serialize_manifest(envelope: Dictionary) -> SerializeResult
static func deserialize_block(buffer: PackedByteArray) -> DeserializeResult
static func deserialize_manifest(buffer: PackedByteArray) -> DeserializeResult
static func compute_block_hash(buffer: PackedByteArray) -> PackedByteArray   # SHA-256,見機制四
static func compute_top_level_hash(ruleset_version: int, block_manifest: Array) -> PackedByteArray
static func canonical_block_order(block_manifest: Array) -> Array  # 依 source_id 字典序排序

# ─── save_block_registry.gd ──────────────────────────────────
class_name SaveBlockRegistry extends RefCounted

func register(source_id: String, validator: Callable) -> void
func get_validator(source_id: String) -> Variant   # Callable 或 null

# ─── save_reader.gd(概念契約,依賴注入 SaveBlockRegistry)──────
class_name SaveReader extends RefCounted

func _init(registry: SaveBlockRegistry) -> void

func read_manifest_only(raw_bytes: PackedByteArray) -> Variant
# 回傳 {ruleset_version, block_manifest} 或 SaveFormat.ReadRejection

func read_block(raw_bytes: PackedByteArray, source_id: String) -> Variant
# 執行機制三步驟 ①~⑥;回傳驗證通過的 payload Dictionary,或 SaveFormat.ReadRejection

# ─── save_enum_registry.gd(概念契約,具體持久化/CI 比對機制留待 /create-architecture)──
class_name SaveEnumRegistry extends RefCounted

# 各擁有系統於其 enum 定案時呼叫,提交「目前合法的字串名稱集合」(機制五)。
# 退役名稱是否曾經存在過、如何比對歷次提交以偵測「消失又重新出現」,屬 CI 檢查的
# 具體實作方式,本 ADR 不定案(只定案「呼叫這個方法提交」這一介面形狀)。
func submit_current_names(enum_id: String, current_names: Array[String]) -> void
```

**enum 轉換慣例**(適用於任何持久化 enum 欄位,所有擁有系統的 `to_dict()`/`from_dict()` 一致遵循,參見 ADR-0002 機制八):正向(enum → 字串)用 `EnumName.find_key(value)`;反向(字串 → enum)用 `EnumName[name_string]`,並以 `EnumName.values().has(...)` 風格檢查guard 非法字串輸入,對應查無此名稱時回傳 `MIGRATION_FAILED`(依 GDD Core Rules #10,需要一個顯式遷移函數處理改名/移除,不是 `DATA_CORRUPTED`)。

**本次修訂新增的類別與常數**(契約細節不在此重述,見對應機制節):

| 類別 / 常數 | 落在哪 | 契約定義於 |
|---|---|---|
| `SaveTypeGate` | `save_type_gate.gd` | 機制一之二 —— 常數、`GateRejection`、`GateResult`、`scan()`/`scan_envelope()`、`_walk()`(薄殼)/`_walk_body()`(型別判斷與遞迴)、`verify_type_table_sum()`/`verify_type_table_partition()`/`self_check()` |
| `SaveEnvelope` | `save_envelope.gd` | 機制一之二 —— `check_shape()`(依 2026-08-24 裁決**不含**未知額外鍵拒絕邏輯) |
| `MANIFEST_ENTRY_FIELDS` | `save_format.gd` | 機制一之二 —— **單一共用常數**,形狀檢查與雜湊正規化都從這裡讀取欄位清單,不得另寫一份 |
| `hash_matches()` | `save_format.gd` | 機制四之二 —— 先驗長度再比內容(兩邊都失敗時空陣列 `==` 會假通過) |
| `SerializeResult` | `save_format.gd` | 機制一之二「寫入側接入點」—— `buffer`/`rejection`/`offending_path`/`ok()`,寫入側唯一的結果型別,不與讀取側的 `DeserializeResult` 或 `SaveFormat.ReadRejection` 混用 |
| `DeserializeResult` | `save_format.gd` | 機制一之二「讀取側接入點」—— `payload`/`rejection`(型別為 `SaveFormat.ReadRejection`)/`detail`/`offending_path`/`ok()` |
| `_sha256_of_chunks()` | `save_format.gd` | 機制四之二第 2/5 節 —— 三段式 `HashingContext` 私有輔助函式,任一 `update()` 失敗即捨棄該 context、回傳空 `PackedByteArray` 作為失敗訊號 |
| `SaveEnumRegistry` | `save_enum_registry.gd` | 機制五 —— 僅定案 `submit_current_names()` 這個介面形狀;退役名稱比對/CI 檢查的具體實作留待 `/create-architecture` |

`serialize_block`/`serialize_manifest`/`deserialize_block`/`deserialize_manifest`
一律委派 `SaveTypeGate`,寫入側與讀取側**共用同一份實作**;回傳型別分別是上表的
`SerializeResult`/`DeserializeResult`,不是裸 `PackedByteArray`/`Variant`。

**測試層新增**:
- `tests/unit/save_system/save_type_gate_depth_regression_test.gd` —— 深度回歸測試,
  涵蓋範圍精確界定為「深度檢查被移到遞迴之後」這一種挪動;⚠️ 其第二項斷言(行程
  沒有真的堆疊溢位)需要 CI 層檢查 stderr,已列為實作階段待辦。
- `tests/unit/save_system/save_type_gate_self_check_test.gd`(BLOCKING)——斷言
  `SaveTypeGate.self_check()` 回傳 `true`,是 `self_check()`(機制一之二)本 ADR
  唯一定案的接線點,理由見該節「接線義務」。

## Alternatives Considered

### Alternative 1:Godot 原生 `Resource`/`.tres`

- **Description**:每個資料區塊為一個 `Resource` 子類別,整份存檔用 `ResourceSaver.save()`/`ResourceLoader.load()` 存取。
- **Pros**:與 Godot 編輯器/除錯工具鏈原生整合(可在編輯器內直接檢視 `.tres` 內容);不需要手寫序列化轉接層。
- **Cons**:`ResourceLoader.load()` 標準路徑無型別過濾參數,會依檔案聲明的類別逕行實例化——Core Rules #9 型別白名單「近乎無法透過標準路徑強制執行」(GDD Open Question 3 `godot-specialist` 發現原話),需要自製 `ResourceFormatLoader` 才能安裝白名單,是額外且缺乏先例的攻擊面。且與 ADR-0002 已選定的格式無關 `Dictionary` 契約直接矛盾。
- **Rejection Reason**:直接牴觸 Core Rules #9 這項 GDD 鎖定的硬性規則,且與已登記的 `affinity_persistence_format` api_decision 衝突。

### Alternative 2:JSON

- **Description**:整份存檔序列化為 JSON 文字。
- **Pros**:人類可讀,除錯時可直接用文字編輯器檢視;跨平台工具鏈成熟。
- **Cons**:雙精度浮點數無法保證位元級往返,直接衝擊 AC-24 既有的「位元完全相同或誤差 <1e-12」容許誤差假設(GDD Open Question 18 明文列為格式相依、待格式定案後重新校準的項目);原生沒有 `PackedByteArray`/雜湊值的位元組表示法,需要額外的 base64/hex 編碼層;巢狀 `Dictionary`/`Array` 轉 JSON 物件/陣列在型別保真度上(例如 `int` vs `float` 的欄位若寫成 JSON 數字,還原時型別可能模糊)比二進位 Variant 序列化脆弱。
- **Rejection Reason**:格式本身的浮點精度限制與既有驗收標準衝突,且不比二進位 Variant 序列化更符合任何本專案已知的目標(不需要人類可讀性——存檔內容從不是玩家或設計師直接編輯的對象)。

### Alternative 3:單一扁平 `var_to_bytes()` 呼叫(無逐區塊獨立緩衝區分層)

- **Description**:整份存檔(manifest 中繼資料 + 全部區塊 payload)以單一 `Dictionary` 巢狀結構,一次 `var_to_bytes()` 呼叫序列化。
- **Pros**:實作更直觀,不需要管理「緩衝區的緩衝區」這種兩層序列化結構。
- **Cons**:`bytes_to_var()` 解碼外層結構時會遞迴解碼全部內容,「僅讀取 manifest」路徑(`TR-save-012`)無法迴避解碼任何區塊 payload,直接違反 Core Rules #5 對此介面的要求。也讓機制三的鎖定讀取順序(頂層雜湊 → 版本比對 → 逐區塊雜湊 → 型別白名單解碼)無法在格式層面自然成立——所有步驟會被迫在同一次 `bytes_to_var()` 呼叫內同時發生,無法在偵測到頂層雜湊不符或版本過新時提前終止而不觸碰任何區塊內容。
- **Rejection Reason**:直接牴觸 GDD 明文要求的兩個介面(manifest-only 路徑)與明文鎖定的讀取順序,不是效能取捨問題,是功能性缺陷。

### Alternative 4:靜態類別(非依賴注入實例)承載區塊驗證器登記表

- **Description**:`SaveBlockRegistry` 以靜態方法/靜態字典實作(`SaveBlockRegistry.register(...)`),不需要建構實例。
- **Pros**:呼叫端不需要持有/傳遞一個 registry 參照,寫法更簡潔。
- **Cons**:與 ADR-0002 機制一「依賴注入優於單例」的既有論證同一類風險——單元測試若要驗證「某區塊未登記驗證器 → `DATA_CORRUPTED`」這類情境,需要在測試前後手動清空/還原全域靜態狀態,無法簡單建構一個刻意留空的乾淨實例。
- **Rejection Reason**:與本專案已確立的 DI 偏好(`.claude/docs/coding-standards.md`)及 `autoload_singleton_for_testable_data_layers` forbidden pattern的精神一致,選擇依賴注入實例。

## Consequences

### Positive

- **`TR-save-001` 的格式決策一次性解決;`TR-save-002` 的下游疑慮(Open Question 4)也有解,但解法不是「格式選擇讓型別白名單問題消失」**——那個框架已被推翻(見機制一之二:`RID`/`Callable`/`Signal` 兩側都不受格式選擇管控)。實際解法是:型別白名單清單本身不需要按 `format_version` 分域,因為機制一之二的拒絕集合錨定在 Godot 引擎的 Variant 型別列舉(結構性、與遊戲內容版本無關),不是隨內容演進的清單。這仍是一個有意義的正面結論(不需要維護版本↔型別集合對照表),只是達成的理由與最初設想不同,且現在依賴本 ADR 自建的機制一之二被正確實作,不是引擎免費提供的保證。
- **manifest-only 與完整讀取兩條路徑、以及 Core Rules #16 鎖定的讀取順序,在格式層面自然成立**,不需要額外的流程控制邏輯「假裝」某個檢查先發生——這降低了未來實作偏離 GDD 鎖定順序的風險(順序錯誤在這個設計下會直接對應「多解碼了一次不該解碼的區塊」這種容易在程式碼審查中發現的具體症狀,不是一個容易被忽略的抽象規則)。
- **雙層雜湊鏈的「操作原子性」要求天然滿足**——不需要額外的紀律要求提醒實作者「不要為了算雜湊而重新序列化」,因為機制二的資料流本就只序列化一次。
- **與 ADR-0002 的既有決策完全一致、互相驗證**:`AffinityDataPool` 選擇格式無關 `Dictionary` 而非 `Resource`,在本 ADR 選定二進位 Variant 序列化後被證明是正確的前瞻判斷,不需要任何回頭修改。
- **enum 字串化轉換慣例從單一系統的實作選擇提升為專案級介面義務**,降低未來新系統各自發明不同轉換方式(進而各自可能踩到同一個 `enum_value_positional_string_conversion` 陷阱)的風險。

### Negative

- **`AffinityDataPool` 需要一次小幅回填修訂**(新增 `validate_semantics()`,`import_state()` 內部重構)——雖然範圍小且 ADR-0002 仍是 Proposed 狀態,仍是一次跨 ADR 的邊界調整,增加了追蹤兩份 ADR 一致性的負擔。
- **`var_to_bytes()`/`bytes_to_var()` 並非對稱地「安全失敗」——已實機驗證,結果比訓練資料推測更差**:讀取側對 `Object` 確實安全失敗(整包原子性失敗,不崩潰、不中止呼叫函式),但寫入側對 `Object`/`Resource` 完全不會失敗,而是靜默編碼並遺失欄位資料,零錯誤訊息(`core-serialization.md` 第 2-3 節)。機制一原本「僅靠格式選擇即可達成型別安全」的論證因此不成立,已改為依賴機制一之二(寫入側 + 讀取側各一道獨立遞迴型別閘門)——這代表本 ADR 需要維護並測試一段自己寫的閘門程式碼,不再是單純依賴引擎原生行為,是本次修訂新增的、真實存在的維護面。
- **逐區塊獨立序列化增加了微量的序列化呼叫次數**(每個區塊一次 `var_to_bytes()`,而非整份存檔一次)——對本系統實際規模(數個區塊、每槽數十 KB)而言可忽略,但這是明確的、非零的取捨,不是零成本的設計。

- **信封層對未知額外鍵寬容,與 `blocks` 額外條目被忽略,合起來產生兩塊不受完整性標記涵蓋的區域** —— 兩者單獨看都有理由,合起來看是存檔裡有兩塊沒人管、也沒人驗的區域。詳見下方專節。

#### 兩塊未受完整性標記涵蓋的區域(組合後果)

**執行者**:security-engineer。**擬併入位置**:ADR-0003「Consequences → Negative」。
**性質**:組合後果分析,結合兩項已各自存在、但從未合併檢視的既有決策/行為。
**建議處置**:登記為延後項,**不阻擋本次修訂**——等實作階段再決定是否擴大頂層雜湊
的涵蓋範圍。

##### 背景:兩項各自獨立、各自有理由的決定

1. **信封層未知額外鍵——2026-08-24 管理者裁決:忽略,不拒絕。**
   裁決理由:
   「與骨架 c-14 的既有行為一致,與延後清單 D-13 記錄的決定一致……換到的是:未來加
   欄位不必升版本號、新舊版存檔仍可互通」。
2. **`blocks` 字典的額外條目——骨架既有行為 c-4。**
   `prototypes/save-format-skeleton-2026-08-21/README.md`「(c) 設計沒講到」表 c-4:
   「`blocks` 的鍵集合不被任何雜湊涵蓋。manifest 少一條 → 頂層雜湊抓到;但 `blocks`
   少一條 → 頂層雜湊完全看不到」,決定為「在 S4 加明確守衛……刻意不把它提前到 S1B」,
   其副作用逐字記載:「**`blocks` 裡多出來的條目會被靜默忽略(從未讀取、從未檢查)**」。

兩項單獨看都有各自的工程理由(前者換取格式演進彈性,後者是「manifest↔blocks
交叉檢查該放哪一關」這個設計張力下的必要取捨,c-4 原文明說「兩者不能同時滿足」)。

##### 頂層雜湊的實際涵蓋範圍(用於界定「未受涵蓋」的精確意思)

頂層雜湊的輸入是 `(ruleset_version, block_manifest 依 source_id 字典序排列的 tuple
清單)`——**不包含** `blocks` 字典本身的鍵集合,也不包含信封層任何未列在
必要鍵清單中的欄位。**證據**(本文件內部):
機制二的 manifest 結構定義(「manifest 頂層雜湊
(涵蓋規則集版本號 + 逐區塊 tuple 清單……)」)、機制四的重算公式、以及 Key Interfaces 的
`compute_top_level_hash(ruleset_version, block_manifest)` 簽章——參數只有這兩個。

##### 組合後果:兩塊區域都不受頂層雜湊涵蓋,但風險輪廓不同——不可等量齊觀

合起來看,存檔裡確實存在**兩塊不受頂層雜湊涵蓋的區域**。但這兩塊區域被下一層
防線(型別閘門)涵蓋的程度**並不相同**,必須分開講清楚,否則會把兩者的風險
誤判為同一等級。

###### 區域一:信封層未知額外鍵——型別閘門仍會掃到

依機制一之二的讀取側接入點,`deserialize_manifest()` 的順序是
`bytes_to_var()` → **`SaveTypeGate.scan_envelope(整個信封)`** → `check_shape()`。
型別閘門跑在形狀檢查**之前**,而且掃描對象是**整個信封 Dictionary**(遞迴掃描
所有鍵與值)。因此即使信封層出現一個未列在必要鍵清單中的額外鍵,它的**內容**仍會
被這道閘門掃過。

| 未知欄位能夾帶什麼 | 是否可行 |
|---|---|
| `RID`/`Object`/`Callable`/`Signal`(危險型別,見上半篇二維框架) | ❌ **擋得住**——型別閘門涵蓋整個信封,§2 表格四個危險型別無論放在信封的哪個位置都會被掃到並拒絕 |
| 一般資料(字串、數字、陣列等白名單型別) | ✅ 可夾帶,且**不受頂層雜湊保護**——放進去之後,即使被外部竄改,`top_level_hash` 比對仍會通過(因為它本來就沒涵蓋這個鍵) |

**⚠️ 界線務必寫準,不要誇大**:管理者的裁決只開放了「任意資料」這一面,
**沒有**開放「危險型別」那一面。這一點在原提問時沒有明講,此處補記以免日後
誤解裁決範圍。**依據**:機制一之二的讀取側接入點順序(型別閘門先於形狀檢查、且掃整個信封),
與此處的判定一致。

###### 區域二:`blocks` 的額外條目——型別閘門**不會**掃到內容,是更深的盲區

`blocks` 字典本身是信封的一部分,所以它的**外層形狀**(每個值的外層型別是否為
`PackedByteArray`)會被信封層型別閘門掃到。但 `blocks` 的值是**已經序列化過的
巢狀 `PackedByteArray`**——依機制一之二的既定設計(已序列化的巢狀
`PackedByteArray` 不打開來掃、視為葉節點;該節已明文記載此決策與其代價),
信封層型別閘門**不會
解碼**這個 `PackedByteArray` 的內容,只把它當成一個不透明的葉節點通過。這個設計
本身已由 F4'-a 驗證為安全前提的一部分(manifest 層讀取不遞迴解讀區塊內容,
見上半篇 §2 引用的 `core-serialization.md`)。

而**具體到 `blocks` 額外條目**——即 `blocks` 字典裡存在一個 `source_id` 不在
`block_manifest` 中的條目——c-4 已明文記載這種條目「從未讀取、從未檢查」,也就是
它**永遠不會被送進 `deserialize_block()`**(該函式才是真正對區塊內容做
「讀取側對稱型別閘門」的地方,見骨架驗證 C 讀取側毒藥向量表)。

**結論(推論,綜合上述兩項已測事實推導,非單獨一次量測)**:`blocks` 額外條目的
**位元組內容**,目前的設計下**不會被任何一道型別閘門檢查**——既不是信封層閘門
(視為葉節點,不開封)、也不是逐區塊閘門(從未被選中解碼)。它比區域一更深一層:
區域一至少保證「危險型別擋得住,只有一般資料能夾帶」;區域二連這個保證都沒有——
一段完整編碼的危險型別位元組理論上可以原封不動地放在一個孤兒 `blocks` 條目裡,
不觸發雜湊不符,也不觸發任何一道型別閘門的拒絕。**但需同時說清楚它不是一個可
即時利用的攻擊面**:因為這段位元組從未被 `bytes_to_var()` 解碼,危險型別本身
不會被「解出」成活體 `Signal`/`RID` 控代碼或空殼 `Callable`——它就是一段永遠
不會被讀取的死位元組,除非未來實作變更成「遍歷 `blocks` 全部鍵」而非「只依
`block_manifest` 選讀」,那時才需要重新評估是否要在該路徑上補一道閘門(這是
針對假設中的未來變更的推論,不是對現行程式碼的宣稱)。

###### 兩塊區域的風險輪廓對照

| | 區域一:信封層未知額外鍵 | 區域二:`blocks` 額外條目 |
|---|---|---|
| 受頂層雜湊涵蓋 | ❌ 否 | ❌ 否 |
| 受型別閘門涵蓋(危險型別會被擋) | ✅ 是 | ❌ 否(內容從未被開封檢查) |
| 可夾帶什麼而不觸發任何檢查 | 一般資料(字串/數字/陣列) | 任意位元組,理論上包含危險型別的完整編碼 |
| 該危險型別是否會被「解出」成活體控代碼 | 不適用(已被閘門擋下,不會寫入/讀出) | 不會——除非未來變更讀取路徑改為遍歷全部 `blocks` 鍵 |
| 目前性質 | 未受完整性保護的「合法資料」旁路 | 未受完整性保護**且**未受型別檢查的「不透明位元組」盲區,目前不可觸發解碼 |

##### 建議登記為延後項

建議在延後清單(依循 `adr-0003-deferred-to-implementation.md` 既有格式)新增一條,
記錄以下待實作階段裁決的問題:

- 是否要把頂層雜湊的涵蓋範圍擴大到包含 `blocks` 的鍵集合(可偵測「多了/少了
  一個區塊」而不必依賴 S4 的個別守衛)?
- 若日後任何程式碼路徑改為遍歷 `blocks` 全部鍵(而非只依 `block_manifest` 選讀),
  是否需要在該路徑上額外掛一道型別閘門(現行 `deserialize_block()` 那一道只在
  被 manifest 選中時才會執行)?
- 信封層是否需要一個「已知但未使用」的稽核記錄(例如記錄下有哪些未知鍵/孤兒
  區塊被忽略),供人工排查存檔異常時使用?這不是安全性要求,是可觀測性要求。

**威脅模型範圍註記**:以上分析全部在單機、無連線威脅模型下進行——攻擊面是本機
存檔檔案被使用者本人或本機其他程式修改,不涉及網路傳輸或多人連線。所有引用的
量測結果均取自 debug/headless 建置,release build 下是否維持一致**未查證**
(`core-serialization.md`「未查證」第 1 項;`save-format-skeleton-2026-08-21/README.md`
「(d) 未查證」第 1 項),本文不宣稱這些行為在 release build 下同樣成立。

### Risks

| 風險 | 緩解 |
|---|---|
| **`bytes_to_var(buffer)`/`var_to_bytes()` 對惡意/損毀位元組的實際行為與訓練資料推測不符 —— 已證實成真,而且不符的方向比預期更壞**(原 Verification Required 第 2 項,已關閉;`core-serialization.md` 第 2-3 節) | **讀取側**:與推測相符——`bytes_to_var()` 對本應解碼出 `Object` 的位元組整包原子性失敗,回傳非 `Dictionary` 值,伴隨 `ERR_UNAUTHORIZED`。**寫入側**:原始問法完全沒問到這一側,而實測結果與直覺相反——`var_to_bytes()` 對 `Object`/`Resource` **不報錯、不拒絕**,靜默編碼成 `EncodedObjectAsID`,原欄位資料靜默遺失,零錯誤訊息。**這個發現直接促成機制一之二的存在**(寫入側 + 讀取側各一道獨立型別閘門,拒絕集合 {23 RID、24 Object、25 Callable、26 Signal}),並連帶推翻本文件初稿全文 18 處採用的兩引數呼叫寫法。型別安全論證已不再依賴「引擎行為天生對稱安全」這個假設,改由機制一之二的自建閘門保證,失敗處置對應機制三步驟 5a(擋 Object)/5b(擋 RID/Callable/Signal) |
| **`Dictionary` 巢狀 `PackedByteArray` 透過 `var_to_bytes()`/`bytes_to_var()` 往返是否有未預期行為**(原 Verification Required 第 4 項,已關閉) | **已測,無此風險**:巢狀 `PackedByteArray` 往返保真(byte-identical),外層 `bytes_to_var()` 解碼時不遞迴解讀內層 `PackedByteArray` 的內容(維持 `typeof=29` 不透明,原封不動),型別化容器(如 `Array[int]`)往返後仍保持型別化。**證據**:探針 F4'-a(`prototypes/xcheck-adr0003-2026-08-21/`);`prototypes/save-format-skeleton-2026-08-21/README.md` 驗證 D(manifest-only 路徑計數器證明,`blocks['...']` 外層解碼後仍是 `typeof=29`、未解碼)。此為機制二「manifest-only 路徑不解碼任何區塊」設計得以成立的直接前提 |
| **超大 Delta Log(數百小時遊玩)下 `var_to_bytes()`/`bytes_to_var()` 或 SHA-256 計算是否有效能懸崖**(原 Verification Required 第 5 項,已關閉於**實務規模**,非無條件關閉) | **已測,實務規模內無效能懸崖**:32MB/64MB 緩衝區與 100k/500k 筆記錄的編解碼與 SHA-256 皆線性成長、往返 byte-identical(`core-serialization.md` 第 8 節,探針 F5)。GDD 自身估計單槽規模為數十 KB,遠低於已測規模六個數量級。⚠️ **這不是「上限已排除」的無條件結論**:測試**刻意未逼近** `var_to_bytes()` 理論上限(~2GB,逼近會 OOM),64MB 是目前唯一確認的線性上界;若未來內容規模假設改變(例如角色數量政策翻轉),須重新測到更大規模才能維持「無懸崖」的結論,已在 GDD Tuning Knobs 標記為連動項目 |
| **`SaveBlockRegistry` 與各擁有系統的初始化時序**(若某系統忘記在讀取發生前呼叫 `register()`,該區塊會被誤判為「無驗證器宣告」而非「尚未初始化」) | 這是 fail-closed 設計的刻意結果,不是需要避免的缺陷——GDD 明文「未宣告視為錯誤」,一個忘記註冊驗證器的系統理應無法通過讀取,而非靜默略過語意檢查。具體的初始化順序保證(確保所有擁有系統在任何讀取發生前完成註冊)留待 `/create-architecture` 決定 |
| **外層 manifest 最終寫入磁碟時,若下一份 ADR 選擇直接呼叫 `FileAccess.store_var()` 而非 `store_buffer()` 寫入本 ADR 產生的最終位元組緩衝區**(2026-08-18 `godot-specialist` 驗證發現)——`store_var()` 自 4.4 起回傳型別為 `bool`(原為 `void`,見 `breaking-changes.md` 4.3→4.4 表格) | 下一份 ADR(原子寫入)設計 Core Rules #14 步驟 1「確保寫入成功」的具體實作時,若使用 `store_var()` 寫入,須檢查此 `bool` 回傳值以偵測寫入失敗,不可假設呼叫必然成功;此為本 ADR 與下一份 ADR 的介面交接提醒,不影響本 ADR 自身決策 |
| **`HashingContext` 三段式呼叫(`start`/`update`/`finish`)是否有更簡潔的一次性便利方法**(原為 `godot-specialist` 低信心度觀察,已查證關閉) | **答案是:不存在——這不是「風險已排除」,而是「這個簡化機會本身不存在」**。`PackedByteArray` 沒有 `sha256_buffer()` 方法,呼叫是編譯期錯誤(逐字:`Parse Error: Cannot find member "sha256_buffer" in base "PackedByteArray".`);該便利方法只存在於 `String`。本 ADR 的雜湊輸入一律是序列化後的 `PackedByteArray` 緩衝區,不是 `String`,因此三段式 `HashingContext` 呼叫是**唯一路徑**,沒有更簡潔的替代寫法可用。**證據**:`core-serialization.md` 第 5 節(193-196 行);探針 F3c1/F3c2/F3c3 |

## GDD Requirements Addressed

| TR-ID | 需求 | How This ADR Addresses It |
|---|---|---|
| TR-save-001 | 序列化格式未定案 | 選定 `var_to_bytes()`/`bytes_to_var(buffer)` 二進位 Variant 序列化(機制一),拒絕 Resource/JSON(Alternatives 1/2) |
| TR-save-002 | 型別白名單須在任何實例化之前完成閘控 | 分兩部分:(1)`Object` (24)由引擎讀取側原生行為無條件擋下(`bytes_to_var()` 對含 Object 的位元組整包 原子性失敗),這部分不依賴本 ADR 的任何額外機制;(2)`RID`(23)/`Callable`(25)/ `Signal`(26)不受引擎任何原生閘門管控,由本 ADR 新增的機制一之二(寫入側 + 讀取側各一道遞迴型別閘門,兩者共用同一份型別判定邏輯)在遷移/語意驗證(機制六) **之前**攔截,讀取順序上型別閘控(機制三步驟 5b)先於語意驗證/遷移(步驟 6)不變 |
| TR-save-003 | manifest + 版本化區塊結構,每區塊各自版本化,manifest 攜帶單一規則集版本號 | 機制二定義的分層 Dictionary 結構(`ruleset_version`/`block_manifest`/`blocks`) |
| TR-save-010 | 結構化機器可讀結果須能區分成功/拒絕代碼/無資料等(本 ADR 僅涵蓋格式/型別安全直接產生的部分) | `SaveFormat.ReadRejection` 列舉定義 `DATA_CORRUPTED`/`VERSION_TOO_NEW` 兩種本 ADR 範圍內的拒絕代碼;`MIGRATION_FAILED`/`SEMANTIC_VALIDATION_FAILED` 等執行模型相關代碼留待下一份 ADR 擴充同一列舉 |
| TR-save-011 | 完整讀取路徑檢查順序已鎖定(#8→#5 版本→#9→#7/#5) | 機制三步驟 1-6 逐項對應此順序,順序由機制二的分層緩衝區結構在格式層面保證,非流程控制邏輯的額外假設 |
| TR-save-012 | 雙讀取路徑,manifest-only 不觸發遷移、不反序列化 payload | 機制二的分層設計讓 manifest-only 路徑只需一次外層 `bytes_to_var()`,不解碼任何 `blocks` 字典的值 |
| TR-save-013 | 兩層加密雜湊鏈,固定規範順序,與寫入當下容器順序無關 | 機制四:逐區塊 SHA-256 + 頂層 SHA-256(涵蓋 `ruleset_version` + 依 `source_id` 字典序排列的 tuple 清單) |
| TR-save-014 | 雜湊輸入須為寫入前、同一次序列化操作產生的記憶體資料 | 機制二/四的資料流本身保證此順序,雜湊計算發生在 `var_to_bytes()` 產生緩衝區之後、寫入磁碟之前 |
| TR-save-022 | 語意驗證器為 fail-closed,未宣告視為錯誤 | 機制六:`SaveBlockRegistry.get_validator()` 回傳 `null` 時直接 `DATA_CORRUPTED`,不進入語意驗證 |
| TR-save-023 | 持久化 enum 一律以字串名稱表示,退役名稱永久保留、CI 可強制重用檢查 | 機制五:推廣 ADR-0002 已建立的 `find_key()`/`enum[name]` 慣例為專案級介面義務;`SaveEnumRegistry` 概念契約供未來 CI 檢查依循 |
| TR-save-028 | 巢狀 Resource 深層複製紀律與存檔格式須一併設計 | 機制一的格式選擇(拒絕 Resource)使此問題降級為未來系統(活棋盤地形)自身的閘道轉換責任,不在本 ADR 範圍內需要解決 |

## Performance Implications

- **CPU**:逐區塊 SHA-256 計算與 `var_to_bytes()`/`bytes_to_var()` 呼叫次數,與區塊數量成正比(目前已知區塊:好感度數值池,未來陸續增加),單次呼叫成本在 GDD 估計的資料規模(單槽數十 KB)下可忽略。manifest-only 路徑的成本為 O(1)(一次外層 `bytes_to_var()` + 一次頂層雜湊比對),不隨區塊 payload 大小成長。
- **Memory**:讀取時同時持有原始位元組緩衝區與解碼後的 `Dictionary`(短暫重疊,解碼完成後原始緩衝區可釋放),峰值記憶體約為單槽資料量的 2 倍,在數十 KB 規模下不構成風險。
- **Load Time**:完整讀取路徑的耗時屬於 GDD `migration_chain_load_time_budget_ms` 的量測範圍(下一份 ADR 的執行模型 ADR 負責),本 ADR 只保證格式層面沒有引入非必要的額外解碼/雜湊計算。
- **Network**:不適用(單人遊戲)。

**明確未定案**:`var_to_bytes()`/`bytes_to_var()` 對大型 `PackedByteArray` 的實際效能特性(Verification Required 第 5 項);enum 退役名稱自動化檢查的具體 CI 實作方式。

## Migration Plan

不適用——本專案 `src/` 目前為空,尚無任何實作程式碼,處於設計階段。本 ADR 為前瞻性決策,不涉及既有程式碼遷移。**但本 ADR 對 ADR-0002 的回填修訂需要在 ADR-0002 的實際實作發生前完成**——若 `/create-stories`/`/dev-story` 已依 ADR-0002 原始版本(無 `validate_semantics()`)產生 story 或程式碼,需要回頭同步。目前 `src/` 為空,不存在此風險。

## Validation Criteria

1. **GDD Acceptance Criteria 中「型別白名單」「雜湊鏈」「enum 字串化」三類的全部向量通過**(即 AC-30/AC-20b/AC-53、AC-28/AC-43/AC-52/AC-62/AC-65/AC-74/AC-79/AC-82、AC-25/AC-29/AC-49/AC-50/AC-41/AC-42/AC-51)——這是本 ADR 機制是否真的支撐 GDD 義務的直接證據。
2. **manifest-only 路徑的黑箱驗證**:透過 profiler 或呼叫計數,確認該路徑執行期間從未對任何區塊的 `PackedByteArray` 呼叫 `bytes_to_var()`。
3. **讀取順序的失敗注入測試**:分別構造「頂層雜湊不符」「版本過新且 payload 含未來型別」「單一區塊雜湊不符」三種輸入,驗證各自在機制三對應的步驟終止,不繼續執行後續步驟(尤其驗證「版本過新」情境確實在觸碰任何區塊 payload 之前就回傳 `VERSION_TOO_NEW`,不會被型別白名單搶先攔截成 `DATA_CORRUPTED`)。
4. **`bytes_to_var(buffer)` 安全失敗的實機驗證**(對應 Verification Required 第 2 項):構造一段刻意編碼出 Object 型別的位元組,確認解碼回傳可預期的失敗結果(而非崩潰或未定義行為)。
5. **雙層雜湊的獨立性測試**:分別驗證「竄改 payload 但不更新逐區塊雜湊」「竄改 `source_id`/`format_version` 但保留 payload」「從 manifest 移除整個區塊條目」三種情境,確認第一種被逐區塊雜湊攔截、第二三種被頂層雜湊攔截。
6. **後續 `/architecture-review`** 判定本 ADR 與 ADR-0001/ADR-0002 無衝突,且對 `save-system.md` 的涵蓋(本 ADR 範圍內的 `TR-save-*` 項目)無缺口。

**反向驗證(本 ADR 若錯了會如何顯現)**:若逐區塊緩衝區分層設計有誤(例如外層 `bytes_to_var()` 意外遞迴解碼了區塊內容),會表現為 manifest-only 路徑的效能與完整讀取路徑無異——第 2 項驗證會直接攔截。若雙層雜湊的涵蓋範圍算錯(例如頂層雜湊遺漏了某個 tuple 元素),會表現為某類竄改(例如刪除區塊條目)未被偵測到——第 5 項的三段式測試會逐一攔截每一種涵蓋範圍錯誤。

## Related Decisions

- `design/gdd/save-system.md` — 本 ADR 服務的全部義務之權威定義處,本 ADR 只定案機制。
- `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` — `relying_on_container_iteration_order` forbidden pattern 的來源,本 ADR 的頂層雜湊固定順序設計直接應用此立場。
- `docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md` — 本 ADR 依賴其 `export_state()`/`import_state()` 契約作為好感度區塊 payload 來源,並對其做 `validate_semantics()` 回填修訂(見機制六)。
- `docs/registry/architecture.yaml` — 本 ADR 核准後,新增立場登記於此檔;登記時機是 ADR 寫入之後的獨立步驟,依專案規則由登記表本身收斂,不在本文重複列出。
- `docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md`(2026-08-18 新增)——消費本 ADR 定義的位元組緩衝區與雜湊機制。**`TR-save-*` 30 項的權威涵蓋數字為 22 完整 / 7 部分 / 1 缺口**(`TR-save-030` 雲端存檔同步;2026-08-18 第二輪 `/architecture-review` 獨立推導,2026-08-20 第七輪重推維持同數)。⚠️ **2026-08-21 修正**:本行原寫「`TR-save-*` 系列至此三份 ADR **全數覆蓋**」——這是同一句過度宣稱的**第五處**,且是**唯一不在 ADR-0004 檔案內**的一處。第五輪 `/architecture-review` 曾核實並宣稱「該過度宣稱至此四處全數清除」,但**那四處指的全是 ADR-0004 自己文件內的**,從未檢查本 ADR 的 `Related Decisions` 有沒有同一句話——**「四處全數清除」這個全稱宣稱本身的定義域小於它的措辭**,這正是本專案反覆出現的失敗形狀。由 2026-08-21 ADR-0004 事實層修訂的 Step 5.5 覆核抓出。
