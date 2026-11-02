extends SceneTree
func _init() -> void:
	for a in ["ui_accept","ui_cancel","battle_confirm"]:
		for e in InputMap.action_get_events(a):
			print(a, " -> ", e, " device=", e.device)
	var j := InputEventJoypadButton.new()
	j.button_index = JOY_BUTTON_A
	j.pressed = true
	print("ui_accept matches joyA: ", InputMap.event_is_action(j, "ui_accept"))
	quit()
