## 支援對話系統(系統 #8)的純規則函式:負向寫入補救檢查、觸發與寫入。
##
## 兩個獨立關注點,各自是無副作用的 [code]static func[/code],形狀上呼應
## [PermanentAffinityWriteRules](`src/gameplay/cards/permanent_affinity_write_rules.gd`):
## [br]
## 1. [method validate_negative_not_last_slot] —— 查詢函式,找出違反 OBL-031
##    (負向寫入不得排最後一槽)的記錄(規格 AC-3)。
## 2. [method trigger] —— 實際判定一段對話該完成還是該跳過,並透過
##    [SupportConversationWritePort] 寫入(規格 AC-1/AC-4/AC-6)。
##
## 規格權威:design/quick-specs/support-conversation-system.md
## Story:production/epics/support-conversation/story-001-data-table-and-trigger-rules.md
class_name SupportConversationRules
extends RefCounted


## 單次寫入的量值絕對值 —— 規格第 3 節「無 α 折扣、權重 1.0」。
##
## 🔴 α 折扣是真實池依 [param source] 在【讀取時】套用的(design/gdd/
## affinity-data-pool.md:「支援對話來源在敘事深度讀取中權重恆為 1.0(不像戰鬥卡牌
## 來源有 α 折扣)」)—— 本系統寫入時不需要、也不應該自行打折。這個常數只決定
## 「寫入幅度的絕對值是多少」,與 α 折扣是兩件不同的事,不要混為一談。
const MAGNITUDE_ABS: float = 1.0


## AC-4(規格 AC-3,OBL-031):找出違反「負向寫入不得排最後一槽」的記錄。
##
## [param total_missions] 由呼叫端提供(例如 5 場 MVP 骨架的 5),刻意不在本函式內
## 寫死 —— 這是資料驅動設計,也是本函式能用合成資料證明「違規真的會被抓到」的
## 理由(本 story AC-4 的查核義務:現行 3 段真實資料剛好都合法,不能只驗現行資料
## 通過,必須證明規則本身抓得到違規)。
##
## 最後一槽 = 第 [code](total_missions - 1)[/code] 場關卡之後 —— 5 場關卡只有
## 4 個轉場槽位(1→2、2→3、3→4、4→5),故最後一槽的
## [code]trigger_after_mission == total_missions - 1[/code]。
static func validate_negative_not_last_slot(
	records: Array[SupportConversationRecord], total_missions: int
) -> Array[SupportConversationRecord]:
	var last_slot: int = total_missions - 1
	var violations: Array[SupportConversationRecord] = []
	for record: SupportConversationRecord in records:
		if (
			record.valence == SupportConversationRecord.Valence.NEGATIVE
			and record.trigger_after_mission == last_slot
		):
			violations.append(record)
	return violations


## 把 [param valence] 轉成帶號寫入量值,正負號由 valence 決定,絕對值固定為
## [constant MAGNITUDE_ABS]。
##
## 🔴 [b]NEUTRAL 的量值未經設計定案 —— 誠實登記,不是裝作有答案。[/b] 輕量規格第 2
## 節只定義 NEUTRAL「影響第 4 節補救規則是否生效」,MVP 三段對話沒有任何一段是
## NEUTRAL(見 assets/data/narrative/support_conversations.txt),規格從未規定
## NEUTRAL 完成時該寫入池多少量值。這裡回傳 [code]0.0[/code] 是一個誠實的預設猜測,
## 不是裁決 —— 真實池([code]AffinityDataPool.append_record[/code])的
## [code]WriteRejection.ZERO_AMPLITUDE[/code] 分支會拒絕量值為 0 的寫入,意味著
## 「今天這樣寫,接上真池後 NEUTRAL 的完成在寫入那一步會被池拒絕」。這個後果留給
## story-002(接真池)處理,不在本 story 範圍內解決,也不是本函式能單方面決定的。
static func magnitude_for_valence(valence: SupportConversationRecord.Valence) -> float:
	match valence:
		SupportConversationRecord.Valence.POSITIVE:
			return MAGNITUDE_ABS
		SupportConversationRecord.Valence.NEGATIVE:
			return -MAGNITUDE_ABS
		SupportConversationRecord.Valence.NEUTRAL:
			return 0.0
		_:
			push_error(
				"SupportConversationRules.magnitude_for_valence: unknown valence %d" % valence
			)
			return 0.0


## 判定 [param record] 這段對話該完成還是該跳過,並據此轉移
## [member SupportConversationRecord.state]。
##
## [param is_alive]:[code]func(roster_id: int) -> bool[/code],與
## [method PermanentAffinityWriteRules.legal_pairs] 的 [param is_alive] 同一種形狀
## —— 刻意是 [Callable] 而非要求完整的 [Unit]/[BattleState] 圖,本函式只需要
## 一個角色活不活的是非題。
##
## 流程(規格 AC-1/AC-4/AC-6):
## [br]
## 1. 若 [member SupportConversationRecord.state] 已不是
##    [constant SupportConversationRecord.TriggerState.NOT_TRIGGERED],代表這段對話
##    已經解決過 —— 記錄一次 [method push_error] 並原樣回傳現有狀態,不重複寫入、
##    也不改變狀態(防止被重複觸發兩次)。
## 2. 若 [param pair_a]、[param pair_b] 任一方已陣亡(本 story AC-5,規格第 5 節
##    「posthumous 判定」):轉移到 [constant SupportConversationRecord.
##    TriggerState.SKIPPED]、[b]不呼叫[/b] [param port],回傳 SKIPPED。
## 3. 否則:把兩個名冊 id 轉成 [enum AffinityTypes.Character]([AffinityRosterCharacterMapper])、
##    組成 [enum AffinityTypes.Pair]([method AffinityTypes.pair_of]),呼叫
##    [method SupportConversationWritePort.append_record] —— 這是本系統對寫入埠
##    [b]唯一[/b]的呼叫點(規格 AC-6/OBL-009,見
##    [code]tests/unit/gameplay/narrative/support_conversation_write_call_site_count_test.gd[/code]
##    的結構性守衛測試),然後轉移到
##    [constant SupportConversationRecord.TriggerState.COMPLETED]、回傳 COMPLETED。
static func trigger(
	record: SupportConversationRecord, is_alive: Callable, port: SupportConversationWritePort
) -> SupportConversationRecord.TriggerState:
	if record.state != SupportConversationRecord.TriggerState.NOT_TRIGGERED:
		push_error(
			"SupportConversationRules.trigger: '%s' already resolved (state=%d), ignoring "
			% [record.conversation_id, record.state]
			+ "duplicate trigger"
		)
		return record.state

	if not is_alive.call(record.pair_a) or not is_alive.call(record.pair_b):
		record.try_transition(SupportConversationRecord.TriggerState.SKIPPED)
		return record.state

	var character_a: Variant = AffinityRosterCharacterMapper.character_for_roster_id(record.pair_a)
	var character_b: Variant = AffinityRosterCharacterMapper.character_for_roster_id(record.pair_b)
	if character_a == null or character_b == null:
		# 理論上不該發生 —— 通過 SupportConversationRecord.from_csv_line() 解析出來的
		# 記錄此處必然合法(該函式已驗證過兩個角色 id)。防禦性檢查,保護直接
		# SupportConversationRecord.new() 建構、繞過解析器的呼叫端(例如測試)。
		push_error(
			"SupportConversationRules.trigger: '%s' has an unmappable pair (%d, %d); "
			% [record.conversation_id, record.pair_a, record.pair_b]
			+ "refusing to write or transition"
		)
		return record.state

	var pair: AffinityTypes.Pair = AffinityTypes.pair_of(character_a, character_b)
	var m: float = magnitude_for_valence(record.valence)
	port.append_record(pair, m, AffinityTypes.Source.SUPPORT_CONVERSATION)
	record.try_transition(SupportConversationRecord.TriggerState.COMPLETED)
	return record.state
