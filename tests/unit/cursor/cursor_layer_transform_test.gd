## Story 010 — regression tests for [code]src/ui/cursor/cursor_state_host.gd[/code]'s
## dedicated presentation [CanvasLayer] (機制十二).
##
## Covers:
## - AC-S010-a (transform identity): ADR-0005 Validation Criteria #20 — the
##   layer's [method CanvasItem.get_final_transform] must stay
##   [constant Transform2D.IDENTITY] across every resolution.
## - AC-S010-b (exclusivity, narrowed — see the two AC-S010-b tests below):
##   the structural precondition that this is a distinct node no other
##   system has attached content to. Full behavioral coverage ("only
##   cursor-system content, ever") cannot be exercised until Story 011 adds
##   real children — documented explicitly rather than presenting a
##   0-children snapshot as the complete claim, following the same narrowing
##   convention [code]state_host_test.gd[/code] already established for this
##   system's earlier stories.
##
## [b]Why headless can measure this at all[/b]: this story's own probe
## ([code]prototypes/story-010-headless-resolution-probe-2026-09-04/[/code])
## established that [code]DisplayServer.window_set_size()[/code] is a
## silent no-op under [code]--headless[/code] (always reports [code](0, 0)[/code]),
## but directly assigning [member Window.size] on [code]get_tree().root[/code]
## DOES engage the engine's real content-scale transform, and the resulting
## numbers match the 2026-09-01 non-headless, real-GPU spike exactly
## (1080p 4x / 2K 5x+offset(80,45) / 4K 8x / ultrawide 5x+offset(520,45)).
## 🔴 [b]This file does not trust that finding by citation alone[/b] — see
## [method test_environment_reality_check_root_transform_is_identity_under_disabled_stretch_mode]
## below, which re-proves it live, in THIS test runtime (GdUnit4's own
## process), not the bare [SceneTree] script the probe used.
##
## [b]Isolation[/b]: every test that resizes [code]get_tree().root[/code]
## restores it in [method after_test] — this project's other suites run in
## the same engine process, and a mutated root size would otherwise leak
## across unrelated tests.
##
## [b]Naming[/b]: follows the sibling files in this directory
## ([code]state_host_test.gd[/code] etc.), which already use
## [code]test_[scenario]_[expected][/code] rather than
## [code]test_[system]_[scenario]_[expected_result][/code] — a known,
## pre-existing inconsistency between [code].claude/docs/coding-standards.md[/code]
## and [code].claude/rules/test-standards.md[/code] (see
## [code]display_pixel_settings_test.gd[/code]'s header), not something this
## story resolves.
##
## [b]🔴 2026-09-04 correction (Story 001, screen-scaling epic) — read this
## before trusting anything this file's header says about "non-identity" as
## a live fact.[/b] Everything above was written when
## [code]window/stretch/mode = "canvas_items"[/code] engaged an automatic,
## resolution-dependent engine transform on [code]get_tree().root[/code].
## Story 001 changed that setting to [code]"disabled"[/code]: the engine now
## performs [b]zero[/b] scaling of its own, at any resolution, and world-layer
## scaling is handled entirely by this project's own
## [code]WorldViewportContainer[/code]/[WorldLayout] — a mechanism that never
## touches [code]get_tree().root[/code]'s own transform. The consequence:
##
## - The test formerly named
##   [code]test_environment_sanity_root_transform_is_non_identity_when_resized[/code]
##   has been RENAMED and REWRITTEN (not deleted — see its own doc comment) to
##   [method test_environment_reality_check_root_transform_is_identity_under_disabled_stretch_mode]
##   below, asserting the opposite of what its old name described: root's
##   transform is now IDENTITY at every resolution, always, by construction.
## - [b]This removes the control-group role that test used to play for
##   AC-S010-a.[/b] Its original point was: prove the surrounding environment
##   is NOT trivially identity, so that "the cursor layer's transform IS
##   identity" carries information (the layer specifically escaped a scaling
##   mechanism that was demonstrably active). That control group is gone —
##   under [code]"disabled"[/code], [b]any[/b] plain, untouched [CanvasLayer]
##   parented under [code]/root[/code] reports identity trivially, cursor
##   layer or not, with zero isolation effort required. Per this file's own
##   pre-written rule ("If so, EVERY identity assertion in this file is
##   vacuous and must be reported as UNCOVERED, not passing"), the four
##   per-resolution AC-S010-a tests below (`test_ac_s010a_*`) are, as of
##   today's settings, [b]no longer evidence that [CursorStateHost]'s
##   isolation discipline is doing any work[/b] — a CanvasLayer that violated
##   that discipline by accident (but was still untouched by anything else)
##   would pass the exact same assertions.
## - [b]They are NOT being deleted or downgraded[/b], for a reason already on
##   record: ADR-0005 Validation Criteria #20 (see
##   [code]docs/architecture/adr-0005-cursor-device-authority-input-architecture.md[/code],
##   item 20) concluded this validation criterion remains necessary going
##   forward — cite that reasoning, do not re-derive it — for two reasons: ①
##   this screen setting can change again; ② Story 002 (adaptive font scale,
##   [code]production/epics/screen-scaling/story-002-adaptive-font-scale.md[/code])
##   is expected to introduce SOME per-resolution scaling for HUD text, and if
##   that scaling is ever applied at a shared/UI [CanvasLayer] rather than a
##   dedicated one, these exact assertions regain their discriminating power
##   automatically, with zero test-code changes — [b]that is the entire
##   reason to keep them running[/b], not their present-day pass/fail value.
## - The two sensitivity canaries below
##   ([method test_sensitivity_canary_scaled_shared_layer_is_not_identity],
##   [method test_sensitivity_canary_offset_only_layer_is_not_identity])
##   remain fully meaningful and unchanged: they build their OWN synthetic
##   scaled/offset layer rather than relying on the real environment, so they
##   independently prove the identity-comparison TECHNIQUE would still catch
##   the real failure shape the day either of the two risks above
##   materializes — they do not depend on today's settings at all.
extends GdUnitTestSuite


const _RESOLUTIONS: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

var _original_root_size: Vector2i


func before_test() -> void:
	_original_root_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _original_root_size


func _get_host() -> Node:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	assert_object(host).append_failure_message(
		"CursorStateHost autoload not found at /root — is it still "
		+ "registered in project.godot's [autoload] section?"
	).is_not_null()
	return host


func _get_cursor_layer() -> CanvasLayer:
	var host: Node = _get_host()
	var layer: Variant = host.get(&"_cursor_layer")
	assert_bool(layer is CanvasLayer).append_failure_message(
		(
			"CursorStateHost._cursor_layer is not a CanvasLayer instance "
			+ "(got %s) — has the field been renamed or removed?"
		) % [layer]
	).is_true()
	return layer


func _assert_transform_identity(t: Transform2D, context: String) -> void:
	assert_bool(t.is_equal_approx(Transform2D.IDENTITY)).append_failure_message(
		(
			"%s: expected CanvasLayer.get_final_transform() == IDENTITY, "
			+ "got x=%s y=%s origin=%s — AC-S010-a / ADR-0005 Validation "
			+ "Criteria #20 violated. This is not a cosmetic drift: at these "
			+ "magnitudes the self-drawn cursor (Story 011) would render "
			+ "thousands of pixels away from the real mouse position."
		) % [context, t.x, t.y, t.origin]
	).is_true()


# ─── Environment sanity — proves the resize technique actually engages ──────
# ─── content scaling in THIS test runtime, not just the standalone probe ────


# 🔴 2026-09-04 (Story 001, screen-scaling epic) — this test,
# test_environment_reality_check_root_transform_is_identity_under_disabled_stretch_mode,
# used to assert the OPPOSITE of what it asserts now, under its former name
# (see the class doc comment's correction note above for that former name
# and the full reasoning). Kept as a live "reality check"
# rather than deleted: if window/stretch/mode is ever silently reverted away
# from "disabled" (the exact class of regression the ORIGINAL version of this
# test existed to catch, just pointed the other way), this test turns red and
# says so explicitly, instead of the AC-S010-a tests below just quietly
# starting to mean something different than their own comments claim.
func test_environment_reality_check_root_transform_is_identity_under_disabled_stretch_mode() -> void:
	# Arrange
	get_tree().root.size = _RESOLUTIONS["2K"]

	# Act
	var root_transform: Transform2D = get_tree().root.get_final_transform()

	# Assert — IDENTITY at every resolution is the expected, CORRECT behavior
	# under window/stretch/mode = "disabled" (2026-09-01 spike,
	# prototypes/ui-canvas-scale-spike-2026-09-01/README.md Scenario 2: "final_transform
	# scale=(1.0, 1.0) offset=(0.0, 0.0)" at all four target resolutions once
	# content_scale_mode is DISABLED). A non-identity result here would mean
	# either project.godot's stretch mode reverted, or something is applying
	# scaling to the root Window again outside WorldLayout's own mechanism —
	# both worth knowing immediately.
	assert_bool(root_transform.is_equal_approx(Transform2D.IDENTITY)).append_failure_message(
		(
			"root.get_final_transform() is NOT identity at 2K — under "
			+ "window/stretch/mode=\"disabled\" (the current setting) it must "
			+ "always be identity, at every resolution. Either project.godot's "
			+ "stretch mode was reverted away from \"disabled\", or something is "
			+ "applying an engine-level content-scale transform again outside "
			+ "WorldLayout's manual mechanism. Got x=%s y=%s origin=%s."
		) % [root_transform.x, root_transform.y, root_transform.origin]
	).is_true()


# ─── Layer parented under the Autoload vs. directly under /root ─────────────
#
# ⚠️ 2026-09-04: under window/stretch/mode="disabled" both sides of this
# comparison are IDENTITY (see class doc comment's correction note) — the
# comparison is now between two identities rather than two non-trivial
# transforms. Kept because the claim it checks (parenting under the Autoload
# vs. directly under /root produces the SAME get_final_transform() behavior)
# is still a real structural question independent of what that shared value
# happens to be today, and a future scaling mechanism could reintroduce a
# difference between the two paths.


func test_layer_parented_under_host_matches_layer_parented_directly_under_root() -> void:
	# Arrange — this story's real _cursor_layer is parented under
	# CursorStateHost (a plain Node that is itself an Autoload under /root),
	# but the 2026-09-01 spike and this story's own probe both measured a
	# CanvasLayer added DIRECTLY as a child of root. Coordinator's explicit
	# instruction: verify these are equivalent empirically, do not reason
	# your way to that conclusion.
	get_tree().root.size = _RESOLUTIONS["2K"]
	var real_layer: CanvasLayer = _get_cursor_layer()

	var direct_layer := CanvasLayer.new()
	direct_layer.name = "DirectlyUnderRootProbeLayer"
	get_tree().root.add_child(direct_layer)
	auto_free(direct_layer)

	# Act
	var real_transform: Transform2D = real_layer.get_final_transform()
	var direct_transform: Transform2D = direct_layer.get_final_transform()

	# Assert
	assert_bool(real_transform.is_equal_approx(direct_transform)).append_failure_message(
		(
			"CanvasLayer parented under CursorStateHost differs from one "
			+ "parented directly under /root: real=(x=%s y=%s o=%s) vs "
			+ "direct=(x=%s y=%s o=%s). Parenting under the Autoload Node "
			+ "changes get_final_transform() behavior — this contradicts the "
			+ "assumption this story's implementation relied on and is this "
			+ "story's most important finding if it ever fires."
		) % [
			real_transform.x, real_transform.y, real_transform.origin,
			direct_transform.x, direct_transform.y, direct_transform.origin,
		]
	).is_true()


# ─── AC-S010-a: transform identity across four resolutions ──────────────────
#
# 🔴 2026-09-04: as of today's window/stretch/mode="disabled" setting, the
# four tests below no longer distinguish "CursorStateHost's isolation
# discipline is working" from "nothing in this architecture scales /root
# children at all" — both produce the same green result. See the class doc
# comment's correction note for the full reasoning and why they are kept
# running anyway (ADR-0005 Validation Criteria #20, forward-looking
# protection for Story 002 / a future settings reversion) rather than deleted
# or downgraded. Report this honestly as reduced present-day information
# value, not as "fully covering AC-S010-a" — the sensitivity canaries further
# below are what still proves the assertion TECHNIQUE works.


func test_ac_s010a_cursor_layer_transform_is_identity_at_1080p() -> void:
	# Arrange
	get_tree().root.size = _RESOLUTIONS["1080p"]
	var layer: CanvasLayer = _get_cursor_layer()

	# Act
	var t: Transform2D = layer.get_final_transform()

	# Assert
	_assert_transform_identity(t, "1080p (%s)" % [_RESOLUTIONS["1080p"]])


func test_ac_s010a_cursor_layer_transform_is_identity_at_2k() -> void:
	# Arrange
	get_tree().root.size = _RESOLUTIONS["2K"]
	var layer: CanvasLayer = _get_cursor_layer()

	# Act
	var t: Transform2D = layer.get_final_transform()

	# Assert
	_assert_transform_identity(t, "2K (%s)" % [_RESOLUTIONS["2K"]])


func test_ac_s010a_cursor_layer_transform_is_identity_at_4k() -> void:
	# Arrange
	get_tree().root.size = _RESOLUTIONS["4K"]
	var layer: CanvasLayer = _get_cursor_layer()

	# Act
	var t: Transform2D = layer.get_final_transform()

	# Assert
	_assert_transform_identity(t, "4K (%s)" % [_RESOLUTIONS["4K"]])


func test_ac_s010a_cursor_layer_transform_is_identity_at_ultrawide() -> void:
	# Arrange — the story's own AC-S010-a text lists four resolutions
	# (1080p/2K/4K/超寬); ADR-0005 Validation Criteria #20 only names three
	# (1080p/2K/4K). This test covers the fourth the story asks for — more
	# coverage than the ADR strictly requires, not a substitute for it.
	get_tree().root.size = _RESOLUTIONS["ultrawide"]
	var layer: CanvasLayer = _get_cursor_layer()

	# Act
	var t: Transform2D = layer.get_final_transform()

	# Assert
	_assert_transform_identity(t, "ultrawide (%s)" % [_RESOLUTIONS["ultrawide"]])


# ─── Sensitivity/canary — proves the identity assertion is not a false green ─


func test_sensitivity_canary_scaled_shared_layer_is_not_identity() -> void:
	# Arrange — the REAL failure shape (probe Q3): the cursor layer merged
	# into a UI layer that carries content scale. Built as a throwaway node,
	# NOT the real _cursor_layer, specifically to prove the assertion
	# technique used above would actually catch this if it ever happened.
	var fake_shared_layer := CanvasLayer.new()
	fake_shared_layer.name = "CanarySharedScaledLayer"
	fake_shared_layer.scale = Vector2(2.6666667, 2.6666667)
	get_tree().root.add_child(fake_shared_layer)
	auto_free(fake_shared_layer)

	# Act
	var t: Transform2D = fake_shared_layer.get_final_transform()

	# Assert — this MUST be false (not identity). If this assertion is ever
	# green when it should not be, every AC-S010-a assertion above is a false
	# green light too. Numbers modeled on
	# prototypes/story-010-headless-resolution-probe-2026-09-04/logs/probe_output.txt.
	assert_bool(t.is_equal_approx(Transform2D.IDENTITY)).append_failure_message(
		"canary layer with scale=2.667 measured as IDENTITY — the identity "
		+ "assertion technique used by AC-S010-a is NOT sensitive to the real "
		+ "failure shape (a shared, scaled CanvasLayer) and must not be trusted."
	).is_false()


func test_sensitivity_canary_offset_only_layer_is_not_identity() -> void:
	# Arrange — the second failure shape the probe's Q3b found: no scale,
	# only a positional offset. The dispatch's own guidance says the SAME
	# identity comparison covers both shapes without a second assertion
	# technique — this canary exists to prove that claim rather than merely
	# cite it.
	var fake_offset_layer := CanvasLayer.new()
	fake_offset_layer.name = "CanaryOffsetLayer"
	fake_offset_layer.offset = Vector2(80, 45)
	get_tree().root.add_child(fake_offset_layer)
	auto_free(fake_offset_layer)

	# Act
	var t: Transform2D = fake_offset_layer.get_final_transform()

	# Assert
	assert_bool(t.is_equal_approx(Transform2D.IDENTITY)).append_failure_message(
		"canary layer with offset=(80,45) measured as IDENTITY — the identity "
		+ "assertion technique is blind to pure-offset failures, contradicting "
		+ "the probe's Q3b finding."
	).is_false()


# ─── AC-S010-b (narrowed): exclusivity structural preconditions ─────────────


func test_ac_s010b_cursor_layer_is_a_distinct_node_owned_solely_by_the_host() -> void:
	# Arrange / Act
	var host: Node = _get_host()
	var layer: CanvasLayer = _get_cursor_layer()

	# Assert — parented directly under CursorStateHost (not shared with, or
	# reachable through, any other system's node), and named for identity.
	assert_object(layer.get_parent()).is_equal(host)
	assert_str(layer.name).is_equal("CursorLayer")


func test_ac_s010b_cursor_layer_has_no_children_yet_narrowed() -> void:
	# Arrange / Act — 🔴 NARROWED, see class doc comment at top of this file.
	# Story 010 draws nothing; this only proves the baseline that nothing has
	# attached to this node YET. It is NOT evidence that Story 011's content
	# will be the ONLY content ever attached to it — that behavioral claim
	# can only be exercised once real children exist (Story 011+).
	var layer: CanvasLayer = _get_cursor_layer()

	# Assert
	assert_int(layer.get_child_count()).append_failure_message(
		"CursorStateHost._cursor_layer already has children in Story 010, "
		+ "before Story 011 adds the self-drawn cursor / hover-detector "
		+ "nodes. Investigate what attached to it and whether this violates "
		+ "the exclusivity requirement."
	).is_equal(0)


func test_ac_s010b_cursor_layer_draw_order_is_independent_of_host_process_priority() -> void:
	# Arrange / Act — Implementation Notes #3: CanvasLayer.layer (draw order)
	# and Node.process_priority (update order) are independent concepts and
	# ADR-0005 明文 must not share a value.
	var host: Node = _get_host()
	var layer: CanvasLayer = _get_cursor_layer()

	# Assert
	assert_int(layer.layer).is_not_equal(host.process_priority)
