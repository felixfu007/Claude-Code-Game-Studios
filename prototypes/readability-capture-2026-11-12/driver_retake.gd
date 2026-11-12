extends SceneTree
## 補拍驅動(2026-11-12 午間)。不改 driver.gd。輸出 out_retake/。
## 重點修正:原驅動在 960x540 強設 _cursor_cell 沒觸發重繪(_process 每幀用 CursorStateHost 權威覆寫回去)。
## 本版:先送合成滑鼠移動;游標沒到位就改走 CursorStateHost.set_target(真實的呼叫端改標入口),
## 再等幀讓 _process 自己重繪;並在 log 印「資訊卡文字」當物證。仍沒到位 -> 檔名加 _CURSOR_FAILED,不假裝成功。
## 規則同原驅動:load() 真實 BattleScreen.tscn、instantiate -> 設 override -> call_deferred add_child -> 等幀。
const OUT_DIR: String = "res://prototypes/readability-capture-2026-11-12/out_retake/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"
const R_REAL: String = "res://assets/data/units/vs01_roster.txt"
const R_LOS: String = "res://prototypes/readability-capture-2026-11-12/fixture_roster_los.txt"
const R_TERR: String = "res://prototypes/readability-capture-2026-11-12/fixture_roster_terrain_enemy.txt"

var _sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1920, 1080)]
var _shots: int = 0
var _headless: bool = false
var _WL: GDScript
var _BC: GDScript
var _CT: GDScript
var _CTYPES: GDScript

func _initialize() -> void:
	_run()

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _make(roster: String) -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	inst.terrain_path_override = L_TERRAIN
	inst.roster_path_override = roster
	inst.affinity_path_override = L_AFF
	inst.cards_path_override = L_CARDS
	inst.card_text_path_override = L_CARDTXT
	root.call_deferred("add_child", inst)
	await _frames(12)
	return inst

func _info(inst: Node) -> String:
	var bg: Node = inst.get_node("UILayer/TileInfoPanelBg")
	var lb: Label = inst.get_node("UILayer/TileInfoPanelBg/TileInfoPanelLabel")
	return "panel_visible=%s cursor_cell=%s cursor_active=%s text=%s" % [
		str(bg.visible), str(inst._cursor_cell), str(inst._cursor_active), lb.text.replace("\n", " | ")]

func _shot(inst: Node, state: String, suffix: String = "") -> void:
	await _frames(3)
	if not _headless:
		await RenderingServer.frame_post_draw
	var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	print("HOST [%s] root.size=%s WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
		state, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])
	print("INFO [%s] %s" % [state, _info(inst)])
	var fname: String = "%02d_%dx%d_%s%s.png" % [_shots, root.size.x, root.size.y, state, suffix]
	_shots += 1
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

## 把游標移到 cell 並確認真的重繪過。回傳是否到位。
func _move_cursor(inst: Node, cell: Vector2i) -> bool:
	await _mouse_move(_cell_pos(cell))
	await _frames(3)
	if inst._cursor_cell == cell and inst._cursor_active:
		print("CURSOR %s reached via mouse motion" % str(cell))
		return true
	print("CURSOR %s NOT reached via motion (at %s); trying CursorStateHost.set_target" % [str(cell), str(inst._cursor_cell)])
	var host: Node = root.get_node("CursorStateHost")
	var tgt: Object = _CT.make(_CTYPES.SurfaceType.BOARD_TILE, _CTYPES.encode_tile(cell, _BC.BOARD_COLS))
	var res: Variant = host.set_target(tgt)
	await _frames(4)
	var ok: bool = inst._cursor_cell == cell and inst._cursor_active
	print("CURSOR %s set_target result=%s reached=%s" % [str(cell), str(res), str(ok)])
	return ok

func _cursor_shot(inst: Node, cell: Vector2i, state: String) -> void:
	var ok: bool = await _move_cursor(inst, cell)
	await _shot(inst, state, "" if ok else "_CURSOR_FAILED")

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
		await _s1_cursor()
		await _s2_cards()
		await _s3_acted_lowhp()
		await _s4_terrain_enemy()
	print("TOTAL shots=", _shots)
	paused = false
	quit()

## 項目 1:03/04 重拍(合成站位,同原驅動 fixture_roster_los.txt)
func _s1_cursor() -> void:
	var inst: Node = await _make(R_LOS)
	await _click(_cell_pos(Vector2i(4, 3)))
	print("S1 select 丙: last_click=", inst.diagnostic_last_click_tile_action())
	await _cursor_shot(inst, Vector2i(8, 3), "03r_cursor_on_los_blocked_enemy")
	await _click(_cell_pos(Vector2i(2, 5)), MOUSE_BUTTON_RIGHT)
	await _cursor_shot(inst, Vector2i(2, 2), "04r_cursor_on_empty_tile")
	inst.queue_free()
	await _frames(3)

## 項目 2、3:選牌 -> 選目標 -> (確認面板) -> 打出後。全用真實動作事件。
func _s2_cards() -> void:
	var inst: Node = await _make(R_REAL)
	await _action(&"battle_open_hand")
	print("S2 hand opened: hand_selecting=", inst._card_selecting_from_hand)
	await _action(&"battle_confirm")
	print("S2 after confirm on card: selecting_from_hand=%s selecting_target=%s confirming=%s" % [
		str(inst._card_selecting_from_hand), str(inst._card_selecting_target), str(inst._card_confirming)])
	await _shot(inst, "10_card_selected_target_prompt")
	# 若卡片不需選目標會直接進確認面板;否則再按一次確認選第一個合法目標
	if inst._card_selecting_target:
		var tries: int = 0
		while inst._card_selecting_target and tries < 3:
			await _action(&"battle_confirm")
			await _frames(3)
			tries += 1
		print("S2 target confirm tries=", tries)
		print("S2 after target confirm: selecting_target=%s confirming=%s" % [
			str(inst._card_selecting_target), str(inst._card_confirming)])
		await _shot(inst, "11_card_confirm_panel")
	if inst._card_confirming:
		await _action(&"battle_confirm")
		await _frames(5)
		print("S2 after final confirm: confirming=%s selecting_from_hand=%s" % [
			str(inst._card_confirming), str(inst._card_selecting_from_hand)])
	await _shot(inst, "12_after_card_played")
	inst.queue_free()
	await _frames(3)

## 項目 4、5:已行動變暗(controller.end_unit_turn 真實入口 + _refresh_view)、低血量(Unit.take_damage 注入)
func _s3_acted_lowhp() -> void:
	var inst: Node = await _make(R_REAL)
	var ended: bool = inst._controller.end_unit_turn(1)
	var u2: Object = inst._state.unit_by_id(2)
	u2.take_damage(20)
	var u3: Object = inst._state.unit_by_id(3)
	u3.take_damage(18)
	inst._refresh_view()
	print("S3 end_unit_turn(1)=%s action_state(1)=%s hp(乙)=%d/%d hp(丙)=%d/%d" % [
		str(ended), str(inst._controller.unit_action_state(1)), u2.hp, u2.hp_max, u3.hp, u3.hp_max])
	await _shot(inst, "13_acted_unit1_and_low_hp_unit2_unit3")
	await _cursor_shot(inst, Vector2i(0, 3), "14_cursor_on_low_hp_unit2")
	inst.queue_free()
	await _frames(3)

## 項目 6:敵兵站灌木 / 倒木格(合成名冊)
func _s4_terrain_enemy() -> void:
	var inst: Node = await _make(R_TERR)
	await _shot(inst, "15_enemies_on_bush_and_log_open")
	await _cursor_shot(inst, Vector2i(5, 1), "16_cursor_on_enemy_in_bush")
	await _cursor_shot(inst, Vector2i(6, 2), "17_cursor_on_enemy_on_fallen_log")
	inst.queue_free()
	await _frames(3)
