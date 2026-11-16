extends SceneTree
func _init() -> void:
	var l: Label = Label.new()
	var s: LabelSettings = LabelSettings.new()
	s.font_size = 8
	l.label_settings = s
	l.text = "30/30"
	print("LS min=", l.get_minimum_size())
	l.size = Vector2(32, l.get_minimum_size().y)
	print("LS size=", l.size)
	l.text = "30→15"
	print("LS preview min=", l.get_minimum_size())
	quit()
