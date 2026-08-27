# GreedyTacticalAI（src/ai/greedy_tactical_ai.gd）的單元測試。
#
# 純函式（RefCounted、static），不建立任何 Node，也不需要 tear-down，不會留下
# 孤兒節點。命名慣例沿用既有先例 tests/unit/gameplay/combat/combat_rules_test.gd
# 的 test_[scenario]_[expected]。
#
# 每個測試自建自己的迷你盤面（Board.from_ascii()）與名冊（Unit.from_csv_line()
# 透過 BattleState.create()），不依賴 assets/data 底下的真實關卡資料檔 ——
# 那些檔案同批有另一位專家在使用，避免撞車。
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

# 13x6（Board 固定尺寸）全開闊版面，每格皆為 "."。
func _open_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		var row: String = ""
		for _x: int in range(Board.BOARD_WIDTH):
			row += Board.TERRAIN_OPEN
		rows.append(row)
	return rows


# 與 _open_rows() 相同，但 wall_pos 那一格改成倒木（阻擋視線）。
func _rows_with_wall(wall_pos: Vector2i) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for y: int in range(Board.BOARD_HEIGHT):
		var row: String = ""
		for x: int in range(Board.BOARD_WIDTH):
			if x == wall_pos.x and y == wall_pos.y:
				row += Board.TERRAIN_FALLEN_LOG
			else:
				row += Board.TERRAIN_OPEN
		rows.append(row)
	return rows


func _state(terrain_rows: PackedStringArray, roster_lines: Array[String]) -> BattleState:
	return BattleState.create(terrain_rows, "\n".join(roster_lines))


# ---- 射程內就攻擊，不移動 ---------------------------------------------------

func test_already_adjacent_attacks_without_moving() -> void:
	# Arrange — 攻方 mp=0（無法移動），與敵人相鄰（距離 1）
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,0,1,1,6,3",
		"2,E1,ENEMY,20,10,5,0,1,1,6,4",
	])

	# Act
	var result: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)

	# Assert
	assert_object(result["move_to"]).is_null()
	assert_int(result["attack"]).is_equal(2)


func test_can_attack_false_never_returns_attack_target_even_when_adjacent() -> void:
	# Arrange — 與上一測試相同盤面，但 can_attack=false
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,0,1,1,6,3",
		"2,E1,ENEMY,20,10,5,0,1,1,6,4",
	])

	# Act
	var result: Dictionary = GreedyTacticalAI.decide(state, 1, true, false)

	# Assert
	assert_object(result["move_to"]).is_null()
	assert_int(result["attack"]).is_equal(-1)


# ---- 不在射程就靠近 ---------------------------------------------------------

func test_out_of_range_moves_closer_without_attacking() -> void:
	# Arrange — 攻方 mp=1、射程 1（近戰），敵人在 (6,0)，距離 3，一回合走不到攻擊位置
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,1,1,1,6,3",
		"2,E1,ENEMY,20,10,5,1,1,1,6,0",
	])

	# Act
	var result: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)

	# Assert — 四個可達格中，(6,2) 與敵人距離最小（2），且是唯一最小值
	assert_vector(result["move_to"]).is_equal(Vector2i(6, 2))
	assert_int(result["attack"]).is_equal(-1)


func test_can_move_false_never_moves_even_when_moving_would_help() -> void:
	# Arrange — 與上一測試相同盤面，但 can_move=false
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,1,1,1,6,3",
		"2,E1,ENEMY,20,10,5,1,1,1,6,0",
	])

	# Act
	var result: Dictionary = GreedyTacticalAI.decide(state, 1, false, true)

	# Assert — 原地距離 3，射程 1，打不到，且不可移動
	assert_object(result["move_to"]).is_null()
	assert_int(result["attack"]).is_equal(-1)


# ---- 視線被 # 擋住時不選該目標 ----------------------------------------------

func test_los_blocked_enemy_is_skipped_even_though_its_hp_is_lower() -> void:
	# Arrange — 攻方在 (6,3)，射程 1..3，mp=0（原地判斷）
	# EA 在 (6,1)：直線距離 2，中繼格 (6,2) 是倒木，視線被擋
	# EB 在 (8,3)：直線距離 2，中繼格 (7,3) 是空地，視線暢通
	# EA 血量刻意設得比 EB 低 —— 若演算法誤把被擋的目標也算進候選，
	# 血量最低優先的規則會選到 EA；只有正確排除 EA 才會選到 EB。
	var state: BattleState = _state(_rows_with_wall(Vector2i(6, 2)), [
		"1,A1,PLAYER,20,10,5,0,1,3,6,3",
		"2,EA,ENEMY,10,10,5,0,1,1,6,1",
		"3,EB,ENEMY,30,10,5,0,1,1,8,3",
	])

	# Act
	var result: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)

	# Assert
	assert_int(result["attack"]).is_equal(3)


# ---- HP 最低優先 ------------------------------------------------------------

func test_selects_lowest_hp_target_even_when_its_unit_id_is_higher() -> void:
	# Arrange — EA（id 較大、血量較低）與 EB（id 較小、血量較高），皆可攻擊到
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,0,1,3,6,3",
		"9,EA,ENEMY,20,10,5,0,1,1,6,1",
		"4,EB,ENEMY,20,10,5,0,1,1,6,5",
	])
	var unit_ea: Unit = state.unit_by_id(9)
	var unit_eb: Unit = state.unit_by_id(4)
	unit_ea.hp = 12
	unit_eb.hp = 25

	# Act
	var result: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)

	# Assert — 血量最低的 EA（id 9）勝出，即使 id 比 EB 大
	assert_int(result["attack"]).is_equal(9)


func test_hp_tie_breaks_by_lowest_unit_id_and_is_deterministic() -> void:
	# Arrange — EX（id 7）與 EY（id 3）血量相同，皆可攻擊到
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,0,1,3,6,3",
		"7,EX,ENEMY,15,10,5,0,1,1,6,1",
		"3,EY,ENEMY,15,10,5,0,1,1,6,5",
	])

	# Act — 同一輸入跑兩次
	var result_first: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)
	var result_second: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)

	# Assert — 兩次結果相同，且血量平手時取較小 id（3）
	assert_int(result_first["attack"]).is_equal(3)
	assert_int(result_second["attack"]).is_equal(3)


# ---- 候選格平手時的確定性 ----------------------------------------------------

func test_move_tile_tie_breaks_by_yx_order_and_is_deterministic() -> void:
	# Arrange — 攻方 mp=1，四個相鄰格中 (6,2) 與 (5,3) 與敵人 (4,1) 距離同為 3，
	# 皆無法攻擊（射程 1，敵人太遠）。(6,2) 的 y=2 小於 (5,3) 的 y=3，應勝出。
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,1,1,1,6,3",
		"2,E1,ENEMY,20,10,5,1,1,1,4,1",
	])

	# Act — 同一輸入跑兩次
	var result_first: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)
	var result_second: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)

	# Assert
	assert_vector(result_first["move_to"]).is_equal(Vector2i(6, 2))
	assert_vector(result_second["move_to"]).is_equal(Vector2i(6, 2))
	assert_int(result_first["attack"]).is_equal(-1)


# ---- 無存活敵人 -------------------------------------------------------------

func test_no_living_enemies_returns_null_move_and_no_attack() -> void:
	# Arrange — 名冊裡只有 PLAYER，完全沒有 ENEMY
	var state: BattleState = _state(_open_rows(), [
		"1,A1,PLAYER,20,10,5,3,1,1,6,3",
	])

	# Act
	var result: Dictionary = GreedyTacticalAI.decide(state, 1, true, true)

	# Assert
	assert_object(result["move_to"]).is_null()
	assert_int(result["attack"]).is_equal(-1)
