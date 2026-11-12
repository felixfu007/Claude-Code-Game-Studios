extends SceneTree
func _init() -> void:
	var font: FontFile = load("res://assets/fonts/Cubic_11.ttf")
	print("FONT loaded=", font != null, " name=", font.get_font_name() if font else "")
	var chars := "藍徐董秦麥亭萱培恩振豪亦柔子健敵兵我方0123456789"
	for i in chars.length():
		var ch := chars.substr(i, 1)
		for sz in [11, 22]:
			var s: Vector2 = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
			print("GLYPH ", ch, " U+%04X" % ch.unicode_at(0), " has_char=", font.has_char(ch.unicode_at(0)), " size@", sz, "=", s)
	print("ASCENT@11=", font.get_ascent(11), " DESCENT@11=", font.get_descent(11), " HEIGHT@11=", font.get_height(11))
	var d := DirAccess.open("res://assets/art/characters/pieces")
	for f in d.get_files():
		if f.ends_with(".png"):
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/art/characters/pieces/" + f))
			print("PIECE ", f, " ", img.get_width(), "x", img.get_height())
	for p in ["ENEMY_SPRITE_PATH"]:
		print("CONST ", p, " = ", BoardView.ENEMY_SPRITE_PATH)
	print("ALLY_SPRITE_PATHS=", BoardView.ALLY_SPRITE_PATHS, " FINAL_PIECE_DIR=", BoardView.FINAL_PIECE_DIR)
	quit()
