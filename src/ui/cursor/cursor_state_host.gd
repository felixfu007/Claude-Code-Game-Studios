## Autoload shell for the cursor/highlight-state system (ADR-0005 機制一).
## Owns nothing but lifecycle: builds the single [CursorState] instance in
## [method _ready] and holds it for the process's lifetime, so its coverage
## spans every screen that uses this system ([code]TR-cursor-001[/code]'s
## lifecycle requirement).
##
## [b]Deliberately empty of logic[/b] — forbidden pattern
## [code]logic_in_cursor_autoload_shell[/code] (ADR-0005). This story does not
## implement:
## - frame-buffered input arbitration ([code]_input()[/code] /
##   [code]_process()[/code] collection and decision — Story 005/007),
## - the seven gated public write entries or the read queries (Story 007),
## - the presentation [CanvasLayer] (Story 010).
##
## [b]Interim collaborator gap, discovered while implementing this story[/b]:
## [MouseReclaimPolicy] is [code]@abstract[/code] (機制八), and its only
## concrete subclass is Story 014's — which, per that story's own
## [code]Depends on: 001, 002[/code], has not been built yet and structurally
## cannot exist before this one. This host therefore constructs [CursorState]
## with [param reclaim] [code]null[/code]. This is safe for THIS story only
## because nothing built so far ever calls a method on
## [member CursorState._reclaim]; it is NOT a decision about the reclaim
## submechanism itself, which remains user-frozen (see Story 014's own
## "凍結區" notice). [b]Replace the [code]null[/code] below with a real
## concrete [MouseReclaimPolicy] instance once Story 014 lands[/b] —
## [code]tests/unit/cursor/state_host_test.gd[/code] has one test documenting
## and guarding this interim value, which must be updated in the same change.
##
## [b]Engine finding (2026-09-02, this story's own test run) — deliberately
## NO [code]class_name[/code] on this file[/b]: ADR-0005's own illustrative
## code (機制一 / Key Interfaces) writes
## [code]class_name CursorStateHost extends Node[/code], and
## [code].claude/docs/technical-preferences.md[/code]'s Autoload Pattern
## section shows the idiom [code]var x: GameManager = GameManager[/code],
## which requires a [code]class_name[/code] identical to the autoload
## registration name. Both are unachievable together in this engine version:
## registering this script as the [code]CursorStateHost[/code] Autoload while
## it also declares [code]class_name CursorStateHost[/code] is a PARSE-TIME
## error — [code]Parse Error: Class "CursorStateHost" hides an autoload
## singleton[/code] — which cascades into "Failed to instantiate an autoload,
## script ... does not inherit from 'Node'" and breaks every test in the
## project, not just this system's own. Verified by hitting it directly
## during this story's first test run. The Autoload's global accessor (bare
## identifier [code]CursorStateHost[/code], used throughout ADR-0005's prose,
## e.g. 機制九's [code]CursorStateHost.resume_arbitration()[/code]) comes from
## the [code][autoload][/code] registration itself, not from
## [code]class_name[/code] — dropping [code]class_name[/code] here loses no
## call-site convention. Flagged for the architecture owner: ADR-0005's
## illustrative snippet and [code]technical-preferences.md[/code]'s Autoload
## Pattern example may need a correction note for future systems that copy
## this pattern.
extends Node

## The single DI core this host owns for the process's lifetime. Built once
## in [method _ready], never reassigned. No getter exposes it by reference
## yet — Story 007 adds the read interface.
var _state: CursorState


## [b]process_priority set here, not in [method _ready][/b] (2026-09-02,
## three-way-review remediation) — ADR-0005's R6-12 explicitly mandates
## [code]process_priority[/code] be set BEFORE [method Node.add_child]
## (機制一/機制六: 行為者① must be the earliest of the six process-priority
## actors), and [method _init] runs before this Autoload is ever added to
## [code]/root[/code], while [method _ready] runs after. The prior placement
## in [method _ready] was very likely harmless in practice — an Autoload's
## [method _ready] runs before the first [method Node._process] pass, so no
## frame's processing order was ever observed while the priority was still
## unset — but "likely harmless" was reasoning, not a measurement, and moving
## it costs nothing. Do not move it back to [method _ready] without a reason.
func _init() -> void:
	process_priority = -100


func _ready() -> void:
	_state = CursorState.new(
		null,  # MouseReclaimPolicy — Story 014, see class doc comment above
		CursorSurfaceRegistry.new(),
		Callable(self, "_get_mouse_position")
	)


## Sole call site in the project for [method Viewport.get_mouse_position], used
## to build [member CursorState._mouse_position_provider] (ADR-0005 機制十
## restricts this to exactly one call site across the whole project). Bound by
## NAME via [method _ready]'s [Callable] construction, never a lambda literal
## — per this project's own explicit finding (機制十 專家發現 G,
## engine-verified 2026-08-20) that named bindings and lambdas are behaviorally
## IDENTICAL for [method Callable.is_valid] detecting a freed object; the named
## form was kept anyway as ADR-0005's more explicit, defensible convention,
## not because it is functionally required.
func _get_mouse_position() -> Vector2:
	return get_viewport().get_mouse_position()
