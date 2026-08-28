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
## [br]- [code]SUPPRESSED[/code]: a positive link that is not the closest one
##   for this unit, so it contributes nothing (draw greyed out).
enum State { POSITIVE, NEGATIVE, NEUTRAL, SUPPRESSED }

## The unit this line is evaluated from. Suppression is decided from this
## unit's point of view.
var unit_id: int

## The unit at the other end of the line.
var partner_id: int

## Polarity of the underlying [AffinityLink].
var polarity: AffinityLink.Polarity

## Manhattan distance between the two units right now.
var distance: int

## Bonus this line contributes to [member unit_id] right now. Always 0 when
## [member state] is [code]SUPPRESSED[/code].
var delta: int

## Player-facing classification — see [enum State].
var state: State


## Builds a status snapshot and derives [member state] from [param delta] and
## [param suppressed]. Suppression wins over the sign of the delta.
static func create(
	from_unit: int,
	to_unit: int,
	link_polarity: AffinityLink.Polarity,
	current_distance: int,
	current_delta: int,
	suppressed: bool
) -> AffinityLineStatus:
	var status: AffinityLineStatus = AffinityLineStatus.new()
	status.unit_id = from_unit
	status.partner_id = to_unit
	status.polarity = link_polarity
	status.distance = current_distance
	status.delta = 0 if suppressed else current_delta
	status.state = _classify(status.delta, suppressed)
	return status


## Maps a delta plus a suppression flag onto a player-facing [enum State].
static func _classify(current_delta: int, suppressed: bool) -> State:
	if suppressed:
		return State.SUPPRESSED
	if current_delta > 0:
		return State.POSITIVE
	if current_delta < 0:
		return State.NEGATIVE
	return State.NEUTRAL
