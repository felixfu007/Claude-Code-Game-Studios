# SupportConversationRules(src/gameplay/narrative/support_conversation_rules.gd)
# 的單元測試。
#
# 純函式/靜態規則,搭配注入式假寫入埠(_SpyWritePort)—— 本 story 的範圍明文
# 「不接任何真實好感度池」(見 EPIC.md「開工前查核一、二」),測試驗的是
# 「有沒有寫、寫了幾次、寫了什麼」,不碰 AffinityDataPool。
#
# 不建立任何 Node,不需要 tear-down,不會留下孤兒節點。
extends GdUnitTestSuite


## 假寫入埠:只記錄呼叫,不做任何其他事。供全部測試共用的本地測試替身,不進版控的
## 正式系統,只活在這支測試檔裡。
class _SpyWritePort extends SupportConversationWritePort:
	var calls: Array = []

	func append_record(pair: AffinityTypes.Pair, m: float, source: AffinityTypes.Source) -> void:
		calls.append({"pair": pair, "m": m, "source": source})


# 以下常數是餵給規則函式的合成資料,不是本作的真實內容。
const LINE_POSITIVE: String = "SC-TEST-01,1,1,2,positive"
const LINE_NEGATIVE: String = "SC-TEST-02,2,3,4,negative"
const LINE_NEUTRAL: String = "SC-TEST-03,3,1,2,neutral"

const SUPPORT_CONVERSATIONS_PATH: String = "res://assets/data/narrative/support_conversations.txt"


# ---- validate_negative_not_last_slot() — AC-4 -------------------------------

func test_validate_negative_not_last_slot_real_data_has_no_violation() -> void:
	# 現行三筆真實資料(5 場關卡,最後一槽 trigger_after_mission=4)剛好都合法 ——
	# 這條只證明「今天的資料合規」,不能單獨證明規則有效,見下一條合成資料測試。
	# Arrange
	var text: String = FileAccess.get_file_as_string(SUPPORT_CONVERSATIONS_PATH)
	var records: Array[SupportConversationRecord] = SupportConversationRecord.records_from_text(text)

	# Act
	var violations: Array[SupportConversationRecord] = (
		SupportConversationRules.validate_negative_not_last_slot(records, 5)
	)

	# Assert
	assert_int(violations.size()).is_equal(0)


func test_validate_negative_not_last_slot_detects_violation_with_synthetic_data() -> void:
	# 🔴 AC-4 的查核義務(story-001 明文):現行資料剛好合法,不能只驗現行資料 ——
	# 必須證明「違規真的會被抓到」,否則這是一條永遠綠燈、證明不了任何事的測試。
	# 用合成資料建構一個 negative 排在最後一槽的情境:total_missions=3 時,
	# 最後一槽是 trigger_after_mission == 2。
	# Arrange
	var violating_record: SupportConversationRecord = SupportConversationRecord.from_csv_line(
		"SC-SYNTH-LAST,2,1,2,negative"
	)
	var legal_negative_record: SupportConversationRecord = SupportConversationRecord.from_csv_line(
		"SC-SYNTH-OK,1,3,4,negative"  # 第 1 場之後 —— 3 場時最後一槽是 2,這不是
	)
	var records: Array[SupportConversationRecord] = [violating_record, legal_negative_record]

	# Act
	var violations: Array[SupportConversationRecord] = (
		SupportConversationRules.validate_negative_not_last_slot(records, 3)
	)

	# Assert — 恰好抓到那一筆排在最後一槽的,合法的那一筆不被誤判
	assert_int(violations.size()).append_failure_message(
		"合成資料的 negative-at-last-slot 違規沒有被抓到 —— 規則本身可能失效,"
		+ "而不只是今天的資料剛好合規。"
	).is_equal(1)
	assert_str(violations[0].conversation_id).is_equal("SC-SYNTH-LAST")


func test_validate_negative_not_last_slot_positive_at_last_slot_is_not_a_violation() -> void:
	# 規則只管 negative —— positive/neutral 排最後一槽不受 OBL-031 限制。
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(
		"SC-SYNTH,2,1,2,positive"
	)

	# Act
	var violations: Array[SupportConversationRecord] = (
		SupportConversationRules.validate_negative_not_last_slot([record], 3)
	)

	# Assert
	assert_int(violations.size()).is_equal(0)


func test_validate_negative_not_last_slot_empty_records_returns_empty() -> void:
	# Act
	var violations: Array[SupportConversationRecord] = (
		SupportConversationRules.validate_negative_not_last_slot([], 5)
	)

	# Assert
	assert_int(violations.size()).is_equal(0)


# ---- magnitude_for_valence() -------------------------------------------------

func test_magnitude_for_valence_positive_is_positive_magnitude_abs() -> void:
	assert_float(
		SupportConversationRules.magnitude_for_valence(SupportConversationRecord.Valence.POSITIVE)
	).is_equal_approx(SupportConversationRules.MAGNITUDE_ABS, 0.0001)


func test_magnitude_for_valence_negative_is_negative_magnitude_abs() -> void:
	assert_float(
		SupportConversationRules.magnitude_for_valence(SupportConversationRecord.Valence.NEGATIVE)
	).is_equal_approx(-SupportConversationRules.MAGNITUDE_ABS, 0.0001)


# ---- trigger() — AC-1/AC-5/AC-6 ---------------------------------------------

func test_trigger_both_alive_writes_once_and_completes() -> void:
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(_roster_id: int) -> bool: return true

	# Act
	var result: SupportConversationRecord.TriggerState = SupportConversationRules.trigger(
		record, is_alive, port
	)

	# Assert
	assert_int(result).is_equal(SupportConversationRecord.TriggerState.COMPLETED)
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.COMPLETED)
	assert_int(port.calls.size()).is_equal(1)
	assert_int(port.calls[0]["pair"]).is_equal(AffinityTypes.Pair.C1_C2)
	assert_int(port.calls[0]["source"]).is_equal(AffinityTypes.Source.SUPPORT_CONVERSATION)
	assert_float(port.calls[0]["m"]).is_equal_approx(SupportConversationRules.MAGNITUDE_ABS, 0.0001)


func test_trigger_negative_valence_writes_negative_magnitude() -> void:
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_NEGATIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(_roster_id: int) -> bool: return true

	# Act
	SupportConversationRules.trigger(record, is_alive, port)

	# Assert
	assert_float(port.calls[0]["m"]).is_equal_approx(-SupportConversationRules.MAGNITUDE_ABS, 0.0001)


func test_trigger_pair_a_dead_skips_and_produces_no_write() -> void:
	# AC-5:觸發時任一參與者已陣亡 → 整段跳過、不產生任何寫入、狀態記 skipped。
	# Arrange — 只有 pair_b(2)活著,pair_a(1)已陣亡
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(roster_id: int) -> bool: return roster_id == 2

	# Act
	var result: SupportConversationRecord.TriggerState = SupportConversationRules.trigger(
		record, is_alive, port
	)

	# Assert
	assert_int(result).is_equal(SupportConversationRecord.TriggerState.SKIPPED)
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.SKIPPED)
	assert_int(port.calls.size()).append_failure_message(
		"陣亡跳過時不應產生任何寫入(規格第 5 節 / 本 story AC-5)"
	).is_equal(0)


func test_trigger_pair_b_dead_skips_and_produces_no_write() -> void:
	# Arrange — 只有 pair_a(1)活著,pair_b(2)已陣亡
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(roster_id: int) -> bool: return roster_id == 1

	# Act
	var result: SupportConversationRecord.TriggerState = SupportConversationRules.trigger(
		record, is_alive, port
	)

	# Assert
	assert_int(result).is_equal(SupportConversationRecord.TriggerState.SKIPPED)
	assert_int(port.calls.size()).is_equal(0)


func test_trigger_both_dead_skips_and_produces_no_write() -> void:
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(_roster_id: int) -> bool: return false

	# Act
	var result: SupportConversationRecord.TriggerState = SupportConversationRules.trigger(
		record, is_alive, port
	)

	# Assert
	assert_int(result).is_equal(SupportConversationRecord.TriggerState.SKIPPED)
	assert_int(port.calls.size()).is_equal(0)


func test_trigger_skipped_records_state_not_completed() -> void:
	# 規格第 5 節明文:跳過時狀態記 skipped,不是 completed(供事後查核)。
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(_roster_id: int) -> bool: return false

	# Act
	SupportConversationRules.trigger(record, is_alive, port)

	# Assert
	assert_int(record.state).append_failure_message(
		"跳過的對話狀態不得是 completed —— 規格第 5 節要求記 skipped 以便事後查核"
	).is_not_equal(SupportConversationRecord.TriggerState.COMPLETED)
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.SKIPPED)


func test_trigger_already_resolved_record_is_idempotent_no_op() -> void:
	# 已經 completed 的記錄再被呼叫一次,不應該再寫入、也不應該改變回傳狀態 ——
	# 本 story 不接轉場系統,但這是 trigger() 自身的防禦性契約(避免被誤觸發兩次)。
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(_roster_id: int) -> bool: return true
	SupportConversationRules.trigger(record, is_alive, port)  # 第一次,COMPLETED

	# Act
	var result: SupportConversationRecord.TriggerState = SupportConversationRules.trigger(
		record, is_alive, port
	)

	# Assert
	assert_int(result).is_equal(SupportConversationRecord.TriggerState.COMPLETED)
	assert_int(port.calls.size()).append_failure_message(
		"重複觸發已完成的對話不應該再寫入第二次"
	).is_equal(1)


# ---- trigger() — 裁決③(2026-10-19 管理者裁決):NEUTRAL 觸發但不寫好感度 -----

func test_trigger_neutral_valence_completes_without_writing() -> void:
	# 裁決③ 逐字選項「觸發對話,但不寫好感度(推薦)」:AffinityDataPool.append_record()
	# 對 m == 0.0 回傳 WriteRejection.ZERO_AMPLITUDE —— 「寫 0」等同「這筆寫入被
	# 拒絕」,所以正確做法是完全不呼叫寫入埠,而不是呼叫後傳 0。
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_NEUTRAL)
	var port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(_roster_id: int) -> bool: return true

	# Act
	var result: SupportConversationRecord.TriggerState = SupportConversationRules.trigger(
		record, is_alive, port
	)

	# Assert — 對話確實發生(COMPLETED,不是 SKIPPED —— SKIPPED 專屬陣亡情境),
	# 但零次寫入。
	assert_int(result).is_equal(SupportConversationRecord.TriggerState.COMPLETED)
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.COMPLETED)
	assert_int(port.calls.size()).append_failure_message(
		"NEUTRAL 對話完成時不應呼叫寫入埠(裁決③:寫 0 等同被 ZERO_AMPLITUDE 拒絕,"
		+ "正確做法是不呼叫)"
	).is_equal(0)


func test_sensitivity_proof_neutral_zero_write_is_neutral_specific_not_whole_path_broken() -> void:
	# 敏感度證明:證明上面那條測試量到的「零次呼叫」是 NEUTRAL 專屬的分支邏輯,
	# 不是 trigger() 整條寫入路徑意外壞掉 —— 同一個 is_alive(全員存活)之下,
	# POSITIVE/NEGATIVE 仍然必須照常呼叫寫入埠恰好一次。
	# Arrange
	var positive_record: SupportConversationRecord = SupportConversationRecord.from_csv_line(
		LINE_POSITIVE
	)
	var negative_record: SupportConversationRecord = SupportConversationRecord.from_csv_line(
		LINE_NEGATIVE
	)
	var positive_port: _SpyWritePort = _SpyWritePort.new()
	var negative_port: _SpyWritePort = _SpyWritePort.new()
	var is_alive: Callable = func(_roster_id: int) -> bool: return true

	# Act
	SupportConversationRules.trigger(positive_record, is_alive, positive_port)
	SupportConversationRules.trigger(negative_record, is_alive, negative_port)

	# Assert
	assert_int(positive_port.calls.size()).append_failure_message(
		"敏感度證明失敗:POSITIVE 也變成零次呼叫 —— NEUTRAL 測試量到的 0 可能只是"
		+ "整條寫入路徑壞掉,不是 NEUTRAL 專屬分支。"
	).is_equal(1)
	assert_int(negative_port.calls.size()).append_failure_message(
		"敏感度證明失敗:NEGATIVE 也變成零次呼叫 —— 同上。"
	).is_equal(1)


func test_trigger_already_skipped_record_is_idempotent_no_op() -> void:
	# 同上,但起點是 SKIPPED 而非 COMPLETED —— 兩個終態都要擋住重複呼叫。
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	var port: _SpyWritePort = _SpyWritePort.new()
	var dead_is_alive: Callable = func(_roster_id: int) -> bool: return false
	SupportConversationRules.trigger(record, dead_is_alive, port)  # 第一次,SKIPPED

	# Act — 第二次改傳「全員存活」,驗證不會因此起死回生並補寫一筆
	var alive_is_alive: Callable = func(_roster_id: int) -> bool: return true
	var result: SupportConversationRecord.TriggerState = SupportConversationRules.trigger(
		record, alive_is_alive, port
	)

	# Assert
	assert_int(result).is_equal(SupportConversationRecord.TriggerState.SKIPPED)
	assert_int(port.calls.size()).is_equal(0)
