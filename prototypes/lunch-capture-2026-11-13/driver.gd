extends SceneTree
## 午休截圖驅動(2026-11-13):story-044 高亮 / story-045 提示列五態 / story-041 血量數字。
## 規則:load() 真實 BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等幀(technical-preferences 第 5 點)。
## 輸入=合成真實輸入事件;游標權威非滑鼠時改走 CursorStateHost.set_target。不碰真滑鼠、不 warp。
## 內建 WATCHDOG:150 秒強制 quit。headless 下 get_image() 為 null 屬正常,只驗流程與狀態物證。
const OUT_DIR: String = "res://prototypes/lunch-capture-2026-11-13/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"
const R_044: String = "res://prototypes/lunch-capture-2026-11-13/fixture_roster_044.txt"
const T_DUEL: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const R_DUEL: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const R_DOOMED: String = "res://assets/data/units/test_fixture_roster_doomed.txt"
const WATCHDOG_SEC: float = 150.0

var _sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1366, 768)]
var _shots: int = 0
var _states_done: int = 0
var _headless: bool = false
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

func _evidence(inst: Node) -> String:
	var hint: Label = inst.get_node("UILayer/ControlsHintBg/ControlsHintLabel")
	var hbg: CanvasItem = inst.get_node("UILayer/ControlsHintBg")
	var ctl: Object = inst._controller
	return "phase=%d outcome=%d sel_unit=%d hint_state=%d hint_bg_visible=%s hint_text='%s' hand_open=%s card_selecting_target=%s card_confirming=%s cursor_cell=%s cursor_active=%s" % [
		ctl.phase(), ctl.outcome(), ctl.selected_unit(), int(inst._current_hint_state()), str(hbg.visible),
		hint.text.replace("\n", " | "), str(inst._card_selecting_from_hand), str(inst._card_selecting_target),
		str(inst._card_confirming), str(inst._cursor_cell), str(inst._cursor_active)]

func _shot(inst: Node, state: String, tag: String) -> void:
	await _frames(3)
	if not _headless:
		await RenderingServer.frame_post_draw
	var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	print("HOST [%s] root.size=%s WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
		state, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])
	print("STATE [%s] %s" % [state, _evidence(inst)])
	var fname: String = "%02d_%dx%d_%s_%s.png" % [_shots, root.size.x, root.size.y, tag, state]
	_shots += 1
	_states_done += 1
	var img: Image = root.get_texture().get_image()
	if img == null:
		print("SHOT %s -> get_image() is null (expected under headless; skipped)" % fname)
		return
	print("SHOT %s -> %dx%d save_err=%d" % [fname, img.get_width(), img.get_height(),
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + fname))])

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

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_WL = load("res://src/ui/battle/world_layout.gd")
	_BC = load("res://src/ui/battle/board_coords.gd")
	_CT = load("res://src/ui/cursor/cursor_target.gd")
	_CTYPES = load("res://src/ui/cursor/cursor_types.gd")
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
		await _s044()
		await _s045()
		await _s041()
	print("TOTAL shots=%d states_done=%d" % [_shots, _states_done])
	paused = false
	quit()

## story-044:選丙 -> 可攻擊(E1 於 (4,0))與視線被擋(E3 於 (8,3));再開手牌選牌選目標。
func _s044() -> void:
	var inst: Node = await _make(R_044)
	await _click(_cell_pos(Vector2i(4, 3)))
	print("S044 select 丙: last_click=", inst.diagnostic_last_click_tile_action())
	await _shot(inst, "unit_selected_attackable_and_los_blocked", "s044")
	var ok: bool = await _move_cursor(inst, Vector2i(8, 3))
	await _shot(inst, "cursor_on_los_blocked_enemy" + ("" if ok else "_CURSOR_FAILED"), "s044")
	ok = await _move_cursor(inst, Vector2i(4, 0))
	await _shot(inst, "cursor_on_attackable_enemy" + ("" if ok else "_CURSOR_FAILED"), "s044")
	await _action(&"battle_open_hand")
	await _action(&"battle_confirm")
	print("S044 after hand+confirm: selecting_target=%s" % str(inst._card_selecting_target))
	if not inst._card_selecting_target:
		print("S044 NOTE: card did not enter target selection; the next screenshot is NOT the target state")
	await _shot(inst, "card_selecting_target" + ("" if inst._card_selecting_target else "_NOT_REACHED"), "s044")
	paused = false
	inst.queue_free()
	await _frames(3)

## story-045:提示列五態。
func _s045() -> void:
	var inst: Node = await _make(R_044)
	await _shot(inst, "hint_1_no_selection", "s045")
	await _click(_cell_pos(Vector2i(4, 3)))
	await _shot(inst, "hint_2_unit_selected", "s045")
	await _action(&"battle_open_hand")
	await _shot(inst, "hint_3_hand_open", "s045")
	await _action(&"battle_open_hand")
	await _click(_cell_pos(Vector2i(2, 5)), MOUSE_BUTTON_RIGHT)
	inst._end_faction_phase_pressed()
	await _frames(15)
	await _shot(inst, "hint_4_enemy_phase", "s045")
	paused = false
	inst.queue_free()
	await _frames(3)
	# 戰鬥結束(勝利):合成 duel 夾具,提示列應為空
	inst = await _make(R_DUEL, false, T_DUEL)
	await _click(_cell_pos(Vector2i(0, 0)))
	await _click(_cell_pos(Vector2i(1, 0)))
	await _frames(20)
	await _shot(inst, "hint_5_finished_victory", "s045")
	inst.queue_free()
	await _frames(3)
	# 戰鬥結束(戰敗)
	inst = await _make(R_DOOMED, false, T_DUEL)
	inst._end_faction_phase_pressed()
	var n: int = 0
	while inst._controller.outcome() == 0 and n < 400:
		await process_frame
		n += 1
	await _frames(20)
	await _shot(inst, "hint_5_finished_defeat", "s045")
	inst.queue_free()
	await _frames(3)

## story-041:低血量(注入 take_damage,不改資料檔)+ 游標停上去顯示血量數字與首字。
func _s041() -> void:
	var inst: Node = await _make(R_044)
	var u2: Object = inst._state.unit_by_id(2)
	var u8: Object = inst._state.unit_by_id(8)
	u2.take_damage(20)
	u8.take_damage(15)
	inst._refresh_view()
	print("S041 injected: 乙 %d/%d  E3 %d/%d" % [u2.hp, u2.hp_max, u8.hp, u8.hp_max])
	await _shot(inst, "lowhp_overview_no_cursor", "s041")
	var ok: bool = await _move_cursor(inst, Vector2i(0, 3))
	await _shot(inst, "lowhp_cursor_on_player_unit2" + ("" if ok else "_CURSOR_FAILED"), "s041")
	ok = await _move_cursor(inst, Vector2i(8, 3))
	await _shot(inst, "lowhp_cursor_on_enemy_E3" + ("" if ok else "_CURSOR_FAILED"), "s041")
	inst.queue_free()
	await _frames(3)
