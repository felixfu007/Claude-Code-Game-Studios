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
# 尚未在此檔出現、屬於後續 story 的東西(避免下一個人誤以為漏寫):
# 三個加權讀取函數、can_write()、export_state()/import_state()——全部不在
# 本 story 範圍。（advance_campaign_tick() 已於 S-005 交付,不再列在此處。）
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
