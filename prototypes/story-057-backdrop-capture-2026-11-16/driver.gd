extends SceneTree
## story-057 真實實作截圖驅動(拍真實 BattleScreen + 真實 BoardView 襯底,不用 ColorRect 模擬)。
## 兩狀態:overview(無游標)/ cursor_xu(游標停徐培恩),960x540 與 1920x1080。WATCHDOG 150 秒。
const OUT_DIR: String = "res://prototypes/story-057-backdrop-capture-2026-11-16/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const L_ROSTER: String = "res://assets/data/units/vs01_roster.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"
const WATCHDOG_SEC: float = 150.0
const BACKDROP_COLOR: Color = Color("0E0F14")
const XU_CELL: Vector2i = Vector2i(0, 3)  ## 徐培恩 = id2 乙,vs01_roster 起點 (0,3)

var _sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1920, 1080)]
var _shots: int = 0
var _headless: bool = false
var _WL: GDScript
var _BC: GDScript
var _CT: GDScript
var _CTYPES: GDScript
var _BV: GDScript

func _initialize() -> void:
	create_timer(WATCHDOG_SEC).timeout.connect(_watchdog)
	_run()

func _watchdog() -> void:
	print("WATCHDOG fired after %.0fs; shots=%d -> quit(2)" % [WATCHDOG_SEC, _shots])
	paused = false
	quit(2)

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _make() -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	inst.terrain_path_override = L_TERRAIN
	inst.roster_path_override = L_ROSTER
	inst.affinity_path_override = L_AFF
	inst.cards_path_override = L_CARDS
	inst.card_text_path_override = L_CARDTXT
	root.call_deferred("add_child", inst)
	await _frames(12)
	return inst

func _mouse_move(pos: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = Vector2(3, 3)
	Input.parse_input_event(e)
	await _frames(2)

func _move_cursor(inst: Node, cell: Vector2i) -> bool:
	var p: Vector2 = _BC.grid_to_window(cell, _WL.canvas_to_window_transform(root.size), Vector2.ZERO)
	await _mouse_move(p)
	await _frames(3)
	if inst._cursor_cell == cell and inst._cursor_active:
		print("CURSOR %s reached via mouse motion" % str(cell))
		return true
	var host: Node = root.get_node("CursorStateHost")
	var tgt: Object = _CT.make(_CTYPES.SurfaceType.BOARD_TILE, _CTYPES.encode_tile(cell, _BC.BOARD_COLS))
	var res: Variant = host.set_target(tgt)
	await _frames(4)
	var ok: bool = inst._cursor_cell == cell and inst._cursor_active
	print("CURSOR %s via set_target result=%s reached=%s" % [str(cell), str(res), str(ok)])
	return ok

func _shot(inst: Node, state: String, variant: String) -> void:
	await _frames(3)
	if not _headless:
		await RenderingServer.frame_post_draw
	var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	print("HOST [%s/%s] root.size=%s WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s cursor_active=%s cursor_cell=%s" % [
		state, variant, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size),
		str(inst._cursor_active), str(inst._cursor_cell)])
	var fname: String = "%dx%d_%s_%s.png" % [root.size.x, root.size.y, state, variant]
	_shots += 1
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT %s -> get_image() is null (expected under headless; skipped)" % fname)
		return
	var sc: int = c.stretch_shrink
	for cell: Vector2i in [Vector2i(0, 2), XU_CELL]:
		var bp: Vector2 = (_BC.grid_to_local(cell) + _BV.piece_label_rect_in_cell().position + Vector2(1, 1)) * float(sc)
		print("BACKDROP_PX [%s/%s] cell=%s top-left-corner-pixel=%s" % [state, variant, str(cell), str(img.get_pixelv(Vector2i(bp)))])
	print("SHOT %s -> %dx%d save_err=%d" % [fname, img.get_width(), img.get_height(),
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + fname))])

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_WL = load("res://src/ui/battle/world_layout.gd")
	_BC = load("res://src/ui/battle/board_coords.gd")
	_CT = load("res://src/ui/cursor/cursor_target.gd")
	_CTYPES = load("res://src/ui/cursor/cursor_types.gd")
	_BV = load("res://src/ui/battle/board_view.gd")
	root.title = "x"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	for sz: Vector2i in _sizes:
		for t: int in range(5):
			root.size = sz
			await _frames(5)
			if root.size == sz:
				break
		await _frames(5)
		print("=== RESOLUTION requested=%s actual root.size=%s ===" % [str(sz), str(root.size)])
		var inst: Node = await _make()
		# 狀態①要「無游標」:出生時為鍵盤權威、游標在種子格(0,2);合成滑鼠移到視窗外 -> 滑鼠權威且格出界 -> _cursor_active=false
		await _frames(10)
		await _mouse_move(Vector2(-50, -50))
		await _mouse_move(Vector2(-60, -60))
		await _frames(4)
		await _frames(6)
		print("PRE-OVERVIEW cursor_active=%s (need false)" % str(inst._cursor_active))
		# 狀態①:總覽無游標
		await _shot(inst, "1overview", "real")
		var ok: bool = await _move_cursor(inst, XU_CELL)
		await _frames(2)
		await _shot(inst, "2cursor_xu" + ("" if ok else "_CURSOR_FAILED"), "real")
		inst.queue_free()
		await _frames(3)
	print("TOTAL shots=%d" % _shots)
	paused = false
	quit()
