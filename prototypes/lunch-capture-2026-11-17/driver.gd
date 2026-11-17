extends SceneTree
## 午休截圖驅動(2026-11-17):story-046 選單五列 / 056 戰役戰敗重打 / 051 敵方型別名 / 054 鞋劍圖示 /
## 052 被擋章 / 047 圖例 / 053 結束角色行動按鈕(禁用 + 真高亮壓框)。
## 規則:load() 真實 BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等幀(technical-preferences 第 5 點)。
## 輸入=合成真實輸入事件;游標權威非滑鼠時改走 CursorStateHost.set_target。不碰真滑鼠、不 warp。
## 只依賴 BattleScreen / BattleController / HudLayout 的既有成員,不讀 BoardView 內部。
## 每狀態輸出 `STATE_RESULT [名稱] REACHED` 或 `UNREACHABLE <原因>`。內建 WATCHDOG 150 秒強制 quit。
const OUT_DIR: String = "res://prototypes/lunch-capture-2026-11-17/out/"
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const R_VS01: String = "res://assets/data/units/vs01_roster.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"
const R_054: String = "res://prototypes/lunch-capture-2026-11-17/fixture_roster_054.txt"
const R_052: String = "res://prototypes/lunch-capture-2026-11-17/fixture_roster_052.txt"
const WATCHDOG_SEC: float = 150.0

var _sizes: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1920, 1080)]
var _shots: int = 0
var _states_done: int = 0
var _headless: bool = false
var _WL: GDScript
var _BC: GDScript
var _CT: GDScript
var _CTYPES: GDScript
var _HL: GDScript
var _CP: GDScript

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

## full=true 注入 vs01 好感度/牌;ledger=true 以戰役模式啟動(注入戰役累積記錄)。
func _make(roster: String, full: bool = true, ledger: bool = false) -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	inst.terrain_path_override = L_TERRAIN
	inst.roster_path_override = roster
	if full:
		inst.affinity_path_override = L_AFF
		inst.cards_path_override = L_CARDS
		inst.card_text_path_override = L_CARDTXT
	if ledger:
		inst.campaign_ledger_override = _CP.start_mission_affinity_ledger()
	root.call_deferred("add_child", inst)
	await _frames(12)
	return inst

func _cleanup(inst: Node) -> void:
	paused = false
	inst.queue_free()
	await _frames(3)

func _report(state: String, reached: bool, detail: String) -> void:
	_states_done += 1
	print("STATE_RESULT [%s] %s %s" % [state, "REACHED" if reached else "UNREACHABLE", detail])

func _shot(inst: Node, state: String, tag: String, facts: String) -> void:
	await _frames(3)
	if not _headless:
		await RenderingServer.frame_post_draw
	var c: SubViewportContainer = inst.get_node("WorldViewportContainer")
	var v: SubViewport = inst.get_node("WorldViewportContainer/WorldViewport")
	print("HOST [%s] root.size=%s WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
		state, str(root.size), str(c.position), str(c.size), c.stretch_shrink, str(v.size)])
	print("FACTS [%s] %s" % [state, facts])
	var fname: String = "%02d_%dx%d_%s_%s.png" % [_shots, root.size.x, root.size.y, tag, state]
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

func _unit_summary(inst: Node) -> String:
	var ctl: Object = inst._controller
	var parts: PackedStringArray = []
	for u: Object in inst._state.units_of(0) + inst._state.units_of(1):
		parts.append("%s@%s move_used=%s atk_used=%s done=%s" % [u.code_name, str(inst._state.position_of(u.id)),
			str(ctl.unit_move_used(u.id)), str(ctl.unit_attack_used(u.id)), str(ctl.unit_is_done(u.id))])
	return " | ".join(parts)

func _run() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_WL = load("res://src/ui/battle/world_layout.gd")
	_BC = load("res://src/ui/battle/board_coords.gd")
	_CT = load("res://src/ui/cursor/cursor_target.gd")
	_CTYPES = load("res://src/ui/cursor/cursor_types.gd")
	_HL = load("res://src/ui/battle/hud_layout.gd")
	_CP = load("res://src/core/campaign/campaign_progress.gd")
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
		await _s046()
		await _s056()
		await _s051()
		await _s054()
		await _s052()
		await _s047()
		await _s053()
		await _s049_enemy()
		await _s049_player()
	print("TOTAL shots=%d states_done=%d" % [_shots, _states_done])
	paused = false
	quit()

## story-046:玩家回合開選單(真實 battle_menu 動作),列出可聚焦的五列文字。
func _s046() -> void:
	var inst: Node = await _make(R_VS01)
	await _action(&"battle_menu")
	var menu: Node = inst._battle_menu
	if not menu.is_open():
		print("S046 action did not open menu; fallback _handle_battle_menu_pressed()")
		inst._handle_battle_menu_pressed()
		await _frames(3)
	if not menu.is_open():
		_report("s046_menu_five_rows", false, "menu did not open")
		await _cleanup(inst)
		return
	var rows: PackedStringArray = []
	for r: Button in menu._focusable_rows:
		rows.append("'%s'(visible=%s,disabled=%s)" % [r.text, str(r.visible), str(r.disabled)])
	_report("s046_menu_five_rows", menu._focusable_rows.size() == 5, "rows=%d" % menu._focusable_rows.size())
	await _shot(inst, "menu_five_rows", "s046", "menu_open=%s paused=%s rows=%s egm_label='%s'" % [
		str(menu.is_open()), str(paused), " ; ".join(rows), str(menu._end_phase_reason_label.text)])
	menu.close()
	await _cleanup(inst)

## story-056:戰役模式(注入戰役 ledger)+ 真實 vs01,擊倒甲 -> 戰敗 -> 結果畫面「重打」文案。
func _s056() -> void:
	_CP.reset_for_test()
	var inst: Node = await _make(R_VS01, true, true)
	var ctl: Object = inst._controller
	var u1: Object = inst._state.unit_by_id(1)
	u1.take_damage(9999)
	ctl._check_outcome_and_finish()
	await _frames(20)
	var detail: String = inst._result_detail_label.text.replace("\n", " | ")
	var retry: bool = bool(inst._retry_same_mission)
	_report("s056_campaign_defeat_retry_text", ctl.outcome() != 0 and retry,
		"outcome=%d retry_same_mission=%s" % [ctl.outcome(), str(retry)])
	await _shot(inst, "campaign_defeat", "s056", "outcome=%d retry_same_mission=%s result_label='%s' detail='%s' campaign_ledger_set=%s" % [
		ctl.outcome(), str(retry), inst._result_label.text, detail, str(inst.campaign_ledger_override != null)])
	await _cleanup(inst)
	_CP.reset_for_test()

## story-051:真實 vs01,游標停在敵兵上,資訊卡顯示型別名。
func _s051() -> void:
	var inst: Node = await _make(R_VS01)
	# E1 (10,0) melee=裂殼;E3 (9,4) ranged=聽環;E4 (7,5) mid=垂鉤。
	var plan: Array = [[Vector2i(10, 0), "melee", true], [Vector2i(9, 4), "ranged", true], [Vector2i(7, 5), "mid", false]]
	var all_ok: bool = true
	for p: Array in plan:
		var cell: Vector2i = p[0]
		var ok: bool = await _move_cursor(inst, cell)
		var txt: String = inst._tile_info_panel_label.text.replace("\n", " | ")
		print("S051 cursor=%s kind=%s reached=%s info_visible=%s info='%s'" % [str(cell), p[1], str(ok), str(inst._tile_info_panel_bg.visible), txt])
		all_ok = all_ok and ok
		if p[2]:
			await _shot(inst, "cursor_on_enemy_" + p[1] + ("" if ok else "_CURSOR_FAILED"), "s051",
				"cursor_cell=%s info_visible=%s info_text='%s'" % [str(inst._cursor_cell), str(inst._tile_info_panel_bg.visible), txt])
	_report("s051_enemy_kind_names", all_ok, "3 cursor targets (see S051 lines for info text)")
	await _cleanup(inst)

## story-054:合成夾具(vs01 地形)。甲只移動(鞋)、乙只攻擊(劍)、丁被結束(變暗無圖示)、戊全新。
func _s054() -> void:
	var inst: Node = await _make(R_054)
	var ctl: Object = inst._controller
	var log_lines: PackedStringArray = []
	log_lines.append("select甲=" + str(ctl.click_tile(Vector2i(0, 2))))
	log_lines.append("move甲->(1,2)=" + str(ctl.click_tile(Vector2i(1, 2))))
	log_lines.append("select乙=" + str(ctl.click_tile(Vector2i(0, 3))))
	log_lines.append("attack乙->E1(2,3)=" + str(ctl.click_tile(Vector2i(2, 3))))
	log_lines.append("end丁=" + str(ctl.end_unit_turn(4)))
	ctl.deselect()
	inst._refresh_view()
	await _frames(3)
	var ok: bool = ctl.unit_move_used(1) and not ctl.unit_attack_used(1) and ctl.unit_attack_used(2) \
		and not ctl.unit_move_used(2) and ctl.unit_is_done(4) and not ctl.unit_move_used(4) and not ctl.unit_attack_used(4)
	_report("s054_shoe_sword_dim", ok, " ; ".join(log_lines))
	await _shot(inst, "shoe_sword_ended_fresh", "s054", "甲=鞋(已移動) 乙=劍(已攻擊) 丁=結束角色行動(變暗無圖示) 戊=全新 | " + _unit_summary(inst))
	await _cleanup(inst)

## story-052:先試真實 vs01(丙移動後再選取找被擋敵兵格);構不成則改用合成夾具另拍。
func _s052() -> void:
	var inst: Node = await _make(R_VS01)
	var ctl: Object = inst._controller
	var stamp_cells: Array[Vector2i] = []
	var blocked_all: Array[Vector2i] = []
	ctl.click_tile(Vector2i(1, 3))  # 選丙(vs01 起點)
	var mt: Variant = ctl.move_targets()
	var best: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in ctl.move_targets().cells if "cells" in mt else []:
		if c.x > best.x:
			best = c
	print("S052 vs01 丙 move target farthest-x candidate=%s" % str(best))
	if best.x >= 0:
		ctl.click_tile(best)
		ctl.click_tile(best)  # 若游標在原格則 no-op;下一行重選
		ctl.select_unit(3)
	blocked_all = ctl.attack_targets_blocked_by_los()
	stamp_cells = inst._filter_blocked_to_enemy_cells(blocked_all)
	inst._refresh_view()
	var real_ok: bool = stamp_cells.size() > 0 and ctl.selected_unit() == 3
	print("S052 vs01 丙@%s selected=%d blocked_all=%d blocked_on_enemy=%s" % [
		str(inst._state.position_of(3)), ctl.selected_unit(), blocked_all.size(), str(stamp_cells)])
	if real_ok:
		_report("s052_blocked_stamp_REAL_vs01", true, "stamp cells=%s (真實 vs01 資料;丙移動後再選取)" % str(stamp_cells))
		await _shot(inst, "blocked_stamp_real_vs01", "s052", "dataset=REAL_vs01 丙@%s blocked_all=%d stamp_on_enemy_cells=%s" % [
			str(inst._state.position_of(3)), blocked_all.size(), str(stamp_cells)])
		await _cleanup(inst)
		return
	_report("s052_blocked_stamp_REAL_vs01", false, "vs01 無法構成(丙移動後重選仍無被擋敵兵格)")
	await _cleanup(inst)
	# 合成夾具另拍(與上方真實 vs01 分開標示)
	inst = await _make(R_052)
	ctl = inst._controller
	await _click(_cell_pos(Vector2i(4, 3)))
	blocked_all = ctl.attack_targets_blocked_by_los()
	stamp_cells = inst._filter_blocked_to_enemy_cells(blocked_all)
	_report("s052_blocked_stamp_SYNTHETIC_fixture", stamp_cells.size() > 0 and ctl.selected_unit() == 3,
		"stamp cells=%s (合成夾具 fixture_roster_052,非真實 vs01)" % str(stamp_cells))
	await _shot(inst, "blocked_stamp_SYNTHETIC", "s052", "dataset=SYNTHETIC_fixture_052 selected=%d blocked_all=%d stamp_on_enemy_cells=%s" % [
		ctl.selected_unit(), blocked_all.size(), str(stamp_cells)])
	await _cleanup(inst)

## story-047:圖例(L 鍵動作;不行則呼叫 open_legend)。
func _s047() -> void:
	var inst: Node = await _make(R_VS01)
	await _action(&"battle_open_legend")
	var via: String = "battle_open_legend action"
	if not inst.is_legend_open():
		inst.open_legend()
		await _frames(3)
		via = "open_legend() fallback"
	if not inst.is_legend_open():
		_report("s047_legend", false, "legend did not open")
		await _cleanup(inst)
		return
	_report("s047_legend", true, "opened via " + via)
	await _shot(inst, "legend_open", "s047", "legend_open=%s via=%s content_rect=%s" % [
		str(inst.is_legend_open()), via, str(inst.legend_panel().content_rect())])
	inst.close_legend()
	await _cleanup(inst)

func _end_btn_facts(inst: Node, cell: Vector2i) -> String:
	var b: Button = inst._end_action_button
	var al: Dictionary = inst.diagnostic_frame_alphas()
	return "cursor_cell=%s cursor_active=%s selected=%d end_btn: text='%s' disabled=%s modulate.a=%.3f tooltip='%s' frame_alphas=%s" % [
		str(inst._cursor_cell), str(inst._cursor_active), inst._controller.selected_unit(),
		b.text, str(b.disabled), b.modulate.a, b.tooltip_text, str(al)]

## story-053:結束角色行動按鈕 禁用 + 真實高亮壓到提示列框造成的變淡;啟用 + 變淡。
func _s053() -> void:
	var inst: Node = await _make(R_VS01)
	var win: Vector2i = root.size
	var bg: Rect2 = _HL.controls_hint_bg_rect(win)
	var cell: Vector2i = Vector2i(-1, -1)
	for y: int in range(_BC.BOARD_ROWS - 1, -1, -1):
		for x: int in range(_BC.BOARD_COLS):
			var c: Vector2i = Vector2i(x, y)
			if cell.x < 0 and _HL.frame_alpha_for_cell(true, _HL.cell_window_rect(c, win), bg) < 1.0:
				cell = c
	print("S053 hint_bg_rect=%s first overlapping cell=%s" % [str(bg), str(cell)])
	if cell.x < 0:
		_report("s053_end_button_disabled_and_enabled_faded", false, "此尺寸找不到與提示列框重疊的格子")
		await _cleanup(inst)
		return
	# (1) 無選取 -> 禁用;游標停在重疊格 -> 真實高亮壓框變淡。
	var ok1: bool = await _move_cursor(inst, cell)
	await _frames(3)
	var b: Button = inst._end_action_button
	var dis_faded: bool = b.disabled and b.modulate.a < 1.0
	_report("s053_disabled_plus_real_highlight_fade", ok1 and dis_faded,
		"disabled=%s modulate.a=%.3f cursor_reached=%s overlap_cell=%s" % [str(b.disabled), b.modulate.a, str(ok1), str(cell)])
	await _shot(inst, "end_btn_disabled_faded_by_real_highlight", "s053", _end_btn_facts(inst, cell))
	# (2) 選甲 -> 啟用;游標再停回重疊格 -> 啟用 + 變淡。
	await _click(_cell_pos(Vector2i(0, 2)))
	var ok2: bool = await _move_cursor(inst, cell)
	await _frames(3)
	var en_faded: bool = (not b.disabled) and b.modulate.a < 1.0
	_report("s053_enabled_plus_real_highlight_fade", ok2 and en_faded,
		"disabled=%s modulate.a=%.3f selected=%d cursor_reached=%s" % [str(b.disabled), b.modulate.a, inst._controller.selected_unit(), str(ok2)])
	await _shot(inst, "end_btn_enabled_faded_by_real_highlight", "s053", _end_btn_facts(inst, cell))
	await _cleanup(inst)

func _banner_facts(inst: Node) -> String:
	var n: Control = inst.phase_banner_node()
	return "phase=%d should_show=%s kind=%d (1=ENEMY 2=PLAYER) banner_elapsed=%.3f banner_rect=%s banner_modulate_a=%.3f status_label_font_color_override=%s status_text='%s' has_pending_discard=%s" % [
		inst._controller.phase(), str(inst.phase_banner_should_show()), int(inst.phase_banner_kind()),
		float(inst._phase_banner_elapsed), str(n.get_global_rect()), n.modulate.a,
		str(inst._status_label.get_theme_color(&"font_color")), inst._status_label.text,
		str(inst._controller.has_pending_discard())]

## 等橫幅計時過淡入(>=0.2s,淡入 0.15s)且仍在停留期(<1.0s);回傳是否仍可見。
func _wait_banner_hold(inst: Node, want_kind: int) -> bool:
	for i: int in range(240):
		if inst.phase_banner_should_show() and float(inst._phase_banner_elapsed) >= 0.2:
			break
		await process_frame
	return inst.phase_banner_should_show() and int(inst.phase_banner_kind()) == want_kind \
		and float(inst._phase_banner_elapsed) < 1.0

## story-049:敵方回合橫幅(end_faction_phase 後,淡入完成、停留期內拍)。
func _s049_enemy() -> void:
	var inst: Node = await _make(R_VS01)
	inst._controller.end_faction_phase()
	var ok: bool = await _wait_banner_hold(inst, 1)
	if not ok:
		_report("s049_enemy_banner", false, "錯過橫幅或種類不符 | " + _banner_facts(inst))
		await _cleanup(inst)
		return
	_report("s049_enemy_banner", true, _banner_facts(inst))
	await _shot(inst, "enemy_banner", "s049", _banner_facts(inst))
	await _cleanup(inst)

## story-049:我方回合橫幅(同步反覆 step_enemy_phase 直到回 PLAYER_INPUT,不在步間等幀)。
func _s049_player() -> void:
	var inst: Node = await _make(R_VS01)
	var ctl: Object = inst._controller
	ctl.end_faction_phase()
	var n: int = 0
	while ctl.phase() == 1 and n < 200:
		ctl.step_enemy_phase()
		n += 1
	print("S049 player: steps=%d phase_after=%d outcome=%d" % [n, ctl.phase(), ctl.outcome()])
	inst._refresh_view()
	var ok: bool = await _wait_banner_hold(inst, 2)
	if not ok:
		_report("s049_player_banner", false, "錯過橫幅或種類不符 | " + _banner_facts(inst))
		await _cleanup(inst)
		return
	_report("s049_player_banner", true, _banner_facts(inst))
	await _shot(inst, "player_banner", "s049", _banner_facts(inst))
	await _cleanup(inst)
