extends SceneTree
## story-061 AC5 開窗實拍驅動(只能開窗;headless 下像素取不到屬正常,腳本會印 null 並跑完)。
## 真實 BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等幀(規則第 5 點)。
## 棋子資料以 BoardView.render_pieces() 注入(真實宿主鏈、注入的是「畫哪些棋子」這份輸入資料)。
## 輸出:HOST 行(WorldViewportContainer position/size/stretch_shrink 與 WorldViewport.size)、
##   我方五位特寫(兩者皆做)、縱列四人四種狀態、圖例「已移動/已攻擊」兩列;各尺寸各一組。
## 用法(開窗,公司環境須:不在最上層、靜音;由協調者擇時執行):
##   timeout 150 <godot console> --audio-driver Dummy --title=x --position 0,0 --path . -s res://prototypes/story-061-action-icons-enlarge-evidence-2026-11-18/driver.gd -- 960x540 1920x1080
const OUT_DIR: String = "res://prototypes/story-061-action-icons-enlarge-evidence-2026-11-18/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const R_VS01: String = "res://assets/data/units/vs01_roster.txt"
const WATCHDOG_SEC: float = 140.0
const CLOSEUP_CELLS: float = 3.0

var _sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1920, 1080)]


func _initialize() -> void:
	create_timer(WATCHDOG_SEC).timeout.connect(func() -> void:
		print("WATCHDOG fired")
		quit(2))
	_run()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _piece(cell: Vector2i, sprite_index: int, flag: int) -> Dictionary:
	return {"cell": cell, "faction": "PLAYER", "sprite_index": sprite_index, "hp": 10, "hp_max": 10,
		"label": "甲乙丙丁戊"[sprite_index], "action_flag": flag}


## 世界層格內座標 -> 視窗像素:取自真實容器(位置 + size/viewport.size 倍率),不自算。
func _world_to_window(c: SubViewportContainer, v: SubViewport, p: Vector2) -> Vector2:
	var k: float = c.size.x / float(v.size.x)
	return c.position + p * k


func _save_crop(shot: Image, rect: Rect2i, fname: String) -> void:
	if shot == null:
		print("SHOT ", fname, " -> get_image() null")
		return
	var r: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, shot.get_size()))
	var img: Image = shot.get_region(r)
	print("SHOT ", fname, " crop=", r, " size=", img.get_size(), " save=", img.save_png(ProjectSettings.globalize_path(OUT_DIR + fname)))


func _capture(label: String) -> Image:
	# headless 下 frame_post_draw 不會觸發(實測看門狗逾時),直接等一般幀、像素取不到(null)。
	if DisplayServer.get_name() == "headless":
		await _frames(2)
		return root.get_texture().get_image()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


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
		var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
		var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
		print("HOST [%dx%d] root.size=%s WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
			sz.x, sz.y, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])
		var bv: BoardView = inst.get("_board_view")
		var done: int = BoardView.ActionFlag.DONE
		# 一、我方五位特寫(兩者皆做)
		for idx: int in range(5):
			var cell: Vector2i = Vector2i(3, 3)
			var pieces: Array[Dictionary] = [_piece(cell, idx, done)]
			bv.render_pieces(pieces)
			await _frames(3)
			var shot: Image = await _capture("closeup")
			var center: Vector2 = _world_to_window(c, v, BoardCoords.grid_to_local_center(cell))
			var half: float = CLOSEUP_CELLS * 0.5 * float(BoardCoords.CELL_SIZE) * (c.size.x / float(v.size.x))
			_save_crop(shot, Rect2i(Vector2i(center - Vector2(half, half)), Vector2i(Vector2(half, half) * 2.0)),
				"closeup_char%d_%dx%d.png" % [idx, sz.x, sz.y])
		# 一之二、我方格游標停留(15% 白罩泛白人眼確認):char0 兩者皆做 + 游標停在該格
		var hover_cell: Vector2i = Vector2i(3, 3)
		var hover_pieces: Array[Dictionary] = [_piece(hover_cell, 0, done)]
		bv.render_pieces(hover_pieces)
		bv.set_cursor(hover_cell)
		await _frames(3)
		var hover_shot: Image = await _capture("hover")
		var hcenter: Vector2 = _world_to_window(c, v, BoardCoords.grid_to_local_center(hover_cell))
		var hhalf: float = CLOSEUP_CELLS * 0.5 * float(BoardCoords.CELL_SIZE) * (c.size.x / float(v.size.x))
		_save_crop(hover_shot, Rect2i(Vector2i(hcenter - Vector2(hhalf, hhalf)), Vector2i(Vector2(hhalf, hhalf) * 2.0)),
			"closeup_char0_cursor_hover_%dx%d.png" % [sz.x, sz.y])
		bv.clear_cursor()
		# 二、縱列四人四種狀態(皆未用 / 只移動 / 只攻擊 / 兩者皆做)
		var states: Array[int] = [BoardView.ActionFlag.NONE_USED, BoardView.ActionFlag.ATTACK_ONLY,
			BoardView.ActionFlag.MOVE_ONLY, done]
		var column: Array[Dictionary] = []
		for i: int in range(4):
			column.append(_piece(Vector2i(3, 1 + i), i, states[i]))
		bv.render_pieces(column)
		await _frames(3)
		var col_shot: Image = await _capture("column")
		var top_left: Vector2 = _world_to_window(c, v, BoardCoords.grid_to_local(Vector2i(2, 1)))
		var k: float = c.size.x / float(v.size.x)
		_save_crop(col_shot, Rect2i(Vector2i(top_left), Vector2i(Vector2(3.0, 4.0) * float(BoardCoords.CELL_SIZE) * k)),
			"column_%dx%d.png" % [sz.x, sz.y])
		# 三、圖例「已移動 / 已攻擊」兩列
		inst.open_legend()
		await _frames(4)
		var legend_shot: Image = await _capture("legend")
		var panel: Control = inst.legend_panel()
		for kind: int in [BoardView.MarkerKind.ACTION_MOVED, BoardView.MarkerKind.ACTION_ATTACKED]:
			var icon: Node2D = panel.icon_for(kind)
			var b: Rect2 = BoardView.legend_sample_bounds(icon)
			var gr: Rect2 = icon.get_global_transform() * b
			print("LEGEND-ROW [%dx%d] kind=%d icon_bounds_global=%s" % [sz.x, sz.y, kind, str(gr)])
			_save_crop(legend_shot, Rect2i(Vector2i(gr.position) - Vector2i(8, 8), Vector2i(gr.size) + Vector2i(16, 16)),
				"legend_kind%d_%dx%d.png" % [kind, sz.x, sz.y])
		_save_crop(legend_shot, Rect2i(Vector2i.ZERO, sz), "legend_full_%dx%d.png" % [sz.x, sz.y])
		inst.queue_free()
		await _frames(3)
	quit()
