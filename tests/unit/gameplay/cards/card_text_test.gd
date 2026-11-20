# CardText（src/gameplay/cards/card_text.gd）的單元測試 —— story-029 三欄格式 id,card_name,effect_line。
#
# 🔴 本檔屬 .claude/rules/test-standards.md 2026-09-16 裁決的「甲類」明文例外:
# 數條測試讀取 assets/data/cards/*_card_text.txt(已進版控的真實資料檔)。
# 為什麼不能用注入取代:要驗的正是「解析器能不能讀懂真正會被提交的那幾份資料檔」
# 與「資料檔不再含【 】/代價：/甲乙丙丁戊」——寫死的假資料驗不到今天資料檔是否仍合法。
# 甲類自陳:這些掃描不證明窮盡性(只掃下列 const 列出的 6 份檔案)。
# 其餘測試用建構出來的字串夾具,不碰檔案系統。
#
# 敏感度證明:AC6② 「解析器接受錯誤欄數」—— 常駐測試用寬鬆替身解析器(接受 2 欄)
# 展示:AC1 的欄數檢查若被拿掉,本檔的「舊兩欄應被拒絕」判準會轉紅。
extends GdUnitTestSuite

const _CARD_TEXT_FILES: Array[String] = [
	"res://assets/data/cards/vs01_card_text.txt",
	"res://assets/data/cards/vs02_card_text.txt",
	"res://assets/data/cards/vs03_card_text.txt",
	"res://assets/data/cards/vs04_card_text.txt",
	"res://assets/data/cards/vs05_card_text.txt",
	"res://assets/data/cards/tutorial_card_text.txt",
]


## 敏感度證明用:錯誤的寬鬆解析器 —— 不檢查欄數,2 欄也收(忽略缺的第三欄)。
static func _lenient_parse_accepts(text: String) -> bool:
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",", true, 2)
		if fields.size() < 2:
			return false
	return true


# ---- AC1 解析 -------------------------------------------------------------

func test_faces_from_text_parses_three_columns() -> void:
	var text: String = "card_01,我先上,藍亭萱衝上去\ncard_02,,沒有牌名\n"

	var names: Dictionary[String, String] = CardText.card_names_from_text(text)
	var effects: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	assert_int(names.size()).is_equal(2)
	assert_str(names["card_01"]).is_equal("我先上")
	assert_str(effects["card_01"]).is_equal("藍亭萱衝上去")
	assert_str(names["card_02"]).is_equal("")
	assert_str(effects["card_02"]).is_equal("沒有牌名")


func test_extra_commas_stay_in_effect_line() -> void:
	var text: String = "card_99,名,甲說,「這句話裡,有逗號」\n"

	var effects: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	assert_str(effects["card_99"]).is_equal("甲說,「這句話裡,有逗號」")


func test_blank_and_comment_lines_are_skipped() -> void:
	var text: String = (
		"# this is a comment\n"
		+ "\n"
		+ "card_01,名一,第一張卡的文字\n"
		+ "   \n"
		+ "# another comment\n"
		+ "card_02,名二,第二張卡的文字\n"
	)

	var effects: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	assert_int(effects.size()).is_equal(2)
	assert_str(effects["card_02"]).is_equal("第二張卡的文字")


func test_old_two_column_line_is_rejected_whole_table() -> void:
	var text: String = "card_01,名一,第一張\ncard_02,舊兩欄格式的文字\ncard_03,名三,第三張\n"
	var result: Array = [null]
	var call: Callable = func() -> void:
		result[0] = CardText.faces_from_text(text)

	await assert_error(call).is_push_error(any_string())

	assert_int((result[0] as Dictionary).size()).is_equal(0)


func test_missing_comma_line_discards_entire_table() -> void:
	var text: String = "card_01,名一,第一張\nthis line has no comma\n"
	var result: Array = [null]
	var call: Callable = func() -> void:
		result[0] = CardText.faces_from_text(text)

	await assert_error(call).is_push_error(any_string())

	assert_int((result[0] as Dictionary).size()).is_equal(0)


# ---- 真實資料檔 -------------------------------------------------------------

func test_all_real_card_text_files_parse_with_expected_row_counts() -> void:
	var expected: Array[int] = [8, 14, 14, 14, 14, 0]
	for i: int in range(_CARD_TEXT_FILES.size()):
		var text: String = FileAccess.get_file_as_string(_CARD_TEXT_FILES[i])
		var faces: Dictionary[String, PackedStringArray] = CardText.faces_from_text(text)
		assert_int(faces.size()).append_failure_message(_CARD_TEXT_FILES[i]).is_equal(expected[i])


func test_vs01_content_matches_narrative_ruling_verbatim() -> void:
	var text: String = FileAccess.get_file_as_string(_CARD_TEXT_FILES[0])

	var names: Dictionary[String, String] = CardText.card_names_from_text(text)
	var effects: Dictionary[String, String] = CardText.flavor_texts_from_text(text)

	assert_str(names["card_01"]).is_equal("我先上")
	assert_str(effects["card_01"]).is_equal(
		"藍亭萱：「我先上、別管我」——這股衝勁讓她這回合下手更狠"
	)
	assert_str(effects["card_02"]).contains("{duration_rounds}")
	assert_str(names["card_08"]).is_equal("不敢對視")


func test_vs04_card_08_keeps_scene_variant() -> void:
	var effects: Dictionary[String, String] = CardText.flavor_texts_from_text(
		FileAccess.get_file_as_string(_CARD_TEXT_FILES[3])
	)

	assert_str(effects["card_08"]).is_equal(
		"董振豪不敢與秦亦柔對視——這是他待過的地方，心虛被她看穿"
	)


# ---- AC3 資料內不含舊裝飾與代號 ---------------------------------------------
# 為避免本檔自己命中:用 unicode 跳脫組字,不把被禁字面寫進本檔。
func test_ac3_data_has_no_brackets_cost_prefix_or_code_names() -> void:
	var banned: Array[String] = [
		String.chr(0x3010), String.chr(0x3011),
		String.chr(0x4EE3) + String.chr(0x50F9) + String.chr(0xFF1A),
		String.chr(0x7532), String.chr(0x4E59), String.chr(0x4E19),
		String.chr(0x4E01), String.chr(0x620A),
	]
	for path: String in _CARD_TEXT_FILES:
		for raw_line: String in FileAccess.get_file_as_string(path).split("\n"):
			if raw_line.strip_edges().begins_with("#"):
				continue
			for b: String in banned:
				assert_bool(raw_line.contains(b)).append_failure_message(
					"%s 含被禁字面 U+%X:%s" % [path, b.unicode_at(0), raw_line]
				).is_false()


# ---- AC6② 敏感度證明 --------------------------------------------------------

func test_sensitivity_proof_lenient_parser_accepts_old_two_column() -> void:
	var old_format: String = "card_01,舊兩欄格式的文字\n"
	# 偵測器(真解析器)拒絕它 ……
	var real: Array = [null]
	var call: Callable = func() -> void:
		real[0] = CardText.faces_from_text(old_format)
	await assert_error(call).is_push_error(any_string())
	assert_int((real[0] as Dictionary).size()).is_equal(0)
	# …… 而「接受錯誤欄數」的替身會放行 —— 證明本檔 old_two_column 判準對該缺陷敏感。
	assert_bool(_lenient_parse_accepts(old_format)).is_true()
