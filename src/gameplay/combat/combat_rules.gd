## Pure combat math and attack-legality checks for the tactical layer.
##
## Stateless utility — every function is a [code]static func[/code] with no
## side effects, no node access, and no randomness. Combat settlement in this
## project is RNG-free by project-level rule ([code]rng_in_combat_settlement[/code]
## in [code].claude/docs/technical-preferences.md[/code]); this module is
## where that guarantee is enforced for damage and range/legality math.
##
## Line-of-sight itself is delegated to [LineOfSight]
## ([code]src/gameplay/board/line_of_sight.gd[/code]) — this module never
## reimplements that traversal, only decides when to call it.
class_name CombatRules
extends RefCounted


## Computes damage dealt: attack minus defense plus a flat modifier
## [param phi], floored at 0 (damage never goes negative).
static func damage(atk: int, def: int, phi: int) -> int:
	return max(0, atk - def + phi)


## Derives an enemy stat from a player baseline scaled by
## [param advantage_pct] (e.g. [code]0.20[/code] for +20%), rounded up to the
## next integer.
static func enemy_stat(player_baseline: int, advantage_pct: float) -> int:
	return ceili(float(player_baseline) * (1.0 + advantage_pct))


## Returns [code]true[/code] if the Manhattan distance between [param from]
## and [param to] falls within [param min_range]..[param max_range]
## inclusive. Distance 0 (targeting one's own cell) always returns
## [code]false[/code], regardless of [param min_range].
static func is_in_range(from: Vector2i, to: Vector2i, min_range: int, max_range: int) -> bool:
	var distance: int = _manhattan_distance(from, to)
	if distance == 0:
		return false
	return distance >= min_range and distance <= max_range


## Returns [code]true[/code] if an attack from [param from] to [param to] is
## legal: it must first satisfy [method is_in_range]. Only when the Manhattan
## distance is 2 or greater does the attack additionally require an
## unobstructed line of sight, checked via [param is_occluding] delegated to
## [method LineOfSight.is_clear]. Melee attacks (distance 1) never require a
## line-of-sight check.
static func is_attack_legal(
	from: Vector2i,
	to: Vector2i,
	min_range: int,
	max_range: int,
	is_occluding: Callable
) -> bool:
	if not is_in_range(from, to, min_range, max_range):
		return false
	if _manhattan_distance(from, to) >= 2:
		return LineOfSight.is_clear(from, to, is_occluding)
	return true


## Manhattan distance shared by [method is_in_range] and
## [method is_attack_legal].
static func _manhattan_distance(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)
