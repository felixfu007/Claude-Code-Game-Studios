# Story S-001:型別基座 —— `AffinityTypes`

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Logic
> **狀態**:✅ Complete(狀態標記 2026-09-16 補正 —— 實作早已完成,但本欄一直停在 `Ready`)
> **估時**:S
> **依賴**:無

## Context

- **GDD**:`design/gdd/affinity-data-pool.md` —— Formulas 章節開頭「共用符號表」(`Pair`/`Character`/`Source` 的定義域)、Section A(AC-27a)、Section M(AC-56/AC-57,索引鍵持久化穩定性)
- **Governing ADR**:ADR-0002(好感度數值池資料結構與並發契約,**Accepted**)—— 機制二(共用列舉的檔案歸屬)、機制四之四(8 個帶 enum 參數的入口統一序數驗證)
- **Engine**:Godot 4.7.1

## 目標

建立好感度數值池最底層的型別詞彙——`AffinityTypes` 類別,包含 `Character`/`Pair`/`Source` 三個列舉、`pair_of()` 正規化建構函式、以及三個公開序數驗證器。**這是整條資料層鏈唯一零依賴的起點**,後續 8 張 story 全部直接或間接引用它;做完之後,「配對」「角色」「來源」這三個詞在程式碼裡第一次有一個唯一、可跨檔引用的型別定義。

## 🔴 本 story 決定的原始碼目錄路徑

**`src/gameplay/affinity_pool/`(本 story 起新建)。**

理由:

1. `src/gameplay/affinity/` 已被系統 #5(好感度—位置連鎖)佔用——`affinity_link.gd`/`affinity_rules.gd`/`affinity_phi_provider.gd`/`affinity_line_status.gd` 四個既有檔案是關係線極性讀取路徑,餵給 `Φ`,EPIC.md 明文交代「不要把本 epic 的檔案混進那個目錄」。
2. `src/gameplay/cards/` 已被技能卡牌系統佔用(`affinity_write_port.gd`/`null_affinity_write_port.gd` 等)。池本體的六個型別(`AffinityRecord`/`AffinityRecordList`/`AffinityTypes`/`AffinityDataPool`/`HypotheticalEntry`/`ImportResult`)理當共享同一個目錄——混進 `cards/` 會讓「這個檔案屬於哪個系統」失去單一目錄這條線索,尤其 `cards/` 裡已有一個同樣以 `Affinity` 開頭命名的既有介面(`AffinityWritePort`),混放容易讓下一個人分不清楚哪些是卡牌系統的契約、哪些是池本體。
3. 已用 `Glob` 確認 `src/gameplay/` 底下目前沒有 `affinity_pool/` 子目錄,不與任何既有結構衝突。

本 story 建立的檔案(`affinity_types.gd`)落在此目錄。S-008(丙類寫入轉接器)**不**落在此目錄——它是 `src/gameplay/cards/` 既有介面 `AffinityWritePort` 的具體實作,理由見該張 story。

## Implementation Notes

出自 ADR-0002:

1. **機制二(共用列舉的檔案歸屬)**:`Pair`/`Character`/`Source` 三個列舉必須集中定義於 `affinity_types.gd`,以 `class_name AffinityTypes` 包裝——GDScript 沒有「不透過任何 class 包裝、跨檔案可見的裸列舉」這回事,若三者裸露宣告卻被其他檔案未經限定地直接使用,不會通過編譯。所有其他類別一律以 `AffinityTypes.Pair`、`AffinityTypes.Character`、`AffinityTypes.Source` 完整限定存取。
2. **enum 成員(ADR-0002 機制二逐字)**:

   ```gdscript
   enum Character { CHARACTER_1, CHARACTER_2, CHARACTER_3, CHARACTER_4, CHARACTER_5 }
   enum Pair {
       C1_C2, C1_C3, C1_C4, C1_C5,
       C2_C3, C2_C4, C2_C5,
       C3_C4, C3_C5,
       C4_C5,
   }
   enum Source { COMBAT_CARD, SUPPORT_CONVERSATION, STORY_EVENT }
   ```

   五個 `Character` 值是**佔位識別碼**(ADR-0002 Constraints:角色系統尚未設計)——呼叫端一律以 `AffinityTypes.Character` 列舉值溝通,不假設任何具體名稱字串。
3. **`static func pair_of(a: Character, b: Character) -> Pair`**:正規化建構函式,內部以固定查表(而非依賴呼叫順序)消除 `pair_of(A,B)` 與 `pair_of(B,A)` 的歧義。**前置條件(機制四之四)**:呼叫端必須先以 `AffinityTypes.is_valid_character()` 驗證兩個參數——`pair_of()` 回傳裸 `Pair`,不可為 `null`,結構上容不下拒絕碼;本函式對非法序數的行為**未定義**。已登記禁令 `unvalidated_character_into_pair_of`。
4. **三個公開靜態驗證器(機制四之四)**:

   ```gdscript
   static func is_valid_character(c: Character) -> bool   # Character.values().has(c)
   static func is_valid_pair(p: Pair) -> bool
   static func is_valid_source(s: Source) -> bool
   ```

   內部以 `.values().has()` 實作(探針 D 實測:對越界輸入乾淨回傳 `false`、不中止)。**這是呼叫端低頻使用的一份**;`AffinityDataPool`(S-004 起)內部另有一份讀 `_init()` 快取的驗證邏輯(熱路徑,理由是 `.values()` 每次呼叫都重新配置一個新 `Array`,而讀取函數是每回合多次的熱路徑)。**兩條路徑的檢查語意必須完全相同**——ADR-0002 Validation Criteria #13 要求對同一組輸入(合法值、`-1`、`999`)斷言兩條路徑回傳一致結果。本 story 只交付 `AffinityTypes` 這一份,一致性測試待 S-004 落地後一併驗證。
5. 🔴 **陷阱一(EPIC.md 原文,本 story 是它第一次被寫下來)——roster id(1~5)與 enum 序數(0 起算)差 1**:`assets/data/units/vs01_roster.txt` 把 id 1~5 釘死為甲乙丙丁戊;上方 `enum Character` 的 `CHARACTER_1` 序數是 0。**ADR-0002 全文沒有任何一句話建立這個對映**(它寫的是「佔位識別碼,角色系統定案時只需重新命名 enum 值」,當時 roster 編號還不存在)。**本 story 只定義 enum 本身,不建立這個對映**——查表或 `id - 1` 轉換的責任在 S-008(丙類寫入轉接器)。此處記錄的目的,是讓實作者一開始就知道「`Character` 的序數不等於 roster id」,不要在 enum 成員順序、命名或任何輔助函式上做出暗示兩者相等的假設。
6. 🔴 **陷阱三(EPIC.md 節錄)——來源字串大小寫不一致**:`AffinityTypes.Source.COMBAT_CARD` 是**大寫**列舉成員名;技能卡牌系統既有的 `AffinityWritePort.SOURCE_COMBAT_CARD`(`src/gameplay/cards/affinity_write_port.gd`)是**小寫**字串常數 `&"combat_card"`。兩者是兩個獨立世界的常數,本 story 不做任何轉換,只確保 `AffinityTypes.Source.keys()` 回傳的是大寫名稱。🔴 **絕不可寫 `AffinityTypes.Source[untrusted_string]`**(已登記禁令 `raw_enum_name_subscript_from_untrusted_string`)——動態非法字串索引會**當場中止呼叫函式**(探針 C 實測)。許可形狀只有三種:`keys().has()`、`find_key()`、`values().has()`。
7. 🔴 **陷阱二(EPIC.md 節錄)——型別化 enum 參數擋不住越界整數,也擋不住浮點截斷**:`is_valid_*()` 系列必須用 `.values().has()`,不得依賴「呼叫端把值賦給型別化變數」這件事本身能擋下非法輸入——探針 B 已實測越界 int(`-1`/`999`)原封不動抵達函式本體、零錯誤零檢查;夾帶 `float 3.7` 會不中止、靜默截斷為合法序數 `3`。`is_valid_*()` 是**唯一防線**,不是防禦層。
8. 🔴 **陷阱四(EPIC.md 節錄)——新增 `class_name` 後,本機第一次跑測試前必須先 import**:本 story 一次引入 `AffinityTypes`(後續 story 陸續再引入 4~5 個)。依 `.claude/docs/coding-standards.md`(2026-08-26 實測,`Board`/`LineOfSight` 進庫當天兩位專家各自踩到),本機第一次跑測試前須先執行一次:

   ```
   godot --headless --path . --import
   ```

   不做的話,runner 會以 `Parse Error: Identifier "AffinityTypes" not declared in the current scope` 失敗。此為一次性,每個工作副本各一次。**CI 不受此限**(每次從頭 checkout,action 自己會 import)。
9. **命名慣例**:`AffinityTypes` 帶 `Affinity` 字首,ADR-0002 Risks 表已登記過此為低碰撞風險的一次性命名慣例,`src/` 目前無碰撞對象。
10. 🔴 **靜態型別、公開方法需文件註解**(專案級硬性規則):`AffinityTypes` 全部為 `static func`,無實例狀態,但仍須為每個公開方法寫文件註解(`##`)。
11. 🔴 **今天基線**(供對照):574 test cases / 44 套件全部執行 / 0 errors / 0 orphans / 1 failure(`affinity_phi_provider_test.gd` 的 `test_phi_reflects_a_pairing_polarity_flip_made_after_construction`,**刻意留紅、已核准、不要動**)。本 story 落地後,執行條數應變為 574 + 本 story 新增測試數,**不得只看 exit code**——EPIC.md 陷阱五記載過「測試存在、看起來全綠、實際一條都沒跑」的前例,新增測試層級/子目錄時務必核對執行條數確實增加。

## Acceptance Criteria

*以下為 `design/gdd/affinity-data-pool.md` 的條文**原文轉錄**,未改寫:*

- **AC-27a**: **GIVEN** 系統的配對列舉(enum)定義,**WHEN** 靜態檢視其定義,**THEN** 恰有 10 種合法值(對應 5 名固定主角兩兩組合,C(5,2)=10)。
- **AC-56**: **GIVEN** 本系統的 `Pair` enum,**WHEN** 透過持久化用途的名稱存取器(而非 enum 本身的序數)查詢任一合法配對值,**THEN** 每個值皆回傳一個獨立、穩定的字串名稱,且該名稱與 enum 定義順序(序數)無關——即使未來 enum 定義順序調整(新增項目插入中間、重構排序),既有配對的字串名稱維持不變。此 AC 確認 `Pair` enum 本身提供存檔系統 Core Rules #10 所需的字串名稱持久化基礎,不依賴存檔系統單方面轉換——若本系統的 `Pair` enum 實作只暴露序數、沒有穩定的名稱存取器,存檔系統即使遵循自己的 Core Rules #10,也無法從本系統取得可靠的持久化名稱來源。
- **AC-57**(2026-08-05 第三輪新增,與 AC-56 對稱,回應 `save-system.md` creative-director 資深審查發現——`source_i` 先前未被任何一輪的索引鍵治理規則涵蓋): **GIVEN** 本系統用於標記 Delta Log 記錄來源的來源類別列舉,**WHEN** 透過持久化用途的名稱存取器(而非該列舉本身的序數)查詢任一合法來源類別值,**THEN** 每個值皆回傳一個獨立、穩定的字串名稱,且該名稱與列舉定義順序(序數)無關——即使未來列舉定義順序調整,既有來源類別的字串名稱維持不變。此 AC 確認來源類別列舉本身提供存檔系統 Core Rules #10(第三輪擴大範圍)所需的字串名稱持久化基礎,理由與 AC-56 對 `Pair` 的論證完全對稱。

## Test Evidence

**型別**:Logic
**測試檔**(獨立單一檔,依 EPIC.md 陷阱五「一張 story 至少一個獨立測試檔」):
`tests/unit/gameplay/affinity_pool/affinity_types_test.gd`

預期涵蓋:

- `test_pair_enum_has_exactly_ten_values`(AC-27a)
- `test_pair_find_key_returns_stable_name_independent_of_ordinal`(AC-56)
- `test_source_find_key_returns_stable_name_independent_of_ordinal`(AC-57)
- `test_is_valid_pair_rejects_out_of_range_ordinal`(`-1`、`999`)
- `test_is_valid_character_rejects_out_of_range_ordinal`
- `test_is_valid_source_rejects_out_of_range_ordinal`
- `test_pair_of_normalizes_argument_order`(`pair_of(A,B)` 與 `pair_of(B,A)` 回傳相同 `Pair`)

## Out of Scope

- **roster id ↔ `Character` 序數的實際對映查表**(陷阱一的解法本身)—— 屬 S-008,本 story 只記錄陷阱存在。
- **`AffinityRecord`/`AffinityRecordList`** —— 屬 S-002。
- **`AffinityDataPool` 內部讀 `_init()` 快取的驗證器**(熱路徑那一份,與本 story 的 `is_valid_*()` 語意須一致)—— 屬 S-004,一致性測試待其落地後才可執行。
