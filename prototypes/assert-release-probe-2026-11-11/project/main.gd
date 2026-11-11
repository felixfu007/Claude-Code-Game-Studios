extends Node
func _ready() -> void:
	print("BUILD debug=", OS.is_debug_build(), " editor=", Engine.is_editor_hint(), " features release=", OS.has_feature("release"), " template=", OS.has_feature("template"))
	preload("res://core.gd").run()
	get_tree().quit()
