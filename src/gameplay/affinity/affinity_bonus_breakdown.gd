## The disclosure of how a unit's Φ bonus was computed at one position: the
## pre-clamp raw sum, the post-clamp total, and -- if clamping occurred --
## which bound it hit.
##
## Exists so a caller (eventually a UI consumer) can show "已達上限/下限" per
## [code]design/gdd/affinity-position-chain.md[/code]'s UI Requirements
## ("原始和被夾限壓回時,必須明示「已達上限/下限」。否則逐條數字加起來不等於
## 總和") without re-summing [AffinityLineStatus] deltas itself -- that second,
## independent summation is exactly what
## [code]production/epics/affinity-position-chain/EPIC.md[/code] risk R-2
## warns against. See
## [code]production/epics/affinity-position-chain/
## story-006-clamp-and-contribution-disclosure-query-api.md[/code], which this
## class and [method AffinityRules.bonus_breakdown_for_at] implement.
##
## Pure data holder, same shape and the same reasoning as [AffinityLineStatus]:
## produced by [method AffinityRules.bonus_breakdown_for_at] /
## [method AffinityRules.bonus_breakdown_for], not meant to be constructed
## directly by callers outside this module.
class_name AffinityBonusBreakdown
extends RefCounted

## Which bound (if any) [member clamped_sum] hit.
##
## A three-value enum rather than two independent booleans
## ([code]hit_upper[/code] / [code]hit_lower[/code]) because two booleans can
## represent "hit both bounds at once" -- a state that is not reachable.
## [method AffinityRules.bonus_breakdown_for_at] clamps to a single closed
## interval [[constant AffinityRules.PHI_MIN], [constant AffinityRules.PHI_MAX]],
## so at most one bound can ever be hit for a given input. [method create]'s
## branching below is exhaustive (every case assigns a value; there is no
## "unreachable" branch), so there is no need for -- and this deliberately
## does not use -- an [code]assert()[/code] to guard any branch. See
## [code].claude/docs/coding-standards.md[/code]'s 2026-09-15 entry: an
## [code]assert()[/code] guarding an "unreachable" branch of a function
## returning an enum silently yields ordinal 0 of that enum on failure, which
## for this enum would be [constant Direction.NONE] -- i.e. a failed guard
## would silently report "not clamped".
enum Direction { NONE, UPPER, LOWER }

## Pre-clamp total of every line's raw [member AffinityLineStatus.delta] (R4
## in [code]design/gdd/affinity-position-chain.md[/code] -- no suppression,
## every line counts). May fall outside
## [[constant AffinityRules.PHI_MIN], [constant AffinityRules.PHI_MAX]] --
## Formula 三's clamp has not been applied to this field.
var raw_sum: int

## Post-clamp total -- identical to what [method AffinityRules.bonus_for_at]
## returns for the same inputs (R7/Formula 三's hard clamp, applied exactly
## once). [method AffinityRules.bonus_for_at] is implemented in terms of this
## value, so there is exactly one summation implementation, not two.
var clamped_sum: int

## [code]true[/code] iff [member raw_sum] fell outside the Φ bounds and had to
## be clamped, i.e. [code]raw_sum != clamped_sum[/code]. [code]false[/code]
## when [member raw_sum] lands exactly on a bound (e.g. exactly
## [constant AffinityRules.PHI_MAX]) without exceeding it -- nothing was cut
## off in that case, so it is not "clamped".
var is_clamped: bool

## [enum Direction] of the bound hit, or [constant Direction.NONE] if
## [member is_clamped] is [code]false[/code].
var clamped_direction: Direction


## Builds a breakdown from an already-computed [param raw_sum] and
## [param clamped_sum], deriving [member is_clamped] and
## [member clamped_direction] purely by comparing the two. Does not itself
## re-clamp or validate that [param clamped_sum] actually is [param raw_sum]
## clamped to the Φ bounds -- the sole caller,
## [method AffinityRules.bonus_breakdown_for_at], owns that.
static func create(raw_sum: int, clamped_sum: int) -> AffinityBonusBreakdown:
	var breakdown: AffinityBonusBreakdown = AffinityBonusBreakdown.new()
	breakdown.raw_sum = raw_sum
	breakdown.clamped_sum = clamped_sum
	breakdown.is_clamped = raw_sum != clamped_sum
	if raw_sum > clamped_sum:
		breakdown.clamped_direction = Direction.UPPER
	elif raw_sum < clamped_sum:
		breakdown.clamped_direction = Direction.LOWER
	else:
		breakdown.clamped_direction = Direction.NONE
	return breakdown
