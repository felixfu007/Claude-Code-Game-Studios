## legend_panel_test.gd
##
## story-047 圖例面板:AC1 完整性、AC2 圖示同源、AC3 叫出/關閉/輸入攔截、AC4 在地化與版面。
##
## 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BattleScreen.tscn,
## 經 terrain/roster_path_override 唯讀餵入 assets/data/ 下已進版控的夾具
## (test_fixture_terrain_duel.txt、test_fixture_roster_duel.txt)。不寫入任何檔案。
## 揭露:不證明窮盡性;不驗像素(AC6 另案);【未驗證】實體手把左扳機的手感與單次觸發,
## 只用合成的 InputEventJoypadMotion 驗證閂鎖邏輯。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const _WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540), Vector2i(1366, 768), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160),
]

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


func after_test() -> void:
	get_tree().paused = false
	_host_snap.restore()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


func _load() -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH
	auto_free(instance)
	add_child(instance)
	return instance


func _key(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var k: InputEventKey = (event as InputEventKey).duplicate()
			k.pressed = true
			return k
	return null


func _pad_button(action: StringName) -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var b: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			b.pressed = true
			return b
	return null


func _trigger(value: float) -> InputEventJoypadMotion:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = JOY_AXIS_TRIGGER_LEFT
	ev.axis_value = value
	return ev


func _action(action: StringName) -> InputEventAction:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _click(pos: Vector2, button: MouseButton) -> InputEventMouseButton:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = pos
	return ev


## 節點的可比較簽章:類別 + 會影響畫面的屬性(顏色/大小/位置/點/貼圖身分/調色)。
func _signature(node: Node) -> Array:
	var out: Array = []
	var entry: Array = [node.get_class()]
	if node is ColorRect:
		entry.append_array([(node as ColorRect).color, (node as ColorRect).size, (node as ColorRect).position])
	if node is Line2D:
		var l: Line2D = node as Line2D
		entry.append_array([l.default_color, l.width, l.points])
	if node is Sprite2D:
		var s: Sprite2D = node as Sprite2D
		entry.append_array([s.modulate, s.position, s.texture.get_size(), s.texture.get_rid() if false else s.texture.get_width()])
	if node is Node2D:
		entry.append((node as Node2D).position)
	out.append(entry)
	for child: Node in node.get_children():
		out.append_array(_signature(child))
	return out


func _child_signature(root: Node) -> Array:
	var out: Array = []
	for child: Node in root.get_children():
		out.append_array(_signature(child))
	return out


# ---- AC1 完整性 ------------------------------------------------------------------

func test_ac1_legend_entries_equal_boardview_marker_kinds() -> void:
	var oracle: Array[int] = BoardView.legend_marker_kinds()
	var shown: Array[int] = LegendPanel.entry_kinds()
	assert_int(oracle.size()).is_greater(0)
	var a: Array[int] = oracle.duplicate()
	var b: Array[int] = shown.duplicate()
	a.sort()
	b.sort()
	assert_array(b).is_equal(a)
	assert_int(shown.size()).is_equal(oracle.size())  # 無重複


func test_ac1_excluded_kinds_are_exactly_the_two_ruled_out_terrain_markers() -> void:
	# 管理者 2026-11-16 裁決:地形擋/不可通行現在不列。排除集必須恰好是這兩項,
	# 且圖例清單 = MarkerKind 全集 − 排除集(其餘全部要在圖例裡)。
	var excluded: Array[int] = BoardView.LEGEND_EXCLUDED_KINDS.duplicate()
	excluded.sort()
	var expected: Array[int] = [
		BoardView.MarkerKind.MOVE_BLOCKED_TERRAIN, BoardView.MarkerKind.IMPASSABLE_TERRAIN]
	expected.sort()
	assert_array(excluded).is_equal(expected)
	var all_kinds: Array[int] = []
	for v: int in BoardView.MarkerKind.values():
		all_kinds.append(v)
	var shown: Array[int] = LegendPanel.entry_kinds()
	for kind: int in all_kinds:
		assert_bool(shown.has(kind) != excluded.has(kind)).append_failure_message(
			"kind %d 必須恰在『圖例』與『排除集』其中之一" % kind).is_true()


func test_ac1_every_entry_has_icon_name_and_sentence() -> void:
	var instance: BattleScreen = _load()
	var panel: LegendPanel = instance.legend_panel()
	assert_object(panel).is_not_null()
	for entry: Dictionary in LegendPanel.ENTRIES:
		var kind: int = entry["kind"]
		var key: String = entry["key"]
		assert_object(panel.icon_for(kind)).is_not_null()
		var nm: String = Loc.localize(StringName(key + ".name"))
		var ds: String = Loc.localize(StringName(key + ".desc"))
		assert_str(nm).is_not_equal(key + ".name")
		assert_str(ds).is_not_equal(key + ".desc")
		assert_bool(nm.length() > 0 and nm.length() <= 4).is_true()
		assert_bool(ds.length() > 0 and ds.length() <= 14).is_true()
		assert_str(panel.name_label_for(kind).text).is_equal(nm)
		assert_str(panel.desc_label_for(kind).text).is_equal(ds)


func test_ac1_includes_action_icons_shoe_sword_and_dimmed_piece() -> void:
	var kinds: Array[int] = LegendPanel.entry_kinds()
	assert_bool(kinds.has(BoardView.MarkerKind.ACTION_MOVED)).is_true()
	assert_bool(kinds.has(BoardView.MarkerKind.ACTION_ATTACKED)).is_true()
	assert_bool(kinds.has(BoardView.MarkerKind.UNIT_DONE)).is_true()
	# 範例裡真的用到棋盤同一份貼圖/變暗常數(預言機:BoardView 自己的函式與常數)。
	var moved: Node2D = BoardView.build_legend_sample(BoardView.MarkerKind.ACTION_MOVED)
	var attacked: Node2D = BoardView.build_legend_sample(BoardView.MarkerKind.ACTION_ATTACKED)
	var done: Node2D = BoardView.build_legend_sample(BoardView.MarkerKind.UNIT_DONE)
	auto_free(moved)
	auto_free(attacked)
	auto_free(done)
	assert_object(moved.find_child("ShoeIcon", true, false)).is_not_null()
	assert_object(attacked.find_child("SwordIcon", true, false)).is_not_null()
	assert_object(moved.find_child("SwordIcon", true, false)).is_null()
	assert_object((moved.find_child("ShoeIcon", true, false) as Sprite2D).texture).is_same(BoardView.shoe_texture())
	var dim: bool = false
	for child: Node in done.get_children():
		if child is Sprite2D and is_equal_approx((child as Sprite2D).modulate.r, BoardView.DONE_PIECE_DIM):
			dim = true
	assert_bool(dim).is_true()


# ---- AC2 圖示同源 ----------------------------------------------------------------

func test_ac2_icons_equal_boardview_builder_output() -> void:
	var instance: BattleScreen = _load()
	var panel: LegendPanel = instance.legend_panel()
	panel.open(Vector2i(960, 540))
	for kind: int in BoardView.legend_marker_kinds():
		var fresh: Node2D = BoardView.build_legend_sample(kind)
		auto_free(fresh)
		var shown: Array = _child_signature(panel.icon_for(kind))
		var expected: Array = _child_signature(fresh)
		assert_array(shown).is_equal(expected)
		assert_int(shown.size()).is_greater(1)  # 防空洞:底磚 + 至少一個標記


func test_ac2_attack_icon_color_is_boardview_constant_and_scale_is_integer() -> void:
	var instance: BattleScreen = _load()
	var panel: LegendPanel = instance.legend_panel()
	for size: Vector2i in _WINDOW_SIZES:
		panel.open(size)
		var root: Node2D = panel.icon_for(BoardView.MarkerKind.ATTACK_RANGE)
		var found: bool = false
		for rect: Node in root.find_children("*", "ColorRect", true, false):
			if (rect as ColorRect).color == BoardView.ATTACK_RING_COLOR:
				found = true
		assert_bool(found).is_true()
		assert_float(root.scale.x).is_equal(float(LegendPanel.icon_scale_for(size)))
		assert_float(root.scale.x).is_equal(floorf(root.scale.x))
		panel.close()


# ---- AC3 叫出方式與輸入攔截 -----------------------------------------------------

func test_ac3_dedicated_key_opens_and_closes() -> void:
	var instance: BattleScreen = _load()
	assert_bool(instance.is_legend_open()).is_false()
	instance._input(_key(&"battle_open_legend"))
	assert_bool(instance.is_legend_open()).is_true()
	instance._input(_key(&"battle_open_legend"))
	assert_bool(instance.is_legend_open()).is_false()


func test_ac3_key_echo_does_not_toggle() -> void:
	var instance: BattleScreen = _load()
	instance._input(_key(&"battle_open_legend"))
	var echo: InputEventKey = _key(&"battle_open_legend")
	echo.echo = true
	instance._input(echo)
	assert_bool(instance.is_legend_open()).is_true()


func test_ac3_cancel_confirm_right_click_outside_click_and_button_close() -> void:
	var instance: BattleScreen = _load()
	var closers: Array[InputEvent] = [
		_action(&"battle_cancel"), _action(&"battle_confirm"),
		_click(Vector2(500, 300), MOUSE_BUTTON_RIGHT),
		_click(Vector2(1, 1), MOUSE_BUTTON_LEFT),
	]
	for ev: InputEvent in closers:
		instance.open_legend()
		assert_bool(instance.is_legend_open()).is_true()
		instance._input(ev)
		assert_bool(instance.is_legend_open()).is_false()
	instance.open_legend()
	var btn: Button = instance.legend_panel().close_button()
	var center: Vector2 = btn.global_position + btn.size * 0.5
	instance._input(_click(center, MOUSE_BUTTON_LEFT))
	assert_bool(instance.is_legend_open()).is_false()


func test_ac3_open_swallows_board_and_other_inputs() -> void:
	var instance: BattleScreen = _load()
	instance.hide_objective()
	var sel_before: int = instance._controller.selected_unit()
	var target_before: CursorTarget = CursorStateHost.get_current_target()
	var hud_before: bool = instance.diagnostic_hud_hidden()
	instance.open_legend()
	var swallowed: Array[StringName] = [
		&"ui_down", &"ui_left", &"ui_right", &"ui_up", &"battle_next_target", &"battle_prev_target",
		&"battle_open_hand", &"battle_guess_cycle", &"battle_toggle_relation_map",
		&"battle_toggle_hud", &"battle_end_unit_turn", &"battle_menu",
	]
	for action: StringName in swallowed:
		var ev: InputEventKey = _key(action)
		if ev == null:
			ev = InputEventKey.new()
			ev.pressed = true
			ev.keycode = KEY_DOWN
		instance._input(ev)
		assert_bool(instance.is_legend_open()).append_failure_message("action " + String(action)).is_true()
	assert_int(instance._controller.selected_unit()).is_equal(sel_before)
	assert_bool(instance.diagnostic_hud_hidden()).is_equal(hud_before)
	assert_bool(instance._battle_menu.is_open()).is_false()
	var target_after: CursorTarget = CursorStateHost.get_current_target()
	assert_bool(target_after.equals(target_before)).is_true()
	# 滑鼠移動被吞,不更新懸停位置。
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(300, 200)
	motion.relative = Vector2(5, 5)
	instance._input(motion)
	assert_bool(instance.is_legend_open()).is_true()


func test_ac3_click_on_mask_does_not_reach_board() -> void:
	var instance: BattleScreen = _load()
	instance.hide_objective()
	var sel_before: int = instance._controller.selected_unit()
	instance.open_legend()
	# 點在左上角(遮罩上、面板外),正是棋盤格的位置。
	instance._input(_click(Vector2(40, 40), MOUSE_BUTTON_LEFT))
	assert_bool(instance.is_legend_open()).is_false()
	assert_int(instance._controller.selected_unit()).is_equal(sel_before)


func test_ac3_not_openable_while_menu_open_and_menu_row_opens_legend() -> void:
	var instance: BattleScreen = _load()
	instance.hide_objective()
	instance._battle_menu.open()
	instance.open_legend()
	assert_bool(instance.is_legend_open()).is_false()
	instance._battle_menu._legend_row.pressed.emit()
	assert_bool(instance._battle_menu.is_open()).is_false()
	assert_bool(instance.is_legend_open()).is_true()
	assert_bool(get_tree().paused).is_false()
	instance.close_legend()
	assert_bool(instance._battle_menu.is_open()).is_false()


func test_ac3_gamepad_trigger_binding_exists_and_is_single_fire_while_held() -> void:
	assert_bool(InputMap.has_action(&"battle_open_legend")).is_true()
	var has_l: bool = false
	var has_trigger: bool = false
	for e: InputEvent in InputMap.action_get_events(&"battle_open_legend"):
		if e is InputEventKey and (e as InputEventKey).keycode == KEY_L:
			has_l = true
		if e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT:
			has_trigger = true
	assert_bool(has_l).is_true()
	assert_bool(has_trigger).is_true()
	# 引擎事實:軸事件按住期間每一個超過門檻的事件都被判為「按下」(這就是需要閂鎖的原因)。
	assert_bool(_trigger(1.0).is_action_pressed(&"battle_open_legend")).is_true()
	assert_bool(_trigger(0.9).is_action_pressed(&"battle_open_legend")).is_true()
	assert_bool(_trigger(0.3).is_action_pressed(&"battle_open_legend")).is_false()
	var instance: BattleScreen = _load()
	instance._input(_trigger(1.0))
	assert_bool(instance.is_legend_open()).is_true()
	instance._input(_trigger(0.9))  # 按住中的抖動:不得關閉
	instance._input(_trigger(1.0))
	assert_bool(instance.is_legend_open()).is_true()
	instance._input(_trigger(0.0))
	instance._process(0.0)  # 放開 → 閂鎖解除(沒有真實輸入,Input.is_action_pressed 為假)
	instance._input(_trigger(1.0))
	assert_bool(instance.is_legend_open()).is_false()


func test_ac3_arbitration_suspended_while_open_and_resumed_on_close() -> void:
	var instance: BattleScreen = _load()
	instance.open_legend()
	assert_bool(bool(CursorStateHost.get(&"_arbitration_suspended"))).is_true()
	instance.close_legend()
	assert_bool(bool(CursorStateHost.get(&"_arbitration_suspended"))).is_false()


# ---- AC4 在地化與版面 ------------------------------------------------------------

func test_ac4_layout_fits_window_and_text_fits_label_at_all_sizes() -> void:
	var instance: BattleScreen = _load()
	var panel: LegendPanel = instance.legend_panel()
	assert_object(panel.get_parent()).is_same(instance.get_node("UILayer"))
	for size: Vector2i in _WINDOW_SIZES:
		panel.open(size)
		var window: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
		assert_bool(window.encloses(panel.content_rect())).append_failure_message(str(size)).is_true()
		var fpx: int = HudLayout.font_size(size)
		for kind: int in LegendPanel.entry_kinds():
			for label: Label in [panel.name_label_for(kind), panel.desc_label_for(kind)]:
				var r: Rect2 = Rect2(label.position, label.size)
				assert_bool(window.encloses(r)).append_failure_message("%s kind %d" % [str(size), kind]).is_true()
				var w: float = HudLayoutScaler.HUD_FONT.get_string_size(
					label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
				assert_bool(w <= label.size.x).append_failure_message(
					"%s kind %d text %s w=%f box=%f" % [str(size), kind, label.text, w, label.size.x]).is_true()
		assert_bool(window.encloses(Rect2(panel.close_button().position, panel.close_button().size))).is_true()
		panel.close()
