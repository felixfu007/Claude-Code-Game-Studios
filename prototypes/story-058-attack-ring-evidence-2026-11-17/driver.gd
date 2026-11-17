extends SceneTree
## story-058 probe/evidence driver (2026-11-17).
## 規則:load() 真實 BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等幀(technical-preferences 第 5 點)。
## 輸入=合成真實輸入事件;游標權威非滑鼠時改走 CursorStateHost.set_target。不碰真滑鼠、不 warp。
## 內建 WATCHDOG:150 秒強制 quit。headless 下 get_image() 為 null 屬正常,只驗流程與狀態物證。
const OUT_DIR: String = "res://prototypes/story-058-attack-ring-evidence-2026-11-17/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"
const R_044: String = "res://prototypes/story-058-attack-ring-evidence-2026-11-17/fixture_roster_044.txt"
const WATCHDOG_SEC: float = 100.0
var _shots: int = 0
var _states_done: int = 0
var _WL: GDScript
var _BC: GDScript
var _CT: GDScript
var _CTYPES: GDScript
func _initialize() -> void:
	create_timer(WATCHDOG_SEC).timeout.connect(_watchdog)
	_run()
func _watchdog() -> void:
	print("WATCHDOG fired after %.0fs; shots=%d states_done=%d -> quit(2)" % [WATCHDOG_SEC, _shots, _states_done])
	paused = false
	quit(2)

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _make(roster: String, full: bool = true, terrain: String = L_TERRAIN) -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	inst.terrain_path_override = terrain
	inst.roster_path_override = roster
	if full:
		inst.affinity_path_override = L_AFF
		inst.cards_path_override = L_CARDS
		inst.card_text_path_override = L_CARDTXT
	root.call_deferred("add_child", inst)
	await _frames(12)
	return inst
func _cell_pos(cell: Vector2i) -> Vector2:
	return _BC.grid_to_window(cell, _WL.canvas_to_window_transform(root.size), Vector2.ZERO)

func _mouse_move(pos: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = Vector2(3, 3)
	Input.parse_input_event(e)
	await _frames(2)

func _click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await _mouse_move(pos)
	for pressed: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)

func _action(act: StringName) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventAction = InputEventAction.new()
		e.action = act
		e.pressed = pressed
		Input.parse_input_event(e)
		await _frames(2)

func _move_cursor(inst: Node, cell: Vector2i) -> bool:
	await _mouse_move(_cell_pos(cell))
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

func _ring_report(inst: Node, state: String, cell: Vector2i, sz: Vector2i) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	print("HOST [%s] root.size=%s WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [state, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])
	var img: Image = v.get_texture().get_image()
	if img == null:
		print("IMG null"); return
	var o: Vector2i = Vector2i(_BC.grid_to_local(cell))
	print("CELL %s local_origin=%s img=%dx%d cursor_active=%s cursor_cell=%s" % [str(cell), str(o), img.get_width(), img.get_height(), str(inst._cursor_active), str(inst._cursor_cell)])
	for y: int in range(-2, 5):
		var row: String = ""
		for x: int in [0, 1, 2, 5, 10, 15, 16, 20, 25, 29, 30, 31]:
			row += "#%s " % img.get_pixel(o.x + x, o.y + y).to_html(false)
		print("ROW [%s] y=%d: %s" % [state, y, row])
	for y: int in range(0, 10):
		print("LEFTCOL [%s] y=%d: x0=#%s x1=#%s x2=#%s" % [state, y, img.get_pixel(o.x, o.y + y).to_html(false), img.get_pixel(o.x + 1, o.y + y).to_html(false), img.get_pixel(o.x + 2, o.y + y).to_html(false)])
	# left/right/bottom edges for reference
	print("EDGE [%s] left(0,16)=#%s right(31,16)=#%s bottom(16,31)=#%s" % [state, img.get_pixel(o.x, o.y + 16).to_html(false), img.get_pixel(o.x + 31, o.y + 16).to_html(false), img.get_pixel(o.x + 16, o.y + 31).to_html(false)])
	var fname: String = "%s_%dx%d.png" % [state, sz.x, sz.y]
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + fname))

func _run() -> void:
	_WL = load("res://src/ui/battle/world_layout.gd")
	_BC = load("res://src/ui/battle/board_coords.gd")
	_CT = load("res://src/ui/cursor/cursor_target.gd")
	_CTYPES = load("res://src/ui/cursor/cursor_types.gd")
	root.title = "x"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	for sz: Vector2i in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		for t: int in range(5):
			root.size = sz
			await _frames(5)
			if root.size == sz:
				break
		await _frames(5)
		print("=== RESOLUTION requested=%s actual=%s ===" % [str(sz), str(root.size)])
		var inst: Node = await _make(R_044)
		await _click(_cell_pos(Vector2i(4, 3)))
		print("select: ", inst.diagnostic_last_click_tile_action(), " sel_unit=", inst._controller.selected_unit())
		await _ring_report(inst, "select_only", Vector2i(4, 0), sz)
		var ok: bool = await _move_cursor(inst, Vector2i(4, 0))
		await _ring_report(inst, "cursor_on_enemy" + ("" if ok else "_CURSOR_FAILED"), Vector2i(4, 0), sz)
		inst.queue_free()
		await _frames(3)
	paused = false
	quit()
