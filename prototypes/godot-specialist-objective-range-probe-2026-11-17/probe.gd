extends SceneTree
## 探針:目標框 Timer / paused / 敵方回合範圍格。headless。
## 順序:load 真實 BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等幀。
const SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const L_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const R_VS01: String = "res://assets/data/units/vs01_roster.txt"
const L_AFF: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const L_CARDS: String = "res://assets/data/cards/vs01_cards.txt"
const L_CARDTXT: String = "res://assets/data/cards/vs01_card_text.txt"

func _initialize() -> void:
	create_timer(120.0, true).timeout.connect(func() -> void:
		print("WATCHDOG"); paused = false; quit(2))
	_run()

func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame

func _wait_real(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

func _make() -> Node:
	var inst: Node = (load(SCENE) as PackedScene).instantiate()
	inst.terrain_path_override = L_TERRAIN
	inst.roster_path_override = R_VS01
	inst.affinity_path_override = L_AFF
	inst.cards_path_override = L_CARDS
	inst.card_text_path_override = L_CARDTXT
	root.call_deferred("add_child", inst)
	await _frames(3)
	return inst

func _layers(inst: Node) -> String:
	var bv: Node = inst._board_view
	return "move=%d attack=%d threat=%d unreach=%d los=%d" % [
		bv._move_highlight_layer.get_child_count(), bv._attack_highlight_layer.get_child_count(),
		bv._threat_highlight_layer.get_child_count(), bv._move_unreachable_layer.get_child_count(),
		bv._attack_los_blocked_layer.get_child_count()]

func _obj(inst: Node, tag: String) -> void:
	var t: Timer = inst.get_node_or_null("ObjectiveTimer") as Timer
	print("OBJ [%s] visible=%s timer.time_left=%.2f timer.can_process=%s tree.paused=%s screen.process_mode=%d timer.process_mode=%d" % [
		tag, str(inst.is_objective_visible()), (t.time_left if t else -1.0),
		str(t.can_process() if t else false), str(paused), inst.process_mode, (t.process_mode if t else -1)])

func _cleanup(inst: Node) -> void:
	paused = false
	inst.queue_free()
	await _frames(3)

func _run() -> void:
	print("DISPLAY_SERVER=", DisplayServer.get_name())
	# ---------- Q2:選單開著時 Timer 是否走 ----------
	var a: Node = await _make()
	print("HOST WVC position=%s size=%s stretch_shrink=%d WorldViewport.size=%s" % [
		str(a.get_node("WorldViewportContainer").position), str(a.get_node("WorldViewportContainer").size),
		a.get_node("WorldViewportContainer").stretch_shrink, str(a.get_node("WorldViewportContainer/WorldViewport").size)])
	_obj(a, "Q2 t=0 after load (menu not yet opened)")
	a._handle_battle_menu_pressed()
	await _frames(3)
	print("Q2 menu_open=%s paused=%s" % [str(a._battle_menu.is_open()), str(paused)])
	_obj(a, "Q2 menu opened")
	var t0: float = a.get_node("ObjectiveTimer").time_left
	await _wait_real(10.0)
	_obj(a, "Q2 after 10.0s REAL wall time with menu open")
	print("Q2 timer.time_left delta over 10s paused = %.3f (0 = Timer frozen)" % (t0 - a.get_node("ObjectiveTimer").time_left))
	a._battle_menu.close()
	await _frames(3)
	_obj(a, "Q2 menu closed")
	await _wait_real(8.5)
	_obj(a, "Q2 8.5s after close (unpaused)")
	await _cleanup(a)

	# ---------- Q1:無暫停時 8 秒自動關;確認鍵關;敵方回合/換手後 ----------
	var b: Node = await _make()
	_obj(b, "Q1 fresh")
	await _wait_real(8.5)
	_obj(b, "Q1 8.5s real, no input")
	await _cleanup(b)
	var c: Node = await _make()
	var ctl: Object = c._controller
	ctl.end_faction_phase()
	var n: int = 0
	var t_start: int = Time.get_ticks_msec()
	while ctl.phase() == 1 and n < 400:
		ctl.step_enemy_phase()
		n += 1
	print("Q1 sync enemy phase steps=%d phase_after=%d took_ms=%d (driver-style: zero real time)" % [n, ctl.phase(), Time.get_ticks_msec() - t_start])
	c._refresh_view()
	await _frames(3)
	_obj(c, "Q1 right after enemy phase + back to player (driver-style, ~0s real)")
	await _cleanup(c)

	# ---------- Q3:選取/範圍格在敵方回合是否清除 ----------
	var d: Node = await _make()
	var dc: Object = d._controller
	print("Q3 fresh: selected=%d layers: %s" % [dc.selected_unit(), _layers(d)])
	print("Q3 select 甲 click_tile(0,2)=%s selected=%d" % [str(dc.click_tile(Vector2i(0, 2))), dc.selected_unit()])
	d._refresh_view()
	await _frames(2)
	print("Q3 after select, before end phase: selected=%d layers: %s" % [dc.selected_unit(), _layers(d)])
	dc.end_faction_phase()
	print("Q3 right after end_faction_phase (before any frame): selected=%d phase=%d layers: %s" % [dc.selected_unit(), dc.phase(), _layers(d)])
	await _frames(4)
	print("Q3 enemy phase after 4 frames: selected=%d phase=%d layers: %s" % [dc.selected_unit(), dc.phase(), _layers(d)])
	var k: int = 0
	while dc.phase() == 1 and k < 400:
		dc.step_enemy_phase()
		k += 1
		if k == 2:
			d._refresh_view()
			print("Q3 mid enemy phase step2: selected=%d layers: %s" % [dc.selected_unit(), _layers(d)])
	d._refresh_view()
	await _frames(3)
	print("Q3 back to PLAYER: phase=%d selected=%d layers: %s" % [dc.phase(), dc.selected_unit(), _layers(d)])
	await _cleanup(d)
	# 07 號圖情境:全新實例 -> 立刻 end_faction_phase -> 等橫幅
	var e: Node = await _make()
	var ec: Object = e._controller
	ec.end_faction_phase()
	await _wait_real(0.4)
	print("Q3 scenario-07 (fresh, end phase, 0.4s): selected=%d phase=%d layers: %s" % [ec.selected_unit(), ec.phase(), _layers(e)])
	await _cleanup(e)
	print("PROBE DONE")
	quit(0)
