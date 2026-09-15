# Story S-002:`AffinityRecord` 五欄記錄 + `AffinityRecordList` 包裝層

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Logic
> **狀態**:📋 Ready
> **估時**:M
> **依賴**:S-001

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` Core Rules #1(資料結構,五欄定義)、共用符號表
- **Governing ADR**:ADR-0002(**Accepted**)—— 機制二(Delta Log 儲存)全段
- **Engine**:Godot 4.7.1

## 目標

建立 Delta Log 單筆記錄的型別(`AffinityRecord`)與繞過 GDScript 不支援巢狀型別容器限制的包裝層(`AffinityRecordList`)。做完之後,「一筆好感度變化」第一次有一個可 `new()`、可型別檢查、可安全依索引存取的具體類別——這是 S-004(池骨架)賴以建構 `_records: Dictionary[Pair, AffinityRecordList]` 的磚塊。

## 🔴 本 story 決定的原始碼目錄路徑

沿用 S-001 的決定:`src/gameplay/affinity_pool/`。本 story 新增 `affinity_record.gd`、`affinity_record_list.gd` 兩個檔案於此目錄。

## Implementation Notes

出自 ADR-0002 機制二:

1. **`AffinityRecord`(`RefCounted` 基底,5 個型別化欄位)**:

   ```gdscript
   class_name AffinityRecord extends RefCounted
   var pair: AffinityTypes.Pair
   var m: float       # 帶號幅度,非零有限浮點數
   var t: int          # 全域好感度寫入計數器值,寫入時指派,≥1
   var c: int          # 戰役刻度計數器值,寫入當下的現值,≥0
   var source: AffinityTypes.Source
   ```

   本 story 只交付欄位本身(直接回應 `TR-affinity-001` 對「須用具型別類別而非 `Array[Dictionary]`」的要求)。`to_dict()`/`from_dict()` 序列化方法屬 S-013(持久化,切片外),本 story **不實作**這兩個方法——但欄位必須與 ADR-0002 機制八的欄位表(`pair`/`m`/`t`/`c`/`source` 恰 5 個)完全一致,避免 S-013 落地時發現欄位對不上。
2. 🔴 **`AffinityRecordList` —— 繞過 GDScript 不支援巢狀型別容器的包裝層(2026-08-20 BLOCKING 修訂,實機驗證)**:ADR-0002 初版把 per-pair 儲存寫成 `Dictionary[Pair, Array[AffinityRecord]]`,在 Godot 4.7.1 **實機測出無法編譯**(`Parse Error: Nested typed collections are not supported`,class member/函式參數/回傳型別三種語法形狀皆同)。本 story 直接照 ADR-0002 已定案的替代方案實作,**不重新踩這個坑**:

   ```gdscript
   class_name AffinityRecordList extends RefCounted
   var _items: Array[AffinityRecord] = []      # 私有,唯一寫入路徑是 append()

   func append(record: AffinityRecord) -> void: ...
   func size() -> int: ...
   func get_at(index: int) -> AffinityRecord: ...   # 越界不中止,回傳 null(見下方)
   ```

   **不提供任何回傳 `_items` 本身的方法**——已登記禁令 `wholesale_reassignment_of_affinity_record_list_items`。
3. 🔴 **`get_at()` 契約(2026-08-25 修訂,VR#11 關閉)——越界不中止,回傳 `null`**:型別化 `Array` 的 `[]` subscript 對越界索引**中止呼叫函式**(已實測)。`get_at()` 必須**自行邊界檢查**,不依賴 `.get()` 或 `[]` 對負索引的原生語意:

   ```gdscript
   func get_at(index: int) -> AffinityRecord:
       if index < 0 or index >= _items.size():
           return null
       return _items[index]
   ```

   **不沿用引擎對負索引的原生行為**(非空陣列 `-1` 取最後一筆、空陣列則中止——這種「行為隨陣列當下狀態而變」的語意不得暴露給呼叫端)。**呼叫端義務**:所有呼叫端必須檢查 `get_at()` 回傳值是否為 `null`,不得假設索引一定落在合法範圍(此義務已登記進 `docs/architecture/control-manifest.md`)。
4. **誠實聲明,不可省略(ADR-0002 原文)**:GDScript 沒有真正的私有成員,`_items` 的底線前綴是命名慣例、不是語言層強制。本 story **不宣稱**這是結構保證——相對公開 `items` 的收益是:唯一被許可的寫入路徑收斂為 `append(record: AffinityRecord)` 這個型別化簽章,任何對 `_items` 的整體賦值都是明顯的慣例違反。
5. 🔴 **內層元素型別不經 subscript 推斷路徑**:已實測「未型別化字面量經 subscript 賦值存入型別化 `Dictionary`/`Array` 的值槽後讀回,`is_typed()` 為 `false`」——`AffinityRecordList` 的內層型別必須由 `var _items: Array[AffinityRecord] = []` 的宣告式初始化 + `append()` 的型別化參數簽章共同保證,**不得**以任何 subscript 賦值路徑寫入 `_items`。
6. **不可用 `get_class()` 做型別斷言**:`get_class()` 回傳原生類別,任何 `RefCounted` 子類都印 `RefCounted`,無法區辨 `AffinityRecordList` 與其他包裝類別。斷言型別須用 `script.get_global_name()` 或 `is AffinityRecordList`。
7. 🔴 **陷阱四(EPIC.md)——本 story 新增兩個 `class_name`**(`AffinityRecord`、`AffinityRecordList`),與 S-001 的 `AffinityTypes` 合計三個。若工作副本尚未在 S-001 落地時 import 過,務必先跑 `godot --headless --path . --import`。
8. **文件註解**:兩個類別的全部公開方法(`append`/`size`/`get_at`)須有 `##` 文件註解。

## Acceptance Criteria

🔴 **本 story 的 GDD AC 歸屬為 0——但零 AC 不等於沒有驗收標準。**

EPIC.md 已登記:`AffinityRecord`/`AffinityRecordList` 是 **ADR 層構造**,不是 GDD 規則,驗收依據是 **ADR-0002 Validation Criteria 第 11 項**,而非本系統 GDD 的任一條 AC。原文轉錄如下(出自 `docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md` 的 `## Validation Criteria` 節,**非本系統 GDD**):

> 11. **`AffinityRecordList` 包裝層的編譯驗證**(2026-08-20 新增):實作第一天即在真機編譯 `var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList]` 的宣告,確認不再出現 `Nested typed collections are not supported`;並斷言兩層型別皆保住 —— **2026-08-21 隨 `_items` 私有化改寫**:(a) `_records[pair] is AffinityRecordList`;(b) **先 `append()` 一筆記錄後**再斷言 `_records[pair].get_at(0) is AffinityRecord`(以元素型別實證第二層);(c) `AffinityRecordList` 自身的單元測試斷言其內層陣列 `is_typed() == true`。⚠️ **(b) 必須先 `append()`** —— 型別化 `Array` 對**越界索引**的讀取行為**零探針覆蓋**(見 VR #11),**不得沿用探針 A 對 `Dictionary` 缺鍵的結論**(不同容器、不同操作)。**不可用 `get_class()` 做這項斷言**——它回傳原生類別,任何 `RefCounted` 子類都印 `RefCounted`;應用 `script.get_global_name()` 或 `is AffinityRecordList`。
>
> **Validation Criteria 11(b) 需同步擴充**:原「先 `append()` 一筆記錄後再斷言 `_records[pair].get_at(0) is AffinityRecord`」方向不變;**新增**:對空 list 呼叫 `get_at(0)`、對非空 list 呼叫 `get_at(-1)`/`get_at(size())`,斷言三者皆乾淨回傳 `null`、不中止。

⚠️ **本 story 尚無 `_records: Dictionary[Pair, AffinityRecordList]` 這個容器本身**(那是 S-004 的產物)——本 story 只能驗證 `AffinityRecordList` 自身的行為(VC-11 的 (b)(c) 兩項與擴充項),VC-11(a)(`_records[pair] is AffinityRecordList`)須等 S-004 落地後才可執行,本 story 不宣稱涵蓋它。

## Test Evidence

**型別**:Logic
**測試檔**(獨立單一檔):`tests/unit/gameplay/affinity_pool/affinity_record_list_test.gd`

預期涵蓋:

- `test_append_and_size_reflect_record_count`
- `test_internal_array_is_typed`(VC-11c)
- `test_get_at_returns_appended_record_with_correct_type`(VC-11b 前半,`is AffinityRecord`,**不得**用 `get_class()`)
- `test_get_at_out_of_bounds_on_empty_list_returns_null`(VC-11b 擴充)
- `test_get_at_negative_index_on_non_empty_list_returns_null`(VC-11b 擴充,`get_at(-1)`)
- `test_get_at_index_equal_to_size_returns_null`(VC-11b 擴充,`get_at(size())`)
- `test_append_does_not_expose_internal_array_reference`(佐證 `wholesale_reassignment_of_affinity_record_list_items` 禁令的動機,非硬性斷言結構保證)

## Out of Scope

- **`to_dict()`/`from_dict()` 序列化**——屬 S-013(切片外)。
- **`Dictionary[Pair, AffinityRecordList]` 容器本身與 VC-11(a)**——屬 S-004。
- **`RecordFieldCheck`/`check_record_fields()`**(ADR-0002 機制八之二,供 `from_dict()`/`validate_semantics()` 共用的欄位合法性檢查)——屬 S-013,本 story 不預先實作。
