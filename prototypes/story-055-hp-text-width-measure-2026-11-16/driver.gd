extends SceneTree
## story-055 步驟 1:血量文字寬度量測(拋棄式)。
## 規則:load() 真實 BattleScreen.tscn -> instantiate -> call_deferred add_child -> 等幀(technical-preferences 第 5 點)。
## 用法(開窗):godot --path . --audio-driver Dummy --title=x --position 0,0 -s res://prototypes/story-055-hp-text-width-measure-2026-11-16/driver.gd
## headless 下 get_image() 為 null 屬正常。內建 WATCHDOG 90 秒。
const OUT_DIR: String = "res://prototypes/story-055-hp-text-width-measure-2026-11-16/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const STRINGS: Array[String] = ["22/22", "23→7", "30→15", "9→0", "30/30", "30→30", "30→0"]
var _headless: bool = false

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		print("WATCHDOG fired -> quit(2)")
		quit(2))
	_run()

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _find_hp_labels(n: Node, out: Array[Label]) -> void:
	if n is Label and n.get_parent() is Control and (n.get_parent() as Control).clip_contents:
		out.append(n)
	for c: Node in n.get_children():
		_find_hp_labels(c, out)

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for size: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = size
		await _frames(3)
		var inst: Node = (load(SCENE) as PackedScene).instantiate()
		root.call_deferred("add_child", inst)
		await _frames(12)
		print("HOST [%s] root.size=%s" % [size, root.size])
		var wvc: SubViewportContainer = inst.get_node("WorldViewportContainer")
		var wv: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
		print("HOST [%s] WorldViewportContainer position=%s size=%s stretch_shrink=%d | WorldViewport.size=%s" % [
			size, wvc.position, wvc.size, wvc.stretch_shrink, wv.size])
		var board: BoardView = inst._board_view
		var strip: Rect2 = BoardView.hp_text_rect_in_cell()
		var avail: float = strip.size.x
		print("CONST HP_TEXT_FONT_SIZE=%d hp_text_rect_in_cell=%s avail_w=%.1f" % [BoardView.HP_TEXT_FONT_SIZE, strip, avail])
		# 探針 Label:掛進真實 board_view(繼承真實主題),字級覆寫同 _build_hp_text。
		var probe: Label = Label.new()
		probe.add_theme_font_size_override("font_size", BoardView.HP_TEXT_FONT_SIZE)
		board.add_child(probe)
		probe.visible = false
		var font: Font = probe.get_theme_font("font")
		print("FONT [%s] %s class=%s" % [size, font.get_font_name() if font else "null", font.get_class() if font else ""])
		for s: String in STRINGS:
			probe.text = s
			var fw: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, BoardView.HP_TEXT_FONT_SIZE).x
			var mw: float = probe.get_minimum_size().x
			print("MEASURE [%s] str='%s' string_size_w=%.1f label_min_w=%.1f avail_w=%.1f overflow_by_string_size=%s overflow_by_label_min=%s" % [
				size, s, fw, mw, avail, fw > avail, mw > avail])
		probe.queue_free()
		# 場上實際 HP Label
		var labels: Array[Label] = []
		_find_hp_labels(board, labels)
		print("REAL_LABELS [%s] count=%d" % [size, labels.size()])
		for i: int in range(mini(labels.size(), 6)):
			var l: Label = labels[i]
			print("REAL_LABEL [%s] #%d text='%s' size=%s position=%s min_size=%s parent_size=%s" % [
				size, i, l.text, l.size, l.position, l.get_minimum_size(), (l.get_parent() as Control).size])
		await _frames(3)
		if not _headless:
			await RenderingServer.frame_post_draw
		_shot(size, "normal")
		if labels.size() > 0:
			labels[0].text = "30→15"
			print("REAL_LABEL [%s] mutated #0 -> '30→15' min_size=%s size=%s" % [size, labels[0].get_minimum_size(), labels[0].size])
			await _frames(3)
			if not _headless:
				await RenderingServer.frame_post_draw
			_shot(size, "preview_30to15")
		inst.queue_free()
		await _frames(3)
	print("DONE")
	quit(0)

func _shot(size: Vector2i, tag: String) -> void:
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT %s -> get_image() is null (expected under headless)" % tag)
		return
	var full: String = "%dx%d_%s.png" % [size.x, size.y, tag]
	print("SHOT %s save_err=%d img=%s" % [full, img.save_png(ProjectSettings.globalize_path(OUT_DIR + full)), img.get_size()])
