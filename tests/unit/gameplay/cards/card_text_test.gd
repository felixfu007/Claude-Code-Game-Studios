# CardText（src/gameplay/cards/card_text.gd）的單元測試。
#
# 🔴 本檔屬 .claude/rules/test-standards.md 2026-09-16 裁決的「甲類」明文例外：
# test_flavor_texts_from_text_parses_vs01_card_text_txt_into_eight_entries 與
# test_flavor_text_content_matches_source_file_verbatim 兩條讀取
# assets/data/cards/vs01_card_text.txt（已進版控的真實資料檔）。
#
# 為什麼不能用注入取代：這兩條要驗的正是「解析器能不能正確讀懂真正會被提交的那份
# 資料檔本身」——包括中文標點(「——」「、」)逐字相符,以及這份檔案實際發生過的表頭
# 陷阱(第 44 行一度是未加 # 的裸表頭 id,flavor_text,會被誤判為第 9 筆資料,已於
# 2026-09-16 修正為 # id,flavor_text)。寫死在測試裡的假資料只能驗證「解析邏輯本身
# 對得起規格」,驗不到「今天這份資料檔的內容是否仍然合法」——而後者正是本專案
# 「資料檔沒打包、遊戲靜默畫空棋盤、151 條測試全綠」那次教訓要防的事。
# 其餘兩條(test_split_only_on_first_comma_preserves_commas_in_flavor_text、
# test_blank_and_comment_lines_are_skipped)用建構出來的字串夾具,不碰檔案系統。
extends GdUnitTestSuite


# ---- flavor_texts_from_text() ---------------------------------------------

func test_flavor_texts_from_text_parses_vs01_card_text_txt_into_eight_entries() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(
		"res://assets/data/cards/vs01_card_text.txt"
	)
	assert_str(text).is_not_empty()

	# Act
	var flavor_texts: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	# Assert
	assert_int(flavor_texts.size()).is_equal(8)
	for i in range(1, 9):
		var id: String = "card_%02d" % i
		assert_bool(flavor_texts.has(id)).append_failure_message(
			"Missing expected key %s" % id
		).is_true()


func test_flavor_text_content_matches_source_file_verbatim() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(
		"res://assets/data/cards/vs01_card_text.txt"
	)

	# Act
	var flavor_texts: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	# Assert — 逐字比對，含中文標點（「——」「、」）
	assert_str(flavor_texts["card_01"]).is_equal(
		"甲:「我先上、別管我」——這股衝勁讓她這回合下手更狠"
	)
	assert_str(flavor_texts["card_08"]).is_equal(
		"丙眼神閃避不敢與丁對視——這份心虛丁看得一清二楚"
	)


func test_split_only_on_first_comma_preserves_commas_in_flavor_text() -> void:
	# Arrange — 刻意構造一筆 flavor_text 內容含逗號的測試資料
	var text: String = "card_99,甲說,「這句話裡,有兩個逗號」\n"

	# Act
	var flavor_texts: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	# Assert — 只在第一個逗號分割，第二、三個逗號留在 flavor_text 裡
	assert_int(flavor_texts.size()).is_equal(1)
	assert_str(flavor_texts["card_99"]).is_equal("甲說,「這句話裡,有兩個逗號」")


func test_blank_and_comment_lines_are_skipped() -> void:
	# Arrange — 混入註解行與空行，只有兩行是真正資料
	var text: String = (
		"# this is a comment\n"
		+ "\n"
		+ "card_01,第一張卡的文字\n"
		+ "   \n"
		+ "# another comment\n"
		+ "card_02,第二張卡的文字\n"
	)

	# Act
	var flavor_texts: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	# Assert
	assert_int(flavor_texts.size()).is_equal(2)
	assert_str(flavor_texts["card_01"]).is_equal("第一張卡的文字")
	assert_str(flavor_texts["card_02"]).is_equal("第二張卡的文字")
