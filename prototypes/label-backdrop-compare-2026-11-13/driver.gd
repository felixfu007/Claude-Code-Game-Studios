extends SceneTree
## 棋子首字襯底並排比較驅動(2026-11-13)。模擬,非正式實作:驅動在首字 Label 同父節點(PieceLabelLayer)
## 之下插入 ColorRect;矩形一律呼叫 BoardView.piece_label_rect_in_cell()。不改 src/。
## load() 真實 BattleScreen.tscn(technical-preferences 第 5 點)。WATCHDOG 150 秒。
const OUT_DIR: String = "res://prototypes/label-backdrop-compare-2026-11-13/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const L_ROSTER: String = "res://assets/data/units/vs01_roster.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"
const WATCHDOG_SEC: float = 150.0
const BACKDROP_COLOR: Color = Color("0E0F14")
const XU_CELL: Vector2i = Vector2i(0, 3)  ## 徐培恩 = id2 乙,vs01_roster 起點 (0,3)
## 變體:名稱, 我方 alpha(0=不加), 是否只徐培恩
const VARIANTS: Array = [
	["0current", 0.0, false],
	["A_alpha072", 0.72, false],
	["B_alpha050", 0.50, false],
	["C_xu_only_alpha072", 0.72, true],
]

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

## 在每個可見首字 Label 同父節點、其正下方插入 ColorRect。回傳 [備份節點陣列, 徐培恩那塊的索引]。
func _insert_backdrops(inst: Node) -> Array:
	var bv: Node = inst.get_node("WorldViewportContainer/WorldViewport/BoardView")
	var layer: Node = bv._piece_label_layer
	var rect: Rect2 = _BV.piece_label_rect_in_cell()
	var made: Array[ColorRect] = []
	var xu: Array[bool] = []
	var xu_top_left: Vector2 = _BC.grid_to_local(XU_CELL)
	var labels: Array = []
	for n: Node in layer.get_children():
		if n is Label and (n as Label).visible:
			labels.append(n)
	for l: Label in labels:
		var cell_tl: Vector2 = l.position - rect.position  # 由 Label 反推格左上,僅取「是哪一格」
		var bd: ColorRect = ColorRect.new()
		bd.name = "DriverBackdrop"
		bd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bd.position = cell_tl + rect.position
		bd.size = rect.size
		bd.color = BACKDROP_COLOR
		layer.add_child(bd)
		layer.move_child(bd, l.get_index())  # 插在該 Label 之前 = 其下
		made.append(bd)
		xu.append(cell_tl.is_equal_approx(xu_top_left))
		var is_enemy: bool = l.text.is_valid_int()  # 敵方首字為數字編號(1~5),我方為漢字
		bd.set_meta("enemy", is_enemy)
		bd.set_meta("xu", cell_tl.is_equal_approx(xu_top_left))
		print("BACKDROP label='%s' enemy=%s xu=%s pos=%s size=%s label_idx=%d bd_idx=%d" % [
			l.text, str(is_enemy), str(bd.get_meta("xu")), str(bd.position), str(bd.size), l.get_index(), bd.get_index()])
	return [made, xu]

func _apply_variant(made: Array, alpha: float, xu_only: bool) -> void:
	for bd: ColorRect in made:
		var show: bool = alpha > 0.0 and not bd.get_meta("enemy")
		if xu_only:
			show = show and bd.get_meta("xu")
		bd.visible = show
		bd.color = Color(BACKDROP_COLOR.r, BACKDROP_COLOR.g, BACKDROP_COLOR.b, alpha)

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
		var info: Array = _insert_backdrops(inst)
		for vr: Array in VARIANTS:
			_apply_variant(info[0], vr[1], vr[2])
			await _shot(inst, "1overview", vr[0])
		# 狀態②:游標停徐培恩(游標移動可能重繪,故重新插入前先清掉舊襯底)
		for bd: ColorRect in info[0]:
			bd.queue_free()
		var ok: bool = await _move_cursor(inst, XU_CELL)
		await _frames(2)
		var info2: Array = _insert_backdrops(inst)
		for vr: Array in VARIANTS:
			_apply_variant(info2[0], vr[1], vr[2])
			await _shot(inst, "2cursor_xu" + ("" if ok else "_CURSOR_FAILED"), vr[0])
		inst.queue_free()
		await _frames(3)
	print("TOTAL shots=%d" % _shots)
	paused = false
	quit()
