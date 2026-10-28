# SupportConversationScript(src/gameplay/narrative/support_conversation_script.gd)
# 與真實台詞資料檔的單元測試。
# Story:production/epics/support-conversation-ui/story-002-dialogue-lines-data.md
#
# 🔴 甲類明文例外(.claude/rules/test-standards.md 2026-09-16 裁決):
# test_real_* 系列讀取已進版控的唯讀資料檔
#   assets/data/narrative/support_conversation_lines.txt
#   assets/data/narrative/support_conversations.txt
# 並透過 Loc.localize() 讀取已匯入的 assets/data/locales/strings.csv 翻譯。
# 為什麼不能用注入取代:AC1/AC2 要驗的正是「今天會被提交的那份資料檔與 CSV 是否與劇本
# 逐字一致」,寫死在測試裡的假資料抓不到資料檔打錯字。
# 其餘測試(AC3 拒絕行為)一律用建構出來的字串夾具,不碰檔案系統。
#
# 敏感度證明:解析器是 static 純函式、真實資料檔為內容 —— 屬 test-standards.md 的
# A 類與 A′ 類「證明不了」(沒有繼承鏈可覆寫、沒有類別可注入錯誤版本)。替代做法:
# AC3 每種壞格式各有一條測試,餵入「剛好壞一處」的輸入並斷言回 null,等於對每條拒絕
# 分支各自示範它抓得到對應缺陷。⚠️ 未包含窮盡性:本檔不證明「資料檔沒有任何其他錯誤」。
extends GdUnitTestSuite

const LINES_PATH: String = "res://assets/data/narrative/support_conversation_lines.txt"
const CONVERSATIONS_PATH: String = "res://assets/data/narrative/support_conversations.txt"

# 劇本 design/narrative/support-conversations-script.md 的說話者序列(甲=1 … 戊=5)。
const EXPECTED_SPEAKERS: Dictionary = {
	"SC-01": [1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2],
	"SC-02": [1, 3, 1, 3, 1, 1, 3, 1, 3, 1, 3, 1, 3, 1],
	"SC-03": [4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4, 2, 4],
}

# 抽樣:{ conversation_id: { seq(1-based): 台詞逐字 } },每段至少首句與末句。
const EXPECTED_TEXT: Dictionary = {
	"SC-01": {1: "今天北路那段,你站的位置剛剛好。", 12: "好。明天也是,妳破門,我在後面。"},
	"SC-02": {1: "董振豪,我有話問你。", 14: "……路要帶好。我也沒打算把你丟下。"},
	"SC-03": {1: "你的手法很穩。受傷的人都安靜下來了。", 13: "那以後,換你提醒我。我也提醒你。"},
}

const KNOWN_IDS: Array[String] = ["SC-01", "SC-02"]
const GOOD_TEXT: String = "SC-01,1,1,k.a\nSC-01,2,2,k.b\nSC-02,1,3,k.c"


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(f).is_not_null()
	return f.get_as_text()


func _real_script() -> Dictionary:
	var records: Variant = SupportConversationRecord.records_from_text(_read(CONVERSATIONS_PATH))
	assert_object(records).is_not_null()
	var ids: Array[String] = []
	for r: SupportConversationRecord in records:
		ids.append(r.conversation_id)
	var parsed: Variant = SupportConversationScript.script_from_text(_read(LINES_PATH), ids)
	assert_object(parsed).is_not_null()
	return parsed


# ---- AC1 ---------------------------------------------------------------------

func test_real_ac1_line_counts_match_script() -> void:
	var s: Dictionary = _real_script()
	assert_int(SupportConversationScript.lines_for(s, "SC-01").size()).is_equal(12)
	assert_int(SupportConversationScript.lines_for(s, "SC-02").size()).is_equal(14)
	assert_int(SupportConversationScript.lines_for(s, "SC-03").size()).is_equal(13)
	assert_int(s.size()).is_equal(3)


func test_real_ac1_speakers_and_order_match_script() -> void:
	var s: Dictionary = _real_script()
	for id: String in EXPECTED_SPEAKERS:
		var actual: Array = []
		for line: Dictionary in SupportConversationScript.lines_for(s, id):
			actual.append(line[SupportConversationScript.KEY_SPEAKER])
		assert_array(actual).is_equal(EXPECTED_SPEAKERS[id])


func test_real_ac1_text_keys_follow_naming_and_are_unique() -> void:
	var s: Dictionary = _real_script()
	var seen: Dictionary = {}
	for id: String in s:
		var n: int = 0
		for line: Dictionary in s[id]:
			n += 1
			var expected_key: String = "support.sc%s.line%02d" % [id.substr(3), n]
			assert_str(line[SupportConversationScript.KEY_TEXT_KEY]).is_equal(expected_key)
			assert_bool(seen.has(expected_key)).is_false()
			seen[expected_key] = true


# ---- AC2 ---------------------------------------------------------------------

func test_real_ac2_every_text_key_localizes_and_sampled_lines_match_script_verbatim() -> void:
	var s: Dictionary = _real_script()
	for id: String in s:
		for line: Dictionary in s[id]:
			var key: String = line[SupportConversationScript.KEY_TEXT_KEY]
			var localized: String = Loc.localize(key)
			# 缺翻譯時 Loc 回傳鍵名本身;不得等於鍵名、不得為空。
			assert_str(localized).is_not_empty()
			assert_str(localized).is_not_equal(key)
	for id: String in EXPECTED_TEXT:
		for seq: int in EXPECTED_TEXT[id]:
			var line: Dictionary = SupportConversationScript.lines_for(s, id)[seq - 1]
			assert_str(Loc.localize(line[SupportConversationScript.KEY_TEXT_KEY])).is_equal(EXPECTED_TEXT[id][seq])


func test_real_ac2_character_names_exist() -> void:
	var expected: Array[String] = ["藍亭萱", "徐培恩", "董振豪", "秦亦柔", "麥子健"]
	for i: int in range(5):
		assert_str(Loc.localize("character.name.%d" % (i + 1))).is_equal(expected[i])


# ---- AC3(合成夾具,不碰檔案)--------------------------------------------------

func test_parse_good_text_returns_ordered_lines() -> void:
	var s: Variant = SupportConversationScript.script_from_text(GOOD_TEXT, KNOWN_IDS)
	assert_object(s).is_not_null()
	var d: Dictionary = s
	assert_int(SupportConversationScript.lines_for(d, "SC-01").size()).is_equal(2)
	assert_str(SupportConversationScript.lines_for(d, "SC-01")[1][SupportConversationScript.KEY_TEXT_KEY]).is_equal("k.b")
	assert_int(SupportConversationScript.lines_for(d, "SC-02")[0][SupportConversationScript.KEY_SPEAKER]).is_equal(3)


func test_parse_comments_and_blank_lines_are_skipped() -> void:
	var s: Variant = SupportConversationScript.script_from_text("# c\n\n" + GOOD_TEXT + "\n", KNOWN_IDS)
	assert_object(s).is_not_null()


func test_parse_wrong_field_count_returns_null() -> void:
	assert_object(SupportConversationScript.script_from_text("SC-01,1,1", KNOWN_IDS)).is_null()
	assert_object(SupportConversationScript.script_from_text("SC-01,1,1,k,extra", KNOWN_IDS)).is_null()


func test_parse_seq_gap_returns_null() -> void:
	assert_object(SupportConversationScript.script_from_text("SC-01,1,1,k.a\nSC-01,3,2,k.b", KNOWN_IDS)).is_null()


func test_parse_seq_not_starting_at_one_returns_null() -> void:
	assert_object(SupportConversationScript.script_from_text("SC-01,2,1,k.a", KNOWN_IDS)).is_null()


func test_parse_duplicate_seq_returns_null() -> void:
	assert_object(SupportConversationScript.script_from_text("SC-01,1,1,k.a\nSC-01,1,2,k.b", KNOWN_IDS)).is_null()


func test_parse_speaker_out_of_range_returns_null() -> void:
	assert_object(SupportConversationScript.script_from_text("SC-01,1,0,k.a", KNOWN_IDS)).is_null()
	assert_object(SupportConversationScript.script_from_text("SC-01,1,6,k.a", KNOWN_IDS)).is_null()
	assert_object(SupportConversationScript.script_from_text("SC-01,1,x,k.a", KNOWN_IDS)).is_null()


func test_parse_unknown_conversation_id_returns_null() -> void:
	assert_object(SupportConversationScript.script_from_text("SC-99,1,1,k.a", KNOWN_IDS)).is_null()


func test_parse_empty_text_key_returns_null() -> void:
	assert_object(SupportConversationScript.script_from_text("SC-01,1,1,", KNOWN_IDS)).is_null()


func test_parse_non_contiguous_conversation_rows_returns_null() -> void:
	var text: String = "SC-01,1,1,k.a\nSC-02,1,1,k.b\nSC-01,2,2,k.c"
	assert_object(SupportConversationScript.script_from_text(text, KNOWN_IDS)).is_null()


func test_lines_for_unknown_id_returns_empty() -> void:
	assert_array(SupportConversationScript.lines_for({}, "SC-01")).is_empty()
