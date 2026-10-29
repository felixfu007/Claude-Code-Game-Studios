# Story 026(production/epics/tactical-combat/story-026-attack-preview-in-info-panel.md)
# —— 游標指到可攻擊的敵人時,右上資訊框顯示傷害拆解。
#
# 測試手法:直接呼叫真實的 BattleController.select_unit() / attack_targets()、
# 寫入 battle_screen.gd 的 _cursor_cell / _cursor_active / _tile_info_cursor_valid,
# 再呼叫真實的 _update_tile_info_panel()(同 attack_confirm_panel_test.gd 的既有手法)。
# 單位移進射程用真實 BattleState.legal_moves()/move_unit()。
# 🔴 揭露:不經真實方向鍵/滑鼠驅動游標;不驗證畫面像素(不開窗)。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _walk_unit_toward(instance: BattleScreen, unit_id: int, target_cell: Vector2i, max_steps: int) -> void:
	for _i in range(max_steps):
		var current: Vector2i = instance._state.position_of(unit_id)
		if _manhattan(current, target_cell) <= 1:
			return
		var reachable: Array[Vector2i] = instance._state.legal_moves(unit_id)
		if reachable.is_empty():
			return
		var best: Vector2i = reachable[0]
		for cell: Vector2i in reachable:
			if _manhattan(cell, target_cell) < _manhattan(best, target_cell):
				best = cell
		instance._state.move_unit(unit_id, best)


## 選我方第 0 位並走進最近敵人射程;PRECONDITION 斷言:已選定、目標格在 attack_targets() 內。
func _setup_attacker_in_range(instance: BattleScreen, unlinked: bool = false) -> Dictionary:
	var attacker: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	if unlinked:
		for candidate: Unit in instance._state.units_of(Unit.Faction.PLAYER):
			var has_link: bool = false
			for link: AffinityLink in instance._phi.links():
				if link.involves(candidate.id):
					has_link = true
			if not has_link:
				attacker = candidate
	var nearest: Unit = instance._state.units_of(Unit.Faction.ENEMY)[0]
	for enemy: Unit in instance._state.units_of(Unit.Faction.ENEMY):
		if _manhattan(instance._state.position_of(attacker.id), instance._state.position_of(enemy.id)) \
				< _manhattan(instance._state.position_of(attacker.id), instance._state.position_of(nearest.id)):
			nearest = enemy
	_walk_unit_toward(instance, attacker.id, instance._state.position_of(nearest.id), 4)
	assert_bool(instance._controller.select_unit(attacker.id)).append_failure_message(
		"PRECONDITION: select_unit 應成功"
	).is_true()
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"PRECONDITION: 應已選定攻擊方"
	).is_equal(attacker.id)
	assert_array(instance._controller.attack_targets().cells).append_failure_message(
		"PRECONDITION: 目標格應在 attack_targets() 內"
	).contains([instance._state.position_of(nearest.id)])
	return {"attacker": attacker, "enemy": nearest}


func _hover(instance: BattleScreen, cell: Vector2i) -> void:
	instance._cursor_cell = cell
	instance._cursor_active = true
	instance._tile_info_cursor_valid = true
	instance._update_tile_info_panel()


func _text(instance: BattleScreen) -> String:
	return instance._tile_info_panel_label.text


func _expected_breakdown(instance: BattleScreen, attacker: Unit, enemy: Unit) -> Dictionary:
	var phi: int = instance._phi.phi(attacker.id, enemy.id)
	return instance._state.preview_damage_breakdown(attacker.id, enemy.id, phi).breakdown


# AC1:五欄齊全,數字等於 breakdown。
func test_hover_attackable_enemy_shows_five_fields() -> void:
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var enemy: Unit = setup["enemy"]
	var bd: Dictionary = _expected_breakdown(instance, setup["attacker"], enemy)
	_hover(instance, instance._state.position_of(enemy.id))
	assert_bool(instance._tile_info_panel_bg.visible).is_true()
	var text: String = _text(instance)
	assert_str(text).contains("ATK：%d" % int(bd["atk"]))
	assert_str(text).contains("DEF：%d" % int(bd["def"]))
	assert_str(text).contains("Φ：%+d" % int(bd["phi"]))
	assert_str(text).contains("結果傷害：%d" % int(bd["damage"]))
	assert_str(text).contains("目標血量：%d → %d" % [enemy.hp, int(bd["target_hp_after"])])


# AC2:Φ = 0 仍顯示「Φ：+0」。前提斷言:這個設置下 Φ 真的是 0。
func test_phi_zero_still_shown_as_signed_zero() -> void:
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _setup_attacker_in_range(instance, true)
	var enemy: Unit = setup["enemy"]
	var bd: Dictionary = _expected_breakdown(instance, setup["attacker"], enemy)
	assert_int(int(bd["phi"])).append_failure_message(
		"PRECONDITION: 用沒有任何好感度連線的單位(戊),Φ 應為 0"
	).is_equal(0)
	_hover(instance, instance._state.position_of(enemy.id))
	assert_str(_text(instance)).contains("Φ：+0")


# AC3:預覽傷害 == 隨後實際扣血。
func test_preview_damage_equals_actual_hp_loss() -> void:
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var enemy: Unit = setup["enemy"]
	var cell: Vector2i = instance._state.position_of(enemy.id)
	_hover(instance, cell)
	var shown: String = _text(instance)
	var hp_before: int = enemy.hp
	instance._handle_click_tile_result(instance._controller.click_tile(cell))
	var actual_loss: int = hp_before - enemy.hp
	assert_int(actual_loss).append_failure_message("PRECONDITION: 攻擊應真的結算並扣血").is_greater(0)
	assert_str(shown).contains("結果傷害：%d" % actual_loss)
	assert_str(shown).contains("目標血量：%d → %d" % [hp_before, enemy.hp])


# AC4:我方單位、空地 → 回到 story-024 行為,不顯示預覽。
func test_non_target_cells_fall_back_to_story_024() -> void:
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var attacker: Unit = setup["attacker"]
	_hover(instance, instance._state.position_of(attacker.id))
	assert_bool(instance._tile_info_panel_bg.visible).is_true()
	assert_str(_text(instance)).not_contains("結果傷害")
	var empty_cell: Vector2i = Vector2i(-1, -1)
	for x in range(13):
		for y in range(6):
			var c: Vector2i = Vector2i(x, y)
			if instance._state.unit_at(c) == null:
				empty_cell = c
	assert_bool(empty_cell != Vector2i(-1, -1)).append_failure_message("PRECONDITION: 應找得到空地").is_true()
	_hover(instance, empty_cell)
	assert_bool(instance._tile_info_panel_bg.visible).is_false()


# AC4:範圍外的敵人 → 顯示單位資訊,不顯示預覽。
func test_enemy_out_of_range_shows_unit_info_not_preview() -> void:
	var instance: BattleScreen = _fresh_instance()
	_setup_attacker_in_range(instance)
	var far: Unit = null
	for enemy: Unit in instance._state.units_of(Unit.Faction.ENEMY):
		if not instance._controller.attack_targets().cells.has(instance._state.position_of(enemy.id)):
			far = enemy
	assert_object(far).append_failure_message("PRECONDITION: 應存在範圍外的敵人").is_not_null()
	_hover(instance, instance._state.position_of(far.id))
	assert_bool(instance._tile_info_panel_bg.visible).is_true()
	assert_str(_text(instance)).not_contains("結果傷害")


# AC5:再次進入同一目標格會重新計算(中間改了目標 HP,預估值必須跟著變)。
func test_preview_recomputed_each_hover() -> void:
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var enemy: Unit = setup["enemy"]
	var cell: Vector2i = instance._state.position_of(enemy.id)
	_hover(instance, cell)
	var first: String = _text(instance)
	enemy._hp = maxi(1, enemy.hp - 1)  # hp 有寫入守衛(Unit.hp setter),測試佈置直接改私有欄位
	_hover(instance, instance._state.position_of(setup["attacker"].id))
	_hover(instance, cell)
	assert_str(_text(instance)).append_failure_message("HP 變了,預覽必須跟著變").is_not_equal(first)
	assert_str(_text(instance)).contains("目標血量：%d →" % enemy.hp)


# AC6:新函式本體不得有寫死中文(只經 Loc.localize)。
func test_preview_builder_has_no_bare_cjk_literals() -> void:
	var src: String = FileAccess.get_file_as_string("res://src/ui/battle/battle_screen.gd")
	var start: int = src.find("func _build_attack_preview_text")
	var end: int = src.find("func _apply_tile_info_panel_layout")
	assert_bool(start != -1 and end > start).append_failure_message("PRECONDITION: 找得到函式本體").is_true()
	var body: String = src.substr(start, end - start)
	var re: RegEx = RegEx.new()
	re.compile("\"[^\"]*[\\x{4e00}-\\x{9fff}][^\"]*\"")
	var code_lines: PackedStringArray = PackedStringArray()
	for line: String in body.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code_lines.append(line)
	assert_object(re.search("\n".join(code_lines))).is_null()


# AC6:預覽行數不超過框的行數上限,且預覽版面寬於單位資訊版面。
func test_preview_layout_fits_lines_and_is_wider() -> void:
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _setup_attacker_in_range(instance)
	instance._apply_tile_info_panel_layout()
	var normal_w: float = instance._tile_info_panel_bg.offset_right - instance._tile_info_panel_bg.offset_left
	_hover(instance, instance._state.position_of(setup["enemy"].id))
	var preview_w: float = instance._tile_info_panel_bg.offset_right - instance._tile_info_panel_bg.offset_left
	assert_float(preview_w).is_greater(normal_w)
	assert_int(_text(instance).split("\n").size()).is_less_equal(BattleScreen._TILE_INFO_PANEL_LINE_COUNT)
