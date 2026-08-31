## The current, position-derived state of one affinity link — the exact data
## the board needs to draw one green/red connection line.
##
## Pure data holder produced by [AffinityRules]. It carries copies of the
## link's fields rather than a reference to the [AffinityLink] itself, so a
## caller can never mutate the pairing table through a status object.
##
## Every field is a snapshot for one specific set of unit positions; recompute
## after any unit moves.
class_name AffinityLineStatus
extends RefCounted

## How this line should currently read to the player.
## [br]- [code]POSITIVE[/code]: currently granting a bonus (draw green).
## [br]- [code]NEGATIVE[/code]: currently costing the unit (draw red).
## [br]- [code]NEUTRAL[/code]: in force but worth 0 at this distance.
##
## There used to be a fourth value, [code]SUPPRESSED[/code], for a positive
## link that lost out to a closer one under the prototype's "only the nearest
## positive link counts" simplification. R4
## ([code]design/gdd/affinity-position-chain.md[/code]) replaced that rule
## with "every line counts, summed, no suppression" — the state that value
## represented can no longer occur, so it was deleted outright rather than
## kept as unreachable API surface. See R8 in the same document: with
## suppression gone, a line's contribution is symmetric at both endpoints by
## construction, which is exactly what made a permanently-dead enum value
## feel like a trap for the next reader rather than a live concept worth
## keeping around.
enum State { POSITIVE, NEGATIVE, NEUTRAL }

## The unit this line is evaluated from. Every line's contribution is
## symmetric at both endpoints now that R4 removed suppression (see R8 in
## [code]design/gdd/affinity-position-chain.md[/code]), so which unit this is
## no longer changes [member delta] or [member state] — only which side of
## the pair the caller asked from.
var unit_id: int

## The unit at the other end of the line.
var partner_id: int

## Polarity of the underlying [AffinityLink].
var polarity: AffinityLink.Polarity

## Manhattan distance between the two units right now.
var distance: int

## Bonus this line contributes to [member unit_id] right now, per R3/R4 — the
## raw per-line delta, not clamped. (The Φ-level clamp from Formula 三 is
## applied once, to the total, by [method AffinityRules.bonus_for_at]; it is
## never applied per line, so individual deltas here can legitimately sum to
## more or less than the [Φ] a caller reads elsewhere.)
var delta: int

## Player-facing classification — see [enum State].
var state: State


## Builds a status snapshot and derives [member state] from [param delta].
static func create(
	from_unit: int,
	to_unit: int,
	link_polarity: AffinityLink.Polarity,
	current_distance: int,
	current_delta: int
) -> AffinityLineStatus:
	var status: AffinityLineStatus = AffinityLineStatus.new()
	status.unit_id = from_unit
	status.partner_id = to_unit
	status.polarity = link_polarity
	status.distance = current_distance
	status.delta = current_delta
	status.state = _classify(status.delta)
	return status


## Maps a delta onto a player-facing [enum State].
static func _classify(current_delta: int) -> State:
	if current_delta > 0:
		return State.POSITIVE
	if current_delta < 0:
		return State.NEGATIVE
	return State.NEUTRAL
