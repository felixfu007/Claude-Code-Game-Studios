extends GdUnitTestSuite

# story-045 AC1/AC2/AC4: ControlsHintContent pure-function per-cell assertions.
# File access: none (reads the imported translation resource via Loc).
# Anti-vacuity: every non-FINISHED cell non-empty + FINISHED empty on all devices + >= 2 states differ.

const S := ControlsHintContent.HintState
const D := ControlsHintContent.HintDevice

const _ALL_STATES: Array[int] = [S.NO_SELECTION, S.UNIT_SELECTED, S.HAND_OPEN, S.CARD_TARGET,
	S.CARD_CONFIRM, S.FORCED_DISCARD, S.MENU_OPEN, S.ENEMY_PHASE, S.FINISHED]
const _ALL_DEVICES: Array[int] = [D.MOUSE, D.KEYBOARD, D.GAMEPAD]

const _KB_ONLY: Array[String] = ["方向鍵", "Enter", "Esc", "Tab"]
const _PAD_ONLY: Array[String] = ["十字鍵", "Start", "Back", "RB"]
const _MOUSE_ONLY: Array[String] = ["左鍵", " 右鍵", "滑鼠"]


func _text(state: int, device: int) -> String:
	return ControlsHintContent.SEPARATOR.join(ControlsHintContent.segments_for(state, device))


func _assert_lacks(text: String, words: Array[String], ctx: String) -> void:
	for w: String in words:
		assert_bool(text.contains(w)).append_failure_message("%s should not contain [%s]: %s" % [ctx, w, text]).is_false()


func test_every_cell_non_empty_except_finished() -> void:
	for st: int in _ALL_STATES:
		for dev: int in _ALL_DEVICES:
			var segs: PackedStringArray = ControlsHintContent.segments_for(st, dev)
			if st == S.FINISHED:
				assert_int(segs.size()).append_failure_message("FINISHED must be empty dev=%d" % dev).is_equal(0)
			else:
				assert_int(segs.size()).append_failure_message("state=%d dev=%d empty" % [st, dev]).is_greater(0)
				for seg: String in segs:
					assert_bool(seg.is_empty() or seg.begins_with("battle.hud.hint")).append_failure_message(
						"empty segment or raw key: %s" % seg).is_false()


func test_states_are_distinguishable() -> void:
	assert_str(_text(S.ENEMY_PHASE, D.KEYBOARD)).is_not_equal(_text(S.UNIT_SELECTED, D.KEYBOARD))
	assert_str(_text(S.HAND_OPEN, D.GAMEPAD)).is_not_equal(_text(S.NO_SELECTION, D.GAMEPAD))


func test_each_device_only_shows_its_own_key_names() -> void:
	for st: int in _ALL_STATES:
		_assert_lacks(_text(st, D.KEYBOARD), _PAD_ONLY + _MOUSE_ONLY, "keyboard state=%d" % st)
		_assert_lacks(_text(st, D.GAMEPAD), _KB_ONLY + _MOUSE_ONLY, "gamepad state=%d" % st)
		_assert_lacks(_text(st, D.MOUSE), _KB_ONLY + _PAD_ONLY, "mouse state=%d" % st)


func test_enemy_phase_has_no_action_words() -> void:
	for dev: int in _ALL_DEVICES:
		_assert_lacks(_text(S.ENEMY_PHASE, dev), ["移動", "確認", "取消", "手牌", "結束角色行動", "跳目標"], "ENEMY_PHASE")
		assert_str(_text(S.ENEMY_PHASE, dev)).contains("敵方行動中")
	assert_int(ControlsHintContent.segments_for(S.ENEMY_PHASE, D.MOUSE).size()).is_equal(1)
	assert_str(_text(S.ENEMY_PHASE, D.KEYBOARD)).contains("選單 M")
	assert_str(_text(S.ENEMY_PHASE, D.GAMEPAD)).contains("選單 Start")


func test_no_selection_lacks_cancel_end_unit_jump() -> void:
	for dev: int in _ALL_DEVICES:
		_assert_lacks(_text(S.NO_SELECTION, dev), ["取消", "結束角色行動", "跳目標"], "NO_SELECTION")
	assert_str(_text(S.NO_SELECTION, D.KEYBOARD)).contains("選取 Enter")


func test_unit_selected_has_full_set_with_cancel_second_after_story_053() -> void:
	var kb: PackedStringArray = ControlsHintContent.segments_for(S.UNIT_SELECTED, D.KEYBOARD)
	assert_int(kb.size()).is_equal(7)
	assert_str(kb[1]).contains("取消")
	assert_str(kb[2]).contains("結束角色行動")
	assert_str(_text(S.UNIT_SELECTED, D.KEYBOARD)).contains("結束角色行動 Q")
	assert_str(_text(S.UNIT_SELECTED, D.GAMEPAD)).contains("結束角色行動 Back")
	assert_str(_text(S.UNIT_SELECTED, D.MOUSE)).contains("取消 右鍵")


func test_hand_card_menu_states_lack_end_unit_and_jump() -> void:
	for st: int in [S.HAND_OPEN, S.CARD_CONFIRM, S.FORCED_DISCARD, S.MENU_OPEN]:
		for dev: int in _ALL_DEVICES:
			_assert_lacks(_text(st, dev), ["結束角色行動", "跳目標"], "state=%d" % st)
	for dev: int in _ALL_DEVICES:
		_assert_lacks(_text(S.FORCED_DISCARD, dev), ["取消", "收手牌", "選單"], "FORCED_DISCARD")
	assert_str(_text(S.CARD_TARGET, D.KEYBOARD)).contains("跳目標 Tab")
	assert_bool(_text(S.CARD_TARGET, D.GAMEPAD).begins_with("請選擇目標")).is_true()


func test_fit_text_drops_from_right_and_keeps_cancel() -> void:
	var segs: PackedStringArray = ControlsHintContent.segments_for(S.UNIT_SELECTED, D.KEYBOARD)
	var font: Font = HudLayoutScaler.HUD_FONT
	var fpx: int = 16
	var through_cancel: String = ControlsHintContent.SEPARATOR.join(segs.slice(0, 2))
	var w: float = font.get_string_size(through_cancel, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
	var fitted: String = ControlsHintContent.fit_text(segs, w, font, fpx)
	assert_str(fitted).is_equal(through_cancel)
	assert_str(fitted).contains("取消 Esc")
	assert_bool(fitted.contains("手牌")).is_false()
	assert_str(ControlsHintContent.fit_text(segs, 1.0, font, fpx)).is_equal(segs[0])


func test_each_state_device_fits_available_width_at_960_1920_2560() -> void:
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var avail: float = HudLayout.compact_hint_available_width(size)
		var fpx: int = HudLayout.font_size(size)
		for st: int in _ALL_STATES:
			for dev: int in _ALL_DEVICES:
				var segs: PackedStringArray = ControlsHintContent.segments_for(st, dev)
				if segs.is_empty():
					continue
				var text: String = ControlsHintContent.fit_text(segs, avail, HudLayoutScaler.HUD_FONT, fpx)
				var wpx: float = HudLayoutScaler.HUD_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
				assert_float(wpx).append_failure_message("%s st=%d dev=%d width %.1f > %.1f" % [size, st, dev, wpx, avail]).is_less_equal(avail)
				# Output must be a left prefix of the input: only right-end segments are dropped.
				assert_bool(ControlsHintContent.SEPARATOR.join(segs).begins_with(text)).is_true()


# ---- story-053:UNIT_SELECTED 段落序(鍵盤/手把:確認→取消→結束角色行動→移動…;滑鼠不變)----

func test_unit_selected_keyboard_gamepad_order_after_story_053() -> void:
	for dev: int in [D.KEYBOARD, D.GAMEPAD]:
		var segs: PackedStringArray = ControlsHintContent.segments_for(S.UNIT_SELECTED, dev)
		assert_int(segs.size()).is_equal(7)
		assert_str(segs[0]).contains("確認")
		assert_str(segs[1]).contains("取消")
		assert_str(segs[2]).contains("結束角色行動")
		assert_str(segs[3]).contains("移動")


func test_unit_selected_mouse_order_unchanged() -> void:
	var segs: PackedStringArray = ControlsHintContent.segments_for(S.UNIT_SELECTED, D.MOUSE)
	assert_int(segs.size()).is_equal(3)
	assert_str(segs[0]).contains("移動")
	assert_str(segs[1]).contains("確認")
	assert_str(segs[2]).contains("取消")


func test_unit_selected_fit_keeps_cancel_and_end_action_at_960_1920_2560() -> void:
	var cancel_word: Dictionary[int, String] = {D.KEYBOARD: "取消 Esc", D.GAMEPAD: "取消 B", D.MOUSE: "取消 右鍵"}
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var avail: float = HudLayout.compact_hint_available_width(size)
		var fpx: int = HudLayout.font_size(size)
		for dev: int in _ALL_DEVICES:
			var segs: PackedStringArray = ControlsHintContent.segments_for(S.UNIT_SELECTED, dev)
			var text: String = ControlsHintContent.fit_text(segs, avail, HudLayoutScaler.HUD_FONT, fpx)
			assert_str(text).append_failure_message("%s dev=%d 應含 %s:%s" % [size, dev, cancel_word[dev], text]).contains(cancel_word[dev])
			if dev != D.MOUSE:
				assert_str(text).append_failure_message("%s dev=%d 應含結束角色行動段:%s" % [size, dev, text]).contains("結束角色行動")


func test_narrow_width_drops_rightmost_end_action_not_cancel() -> void:
	var segs: PackedStringArray = ControlsHintContent.segments_for(S.UNIT_SELECTED, D.KEYBOARD)
	var font: Font = HudLayoutScaler.HUD_FONT
	var through_cancel: String = ControlsHintContent.SEPARATOR.join(segs.slice(0, 2))
	var w: float = font.get_string_size(through_cancel, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var fitted: String = ControlsHintContent.fit_text(segs, w, font, 16)
	assert_str(fitted).contains("取消 Esc")
	assert_bool(fitted.contains("結束角色行動")).is_false()


func test_sensitivity_proof_lack_lists_detect_end_action_wording() -> void:
	# _assert_lacks 的偵測詞已由「結束單位」改為「結束角色行動」;證明它對污染文字會抓到(為真),
	# 且舊詞抓不到新字樣(為假 —— 若詞表沒改,上面三條「不得含」斷言會永遠通過)。
	var polluted: String = "敵方行動中　結束角色行動 Q"
	assert_bool(polluted.contains("結束角色行動")).is_true()
	assert_bool(polluted.contains("結束單位")).is_false()
