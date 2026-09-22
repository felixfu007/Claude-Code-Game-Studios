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
##
## 🔴 [b]Corrected 2026-09-15 (Story 008) — 機制九 is now implemented, the
## paragraph that used to stand here was stale.[/b] [member _arbitration_suspended],
## [method suspend_arbitration], [method resume_arbitration] and the
## [method _notification] [code]NOTIFICATION_APPLICATION_FOCUS_*[/code]
## branches all exist below. [member _frame_events] no longer fills or drains
## unconditionally — [method _input], [method _process] and
## [method flush_buffered_navigation] all gate on
## [member _arbitration_suspended] first.
##
## 🔴 [b]Removed from ADR-0005, not a pending gap[/b] (2026-09-15, manager
## ruling, commit [code]599108e[/code]): ADR-0005's frozen Key Interfaces
## section used to list [code]CursorState.force_redraw_current_authority()[/code]
## (tagged "# AC-30") and [code]CursorState.reapply_native_cursor_visibility()[/code]
## (tagged "# Core Rules #5") as calls [method _notification]'s FOCUS_IN
## branch should make, per the ADR's own illustrative pseudocode for 機制九.
## Neither method was ever built anywhere in [code]src/[/code] (this story's
## own original finding: [code]grep -rn "^func force_redraw_current_authority\|^func
## reapply_native_cursor_visibility" src/[/code] → 0 matches). On 2026-09-15 the
## manager ruled to delete both from the ADR itself, rather than build them:
## Story 011's [code]NativePointerVisibilityArbiter._process()[/code] and
## [code]SelfDrawnReclaimCursor._process()[/code] already re-derive their
## output from [member _state] unconditionally every frame — neither checks
## [member _arbitration_suspended] or window focus at all — so nothing needs
## to be explicitly "reapplied" on FOCUS_IN. See
## [code]docs/architecture/adr-0005-cursor-device-authority-input-architecture.md[/code]'s
## 機制九 section, "🔴 2026-09-15 事實層更正" (and the matching Key Interfaces
## entry further down the same file), for the full ruling and the zero-hits
## [code]grep -rn[/code] the technical director ran against all of
## [code]src/[/code] as of that date.
## [b]This host must NOT add either method to [CursorState][/b]: doing so
## would reopen a ruling the manager already made, not complete pending work.
## Guarded by an executable regression test — not merely this comment — in
## [code]tests/integration/cursor/focus_pause_gating_test.gd[/code]'s
## [code]test_force_redraw_and_reapply_native_cursor_visibility_stay_removed_from_cursor_state[/code].
##
## ⚠️ Do not confuse either name with
## [code]_reapply_native_cursor_visibility_with_unregistered_surface_exception()[/code]
## on [NativePointerVisibilityArbiter] (機制十三之二, [code]native_pointer_visibility_arbiter.gd[/code])
## — a private, already-implemented, unrelated method. A plain
## [code]grep reapply_native_cursor_visibility[/code] matches both; see ADR-0005's
## own "2026-09-15 命名釐清" table for why they are two different symbols.
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
##
## [b]Story U-006 (2026-09-16, `battle-menu.md` BM-9 / BM-10)[/b]: this Node's
## [member process_mode] is now [constant PROCESS_MODE_ALWAYS] (see
## [method _init]) so [method Node._process] keeps running while a pause menu
## sets [member SceneTree.paused] = [code]true[/code] — otherwise the engine
## would stop calling [method _process] on this Autoload entirely, and 機制九's
## [member _arbitration_suspended] check inside it would never execute, even
## though nothing about that flag itself changed. [b]This does not make
## [member SceneTree.paused] or [member process_mode] an arbitration gate[/b]
## (`cursor_arbitration_suspension_gate`'s `not:` entry forbids exactly that,
## and ADR-0005 機制九 explains why) — it only keeps the REAL gate,
## [member _arbitration_suspended], reachable during a pause. A new QA-only
## [member diagnostic_process_tick_count] counter (declared next to
## [member _arbitration_suspended] below) proves this in
## [code]tests/unit/cursor/cursor_host_pause_exclusion_test.gd[/code] — it
## lives on this Node rather than on [CursorState] because [CursorState] is a
## plain [RefCounted] with no [method Node._process] of its own, so it cannot
## be the thing AC-M14 needs proof of. Confirmed against a throwaway headless
## probe (this story's own report) that [member SceneTree.paused] +
## [member process_mode] are pure scheduling logic that behaves identically
## headless and windowed — unlike [member Input.mouse_mode]
## (`.claude/docs/coding-standards.md`'s "What NOT to Automate" no-op-headless
## trap), which this is NOT an instance of.
extends Node

## The single DI core this host owns for the process's lifetime. Built once
## in [method _ready], never reassigned.
##
## 🔴 [b]Corrected 2026-09-22 (U-013 dispatch)[/b]: this paragraph used to read
## "No getter exposes it by reference yet — Story 007 adds the read
## interface." Story 007 added the read interface to [CursorState] itself but
## never wired it onto this Host, so the sentence was stale the moment Story
## 007 landed. See this file's bottom section ("Story U-013: thin forwarding
## read/write/registration entries") for the forwarding methods that now
## close this gap — none of them expose [member _state] BY REFERENCE; each
## forwards to one of its own public methods, which for
## [method CursorState.get_current_target] already returns a copy.
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
## 🔴 [b]Corrected 2026-09-15 (Story 008)[/b]: this buffer no longer fills or
## drains unconditionally. [method _input], [method _process] and
## [method flush_buffered_navigation] all gate on [member _arbitration_suspended]
## first (機制五 F5). [member suspend_arbitration], [member resume_arbitration]
## and both [method _notification] FOCUS branches additionally clear this
## buffer directly, on top of the gating — see each one's own doc comment for
## why (F5's two confirmed determinism gaps: a 100%-reproducible same-frame
## race if only the gate existed, and stale-event carryover across a
## suspend/resume or focus cycle if only the gate existed without also
## clearing on every transition).
var _frame_events: Array[InputEvent] = []

## Story 008 (ADR-0005 機制九). Explicit pause/focus gate for the PASSIVE
## arbitration path only — [b]never checked by[/b] [method CursorState.set_target]
## / [method CursorState.mark_pending_reresolve] / their handoff-branch
## siblings, which the ADR calls the "呼叫方主動 API 呼叫" path and requires to
## keep working even while this flag is [code]true[/code] (存檔讀取的甲/丙分支
## may legitimately run during a pause-menu transition). This project
## deliberately rejects [member SceneTree.paused] as the gating criterion —
## see [method suspend_arbitration]'s doc comment for why.
var _arbitration_suspended: bool = false

## [b]Story U-006[/b] (`battle-menu.md` BM-10, AC-M14). QA-only, monotonically
## incrementing tick counter — proves this Node's [method _process] keeps
## executing during a real [member SceneTree.paused] = [code]true[/code]
## (thanks to [member process_mode] above), independent of whatever
## [member _arbitration_suspended] is doing. Incremented UNCONDITIONALLY, as
## the very first statement of [method _process], before either early-return
## branch — a counter that only advanced past those branches would prove
## nothing during exactly the suspended/paused period AC-M14 cares about.
##
## Per control-manifest's global [code]diagnostic_*[/code] convention ("QA/
## 測試專用,下游業務邏輯不得依賴"), nothing in this file or elsewhere reads
## this field to make a decision — see
## [code]test_diagnostic_state_does_not_affect_arbitration_suspended_flag[/code]
## in [code]tests/unit/cursor/cursor_host_pause_exclusion_test.gd[/code] for
## the executable guard. This does not reopen forbidden pattern
## [code]logic_in_cursor_autoload_shell[/code]: that pattern bars ARBITRATION
## LOGIC and duplicated GDD state fields on this shell, not a passive
## observation counter that never feeds back into any decision — the same
## category as [CursorState]'s own [code]diagnostic_*[/code] counters.
var diagnostic_process_tick_count: int = 0

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
	# Story U-006 (BM-9): survive SceneTree.paused = true so _process() below
	# (and the 機制九 _arbitration_suspended check inside it) keeps running
	# during a pause menu. Set here rather than _ready() purely to match this
	# file's existing process_priority convention (as early as possible, before
	# this Autoload is ever added to /root) — unlike process_priority there is
	# no R6-12-style ordering requirement forcing this specific placement.
	process_mode = Node.PROCESS_MODE_ALWAYS


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
## 🔴 [b]Corrected 2026-09-15 (Story 008)[/b]: gates on [member _arbitration_suspended]
## first. A suspended event is dropped here, not merely left uncollected —
## there is nothing to buffer for a later resume to replay; the ADR's own
## model is "the passive path does not run at all while suspended", not "runs
## later, delayed".
func _input(event: InputEvent) -> void:
	if _arbitration_suspended:
		return
	_frame_events.append(event)


## GDD 步驟一(機制六①): device-authority arbitration only, at THIS node's
## own [member Node.process_priority] ([code]-100[/code]) — earliest of the
## six 機制六 actors. Does [b]NOT[/b] clear [member _frame_events]: 機制六③
## ([method flush_buffered_navigation] below) still needs to read it. The
## buffer's clear point is that method, the frame's LAST consumer (機制五
## R4-1).
##
## 🔴 [b]Corrected 2026-09-15 (Story 008, F5)[/b]: also gates on
## [member _arbitration_suspended]. This closes the 100%-reproducible
## same-frame race the ADR names: without this check, an event appended by
## [method _input] in the same frame [member _arbitration_suspended] later
## flips [code]true[/code] would still be arbitrated here — this project's
## own [code]/architecture-review[/code] confirmed that race does not depend
## on any unverified engine behaviour.
func _process(_delta: float) -> void:
	# Story U-006 (BM-10): incremented unconditionally, before either
	# early-return branch below — see diagnostic_process_tick_count's own doc
	# comment for why this ordering is the entire point of the diagnostic.
	diagnostic_process_tick_count += 1
	if _arbitration_suspended or _frame_events.is_empty():
		return
	_state.arbitrate_device_authority(_frame_events)


## GDD 步驟三(機制六③), called by [member _navigation_applier] from ITS OWN
## [method Node._process] at [code]process_priority = -25[/code] — after any
## caller's own 機制六②主動改標 at the architecture-mandated open interval
## (-100, -25), both exclusive. Buffer stays private (no getter hands out the
## internal [Array] — forbidden pattern
## [code]returning_internal_container_references[/code], ADR-0001).
##
## 🔴 [b]Corrected 2026-09-15 (Story 008, F5)[/b]: also gates on
## [member _arbitration_suspended]. Per ADR-0005's own documented "R4-1 修法對
## F5 的連帶影響": if [method suspend_arbitration] runs between 機制六① and
## this method within the same frame, [member _frame_events] has already been
## cleared by [method suspend_arbitration] itself, so this early-return is
## almost always a no-op in that exact interleaving — kept anyway because the
## ADR requires it explicitly and a future change to [method suspend_arbitration]
## should not silently reopen the gap by relying on this method's emptiness
## check alone.
func flush_buffered_navigation() -> void:
	if _arbitration_suspended or _frame_events.is_empty():
		return
	_state.apply_buffered_navigation(_frame_events)
	_frame_events.clear()


## Story 008 (ADR-0005 機制九). Called by a pause menu / modal UI when it
## opens. [b]Does not touch device authority or the cursor target[/b] — only
## the passive-arbitration gate and this frame's buffer.
##
## [b]Why a explicit flag and not [member SceneTree.paused][/b]: GDD's own
## AC-60 already establishes, in its own test scenario, that non-modal
## surfaces exist which do NOT set [member SceneTree.paused] true (a
## non-modal settings sidebar, an achievement toast) — so building the
## pause/focus gate on [member SceneTree.paused] would build it on a
## criterion this project's own design documents already know is incomplete.
## See ADR-0005 機制九's "拒絕 SceneTree.paused 的理由" for the full argument.
func suspend_arbitration() -> void:
	_arbitration_suspended = true
	_frame_events.clear()


## Story 008 (ADR-0005 機制九). Called by a pause menu / modal UI when it
## closes. Reseeds the mouse-reclaim accumulator at the CURRENT mouse
## position via [method CursorState.reseed_reclaim_on_focus_regained] — a
## one-line forward, never a direct [code]_reclaim.reset(...)[/code] call
## (R5-3: [member CursorState._reclaim] is private to [CursorState], and
## choosing which [enum CursorTypes.ResetTrigger] applies IS arbitration
## logic, which this Autoload shell must not contain).
func resume_arbitration() -> void:
	_arbitration_suspended = false
	_frame_events.clear()
	_state.reseed_reclaim_on_focus_regained()


## Story 008 (ADR-0005 機制九). OS-level focus loss/regain — distinct from
## [method suspend_arbitration] / [method resume_arbitration], which a
## pause-menu/modal caller drives explicitly. Both paths converge on the same
## two effects ([member _arbitration_suspended] + buffer clear), which is why
## FOCUS_IN also reseeds via the same forwarding call FOCUS_OUT's counterpart
## [method resume_arbitration] uses.
##
## ⚠️ [b]Dispatch order across nodes is TREE order, not
## [member Node.process_priority] order[/b] (ADR-0005 S-3) — this is
## independent of, and not resolved by, whatever this method does. Nothing in
## this method may assume any other node has or has not yet observed this
## notification.
##
## 🔴 [b]force_redraw_current_authority() / reapply_native_cursor_visibility()
## are not called here because they no longer exist[/b] — both were deleted
## from ADR-0005 itself on 2026-09-15 (manager ruling, commit
## [code]599108e[/code]), not merely left unbuilt. See this file's class doc
## comment's "Removed from ADR-0005, not a pending gap" paragraph for the full
## finding and why Story 011's per-frame polling already covers what these two
## calls used to do.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_arbitration_suspended = true
			_frame_events.clear()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_arbitration_suspended = false
			_frame_events.clear()
			_state.reseed_reclaim_on_focus_regained()


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


# ─── Story U-013: thin forwarding read/write/registration entries ──────────
#
# 🔴 Added 2026-09-22 (U-013 dispatch, godot-specialist ruling). This file's
# own class doc comment already flagged this as a known, anticipated gap
# ("No getter exposes it by reference yet — Story 007 adds the read
# interface."). Story 007 landed CursorState's OWN read queries but never
# wired them onto this Autoload, so U-013 — the first downstream consumer
# that is NOT a child node this Host constructs itself (unlike Story 011's
# [SelfDrawnReclaimCursor] / [NativePointerVisibilityArbiter], which receive
# [param _state]/[param _registry] via direct constructor injection) — had no
# handle to reach either collaborator through.
#
# Every method below is a ONE-LINE FORWARD with zero added decision logic —
# the same shape ADR-0005's Key Interfaces section already documents for this
# class ("全部公開 API 為對 _state 的一行轉發,不新增任何判斷邏輯") and the same
# shape [method suspend_arbitration] / [method resume_arbitration] above
# already use. This completes previously-anticipated wiring under an already-
# `Accepted` governing principle; it is not a new architectural decision, and
# ADR-0005 is not being reopened (see that document's Key Interfaces
# `CursorStateHost` block for the matching factual-correction note).
#
# Deliberately NOT added here (flagged, not silently omitted — do not add
# these without a story that actually needs them):
#   - mark_pending_reresolve() — U-013's own scope excludes external
#     mid-selection invalidation (see that story's "Out of Scope" section).
#   - handoff_before_unload() / handoff_after_mount() — 機制十一 screen-
#     transition lifecycle, not this story.
#   - reclaim_progress() / reclaim_reset_triggered forwarding — 機制十三's
#     presentation layer already reaches [member _state] via direct
#     constructor injection (Story 011); not battle_screen.gd's concern.
#   - target_changed() / device_authority_changed() signal forwarding —
#     U-013's own Implementation Note #1 commits to polling in
#     [method Node._process] at [code]process_priority = 100[/code], not
#     signal subscription.


## Forwards to [method CursorState.is_current_target_valid] (ADR-0005 機制十,
## TR-cursor-014). Gates confirm/select actions. Callers belonging to 機制六⑥
## (下游讀取方) MUST read this from their OWN node's [method Node._process] at
## [code]process_priority = 100[/code] — never from [code]_input()[/code] /
## [code]_unhandled_input()[/code] (機制六 Requirements 第 11 項).
func is_current_target_valid() -> bool:
	return _state.is_current_target_valid()


## Forwards to [method CursorState.get_device_authority] (ADR-0005 機制十,
## TR-cursor-014). Gates mouse-click confirmation. See that method's own doc
## comment for why this is a separate query from
## [method is_current_target_valid] rather than one merged boolean — the two
## rejection causes need opposite recoveries.
func get_device_authority() -> CursorTypes.Authority:
	return _state.get_device_authority()


## Forwards to [method CursorState.get_current_target] (ADR-0005 機制十,
## TR-cursor-014). Returns a freshly allocated COPY, never the internal
## instance — that discipline lives entirely inside [CursorState] itself
## (forbidden pattern [code]returning_internal_container_references[/code],
## ADR-0001), so this one-line forward cannot leak the internal reference
## even by accident.
func get_current_target() -> CursorTarget:
	return _state.get_current_target()


## Forwards to [method CursorState.set_target] (ADR-0005 機制十,
## TR-cursor-012). This is the 機制六② "呼叫方主動改標" entry point — a caller
## using this (e.g. a jump-to-next-legal-target action that is NOT itself a
## [constant CursorTypes.ActionClass.NAVIGATION]-class [code]ui_*[/code]
## action, and therefore never reaches 機制六③'s buffered-navigation path at
## all) must call this from ITS OWN node's [method Node._process] at a
## [code]process_priority[/code] strictly between -100 and -25 (architecture-
## mandated open interval, R5-2) — never from [code]_input()[/code].
func set_target(target: CursorTarget) -> CursorState.SetTargetResult:
	return _state.set_target(target)


## Forwards to [method CursorSurfaceRegistry.register] (ADR-0005 機制三,
## TR-cursor-003). Registers the [Node] that represents a mounted
## [code]CursorSurface[/code] under a [enum CursorTypes.SurfaceType] tag —
## single-tag, single-instance; fails loud
## ([constant CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED])
## on an already-occupied tag rather than silently overwriting.
## [b]Registering a surface is also the precondition for 機制六③'s "Option E"
## navigation contract[/b] (see [constant CursorState.NAVIGATE_METHOD_NAME]):
## the registered [param node] must implement
## [code]func cursor_navigate(from_id: int, direction: Vector2i) -> Variant[/code]
## by name for directional keyboard/gamepad navigation to do anything on this
## surface tag — registering alone does not satisfy that contract.
func register_surface(surface: CursorTypes.SurfaceType, node: Node) -> CursorSurfaceRegistry.RegisterResult:
	return _registry.register(surface, node)


## Forwards to [method CursorSurfaceRegistry.unregister] (ADR-0005 機制三,
## TR-cursor-003). Callers MUST call this explicitly when their surface
## unmounts — this table has no automatic cleanup (unlike the AC-60 exception
## whitelist, which auto-deregisters on [signal Node.tree_exited]).
func unregister_surface(surface: CursorTypes.SurfaceType) -> CursorSurfaceRegistry.RegisterResult:
	return _registry.unregister(surface)
