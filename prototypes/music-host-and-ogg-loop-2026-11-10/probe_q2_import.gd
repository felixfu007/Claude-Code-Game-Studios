extends SceneTree
func _init() -> void:
	var s = load("res://m.ogg")
	print("Q2I class=", s.get_class(), " loop=", s.loop, " loop_offset=", s.loop_offset, " length=", s.get_length())
	quit()
