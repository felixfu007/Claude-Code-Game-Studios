extends SceneTree
func _init() -> void:
	print("BUILD debug=", OS.is_debug_build(), " editor=", Engine.is_editor_hint(), " via -s SceneTree")
	preload("res://core.gd").run()
	quit()
