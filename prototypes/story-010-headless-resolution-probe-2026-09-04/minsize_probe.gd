## 開工前查核:視窗小於棋盤基準(480x270)時,引擎有沒有現成的「最小視窗尺寸」機制?
## 若有,那條未定義邊界就有一個不必自己發明的答案。
extends SceneTree

func _initialize() -> void:
	for k in ["display/window/size/window_width_override",
			  "display/window/size/window_height_override",
			  "display/window/size/resizable",
			  "display/window/size/borderless"]:
		print("%-52s 存在=%s 值=%s" % [k, ProjectSettings.has_setting(k), ProjectSettings.get_setting(k)])

	print()
	print("Window 物件有沒有 min_size 屬性:")
	var found := false
	for p in root.get_property_list():
		if String(p.name).findn("min_size") >= 0 or String(p.name).findn("max_size") >= 0:
			print("  ", p.name, "  現值=", root.get(p.name))
			found = true
	if not found:
		print("  (無)")

	print()
	print("DisplayServer 有沒有 window_set_min_size:")
	print("  ", DisplayServer.has_method("window_set_min_size"))

	# 實測:設定最小尺寸後,能不能把視窗設得比它更小
	root.min_size = Vector2i(480, 270)
	root.size = Vector2i(320, 180)
	print()
	print("設 min_size=(480,270) 後,再指派 size=(320,180) → 實際 root.size = ", root.size)
	quit()
