extends SceneTree
func _initialize() -> void:
	for key: String in ["display/window/size/window_width_override","display/window/size/window_height_override","display/window/size/min_width","display/window/size/min_height","display/window/size/window_min_width","display/window/size/window_min_height"]:
		print(key, " has_setting=", ProjectSettings.has_setting(key))
	print("--- all display/window/size/* keys in this project ---")
	for key: String in ProjectSettings.get_property_list().map(func(p): return p.name):
		if key.begins_with("display/window/size/"):
			print(key)
	quit(0)
