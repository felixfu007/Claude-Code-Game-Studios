extends SceneTree

func _init() -> void:
	print("=== Probe: does Input.action_press() / is_action_pressed() round-trip headless? ===")
	print("Input.is_action_pressed(ui_up) BEFORE action_press = ", Input.is_action_pressed(&"ui_up"))
	Input.action_press(&"ui_up")
	print("Input.is_action_pressed(ui_up) AFTER action_press  = ", Input.is_action_pressed(&"ui_up"))
	Input.action_release(&"ui_up")
	print("Input.is_action_pressed(ui_up) AFTER action_release = ", Input.is_action_pressed(&"ui_up"))
	quit()
