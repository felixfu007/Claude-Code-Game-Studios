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
## prototype's [code]manhattanPos()[/code]. See [method manhattan_distance]'s
## own doc comment for why this is a second, independent implementation
## rather than a shared function.
##
## The single-line distance-to-delta curve ([method delta]) is a faithful
## port of the rule validated in
## [code]prototypes/affinity-position-concept-v5/prototype.html[/code]
## ([code]affinityDelta()[/code]). The prototype's stacking rule
## ([code]activeDeltasAt()[/code], "only the single closest positive link is
## active") has been replaced: R4 in
## [code]design/gdd/affinity-position-chain.md[/code] is the live rule now —
## every line counts, summed, with no suppression of any kind — and is what
## [method lines_for_at] implements. R7 in the same document adds a hard
## clamp on the summed total ([constant PHI_MIN]/[constant PHI_MAX]), applied
## exactly once by [method bonus_for_at], never per line.
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

## Hard lower bound on the summed total Φ (Formula 三 / R7 in
## [code]design/gdd/affinity-position-chain.md[/code]). Per-character link
## count is unbounded by design (2026-08-31 ruling: "不限制敘事" — don't let
## the numbers constrain the narrative), so the raw pre-clamp sum is
## unbounded in both directions; this clamp is the ONLY thing that bounds it,
## and it fires during ordinary legal play once a unit has enough links —
## it is not a fuse that only trips on malformed data. Equals the saturation
## point of 4 adjacent negative links at [constant DISTANCE_ADJACENT] with
## [code]amp == 1[/code] (4 × [constant DELTA_NEGATIVE_ADJACENT]).
const PHI_MIN: int = -4

## Hard upper bound on the summed total Φ — see [constant PHI_MIN] for why
## this fires in legal play. Equals the saturation point of 4 adjacent
## positive links at [constant DISTANCE_ADJACENT] with [code]amp == 1[/code]
## (4 × [constant DELTA_POSITIVE_ADJACENT]).
const PHI_MAX: int = 12


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
## integer to add to a stat, already clamped to [constant PHI_MIN]/
## [constant PHI_MAX] by [method bonus_for_at]. Returns 0 when the unit has
## no links, or when it is absent from [param positions].
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
## [param origin] — this is the "what if I move here" preview the prototype
## used for its hover readout; [param unit_id] does not need to be in
## [param positions]. Sums every line's raw [member AffinityLineStatus.delta]
## (R4 — no suppression) and clamps the total exactly once, here, to
## [constant PHI_MIN]/[constant PHI_MAX] (R7/Formula 三). Individual lines
## reported by [method lines_for]/[method lines_for_at] are never clamped
## themselves, so they can legitimately sum to more or less than this
## function's return value.
static func bonus_for_at(
	unit_id: int,
	origin: Vector2i,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> int:
	var total: int = 0
	for status: AffinityLineStatus in lines_for_at(unit_id, origin, positions, links):
		total += status.delta
	return clampi(total, PHI_MIN, PHI_MAX)


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
## standing on [param origin] — the move-preview form. Per R4, every link
## touching [param unit_id] contributes; there is no suppression of any kind.
static func lines_for_at(
	unit_id: int,
	origin: Vector2i,
	positions: Dictionary[int, Vector2i],
	links: Array[AffinityLink]
) -> Array[AffinityLineStatus]:
	var statuses: Array[AffinityLineStatus] = []
	for link: AffinityLink in links:
		if not link.involves(unit_id):
			continue
		var partner: int = link.partner_of(unit_id)
		if not positions.has(partner):
			continue
		var distance: int = manhattan_distance(origin, positions[partner])
		statuses.append(
			AffinityLineStatus.create(
				unit_id,
				partner,
				link.polarity,
				distance,
				delta(link.polarity, distance, link.amp)
			)
		)
	return statuses


## Every link in the table that currently has both endpoints on the board,
## evaluated from [member AffinityLink.unit_a]'s point of view — the
## whole-board line overlay, matching the prototype's
## [code]renderConnections()[/code].
##
## R8 in [code]design/gdd/affinity-position-chain.md[/code] guarantees a
## line's [member AffinityLineStatus.delta]/[member AffinityLineStatus.state]
## are identical regardless of which endpoint is asked from, now that R4
## removed suppression — so which unit is treated as the perspective here no
## longer changes the result, only which id lands in
## [member AffinityLineStatus.unit_id] on the returned entry.
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
		statuses.append(
			AffinityLineStatus.create(
				link.unit_a,
				link.unit_b,
				link.polarity,
				distance,
				delta(link.polarity, distance, link.amp)
			)
		)
	return statuses


## Manhattan distance between two board cells. This is a separate
## implementation from [method CombatRules.is_in_range]'s private
## [code]_manhattan_distance[/code] — R2 in
## [code]design/gdd/affinity-position-chain.md[/code] deliberately keeps the
## two apart (merging them would couple this Gameplay-layer module to the
## combat module) rather than sharing one function, and instead requires the
## two to be tested to agree; see
## [code]tests/unit/gameplay/affinity/affinity_rules_test.gd[/code]'s AC-R2
## test.
static func manhattan_distance(from: Vector2i, to: Vector2i) -> int:
	return absi(to.x - from.x) + absi(to.y - from.y)
