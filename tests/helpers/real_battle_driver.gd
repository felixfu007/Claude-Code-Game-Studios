class_name RealBattleDriver
extends RefCounted
## Test helper (story-062, 2026-11-18): the ONE shared driver that plays the REAL
## vs01 5-vs-5 battle (real BattleScreen.tscn, zero path overrides) to a terminal
## outcome or a round cap. Extracted verbatim from
## tests/integration/ui/battle/battle_screen_real_level_battle_test.gd so that the
## in-suite "can it be finished" test and the perf timing check call the SAME code
## (never two copies that can drift apart).
##
## The driver holds a reference to the calling [GdUnitTestSuite] and calls
## [code]auto_free()[/code], [code]add_child()[/code] and [code]assert_*()[/code]
## through it -- exactly as the original private helpers did via [code]self[/code] --
## so assertion semantics, failure messages and node lifetime are unchanged.
## Usage inside a suite: [code]var driver: RealBattleDriver = RealBattleDriver.new(self)[/code].
##
## Everything from [method load_battle_screen_real] downward is a pure move of the
## original private helpers (only the [code]_suite.[/code] prefix is new); their doc
## comments are kept as written on 2026-10-16.

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _suite: GdUnitTestSuite = null


func _init(suite: GdUnitTestSuite) -> void:
	_suite = suite


## The shared judgement "did this battle actually finish?". Static and suite-free so the
## in-suite test and the sensitivity proof use literally the same function.
static func is_terminal_outcome(outcome: int) -> bool:
	return outcome == BattleState.Outcome.VICTORY or outcome == BattleState.Outcome.DEFEAT


## Opening sanity (anti false-positive): real vs01 roster is 5 vs 5 and nothing has
## happened yet, so outcome() must still be ONGOING.
func assert_opening_state(instance: BattleScreen) -> void:
	_suite.assert_int(instance._state.units_of(Unit.Faction.PLAYER).size()).is_equal(5)
	_suite.assert_int(instance._state.units_of(Unit.Faction.ENEMY).size()).is_equal(5)
	_suite.assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.ONGOING)


## Plays round after round until outcome() leaves ONGOING or [param round_cap] is hit.
## Returns {round_count, outcome, elapsed_msec, player_units, enemy_units} (the unit
## arrays are the original 5+5 references captured at the start).
## [param verbose] keeps the original per-round diagnostic prints.
func run_battle(instance: BattleScreen, round_cap: int, verbose: bool = true) -> Dictionary:
	var player_units_at_start: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var enemy_units_at_start: Array[Unit] = instance._state.units_of(Unit.Faction.ENEMY)
	var round_count: int = 0
	var start_msec: int = Time.get_ticks_msec()
	if verbose:
		print("=== battle_screen_real_level_battle_test diagnostic (story-020) ===")
	while instance._controller.outcome() == BattleState.Outcome.ONGOING and round_count < round_cap:
		round_count += 1
		_resolve_any_pending_discard(instance)
		var alive_player_before: int = instance._state.units_of(Unit.Faction.PLAYER).size()
		var alive_enemy_before: int = instance._state.units_of(Unit.Faction.ENEMY).size()
		if instance._controller.phase() == BattleController.Phase.PLAYER_INPUT:
			_play_faction_turn_via_ai(instance, Unit.Faction.PLAYER)
		await instance._end_faction_phase_pressed()
		var alive_player_after: int = instance._state.units_of(Unit.Faction.PLAYER).size()
		var alive_enemy_after: int = instance._state.units_of(Unit.Faction.ENEMY).size()
		if verbose:
			print(
				"  round ", round_count,
				": PLAYER died=", alive_player_before - alive_player_after,
				" ENEMY died=", alive_enemy_before - alive_enemy_after,
				" (PLAYER alive=", alive_player_after, "/5 ENEMY alive=", alive_enemy_after, "/5)",
				" pending_discard=", instance._controller.has_pending_discard()
			)
			for u: Unit in player_units_at_start:
				if u.is_alive():
					print("    PLAYER ", u.code_name, " pos=", instance._state.position_of(u.id), " hp=", u.hp)
			for u: Unit in enemy_units_at_start:
				if u.is_alive():
					print("    ENEMY  ", u.code_name, " pos=", instance._state.position_of(u.id), " hp=", u.hp)
	var elapsed_msec: int = Time.get_ticks_msec() - start_msec
	return {
		"round_count": round_count,
		"outcome": instance._controller.outcome(),
		"elapsed_msec": elapsed_msec,
		"player_units": player_units_at_start,
		"enemy_units": enemy_units_at_start,
	}


## Shared Arrange step — loads the REAL BattleScreen.tscn with ZERO path
## overrides, so _ready() reads the production constants (TERRAIN_PATH /
## ROSTER_PATH / etc.), i.e. the real vs01 5-vs-5 level. This is the one
## deliberate difference from story-018's _load_battle_screen() helper,
## which always injects terrain_path_override / roster_path_override.
##
## story-062: renamed from the private [code]_load_battle_screen_real[/code] and given an
## optional [param mutant_script] for the sensitivity proof. [code]set_script()[/code] runs
## BEFORE [code]add_child()[/code] (Case A, safe) and before any property is touched
## (test-standards trap 1); with the default null this is identical to the original.
func load_battle_screen_real(mutant_script: Script = null) -> BattleScreen:
	var instance: BattleScreen = _suite.auto_free(load(_SCENE_PATH).instantiate())
	if mutant_script != null:
		instance.set_script(mutant_script)
	_suite.add_child(instance)
	return instance


## Story 020 AC-1/AC-2 — a TEST-ONLY safety filter layered on top of
## GreedyTacticalAI.decide()'s raw suggestion. Never a change to
## src/ai/greedy_tactical_ai.gd itself (AC-1 forbids touching src/ at all).
## Story-019 measured that driving the PLAYER faction with the unfiltered
## decider kills our squishiest unit in round 1 (丙, 22 HP / 4 DEF) because
## the decider has no concept of "this tile is also in enemy striking
## distance" — it only optimizes for "can I hit something from here".
##
## 🔴 THE RULE, IN WORDS (AC-2 requires this be readable prose, not just
## code):
## [br]
## If the decider wants to MOVE this unit to a new tile, AND that tile is
## THREATENED by at least one living enemy (see [method _threat_count] for
## what "threatened" means here), AND this turn's attack (if any) would NOT
## kill its target outright (see [method _is_lethal_attack]) — THEN discard
## the decider's move and attack entirely, and instead move this unit to
## whichever candidate tile (its own current tile, plus every tile [method
## BattleState.legal_moves] reports) is threatened by the FEWEST living
## enemies. Ties are broken by preferring to stay at the current tile;
## remaining ties among moved-to candidates are broken by (y, x)
## lexicographic order on the tile — the same deterministic tie-break shape
## [code]greedy_tactical_ai.gd[/code]'s own [code]_is_better_tile[/code]
## already uses, for the identical reason: this project's
## [code]rng_in_combat_settlement[/code] ban means no coin-flip is ever
## available to break a tie.
## [br]
## When this filter overrides the move, no attack is attempted this turn
## from the retreat tile — this filter's purpose is retreating, not
## "retreat AND still land a hit from the new position". A unit that
## retreats this turn keeps its flags unspent for next turn exactly as
## normal (see [method _play_faction_turn_via_ai]'s multi-pass loop).
## [br]
## 🔴 If the decider was not proposing to move at all ([code]move_to ==
## null[/code] — either staying put, or [param can_move] was already false
## because the move flag is spent), this filter does NOT apply, even if the
## unit's CURRENT tile is already threatened. This is a deliberate scope
## limit, not an oversight: the filter only vets a move about to be taken
## this turn. A unit that starts its turn already standing in an enemy's
## threat range (story-019 measured 戊 at (0,5) vs E4 at (7,5), distance
## exactly 7) is left exactly where [GreedyTacticalAI] already decided to
## leave it. See this file's AC-7 disclosure header for what this scope
## limit means for what this test does and does not cover.
func _apply_safety_filter(
	state: BattleState, unit_id: int, decision: Dictionary
) -> Dictionary:
	if decision["move_to"] == null:
		return decision
	var acting_unit: Unit = state.unit_by_id(unit_id)
	var enemies: Array[Unit] = state.units_of(_opposing_faction(acting_unit.faction))
	if enemies.is_empty():
		return decision
	var destination: Vector2i = decision["move_to"]
	if _threat_count(destination, enemies, state) == 0:
		return decision
	var attack_target: int = decision["attack"]
	if attack_target != -1 and _is_lethal_attack(state, unit_id, attack_target):
		return decision  # worth the exposure -- this ends the threat now

	var origin: Vector2i = state.position_of(unit_id)
	var candidates: Array[Vector2i] = state.legal_moves(unit_id)
	var safest_tile: Vector2i = origin
	var safest_count: int = _threat_count(origin, enemies, state)
	for tile: Vector2i in candidates:
		if tile == origin:
			continue
		var count: int = _threat_count(tile, enemies, state)
		if count < safest_count:
			safest_tile = tile
			safest_count = count
		elif count == safest_count and safest_tile != origin and _tile_is_before(tile, safest_tile):
			safest_tile = tile
	var overridden_move: Variant = null
	if safest_tile != origin:
		overridden_move = safest_tile
	return {"move_to": overridden_move, "attack": -1}


## Mirrors [method GreedyTacticalAI._opposing_faction] — duplicated here
## rather than reached into as a private method of a different class (its
## leading underscore marks it an implementation detail GreedyTacticalAI
## does not promise to keep stable for outside callers). Only two factions
## exist, so this is a straight flip — identical logic, intentionally kept
## in sync by inspection rather than by a shared dependency.
func _opposing_faction(faction: Unit.Faction) -> Unit.Faction:
	if faction == Unit.Faction.PLAYER:
		return Unit.Faction.ENEMY
	return Unit.Faction.PLAYER


## 🔴 APPROXIMATION, not an exact simulation of what the opposing AI will
## actually do next turn (dispatch-brief risk #2). Counts a living enemy as
## "threatening" tile if the Manhattan distance from that enemy's CURRENT
## position to tile is <= enemy.mp + enemy.max_range. This OVERESTIMATES
## true reachability in two ways: it ignores terrain movement cost (a cell
## costing more than 1 MP point to enter shrinks the true reachable radius)
## and it ignores occupancy (a blocked path can make a raw-radius tile
## actually unreachable). The overestimate direction is the SAFER one for
## this filter: it can make a unit retreat from a tile that was, in fact,
## already safe, but it can never let a unit walk somewhere genuinely
## lethal while reporting it as safe.
func _threat_count(tile: Vector2i, enemies: Array[Unit], state: BattleState) -> int:
	var count: int = 0
	for enemy: Unit in enemies:
		var enemy_pos: Vector2i = state.position_of(enemy.id)
		var distance: int = absi(enemy_pos.x - tile.x) + absi(enemy_pos.y - tile.y)
		if distance <= enemy.mp + enemy.max_range:
			count += 1
	return count


## 🔴 APPROXIMATION (dispatch-brief risk #2, second half): treats Φ (the
## affinity-driven flat damage bonus BattleScreen's real AffinityPhiProvider
## supplies in production attacks, via BattleController's private
## _compute_phi()) as always 0, rather than querying the real provider. This
## can UNDERESTIMATE a player attack's true damage whenever Φ is actually
## positive that turn, which in turn can make this filter retreat in a case
## where the real, unfiltered attack would in fact have been lethal.
## Accepted as a known imprecision of this TEST-ONLY harness — it is never
## used to decide an actual combat outcome, only to decide whether THIS
## filter lets a risky move through.
func _is_lethal_attack(state: BattleState, attacker_id: int, target_id: int) -> bool:
	var attacker: Unit = state.unit_by_id(attacker_id)
	var target: Unit = state.unit_by_id(target_id)
	var predicted_damage: int = CombatRules.damage(attacker.effective_atk(), target.effective_def(), 0)
	return predicted_damage >= target.hp


## Deterministic tile tie-break — smaller y first, then smaller x — the same
## shape [code]greedy_tactical_ai.gd[/code]'s own [code]_is_better_tile[/code]
## already uses, for the identical reason (no RNG available to break a tie).
func _tile_is_before(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## Stage C — drives a single unit's turn through the REAL BattleController
## input entry point (click_tile()), never a BattleState mutator directly
## (AC-3). The move/attack decision itself comes from GreedyTacticalAI.decide()
## (faction-agnostic — see src/ai/greedy_tactical_ai.gd's own doc comment),
## fed the can_move/can_attack flags derived from this unit's CURRENT
## TurnOrder.ActionState so the AI never tries to spend a flag already spent.
##
## 🔴 ActionState direction, confirmed by reading turn_order.gd's own doc
## comment plus the TEXT_TILE_INFO_STATE_ATTACK_ONLY / _STATE_MOVE_ONLY
## caption constants in battle_screen.gd (named for what the player can STILL
## do): ATTACK_ONLY means "attack remains, move already spent"; MOVE_ONLY
## means "move remains, attack already spent".
##
## A unit may legally move THEN attack in the same call (dispatch brief trap
## note) — click_tile()'s own _apply_move() never clears _selected_unit_id
## (read from battle_controller.gd:1493-1505), so after the move click the
## same unit is still selected and the attack click targets its NEW position's
## legal targets, not a re-selection.
##
## 🔴 story-020 AC-1/AC-2: before any click happens, [method
## _apply_safety_filter] gets a chance to override [param decision] entirely
## — see that method's own doc comment for the rule it applies, in prose.
##
## 🔴 2026-10-16 coordinator finding, same-day follow-up: [method
## BattleController.click_tile]'s [code]"selected"[/code] result is the ONLY
## branch of its contract that carries a [code]"unit_id"[/code] key — the
## real production method ([code]src/gameplay/battle/battle_controller.gd[/code]
## [method BattleController.click_tile]) returns
## [code]{"action": &"blocked_pending_discard"}[/code] with NO
## [code]"unit_id"[/code] key whenever [method
## BattleController.has_pending_discard] is true
## ([code]src/gameplay/cards/card_deck.gd[/code]'s forced-discard-gate,
## story-007). Indexing [code]select_result["unit_id"][/code]
## unconditionally after that branch is a [code]SCRIPT ERROR[/code]
## ("Invalid access to property or key"), not a controlled test failure —
## measured live: a multi-round run produced exactly this crash 900 times
## before [method _resolve_any_pending_discard] existed (see that method's
## doc comment for the fix — [method
## test_real_level_battle_reaches_a_terminal_outcome] now calls it at the
## top of every round, BEFORE any unit's turn is attempted, specifically so
## this branch should no longer be reachable in the steady state). This
## guard is kept regardless: it prints the full result Dictionary plus the
## live [method BattleController.has_pending_discard] flag so the moment
## selection ever fails for ANY reason is directly visible in the log, and
## returns [code]false[/code] rather than crash on the missing key or let
## the caller re-try forever — a cheap defense against the NEXT undiscovered
## gate of this shape, not just the one this story found.
##
## Returns [code]true[/code] if this call actually changed something
## (selected-and-moved/attacked, OR explicitly ended an idle turn via
## [method BattleController.end_unit_turn] — see the [code]did_something ==
## false[/code] branch below), [code]false[/code] if nothing happened at
## all. [method _play_faction_turn_via_ai]'s pass loop uses this return
## value to know when a faction phase has genuinely stalled, instead of the
## previous "not DONE yet" proxy that could never distinguish "still has
## work to do" from "tried and failed to do anything, forever" (see that
## method's own doc comment for the bug this replaces).
func _play_unit_turn_via_ai(instance: BattleScreen, unit_id: int) -> bool:
	var action_state: TurnOrder.ActionState = instance._controller.unit_action_state(unit_id)
	if (
		action_state == TurnOrder.ActionState.DONE
		or action_state == TurnOrder.ActionState.NOT_FOUND
	):
		return false
	var can_move: bool = (
		action_state == TurnOrder.ActionState.NONE_USED
		or action_state == TurnOrder.ActionState.MOVE_ONLY
	)
	var can_attack: bool = (
		action_state == TurnOrder.ActionState.NONE_USED
		or action_state == TurnOrder.ActionState.ATTACK_ONLY
	)
	var decision: Dictionary = GreedyTacticalAI.decide(instance._state, unit_id, can_move, can_attack)
	# story-020 AC-1/AC-2: vet the raw decision through the test-only safety
	# filter before executing anything -- see _apply_safety_filter()'s doc
	# comment for the full rule in prose.
	decision = _apply_safety_filter(instance._state, unit_id, decision)

	# AC-3: select by clicking the unit's OWN current tile first.
	var origin: Vector2i = instance._state.position_of(unit_id)
	var select_result: Dictionary = instance._controller.click_tile(origin)
	if select_result["action"] != &"selected":
		print(
			"    !! unit ", unit_id, " could not be selected -- select_result=", select_result,
			" has_pending_discard=", instance._controller.has_pending_discard()
		)
		return false
	_suite.assert_int(select_result["unit_id"]).is_equal(unit_id)

	var did_something: bool = false
	if decision["move_to"] != null:
		var move_result: Dictionary = instance._controller.click_tile(decision["move_to"])
		_suite.assert_that(move_result["action"]).is_equal(&"moved")
		did_something = true

	var attack_target: int = decision["attack"]
	if attack_target != -1:
		var target_pos: Vector2i = instance._state.position_of(attack_target)
		var attack_result: Dictionary = instance._controller.click_tile(target_pos)
		_suite.assert_that(attack_result["action"]).is_equal(&"attacked")
		did_something = true

	if not did_something:
		# story-020 AC-1/AC-2: the safety filter chose "stay put, don't
		# attack" (either the raw decision already was that, or the filter
		# overrode a risky move into one). That spends neither flag, so
		# without explicitly ending the turn here this unit would still
		# read NONE_USED next pass and _play_faction_turn_via_ai would try
		# it again, every pass, for the rest of this round -- the exact bug
		# the coordinator found (see that method's doc comment). Ending the
		# turn through the real production entry point also means this test
		# is the first to exercise BattleController.end_unit_turn() at all.
		var ended: bool = instance._controller.end_unit_turn(unit_id)
		_suite.assert_bool(ended).is_true()

	return true


## Drives every not-yet-DONE unit of faction through _play_unit_turn_via_ai(),
## repeating passes until a full pass changes nothing (handles the "moved but
## could not then attack, still has a flag left" case — see
## _play_unit_turn_via_ai's doc comment on ActionState direction). _PASS_CAP
## bounds this independently of the outer round cap so a single stuck faction
## phase cannot itself loop forever.
##
## 🔴 2026-10-16 coordinator finding, same-day follow-up: [code]acted_this_pass[/code]
## used to be set unconditionally whenever a unit was not yet DONE, regardless
## of whether [method _play_unit_turn_via_ai] actually changed anything. Once
## story-020's safety filter started legitimately choosing "stay put, don't
## attack, flags unspent" for a unit, that unit stayed NONE_USED forever (it
## never became DONE on its own), so this loop re-tried it every single pass
## up to [constant _PASS_CAP] — EVERY round, not just the ones where it
## mattered. Measured live: a 10-round run that also hit the forced-discard
## crash (see [method _play_unit_turn_via_ai]'s doc comment) produced 900
## runtime errors, matching 9 rounds (once [method
## BattleController.has_pending_discard] went true) x [constant _PASS_CAP]
## (20) x ~5 units. [method _play_unit_turn_via_ai] now returns whether it
## actually changed anything (including explicitly ending an idle unit's
## turn via [method BattleController.end_unit_turn]), and this loop uses
## THAT to decide whether another pass is worth attempting.
const _PASS_CAP: int = 20

func _play_faction_turn_via_ai(instance: BattleScreen, faction: Unit.Faction) -> void:
	var pass_count: int = 0
	while pass_count < _PASS_CAP:
		pass_count += 1
		var acted_this_pass: bool = false
		for unit: Unit in instance._state.units_of(faction):
			var action_state: TurnOrder.ActionState = instance._controller.unit_action_state(unit.id)
			if (
				action_state == TurnOrder.ActionState.DONE
				or action_state == TurnOrder.ActionState.NOT_FOUND
			):
				continue
			if _play_unit_turn_via_ai(instance, unit.id):
				acted_this_pass = true
		if not acted_this_pass:
			break


## 2026-10-16 coordinator finding, same-day second follow-up — resolves any
## owed forced discard through the REAL production entry point:
## [method BattleController.resolve_forced_discard], which delegates to
## [method BattleState.card_deck]'s [method CardDeck.discard_card] — the
## exact same call [BattleLoop]'s injected [code]discard_policy[/code] path
## also ends at, per [method BattleController.resolve_forced_discard]'s own
## doc comment ("the human-driven and simulation-driven paths converge on
## one discard implementation"). This is the correct way to clear
## [CardDeck]'s forced-discard gate (story-007-forced-discard-gate.md), not
## a workaround around it.
##
## 🔴 Without this call, NOTHING in this battle can progress past the first
## turn boundary where a discard becomes owed: [method
## BattleController.click_tile] refuses every selection
## ([code]&"blocked_pending_discard"[/code]) AND [method
## BattleController.end_faction_phase] itself no-ops while [method
## BattleController.has_pending_discard] is true (its own source line is
## literally [code]if _state.has_pending_discard(): return[/code] — it does
## not even advance [method BattleController.phase]), so BOTH factions
## freeze simultaneously, forever. story-019 never hit this because its
## battle ended inside the real game's round 1, before round 1's opening
## hand (already at [constant CardDeck.HAND_SIZE_LIMIT] — see [method
## BattleState.deal_opening_hand]'s doc comment) could ever draw past its
## limit; that can only happen starting round 2's [method
## BattleState.begin_player_turn] hook.
##
## 🔴 DETERMINISTIC choice, not optional (this project's
## [code]rng_in_combat_settlement[/code] ban, plus Determinism in
## [code].claude/rules/test-standards.md[/code]): always discards
## [code]hand[0][/code] — never a random index. The CARD IDENTITIES
## [CardDeck] actually deals are themselves NOT guaranteed deterministic
## across separate runs of this test ([code]src/ui/battle/battle_screen.gd[/code]'s
## [code]_build_card_deck(cards)[/code] call site passes no [param rng]
## argument, so [method CardDeck._init] falls back to a fresh, unseeded,
## time-seeded [RandomNumberGenerator] per its own doc comment) — but this
## is harmless for this test specifically: discarding a card only ever moves
## it out of hand ([method CardDeck.discard_card]); this test never PLAYS a
## card, so no [CardModifier] effect ever fires regardless of which card
## ends up at [code]hand[0][/code]. Only the COUNT of cards in hand (not
## their identity) determines when [method
## BattleController.has_pending_discard] becomes true, and that count is
## fully deterministic — confirmed by [code]round_count[/code],
## [code]outcome()[/code], and every unit's position/HP reading
## byte-for-byte identical across two independent reruns of this exact file
## ([code]elapsed_msec[/code] itself is the one field that differs, as
## expected for a wall-clock measurement).
##
## Bounded by [constant _FORCED_DISCARD_RESOLVE_CAP] rather than an
## unconditional [code]while[/code] loop: if [method
## BattleController.has_pending_discard] is STILL true after resolving that
## many times, something OTHER than a simple over-limit discard is holding
## the flag up — a new, different discovery, not something to paper over
## with an infinite retry. The trailing assertion makes that discovery a
## loud, named test failure instead of a silent hang.
const _FORCED_DISCARD_RESOLVE_CAP: int = 10

func _resolve_any_pending_discard(instance: BattleScreen) -> void:
	var attempts: int = 0
	while instance._controller.has_pending_discard() and attempts < _FORCED_DISCARD_RESOLVE_CAP:
		attempts += 1
		var hand: Array[Card] = instance._state.card_deck().hand()
		_suite.assert_int(hand.size()).is_greater(0)
		var resolved: bool = instance._controller.resolve_forced_discard(hand[0])
		_suite.assert_bool(resolved).is_true()
	if attempts > 0:
		print("    (resolved ", attempts, " forced discard(s) via hand[0])")
	_suite.assert_bool(instance._controller.has_pending_discard()).is_false()
