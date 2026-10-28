## production/epics/game-shell/story-003-campaign-flow-and-transition-slots.md
## AC1(解析與讀檔分離)/ AC2(資料驅動,非寫死)。
extends GdUnitTestSuite

const _CAMPAIGN_SEQUENCE_PATH: String = "res://assets/data/levels/campaign_sequence.txt"


func test_from_csv_line_parses_all_six_fields() -> void:
	# Arrange
	var line: String = "1,res://a_terrain.txt,res://a_roster.txt,res://a_affinity.txt,res://a_cards.txt,res://a_card_text.txt"

	# Act
	var record: CampaignSequence = CampaignSequence.from_csv_line(line)

	# Assert
	assert_object(record).append_failure_message(
		"合法的 6 欄資料列不應解析失敗"
	).is_not_null()
	assert_int(record.mission_index).is_equal(1)
	assert_str(record.terrain_path).is_equal("res://a_terrain.txt")
	assert_str(record.roster_path).is_equal("res://a_roster.txt")
	assert_str(record.affinity_path).is_equal("res://a_affinity.txt")
	assert_str(record.cards_path).is_equal("res://a_cards.txt")
	assert_str(record.card_text_path).is_equal("res://a_card_text.txt")


func test_from_csv_line_wrong_field_count_returns_null() -> void:
	# Arrange — 缺少 affinity_path / cards_path 兩欄
	var line: String = "1,res://a_terrain.txt,res://a_roster.txt"

	# Act
	var record: CampaignSequence = CampaignSequence.from_csv_line(line)

	# Assert
	assert_object(record).append_failure_message(
		"AC1:欄位數不對必須明確拒絕(回傳 null),不得靜默吞掉或半套解析"
	).is_null()


func test_sequence_from_text_skips_comments_and_blank_lines_and_expresses_more_than_one_mission() -> void:
	# Arrange — 刻意兩列,證明本函式不是只能表達單一寫死的關卡(AC2)
	var text: String = (
		"# 這是註解\n"
		+ "\n"
		+ "1,res://a_terrain.txt,res://a_roster.txt,res://a_affinity.txt,res://a_cards.txt,res://a_card_text.txt\n"
		+ "2,res://b_terrain.txt,res://b_roster.txt,res://b_affinity.txt,res://b_cards.txt,res://b_card_text.txt\n"
	)

	# Act
	var records: Variant = CampaignSequence.sequence_from_text(text)

	# Assert
	assert_array(records).append_failure_message(
		"AC2:資料驅動 —— 本函式必須能表達不只一場,證明不是寫死單一關卡"
	).has_size(2)
	assert_int(records[0].mission_index).is_equal(1)
	assert_int(records[1].mission_index).is_equal(2)


func test_sequence_from_text_invalid_line_returns_null_not_partial_array() -> void:
	# Arrange — 第二列欄位數不對
	var text: String = (
		"1,res://a_terrain.txt,res://a_roster.txt,res://a_affinity.txt,res://a_cards.txt,res://a_card_text.txt\n"
		+ "2,res://b_terrain.txt\n"
	)

	# Act
	var records: Variant = CampaignSequence.sequence_from_text(text)

	# Assert
	assert_object(records).append_failure_message(
		"任一列解析失敗應回傳 null(響亮地停),不得回傳只含合法列的半套陣列"
	).is_null()


## ---- 甲類例外(.claude/rules/test-standards.md 2026-09-16 裁決)----------------
## 讀取已進版控的真實資料檔 assets/data/levels/campaign_sequence.txt,唯讀,
## 不寫入任何檔案。無法用依賴注入取代:本測試要證明的正是「本 story 實際產出的
## 生產資料檔本身可以被這個解析器正確解析」——資料檔打錯字這類錯,只有讀真實
## 檔案才抓得到(本專案已有「資料檔沒打包、151 條測試全綠」的前例)。
## 揭露:本測試不證明窮盡性,只驗證今天這一列的內容。
func test_real_campaign_sequence_file_parses_with_at_least_mission_one() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(_CAMPAIGN_SEQUENCE_PATH)

	# Act
	var records: Variant = CampaignSequence.sequence_from_text(text)

	# Assert
	assert_array(records).append_failure_message(
		(
			"生產資料檔 %s 解析失敗或為空 —— 查核一已知現況是只有第 1 場有真實" +
			"資料,本表至少應能解析出這一列"
		) % _CAMPAIGN_SEQUENCE_PATH
	).has_size(5)  # 2026-10-28 story-007:序列表補上第 3~5 場(原 2)
	assert_int(records[0].mission_index).is_equal(1)
	assert_str(records[0].terrain_path).is_equal("res://assets/data/levels/vs01_terrain.txt")
	# 2026-10-27 story-005 AC4:第 2 場補進序列表(原斷言 has_size(1))
	assert_int(records[1].mission_index).is_equal(2)
	assert_str(records[1].terrain_path).is_equal("res://assets/data/levels/vs02_terrain.txt")
	assert_str(records[0].roster_path).is_equal("res://assets/data/units/vs01_roster.txt")
	assert_str(records[0].affinity_path).is_equal("res://assets/data/affinity/vs01_affinity_links.txt")
	assert_str(records[0].cards_path).is_equal("res://assets/data/cards/vs01_cards.txt")
	assert_str(records[0].card_text_path).is_equal("res://assets/data/cards/vs01_card_text.txt")
	assert_str(records[1].card_text_path).is_equal("res://assets/data/cards/vs02_card_text.txt")
	# 2026-10-28 story-007:第 3~5 列的五個欄位逐一指向同編號的 vs0N 檔
	for n: int in [3, 4, 5]:
		var r: CampaignSequence = records[n - 1]
		assert_int(r.mission_index).is_equal(n)
		assert_str(r.terrain_path).is_equal("res://assets/data/levels/vs0%d_terrain.txt" % n)
		assert_str(r.roster_path).is_equal("res://assets/data/units/vs0%d_roster.txt" % n)
		assert_str(r.affinity_path).is_equal("res://assets/data/affinity/vs0%d_affinity_links.txt" % n)
		assert_str(r.cards_path).is_equal("res://assets/data/cards/vs0%d_cards.txt" % n)
		assert_str(r.card_text_path).is_equal("res://assets/data/cards/vs0%d_card_text.txt" % n)
