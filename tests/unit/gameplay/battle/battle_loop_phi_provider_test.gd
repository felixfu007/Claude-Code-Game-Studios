# Story 021 (production/epics/tactical-combat/story-021-battle-loop-phi-provider.md):
# BattleLoop's optional phi_provider. Unit tests, no Node, no file I/O; rosters
# are in-test text. Expected damage always comes from BattleState.preview_damage()
# on a twin state, never from a hand-written formula.
#
# AC4 rule (from BattleController): Φ applies to PLAYER attackers only; enemy
# attacks always use 0 and never consult the provider.
extends GdUnitTestSuite


# Player atk 50 / enemy atk 30, both def 0, adjacent, hp large enough to survive.
const _ROSTER: Array[String] = [
	"1,P1,PLAYER,1000,50,0,0,1,1,0,0",
	"2,E1,ENEMY,1000,30,0,0,1,1,1,0",
]
const _PHI_N: int = 7


class _MutantZeroPhi extends BattleLoop:
	func _compute_phi(_attacker_id: int, _target_id: int) -> int:
		return 0


func _both_attack() -> Callable:
	return func(_s: BattleState, unit_id: int, _cm: bool, _ca: bool) -> Dictionary:
		return {"move_to": null, "attack": 2 if unit_id == 1 else 1}


func _make_state() -> BattleState:
	return BattleState.create(PackedStringArray(), "\n".join(_ROSTER))


# Runs one round (player attacks, enemy attacks) and returns [player_dmg_taken, enemy_dmg_taken].
func _run_round(loop: BattleLoop, state: BattleState) -> Array[int]:
	var p_before: int = state.unit_by_id(1).hp
	var e_before: int = state.unit_by_id(2).hp
	loop.run(1)
	return [p_before - state.unit_by_id(1).hp, e_before - state.unit_by_id(2).hp]


func test_default_no_provider_uses_zero_phi() -> void:
	var state: BattleState = _make_state()
	var expected: int = state.preview_damage(1, 2, 0).damage
	var loop := BattleLoop.new(state, TurnOrder.new([1], [2]), _both_attack())

	var taken: Array[int] = _run_round(loop, state)

	assert_int(taken[1]).is_equal(expected)


func test_provider_phi_is_applied_to_player_attack() -> void:
	var state: BattleState = _make_state()
	var with_phi: int = state.preview_damage(1, 2, _PHI_N).damage
	var without_phi: int = state.preview_damage(1, 2, 0).damage
	var provider: Callable = func(_a: int, _t: int) -> int: return _PHI_N
	var loop := BattleLoop.new(
		state, TurnOrder.new([1], [2]), _both_attack(), null, Callable(), provider
	)

	var taken: Array[int] = _run_round(loop, state)

	assert_int(without_phi).is_not_equal(with_phi)  # fixture must make Φ observable
	assert_int(taken[1]).is_equal(with_phi)


func test_provider_receives_attacker_and_target_ids() -> void:
	var state: BattleState = _make_state()
	var calls: Array = []
	var provider: Callable = func(a: int, t: int) -> int:
		calls.append([a, t])
		return 0
	var loop := BattleLoop.new(
		state, TurnOrder.new([1], [2]), _both_attack(), null, Callable(), provider
	)

	loop.run(1)

	assert_array(calls).is_equal([[1, 2]])  # player only; enemy never consults it


func test_enemy_attack_ignores_provider_like_battle_controller() -> void:
	var state: BattleState = _make_state()
	var enemy_expected: int = state.preview_damage(2, 1, 0).damage
	var provider: Callable = func(_a: int, _t: int) -> int: return _PHI_N
	var loop := BattleLoop.new(
		state, TurnOrder.new([1], [2]), _both_attack(), null, Callable(), provider
	)

	var taken: Array[int] = _run_round(loop, state)

	assert_int(taken[0]).is_equal(enemy_expected)


func test_invalid_provider_callable_falls_back_to_zero() -> void:
	var state: BattleState = _make_state()
	var expected: int = state.preview_damage(1, 2, 0).damage
	var dead_target := RefCounted.new()
	var bad: Callable = Callable(dead_target, "no_such_method")
	var loop := BattleLoop.new(
		state, TurnOrder.new([1], [2]), _both_attack(), null, Callable(), bad
	)
	# Callable on a live object with a missing method is_valid() == false.
	assert_bool(bad.is_valid()).is_false()

	var taken: Array[int] = _run_round(loop, state)

	assert_int(taken[1]).is_equal(expected)


# Sensitivity proof: a loop that always uses phi 0 must fail the AC3 assertion
# that test_provider_phi_is_applied_to_player_attack makes.
func test_sensitivity_proof_zero_phi_mutant_is_detected() -> void:
	var state: BattleState = _make_state()
	var with_phi: int = state.preview_damage(1, 2, _PHI_N).damage
	var provider: Callable = func(_a: int, _t: int) -> int: return _PHI_N
	var mutant := _MutantZeroPhi.new(
		state, TurnOrder.new([1], [2]), _both_attack(), null, Callable(), provider
	)

	var taken: Array[int] = _run_round(mutant, state)

	assert_int(taken[1]).is_not_equal(with_phi)
