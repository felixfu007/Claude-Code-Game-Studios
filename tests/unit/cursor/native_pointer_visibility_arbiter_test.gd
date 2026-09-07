## Unit tests for [code]src/ui/cursor/native_pointer_visibility_arbiter.gd[/code]
## (Story 011, ADR-0005 機制十三之二). Covers AC-11, AC-19, AC-38, AC-60 from
## [code]production/epics/cursor-highlight-state/story-011-native-cursor-suppression.md[/code].
##
## [b]Scope narrowing — read before extending or "fixing" these tests[/b]:
## - [b]AC-11[/b]: verifiable at this layer via
##   [member NativePointerVisibilityArbiter.diagnostic_last_desired_mouse_mode],
##   NOT via reading [member Input.mouse_mode] directly. [NativePointerVisibilityArbiter]
##   never reads raw [InputEvent]s at all — only [method CursorState.get_device_authority]
##   and the injected hover provider — so "suppression persists regardless of
##   how much raw signal noise A produces" holds by construction, the
##   strongest form of this guarantee.
##   🔴 [b]2026-09-07 coordinator finding — why this file never asserts on the
##   real [member Input.mouse_mode][/b]: measured directly on this engine,
##   headless, a throwaway probe found that assigning EITHER
##   [constant Input.MOUSE_MODE_HIDDEN] or [constant Input.MOUSE_MODE_VISIBLE]
##   and reading [member Input.mouse_mode] back both report [code]0[/code]
##   ([code]MOUSE_MODE_VISIBLE[/code]'s own value) — the engine does not apply
##   the write without a real window/display server. The failure direction is
##   ASYMMETRIC and the dangerous half is silent: asserting "should read
##   HIDDEN" always fails (loud); asserting "should read VISIBLE" always
##   PASSES regardless of what this class decided (a false green). Every test
##   below therefore asserts against
##   [member NativePointerVisibilityArbiter.diagnostic_last_desired_mouse_mode]
##   (this class's own decision, QA-only per its doc comment) — proving the
##   DECISION logic. The real [member Input.mouse_mode] write is verified
##   separately, in this story's windowed manual-verification evidence
##   (`production/qa/evidence/`), where the engine can actually apply it. Both
##   are required; this file's coverage does not substitute for the windowed
##   check, and the windowed check does not substitute for this file.
## - [b]AC-19[/b] (PARTIAL COVERAGE — 2026-09-07): AC-19's own mechanism (does
##   raw mouse motion over an illegal area ever attempt a re-target or an
##   authority transfer at all?) is governed by Story 005's arbitration SEAM
##   in [code]cursor_state.gd[/code] ([method CursorState.arbitrate_device_authority]),
##   which is currently EMPTY — see that method's own "STORY 005 SEAM" comment
##   block. This story builds no caller that hit-tests the mouse position
##   against board geometry, and does not fake one. What IS verified here: the
##   ONE component this story DOES build that reacts to hover
##   ([NativePointerVisibilityArbiter]) never writes to [CursorState] under any
##   circumstance, across arbitrarily many [method Node._process] calls — the
##   presentation layer cannot itself be the source of a spurious re-target,
##   regardless of raw event volume. This is a real, useful, independently
##   testable half of AC-19 (matching the precedent
##   [code]tests/unit/cursor/mouse_reclaim_test.gd[/code] already set for
##   AC-35b/AC-58), not the full AC.
## - [b]AC-38[/b] (PARTIAL COVERAGE — 2026-09-07): AC-38's full behavior (a
##   mouse click is rejected, produces no confirm effect, is not counted
##   toward the reclaim accumulation, AND the caller emits active feedback) is
##   split across a click-consuming caller system that does not exist yet in
##   this repository (board input handling is blocked on OQ-2, see
##   `technical-preferences.md`'s ADR-0001 status table) — this story builds no
##   such caller. What IS verified here: [method CursorState.get_device_authority]
##   correctly reads non-MOUSE across ALL THREE of AC-38's enumerated GIVEN
##   branches (hidden native pointer, partial mouse-reclaim visual feedback,
##   and the UNINITIALIZED startup state) — the exact query surface a future
##   click-handling caller would read to decide whether to reject a click. The
##   "click has no effect" half is not testable without that caller.
## - [b]AC-60[/b]: fully verifiable at this layer using a test-double
##   [Control] surface (matching AC-59's "today-constructible test double"
##   precedent this AC's own text cites), with its "unregistered" and
##   "does not pause" properties explicitly recorded per this AC's own
##   execution precondition.
##
## [b]Global state hygiene[/b]: [member Input.mouse_mode] is a process-wide
## engine singleton, not per-[CursorState] — every test here saves and
## restores it in [method before_test] / [method after_test] so this file
## cannot leak state into any other suite running in the same GdUnit4 process.
extends GdUnitTestSuite


var _original_mouse_mode: Input.MouseMode


func before_test() -> void:
	_original_mouse_mode = Input.mouse_mode


func after_test() -> void:
	Input.mouse_mode = _original_mouse_mode


func _test_mouse_position() -> Vector2:
	return Vector2.ZERO


## Minimal concrete [MouseReclaimPolicy] double — same pattern
## [code]tests/unit/cursor/state_host_test.gd[/code]'s [code]_FakeMouseReclaimPolicy[/code]
## already established. Used here (instead of [code]null[/code]) purely to
## avoid [constant CursorState.ERR_RECLAIM_POLICY_ABSENT]'s [method @GlobalScope.push_error]
## noise in tests that do not exercise the reclaim submechanism at all.
class _FakeMouseReclaimPolicy extends MouseReclaimPolicy:
	func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
		return false

	func reclaim_progress() -> float:
		return 0.0

	func reset(_seed_position: Vector2, _trigger: CursorTypes.ResetTrigger) -> void:
		pass

	func diagnostic_seed_position() -> Vector2:
		return Vector2.ZERO


func _make_state(registry: CursorSurfaceRegistry) -> CursorState:
	return CursorState.new(
		_FakeMouseReclaimPolicy.new(),
		registry,
		Callable(self, "_test_mouse_position")
	)


func _make_arbiter(
	state: CursorState,
	registry: CursorSurfaceRegistry,
	hover_provider: Callable
) -> NativePointerVisibilityArbiter:
	var arbiter := NativePointerVisibilityArbiter.new(state, registry, hover_provider)
	add_child(arbiter)
	auto_free(arbiter)
	return arbiter


# ─── Hover-provider test doubles (named methods, S-1 convention) ───────────

var _hover_stub_value: Variant = null


func _stub_hovered_control() -> Variant:
	return _hover_stub_value


# ─── AC-11: suppression persists across frames regardless of raw signal noise ─

func test_ac11_native_pointer_stays_hidden_across_many_frames_after_authority_transfers_away_from_mouse() -> void:
	# Arrange — "authority just transferred to B" simulated by direct field
	# write (機制六's actual transfer mechanism is Story 005's unbuilt SEAM;
	# this test's own scope is the PRESENTATION layer's reaction to whatever
	# authority value is current, not how it got there — matching the same
	# narrowing state_host_test.gd already applies to _device_authority).
	var registry := CursorSurfaceRegistry.new()
	var state := _make_state(registry)
	state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)

	_hover_stub_value = null  # no hover target at all — no exception can apply
	var arbiter := _make_arbiter(state, registry, Callable(self, "_stub_hovered_control"))

	# Act — many frames. NativePointerVisibilityArbiter reads no raw
	# InputEvents at all, so this loop is the strongest possible stand-in for
	# "A continues producing non-ui_* raw signals": even if such signals were
	# actually delivered, this component structurally cannot see them.
	#
	# 🔴 Asserts against diagnostic_last_desired_mouse_mode, NOT Input.mouse_mode
	# — see this file's class doc comment for why the real engine singleton is
	# not observable headless (measured: writes to it silently do not persist
	# without a real window/display server).
	for frame in range(10):
		arbiter._process(0.0)
		assert_int(arbiter.diagnostic_last_desired_mouse_mode).append_failure_message(
			(
				"frame %d: native pointer's DECIDED visibility became VISIBLE "
				+ "despite device authority remaining KEYBOARD_GAMEPAD the "
				+ "entire time."
			) % frame
		).is_equal(Input.MOUSE_MODE_HIDDEN)


# ─── AC-19 (PARTIAL — see class doc comment): presentation layer never writes to CursorState ─

func test_ac19_partial_hover_over_illegal_area_never_writes_cursor_state_regardless_of_frame_count() -> void:
	# Arrange — an "illegal cursor target area" test surface: NOT registered
	# under either CursorSurfaceRegistry table (not a mounted surface, not an
	# AC-60 exception either) — matching AC-19's own "UI 面板本身或棋盤外空白
	# 處" example.
	var registry := CursorSurfaceRegistry.new()
	var illegal_area := Control.new()
	auto_free(illegal_area)

	var state := _make_state(registry)
	# Establish a real, known-valid target first via a registered surface, so
	# "unchanged" is a comparison against a real prior value, not a vacuous
	# comparison of two nulls.
	var registered_node := Node.new()
	auto_free(registered_node)
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, registered_node)
	state.handoff_after_mount(CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 5))
	var target_before: CursorTarget = state.get_current_target()
	var authority_before: CursorTypes.Authority = state.get_device_authority()

	_hover_stub_value = illegal_area
	var arbiter := _make_arbiter(state, registry, Callable(self, "_stub_hovered_control"))

	# Act — "不論產生多少次原生移動事件": simulate many hover frames over the
	# illegal area.
	for _i in range(10):
		arbiter._process(0.0)

	# Assert — CursorState's target and device authority are completely
	# unaffected. This is provable at this layer because
	# NativePointerVisibilityArbiter contains no call to any CursorState write
	# entry anywhere in its implementation (structural fact, also enforced by
	# ADR-0005's registered forbidden pattern
	# external_access_to_cursor_reclaim_instance's sibling discipline for this
	# class — it only ever calls get_device_authority(), a read).
	var target_after: CursorTarget = state.get_current_target()
	assert_bool(target_after.equals(target_before)).append_failure_message(
		"cursor target changed after hovering an unregistered, non-exception "
		+ "surface — the presentation layer must never write to CursorState."
	).is_true()
	assert_bool(target_after.is_valid).is_equal(target_before.is_valid)
	assert_int(state.get_device_authority()).is_equal(authority_before)


# ─── AC-38 (PARTIAL — see class doc comment): device authority reads non-MOUSE ─
# across all three enumerated GIVEN branches ────────────────────────────────

func test_ac38_partial_device_authority_reads_non_mouse_when_native_pointer_hidden() -> void:
	# Branch 1: keyboard/gamepad holds authority, native pointer hidden per
	# Core Rules #5 (no reclaim progress in flight).
	var registry := CursorSurfaceRegistry.new()
	var state := _make_state(registry)
	state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)

	assert_int(state.get_device_authority()).is_not_equal(CursorTypes.Authority.MOUSE)


func test_ac38_partial_device_authority_reads_non_mouse_during_partial_reclaim_visual_feedback() -> void:
	# Branch 2: keyboard/gamepad still holds authority while a mouse-reclaim
	# attempt is PARTIALLY visible (0 < reclaim_progress < 1, AC-31b) — the
	# GDD's own point being that "指標可見" here must not be misread by a
	# caller as "authority is mouse".
	var reclaim_config := MouseReclaimThresholdConfig.new()
	reclaim_config.board_tile_threshold_px = 10.0
	var reclaim := ThresholdMouseReclaimPolicy.new(reclaim_config)
	var registry := CursorSurfaceRegistry.new()
	var state := CursorState.new(reclaim, registry, Callable(self, "_test_mouse_position"))
	state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)

	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	reclaim.evaluate(Vector2(3, 0), CursorTypes.SurfaceType.BOARD_TILE)
	assert_float(state.reclaim_progress()).append_failure_message(
		"arrange step did not produce a partial (0,1) reclaim_progress"
	).is_equal_approx(0.3, 0.0001)

	assert_int(state.get_device_authority()).is_not_equal(CursorTypes.Authority.MOUSE)


func test_ac38_partial_device_authority_reads_non_mouse_when_uninitialized() -> void:
	# Branch 3: system has not yet processed any device's ui_* action.
	var registry := CursorSurfaceRegistry.new()
	var state := _make_state(registry)

	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.UNINITIALIZED)
	assert_int(state.get_device_authority()).is_not_equal(CursorTypes.Authority.MOUSE)


# ─── AC-60: hovering an unregistered, non-pausing surface leaves cursor target untouched ─

func test_ac60_hovering_unregistered_non_pausing_surface_does_not_write_cursor_target() -> void:
	# Arrange — test-double surface with its two required properties recorded
	# explicitly, per this AC's own "選定的測試表面須在測試文件中明確記載其
	# 「未登記」與「不暫停」兩項屬性" instruction:
	#   (1) UNREGISTERED: not present in either CursorSurfaceRegistry table
	#       (neither table 1's mounted-surface registry nor table 2's AC-60
	#       exception whitelist) — verified explicitly below, not merely assumed.
	#   (2) DOES NOT PAUSE: this test never touches SceneTree.paused, and
	#       get_tree().paused is asserted false throughout — a plain Control
	#       test double has no mechanism to pause the tree at all.
	var registry := CursorSurfaceRegistry.new()
	var unregistered_surface := Control.new()
	auto_free(unregistered_surface)

	assert_bool(registry.is_native_pointer_exception(unregistered_surface)).append_failure_message(
		"test surface must NOT be registered as an AC-60 exception, or this "
		+ "test would be exercising the exception path instead of the "
		+ "jurisdiction-boundary path AC-60 actually verifies."
	).is_false()

	var state := _make_state(registry)
	var registered_node := Node.new()
	auto_free(registered_node)
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, registered_node)
	state.handoff_after_mount(CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 3))
	var target_before: CursorTarget = state.get_current_target()

	_hover_stub_value = unregistered_surface
	var arbiter := _make_arbiter(state, registry, Callable(self, "_stub_hovered_control"))

	# Act — repeated hover frames (mouse hover, no ui_* action), tree not paused.
	assert_bool(get_tree().paused).append_failure_message(
		"(2) property check: scene tree must not be paused during this test — "
		+ "AC-60's own GIVEN explicitly excludes surfaces that pause the tree."
	).is_false()
	for _i in range(5):
		arbiter._process(0.0)

	# Assert — current cursor target field completely unaffected.
	var target_after: CursorTarget = state.get_current_target()
	assert_bool(target_after.equals(target_before)).append_failure_message(
		"cursor target was written after hovering an unregistered, "
		+ "non-pausing surface — AC-60's jurisdiction boundary was violated."
	).is_true()
	assert_bool(target_after.is_valid).is_equal(target_before.is_valid)


# ─── R5-6 whitelist supplement (not itself one of the 4 delivered ACs) ──────
#
# Exercises BOTH directions of the whitelist decision via
# diagnostic_last_desired_mouse_mode — this is exactly the pair that would
# have been a loud-fail / silent-false-green split if asserted against the
# real Input.mouse_mode headless (see class doc comment). Supplements AC-60
# above, which deliberately does not assert on visibility at all.

func test_r5_6_desired_mode_is_hidden_for_unregistered_surface_and_visible_for_registered_exception() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var unregistered_surface := Control.new()
	auto_free(unregistered_surface)
	var exception_surface := Control.new()
	auto_free(exception_surface)
	registry.register_native_pointer_exception(exception_surface)

	var state := _make_state(registry)
	state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)
	var arbiter := _make_arbiter(state, registry, Callable(self, "_stub_hovered_control"))

	# Act / Assert — unregistered surface: HIDDEN (whitelist default).
	_hover_stub_value = unregistered_surface
	arbiter._process(0.0)
	assert_int(arbiter.diagnostic_last_desired_mouse_mode).append_failure_message(
		"unregistered surface must default to HIDDEN under the whitelist rule."
	).is_equal(Input.MOUSE_MODE_HIDDEN)

	# Act / Assert — explicitly registered exception surface: VISIBLE.
	_hover_stub_value = exception_surface
	arbiter._process(0.0)
	assert_int(arbiter.diagnostic_last_desired_mouse_mode).append_failure_message(
		"explicitly registered AC-60 exception surface did not resolve to VISIBLE."
	).is_equal(Input.MOUSE_MODE_VISIBLE)

	# Act / Assert — back to no hover at all: HIDDEN again.
	_hover_stub_value = null
	arbiter._process(0.0)
	assert_int(arbiter.diagnostic_last_desired_mouse_mode).is_equal(Input.MOUSE_MODE_HIDDEN)


func test_r5_6_desired_mode_is_visible_when_authority_is_mouse_regardless_of_hover() -> void:
	# Arrange — Core Rules #5's normal rule: mouse holds authority -> visible,
	# independent of hover target (even an unregistered one).
	var registry := CursorSurfaceRegistry.new()
	var unregistered_surface := Control.new()
	auto_free(unregistered_surface)

	var state := _make_state(registry)
	state.set(&"_device_authority", CursorTypes.Authority.MOUSE)
	_hover_stub_value = unregistered_surface
	var arbiter := _make_arbiter(state, registry, Callable(self, "_stub_hovered_control"))

	# Act
	arbiter._process(0.0)

	# Assert
	assert_int(arbiter.diagnostic_last_desired_mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
