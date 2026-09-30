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


## story-003-los-blocked-in-range-query.md: returns [code]true[/code] if an
## attack from [param from] to [param to] falls within [param min_range]/
## [param max_range] but is blocked by an occluding cell along the way —
## GDD Visual/Audio §1.3's third overlay layer ("範圍內但不可攻擊"), checked
## via [param is_occluding] delegated to [method LineOfSight.is_clear] exactly
## as [method is_attack_legal] already does. This is the complement half of
## that method, not a new algorithm: for any given
## [code]from[/code]/[code]to[/code]/[code]min_range[/code]/[code]max_range[/code]/
## [code]is_occluding[/code], exactly one of the following holds —
## [br]
## 1. Out of range -> [method is_in_range] false, both this method and
##    [method is_attack_legal] false ("無疊加").
## [br]
## 2. In range, LOS clear (or melee distance 1, which never checks LOS) ->
##    [method is_attack_legal] true, this method false ("合法可攻擊").
## [br]
## 3. In range, LOS blocked -> [method is_attack_legal] false, this method
##    true ("範圍內但不可攻擊").
## [br]
## Melee weapons (whose [param max_range] is 1) structurally can never reach
## state 3: exactly like [method is_attack_legal], the line-of-sight check
## below only runs when the Manhattan distance is 2 or greater, and the only
## distance a [code]max_range = 1[/code] weapon can be in range at is 1 — so
## this method returns [code]false[/code] for every input a melee weapon can
## produce, with no special-case branch (GDD Visual/Audio §1.3: "近戰不受
## 視線檢查……不需實作第三態").
static func is_attack_blocked_by_los(
	from: Vector2i,
	to: Vector2i,
	min_range: int,
	max_range: int,
	is_occluding: Callable
) -> bool:
	if not is_in_range(from, to, min_range, max_range):
		return false
	if _manhattan_distance(from, to) < 2:
		return false
	return not LineOfSight.is_clear(from, to, is_occluding)


## Manhattan distance shared by [method is_in_range] and
## [method is_attack_legal].
static func _manhattan_distance(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)
