# BattleState（src/gameplay/battle/battle_state.gd）的單元測試。
#
# 這是本專案第一個把 Board / Unit / CombatRules 接起來的整合層，因此每一個測試
# 都從 vs01 的兩份真實資料檔（assets/data/levels/vs01_terrain.txt、
# assets/data/units/vs01_roster.txt）重新建構一份全新的 BattleState —— 不共用
# 可變狀態，符合 .claude/rules/test-standards.md「每個測試自建自拆」的要求。
#
# 讀檔手法沿用既有先例：地形逐行讀取沿用
# tests/unit/gameplay/board/board_test.gd，名冊整檔讀取沿用
# tests/unit/gameplay/units/unit_test.gd。命名慣例沿用
# tests/unit/gameplay/combat/combat_rules_test.gd 的 test_[scenario]_[expected]。
#
# 不建立任何 Node —— BattleState 全鏈路（Board/Unit/CombatRules）都是
# RefCounted，不會留下孤兒節點。
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

func _load_terrain_rows() -> PackedStringArray:
	var file: FileAccess = FileAccess.open(
		"res://assets/data/levels/vs01_terrain.txt", FileAccess.READ
	)
	assert_object(file).is_not_null()

	var rows: PackedStringArray = PackedStringArray()
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty() and file.eof_reached():
			break
		rows.append(line)
	file.close()
	return rows


func _load_roster_text() -> String:
	var text: String = FileAccess.get_file_as_string("res://assets/data/units/vs01_roster.txt")
	assert_str(text).is_not_empty()
	return text


func _load_state() -> BattleState:
	return BattleState.create(_load_terrain_rows(), _load_roster_text())


# ---- create() ---------------------------------------------------------------

func test_create_loads_vs01_data_and_places_units_at_start_pos() -> void:
	# Arrange / Act
	var state: BattleState = _load_state()

	# Assert — 名冊第一筆（甲）與最後一筆（E5）都落在各自的 start_pos
	assert_vector(state.position_of(1)).is_equal(Vector2i(0, 2))
	assert_vector(state.position_of(10)).is_equal(Vector2i(11, 5))
	assert_int(state.board.get_occupant(Vector2i(0, 2))).is_equal(1)
	assert_int(state.board.get_occupant(Vector2i(11, 5))).is_equal(10)
	assert_array(state.units_of(Unit.Faction.PLAYER)).has_size(5)
	assert_array(state.units_of(Unit.Faction.ENEMY)).has_size(5)


# ---- move_unit() — (a) 非法移動被擋、狀態不變 --------------------------------

func test_move_unit_beyond_reach_is_rejected_and_state_unchanged() -> void:
	# Arrange — 單位 1（甲）mp=6，起點 (0,2)；目的地 (12,5) 曼哈頓距離 15，
	# 就算沿線全開闊地（每格成本 1）也遠遠超出 6 點移動力
	var state: BattleState = _load_state()
	var origin: Vector2i = state.position_of(1)
	var dest: Vector2i = Vector2i(12, 5)

	# Act
	var moved: bool = state.move_unit(1, dest)

	# Assert — 回傳 false，位置與棋盤佔位表都沒被動過
	assert_bool(moved).is_false()
	assert_vector(state.position_of(1)).is_equal(origin)
	assert_int(state.board.get_occupant(origin)).is_equal(1)
	assert_bool(state.board.has_occupant(dest)).is_false()


func test_move_unit_within_reach_updates_position_and_occupancy() -> void:
	# Arrange — 單位 1（甲）mp=6，起點 (0,2)，沿開闊地移動到 (0,0) 只需 2 點
	var state: BattleState = _load_state()
	var origin: Vector2i = state.position_of(1)
	var dest: Vector2i = Vector2i(0, 0)

	# Act
	var moved: bool = state.move_unit(1, dest)

	# Assert
	assert_bool(moved).is_true()
	assert_vector(state.position_of(1)).is_equal(dest)
	assert_bool(state.board.has_occupant(origin)).is_false()
	assert_int(state.board.get_occupant(dest)).is_equal(1)


# ---- resolve_attack() — (b) 單位陣亡後該格變可通行 ----------------------------

func test_unit_death_clears_occupancy_and_tile_becomes_passable() -> void:
	# Arrange — 目標 8（E3）hp=24 def=5，站在 (9,4)；攻擊方 3（丙）atk=20，
	# 每擊 20-5+0=15 傷害，兩擊即可致死（30 ≥ 24）。
	# 另一個單位 9（E4）從 (7,5) 沿全開闊地走到 (9,4) 只需 3 點移動力（mp=5）。
	var state: BattleState = _load_state()
	var target_pos: Vector2i = state.position_of(8)
	assert_vector(target_pos).is_equal(Vector2i(9, 4))

	# Act 1 — 目標還活著時，(9,4) 被佔用，任何人都無法移動進去
	var move_while_alive: bool = state.move_unit(9, target_pos)

	# Assert 1
	assert_bool(move_while_alive).is_false()
	assert_int(state.board.get_occupant(target_pos)).is_equal(8)

	# Act 2 — 兩擊打死目標
	state.resolve_attack(3, 8, 0)
	state.resolve_attack(3, 8, 0)

	# Assert 2 — 目標死亡、格子清空、不再是合法目標
	assert_bool(state.unit_by_id(8).is_alive()).is_false()
	assert_bool(state.board.has_occupant(target_pos)).is_false()
	assert_object(state.unit_at(target_pos)).is_null()

	# Act 3 — 現在同一步路徑應該走得通了
	var move_after_death: bool = state.move_unit(9, target_pos)

	# Assert 3
	assert_bool(move_after_death).is_true()
	assert_int(state.board.get_occupant(target_pos)).is_equal(9)


# ---- resolve_attack() — (c) 敵方攻擊時 phi 被強制歸零 -------------------------

func test_resolve_attack_enemy_attacker_forces_phi_zero_player_attacker_keeps_phi() -> void:
	# Arrange
	var state: BattleState = _load_state()

	# Act 1 — 敵方 6（E1，atk=20）打玩家 1（甲，def=8），傳入 phi=999
	# 應被強制視為 0：20-8+0=12，phi 完全不生效
	var enemy_damage: int = state.resolve_attack(6, 1, 999)

	# Assert 1
	assert_int(enemy_damage).is_equal(12)
	assert_int(state.unit_by_id(1).hp).is_equal(30 - 12)

	# Act 2 — 對照組：玩家 1（甲，atk=16）打敵方 6（E1，def=10），phi=5 正常生效
	# 16-10+5=11
	var player_damage: int = state.resolve_attack(1, 6, 5)

	# Assert 2
	assert_int(player_damage).is_equal(11)
	assert_int(state.unit_by_id(6).hp).is_equal(36 - 11)


# ---- can_attack() — (d) 中央倒木堆擋下原本射程內的遠程攻擊 ----------------------

func test_can_attack_blocked_by_central_fallen_log_despite_being_in_range() -> void:
	# Arrange — 攻擊方 3（丙，range 2-4，mp=3）從 (1,3) 走到 (3,3)（開闊地，成本 2）；
	# 目標 9（E4，mp=5）從 (7,5) 走到 (7,3)（(7,4) 開闊 1 + (7,3) 灌木 2 = 3）。
	# 兩者最終距離 4，落在 2-4 射程內；但視線直線會穿過 (5,3) 與 (6,3) 兩格倒木。
	var state: BattleState = _load_state()
	assert_bool(state.move_unit(3, Vector2i(3, 3))).is_true()
	assert_bool(state.move_unit(9, Vector2i(7, 3))).is_true()

	# Act
	var legal: bool = state.can_attack(3, 9)

	# Assert — 距離合法，但倒木擋視線，攻擊不合法
	assert_bool(legal).is_false()


func test_can_attack_ignores_a_living_unit_standing_between_attacker_and_target() -> void:
	# Arrange — 三個單位沿全開闊的第 5 列（row 5，無倒木無灌木）一字排開：
	# 攻擊方 3（丙，range 2-4）在 (2,5)；擋在正中間的 4（丁，仍存活）在 (3,5)；
	# 目標 9（E4）在 (4,5)。距離 2，落在射程內；中繼格地形不遮蔽，
	# 且依規則單位本身絕不遮蔽視線 —— 即使 4 活生生站在直線正中央。
	var state: BattleState = _load_state()
	assert_bool(state.move_unit(3, Vector2i(2, 5))).is_true()
	assert_bool(state.move_unit(4, Vector2i(3, 5))).is_true()
	assert_bool(state.move_unit(9, Vector2i(4, 5))).is_true()
	assert_bool(state.unit_by_id(4).is_alive()).is_true()

	# Act
	var legal: bool = state.can_attack(3, 9)

	# Assert
	assert_bool(legal).is_true()


# ---- outcome() — (e) 三態各一 -------------------------------------------------

func test_outcome_fresh_battle_is_ongoing() -> void:
	# Arrange / Act
	var state: BattleState = _load_state()

	# Assert
	assert_int(state.outcome()).is_equal(BattleState.Outcome.ONGOING)


func test_outcome_all_enemies_dead_is_victory() -> void:
	# Arrange — 攻擊方 1（甲，atk=16，phi=0）逐一打死 5 名敵人（id 6..10），
	# 每次攻擊只傷害目標，攻擊方自己永遠不受傷，因此不會意外觸發 DEFEAT
	var state: BattleState = _load_state()
	for enemy_id: int in [6, 7, 8, 9, 10]:
		var target: Unit = state.unit_by_id(enemy_id)
		while target.is_alive():
			state.resolve_attack(1, enemy_id, 0)

	# Act
	var result: BattleState.Outcome = state.outcome()

	# Assert
	assert_int(result).is_equal(BattleState.Outcome.VICTORY)


func test_outcome_any_player_dead_is_defeat_even_with_enemies_remaining() -> void:
	# Arrange — 敵方 6（E1）反覆攻擊玩家 1（甲，hp=30），直到甲陣亡；
	# 其餘 4 名敵人與 4 名玩家都還活著，證明「輸」不需要全滅任一方
	var state: BattleState = _load_state()
	var target: Unit = state.unit_by_id(1)
	while target.is_alive():
		state.resolve_attack(6, 1, 0)

	# Act
	var result: BattleState.Outcome = state.outcome()

	# Assert
	assert_int(result).is_equal(BattleState.Outcome.DEFEAT)
	assert_bool(state.unit_by_id(6).is_alive()).is_true()
	assert_bool(state.unit_by_id(2).is_alive()).is_true()
