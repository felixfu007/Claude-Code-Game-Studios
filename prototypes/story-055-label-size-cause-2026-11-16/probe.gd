extends SceneTree
func _init() -> void:
	var l: Label = Label.new()
	l.add_theme_font_size_override("font_size", 8)
	l.text = "30/30"
	print("A min=", l.get_minimum_size(), " size=", l.size)
	l.size = Vector2(32, l.get_minimum_size().y)
	print("B size=", l.size)
	var l2: Label = Label.new()
	l2.add_theme_font_size_override("font_size", 8)
	l2.text = "30/30"
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l2.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	print("C min=", l2.get_minimum_size())
	l2.size = Vector2(32, 12)
	print("D size=", l2.size)
	l2.size = Vector2(32, l2.get_minimum_size().y)
	root.add_child(l2)
	print("E size in tree=", l2.size, " min=", l2.get_minimum_size())
	var l3: Label = Label.new()
	l3.add_theme_font_size_override("font_size", 8)
	l3.text = "30/30"
	root.add_child(l3)
	l3.size = Vector2(32, 12)
	print("F size=", l3.size, " min=", l3.get_minimum_size())
	l3.size = Vector2(32, 12)
	print("G size again=", l3.size)
	quit()
