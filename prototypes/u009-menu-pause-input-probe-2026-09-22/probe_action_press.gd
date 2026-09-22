extends SceneTree
# Follow-up #2: does Input.action_press()/action_release() (the officially
# documented way to simulate an action in tests, distinct from constructing a
# raw InputEventKey and calling push_input()) fire Button.pressed where the
# raw-event technique did not?
func _init() -> void:
	await process_frame
	var root: Window = get_root()
	var a := Button.new()
	a.text = "A"
	a.focus_mode = Control.FOCUS_ALL
	root.add_child(a)
	await process_frame
	var a_pressed_count := 0
	a.pressed.connect(func() -> void: a_pressed_count += 1)
	a.grab_focus()
	await process_frame

	Input.action_press(&"ui_accept")
	await process_frame
	print("after Input.action_press(ui_accept): a_pressed_count = ", a_pressed_count)
	Input.action_release(&"ui_accept")
	await process_frame
	await process_frame
	print("after Input.action_release(ui_accept): a_pressed_count = ", a_pressed_count)
	quit()
