extends Node

# Throwaway reflection probe: list real DisplayServer methods relevant to
# focus/flags, and list ProjectSettings under display/window/*, so the
# windowed probe script is written against real API, not guessed names.

func _ready() -> void:
	print("=== DisplayServer methods matching 'focus' ===")
	for m in ClassDB.class_get_method_list("DisplayServer"):
		var n: String = m["name"]
		if n.findn("focus") != -1:
			print(n)

	print("=== DisplayServer methods matching 'window' (partial, first 60) ===")
	var count := 0
	for m in ClassDB.class_get_method_list("DisplayServer"):
		var n: String = m["name"]
		if n.findn("window") != -1:
			print(n)
			count += 1
			if count >= 60:
				break

	print("=== ProjectSettings display/window/* properties (name, default, has) ===")
	for p in ProjectSettings.get_property_list():
		var n2: String = p["name"]
		if n2.begins_with("display/window/"):
			var has := ProjectSettings.has_setting(n2)
			var val = ProjectSettings.get_setting(n2) if has else null
			print(n2, " | has=", has, " | default_or_current=", val)

	print("=== hint_string for enum-like display/window/size properties ===")
	for p in ProjectSettings.get_property_list():
		var n3: String = p["name"]
		if n3 in ["display/window/size/initial_position_type", "display/window/size/mode", "display/window/stretch/mode"]:
			print(n3, " | hint=", p.get("hint"), " | hint_string=", p.get("hint_string"), " | type=", p.get("type"))

	print("=== DONE ===")
	get_tree().quit()
