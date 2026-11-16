extends SceneTree
func _initialize() -> void:
	var dir: String = "res://prototypes/story-057-backdrop-capture-2026-11-16/out/"
	for f: String in ["1920x1080_2cursor_xu_real.png", "1920x1080_1overview_real.png"]:
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(dir + f))
		print(f, " ", img.get_size())
		for p: Vector2i in [Vector2i(134, 580), Vector2i(172, 622), Vector2i(134, 450), Vector2i(172, 490), Vector2i(134, 740), Vector2i(134, 520)]:
			print("  px ", p, " = ", img.get_pixelv(p))
	quit()
