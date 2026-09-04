## Pure, node-independent rules for the manually-managed world layer scaling
## and centering mandated by the 2026-09-01 screen-architecture decision
## (`design/art/screen-architecture.md`: "取塞得下的最大整數倍,永遠置中") and
## implemented by `production/epics/screen-scaling/story-001-manual-world-scaling.md`.
##
## [b]Why this class exists at all[/b]: `window/stretch/mode` is `"disabled"`
## (see `project.godot`) — the engine performs zero automatic scale/offset of
## its own. Every number this file returns is therefore the [b]sole source of
## truth[/b] every call site must share, replacing the role
## [code]Window.get_final_transform()[/code] played while
## `window/stretch/mode` was `"canvas_items"` (see the now-retired discipline
## in `src/ui/CLAUDE.md`, "條件二"). Per this story's own Implementation Notes
## #3 ("那段邏輯要有單一出處,不得在呼叫端各自複製一份") and this project's
## registered failure pattern of the same formula being re-implemented twice
## and only agreeing "today" (see `design/gdd/reviews/` affinity/combat
## Manhattan-distance duplication case): [b]no call site may re-derive the
## scale/rect/transform math itself — every call site MUST go through this
## class.[/b]
##
## Verified against the real engine before being written here — see
## `prototypes/story-001-manual-scaling-verification-2026-09-04/README.md`
## (real GPU, non-headless, four target resolutions, content painted in
## [SubViewport]-local 480x270 space sampled from an actual captured frame at
## the mathematically expected screen position; also confirmed a
## [SubViewportContainer] can carry a manual, non-full-rect
## [code]position[/code]/[code]size[/code] AND a non-1
## [member SubViewportContainer.stretch_shrink] at the same time without the
## two interfering — a combination neither the 2026-08-27 nor the 2026-09-01
## spike had exercised together).
class_name WorldLayout
extends RefCounted

## Base canvas width all board content (`BoardCoords`, `BoardView`) is
## authored in, at 1x scale.
const BASE_WIDTH: int = 480

## Base canvas height all board content is authored in, at 1x scale.
const BASE_HEIGHT: int = 270


## Returns the largest integer scale that fits [param window_size] without
## exceeding it in either axis (`480x270` decision table: 1080p->4, 2K->5,
## 4K->8, ultrawide->5).
##
## Floored at 1 as defense in depth only — not something normal play can
## reach. [code]world_viewport_scaler.gd[/code] sets [code]Window.min_size
## = (960, 540)[/code] at startup (the 2026-09-04 manager ruling recorded in
## story-001's Implementation Notes) — [b]not[/b] a
## [code]project.godot[/code] setting: verified empirically
## (`prototypes/story-001-manual-scaling-verification-2026-09-04/`) that
## Godot 4.7.1 has no registered [code]display/window/size/*[/code] project
## setting for minimum window size at all, only the runtime
## [code]Window.min_size[/code] property. The engine enforces that minimum
## by clamping any smaller assigned size back up (measured in
## `prototypes/story-010-headless-resolution-probe-2026-09-04/logs/minsize_probe_output.txt`)
## — so a window below `480x270` (which would otherwise make this compute a
## scale of 0) is structurally unreachable through ordinary resize.
static func compute_scale(window_size: Vector2i) -> int:
	var scale_x: int = window_size.x / BASE_WIDTH
	var scale_y: int = window_size.y / BASE_HEIGHT
	return maxi(1, mini(scale_x, scale_y))


## Returns the world layer's rect in window-pixel space: sized to
## [code]BASE_WIDTH/HEIGHT * compute_scale(window_size)[/code], centered
## inside [param window_size] (AC-S001-b: left/right margins equal, top/bottom
## margins equal — both may be zero, as at 1080p/4K).
static func compute_rect(window_size: Vector2i) -> Rect2i:
	var scale: int = compute_scale(window_size)
	var world_size: Vector2i = Vector2i(BASE_WIDTH * scale, BASE_HEIGHT * scale)
	var margin: Vector2i = (window_size - world_size) / 2
	return Rect2i(margin, world_size)


## Base-canvas (480x270) -> window-pixel transform for [param window_size].
## This is what call sites use in place of the retired
## [code]Window.get_final_transform()[/code] — see class doc comment. Feed
## the result to [method BoardCoords.grid_to_window] as
## [code]canvas_to_window[/code], with [code]world_viewport_canvas_origin =
## Vector2.ZERO[/code] (in this manually-managed architecture there is no
## separate intermediate UI-canvas space distinct from the 480x270 board-local
## space — the two collapsed into one once the UI layer's own basis became
## `NATIVE`/1:1, per `design/art/screen-architecture.md` §1; this transform
## already carries both the scale AND the centering offset in one step, so
## [BoardCoords] needs no separate origin term).
static func canvas_to_window_transform(window_size: Vector2i) -> Transform2D:
	var scale: int = compute_scale(window_size)
	var rect: Rect2i = compute_rect(window_size)
	return Transform2D(Vector2(scale, 0.0), Vector2(0.0, scale), Vector2(rect.position))


## Window-pixel -> base-canvas (480x270) transform for [param window_size].
## Inverse of [method canvas_to_window_transform] — feed to
## [method BoardCoords.window_to_grid] as [code]window_to_canvas[/code], with
## [code]world_viewport_canvas_origin = Vector2.ZERO[/code] (see that
## method's doc comment above).
static func window_to_canvas_transform(window_size: Vector2i) -> Transform2D:
	return canvas_to_window_transform(window_size).affine_inverse()
