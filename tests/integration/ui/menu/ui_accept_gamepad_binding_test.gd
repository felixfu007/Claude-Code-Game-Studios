## Regression test for 2026-11-02 bug: 手把 A 鍵按不了任何 Button(標題/選單列/設定/離開確認框)。
## 成因:project.godot 未覆寫 [code]ui_accept[/code],引擎預設只有 Enter/KP Enter/Space。
##
## 🔴 只證明 InputMap 綁定(決策層):headless 下無法模擬 Button 被啟用
## (見 battle_menu_leave_confirmation_test.gd 檔頭),「手把 A 真的按下 Button」
## 須開窗手動驗證 —— 本檔未涵蓋。分類:無檔案 I/O。
## 敏感度:斷言對象是 InputMap 全域狀態(第六類/A′),不蓋常駐證明;
## 以「暫時移除綁定 → 變紅 → 還原」手動驗證,結果記在交件報告。
extends GdUnitTestSuite


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _has_joy_button(action: StringName, button: JoyButton) -> bool:
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			return true
	return false


func test_ui_accept_has_gamepad_a_bound() -> void:
	assert_bool(_has_joy_button(&"ui_accept", JOY_BUTTON_A)).is_true()


func test_ui_accept_matches_synthetic_gamepad_a_press() -> void:
	assert_bool(InputMap.event_is_action(_joy(JOY_BUTTON_A), &"ui_accept")).is_true()
	assert_bool(Input.is_action_pressed(&"ui_accept")).is_false()  # 不污染全域輸入狀態


func test_ui_accept_keeps_keyboard_defaults() -> void:
	var codes: Array[int] = []
	for e: InputEvent in InputMap.action_get_events(&"ui_accept"):
		if e is InputEventKey:
			codes.append((e as InputEventKey).keycode)
	assert_array(codes).contains([KEY_ENTER, KEY_KP_ENTER, KEY_SPACE])


func test_ui_cancel_has_gamepad_b_and_keeps_escape() -> void:
	assert_bool(_has_joy_button(&"ui_cancel", JOY_BUTTON_B)).is_true()
	var has_esc := false
	for e: InputEvent in InputMap.action_get_events(&"ui_cancel"):
		if e is InputEventKey and (e as InputEventKey).keycode == KEY_ESCAPE:
			has_esc = true
	assert_bool(has_esc).is_true()
