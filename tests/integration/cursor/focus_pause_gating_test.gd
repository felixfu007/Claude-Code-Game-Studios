## Integration tests for Story 008 — 焦點/暫停閘控 (ADR-0005 機制九), built on
## [CursorStateHost] (Story 002/005/007/010/011) + [CursorState] (Story
## 002/005/007) + [CursorSurfaceRegistry] (Story 003).
##
## Covers AC-18 / AC-21 / AC-22 / AC-23 / AC-30 / AC-30b from
## [code]production/epics/cursor-highlight-state/story-008-focus-pause-gating.md[/code],
## plus AC-59 (present in that story file's own Acceptance Criteria section,
## even though this story's dispatch brief listed only the other six — see
## this story's final report for that discrepancy) and an explicit,
## executable architectural guard this story's own investigation originally
## registered as a gap (ADR-0005's Key Interfaces once listed two
## [CursorState] methods neither this nor any prior story ever built — on
## 2026-09-15 the manager ruled to delete both from the ADR itself, so this
## same assertion now guards against their reintroduction rather than
## tracking pending work; see
## [method test_force_redraw_and_reapply_native_cursor_visibility_stay_removed_from_cursor_state]
## below for the full history).
##
## [b]Isolation — every test builds its OWN detached [CursorStateHost]-script
## instance, the real registered Autoload singleton at [code]/root[/code] is
## NEVER touched, read or written by any test in this file[/b]. This is a
## stronger version of the convention
## [code]tests/integration/cursor/screen_handoff_test.gd[/code] and
## [code]tests/integration/cursor/frame_buffer_ordering_test.gd[/code] already
## state for [CursorState] alone ("the CursorStateHost Autoload is never
## touched by any test in this file") — here it extends to the [Node]
## wrapper itself, via [method _fresh_host] below. This sidesteps the
## shared-Autoload write hazard [code]tests/unit/cursor/state_host_test.gd[/code]'s
## own class doc comment warns about entirely, rather than managing it with
## per-test setup/teardown discipline: [member CursorStateHost._arbitration_suspended]
## defaults to [code]false[/code] on every freshly-[method Node._ready] instance,
## so there is no shared mutable field for one test's leftover state to poison
## another test in this file OR any other file's use of the real Autoload.
##
## [b]Why a fresh instance rather than the real Autoload[/b]: several
## Acceptance Criteria here (AC-30b especially) require driving the injected
## mouse-position [Callable] to specific, controlled coordinates — the real
## Autoload's provider is [code]get_viewport().get_mouse_position()[/code],
## which this project's own [code]coding-standards.md[/code] documents as
## engine-controlled and not independently steerable in a headless run. See
## [method _install_controllable_state].
##
## [b]Determinism[/b]: [method Node._ready] / [method Node._input] /
## [method Node._process] / [method CursorStateHost.flush_buffered_navigation] /
## [method CursorStateHost.suspend_arbitration] /
## [method CursorStateHost.resume_arbitration] / [method Node._notification]
## are all invoked as PLAIN DIRECT METHOD CALLS on a [Node] that is never
## added to a live [SceneTree] — the same convention
## [code]tests/unit/cursor/state_host_test.gd[/code] already established for
## [method Node._input]/[method Node._process] on the real Autoload, extended
## here to [method Node._ready] and [method Node._notification] so that
## nothing is ever driven by the engine's own automatic per-frame ticking
## (which would make these tests non-deterministic and liable to interleave
## with whatever else is running in the same headless process). No random
## seed, no timer, no [code]await[/code], no external I/O.
extends GdUnitTestSuite


## [code]CursorStateHost[/code] deliberately declares NO [code]class_name[/code]
## (see that file's own class doc comment) — this [preload] is both the type
## used to construct a fresh instance ([method GDScript.new]) and, elsewhere
## in this project, the only way to identify "is this node running this exact
## script" without one.
const _CursorStateHostScript: GDScript = preload("res://src/ui/cursor/cursor_state_host.gd")

## Surface tag every test in this file registers and targets.
const _SURFACE: CursorTypes.SurfaceType = CursorTypes.SurfaceType.BOARD_TILE


## Recording [MouseReclaimPolicy] test double — same shape as
## [code]frame_buffer_ordering_test.gd[/code]'s / [code]screen_handoff_test.gd[/code]'s
## own [code]_RecordingReclaimPolicy[/code], duplicated rather than shared
## across files (Isolation, same reasoning those files already document).
class _RecordingReclaimPolicy extends MouseReclaimPolicy:
	## Incremented on every [method evaluate] call — this file's own
	## discriminator for "was the passive arbitration path actually invoked
	## this frame", independent of what it returned.
	var evaluate_calls: int = 0
	## Settable stand-in for "the mouse has a same-frame valid reclaim
	## candidate" (機制八's concrete math is Story 014's frozen sub-mechanism,
	## out of this story's scope — see
	## [code]frame_buffer_ordering_test.gd[/code]'s own precedent for this
	## exact double shape).
	var claims_mouse: bool = false
	var progress: float = 0.0
	var reset_calls: Array[Dictionary] = []

	func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
		evaluate_calls += 1
		return claims_mouse

	func reclaim_progress() -> float:
		return progress

	func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void:
		reset_calls.append({"position": seed_position, "trigger": trigger})
		progress = 0.0
		reset_triggered.emit(trigger)

	func diagnostic_seed_position() -> Vector2:
		if reset_calls.is_empty():
			return Vector2.ZERO
		return reset_calls[-1]["position"]

	## Convenience for assertions: just the trigger sequence, in call order.
	func triggers() -> Array[CursorTypes.ResetTrigger]:
		var out: Array[CursorTypes.ResetTrigger] = []
		for call_record: Dictionary in reset_calls:
			out.append(call_record["trigger"])
		return out


## Test double for Story 005's Option E navigation contract — same shape as
## [code]frame_buffer_ordering_test.gd[/code]'s own [code]_FakeNavigableSurface[/code],
## duplicated for the same Isolation reason.
class _FakeNavigableSurface extends Node:
	var next_response: Variant = null

	func cursor_navigate(_from_id: int, _direction: Vector2i) -> Variant:
		return next_response


## Controllable stand-in for [code]Viewport.get_mouse_position()[/code] —
## tests change this directly between steps to simulate the mouse moving to a
## specific, known coordinate, which the real Autoload's
## [code]get_viewport()[/code]-bound provider cannot be made to do headless.
var _mouse_position: Vector2 = Vector2(100.0, 100.0)


func _test_mouse_position() -> Vector2:
	return _mouse_position


## Pulls the REAL, live-[InputMap]-bound event for [param action] and
## duplicates it — same convention as
## [code]tests/integration/cursor/frame_buffer_ordering_test.gd[/code]'s own
## [code]_real_event[/code], for the same reason (a hand-constructed
## [InputEventKey] risks silently not matching
## [method InputMap.event_is_action] if a guessed keycode is wrong).
func _real_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).duplicate()
	return null


func _target(id: int) -> CursorTarget:
	return CursorTarget.make(_SURFACE, id)


## Builds a FRESH, DETACHED [code]CursorStateHost[/code]-script instance —
## see this file's class doc comment for why this is never the real
## registered Autoload. [method Node._ready] is called directly as a plain
## method (matching this project's established convention of invoking [Node]
## overrides directly in headless tests, e.g.
## [code]tests/unit/cursor/state_host_test.gd[/code]'s [code]host._process(0.0)[/code]),
## which builds [member CursorStateHost._state] / [member CursorStateHost._registry] /
## the [CanvasLayer] presentation subtree exactly as the real Autoload's own
## [method Node._ready] does — the host is never added to a live [SceneTree],
## so none of that subtree is ever automatically ticked by the engine.
## [method GdUnitTestSuite.auto_free] frees the whole subtree (children
## included) at teardown, avoiding orphans.
func _fresh_host() -> Node:
	var host: Node = _CursorStateHostScript.new()
	host._ready()
	auto_free(host)
	return host


## Replaces the host's internally-built [CursorState] (real
## [ThresholdMouseReclaimPolicy], real [code]Viewport[/code]-bound mouse
## provider) with one built from [param reclaim] and this file's own
## controllable [method _test_mouse_position]. The internally-built default
## collaborators become inert orphaned children of [param host] (harmless —
## nothing in this file exercises them) once [member CursorStateHost._state]
## is reassigned via [method Object.set]. Also registers a fresh
## [_FakeNavigableSurface] under [constant _SURFACE] on the NEW
## [CursorState]'s own [CursorSurfaceRegistry] (a separate instance from
## [member CursorStateHost._registry], which still points at the original —
## harmless for the same reason).
func _install_controllable_state(host: Node, reclaim: _RecordingReclaimPolicy) -> Dictionary:
	var registry: CursorSurfaceRegistry = CursorSurfaceRegistry.new()
	var surface: _FakeNavigableSurface = _FakeNavigableSurface.new()
	auto_free(surface)
	registry.register(_SURFACE, surface)
	var state: CursorState = CursorState.new(reclaim, registry, Callable(self, "_test_mouse_position"))
	host.set(&"_state", state)
	return {"state": state, "registry": registry, "surface": surface}


## Appends a fake event DIRECTLY into the live [member CursorStateHost._frame_events]
## array, bypassing [method Node._input]'s own suspend gate — used to prove
## the gate inside [method Node._process] /
## [method CursorStateHost.flush_buffered_navigation] is what blocks
## arbitration while suspended, not merely "the buffer happened to be empty".
func _inject_residual_event(host: Node) -> void:
	var buffer: Array = host.get(&"_frame_events")
	buffer.append(InputEventKey.new())


# ═══════════════════════════════════════════════════════════════════════════
# 🔴 Architectural guard, NOT a gap registration (renamed 2026-09-15 — see the
# test's own doc comment below for the full history and why the OLD framing
# below no longer applies). cursor_state_host.gd's class doc comment ("Discovered
# gap" paragraph) still uses the pre-2026-09-15 gap framing as of this writing
# — that is a src/ file, out of this test-file-only change's authorized scope;
# flagged in this story's report rather than edited here.
# ═══════════════════════════════════════════════════════════════════════════

## 🔴 [b]This is an architectural guard, not a gap registration[/b] — the
## test's ASSERTIONS are unchanged since it was first written, but their
## MEANING changed on 2026-09-15. Originally this documented a temporary gap:
## ADR-0005's frozen Key Interfaces section listed
## [code]CursorState.force_redraw_current_authority()[/code] (tagged "# AC-30")
## and [code]CursorState.reapply_native_cursor_visibility()[/code] (tagged
## "# Core Rules #5") as calls this story's [method Node._notification]
## FOCUS_IN branch was expected to eventually make, and neither existed yet.
##
## 🔴 [b]On 2026-09-15 the manager ruled to delete both methods from ADR-0005
## itself[/b] (verbatim ruling: 「更正架構文件,拿掉那兩個方法」— commit
## [code]599108e[/code]), because Story 011 already achieves AC-30's visual
## guarantee a different way: [code]SelfDrawnReclaimCursor._process()[/code]
## and [code]NativePointerVisibilityArbiter._process()[/code] unconditionally
## re-derive their output from [CursorState] every frame regardless of
## [member CursorStateHost._arbitration_suspended] or window focus, so nothing
## needs to be explicitly "reapplied" on FOCUS_IN. See
## [code]docs/architecture/adr-0005-cursor-device-authority-input-architecture.md[/code]'s
## 機制九 section, "🔴 2026-09-15 事實層更正" (and the matching entry against the
## Key Interfaces list further down the same file), for the full ruling and
## the zero-hits [code]grep -rn[/code] the technical director ran against all
## of [code]src/[/code] as of that date.
##
## This test therefore no longer pins down "not built yet, still to do" — it
## pins down [b]"must never come back"[/b]: these two names were removed from
## the architecture that specified them, and their reintroduction would be an
## undocumented, unreviewed re-opening of that 2026-09-15 ruling, not a
## completion of pending work. If this assertion ever FAILS because one of
## these methods was added back to [code]cursor_state.gd[/code], that is a
## regression against the ruling above, not a milestone — stop and get the
## addition reviewed against ADR-0005 before touching this test.
##
## ⚠️ Do not confuse either name with
## [code]_reapply_native_cursor_visibility_with_unregistered_surface_exception()[/code]
## — a private, already-implemented, unrelated method on the hover arbiter
## node (機制十三之二), documented in ADR-0005's own "2026-09-15 命名釐清" table
## specifically because a plain [code]grep reapply_native_cursor_visibility[/code]
## matches both. This test's [FileAccess]-based string search below targets
## [code]cursor_state.gd[/code] only, so it was never at risk of matching that
## unrelated method — noted here only so the next reader does not go looking
## for it.
func test_force_redraw_and_reapply_native_cursor_visibility_stay_removed_from_cursor_state() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/ui/cursor/cursor_state.gd")

	assert_bool(source.contains("func force_redraw_current_authority")).append_failure_message(
		"force_redraw_current_authority() now exists on CursorState — ADR-0005 "
		+ "deleted this method on 2026-09-15 (commit 599108e); its "
		+ "reintroduction is a regression against that ruling, not a "
		+ "completion of pending work. Get it reviewed against ADR-0005's "
		+ "機制九 \"2026-09-15 事實層更正\" section before updating this test."
	).is_false()
	assert_bool(source.contains("func reapply_native_cursor_visibility")).append_failure_message(
		"reapply_native_cursor_visibility() now exists on CursorState — ADR-0005 "
		+ "deleted this method on 2026-09-15 (commit 599108e); its "
		+ "reintroduction is a regression against that ruling, not a "
		+ "completion of pending work. Get it reviewed against ADR-0005's "
		+ "機制九 \"2026-09-15 事實層更正\" section before updating this test."
	).is_false()


# ═══════════════════════════════════════════════════════════════════════════
# AC-18: mouse holds authority; mouse leaves the window; target/authority
# stay at their last valid value; no state change while nothing arrives.
# ═══════════════════════════════════════════════════════════════════════════

## 🔴 [b]What this test does and does not model[/b]: this system never reads
## raw [InputEventMouseMotion] for arbitration purposes (機制四之二 classifies
## it [code]OTHER[/code]; the reclaim policy reads absolute position only
## INSIDE [method CursorState.arbitrate_device_authority], itself only
## invoked by [method Node._process] when the frame buffer is non-empty).
## "Mouse outside the window" is modelled here as "zero events arrive for
## several frames" — the only state this system could possibly change on
## that account, and a guarantee that predates this story (Story 005's
## empty-buffer guard) but is listed as this story's own AC, so this is
## explicit regression coverage at the [CursorStateHost] level, not a claim
## that Story 008 invented this behaviour.
func test_ac18_mouse_authority_and_target_frozen_while_nothing_arrives_from_outside_the_window() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]

	# Arrange — GIVEN: mouse currently holds authority, at a known target.
	reclaim.claims_mouse = true
	state.arbitrate_device_authority([])
	assert_int(state.get_device_authority()).append_failure_message(
		"PRECONDITION: mouse did not claim authority."
	).is_equal(CursorTypes.Authority.MOUSE)
	assert_int(state.set_target(_target(3))).is_equal(CursorState.SetTargetResult.APPLIED)
	var evaluate_calls_before: int = reclaim.evaluate_calls

	# Act — WHEN: several frames pass with a genuinely empty buffer (no
	# host._input() call at all).
	for frame_index: int in range(3):
		host._process(0.0)
		host.flush_buffered_navigation()
		assert_int(state.get_device_authority()).append_failure_message(
			"frame %d: device authority changed with no new events." % frame_index
		).is_equal(CursorTypes.Authority.MOUSE)
		assert_int(state.get_current_target().id).append_failure_message(
			"frame %d: target changed with no new events." % frame_index
		).is_equal(3)

	# Assert — THEN: not merely "unchanged", but genuinely never re-evaluated.
	assert_int(reclaim.evaluate_calls).append_failure_message(
		"arbitrate_device_authority() ran despite an empty buffer — the "
		+ "mouse position would have been silently re-evaluated while "
		+ "outside the window."
	).is_equal(evaluate_calls_before)


# ═══════════════════════════════════════════════════════════════════════════
# AC-21: gamepad holds authority; gamepad disconnects; next frame(s):
# target/authority identical, highlight persists (untestable headless — see
# report), state stays still if nothing else ever arrives.
# ═══════════════════════════════════════════════════════════════════════════

## 🔴 [Input.joy_connection_changed] is a completely separate signal from
## this system's [InputEvent]-buffered path (機制五/機制九) — a disconnected
## controller simply stops producing events. Modelled the same way as AC-18.
func test_ac21_gamepad_authority_and_target_frozen_across_a_simulated_disconnect() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]
	var surface: _FakeNavigableSurface = fixture["surface"]

	# Arrange — GIVEN: gamepad (KEYBOARD_GAMEPAD bucket) holds authority at a
	# known target.
	var nav_event: InputEventKey = _real_event(&"ui_right")
	assert_object(nav_event).append_failure_message(
		"PRECONDITION: no real InputEventKey bound to ui_right."
	).is_not_null()
	surface.next_response = 7
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(state.get_current_target().id).is_equal(7)

	# Act / Assert — WHEN: the gamepad disconnects — zero events from any
	# device across several frames.
	for frame_index: int in range(3):
		host._process(0.0)
		host.flush_buffered_navigation()
		assert_int(state.get_device_authority()).append_failure_message(
			"frame %d: authority changed after the simulated disconnect with "
			+ "no new input from any device." % frame_index
		).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
		assert_int(state.get_current_target().id).is_equal(7)


# ═══════════════════════════════════════════════════════════════════════════
# AC-22: after the frozen period above, mouse produces a valid action ⇒
# transfers per Group B, inherits the frozen target per Group C.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac22_mouse_input_after_the_frozen_period_transfers_authority_and_inherits_the_frozen_target() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]
	var surface: _FakeNavigableSurface = fixture["surface"]

	# Arrange — GIVEN: the AC-21 scenario (gamepad held authority, then a
	# simulated disconnect with the state frozen for at least one frame).
	var nav_event: InputEventKey = _real_event(&"ui_right")
	surface.next_response = 7
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])
	host._process(0.0)
	host.flush_buffered_navigation()  # one frozen frame, empty buffer

	# Act — WHEN: the mouse subsequently produces a valid claim.
	reclaim.claims_mouse = true
	state.arbitrate_device_authority([])

	# Assert — THEN: authority transfers to MOUSE (Group B), and the target
	# is UNTOUCHED by the transfer itself (Group C inheritance —
	# arbitrate_device_authority()'s AUTHORITY_TRANSFER branch in
	# cursor_state.gd never writes _target), so it still reads the
	# pre-disconnect value.
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.MOUSE)
	assert_int(state.get_current_target().id).append_failure_message(
		"target was not inherited across the authority transfer — Group C's "
		+ "handoff-continuation rule requires the pre-disconnect target to "
		+ "survive the transfer."
	).is_equal(7)

	# And: if nothing further ever arrives, the state stays still (same
	# guarantee as AC-18/AC-21, re-asserted post-transfer).
	host._process(0.0)
	host.flush_buffered_navigation()
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.MOUSE)
	assert_int(state.get_current_target().id).is_equal(7)


# ═══════════════════════════════════════════════════════════════════════════
# AC-23: pause menu / modal dialog — passive path suspended; background
# input and menu-internal navigation do not touch state; restored exactly on
# resume.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac23_pause_menu_suspends_the_passive_path_and_state_is_unchanged_on_resume() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]
	var surface: _FakeNavigableSurface = fixture["surface"]

	# Arrange — GIVEN: cursor holds a specific target and device authority.
	var nav_event: InputEventKey = _real_event(&"ui_right")
	surface.next_response = 11
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	var evaluate_calls_before: int = reclaim.evaluate_calls
	# UNINITIALIZED -> KEYBOARD_GAMEPAD above is itself an AUTHORITY_TRANSFER
	# (機制六①'s own contract: any authority CHANGE resets the reclaim
	# accumulator, not only a transfer away from a real device) — that reset
	# call is part of the GIVEN setup, not part of what this test is
	# measuring. Cleared here so the assertions below observe only what
	# happens from the pause onward.
	reclaim.reset_calls.clear()

	# Act — WHEN: a pause menu opens (explicit flag, NOT SceneTree.paused —
	# see suspend_arbitration()'s own doc comment for why).
	host.suspend_arbitration()
	assert_bool(host.get(&"_arbitration_suspended")).is_true()
	assert_array(host.get(&"_frame_events")).is_empty()

	# Background input signal / menu-internal gamepad navigation, arriving
	# while suspended.
	host._input(_real_event(&"ui_down"))
	assert_array(host.get(&"_frame_events")).append_failure_message(
		"an event arriving while suspended was appended to the buffer — "
		+ "_input() must drop it, not merely leave it uncollected."
	).is_empty()
	host._process(0.0)
	host.flush_buffered_navigation()

	# Assert — mid-pause: nothing moved.
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(state.get_current_target().id).is_equal(11)
	assert_int(reclaim.evaluate_calls).append_failure_message(
		"arbitrate_device_authority() ran while suspended."
	).is_equal(evaluate_calls_before)

	# Act — WHEN: the player closes the menu.
	host.resume_arbitration()

	# Assert — THEN: authority and target are exactly what they were before
	# the pause — resume_arbitration() only reseeds the reclaim accumulator,
	# never touches either field.
	assert_bool(host.get(&"_arbitration_suspended")).is_false()
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(state.get_current_target().id).is_equal(11)
	assert_array(reclaim.triggers()).append_failure_message(
		"resume_arbitration() did not reseed the reclaim accumulator via the "
		+ "real CursorState.reseed_reclaim_on_focus_regained() forward."
	).is_equal([CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED])


# ═══════════════════════════════════════════════════════════════════════════
# AC-59 (present in the story file's own Acceptance Criteria section; not
# listed in this story's dispatch brief — see this story's final report):
# pause never consumes input for its own arbitration, even mid-reclaim
# progress; resume zeroes the accumulator and reseeds at the CURRENT mouse
# position.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac59_pause_never_consumes_input_for_its_own_arbitration_mid_reclaim_progress() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]
	var surface: _FakeNavigableSurface = fixture["surface"]

	# Arrange — GIVEN: keyboard/gamepad holds authority, mouse reclaim
	# progress sits at an arbitrary MID value (strictly between 0 and the
	# threshold — "介於 0 與門檻之間").
	var nav_event: InputEventKey = _real_event(&"ui_right")
	surface.next_response = 5
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])
	reclaim.progress = 0.4
	var evaluate_calls_before: int = reclaim.evaluate_calls
	# UNINITIALIZED -> KEYBOARD_GAMEPAD above already fired one
	# AUTHORITY_TRANSFER reset as part of the GIVEN setup — cleared so the
	# reset_calls assertions below observe only the pause/resume cycle.
	reclaim.reset_calls.clear()

	# Act — WHEN: pause/modal opens, and — adversarially — an event is placed
	# directly into the buffer (bypassing _input()'s own gate), to prove the
	# gate inside _process()/flush_buffered_navigation() is what blocks
	# arbitration, not merely "the buffer happened to be empty".
	host.suspend_arbitration()
	_inject_residual_event(host)
	host._process(0.0)
	host.flush_buffered_navigation()

	# Assert — THEN: this system's own arbitration logic never ran, even with
	# an artificially non-empty buffer, so the accumulator never moved.
	assert_int(reclaim.evaluate_calls).append_failure_message(
		"the reclaim accumulator was evaluated during pause despite an "
		+ "artificially non-empty buffer — the suspend gate must block this "
		+ "regardless of buffer contents."
	).is_equal(evaluate_calls_before)
	assert_float(reclaim.progress).is_equal_approx(0.4, 0.0001)

	# Act — WHEN: the player closes the pause menu. Move the mouse-position
	# probe to a NEW value first, so the reseed below can only match it if it
	# is really reading the CURRENT position.
	_mouse_position = Vector2(999.0, 888.0)
	host.resume_arbitration()

	# Assert — THEN: accumulator reset to 0, reseeded at the CURRENT mouse
	# screen coordinate — not the coordinate from before the pause — and
	# authority/target unchanged.
	assert_float(reclaim.progress).is_equal_approx(0.0, 0.0001)
	assert_int(reclaim.reset_calls.size()).is_equal(1)
	assert_vector(reclaim.reset_calls[0]["position"]).append_failure_message(
		"resume seeded the reclaim accumulator at a stale mouse position "
		+ "instead of the current one."
	).is_equal(Vector2(999.0, 888.0))
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(state.get_current_target().id).is_equal(5)


# ═══════════════════════════════════════════════════════════════════════════
# AC-30: OS focus lost then regained — CursorStateHost-level state transition
# (suspend/clear/reseed). The two VISUAL halves of this AC (highlight
# confirmed redrawn, native pointer visibility reapplied) are addressed in
# this test's own comments and in this story's report, not asserted headless
# — see the reasoning inline.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac30_focus_out_then_focus_in_suspends_clears_and_reseeds_via_notification() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]
	var surface: _FakeNavigableSurface = fixture["surface"]

	# Arrange — GIVEN: cursor holds a target and device authority.
	var nav_event: InputEventKey = _real_event(&"ui_right")
	surface.next_response = 9
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])
	# UNINITIALIZED -> KEYBOARD_GAMEPAD above already fired one
	# AUTHORITY_TRANSFER reset as part of the GIVEN setup — cleared so the
	# triggers()/reset_calls assertions below observe only the focus cycle.
	reclaim.reset_calls.clear()

	# Simulate a residual event buffered the same frame OS focus is lost.
	_inject_residual_event(host)

	# Act — WHEN: the window loses OS-level focus.
	host._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)

	# Assert
	assert_bool(host.get(&"_arbitration_suspended")).is_true()
	assert_array(host.get(&"_frame_events")).append_failure_message(
		"NOTIFICATION_APPLICATION_FOCUS_OUT did not clear the frame buffer."
	).is_empty()

	# Simulate the mouse moving to a new position while unfocused, and
	# another residual event present the instant focus returns.
	_mouse_position = Vector2(42.0, 77.0)
	_inject_residual_event(host)

	# Act — WHEN: the window regains OS-level focus.
	host._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	# Assert
	assert_bool(host.get(&"_arbitration_suspended")).is_false()
	assert_array(host.get(&"_frame_events")).append_failure_message(
		"NOTIFICATION_APPLICATION_FOCUS_IN did not clear the frame buffer."
	).is_empty()
	assert_array(reclaim.triggers()).append_failure_message(
		"FOCUS_IN did not reseed the reclaim accumulator via "
		+ "CursorState.reseed_reclaim_on_focus_regained()."
	).is_equal([CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED])
	assert_vector(reclaim.reset_calls[0]["position"]).append_failure_message(
		"the reseed used a stale mouse position instead of the current one."
	).is_equal(Vector2(42.0, 77.0))
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(state.get_current_target().id).is_equal(9)

	# 🔴 NOT asserted here, and why: AC-30's other two clauses ("the highlight
	# visual is confirmed redrawn", "native pointer visibility is reapplied")
	# are visual/engine-applied effects. As of 2026-09-15 ADR-0005 no longer
	# specifies force_redraw_current_authority() / reapply_native_cursor_visibility()
	# at all (manager ruling, commit 599108e — see
	# test_force_redraw_and_reapply_native_cursor_visibility_stay_removed_from_cursor_state
	# above for the full history). Those two names were REMOVED from the ADR
	# itself, not merely left unbuilt, so there is nothing left here to "not
	# call yet". What actually covers AC-30's visual half is a structural
	# fact, unaffected by that ruling:
	# (1) SelfDrawnReclaimCursor._process() and
	#     NativePointerVisibilityArbiter._process() (Story 011) both already
	#     re-derive their output from _state UNCONDITIONALLY every frame —
	#     neither checks _arbitration_suspended or window focus at all — so
	#     structurally they self-correct on the next tick regardless of
	#     whether an explicit "reapply" is ever called. This is readable
	#     directly from those two files' _process() bodies, not asserted by
	#     a headless test here (Input.mouse_mode writes are a documented
	#     engine no-op headless per coding-standards.md, and there is no
	#     registered CursorSurface anywhere in src/ yet whose "redraw" could
	#     be asserted against — see frame_buffer_ordering_test.gd's own
	#     registered gap test for that fact).
	# (2) ADR-0005 itself registers one honestly-open gap this structural
	#     argument does NOT cover: subscriber-only downstreams that never
	#     poll _state per-frame receive no signal on refocus (the target is
	#     unchanged across a focus cycle, so target_changed() never fires) —
	#     see the ADR's 機制九 "🔴 2026-09-15 事實層更正" section, subsection
	#     "本次更正「未」涵蓋的一項". AC-30's first clause is not "fully
	#     covered" until the first real CursorSurface lands and answers that
	#     question.


# ═══════════════════════════════════════════════════════════════════════════
# AC-30b: mid-progress mouse-reclaim accumulation frozen through an entire
# defocus period (never creeping toward/crossing the threshold), reset to 0
# and reseeded at the POST-defocus mouse position on refocus.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac30b_accumulator_frozen_through_defocus_then_reset_and_reseeded_at_the_post_defocus_position() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]
	var surface: _FakeNavigableSurface = fixture["surface"]

	# Arrange — GIVEN: keyboard/gamepad holds authority, mouse reclaim
	# accumulation sits at a mid value (0 < progress < 1) — an in-progress but
	# not-yet-completed reclaim attempt.
	var nav_event: InputEventKey = _real_event(&"ui_right")
	surface.next_response = 6
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])
	reclaim.progress = 0.4
	var evaluate_calls_before: int = reclaim.evaluate_calls
	# UNINITIALIZED -> KEYBOARD_GAMEPAD above already fired one
	# AUTHORITY_TRANSFER reset as part of the GIVEN setup — cleared so the
	# reset_calls assertion below observes only the post-refocus reseed.
	reclaim.reset_calls.clear()

	# Act — WHEN: the window loses OS-level focus.
	host._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_bool(host.get(&"_arbitration_suspended")).is_true()

	# WHEN (during defocus): the mouse is actually moved to several different,
	# far-away positions across several simulated frames, each with a residual
	# event forced into the buffer (adversarial — proves the freeze holds even
	# when the buffer is not naturally empty).
	var defocus_positions: Array[Vector2] = [Vector2(500.0, 10.0), Vector2(9.0, 640.0), Vector2(-30.0, -30.0)]
	for position: Vector2 in defocus_positions:
		_mouse_position = position
		_inject_residual_event(host)
		host._process(0.0)
		host.flush_buffered_navigation()

		# THEN (i): during the ENTIRE defocus period, the accumulated
		# displacement field stays at its pre-defocus value, never updated —
		# not even re-evaluated — regardless of how far the mouse actually
		# moved.
		assert_int(reclaim.evaluate_calls).append_failure_message(
			"the reclaim accumulator was re-evaluated during defocus at mouse "
			+ "position %s — it must never run while suspended, so it can "
			+ "never creep toward or cross the reclaim threshold." % position
		).is_equal(evaluate_calls_before)
		assert_float(reclaim.progress).append_failure_message(
			"reclaim progress changed during defocus at mouse position %s "
			+ "instead of staying frozen at its pre-defocus value." % position
		).is_equal_approx(0.4, 0.0001)

	# Act — WHEN: the window regains OS-level focus, at the LAST (most
	# recent, post-defocus) mouse position from the loop above.
	host._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	# Assert — THEN (ii): the frame after FOCUS_IN, the field is reset to 0,
	# reseeded at the CURRENT (post-defocus) mouse coordinate — not any
	# position visited during the defocus period, and not the pre-defocus
	# seed either.
	assert_float(reclaim.progress).append_failure_message(
		"reclaim progress was not reset to 0 on the frame after FOCUS_IN."
	).is_equal_approx(0.0, 0.0001)
	assert_int(reclaim.reset_calls.size()).is_equal(1)
	assert_vector(reclaim.reset_calls[0]["position"]).append_failure_message(
		"the post-refocus reseed did not use the CURRENT (post-defocus) mouse "
		+ "position — a stale or intermediate defocus-period position would "
		+ "let a spurious high displacement reading leak into the very next "
		+ "reclaim evaluation, exactly what this AC forbids."
	).is_equal(defocus_positions[-1])
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(state.get_current_target().id).is_equal(6)


# ═══════════════════════════════════════════════════════════════════════════
# F5 structural coverage: all four suspend/resume/focus transitions clear the
# frame buffer — the ADR's own named "two deterministic gaps" (F5: a
# 100%-reproducible same-frame race, and stale-event carryover), pinned here
# as regression coverage independent of any single AC number.
# ═══════════════════════════════════════════════════════════════════════════

func test_suspend_arbitration_clears_the_frame_buffer() -> void:
	var host: Node = _fresh_host()
	_inject_residual_event(host)
	host.suspend_arbitration()
	assert_array(host.get(&"_frame_events")).is_empty()


func test_resume_arbitration_clears_the_frame_buffer() -> void:
	# 🔴 Uses _install_controllable_state, unlike the suspend/FOCUS_OUT
	# siblings of this test: resume_arbitration() also calls
	# CursorState.reseed_reclaim_on_focus_regained(), which reads the mouse
	# position through the injected provider. The host built by _fresh_host()
	# is deliberately never added to a live SceneTree (see this file's class
	# doc comment), so the DEFAULT internally-built state's real
	# Viewport-bound provider would call get_viewport() on a detached node —
	# null — and crash. This is not a workaround that hides anything
	# untested: buffer-clearing is a plain Array operation with no
	# engine-applied half to separately verify (unlike Input.mouse_mode,
	# which coding-standards.md documents as a headless no-op — there is no
	# such split here).
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	_install_controllable_state(host, reclaim)
	_inject_residual_event(host)
	host.resume_arbitration()
	assert_array(host.get(&"_frame_events")).is_empty()


func test_focus_out_notification_clears_the_frame_buffer() -> void:
	# FOCUS_OUT does not reseed (only resume_arbitration() / FOCUS_IN do), so
	# this one does not need _install_controllable_state — the default
	# internally-built state is never touched.
	var host: Node = _fresh_host()
	_inject_residual_event(host)
	host._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_array(host.get(&"_frame_events")).is_empty()


func test_focus_in_notification_clears_the_frame_buffer() -> void:
	# 🔴 Same reason as test_resume_arbitration_clears_the_frame_buffer above:
	# the FOCUS_IN branch also reseeds via CursorState.reseed_reclaim_on_focus_regained(),
	# which needs a working mouse-position provider — the detached host's
	# default real one calls get_viewport() on a node with no viewport.
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	_install_controllable_state(host, reclaim)
	_inject_residual_event(host)
	host._notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_array(host.get(&"_frame_events")).is_empty()


func test_process_does_not_arbitrate_with_a_nonempty_buffer_while_suspended() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	_install_controllable_state(host, reclaim)
	host.set(&"_arbitration_suspended", true)
	# Bypass the (also-gated) _input() to force a genuinely non-empty buffer.
	var buffer: Array = host.get(&"_frame_events")
	buffer.append(InputEventKey.new())

	host._process(0.0)

	assert_int(reclaim.evaluate_calls).append_failure_message(
		"_process() called arbitrate_device_authority() (and therefore "
		+ "MouseReclaimPolicy.evaluate()) while suspended, despite a "
		+ "non-empty buffer."
	).is_equal(0)


func test_flush_buffered_navigation_does_not_apply_with_a_nonempty_buffer_while_suspended() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]
	var surface: _FakeNavigableSurface = fixture["surface"]
	surface.next_response = 123
	host.set(&"_arbitration_suspended", true)
	var nav_event: InputEventKey = _real_event(&"ui_right")
	var buffer: Array = host.get(&"_frame_events")
	buffer.append(nav_event)

	host.flush_buffered_navigation()

	assert_bool(state.is_current_target_valid()).append_failure_message(
		"flush_buffered_navigation() applied a buffered navigation write "
		+ "while suspended."
	).is_false()
	# And the buffer survives (only the suspended entry points clear it; a
	# gated early-return must not silently drop what suspend/resume own).
	assert_array(host.get(&"_frame_events")).is_equal([nav_event])


# ═══════════════════════════════════════════════════════════════════════════
# Orthogonality (ADR-0005 機制九's own explicit scope boundary): the ACTIVE
# caller-driven write interface must never be gated by _arbitration_suspended
# — only the PASSIVE arbitration path is.
# ═══════════════════════════════════════════════════════════════════════════

func test_set_target_and_mark_pending_reresolve_are_not_gated_by_arbitration_suspended() -> void:
	var host: Node = _fresh_host()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var fixture: Dictionary = _install_controllable_state(host, reclaim)
	var state: CursorState = fixture["state"]

	host.suspend_arbitration()
	assert_bool(host.get(&"_arbitration_suspended")).is_true()

	# set_target() (機制十一 乙/一般路徑) must apply normally while suspended —
	# this is the "存檔讀取的甲/丙分支可能發生在暫停選單仍顯示的轉場期間" case
	# ADR-0005 明文要求繼續運作.
	var applied: CursorState.SetTargetResult = state.set_target(_target(4))
	assert_int(applied).append_failure_message(
		"set_target() was rejected while _arbitration_suspended was true — "
		+ "the ADR requires this active write path to be UNAFFECTED by the "
		+ "passive-arbitration gate."
	).is_equal(CursorState.SetTargetResult.APPLIED)

	var marked: CursorState.MarkResult = state.mark_pending_reresolve(_target(4))
	assert_int(marked).append_failure_message(
		"mark_pending_reresolve() was rejected while _arbitration_suspended "
		+ "was true — same orthogonality requirement as set_target() above."
	).is_equal(CursorState.MarkResult.APPLIED)
