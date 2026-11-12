extends SceneTree
## 可讀性稽核截圖驅動(2026-11-12)。開窗跑一次;headless 只驗流程(get_image 為 null,預期)。
## 第 5 點:load() 真實 BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等 2 幀。
## 輸入一律用合成的真實輸入事件(Input.parse_input_event),不碰真滑鼠、不 warp。
## 用 load() 取類別,避免 -s 腳本編譯時 Autoload 尚未註冊的問題。
const OUT_DIR: String = "res://prototypes/readability-capture-2026-11-12/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"
const R_LOS: String = "res://prototypes/readability-capture-2026-11-12/fixture_roster_los.txt"
const T_DUEL: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const R_DUEL: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const R_DOOMED: String = "res://assets/data/units/test_fixture_roster_doomed.txt"

var _sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1440, 810), Vector2i(1920, 1080)]
var _shots: int = 0
var _headless: bool = false
var _WL: GDScript
var _BC: GDScript

func _initialize() -> void:
	_run()

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _make(terrain: String, roster: String, full: bool = true) -> Node:
	var scene: PackedScene = load(SCENE)
	var inst: Node = scene.instantiate()
	inst.terrain_path_override = terrain
	inst.roster_path_override = roster
	if full:
		inst.affinity_path_override = L_AFF
		inst.cards_path_override = L_CARDS
		inst.card_text_path_override = L_CARDTXT
	root.call_deferred("add_child", inst)
	await _frames(12)
	return inst

func _log_host(inst: Node, state: String) -> void:
	var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	print("HOST [%s] root.size=%s WorldViewportContainer position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
		state, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])

func _shot(inst: Node, state: String) -> void:
	await _frames(3)
	if not _headless:
		await RenderingServer.frame_post_draw
	_log_host(inst, state)
	var fname: String = "%02d_%dx%d_%s.png" % [_shots, root.size.x, root.size.y, state]
	_shots += 1
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT %s -> get_image() is null (expected under headless; skipped)" % fname)
		return
	var err: int = img.save_png(ProjectSettings.globalize_path(OUT_DIR + fname))
	print("SHOT %s -> %dx%d save_err=%d" % [fname, img.get_width(), img.get_height(), err])

func _cell_pos(cell: Vector2i) -> Vector2:
	var xf: Transform2D = _WL.canvas_to_window_transform(root.size)
	return _BC.grid_to_window(cell, xf, Vector2.ZERO)

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

func _state(inst: Node) -> String:
	return "phase=%d outcome=%d last_click=%s" % [inst._controller.phase(), inst._controller.outcome(), str(inst.diagnostic_last_click_tile_action())]

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_WL = load("res://src/ui/battle/world_layout.gd")
	_BC = load("res://src/ui/battle/board_coords.gd")
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
		await _frames(5)
		print("=== RESOLUTION requested=%s actual root.size=%s ===" % [str(sz), str(root.size)])
		await _scenario_los()
		await _scenario_victory()
		await _scenario_defeat()
	print("TOTAL shots=", _shots)
	quit()

func _scenario_los() -> void:
	var inst: Node = await _make(L_TERRAIN, R_LOS)
	print("LOS resolved=", inst.diagnostic_resolved_data_paths())
	await _shot(inst, "01_open")
	await _click(_cell_pos(Vector2i(4, 3)))
	print("LOS after select 丙: ", _state(inst))
	await _shot(inst, "02_selected_ranges")
	await _mouse_move(_cell_pos(Vector2i(8, 3)))
	print("LOS cursor after hover E3: cell=%s active=%s" % [str(inst._cursor_cell), str(inst._cursor_active)])
	if inst._cursor_cell != Vector2i(8, 3):
		print("LOS NOTE: injected motion did not move cursor (mouse authority reads live pointer); FORCING _cursor_cell")
		inst._cursor_cell = Vector2i(8, 3)
		inst._cursor_active = true
		inst._refresh_view()
	await _shot(inst, "03_cursor_on_los_blocked_enemy")
	await _click(_cell_pos(Vector2i(2, 5)), MOUSE_BUTTON_RIGHT)
	print("LOS after right-click cancel: ", _state(inst))
	await _mouse_move(_cell_pos(Vector2i(2, 2)))
	await _shot(inst, "04_cursor_on_empty_tile")
	await _action(&"battle_open_hand")
	print("LOS after open_hand: ", _state(inst), " hand_selecting=", inst._card_selecting_from_hand)
	await _shot(inst, "05_hand_open")
	await _action(&"battle_open_hand")
	await _action(&"battle_menu")
	await _shot(inst, "06_battle_menu")
	paused = false
	await _action(&"battle_cancel")
	inst._end_faction_phase_pressed()
	await _frames(15)
	print("LOS enemy phase early: ", _state(inst))
	await _shot(inst, "07_enemy_phase_a")
	await _frames(40)
	print("LOS enemy phase later: ", _state(inst))
	await _shot(inst, "07_enemy_phase_b")
	paused = false
	inst.queue_free()
	await _frames(3)

func _scenario_victory() -> void:
	var inst: Node = await _make(T_DUEL, R_DUEL, false)
	await _click(_cell_pos(Vector2i(0, 0)))
	await _click(_cell_pos(Vector2i(1, 0)))
	await _frames(20)
	print("VICTORY state: ", _state(inst))
	await _shot(inst, "08_victory")
	inst.queue_free()
	await _frames(3)

func _scenario_defeat() -> void:
	var inst: Node = await _make(T_DUEL, R_DOOMED, false)
	inst._end_faction_phase_pressed()
	var n: int = 0
	while inst._controller.outcome() == 0 and n < 400:
		await process_frame
		n += 1
	await _frames(20)
	print("DEFEAT state (waited %d frames): %s" % [n, _state(inst)])
	await _shot(inst, "09_defeat")
	inst.queue_free()
	await _frames(3)
