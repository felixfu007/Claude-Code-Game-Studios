## Integration tests for Story 005 — frame-buffered input arbitration and
## the six-actor process_priority ladder (ADR-0005 機制五/機制六), built on
## [CursorState] (Story 002/007) + [CursorSurfaceRegistry] (Story 003) +
## [CursorTypes] (Story 004).
##
## Covers AC-10 / AC-10b / AC-13 / AC-14 / AC-17 / AC-20 / AC-20b / AC-32 /
## AC-52 from
## [code]production/epics/cursor-highlight-state/story-005-frame-buffer-ordering.md[/code],
## plus the manager-mandated explicit gap registration (nothing in this
## project registers any [CursorSurface] yet) and the real-[Board] adjacency
## proof.
##
## [b]This is an INTEGRATION suite[/b]: every test here assembles
## [CursorState] + [CursorSurfaceRegistry] + real [InputEvent]s pulled from
## the live [InputMap] and drives [method CursorState.arbitrate_device_authority] /
## [method CursorState.apply_buffered_navigation] the same way
## [code]cursor_state_host.gd[/code] / [code]cursor_navigation_applier.gd[/code]
## do at their respective [member Node.process_priority] tiers — not calling
## [Node._process] on real scene-tree nodes (that half is covered by
## [code]tests/unit/cursor/state_host_test.gd[/code]'s structural/timing
## section), but exercising the SAME two entry points in the SAME order those
## nodes call them in, with real device-classified events.
##
## [b]Determinism / Isolation[/b]: same conventions as
## [code]write_read_interface_test.gd[/code] / [code]screen_handoff_test.gd[/code]
## — [CursorState] is a pure [RefCounted] DI core, every collaborator is a
## hand-built test double or a real object ([CursorSurfaceRegistry],
## [Board]), no random seed/timer/[code]await[/code]/file/network I/O, and the
## [code]CursorStateHost[/code] Autoload is never touched by any test in this
## file — every test builds its own [CursorState] instance(s).
##
## 🔴 [b]Real [InputEvent]s, not hand-guessed ones[/b]: every NAVIGATION/CONFIRM
## event this file builds is pulled via [method InputMap.action_get_events]
## and [method InputEvent.duplicate]d — the SAME convention
## [code]tests/unit/cursor/device_classification_test.gd[/code] already
## established, and for the same reason: hand-constructing an
## [InputEventKey] with a guessed [member InputEventKey.keycode] risks
## silently NOT matching [method InputMap.event_is_action] if the guess is
## wrong, which would make a test pass or fail for the wrong reason.
extends GdUnitTestSuite


## Surface tag most tests in this file register and target.
const _SURFACE: CursorTypes.SurfaceType = CursorTypes.SurfaceType.BOARD_TILE

## Constant coordinate the injected mouse-position [Callable] returns.
## Non-zero for the same reason every other cursor test file's probe value
## is: the production fallback ([method CursorState._safe_mouse_position]
## when the provider has gone invalid) IS [constant Vector2.ZERO], so a zero
## probe could not distinguish a real provider read from that fallback.
const _MOUSE_POSITION: Vector2 = Vector2(555.0, 111.0)


## Recording [MouseReclaimPolicy] test double — same shape as
## [code]write_read_interface_test.gd[/code] / [code]screen_handoff_test.gd[/code]'s
## [code]_RecordingReclaimPolicy[/code], duplicated rather than shared across
## files (Isolation, same reasoning those files already document).
## [br]
## [member claims_mouse] is this file's own addition: a settable stand-in for
## [method MouseReclaimPolicy.evaluate]'s return value, so tests can simulate
## "the mouse has a same-frame valid reclaim candidate" without needing a
## real threshold/displacement calculation (機制八's concrete math is Story
## 014's frozen, user-paused sub-mechanism — out of this story's scope
## entirely, see this story's report).
class _RecordingReclaimPolicy extends MouseReclaimPolicy:
	var reset_calls: Array[Dictionary] = []
	var progress: float = 0.0
	var claims_mouse: bool = false
	var evaluate_calls: int = 0

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
		return Vector2.ZERO

	## Convenience for assertions: just the trigger sequence, in call order.
	func triggers() -> Array[CursorTypes.ResetTrigger]:
		var out: Array[CursorTypes.ResetTrigger] = []
		for call_record: Dictionary in reset_calls:
			out.append(call_record["trigger"])
		return out


## Test double for Story 005's Option E navigation contract (2026-09-07
## manager ruling) — see [constant CursorState.NAVIGATE_METHOD_NAME]'s doc
## comment in [code]cursor_state.gd[/code] for the full contract. Scripted,
## single-response stub: [member next_response] is what the NEXT
## [method cursor_navigate] call returns ([code]null[/code] = "no legal
## target that direction", the grid-edge case).
class _FakeNavigableSurface extends Node:
	var next_response: Variant = null
	var call_log: Array[Dictionary] = []

	func cursor_navigate(from_id: int, direction: Vector2i) -> Variant:
		call_log.append({"from_id": from_id, "direction": direction})
		return next_response


## 🔴 [b]Test-ONLY fixture — NOT production wiring.[/b] Proves Option E's
## contract is correct against REAL board data, per the manager's explicit
## instruction ("用真正的 Board 寫一組測試...呼叫真正的 Board 類別才算實機驗證;
## 自己在測試裡重刻一份相鄰格運算不算"). This class calls the REAL
## [method Board.is_in_bounds] and the REAL
## [method CursorTypes.encode_tile]/[method CursorTypes.decode_tile] — the
## only code THIS class contributes is [code]from_cell + direction[/code],
## plain [Vector2i] addition, not a re-implementation of any board rule.
## [br]
## [b]Why this stays a test fixture and is not shipped as a real production
## adapter[/b] (this story's own engineering judgment call, flagged in the
## report): as of this story, NOTHING in [code]src/[/code] calls
## [method CursorSurfaceRegistry.register] for
## [constant CursorTypes.SurfaceType.BOARD_TILE] or any other tag — verified
## empty via [code]grep -rn "\.register(" src/[/code] excluding the
## registry's own method definitions. Shipping a "real" adapter today would
## imply a design decision (which node owns this responsibility in the real
## battle scene, how it reaches the live [Board] instance held by
## [code]BattleState[/code]) that belongs to whichever future story actually
## performs that wiring — [BoardView] itself is explicitly barred from
## holding [Board] by [code].claude/rules/ui-code.md[/code] and its own class
## doc comment ("owns zero game state"), so the real answer is not simply
## "attach this to BoardView".
## [br]
## Board itself is [RefCounted], not [Node] — [method CursorSurfaceRegistry.get_surface]
## returns [Node], so this wrapper exists to hold one.
class _BoardBackedSurface extends Node:
	var board: Board
	var call_log: Array[Dictionary] = []

	func cursor_navigate(from_id: int, direction: Vector2i) -> Variant:
		call_log.append({"from_id": from_id, "direction": direction})
		var from_cell: Vector2i = CursorTypes.decode_tile(from_id, Board.BOARD_WIDTH)
		var to_cell: Vector2i = from_cell + direction
		if not board.is_in_bounds(to_cell):
			return null
		return CursorTypes.encode_tile(to_cell, Board.BOARD_WIDTH)


## Named-method [Callable] target for the injected mouse-position provider —
## a named binding, not a lambda literal (機制十 專家發現 G / S-1).
func _test_mouse_position() -> Vector2:
	return _MOUSE_POSITION


## Pulls the REAL, live-[InputMap]-bound event for [param action] and
## duplicates it — see this file's class doc comment for why this is not
## hand-constructed. Prefers the [InputEventKey] form (this project's tests
## consistently use the keyboard form as the KEYBOARD_GAMEPAD representative
## when either would classify identically — see
## [code]device_classification_test.gd[/code]'s own precedent).
func _real_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).duplicate()
	return null


## A target on [constant _SURFACE].
func _target(id: int) -> CursorTarget:
	return CursorTarget.make(_SURFACE, id)


## Builds one fresh, independent (state, registry, reclaim-double) triple.
func _build_fixture() -> Dictionary:
	var registry: CursorSurfaceRegistry = CursorSurfaceRegistry.new()
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	var state: CursorState = CursorState.new(
		reclaim, registry, Callable(self, "_test_mouse_position")
	)
	return {"state": state, "registry": registry, "reclaim": reclaim}


## 13 dots = [constant Board.BOARD_WIDTH]. Matches
## [code]tests/unit/gameplay/board/board_test.gd[/code]'s own
## [code]_build_open_rows()[/code] precedent (hand-written literal, not
## [method String.repeat]) rather than introducing a new construction idiom
## for the same shape.
func _open_board_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		rows.append(".............")
	return rows


# ═══════════════════════════════════════════════════════════════════════════
# 🔴 Explicit gap registration (manager requirement, 2026-09-07): nothing in
# this project registers ANY CursorSurface yet. This is the test-suite half
# of that registration — the other half is this story's final report.
# ═══════════════════════════════════════════════════════════════════════════

## Recursively collects every line in every [code].gd[/code] file under
## [param dir_path] containing the literal substring [code].register([/code].
## Pure [DirAccess]/[FileAccess] — deliberately NOT a shelled-out
## [code]grep[/code] call: [code].claude/docs/coding-standards.md[/code]
## documents this exact class of hazard for this project (`godot` itself not
## being on PATH in some shells), and an external-tool dependency inside an
## automated test is the same fragility one level down. [code]func register([/code]
## / [code]func register_native_pointer_exception([/code] (the registry's own
## method DEFINITIONS) do not match — there is no dot immediately before
## "register" in a function declaration — so they are excluded without any
## special-casing.
func _files_matching_dot_register(dir_path: String) -> Array[String]:
	var matches: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return matches
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full_path: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				matches.append_array(_files_matching_dot_register(full_path))
			elif entry.ends_with(".gd"):
				var lines: PackedStringArray = FileAccess.get_file_as_string(full_path).split("\n")
				for i: int in range(lines.size()):
					if lines[i].contains(".register("):
						matches.append("%s:%d: %s" % [full_path, i + 1, lines[i].strip_edges()])
		entry = dir.get_next()
	dir.list_dir_end()
	return matches


## Documents, as an EXECUTABLE test, that this project's actual game code
## does not register anything under ANY [enum CursorTypes.SurfaceType] tag
## today — so "a player sees the highlight move when pressing arrow keys"
## cannot happen yet, regardless of how correct this story's Option E
## mechanism is (see every other test in this file, which DOES register test
## doubles/real-[Board] fixtures, deliberately, to prove the mechanism
## itself works). This test is about [code]res://src/[/code] only.
func test_gap_no_surface_is_registered_anywhere_in_src_yet() -> void:
	var matches: Array[String] = _files_matching_dot_register("res://src")

	assert_array(matches).append_failure_message(
		"EXPECTED EMPTY. This is the explicit gap this story registered: "
		+ "nothing in src/ calls CursorSurfaceRegistry.register() for ANY "
		+ "CursorTypes.SurfaceType tag, so a player pressing arrow keys "
		+ "cannot see the highlight move in any real running scene yet — "
		+ "this story's Option E mechanism is correct and tested (see the "
		+ "rest of this file), but nothing wires a real surface into it. "
		+ "If this assertion now FAILS, something changed that — update "
		+ "this story's report, do not just widen this assertion. Matches: %s"
		% str(matches)
	).is_empty()


# ═══════════════════════════════════════════════════════════════════════════
# AC-17: gamepad holds authority + continuous directional input, mouse fully
# stationary → authority stays gamepad across multiple frames.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac17_gamepad_holds_authority_across_frames_while_mouse_sits_still() -> void:
	# Arrange — GIVEN: gamepad holds authority, mouse produces no candidate at
	# all (機制八's evaluate() returns false every frame — "完全靜止" is
	# represented here as "never crosses the reclaim threshold", which is
	# what a genuinely stationary mouse means in this system's own model).
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var reclaim: _RecordingReclaimPolicy = fixture["reclaim"]
	reclaim.claims_mouse = false
	var nav_event: InputEventKey = _real_event(&"ui_right")
	assert_object(nav_event).append_failure_message(
		"PRECONDITION: no real InputEventKey bound to ui_right in this "
		+ "engine's InputMap."
	).is_not_null()

	# Act / Assert — WHEN: 3 consecutive frames, each with a fresh directional
	# event (機制四之二's echo filter already excludes literal held-key
	# repeats; "continuous input" here is 3 distinct frames each carrying a
	# real navigation press, matching how discrete d-pad presses actually
	# arrive). THEN: device authority stays gamepad every frame.
	for frame_index: int in range(3):
		state.arbitrate_device_authority([nav_event])
		assert_int(state.get_device_authority()).append_failure_message(
			"frame %d: device authority did not stay KEYBOARD_GAMEPAD while "
			+ "mouse never produced a claim." % frame_index
		).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)

	# And: the stationary mouse never even got a chance to be vetoed — no
	# VETOED_SAME_FRAME should appear, because it never had a candidate to
	# veto (see arbitrate_device_authority()'s own comment: (d) requires BOTH
	# candidates to exist this frame).
	assert_bool(reclaim.triggers().has(CursorTypes.ResetTrigger.VETOED_SAME_FRAME)).append_failure_message(
		"a stationary mouse produced a VETOED_SAME_FRAME trigger, which "
		+ "means something treated it as having had a same-frame candidate."
	).is_false()


# ═══════════════════════════════════════════════════════════════════════════
# AC-20: same-frame dual-device arbitration — KEYBOARD_GAMEPAD always wins,
# independent of event ARRIVAL ORDER within the buffer.
# ═══════════════════════════════════════════════════════════════════════════

## 🔴 [b]Code review half (AC-20's PRIMARY verification method per the AC's
## own text — this paragraph is not optional supporting material)[/b]:
##
## Read [method CursorState.arbitrate_device_authority]
## ([code]src/ui/cursor/cursor_state.gd[/code], the "SEAM FILLED 2026-09-07"
## block). The eligibility check is a single [code]for event in events:[/code]
## loop with a [code]break[/code] on the FIRST match — it does not read
## [member InputEvent.device], does not compare timestamps, does not branch
## on [code]events[/code]'s array index, and calls nothing that depends on
## engine-internal event-processing order. The mouse candidate
## ([code]mouse_claimed[/code]) is computed completely independently, via
## [method MouseReclaimPolicy.evaluate] against the CURRENT mouse position —
## NOT derived from anything in [code]events[/code] at all (機制八's F2
## revision moved [method MouseReclaimPolicy.evaluate] off a per-event delta
## onto an absolute-position/internal-seed model specifically to remove any
## event-order dependency; see that revision's own rationale in ADR-0005).
## The priority resolution itself is [code]if keyboard_gamepad_navigation_claimed:
## ... elif mouse_claimed: ...[/code] — KEYBOARD_GAMEPAD is checked FIRST and
## unconditionally wins whenever both booleans are true, and neither
## boolean's VALUE carries any notion of "which became true first". There is
## no code path in this function whose outcome depends on where in
## [code]events[/code] the winning event sits, or how many non-eligible
## events surround it.
##
## [b]Runtime half (auxiliary, per AC-20's own text)[/b]: 20 DISTINCT
## arrangements of the same logical inputs, never repeating an arrangement —
## per this AC's own explicit rejection of "same sequence 20 times" as
## having no additional information value. [member _RecordingReclaimPolicy.claims_mouse]
## is [code]true[/code] for every trial, so a competing same-frame mouse
## candidate is ALSO present every time (a non-competing mouse would
## trivially pass regardless of any ordering logic, which would prove
## nothing).
func test_ac20_keyboard_gamepad_beats_mouse_same_frame_across_20_distinct_orderings() -> void:
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var reclaim: _RecordingReclaimPolicy = fixture["reclaim"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	reclaim.claims_mouse = true

	var nav_event: InputEventKey = _real_event(&"ui_right")
	var confirm_event: InputEventKey = _real_event(&"ui_accept")
	var page_event: InputEventKey = _real_event(&"ui_page_up")
	assert_object(nav_event).is_not_null()
	assert_object(confirm_event).is_not_null()
	assert_object(page_event).is_not_null()

	var noise_pool: Array[InputEvent] = [
		InputEventMouseMotion.new(), confirm_event, page_event,
		InputEventMouseMotion.new(), InputEventMouseMotion.new(),
	]

	var surface: _FakeNavigableSurface = _FakeNavigableSurface.new()
	auto_free(surface)
	registry.register(_SURFACE, surface)

	# 🔴 Genuinely 20 DISTINCT arrangements, not a repeated pattern:
	# `offset` cycles with period 5 (noise_pool.size()), `insert_at` cycles
	# with period 6 (events.size()+1 after building the rotated noise array).
	# lcm(5, 6) = 30 > 20, so no (offset, insert_at) pair — and therefore no
	# resulting array — repeats across trials 0..19.
	for trial: int in range(20):
		var events: Array[InputEvent] = []
		var offset: int = trial % noise_pool.size()
		for i: int in range(noise_pool.size()):
			events.append(noise_pool[(i + offset) % noise_pool.size()])
		var insert_at: int = trial % (events.size() + 1)
		events.insert(insert_at, nav_event)

		surface.next_response = 99  # arbitrary legal-looking target id
		state.arbitrate_device_authority(events)
		state.apply_buffered_navigation(events)

		assert_int(state.get_device_authority()).append_failure_message(
			("trial %d (nav event at index %d of %d): mouse won instead of "
			+ "keyboard/gamepad — determinism depends on ARRAY ORDER, which "
			+ "AC-20 forbids.") % [trial, insert_at, events.size()]
		).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
		assert_int(state.get_current_target().id).append_failure_message(
			"trial %d: target did not update to the navigated value even "
			+ "though keyboard/gamepad won arbitration." % trial
		).is_equal(99)


# ═══════════════════════════════════════════════════════════════════════════
# AC-20b: same-device two ui_* actions same frame (nav + confirm) — the
# confirm-class read sees the value AFTER the navigation write.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac20b_confirm_class_read_sees_the_post_navigation_value_same_frame() -> void:
	# Arrange — GIVEN: authority already KEYBOARD_GAMEPAD (settled in an
	# earlier, separate call — see this file's AC-13 test's doc comment for
	# why "authority already settled" sidesteps the AC-10 same-frame-transfer
	# question entirely (that question was RESOLVED 2026-09-07 — see the
	# AC-10 tests further down this file — but this test still deliberately
	# settles authority in an earlier, separate call, since AC-20b is not
	# about the transfer instant itself).
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	var surface: _FakeNavigableSurface = _FakeNavigableSurface.new()
	auto_free(surface)
	registry.register(_SURFACE, surface)

	var nav_event: InputEventKey = _real_event(&"ui_right")
	var confirm_event: InputEventKey = _real_event(&"ui_accept")
	state.arbitrate_device_authority([nav_event])
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)

	# Act — WHEN: the SAME buffered frame carries BOTH a navigation action
	# and a confirm action. Deliberately ordered CONFIRM-before-NAV in the
	# array — an adversarial order, proving the result does not depend on
	# which one this test happened to list first.
	surface.next_response = 42
	state.apply_buffered_navigation([confirm_event, nav_event])

	# Assert — THEN: reading the target now (機制六③ has already returned;
	# 機制六⑥'s later read, whenever it happens, would see exactly this) is
	# the NAVIGATED value, not the value from before this call.
	assert_int(state.get_current_target().id).append_failure_message(
		"the confirm-class event in the buffer interfered with, or "
		+ "pre-empted, the navigation write — a downstream confirm reader "
		+ "would see a stale target."
	).is_equal(42)
	assert_bool(state.is_current_target_valid()).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# AC-52: caller's active retarget (機制六②, e.g. unit-death
# mark_pending_reresolve) beats a same-frame buffered CONFIRM read.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac52_caller_retarget_settles_before_buffered_confirm_read_observes_it() -> void:
	# Arrange — a valid target, so mark_pending_reresolve() has something
	# real to invalidate.
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	registry.register(_SURFACE, auto_free(Node.new()))
	var original: CursorTarget = _target(17)
	assert_int(state.set_target(original)).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_bool(state.is_current_target_valid()).is_true()

	var confirm_event: InputEventKey = _real_event(&"ui_accept")

	# Act — WHEN: 機制六② (caller's own re-target, e.g. unit death), THEN
	# 機制六③ processing the SAME frame's buffer, which carries only a
	# CONFIRM-class event (no navigation event — this AC's GIVEN is about a
	# confirm targeting the SAME cell the caller just invalidated, not a
	# navigation move).
	var mark_result: CursorState.MarkResult = state.mark_pending_reresolve(original)
	assert_int(mark_result).append_failure_message(
		"PRECONDITION: the caller's own retarget call did not apply."
	).is_equal(CursorState.MarkResult.APPLIED)
	state.apply_buffered_navigation([confirm_event])

	# Assert — THEN: 機制六③'s confirm-ignoring pass did not resurrect
	# validity, so the confirm read (is_current_target_valid(), whatever
	# downstream system performs it at 機制六⑥) correctly sees the
	# ALREADY-invalidated flag and would reject the confirm.
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"the buffered confirm-class event caused apply_buffered_navigation() "
		+ "to touch validity — it must only ever act on NAVIGATION-class "
		+ "events."
	).is_false()


# ═══════════════════════════════════════════════════════════════════════════
# AC-32 (moved from Story 007, 2026-09-03 registration) — the only
# permanently-sunk-if-missed AC in this story. The player's own navigation
# unsticks a pending-re-resolve target with NO caller system involved.
# ═══════════════════════════════════════════════════════════════════════════

## Replaces [code]tests/unit/cursor/write_read_interface_test.gd[/code]'s
## [code]test_ac32_blocked_...[/code] tripwire, per that test's own doc
## comment instruction ("delete it and write the real AC-32 test").
func test_ac32_players_own_navigation_unsticks_a_pending_reresolve_target() -> void:
	# Arrange — GIVEN: a target whose validity flag is invalid (pending
	# re-resolve), and no caller system about to intervene.
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	var surface: _FakeNavigableSurface = _FakeNavigableSurface.new()
	auto_free(surface)
	registry.register(_SURFACE, surface)

	var original: CursorTarget = _target(5)
	assert_int(state.set_target(original)).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(state.mark_pending_reresolve(_target(5))).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"PRECONDITION: target is not actually pending re-resolve."
	).is_false()

	var nav_event: InputEventKey = _real_event(&"ui_right")
	state.arbitrate_device_authority([nav_event])
	assert_int(state.get_device_authority()).append_failure_message(
		"PRECONDITION: authority did not become KEYBOARD_GAMEPAD."
	).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)

	# Act — WHEN: the player navigates. apply_buffered_navigation() is the
	# only entry that carries player navigation into this system, and no
	# caller system does anything here — no set_target(), no
	# mark_pending_reresolve() call after the GIVEN setup above.
	surface.next_response = 6
	state.apply_buffered_navigation([nav_event])

	# Assert — THEN: the coordinate becomes the newly navigated one, and
	# validity flips back to true — with NO caller system involved.
	assert_int(state.get_current_target().id).is_equal(6)
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"AC-32's core claim: the player's own navigation must unstick the "
		+ "pending-re-resolve state with no caller intervention."
	).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# AC-14: device A regains authority after losing it, on its next valid
# ui_* action — for keyboard/gamepad, "valid" = any NAVIGATION action, no
# accumulation threshold (unlike mouse, AC-28/AC-28b).
# ═══════════════════════════════════════════════════════════════════════════

func test_ac14_keyboard_gamepad_regains_authority_on_its_next_navigation_action() -> void:
	# Arrange — GIVEN: A (keyboard/gamepad) has lost authority to mouse.
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var reclaim: _RecordingReclaimPolicy = fixture["reclaim"]
	reclaim.claims_mouse = true
	state.arbitrate_device_authority([])
	assert_int(state.get_device_authority()).append_failure_message(
		"PRECONDITION: mouse did not claim authority."
	).is_equal(CursorTypes.Authority.MOUSE)

	reclaim.claims_mouse = false  # mouse stops claiming — no longer relevant
	var nav_event: InputEventKey = _real_event(&"ui_left")

	# Act — WHEN: A produces a single valid NAVIGATION action — no
	# accumulated threshold needed, unlike mouse's reclaim.
	state.arbitrate_device_authority([nav_event])

	# Assert — THEN: A regains authority immediately.
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)


# ═══════════════════════════════════════════════════════════════════════════
# AC-13: once authority has SETTLED on B (an earlier, separate call — this
# test does not exercise the transfer instant itself; see the AC-10 tests'
# own doc comments further down this file for the full history of that
# specific instant, RESOLVED 2026-09-07), B's next navigation action applies
# immediately, same call/frame as that input.
# ═══════════════════════════════════════════════════════════════════════════

func test_ac13_navigation_action_applies_immediately_once_authority_is_settled() -> void:
	# Arrange — GIVEN: authority already settled on KEYBOARD_GAMEPAD in an
	# EARLIER, separate call (deliberately not calling apply_buffered_navigation
	# in that earlier call at all, so this test says nothing about the
	# transfer-instant question).
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	var surface: _FakeNavigableSurface = _FakeNavigableSurface.new()
	auto_free(surface)
	registry.register(_SURFACE, surface)

	var earlier_nav_event: InputEventKey = _real_event(&"ui_up")
	state.arbitrate_device_authority([earlier_nav_event])
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)

	# Act — WHEN: B subsequently produces a NEW ui_* action with an explicit
	# new target.
	var new_nav_event: InputEventKey = _real_event(&"ui_right")
	surface.next_response = 88
	state.apply_buffered_navigation([new_nav_event])

	# Assert — THEN: the target field's value, within the SAME call as that
	# input, immediately equals the new coordinate.
	assert_int(state.get_current_target().id).append_failure_message(
		"target did not update to the newly navigated value within the "
		+ "same call as the navigation input."
	).is_equal(88)
	assert_bool(state.is_current_target_valid()).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# AC-10 (keyboard/gamepad B) — ✅ RESOLVED 2026-09-07 (manager ruling): the
# transfer-triggering frame's legal move applies same-frame, not suppressed.
# See the doc comment on the first test below for the ruling text and the
# full history of why this was ever in question.
# ═══════════════════════════════════════════════════════════════════════════

## ✅ [b]RULING CONFIRMED 2026-09-07 (project manager)[/b]: same-frame write
## is the correct, confirmed reading of AC-10 for the keyboard/gamepad case.
## This test (and the one below it) encode that confirmed reading — this is
## no longer a recommendation awaiting a decision.
## [br]
## [b]The tension that made this provisional[/b], preserved verbatim below
## because it explains why this was ever in question (evidence, not a live
## caveat): AC-10's literal text says the target is UNCHANGED at the end of
## the transfer-triggering frame. Because keyboard/gamepad's ONLY eligibility
## path to claim authority is itself a NAVIGATION-class event (機制六①), and
## that SAME event is still in the buffer when 機制六③ runs (the buffer is
## not cleared between them, same frame), a LITERAL reading of AC-10 would
## require SUPPRESSING ③'s write for that specific frame — which this
## implementation does NOT do. These two tests instead encode the reading
## consistent with AC-10b's own explicit precedent for the mouse case
## ("不殘留 A 的舊值超過該觸發影格本身" — same-frame application is correct and
## expected there).
## [br]
## [b]The manager's actual ruling, quoted verbatim[/b] (2026-09-07, in answer
## to "玩家從滑鼠改用鍵盤/手把,第一次按方向鍵 —— 高亮要不要立刻動?"): "要立刻動
## (建議,實作者也建議這個)—— 按下去就看得到反應。代價:這跟驗收標準的字面寫法
## 有張力,所以要回頭把那條標準的文字改清楚(不是改決定,是讓文字跟行為一致)。
## 目前的程式已經是這樣寫的,且測試已標註『待裁決』。" — i.e. same-frame write is
## the confirmed BEHAVIOR; only the AC-10 acceptance-criterion TEXT still
## needs to change to match it.
## [br]
## 🔴 [b]Outstanding follow-up this ruling does NOT close[/b]:
## [code]design/gdd/cursor-highlight-state.md[/code]'s AC-10 wording has NOT
## been updated yet — it still reads literally as "unchanged", which is now
## the OPPOSITE of the confirmed, implemented, and tested behavior. Anyone
## who reads that GDD clause on its own, without also finding this ruling,
## will read something the code directly contradicts. Syncing that text is a
## separate, still-open task; this comment exists so the gap is not lost.
func test_ac10_unchanged_when_the_transfer_frames_move_is_illegal() -> void:
	# Arrange — GIVEN: device authority transfers on this call (UNINITIALIZED
	# -> KEYBOARD_GAMEPAD is itself a transfer — 機制六① does not special-case
	# "first ever" transfers). The surface reports NO legal move this
	# direction (機制六③'s null-response path — the uncontested branch: this
	# was satisfied under EITHER candidate reading of AC-10 while the
	# question was open, and remains satisfied now that same-frame write is
	# the confirmed reading, since nothing was written to begin with).
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	var surface: _FakeNavigableSurface = _FakeNavigableSurface.new()
	auto_free(surface)
	registry.register(_SURFACE, surface)
	surface.next_response = null

	var nav_event: InputEventKey = _real_event(&"ui_right")

	# Act — WHEN: the SAME call-pair runs both 機制六① (transfer) and 機制六③
	# (buffered navigation), exactly as CursorStateHost / CursorNavigationApplier
	# do at process_priority -100 / -25 within one real frame.
	state.arbitrate_device_authority([nav_event])
	assert_int(state.get_device_authority()).append_failure_message(
		"PRECONDITION: authority did not transfer."
	).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	state.apply_buffered_navigation([nav_event])

	# Assert — THEN: nothing overwrote the target (it was never set to begin
	# with), so this branch is satisfied under EITHER reading of AC-10.
	assert_bool(state.is_current_target_valid()).is_false()


func test_ac10_same_frame_write_when_the_transfer_frames_move_is_legal() -> void:
	# The genuinely contested case, now RESOLVED: same setup, but the move IS
	# legal. Under this implementation's confirmed reading (2026-09-07
	# manager ruling — see the section header above and the previous test's
	# doc comment for the ruling text and full history), the target updates
	# in the SAME frame as the transfer.
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	var surface: _FakeNavigableSurface = _FakeNavigableSurface.new()
	auto_free(surface)
	registry.register(_SURFACE, surface)
	surface.next_response = 71

	var nav_event: InputEventKey = _real_event(&"ui_right")
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])

	assert_int(state.get_current_target().id).append_failure_message(
		"AC-10 same-frame write (2026-09-07 manager ruling, CONFIRMED): the "
		+ "transfer-triggering frame's legal move must apply in the SAME "
		+ "frame as the transfer, not be suppressed. If this fails, the "
		+ "implementation regressed against the confirmed reading — see "
		+ "this section's doc comments for the ruling text."
	).is_equal(71)


# ═══════════════════════════════════════════════════════════════════════════
# from_ui_action deadline — ✅ RESOLVED 2026-09-07 (Story 005), parameter
# DELETED.
# ═══════════════════════════════════════════════════════════════════════════

## The test that used to live here proved the premise for deletion (called
## [method CursorState.set_target] with [code]true[/code] and [code]false[/code]
## on two independent states, both preceded by a real
## [method CursorState.arbitrate_device_authority] call, and asserted
## identical resulting device authority — PASSED). Per the manager's
## 2026-09-07 ruling ("先用測試證明它真的沒用，再刪掉"), the parameter was then
## deleted from [method CursorState.set_target]'s signature — see that
## method's class doc comment in [code]cursor_state.gd[/code] ("DELETED
## 2026-09-07") for the full history. This test is deleted with it: it tested
## a distinction ([code]from_ui_action=true[/code] vs [code]false[/code])
## that no longer exists to test. AC-39 ("set_target() must not touch device
## authority") remains covered —
## [code]tests/unit/cursor/write_read_interface_test.gd[/code]'s own AC-39
## test, unaffected by this deletion since it always called with what is now
## the only shape.


# ═══════════════════════════════════════════════════════════════════════════
# Real Board proof (manager requirement, 2026-09-07): "往右一格" / "撞到邊界
# 會停" computed against a REAL Board instance, not a re-implemented
# geometry rule. See _BoardBackedSurface's own class doc comment for exactly
# which calls are real (Board.is_in_bounds, CursorTypes.encode_tile/decode_tile)
# vs. this file's own trivial Vector2i addition.
# ═══════════════════════════════════════════════════════════════════════════

func test_real_board_moving_right_lands_on_the_correct_adjacent_tile() -> void:
	# Arrange — a real Board, ASCII-built (Board.from_ascii — the same
	# production entry point board_test.gd's own tests use), an open field
	# so the move is unambiguously legal.
	var board: Board = Board.from_ascii(_open_board_rows())
	var board_surface: _BoardBackedSurface = _BoardBackedSurface.new()
	board_surface.board = board
	auto_free(board_surface)

	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	registry.register(_SURFACE, board_surface)

	var start_cell: Vector2i = Vector2i(4, 1)
	var start_id: int = CursorTypes.encode_tile(start_cell, Board.BOARD_WIDTH)
	state.set_target(CursorTarget.make(_SURFACE, start_id))

	var nav_event: InputEventKey = _real_event(&"ui_right")
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])

	var expected_cell: Vector2i = start_cell + Vector2i(1, 0)
	var expected_id: int = CursorTypes.encode_tile(expected_cell, Board.BOARD_WIDTH)
	assert_int(state.get_current_target().id).append_failure_message(
		("moving right from %s did not land on %s — computed via the REAL "
		+ "Board.is_in_bounds() and CursorTypes.encode_tile()/decode_tile().")
		% [start_cell, expected_cell]
	).is_equal(expected_id)


func test_real_board_moving_off_the_edge_leaves_the_target_unchanged() -> void:
	# Arrange — start at the RIGHTMOST column; moving right is illegal.
	var board: Board = Board.from_ascii(_open_board_rows())
	var board_surface: _BoardBackedSurface = _BoardBackedSurface.new()
	board_surface.board = board
	auto_free(board_surface)

	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	registry.register(_SURFACE, board_surface)

	var edge_cell: Vector2i = Vector2i(Board.BOARD_WIDTH - 1, 0)
	var edge_id: int = CursorTypes.encode_tile(edge_cell, Board.BOARD_WIDTH)
	state.set_target(CursorTarget.make(_SURFACE, edge_id))

	var nav_event: InputEventKey = _real_event(&"ui_right")
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])

	# Assert — THEN: real Board.is_in_bounds() rejects the off-grid cell,
	# _BoardBackedSurface.cursor_navigate() returns null, and this system
	# leaves the target exactly where it was — not clamped, not wrapped, not
	# defaulted.
	assert_int(state.get_current_target().id).append_failure_message(
		"moving right off the real board's edge changed the target — it "
		+ "must stay exactly where it was (Board.is_in_bounds() correctly "
		+ "rejected the destination)."
	).is_equal(edge_id)
	assert_int(board_surface.call_log.size()).append_failure_message(
		"cursor_navigate() was never actually called — this test would "
		+ "pass vacuously without exercising Board.is_in_bounds() at all."
	).is_greater(0)


# ═══════════════════════════════════════════════════════════════════════════
# Option E's own failure direction: no registered surface, or a registered
# one that doesn't implement the contract — must be LOUD, never silent
# (manager requirement, 2026-09-07).
# ═══════════════════════════════════════════════════════════════════════════

func test_navigation_gap_no_registered_surface_is_loud_not_silent() -> void:
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	# Deliberately do NOT register anything under _SURFACE.

	var nav_event: InputEventKey = _real_event(&"ui_right")
	state.arbitrate_device_authority([nav_event])
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(state.diagnostic_surface_navigation_unsupported_count).is_equal(0)

	state.apply_buffered_navigation([nav_event])
	assert_int(state.diagnostic_surface_navigation_unsupported_count).append_failure_message(
		"apply_buffered_navigation() silently did nothing when no surface "
		+ "was registered — this must be observable via the diagnostic "
		+ "counter."
	).is_equal(1)

	# Second frame — keeps counting, not just a one-shot flag.
	state.apply_buffered_navigation([nav_event])
	assert_int(state.diagnostic_surface_navigation_unsupported_count).is_equal(2)


func test_navigation_gap_registered_surface_without_the_contract_method_is_loud() -> void:
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]
	# A real, legitimately registered surface — just one that does not
	# implement cursor_navigate().
	registry.register(_SURFACE, auto_free(Node.new()))

	var nav_event: InputEventKey = _real_event(&"ui_right")
	state.arbitrate_device_authority([nav_event])
	state.apply_buffered_navigation([nav_event])

	assert_int(state.diagnostic_surface_navigation_unsupported_count).is_equal(1)
	assert_bool(state.is_current_target_valid()).is_false()  # never touched
