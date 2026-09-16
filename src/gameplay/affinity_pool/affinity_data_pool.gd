# AffinityDataPool —— 好感度數值池(Delta Log)資料層的核心容器。
#
# 設計文件:design/gdd/affinity-data-pool.md
#   - Core Rules #1「陣亡標記表」段落、「前進戰役刻度」段落(t_now 現值慣例)、
#     「效能介面要求」(依配對索引存取,O(n_p))
#   - Core Rules #2「寫入規則」與「陣亡配對的寫入限制」(七類拒絕情境之一)
#   - Core Rules #3「陣亡配對的預設查詢時點」對 t_death(p) 的定義
#   - Edge Cases(幅度為 0/來源非法/配對非法/NaN 一律拒絕、不靜默糾正)
# 治理 ADR:docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md
#   - 機制二(_records 容器與建構子預填,與 _death_marks 的預填策略相反)
#   - 機制三(陣亡標記表——獨立結構,O(1))
#   - 機制四(寫入路徑——7 類拒絕情境)
#   - 機制四之二(型別保證三層與兩條邊界規則)
#   - 機制四之三(驗證順序與呼叫端型別義務——本方法不涵蓋型別非法)
#   - 機制四之四(8 個帶 enum 參數的入口統一序數驗證,R7-P1 修法列表第 2 項;
#     本 story 涵蓋其中入口 1)
# Story:
#   - production/epics/affinity-data-pool/story-003-death-marks.md(S-003)
#   - production/epics/affinity-data-pool/story-004-pool-skeleton-and-write-path.md(S-004)
#   - production/epics/affinity-data-pool/story-005-campaign-tick.md(S-005)
#
# 🔴 本檔是本 epic 的序列化點(EPIC.md「開工順序」)——S-003/004/005/006/007
# 全部往同一個檔案裡加東西,彼此之間沒有真正的平行機會。
#
# S-003 交付範圍:
#   - _death_marks 欄位、notify_death()、t_death()
#   - DeathNotifyResult 列舉本體(僅 NONE / DUPLICATE_DEATH_NOTIFICATION /
#     INVALID_CHARACTER 三分支落地——SERIALIZATION_WINDOW_ACTIVE 只保留檢查點
#     結構,依賴 S-014(切片外)的序列化生命週期權杖集合,今天恆不可達)
#   - _t_now 欄位本身(本 story 只需要它以 int 0 存在並可讀)
#
# S-004 交付範圍(本次新增):
#   - _records 欄位、建構子 _init() 預填全部 10 對配對的空 AffinityRecordList
#   - _pair_ordinals / _character_ordinals / _source_ordinals 三個序數快取
#   - 三個私有序數驗證器(_validate_pair_ordinal 等,機制四之四)
#   - WriteRejection 列舉本體(僅 NONE / ZERO_AMPLITUDE / NON_FINITE_AMPLITUDE /
#     INVALID_SOURCE / INVALID_PAIR / DEAD_PAIR_COMBAT_CARD_FORBIDDEN 六分支落地
#     ——SERIALIZATION_WINDOW_ACTIVE 沿用 S-003 已建立的 _serialization_tokens
#     檢查點,今天同樣恆不可達,不宣稱測過)
#   - append_record() 六步驗證
#   - 🔴 record.c(戰役刻度)本 story(S-004)恆寫入佔位值 0——真正的戰役刻度
#     計數器由 S-005 引入,本 story 只保證欄位存在、寫入後不再變動
#
# S-005 交付範圍(本次新增):
#   - _campaign_tick_marks 欄位(獨立於 _records 的 append-only 標記列表)
#   - AdvanceRejection 列舉本體(僅 NONE 分支落地——SERIALIZATION_WINDOW_ACTIVE
#     沿用既有的 _serialization_tokens 檢查點,今天恆不可達,不宣稱測過)
#   - advance_campaign_tick():附加當下 _t_now 現值到 _campaign_tick_marks,
#     不遞增 _t_now 本身
#   - _c_now(t_query):Formulas 3c 的 c_now(t_query) 精確定義,內部/私有輔助
#     方法(不對外公開獨立查詢介面——GDD 明文 c_now 隨三個讀取函數的回傳值
#     附帶,S-006/S-007 負責接線)
#   - append_record() 的 record.c 改為呼叫 _c_now() 取得真實現值,S-004 遺留的
#     恆 0 佔位腳手架自本 story起不再成立
#
# 2026-09-15 補件(管理者裁決,非新 story——見 EPIC.md 限制表第 10 條)：
#   - [signal entry_appended] 本體與 append_record() 成功路徑的 emit。
#     S-004 原始交付漏了這個訊號(工作單全文對它零命中),ADR-0002 機制七/
#     TR-affinity-024 明文要求。管理者裁決依據:card-play-interface epic
#     需要即時反映關係變化,是這個訊號第一個看得見的使用者。
#     🔴 這不是把訊號升格成契約——ADR-0002 原文（TR-affinity-024)明寫
#     此訊號是「實作慣例決策，非已承諾的契約」，下游不得假設它會被
#     其他 ADR 或未來重構保留。見下方 [signal entry_appended] 文件註解。
#
# S-006 交付範圍(本次新增,production/epics/affinity-data-pool/story-006-*.md):
#   - ReadRejection 統一列舉本體(六值全數宣告;本 story 只讓 NONE/INVALID_PAIR/
#     INVALID_T_QUERY_TYPE/FUTURE_TIME_QUERY 四值在三個讀取函數內可達——
#     EMPTY_HYPOTHETICAL_SET/DEAD_PAIR_NOT_ALLOWED 僅預留位置給 S-012)
#   - AffinityReadResult / ShapeFeatureResult 兩個結果型別(ADR-0002 2026-08-24
#     同檔強制規則:並列 inner class,不獨立成檔、不掛 class_name——見機制五
#     附近的「同檔裸引用 COMPILED OK / 跨檔裸引用 Parse Error」探針)
#   - combat_strength_read() / narrative_depth_read() / shape_feature_read()
#     三個入口:t_query 型別閘門(match typeof() 三分支,case 順序不可交換)、
#     pair 序數驗證(機制四之四入口 3–5)、拒絕分流(_rejected_read_result()/
#     _rejected_shape_feature_result() 統一哨兵值)。
#     🔴 三個函數對合法輸入(rejection == NONE)只回傳佔位中性值——加權計算
#     本身、n(p)=0 的完整合法回傳值、陣亡配對條件式預設查詢時點的實際值,
#     全部屬 S-007,本 story 不宣稱這些值現在就有意義。
#
# 尚未在此檔出現、屬於後續 story 的東西(避免下一個人誤以為漏寫):
# 三個讀取函數的真正加權計算邏輯(S-007)、can_write()、
# export_state()/import_state()——全部不在本 story 範圍。
# (advance_campaign_tick() 已於 S-005 交付;三個讀取函數的入口/閘門/拒絕分流
# 已於 S-006 交付,不再列在此處——只有「真正的計算」還沒有。)
class_name AffinityDataPool
extends RefCounted


## [method append_record] 成功寫入一筆記錄時發出(ADR-0002 機制七、機制四逐字:
## 「全數通過 → 建立 AffinityRecord…回傳 WriteRejection.NONE,並 emit
## entry_appended(pair, record) 訊號」)。[param pair] 為寫入的配對、[param record]
## 為剛附加進 Delta Log 的記錄本體(與 [code]_records[pair][/code] 最新一筆同一個實例)。
##
## 🔴 [b]任何拒絕路徑一律不 emit[/b]——七類 [enum WriteRejection] 分支(含
## [constant WriteRejection.SERIALIZATION_WINDOW_ACTIVE] 恆不可達分支)皆不觸發本訊號,
## 對應 [method append_record] 逐一頁首的「不遞增 t_now、不附加記錄」慣例:沒有附加就
## 沒有訊號。
##
## 🔴 [b]本訊號是實作慣例決策,不是已承諾的契約[/b](ADR-0002 追溯編號
## `TR-affinity-024` 逐字:「entry_appended 信號為實作慣例,非承諾契約……明文下游
## 不得假設其被保留」)。下游(例如卡牌介面用它即時反映關係變化)**不得假設**這個
## 訊號的存在會被其他 ADR 或未來重構保留——今天補上它是 2026-09-15 管理者裁決
## (依據:card-play-interface epic 是它第一個看得見的使用者),不是把它升格為
## 正式介面契約。若未來移除或改變它的語意,呼叫端沒有任何 ADR 保證可以援引。
signal entry_appended(pair: AffinityTypes.Pair, record: AffinityRecord)


## 陣亡通知介面 [method notify_death] 的四值回傳結果。
##
## 🔴 本 story(S-003)只落地 [constant NONE] / [constant DUPLICATE_DEATH_NOTIFICATION] /
## [constant INVALID_CHARACTER] 三個分支。[constant SERIALIZATION_WINDOW_ACTIVE]
## 依賴 S-014(切片外)的序列化生命週期權杖集合,今天恆不可達——見
## [method notify_death] 內的檢查點與 [member _serialization_tokens] 佔位欄位的
## 文件註解。不宣稱這個分支今天被測過(EPIC.md 限制表第 3 條)。
enum DeathNotifyResult {
	NONE,
	SERIALIZATION_WINDOW_ACTIVE,
	DUPLICATE_DEATH_NOTIFICATION,
	INVALID_CHARACTER,
}


## 寫入介面 [method append_record] 的回傳結果(機制四,fail-loud——任何非法輸入一律
## 明確拒絕並回傳可判斷的拒絕碼,不靜默糾正、不靜默丟棄、不允許 NaN 等以任何形式進入
## Delta Log)。
##
## 🔴 本 story(S-004)只落地六個結構上可達的分支。[constant SERIALIZATION_WINDOW_ACTIVE]
## 依賴 S-014(切片外)的序列化生命週期權杖集合——與 [enum DeathNotifyResult] 的同名分支
## 共用同一顆檢查點欄位([member _serialization_tokens]),今天恆為空集合、此分支恆不可達。
## 不得刪除 [method append_record] 對這顆欄位的檢查(S-014 落地時要重新推導整個驗證順序的
## 成本比留著這個恆假分支高),也不得在任何測試/註解裡宣稱這個分支今天被測過。
##
## 🔴 本 ADR 刻意不新增 `INVALID_TYPE` 分支(機制四「陷阱二」/機制四之三)——上游若夾帶
## 型別錯誤但數值上是合法序數近親的輸入(例如 `float 3.7`),呼叫端**不會中止**,參數會被
## 靜默截斷成合法序數(`3`);值域檢查看到的已經是「合法的 3」,無從得知它原本是型別錯誤的
## 浮點數。這一類失敗結構上無法被本列舉表達,唯一防線是呼叫端義務(ADR-0002 機制四之三)
## ——本方法不對此負責,見 S-008(丙類寫入轉接器)。
##
## 🔴 [constant INVALID_PAIR] 在寫入端接縫兩側同名不同義:埠側(S-008 的
## `AffinityWritePort.Rejection.INVALID_PAIR`,尚未存在)= 「這兩人劇情上沒有關係線」;
## 本值 = 「配對序數不在 10 個合法值內」。**S-008 不可把兩者當同一件事直接轉送**——正解是
## 靠 S-001 的驗證器讓本值永遠不會發生(S-008 在呼叫 [method append_record] 之前,自己的
## roster id → [enum AffinityTypes.Character] 對映邏輯已經先驗證過)。
enum WriteRejection {
	NONE,
	SERIALIZATION_WINDOW_ACTIVE,      # S-014(切片外)接口,今天恆不可達,見上方說明
	ZERO_AMPLITUDE,                    # m == 0.0
	NON_FINITE_AMPLITUDE,              # m 為 NaN 或 ±Infinity
	INVALID_SOURCE,                    # source 不在三個合法值之內
	INVALID_PAIR,                      # pair 不在 10 對固定組合內——見上方接縫語意警告
	DEAD_PAIR_COMBAT_CARD_FORBIDDEN,   # 配對已符合 t_death(pair) 條件,且 source == COMBAT_CARD
}


## 前進戰役刻度介面 [method advance_campaign_tick] 的回傳結果(ADR-0002 機制四之四,
## 8 個帶 enum 參數入口清單之一;本方法無參數,但回傳值本身是 enum,故仍屬同一清單
## 統一序數驗證慣例的延伸)。
##
## 🔴 本 story(S-005)只落地 [constant NONE] 分支。[constant SERIALIZATION_WINDOW_ACTIVE]
## 依賴 S-014(切片外)的序列化生命週期權杖集合——與 [enum DeathNotifyResult] /
## [enum WriteRejection] 的同名分支共用同一顆檢查點欄位([member _serialization_tokens]),
## 今天恆為空集合、此分支恆不可達。不得刪除 [method advance_campaign_tick] 對這顆欄位的
## 檢查,也不得在任何測試/註解裡宣稱這個分支今天被測過。
enum AdvanceRejection {
	NONE,
	SERIALIZATION_WINDOW_ACTIVE,
}


## 三個真實讀取函數([method combat_strength_read]/[method narrative_depth_read]/
## [method shape_feature_read])與公式四預判讀取([code]speculative_read()[/code],
## S-012、切片外)共用的統一拒絕碼(ADR-0002 機制五、機制五之二)。
##
## 🔴 本 story(S-006)只讓前四個分支([constant NONE]/[constant INVALID_PAIR]/
## [constant INVALID_T_QUERY_TYPE]/[constant FUTURE_TIME_QUERY])在三個真實讀取
## 函數內可達。後兩個分支([constant EMPTY_HYPOTHETICAL_SET]/
## [constant DEAD_PAIR_NOT_ALLOWED])僅供 S-012 的 [code]speculative_read()[/code]
## 使用——本 story 只保留列舉成員位置,避免該 story 落地時需要變動列舉型別本身
## (工作單 Out of Scope 第 4 項),不宣稱本 story 的任何分支會產生這兩個值。
enum ReadRejection {
	NONE,
	INVALID_PAIR,
	INVALID_T_QUERY_TYPE,
	FUTURE_TIME_QUERY,
	EMPTY_HYPOTHETICAL_SET,   # 僅 speculative_read()(S-012,切片外)
	DEAD_PAIR_NOT_ALLOWED,    # 僅 speculative_read()(S-012,切片外)
}


## 公式一(戰鬥強度)/公式二(敘事深度)讀取結果容器(ADR-0002 機制五)。
##
## 🔴 呼叫端義務(機制五之二、`docs/architecture/control-manifest.md`):必須先
## 檢查 [member rejection] 是否為 [constant ReadRejection.NONE],才可讀取其餘
## 欄位——拒絕時其餘欄位一律為機制五之二表定的哨兵值,不代表任何真實讀值。
##
## 🔴 [member value] 拒絕時為 [constant @GDScript.NAN] 而非 `0.0`——多筆記錄
## 正負相消時,成功呼叫完全可能算出 `0.0`;若用 `0.0` 當拒絕哨兵,呼叫端漏檢
## [member rejection] 時無法區分「淨值為零」與「被拒絕」(工作單 Implementation
## Notes #5)。
##
## 🔴 [member diagnostic_visited_count] 為 QA-only 診斷輸出(見 S-007)——
## 業務邏輯不得依賴此欄位做任何判斷,理由與 [member value] 同(用 `-1` 而非
## `0` 當拒絕哨兵)。
##
## 🔴 [b]同檔強制規則[/b](ADR-0002 2026-08-24 修訂):本型別因跨檔裸引用
## [enum ReadRejection] 在 Godot 4.7.1 是編譯期限制(同檔裸引用 `COMPILED OK`,
## 跨檔裸引用 `Parse Error`,已實機驗證),故必須與 [AffinityDataPool] 同檔宣告
## 為並列 inner class,不得獨立成檔、不得擁有自己的 `class_name`。
##
## 🔴 本 story(S-006)只交付本型別定義本身與拒絕時的哨兵值——成功呼叫時各
## 欄位的真實計算值屬 S-007,本 story 回傳的是佔位中性值(見
## [method combat_strength_read]/[method narrative_depth_read] 文件註解)。
class AffinityReadResult extends RefCounted:
	var rejection: ReadRejection = ReadRejection.NONE
	var value: float
	var t_query: int
	var n_pair: int
	var diagnostic_visited_count: int


## 公式三(形狀特徵)讀取結果容器(ADR-0002 機制五)。呼叫端義務、同檔強制規則
## 皆與 [AffinityReadResult] 相同,見該型別文件註解,不重複。
##
## 🔴 三個 [Dictionary] 欄位([member source_distribution]/[member source_polarity]/
## [member source_absence])拒絕時為 `{}` 而非 `null`——它們的成功型別是非雙態
## [Dictionary],改用 `null` 會讓下游對它們的 `.has()`/`.get()` 操作變成中止風險
## (工作單 Implementation Notes #5)。三個雙態欄位([member time_distribution]/
## [member segment_profile]/[member low_confidence])拒絕時維持 `null`,因為
## `null` 本來就是它們的合法成功值之一([code]n_pair == 0[/code] 時)。
##
## 🔴 七項形狀特徵欄位([member reversal_count] 起算)的實際計算邏輯屬 S-007——
## 本 story 只保證欄位存在、拒絕時哨兵值正確(工作單 Implementation Notes #1)。
class ShapeFeatureResult extends RefCounted:
	var rejection: ReadRejection = ReadRejection.NONE
	var reversal_count: int
	var source_distribution: Dictionary   # {n_cc, n_sc, n_se, p_cc, p_sc, p_se}
	var time_distribution: Variant        # {span_c, spread_ratio} 或 null(n_pair==0)
	var source_polarity: Dictionary       # {net_cc, net_sc, net_se}
	var total_churn: float
	var segment_profile: Variant          # Array 或 null(n_pair==0)
	var low_confidence: Variant           # bool 或 null(n_pair==0)
	var source_absence: Dictionary        # {cc, sc, se} 三態 enum
	var n_pair: int
	var t_query: int
	var c_now: int
	var diagnostic_visited_count: int


## 陣亡標記表:記錄「誰陣亡、陣亡當下的全域好感度寫入計數器現值是多少」。
## 獨立於 Delta Log(`_records`,S-004 加入)之外的結構,鍵查找 O(1)。
##
## 🔴 刻意不預填(ADR-0002 機制二逐字,已登記禁令
## `death_marks_prefill_or_unguarded_read`)——鍵存在本身就是「該角色已陣亡」,
## 預填會讓 5 名角色全部變成已陣亡,摧毀語意。這與 S-004 即將加入的
## `_records` 預填策略【相反】,不要為了一致性套用同一套。一律 `has()` 守衛。
var _death_marks: Dictionary[AffinityTypes.Character, int] = {}

## 全域好感度寫入計數器現值。S-004 的 `append_record()` 每次成功寫入時 +1;
## S-013 的 `import_state()` 會從 `_records` 各配對總筆數重建(執行期快取,
## 不獨立持久化——ADR-0002 機制二逐字)。
##
## 本 story 只需要它以 `0` 存在並可被 [method notify_death] 讀取——AC-73 的
## 「呼叫當下的全域好感度寫入計數器現值」指的正是這個欄位。呼叫
## [method notify_death] 本身**不**遞增它(GDD Core Rules #1「前進戰役刻度」
## 的既有慣例:記錄呼叫當下的現值,不推進計數器本身)。
var _t_now: int = 0

## 戰役刻度標記列表(GDD Core Rules #1「戰役刻度標記列表」段落、ADR-0002 機制二
## 末段)——**獨立於** [member _records](Delta Log)之外的 append-only 結構。
## [method advance_campaign_tick] 每次成功呼叫時附加當下的 [member _t_now] 現值。
##
## 🔴 刻意不預填——與 [member _records] 相反,與 [member _death_marks] 一致
## (戰役尚未開始的最初狀態就是空列表,這是合法初始狀態,不是需要守衛的邊緣情境;
## 讀取邏輯([method _c_now])對空列表天然回傳 0,不需要守衛)。
##
## ⚠️ 本 story 不處理序列化——是否整份持久化或如何重建屬 S-013(切片外)範圍,
## 本檔不對此做任何宣稱。
var _campaign_tick_marks: Array[int] = []

## S-014(切片外)的序列化生命週期權杖集合佔位——今天恆為空,
## [constant DeathNotifyResult.SERIALIZATION_WINDOW_ACTIVE] 分支因此恆不可達
## (EPIC.md 限制表第 3 條:「一條測不出真陽性的分支」)。
##
## 🔴 不得刪除下方 [method notify_death] 對這個欄位的檢查——刪了的話,
## S-014 落地時要重新推導整個驗證順序。也不得在任何 story/測試裡宣稱這個
## 分支今天被測過:它依賴的權杖集合結構上不存在於本切片。
var _serialization_tokens: Dictionary[int, bool] = {}

## 每個合法配對的 Delta Log,依 [enum AffinityTypes.Pair] 索引(機制二,O(1) 鍵查找,
## 滿足 GDD Core Rules #1「效能介面要求」——單一配對查詢只需 `_records[pair]`,
## 不掃描其他配對)。
##
## 🔴 建構子([method _init])預填全部 10 對配對的空 [AffinityRecordList]——與
## [member _death_marks] 刻意不預填【相反】,不要為了一致性統一它們:兩個容器的鍵存在性
## 語意不同([member _death_marks] 的鍵存在本身就是「已陣亡」,預填會摧毀語意;`_records`
## 的鍵只是索引,不預填則「這對還沒有任何記錄」這個合法狀態會變成中止)。
##
## **為何必須預填(探針 A 實測)**:型別化 [Dictionary] 對從未寫入的鍵做 subscript 讀取是
## `SCRIPT ERROR: Out of bounds get index` 並中止呼叫函式——不是 `null`、不是預設值。
## 不預填的話,戰役開場第一次讀取(S-006/S-007)必然中止,而 `n(p)=0` 是 GDD 跨結構
## 不變量第 4 條明文的合法狀態,不是邊緣情境。讀取路徑因此對全部 10 個合法配對零守衛,
## 非法序數在 [method append_record] 入口即被攔下(機制四之四)。
var _records: Dictionary[AffinityTypes.Pair, AffinityRecordList] = {}

## 三個 enum 的合法序數快取(機制四之四),[method _init] 時一次性建立。
##
## 🔴 不得改用 `.values()` 現查——`.values()` 每次呼叫都重新配置一個新 [Array],而
## [method append_record] 與三個讀取函數(S-006/S-007)是每回合多次的熱路徑。也不得改用
## `const`——GDScript 的 `const` 不支援方法呼叫作初始化式,無法用它承載 `.values()` 的結果。
var _pair_ordinals: Array
var _character_ordinals: Array
var _source_ordinals: Array


## 建構子:快取三個 enum 的合法序數列表,並預填 [member _records] 的全部 10 對配對
## (機制二,R7E-2)。見 [member _records] 與 [member _pair_ordinals] 的文件註解——
## 兩者存在的理由不同(前者是「未寫入的鍵讀取會中止」,後者是「`.values()` 重複配置陣列」),
## 但都必須在建構當下一次做完,不能延後到第一次使用時才做。
func _init() -> void:
	_pair_ordinals = AffinityTypes.Pair.values()
	_character_ordinals = AffinityTypes.Character.values()
	_source_ordinals = AffinityTypes.Source.values()
	for p in _pair_ordinals:
		_records[p] = AffinityRecordList.new()


## 記錄角色 [param character] 陣亡,標記值為呼叫當下的 [member _t_now]
## 現值(GDD AC-73,含 `t_now=0` 邊界案例)。[b]此呼叫不遞增 [member _t_now]
## 本身[/b]——呼叫前後 `t_now` 相同。
##
## 回傳 [enum DeathNotifyResult]:
## - [constant DeathNotifyResult.NONE]:成功記錄。
## - [constant DeathNotifyResult.DUPLICATE_DEATH_NOTIFICATION]:
##   [param character] 已存在於陣亡標記表,呼叫被拒,既有標記值不變(AC-74)。
## - [constant DeathNotifyResult.INVALID_CHARACTER]:序數不合法(越界 int
##   或截斷後的浮點——見 [method AffinityTypes.is_valid_character] 文件
##   註解),呼叫被拒、不寫入(ADR-0002 R7-P1「陷阱二」:不擋的話會靜默
##   寫入非法鍵)。
## - [constant DeathNotifyResult.SERIALIZATION_WINDOW_ACTIVE]:🔴 本 story
##   未實作觸發路徑——依賴 S-014(切片外)的序列化生命週期權杖集合,
##   [member _serialization_tokens] 今天恆為空,此分支恆不可達。檢查點
##   結構保留在下方,供 S-014 落地時接上,不宣稱今天測得到。
func notify_death(character: AffinityTypes.Character) -> DeathNotifyResult:
	# 檢查點(S-014 接口,今天恆為 false):序列化/還原非原子視窗期間拒絕
	# 任何會改變狀態的呼叫——理由與 append_record() 七步驗證的第一步一致
	# (避免副作用發生在資料被視為凍結快照的期間)。最先檢查。
	if not _serialization_tokens.is_empty():
		return DeathNotifyResult.SERIALIZATION_WINDOW_ACTIVE

	# 冪等性檢查與序數合法性檢查的相對順序不影響正確性——非法序數必然不在
	# _death_marks 鍵集合中,.has() 對其恆回傳 false(工作單 Implementation
	# Notes #3)。但兩者都必須在寫入 _death_marks[character] = _t_now 之前
	# 完成,否則會靜默寫入非法鍵(ADR-0002 R7-P1「陷阱二」)。
	if _death_marks.has(character):
		return DeathNotifyResult.DUPLICATE_DEATH_NOTIFICATION

	if not AffinityTypes.is_valid_character(character):
		return DeathNotifyResult.INVALID_CHARACTER

	_death_marks[character] = _t_now
	return DeathNotifyResult.NONE


## 回傳配對 [param pair] 兩名成員中較早的陣亡標記值;兩者皆未陣亡回傳
## `null`(GDD Core Rules #3)。至多 2 次 [member _death_marks] 鍵查找,O(1)。
##
## 🔴 [b]回傳型別為 [Variant]([int] 或 `null`)——呼叫端義務(ADR-0002
## 機制四之三之二,Variant 出口 #6):呼叫端必須先 `typeof()` / null 檢查,
## [b]絕不直接做數值比較[/b]。已實測 `is_finite`/`==`/`>=` 等操作對非數值
## 型別皆會中止呼叫函式,`null` 亦不安全(布林判斷對 `null` 安全,數值
## 比較不安全)。[/b]
func t_death(pair: AffinityTypes.Pair) -> Variant:
	# 非法 pair 序數今天不在本 story 的 AC/測試範圍內(ADR-0002 機制四之四
	# 的 8 個入口清單不含 t_death());AffinityTypes.members_of() 對未知鍵
	# 回傳空陣列,下方迴圈自然不執行、earliest 維持 null——不中止、不拋錯。
	var members: Array = AffinityTypes.members_of(pair)

	var earliest: Variant = null
	for member: AffinityTypes.Character in members:
		if not _death_marks.has(member):
			continue
		var mark: int = _death_marks[member]
		if earliest == null:
			earliest = mark
		elif mark < earliest:
			earliest = mark
	return earliest


## 前進戰役刻度介面(GDD Core Rules #1「戰役刻度標記列表」段落、ADR-0002 機制二末段,
## Story S-005)。每次成功呼叫附加當下的 [member _t_now] 現值到
## [member _campaign_tick_marks]。[b]此呼叫不遞增 [member _t_now] 本身[/b]——呼叫前後
## `t_now` 相同(與 [method notify_death] 的既有慣例一致:記錄呼叫當下的現值,不推進
## 計數器本身)。
##
## 回傳 [enum AdvanceRejection]:
## - [constant AdvanceRejection.NONE]:成功附加標記。
## - [constant AdvanceRejection.SERIALIZATION_WINDOW_ACTIVE]:🔴 本 story 未實作
##   觸發路徑——依賴 S-014(切片外)的序列化生命週期權杖集合,
##   [member _serialization_tokens] 今天恆為空,此分支恆不可達。檢查點結構保留在
##   下方,供 S-014 落地時接上,不宣稱今天測得到。
func advance_campaign_tick() -> AdvanceRejection:
	# 檢查點(S-014 接口,今天恆為 false):理由與 notify_death()/append_record()
	# 的同名檢查點一致——避免副作用發生在資料被視為凍結快照的期間。最先檢查。
	if not _serialization_tokens.is_empty():
		return AdvanceRejection.SERIALIZATION_WINDOW_ACTIVE

	_campaign_tick_marks.append(_t_now)
	return AdvanceRejection.NONE


## 計算 `c_now(t_query)`(GDD Formulas 3c 精確定義,Story S-005):回傳
## [member _campaign_tick_marks] 中「標記值 ≤ t_query」的筆數——即在 `t_query` 這個
## 全域時間點以前(含當下),[method advance_campaign_tick] 總共被呼叫過幾次。這個
## 定義不依賴 Delta Log([member _records])中任何配對是否被寫入,這正是本 story
## 存在的理由(工作單 Implementation Notes #3)。
##
## [param t_query] 省略時(維持預設的負數哨兵值)等同「目前已呼叫次數」——因為每個
## 標記都是在某次呼叫當下以 [member _t_now] 現值寫入,而 [member _t_now] 只會隨後續
## 寫入單調不減,故任何既有標記在之後任一時刻查詢都必然滿足「≤ 現值」,全部標記數
## 與「以目前 t_now 查詢」得到的計數恆相等,故省略時直接回傳標記總數,不需重新取得
## 目前的 [member _t_now]。
##
## 🔴 本 story 只交付這個內部/私有輔助方法本身,不對外公開獨立的 `c_now()` 查詢
## 介面——GDD 明文 `c_now` 是隨三個讀取函數的回傳值一併附帶的欄位(Core Rules #3
## 「回傳值中的計數器可觀測性」),不是獨立方法;S-006/S-007 負責把它接進各自的
## 回傳簽章。
##
## 線性計數,`O(m)`(`m` = 目前標記筆數),滿足 GDD 鎖定的 `O(n_p+m)` 效能契約
## (ADR-0002 逐字)。
func _c_now(t_query: int = -1) -> int:
	if t_query < 0:
		return _campaign_tick_marks.size()

	var count: int = 0
	for mark: int in _campaign_tick_marks:
		if mark <= t_query:
			count += 1
	return count


## 三個私有序數驗證器(機制四之四),讀 [method _init] 快取的序數陣列而非每次重新呼叫
## `.values()`(理由見 [member _pair_ordinals] 文件註解)。
##
## 🔴 這與 [method AffinityTypes.is_valid_pair] / [method AffinityTypes.is_valid_character] /
## [method AffinityTypes.is_valid_source](S-001,公開靜態,低頻)是刻意的【兩份獨立實作
## 路徑】——ADR-0002 機制四之四明文接受這個「同一個檢查散寫在兩個地方」的形狀:熱路徑
## (本方法群與三個讀取函數,S-006/S-007)不能承受 `.values()` 每次重新配置陣列的成本,
## 靜態函式又讀不到本類別的實例成員快取,而 GDScript 的 `const` 不支援方法呼叫作初始化式,
## 無法用它取代兩者中的任一個。
##
## **不要「順手統一」成一份**——這不是本專案已知的「同一份對映在兩處各自手寫、只是今天
## 答案一致」那種病(對照 [AffinityTypes] 檔頭關於 `_PAIR_MEMBERS` 收斂為單一權威來源的
## 說明),而是 ADR 在查明兩種寫法各自的技術限制後【刻意】保留的兩條路徑。ADR-0002
## Validation Criteria #13 要求兩條路徑對同一輸入回傳完全一致的結果,對應測試見
## `test_two_ordinal_validation_paths_agree_on_same_inputs`。
## ⚠️ 該測試只能證明「兩條路徑今天一致」,不能證明「結構上不可能分岔」——兩份獨立實作
## 意味著未來任一份被單獨修改,編譯器不會擋下語意分歧,這是接受這個形狀所付的代價,
## 不是這條測試消除掉的風險。
func _validate_pair_ordinal(pair: AffinityTypes.Pair) -> bool:
	return _pair_ordinals.has(pair)


func _validate_character_ordinal(c: AffinityTypes.Character) -> bool:
	return _character_ordinals.has(c)


func _validate_source_ordinal(s: AffinityTypes.Source) -> bool:
	return _source_ordinals.has(s)


## 好感度數值池的寫入介面(機制四,GDD Core Rules #2)。六步驗證,fail-loud——任何一步
## 拒絕即回傳對應的 [enum WriteRejection] 分支,不遞增 [member _t_now]、不附加記錄。
##
## 驗證順序由 ADR-0002 決定(GDD 未規定順序,只規定情境本身須被涵蓋),**不得重排**——
## 重排會改變「一個同時違反兩條規則的輸入回傳哪個拒絕碼」這個可觀測行為:
##
## 1. [member _serialization_tokens] 非空 → [constant WriteRejection.SERIALIZATION_WINDOW_ACTIVE]
##    (今天恆為空集合,此分支結構上不可達,見 [enum WriteRejection] 文件註解——S-014
##    落地前不得刪除這一步)
## 2. `m == 0.0` → [constant WriteRejection.ZERO_AMPLITUDE]
## 3. `is_nan(m) or is_inf(m)` → [constant WriteRejection.NON_FINITE_AMPLITUDE]
## 4. `source` 序數非法 → [constant WriteRejection.INVALID_SOURCE]
## 5. `pair` 序數非法 → [constant WriteRejection.INVALID_PAIR]
## 6. 配對已陣亡([method t_death] 非 `null`)且 `source == COMBAT_CARD`
##    → [constant WriteRejection.DEAD_PAIR_COMBAT_CARD_FORBIDDEN](GDD Core Rules #2
##    「陣亡配對的寫入限制」——判定條件是【至少一人】陣亡,不論另一人是否亦已陣亡)
##
## 全數通過 → 建立 [AffinityRecord]、附加進 `_records[pair]`、[member _t_now] 前進一格、
## 發出 [signal entry_appended] 訊號(2026-09-15 補件,見該訊號文件註解的重要但書)、
## 回傳 [constant WriteRejection.NONE]。**任何一步拒絕都不會走到這裡,故七類拒絕分支
## 一律不 emit [signal entry_appended]**。
##
## `record.c`(戰役刻度)自 Story S-005 起改為呼叫 [method _c_now]() 取得寫入當下的
## 戰役刻度計數器現值——即目前已成功呼叫過幾次 [method advance_campaign_tick]。
## S-004 遺留的恆 0 佔位腳手架至此不再成立(AC-2 的精確值涵蓋、AC-39 由本 story 交付)。
##
## 呼叫端型別義務(機制四之三,本方法【不】涵蓋):`pair`/`source` 為型別化 enum 參數、
## `m` 為型別化 `float`——上游若持有來源不明的 `Variant`,必須在呼叫本方法之前自行以
## `typeof()` 收斂型別。本方法的七類拒絕碼不涵蓋型別非法,這是 S-008(丙類寫入轉接器)
## 的義務,不是本方法的職責。
func append_record(
	pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source
) -> WriteRejection:
	if not _serialization_tokens.is_empty():
		return WriteRejection.SERIALIZATION_WINDOW_ACTIVE

	if m == 0.0:
		return WriteRejection.ZERO_AMPLITUDE

	if is_nan(m) or is_inf(m):
		return WriteRejection.NON_FINITE_AMPLITUDE

	if not _validate_source_ordinal(source):
		return WriteRejection.INVALID_SOURCE

	if not _validate_pair_ordinal(pair):
		return WriteRejection.INVALID_PAIR

	# t_death() 回傳 Variant(int 或 null)——呼叫端義務(機制四之三之二,Variant 出口
	# #6):先做 null 檢查,絕不直接做數值比較。此處只做 `!= null`(布林判斷,對 null
	# 安全),不對回傳值本身做任何數值運算或比較。
	if t_death(pair) != null and source == AffinityTypes.Source.COMBAT_CARD:
		return WriteRejection.DEAD_PAIR_COMBAT_CARD_FORBIDDEN

	# 全數通過——_records[pair] 對全部 10 個合法配對永遠存在(建構子預填,見
	# member _records 文件註解),不需要「檢查—建立」這一步;非法序數已在上方步驟
	# 4/5 被攔下,不會走到這裡。
	var new_t: int = _t_now + 1
	var record: AffinityRecord = AffinityRecord.new()
	record.pair = pair
	record.m = m
	record.t = new_t
	record.c = _c_now()  # 戰役刻度現值(Story S-005)——見 _c_now() 文件註解
	record.source = source

	_records[pair].append(record)
	_t_now = new_t

	# ADR-0002 機制四逐字順序:附加記錄 → t_now 前進一格 → emit entry_appended → 回傳 NONE。
	# 2026-09-15 補件(見 [signal entry_appended] 文件註解的重要但書——實作慣例,非契約)。
	entry_appended.emit(pair, record)

	return WriteRejection.NONE


## 三個真實讀取函數共用的入口驗證(ADR-0002 機制五、Story S-006)。依序:
## 1. [param t_query] 型別閘門——[code]match typeof(t_query)[/code] 三分支。
##    [b]case 順序不可交換[/b](已實測):若把 `_` 預設分支寫在 [constant TYPE_NIL]
##    之前,`null` 會被 `_` 提前吃掉,[constant TYPE_NIL] 分支變成不可達的死碼,
##    且引擎[b]既不擋編譯、執行期也不印任何警告[/b](工作單 Implementation
##    Notes #2)。[constant TYPE_FLOAT] 一律落入 `_` 被拒絕——不接受 `3.0`,理由
##    與機制八對 `t`/`c` 嚴格 [constant TYPE_INT] 一致:浮點截斷後落入合法範圍
##    會靜默通過後續值域檢查。
## 2. [param pair] 序數驗證(機制四之四入口 3–5)——非法序數若不在此攔下,
##    下游 `_records[非法序數]` 缺鍵讀取會直接中止呼叫函式。
## 3. 型別通過為 [constant TYPE_INT] 時,[param t_query] 大於目前 [member _t_now]
##    一律視為未來時間點查詢,拒絕(GDD Edge Cases「若 t_query 大於目前實際的
##    t_now」,AC-36)。[b]若 [param t_query] 早於配對最早一筆記錄的
##    [code]t_i[/code],視同該配對在此刻 [code]n(p, t_query) = 0[/code],是合法
##    情境,不觸發本分支[/b]——本方法只與 [member _t_now] 比較,不查任何配對的
##    最早記錄時間,故此情境自然不會誤觸。
##
## 🔴 [b]步驟 1(型別閘門)必須最先[/b]是規格明文(ADR-0002 機制五「機制五
## 開頭,先於任何其他運算」,BLOCKING)。[b]步驟 2(pair 驗證)與步驟 3
## (未來時點檢查)之間的相對順序不是[/b]——GDD/ADR 均未針對「同一次呼叫
## 同時違反兩者時回傳哪個拒絕碼」給出可測試的明文斷言。目前實作選擇
## 「pair 驗證先於未來時點檢查」,由
## `test_combined_invalid_pair_and_future_t_query_returns_invalid_pair_first`
## 這條回歸測試釘死[b]這個實作選擇[/b],不是在斷言某個規格保證——若日後
## 需要調整此順序,必須同步改動那條測試,而不是任由它悄悄變成一個假的契約。
##
## 🔴 [b]明文禁止[/b] [code]if t_query != null and t_query > _t_now[/code]——
## 對 [String] 會在比較運算子處中止所在函式(已實測)。[param t_query] 的型別
## 判定[b]只能用[/b] `typeof()`:不可用 `!= null`、不可用比較、不可用賦值進
## 型別化變數當檢查。
##
## 回傳 [constant ReadRejection.NONE] 表示通過全部三步——呼叫端(即下方三個
## 讀取函數自身)接著仍需依 [code]typeof(t_query) == TYPE_INT[/code] 判斷是走
## 「明確查詢時點」還是「條件式預設查詢時點」分支。本方法[b]不[/b]決定後者
## 實際應該解出什麼值(屬 S-007,見三個讀取函數的文件註解)。
func _validate_read_query(pair: AffinityTypes.Pair, t_query: Variant) -> ReadRejection:
	match typeof(t_query):
		TYPE_NIL:
			pass   # 走條件式預設查詢時點分支——實際預設值由 S-007 決定
		TYPE_INT:
			pass   # 繼續下方值域檢查
		_:
			return ReadRejection.INVALID_T_QUERY_TYPE

	if not _validate_pair_ordinal(pair):
		return ReadRejection.INVALID_PAIR

	if typeof(t_query) == TYPE_INT and t_query > _t_now:
		return ReadRejection.FUTURE_TIME_QUERY

	return ReadRejection.NONE


## 建立一個帶指定 [param rejection] 碼與機制五之二哨兵值的 [AffinityReadResult]。
## [method combat_strength_read]/[method narrative_depth_read] 的所有拒絕分支
## 共用本方法,避免哨兵值表在多處各自手寫、日後只改到其中幾處——本專案已登記過
## 這個失效模式(見 [method _validate_pair_ordinal] 文件註解對「兩份獨立實作」
## 與「同一份手寫兩處」的區分)。
func _rejected_read_result(rejection: ReadRejection) -> AffinityReadResult:
	var result := AffinityReadResult.new()
	result.rejection = rejection
	result.value = NAN
	result.t_query = -1
	result.n_pair = -1
	result.diagnostic_visited_count = -1
	return result


## 建立一個帶指定 [param rejection] 碼與機制五之二哨兵值的 [ShapeFeatureResult]。
## [method shape_feature_read] 的所有拒絕分支共用本方法,理由同
## [method _rejected_read_result]。
func _rejected_shape_feature_result(rejection: ReadRejection) -> ShapeFeatureResult:
	var result := ShapeFeatureResult.new()
	result.rejection = rejection
	result.reversal_count = -1
	result.source_distribution = {}
	result.time_distribution = null
	result.source_polarity = {}
	result.total_churn = NAN
	result.segment_profile = null
	result.low_confidence = null
	result.source_absence = {}
	result.n_pair = -1
	result.t_query = -1
	result.c_now = -1
	result.diagnostic_visited_count = -1
	return result


## 公式一(戰鬥強度讀取,GDD Formulas 公式一)。ADR-0002 機制五,Story S-006。
##
## 🔴 本 story 只交付入口驗證([method _validate_read_query])與拒絕分流——加權
## 計算邏輯本身(公式一的實際數學)、`n(p)=0` 的完整合法回傳值、陣亡配對的
## 條件式預設查詢時點實際算出的值,全部屬 S-007。通過驗證後回傳的是[b]佔位
## 中性值[/b]([code]value = 0.0[/code]、[code]n_pair = 0[/code]、
## [code]diagnostic_visited_count = 0[/code]),[b]不代表任何真實讀值[/b]——
## 本 story 的測試範圍嚴格限定在型別/閘門/拒絕層級,不涉及此處回傳值的正確性。
##
## [param t_query] 省略([code]null[/code])時走「條件式預設查詢時點」
## (GDD Core Rules #3):若 [method t_death] 非 `null` 則預設為該值,否則預設
## 為目前 [member _t_now]。[b]本 story 只保證落到這個分支,不決定實際算出
## 什麼[/b]——下方佔位實作直接使用 [member _t_now],真正呼叫 [method t_death]
## 分流屬 S-007。
func combat_strength_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult:
	var rejection: ReadRejection = _validate_read_query(pair, t_query)
	if rejection != ReadRejection.NONE:
		return _rejected_read_result(rejection)

	var result := AffinityReadResult.new()
	result.rejection = ReadRejection.NONE
	result.value = 0.0
	result.t_query = t_query if typeof(t_query) == TYPE_INT else _t_now
	result.n_pair = 0
	result.diagnostic_visited_count = 0
	return result


## 公式二(敘事深度讀取,GDD Formulas 公式二)。ADR-0002 機制五,Story S-006。
## 結構與 [method combat_strength_read] 完全對稱(同一套入口驗證、同一種條件式
## 預設查詢時點、同一種佔位中性值)——見該方法文件註解,不重複。
func narrative_depth_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> AffinityReadResult:
	var rejection: ReadRejection = _validate_read_query(pair, t_query)
	if rejection != ReadRejection.NONE:
		return _rejected_read_result(rejection)

	var result := AffinityReadResult.new()
	result.rejection = ReadRejection.NONE
	result.value = 0.0
	result.t_query = t_query if typeof(t_query) == TYPE_INT else _t_now
	result.n_pair = 0
	result.diagnostic_visited_count = 0
	return result


## 公式三(形狀特徵讀取,GDD Formulas 公式三)。ADR-0002 機制五,Story S-006。
##
## 🔴 [param t_query] 省略時[b]一律[/b]預設為目前 [member _t_now]——不受陣亡
## 凍結規則影響(GDD 明文形狀特徵須能反映陣亡後的追憶寫入),與
## [method combat_strength_read]/[method narrative_depth_read] 的條件式預設
## [b]不同[/b]。這條規則本身無條件、不依賴 [method t_death],故本 story 直接
## 落地,不留待 S-007。
##
## 🔴 七項形狀特徵欄位([member ShapeFeatureResult.reversal_count] 起算)的
## 實際計算邏輯屬 S-007——本 story 只保證欄位存在、拒絕時哨兵值正確(工作單
## Implementation Notes #1)。成功呼叫時回傳佔位中性值,[member c_now] 例外:
## 它呼叫既有的 [method _c_now]()(S-005 已交付的真實實作),不是佔位值。
func shape_feature_read(pair: AffinityTypes.Pair, t_query: Variant = null) -> ShapeFeatureResult:
	var rejection: ReadRejection = _validate_read_query(pair, t_query)
	if rejection != ReadRejection.NONE:
		return _rejected_shape_feature_result(rejection)

	var effective_t_query: int = t_query if typeof(t_query) == TYPE_INT else _t_now
	var result := ShapeFeatureResult.new()
	result.rejection = ReadRejection.NONE
	result.reversal_count = 0
	result.source_distribution = {}
	result.time_distribution = null
	result.source_polarity = {}
	result.total_churn = 0.0
	result.segment_profile = null
	result.low_confidence = null
	result.source_absence = {}
	result.n_pair = 0
	result.t_query = effective_t_query
	result.c_now = _c_now(effective_t_query)
	result.diagnostic_visited_count = 0
	return result
