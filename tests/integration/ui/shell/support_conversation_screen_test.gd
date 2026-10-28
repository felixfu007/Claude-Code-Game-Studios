# SupportConversationScreen(src/ui/shell/support_conversation_screen.gd)第一段整合測試。
# Story:production/epics/support-conversation-ui/story-003-support-conversation-screen.md
#
# 🔴 甲類明文例外(.claude/rules/test-standards.md 2026-09-16 裁決):
# 讀取已進版控的唯讀資料檔 assets/data/narrative/support_conversation_lines.txt 與
# support_conversations.txt(用來取得「資料說應該有幾句、什麼順序」),並透過 Loc 讀已匯入的 CSV 翻譯。
# 為什麼不能用注入取代:要驗的正是「畫面照真實資料檔播放」,假資料抓不到資料檔打錯字。
# 🔴 乙類明文例外:test_source_* 讀 src/ui/shell/support_conversation_screen.gd 的文字,
# 斷言 AC-12(原始碼不含台詞字面值)。⚠️ 非窮盡性:只掃本檔的非註解行是否含 CJK 字元與已知台詞,
# 看不見組字串、反射、.tscn 內的文字。
#
# 敏感度證明:echo 過濾可證(_MutantNoEchoFilter,set_script 在 add_child 之前、
# 在設任何屬性之前)。不可證:A 類 dialogue_font_size 是 static 純函式、沒有繼承鏈可覆寫
# (改以多解析度算式斷言取代);A' 類「句數/順序與資料一致」斷言真實資料檔內容。
# 逐字速度/推進狀態機未做突變證明,理由:未實作(本段不做)。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/shell/SupportConversationScreen.tscn"
const SOURCE_PATH: String = "res://src/ui/shell/support_conversation_screen.gd"
const LINES_PATH: String = "res://assets/data/narrative/support_conversation_lines.txt"
const CONVERSATIONS_PATH: String = "res://assets/data/narrative/support_conversations.txt"


class _MutantNoEchoFilter extends SupportConversationScreen:
	func _is_echo(_event: InputEvent) -> bool:
		return false


func _read(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_object(f).is_not_null()
	return f.get_as_text()


func _real_script() -> Dictionary:
	var records: Variant = SupportConversationRecord.records_from_text(_read(CONVERSATIONS_PATH))
	var ids: Array[String] = []
	for r: SupportConversationRecord in records:
		ids.append(r.conversation_id)
	return SupportConversationScript.script_from_text(_read(LINES_PATH), ids)


func _make(ids: Array[String], mutant: GDScript = null) -> SupportConversationScreen:
	var instance: SupportConversationScreen = load(SCENE_PATH).instantiate()
	if mutant != null:
		instance.set_script(mutant)  # 必須在設任何屬性之前
	instance.conversation_ids = ids
	add_child(instance)
	auto_free(instance)
	return instance


func _enter(echo: bool = false) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_ENTER
	ev.pressed = true
	ev.echo = echo
	return ev


func _count_signal(screen: SupportConversationScreen) -> Array:
	var counter: Array = [0]
	screen.all_conversations_finished.connect(func() -> void: counter[0] += 1)
	return counter


func _confirm_twice(screen: SupportConversationScreen) -> void:
	screen.handle_input_event(_enter())  # 逐字中 -> 顯示整句
	screen.handle_input_event(_enter())  # 已完整 -> 下一句


# ---- 句數/順序與資料一致 ---------------------------------------------------------

func test_screen_plays_sc01_lines_in_data_order() -> void:
	var lines: Array = SupportConversationScript.lines_for(_real_script(), "SC-01")
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	for i: int in range(lines.size()):
		var entry: Dictionary = lines[i]
		assert_int(screen.diagnostic_current_line_index()).is_equal(i)
		assert_str(screen.diagnostic_current_conversation_id()).is_equal("SC-01")
		assert_str(screen.diagnostic_speaker_text()).is_equal(
			Loc.localize("character.name.%d" % int(entry["speaker_roster_id"]))
		)
		screen.handle_input_event(_enter())
		assert_str(screen.diagnostic_visible_text()).is_equal(Loc.localize(entry["text_key"]))
		if i < lines.size() - 1:
			screen.handle_input_event(_enter())
	assert_int(lines.size()).is_equal(12)


func test_screen_two_confirms_needed_per_line() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	assert_bool(screen.diagnostic_line_fully_shown()).is_false()
	screen.handle_input_event(_enter())
	assert_int(screen.diagnostic_current_line_index()).is_equal(0)
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()
	screen.handle_input_event(_enter())
	assert_int(screen.diagnostic_current_line_index()).is_equal(1)


func test_screen_typewriter_reveals_progressively_and_never_auto_advances() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	screen.advance_typewriter(1.0 / SupportConversationScreen.CHARS_PER_SECOND * 3.0)
	assert_int(screen.diagnostic_visible_text().length()).is_equal(3)
	screen.advance_typewriter(1000.0)
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()
	screen.advance_typewriter(1000.0)
	assert_int(screen.diagnostic_current_line_index()).is_equal(0)


func test_screen_mouse_left_click_advances_but_right_click_does_not() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	var right: InputEventMouseButton = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_bool(screen.handle_input_event(right)).is_false()
	assert_bool(screen.diagnostic_line_fully_shown()).is_false()
	var left: InputEventMouseButton = InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	assert_bool(screen.handle_input_event(left)).is_true()
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()


func test_screen_gamepad_confirm_advances() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	assert_bool(screen.handle_input_event(pad)).is_true()
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()


# ---- echo ----------------------------------------------------------------------

func test_screen_key_echo_does_not_advance() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	assert_bool(screen.handle_input_event(_enter(true))).is_false()
	assert_bool(screen.diagnostic_line_fully_shown()).is_false()
	assert_int(screen.diagnostic_current_line_index()).is_equal(0)


func test_sensitivity_proof_echo_filter_removed_makes_echo_advance() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String], _MutantNoEchoFilter)
	screen.handle_input_event(_enter(true))
	# 突變版:echo 被當成確認,整句被顯示 —— 證明上面那條 echo 測試抓得到缺陷。
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()


# ---- 段落切換與結束訊號 ----------------------------------------------------------

func test_screen_moves_to_next_conversation_after_last_line_and_finishes_once() -> void:
	var script: Dictionary = _real_script()
	var n1: int = SupportConversationScript.lines_for(script, "SC-01").size()
	var n2: int = SupportConversationScript.lines_for(script, "SC-02").size()
	var screen: SupportConversationScreen = _make(["SC-01", "SC-02"] as Array[String])
	var counter: Array = _count_signal(screen)
	for i: int in range(n1 - 1):
		_confirm_twice(screen)
	assert_int(screen.diagnostic_current_line_index()).is_equal(n1 - 1)
	_confirm_twice(screen)  # 最後一句已完整 -> 下一段
	assert_str(screen.diagnostic_current_conversation_id()).is_equal("SC-02")
	assert_int(screen.diagnostic_current_line_index()).is_equal(0)
	assert_int(counter[0]).is_equal(0)
	for i: int in range(n2 - 1):
		_confirm_twice(screen)
	screen.handle_input_event(_enter())
	assert_int(counter[0]).is_equal(0)  # 最後一句剛顯示完,尚未再按
	screen.handle_input_event(_enter())
	assert_int(counter[0]).is_equal(1)
	screen.handle_input_event(_enter())
	screen.handle_input_event(_enter())
	assert_int(counter[0]).is_equal(1)  # 只發一次


func test_screen_empty_conversation_list_finishes_once_deferred() -> void:
	var screen: SupportConversationScreen = _make([] as Array[String])
	var counter: Array = _count_signal(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(counter[0]).is_equal(1)
	assert_bool(screen.diagnostic_is_finished()).is_true()


# ---- 缺字 -----------------------------------------------------------------------

func test_screen_missing_text_key_shows_explicit_marker() -> void:
	var shown: String = SupportConversationScreen.resolve_text("support.no_such_key.line99")
	assert_str(shown).starts_with(SupportConversationScreen.MISSING_MARKER_PREFIX)
	assert_str(shown).contains("support.no_such_key.line99")


# ---- 字級(暫行規則)-------------------------------------------------------------

func test_font_size_matches_provisional_formula_at_four_heights() -> void:
	# 算式:max(24, round(高/30)),再往上取偶數。
	# 768  -> 25.6 -> 26(已偶數)         = 26
	# 1080 -> 36.0 -> 36                  = 36
	# 1440 -> 48.0 -> 48                  = 48
	# 2160 -> 72.0 -> 72                  = 72
	# 540(最小視窗)-> 18 -> 低於下限 24   = 24
	# 800  -> 26.67 -> 27(奇數)-> 28      = 28
	assert_int(SupportConversationScreen.dialogue_font_size(Vector2i(1366, 768))).is_equal(26)
	assert_int(SupportConversationScreen.dialogue_font_size(Vector2i(1920, 1080))).is_equal(36)
	assert_int(SupportConversationScreen.dialogue_font_size(Vector2i(2560, 1440))).is_equal(48)
	assert_int(SupportConversationScreen.dialogue_font_size(Vector2i(3840, 2160))).is_equal(72)
	assert_int(SupportConversationScreen.dialogue_font_size(Vector2i(960, 540))).is_equal(24)
	assert_int(SupportConversationScreen.dialogue_font_size(Vector2i(1280, 800))).is_equal(28)


# ---- AC-12:原始碼不含台詞字面值(乙類)--------------------------------------------

func test_source_has_no_dialogue_literals() -> void:
	var script: Dictionary = _real_script()
	var sample_texts: Array[String] = []
	for id: String in ["SC-01", "SC-02", "SC-03"]:
		for entry: Dictionary in SupportConversationScript.lines_for(script, id):
			sample_texts.append(Loc.localize(entry["text_key"]))
	assert_int(sample_texts.size()).is_equal(39)  # 12 + 14 + 13
	var offending: Array[String] = []
	for raw: String in _read(SOURCE_PATH).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#"):
			continue
		for i: int in range(line.length()):
			if line.unicode_at(i) >= 0x4E00 and line.unicode_at(i) <= 0x9FFF:
				offending.append(line)
				break
		for t: String in sample_texts:
			if line.contains(t):
				offending.append(line)
	assert_array(offending).is_empty()
