extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _walk(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is Control:
			out.append(c)
		_walk(c, out)

func _measure(size: Vector2i) -> void:
	var win: Window = get_root()
	win.size = size
	print("=== requested ", size, " actual root.size=", win.size, " content_scale_size=", win.content_scale_size)
	var scn: PackedScene = load("res://src/ui/shell/SettingsScreen.tscn")
	var inst: Node = scn.instantiate()
	get_root().call_deferred("add_child", inst)
	await process_frame
	await process_frame
	var panel: Control = inst.get_node("Panel")
	var rows: Control = inst.get_node("Panel/ContentMargin/Rows")
	var vp: Rect2 = Rect2(Vector2.ZERO, Vector2(win.size))
	print("viewport rect=", get_root().get_visible_rect())
	print("Panel global_rect=", panel.get_global_rect(), " size=", panel.size, " min=", panel.get_combined_minimum_size())
	print("Rows global_rect=", rows.get_global_rect(), " min=", rows.get_combined_minimum_size())
	var all: Array = []
	_walk(panel, all)
	var maxb: float = 0.0
	var pr: Rect2 = panel.get_global_rect()
	var vr: Rect2 = get_root().get_visible_rect()
	for c in all:
		var r: Rect2 = c.get_global_rect()
		maxb = maxf(maxb, r.end.y)
		var in_p: bool = pr.encloses(r)
		var in_v: bool = vr.encloses(r)
		print("CHILD ", c.get_path().get_concatenated_names().replace("root/", ""), " rect=", r, " inPanel=", in_p, " inWindow=", in_v)
	print("MAX_BOTTOM_Y=", maxb, " panel_bottom=", pr.end.y, " window_h=", vr.size.y, " overflow_panel=", maxb > pr.end.y + 0.01, " overflow_window=", maxb > vr.size.y)
	print("panel_min_h_vs_panel_h: min=", panel.get_combined_minimum_size().y, " actual=", panel.size.y)
	inst.queue_free()
	await process_frame

func _run() -> void:
	await _measure(Vector2i(960, 540))
	await _measure(Vector2i(1920, 1080))
	quit()
