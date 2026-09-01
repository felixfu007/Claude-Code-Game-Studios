# ADR-0004: 存檔系統原子寫入與遷移執行模型

## Status

**Proposed**

> **2026-08-19 修訂(銜接缺口 C1/C6 + 一處殘留過度宣稱,不改動任何機制決策)**:**C1** —— 本 ADR 接下 `TOKEN_TIMEOUT_MS` 的定值責任(機制六新增「C1 銜接缺口」段落,定死推導規則而非具體毫秒數;新增 Validation Criteria 第 7 項的版本連動測試)。此前本 ADR 與 ADR-0002 各自把它推給對方,連續三輪 `/architecture-review` 判為**孤兒義務**。**C6** —— `Related Decisions` 新增回指 ADR-0005 機制十一並明文寫出義務歸屬(游標交接義務歸呼叫方,不歸存檔系統),避免本 ADR 在被單方面宣稱交接的狀態下逕行 `Accepted`。**另修正**:`Related Decisions` 最後一行殘留「`TR-save-*` 至此全數覆蓋」——那是第二輪 `/architecture-review` 推翻的過度宣稱在本檔案的**第四處**,`1c3d5d0` 只改了第 27/421 兩行,漏改此處;現已改為與其一致的「22 完整 / 7 部分 / 1 缺口」。**三項皆為擁有權與措辭修正,未新增、未移除、未改變任何機制、介面或檔案格式決策。**

## Date

2026-08-18(初版) / 2026-08-19(C1/C6 銜接缺口修訂 + 殘留過度宣稱更正)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core(檔案 I/O、並發、狀態機) |
| **Knowledge Risk** | HIGH——本 ADR 的正確性直接倚賴 `DirAccess.rename()`/`remove()`、`FileAccess` 的寫入/flush 錯誤偵測能力、`await get_tree().process_frame` 跨幀語意等多組 API 的精確行為,`breaking-changes.md` 未列出這些 API 在 4.4→4.7 之間的異動,但 GDD 自身(Open Question 7/12/13/14/15)已明文列出多項待驗證項目,顯示 GDD 作者群本身也不確定 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`breaking-changes.md`、`deprecated-apis.md`、`current-best-practices.md`;`docs/architecture/adr-0001-tactical-query-atomicity-contract.md`(跨幀 `await` 生命週期約束的既有先例) |
| **Post-Cutoff APIs Used** | 無已知——`FileAccess`/`DirAccess`/`await get_tree().process_frame`/`@abstract` 皆為 4.5 前既有穩定機制,`deprecated-apis.md` 未列出任何相關廢棄項 |
| **Verification Required** | (1) `FileAccess.flush()` 是否提供可檢查的失敗訊號——**`store_buffer()` 的 `bool` 回傳值已由 `breaking-changes.md` 4.3→4.4 表格明文確認**(該表逐名列出 `store_buffer` 在回傳型別異動清單內),此半已解決,不再視為待驗證;**仍待驗證的僅剩 `flush()` 本身**(傾向無直接回傳值,若無則須改用 `FileAccess.get_error()` 累積錯誤狀態間接判定——但 `get_error()` 回傳的是**累積**錯誤狀態,無法區分「`flush()` 本身失敗」與「前一次 `store_buffer()` 呼叫已設下錯誤狀態」,只是一個較粗粒度的訊號,見 Risks);(2) `DirAccess.rename()` 對「目的檔案已存在」情境的實際行為(部分平台 `rename()` 若目的已存在會失敗,這正是 Core Rules #14 Step 4a 存在的理由,但確切在 4.7.1/各平台上的行為未經本專案驗證——`godot-specialist` 2026-08-18 查核:靜態便利方法可能是 `DirAccess.rename_absolute(from, to) -> Error`/`DirAccess.remove_absolute(path) -> Error`,回傳 `Error` 列舉而非 `bool`,**中高信心度、未實機驗證**,具體方法名稱待 `/create-architecture` 確認);(3) `OS.get_thread_caller_id()`/`OS.get_main_thread_id()` 是否為 4.7.1 正確 API 名稱(GDD Open Question 12 明文標記,`design/gdd/reviews/save-system-review-log.md` 已記載為待查證項,`godot-specialist` 2026-08-18 查核仍無新解──供 Core Rules #15 主執行緒斷言使用);(4) GDScript 是否有 fsync/`FlushFileBuffers` 等效的硬體層級落盤機制(GDD Open Question 14 明文標記,關係到耐久性範圍聲明,傾向無,可能需要 GDExtension);(5) `await get_tree().process_frame` 在本 ADR 的分步遷移情境下,跨幀恢復點的行為是否與 ADR-0001 已驗證的假設一致(`godot-specialist` 2026-08-18 高信心度確認:`await` 機制本身與宿主是否為 `Node`/`RefCounted` 無關,`SceneTree.process_frame` 為穩定訊號名稱,同一份訓練資料來源,但分步遷移可能跨越比 ADR-0001 更多幀,建議獨立煙霧測試);(6) **已查證並關閉(2026-08-21,`prototypes/xcheck-round7-2026-08-20/`,見 `logs/probeE-unfiltered.txt`)**:`@abstract` 方法宣告的正確語法是**裸簽章**(`@abstract func f() -> T`,無冒號、無主體);冒號 + `pass` 主體是 `Parse Error: An abstract function cannot have a body.`,會擋下整個檔案。裸簽章已對 **8 種**回傳型別各自實測成立、每種皆有獨立的 `[COMPILED OK]` 證據行(`Array[T]`/`bool`/`float`/`void`/`Vector2` 於 2026-08-20 批次 `engine-verification-spike-2026-08-20`;`Variant`/`String`/`PackedByteArray` 於 2026-08-21 探針 E),**且機制一那整段的完整組合已逐字編譯通過**(混合 `bool`×4 + `Variant`×1、`@abstract` 標記與 `class_name`/`extends` 同檔)——後者才是本項真正要關的東西,各回傳型別分別通過並不等於該組合通過。⚠️ **本項在 2026-08-21 之前是三處自相矛盾**:本欄宣稱程式碼區塊採裸簽章,但機制一的指示句與實際程式碼都是冒號 + `pass`;且本欄末尾 `見下方機制一修訂與 Risks` 之中 **Risks 半邊是懸空指標**(Risks 表逐列核對,從無 `@abstract` 列),已一併刪除該指標(機制一半邊的交叉引用未遺失——機制一的新語法段落與本項互相點名)。修法方向恰與實測結果一致,故本次是往正確方向收斂,但**這個矛盾能長期存在而無人發現,本身就是本專案「散文改了、結構化欄位沒跟上」這個慣性缺陷的又一次實例**。原文如下(保留供追溯):`@abstract` 方法宣告的確切語法(機制一程式碼區塊採「無冒號、無函式主體」的裸簽章形式,但本專案唯一已查證的 `@abstract` 範例——`current-best-practices.md`——採「冒號 + `pass` 主體」形式,兩者互斥,`godot-specialist` 2026-08-18 查核無法在本環境確認何者正確;若寫錯屬編譯期錯誤,會擋下整個 `save_io_backend.gd`);(6a) **已查證並關閉(2026-08-20 批次 + 2026-08-21 探針 E)**:具體子類別漏實作某個抽象方法是**編譯期**錯誤。實測訊息格式為 `Parse Error: Class "X.gd" must implement "Base.method_name()" and other inherited abstract methods or be marked as "@abstract".` —— ⚠️ **注意它只指名其中一個方法**,其餘以「and other inherited abstract methods」概括,**不逐一列舉**;修完被指名的那一個之後可能還要再編譯一次才會看到下一個。另已實測:完整實作全部五個方法的具體子類別可正常編譯、可 `.new()` 實例化,`-> Variant` 的多型覆寫在執行期兩個分支(回 `PackedByteArray`(typeof=29)/ 回 `null`(typeof=0))皆正常,**包含透過靜態型別為抽象基底的參數做多型呼叫**(`read_via_base_type(backend: SaveIOBackend, ...)`,兩分支結果一致)——這是機制一「上層只持有 `SaveIOBackend` 型別參照」的執行期前提,本項連帶關閉。原文如下(保留供追溯):`@abstract` 類別若某具體子類別漏實作某個抽象方法,是否為編譯期錯誤或僅在該方法被呼叫時才於執行期顯現;(6b) **新增,未查證** —— `@abstract` 類別經**間接路徑**構造是否同樣被擋:`Object.new()` 後 `set_script()`、`load("save_io_backend.gd").new()`(呼叫端持有 `Script` 資源變數,parser 未必能靜態推斷)、`ClassDB`/`ResourceLoader` 間接實例化。**已查證的只有文字上直接 `ClassName.new()`**(編譯期 Parse Error);三條間接路徑**既無實測證據亦無反證**,故機制一的編譯期保證宣稱明文限定在直接構造這一條路徑上。**低優先**——會被實作者誤寫的形狀是直接構造,那條已關閉;本項只影響能否把宣稱擴寫為「不可能被實例化」。探針成本已證實極低,可併入下一批 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md`(消費其 `SaveFormat` 位元組緩衝區、`ReadRejection` 列舉——本 ADR 擴充該列舉新增 `MIGRATION_FAILED`/`SEMANTIC_VALIDATION_FAILED`——以及 `SaveBlockRegistry` 驗證器登記表);`docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md`(消費其權杖式序列化生命週期介面 `begin_non_atomic_window()`/`end_non_atomic_window()`) |
| **Enables** | 存檔系統相關 story 的完整實作(`/create-stories`/`/dev-story`)——`TR-save-*` 30 項需求至此為 **22 項完整涵蓋、7 項部分涵蓋、1 項缺口**(`TR-save-030` 雲端同步;2026-08-18 第二輪 `/architecture-review` 獨立推導,本欄原宣稱「全數有 ADR 覆蓋」不成立);好感度視覺呈現 UI / 未來存檔管理 UI 的設計(消費本 ADR 定義的結構化結果型別與可觀測性介面) |
| **Blocks** | 任何觸及實際存檔讀寫、遷移鏈執行、跨系統生命週期通知消費的 story |
| **Ordering Note** | 本 ADR 是 `TR-save-*` 系列的最後一份、也是最複雜的一份——依賴前兩份 ADR 的位元組格式與資料結構決策,把 `save-system.md` Core Rules #4~#16 的並發/狀態機/檔案 I/O 義務對應到具體實作。GDD Open Question 9(一般寫入的同步阻塞模型是否在確認的主機平台上仍成立)在本 ADR 內**維持現行 GDD 決策(同步阻塞)但包一層可替換抽象**(見機制一)——不等待具體主機 SDK 確認,理由與範圍見機制一 |

## Context

### Problem Statement

`save-system.md`(Foundation 層,已 Approved,15 輪 `/design-review`)在架構層的最後一塊拼圖:序列化格式與型別安全已由 ADR-0003 定案,但**如何把位元組緩衝區安全地寫進磁碟、如何執行版本躍遷、如何在整個過程中不遺失玩家資料**——這是 GDD 本身投入最多輪次對抗性覆核(security-engineer 多次介入)、規則密度最高的部分:六步驟跨平台原子置換序列、分步執行的遷移狀態機、跨系統(好感度數值池)的權杖式生命週期通知、逐槽重入不變量、四條自動痊癒路徑。這些規則彼此高度耦合(Core Rules #16 的交互矩陣有超過 15 條跨規則約束),任何一處實作偏離都可能重現 GDD 自陳的「靜默資料遺失」——本文件家族最昂貴的失敗類別。本 ADR 的存在理由,是把這套規則對應到具體的 Godot 檔案 I/O 呼叫、狀態機結構與跨系統呼叫時機,讓下游實作有一份逐步驟可依循、且與 GDD 逐條對應的架構藍圖。

### Constraints

- **GDD 已鎖定、不受本 ADR 裁量的核心序列**(Core Rules #14):跨平台原子置換的六個步驟(Step 0 分支邏輯、1、2、3、4a、4)已經是 GDD 層級定案的具體演算法,不是留給架構階段自由裁量的高層次原則——本 ADR 的角色是把這個已定案的序列翻譯成 Godot API 呼叫,不是重新設計它。
- **無例外處理機制**:GDScript 沒有 try/catch/finally——本 ADR 對「無條件釋放」「單一結束出口」等 GDD 要求(見機制四)必須靠函式結構本身(單一釋放點、進入後不提前 return)實現,不能依賴語言層級的例外安全機制。
- **威脅模型範圍聲明**(承 ADR-0003):防護意外損毀,非反作弊。
- **ADR-0002/0003 已建立的先例**:DI 優於 Autoload(ADR-0002 機制一已直接建立此慣例)、跨幀 `await` 需要宿主生命週期涵蓋整個操作(ADR-0001 已驗證的約束)。**`@abstract` 基底類別是本 ADR 首次在本專案 ADR 系列中實際採用**(2026-08-18 `godot-specialist` 驗證修訂,原稿誤稱此為 ADR-0002/0003 已建立的先例——查核後確認 ADR-0001/0002/0003 皆未使用或驗證過 `@abstract`,唯一依據是 `docs/engine-reference/godot/current-best-practices.md` 的獨立範例片段,尚未經任何本專案 ADR 審查驗證)。**⚠️ 2026-08-21 更新**:那個範例後來被證實**寫錯**(冒號 + `pass` 主體),已於 2026-08-20 第七輪修正;本 ADR 據它寫下的 5 處 `pass` 主體同日刪除。`@abstract` 現已由兩批探針實機驗證——8 種回傳型別、機制一完整組合的逐字編譯、具體子類別的多型執行期行為、以及抽象基底的直接構造為編譯期錯誤——**不再是本專案 ADR 系列中未經驗證的賭注**。這是本 ADR 相對 2026-08-18 原稿最重要的一項事實層變化:當時它是唯一押在一份未經審查的範例片段上的語法決定,而那個賭注**押錯了**。
- **確認的目標平台**:PC、Console(`.claude/docs/technical-preferences.md`),但未指定具體主機型號/SDK——本 ADR 不得假設任何具體主機 SaveData API 的細節,只能對「若同步阻塞模型不成立」這個可能性做結構性準備(見機制一),不能替换成一個未經任何主機平台驗證的非同步設計。

### Requirements

本 ADR 須同時滿足 `save-system.md` 的下列義務群組(完整逐項對應見下方 GDD Requirements Addressed):

1. **一般寫入模型**(Core Rules #4):同步阻塞、單執行緒假設,但須為未來可能的翻轉留出可替換的介面邊界。
2. **多檔案佈局**(Edge Cases、Core Rules #13/#14):`slot_N.dat`/`.tmp`/`.bak`/`.prev.bak`/`.pre_migration.bak` 五種檔案,精確檔名比對,同檔案系統。
3. **跨平台原子置換**(Core Rules #14):六步驟序列,每一步的成功須被實際檢查,任一步失敗立即中止。
4. **分步遷移執行模型**(Core Rules #5):遷移鏈每次只執行一個版本躍遷,步與步之間讓出控制權;同槽重入拒絕;僅限指定的非互動式載入過場情境觸發。
5. **序列化生命週期權杖消費**(Core Rules #5、跨 `affinity-data-pool.md` Core Rules #6):分步遷移前呼叫 `begin`,依四條終止路徑之一呼叫對應的 `end`。
6. **兩階段回寫與備份策略**(Core Rules #13):Phase A 創世存底(僅首次)、Phase B 標準原子置換;四條自動痊癒路徑。
7. **結構化結果與拒絕代碼**(Core Rules #6、#10):擴充 ADR-0003 的 `ReadRejection`,新增執行模型相關的非錯誤結果(槽處理中、待遷移未嘗試、回寫 I/O 失敗待重試)。
8. **可觀測性介面分類**(Core Rules #15):診斷介面(4 項)與生產介面(2 項)的明確區分,含重入豁免矩陣。
9. **重複回寫失敗與唯讀存取管道**(Core Rules #5 R7 段落):逐槽獨立計數,達門檻後擴大唯讀存取管道可用條件。

## Decision

採用**可替換 I/O 後端抽象**(現行實作為同步阻塞)承載 Core Rules #14 的六步驟原子置換序列,搭配**跨幀讓出的分步遷移狀態機**、**單一結束出口的逐槽重入旗標**,以及**擴充自 ADR-0003 的統一結果型別**。

### 核心洞見:GDD 已經把最難的部分定案,本 ADR 的責任是不在翻譯過程中弄丟任何一個分支

Core Rules #14 的六步驟序列與 Core Rules #5 的四條終止路徑,都已經是 GDD 十幾輪對抗性審查收斂出的具體演算法,不是留給架構階段重新設計的空間。security-engineer 在 GDD 審查過程中至少三次抓到「同一個規則在傳播到其他章節時遺漏了某個分支」(R13 的 Step 0 單一歸因錯誤、四條終止路徑一度誤植為三條)——這是一個具體的、已經在 GDD 自己內部發生過的失敗模式,本 ADR 的實作結構因此優先考慮**降低分支被遺漏的風險**,而非只求邏輯上等價的最簡潔寫法:每個 GDD 明文列舉的分支(六個步驟、四條終止路徑、四條自動痊癒路徑)在本 ADR 的程式碼結構中都有一個直接對應、可以逐項核對的具體位置,不把多個分支合併成一個「等價」但難以逐條核對的通用邏輯。

### 機制一:可替換 I/O 後端抽象(現行實作:同步阻塞)

> **語法(2026-08-21 已實機驗證,取代原本的「語法提醒」)**:以下為概念契約,`@abstract` 方法宣告採**裸簽章**形式(無冒號、無函式主體)——這是 Godot 4.7.1 唯一合法的寫法;`@abstract func f() -> T: pass` 是 `Parse Error: An abstract function cannot have a body.`,會擋下整個 `save_io_backend.gd`。**下方這整段組合已由探針 `prototypes/xcheck-round7-2026-08-20/scripts/e3_save_io_backend.gd` 逐字編譯通過**(`bool`×4 + `Variant`×1、`@abstract` 標記與 `class_name`/`extends` 同檔、行尾註解保留),不只是各回傳型別分別通過,見 Engine Compatibility Verification Required 第 6 項。
>
> ⚠️ **本段原本明文指示「採用 `docs/engine-reference/godot/current-best-practices.md` 唯一已查證範例的形式(冒號 + `pass` 主體)」——那個範例本身是錯的**(已於 2026-08-20 第七輪連同一段更正註記修正)。依它寫下的 5 處 `pass` 主體已於 2026-08-21 全部刪除。**根因的指示句與症狀必須同時改**:只刪 `pass` 而留下這句話,下一個實作者會照著把它加回來。

```gdscript
# ─── save_io_backend.gd ──────────────────────────────────────
@abstract
class_name SaveIOBackend extends RefCounted

@abstract
func write_temp(path: String, buffer: PackedByteArray) -> bool   # Core Rules #14 Step 1
@abstract
func rename_file(from_path: String, to_path: String) -> bool     # Step 2/3/4
@abstract
func delete_file(path: String) -> bool                            # Step 4a
@abstract
func file_exists(path: String) -> bool
@abstract
func read_file(path: String) -> Variant                           # PackedByteArray 或 null(不存在/讀取失敗)

# ─── sync_blocking_save_io_backend.gd ────────────────────────
class_name SyncBlockingSaveIOBackend extends SaveIOBackend
# 現行實作:呼叫執行緒等待每一步完成才返回。內部使用 FileAccess/DirAccess
# (`DirAccess.rename_absolute()`/`remove_absolute()` 回傳 `Error` 列舉——確切方法名稱
# 待驗證,見 Engine Compatibility 第 2 項),見機制三的六步驟序列。
#
# write_temp() 底層一律使用 `FileAccess.store_buffer()`,不用 `store_var()`
# (2026-08-18 第二輪 /architecture-review 補上此拍板,原為 ADR-0003/0004 之間的銜接空白 C4):
#   (a) 輸入已是 ADR-0003 機制二產出的 PackedByteArray,再過一層 Variant 編碼是多餘的;
#   (b) `store_buffer()` 自 4.4 起回傳 `bool` 已由 breaking-changes.md 4.3→4.4 表格逐名
#       明文確認——這是本專案少數已查證(而非訓練資料印象)的引擎事實,正好滿足機制三
#       「每一步驟的成功與否須被實際檢查」的前提,不必倚賴任何待驗證假設。
#   ADR-0003 的 Risks 表原已提醒「若呼叫 store_var()/store_buffer() 須檢查 bool 回傳值」,
#   但兩份 ADR 先前都沒有真正拍板用哪一個;此處正式定案。
```

**`SaveIOBackend` 不可能被誤寫成具體類別來實例化,這是編譯期保證而非紀律要求**(2026-08-21 探針 E 額外發現,見 `prototypes/xcheck-round7-2026-08-20/logs/probeE-unfiltered.txt`):對 `@abstract` 類別以**文字上直接的 `ClassName.new()`** 形式構造,是 `Parse Error: Cannot construct abstract class "SaveIOBackend"` —— **編譯期**,不是執行期。因此「上層邏輯只能持有具體後端實例、絕不能自己 `new` 一個抽象基底」不需要靠程式碼審查維持:寫錯的檔案根本編譯不過,**連寫在一條永遠不會執行到的分支上也一樣**(探針的加碼檔就是因為含一行 `SaveIOBackend.new()` 而整檔編譯失敗,被逐檔編譯檢查擋在任何呼叫之前)。

> ⚠️ **本宣稱的範圍界線(2026-08-21 Step 5.5 覆核要求收窄)**:上述已驗證的只有**文字上直接 `ClassName.new()`** 這一條構造路徑 —— parser 之所以能擋,正是因為它靜態看得見那個類名是 `@abstract`。**以下間接路徑本專案尚未查證,不在本宣稱涵蓋範圍內**:`Object.new()` 後 `set_script()`(腳本關聯是執行期賦值,不是文字上的 `ClassName.new()`)、`load("save_io_backend.gd").new()`(呼叫端持有的是 `Script` 資源變數,parser 未必能靜態推斷該腳本是抽象)、`ClassDB`/`ResourceLoader` 間接實例化。三者**既無實測證據支撐、亦無反證**,已列入 Verification Required 第 6b 項。這條界線對本 ADR 的實務影響很小(會被實作者誤寫的形狀就是 `SaveIOBackend.new()`,而那條已關閉),但**不可把本段擴讀成「不可能被實例化」** —— 那超出已驗證範圍。
>
> 對照:ADR-0002 明文承認 `AffinityRecordList` 的欄位私有化**只是紀律**(GDScript 無真正的私有成員)。兩者不同級,不可混用同一套論述強度。連帶事實:`is_abstract` 會被序列化進 `.godot/global_script_class_cache.cfg` 的結構化欄位,不只是 parse 階段的暫時旗標。

**決策**:延續 GDD Core Rules #4 的現行(provisional)決定——一般寫入為同步阻塞、單執行緒假設。**但**上層邏輯(機制三/四/五/六)一律透過 `SaveIOBackend` 抽象存取檔案系統,不直接呼叫 `FileAccess`/`DirAccess`。**理由**:GDD Open Question 9 明文要求在 `/create-architecture` 開始前確認同步阻塞模型在**已確認的目標主機平台**(`.claude/docs/technical-preferences.md`:PC、Console)上是否成立,但本 ADR 撰寫時專案文件未指定具體主機型號/SDK,無法實際驗證。本 ADR 不假裝這個驗證已經完成,也不在缺乏具體平台資訊的情況下貿然改用一個未經任何主機平台驗證的非同步設計(那同樣是缺乏依據的猜測,只是猜測的方向不同)。可替換的 `SaveIOBackend` 邊界讓這個懸而未決的驗證項目,將來只需要新增一個 `AsyncSaveIOBackend`(方法簽章可能需要改為回傳 `Signal`/接受 `Callable` 回呼,屆時另需修訂本 ADR)實作,不需要重寫機制三以上的任何邏輯——上層的六步驟序列、分步遷移狀態機、權杖消費時機皆與 I/O 是否同步無關,只依賴「每一步驟的成功與否可以被檢查」這個更弱的前提。

**此決策不解決 GDD Open Question 9,只是把它的影響面縮小到一個檔案**(`sync_blocking_save_io_backend.gd`)——實際驗證仍須在 `/create-architecture` 階段、取得具體主機平台資訊後完成。

### 機制二:檔案佈局與命名慣例

```
user://saves/slot_{N}.dat            # 現行有效內容
user://saves/slot_{N}.tmp            # Step 1 暫存檔(短暫存在,寫入進行中)
user://saves/slot_{N}.bak            # Step 2~4 之間的過渡備份(短暫存在)
user://saves/slot_{N}.prev.bak       # Core Rules #14 Step 4 滾動備份(永久存在,每次一般寫入後更新)
user://saves/slot_{N}.pre_migration.bak  # Core Rules #13 創世存底(僅首次遷移時建立,此後永不覆寫)
```

**理由**:GDD Edge Cases 明文要求「精確檔名比對,不得用萬用字元/前綴比對」(TR-save-017)——五個檔案雖然共享 `slot_{N}` 前綴與 `.bak` 尾綴的相似命名,語意與生命週期完全不同(見上方註解),本 ADR 的命名慣例刻意選擇容易在程式碼審查中人工核對「這個字串常數究竟指哪一個檔案」,不依賴任何動態組字串邏輯以外的比對。`user://` 目錄與所有檔案位於同一檔案系統(GDD Open Question 15 要求明文化的隱含假設),本 ADR 在此正式定案為硬性設定要求,不留給實作階段自由選擇存檔位置。

### 機制三:跨平台原子置換序列(Core Rules #14 六步驟)

```gdscript
# ─── atomic_replace.gd ───────────────────────────────────────
class_name AtomicReplace extends RefCounted

var _io: SaveIOBackend

func _init(io: SaveIOBackend) -> void

enum WriteFailure { NONE, STEP0_FAILED, STEP1_FAILED, STEP2_FAILED, STEP3_FAILED, STEP4A_FAILED, STEP4_FAILED }

func replace(slot: int, buffer: PackedByteArray) -> WriteFailure
```

`replace()` 內部依序執行,**每一步驟的成功與否皆由 `_io` 的回傳值實際檢查,任一步失敗立即回傳對應的 `WriteFailure`、不進入下一步驟**:

- **Step 0(寫入前置檢查,分支邏輯)**:若 `slot_N.bak` 存在,依 `slot_N.dat` 是否存在分支——
  - **分支 A(`.dat` 存在)**:中斷發生於上次寫入 Step 3 之後——先完成上次寫入的未竟步驟(若 `.prev.bak` 也存在,依 Step 4a 刪除;再執行 Step 4 的重新命名),再開始本次寫入的 Step 1。
  - **分支 B(`.dat` 不存在)**:中斷發生於 Step 2 與 Step 3 之間——`.bak` 是該槽**唯一有效內容**。**不得**執行 4a、**不得**執行 Step 4、**不得**碰觸 `.prev.bak`;補救動作是把 `slot_N.bak` 重新命名回 `slot_N.dat`,回到正常起始點,再開始本次寫入的 Step 1。
  - 若 `.bak` 不存在,Step 0 無事可做,直接進入 Step 1。
- **Step 1**:寫入暫存檔 `slot_N.tmp`,確保完整寫入 + flush(見 Verification Required 第 1 項——`_io.write_temp()` 的回傳值須反映此步驟的完整檢查結果,不只是「呼叫是否成功送出」)。
- **Step 2**:若目標槽已有現存有效檔案(`slot_N.dat`),重新命名為 `slot_N.bak`(重新命名,非刪除)。
- **Step 3**:將暫存檔重新命名為目標檔名(`slot_N.dat`)。
- **Step 4a**:若 `slot_N.prev.bak` 已存在,先刪除,再執行 Step 4(理由:部分平台的 `rename()` 若目的檔案已存在會失敗,見 Verification Required 第 2 項——Step 4a 的存在本身就是對這個不確定性的防禦性設計,不論該平台行為為何,依序執行 4a→4 都是安全的)。
- **Step 4**:若 `slot_N.bak` 存在,重新命名為 `slot_N.prev.bak`(取代任何既有的,見 Step 4a)。

**每一步驟(含 Step 0 自身的 4a/4 子呼叫)的失敗行為皆有明確定義**(見 GDD Core Rules #14 R9 修法的兩個子情況——本 ADR 直接對應為 `WriteFailure` 列舉的獨立成員,呼叫端可依此判斷檔案系統目前處於六種可能狀態的哪一種,不需要重新讀取檔案系統推斷)。

**讀取端回復規則**(對應機制三的鏡像邏輯,由讀取路徑消費,見機制八):若目標檔案(`slot_N.dat`)遺失或無法解析,但 `slot_N.bak`(**精確此檔名**,非 `.prev.bak`/`.pre_migration.bak`)存在,視為「中斷發生於 Step 3 與 Step 4 之間」,以 `slot_N.bak` 作為該槽最後有效狀態,走正常讀取路徑(非視為損毀)。

### 機制四:逐槽重入旗標與單一結束出口

```gdscript
# ─── save_slot_lock.gd ───────────────────────────────────────
class_name SaveSlotLock extends RefCounted

var _locked_slots: Dictionary[int, bool]

func try_acquire(slot: int) -> bool     # false = 該槽已鎖定(「該槽處理中」結果)
func release(slot: int) -> void          # 無條件釋放,不檢查是否真的持有
```

**呼叫慣例(GDD Core Rules #5 R13「須無條件釋放」的具體實作)**:任何觸及某槽的完整讀取或一般寫入操作,一律遵循**單一進入、單一釋放**的函式結構——

```gdscript
func _read_full_with_migration(slot: int) -> ReadResult:
    if not _slot_lock.try_acquire(slot):
        return ReadResult.slot_busy()
    var result: ReadResult = await _run_migration_pipeline(slot)   # 見機制五/六,內部窮盡所有分支、必定回傳一個 ReadResult
    _slot_lock.release(slot)   # 本函式從取得鎖到釋放鎖之間,不存在任何提前 return
    return result
```

**理由**:GDScript 沒有 try/catch/finally,無法用語言機制保證「不論中間發生什麼,收尾程式碼一定執行」。本 ADR 的解法是**結構性**的:`_read_full_with_migration()` 本身在取得鎖之後、釋放鎖之前,不包含任何 `return` 陳述式——所有分支邏輯都封裝在 `_run_migration_pipeline()` 內部,該函式**窮盡列舉所有已知結局**(成功、四類拒絕、路徑四的 I/O 失敗)並各自回傳對應的 `ReadResult`,不會以任何方式跳出到呼叫端而不回傳值。這使得「該槽重入旗標無條件釋放」這個 GDD 要求,不依賴分步遷移內部邏輯是否完備——即使 `_run_migration_pipeline()` 未來新增了目前未預期的分支,只要它仍然回傳一個值(而不是靜默中止腳本執行),鎖就會被釋放。**真正的例外**是 GDD Core Rules #5(三)本就承認的「未被分類的例外導致上層攔截」情境——若 GDScript 執行期錯誤導致 `_run_migration_pipeline()` 本身未能正常返回(而非回傳某個 `ReadResult` 值),`release()` 確實不會被呼叫,這與 GDD 自陳的殘留風險完全對應,不是本 ADR 遺漏的缺陷,而是語言層級無法迴避的邊界(GDD 對此的既有態度是「已知並接受」,見機制六)。

### 機制五:分步遷移狀態機與跨幀讓出

```gdscript
# ─── stepped_migration.gd ────────────────────────────────────
class_name SteppedMigration extends RefCounted

var _scene_tree: SceneTree   # 依賴注入,用於 await scene_tree.process_frame

func _init(scene_tree: SceneTree) -> void

# 回傳值涵蓋:成功(附最終資料)、MIGRATION_FAILED(附失敗步驟資訊)、
# SEMANTIC_VALIDATION_FAILED——不涵蓋 I/O 回寫本身(那是機制七的職責)
func run_chain(initial_data: Dictionary, from_version: int, to_version: int, migration_fns: Dictionary[int, Callable]) -> MigrationChainResult
```

**執行模型**:`run_chain()` 每次只執行一個版本躍遷(`v→v+1`),每完成一步後 `await _scene_tree.process_frame`,再繼續下一步——**允許引擎渲染新影格、更新忙碌指示、輪詢輸入**,對應 GDD Core Rules #5「分步執行」的核心要求。每一步執行完畢後,依序套用 Core Rules #12 結構性後置條件檢查與(僅在抵達目標版本後)Core Rules #7 語意驗證(呼叫 `SaveBlockRegistry.get_validator(source_id).call(data)`,見 ADR-0003 機制六)——任一檢查失敗立即回傳 `MIGRATION_FAILED`/`SEMANTIC_VALIDATION_FAILED`,不繼續後續步驟。

**跨幀 `await` 的宿主生命週期約束(沿用 ADR-0001 的一般性原則;`RefCounted` 特有路徑未經單獨驗證)**:`SteppedMigration` 實例在 `run_chain()` 的整個執行期間(可能橫跨數個至數十個影格,取決於遷移鏈深度)必須維持存活——呼叫端(機制四的 `_read_full_with_migration`)不得在 `await` 期間釋放持有 `SteppedMigration` 的參照。每次 `await` 恢復後應以 `is_instance_valid()`(或等效防衛)確認 `_scene_tree` 仍有效,理由與 ADR-0001 機制一「跨幀計算主體的生命週期約束」相同:GDScript 協程若在 `await` 期間其宿主被釋放,恢復時的行為是靜默丟失或執行期錯誤,而非本 ADR 定義的明確結果。

**措辭修正(2026-08-18 第二輪 `/architecture-review` 發現 C5,`godot-specialist` 逐字比對 ADR-0001 原文後提出)**:本段標題原寫「沿用 ADR-0001 **已驗證的**先例」,該措辭超出 ADR-0001 實際驗證過的範圍。ADR-0001 機制一驗證的是**一般性**原則——「跨幀計算的宿主必須有涵蓋整場戰鬥的生命週期」——它**未區分** `RefCounted` 與 `Node` 兩種宿主的失效路徑,而兩者的觸發條件不同:`Node` 的釋放來自顯式 `queue_free()`(程式碼審查搜得到),`RefCounted` 的釋放來自參照計數歸零(**沒有任何顯式呼叫可供搜尋**,「意外少掉一個參照」因此更難在審查中被發現)。本 ADR 選 `RefCounted`(見 Alternative 2 的拒絕理由)本身仍是合理的架構一致性選擇,但這個更細的風險不應被「已有先例」這句話吸收掉——Engine Compatibility Verification Required 第 5 項的獨立煙霧測試建議因此**不因既有先例而降級**,且該測試須明確涵蓋「`await` 期間宿主參照被釋放」這個 `RefCounted` 專屬情境,而非只驗證跨幀恢復點的一般行為。

**觸發情境限制**(GDD 明文):`run_chain()` 只能從下游 UI 指定的**非互動式載入過場**情境呼叫——不得在互動情境(例如存檔槽瀏覽器懸停預覽)直接呼叫。互動情境須改用 ADR-0003 機制三步驟 1(僅讀取 manifest,不觸發此狀態機)。**本 ADR 不在程式碼層級強制這個呼叫慣例**(GDScript 沒有「僅限特定呼叫情境」的語言機制)——這是下游 UI 系統設計時的義務,本 ADR 只保證存在一條較輕量的替代路徑(manifest-only)供互動情境使用,讓「不小心呼叫錯介面」的後果止於「效能較差」而非「資料損毀」。

**進度可觀測性**:`SteppedMigration` 對外暴露 `current_step: int`/`total_steps: int` 唯讀屬性(見機制十),供下游 UI 的進度查詢介面呈現真實進度。

### 機制六:序列化生命週期權杖消費(四條終止路徑)

`_run_migration_pipeline()`(機制四引用)在觸發分步遷移前,呼叫 `AffinityDataPool.begin_non_atomic_window()` 取得權杖,並依實際發生的路徑呼叫對應的 `end_non_atomic_window(token)`——**四條路徑中,三條(一/二/四)是本 ADR 的程式碼結構直接保證的,第三條(三)是結構性無法保證、GDD 自陳已知並接受的殘留風險,不是本 ADR 遺漏的分支**:

```gdscript
func _run_migration_pipeline(slot: int) -> ReadResult:
    var buffer = _io.read_file(_dat_path(slot))
    # ... 機制三讀取端回復規則、ADR-0003 機制三讀取順序 ...
    var token = AffinityDataPool.begin_non_atomic_window()
    var chain_result = await _stepped_migration.run_chain(...)

    if chain_result.rejected:
        AffinityDataPool.end_non_atomic_window(token)   # 路徑(二):同一次呼叫內立即釋放
        return ReadResult.rejected(chain_result.reason)

    var write_result = _atomic_replace_with_genesis_backup(slot, chain_result.data)   # 見機制七
    if write_result.io_failed:
        AffinityDataPool.end_non_atomic_window(token)   # 路徑(四):同一次呼叫內立即釋放,
                                                          # 保證強度與路徑一/二同級
        return ReadResult.pending_migration_io_failure()

    AffinityDataPool.end_non_atomic_window(token)   # 路徑(一):回寫兩階段確認完成後釋放
    return ReadResult.success(chain_result.data)
    # 路徑(三)——非本函式的任何分支:若本函式本身因未分類的執行期錯誤而未能
    # 正常返回(見機制四「真正的例外」段落),此權杖永不被釋放,依賴
    # affinity-data-pool.md 自身的逐權杖逾時後備機制。
    # 2026-08-19 修訂(C1):上一版此處寫「該系統的職責,非本系統補償」——**機制的執行**
    # 確實在該系統,但 TOKEN_TIMEOUT_MS 這個**參數的定值責任**已由本 ADR 接下,見下方
    # 「C1 銜接缺口」段落。兩者不是同一件事,上一版把它們混為一談才造成孤兒義務。
```

**2026-08-19 修訂 —— C1 銜接缺口:`TOKEN_TIMEOUT_MS` 的擁有權由本 ADR 接下**(第二輪 `/architecture-review` 提出,第三、四輪重申仍開):此值先前是**孤兒義務**——ADR-0002 的 Risks 表明文把它委派給「存檔系統 ADR」,而本 ADR 上一版的路徑(三)註解卻寫「該系統的職責,非本系統補償」,兩份 ADR 各自把它推給對方,結果是全專案無人擁有一個會**靜默誤判**的參數。

**決策:本 ADR 接下 `TOKEN_TIMEOUT_MS` 的定值責任。** 理由是資訊在誰手上——ADR-0002 的權杖逾時判定會誤傷的唯一情境,就是「一個合法但耗時很長的非原子視窗」,而**只有本 ADR 知道那個視窗最長能有多長**:它等於分步遷移鏈的深度上界 × 每步的 `await scene_tree.process_frame` 間隔(機制五),再加上機制七兩階段回寫的 I/O 時間。ADR-0002 對這兩個量一無所知,它連遷移鏈存不存在都不知道。

**定值規則(不定死具體毫秒數,定死推導方式)**:

```
TOKEN_TIMEOUT_MS ≥ SAFETY_FACTOR × (MAX_MIGRATION_CHAIN_DEPTH × FRAME_BUDGET_MS
                                     + WORST_CASE_TWO_PHASE_REWRITE_MS)
```

- `MAX_MIGRATION_CHAIN_DEPTH` —— 本 ADR 機制五的遷移鏈深度上界(目前為 1,`SaveFormat` 只有一個版本;每新增一個版本即 +1)。
- `FRAME_BUDGET_MS` —— 16.6(`technical-preferences.md` 的 60fps 幀預算);低階硬體掉幀時實際值更大,由 `SAFETY_FACTOR` 吸收。
- `WORST_CASE_TWO_PHASE_REWRITE_MS` —— 機制七 Phase A + Phase B 的最壞 I/O 時間,**待實測**(機制十的儀器化涵蓋此量測)。
- `SAFETY_FACTOR` —— 建議 ≥ 10。逾時過短的後果是合法操作被誤判為 `TIMED_OUT_RECLAIMED`(ADR-0002 自陳的風險);逾時過長的後果只是洩漏的權杖多躺一會兒。**兩側代價嚴重不對稱,應大幅偏向過長。**

**單向修訂義務**:每次 `SaveFormat` 版本 +1(遷移鏈深度增加),本 ADR 的實作者**必須**回頭重算此值。已列入下方 Validation Criteria。ADR-0002 的 Risks 表已同步改為指向本節。

**與 `SaveSlotLock`(機制四)的獨立性**:本系統自己的逐槽重入旗標,**不**享有與 affinity 端權杖相同的殘留風險豁免——機制四已經用「單一結束出口」的結構保證無條件釋放。兩者是**兩個獨立的鎖**,保護的對象不同(本系統的槽狀態 vs. affinity-data-pool 的 Delta Log),失效後果的嚴重度也不對稱:affinity 端權杖洩漏只封鎖 affinity 寫入,且有逾時後備;本系統自己的槽鎖若洩漏,會讓該槽在本行程剩餘生命週期內所有自動存檔以「該槽處理中」的非錯誤結果被靜默拒絕、且沒有任何後備逾時機制——這正是 GDD 判定為 BLOCKING 而非殘留風險的理由,也是機制四把它做成結構性保證(而非依賴紀律)的原因。

### 機制七:兩階段回寫與創世/滾動備份(Core Rules #13)

```gdscript
enum RewriteOutcome { SUCCESS, IO_FAILED }

func _atomic_replace_with_genesis_backup(slot: int, migrated_data: Dictionary) -> RewriteOutcome
```

- **Phase A(僅當 `slot_N.pre_migration.bak` 不存在時執行一次)**:以機制三相同的技術(暫存寫入→flush→重新命名)將**遷移前的原始位元組**原子寫入為 `slot_N.pre_migration.bak`。若已存在,跳過,永不覆寫(創世保留策略,非「保留最近一次」——理由:若採「最近一次」策略,一個未被偵測到的遷移 bug 會在下一次遷移時,把真正的原始位元組永久覆蓋掉,使創世存底保護的正是最需要它的那個情境失去意義)。
- **Phase B**:以機制三的 `AtomicReplace.replace()` 把遷移後的結果寫入 `slot_N.dat`(即一次視為新自動存檔的標準原子置換)。
- **兩階段的順序保證**:Phase A 必須先完全確認成功,才能開始 Phase B——若 Phase A 本身失敗(`_io` 任一步驟回傳失敗),整個回寫中止,`Phase B` 不得開始,回傳 `IO_FAILED`。
- **三種中斷結果模型**(對應 GDD Edge Cases「Core Rules #13 遷移後中斷」的三種結局,不存在第四種中間狀態):(a)Phase A 完成前中斷——槽維持原始(舊版本)狀態不變;(b)Phase A 完成、Phase B 未達 Step 3 前中斷——`.pre_migration.bak` 已確認寫入,`.dat` 仍是遷移前內容,下次讀取視為仍待遷移,重跑時 Phase A 因已存在而跳過,直接進入 Phase B;(c)Phase B 的 Step 3 完成後中斷——`.pre_migration.bak` 已確認寫入,`.dat` 已是遷移後內容,至多殘留一個尚未被 Step 4 轉換成 `.prev.bak` 的 `slot_N.bak`。

**遷移完成標記的攜帶與保留責任**(GDD 第五輪最高優先發現,直接對應 ADR-0003 機制二 manifest 結構中的 `migration_completion_marker` 欄位):Phase B 每次執行,須把各 append-only 區塊(目前唯一實例:好感度數值池的 Delta Log)當下的記錄索引/戰役刻度位置寫入該欄位;**非 append-only 區塊此欄位恆為顯式 `null`,不得以欄位缺席表達**(呼應 ADR-0003 機制四「固定順序」段落同一類「表示法選擇不得影響雜湊結果」的紀律)。**一般寫入路徑(機制一之外,Core Rules #4 的標準自動/手動存檔)必須原樣攜帶此欄位,不得重新計算或省略**——這個欄位的值**只**在本機制的 Phase B 改變,一般寫入的唯二責任是原樣保留與被納入 ADR-0003 頂層雜湊輸入。**理由(此義務缺席的具體後果)**:若一般寫入路徑遺漏此責任,一次成功遷移後的任何後續自動存檔都會靜默抹除這個標記,而抹除本身通過兩層雜湊驗證(manifest/payload 自洽、雜湊輸入取自寫入前記憶體資料)、不產生任何錯誤代碼——這正是路徑(二,見下方)存在的目的所倚賴的錨點被靜默沖走,是本文件家族已知最危險的失敗類別之一。

**四條自動痊癒路徑**(GDD Core Rules #13,**並非四個對等的保證**):

1. **路徑一(遷移失敗後自動重試,無損、自動觸發)**:槽先前因缺少某個遷移函數進入「拒絕讀取」;遊戲更新補上該函數後,下次讀取自動重跑整條鏈,成功即依本機制回寫,不需要玩家任何動作。本 ADR 的機制五/七天然支援——沒有任何狀態需要特殊處理,「下次讀取」走的就是一般路徑。
2. **路徑二(維運層級重跑,資料前提由本 ADR 保證,執行程序留給 `/create-architecture`)**:若槽已回寫(狀態「有效」),但事後發現語意驗證有遺漏,遊戲更新修正驗證規則後,理論上可從創世存底重跑修正後的鏈。**本 ADR 只保證創世存底存在且永不被覆寫(機制七 Phase A)、且遷移完成標記被正確攜帶(上方責任分工)這兩個資料前提成立**——實際觸發機制、狀態呈現、拼接程序本身,依 GDD 明文,留給 `/create-architecture` 或維運工具鏈決定,本 ADR 不定案。**拼接完成後的重新雜湊義務**:若此路徑執行,產出結果必須重新計算並寫回逐區塊雜湊與 manifest 頂層雜湊(重用機制三/ADR-0003 的標準雜湊計算,**不得**繞過標準寫入管線直接編輯磁碟位元組)——此義務本身是 GDD 層級的硬性前提,不因路徑二的觸發機制本身仍待決定而被排除。
3. **路徑三(同版本語意驗證修正後自動痊癒,無損、自動觸發)**:目前版本區塊因語意驗證失敗被拒絕;遊戲更新修正驗證規則(`SaveBlockRegistry` 中對應的 `validate_semantics` 實作)後,下次讀取自動重跑驗證,通過即轉為有效狀態。與路徑一同理,本 ADR 不需要特殊狀態處理。
4. **路徑四(型別白名單/完整性標記邏輯修正後自動痊癒,僅對誤判有效)**:若槽因本系統自身邏輯 bug(ADR-0003 機制三/四)被誤判 `DATA_CORRUPTED`,修正後下次讀取自動重跑,可能轉為有效或待遷移。**此路徑僅執行完整性/型別檢查,不反序列化 payload、不還原記憶體狀態、不產生非原子視窗**——因此**不呼叫** `begin_non_atomic_window()`(對應 `affinity-data-pool.md` Core Rules #6「不產生非原子視窗的操作不得取得權杖」),不得被誤判為遺漏的 begin 呼叫。此路徑對真正的位元腐蝕/外部竄改**不提供任何修復保證**,本系統在拒絕當下無法區分誤判與真正損毀,故不得對玩家承諾任何形式的「終將修復」。

### 機制八:結構化結果型別與拒絕代碼擴充

延伸 ADR-0003 的 `SaveFormat.ReadRejection`:

```gdscript
enum ReadRejection {
    NONE,
    DATA_CORRUPTED,             # ADR-0003 定義
    VERSION_TOO_NEW,            # ADR-0003 定義
    MIGRATION_FAILED,           # 本 ADR 新增
    SEMANTIC_VALIDATION_FAILED, # 本 ADR 新增
}

class ReadResult extends RefCounted:
    var rejection: ReadRejection   # NONE 表示以下三種非拒絕結局之一
    var data: Variant               # 成功時的還原資料
    var is_empty: bool               # 槽從未寫入(AC-4,獨立於 rejection,非錯誤)
    var is_slot_busy: bool           # 同槽重入(機制四),獨立、非錯誤
    var is_pending_not_attempted: bool     # 待遷移、本次讀取尚未嘗試(區別於已嘗試但路徑四失敗)
    var is_pending_io_failure: bool  # 路徑四:遷移語意成功、回寫 I/O 失敗,獨立、非錯誤
    var repeated_failure_count: int  # 見機制十一,僅 is_pending_io_failure 時有意義

static func success(data: Variant) -> ReadResult
static func rejected(reason: ReadRejection) -> ReadResult
static func empty() -> ReadResult
static func slot_busy() -> ReadResult
static func pending_migration_io_failure(repeated_count: int) -> ReadResult
```

**六種結局互斥、可程式化區分**(對應 GDD 明文「不得合併呈現」的要求):成功、四類拒絕代碼中的一種、無資料、槽處理中、待遷移未嘗試、待遷移且回寫 I/O 失敗——下游 UI 依 `ReadResult` 的欄位分派,不得以字串比對或其他脆弱手段判斷結局種類。

### 機制九:唯讀存取介面與來源優先序

```gdscript
enum ReadOnlyHitSource { DAT, PREV_BAK, PRE_MIGRATION_BAK, ALL_UNREADABLE }

class ReadOnlyAccessResult extends RefCounted:
    var hit_source: ReadOnlyHitSource
    var data: Variant   # ALL_UNREADABLE 時為 null

func read_only_access(slot: int) -> ReadOnlyAccessResult
```

**可用條件**(GDD 明文,兩組條件之一即可):(a)該槽處於「拒絕讀取」狀態(`DATA_CORRUPTED`/`SEMANTIC_VALIDATION_FAILED`/`MIGRATION_FAILED`,**不含** `VERSION_TOO_NEW`);(b)該槽處於「待遷移」狀態,且已滿足機制十一的「重複回寫失敗」條件,且當下無進行中的分步狀態機。

**來源優先序**(依序嘗試,取第一個通過檢查者):`slot_N.dat`(即使版本落後,只要仍可解析)→ `slot_N.prev.bak` → `slot_N.pre_migration.bak`。**每個來源皆須重新套用 ADR-0003 機制三的頂層/逐區塊雜湊驗證與型別白名單解碼**(「這是我們自己的備份」不構成免驗證的理由)——通過才視為該來源命中,三者皆未通過則回傳 `ALL_UNREADABLE`。**語意驗證(Core Rules #7)於此介面降級為僅標註、不阻擋**(理由:此介面的目的是讓玩家在語意有疑慮時仍能看見內容,格式安全與位元組完整性不可放寬,但語意合理性可以)。

**分級揭露的中繼資訊**:`hit_source` 直接對應 GDD 的三級分類——`DAT`/`PREV_BAK` 為「高完整度」,`PRE_MIGRATION_BAK` 為「可能遺漏後續進度」,`ALL_UNREADABLE` 為「備份本身也已損毀」——下游 UI 依此欄位選擇對應文案(見 GDD Interactions 最低呈現契約),本 ADR 不決定實際文案內容。

### 機制十:可觀測性介面分類(Core Rules #15)

| 介面 | 分類 | 受機制四重入拒絕? | 是否套用完整性/白名單檢查? |
|---|---|---|---|
| 完整讀取介面(觸發遷移鏈) | 生產 | 是 | 是 |
| 一般寫入介面(Core Rules #4) | 生產 | 是(逐槽) | 是 |
| manifest-only 輕量讀取(ADR-0003) | 生產 | **否** | 僅頂層完整性標記 |
| 遷移進度查詢介面(機制五 `current_step`/`total_steps`) | 生產 | **否**(查詢的是狀態機自身進度,非對槽發起新讀寫請求) | 否(不觸碰磁碟內容) |
| 唯讀存取介面(機制九) | 生產 | **否**(可用條件本身已保證無進行中狀態機) | 是 |
| 診斷介面(以下四項) | 診斷 | 不適用 | 不適用 |

**四項診斷介面**(GDD 明文:QA/除錯專用,下游業務邏輯不得依賴為正式回傳簽章):

1. **遷移呼叫計數器**:記錄一次讀取實際呼叫了幾次遷移函數(驗證「零次遷移」/「恰一次遷移」情境)。
2. **遷移呼叫順序記錄**:記錄遷移函數呼叫的時間順序(驗證嚴格依序執行)。
3. **生命週期通知呼叫記錄**(機制六):記錄每一次對 `AffinityDataPool` 的 `begin`/`end` 呼叫,含呼叫類型、攜帶的權杖、受影響的槽、相對於遷移步驟與機制七兩階段回寫的時間位置,須能判定兩次呼叫是否跨越了事件迴圈刻度邊界。
4. **主執行緒斷言**(debug build):存檔讀寫介面進入點斷言呼叫執行緒為主執行緒(`OS.get_thread_caller_id()` vs `OS.get_main_thread_id()`,**確切 API 名稱待驗證**,見 Engine Compatibility)——把 Core Rules #4 的單執行緒假設從文件宣稱轉為自動可偵測的違規斷言。

### 機制十一:重複回寫失敗計數與唯讀存取管道擴大

```gdscript
class RepeatedFailureTracker extends RefCounted:
    var _counts: Dictionary[int, int]   # 逐槽獨立,不持久化(行程重啟即歸零)

func record_io_failure(slot: int) -> int   # 回傳遞增後的計數
func reset(slot: int) -> void               # 成功回寫或槽被覆寫時呼叫
```

**計數規則**(GDD 明文,逐一對應):(a)逐槽獨立(Core Rules #2 槽隔離性的直接推論);(b)「連續」定義為該槽任何一次成功回寫或被覆寫即歸零,不持久化磁碟(僅服務同一次遊玩期間的告知需求,持久化的代價遠高於收益);(c)唯讀存取(機制九)**不影響**此計數(既非回寫亦非覆寫,不歸零亦不遞增);(d)機制四的「槽處理中」重入拒絕結果**不遞增**此計數(該結果不是一次因路徑四 I/O 失敗而未完成回寫的讀取嘗試,否則玩家在遷移執行期間連續嘗試讀取即可人為推高計數,提前開啟本應由真實 I/O 失敗閘控的唯讀存取管道)。

**兩級揭露門檻**:第一次路徑四失敗即回傳可辨識、非合併的結構化結果(`ReadResult.is_pending_io_failure = true`,`repeated_failure_count = 1`)——不要求玩家看不到任何原因就被迫重試;**連續兩次**後(a)唯讀存取管道開啟(機制九可用條件 b),(b)下游 UI 升級為完整揭露文案 + 復原前景語句。**此門檻只控制「唯讀存取管道」與「升級版告知文案」兩件事,不控制「錯誤原因本身是否可辨識」**——後者從第一次失敗就必須成立,呼應 GDD 對第七輪修法副作用的自我修正。

## Architecture Diagram

```
                    讀取路徑總覽:
                    ┌────────────────────────────────────────┐
                    │  SaveSlotLock.try_acquire(slot)          │
                    │  false ──▶ ReadResult.slot_busy()        │
                    └──────────────────┬────────────────────────┘
                                       │ true
                                       ▼
                    ┌────────────────────────────────────────┐
                    │  讀取 slot_N.dat（或依機制三讀取端回復規則  │
                    │  改讀 slot_N.bak）→ ADR-0003 機制三步驟 1-6 │
                    │  （頂層雜湊→版本比對→逐區塊雜湊→白名單→驗證）│
                    └──────────────────┬────────────────────────┘
                        版本相同 ┌──────┴──────┐ 版本落後
                                 ▼             ▼
                    ┌──────────────────┐  ┌────────────────────────────┐
                    │ 直接還原，完成    │  │ begin_non_atomic_window()  │
                    └──────────────────┘  │        ↓                    │
                                           │ SteppedMigration.run_chain()│
                                           │ （跨幀讓出，機制五）         │
                                           │        ↓                    │
                                           │  拒絕？──▶ end() 路徑二     │
                                           │        ↓ 成功                │
                                           │ AtomicReplace + 創世存底     │
                                           │ （機制三/七）                │
                                           │        ↓                    │
                                           │ I/O 失敗？──▶ end() 路徑四  │
                                           │        ↓ 成功                │
                                           │  end() 路徑一               │
                                           └──────────────┬───────────────┘
                                                          ▼
                    ┌────────────────────────────────────────┐
                    │  SaveSlotLock.release(slot)  ← 無條件，  │
                    │  單一結束出口（機制四）                    │
                    └────────────────────────────────────────┘
```

## Key Interfaces

以下為本 ADR 定案的契約形狀,語意不得改變,命名可微調。

```gdscript
# ─── save_system.gd（概念契約，DI 注入 SaveIOBackend/SaveBlockRegistry/SceneTree）
class_name SaveSystem extends RefCounted

func _init(io: SaveIOBackend, registry: SaveBlockRegistry, scene_tree: SceneTree) -> void

func write(slot: int, blocks: Dictionary[String, Dictionary]) -> ReadResult   # Core Rules #4，同步阻塞
func read_full(slot: int) -> ReadResult                                        # 觸發遷移鏈的完整讀取
func read_manifest_only(slot: int) -> Variant                                  # ADR-0003 機制三步驟 1-3
func read_only_access(slot: int) -> ReadOnlyAccessResult                       # 機制九
func migration_progress(slot: int) -> Variant                                  # {current_step, total_steps} 或 null
```

## Alternatives Considered

### Alternative 1:現在就改用非同步寫入模型

- **Description**:不等待具體主機平台 SDK 確認,直接把 Core Rules #4 的寫入介面改為 callback/signal 式非同步。
- **Pros**:若目標主機的 SaveData API 確實是非同步設計,現在改比日後回頭改的成本低。
- **Cons**:專案文件目前未指定具體主機型號,任何非同步設計的具體形狀(callback 參數、是否需要輪詢、錯誤傳遞方式)都只能是猜測,猜錯的成本(重新設計 + 重寫已完成的程式碼)不比維持同步阻塞低。且會與 GDD 現行文字(明文「同步阻塞」)直接衝突,需要同步回頭修訂 GDD,超出本 ADR 的職權(GDD 的義務變更方向是單向的,ADR 不得反過來擴大或縮小 GDD 的義務,除非使用者明確裁決重開該 GDD 段落)。
- **Rejection Reason**:使用者已明確裁決維持同步阻塞、以可替換抽象因應未來可能的翻轉(見機制一)。

### Alternative 2:遷移狀態機用 `Node` + `_process()` 而非 RefCounted + `await`

- **Description**:`SteppedMigration` 繼承 `Node`,加入場景樹,每個 `_process(delta)` 執行一個遷移步驟,完成後 `queue_free()`。
- **Pros**:不需要處理跨幀 `await` 的宿主生命週期約束(ADR-0001 已識別的陷阱類別)——`Node` 的 `_process` 本就是逐幀呼叫,沒有協程恢復點失效的問題。
- **Cons**:需要動態地把節點加入/移出場景樹,增加了與場景樹生命週期(父節點是否還存在、場景切換時機)耦合的另一類風險;且與 ADR-0002/0003 已建立的 DI 優先、避免不必要場景樹依賴的慣例不一致——`SaveSystem` 及其協作物件目前皆為純 `RefCounted`,不需要因為這一個機制引入例外。
- **Rejection Reason**:`await get_tree().process_frame` 的生命週期約束已有 ADR-0001 的既有先例可以直接複用(機制五已引用),不需要為了迴避這個已知模式而引入新的耦合面。

### Alternative 3:重複回寫失敗計數持久化至磁碟

- **Description**:把機制十一的計數寫入 manifest,跨行程存續。
- **Pros**:玩家重啟遊戲後,計數不會歸零,若確實是持續性的磁碟問題(而非偶發),可以更快抵達唯讀存取管道。
- **Cons**:此欄位一旦持久化,就成為 ADR-0003 頂層雜湊 tuple 清單的第五個需要涵蓋的欄位——GDD 明文指出此代價遠高於收益(此計數服務的是「同一次遊玩期間」的告知需求,不是一個需要跨 session 追蹤的資料)。
- **Rejection Reason**:GDD 已在 Core Rules #5 明文裁決不持久化,本 ADR 沿用該裁決,不重新開放。

## Consequences

### Positive

- **`TR-save-*` 30 項需求至此為 22 項完整涵蓋、7 項部分涵蓋、1 項缺口**——好感度數值池、序列化格式、原子寫入與遷移執行模型三份 ADR 合起來回答了存檔系統絕大部分的架構層問題。**2026-08-18 第二輪 `/architecture-review` 修正**:本行原宣稱「全數有 ADR 覆蓋」不成立。`TR-save-030`(雲端存檔同步 × 多檔案原子性)為缺口——本 ADR 的 Requirements Addressed 表雖列出該項,同格說明文字自陳「本 ADR 不解決此問題」;另 `TR-save-005/-015/-019/-021/-026/-028/-029` 為部分涵蓋,其中 `-026`(三桶/六桶耗時儀器化 + 加性下限成本模型)缺口最實質,機制十提供的是遷移呼叫計數器而非耗時儀器。詳見 `docs/architecture/architecture-review-2026-08-18-round2.md`。
- **GDD 密度最高、對抗性審查最頻繁的規則群(六步驟原子置換、四條終止路徑),在本 ADR 中都有明確對應的程式碼結構**——降低了「規則傳播到實作時遺漏某個分支」的風險(這正是 GDD 自身審查過程中至少三次實際發生過的失敗模式)。
- **同步/非同步的懸而未決,被限縮到單一檔案的抽象邊界**,不阻塞其餘架構決策定案,也不需要靠猜測具體主機 SDK 細節來強行定案。
- **與 ADR-0001 的跨幀 `await` 先例、ADR-0002/0003 的 DI 慣例一致**,不引入新的架構風格。

### Negative

- **GDD Open Question 9(同步阻塞模型是否在確認主機平台上成立)仍未被本 ADR 真正解決**,只是被結構化地延後——若日後證實不成立,`AsyncSaveIOBackend` 的具體形狀需要新的設計工作與可能的本 ADR 修訂。
- **路徑二(維運層級重跑)的具體觸發機制與程序仍是空白**——本 ADR 只保證資料前提(創世存底、遷移完成標記)成立,實際的「誰觸發、怎麼呈現、拼接程序本身」留給 `/create-architecture` 或維運工具鏈,這與 GDD 自身的裁決一致,但代表這部分的實作仍需要額外一輪設計工作,不是本 ADR 已經完整回答的範圍。
- **診斷介面(機制十)的四個項目目前只定義了「應該記錄什麼」,未定義具體儲存/查詢機制**(例如記錄檔案格式、保留期間)——留待實作階段决定,不影響本 ADR 的架構正確性,但下游測試撰寫時需要這些細節。

### Risks

| 風險 | 緩解 |
|---|---|
| **`FileAccess.flush()` 缺乏可檢查的失敗訊號**(Verification Required 第 1 項,GDD 自身 Open Question 13 已標記) | 機制一/三已將所有磁碟存取封裝在 `SaveIOBackend` 介面之後,若證實 `flush()` 無直接回傳值,可在 `SyncBlockingSaveIOBackend` 內部改用 `FileAccess.get_error()` 等間接判定手段,不需要修改本 ADR 的機制三/四/五/六/七——影響面已被機制一的抽象邊界限縮 |
| **`FileAccess.get_error()` 作為 `flush()` 失敗的備援判定,回傳的是累積錯誤狀態,無法區分「`flush()` 本身失敗」與「前一次 `store_buffer()` 呼叫已設下的錯誤狀態」**(2026-08-18 `godot-specialist` 驗證發現) | 不影響本 ADR 的設計正確性——`write_temp()` 已將整個「寫入 + flush」序列視為單一原子檢查單位(任一環節失敗即整體回傳失敗),不需要區分失敗發生在序列中的哪一步;僅為訊號粒度的誠實揭露,避免未來讀者誤以為能單獨診斷 `flush()` 本身 |
| **`DirAccess.rename()` 對目的檔案已存在的行為因平台而異**(Verification Required 第 2 項) | Core Rules #14 的 Step 4a(先刪除 `.prev.bak` 再重新命名)本就是對這個不確定性的防禦性設計,不論實際平台行為為何,依序執行都是安全的——本 ADR 已忠實實作此防禦,不需要等驗證結果才能定案 |
| **分步遷移橫跨的影格數若因遷移鏈極深而過多,`await get_tree().process_frame` 的累積排程開銷可能不可忽略**(GDD Tuning Knobs `migration_chain_load_time_budget_ms` 已標記此為總時間的一部分) | 屬已知、GDD 自身已標記的效能追蹤項目,非本 ADR 需要現在解決的問題;若實測證實顯著,`max_supported_migration_depth` 的重新評估觸發條件已由 GDD 定義 |
| **主執行緒斷言 API(`OS.get_thread_caller_id()`/`get_main_thread_id()`)名稱可能不正確**(Verification Required 第 3 項) | 僅影響機制十第 4 項診斷介面(debug-only),不影響任何生產路徑的正確性;若名稱有誤,實作階段查證正確 API 即可,不需要回頭修訂本 ADR 的其他機制 |
| **創世存底(`slot_N.pre_migration.bak`)本身沒有滾動備份保護,長期靜置有位元腐蝕曝險**(GDD 自身已承認的殘留風險) | 本 ADR 忠實反映 GDD 的既有態度(已知並接受,比照 Core Rules #14 耐久性範圍聲明的寫法),不在架構層試圖消除一個 GDD 已裁定接受的風險——若需要更強保護(例如額外的校驗和輪替備份),須回頭修訂 GDD 本身的取捨,不是本 ADR 的裁量範圍 |

## GDD Requirements Addressed

| TR-ID | 需求 | How This ADR Addresses It |
|---|---|---|
| TR-save-004 | 每槽多檔案佈局 `.dat`/`.bak`/`.prev.bak`/`.pre_migration.bak`/`.tmp`,槽與槽完全隔離 | 機制二定義精確命名慣例;`SaveSlotLock`(機制四)以 slot id 為鍵,槽與槽的鎖/計數皆獨立 |
| TR-save-005 | 一般寫入路徑同步阻塞單執行緒,provisional 已逾期 | 機制一:維持同步阻塞現行決定,包一層 `SaveIOBackend` 抽象邊界,承認 Open Question 9 尚未真正解決但限縮其影響面 |
| TR-save-006 | 遷移執行模型獨立決定,分步執行,仍為單執行緒 | 機制五:`SteppedMigration` 每步 `await get_tree().process_frame` 讓出控制權,不引入背景執行緒 |
| TR-save-007 | 同槽重入不變量,逐槽進行中標記須無條件釋放 | 機制四:單一進入/單一釋放函式結構,GDScript 無例外機制下的最佳保證 |
| TR-save-008 | 跨系統權杖式序列化生命週期介面,涵蓋 4 條終止路徑 | 機制六:三條(一/二/四)結構性保證,第三條為 GDD 自陳的已知殘留風險 |
| TR-save-009 | 路徑四強保證僅在 I/O 失敗以回傳碼回報成立 | 機制六/七:`RewriteOutcome.IO_FAILED` 依賴 `SaveIOBackend` 回傳值,若底層改以未分類例外回報則落入路徑三(GDD 明文的邊界) |
| TR-save-015 | 每一次寫入/flush/rename/刪除呼叫的成功與否須被實際檢查 | 機制三:`WriteFailure` 列舉窮盡六個步驟各自的失敗情境,`SaveIOBackend` 的每個方法回傳值皆須被檢查 |
| TR-save-016 | 跨平台原子置換是已鎖定的六步驟行為序列 | 機制三忠實實作 Core Rules #14 的 Step 0(含分支 A/B)、1、2、3、4a、4 |
| TR-save-017 | 讀取端回復規則須採精確檔名比對 | 機制三「讀取端回復規則」段落,`slot_N.bak` 精確比對,不使用萬用字元 |
| TR-save-018 | 遭拒存檔的唯讀存取入口,依命中的備份層級分三級告知 | 機制九:`ReadOnlyHitSource` 三態 + 來源優先序 |
| TR-save-019 | 耐久性邊界:「flush」僅指引擎緩衝區沖刷至 OS 層級 | Engine Compatibility Verification Required 第 4 項忠實反映此邊界,不宣稱本 ADR 解決硬體層級落盤問題 |
| TR-save-020 | 存檔位置須在 `user://`,`.tmp` 與目標檔須同一檔案系統 | 機制二明文定案為硬性設定要求 |
| TR-save-021 | 遷移函數須為純函數、`O(該區塊自身筆數)` | 機制五:`migration_fns: Dictionary[int, Callable]` 由呼叫方(各擁有系統)提供,本 ADR 的狀態機本身不引入額外的非線性遍歷 |
| TR-save-024 | 遷移完成標記的寫入責任分散於 3 種寫入路徑類型 | 機制七「遷移完成標記的攜帶與保留責任」段落,明訂 Phase B 與一般寫入路徑各自的責任邊界 |
| TR-save-025 | 可觀測性介面分兩類:診斷用 vs 生產用 | 機制十的分類表與四項診斷介面/兩項生產介面清單 |
| TR-save-026 | 效能量測儀器化 | 機制十的遷移呼叫計數器/順序記錄提供量測所需的原始資料,具體量測門檻(`save_write_max_duration_ms` 等)由 GDD Tuning Knobs 定義,本 ADR 不重新定案數值 |
| TR-save-027 | 重複回寫失敗計數逐槽獨立、不持久化 | 機制十一:`RepeatedFailureTracker`,逐槽 `Dictionary`,行程重啟即歸零 |
| TR-save-029 | 維運層級重跑創世存底 + append-only 拼接和解 | 機制七路徑二:本 ADR 保證資料前提(創世存底、完成標記)成立,觸發機制與拼接程序留給 `/create-architecture`(與 GDD 裁決一致) |
| TR-save-030 | 雲端存檔同步與多檔案原子性的互動未定義 | 本 ADR 不解決此問題(GDD 自身列為 Open Question,目標為平台策略定案時)——機制二的精確檔名/同檔案系統設計不會讓此問題更難處理,但也不主動解決 |

## Performance Implications

- **CPU**:六步驟原子置換序列的成本與現有 `save_write_max_duration_ms` 的量測範圍相同(GDD 已有的效能追蹤機制涵蓋,本 ADR 不改變其量測對象)。分步遷移的每步 `await` 引入至少一次額外的引擎排程等待,總時間 = Σ(各步驟計算時間)+ 鏈深度 × 每步固定讓出成本(GDD Tuning Knobs 已定義此模型)。
- **Memory**:六步驟置換序列在最壞情況(Step 1-3 之間)同時持有暫存檔與現存槽檔案 + `.prev.bak` + `.pre_migration.bak`,即時尖峰磁碟用量為穩態的 4 倍(GDD Tuning Knobs 已量化,估計仍為數十 KB 量級)。
- **Load Time**:完整讀取路徑的耗時受 `migration_chain_load_time_budget_ms` 追蹤,本 ADR 的分步執行設計把「玩家完全無回應」轉換為「玩家看得到進度」,是刻意的體驗取捨(增加些微總時間,換取可感知的回應性),非效能迴歸。
- **Network**:不適用。

**明確未定案**:同步/非同步模型的最終確認(取決於具體主機 SDK,本 ADR 不擅自假設);創世存底的額外保護機制(若需要)。

## Migration Plan

不適用——本專案 `src/` 目前為空,尚無任何實作程式碼,處於設計階段。

## Validation Criteria

1. **GDD Acceptance Criteria 中「原子寫入」「遷移狀態機」「終止路徑」三類的全部向量通過**(對應本 ADR 涵蓋範圍的 AC-6~12、AC-10a/10b、AC-13~16、AC-38、AC-48、AC-64、AC-66、AC-75、AC-81、AC-59、AC-67~69、AC-72~73、AC-76~78、AC-80)。
2. **六步驟失敗注入測試**:對 Step 0(分支 A/B 各自的子情境)、1、2、3、4a、4 逐一構造在該步驟失敗的情境,驗證回傳對應的 `WriteFailure` 成員,且檔案系統狀態符合 GDD Edge Cases 定義的對應中斷結果(不多不少)。
3. **四條終止路徑的獨立驗證**:分別構造遷移成功、Core Rules #6 拒絕、回寫 I/O 失敗三種情境(路徑三因結構性無法主動觸發,見機制六說明,不納入本項),驗證 `AffinityDataPool.end_non_atomic_window()` 皆在對應時機被呼叫、且不多不少一次。
4. **逐槽重入的黑箱測試**:同一槽並行發起兩次完整讀取,驗證後者立即回傳 `slot_busy()`、不排隊、不啟動第二個狀態機;不同槽並行不受影響。
5. **鎖釋放的完整性測試**:構造 `_run_migration_pipeline()` 內部各分支(成功/拒絕/I/O 失敗),驗證每一種分支結束後 `SaveSlotLock` 皆已釋放該槽(可透過立即嘗試 `try_acquire()` 驗證回傳 `true`)。
6. **`TOKEN_TIMEOUT_MS` 的定值與版本連動測試(2026-08-19 修訂新增,C1;**2026-08-19 第五輪審查 R5-4:本項原印為第 7 項且排在第 6 項之前,已改號為 6 並維持位置**)**:斷言實際採用的 `TOKEN_TIMEOUT_MS` ≥ 機制六定值規則算出的下界;並於 `SaveFormat` 版本 +1 時,以一個會失敗的測試強制實作者回頭重算(例如把 `MAX_MIGRATION_CHAIN_DEPTH` 寫成常數並斷言它等於 `SaveFormat` 的版本數 − 1)。**沒有這道測試,C1 的擁有權宣告會在第二次遷移版本上線時靜默失效。**
7. **後續 `/architecture-review`** 判定本 ADR 與 ADR-0001/0002/0003 無衝突,且對 `save-system.md` 的**缺口清單與已知清單一致**(目前已知且接受的缺口:`TR-save-030` 雲端存檔同步 × 多檔案原子性,歸屬平台策略,明文不屬本 ADR)。
   > 🔴 **2026-09-01 稽核修正判準句。** 原文要求「涵蓋**無缺口**」,而**同一份文件另外三處**
   > (`ADR Dependencies → Enables`、涵蓋率結論段、`Related Decisions`)明文承認有 1 項永久缺口。
   > **這條驗收條件因此結構上永遠不可能通過** —— 它不是「還沒做」,是「照字面做不到」,
   > 而它是一條會被自動檢查讀到的驗收條件,等於在核准路徑上放了一道打不開的門。
   > 修法方向是把判準從「無缺口」改為「缺口清單與已知清單一致」,**不是**去刪掉那項缺口。**2026-08-18 第二輪執行結果:衝突面通過**(無阻塞級衝突;但發現 5 項銜接缺口 C1~C5,其中 C1 `TOKEN_TIMEOUT_MS` 孤兒義務、C4 `write_temp()` 底層呼叫未拍板、C5「沿用 ADR-0001 已驗證先例」措辭超出實際驗證範圍,三者皆與本 ADR 直接相關);**涵蓋面未通過**——1 項缺口 + 7 項部分涵蓋,見上方 Consequences 的修正說明。

**反向驗證**:若六步驟序列的某個分支被遺漏或實作有誤,會表現為特定失敗注入情境下的檔案系統終態不符合 GDD Edge Cases 定義的三種允許結局之一——第 2 項測試會直接攔截。若鎖釋放邏輯有誤(例如某條分支忘記回傳導致函式提前結束),會表現為該槽此後所有操作恆為「處理中」——第 5 項測試逐分支驗證會攔截。

## Related Decisions

- `design/gdd/save-system.md` — 本 ADR 服務的全部義務之權威定義處。
- `docs/architecture/adr-0001-tactical-query-atomicity-contract.md` — 跨幀 `await` 生命週期約束的先例,機制五直接引用。
- `docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md` — 機制六消費其權杖式生命週期介面。
- `docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md` — 機制三/八延伸其 `SaveFormat`/`ReadRejection`/`SaveBlockRegistry`。
- `docs/registry/architecture.yaml` — 本 ADR 完成後將登記的新增立場。
- `docs/architecture/adr-0005-cursor-device-authority-input-architecture.md` — **2026-08-19 修訂新增(C6 銜接缺口關閉)**。該 ADR 機制十一(跨畫面交接生命週期,甲/乙/丙三分支)在本 ADR 定義的讀檔生命週期節點上動作。**義務歸屬明文如下,避免被誤讀為本 ADR 有未履行的義務**:`cursor-highlight-state.md` Core Rules #7 把游標交接義務歸給**呼叫方**(戰棋系統),**不**歸給存檔系統——本 ADR 不呼叫游標系統的任何介面,也不需要知道它存在(本 ADR 與 ADR-0005 皆宣稱不理解遊戲實體語意)。前三輪 `/architecture-review` 實測本 ADR 全文對「游標」/「cursor」零命中,判定為「不是矛盾,但 ADR-0004 不宜在被單方面宣稱交接的狀態下逕行 `Accepted`」——本條目即為該判定的處置。**本 ADR 讀檔路徑的四條終止路徑(機制六)是呼叫方判斷該走甲/乙/丙哪一分支的輸入**,其中路徑〔四〕(遷移成功但回寫失敗)依 `cursor-highlight-state.md` 第十三輪裁決**不落入丙分支**,呼叫方仍走甲/乙前進路徑。
- **`TR-save-*` 系列的涵蓋狀態**:**22 項完整 / 7 項部分 / 1 項缺口**(`TR-save-030` 雲端同步)——見上方 ADR Dependencies 的 `Enables` 欄與 Consequences 的同一修正。**2026-08-19 修訂**:本行原寫「至此三份 ADR 全數覆蓋」,與同檔第 27 行、第 421 行已於 `1c3d5d0` 修正的「22/7/1」互相矛盾——那是第二輪 `/architecture-review` 推翻的同一個過度宣稱在本檔案的**第四處**,前次修正漏改。`docs/architecture/traceability-index.md`「需要 ADR 的已知缺口」清單第 2/3 項至此完成(此半句成立,指的是缺口清單的項次,不是 TR 涵蓋率)。
