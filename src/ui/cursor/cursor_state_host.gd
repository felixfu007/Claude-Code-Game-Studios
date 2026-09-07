## Autoload shell for the cursor/highlight-state system (ADR-0005 機制一).
## Owns nothing but lifecycle: builds the single [CursorState] instance in
## [method _ready] and holds it for the process's lifetime, so its coverage
## spans every screen that uses this system ([code]TR-cursor-001[/code]'s
## lifecycle requirement).
##
## [b]Deliberately empty of logic[/b] — forbidden pattern
## [code]logic_in_cursor_autoload_shell[/code] (ADR-0005). At Story 002 (this
## file's original story) this did not yet implement frame-buffered input
## arbitration, the seven gated public write entries / read queries, or the
## presentation [CanvasLayer]. 🔴 [b]Corrected 2026-09-07 (Story 005) — that
## list is now stale and would mislead a reader checking current scope[/b]:
## Story 007 landed the seven public write entries and read queries; Story
## 011 landed the presentation [CanvasLayer]; this story lands the
## frame-buffered [code]_input()[/code]/[code]_process()[/code] collection
## points below (機制五) and the [CursorNavigationApplier] child (機制六③).
## [b]Still NOT implemented by this story[/b]: 機制九's pause/focus gate
## ([code]_arbitration_suspended[/code], [code]suspend_arbitration()[/code],
## [code]resume_arbitration()[/code], the
## [code]NOTIFICATION_APPLICATION_FOCUS_*[/code] branches) — that is Story
## 008's explicit scope (this story's own dispatch, "Out of Scope"). Until
## Story 008 lands, [member _frame_events] is collected and drained
## unconditionally, every frame, with no pause/focus check anywhere in this
## file.
##
## [b]Interim collaborator gap — CLOSED 2026-09-07 (Story 011).[/b] Story 014
## landed [ThresholdMouseReclaimPolicy] the same day as this story; this host
## now constructs [CursorState] with a real, live [param reclaim] (see
## [method _ready] below). The paragraphs immediately below are kept for
## history — every test in [code]tests/unit/cursor/state_host_test.gd[/code]
## that referenced the interim [code]null[/code] value has been updated in
## this same change, per the obligation the old text below itself stated.
##
## 🔴 [b]Corrected 2026-09-03 (Story 007).[/b] This paragraph previously read
## "This is safe for THIS story only because nothing built so far ever calls a
## method on [member CursorState._reclaim]". [b]Story 007 falsified that[/b] —
## it added six call sites. A null [param reclaim] was handled explicitly by
## [CursorState] itself: one [method @GlobalScope.push_error] at construction
## ([constant CursorState.ERR_RECLAIM_POLICY_ABSENT]) plus a guard at every
## call site, with [method CursorState.reclaim_progress] returning
## [code]0.0[/code]. ADR-0005 has no position on a null [param reclaim]; see
## that method's doc comment for why [code]0.0[/code] was ambiguous
## downstream. It was NOT a decision about the reclaim submechanism itself,
## which remains user-frozen (see Story 014's own "凍結區" notice) — Story 014
## implements the frozen design's threshold math, it does not reopen it.
##
## [b]This story's own choice: construct [ThresholdMouseReclaimPolicy] +
## [MouseReclaimThresholdConfig] directly via [method RefCounted.new], NOT
## from a saved `.tres` asset.[/b] No `.tres` file exists for
## [MouseReclaimThresholdConfig] as of this writing. Considered and rejected:
## hand-authoring one now. [MouseReclaimThresholdConfig]'s own class doc
## comment already documents that its `@export` defaults are an acknowledged,
## GDD-flagged provisional gap ("待垂直切片階段實測") — wrapping today's
## placeholder numbers in a `.tres` file would not make them any less
## placeholder, would add a hand-typed resource file this story cannot verify
## parses correctly through the editor, and risks the exact silent-wrong-value
## failure mode ([method ResourceLoader.load] returning [code]null[/code] on a
## malformed `.tres`, which nothing here currently guards against) that a
## plain [method RefCounted.new] call cannot produce. This is a story-level
## engineering judgment call, not a written rule — flagged in this story's
## report. The real per-surface-type `.tres` asset belongs to whichever future
## story actually performs the vertical-slice calibration GDD Tuning Knobs
## calls for; wiring it in today would not change what number is inside it.
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

## Same [CursorSurfaceRegistry] instance handed to [CursorState]'s constructor
## — stored as its own field (Story 011) so [NativePointerVisibilityArbiter]
## can be constructed against the IDENTICAL instance [CursorState] reads from,
## without adding a new getter to [CursorState] itself (which owns the "two-
## query read interface" contract, ADR-0005 機制十 — this registry access is
## not part of it). ADR-0005's own illustrative 機制十三之二 pseudocode calls
## [code]_registry[/code] directly as if it were already in scope; this field
## is how that reference actually reaches the sibling presentation node in
## this story's split-into-two-classes implementation (機制十二/十三/十三之二).
var _registry: CursorSurfaceRegistry


## [b]Story 010.[/b] Dedicated presentation [CanvasLayer] this host owns for
## the process's lifetime (機制十二: "全域游標視覺宿主"). Built once in
## [method _ready], never reassigned. This story deliberately draws nothing
## on it — it hosts no children yet. Stories 011 (自繪替代游標,機制十三)
## and the hover-detector (機制十三之二) attach their nodes directly to
## THIS layer; nothing may construct a second one.
##
## 🔴 [b]Exclusivity is load-bearing, not stylistic[/b] (ADR-0005 隨核准生效
## 的硬性義務 ①,`src/ui/CLAUDE.md` 同文重申): [member CanvasLayer.modulate]'s
## alpha channel is a PER-NODE property. 機制十三's presentation smoother
## writes [code]modulate.a = _presented_alpha[/code] on its own child node
## every frame (R6-8) — sharing this layer with unrelated UI content would
## drag that content's opacity along with the mouse-reclaim fade, and R6-8's
## whole reason for splitting the self-drawn cursor and the hover detector
## into two sibling nodes (rather than one) is this same per-node hazard.
##
## 🔴 [b]Also load-bearing[/b]: ADR-0005 Validation Criteria #20 requires
## this layer's [method CanvasItem.get_final_transform] stay
## [constant Transform2D.IDENTITY] across every resolution — this only holds
## while nothing external attaches scale/offset to this exact node (a second,
## differently-parented [CanvasLayer] would not violate it; a merged/shared
## node would). See
## [code]tests/unit/cursor/cursor_layer_transform_test.gd[/code], and the
## headless probe that established this is measurable at all:
## [code]prototypes/story-010-headless-resolution-probe-2026-09-04/[/code].
var _cursor_layer: CanvasLayer


## `CanvasLayer.layer` (draw order — [b]not[/b] [member Node.process_priority],
## ADR-0005 明文兩者是獨立概念,不得混用同一組數值,見機制十二 Implementation
## Notes #3) picked well above this project's only other [CanvasLayer] today
## ([code]src/ui/GameRoot.tscn[/code]'s "UILayer", which does not override
## [member CanvasLayer.layer] and therefore sits at the engine default of
## [code]1[/code]), so the cursor/hover presentation always draws on top of
## screen content — matching 機制十二's decision text ("高 layer 值,恆在
## 所有畫面內容之上").
##
## ⚠️ [b]The ADR does not pin an exact number for this constant[/b] — this
## value is this story's own engineering judgment call, not a cited
## requirement. Flagged to the architecture owner in this story's report
## rather than silently chosen and left undocumented.
const CURSOR_LAYER_DRAW_ORDER: int = 100


## Per-frame input event buffer (ADR-0005 機制五). Collected in [method _input]
## below, decided (機制六①,[method _process] below) then applied (機制六③,
## [method flush_buffered_navigation] below) across two [member Node.process_priority]
## tiers, then cleared by the LAST consumer — never by [method _process].
##
## 🔴 [b]This story does NOT gate on 機制九's pause/focus flag.[/b] See this
## file's class doc comment's "Still NOT implemented by this story" paragraph
## — [code]_arbitration_suspended[/code] does not exist yet (Story 008). Until
## then this buffer fills and drains unconditionally every frame.
var _frame_events: Array[InputEvent] = []

## [b]Story 005.[/b] Dedicated child node for 機制六③ (see
## [code]cursor_navigation_applier.gd[/code]'s own class doc comment for why
## it cannot be a second role folded onto THIS node). Built once in
## [method _ready], never reassigned. Its OWN
## [member Node.process_priority] (-25) is set in ITS OWN [method Node._init],
## before [method Node.add_child] — same convention as [member _cursor_layer]'s
## two children below.
var _navigation_applier: CursorNavigationApplier


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
	# Story 011 step 1 (2026-09-07): real ThresholdMouseReclaimPolicy, no
	# longer null — see class doc comment's "Interim collaborator gap — CLOSED"
	# section for why MouseReclaimThresholdConfig.new()'s bare provisional
	# defaults are used directly rather than a hand-authored `.tres` asset.
	var reclaim_config: MouseReclaimThresholdConfig = MouseReclaimThresholdConfig.new()
	var reclaim_policy: MouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(reclaim_config)

	_registry = CursorSurfaceRegistry.new()
	_state = CursorState.new(
		reclaim_policy,
		_registry,
		Callable(self, "_get_mouse_position")
	)

	# Story 005: 機制六③'s dedicated child node. process_priority = -25 is set
	# in ITS OWN _init() (R6-12: before add_child()), not here — same
	# convention as the CanvasLayer children below. `self` is passed as the
	# host: there is exactly one CursorStateHost instance (the Autoload) and
	# this node is always its own direct child, never shared.
	_navigation_applier = CursorNavigationApplier.new(self)
	_navigation_applier.name = "CursorNavigationApplier"
	add_child(_navigation_applier)

	# Story 010: 機制十二's presentation host. No process_priority is set on
	# this node itself — unlike the six 機制六 process-priority actors, a bare
	# CanvasLayer with no children has no _process()/_input() of its own. Its
	# two children below (Story 011) DO set process_priority, each in its own
	# _init(), before being add_child()-ed here (R6-12).
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.name = "CursorLayer"
	_cursor_layer.layer = CURSOR_LAYER_DRAW_ORDER
	add_child(_cursor_layer)

	# Story 011 step 2 (2026-09-07): 機制十三's self-drawn substitute cursor —
	# see that class's own doc comment for why
	# reclaim_visual_convergence_max_frames has no `.tres` asset either, same
	# reasoning as MouseReclaimThresholdConfig above.
	var visual_config: CursorReclaimVisualConfig = CursorReclaimVisualConfig.new()
	var self_drawn_cursor: SelfDrawnReclaimCursor = SelfDrawnReclaimCursor.new(_state, visual_config)
	self_drawn_cursor.name = "SelfDrawnReclaimCursor"
	_cursor_layer.add_child(self_drawn_cursor)

	# Story 011 step 2: 機制十三之二's hover-based native-pointer visibility
	# arbiter — separate sibling node (R6-8), never the same node as the
	# self-drawn cursor above. hovered_control_provider bound by NAME (S-1
	# convention), never a lambda literal.
	var hover_arbiter: NativePointerVisibilityArbiter = NativePointerVisibilityArbiter.new(
		_state, _registry, Callable(self, "_get_hovered_control")
	)
	hover_arbiter.name = "NativePointerVisibilityArbiter"
	_cursor_layer.add_child(hover_arbiter)


## GDD 步驟一/二/三 的緩衝掛載點(ADR-0005 機制五)。[b]只收集，絕不裁定[/b] —
## mounted here rather than [method Node._unhandled_input] per ADR-0005's
## explicit rejection of that hook: an event consumed via
## [method InputEvent.accept_event] by a focused [Control]'s own GUI handling
## (e.g. its built-in focus navigation on [code]ui_up[/code]/[code]ui_down[/code])
## never reaches [method Node._unhandled_input] at all — a silent omission,
## not a reordering, that no buffering scheme downstream could repair.
##
## 🔴 Does NOT check [code]_arbitration_suspended[/code] — that field does not
## exist yet (Story 008, see class doc comment). Every event collected here
## is drained unconditionally.
func _input(event: InputEvent) -> void:
	_frame_events.append(event)


## GDD 步驟一(機制六①): device-authority arbitration only, at THIS node's
## own [member Node.process_priority] ([code]-100[/code]) — earliest of the
## six 機制六 actors. Does [b]NOT[/b] clear [member _frame_events]: 機制六③
## ([method flush_buffered_navigation] below) still needs to read it. The
## buffer's clear point is that method, the frame's LAST consumer (機制五
## R4-1).
func _process(_delta: float) -> void:
	if _frame_events.is_empty():
		return
	_state.arbitrate_device_authority(_frame_events)


## GDD 步驟三(機制六③), called by [member _navigation_applier] from ITS OWN
## [method Node._process] at [code]process_priority = -25[/code] — after any
## caller's own 機制六②主動改標 at the architecture-mandated open interval
## (-100, -25), both exclusive. Buffer stays private (no getter hands out the
## internal [Array] — forbidden pattern
## [code]returning_internal_container_references[/code], ADR-0001).
func flush_buffered_navigation() -> void:
	if _frame_events.is_empty():
		return
	_state.apply_buffered_navigation(_frame_events)
	_frame_events.clear()


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


## Bound-by-name [Callable] target for [NativePointerVisibilityArbiter]'s
## injected [code]hovered_control_provider[/code] (Story 011, S-1 convention —
## never a lambda literal). Unlike [method _get_mouse_position], this call is
## NOT restricted to a single call site anywhere in ADR-0005 — Validation
## Criteria #16(ii) names only [method Viewport.get_mouse_position]. See
## [code]native_pointer_visibility_arbiter.gd[/code]'s own class doc comment
## for why this indirection exists at all (headless testability, this story's
## own engineering judgment call).
func _get_hovered_control() -> Control:
	return get_viewport().gui_get_hovered_control()
