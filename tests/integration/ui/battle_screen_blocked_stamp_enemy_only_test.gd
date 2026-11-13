# story-052 -- 視線被擋章只畫在「被擋集合 ∩ 存活敵兵格」;威脅排除只套用在真的畫了章的格。
#
# 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BattleScreen.tscn,
# 以 terrain_path_override / roster_path_override 注入合成夾具(唯讀、已進版控):
#   terrain: assets/data/levels/test_fixture_terrain_los.txt(5 格走廊,(2,0) 密林)
#   roster : test_fixture_roster_los.txt(我方 (0,0) 射程 1-4,敵 (4,0))—— AC1/AC2b/AC6 用
#            test_fixture_roster_los2.txt(另加敵 (3,0))—— AC2 用
#   test_fixture_roster_los3.txt(我方 mp=3,使被擋格也落在威脅集合)—— AC2b 用
# 兩份 roster 都與 terrain 相容(起點都在 5x3 範圍內)。
# 揭露:headless 不 rasterize,只證明節點樹(哪些格有章/威脅標記),不證明畫面看起來對(像素層待補拍,AC7)。
# 敏感度:mutant 手動注入(一次一個),記錄在交付回報;本檔無常駐 spy(篩選在 BattleScreen 私有流程內,
#   無繼承鏈可覆寫,屬 test-standards 的 D 類)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_PATH: String = "res://assets/data/levels/test_fixture_terrain_los.txt"
const _ROSTER_PATH: String = "res://assets/data/units/test_fixture_roster_los.txt"
const _ROSTER2_PATH: String = "res://assets/data/units/test_fixture_roster_los2.txt"
const _ROSTER3_PATH: String = "res://assets/data/units/test_fixture_roster_los3.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _load(roster_path: String) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.terrain_path_override = _TERRAIN_PATH
	instance.roster_path_override = roster_path
	auto_free(instance)
	add_child(instance)
	return instance


func _cells_in_layer(screen: BattleScreen, layer_name: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var layer: Node2D = screen._board_view.get_node(layer_name)
	for child: Node in layer.get_children():
		if child is Node2D and not child is Sprite2D:
			var root: Node2D = child as Node2D
			cells.append(Vector2i((root.position - BoardCoords.BOARD_ORIGIN) / BoardCoords.CELL_SIZE))
	return cells


func _select_and_refresh(screen: BattleScreen) -> void:
	assert_bool(screen._controller.select_unit(1)).is_true()
	screen._refresh_view()


func test_blocked_stamp_only_on_enemy_cells_not_on_empty_blocked_cells() -> void:
	var screen: BattleScreen = _load(_ROSTER_PATH)
	_select_and_refresh(screen)

	var blocked: Array[Vector2i] = screen._controller.attack_targets_blocked_by_los()
	var empty_blocked: Array[Vector2i] = []
	var enemy_blocked: Array[Vector2i] = []
	for cell: Vector2i in blocked:
		var occupant: Unit = screen._state.unit_at(cell)
		if occupant != null and occupant.faction == Unit.Faction.ENEMY:
			enemy_blocked.append(cell)
		elif occupant == null:
			empty_blocked.append(cell)
	# 防空洞:被擋集合同時含空格與敵兵格,篩選才被考驗
	assert_int(empty_blocked.size()).append_failure_message("前提:被擋集合需含空格").is_greater(0)
	assert_int(enemy_blocked.size()).append_failure_message("前提:被擋集合需含敵兵格").is_greater(0)

	var stamps: Array[Vector2i] = _cells_in_layer(screen, "AttackLosBlockedLayer")
	assert_int(stamps.size()).is_greater(0)
	for cell: Vector2i in empty_blocked:
		assert_bool(stamps.has(cell)).append_failure_message("空格不得有章:%s" % cell).is_false()
	for cell: Vector2i in enemy_blocked:
		assert_bool(stamps.has(cell)).append_failure_message("敵兵格須有章:%s" % cell).is_true()
	assert_int(stamps.size()).is_equal(enemy_blocked.size())


func test_dead_enemy_cell_loses_stamp_while_other_enemy_keeps_it() -> void:
	var screen: BattleScreen = _load(_ROSTER2_PATH)
	_select_and_refresh(screen)
	var cell_a: Vector2i = screen._state.position_of(2)
	var cell_b: Vector2i = screen._state.position_of(3)
	var before: Array[Vector2i] = _cells_in_layer(screen, "AttackLosBlockedLayer")
	# 防空洞:兩個敵兵格原本都有章
	assert_bool(before.has(cell_a)).append_failure_message("前提:敵2 格有章 %s" % [before]).is_true()
	assert_bool(before.has(cell_b)).append_failure_message("前提:敵3 格有章 %s" % [before]).is_true()

	var victim: Unit = screen._state.unit_by_id(2)
	victim.take_damage(victim.hp_max)
	assert_bool(victim.is_alive()).is_false()
	screen._refresh_view()

	var after: Array[Vector2i] = _cells_in_layer(screen, "AttackLosBlockedLayer")
	assert_bool(after.has(cell_a)).append_failure_message("死者格章應消失").is_false()
	assert_bool(after.has(cell_b)).append_failure_message("另一敵兵格章應保留").is_true()


func test_threat_excluded_only_where_stamp_drawn_empty_blocked_cell_keeps_threat() -> void:
	var screen: BattleScreen = _load(_ROSTER3_PATH)
	_select_and_refresh(screen)
	var threat_all: Array[Vector2i] = screen._controller.threat_targets().cells
	var blocked: Array[Vector2i] = screen._controller.attack_targets_blocked_by_los()
	var empty_blocked_in_threat: Array[Vector2i] = []
	var enemy_blocked_in_threat: Array[Vector2i] = []
	for cell: Vector2i in blocked:
		if not threat_all.has(cell):
			continue
		var occupant: Unit = screen._state.unit_at(cell)
		if occupant == null:
			empty_blocked_in_threat.append(cell)
		elif occupant.faction == Unit.Faction.ENEMY:
			enemy_blocked_in_threat.append(cell)
	# 防空洞:兩種格各至少一個,排除邏輯才被考驗
	assert_int(empty_blocked_in_threat.size()).append_failure_message(
		"前提:需有同時在威脅集合的被擋空格").is_greater(0)
	assert_int(enemy_blocked_in_threat.size()).append_failure_message(
		"前提:需有同時在威脅集合的被擋敵兵格").is_greater(0)

	var threat_drawn: Array[Vector2i] = _cells_in_layer(screen, "ThreatHighlightLayer")
	var stamps: Array[Vector2i] = _cells_in_layer(screen, "AttackLosBlockedLayer")
	for cell: Vector2i in empty_blocked_in_threat:
		assert_bool(threat_drawn.has(cell)).append_failure_message("被擋空格應照常畫威脅:%s" % cell).is_true()
		assert_bool(stamps.has(cell)).is_false()
	for cell: Vector2i in enemy_blocked_in_threat:
		assert_bool(stamps.has(cell)).append_failure_message("被擋敵兵格有章:%s" % cell).is_true()
		assert_bool(threat_drawn.has(cell)).append_failure_message("有章的格不得再畫威脅:%s" % cell).is_false()


func test_hover_on_blocked_empty_cell_still_shows_tile_info_card() -> void:
	# AC6:章不畫不等於資訊不告知。資訊卡(story-042)對被擋空格仍照常顯示「擋視線」行。
	# 揭露:story-040 的「攻擊:視線被擋」原因行本來就只對「有單位的格」產生(battle_screen.gd
	# 以 occupant 為條件),空格從來沒有該行 —— 本單未改變這一點,故此處不斷言空格有原因行。
	var screen: BattleScreen = _load(_ROSTER_PATH)
	_select_and_refresh(screen)
	var empty_blocked: Vector2i = Vector2i(-1, -1)
	for cell: Vector2i in screen._controller.attack_targets_blocked_by_los():
		if screen._state.unit_at(cell) == null:
			empty_blocked = cell
			break
	assert_vector(empty_blocked).append_failure_message("前提:需有被擋空格").is_not_equal(Vector2i(-1, -1))

	screen._cursor_active = true
	screen._cursor_cell = empty_blocked
	screen._tile_info_cursor_valid = true
	screen._update_tile_info_panel()
	var text: String = screen._tile_info_panel_label.text

	assert_bool(text.contains("擋視線：")).override_failure_message(text).is_true()
