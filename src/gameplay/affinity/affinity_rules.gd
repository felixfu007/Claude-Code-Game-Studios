## Position-driven affinity math: how much a unit's stats gain or lose from
## where it is standing relative to the units it likes and dislikes.
##
## Stateless utility — every function is a [code]static func[/code] with no
## side effects, no node access, no [FileAccess], and no randomness. Combat
## settlement in this project is RNG-free by project-level rule
## ([code]rng_in_combat_settlement[/code] in
## [code].claude/docs/technical-preferences.md[/code]), and the affinity bonus
## feeds that settlement, so this module must stay deterministic.
##
## Distance is Manhattan distance, matching [CombatRules] and matching the
## prototype's [code]manhattanPos()[/code].
##
## This is a faithful port of the rule validated in
## [code]prototypes/affinity-position-concept-v5/prototype.html[/code]
## ([code]affinityDelta()[/code] and [code]activeDeltasAt()[/code]), including
## its deliberate simplification: only the single CLOSEST positive link of a
## unit is active at a time. The general stacking rule is not designed yet —
## do not invent one here.
##
## The pairing table itself is data ([AffinityLink], parsed from
## [code]assets/data/affinity/vs01_affinity_links.txt[/code]); only the
## distance-to-delta curve lives in this file, as named constants.
class_name AffinityRules
extends RefCounted

## Manhattan distance at which a link is "adjacent".
const DISTANCE_ADJACENT: int = 1

## Manhattan distance at or beyond which a link counts as "far apart".
const DISTANCE_FAR: int = 3

## Delta of an active positive link at [constant DISTANCE_ADJACENT].
const DELTA_POSITIVE_ADJACENT: int = 3

## Delta of an active positive link at [constant DISTANCE_FAR] or beyond.
const DELTA_POSITIVE_FAR: int = -1

## Delta of a negative link at [constant DISTANCE_ADJACENT].
const DELTA_NEGATIVE_ADJACENT: int = -1

## Delta of a negative link at [constant DISTANCE_FAR] or beyond.
const DELTA_NEGATIVE_FAR: int = 2

## Delta at every distance not covered by the two thresholds above — notably
## distance 2, the deliberate dead zone between the two effects.
const DELTA_NEUTRAL: int = 0


## Base affinity delta for one link at [param distance], multiplied by
## [param amp]. Ported verbatim from the prototype's
## [code]affinityDelta()[/code]:
## [br]- positive: distance 1 -> +3, distance 2 -> 0, distance 3+ -> -1
## [br]- negative: distance 1 -> -1, distance 2 -> 0, distance 3+ -> +2
## [br]Distance 0 (two units on one cell, which the board disallows) is
## treated as the neutral case, as in the prototype.
static func delta(polarity: AffinityLink.Polarity, distance: int, amp: int) -> int:
	var base: int = DELTA_NEUTRAL
	if polarity == AffinityLink.Polarity.POSITIVE:
		if distance == DISTANCE_ADJACENT:
			base = DELTA_POSITIVE_ADJACENT
		elif distance >= DISTANCE_FAR:
			base = DELTA_POSITIVE_FAR
	else:
		if distance == DISTANCE_ADJACENT:
			base = DELTA_NEGATIVE_ADJACENT
		elif distance >= DISTANCE_FAR:
			base = DELTA_NEGATIVE_FAR
	return base * amp


## Total affinity bonus for [param unit_id] at its current position — the
## integer to add to a stat. Returns 0 when the unit has no links, or when it
## is absent from [param positions].
##
## [param positions] maps roster id to board cell and is also the liveness
## input: a unit that is dead or off the board must simply be absent from it,
## and every link to it is then ignored (the prototype skips dead partners the
## same way).
static func bonus_for(
	unit_id: int,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> int:
	if not positions.has(unit_id):
		return 0
	return bonus_for_at(unit_id, positions[unit_id], positions, links)


## Same as [method bonus_for] but evaluates the unit as if it were standing on
## [param origin]. This is the "what if I move here" preview the prototype used
## for its hover readout; [param unit_id] does not need to be in
## [param positions].
static func bonus_for_at(
	unit_id: int,
	origin: Vector2i,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> int:
	var total: int = 0
	for status: AffinityLineStatus in lines_for_at(unit_id, origin, positions, links):
		total += status.delta
	return total


## Every affinity link touching [param unit_id], with its current distance,
## delta and player-facing state — one entry per drawable line. Returns an
## empty array when the unit is absent from [param positions].
##
## Entries come back in pairing-table order, which is stable because
## [method AffinityLink.links_from_text] preserves file order.
static func lines_for(
	unit_id: int,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> Array[AffinityLineStatus]:
	if not positions.has(unit_id):
		return []
	return lines_for_at(unit_id, positions[unit_id], positions, links)


## Same as [method lines_for] but evaluates [param unit_id] as if it were
## standing on [param origin] — the move-preview form.
static func lines_for_at(
	unit_id: int,
	origin: Vector2i,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> Array[AffinityLineStatus]:
	var statuses: Array[AffinityLineStatus] = []
	var active_positive: AffinityLink = active_positive_link(unit_id, origin, positions, links)
	for link: AffinityLink in links:
		if not link.involves(unit_id):
			continue
		var partner: int = link.partner_of(unit_id)
		if not positions.has(partner):
			continue
		var distance: int = manhattan_distance(origin, positions[partner])
		var suppressed: bool = (
			link.polarity == AffinityLink.Polarity.POSITIVE and link != active_positive
		)
		statuses.append(
			AffinityLineStatus.create(
				unit_id,
				partner,
				link.polarity,
				distance,
				delta(link.polarity, distance, link.amp),
				suppressed
			)
		)
	return statuses


## Every link in the table that currently has both endpoints on the board,
## evaluated from [member AffinityLink.unit_a]'s point of view — the
## whole-board line overlay, matching the prototype's
## [code]renderConnections()[/code].
##
## Suppression is asymmetric, so which endpoint is asked matters; the
## prototype always asks the first unit of the pair and this port does the same.
static func board_lines(
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> Array[AffinityLineStatus]:
	var statuses: Array[AffinityLineStatus] = []
	for link: AffinityLink in links:
		if not positions.has(link.unit_a) or not positions.has(link.unit_b):
			continue
		var origin: Vector2i = positions[link.unit_a]
		var distance: int = manhattan_distance(origin, positions[link.unit_b])
		var suppressed: bool = false
		if link.polarity == AffinityLink.Polarity.POSITIVE:
			suppressed = link != active_positive_link(link.unit_a, origin, positions, links)
		statuses.append(
			AffinityLineStatus.create(
				link.unit_a,
				link.unit_b,
				link.polarity,
				distance,
				delta(link.polarity, distance, link.amp),
				suppressed
			)
		)
	return statuses


## The single positive link of [param unit_id] that is in force from
## [param origin]: the one whose partner is closest. Ties are broken by the
## lower partner id, so the result never depends on table order. Returns
## [code]null[/code] when the unit has no positive link with a partner on the
## board.
##
## This is the prototype's deliberate simplification — "only the nearest
## positive pair counts at a time" — isolated in one function so the eventual
## real stacking rule has exactly one place to replace.
static func active_positive_link(
	unit_id: int,
	origin: Vector2i,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> AffinityLink:
	var best: AffinityLink = null
	var best_distance: int = 0
	var best_partner: int = 0
	for link: AffinityLink in links:
		if link.polarity != AffinityLink.Polarity.POSITIVE:
			continue
		if not link.involves(unit_id):
			continue
		var partner: int = link.partner_of(unit_id)
		if not positions.has(partner):
			continue
		var distance: int = manhattan_distance(origin, positions[partner])
		if best == null or distance < best_distance:
			best = link
			best_distance = distance
			best_partner = partner
		elif distance == best_distance and partner < best_partner:
			best = link
			best_distance = distance
			best_partner = partner
	return best


## Manhattan distance between two board cells — the same metric
## [method CombatRules.is_in_range] uses, so "two tiles away" means the same
## thing to affinity as it does to weapon range.
static func manhattan_distance(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)
