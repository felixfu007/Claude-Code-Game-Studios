# SupportConversationScreen(src/ui/shell/support_conversation_screen.gd)整合測試。
# Story:production/epics/support-conversation-ui/story-003-support-conversation-screen.md
#
# 🔴 甲類明文例外(.claude/rules/test-standards.md 2026-09-16 裁決):
# 讀取已進版控的唯讀資料檔 assets/data/narrative/support_conversation_lines.txt 與
# support_conversations.txt(取得「資料說應該有幾句、什麼順序」),並透過 Loc 讀已匯入的 CSV 翻譯。
# 為什麼不能用注入取代:要驗的正是「畫面照真實資料檔播放」,假資料抓不到資料檔打錯字。
# 🔴 乙類明文例外:test_source_* 讀 src/ui/shell/support_conversation_screen.gd 的文字,
# 斷言 AC-12。⚠️ 非窮盡性:只掃非註解行是否含 CJK 字元與已知 39 句台詞,
# 看不見組字串、反射、.tscn 內的文字。
#
# 全域狀態:畫面會登記 CursorStateHost 的 DIALOGUE_CHOICE 表面並寫目標 ——
# before_test 用 CursorHostSnapshot.capture(),after_test 先卸下並釋放所有畫面再 restore()。
#
# ═══ 敏感度對照表(.claude/rules/test-standards.md 2026-09-16 門檻;逐條,不合併)═══
# 「D」= 唯一有意義的注入點就是受測的那段邏輯本身,突變等於重寫它,證明會變成重言式。
# 「A」= static 純函式沒有繼承鏈可覆寫。「A′」= 斷言真實資料檔/原始碼內容,無類別可注入錯誤版本。
#
# 第一段(12 條)
#  1 test_screen_plays_sc01_lines_in_data_order ........ A′(斷言真實資料檔內容與順序)。⚠️ 未證明
#  2 test_screen_two_confirms_needed_per_line .......... D(request_advance 的分支即受測物)。⚠️ 未證明
#  3 test_screen_typewriter_reveals_progressively... ... D(advance_typewriter 即受測物)。⚠️ 未證明
#  4 test_screen_mouse_left_click_advances_but_right_... D(handle_input_event 的分支即受測物)。⚠️ 未證明
#  5 test_screen_gamepad_confirm_advances .............. A′(斷言 project.godot 的 battle_confirm 映射)。⚠️ 未證明
#  6 test_screen_key_echo_does_not_advance ............. 可證 -> #7
#  7 test_sensitivity_proof_echo_filter_removed_... .... 本身即證明(_MutantNoEchoFilter)
#  8 test_screen_moves_to_next_conversation_... ........ D。⚠️ 未證明
#  9 test_screen_empty_conversation_list_finishes_... .. D。⚠️ 未證明
# 10 test_screen_missing_text_key_shows_explicit_marker  A(static resolve_text)。⚠️ 未證明
# 11 test_font_size_matches_provisional_formula_... .... A(static dialogue_font_size);以多解析度算式斷言替代
# 12 test_source_has_no_dialogue_literals .............. A′(斷言原始碼內容)。⚠️ 未證明
# 第二段
# 13 test_skip_panel_opens_with_default_focus_on_cancel ... 可證 -> #14
# 14 test_sensitivity_proof_default_focus_confirm_... ..... 本身即證明(_MutantDefaultFocusConfirm)
# 15 test_skip_cancel_returns_to_same_line_zero_state_change D(關面板即不改狀態,沒有可注入的第二路徑)。⚠️ 未證明
# 16 test_skip_confirm_key_on_default_focus_cancels ........ 可證 -> #14(同一突變:預設焦點換成確定)
# 17 test_skip_confirm_shows_last_line_then_one_confirm_finishes D。⚠️ 未證明
# 18 test_skip_multi_conversation_skips_only_current ....... D。⚠️ 未證明
# 19 test_skip_and_full_read_share_same_completion_path .... D(性質是「不存在第二條分支」,沒有東西可突變)。⚠️ 未證明
# 20 test_skip_panel_blocks_mouse_advance .................. D。⚠️ 未證明
# 21 test_review_back_is_readonly_and_cannot_pass_progress . D(回看上界是結構性的:forward 在到達 _line_index 即離開)。⚠️ 未證明
# 22 test_review_confirm_moves_one_step_toward_newest ...... D。⚠️ 未證明
# 23 test_cursor_surface_registered_and_seeded_on_ready .... A′(斷言全域單例 CursorStateHost 的狀態,第六類)。⚠️ 未證明
# 24 test_cursor_navigate_panel_and_normal_modes ........... D
# 25 test_unload_hands_off_cursor_target ................... 可證 -> #26
# 26 test_sensitivity_proof_no_handoff_leaves_target_valid . 本身即證明(_MutantNoHandoff)
# 27 test_ui_texts_come_from_localization .................. A′(斷言 CSV 內容)。⚠️ 未證明
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/shell/SupportConversationScreen.tscn"
const SOURCE_PATH: String = "res://src/ui/shell/support_conversation_screen.gd"
const LINES_PATH: String = "res://assets/data/narrative/support_conversation_lines.txt"
const CONVERSATIONS_PATH: String = "res://assets/data/narrative/support_conversations.txt"

var _snap: CursorHostSnapshot
var _screens: Array[SupportConversationScreen] = []


class _MutantNoEchoFilter extends SupportConversationScreen:
	func _is_echo(_event: InputEvent) -> bool:
		return false


class _MutantDefaultFocusConfirm extends SupportConversationScreen:
	func _default_skip_focus_id() -> int:
		return SupportConversationScreen.TARGET_PANEL_CONFIRM


class _MutantNoHandoff extends SupportConversationScreen:
	func _on_tree_exited_cursor_handoff() -> void:
		CursorStateHost.unregister_surface(CursorTypes.SurfaceType.DIALOGUE_CHOICE)


func before_test() -> void:
	_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	for s: SupportConversationScreen in _screens:
		if is_instance_valid(s):
			if s.is_inside_tree():
				remove_child(s)
			s.free()
	_screens.clear()
	_snap.restore()


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
	_screens.append(instance)
	return instance


func _key(code: Key, echo: bool = false, shift: bool = false) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.echo = echo
	ev.shift_pressed = shift
	return ev


func _enter(echo: bool = false) -> InputEventKey:
	return _key(KEY_ENTER, echo)


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var pad: InputEventJoypadButton = InputEventJoypadButton.new()
	pad.button_index = button
	pad.pressed = true
	return pad


func _click_at(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = pos
	return ev


func _count_signal(screen: SupportConversationScreen) -> Array:
	var counter: Array = [0]
	screen.all_conversations_finished.connect(func() -> void: counter[0] += 1)
	return counter


func _confirm_twice(screen: SupportConversationScreen) -> void:
	screen.handle_input_event(_enter())  # 逐字中 -> 顯示整句
	screen.handle_input_event(_enter())  # 已完整 -> 下一句


func _read_to(screen: SupportConversationScreen, index: int) -> void:
	for i: int in range(index):
		_confirm_twice(screen)


func _target_id() -> int:
	var t: CursorTarget = CursorStateHost.get_current_target()
	return t.id if t != null else -999


# ---- 第一段 ---------------------------------------------------------------------

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
	var center: Vector2 = screen.diagnostic_advance_area_center()
	assert_bool(screen.handle_input_event(_click_at(center, MOUSE_BUTTON_RIGHT))).is_false()
	assert_bool(screen.diagnostic_line_fully_shown()).is_false()
	assert_bool(screen.handle_input_event(_click_at(Vector2(-5, -5)))).is_false()  # 對話框外不推進
	assert_bool(screen.diagnostic_line_fully_shown()).is_false()
	assert_bool(screen.handle_input_event(_click_at(center))).is_true()
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()


func test_screen_gamepad_confirm_advances() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	assert_bool(screen.handle_input_event(_pad(JOY_BUTTON_A))).is_true()
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()


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


func test_screen_moves_to_next_conversation_after_last_line_and_finishes_once() -> void:
	var script: Dictionary = _real_script()
	var n1: int = SupportConversationScript.lines_for(script, "SC-01").size()
	var n2: int = SupportConversationScript.lines_for(script, "SC-02").size()
	var screen: SupportConversationScreen = _make(["SC-01", "SC-02"] as Array[String])
	var counter: Array = _count_signal(screen)
	_read_to(screen, n1 - 1)
	assert_int(screen.diagnostic_current_line_index()).is_equal(n1 - 1)
	_confirm_twice(screen)  # 最後一句已完整 -> 下一段
	assert_str(screen.diagnostic_current_conversation_id()).is_equal("SC-02")
	assert_int(screen.diagnostic_current_line_index()).is_equal(0)
	assert_int(counter[0]).is_equal(0)
	_read_to(screen, n2 - 1)
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


func test_screen_missing_text_key_shows_explicit_marker() -> void:
	var shown: String = SupportConversationScreen.resolve_text("support.no_such_key.line99")
	assert_str(shown).starts_with(SupportConversationScreen.MISSING_MARKER_PREFIX)
	assert_str(shown).contains("support.no_such_key.line99")


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


# ---- 第二段:跳過整段 --------------------------------------------------------------

func test_skip_panel_opens_with_default_focus_on_cancel() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	assert_bool(screen.handle_input_event(_key(KEY_M))).is_true()
	assert_bool(screen.diagnostic_skip_panel_open()).is_true()
	assert_int(_target_id()).is_equal(SupportConversationScreen.TARGET_PANEL_CANCEL)


func test_sensitivity_proof_default_focus_confirm_makes_confirm_key_skip() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String], _MutantDefaultFocusConfirm)
	screen.handle_input_event(_key(KEY_M))
	assert_int(_target_id()).is_equal(SupportConversationScreen.TARGET_PANEL_CONFIRM)
	screen.handle_input_event(_enter())
	# 突變版:預設焦點在「確定跳過」,一按確認就跳 —— 證明 #13/#16 抓得到這個缺陷。
	assert_int(screen.diagnostic_current_line_index()).is_equal(11)


func test_skip_cancel_returns_to_same_line_zero_state_change() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	_read_to(screen, 2)
	screen.advance_typewriter(1.0 / SupportConversationScreen.CHARS_PER_SECOND * 2.0)
	var text_before: String = screen.diagnostic_visible_text()
	var speaker_before: String = screen.diagnostic_speaker_text()
	screen.handle_input_event(_key(KEY_M))
	assert_bool(screen.handle_input_event(_key(KEY_ESCAPE))).is_true()
	assert_bool(screen.diagnostic_skip_panel_open()).is_false()
	assert_int(screen.diagnostic_current_line_index()).is_equal(2)
	assert_str(screen.diagnostic_visible_text()).is_equal(text_before)
	assert_str(screen.diagnostic_speaker_text()).is_equal(speaker_before)
	assert_bool(screen.diagnostic_is_finished()).is_false()
	assert_int(_target_id()).is_equal(SupportConversationScreen.TARGET_ADVANCE)


func test_skip_confirm_key_on_default_focus_cancels() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	screen.handle_input_event(_key(KEY_M))
	screen.handle_input_event(_enter())
	assert_bool(screen.diagnostic_skip_panel_open()).is_false()
	assert_int(screen.diagnostic_current_line_index()).is_equal(0)


func test_skip_confirm_shows_last_line_then_one_confirm_finishes() -> void:
	var n: int = SupportConversationScript.lines_for(_real_script(), "SC-01").size()
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	var counter: Array = _count_signal(screen)
	screen.handle_input_event(_key(KEY_M))
	CursorStateHost.set_target(CursorTarget.make(CursorTypes.SurfaceType.DIALOGUE_CHOICE, SupportConversationScreen.TARGET_PANEL_CONFIRM))
	screen.handle_input_event(_enter())
	assert_int(screen.diagnostic_current_line_index()).is_equal(n - 1)
	assert_bool(screen.diagnostic_line_fully_shown()).is_true()
	assert_int(counter[0]).is_equal(0)
	screen.handle_input_event(_enter())
	assert_int(counter[0]).is_equal(1)


func test_skip_multi_conversation_skips_only_current() -> void:
	var screen: SupportConversationScreen = _make(["SC-01", "SC-02"] as Array[String])
	var counter: Array = _count_signal(screen)
	screen.handle_input_event(_key(KEY_M))
	screen.confirm_skip()
	screen.handle_input_event(_enter())
	assert_str(screen.diagnostic_current_conversation_id()).is_equal("SC-02")
	assert_int(screen.diagnostic_current_line_index()).is_equal(0)
	assert_int(counter[0]).is_equal(0)


func test_skip_and_full_read_share_same_completion_path() -> void:
	var n: int = SupportConversationScript.lines_for(_real_script(), "SC-01").size()
	var read: SupportConversationScreen = _make(["SC-01"] as Array[String])
	var read_counter: Array = _count_signal(read)
	_read_to(read, n - 1)
	read.handle_input_event(_enter())
	read.handle_input_event(_enter())
	var skipped: SupportConversationScreen = _make(["SC-01"] as Array[String])
	var skip_counter: Array = _count_signal(skipped)
	skipped.handle_input_event(_key(KEY_M))
	skipped.confirm_skip()
	skipped.handle_input_event(_enter())
	assert_int(read_counter[0]).is_equal(1)
	assert_int(skip_counter[0]).is_equal(1)
	assert_bool(read.diagnostic_is_finished()).is_equal(skipped.diagnostic_is_finished())
	assert_int(read.diagnostic_current_line_index()).is_equal(skipped.diagnostic_current_line_index())


func test_skip_panel_blocks_mouse_advance() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	screen.handle_input_event(_key(KEY_M))
	assert_bool(screen.handle_input_event(_click_at(screen.diagnostic_advance_area_center()))).is_false()
	assert_bool(screen.diagnostic_line_fully_shown()).is_false()
	screen.advance_typewriter(1000.0)
	assert_bool(screen.diagnostic_line_fully_shown()).is_false()  # 面板開啟時逐字暫停


# ---- 第二段:回看 ------------------------------------------------------------------

func test_review_back_is_readonly_and_cannot_pass_progress() -> void:
	var lines: Array = SupportConversationScript.lines_for(_real_script(), "SC-01")
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	var counter: Array = _count_signal(screen)
	_read_to(screen, 2)
	screen.handle_input_event(_enter())  # 第 3 句(索引 2)顯示完整
	assert_bool(screen.handle_input_event(_pad(JOY_BUTTON_LEFT_SHOULDER))).is_true()
	assert_int(screen.diagnostic_review_index()).is_equal(1)
	screen.handle_input_event(_pad(JOY_BUTTON_LEFT_SHOULDER))
	assert_int(screen.diagnostic_review_index()).is_equal(0)
	assert_str(screen.diagnostic_visible_text()).is_equal(Loc.localize(lines[0]["text_key"]))
	screen.handle_input_event(_pad(JOY_BUTTON_LEFT_SHOULDER))  # 已是最早,不動
	assert_int(screen.diagnostic_review_index()).is_equal(0)
	assert_int(screen.diagnostic_current_line_index()).is_equal(2)
	for i: int in range(6):  # 連按右肩鍵:只能回到目前進度,不能前跳到第 4 句
		screen.handle_input_event(_pad(JOY_BUTTON_RIGHT_SHOULDER))
		assert_int(screen.diagnostic_current_line_index()).is_equal(2)
	assert_int(screen.diagnostic_review_index()).is_equal(SupportConversationScreen.NOT_REVIEWING)
	assert_str(screen.diagnostic_visible_text()).is_equal(Loc.localize(lines[2]["text_key"]))
	assert_bool(screen.diagnostic_is_finished()).is_false()
	assert_int(counter[0]).is_equal(0)


func test_review_confirm_moves_one_step_toward_newest() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	_read_to(screen, 3)
	screen.handle_input_event(_enter())
	screen.review_back()
	screen.review_back()
	assert_int(screen.diagnostic_review_index()).is_equal(1)
	screen.handle_input_event(_enter())  # 回看時確認 = 往較新一句,不是推進播放
	assert_int(screen.diagnostic_review_index()).is_equal(2)
	assert_int(screen.diagnostic_current_line_index()).is_equal(3)


# ---- 第二段:游標義務 ----------------------------------------------------------------

func test_cursor_surface_registered_and_seeded_on_ready() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	var current: CursorTarget = CursorStateHost.get_current_target()
	assert_object(current).is_not_null()
	assert_int(current.surface).is_equal(CursorTypes.SurfaceType.DIALOGUE_CHOICE)
	assert_int(current.id).is_equal(SupportConversationScreen.TARGET_ADVANCE)
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()
	assert_object(screen).is_not_null()


func test_cursor_navigate_panel_and_normal_modes() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	assert_int(screen.cursor_navigate(SupportConversationScreen.TARGET_ADVANCE, Vector2i(0, 1))).is_equal(SupportConversationScreen.TARGET_PREV)
	assert_int(screen.cursor_navigate(SupportConversationScreen.TARGET_PREV, Vector2i(0, 1))).is_equal(SupportConversationScreen.TARGET_SKIP)
	assert_object(screen.cursor_navigate(SupportConversationScreen.TARGET_SKIP, Vector2i(0, 1))).is_null()
	assert_object(screen.cursor_navigate(SupportConversationScreen.TARGET_ADVANCE, Vector2i(0, -1))).is_null()
	screen.handle_input_event(_key(KEY_M))
	assert_int(screen.cursor_navigate(SupportConversationScreen.TARGET_PANEL_CANCEL, Vector2i(-1, 0))).is_equal(SupportConversationScreen.TARGET_PANEL_CONFIRM)
	assert_int(screen.cursor_navigate(SupportConversationScreen.TARGET_PANEL_CONFIRM, Vector2i(1, 0))).is_equal(SupportConversationScreen.TARGET_PANEL_CANCEL)
	assert_object(screen.cursor_navigate(SupportConversationScreen.TARGET_PANEL_CONFIRM, Vector2i(0, 1))).is_null()


func test_unload_hands_off_cursor_target() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()
	remove_child(screen)  # tree_exited 同步觸發交接
	assert_bool(CursorStateHost.is_current_target_valid()).is_false()


func test_sensitivity_proof_no_handoff_leaves_target_valid() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String], _MutantNoHandoff)
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()
	remove_child(screen)
	# 突變版:沒標記待重新解析,目標仍「有效」地指著已卸載的表面 —— 證明上面那條測試抓得到。
	assert_bool(CursorStateHost.is_current_target_valid()).is_true()


func test_ui_texts_come_from_localization() -> void:
	var screen: SupportConversationScreen = _make(["SC-01"] as Array[String])
	assert_array(screen.diagnostic_button_texts()).contains_exactly([
		Loc.localize(SupportConversationScreen.TEXT_PREV), Loc.localize(SupportConversationScreen.TEXT_SKIP)
	])
	assert_array(screen.diagnostic_skip_panel_texts()).contains_exactly([
		Loc.localize(SupportConversationScreen.TEXT_SKIP_BODY),
		Loc.localize(SupportConversationScreen.TEXT_SKIP_YES),
		Loc.localize(SupportConversationScreen.TEXT_SKIP_NO),
	])
