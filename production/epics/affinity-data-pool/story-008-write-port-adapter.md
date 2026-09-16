# Story S-008:丙類寫入轉接器 —— `AffinityWritePort` 的第一個真實實作

> **Epic**:好感度數值池(Delta Log)—— 資料層(`production/epics/affinity-data-pool/EPIC.md`)
> **型別**:Integration
> **狀態**:✅ Complete(狀態標記 2026-09-16 補正 —— 實作早已完成,但本欄一直停在 `Ready`)
> **估時**:M
> **依賴**:S-001、S-003、S-004

## Context

- **GDD(本系統)**:`design/gdd/affinity-data-pool.md`——本系統 GDD 對本 story 的驗收**零管轄**,見下方 Acceptance Criteria 節的出處說明。
- **對接面**:`src/gameplay/cards/affinity_write_port.gd`(技能卡牌系統 Story 004 已提交的抽象介面,**不得修改其語意**)——本 story 的產物是它的第一個具體子類別。
- **Governing ADR**:ADR-0002(**Accepted**)機制四(`append_record()` 七類拒絕)、機制四之三(呼叫端型別義務)、機制四之四(序數驗證)。**本 story 是機制四之三「呼叫端義務目前是孤兒」這句話第一次有主人接手的地方。**
- **Engine**:Godot 4.7.1

## 目標

寫一個 `AffinityWritePort` 的具體實作,內部持有一個真正的 `AffinityDataPool` 參照,把技能卡牌系統既有的呼叫(`character_a`/`character_b` 為 roster id、`m: int`、`source` 恆為 `SOURCE_COMBAT_CARD`)轉換成 `AffinityDataPool.append_record()` 需要的型別(`AffinityTypes.Pair`/`float`/`AffinityTypes.Source`)。做完之後,「打一張丙類卡」這個動作**第一次有地方可以真的寫進 Delta Log**——在此之前,`NullAffinityWritePort` 是唯一存在的實作,永遠什麼都不做。

## 🔴 本 story 決定的原始碼目錄路徑

**`src/gameplay/cards/`(不是 `affinity_pool/`)。**

理由:本轉接器是 `AffinityWritePort` 這個**卡牌系統既有介面**的具體實作,`affinity_write_port.gd`/`null_affinity_write_port.gd` 兩個既有檔案都在 `src/gameplay/cards/`——把轉接器放在同一個目錄,讓「這個介面有哪些實作」這件事對下一個人一眼可見(`ls src/gameplay/cards/*affinity_write_port*`),而不是分散在兩個目錄裡靠記憶找。它依賴 `src/gameplay/affinity_pool/` 的 `AffinityDataPool`/`AffinityTypes`,這是一條正常的跨目錄依賴,不構成理由把它搬過去。

**檔名**:`affinity_pool_write_port.gd`(區別於既有的 `null_affinity_write_port.gd`)。

## Implementation Notes

出自 `affinity_write_port.gd` 檔頭(**必讀,逐字整理如下**)與 EPIC.md 五個陷阱:

1. 🔴 **陷阱一(EPIC.md 原文,本 story 是它的解法歸屬處)——roster id(1~5)與 enum 序數(0 起算)差 1**:`assets/data/units/vs01_roster.txt` 把 id 1~5 釘死為甲乙丙丁戊;`AffinityTypes.Character.CHARACTER_1` 的序數是 0。**ADR-0002 全文沒有任何一句話建立這個對映**。**本 story 必須是明文查表或 `id - 1`,不得直接把 roster id 當序數丟進去**——直接丟入的後果:`5`(戊)落在合法範圍外、`1`(甲)變成乙。**必須把這個對映寫進程式碼註解**,不要指望下一個人也推理出同一個答案。轉換後**必須**呼叫 `AffinityTypes.is_valid_character()` 驗證(見下方陷阱二),不可假設 `id - 1` 這個算式本身就是驗證。
2. 🔴 **陷阱二(EPIC.md 節錄)——進 `AffinityTypes.pair_of()` 之前必須先驗證**:兩個 roster id 各自轉換成 `Character` 序數後,**必須先呼叫 `AffinityTypes.is_valid_character()` 驗證兩個參數,才可以呼叫 `pair_of()`**——`pair_of()` 回傳裸 `Pair`,結構上沒有拒絕通道,對非法序數的行為未定義。已登記禁令 `unvalidated_character_into_pair_of`。
3. 🔴 **陷阱三(EPIC.md 節錄)——本路徑最乾淨的做法是根本不做字串轉換**:埠的 `SOURCE_COMBAT_CARD: StringName = &"combat_card"` 是小寫;`AffinityTypes.Source.COMBAT_CARD` 是大寫列舉成員。**這個埠只有一個合法來源值**——直接映射成常數(`AffinityTypes.Source.COMBAT_CARD`),不要寫任何字串比對或字串轉列舉的邏輯,那條路徑在本轉接器裡完全不需要存在。
4. **`m: int → float` 的單一收斂點**:`affinity_write_port.gd` 檔頭已裁決 `m: int` 留在埠本身(比照 `Card.affinity_magnitude`);`AffinityRecord.m: float` 是池的欄位型別。**`int → float` 的拓寬轉換在本轉接器這一個接縫發生**(`float(m)`),不得散佈到卡牌系統的其他呼叫端。
5. 🔴 **型別邊界的雙重防線(檔頭原文,機制四之三)**:「型別錯誤在 `append_record()` 本身會**中止呼叫端函式**,而不是回傳拒絕碼——本埠的 `Rejection` 列舉無法表達這種失敗模式,轉接器是唯一需要防禦這個邊界的地方(用 `typeof()` 窄化任何 `Variant`,在它抵達真正的 `append_record()` 之前)。」**本轉接器的輸入本來就是靜態型別的 `int`/`int`(roster id 各自)**,不是 `Variant`,但**轉換出的 `AffinityTypes.Character`/`Pair`/`Source` 在傳進 `append_record()` 前,仍必須先過本 story 自己的序數驗證**(陷阱二),不能假設「輸入是 `int` 就安全」——`id - 1` 算出的整數若超出 5 名角色範圍(例如上游傳入 roster id `0` 或 `6`),`AffinityTypes.is_valid_character()` 會擋下,而不是讓一個越界序數流進 `pair_of()`。
6. **`Rejection` 對映(埠的 4 值 → 池的 7 值,反之亦然)**:

   | 埠側 `AffinityWritePort.Rejection` | 池側 `AffinityDataPool.WriteRejection` | 對映方式 |
   |---|---|---|
   | `NONE` | `NONE` | 直接對映 |
   | `ZERO_MAGNITUDE` | `ZERO_AMPLITUDE` | 直接對映——`m: int` 造不出 NaN/±Infinity,`NON_FINITE_AMPLITUDE` 結構上不可達,不需要對映路徑 |
   | `DEAD_PAIR_FORBIDDEN` | `DEAD_PAIR_COMBAT_CARD_FORBIDDEN` | 直接對映 |
   | `INVALID_PAIR` | **不對映自池側同名值** | 見下方陷阱九,埠側 `INVALID_PAIR` 由 `PermanentAffinityWriteRules.play()` 在碰到本轉接器**之前**就決定,本轉接器不產生它 |
   | `NO_PORT_CONFIGURED` | 不適用 | 本轉接器**永遠不回傳**此值——它是 `NullAffinityWritePort` 專屬的哨兵,見該檔頭 |

7. 🔴 **限制第 9 條(EPIC.md 原文,本 story 的核心紀律)——`INVALID_PAIR` 在接縫兩側同名不同義**:埠側 = 「這兩人在劇情上沒有關係線」(由 `PermanentAffinityWriteRules.play()` 在碰埠**之前**決定);池側 = 「配對序數不在 10 個合法值內」。**本轉接器不可把池的 `INVALID_PAIR` 直接轉送成埠的 `INVALID_PAIR`**——那會把一個程式錯誤讀成一個劇情事實。正解是靠陷阱二的驗證讓池側那個值**永遠不會發生**——即,若本轉接器的 roster id → `Character` → `Pair` 轉換鏈全程正確驗證,`append_record()` 理論上不應該回傳 `INVALID_PAIR`;若它真的回傳了,代表本轉接器自己的轉換邏輯有 bug,**不應該被吞掉或轉送,應該視為一個未預期的內部錯誤**(可用斷言/`push_error()` 曝光,但不對外回傳埠的 `INVALID_PAIR`)。
8. 🔴 **限制第 8 條(EPIC.md 原文,登記給協調者,本 story 不處置)——埠的 `Rejection` 列舉裝不下 `SERIALIZATION_WINDOW_ACTIVE`**:埠 4 值(不含 `NO_PORT_CONFIGURED` 則 3 值可能由本轉接器產生)、池 7 值。`NON_FINITE_AMPLITUDE`/`INVALID_SOURCE` 在本轉接器這條路徑上結構不可達(見上表),但 `SERIALIZATION_WINDOW_ACTIVE` **只是今天不可達,不是結構不可達**——等 S-014(序列化生命週期,切片外)與存檔系統都在,池就會丟一個埠承載不了的值回來。**本 story 不新增埠的列舉值,也不假裝這個情況不存在**——若 `append_record()` 回傳 `SERIALIZATION_WINDOW_ACTIVE`(今天不會發生,因為 S-014 未落地,`_serialization_tokens` 恆空),本轉接器應以斷言/`push_error()` 曝光為未預期分支,不得靜默對映成埠的任何既有值。此限制已由 EPIC.md 登記給協調者處置(三條路:新增埠列舉值 / 折成既有值〔會說謊〕/ 明文登記待 S-014 當天一併處理),**本 story 不發起裁決**。
9. 🔴 **陷阱四(EPIC.md)**:本 story 不新增新的 `class_name`(轉接器本身是否需要 `class_name` 視實作決定;若需要,須與既有 `AffinityTypes`/`AffinityRecord`/`AffinityRecordList`/`AffinityDataPool` 檢查全域唯一性),若這是工作副本第一次執行本張測試,仍須確認已 import 過。
10. **依賴注入**:本轉接器的建構子接收一個 `AffinityDataPool` 參照(依 ADR-0002 機制一,DI 非 Autoload)。本 story **不負責**這個池實例從哪裡來、由誰持有——那是 S-009(接線)的範圍。本 story 只需要能在單元測試裡自行 `new()` 一個 `AffinityDataPool` 傳入即可獨立驗證。

## Acceptance Criteria

🔴 **本 story 的 GDD AC 歸屬為 0——但零 AC 不等於沒有驗收標準。**

EPIC.md 已登記:本 story 的驗收在**對面那份 GDD**(`design/gdd/skill-card-system.md`),本系統 GDD 不管轄轉接器。以下**原文轉錄**自 `design/gdd/skill-card-system.md` 的 `## Acceptance Criteria` 章節(表格形式,已轉錄為條列以利閱讀,文字本身未改寫):

- **AC-6**(出自 `design/gdd/skill-card-system.md`,非本系統 GDD):打出丙類 → 好感度數值池新增一筆記錄,`source` 欄為 `combat_card`、幅度為該卡定義值。**型別**:Logic
- **AC-7b**(出自 `design/gdd/skill-card-system.md`,非本系統 GDD):繞過選擇介面,直接以**陣亡配對**呼叫好感度數值池的丙類寫入介面 → **回傳驗證錯誤,記錄筆數不變** —— 第二道防線。Edge Cases 明文要求兩層,AC-7 只驗了第一層。**型別**:Logic(邊界)
- **AC-8c**(出自 `design/gdd/skill-card-system.md`,非本系統 GDD):**繞過選取介面,直接以非 canon 配對(含戊者)呼叫寫入** → **回傳驗證錯誤,記錄筆數不變**。**2026-09-10 新增**,因該日裁決「配對由玩家選」開了這條路徑 —— 在此之前配對由卡片寫死,非 canon 配對進不到寫入函式。⚠️ **與 AC-7b 是同一形狀的兩種非法**(7b 驗陣亡、8c 驗非 canon),**而上游對兩者的態度相反**:池會拒絕陣亡配對,**但對「角色設定關係線」零認知,不會拒絕非 canon 配對** —— 故 8c 沒有第二道防線,唯一防線就在本系統。**型別**:Logic(邊界)

⚠️ **這三條的落點是引自 `production/epics/skill-card-system/EPIC.md` 的「驗收條件對照」表,不是讀那八張 story 檔本體**(EPIC.md 原文提醒)。需要逐條細節時請打開 `design/gdd/skill-card-system.md` 與 `production/epics/skill-card-system/story-004-permanent-write-port.md`。

## Test Evidence

**型別**:Integration
**測試檔**(獨立單一檔):`tests/integration/gameplay/cards/affinity_pool_write_port_test.gd`

預期涵蓋:

- `test_playing_combat_card_appends_record_with_combat_card_source_and_defined_magnitude`(AC-6)
- `test_dead_pair_write_via_port_returns_validation_rejection_with_no_count_change`(AC-7b)
- `test_non_canon_pair_write_via_port_returns_validation_rejection_with_no_count_change`(AC-8c)
- `test_roster_id_to_character_ordinal_mapping_is_off_by_one_and_validated`(陷阱一——正面驗證 roster id 1/5 分別對映到 `CHARACTER_1`/`CHARACTER_5`,且該對映經過驗證,不是裸算式)
- `test_roster_id_out_of_range_is_rejected_before_reaching_pair_of`(陷阱二——構造一個 roster id 超出 1~5 範圍的輸入,斷言在 `pair_of()` 之前就被擋下,不產生未定義行為)
- `test_port_never_returns_pool_invalid_pair_as_port_invalid_pair`(限制第 9 條——若能構造出池側 `INVALID_PAIR`,斷言轉接器不會把它轉送成埠的 `INVALID_PAIR`)
- `test_int_magnitude_widens_to_float_without_precision_loss`(int → float 收斂點)

## Out of Scope

- **`AffinityDataPool` 實例的生命週期與注入來源**——屬 S-009(接線)。
- **`SERIALIZATION_WINDOW_ACTIVE` 的埠側表達方式**——登記給協調者,本 story 不裁決(見限制第 8 條)。
- **`PermanentAffinityWriteRules.play()` 本身的行為**(它決定埠側 `INVALID_PAIR`/陣亡檢查發生在轉接器之前)——那是技能卡牌系統既有的既完成程式碼,本 story 不修改它。
- **本系統 GDD 的任何 AC**——本 story 零涵蓋,已於上方明文說明。
