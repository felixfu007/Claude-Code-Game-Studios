## production/epics/game-shell/story-003-campaign-flow-and-transition-slots.md
## AC5(唯一觸發呼叫點)/ AC6(第 4 場之後 ——4→5 槽位—— 沒有對話被觸發;空集合
## 最容易被誤判成「功能還沒做」)。
##
## 🔴 本檔不在協調者 2026-10-19 訊息列出的兩個測試檔清單內,是本輪新增的第三個
## 測試檔 —— AC6 的判斷邏輯載體是 support_conversation_transition.gd,不屬於
## campaign_progress.gd 或 campaign_sequence.gd 的職責範圍,兩者都無法涵蓋這條
## AC,故另立本檔。已在任務報告中明確揭露此一偏離。
extends GdUnitTestSuite


## 間諜寫入埠 —— 只記錄被呼叫幾次,不做任何真實寫入(比照既有測試的 fake port
## 慣例)。
class _SpyPort:
	extends SupportConversationWritePort

	var call_count: int = 0

	func append_record(_pair: AffinityTypes.Pair, _m: float, _source: AffinityTypes.Source) -> void:
		call_count += 1


func _always_alive(_roster_id: int) -> bool:
	return true


## 比照 assets/data/narrative/support_conversations.txt 的既有三列
## (SC-01/02/03,槽位 1/2/3)—— 4→5 槽位刻意空置,不在這份清單內。
func _mvp_records() -> Array[SupportConversationRecord]:
	var records: Array[SupportConversationRecord] = []
	records.append(SupportConversationRecord.from_csv_line("SC-01,1,1,2,positive"))
	records.append(SupportConversationRecord.from_csv_line("SC-02,2,1,3,negative"))
	records.append(SupportConversationRecord.from_csv_line("SC-03,3,2,4,positive"))
	return records


func test_trigger_for_mission_transition_triggers_matching_slot() -> void:
	# Arrange
	var records: Array[SupportConversationRecord] = _mvp_records()
	var port: _SpyPort = _SpyPort.new()

	# Act
	var triggered: Array[SupportConversationRecord] = SupportConversationTransition.trigger_for_mission_transition(
		1, records, _always_alive, port
	)

	# Assert
	assert_int(triggered.size()).append_failure_message(
		"AC5:槽位 1 應觸發 SC-01 這一段"
	).is_equal(1)
	assert_str(triggered[0].conversation_id).is_equal("SC-01")
	assert_int(port.call_count).append_failure_message(
		"觸發應該真的呼叫寫入埠一次"
	).is_equal(1)


func test_trigger_for_mission_transition_slot_four_triggers_nothing() -> void:
	# Arrange — 5 場骨架 4→5 槽位刻意空置
	# (design/quick-specs/mvp-five-levels-skeleton.md 第二部分)。
	var records: Array[SupportConversationRecord] = _mvp_records()
	var port: _SpyPort = _SpyPort.new()

	# Act
	var triggered: Array[SupportConversationRecord] = SupportConversationTransition.trigger_for_mission_transition(
		4, records, _always_alive, port
	)

	# Assert
	assert_array(triggered).append_failure_message(
		"AC6:第 4 場之後(4→5 槽位)資料表沒有任何記錄,觸發結果必須是空集合 —— " +
		"空集合是正確答案,不是功能沒做"
	).is_empty()
	assert_int(port.call_count).append_failure_message(
		"AC6:4→5 槽位沒有對話,寫入埠不應被呼叫"
	).is_equal(0)


## 敏感度證明:若 4→5 槽位「意外」被塞進一筆記錄,上面那條測試的判斷邏輯真的
## 抓得到,不是巧合地永遠回傳空集合。
func test_sensitivity_proof_slot_four_detects_an_injected_record() -> void:
	# Arrange
	var records: Array[SupportConversationRecord] = _mvp_records()
	records.append(SupportConversationRecord.from_csv_line("SC-04,4,1,5,positive"))
	var port: _SpyPort = _SpyPort.new()

	# Act
	var triggered: Array[SupportConversationRecord] = SupportConversationTransition.trigger_for_mission_transition(
		4, records, _always_alive, port
	)

	# Assert
	assert_int(triggered.size()).append_failure_message(
		"敏感度證明失敗:植入了一筆槽位 4 的記錄,掃描卻沒有抓到"
	).is_equal(1)
	assert_int(port.call_count).append_failure_message(
		"敏感度證明失敗:植入的記錄應觸發一次寫入"
	).is_equal(1)


## 敏感度證明:陣亡跳過(story-001 既有規則)透過本入口仍然生效 —— 證明本檔
## 只是轉送,沒有悄悄繞過 SupportConversationRules.trigger() 自己的判定。
func test_sensitivity_proof_dead_participant_is_skipped_not_triggered() -> void:
	# Arrange
	var records: Array[SupportConversationRecord] = _mvp_records()
	var port: _SpyPort = _SpyPort.new()
	var is_pair_a_dead: Callable = func(roster_id: int) -> bool:
		return roster_id != 1  # SC-01 的 pair_a(甲,roster id 1)視為已陣亡

	# Act
	var triggered: Array[SupportConversationRecord] = SupportConversationTransition.trigger_for_mission_transition(
		1, records, is_pair_a_dead, port
	)

	# Assert
	assert_int(triggered.size()).append_failure_message(
		"陣亡跳過仍應回報這段對話被本函式處理過一次(只是跳過,不是沒找到)"
	).is_equal(1)
	assert_int(triggered[0].state).append_failure_message(
		"任一參與者已陣亡時應轉移到 SKIPPED,不是 COMPLETED"
	).is_equal(SupportConversationRecord.TriggerState.SKIPPED)
	assert_int(port.call_count).append_failure_message(
		"陣亡跳過不得產生任何寫入(story-001 AC5 既有規則)"
	).is_equal(0)
