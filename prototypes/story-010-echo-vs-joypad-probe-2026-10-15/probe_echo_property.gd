extends SceneTree

func _init() -> void:
	print("=== Probe: does InputEventJoypadMotion / InputEventJoypadButton have an 'echo' property? ===")

	var key_event := InputEventKey.new()
	print("InputEventKey has 'echo' in property list: ", _has_prop(key_event, "echo"))
	print("InputEventKey.echo default value: ", key_event.echo)

	var motion_event := InputEventJoypadMotion.new()
	print("InputEventJoypadMotion has 'echo' in property list: ", _has_prop(motion_event, "echo"))
	print("InputEventJoypadMotion.get('echo') (null if no such property): ", motion_event.get("echo"))

	var joy_button_event := InputEventJoypadButton.new()
	print("InputEventJoypadButton has 'echo' in property list: ", _has_prop(joy_button_event, "echo"))
	print("InputEventJoypadButton.get('echo') (null if no such property): ", joy_button_event.get("echo"))

	print("=== Static-type compile check (already proven by prior parse-error run) ===")
	print("Prior run of this probe (same file, before this edit) failed to COMPILE with:")
	print("  'Expression is of type InputEventJoypadMotion so it can't be of type InputEventWithModifiers'")
	print("  'Expression is of type InputEventJoypadButton so it can't be of type InputEventWithModifiers'")
	print("This is the GDScript static type checker itself confirming, at parse time (not a runtime guess),")
	print("that InputEventJoypadMotion/InputEventJoypadButton do NOT inherit InputEventWithModifiers --")
	print("the class InputEventKey.echo is declared on. echo is structurally a keyboard-only concept.")

	quit()


func _has_prop(obj: Object, prop_name: String) -> bool:
	for p in obj.get_property_list():
		if p["name"] == prop_name:
			return true
	return false
