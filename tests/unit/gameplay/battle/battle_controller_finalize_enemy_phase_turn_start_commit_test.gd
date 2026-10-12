## production/epics/tactical-combat/story-003c-player-turn-start-commit-wrapping.md
## (ADR-0001 path ⑥, the BattleController side): AC1 — confirms (does NOT
## change) BattleController._finalize_enemy_phase()'s existing
## commit_authoritative_change() wrapping (src/gameplay/battle/battle_
## controller.gd, written by story-003b's own AC11) already covers BOTH
## TurnOrder.advance_faction() AND BattleState.begin_player_turn() in the
## SAME outer Callable — this story's own "與 story-003b 的分工" section
## predicted this is the likely case for this driver, and reading the
## current source confirms it (_finalize_enemy_phase()'s body is exactly
## those two calls inside one commit_authoritative_change() call). NO
## production code change was made in battle_controller.gd for this story —
## this file exists to make that fact a checked, standing assertion instead
## of a one-time reading.
##
## The BattleLoop side of this story (AC2, which DID require a production
## code change) is covered by the separate file battle_loop_player_turn_
## start_commit_test.gd — see that file's header for why the spy/mutant
## technique below is duplicated here rather than shared (project convention:
## a failing test aborts the rest of its own suite, so these stay isolated;
## see commit_authoritative_change_version_test.gd's own header for the same
## reasoning already established for this test group).
##
## AC4 (path ⑦, battle_controller.gd:212's _init()-time tick_all_modifiers()
## call) is explicitly descoped in this pass — see the BattleLoop-side file's
## header for the full reasoning (symmetry with battle_loop.gd:88, which this
## story's dispatch brief predicted would need no change here either).
##
## production's only call path into _finalize_enemy_phase() via
## step_enemy_phase() is exercised here (not run_enemy_phase()) — per
## step_enemy_phase()'s own doc comment, "Production code only ever calls
## this method" (battle_screen.gd).
##
## No Node is ever constructed — BattleController's whole call chain
## (TurnOrder/BattleState/Board/Unit/CombatRules/GreedyTacticalAI) is
## RefCounted, so nothing here leaves an orphan.
extends GdUnitTestSuite


# ---- spy BattleState: records write_window_is_open() at the moment -------
# ---- begin_player_turn() is invoked, without changing its behavior -------
# ---- (duplicated from battle_loop_player_turn_start_commit_test.gd — see --
# ---- that file's header for why a plain before/after version diff cannot -
# ---- prove this story's AC1/AC2, and why this duplication is disclosed ---
# ---- rather than factored into a shared helper) ---------------------------

class _SpyStateRecordsWriteWindowAtBeginPlayerTurn extends BattleState:
	var observed_write_window_open: Array[bool] = []

	func begin_player_turn() -> void:
		observed_write_window_open.append(write_window_is_open())
		super.begin_player_turn()


# Re-implements BattleState.create()'s own body (verified identical against
# src/gameplay/battle/battle_state.gd at the time of writing) against
# `_SpyStateRecordsWriteWindowAtBeginPlayerTurn.new()` instead of
# `BattleState.new()`, because create() always returns a base BattleState.
func _create_spy_state(
	terrain_rows: PackedStringArray, roster_text: String
) -> _SpyStateRecordsWriteWindowAtBeginPlayerTurn:
	var state: _SpyStateRecordsWriteWindowAtBeginPlayerTurn = (
		_SpyStateRecordsWriteWindowAtBeginPlayerTurn.new()
	)
	state.board = Board.from_ascii(terrain_rows)
	var roster: Array[Unit] = Unit.roster_from_text(roster_text)
	for unit: Unit in roster:
		state._units[unit.id] = unit
		state._positions[unit.id] = unit.start_pos
		state.board._set_occupant(unit.start_pos, unit.id)
	state.board.attach_write_guard(Callable(state, "write_window_is_open"))
	return state


# ---- mutant: reproduces the shape this story's AC1 rules OUT for this -----
# ---- driver (the two calls split into separate commits, or one left -------
# ---- uncommitted) by overriding ONLY _finalize_enemy_phase() — everything --
# ---- else in BattleController stays the real production code -------------

class _MutantFinalizeEnemyPhaseSplitsCommits extends BattleController:
	func _finalize_enemy_phase() -> void:
		_state.commit_authoritative_change(func() -> void:
			_order.advance_faction()
		)
		_state.begin_player_turn()
		_set_phase(Phase.PLAYER_INPUT)


# ---- fixtures --------------------------------------------------------------

# One player unit, one passive enemy (mp=0, positioned out of range) — same
# "被動敵人" shape already used by battle_controller_step_enemy_phase_test.gd's
# own fixtures, chosen so step_enemy_phase() drains in exactly two calls: the
# first processes E1 (does nothing, ends its own turn), the second finds no
# unit left and triggers _finalize_enemy_phase().
func _roster_lines() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,0,0,1,1,0,0",
		"2,E1,ENEMY,20,5,0,0,1,1,5,5",
	]


func _build_state_and_order() -> Dictionary:
	var state: _SpyStateRecordsWriteWindowAtBeginPlayerTurn = _create_spy_state(
		PackedStringArray(), "\n".join(_roster_lines())
	)
	var order: TurnOrder = TurnOrder.new([1], [2])
	return {"state": state, "order": order}


# ---- AC1 / AC3: BattleController-driven ENEMY -> PLAYER transition -------

func test_finalize_enemy_phase_via_step_enemy_phase_increments_version_by_exactly_one_and_expires_modifier_in_same_call() -> void:
	# Arrange
	var bundle: Dictionary = _build_state_and_order()
	var state: _SpyStateRecordsWriteWindowAtBeginPlayerTurn = bundle["state"]
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = BattleController.new(state, order)
	# Attached AFTER construction — _init()'s own tick_all_modifiers() call
	# (path⑦, descoped, see this file's header) must not consume this turn's
	# decrement before the scenario starts.
	state.unit_by_id(1).add_modifier(CardModifier.new("test_card", 2, 0, 1))
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)

	# Act — drain the enemy phase via production's only driver.
	var first: Dictionary = controller.step_enemy_phase()
	assert_bool(bool(first["has_next"])).is_false()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	var before: int = state.combat_state_version
	var second: Dictionary = controller.step_enemy_phase()

	# Assert — outcome: phase finalized, round incremented, exactly +1.
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_bool(bool(second["has_next"])).is_false()
	assert_int(order.round_number()).is_equal(2)
	assert_int(state.combat_state_version).is_equal(before + 1)

	# Assert — AC3: the modifier attached to P1 has expired.
	assert_bool(state.unit_by_id(1).active_modifiers().is_empty()).is_true()

	# Assert — AC1, the actual structural proof: begin_player_turn() ran
	# exactly once, with the write window OPEN at that moment — i.e. inside
	# the SAME commit_authoritative_change() Callable as advance_faction(),
	# confirming story-003b's AC11 wrapping already covers this line and
	# this story needs no production code change here.
	assert_int(state.observed_write_window_open.size()).is_equal(1)
	assert_bool(state.observed_write_window_open[0]).is_true()


# ---- sensitivity proof: the structural assertion above actually detects ---
# ---- the shape this story's AC1 rules out, it is not a coincidental green -

func test_sensitivity_proof_mutant_splits_finalize_enemy_phase_into_two_commits_is_caught() -> void:
	# Arrange — identical scenario, driven by the mutant instead of the real
	# BattleController.
	var bundle: Dictionary = _build_state_and_order()
	var state: _SpyStateRecordsWriteWindowAtBeginPlayerTurn = bundle["state"]
	var order: TurnOrder = bundle["order"]
	var mutant_controller: _MutantFinalizeEnemyPhaseSplitsCommits = (
		_MutantFinalizeEnemyPhaseSplitsCommits.new(state, order)
	)
	state.unit_by_id(1).add_modifier(CardModifier.new("test_card", 2, 0, 1))
	mutant_controller.end_faction_phase()
	var first: Dictionary = mutant_controller.step_enemy_phase()
	assert_bool(bool(first["has_next"])).is_false()
	var before: int = state.combat_state_version

	# Act
	mutant_controller.step_enemy_phase()

	# Assert — documents WHY a count/outcome-only test would have missed
	# this regression: version and modifier state are identical to the
	# correct-code test above, even though this run used the split-commit
	# (ruled-out) shape.
	assert_int(mutant_controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(state.combat_state_version).is_equal(before + 1)
	assert_bool(state.unit_by_id(1).active_modifiers().is_empty()).is_true()

	# Assert — the actual catch: write_window_is_open() read FALSE at the
	# moment begin_player_turn() ran, because the mutant commits
	# advance_faction() alone and calls begin_player_turn() afterward, with
	# no open window.
	assert_int(state.observed_write_window_open.size()).is_equal(1)
	assert_bool(state.observed_write_window_open[0]).is_false()
