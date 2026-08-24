# ADR-0003: 存檔系統序列化格式與型別安全

## Status

Proposed

## Date

2026-08-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core(序列化與資料完整性) |
| **Knowledge Risk** | **MEDIUM(2026-08-21 第一次修訂由 HIGH 下調,理由如下;⚠️ 此下調為本次修訂的提案,請覆核者明確確認或否決)**——原 HIGH 的兩項理由**其中一項已消滅、一項仍成立**。**已消滅**:「無專屬 core/scripting 模組參考文件可查」——2026-08-21 已建立 `docs/engine-reference/godot/modules/core-serialization.md` 與 `modules/scripting-typing.md`,兩份皆逐條附探針與未過濾 log 引用,涵蓋本 ADR 依賴的全部 API(四個全域序列化函式、`HashingContext` 完整狀態機、`EncodedObjectAsID`、`Callable`/`Signal`/`RID` 邊界、Variant 型別枚舉全表)。**仍成立**:`var_to_bytes`/`bytes_to_var`/`HashingContext` 在 `breaking-changes.md`/`deprecated-apis.md` 仍為零命中,即**官方仍未記錄這些 API 的任何版本變更**,故不能宣稱「已知穩定」,只能宣稱「本專案已在 4.7.1 實測」。**新增的第三項理由(支持不降到 LOW)**:全部量測皆在 **debug/headless** 下取得,**release 建置行為未查證且本機無法查證**(`%APPDATA%/Godot/export_templates/` 存在但完全是空的,全域零個 `.tpz`)——此缺口與 ADR-0002 第 7 項、ADR-0004 為同一個洞,可一次關三份。⚠️ **本 ADR 的歷史教訓必須保留在此欄**:2026-08-21 探針 F 實測推翻本文件**全文 18 處**逐字採用的呼叫寫法(`bytes_to_var(bytes, false)` 是 **Parse Error**),這是本專案第二次由實機驗證擊落已寫下的 ADR 內容。**該錯誤的根因不是引擎版本變更,而是過期的舊版記憶**——Godot 3 的單一布林參數在 Godot 4 已拆成兩個獨立函式,而 `FileAccess.get_var(allow_objects)`/`store_var(full_objects)` **仍保留第二個布林參數**,「同一線格式、兩種 API 形狀」正是誤植來源(詳見 `modules/core-serialization.md` 第 1 節) |
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

採用 **`var_to_bytes()`/`bytes_to_var(bytes)` 二進位 Variant 序列化**(拒絕 `Resource`/`.tres` 與 JSON)——與底層 `FileAccess.store_var()`/`get_var()` 共用相同的 Variant 編碼線格式與安全語意,但不繫結於 `FileAccess` 物件——搭配**逐區塊獨立序列化為 `PackedByteArray` 緩衝區**的 manifest 分層結構,**SHA-256 雙層雜湊鏈**,以及**依賴注入的區塊驗證器登記表**。

### 核心洞見:格式選擇本身就是型別安全機制,不是型別安全機制的載體

GDD Open Question 3 的 `godot-specialist` 發現點出一個容易被忽略的事實:Core Rules #9(型別白名單)通常被想成「格式決定後,另外寫一段驗證邏輯」,但格式選擇本身就能讓這段邏輯變得多餘或變得幾乎不可能省略。`Resource`/`.tres` 的標準載入路徑(`ResourceLoader.load()`)沒有型別過濾參數,會依檔案聲明的類別逕行實例化——若要在這個路徑上安裝白名單,需要自製 `ResourceFormatLoader` 攔截每一次實例化,是額外的、持續維護的攻擊面。`bytes_to_var(bytes)` 則是**引擎層級直接拒絕解碼出任何 `Object` 衍生實例**,只產生巢狀 `Dictionary`/`Array`/原生型別——型別白名單問題不是「被解決」,而是**結構性地不存在**:沒有任何自訂類別可以從這條路徑產生,因此也沒有「非白名單類別」這個情境可言。這個選擇同時解答了 GDD Open Question 4(白名單的版本域範圍——扁平聯集或依版本分域):兩者都以「存在一份需要維護的合法類別清單」為前提,而本 ADR 的格式選擇讓這個前提本身不成立。

### 機制一:二進位 Variant 序列化(`var_to_bytes`/`bytes_to_var`),拒絕 Resource 與 JSON

每個持久化資料區塊的 payload,由其擁有系統提供一個純 `Dictionary`(巢狀 `Array`/`String`/`int`/`float`/`bool`/`PackedByteArray` 等原生 Variant 型別,不含任何自訂 `Object`/`Resource`)——`AffinityDataPool.export_state()`(ADR-0002)已經是這個形狀,不需要任何轉接層。**編碼/解碼機制(2026-08-18 `godot-specialist` 驗證修訂,BLOCKING)**:此 `Dictionary` 透過全域函式 `var_to_bytes(payload) -> PackedByteArray` 序列化成一份記憶體中的位元組緩衝區,讀取時以 `bytes_to_var(buffer) -> Variant` 還原——**不使用** `FileAccess.store_var()`/`get_var()` 承載這一層:`godot-specialist` 查核時指出 GDScript 的 `FileAccess.open()` 只能開啟真實檔案路徑(`res://`/`user://`/絕對路徑),沒有暴露「純記憶體」開啟模式,原草稿「開一個記憶體內或暫存檔案」的描述技術上不成立。`var_to_bytes()`/`bytes_to_var()` 與 `FileAccess.store_var()`/`get_var()` 底層共用相同的 Variant 編碼/解碼核心邏輯(線格式相同),差別只是不需要 `FileAccess` 物件、不需要暫存檔案——`bytes_to_var()` 的 `allow_objects` 參數預設即為 `false`,本 ADR 一律**顯式**傳入 `false`(不依賴預設值,見機制三的縱深防禦說明),確保任何試圖解碼出 `Object` 的輸入直接安全失敗,不進入本系統其餘邏輯。**外層 manifest 本身若最終確實需要以 `FileAccess` 寫入實體檔案(下一份 ADR 的原子寫入序列),屆時才會用到 `FileAccess` 相關 API**——本 ADR 的兩層緩衝區結構(機制二)全程只處理記憶體中的 `PackedByteArray`,與磁碟 I/O 解耦,兩者的介面交接點見 Related Decisions。

**與 `Resource`/`.tres` 的取捨**(拒絕理由):`ResourceLoader.load()` 的標準路徑無型別過濾參數,原生會依檔案聲明的類別實例化——這與 Core Rules #9「反序列化型別白名單」的存在目的直接衝突,除非另外實作自訂 `ResourceFormatLoader`,而那本身是一個需要獨立維護、且沒有先例可循的攻擊面。

**與 JSON 的取捨**(拒絕理由):JSON 為文字格式,雙精度浮點數無法保證位元級往返(見 GDD Open Question 18,AC-24 的「位元完全相同或誤差 <1e-12」容許誤差假設在 JSON 下不成立)——`AffinityDataPool` 的公式一/二讀值、Delta Log 的 `m_i` 幅度欄位皆為浮點,JSON 格式會直接讓 AC-24 的既有驗收標準失真,需要重新校準成一個較寬鬆、格式相依的容許誤差,這是一個不必要的複雜度來源。此外 JSON 原生沒有 `PackedByteArray`/型別化陣列的概念,巢狀雜湊值(見機制四)須額外編碼為字串(例如 base64 或 hex),增加不必要的轉換層。

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
5. 通過雜湊驗證的區塊,以 `bytes_to_var(buffer)` 解碼其 `PackedByteArray`,取得該區塊的 payload `Dictionary`——此呼叫本身即是型別白名單閘門(機制一),解碼失敗(例如位元組本應解碼出一個 Object)視為 `DATA_CORRUPTED`。
6. 解碼成功的區塊 payload,交由其擁有系統的 `validate_semantics()`(機制六)做語意驗證,或(若格式版本落後)進入遷移鏈——這部分屬於下一份 ADR(遷移執行模型)的範圍,本 ADR 只保證抵達這一步時,payload 已經是型別安全、雜湊驗證通過的 `Dictionary`。

### 機制四:雙層雜湊鏈與操作原子性

雜湊演算法採 **SHA-256**,透過 `HashingContext`(`start(HashingContext.HASH_SHA256)` → 逐段 `update()` → `finish()`,**確切 API 簽章待驗證**,見 Engine Compatibility)。

- **逐區塊雜湊**:對該區塊**獨立序列化後、尚未寫入外層結構前**的 `PackedByteArray` 緩衝區本身計算,不含 `source_id`/`format_version`/`migration_completion_marker`(這三者由頂層雜湊涵蓋,見下)——直接對應 GDD「逐區塊雜湊只涵蓋 payload 本身」與「頂層雜湊才涵蓋來源身分與版本中繼資料」的兩層分工。
- **頂層雜湊**:輸入為 `(ruleset_version, block_manifest 依 source_id 字典序排列的 tuple 清單)`——每個 tuple 為 `(source_id, format_version, block_hash, migration_completion_marker)`。**固定順序採 `source_id` 字典序,不依賴 `block_manifest` 陣列本身的建構/迭代順序**——直接呼應 `docs/registry/architecture.yaml` 已登記的 `relying_on_container_iteration_order` forbidden pattern(ADR-0001 登記,原針對 `Dictionary`/`Array` 原生迭代順序不穩定的一般性風險,本 ADR 是該登記立場在 manifest 層級的具體應用)。
- **操作原子性**(GDD 第七輪新增規則,直接對應機制二的分層設計):逐區塊雜湊的輸入緩衝區,與最終寫入磁碟的**是同一個** `PackedByteArray` 物件——本 ADR 的設計天然滿足此規則,因為機制二本就要求每個區塊獨立序列化出一份緩衝區,該緩衝區同時是雜湊輸入與 `blocks[source_id]` 的值,不存在「為了算雜湊而重新序列化一次」的第二條路徑。
- **雜湊輸入來源為寫入前的記憶體資料**(GDD 第六輪新增規則):本 ADR 的雜湊計算天然發生在 `var_to_bytes()` 產生緩衝區之後、`FileAccess` 實際寫入磁碟之前的記憶體物件上——不涉及任何「寫入後讀回磁碟位元組」的路徑,這個順序由機制二的資料流本身保證,不需要額外的紀律要求。

**為何不用較廉價的非加密雜湊(例如 CRC32)**:雖然 Core Rules #8 明文的威脅模型是意外損毀而非知情攻擊者,GDD 本身仍明文要求「SHA-256 或等效強度演算法」,排除純檢查碼類別(CRC32 對特定樣式的多位元同時翻轉有已知的碰撞盲點,不符合「等效強度」的字面要求)。SHA-256 對本系統實際資料量(單槽估計數十 KB,見 GDD Tuning Knobs)的計算成本可忽略,沒有理由為了省下這個可忽略的成本而低於 GDD 鎖定的演算法強度門檻。

### 機制五:enum/索引鍵字串化——沿用 ADR-0002 已登記的慣例,推廣為專案級介面義務

Core Rules #10 要求 `Pair`(索引鍵)與任何持久化 enum 欄位(如 `source_i`)以字串名稱持久化。ADR-0002 已經在 `AffinityRecord.to_dict()`/`from_dict()` 中實作此規則,採 `enum.find_key(value)`(依值查鍵)與 `enum[name_string]`(依鍵查值)而非 `keys()[value]` 位置索引——`docs/registry/architecture.yaml` 已登記 `enum_value_positional_string_conversion` forbidden pattern。**本 ADR 不重新發明這個機制,而是把它從「`AffinityDataPool` 自己的實作選擇」提升為「本系統對所有持久化資料區塊的擁有系統的介面要求」**:任何區塊的 `to_dict()`/`from_dict()`(或等效轉接方法)若涉及 enum 欄位,一律採此慣例。**退役名稱治理與自動化檢查**(Core Rules #10 的強制項)由本系統集中提供一個輕量工具——`SaveEnumRegistry`(概念契約,見 Key Interfaces):各擁有系統於其 enum 定案時,向此登記表提交「目前合法的字串名稱集合」;`/create-architecture` 階段須提供一個建置期/CI 可執行的檢查,比對歷次提交記錄與目前集合,偵測任何「曾經存在、後消失、又重新出現」的名稱並使建置失敗——**此檢查本身的具體實作(例如比對歷史記錄檔案的存放方式)留待 `/create-architecture` 決定,本 ADR 只定案介面形狀與檢查必須存在這件事**,呼應 GDD「此規則必須有自動化檢查,不能只靠人工審查紀律」的硬性要求。

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

### 機制七:型別白名單版本域範圍問題的消解(Open Question 4)

GDD Open Question 4 問的是:若採「扁平聯集」型別白名單(所有版本曾經合法過的型別皆列入),存在攻擊者宣告舊規則集版本以繞過較新版本較嚴格檢查的理論風險;若採「依版本分域」,則需要額外的版本↔合法型別集合對照機制。**本 ADR 的格式選擇讓這個問題不成立**:`bytes_to_var(buffer)` 從不產生任何自訂 `Object`,因此不存在「型別」這個維度需要按版本分域——**唯一與版本相關的合法性檢查,是機制六的 `validate_semantics()`(語意層級的欄位值域,可以且應該依格式版本分流其檢查邏輯,但那是語意驗證,不是型別白名單)**。GDD 原本擔心的「宣告舊版本以繞過較新版本檢查」風險,在本 ADR 的架構下轉譯為「宣告舊 `format_version` 觸發舊版遷移函數鏈,而非新版驗證邏輯」——這正是 Core Rules #16 鎖定順序中「遷移鏈執行完成後仍須通過目前版本的語意驗證」(GDD 第二輪裁決)本就防範的情境,不需要本 ADR 額外處理。

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
                                            (= 型別白名單閘門)
                                                              │
                                                              ▼
                                          ⑤SaveBlockRegistry.get_validator(source_id)
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

# serialize_block/deserialize_block 內部分別包一層 var_to_bytes()/bytes_to_var(buffer)——
# 對外暴露為本系統自己的函式名稱,不直接曝露底層全域函式,方便未來若需要替換底層機制
# (例如 Verification Required 第 4 項若證實有問題)時只需改動這兩個函式的實作。
static func serialize_block(payload: Dictionary) -> PackedByteArray
static func deserialize_block(buffer: PackedByteArray) -> Variant   # Dictionary 或 null(型別白名單失敗)
static func compute_block_hash(buffer: PackedByteArray) -> PackedByteArray   # SHA-256,見機制四
static func compute_top_level_hash(ruleset_version: int, block_manifest: Array[Dictionary]) -> PackedByteArray
static func canonical_block_order(block_manifest: Array[Dictionary]) -> Array[Dictionary]  # 依 source_id 字典序排序

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
# 執行機制三步驟 ①~⑤;回傳驗證通過的 payload Dictionary,或 SaveFormat.ReadRejection
```

**enum 轉換慣例**(適用於任何持久化 enum 欄位,所有擁有系統的 `to_dict()`/`from_dict()` 一致遵循,參見 ADR-0002 機制八):正向(enum → 字串)用 `EnumName.find_key(value)`;反向(字串 → enum)用 `EnumName[name_string]`,並以 `EnumName.values().has(...)` 風格檢查guard 非法字串輸入,對應查無此名稱時回傳 `MIGRATION_FAILED`(依 GDD Core Rules #10,需要一個顯式遷移函數處理改名/移除,不是 `DATA_CORRUPTED`)。

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

- **`TR-save-001`/`-002` 的格式決策一次性解決,且解法本身消解了 `-002` 的下游疑慀(Open Question 4)**——型別白名單不是靠維護清單實現,而是格式選擇的結構性副產品。
- **manifest-only 與完整讀取兩條路徑、以及 Core Rules #16 鎖定的讀取順序,在格式層面自然成立**,不需要額外的流程控制邏輯「假裝」某個檢查先發生——這降低了未來實作偏離 GDD 鎖定順序的風險(順序錯誤在這個設計下會直接對應「多解碼了一次不該解碼的區塊」這種容易在程式碼審查中發現的具體症狀,不是一個容易被忽略的抽象規則)。
- **雙層雜湊鏈的「操作原子性」要求天然滿足**——不需要額外的紀律要求提醒實作者「不要為了算雜湊而重新序列化」,因為機制二的資料流本就只序列化一次。
- **與 ADR-0002 的既有決策完全一致、互相驗證**:`AffinityDataPool` 選擇格式無關 `Dictionary` 而非 `Resource`,在本 ADR 選定二進位 Variant 序列化後被證明是正確的前瞻判斷,不需要任何回頭修改。
- **enum 字串化轉換慣例從單一系統的實作選擇提升為專案級介面義務**,降低未來新系統各自發明不同轉換方式(進而各自可能踩到同一個 `enum_value_positional_string_conversion` 陷阱)的風險。

### Negative

- **`AffinityDataPool` 需要一次小幅回填修訂**(新增 `validate_semantics()`,`import_state()` 內部重構)——雖然範圍小且 ADR-0002 仍是 Proposed 狀態,仍是一次跨 ADR 的邊界調整,增加了追蹤兩份 ADR 一致性的負擔。
- **`bytes_to_var(bytes)` 的安全失敗行為(Engine Compatibility Verification Required 第 2 項)目前僅為訓練資料推測,尚未經本專案實機驗證**——若實際行為不是「安全失敗」而是其他(例如拋出未分類例外、或部分解碼後回傳不完整結構),機制一的型別安全論證需要重新評估,可能需要在 `bytes_to_var()` 呼叫外再包一層防衛(例如額外的結構完整性檢查——GDScript 無例外機制,故防衛須以回傳值檢查實現)。
- **逐區塊獨立序列化增加了微量的序列化呼叫次數**(每個區塊一次 `var_to_bytes()`,而非整份存檔一次)——對本系統實際規模(數個區塊、每槽數十 KB)而言可忽略,但這是明確的、非零的取捨,不是零成本的設計。

### Risks

| 風險 | 緩解 |
|---|---|
| **`bytes_to_var(buffer)` 對惡意/損毀位元組的實際行為與訓練資料推測不符**(見 Verification Required 第 2 項) | 本 ADR 明文列為架構階段第一優先驗證項;若實機行為不同,機制三步驟 5 的失敗處置需要調整,但機制二/四(緩衝區分層、雙層雜湊)本身不受影響——雜湊驗證發生在解碼之前(機制三步驟 4 先於步驟 5),即使 `bytes_to_var()` 本身的失敗行為有出入,絕大多數損毀情境已在雜湊比對階段被攔截,不會抵達解碼呼叫 |
| **`Dictionary` 巢狀 `PackedByteArray` 透過 `var_to_bytes()`/`bytes_to_var()` 往返若有未預期的行為**(例如深度限制、巢狀 Variant 型別轉換損耗) | 列為 Verification Required 第 4 項;若證實有問題,備援方案是把 `blocks` 字典的值從「巢狀在同一個 `var_to_bytes()` 呼叫內」改為「manifest 只記錄各區塊的位元組長度與位移,個別區塊各自以獨立的 `var_to_bytes()` 呼叫產生緩衝區、由下一份 ADR 寫入檔案的對應位移」——這需要下一份 ADR(原子寫入)配合調整檔案佈局,但不改變本 ADR 機制一/四(格式選擇、雜湊機制)本身 |
| **超大 Delta Log(數百小時遊玩)下 `var_to_bytes()`/`bytes_to_var()` 或 SHA-256 計算是否有效能懸崖**(見 Verification Required 第 5 項與 GDD `migration_chain_load_time_budget_ms`) | GDD 自身估計單槽規模為數十 KB(5 名固定角色、10 對配對),遠低於任何已知的 `var_to_bytes`/`HashingContext` 效能疑慮門檻;若未來內容規模假設改變(例如角色數量政策翻轉),須重新評估,已在 GDD Tuning Knobs 標記為連動項目 |
| **`SaveBlockRegistry` 與各擁有系統的初始化時序**(若某系統忘記在讀取發生前呼叫 `register()`,該區塊會被誤判為「無驗證器宣告」而非「尚未初始化」) | 這是 fail-closed 設計的刻意結果,不是需要避免的缺陷——GDD 明文「未宣告視為錯誤」,一個忘記註冊驗證器的系統理應無法通過讀取,而非靜默略過語意檢查。具體的初始化順序保證(確保所有擁有系統在任何讀取發生前完成註冊)留待 `/create-architecture` 決定 |
| **外層 manifest 最終寫入磁碟時,若下一份 ADR 選擇直接呼叫 `FileAccess.store_var()` 而非 `store_buffer()` 寫入本 ADR 產生的最終位元組緩衝區**(2026-08-18 `godot-specialist` 驗證發現)——`store_var()` 自 4.4 起回傳型別為 `bool`(原為 `void`,見 `breaking-changes.md` 4.3→4.4 表格) | 下一份 ADR(原子寫入)設計 Core Rules #14 步驟 1「確保寫入成功」的具體實作時,若使用 `store_var()` 寫入,須檢查此 `bool` 回傳值以偵測寫入失敗,不可假設呼叫必然成功;此為本 ADR 與下一份 ADR 的介面交接提醒,不影響本 ADR 自身決策 |
| **`HashingContext` 三段式呼叫(`start`/`update`/`finish`)可能存在更簡潔的一次性便利方法**(例如 `PackedByteArray.sha256_buffer()`,`godot-specialist` 低信心度觀察,未經確認) | 不影響本 ADR 現行設計的正確性,純粹是潛在的實作簡化機會;`/create-architecture` 或實作階段可自行查證是否存在此方法並採用,採用與否不需要回頭修訂本 ADR(雜湊演算法本身、涵蓋範圍、固定順序等決策不受影響) |

## GDD Requirements Addressed

| TR-ID | 需求 | How This ADR Addresses It |
|---|---|---|
| TR-save-001 | 序列化格式未定案 | 選定 `var_to_bytes()`/`bytes_to_var(buffer)` 二進位 Variant 序列化(機制一),拒絕 Resource/JSON(Alternatives 1/2) |
| TR-save-002 | 型別白名單須在任何實例化之前完成閘控 | `allow_objects=false` 使白名單問題在引擎層級結構性消除,無自訂型別可被實例化(機制一);讀取順序上白名單解碼(機制三步驟 5)先於語意驗證/遷移(步驟 6) |
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
- `docs/registry/architecture.yaml` — 本 ADR 完成後將登記的新增立場(見下方 Registry 更新提案)。
- `docs/architecture/adr-0004-save-system-atomic-write-and-migration-execution-model.md`(2026-08-18 新增)——消費本 ADR 定義的位元組緩衝區與雜湊機制。**`TR-save-*` 30 項的權威涵蓋數字為 22 完整 / 7 部分 / 1 缺口**(`TR-save-030` 雲端存檔同步;2026-08-18 第二輪 `/architecture-review` 獨立推導,2026-08-20 第七輪重推維持同數)。⚠️ **2026-08-21 修正**:本行原寫「`TR-save-*` 系列至此三份 ADR **全數覆蓋**」——這是同一句過度宣稱的**第五處**,且是**唯一不在 ADR-0004 檔案內**的一處。第五輪 `/architecture-review` 曾核實並宣稱「該過度宣稱至此四處全數清除」,但**那四處指的全是 ADR-0004 自己文件內的**,從未檢查本 ADR 的 `Related Decisions` 有沒有同一句話——**「四處全數清除」這個全稱宣稱本身的定義域小於它的措辭**,這正是本專案反覆出現的失敗形狀。由 2026-08-21 ADR-0004 事實層修訂的 Step 5.5 覆核抓出。
