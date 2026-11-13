extends GdUnitTestSuite

# story-045 AC5: hint bar updates live on the REAL BattleScreen.tscn (real data, scene loaded as production does).
# File access: none.

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false


func _fresh() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _key(code: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	return ev


func test_mouse_event_shows_mouse_keys_and_keyboard_event_switches() -> void:
	var instance: BattleScreen = _fresh()
	var mb: InputEventMouseButton = InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_MIDDLE
	mb.pressed = true
	instance._note_hint_device(mb)
	instance._refresh_controls_hint()
	assert_str(instance._controls_hint_label.text).contains("左鍵")
	assert_bool(instance._controls_hint_label.text.contains("Enter")).is_false()
	instance._note_hint_device(_key(KEY_A))
	instance._refresh_controls_hint()
	assert_str(instance._controls_hint_label.text).contains("Enter")
	assert_bool(instance._controls_hint_label.text.contains("左鍵")).is_false()
	var jb: InputEventJoypadButton = InputEventJoypadButton.new()
	jb.pressed = true
	instance._note_hint_device(jb)
	instance._refresh_controls_hint()
	assert_str(instance._controls_hint_label.text).contains("十字鍵")


func test_device_flag_does_not_touch_cursor_authority() -> void:
	var instance: BattleScreen = _fresh()
	var before: int = CursorStateHost.get_device_authority()
	instance._note_hint_device(_key(KEY_A))
	assert_int(CursorStateHost.get_device_authority()).is_equal(before)


func test_enemy_phase_text_has_no_confirm() -> void:
	var instance: BattleScreen = _fresh()
	instance._note_hint_device(_key(KEY_A))
	instance._refresh_controls_hint()
	var before: String = instance._controls_hint_label.text
	instance._controller._phase = BattleController.Phase.ENEMY_ACTING
	instance._refresh_controls_hint()
	assert_str(instance._controls_hint_label.text).is_not_equal(before)
	assert_bool(instance._controls_hint_label.text.contains("確認")).is_false()
	assert_str(instance._controls_hint_label.text).contains("敵方行動中")


func test_finished_text_is_empty() -> void:
	var instance: BattleScreen = _fresh()
	instance._note_hint_device(_key(KEY_A))
	instance._controller._phase = BattleController.Phase.FINISHED
	instance._refresh_controls_hint()
	assert_str(instance._controls_hint_label.text).is_empty()


func test_hand_open_changes_content() -> void:
	var instance: BattleScreen = _fresh()
	instance._note_hint_device(_key(KEY_A))
	instance._refresh_controls_hint()
	var before: String = instance._controls_hint_label.text
	instance._card_selecting_from_hand = true
	instance._refresh_controls_hint()
	assert_str(instance._controls_hint_label.text).is_not_equal(before)
	assert_str(instance._controls_hint_label.text).contains("換牌")
