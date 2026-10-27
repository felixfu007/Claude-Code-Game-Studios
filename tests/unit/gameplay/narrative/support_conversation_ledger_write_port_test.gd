## SupportConversationLedgerWritePort 單元測試(game-shell story-005 AC4 的零件 C1)。
##
## 純記憶體,不碰檔案系統。敏感度證明:見檔尾
## test_sensitivity_proof_a_port_that_does_not_write_is_detected(常駐間諜子類別)。
extends GdUnitTestSuite


## 敏感度證明用:不寫入的假轉接器。
class _SilentPort extends SupportConversationLedgerWritePort:
	func append_record(_pair: AffinityTypes.Pair, _m: float, _source: AffinityTypes.Source) -> void:
		pass


func _always_alive(_roster_id: int) -> bool:
	return true


func _pair_1_2() -> AffinityTypes.Pair:
	return AffinityTypes.pair_of(
		AffinityRosterCharacterMapper.character_for_roster_id(1),
		AffinityRosterCharacterMapper.character_for_roster_id(2)
	)


func test_ledger_port_append_record_adds_one_entry_with_matching_fields() -> void:
	# Arrange
	var ledger := CampaignAffinityLedger.new()
	var port := SupportConversationLedgerWritePort.new(ledger)
	var pair: AffinityTypes.Pair = _pair_1_2()

	# Act
	port.append_record(pair, 2.5, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Assert
	var recs: Array[CampaignAffinityLedger.Entry] = ledger.records()
	assert_int(recs.size()).is_equal(1)
	assert_int(recs[0].pair).is_equal(pair)
	assert_float(recs[0].m).is_equal(2.5)
	assert_int(recs[0].source).is_equal(AffinityTypes.Source.SUPPORT_CONVERSATION)


func test_ledger_port_trigger_positive_record_writes_one_support_conversation_entry() -> void:
	# Arrange
	var ledger := CampaignAffinityLedger.new()
	var port := SupportConversationLedgerWritePort.new(ledger)
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(
		"SC-01,1,1,2,positive"
	)

	# Act
	SupportConversationRules.trigger(record, _always_alive, port)

	# Assert
	var recs: Array[CampaignAffinityLedger.Entry] = ledger.records()
	assert_int(recs.size()).is_equal(1)
	assert_int(recs[0].source).is_equal(AffinityTypes.Source.SUPPORT_CONVERSATION)
	assert_int(recs[0].pair).is_equal(_pair_1_2())


func test_ledger_port_trigger_neutral_record_writes_nothing() -> void:
	# Arrange
	var ledger := CampaignAffinityLedger.new()
	var port := SupportConversationLedgerWritePort.new(ledger)
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(
		"SC-02,1,1,2,neutral"
	)

	# Act
	SupportConversationRules.trigger(record, _always_alive, port)

	# Assert
	assert_int(ledger.records().size()).is_equal(0)


func test_ledger_port_rollback_current_mission_removes_the_written_entry() -> void:
	# Arrange
	var ledger := CampaignAffinityLedger.new()
	var port := SupportConversationLedgerWritePort.new(ledger)
	ledger.begin_mission()

	# Act
	port.append_record(_pair_1_2(), 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	assert_int(ledger.records().size()).is_equal(1)
	ledger.rollback_current_mission()

	# Assert
	assert_int(ledger.records().size()).is_equal(0)


func test_sensitivity_proof_a_port_that_does_not_write_is_detected() -> void:
	# Arrange —— 植入缺陷:append_record 什麼都不寫
	var ledger := CampaignAffinityLedger.new()
	var port := _SilentPort.new(ledger)

	# Act
	port.append_record(_pair_1_2(), 2.5, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Assert —— 與第一條測試相同的斷言在此必須「看得到缺陷」:筆數為 0 而非 1
	assert_int(ledger.records().size()).append_failure_message(
		"敏感度證明失敗:不寫入的轉接器沒有被「筆數 == 1」這類斷言抓到。"
	).is_equal(0)
