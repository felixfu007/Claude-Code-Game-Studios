## Adapter that satisfies [BattleController]'s [code]phi_provider: Callable[/code]
## contract (signature [code]func(attacker_id: int, target_id: int) -> int[/code])
## by reading live positions out of a [BattleState] and a live pairing table out
## of an [AffinityDataPool], handing both to [AffinityRules]. This is the object
## that turns Φ from "always 0 because nothing calls the affinity math" into
## "the attacker's real positional bonus."
##
## Pure state-reading math — no RNG, no [FileAccess], no node access, no
## autoloads. Combat settlement in this project is RNG-free by project-level
## rule ([code]rng_in_combat_settlement[/code] in
## [code].claude/docs/technical-preferences.md[/code]), and Φ feeds that
## settlement, so this adapter must stay exactly as deterministic as
## [AffinityRules] itself.
##
## [b]The owner MUST keep a strong reference to an instance of this class.[/b]
## [method BattleController._compute_phi] re-checks [method Callable.is_valid]
## immediately before every single attack rather than caching the result —
## and a [Callable] bound to a [RefCounted] instance method does
## [b]not[/b] keep that instance alive. If the last strong reference to an
## [AffinityPhiProvider] is dropped, the [Callable] silently goes invalid and
## Φ silently degrades back to a constant 0, with no error and no signal —
## exactly the "stale value from before it broke" failure mode
## [member BattleController._phi_provider]'s own doc comment warns against.
## See [code]docs/engine-reference/godot/modules/scripting-typing.md[/code]
## section 6 ("Callable 綁定 RefCounted 實例方法的生命週期") for the measured
## engine behavior this warning is based on: [code]is_valid()[/code] correctly
## reports [code]false[/code] once the bound object is gone, but
## [code]get_method()[/code] keeps returning the method name regardless, so it
## must never be used as a liveness check.
##
## 🔴 story-005 (production/epics/affinity-position-chain/
## story-005-pairing-data-per-query-refetch.md) — pairing data is no longer
## read once at construction and frozen. The old frozen
## [code]_links: Array[AffinityLink][/code] field (assigned once in
## [code]_init()[/code], documented "fixed for the provider's lifetime") is
## GONE. [method links] now rebuilds the pairing table fresh from
## [member _pool] on every single call, exactly like [method positions]
## already rebuilds positions from [member _state] on every call — see
## [method links]/[method _link_for_pair]'s own doc comments for the per-pair
## query/degrade decision tree (裁決 4, 2026-09-29 manager ruling).
class_name AffinityPhiProvider
extends RefCounted

# The battle this provider reads positions from. Never mutated here — every
# public method only reads.
var _state: BattleState

## The live pairing data source this provider queries fresh on every single
## [method links]/[method phi] call — [b]never cached[/b] (story-005). This
## is the same [AffinityDataPool] instance [BattleScreen] wraps in an
## [AffinityPoolWritePort] for card-play writes; this provider only ever
## reads from it via [method AffinityDataPool.combat_strength_read].
var _pool: AffinityDataPool

## Diagnostic-only counters — business logic never reads either field; they
## exist purely so a test can observe "did a degrade path fire at all"
## without scraping stdout for a [method @GlobalScope.push_warning] call.
## See [method _link_for_pair]'s doc comment for what increments each one and
## why they are logged at different severities.
var _diagnostic_rejected_pair_count: int = 0
var _diagnostic_zero_value_pair_count: int = 0


## Builds a provider over an already-constructed [param state] and [param pool]
## — the live [AffinityDataPool] this battle's card-play writes land in.
## Neither argument is copied or duplicated; both are consulted fresh on
## every single [method positions]/[method links] call — this provider never
## freezes a snapshot of either at construction time (story-005).
func _init(state: BattleState, pool: AffinityDataPool) -> void:
	_state = state
	_pool = pool


## Diagnostic-only accessor for [member _diagnostic_rejected_pair_count] —
## see that field's doc comment. Not business logic.
func diagnostic_rejected_pair_count() -> int:
	return _diagnostic_rejected_pair_count


## Diagnostic-only accessor for [member _diagnostic_zero_value_pair_count] —
## see that field's doc comment. Not business logic.
func diagnostic_zero_value_pair_count() -> int:
	return _diagnostic_zero_value_pair_count


## Rebuilds the pairing table FRESH from [member _pool] on every single
## call — [b]never cached[/b] (story-005; see this class's own header
## comment for what this replaces, and the registry interface contract
## [code]affinity_pairing_data_per_query_refetch[/code] this method exists
## to satisfy).
##
## Candidate pairs are every two-combination of currently ALIVE on-board
## PLAYER units ([method BattleState.units_of] already excludes the dead —
## see [method positions]'s own doc comment for the same guarantee on the
## position side). Converting a roster id to an [enum AffinityTypes.Character]
## goes through [AffinityRosterCharacterMapper] ([code]src/gameplay/affinity/
## affinity_roster_character_mapper.gd[/code], story-004), which already
## rejects enemy roster ids (6~10) and any out-of-range input before this
## method ever builds an [enum AffinityTypes.Pair] from it — a failed
## conversion is skipped rather than treated as a pairing.
##
## For each candidate pair, [method _link_for_pair] performs the actual query
## against [member _pool] and the full query/degrade decision tree (裁決 4 +
## the OQ-3 value==0.0 edge case) — see that method's own doc comment.
func links() -> Array[AffinityLink]:
	var result: Array[AffinityLink] = []
	var player_units: Array[Unit] = _state.units_of(Unit.Faction.PLAYER)
	for i in range(player_units.size()):
		for j in range(i + 1, player_units.size()):
			var unit_a: Unit = player_units[i]
			var unit_b: Unit = player_units[j]
			var character_a_variant: Variant = (
				AffinityRosterCharacterMapper.character_for_roster_id(unit_a.id)
			)
			var character_b_variant: Variant = (
				AffinityRosterCharacterMapper.character_for_roster_id(unit_b.id)
			)
			if character_a_variant == null or character_b_variant == null:
				continue
			var character_a: AffinityTypes.Character = character_a_variant
			var character_b: AffinityTypes.Character = character_b_variant
			var pair: AffinityTypes.Pair = AffinityTypes.pair_of(character_a, character_b)
			var link: Variant = _link_for_pair(unit_a.id, unit_b.id, pair)
			if link != null:
				result.append(link)
	return result


## Queries [member _pool] for one candidate pair and turns the result into
## the [AffinityLink] [method links] should include for it this call, or
## [code]null[/code] if this pair should not produce a line at all right now.
## This is the single place every "rejected / n_pair==0 / value==0.0" branch
## from this story's Implementation Notes lives — [method links] never
## re-derives any of this logic per-pair itself.
##
## Three distinct "no line" outcomes, each a different branch below:
##
## 1. [member AffinityDataPool.AffinityReadResult.rejection] is anything other
##    than [constant AffinityDataPool.ReadRejection.NONE] — 裁決 4
##    (2026-09-29 manager ruling). Structurally only reachable if THIS CLASS
##    built [param pair] wrong (an engineering error — [method links]'s own
##    candidate-pair construction only ever feeds it currently-alive player
##    units, so this is never a legal game state reachable through normal
##    play). Contribution is 0, no exception is raised, and
##    [method @GlobalScope.push_warning] records which pair and which
##    rejection code — loud enough to be noticed during development, never
##    shown to the player (this class never touches any UI).
##    [member _diagnostic_rejected_pair_count] is incremented so a test can
##    observe this happened without scraping stdout.
## 2. [member AffinityDataPool.AffinityReadResult.n_pair] is [code]0[/code] —
##    a completely legal "these two have never interacted" state (GDD
##    [code]design/gdd/affinity-data-pool.md[/code] Edge Cases on
##    [code]n(p)=0[/code]). No line at all is produced — matching
##    [method AffinityRules.lines_for_at]'s own existing "absent partner ->
##    no entry" behavior for a dead/off-board unit.
## 3. [member AffinityDataPool.AffinityReadResult.value] is exactly
##    [code]0.0[/code] while [member AffinityDataPool.AffinityReadResult.n_pair]
##    is greater than [code]0[/code] — this story's own 🔴 UNRESOLVED open
##    question (see this story's markdown file, "⚠️ 待決問題"): real
##    interactions exist but happen to net to zero, which carries no sign to
##    derive a polarity from. [b]This branch follows the story AUTHOR's own
##    suggested — NOT management-approved — resolution[/b] (reuse 裁決 4's
##    degrade mechanism: contribution 0, no line), logged via
##    [member _diagnostic_zero_value_pair_count] at a deliberately quieter
##    level than branch 1 (no [method @GlobalScope.push_warning] call — this
##    is a legal game state, not an engineering error). [b]Whoever next
##    touches this method must confirm this has since been ruled on by a
##    manager or systems-designer before treating it as settled.[/b]
func _link_for_pair(
	unit_a_id: int, unit_b_id: int, pair: AffinityTypes.Pair
) -> Variant:
	var result: AffinityDataPool.AffinityReadResult = _pool.combat_strength_read(pair)
	if result.rejection != AffinityDataPool.ReadRejection.NONE:
		push_warning(
			(
				"AffinityPhiProvider._link_for_pair: combat_strength_read() rejected pair "
				+ "(unit %d, unit %d) with rejection code %d -- this pair should never have "
				+ "been constructed from currently-alive player units, so this is almost "
				+ "certainly a bug in this class's own pair-building logic, not a legal game "
				+ "state. Contribution treated as 0 (裁決 4)."
			) % [unit_a_id, unit_b_id, result.rejection]
		)
		_diagnostic_rejected_pair_count += 1
		return null

	if result.n_pair == 0:
		return null

	var link: AffinityLink = AffinityLink.new()
	link.unit_a = unit_a_id
	link.unit_b = unit_b_id
	link.amp = AffinityLink.AMP_EXPECTED
	if result.value > 0.0:
		link.polarity = AffinityLink.Polarity.POSITIVE
	elif result.value < 0.0:
		link.polarity = AffinityLink.Polarity.NEGATIVE
	else:
		_diagnostic_zero_value_pair_count += 1
		return null
	return link


## Snapshots the current cell of every ALIVE unit of both factions, keyed by
## roster id. Rebuilt from [member _state] on every single call —
## [b]never cached[/b]. [AffinityRules] treats absence from this dictionary
## as "dead or off the board" and skips every link to that id accordingly
## ([method AffinityRules.bonus_for]'s own doc comment), so a stale snapshot
## would keep granting a bonus from a corpse's last known position.
func positions() -> Dictionary[int, Vector2i]:
	var result: Dictionary[int, Vector2i] = {}
	for unit: Unit in _state.units_of(Unit.Faction.PLAYER):
		result[unit.id] = _state.position_of(unit.id)
	for unit: Unit in _state.units_of(Unit.Faction.ENEMY):
		result[unit.id] = _state.position_of(unit.id)
	return result


## Same as [method positions], except [param unit_id] is mapped to
## [param origin] instead of its real current cell. This is the "what if this
## unit stood here" hypothesis the cursor preview draws from — [param unit_id]
## does not need to currently be on the board (matching
## [method AffinityRules.bonus_for_at]'s own contract). Every other unit's
## entry is untouched.
func positions_with(unit_id: int, origin: Vector2i) -> Dictionary[int, Vector2i]:
	var result: Dictionary[int, Vector2i] = positions()
	result[unit_id] = origin
	return result


## Satisfies [BattleController]'s [code]phi_provider: Callable[/code]
## contract. Returns [param attacker_id]'s current affinity bonus via
## [method AffinityRules.bonus_for], evaluated against a freshly rebuilt
## [method positions] snapshot AND a freshly rebuilt [method links] pairing
## table (story-005 — both inputs are now the same freshness level).
## [param _target_id] is deliberately unused: Φ is the attacker's own
## positional bonus to its own stat, not a function of who it is attacking,
## and the parameter exists only so this method's signature matches the
## [Callable] contract [member BattleController._phi_provider] requires.
func phi(attacker_id: int, _target_id: int) -> int:
	return AffinityRules.bonus_for(attacker_id, positions(), links())
