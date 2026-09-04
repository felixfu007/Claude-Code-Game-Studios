extends SceneTree
func _initialize() -> void:
	var w: Window = root
	w.size = Vector2i(480, 270)
	print("before min_size set: root.size = ", w.size)
	w.min_size = Vector2i(960, 540)
	print("after min_size=960x540 set:  root.size = ", w.size)
	quit(0)
