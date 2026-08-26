# CombatRules（src/gameplay/combat/combat_rules.gd）的單元測試。
#
# 純函式、無狀態、無節點 —— 不建立任何 Node，也不需要 tear-down，
# 不會留下孤兒節點。命名慣例沿用既有先例
# tests/unit/gameplay/board/line_of_sight_test.gd 的 test_[scenario]_[expected]。
extends GdUnitTestSuite


# ---- damage() ----------------------------------------------------------

func test_damage_atk12_def8_phi3_returns_7() -> void:
	# Arrange
	var atk: int = 12
	var def: int = 8
	var phi: int = 3

	# Act
	var result: int = CombatRules.damage(atk, def, phi)

	# Assert
	assert_int(result).is_equal(7)


func test_damage_def_exceeds_atk_floors_at_zero() -> void:
	# Arrange — 5 - 9 + 0 = -4，應夾在下限 0
	var atk: int = 5
	var def: int = 9
	var phi: int = 0

	# Act
	var result: int = CombatRules.damage(atk, def, phi)

	# Assert
	assert_int(result).is_equal(0)


func test_damage_with_negative_phi_subtracts_further() -> void:
	# Arrange — 10 - 3 - 2 = 5
	var atk: int = 10
	var def: int = 3
	var phi: int = -2

	# Act
	var result: int = CombatRules.damage(atk, def, phi)

	# Assert
	assert_int(result).is_equal(5)


func test_damage_negative_phi_still_floors_at_zero() -> void:
	# Arrange — 4 - 4 - 1 = -1，應夾在下限 0
	var atk: int = 4
	var def: int = 4
	var phi: int = -1

	# Act
	var result: int = CombatRules.damage(atk, def, phi)

	# Assert
	assert_int(result).is_equal(0)


# ---- enemy_stat() -------------------------------------------------------

func test_enemy_stat_baseline12_advantage20pct_rounds_up() -> void:
	# Arrange — 12 * 1.20 = 14.4，ceili 後為 15
	var player_baseline: int = 12
	var advantage_pct: float = 0.20

	# Act
	var result: int = CombatRules.enemy_stat(player_baseline, advantage_pct)

	# Assert
	assert_int(result).is_equal(15)


func test_enemy_stat_baseline10_advantage20pct_exact_value_not_bumped() -> void:
	# Arrange — 10 * 1.20 = 12.0（整數邊界），ceili 不應再往上多加 1
	var player_baseline: int = 10
	var advantage_pct: float = 0.20

	# Act
	var result: int = CombatRules.enemy_stat(player_baseline, advantage_pct)

	# Assert
	assert_int(result).is_equal(12)


# ---- is_in_range() -------------------------------------------------------

func test_is_in_range_at_min_boundary_is_true() -> void:
	# Arrange — 距離恰為 min_range=2
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(2, 0)

	# Act
	var result: bool = CombatRules.is_in_range(from, to, 2, 4)

	# Assert
	assert_bool(result).is_true()


func test_is_in_range_at_max_boundary_is_true() -> void:
	# Arrange — 距離恰為 max_range=4
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(4, 0)

	# Act
	var result: bool = CombatRules.is_in_range(from, to, 2, 4)

	# Assert
	assert_bool(result).is_true()


func test_is_in_range_beyond_max_is_false() -> void:
	# Arrange — 距離 5，超出 max_range=4
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(5, 0)

	# Act
	var result: bool = CombatRules.is_in_range(from, to, 2, 4)

	# Assert
	assert_bool(result).is_false()


func test_is_in_range_below_min_is_false() -> void:
	# Arrange — 距離 1，低於 min_range=2
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(1, 0)

	# Act
	var result: bool = CombatRules.is_in_range(from, to, 2, 4)

	# Assert
	assert_bool(result).is_false()


func test_is_in_range_distance_zero_is_always_false() -> void:
	# Arrange — 打自己（距離 0），即使 min_range 允許 0 也一律 false
	var from: Vector2i = Vector2i(3, 3)
	var to: Vector2i = Vector2i(3, 3)

	# Act
	var result: bool = CombatRules.is_in_range(from, to, 0, 5)

	# Assert
	assert_bool(result).is_false()


# ---- is_attack_legal() ---------------------------------------------------

func test_is_attack_legal_melee_distance1_ignores_occlusion() -> void:
	# Arrange — 距離 1（貼身），is_occluding 恆回 true，證明近戰不查視線
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(1, 0)
	var always_occluding: Callable = func(_cell: Vector2i) -> bool:
		return true

	# Act
	var result: bool = CombatRules.is_attack_legal(from, to, 1, 3, always_occluding)

	# Assert
	assert_bool(result).is_true()


func test_is_attack_legal_distance2_occluded_is_false() -> void:
	# Arrange — 距離 2，中繼格 (1,0) 遮蔽，視線不通
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(2, 0)
	var occluding_midpoint: Callable = func(cell: Vector2i) -> bool:
		return cell == Vector2i(1, 0)

	# Act
	var result: bool = CombatRules.is_attack_legal(from, to, 1, 5, occluding_midpoint)

	# Assert
	assert_bool(result).is_false()


func test_is_attack_legal_distance2_clear_is_true() -> void:
	# Arrange — 距離 2，同一條路徑但沿線無遮蔽
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(2, 0)
	var never_occluding: Callable = func(_cell: Vector2i) -> bool:
		return false

	# Act
	var result: bool = CombatRules.is_attack_legal(from, to, 1, 5, never_occluding)

	# Assert
	assert_bool(result).is_true()


func test_is_attack_legal_out_of_range_is_false_regardless_of_occlusion() -> void:
	# Arrange — 距離 10 超出 max_range=3，即使視線通透也應為 false
	var from: Vector2i = Vector2i(0, 0)
	var to: Vector2i = Vector2i(10, 0)
	var never_occluding: Callable = func(_cell: Vector2i) -> bool:
		return false

	# Act
	var result: bool = CombatRules.is_attack_legal(from, to, 1, 3, never_occluding)

	# Assert
	assert_bool(result).is_false()
