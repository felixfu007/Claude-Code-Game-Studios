## Unit tests for [code]src/ui/cursor/threshold_mouse_reclaim_policy.gd[/code]
## and [code]src/ui/cursor/mouse_reclaim_threshold_config.gd[/code]
## (Story 014, ADR-0005 機制八). Covers AC-28, AC-28b, AC-35b, AC-42, AC-43,
## AC-45, AC-58 from
## [code]production/epics/cursor-highlight-state/story-014-mouse-reclaim-frozen.md[/code].
##
## [b]Scope narrowing — read before extending or "fixing" these tests[/b]:
## this story builds the [MouseReclaimPolicy] concrete strategy in isolation.
## It does NOT build, and these tests do NOT simulate:
## - Story 005's frame-buffered device-authority arbitration (機制六) — the
##   decision of WHICH [enum CursorTypes.ResetTrigger] applies in a given
##   frame, and whether device authority actually transfers.
##   🔴 [b]AC-35b and AC-58 are PARTIAL COVERAGE, not delivered[/b] (2026-09-07
##   coordinator re-review) — both ACs' own GIVEN is entirely inside that
##   unbuilt arbitration (which device wins the same-frame race, and whether
##   its action classifies as NAVIGATION vs CONFIRM). The two tests below
##   only verify what THIS policy does once Story 005 has already made that
##   decision and calls [method reset] (or does not call it) accordingly —
##   see each test's own comment for the exact split. Do not treat a green
##   result on either test as "AC-35b/AC-58 verified".
## - Story 011's presentation-layer transparency smoother — AC-28c / AC-41 /
##   AC-41b are that story's Visual/Feel-evidence ACs (per this story's own
##   work order Out of Scope section) and are not tested here. One
##   supplementary test below (not itself one of the 7 delivered ACs) does
##   verify that [signal MouseReclaimPolicy.reset_triggered] forwards every
##   [enum CursorTypes.ResetTrigger] member unchanged, because Story 011's
##   smoother depends entirely on that signal carrying the correct value.
##
## [b]GDD Formulas 邊界值 line 144 (negative threshold) — measured build
## interaction, 2026-09-07 coordinator review[/b]: a REAL
## [MouseReclaimThresholdConfig] cannot be used to reach GDD line 144's
## documented negative-threshold consequence from this test suite. Measured
## on this engine (Godot 4.7.1, editor/debug binary — see
## [code]mouse_reclaim_threshold_config.gd[/code]'s
## [method MouseReclaimThresholdConfig.threshold_for_surface] doc comment for
## the full probe evidence): that method's own boundary [method Object.assert]
## fires for a negative value, aborts the method before its
## [code]return value[/code] line, and GDScript substitutes the zero-value
## default for its [code]-> float[/code] return type ([code]0.0[/code]) —
## not the negative number actually configured. So the negative-threshold
## test below uses a minimal bypass double
## ([code]_RawThresholdConfigStub[/code]) instead of a real config, to
## exercise [method ThresholdMouseReclaimPolicy.evaluate]'s own
## division/clamp/comparison logic directly, independent of that unrelated
## defensive assert.
## [b]Tuning values are never hardcoded from the provisional default[/b]
## (`design/gdd/cursor-highlight-state.md` Tuning Knobs explicitly flags the
## per-surface-type table as unmeasured pending vertical-slice calibration).
## Every test below constructs an explicit [MouseReclaimThresholdConfig] via
## the [method _config] helper with fixture values chosen for this test file
## — never [code]MouseReclaimThresholdConfig.new()[/code]'s bare defaults —
## so no assertion here depends on what today's provisional number happens
## to be.
##
## All production code under test is pure [RefCounted] (no [Node], no scene
## tree, no [Input] singleton, no file I/O) — every test constructs directly
## with [code]new()[/code], headless, no random seed, no time dependency.
extends GdUnitTestSuite


## Builds a [MouseReclaimThresholdConfig] with explicit, test-chosen
## thresholds for all four surface types — never the class's bare
## provisional defaults, per this file's header note.
func _config(
	board_tile_px: float = 50.0,
	relation_minimap_node_px: float = 50.0,
	card_slot_px: float = 50.0,
	dialogue_choice_px: float = 50.0
) -> MouseReclaimThresholdConfig:
	var config: MouseReclaimThresholdConfig = MouseReclaimThresholdConfig.new()
	config.board_tile_threshold_px = board_tile_px
	config.relation_minimap_node_threshold_px = relation_minimap_node_px
	config.card_slot_threshold_px = card_slot_px
	config.dialogue_choice_threshold_px = dialogue_choice_px
	return config


# ─── Infrastructure sanity (not itself one of the 7 delivered ACs) ──────────
# These two tests do not correspond to a GDD AC number. They exist so a
# broken per-surface-type wiring or a regressed default could not make every
# AC test below pass by accident (e.g. off a single hardcoded global
# threshold).

func test_default_config_values_are_all_strictly_positive() -> void:
	# Arrange / Act — deliberately the ONE test in this file that touches the
	# bare provisional defaults, and only to check the Formulas 邊界值
	# legality constraint (> 0), never the actual number.
	var config: MouseReclaimThresholdConfig = MouseReclaimThresholdConfig.new()

	# Assert
	assert_float(config.board_tile_threshold_px).is_greater(0.0)
	assert_float(config.relation_minimap_node_threshold_px).is_greater(0.0)
	assert_float(config.card_slot_threshold_px).is_greater(0.0)
	assert_float(config.dialogue_choice_threshold_px).is_greater(0.0)


func test_evaluate_uses_the_threshold_for_the_given_surface_type_not_a_single_global_value() -> void:
	# Arrange — BOARD_TILE gets a small threshold, CARD_SLOT a large one
	var config: MouseReclaimThresholdConfig = _config()
	config.board_tile_threshold_px = 10.0
	config.card_slot_threshold_px = 200.0
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(config)
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act / Assert — 15px clears BOARD_TILE's 10px threshold
	assert_bool(policy.evaluate(Vector2(15, 0), CursorTypes.SurfaceType.BOARD_TILE)).is_true()

	# Fresh seed, same 15px does NOT clear CARD_SLOT's 200px threshold —
	# proves evaluate() looks the threshold up per-call, not once at construction
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.TARGET_CHANGED)
	assert_bool(policy.evaluate(Vector2(15, 0), CursorTypes.SurfaceType.CARD_SLOT)).is_false()


# ─── AC-28: threshold reached (or exceeded) → valid reclaim claim, full progress ──

func test_ac28_evaluate_returns_true_and_progress_is_full_at_exactly_the_threshold() -> void:
	# Arrange — GDD 原文「達...以上」(reach OR exceed): exactly-at-threshold
	# must count as a valid claim, not just strictly-above.
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act
	var claimed: bool = policy.evaluate(Vector2(50, 0), CursorTypes.SurfaceType.BOARD_TILE)

	# Assert
	assert_bool(claimed).is_true()
	assert_float(policy.reclaim_progress()).is_equal_approx(1.0, 0.0001)


func test_ac28_evaluate_returns_true_and_progress_clamps_to_one_beyond_the_threshold() -> void:
	# Arrange
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act — 80px net displacement against a 50px threshold
	var claimed: bool = policy.evaluate(Vector2(80, 0), CursorTypes.SurfaceType.BOARD_TILE)

	# Assert — progress clamps to 1.0, not 1.6 (Formulas: clamp(...,  0.0, 1.0))
	assert_bool(claimed).is_true()
	assert_float(policy.reclaim_progress()).is_equal_approx(1.0, 0.0001)


# ─── AC-28b: below threshold → no claim, no drift across subsequent frames ──

func test_ac28b_evaluate_returns_false_below_threshold() -> void:
	# Arrange
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act
	var claimed: bool = policy.evaluate(Vector2(49, 0), CursorTypes.SurfaceType.BOARD_TILE)

	# Assert
	assert_bool(claimed).is_false()
	assert_float(policy.reclaim_progress()).is_equal_approx(49.0 / 50.0, 0.0001)


func test_ac28b_state_unchanged_across_repeated_subsequent_frames_while_still_below_threshold() -> void:
	# Arrange — AC-28b's WHEN clause is "任意後續影格" (any subsequent frame),
	# not just the one immediately after the move.
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act / Assert — repeated queries at the same below-threshold position
	for frame in range(3):
		assert_bool(policy.evaluate(Vector2(30, 0), CursorTypes.SurfaceType.BOARD_TILE)) \
			.append_failure_message("frame %d" % frame).is_false()
	assert_float(policy.reclaim_progress()).is_equal_approx(30.0 / 50.0, 0.0001)


# ─── AC-45: net displacement, never a path-sum (anti-jitter) ───────────────

func test_ac45_repeated_back_and_forth_motion_does_not_accumulate_path_length() -> void:
	# Arrange — a policy queried once, directly, at the final resting
	# position, establishes the baseline "correct" reading.
	var baseline_policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(
		_config(50.0, 50.0, 50.0, 50.0)
	)
	baseline_policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	var baseline_claim: bool = baseline_policy.evaluate(Vector2(5, 0), CursorTypes.SurfaceType.BOARD_TILE)
	var baseline_progress: float = baseline_policy.reclaim_progress()

	# A second policy oscillates back and forth 20 times before settling at
	# the SAME final position — 20 * (30 + 25) = 1100px of path length,
	# far above the 50px threshold, while net displacement from the seed
	# (0,0) to the final position (5,0) is only 5px.
	var oscillating_policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(
		_config(50.0, 50.0, 50.0, 50.0)
	)
	oscillating_policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	for _i in range(20):
		oscillating_policy.evaluate(Vector2(30, 0), CursorTypes.SurfaceType.BOARD_TILE)
		oscillating_policy.evaluate(Vector2(5, 0), CursorTypes.SurfaceType.BOARD_TILE)

	# Act — one more query at the final position, matching the baseline's
	# single query exactly
	var final_claim: bool = oscillating_policy.evaluate(Vector2(5, 0), CursorTypes.SurfaceType.BOARD_TILE)
	var final_progress: float = oscillating_policy.reclaim_progress()

	# Assert — identical to the baseline: no authority claim, no leftover
	# path-length state distinguishing the two policies
	assert_bool(baseline_claim).is_false()
	assert_bool(final_claim).is_false()
	assert_float(final_progress).is_equal_approx(baseline_progress, 0.0001)


# ─── AC-42: transfer TO mouse → accumulator zeroed at the instant of transfer ──

func test_ac42_reset_after_authority_transfer_to_mouse_zeroes_progress_immediately() -> void:
	# Arrange — bring the policy to a completed claim first (the moment
	# transfer would happen)
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	policy.evaluate(Vector2(50, 0), CursorTypes.SurfaceType.BOARD_TILE)
	assert_float(policy.reclaim_progress()).is_equal_approx(1.0, 0.0001)  # sanity check on the arrange step

	var captured: Array[CursorTypes.ResetTrigger] = []
	policy.reset_triggered.connect(func(trigger: CursorTypes.ResetTrigger) -> void: captured.append(trigger))

	# Act — Story 005's (unbuilt) arbitration is what decides "transfer just
	# happened, call reset(AUTHORITY_TRANSFER) now"; this test verifies only
	# what THIS policy does once that call is made.
	policy.reset(Vector2(50, 0), CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Assert
	assert_float(policy.reclaim_progress()).is_equal_approx(0.0, 0.0001)
	assert_array(captured).is_equal([CursorTypes.ResetTrigger.AUTHORITY_TRANSFER])


# ─── AC-43: target changed by nav → zeroed AND reseeded at that frame's mouse position ──

func test_ac43_reset_on_target_changed_zeroes_progress_and_reseeds_at_given_position() -> void:
	# Arrange — partial progress, not yet at the threshold
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	policy.evaluate(Vector2(20, 0), CursorTypes.SurfaceType.BOARD_TILE)
	assert_float(policy.reclaim_progress()).is_equal_approx(0.4, 0.0001)  # sanity check on the arrange step

	var captured: Array[CursorTypes.ResetTrigger] = []
	policy.reset_triggered.connect(func(trigger: CursorTypes.ResetTrigger) -> void: captured.append(trigger))

	# Act — keyboard/gamepad navigation changes the highlighted target this
	# frame; the caller reseeds at THIS frame's mouse screen position
	# (AC-43's "該影格滑鼠的螢幕座標")
	policy.reset(Vector2(20, 0), CursorTypes.ResetTrigger.TARGET_CHANGED)

	# Assert — zeroed, reseeded, correct trigger forwarded
	assert_float(policy.reclaim_progress()).is_equal_approx(0.0, 0.0001)
	assert_vector(policy.diagnostic_seed_position()).is_equal(Vector2(20, 0))
	assert_array(captured).is_equal([CursorTypes.ResetTrigger.TARGET_CHANGED])

	# Post-condition — querying AT the new seed position must read zero net
	# displacement, proving the origin actually moved (not just the cached
	# progress number)
	assert_bool(policy.evaluate(Vector2(20, 0), CursorTypes.SurfaceType.BOARD_TILE)).is_false()
	assert_float(policy.reclaim_progress()).is_equal_approx(0.0, 0.0001)


# ─── AC-35b (PARTIAL COVERAGE ONLY — see comment below): same-frame veto ──

func test_ac35b_veto_reset_zeroes_progress_and_reseeds_so_next_frame_does_not_auto_complete() -> void:
	# 🔴 PARTIAL COVERAGE — 2026-09-07 coordinator re-review. Do not read a
	# passing result here as "AC-35b is verified". AC-35b's own GIVEN is
	# "keyboard/gamepad's NAVIGATION-class action WINS the same-frame race
	# against the mouse" (Edge Cases「同一影格雙裝置」fixed priority) — THAT
	# arbitration decision is Story 005's (機制六, the SEAM in
	# cursor_state.gd's arbitrate_device_authority(), currently empty) and is
	# NOT exercised by this test at all.
	#
	# What IS verified here: given that Story 005's arbitration has ALREADY
	# decided the veto happened and calls
	# reset(mouse_pos, VETOED_SAME_FRAME), this policy's own reaction to that
	# call is correct — the accumulator zeroes and reseeds, so the mouse
	# cannot silently auto-complete next frame off a stale near-full
	# progress value. That is a real, useful, independently-testable half of
	# AC-35b, but it is only half. The other half (does the arbitration
	# actually happen, and does it correctly recognize a NAVIGATION-class
	# action) has zero test coverage anywhere in this repository today —
	# Story 005 owns writing that coverage when it builds the SEAM.
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)
	policy.evaluate(Vector2(50, 0), CursorTypes.SurfaceType.BOARD_TILE)  # mouse reached threshold this frame
	assert_float(policy.reclaim_progress()).is_equal_approx(1.0, 0.0001)  # sanity check on the arrange step

	var captured: Array[CursorTypes.ResetTrigger] = []
	policy.reset_triggered.connect(func(trigger: CursorTypes.ResetTrigger) -> void: captured.append(trigger))

	# Act
	policy.reset(Vector2(50, 0), CursorTypes.ResetTrigger.VETOED_SAME_FRAME)

	# Assert
	assert_float(policy.reclaim_progress()).is_equal_approx(0.0, 0.0001)
	assert_vector(policy.diagnostic_seed_position()).is_equal(Vector2(50, 0))
	assert_array(captured).is_equal([CursorTypes.ResetTrigger.VETOED_SAME_FRAME])

	# Post-condition — AC-35b's THEN clause explicitly requires this: next
	# frame, with no further mouse movement, must NOT auto-complete.
	assert_bool(policy.evaluate(Vector2(50, 0), CursorTypes.SurfaceType.BOARD_TILE)).is_false()


# ─── AC-58 (PARTIAL COVERAGE ONLY — see comment below): confirm-only, no veto ──

func test_ac58_confirm_only_action_does_not_reset_so_mouse_claim_survives_unvetoed() -> void:
	# 🔴 PARTIAL COVERAGE — 2026-09-07 coordinator re-review. Do not read a
	# passing result here as "AC-58 is verified". Same split as AC-35b
	# above: AC-58's own GIVEN is "keyboard/gamepad's same-frame action is
	# CONFIRM-class, which structurally lacks standing to veto at all"
	# (Core Rules #3「確認類動作不觸發本重置路徑」) — classifying the action and
	# deciding it therefore does NOT veto is Story 005's arbitration
	# decision (機制六, the SEAM in cursor_state.gd's
	# arbitrate_device_authority(), currently empty), and is NOT exercised
	# by this test.
	#
	# What IS verified here is the negative space this policy is
	# responsible for: GIVEN that Story 005 correctly does NOT call reset()
	# in this scenario, this policy does not spontaneously invalidate a
	# claim that already reached its threshold this frame. That is real,
	# useful, independently-testable — but it is only the "this policy
	# stays out of the way" half. The other half (does the arbitration
	# actually classify a confirm-class action correctly and skip the
	# veto) has zero test coverage anywhere in this repository today —
	# Story 005 owns writing that coverage when it builds the SEAM.
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	var captured: Array[CursorTypes.ResetTrigger] = []
	policy.reset_triggered.connect(func(trigger: CursorTypes.ResetTrigger) -> void: captured.append(trigger))

	# Act — mouse reaches the threshold; NO reset() call happens (this IS
	# the confirm-only scenario: nothing vetoes the claim)
	var claimed: bool = policy.evaluate(Vector2(50, 0), CursorTypes.SurfaceType.BOARD_TILE)

	# Assert — claim stands, no spurious reset fired
	assert_bool(claimed).is_true()
	assert_float(policy.reclaim_progress()).is_equal_approx(1.0, 0.0001)
	assert_array(captured).is_equal([])

	# Post-condition — querying again at the same position still reads the
	# completed claim; nothing silently reverted it
	assert_bool(policy.evaluate(Vector2(50, 0), CursorTypes.SurfaceType.BOARD_TILE)).is_true()


# ─── Supporting Story 011's dependency (not itself one of the 7 delivered ACs) ──

func test_reset_triggered_forwards_every_reset_trigger_enum_member_unchanged() -> void:
	# The presentation-layer smoother (Story 011, out of scope here)
	# distinguishes VETOED_SAME_FRAME (snaps to zero, AC-41b) from the other
	# four triggers (converge instead, AC-41) purely by the enum value
	# carried on reset_triggered. This test proves every
	# CursorTypes.ResetTrigger member passes through reset() -> signal
	# unchanged, not just the subset the 7 delivered ACs above happen to
	# exercise.
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(_config(50.0, 50.0, 50.0, 50.0))
	var captured: Array[CursorTypes.ResetTrigger] = []
	policy.reset_triggered.connect(func(trigger: CursorTypes.ResetTrigger) -> void: captured.append(trigger))

	var all_triggers: Array[CursorTypes.ResetTrigger] = [
		CursorTypes.ResetTrigger.AUTHORITY_TRANSFER,
		CursorTypes.ResetTrigger.TARGET_CHANGED,
		CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED,
		CursorTypes.ResetTrigger.VETOED_SAME_FRAME,
		CursorTypes.ResetTrigger.SURFACE_HANDOFF,
	]
	for trigger in all_triggers:
		policy.reset(Vector2.ZERO, trigger)

	assert_array(captured).is_equal(all_triggers)


# ─── GDD Formulas 邊界值 line 144 — negative threshold (2026-09-07 coordinator review) ──

## Bypasses [method MouseReclaimThresholdConfig.threshold_for_surface]'s own
## boundary [method Object.assert] by overriding it to hand back a raw value
## with no guard at all. See this file's header doc comment and
## [method test_negative_threshold_permanently_clamps_progress_to_zero_per_gdd_line_144]
## for exactly why a real [MouseReclaimThresholdConfig] cannot be used here —
## in short: its own assert intercepts a negative value in this editor/debug
## build and silently substitutes [code]0.0[/code] instead, so a test built on
## a real config instance would end up exercising the ZERO-threshold case
## instead of the NEGATIVE one it is named for.
class _RawThresholdConfigStub extends MouseReclaimThresholdConfig:
	var _raw_value: float = 0.0

	func _init(raw_value: float) -> void:
		_raw_value = raw_value

	func threshold_for_surface(_surface: CursorTypes.SurfaceType) -> float:
		return _raw_value


func test_negative_threshold_permanently_clamps_progress_to_zero_per_gdd_line_144() -> void:
	# This test pins a DOCUMENTED FAILURE MODE, not a correct/desired
	# feature. GDD `design/gdd/cursor-highlight-state.md:144` (Formulas 邊界值)
	# states verbatim what a misconfigured negative threshold does:
	# "displacement / 負值 ≤ 0,clamp() 後 reclaim_progress 恆為 0.0 —— 該表面類型
	# 上滑鼠永久無法奪回權威,不拋出任何例外,是比除以零更難察覺的靜默死鎖。" A
	# negative threshold is a FORBIDDEN configuration (see
	# MouseReclaimThresholdConfig's own boundary assert) that AC-46's
	# system-level startup rejection (Story 006, unbuilt) is meant to
	# prevent from ever existing — this test exists only so THIS class's
	# behavior on that illegal input, if it ever occurs, stays consistent
	# with what the GDD says happens, per the 2026-09-07 coordinator fix to
	# evaluate()'s boolean derivation.
	#
	# Arrange — bypass double, not a real MouseReclaimThresholdConfig; see
	# the class doc comment above and this file's header comment for why.
	var negative_config: _RawThresholdConfigStub = _RawThresholdConfigStub.new(-10.0)
	var policy: ThresholdMouseReclaimPolicy = ThresholdMouseReclaimPolicy.new(negative_config)
	policy.reset(Vector2.ZERO, CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Act — net displacement is a distance (GDD: "恆為非負"), so try both zero
	# and a large displacement; GDD line 144 claims the lockout is permanent
	# REGARDLESS of how far the mouse moves.
	var claim_at_zero_displacement: bool = policy.evaluate(Vector2.ZERO, CursorTypes.SurfaceType.BOARD_TILE)
	var progress_at_zero_displacement: float = policy.reclaim_progress()
	var claim_at_large_displacement: bool = policy.evaluate(Vector2(500, 0), CursorTypes.SurfaceType.BOARD_TILE)
	var progress_at_large_displacement: float = policy.reclaim_progress()

	# Assert — GDD line 144's documented consequence: reclaim_progress
	# permanently clamps to 0.0 and evaluate() never returns true, no matter
	# how far the mouse moves — a silent, permanent deadlock, not an
	# exception.
	assert_float(progress_at_zero_displacement).is_equal_approx(0.0, 0.0001)
	assert_bool(claim_at_zero_displacement).is_false()
	assert_float(progress_at_large_displacement).is_equal_approx(0.0, 0.0001)
	assert_bool(claim_at_large_displacement).is_false()
