extends SceneTree
# Follow-up to probe_pause_input.gd: v1 pushed ONLY a "pressed=true" key event
# for ui_accept and observed Button.pressed never fired, even unpaused. Button's
# default action_mode is ACTION_MODE_BUTTON_RELEASE, so pressed should fire on
# the RELEASE half of a press/release pair, not the press half alone. This
# probe pushes both halves and checks the baseline again before attributing
# anything to pausing.
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
	print("action_mode = ", a.action_mode, " (0=BUTTON_PRESS, 1=BUTTON_RELEASE)")

	var accept_events: Array = InputMap.action_get_events(&"ui_accept")
	var real_event: InputEventKey = null
	for event in accept_events:
		if event is InputEventKey:
			real_event = event as InputEventKey
			break

	var down_event: InputEventKey = real_event.duplicate()
	down_event.pressed = true
	root.push_input(down_event)
	await process_frame
	print("after PRESS half only: a_pressed_count = ", a_pressed_count)

	var up_event: InputEventKey = real_event.duplicate()
	up_event.pressed = false
	root.push_input(up_event)
	await process_frame
	await process_frame
	print("after RELEASE half too: a_pressed_count = ", a_pressed_count)

	quit()
