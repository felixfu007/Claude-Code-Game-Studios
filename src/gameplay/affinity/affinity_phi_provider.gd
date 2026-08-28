## Adapter that satisfies [BattleController]'s [code]phi_provider: Callable[/code]
## contract (signature [code]func(attacker_id: int, target_id: int) -> int[/code])
## by reading live positions out of a [BattleState] and handing them to
## [AffinityRules]. This is the object that turns Φ from "always 0 because
## nothing calls the affinity math" into "the attacker's real positional bonus."
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
class_name AffinityPhiProvider
extends RefCounted

# The battle this provider reads positions from. Never mutated here — every
# public method only reads.
var _state: BattleState

# The pairing table this provider was built with — fixed for the provider's
# lifetime, returned verbatim by links().
var _links: Array[AffinityLink]


## Builds a provider over an already-constructed [param state] and the
## pairing table [param links] (typically parsed once via
## [method AffinityLink.links_from_text] from
## [code]assets/data/affinity/vs01_affinity_links.txt[/code]). Neither
## argument is copied or duplicated; [param state] is consulted fresh on
## every call, and [param links] is assumed fixed for this provider's
## lifetime.
func _init(state: BattleState, links: Array[AffinityLink]) -> void:
	_state = state
	_links = links


## Returns the pairing table this provider was built with.
func links() -> Array[AffinityLink]:
	return _links


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
## [method positions] snapshot. [param _target_id] is deliberately unused: Φ
## is the attacker's own positional bonus to its own stat, not a function of
## who it is attacking, and the parameter exists only so this method's
## signature matches the [Callable] contract
## [member BattleController._phi_provider] requires.
func phi(attacker_id: int, _target_id: int) -> int:
	return AffinityRules.bonus_for(attacker_id, positions(), _links)
