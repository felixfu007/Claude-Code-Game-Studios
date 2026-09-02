## Abstract strategy boundary for the mouse-reclaim submechanism (ADR-0005
## 機制八). Concrete threshold math, the accumulator, and the four reset
## triggers live in a concrete subclass (Story 014, out of scope here) —
## this file is the frozen contract only.
##
## [b]Bare-signature abstract methods — no body, no colon.[/b] A body (even
## [code]pass[/code]) is a COMPILE-TIME ERROR in this engine version
## (registered forbidden pattern [code]abstract_func_with_body[/code],
## verified 2026-08-20). Do not add one.
@abstract
class_name MouseReclaimPolicy
extends RefCounted

## Presentation layer (機制十三) subscribes to learn whether a given
## zero-out is [constant CursorTypes.ResetTrigger.VETOED_SAME_FRAME] (the
## only trigger allowed to snap to zero within a single frame, AC-41b) or one
## of the other four (which must converge instead).
signal reset_triggered(trigger: CursorTypes.ResetTrigger)

## Returns whether the mouse gains a valid reclaim claim this frame.
## [param current_mouse_position] is the current mouse screen position (root
## viewport space, see ADR-0005 Constraints "single root Viewport
## assumption") — NOT a net-delta. Net displacement is computed internally
## by the concrete strategy from its own held seed (see [method reset]).
@abstract
func evaluate(current_mouse_position: Vector2, surface: CursorTypes.SurfaceType) -> bool

## Returns the current reclaim progress in [code][0.0, 1.0][/code], read by
## the presentation layer's smoother (機制十三). Not directly bound to
## [code]modulate.a[/code].
@abstract
func reclaim_progress() -> float

## Reseeds the accumulator at [param seed_position] and records which of the
## five [enum CursorTypes.ResetTrigger] values caused it, both for internal
## bookkeeping and via [signal reset_triggered].
@abstract
func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void

## QA/test-only diagnostic getter — downstream gameplay logic must not
## depend on it (same convention as 機制十五's [code]diagnostic_*[/code]
## methods). Returns whatever position was last passed to [method reset].
@abstract
func diagnostic_seed_position() -> Vector2
