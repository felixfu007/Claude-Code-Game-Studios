extends SceneTree
## story-059 圖例開窗實拍驅動。真實 BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等幀。
## 用法(開窗,辦公室規則):
##   timeout 100 <godot console> --audio-driver Dummy --title=x --position 0,0 --path . \
##     -s res://prototypes/story-059-legend-layout-evidence-2026-11-17/driver.gd -- 960x540 1280x720
## 每個尺寸輸出 HOST(WorldViewportContainer 與 WorldViewport 實測值)、圖例 content_rect、截圖。
const OUT_DIR: String = "res://prototypes/story-059-legend-layout-evidence-2026-11-17/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const R_VS01: String = "res://assets/data/units/vs01_roster.txt"
const WATCHDOG_SEC: float = 80.0

var _sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]


func _initialize() -> void:
	create_timer(WATCHDOG_SEC).timeout.connect(func() -> void:
		print("WATCHDOG fired")
		quit(2))
	_run()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _run() -> void:
	root.title = "x"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_sizes.clear()
		for a: String in args:
			var p: PackedStringArray = a.split("x")
			_sizes.append(Vector2i(int(p[0]), int(p[1])))
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	for sz: Vector2i in _sizes:
		for t: int in range(5):
			root.size = sz
			await _frames(5)
			if root.size == sz:
				break
		var inst: Node = (load(SCENE) as PackedScene).instantiate()
		inst.terrain_path_override = L_TERRAIN
		inst.roster_path_override = R_VS01
		root.call_deferred("add_child", inst)
		await _frames(12)
		inst.open_legend()
		await _frames(4)
		await RenderingServer.frame_post_draw
		var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
		var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
		print("HOST [%dx%d] root.size=%s WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
			sz.x, sz.y, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])
		var panel: Control = inst.legend_panel()
		print("LEGEND [%dx%d] open=%s content_rect=%s window_area=%d content_area=%d" % [
			sz.x, sz.y, str(inst.is_legend_open()), str(panel.content_rect()),
			root.size.x * root.size.y, int(panel.content_rect().get_area())])
		var img: Image = root.get_texture().get_image()
		var fname: String = "legend_%dx%d.png" % [sz.x, sz.y]
		if img == null:
			print("SHOT ", fname, " -> get_image() null")
		else:
			print("SHOT ", fname, " size=", img.get_size(), " save=", img.save_png(ProjectSettings.globalize_path(OUT_DIR + fname)))
		inst.queue_free()
		await _frames(3)
	quit()
