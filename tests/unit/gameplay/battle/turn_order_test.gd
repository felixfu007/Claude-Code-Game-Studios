# TurnOrder（src/gameplay/battle/turn_order.gd）的單元測試。
#
# 純狀態機、無節點 —— 不建立任何 Node，也不需要 tear-down，不會留下孤兒節點。
# 命名慣例沿用既有先例 tests/unit/gameplay/combat/combat_rules_test.gd 的
# test_[scenario]_[expected]。
extends GdUnitTestSuite


# ---- construction / faction & round progression --------------------------

func test_construction_current_faction_is_player_and_round_is_1() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1, 2], [10, 11])

	# Act / Assert
	assert_int(turn_order.current_faction()).is_equal(TurnOrder.Side.PLAYER)
	assert_int(turn_order.round_number()).is_equal(1)


func test_advance_faction_player_to_enemy_keeps_round_number() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.advance_faction()

	# Assert — player -> enemy is a half-round, round_number must not bump yet
	assert_int(turn_order.current_faction()).is_equal(TurnOrder.Side.ENEMY)
	assert_int(turn_order.round_number()).is_equal(1)


func test_advance_faction_full_round_increments_round_number() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act — player -> enemy -> player completes one full round
	turn_order.advance_faction()
	turn_order.advance_faction()

	# Assert
	assert_int(turn_order.current_faction()).is_equal(TurnOrder.Side.PLAYER)
	assert_int(turn_order.round_number()).is_equal(2)


# ---- free ordering of move / attack flags ---------------------------------

func test_attack_then_move_order_both_succeed() -> void:
	# Arrange — spec requires order freedom: attack before move must work too
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	var attack_result: bool = turn_order.use_attack(1)
	var move_result: bool = turn_order.use_move(1)

	# Assert
	assert_bool(attack_result).is_true()
	assert_bool(move_result).is_true()
	assert_bool(turn_order.can_attack(1)).is_false()
	assert_bool(turn_order.can_move(1)).is_false()


func test_using_both_flags_marks_unit_done_automatically() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.use_move(1)
	turn_order.use_attack(1)

	# Assert
	assert_bool(turn_order.is_done(1)).is_true()


func test_deferring_one_flag_leaves_unit_not_done_within_same_phase() -> void:
	# Arrange — spending only the move flag must not force the unit to
	# finish; the attack flag stays available for later the same phase.
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.use_move(1)

	# Assert
	assert_bool(turn_order.is_done(1)).is_false()
	assert_bool(turn_order.can_attack(1)).is_true()
	assert_bool(turn_order.can_move(1)).is_false()


# ---- non-current-faction units cannot act ---------------------------------

func test_non_current_faction_unit_use_move_and_use_attack_both_return_false() -> void:
	# Arrange — current faction is PLAYER; id 10 belongs to ENEMY
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	var move_result: bool = turn_order.use_move(10)
	var attack_result: bool = turn_order.use_attack(10)

	# Assert
	assert_bool(move_result).is_false()
	assert_bool(attack_result).is_false()


func test_failed_use_move_on_wrong_faction_unit_does_not_change_its_state() -> void:
	# Arrange — attempt to spend flags on an enemy unit during the player
	# phase, then advance to the enemy phase and prove nothing was spent.
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.use_move(10)
	turn_order.use_attack(10)
	turn_order.advance_faction()  # player -> enemy

	# Assert — id 10's flags must be untouched by the earlier no-op calls
	assert_bool(turn_order.can_move(10)).is_true()
	assert_bool(turn_order.can_attack(10)).is_true()


# ---- end_unit_turn ---------------------------------------------------------

func test_end_unit_turn_finishes_unit_without_using_either_flag() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	var result: bool = turn_order.end_unit_turn(1)

	# Assert
	assert_bool(result).is_true()
	assert_bool(turn_order.is_done(1)).is_true()


func test_end_unit_turn_on_wrong_faction_unit_returns_false() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	var result: bool = turn_order.end_unit_turn(10)

	# Assert
	assert_bool(result).is_false()
	assert_bool(turn_order.is_done(10)).is_false()


# ---- reset independence (the easy-to-get-wrong rule) -----------------------

func test_reset_restores_flags_for_unit_that_used_only_one_flag_and_never_ended() -> void:
	# Arrange — required case (a): partial use, no explicit end
	var turn_order: TurnOrder = TurnOrder.new([1], [10])
	turn_order.use_move(1)

	# Act — advance a full round back to the player phase
	turn_order.advance_faction()  # player -> enemy
	turn_order.advance_faction()  # enemy -> player, round 2

	# Assert
	assert_bool(turn_order.can_move(1)).is_true()
	assert_bool(turn_order.can_attack(1)).is_true()
	assert_bool(turn_order.is_done(1)).is_false()


func test_reset_restores_flags_for_unit_auto_finished_by_using_both_flags() -> void:
	# Arrange — the trap case: unit became done via both flags spent, never
	# called end_unit_turn. Reset must still apply unconditionally.
	var turn_order: TurnOrder = TurnOrder.new([1], [10])
	turn_order.use_move(1)
	turn_order.use_attack(1)
	assert_bool(turn_order.is_done(1)).is_true()  # sanity check before the act

	# Act
	turn_order.advance_faction()  # player -> enemy
	turn_order.advance_faction()  # enemy -> player, round 2

	# Assert
	assert_bool(turn_order.can_move(1)).is_true()
	assert_bool(turn_order.can_attack(1)).is_true()
	assert_bool(turn_order.is_done(1)).is_false()


func test_reset_restores_flags_for_unit_explicitly_ended_with_flags_unused() -> void:
	# Arrange — the other trap case: unit was actively ended while both
	# flags were still unspent. Reset must still apply unconditionally.
	var turn_order: TurnOrder = TurnOrder.new([1], [10])
	turn_order.end_unit_turn(1)
	assert_bool(turn_order.is_done(1)).is_true()  # sanity check before the act

	# Act
	turn_order.advance_faction()  # player -> enemy
	turn_order.advance_faction()  # enemy -> player, round 2

	# Assert
	assert_bool(turn_order.can_move(1)).is_true()
	assert_bool(turn_order.can_attack(1)).is_true()
	assert_bool(turn_order.is_done(1)).is_false()


func test_reset_also_applies_to_unit_that_took_no_action_at_all() -> void:
	# Arrange — a unit that never acted must reset the same as any other;
	# reset is unconditional, not a "recovery" from some prior action.
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.advance_faction()  # player -> enemy
	turn_order.advance_faction()  # enemy -> player, round 2

	# Assert
	assert_bool(turn_order.can_move(1)).is_true()
	assert_bool(turn_order.can_attack(1)).is_true()
	assert_bool(turn_order.is_done(1)).is_false()


# ---- units_with_flags_remaining() ------------------------------------------

func test_units_with_flags_remaining_lists_all_untouched_current_faction_units() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1, 2, 3], [10, 11])

	# Act
	var remaining: Array[int] = turn_order.units_with_flags_remaining()

	# Assert
	assert_array(remaining).contains_exactly_in_any_order([1, 2, 3])


func test_units_with_flags_remaining_excludes_finished_units() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1, 2, 3], [10, 11])
	turn_order.end_unit_turn(2)

	# Act
	var remaining: Array[int] = turn_order.units_with_flags_remaining()

	# Assert
	assert_array(remaining).contains_exactly_in_any_order([1, 3])


func test_units_with_flags_remaining_only_reports_current_faction() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10, 11])

	# Act — still the player phase
	var remaining: Array[int] = turn_order.units_with_flags_remaining()

	# Assert — enemy ids must not leak into the player phase's list
	assert_array(remaining).contains_exactly_in_any_order([1])


# ---- remove_unit() ----------------------------------------------------------

func test_remove_unit_excludes_it_from_units_with_flags_remaining() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1, 2], [10])

	# Act
	turn_order.remove_unit(1)
	var remaining: Array[int] = turn_order.units_with_flags_remaining()

	# Assert
	assert_array(remaining).contains_exactly_in_any_order([2])


func test_remove_unit_makes_is_done_report_true() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.remove_unit(1)

	# Assert — a removed unit can never take further action, so it reports done
	assert_bool(turn_order.is_done(1)).is_true()


func test_remove_unit_then_use_move_returns_false_without_error() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])
	turn_order.remove_unit(1)

	# Act
	var result: bool = turn_order.use_move(1)

	# Assert
	assert_bool(result).is_false()


func test_remove_unit_survives_faction_advance_without_reappearing() -> void:
	# Arrange — removal must be permanent, not just a per-phase suppression
	var turn_order: TurnOrder = TurnOrder.new([1, 2], [10])
	turn_order.remove_unit(1)

	# Act
	turn_order.advance_faction()  # player -> enemy
	turn_order.advance_faction()  # enemy -> player, round 2
	var remaining: Array[int] = turn_order.units_with_flags_remaining()

	# Assert
	assert_array(remaining).contains_exactly_in_any_order([2])
	assert_bool(turn_order.is_done(1)).is_true()
