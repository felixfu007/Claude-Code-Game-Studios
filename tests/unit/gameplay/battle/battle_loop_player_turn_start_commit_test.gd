## production/epics/tactical-combat/story-003c-player-turn-start-commit-wrapping.md
## (ADR-0001 path ⑥, the BattleLoop side): covers
## BattleLoop._advance_faction_and_start_next_turn() — the merged
## commit_authoritative_change() Callable that now wraps BOTH
## TurnOrder.advance_faction() (battle_loop.gd:119 in story-003b's own path⑤
## numbering) AND BattleState.begin_player_turn() (battle_loop.gd:152 before
## this story) in the SAME outer commit, gated on the transition landing on
## TurnOrder.Side.PLAYER.
##
## AC1 (the BattleController side of this story — confirming
## _finalize_enemy_phase() already wraps both calls, no production code
## change needed there) is covered by the SEPARATE file
## battle_controller_finalize_enemy_phase_turn_start_commit_test.gd, per this
## project's "a failing test aborts the rest of its own suite" isolation
## convention (already established by commit_authoritative_change_version_
## test.gd's own header) and per this story's Affected Files note that the
## two drivers may use separate test files.
##
## 🔴 AC4 (path ⑦ — wrapping each driver's _init()-time tick_all_modifiers()
## call, battle_loop.gd:88 / battle_controller.gd:212, in its own independent
## commit) is explicitly marked "建議,可 descope" in the story and is
## DESCOPED in this pass — not implemented, not tested here. Reasoning
## (flagged for the dispatch owner to confirm, not a silent decision): this
## story's dispatch brief explicitly scopes battle_controller.gd as
## "predicted to need no change"; wrapping ONLY battle_loop.gd:88 while
## leaving battle_controller.gd:212 unwrapped would make the two otherwise-
## symmetric drivers behave asymmetrically for the identical construction-
## time event, for zero observable benefit today (both call sites' own doc
## comments confirm no modifier can exist yet at construction time in current
## gameplay — still verified true as of this change, since nothing in this
## story attaches a modifier before either constructor returns). Consequently
## Validation Criteria 4m's "不論經由 ENEMY→PLAYER 轉換或建構期一次性呼叫觸發"
## clause is only evidenced here for the ENEMY→PLAYER transition half, not
## the construction-time half.
##
## ---- Why a spy BattleState subclass, not just a before/after version diff
## ----
##
## A plain "combat_state_version went up by exactly 1, and the modifier is
## gone afterward" assertion CANNOT distinguish the fixed code from the
## pre-story-003c gap: begin_player_turn() touches no guarded Board/TurnOrder
## mutator, so calling it OUTSIDE the commit window (the old, buggy shape)
## produces the exact same version delta (+1, from advance_faction() alone)
## and the exact same end-state (modifier still expires, since
## begin_player_turn() still runs, just not inside the window) as calling it
## INSIDE the window (the fixed shape). The only place the two shapes
## actually differ is WHETHER BattleState.write_window_is_open() reads true
## at the exact moment begin_player_turn() is invoked — which is only
## observable from inside that call, hence the spy override below. Both
## test_sensitivity_proof_* functions in this file demonstrate this
## explicitly (see their own Assert sections) rather than just asserting it
## in prose here.
##
## 🔴 The spy subclass's _create_spy_state() factory re-implements
## BattleState.create()'s own ~5-line body (src/gameplay/battle/battle_state.
## gd, the create() static method) rather than calling it, because create()
## hardcodes `BattleState.new()` — there is no seam that lets a subclass hook
## into it. This is NOT a re-derivation of a game rule (the
## .claude/docs/technical-preferences.md "(A) 的精確定義" caution this
## project applies to analysis scripts does not apply to ordinary GDScript
## test-fixture construction) — it is the same five lines, copied verbatim,
## so the spy subclass can exist at all. Kept intentionally tiny and
## side-by-side-diffable against the original for exactly this reason.
##
## Mutant-subclass technique (overriding a private method from a different
## script file) follows the established project convention — see
## battle_controller_step_enemy_phase_test.gd's _Mutant* classes, which do
## the same thing against BattleController's own underscore-prefixed methods
## and fields.
##
## No Node is ever constructed — BattleLoop's whole call chain (TurnOrder/
## BattleState/Board/Unit/CombatRules) is RefCounted, so nothing here leaves
## an orphan.
extends GdUnitTestSuite


# ---- spy BattleState: records write_window_is_open() at the moment -------
# ---- begin_player_turn() is invoked, without changing its behavior -------

class _SpyStateRecordsWriteWindowAtBeginPlayerTurn extends BattleState:
	var observed_write_window_open: Array[bool] = []

	func begin_player_turn() -> void:
		observed_write_window_open.append(write_window_is_open())
		super.begin_player_turn()


# Re-implements BattleState.create()'s own body (verified identical against
# src/gameplay/battle/battle_state.gd at the time of writing — re-check that
# method if this ever stops compiling) against `_SpyStateRecordsWriteWindow
# AtBeginPlayerTurn.new()` instead of `BattleState.new()`, because create()
# itself always returns a base BattleState. See this file's header for why
# this duplication is disclosed rather than hidden.
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


# ---- mutant: reproduces the pre-story-003c gap (begin_player_turn() left --
# ---- outside the commit window) by overriding ONLY the extracted helper ---
# ---- method, so everything else in BattleLoop.run() stays the real code --

class _MutantCallsBeginPlayerTurnOutsideCommitWindow extends BattleLoop:
	func _advance_faction_and_start_next_turn() -> void:
		_state.commit_authoritative_change(func() -> void:
			_order.advance_faction()
		)
		if _order.current_faction() == TurnOrder.Side.PLAYER:
			_state.begin_player_turn()


# ---- fixtures --------------------------------------------------------------

# Same roster/decide shape as commit_authoritative_change_version_test.gd's
# test_4j (deliberately — that test already establishes the +4-commits-per-
# round baseline this story must not disturb): 1 player unit (DEF=100, so
# enemy attacks always deal 0 damage and never end the battle early) and 2
# enemy units that both always attack player 1 when able. max_rounds=1 makes
# BattleLoop.run() abort right after round_number() becomes 2, i.e.
# immediately after the ENEMY -> PLAYER transition this story's AC2/AC3
# target.
func _roster_lines() -> Array[String]:
	return [
		"1,P1,PLAYER,20,0,100,0,1,1,0,0",
		"2,E1,ENEMY,20,5,0,0,1,1,1,0",
		"3,E2,ENEMY,20,5,0,0,1,1,0,1",
	]


func _always_attack_player_1(
	s: BattleState, unit_id: int, _can_move: bool, can_attack: bool
) -> Dictionary:
	var unit: Unit = s.unit_by_id(unit_id)
	if unit.faction == Unit.Faction.ENEMY and can_attack:
		return {"move_to": null, "attack": 1}
	return {"move_to": null, "attack": -1}


# ---- AC2 / AC3: BattleLoop-driven ENEMY -> PLAYER transition -------------

func test_enemy_to_player_transition_via_battle_loop_increments_version_by_exactly_one_and_expires_modifier_in_same_call() -> void:
	# Arrange — attach a 1-remaining-turn CardModifier to P1 AFTER
	# constructing BattleLoop (construction time's own tick_all_modifiers()
	# call, AC4/path⑦, is out of scope here and must not consume this turn's
	# decrement before the scenario even starts — see this file's header).
	var state: _SpyStateRecordsWriteWindowAtBeginPlayerTurn = _create_spy_state(
		PackedStringArray(), "\n".join(_roster_lines())
	)
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var loop: BattleLoop = BattleLoop.new(
		state, order, Callable(self, "_always_attack_player_1")
	)
	state.unit_by_id(1).add_modifier(CardModifier.new("test_card", 2, 0, 1))
	var before: int = state.combat_state_version

	# Act
	var result: Dictionary = loop.run(1)

	# Assert — behavior unchanged from test_4j's own baseline (+4 total: PLAYER
	# batch, PLAYER->ENEMY advance_faction, ENEMY batch, ENEMY->PLAYER
	# advance_faction+begin_player_turn merged) — see this file's header for
	# why the total count alone cannot prove AC2 by itself.
	assert_bool(bool(result["aborted"])).is_true()
	assert_str(String(result["abort_reason"])).is_equal("max_rounds_reached")
	assert_int(order.round_number()).is_equal(2)
	assert_int(state.combat_state_version).is_equal(before + 4)

	# Assert — AC3: the modifier attached to P1 has expired (remaining_turns
	# started at 1, ticked once by begin_player_turn() during the
	# ENEMY -> PLAYER transition).
	assert_bool(state.unit_by_id(1).active_modifiers().is_empty()).is_true()

	# Assert — AC2, the actual structural proof: begin_player_turn() was
	# invoked exactly once (not on the PLAYER -> ENEMY leg, correctly gated
	# out), and the write window was OPEN at that exact moment — i.e. it ran
	# inside the same commit_authoritative_change() Callable as
	# advance_faction(), not after it closed.
	assert_int(state.observed_write_window_open.size()).is_equal(1)
	assert_bool(state.observed_write_window_open[0]).is_true()


# ---- sensitivity proof: the structural assertion above actually detects ---
# ---- the pre-story-003c gap, it is not a coincidental green ---------------

func test_sensitivity_proof_mutant_leaves_begin_player_turn_outside_commit_window_is_caught() -> void:
	# Arrange — identical scenario, driven by the mutant instead of the real
	# BattleLoop.
	var state: _SpyStateRecordsWriteWindowAtBeginPlayerTurn = _create_spy_state(
		PackedStringArray(), "\n".join(_roster_lines())
	)
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var mutant_loop: _MutantCallsBeginPlayerTurnOutsideCommitWindow = (
		_MutantCallsBeginPlayerTurnOutsideCommitWindow.new(
			state, order, Callable(self, "_always_attack_player_1")
		)
	)
	state.unit_by_id(1).add_modifier(CardModifier.new("test_card", 2, 0, 1))
	var before: int = state.combat_state_version

	# Act
	var result: Dictionary = mutant_loop.run(1)

	# Assert — documents WHY a count/outcome-only test would have missed this
	# regression: both are identical to the fixed-code test above, even
	# though this run used the pre-story-003c (buggy) shape.
	assert_bool(bool(result["aborted"])).is_true()
	assert_int(state.combat_state_version).is_equal(before + 4)
	assert_bool(state.unit_by_id(1).active_modifiers().is_empty()).is_true()

	# Assert — the actual catch: write_window_is_open() read FALSE at the
	# moment begin_player_turn() ran, because the mutant's override commits
	# advance_faction() alone and calls begin_player_turn() afterward, with
	# no open window. A regression shaped like this mutant is exactly what
	# the structural assertion in the test above would turn red for.
	assert_int(state.observed_write_window_open.size()).is_equal(1)
	assert_bool(state.observed_write_window_open[0]).is_false()


# ---- regression guard: PLAYER -> ENEMY leg must still be gated out --------

func test_player_to_enemy_transition_does_not_call_begin_player_turn() -> void:
	# Arrange — same scenario, but stop the battle (max_rounds=0, aborts on
	# the very first round_number() > max_rounds check, which fires AFTER
	# round 1 completes) is not useful here since the ENEMY->PLAYER leg still
	# fires within round 1 before the abort check is next reached. Instead,
	# directly exercise only the PLAYER->ENEMY leg via the private helper,
	# the same way this story's production code reaches it.
	var state: _SpyStateRecordsWriteWindowAtBeginPlayerTurn = _create_spy_state(
		PackedStringArray(), "\n".join(_roster_lines())
	)
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var loop: BattleLoop = BattleLoop.new(
		state, order, Callable(self, "_always_attack_player_1")
	)
	# order starts on PLAYER with both flags available for unit 1; spend them
	# both so units_with_flags_remaining() is empty and the transition fires.
	# Wrapped in its own commit_authoritative_change() because TurnOrder's
	# mutators are guarded (story-003b) and reject a call made with no write
	# window open — mirrors the white-box setup technique already used by
	# commit_authoritative_change_version_test.gd's own 4l tests.
	state.commit_authoritative_change(func() -> void:
		order.use_move(1)
		order.use_attack(1)
	)
	assert_bool(order.units_with_flags_remaining().is_empty()).is_true()

	# Act — invoke the same private helper run() calls for this branch.
	loop._advance_faction_and_start_next_turn()

	# Assert — current_faction() is now ENEMY, so begin_player_turn() must
	# not have been called at all (not even outside a window).
	assert_int(order.current_faction()).is_equal(TurnOrder.Side.ENEMY)
	assert_int(state.observed_write_window_open.size()).is_equal(0)
