## relation-minimap story-001 -- 關係圖開關與繪製,真實 BattleScreen.tscn。
##
## 🔴 檔案 I/O 例外聲明(test-standards 2026-09-16 裁決):AC-13 一條【乙類】測試唯讀
##   relation_minimap.gd 的原始碼文字,斷言它不呼叫好感度層(單一來源/無狀態)。
##   為什麼不能注入:斷言對象就是原始碼寫法。🔴 自陳:掃描不等於窮盡(反射/.tscn 不在視野)。
##
## 🔴 敏感度證明對照:
##   - 單一來源(AC-3/4):常駐變種 _MutantEmptyLines + test_sensitivity_proof_*。
##   - 其餘:開關、版面 rect(static 純函式,類別 A)、符號表(static,類別 A)、
##     在地化鍵存在(真實資料檔,類別 A′)—— 【證明不了】。
##   - 🔴 未驗證:畫面實際外觀、字型是否含字、版面遮擋 —— 只做 headless,需人眼看。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _MINIMAP_SRC: String = "res://src/ui/battle/relation_minimap.gd"
const _WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(3440, 1440), Vector2i(3840, 2160),
]

var _host_snap: CursorHostSnapshot = null


## 缺陷:地圖收到空線集合(沒吃棋盤同一份資料)。
class _MutantEmptyLines extends BattleScreen:
	func _update_relation_minimap(_s: Array[AffinityLineStatus], positions: Dictionary[int, Vector2i]) -> void:
		var none: Array[AffinityLineStatus] = []
		super(none, positions)


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _instance(mutant: Script = null) -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	if mutant != null:
		instance.set_script(mutant)
	add_child(instance)
	return instance


func _key(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var k: InputEventKey = (event as InputEventKey).duplicate()
			k.pressed = true
			return k
	return null


func _pad(action: StringName) -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var b: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			b.pressed = true
			return b
	return null


func _line_set(lines: Array) -> Array[String]:
	var out: Array[String] = []
	for l: Dictionary in lines:
		out.append("%d-%d-%d" % [l["a"], l["b"], l["state"]])
	out.sort()
	return out


func _expected_set(statuses: Array[AffinityLineStatus]) -> Array[String]:
	var out: Array[String] = []
	for s: AffinityLineStatus in statuses:
		out.append("%d-%d-%d" % [s.unit_id, s.partner_id, s.state])
	out.sort()
	return out


# ---- 開關 ---------------------------------------------------------------------

func test_default_closed_panel_not_visible() -> void:
	var instance: BattleScreen = _instance()
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_false()


func test_action_registered_with_key_r_and_pad_button_8() -> void:
	assert_bool(InputMap.has_action(&"battle_toggle_relation_map")).is_true()
	assert_int(_key(&"battle_toggle_relation_map").keycode).is_equal(KEY_R)
	assert_int(_pad(&"battle_toggle_relation_map").button_index).is_equal(8)


func test_keyboard_toggle_opens_then_closes() -> void:
	var instance: BattleScreen = _instance()
	instance._input(_key(&"battle_toggle_relation_map"))
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_true()
	instance._input(_key(&"battle_toggle_relation_map"))
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_false()


func test_gamepad_toggle_opens() -> void:
	var instance: BattleScreen = _instance()
	instance._input(_pad(&"battle_toggle_relation_map"))
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_true()


func test_key_echo_is_ignored() -> void:
	var instance: BattleScreen = _instance()
	var e: InputEventKey = _key(&"battle_toggle_relation_map")
	e.echo = true
	instance._input(e)
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_false()


func test_cannot_open_while_card_hand_open() -> void:
	var instance: BattleScreen = _instance()
	instance._input(_key(&"battle_open_hand"))
	if not instance._controller.is_card_play_in_progress():
		return  # 此關卡開不了手牌時,本條不適用(不當成通過證據)
	instance._input(_key(&"battle_toggle_relation_map"))
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_false()


func test_open_map_does_not_block_board_input() -> void:
	var instance: BattleScreen = _instance()
	instance._input(_key(&"battle_toggle_relation_map"))
	var before: Vector2i = instance._cursor_cell
	var moved: bool = false
	for action: StringName in [&"ui_right", &"ui_down", &"ui_left", &"ui_up"]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = true
		instance._input(ev)
	# 方向由 _handle_directional 讀專案動作;改直接驗確認鍵仍會走到棋盤路徑而不被吞。
	instance._input(_key(&"battle_confirm"))
	moved = instance._cursor_cell != before or instance._controller.selected_unit() != -1 or instance._cursor_active
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_true()
	assert_bool(moved).append_failure_message("開著地圖時確認/移動輸入應仍作用於棋盤").is_true()


# ---- 單一來源 -----------------------------------------------------------------

func test_map_lines_equal_board_lines_idle() -> void:
	var instance: BattleScreen = _instance()
	instance._input(_key(&"battle_toggle_relation_map"))
	instance._refresh_view()
	var expected: Array[AffinityLineStatus] = AffinityRules.board_lines(instance._phi.positions(), instance._phi.links())
	assert_array(expected).is_not_empty()
	assert_array(_line_set(instance.diagnostic_relation_minimap_lines())).is_equal(_expected_set(expected))
	var board_children: int = instance._board_view._affinity_line_layer.get_child_count()
	assert_int(board_children).is_equal(expected.size() * 2)


func test_map_lines_equal_board_lines_under_move_preview() -> void:
	var instance: BattleScreen = _instance()
	instance._input(_key(&"battle_toggle_relation_map"))
	for unit: Unit in instance._state.units_of(Unit.Faction.PLAYER):
		if not instance._controller.select_unit(unit.id):
			continue
		for cell: Vector2i in instance._controller.move_targets().cells:
			if cell == instance._state.position_of(unit.id):
				continue
			instance._cursor_cell = cell
			instance._cursor_active = true
			instance._refresh_view()
			var hypo: Dictionary[int, Vector2i] = instance._phi.positions_with(unit.id, cell)
			var expected: Array[AffinityLineStatus] = AffinityRules.board_lines(hypo, instance._phi.links())
			assert_array(_line_set(instance.diagnostic_relation_minimap_lines())).is_equal(_expected_set(expected))
			return
		instance._controller.deselect()
	fail("找不到可預覽的移動格")


func test_sensitivity_proof_empty_feed_is_detected() -> void:
	var instance: BattleScreen = _instance(_MutantEmptyLines)
	instance._input(_key(&"battle_toggle_relation_map"))
	instance._refresh_view()
	var expected: Array[AffinityLineStatus] = AffinityRules.board_lines(instance._phi.positions(), instance._phi.links())
	assert_array(_line_set(instance.diagnostic_relation_minimap_lines())).is_not_equal(_expected_set(expected))


func test_ac13_minimap_source_never_touches_affinity_layer() -> void:
	var code: String = ""
	for line: String in FileAccess.get_file_as_string(_MINIMAP_SRC).split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	for banned: String in ["AffinityRules.", "AffinityPhiProvider", "AffinityDataPool", ".links()"]:
		assert_bool(code.contains(banned)).append_failure_message(banned).is_false()


# ---- 非色彩 / 在地化 / 版面 ------------------------------------------------------

func test_symbols_differ_per_state_not_colour_only() -> void:
	var p: String = RelationMinimap.symbol_for(AffinityLineStatus.State.POSITIVE)
	var n: String = RelationMinimap.symbol_for(AffinityLineStatus.State.NEGATIVE)
	var z: String = RelationMinimap.symbol_for(AffinityLineStatus.State.NEUTRAL)
	assert_bool(p != n and n != z and p != z).is_true()


func test_localization_keys_resolve() -> void:
	for key: StringName in [&"battle.hud.relation_map_title", &"battle.hud.relation_map_dead",
			&"battle.hud.relation_map_toggle", &"character.name.1", &"character.name.5"]:
		assert_bool(Loc.is_missing(key, String(TranslationServer.translate(key)))).append_failure_message(String(key)).is_false()


func test_panel_rect_does_not_overlap_other_hud_rects() -> void:
	for size: Vector2i in _WINDOW_SIZES:
		var panel: Rect2 = HudLayout.relation_minimap_rect(size)
		var win: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
		assert_bool(win.encloses(panel)).append_failure_message("outside window %s" % size).is_true()
		var others: Array[Rect2] = [
			HudLayout.status_label_rect(size), HudLayout.info_label_rect(size),
			HudLayout.consistency_counter_rect(size), HudLayout.controls_hint_bg_rect(size),
			HudLayout.relation_minimap_toggle_rect(size), HandBar.slot_bar_rect(size, 5),
		]
		for o: Rect2 in others:
			assert_bool(panel.intersects(o)).append_failure_message("overlap %s %s" % [size, o]).is_false()


func test_layout_applied_to_nodes() -> void:
	var instance: BattleScreen = _instance()
	var size: Vector2i = instance.get_window().size
	var panel: Control = instance.get_node("UILayer/RelationMinimap")
	assert_vector(panel.position).is_equal(HudLayout.relation_minimap_rect(size).position)
