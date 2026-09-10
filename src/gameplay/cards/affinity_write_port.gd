## Narrow write port Story 004 defines and injects in place of
## [code]AffinityDataPool.append_record()[/code] (ADR-0002, [b]Accepted[/b] —
## but, as of 2026-09-10, zero implementation exists anywhere in [code]src/[/code]:
## [code]grep -rn "append_record\|combat_card\|AffinityPool\|data_pool" src/ --include=*.gd[/code]
## returns nothing). "The ADR is Accepted" is a design-layer approval, not
## evidence the code exists — see
## [code]production/epics/skill-card-system/story-004-permanent-write-port.md[/code]
## for the full context this class exists to unblock.
##
## [b]Deliberately NOT a literal copy of ADR-0002's signature.[/b] That
## signature is [code]func append_record(pair: AffinityTypes.Pair, m: float,
## source: AffinityTypes.Source) -> WriteRejection[/code], and
## [code]AffinityTypes[/code] is itself part of the unimplemented pool (same
## grep, same zero hits). Building [code]AffinityTypes[/code] here to match
## that shape would mean this story quietly implementing a piece of #1's own
## ADR — not this story's job, and it would create a second, drifting copy
## the moment #1 is actually built (this project's recurring failure mode,
## see [code]docs/consistency-failures.md[/code]). This port instead uses
## the types Story 004's own domain already has:
## [br]
## - [param character_a] / [param character_b]: raw roster ids, the same
##   convention [AffinityLink]'s [member AffinityLink.unit_a] /
##   [member AffinityLink.unit_b] already use — not
##   [code]AffinityTypes.Character[/code].
## - [param source]: a [StringName] constant ([constant SOURCE_COMBAT_CARD]),
##   matching this system's own vocabulary (GDD Formula 三:
##   [code]source = combat_card[/code]) — not [code]AffinityTypes.Source[/code].
## - [enum Rejection]: a reduced 4-value enum covering only what THIS
##   story's own contract needs a caller to distinguish, not ADR-0002's full
##   7-value [code]WriteRejection[/code]. Two of the remaining 3 values there
##   ([code]SERIALIZATION_WINDOW_ACTIVE[/code], [code]NON_FINITE_AMPLITUDE[/code])
##   are concerns of the pool's own internal state or of a [code]Variant[/code]
##   boundary this port does not have — see [member SOURCE_COMBAT_CARD]'s
##   doc comment for why [code]INVALID_SOURCE[/code] (the third) cannot
##   occur here, and this file's own [code]m: int[/code] note for why
##   [code]NON_FINITE_AMPLITUDE[/code] cannot either. [code]INVALID_PAIR[/code]
##   IS included, but see [enum Rejection]'s own doc comment — it is decided
##   by a caller, not by an implementation of this port.
##
## [b]m: int, not float — this is the one real type boundary the work order
## calls out explicitly.[/b] ADR-0002's [code]AffinityRecord.m[/code] is
## [code]float[/code]; this system's own domain is [code]int[/code]
## end-to-end ([member Card.affinity_magnitude], GDD Formula 三's variable
## table, [code]{-3,-2,-1,+1,+2,+3}[/code]). Judgment call, recorded here per
## the work order's own instruction rather than left for the wiring day:
## keep [code]m: int[/code] on THIS port, matching every other type this
## story already owns, instead of forcing every caller in this system to
## carry a [code]float[/code] it never otherwise needs. [code]int -> float[/code]
## widening is lossless for this domain, and becomes the FUTURE adapter's
## job — whoever implements #1 and wires a real [code]AffinityDataPool[/code]
## behind this port converts at that single seam ([code]float(m)[/code]),
## not scattered across this story's own callers.
## ⚠️ That future adapter must also read ADR-0002 機制四之三 before wiring: a
## type mismatch AT [code]append_record()[/code] itself aborts the CALLING
## function rather than returning a rejection code — this port's
## [enum Rejection] cannot represent that failure mode, and the adapter is
## the one place that boundary must be defended (narrow any [code]Variant[/code]
## with [code]typeof()[/code] before it ever reaches the real
## [code]append_record()[/code]).
##
## [b]Bare-signature abstract methods — no body, no colon.[/b] A body (even
## [code]pass[/code]) is a COMPILE-TIME ERROR in this engine version
## (registered forbidden pattern [code]abstract_func_with_body[/code],
## verified 2026-08-20; precedent: [code]src/ui/cursor/mouse_reclaim_policy.gd[/code]).
@abstract
class_name AffinityWritePort
extends RefCounted

## The only [code]Source[/code]-equivalent value THIS story ever passes —
## GDD Formula 三 fixes it: 丙類 writes are always
## [code]source = combat_card[/code]. Because every caller in this story
## uses this single constant, [code]INVALID_SOURCE[/code] (ADR-0002's
## [code]WriteRejection[/code] value for an out-of-domain source) has no
## way to occur through this port and is not part of [enum Rejection].
const SOURCE_COMBAT_CARD: StringName = &"combat_card"

## Rejection reasons a caller of [method append_record] — or of
## [code]PermanentAffinityWriteRules.play[/code], which can return this same
## enum WITHOUT ever calling [method append_record] — must be able to
## distinguish. See the class doc comment for why this is a reduced set,
## not ADR-0002's full [code]WriteRejection[/code].
##
## [b]INVALID_PAIR is decided BEFORE this port is ever reached, not by an
## implementation of [method append_record] itself[/b] (added 2026-09-10,
## same manager ruling that moved pair selection off [Card]'s own fields —
## design/ux/skill-card-play.md S2p/S2q). GDD Core Rules 一之三 界線 4 says
## the real future pool has ZERO awareness of narrative canon and would
## accept any of the 10 possible pairs — so this specific rejection can
## never live inside a concrete [AffinityWritePort] implementation; it
## exists on this enum purely so [code]PermanentAffinityWriteRules.play[/code]
## can hand every caller a single result type, whether it rejected the pair
## itself (before ever touching [param port]) or forwarded to a real port.
enum Rejection {
	NONE,                  ## Write accepted.
	ZERO_MAGNITUDE,         ## m == 0 (GDD Formula 三: illegal — reject, never silently correct)
	DEAD_PAIR_FORBIDDEN,    ## AC-7b's second line of defense — a member of the pair has died
	INVALID_PAIR,           ## No canon relationship line exists for this pair at all (界線 4)
}

## Appends one 丙類 write record for the pair ([param character_a],
## [param character_b]) with signed magnitude [param m] and [param source]
## (always [constant SOURCE_COMBAT_CARD] for this story's own callers).
##
## Deliberately performs NO pre-validation of its own in this file — every
## [enum Rejection] value is a decision the IMPLEMENTATION of this method
## makes, so a test double standing in for it can prove AC-7b/AC-9 actually
## reached the port rather than being intercepted upstream. See
## [code]PermanentAffinityWriteRules.play[/code]'s doc comment for why the
## caller must not pre-filter either.
@abstract
func append_record(character_a: int, character_b: int, m: int, source: StringName) -> Rejection
