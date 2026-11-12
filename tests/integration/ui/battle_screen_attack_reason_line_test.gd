# story-040 AC2(整合層)/AC3/AC4 —— 資訊卡「攻擊：原因」行。
#
# 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BattleScreen.tscn,
# 使用預設 vs01 真實關卡與名冊(assets/data/,唯讀、已進版控);不寫入任何檔案、不自組替身節點鏈。
# 揭露:不證明窮盡性。vs01 開局沒有「過近」與「視線被擋」的敵我配對,這兩種原因由
# tests/unit/gameplay/combat/combat_rules_attack_block_reason_test.gd 的規則層掃描涵蓋,
# 本檔只驗證 controller 閘門/優先序與顯示條件。
# 敏感度證明:手動單一 mutant(見交付回報),static/私有狀態無繼承鏈可覆寫。
#
# AC 對照:
#   test_controller_reason_none_iff_attack_targets_contains_enemy -> AC2 整合層
#   test_controller_spent_attacker_returns_action_spent / _priority -> AC2 整合層
#   test_panel_*                                                  -> AC3
#   test_panel_extra_line_height_*                                -> AC4
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _load() -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	auto_free(instance)
	add_child(instance)
	return instance


func _enemy_ids(screen: BattleScreen) -> Array[int]:
	var ids: Array[int] = []
	for u: Unit in screen._state.units_of(Unit.Faction.ENEMY):
		ids.append(u.id)
	return ids


func _spend_attack(screen: BattleScreen, id: int) -> void:
	screen._state.commit_authoritative_change(func() -> void:
		screen._controller._order.use_attack(id)
	)
	assert_bool(screen._controller._order.can_attack(id)).override_failure_message(
		"前提失敗(測試空轉):攻擊旗標未真的用掉").is_false()


func _point_cursor_at(screen: BattleScreen, cell: Vector2i) -> void:
	screen._cursor_active = true
	screen._cursor_cell = cell
	screen._tile_info_cursor_valid = true
	screen._update_tile_info_panel()


func _line_count(text: String) -> int:
	return text.split("\n").size()


func test_controller_reason_none_iff_attack_targets_contains_enemy() -> void:
	var screen: BattleScreen = _load()
	var enemies: Array[int] = _enemy_ids(screen)
	assert_int(enemies.size()).override_failure_message("前提失敗:沒有敵兵").is_greater(0)
	var checked: int = 0
	for player: Unit in screen._state.units_of(Unit.Faction.PLAYER):
		assert_bool(screen._controller.select_unit(player.id)).is_true()
		var cells: Array[Vector2i] = screen._controller.attack_targets().cells
		for eid: int in enemies:
			var reason: CombatRules.AttackBlockReason = screen._controller.attack_block_reason_for(eid)
			assert_bool(cells.has(screen._state.position_of(eid))).is_equal(
				reason == CombatRules.AttackBlockReason.NONE)
			checked += 1
	assert_int(checked).is_greater(0)


func test_controller_spent_attacker_returns_action_spent() -> void:
	var screen: BattleScreen = _load()
	assert_bool(screen._controller.select_unit(1)).is_true()
	_spend_attack(screen, 1)
	for eid: int in _enemy_ids(screen):
		assert_int(screen._controller.attack_block_reason_for(eid)).is_equal(
			CombatRules.AttackBlockReason.ACTION_SPENT)


func test_controller_action_spent_outranks_out_of_range() -> void:
	var screen: BattleScreen = _load()
	assert_bool(screen._controller.select_unit(1)).is_true()
	var eid: int = _enemy_ids(screen)[0]
	# 未用完時,vs01 開局單位 1(近戰)對遠處敵兵 → 過遠。
	assert_int(screen._controller.attack_block_reason_for(eid)).is_equal(
		CombatRules.AttackBlockReason.OUT_OF_RANGE)
	_spend_attack(screen, 1)
	assert_int(screen._controller.attack_block_reason_for(eid)).is_equal(
		CombatRules.AttackBlockReason.ACTION_SPENT)


func test_controller_no_selection_is_not_applicable() -> void:
	var screen: BattleScreen = _load()
	assert_int(screen._controller.attack_block_reason_for(_enemy_ids(screen)[0])).is_equal(
		CombatRules.AttackBlockReason.NONE)


func test_panel_enemy_out_of_range_shows_reason_line() -> void:
	var screen: BattleScreen = _load()
	assert_bool(screen._controller.select_unit(1)).is_true()
	var eid: int = _enemy_ids(screen)[0]
	_point_cursor_at(screen, screen._state.position_of(eid))
	var expected: String = Loc.localize(&"battle.tile_info.attack_line_format") % Loc.localize(&"battle.tile_info.attack_reason_out_of_range")
	assert_bool(expected.length() > 0 and expected != "%s").is_true()
	assert_str(screen._tile_info_panel_label.text.split("\n")[-1]).is_equal(expected)


func test_panel_spent_attacker_shows_action_spent_line() -> void:
	var screen: BattleScreen = _load()
	assert_bool(screen._controller.select_unit(1)).is_true()
	_spend_attack(screen, 1)
	_point_cursor_at(screen, screen._state.position_of(_enemy_ids(screen)[0]))
	var expected: String = Loc.localize(&"battle.tile_info.attack_line_format") % Loc.localize(&"battle.tile_info.attack_reason_action_spent")
	assert_str(screen._tile_info_panel_label.text.split("\n")[-1]).is_equal(expected)


func test_panel_player_unit_and_empty_cell_and_unselected_show_no_attack_line() -> void:
	var screen: BattleScreen = _load()
	var prefix: String = Loc.localize(&"battle.tile_info.attack_line_format").split("%s")[0]
	# 未選取 + 敵兵
	_point_cursor_at(screen, screen._state.position_of(_enemy_ids(screen)[0]))
	assert_bool(screen._tile_info_panel_label.text.contains(prefix)).is_false()
	# 已選取 + 我方單位
	assert_bool(screen._controller.select_unit(1)).is_true()
	_point_cursor_at(screen, screen._state.position_of(2))
	assert_bool(screen._tile_info_panel_label.text.contains(prefix)).is_false()
	# 已選取 + 空格
	_point_cursor_at(screen, Vector2i(5, 0))
	assert_bool(screen._tile_info_panel_label.text.contains(prefix)).is_false()


func test_panel_extra_line_height_one_more_line_and_mutually_exclusive_with_guard() -> void:
	var screen: BattleScreen = _load()
	var eid: int = _enemy_ids(screen)[0]
	var enemy_cell: Vector2i = screen._state.position_of(eid)
	_point_cursor_at(screen, enemy_cell)  # 未選取:基準行數
	var base_lines: int = _line_count(screen._tile_info_panel_label.text)
	assert_bool(screen._tile_info_extra_line).is_false()
	assert_bool(screen._controller.select_unit(1)).is_true()
	_point_cursor_at(screen, enemy_cell)
	assert_int(_line_count(screen._tile_info_panel_label.text)).is_equal(base_lines + 1)
	assert_bool(screen._tile_info_extra_line).is_true()
	# 互斥:減傷列只在我方分支產生、原因行只在敵方分支產生,共用同一個旗標;
	# 敵方文字不得含減傷列(減傷格式 battle.hud.guard_format 的前綴)。
	var guard_prefix: String = Loc.localize(&"battle.attack_confirm.guard_format").split("%")[0]
	assert_bool(guard_prefix != "" and not screen._tile_info_panel_label.text.contains(guard_prefix)).is_true()
	# 高度:旗標為真時面板比旗標為假高「恰好一行」,且面板含 8 + 1 行的高度。
	var h_with: float = screen._tile_info_panel_bg.offset_bottom - screen._tile_info_panel_bg.offset_top
	_point_cursor_at(screen, Vector2i(5, 0))
	assert_bool(screen._tile_info_extra_line).is_false()
	var h_without: float = screen._tile_info_panel_bg.offset_bottom - screen._tile_info_panel_bg.offset_top
	assert_bool(h_with > h_without).is_true()
	var fpx: float = float(HudLayout.small_font_size(screen.get_window().size))
	assert_float(h_with - h_without).is_equal_approx(fpx * BattleScreen._TILE_INFO_PANEL_LINE_HEIGHT_MULTIPLIER, 0.01)
