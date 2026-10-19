# SupportConversationRecord(src/gameplay/narrative/support_conversation_record.gd)
# 的單元測試。
#
# 純資料類別(RefCounted),不建立任何 Node,不需要 tear-down,不會留下孤兒節點。
# 命名慣例沿用既有先例 tests/unit/gameplay/affinity/affinity_link_test.gd 的
# test_[scenario]_[expected]。
#
# 🔴 本檔的 test_records_from_text_loads_the_real_data_file_matches_mvp_skeleton_table()
# 與 test_records_from_text_real_file_has_no_conversation_at_last_slot() 兩條屬
# .claude/rules/test-standards.md 2026-09-16 裁決的「甲類」明文例外:讀取
# assets/data/narrative/support_conversations.txt(已進版控的真實資料檔)。
# 為什麼不能用注入取代:這兩條要驗的正是「解析器能不能正確讀懂真正會被提交的那份
# 資料檔本身」,包含 story AC-1 要求的三段對話內容是否與
# mvp-five-levels-skeleton.md 第三部分逐字一致 —— 寫死在測試裡的假資料驗不到
# 「今天這份資料檔的內容是否仍然合法」,這正是本專案登記過的「資料檔沒打包、
# 遊戲靜默畫空棋盤、151 條測試全綠」那次教訓要防的事。其餘測試一律用建構出來的
# 字串夾具,不碰檔案系統。
extends GdUnitTestSuite

const SUPPORT_CONVERSATIONS_PATH: String = "res://assets/data/narrative/support_conversations.txt"

# 以下常數是餵給解析器的合成資料,不是本作的真實內容 —— 真實資料表只在
# test_records_from_text_loads_the_real_data_file_matches_mvp_skeleton_table() 裡斷言。
const LINE_POSITIVE: String = "SC-TEST-01,1,1,2,positive"
const LINE_NEGATIVE: String = "SC-TEST-02,2,3,4,negative"
const LINE_NEUTRAL: String = "SC-TEST-03,3,2,4,neutral"


# ---- from_csv_line() --------------------------------------------------------

func test_from_csv_line_parses_every_field_correctly() -> void:
	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)

	# Assert
	assert_str(record.conversation_id).is_equal("SC-TEST-01")
	assert_int(record.trigger_after_mission).is_equal(1)
	assert_int(record.pair_a).is_equal(1)
	assert_int(record.pair_b).is_equal(2)
	assert_int(record.valence).is_equal(SupportConversationRecord.Valence.POSITIVE)


func test_from_csv_line_parses_negative_valence() -> void:
	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_NEGATIVE)

	# Assert
	assert_int(record.valence).is_equal(SupportConversationRecord.Valence.NEGATIVE)


func test_from_csv_line_parses_neutral_valence() -> void:
	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_NEUTRAL)

	# Assert
	assert_int(record.valence).is_equal(SupportConversationRecord.Valence.NEUTRAL)


func test_from_csv_line_initial_state_is_not_triggered() -> void:
	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)

	# Assert
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.NOT_TRIGGERED)


# AC-2 — 畸形輸入:欄位數不對。
#
# 2026-10-19 協調者覆核後改為 push_error() + 明確 return null(見
# from_csv_line() 文件註解的完整理由,含既有反例
# board_passable_test.gd 的 test_unregistered_terrain_character_returns_
# explicit_sentinels_not_silent_fallback 作為「push_error() 不會讓測試變紅」
# 的佐證,協調者提供、本檔作者已獨立複驗該測試確實 PASSED 才採用)——原本
# 用 assert() 時這條路徑不可測(GdUnit4 把 assert() 失敗算成測試錯誤),
# 現在改用 push_error() 後行為對呼叫端不變,但測得出來了。
func test_from_csv_line_wrong_field_count_returns_null() -> void:
	# Arrange — 缺 valence 欄位
	var line: String = "SC-BAD,1,1,2"

	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(line)

	# Assert
	assert_object(record).is_null()


# AC-2 — 畸形輸入:未知 valence
func test_from_csv_line_unknown_valence_returns_null() -> void:
	# Arrange — 大小寫錯誤,本表格式一律小寫
	var line: String = "SC-BAD,1,1,2,POSITIVE"

	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(line)

	# Assert
	assert_object(record).is_null()


# AC-2 — 畸形輸入:未知角色(超出 1~5 名冊範圍,6 是敵方名冊 id)
func test_from_csv_line_unknown_character_returns_null() -> void:
	# Arrange
	var line: String = "SC-BAD,1,1,6,positive"

	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(line)

	# Assert
	assert_object(record).is_null()


# AC-2 — 畸形輸入:兩個角色相同(自己跟自己不構成一段對話)
func test_from_csv_line_same_character_for_both_pairs_returns_null() -> void:
	# Arrange
	var line: String = "SC-BAD,1,3,3,positive"

	# Act
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(line)

	# Assert
	assert_object(record).is_null()


# ---- records_from_text() ----------------------------------------------------

func test_records_from_text_parses_three_records_in_file_order() -> void:
	# Arrange
	var text: String = "%s\n%s\n%s" % [LINE_POSITIVE, LINE_NEGATIVE, LINE_NEUTRAL]

	# Act
	var records: Array[SupportConversationRecord] = SupportConversationRecord.records_from_text(text)

	# Assert
	assert_int(records.size()).is_equal(3)
	assert_str(records[0].conversation_id).is_equal("SC-TEST-01")
	assert_str(records[1].conversation_id).is_equal("SC-TEST-02")
	assert_str(records[2].conversation_id).is_equal("SC-TEST-03")


func test_records_from_text_skips_comment_and_blank_lines() -> void:
	# Arrange
	var text: String = "# 註解\n\n%s\n   \n# 又一行\n%s" % [LINE_POSITIVE, LINE_NEGATIVE]

	# Act
	var records: Array[SupportConversationRecord] = SupportConversationRecord.records_from_text(text)

	# Assert
	assert_int(records.size()).is_equal(2)


func test_records_from_text_empty_text_returns_empty_array() -> void:
	# Act
	var records: Array[SupportConversationRecord] = SupportConversationRecord.records_from_text("")

	# Assert — 空表是合法狀態,不是錯誤
	assert_int(records.size()).is_equal(0)


func test_records_from_text_unknown_valence_returns_null_not_partial_array() -> void:
	# Arrange — 刻意在壞列前後各放一個合法列,證明一列壞掉會讓整張表失敗,
	# 不是只丟掉那一列(比照 AffinityLink.links_from_text 既有慣例)。
	var text: String = "%s\nSC-BAD,1,1,2,POSITIVE\n%s" % [LINE_POSITIVE, LINE_NEGATIVE]

	# Act
	var records: Variant = SupportConversationRecord.records_from_text(text)

	# Assert — null(解析失敗),不是空陣列或部分成功的陣列
	assert_object(records).is_null()


func test_records_from_text_loads_the_real_data_file_matches_mvp_skeleton_table() -> void:
	# Arrange — design/quick-specs/mvp-five-levels-skeleton.md 第三部分 Q1~Q3 定案內容
	assert_bool(FileAccess.file_exists(SUPPORT_CONVERSATIONS_PATH)).is_true()
	var text: String = FileAccess.get_file_as_string(SUPPORT_CONVERSATIONS_PATH)

	# Act
	var records: Array[SupportConversationRecord] = SupportConversationRecord.records_from_text(text)

	# Assert
	assert_int(records.size()).is_equal(3)

	assert_str(records[0].conversation_id).is_equal("SC-01")
	assert_int(records[0].trigger_after_mission).is_equal(1)
	assert_int(records[0].pair_a).is_equal(1)
	assert_int(records[0].pair_b).is_equal(2)
	assert_int(records[0].valence).is_equal(SupportConversationRecord.Valence.POSITIVE)

	assert_str(records[1].conversation_id).is_equal("SC-02")
	assert_int(records[1].trigger_after_mission).is_equal(2)
	assert_int(records[1].pair_a).is_equal(1)
	assert_int(records[1].pair_b).is_equal(3)
	assert_int(records[1].valence).is_equal(SupportConversationRecord.Valence.NEGATIVE)

	assert_str(records[2].conversation_id).is_equal("SC-03")
	assert_int(records[2].trigger_after_mission).is_equal(3)
	assert_int(records[2].pair_a).is_equal(2)
	assert_int(records[2].pair_b).is_equal(4)
	assert_int(records[2].valence).is_equal(SupportConversationRecord.Valence.POSITIVE)


func test_records_from_text_real_file_has_no_conversation_at_last_slot() -> void:
	# AC-1 補充:4→5 槽位(trigger_after_mission=4)刻意空置,戊(5)不參與任何一段。
	# Arrange
	var text: String = FileAccess.get_file_as_string(SUPPORT_CONVERSATIONS_PATH)
	var records: Array[SupportConversationRecord] = SupportConversationRecord.records_from_text(text)

	# Act / Assert
	for record: SupportConversationRecord in records:
		assert_int(record.trigger_after_mission).append_failure_message(
			"4→5 槽位(trigger_after_mission=4)應刻意空置"
		).is_not_equal(4)
		assert_bool(record.pair_a == 5 or record.pair_b == 5).append_failure_message(
			"戊(roster id 5)不參與任何一段支援對話"
		).is_false()


# ---- try_transition() — AC-3/AC-7 狀態機 ------------------------------------

func test_try_transition_not_triggered_to_completed_is_legal() -> void:
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)

	# Act
	var ok: bool = record.try_transition(SupportConversationRecord.TriggerState.COMPLETED)

	# Assert
	assert_bool(ok).is_true()
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.COMPLETED)


func test_try_transition_not_triggered_to_skipped_is_legal() -> void:
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)

	# Act
	var ok: bool = record.try_transition(SupportConversationRecord.TriggerState.SKIPPED)

	# Assert
	assert_bool(ok).is_true()
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.SKIPPED)


func test_try_transition_completed_to_anything_is_illegal_and_state_unchanged() -> void:
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	record.try_transition(SupportConversationRecord.TriggerState.COMPLETED)

	# Act
	var ok: bool = record.try_transition(SupportConversationRecord.TriggerState.SKIPPED)

	# Assert
	assert_bool(ok).is_false()
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.COMPLETED)


func test_try_transition_skipped_to_anything_is_illegal_and_state_unchanged() -> void:
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)
	record.try_transition(SupportConversationRecord.TriggerState.SKIPPED)

	# Act
	var ok: bool = record.try_transition(SupportConversationRecord.TriggerState.COMPLETED)

	# Assert
	assert_bool(ok).is_false()
	assert_int(record.state).is_equal(SupportConversationRecord.TriggerState.SKIPPED)


func test_try_transition_not_triggered_to_itself_is_illegal() -> void:
	# NOT_TRIGGERED 不是自己的合法目的地 —— 轉移代表「發生了一件事」,原地不動
	# 不是合法轉移。
	# Arrange
	var record: SupportConversationRecord = SupportConversationRecord.from_csv_line(LINE_POSITIVE)

	# Act
	var ok: bool = record.try_transition(SupportConversationRecord.TriggerState.NOT_TRIGGERED)

	# Assert
	assert_bool(ok).is_false()


# AC-7 — 「沒有可延後狀態」要體現在型別上:只有 3 個合法值,找不到第 4 個中繼狀態。
func test_trigger_state_enum_has_exactly_three_values_no_deferred_state() -> void:
	assert_int(SupportConversationRecord.TriggerState.values().size()).is_equal(3)
