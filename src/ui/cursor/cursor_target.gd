## Value-semantics target identity for the cursor/highlight-state system
## (ADR-0005 機制三). Immutable: any change produces a new instance, never
## mutated in place.
##
## Does NOT contain hitbox/collision geometry — GDD 第九輪 converged this
## system's write interface to surface-type-keyed fixed pixel thresholds
## (機制八), so no geometry query is needed here or per-frame.
class_name CursorTarget
extends RefCounted

var surface: CursorTypes.SurfaceType
var id: int          # target identity within surface. int, not Variant — see [method equals]
var is_valid: bool   # GDD Core Rules #1 validity flag


## Explicit value comparison — do NOT use [code]==[/code], which compares
## object identity for a [RefCounted], not field values (GDScript trap
## documented by the forbidden pattern
## [code]mutable_container_as_dictionary_key[/code]).
##
## [param other] must not be [code]null[/code] — precondition-checked with
## [code]assert()[/code], matching this project's existing convention for
## caller-contract preconditions (see [code]AffinityLink.partner_of[/code],
## [code]src/gameplay/affinity/affinity_link.gd[/code]). Without this check,
## a [code]null[/code] [param other] would raise a script error on
## [code]other.surface[/code] and silently resolve to [code]false[/code] —
## indistinguishable from a legitimate "not equal" result.
##
## [b]Only compares [code]surface[/code] + [code]id[/code] —
## [code]is_valid[/code] deliberately does NOT participate.[/b] Finalized
## 2026-08-21 (R6-7): if [code]is_valid[/code] participated,
## [code]CursorState.mark_pending_reresolve[/code]'s race check would be
## permanently broken — the caller's [code]expected[/code] is almost always
## the "valid" version while the currently-held target may already be
## invalidated, so that entry point would ALWAYS return
## [code]STALE_NOT_APPLIED[/code], disabling the whole path. Tradeoff: "did
## the target change" therefore does not cover a validity flip on its own —
## that is handled separately (機制十), not by this method.
func equals(other: CursorTarget) -> bool:
	assert(other != null, "CursorTarget.equals: other must not be null")
	return surface == other.surface and id == other.id


## Constructs a new valid target. [param is_valid] is always [code]true[/code].
static func make(surface: CursorTypes.SurfaceType, id: int) -> CursorTarget:
	var target := CursorTarget.new()
	target.surface = surface
	target.id = id
	target.is_valid = true
	return target


## Returns a new instance with the same [code]surface[/code]/[code]id[/code]
## as [param from], with [code]is_valid[/code] flipped to [code]false[/code].
static func invalidated(from: CursorTarget) -> CursorTarget:
	var target := CursorTarget.new()
	target.surface = from.surface
	target.id = from.id
	target.is_valid = false
	return target
