extends GdUnitTestSuite

# battle-hud story-004 AC1(指到才變淡)/ AC2(一鍵隱藏)的接線測試,載入真實 BattleScreen.tscn。
# 檔案存取:無(不屬甲/乙類例外)。
# 敏感度:兩個常駐突變子類別(進樹前 set_script,Case A 安全時機,且之後才指派任何屬性):
#   _MutantNoFade 讓變淡更新什麼都不做;_MutantNoToggle 讓隱藏切換什麼都不做。
#   各有一條 test_sensitivity_proof_* 斷言「同一組斷言在突變版上會抓到缺陷」。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


class _MutantNoFade extends BattleScreen:
	func _update_hud_overlap_fade() -> void:
		pass


class _MutantNoToggle extends BattleScreen:
	func _toggle_hud_hidden() -> void:
		pass


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false


func _instance(script: Script = null) -> BattleScreen:
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		inst.set_script(script)
	auto_free(inst)
	add_child(inst)
	return inst


## 找一格:與左上關係圖按鈕框重疊(want_overlap=true)或不重疊(false)。用的是真實矩形函式。
func _find_cell(window_size: Vector2i, want_overlap: bool) -> Vector2i:
	var counter: Rect2 = HudLayout.relation_minimap_toggle_rect(window_size)
	for y: int in range(BoardCoords.BOARD_ROWS):
		for x: int in range(BoardCoords.BOARD_COLS):
			var cell: Vector2i = Vector2i(x, y)
			if HudLayout.cell_overlaps_frame(HudLayout.cell_window_rect(cell, window_size), counter) == want_overlap:
				return cell
	return Vector2i(-1, -1)


func _press_toggle(inst: BattleScreen) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"battle_toggle_hud"
	ev.pressed = true
	inst._input(ev)


# ---- AC1 ---------------------------------------------------------------------------

func _run_fade_scenario(inst: BattleScreen) -> Dictionary:
	var size: Vector2i = inst.get_window().size
	var over: Vector2i = _find_cell(size, true)
	var apart: Vector2i = _find_cell(size, false)
	inst._cursor_active = true
	inst._cursor_cell = over
	inst._update_hud_overlap_fade()
	var faded: float = inst.diagnostic_frame_alphas()["toggle"]
	inst._cursor_cell = apart
	inst._update_hud_overlap_fade()
	var restored: float = inst.diagnostic_frame_alphas()["toggle"]
	return {"over": over, "apart": apart, "faded": faded, "restored": restored}


func test_frame_fades_when_highlight_cell_overlaps_and_restores_after_leaving() -> void:
	var inst: BattleScreen = _instance()
	var r: Dictionary = _run_fade_scenario(inst)
	assert_bool(r["over"] != Vector2i(-1, -1) and r["apart"] != Vector2i(-1, -1)).append_failure_message(
		"PRECONDITION: 找得到重疊與不重疊的格子").is_true()
	assert_float(r["faded"]).is_equal_approx(HudLayout.OVERLAP_FADE_ALPHA, 0.001)
	assert_float(r["restored"]).is_equal(1.0)


func test_no_highlight_means_every_frame_opaque() -> void:
	var inst: BattleScreen = _instance()
	inst._cursor_active = false
	inst._update_hud_overlap_fade()
	for key: String in inst.diagnostic_frame_alphas():
		assert_float(inst.diagnostic_frame_alphas()[key]).append_failure_message(key).is_equal(1.0)


func test_sensitivity_proof_no_fade_mutant_is_caught_by_fade_scenario() -> void:
	var inst: BattleScreen = _instance(_MutantNoFade)
	var r: Dictionary = _run_fade_scenario(inst)
	assert_float(r["faded"]).append_failure_message("突變版不應變淡").is_not_equal(HudLayout.OVERLAP_FADE_ALPHA)


# ---- AC2 ---------------------------------------------------------------------------

func test_toggle_action_hides_and_restores_whole_ui_layer() -> void:
	var inst: BattleScreen = _instance()
	_press_toggle(inst)
	assert_bool(inst.diagnostic_hud_hidden()).is_true()
	assert_bool(inst.get_node("UILayer").visible).is_false()
	_press_toggle(inst)
	assert_bool(inst.diagnostic_hud_hidden()).is_false()
	assert_bool(inst.get_node("UILayer").visible).is_true()


func test_cursor_still_updates_while_hud_hidden() -> void:
	var inst: BattleScreen = _instance()
	_press_toggle(inst)
	inst._update_cursor_visual()
	assert_bool(inst._board_view._cursor_sprite.visible).is_true()


func test_opening_hand_or_menu_restores_hidden_hud() -> void:
	var inst: BattleScreen = _instance()
	_press_toggle(inst)
	assert_bool(inst.diagnostic_hud_hidden()).append_failure_message("PRECONDITION").is_true()
	inst._handle_open_hand_pressed()
	assert_bool(inst.diagnostic_hud_hidden()).append_failure_message("開手牌應恢復").is_false()
	inst._handle_open_hand_pressed()  # 關手牌,回到可再隱藏的狀態
	_press_toggle(inst)
	assert_bool(inst.diagnostic_hud_hidden()).append_failure_message("PRECONDITION 2").is_true()
	inst._handle_battle_menu_pressed()
	assert_bool(inst.diagnostic_hud_hidden()).append_failure_message("開選單應恢復").is_false()


func test_hidden_buttons_do_not_swallow_board_clicks() -> void:
	var inst: BattleScreen = _instance()
	var center: Vector2 = inst._relation_toggle_button.get_global_rect().get_center()
	assert_bool(inst._mouse_over_relation_toggle(center)).append_failure_message("PRECONDITION").is_true()
	_press_toggle(inst)
	assert_bool(inst._mouse_over_relation_toggle(center)).is_false()


func test_toggle_action_is_registered_with_keyboard_and_gamepad_events() -> void:
	assert_bool(InputMap.has_action(&"battle_toggle_hud")).is_true()
	var has_key: bool = false
	var has_pad: bool = false
	for e: InputEvent in InputMap.action_get_events(&"battle_toggle_hud"):
		has_key = has_key or e is InputEventKey
		has_pad = has_pad or e is InputEventJoypadButton
	assert_bool(has_key and has_pad).is_true()


func test_sensitivity_proof_no_toggle_mutant_is_caught_by_toggle_scenario() -> void:
	var inst: BattleScreen = _instance(_MutantNoToggle)
	_press_toggle(inst)
	assert_bool(inst.diagnostic_hud_hidden()).append_failure_message("突變版不應隱藏").is_false()
