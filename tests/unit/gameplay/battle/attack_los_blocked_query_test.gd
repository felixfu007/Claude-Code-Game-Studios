# story-003-los-blocked-in-range-query.md：
# BattleController.attack_targets_blocked_by_los()（src/gameplay/battle/battle_controller.gd）、
# BattleState.is_attack_range_blocked_by_los()、CombatRules.is_attack_blocked_by_los()、
# 與 BattleState.combat_state_version 的單元測試。
#
# 背景：GDD Visual/Audio §1.3 要求攻擊範圍疊加圖有三層權重（無疊加/合法可攻擊/
# 範圍內但不可攻擊），現有 attack_targets() 只回傳第二層（最終合法集合），第三層
# 「範圍內但視線被擋」過去沒有獨立查詢可畫。本檔驗證新查詢的三層互斥、盲區排除、
# 近戰結構性空集合、視線判定沿用既有 LineOfSight/CombatRules（不重新實作），以及
# ADR-0001 combat_state_version 在本 story 範圍內的最小行為（見 battle_state.gd 該
# 欄位的文件註解 — 本 story 只在 move_unit()/resolve_attack() 遞增，非完整合規）。
#
# 手法沿用 battle_controller_threat_test.gd：自建最小名冊、視需要疊加最小地形字串。
# 不建立任何 Node — 全鏈路（TurnOrder/BattleState/Board/Unit/CombatRules）都是
# RefCounted 或 static，不會留下孤兒節點。
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

func _build(
	roster_lines: Array[String],
	player_ids: Array[int],
	enemy_ids: Array[int],
	terrain: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var state: BattleState = BattleState.create(terrain, "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order)
	return {"state": state, "order": order, "controller": controller}


# Ascending (y, x) comparator matching BattleController._tile_less — kept as
# a local copy rather than calling the private static (tests should not reach
# into another class's private implementation details).
static func _tile_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


# ---- QA (1)/(2): 視線被擋格進入第三層、暢通格進入 attack_targets()、兩者互斥 -------

func test_los_blocked_cell_in_third_layer_clear_cell_in_attack_targets_mutually_exclusive() -> void:
	# Arrange — 單位 1 mp=0、射程 1-4，起點 (0,0)；row0 的 (2,0) 放倒木擋視線。
	# 敵方 2 站 (4,0)：距離 4，直線穿過 (2,0) → 應被擋，落入第三層、不在
	# attack_targets()。敵方 3 站 (0,4)：距離 4，沿 y 軸開闊地 → 視線暢通，應在
	# attack_targets()、不落入第三層。
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
		"3,E2,ENEMY,20,10,0,0,1,1,0,4",
	]
	var bundle: Dictionary = _build(roster, [1], [2, 3], terrain)
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var blocked: Array[Vector2i] = controller.attack_targets_blocked_by_los()
	var attackable: Array[Vector2i] = controller.attack_targets()

	# Assert
	assert_array(blocked).contains([Vector2i(4, 0)])
	assert_array(blocked).not_contains([Vector2i(0, 4)])
	assert_array(attackable).contains([Vector2i(0, 4)])
	assert_array(attackable).not_contains([Vector2i(4, 0)])
	# 互斥：兩個切面沒有任何一格同時出現在兩邊
	for cell: Vector2i in blocked:
		assert_array(attackable).not_contains([cell])
	for cell: Vector2i in attackable:
		assert_array(blocked).not_contains([cell])


# ---- QA (窮盡性的一半)：第三層永遠是「射程內」的子集，不會殘留範圍外/盲區的格子 ------

func test_third_layer_cells_are_always_within_the_min_max_range_band() -> void:
	# Arrange — 同上場景（有實際被擋的格子，測試才有意義），但這次掃過整份輸出，
	# 逐格用 CombatRules.is_in_range()（已在別處驗證過的既有函式，此處僅作為
	# 獨立於受測程式碼的量尺）核對每一格都落在 [1,4] 內。
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var blocked: Array[Vector2i] = controller.attack_targets_blocked_by_los()

	# Assert
	assert_bool(blocked.is_empty()).is_false()  # 先確認這支測試真的測到東西
	for cell: Vector2i in blocked:
		assert_bool(CombatRules.is_in_range(Vector2i(0, 0), cell, 1, 4)).is_true()


# ---- QA (3) 近戰武器恆回傳空集合（結構性保證，非特判）---------------------------

func test_melee_weapon_always_returns_empty_regardless_of_terrain() -> void:
	# Arrange — 單位 1 近戰 (1,1)，起點 (0,0)；緊鄰的 (1,0) 刻意放倒木（用來
	# 證明「不論盤面遮蔽狀況」——即使緊鄰格被標記為遮蔽，近戰距離 1 結構上永遠
	# 不會走到視線分支，見 CombatRules.is_attack_blocked_by_los 的文件註解）。
	# 敵方 2 就站在這個被標記遮蔽的鄰格上。
	var terrain: PackedStringArray = PackedStringArray([".#............"])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var blocked: Array[Vector2i] = controller.attack_targets_blocked_by_los()

	# Assert
	assert_array(blocked).is_empty()


# ---- QA (4) 盲區格不計入第三層 ----------------------------------------------

func test_blind_spot_cell_excluded_from_third_layer() -> void:
	# Arrange — 遠程武器 (2,4)，起點 (0,0)；敵方站 (1,0)，距離 1，落在盲區內
	# （< min_range=2）。全開闊地（無遮蔽），驗證盲區格不會被誤判進第三層——
	# 它根本不屬於本查詢的定義域（在 is_in_range 這一關就先被排除），而非碰巧
	# 視線暢通。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,2,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var blocked: Array[Vector2i] = controller.attack_targets_blocked_by_los()

	# Assert
	assert_array(blocked).not_contains([Vector2i(1, 0)])


# ---- QA (5) 穿角規則沿用既有實作（AC-16 對照，交叉驗證未重新實作視線演算法）--------

func test_corner_clip_both_flanks_blocked_matches_existing_is_attack_reachable() -> void:
	# Arrange — 攻擊方 (0,0)、目標 (1,1)（曼哈頓距離 2，射線恰穿過 (0.5,0.5)
	# 頂點）；兩側 (1,0)/(0,1) 皆放倒木 → 依既有 LineOfSight 規則「兩側皆遮蔽
	# 才算擋」，應判定視線被擋。交叉核對既有 BattleState.is_attack_reachable()
	# 對同一輸入回報相反的布林值（同一份判定的兩面，而非各算各的）。
	var terrain: PackedStringArray = PackedStringArray([
		".#...........",
		"#............",
	])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,2,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,1,1",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var blocked: Array[Vector2i] = controller.attack_targets_blocked_by_los()
	var is_reachable: bool = state.is_attack_reachable(1, Vector2i(0, 0), Vector2i(1, 1))
	var is_blocked_direct: bool = state.is_attack_range_blocked_by_los(
		1, Vector2i(0, 0), Vector2i(1, 1)
	)

	# Assert
	assert_array(blocked).contains([Vector2i(1, 1)])
	assert_bool(is_reachable).is_false()
	assert_bool(is_blocked_direct).is_true()


func test_corner_clip_only_one_flank_blocked_matches_existing_is_attack_reachable() -> void:
	# Arrange — 同上座標，但只有 (1,0) 放倒木、(0,1) 保持開闊 → 依「兩側皆遮蔽
	# 才算擋」規則，單側遮蔽不足以擋住視線，應視為暢通。
	var terrain: PackedStringArray = PackedStringArray([".#..........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,2,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,1,1",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var blocked: Array[Vector2i] = controller.attack_targets_blocked_by_los()
	var is_reachable: bool = state.is_attack_reachable(1, Vector2i(0, 0), Vector2i(1, 1))

	# Assert
	assert_array(blocked).not_contains([Vector2i(1, 1)])
	assert_bool(is_reachable).is_true()
	assert_array(controller.attack_targets()).contains([Vector2i(1, 1)])


# ---- 排序：升冪 (y, x)（不手算完整期望集合，改比對「輸出 vs. 重新排序後的複本」）----

func test_output_is_sorted_ascending_by_y_then_x() -> void:
	# Arrange — 沿用測試 1 的場景（保證有至少一格落入第三層）。
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()

	# Act
	var blocked: Array[Vector2i] = controller.attack_targets_blocked_by_los()
	var resorted: Array[Vector2i] = blocked.duplicate()
	resorted.sort_custom(_tile_less)

	# Assert
	assert_bool(blocked.is_empty()).is_false()
	assert_array(blocked).is_equal(resorted)


# ---- 三種「空集合」情境（比照 battle_controller_threat_test.gd 的既有先例）--------

func test_empty_when_nothing_selected() -> void:
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var controller: BattleController = bundle["controller"]

	# Act / Assert — 沒有呼叫 select_unit()
	assert_array(controller.attack_targets_blocked_by_los()).is_empty()


func test_empty_when_attack_flag_already_consumed() -> void:
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	assert_bool(order.use_attack(1)).is_true()

	# Act / Assert
	assert_array(controller.attack_targets_blocked_by_los()).is_empty()


func test_empty_outside_player_input_phase() -> void:
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	assert_bool(controller.attack_targets_blocked_by_los().is_empty()).is_false()

	# Act — 結束玩家陣營回合,轉入 ENEMY_ACTING
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)

	# Assert
	assert_array(controller.attack_targets_blocked_by_los()).is_empty()


# ---- combat_state_version（story-003 範圍內的最小行為 — 見 battle_state.gd 該 ----
# ---- 欄位文件註解:本 story 只在 move_unit()/resolve_attack() 遞增，非完整 ADR-0001 --
# ---- 合規)------------------------------------------------------------------

func test_combat_state_version_rejects_external_write_and_leaves_value_unchanged() -> void:
	var bundle: Dictionary = _build(
		["1,P1,PLAYER,20,10,0,0,1,4,0,0", "2,E1,ENEMY,20,10,0,0,1,1,4,0"], [1], [2]
	)
	var state: BattleState = bundle["state"]
	var before: int = state.combat_state_version

	var call_external_write: Callable = func() -> void:
		state.combat_state_version = 999
	await assert_error(call_external_write).is_push_error(any_string())
	assert_int(state.combat_state_version).is_equal(before)


func test_combat_state_version_increments_exactly_once_on_successful_move() -> void:
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,3,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var before: int = state.combat_state_version

	# Act
	assert_bool(state.move_unit(1, Vector2i(3, 0))).is_true()

	# Assert
	assert_int(state.combat_state_version).is_equal(before + 1)


func test_combat_state_version_unchanged_on_rejected_move() -> void:
	# Arrange — mp=0,任何 dest 都不在 legal_moves() 內,move_unit() 應失敗且
	# 不遞增版本號(遞增只綁定「已提交的寫入」,不是每次呼叫)。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var before: int = state.combat_state_version

	# Act
	assert_bool(state.move_unit(1, Vector2i(5, 5))).is_false()

	# Assert
	assert_int(state.combat_state_version).is_equal(before)


func test_combat_state_version_increments_exactly_once_on_resolve_attack() -> void:
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,20,5,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var before: int = state.combat_state_version

	# Act
	state.resolve_attack(1, 2, 0)

	# Assert
	assert_int(state.combat_state_version).is_equal(before + 1)


func test_combat_state_version_unchanged_by_pure_query_calls() -> void:
	# Arrange — story-003 的新查詢與 attack_targets() 都是純讀取,依 ADR-0001
	# 明文「不得因唯讀操作而遞增」;select_unit() 同理(改變的是「畫哪張疊加圖」,
	# 不是任何查詢的答案)。
	var terrain: PackedStringArray = PackedStringArray(["..#.........."])
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,4,0,0",
		"2,E1,ENEMY,20,10,0,0,1,1,4,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2], terrain)
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	var before: int = state.combat_state_version

	# Act
	assert_bool(controller.select_unit(1)).is_true()
	controller.attack_targets_blocked_by_los()
	controller.attack_targets()

	# Assert
	assert_int(state.combat_state_version).is_equal(before)
