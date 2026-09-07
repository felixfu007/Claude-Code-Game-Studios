## Unit tests for [code]src/ui/cursor/self_drawn_reclaim_cursor.gd[/code]
## (Story 011, ADR-0005 機制十三). Covers AC-31 and AC-31b from
## [code]production/epics/cursor-highlight-state/story-011-native-cursor-suppression.md[/code],
## plus a NAN-safety pin required by this story's own dispatch (2026-09-07
## coordinator finding, see [code]threshold_mouse_reclaim_policy.gd[/code]'s
## doc comment).
##
## [b]Why every test here builds its own [CursorState] rather than using the
## [code]CursorStateHost[/code] Autoload's instance[/b]: AC-31b's execution-time
## domain (a non-zero, non-one [code]reclaim_progress()[/code]) can only be
## reached by controlling a [MouseReclaimPolicy] directly — this story's
## dispatch explicitly requires an injected test double, never the Autoload's
## real instance, for exactly this reason.
##
## [b]Determinism[/b]: [ThresholdMouseReclaimPolicy] and [SelfDrawnReclaimCursor]
## are both driven by hand-called [method Node._process] with an explicit
## [code]_delta[/code] the production code never reads — no timer, no
## [code]await[/code], no random seed.
extends GdUnitTestSuite


const _MOUSE_POSITION: Vector2 = Vector2.ZERO


func _threshold_config(px: float) -> MouseReclaimThresholdConfig:
	var config := MouseReclaimThresholdConfig.new()
	config.board_tile_threshold_px = px
	config.relation_minimap_node_threshold_px = px
	config.card_slot_threshold_px = px
	config.dialogue_choice_threshold_px = px
	return config


func _make_state(reclaim: MouseReclaimPolicy) -> CursorState:
	return CursorState.new(
		reclaim,
		CursorSurfaceRegistry.new(),
		Callable(self, "_test_mouse_position")
	)


func _test_mouse_position() -> Vector2:
	return _MOUSE_POSITION


func _make_cursor(state: CursorState, max_frames: int = 2) -> SelfDrawnReclaimCursor:
	var visual_config := CursorReclaimVisualConfig.new()
	visual_config.reclaim_visual_convergence_max_frames = max_frames
	var cursor := SelfDrawnReclaimCursor.new(state, visual_config)
	add_child(cursor)
	auto_free(cursor)
	return cursor


# ─── AC-31: binary "hidden" (presented alpha == 0.0) when progress == 0 ──────
#
# 🔴 Anti-vacuous-pass sentinel (this story's dispatch, 2026-09-07): before
# Story 011 wired a real MouseReclaimPolicy into CursorStateHost,
# reclaim_progress() returned 0.0 UNCONDITIONALLY (see
# cursor_state.gd's CursorState.ERR_RECLAIM_POLICY_ABSENT), which made AC-31
# pass with zero discriminating power — a hardwired-always-0 implementation
# would have passed identically. The test below first drives the presented
# alpha to a NON-zero sentinel value and asserts it actually moved, so a
# subsequent read of exactly 0.0 is evidence "a reset really happened", not
# "this was always going to read 0 no matter what".

func test_ac31_presented_alpha_reads_zero_when_reclaim_progress_is_exactly_zero_not_vacuously() -> void:
	# Arrange — real ThresholdMouseReclaimPolicy (not a fake), threshold 10px,
	# convergence window fixed at 2 frames so the math is exact and hand-checkable.
	var reclaim := ThresholdMouseReclaimPolicy.new(_threshold_config(10.0))
	var state := _make_state(reclaim)
	var cursor := _make_cursor(state, 2)

	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Sentinel — drive progress to 0.5 (5px of a 10px threshold) and confirm
	# the cursor's presented alpha actually follows it (rising edge, immediate
	# sync per R4-3). If this step did not move presented alpha away from 0,
	# the assertion below would prove nothing.
	reclaim.evaluate(Vector2(5, 0), CursorTypes.SurfaceType.BOARD_TILE)
	cursor._process(0.0)
	assert_float(cursor.modulate.a).append_failure_message(
		"sentinel step failed to move presented alpha away from 0 — this "
		+ "test cannot distinguish 'really reads progress' from 'hardwired "
		+ "to 0', the exact false-green shape AC-31 had before Story 011's "
		+ "own MouseReclaimPolicy wiring landed."
	).is_greater(0.0)

	# Act — return progress to exactly 0 via a REAL reset() call (trigger (a),
	# AUTHORITY_TRANSFER — converges, does not snap). With max_frames = 2,
	# max_step = 0.5, so exactly one _process() call carries 0.5 -> 0.0 exactly.
	reclaim.reset(Vector2(5, 0), CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	cursor._process(0.0)

	# Assert — AC-31's own binary reading, now proven non-vacuous by the
	# sentinel step above.
	assert_float(cursor.modulate.a).is_equal_approx(0.0, 0.0001)


# ─── AC-31b: presented alpha proportional to progress in (0, 1) ─────────────

func test_ac31b_presented_alpha_is_proportional_to_reclaim_progress_between_zero_and_one() -> void:
	# Arrange
	var reclaim := ThresholdMouseReclaimPolicy.new(_threshold_config(10.0))
	var state := _make_state(reclaim)
	var cursor := _make_cursor(state)

	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act — 3px of a 10px threshold = 0.3 progress, strictly between 0 and 1.
	reclaim.evaluate(Vector2(3, 0), CursorTypes.SurfaceType.BOARD_TILE)
	cursor._process(0.0)  # rising edge, immediate sync (R4-3)

	# Assert — proportional, not the AC-31 binary-hidden reading (0.0) and not
	# a saturated 1.0.
	assert_float(cursor.modulate.a).append_failure_message(
		"presented alpha did not track reclaim_progress proportionally: "
		+ "expected ~0.3, got %f" % cursor.modulate.a
	).is_equal_approx(0.3, 0.0001)


## AC-28c's own text has TWO clauses. The proportionality clause overlaps
## AC-31b's test above; this test targets the clause AC-31b does NOT cover:
## "連續多個移動中的影格之間,透明度不發生無對應輸入變化量的瞬間跳變" (across
## consecutive in-motion frames, alpha never jumps without a corresponding
## input change) — i.e. per-frame tracking, not merely "some single frame
## reads a proportional value". 🔴 2026-09-07 coordinator finding: this
## clause had ZERO test coverage anywhere in this file; AC-31b's single-frame
## snapshot cannot stand in for it.
func test_ac28c_presented_alpha_tracks_incremental_mouse_movement_frame_by_frame_with_no_unaccounted_jump() -> void:
	# Arrange — 10px threshold, feed strictly increasing sub-threshold net
	# displacement one pixel at a time (1px..9px), one _process() call per step.
	var reclaim := ThresholdMouseReclaimPolicy.new(_threshold_config(10.0))
	var state := _make_state(reclaim)
	var cursor := _make_cursor(state)
	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	var previous_alpha: float = 0.0
	for px in range(1, 10):
		# Act — one frame per 1px increment of movement.
		reclaim.evaluate(Vector2(px, 0), CursorTypes.SurfaceType.BOARD_TILE)
		cursor._process(0.0)

		var expected_alpha: float = float(px) / 10.0
		var actual_alpha: float = cursor.modulate.a

		# Assert (per-frame) — alpha this frame corresponds EXACTLY to the
		# progress produced by this frame's own input, not a stale, delayed,
		# or prematurely-jumped value.
		assert_float(actual_alpha).append_failure_message(
			(
				"frame at %dpx: presented alpha %f does not correspond to "
				+ "this frame's own input-derived progress %f — either a "
				+ "delayed read (previous frame's value) or an unaccounted "
				+ "jump (some other frame's value)."
			) % [px, actual_alpha, expected_alpha]
		).is_equal_approx(expected_alpha, 0.0001)

		# Assert (delta) — the CHANGE from the previous frame is exactly
		# accounted for by the CHANGE in input (1px / 10px = 0.1 per step),
		# never more, never less, never in the wrong direction — this is the
		# literal "無對應輸入變化量的瞬間跳變" (no jump without a corresponding
		# input delta) clause.
		var delta: float = actual_alpha - previous_alpha
		assert_float(delta).append_failure_message(
			(
				"frame at %dpx: alpha changed by %f this frame, but the "
				+ "input only changed by 1px of a 10px threshold (expected "
				+ "delta 0.1) — an unaccounted jump."
			) % [px, delta]
		).is_equal_approx(0.1, 0.0001)

		previous_alpha = actual_alpha


func test_ac31_ac31b_boundary_is_exact_no_overlap_no_gap() -> void:
	# Arrange — AC-31's own text requires the two ACs' judgment boundary
	# (reclaim_progress == 0 vs > 0) be "明確、互斥、無重疊或缺口" (exact,
	# mutually exclusive, no overlap or gap). Probe values just below and
	# exactly at the transition.
	var reclaim := ThresholdMouseReclaimPolicy.new(_threshold_config(10.0))
	var state := _make_state(reclaim)
	var cursor := _make_cursor(state)
	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act / Assert — progress exactly 0: AC-31 binary hidden.
	cursor._process(0.0)
	assert_float(cursor.modulate.a).is_equal_approx(0.0, 0.0001)

	# The smallest representable step above zero: AC-31b's proportional regime.
	reclaim.evaluate(Vector2(0.001, 0), CursorTypes.SurfaceType.BOARD_TILE)
	cursor._process(0.0)
	assert_float(cursor.modulate.a).is_greater(0.0)


# ─── R4-3: rising edge reaches 1.0 on the exact frame the threshold crosses ──

func test_r4_3_presented_alpha_reaches_full_on_the_exact_frame_threshold_is_crossed() -> void:
	# Arrange — this is the specific regression R4-3 exists to prevent: a
	# smoother that rate-limits BOTH directions cannot reach 1.0 on the
	# crossing frame at all (see self_drawn_reclaim_cursor.gd's own doc
	# comment for the full mathematical derivation cited in this story's
	# dispatch).
	var reclaim := ThresholdMouseReclaimPolicy.new(_threshold_config(10.0))
	var state := _make_state(reclaim)
	var cursor := _make_cursor(state, 2)
	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act — single frame, straight to the threshold.
	reclaim.evaluate(Vector2(10, 0), CursorTypes.SurfaceType.BOARD_TILE)
	cursor._process(0.0)

	# Assert
	assert_float(cursor.modulate.a).is_equal_approx(1.0, 0.0001)


# ─── AC-41b: trigger (d) snaps to zero within the same frame, no convergence ─

func test_ac41b_vetoed_same_frame_trigger_snaps_to_zero_within_the_same_frame() -> void:
	# Arrange — reach full progress, then veto it. With a LARGE convergence
	# window (10 frames), a converging implementation would need many frames
	# to reach 0; trigger (d) must reach it in exactly one.
	var reclaim := ThresholdMouseReclaimPolicy.new(_threshold_config(10.0))
	var state := _make_state(reclaim)
	var cursor := _make_cursor(state, 10)
	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	reclaim.evaluate(Vector2(10, 0), CursorTypes.SurfaceType.BOARD_TILE)
	cursor._process(0.0)
	assert_float(cursor.modulate.a).is_equal_approx(1.0, 0.0001)  # sanity check on arrange

	# Act — trigger (d): same-frame veto.
	reclaim.reset(Vector2(10, 0), CursorTypes.ResetTrigger.VETOED_SAME_FRAME)
	cursor._process(0.0)

	# Assert — zero on the SAME frame the trigger fired, despite a 10-frame
	# convergence window that would otherwise mean this is impossible.
	assert_float(cursor.modulate.a).is_equal_approx(0.0, 0.0001)


# ─── AC-41: triggers (a)(b)(c) converge, never snap within a single frame ────

func test_ac41_authority_transfer_trigger_converges_over_configured_frame_count_not_snap() -> void:
	# Arrange — 4-frame convergence window, chosen so a snap-to-zero bug is
	# distinguishable from correct convergence on the very first post-reset frame.
	var reclaim := ThresholdMouseReclaimPolicy.new(_threshold_config(10.0))
	var state := _make_state(reclaim)
	var cursor := _make_cursor(state, 4)
	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	reclaim.evaluate(Vector2(10, 0), CursorTypes.SurfaceType.BOARD_TILE)
	cursor._process(0.0)
	assert_float(cursor.modulate.a).is_equal_approx(1.0, 0.0001)  # sanity check on arrange

	# Act — trigger (a), AUTHORITY_TRANSFER: must converge, not snap.
	reclaim.reset(Vector2(10, 0), CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	cursor._process(0.0)

	# Assert — max_step = 1.0 / 4 = 0.25, so after exactly one frame the
	# presented alpha is 0.75, NOT 0.0. A snap-to-zero bug would fail this.
	assert_float(cursor.modulate.a).append_failure_message(
		"presented alpha snapped to 0 on the first post-reset frame for "
		+ "AUTHORITY_TRANSFER (trigger a) — AC-41 requires (a)(b)(c) to "
		+ "CONVERGE, never snap within a single frame; only trigger (d) may "
		+ "snap (AC-41b)."
	).is_equal_approx(0.75, 0.0001)

	# Continue converging: 3 more frames of -0.25 reaches exactly 0.
	cursor._process(0.0)
	cursor._process(0.0)
	cursor._process(0.0)
	assert_float(cursor.modulate.a).is_equal_approx(0.0, 0.0001)


# ─── NAN safety (2026-09-07 coordinator finding, this story's own fix) ──────

## Bypasses [method MouseReclaimThresholdConfig.threshold_for_surface]'s own
## boundary [method Object.assert] entirely (same technique
## [code]tests/unit/cursor/mouse_reclaim_test.gd[/code]'s own
## [code]_RawThresholdConfigStub[/code] uses for the negative-threshold case) —
## avoids triggering that assert's editor/debug-build warning noise for a
## value (0.0) this test needs to reach cleanly.
class _ZeroThresholdConfigStub extends MouseReclaimThresholdConfig:
	func threshold_for_surface(_surface: CursorTypes.SurfaceType) -> float:
		return 0.0


func test_nan_reclaim_progress_does_not_propagate_into_presented_alpha() -> void:
	# Arrange — GDD Formulas 邊界值's second illegal-input split (measured on
	# this engine, documented in threshold_mouse_reclaim_policy.gd's own
	# 2026-09-07 doc comment): a ZERO threshold with net displacement also
	# exactly 0.0 (mouse never left its seed) computes 0.0 / 0.0 == NAN, and
	# clampf(NAN, 0.0, 1.0) returns NAN UNCHANGED — CursorState.reclaim_progress()
	# would hand this smoother a NAN value.
	var reclaim := ThresholdMouseReclaimPolicy.new(_ZeroThresholdConfigStub.new())
	reclaim.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	# reset() alone sets _last_progress to a REAL 0.0, not NAN — NAN only
	# appears once evaluate() actually computes 0.0 net-displacement /
	# 0.0 threshold. Querying at the seed position itself (net displacement
	# == 0.0) is what triggers it.
	reclaim.evaluate(Vector2.ZERO, CursorTypes.SurfaceType.BOARD_TILE)

	# Sanity check on the arrange step — confirm this really does produce NAN
	# before testing the smoother's reaction, so a future engine change that
	# stops producing NAN here does not leave this test silently meaningless.
	assert_bool(is_nan(reclaim.reclaim_progress())).append_failure_message(
		"arrange step did not reproduce NAN via 0.0/0.0 — this engine's "
		+ "float division behavior may have changed; this test's premise no "
		+ "longer holds and must be re-derived, not left green by accident."
	).is_true()

	var state := _make_state(reclaim)
	var cursor := _make_cursor(state)

	# Act
	cursor._process(0.0)

	# Assert — modulate.a must be a finite number, NEVER NAN. This cannot be
	# caught by a >=/<= range check anywhere downstream — every comparison
	# against NAN is false under IEEE-754 — so it is asserted directly with
	# is_nan(), matching this story's dispatch instruction.
	assert_bool(is_nan(cursor.modulate.a)).append_failure_message(
		"SelfDrawnReclaimCursor propagated NAN into modulate.a — this makes "
		+ "the cursor's rendered alpha undefined, and any downstream >=/<= "
		+ "guard against it would be silently useless (every NAN comparison "
		+ "evaluates to false)."
	).is_false()

	# Additionally pin the CHOSEN behavior (treat NAN as "no progress"), not
	# merely "not NAN" — a future refactor could otherwise silently pick a
	# different fallback (e.g. 1.0) and still pass the weaker assertion above.
	assert_float(cursor.modulate.a).is_equal_approx(0.0, 0.0001)
