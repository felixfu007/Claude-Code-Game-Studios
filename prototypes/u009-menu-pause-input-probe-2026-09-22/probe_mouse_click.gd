extends SceneTree
# Follow-up #3: sanity check — does a SIMULATED MOUSE CLICK (not keyboard/
# action at all) fire Button.pressed headlessly? If this ALSO fails, the
# finding generalizes to "headless cannot prove native Button activation by
# any input method", not something specific to ui_accept/keyboard actions.
func _init() -> void:
	await process_frame
	var root: Window = get_root()
	var a := Button.new()
	a.text = "A"
	a.size = Vector2(100, 40)
	a.position = Vector2(10, 10)
	root.add_child(a)
	await process_frame
	var pressed_count := 0
	var down_count := 0
	var up_count := 0
	a.pressed.connect(func() -> void: pressed_count += 1)
	a.button_down.connect(func() -> void: down_count += 1)
	a.button_up.connect(func() -> void: up_count += 1)

	var click_pos: Vector2 = Vector2(50, 30)
	var down_ev := InputEventMouseButton.new()
	down_ev.button_index = MOUSE_BUTTON_LEFT
	down_ev.pressed = true
	down_ev.position = click_pos
	down_ev.global_position = click_pos
	root.push_input(down_ev)
	await process_frame

	var up_ev := InputEventMouseButton.new()
	up_ev.button_index = MOUSE_BUTTON_LEFT
	up_ev.pressed = false
	up_ev.position = click_pos
	up_ev.global_position = click_pos
	root.push_input(up_ev)
	await process_frame
	await process_frame

	print("mouse click sim: button_down_count=", down_count, " button_up_count=", up_count, " pressed_count=", pressed_count)
	quit()
