## Unit tests for [code]src/ui/cursor/cursor_surface_registry.gd[/code] (Story
## 003) — [code]CursorSurfaceRegistry[/code]'s two structurally independent
## tables (ADR-0005 機制三). Covers AC-4 / AC-5 / AC-47 / AC-51 from
## [code]production/epics/cursor-highlight-state/story-003-surface-registry.md[/code],
## plus the registry's own contract (duplicate rejection, sorted iteration,
## table independence, native-pointer-exception lifecycle).
##
## [b]Scope narrowing — read before extending or "fixing" these tests[/b]:
## AC-4, AC-5 and AC-51 are GDD-level acceptance criteria whose full text
## describes behavior that spans [code]CursorState[/code] (Stories 002/007,
## not yet implemented) and, for AC-51, the cross-screen handoff entry points
## on [code]CursorState[/code] (機制十一, Story 009). This story only
## implements the registry. Each narrowed test below documents exactly what
## IS verified at the registry layer and what is deferred — following the
## same pattern Story 001's [code]shared_types_test.gd[/code] already
## established for its own AC-53 scope note.
##
## - [b]AC-4[/b] ("two mounted surfaces share one state source, not
##   independent per-surface highlight logic"): the registry itself holds no
##   highlight state, so the "highlight disappears elsewhere" assertion is
##   [code]CursorState[/code]'s to prove. What IS verified here is the
##   necessary substrate: the registry supports two DISTINCT surface types
##   registered and independently retrievable AT THE SAME TIME, with no
##   coupling between them — the precondition for a single external state
##   source (not the registry) to serve both.
## - [b]AC-5[/b] (narrowed — corrected 2026-09-02, three-way-review
##   remediation; the original wording here overclaimed "fully verifiable"):
##   the GDD text has two clauses, and only one is provable at this layer.
##   [b]Generalization clause[/b] ("a new, previously nonexistent third-party
##   surface — e.g. card selection — plugs into the shared read/write
##   interface [b]without modifying this system's own code[/b]"): fully
##   verifiable at this layer. [constant CursorTypes.SurfaceType.CARD_SLOT] is
##   registered through the exact same generic
##   [method CursorSurfaceRegistry.register] API used for
##   [constant CursorTypes.SurfaceType.BOARD_TILE], with identical contract
##   behavior (duplicate rejection, retrieval, sorted iteration) and no
##   surface-type-specific branch anywhere in the production code.
##   [b]Single-highlight-invariant clause[/b] ("that surface's hover highlight
##   [b]correctly participates in AC-2's single-highlight invariant[/b]"): NOT
##   verifiable here — the registry itself holds no highlight state (see the
##   AC-4 note above), and AC-2 is [code]CursorState[/code]/Story 002's own AC,
##   honestly narrowed in
##   [code]tests/unit/cursor/state_host_test.gd[/code] as only partially
##   verified pending Story 007 (real mounted surfaces) / Story 010 (real
##   rendered highlight). An AC that names another AC as its own success
##   condition cannot be "fully verified" while the named AC is not. Deferred
##   to the same Story 007/010 boundary as AC-2 itself.
## - [b]AC-47[/b] ("at most 1 mounted instance per surface tag at any point in
##   time"): fully verifiable at this layer — this IS
##   [constant CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED].
## - [b]AC-51[/b] ("before a surface unloads, the current target has been
##   handed off — no state where the target's surface tag has zero mounted
##   instances"): the actual handoff CALL
##   ([code]CursorState.handoff_before_unload[/code] /
##   [code]mark_pending_reresolve[/code] / [code]set_target[/code]) lives on
##   [code]CursorState[/code], not this registry, and is Story 009's scope
##   (機制十一) — not tested here, and not faked with a placeholder downstream
##   surface (explicitly forbidden by this story's instructions, since zero
##   downstream surfaces exist yet to test against honestly). What IS verified
##   here is the registry-side precondition AC-51's invariant depends on:
##   immediately after [method CursorSurfaceRegistry.unregister] completes,
##   [method CursorSurfaceRegistry.get_surface] reliably returns
##   [code]null[/code] and [method CursorSurfaceRegistry.registered_surfaces_sorted]
##   no longer lists that tag — i.e. the registry never reports "zero mounted
##   instances" and "still registered" at the same time. Full AC-51
##   verification (the handoff call itself, and a real downstream surface's
##   unload path) is Story 009's responsibility.
##
## All production code under test is pure [RefCounted] with no [Input] or
## file-I/O dependency — no random seed, no time-dependent assertion. Tests
## that exercise [signal Node.tree_exited] use [method GdUnitTestSuite.auto_free]
## + [method Node.add_child]/[method Node.remove_child] (the established
## pattern in [code]tests/unit/ui/battle_screen_scene_test.gd[/code]) so no
## node is orphaned at suite teardown.
extends GdUnitTestSuite


# ─── Table 1: registered surfaces — core contract ───────────────────────────

func test_register_new_tag_returns_registered() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var node: Node = auto_free(Node.new())

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, node
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_equal(node)


func test_register_null_node_returns_invalid_node() -> void:
	# Arrange — 2026-09-02 three-way-review remediation: before this fix,
	# register() had no validity check at all and a null node was silently
	# accepted and reported as REGISTERED (see production doc comment).
	var registry := CursorSurfaceRegistry.new()

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, null
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.INVALID_NODE)


func test_register_null_node_does_not_occupy_the_tag() -> void:
	# Arrange — the specific failure mode this fix closes: a rejected null
	# registration must NOT permanently squat the tag. A real registration
	# under the same tag afterward must still succeed.
	var registry := CursorSurfaceRegistry.new()
	var node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, null)

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, node
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_equal(node)


func test_get_surface_unregistered_tag_returns_null() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()

	# Act / Assert — never registered at all, not merely unregistered-again
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_null()


func test_unregister_never_registered_tag_returns_unregistered_not_found() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.unregister(
		CursorTypes.SurfaceType.BOARD_TILE
	)

	# Assert — fail-loud, not a silent no-op
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.UNREGISTERED_NOT_FOUND)


func test_unregister_twice_second_call_returns_unregistered_not_found() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, node)
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)

	# Act
	var second_result: CursorSurfaceRegistry.RegisterResult = registry.unregister(
		CursorTypes.SurfaceType.BOARD_TILE
	)

	# Assert
	assert_int(second_result).is_equal(CursorSurfaceRegistry.RegisterResult.UNREGISTERED_NOT_FOUND)


func test_register_after_unregister_same_tag_succeeds() -> void:
	# Arrange — demonstrates the "at most 1 AT ANY POINT IN TIME" contract
	# (AC-47), not "at most 1 ever": a tag must be re-registerable once freed.
	var registry := CursorSurfaceRegistry.new()
	var first_node: Node = auto_free(Node.new())
	var second_node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, first_node)
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, second_node
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_equal(second_node)


func test_registered_surfaces_sorted_orders_by_enum_value_not_insertion_order() -> void:
	# Arrange — register out of the enum's declared order (CARD_SLOT = 2
	# first, then BOARD_TILE = 0) to prove the result is NOT insertion order.
	var registry := CursorSurfaceRegistry.new()
	registry.register(CursorTypes.SurfaceType.CARD_SLOT, auto_free(Node.new()))
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, auto_free(Node.new()))

	# Act
	var sorted_tags: Array[CursorTypes.SurfaceType] = registry.registered_surfaces_sorted()

	# Assert
	assert_array(sorted_tags).is_equal([
		CursorTypes.SurfaceType.BOARD_TILE, CursorTypes.SurfaceType.CARD_SLOT,
	])


func test_registered_surfaces_sorted_empty_registry_returns_empty_array() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()

	# Act / Assert
	assert_array(registry.registered_surfaces_sorted()).is_empty()


# ─── AC-47: at most 1 mounted instance per tag at any point in time ─────────

func test_ac47_duplicate_tag_registration_is_rejected_and_does_not_overwrite() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var first_node: Node = auto_free(Node.new())
	var second_node: Node = auto_free(Node.new())
	var first_result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, first_node
	)

	# Act — second registration under the SAME tag while the first is still mounted
	var second_result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, second_node
	)

	# Assert — rejected, AND the original registration is untouched (not overwritten)
	assert_int(first_result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_int(second_result).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_equal(first_node)


# ─── AC-4 (narrowed — see class doc comment): multi-surface substrate ───────

func test_ac4_two_distinct_surface_types_register_and_retrieve_independently() -> void:
	# Arrange — two independent UI surfaces "mounted at the same time"
	# (board tile grid + relation minimap), the AC-4 GIVEN precondition.
	var registry := CursorSurfaceRegistry.new()
	var board_node: Node = auto_free(Node.new())
	var minimap_node: Node = auto_free(Node.new())

	# Act
	var board_result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, board_node
	)
	var minimap_result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.RELATION_MINIMAP_NODE, minimap_node
	)

	# Assert — both succeed, each independently retrievable, no cross-talk.
	# (The behavioral half of AC-4 — that a valid input on one surface clears
	# the other's highlight — depends on CursorState and is out of this
	# story's scope; see class doc comment.)
	assert_int(board_result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_int(minimap_result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_equal(board_node)
	assert_object(
		registry.get_surface(CursorTypes.SurfaceType.RELATION_MINIMAP_NODE)
	).is_equal(minimap_node)


func test_ac4_unregistering_one_surface_does_not_affect_the_other() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var board_node: Node = auto_free(Node.new())
	var minimap_node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, board_node)
	registry.register(CursorTypes.SurfaceType.RELATION_MINIMAP_NODE, minimap_node)

	# Act
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)

	# Assert
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_null()
	assert_object(
		registry.get_surface(CursorTypes.SurfaceType.RELATION_MINIMAP_NODE)
	).is_equal(minimap_node)


# ─── AC-5 (fully verifiable at this layer): generalization, not board-tied ──

func test_ac5_new_surface_type_registers_through_the_same_generic_api_as_board_tile() -> void:
	# Arrange — CARD_SLOT stands in for the AC's own example ("a new,
	# previously nonexistent third-party UI surface — e.g. card selection").
	# No production code anywhere branches on which SurfaceType this is.
	var registry := CursorSurfaceRegistry.new()
	var card_node: Node = auto_free(Node.new())

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.CARD_SLOT, card_node
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_object(registry.get_surface(CursorTypes.SurfaceType.CARD_SLOT)).is_equal(card_node)


func test_ac5_new_surface_type_obeys_the_same_duplicate_rejection_contract() -> void:
	# Arrange — same DUPLICATE_TAG_REJECTED contract already proven for
	# BOARD_TILE (test_ac47_*) must hold identically for a newly-added
	# surface type, with zero core-code changes required to support it.
	var registry := CursorSurfaceRegistry.new()
	registry.register(CursorTypes.SurfaceType.CARD_SLOT, auto_free(Node.new()))

	# Act
	var second_result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.CARD_SLOT, auto_free(Node.new())
	)

	# Assert
	assert_int(second_result).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)


# ─── AC-51 (narrowed — see class doc comment): registry-side precondition ───

func test_ac51_after_unregister_get_surface_returns_null() -> void:
	# Arrange — a surface holding what would be the current cursor target's
	# surface type, about to unmount.
	var registry := CursorSurfaceRegistry.new()
	var node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, node)

	# Act
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)

	# Assert — no window where the tag is still reported as mounted
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_null()


func test_ac51_after_unregister_tag_is_absent_from_sorted_iteration() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, node)

	# Act
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)

	# Assert — registered_surfaces_sorted() is the only sanctioned iteration
	# path (see production doc comment); it must not still list the tag.
	assert_array(registry.registered_surfaces_sorted()).is_empty()


# ─── Table 2: AC-60 native-pointer exception whitelist ──────────────────────

func test_register_native_pointer_exception_new_node_returns_registered() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())

	# Act
	var result: CursorSurfaceRegistry.ExceptionRegisterResult = (
		registry.register_native_pointer_exception(control)
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.ExceptionRegisterResult.REGISTERED)
	assert_bool(registry.is_native_pointer_exception(control)).is_true()


func test_register_native_pointer_exception_same_node_twice_returns_already_excepted() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	registry.register_native_pointer_exception(control)

	# Act
	var second_result: CursorSurfaceRegistry.ExceptionRegisterResult = (
		registry.register_native_pointer_exception(control)
	)

	# Assert
	assert_int(second_result).is_equal(CursorSurfaceRegistry.ExceptionRegisterResult.ALREADY_EXCEPTED)


func test_register_native_pointer_exception_null_node_returns_invalid_node() -> void:
	# Arrange / Act / Assert — see production code's is_instance_valid()-first
	# doc comment: null is the only INVALID_NODE case reachable through this
	# statically Control-typed signature. An ALREADY-FREED-but-non-null
	# reference cannot reach this method's body at all — engine-verified
	# 2026-09-02 during this story's own test run: GDScript's typed-parameter
	# boundary check rejects a previously-freed Object argument with
	# "Invalid type in function ... (previously freed) is not a subclass of
	# the expected argument class" BEFORE the callee's body executes,
	# aborting the caller — the same "operation on a freed object aborts the
	# calling function" family already documented by
	# prototypes/engine-verification-spike-2026-08-20/ C2/F-10, but occurring
	# one level higher (at the call boundary, not inside this function). This
	# means the is_instance_valid() guard's practical effect for a
	# concretely-typed Object parameter is limited to catching [code]null[/code];
	# see this story's final report for the full finding.
	var registry := CursorSurfaceRegistry.new()

	# Act
	var result: CursorSurfaceRegistry.ExceptionRegisterResult = (
		registry.register_native_pointer_exception(null)
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.ExceptionRegisterResult.INVALID_NODE)


func test_unregister_native_pointer_exception_not_registered_returns_not_registered() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())

	# Act
	var result: CursorSurfaceRegistry.ExceptionRegisterResult = (
		registry.unregister_native_pointer_exception(control)
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.ExceptionRegisterResult.NOT_REGISTERED)


func test_unregister_native_pointer_exception_registered_node_succeeds_and_clears_membership() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	registry.register_native_pointer_exception(control)

	# Act
	var result: CursorSurfaceRegistry.ExceptionRegisterResult = (
		registry.unregister_native_pointer_exception(control)
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.ExceptionRegisterResult.REGISTERED)
	assert_bool(registry.is_native_pointer_exception(control)).is_false()


func test_is_native_pointer_exception_unrelated_node_returns_false() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var registered_control: Control = auto_free(Control.new())
	var unrelated_control: Control = auto_free(Control.new())
	registry.register_native_pointer_exception(registered_control)

	# Act / Assert
	assert_bool(registry.is_native_pointer_exception(unrelated_control)).is_false()


func test_is_native_pointer_exception_checks_ancestor_chain_for_descendant_node() -> void:
	# Arrange — Viewport.gui_get_hovered_control() (機制十三之二's caller) may
	# return a DESCENDANT of the registered exception surface's root, not the
	# root itself; membership must be checked by walking up the ancestor chain.
	var registry := CursorSurfaceRegistry.new()
	var root_control: Control = auto_free(Control.new())
	var child_control: Control = Control.new()
	root_control.add_child(child_control)
	registry.register_native_pointer_exception(root_control)

	# Act / Assert
	assert_bool(registry.is_native_pointer_exception(child_control)).is_true()


func test_native_pointer_exception_auto_deregisters_on_tree_exited() -> void:
	# Arrange — 2026-08-21 R6-13: table 2 auto-deregisters via tree_exited so
	# callers with a "come and go freely" surface never need explicit
	# unregister discipline. remove_child() fires tree_exited synchronously
	# (unlike queue_free()'s deferred free), keeping this test deterministic
	# with no awaited frame.
	var registry := CursorSurfaceRegistry.new()
	var parent: Node = auto_free(Node.new())
	add_child(parent)
	var exception_control: Control = Control.new()
	parent.add_child(exception_control)
	registry.register_native_pointer_exception(exception_control)
	assert_bool(registry.is_native_pointer_exception(exception_control)).is_true()

	# Act
	parent.remove_child(exception_control)

	# Assert
	assert_bool(registry.is_native_pointer_exception(exception_control)).is_false()
	exception_control.free()


# ─── Table independence (Implementation Notes #2 — must not be merged) ──────

func test_table_1_registration_does_not_make_node_a_native_pointer_exception() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, node)

	# Act / Assert — table 1 membership must not leak into table 2's query
	assert_bool(registry.is_native_pointer_exception(node)).is_false()


func test_table_2_registration_does_not_make_node_retrievable_from_table_1() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	registry.register_native_pointer_exception(control)

	# Act / Assert — table 2 has no tags at all, so no CursorSurfaceRegistry
	# tag lookup can ever surface it; spot-check against every declared tag.
	for tag: CursorTypes.SurfaceType in CursorTypes.SurfaceType.values():
		assert_object(registry.get_surface(tag)).is_null()


# ─── Story 012: ADR-0005 機制十四 guard (register() entry-point rejection) ───
#
# Governing contract: docs/reviews/cursor-surface-register-guard-contract-2026-10-15.md
# ("甲案" — reject at register()'s entry point; does NOT store the node, and
# register() itself push_error()s the detail, per that contract's 第二節).
#
# Engine evidence this whole block depends on — NOT reimplemented here, read
# directly from the real engine 2026-10-15:
#   prototypes/godot-gdscript-specialist-cursor-guard-probe-2026-10-15/run_output.txt
# Key facts from that probe:
#   - Control.new().focus_mode defaults to FOCUS_NONE (0); Button.new()
#     defaults to FOCUS_ALL (2).
#   - A plain Control with no theme has no "hover"/"focus" StyleBox at all.
#   - Button's BUILT-IN theme has "hover", "focus" AND "normal" StyleBoxes
#     that are three DIFFERENT instances (reference-unequal) even on a node
#     that was never added to the tree.
#   - Control.get_theme_stylebox() returns the EXACT instance previously
#     passed to add_theme_stylebox_override() (reference-equal).


## T4 is the one test in this Phase-1 block that actually proves condition 2
## ("no built-in hover theme") was implemented, not merely condition 1
## ("focus_mode == FOCUS_NONE"). Contract 第六節's own reasoning: a
## default-constructed [Button] already fails condition 1 (focus_mode
## defaults to FOCUS_ALL — see probe above), so test_bare_button_is_rejected
## below would pass identically whether or not condition 2 exists at all.
## This test explicitly clears condition 1 first, so the ONLY thing left that
## can explain a rejection is condition 2. Same shape of risk this project
## already registered once (Story 007 AC-32: "the assertion's observed
## result has a second possible cause").
func test_button_with_focus_none_is_still_rejected() -> void:
	# Arrange — explicitly compliant with condition 1; Button's untouched
	# built-in theme still violates condition 2 (hover/focus StyleBox differ
	# from normal by reference — see probe evidence above).
	var registry := CursorSurfaceRegistry.new()
	var button: Button = auto_free(Button.new())
	button.focus_mode = Control.FOCUS_NONE

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, button
	)

	# Assert
	assert_int(result).is_not_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.NATIVE_HOVER_THEME_REJECTED)


func test_control_with_focus_all_is_rejected() -> void:
	# Arrange — a plain Control, otherwise compliant (no built-in theme), but
	# with focus_mode explicitly set away from FOCUS_NONE.
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	control.focus_mode = Control.FOCUS_ALL

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, control
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.FOCUS_MODE_NOT_NONE_REJECTED)


func test_rejected_control_is_not_stored() -> void:
	# Arrange — same violating input as test_control_with_focus_all_is_rejected.
	# This is the test that proves the contract's "拒絕註冊" decision (甲-1 —
	# reject outright) rather than "甲-2" (register anyway and merely log):
	# a violation must not occupy the tag at all.
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	control.focus_mode = Control.FOCUS_ALL

	# Act
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, control)

	# Assert
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_null()


func test_bare_button_is_rejected() -> void:
	# Arrange — a Button with no properties touched at all. Per the probe
	# evidence above, Button.new().focus_mode defaults to FOCUS_ALL (2), so
	# THIS specific input is rejected on condition 1 — both conditions are
	# actually violated here (the untouched Button also fails condition 2),
	# and the contract's tie-break ("violating both returns the lower
	# ordinal, FOCUS_MODE_NOT_NONE_REJECTED") is asserted explicitly.
	# test_button_with_focus_none_is_still_rejected above is the test that
	# isolates condition 2 alone.
	var registry := CursorSurfaceRegistry.new()
	var button: Button = auto_free(Button.new())

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, button
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.FOCUS_MODE_NOT_NONE_REJECTED)


func test_compliant_control_is_registered() -> void:
	# Arrange — a plain Control (no built-in theme, so no hover/focus
	# StyleBox at all — probe-verified) with focus_mode explicitly cleared.
	# ⚠️ TAUTOLOGY TODAY (contract 第六節 names this explicitly, same caveat as
	# this project's 2026-09-23 Check-4 "N/A ≠ PASS" precedent): register()
	# already returned REGISTERED for every valid node BEFORE this guard
	# existed, so this test is green whether or not the guard runs at all. It
	# has zero regression value on its own — kept as the compliant-input
	# companion to the rejection tests above, and as a precondition sanity
	# check for the guard-verdict tests further down.
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	control.focus_mode = Control.FOCUS_NONE

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, control
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)


func test_non_control_is_registered() -> void:
	# Arrange — Node2D, structurally exempt from 機制十四 (not a Control).
	# ⚠️ TAUTOLOGY TODAY — same caveat as test_compliant_control_is_registered
	# above. This is also the shape of the ONLY real production surface
	# registered today (BattleScreen extends Node — contract 第五節): the
	# guard's Control-only branch has never actually executed against a real
	# mounted surface as of this story.
	var registry := CursorSurfaceRegistry.new()
	var node: Node2D = auto_free(Node2D.new())

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, node
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)


# ─── Story 012, beyond Phase 1: escape hatch, diagnostic verdict, regression ─
#
# Contract 第六節 called these "Phase 2" only because referencing
# FOCUS_MODE_NOT_NONE_REJECTED / NATIVE_HOVER_THEME_REJECTED /
# diagnostic_last_guard_verdict() before they existed in production code is a
# PARSE ERROR (GdUnit4 exit 105 — test discovery aborts, not "tests fail").
# Writing them only after the guard was implemented (this same change) avoids
# that trap; they are included now rather than deferred further.

func test_button_with_focus_none_and_cleared_hover_theme_is_registered() -> void:
	# Arrange — the ADR's explicit escape hatch: override the built-in
	# hover/focus StyleBox with the SAME instance used for normal, so they
	# compare reference-equal (probe-verified: get_theme_stylebox() returns
	# the exact instance passed to add_theme_stylebox_override()). Both
	# "hover" and "focus" must be cleared — probe evidence shows Button's
	# built-in theme provides distinct instances for all three keys.
	var registry := CursorSurfaceRegistry.new()
	var button: Button = auto_free(Button.new())
	button.focus_mode = Control.FOCUS_NONE
	var normal_stylebox: StyleBox = button.get_theme_stylebox(&"normal")
	button.add_theme_stylebox_override(&"hover", normal_stylebox)
	button.add_theme_stylebox_override(&"focus", normal_stylebox)

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, button
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)


func test_non_control_registration_records_not_applicable_guard_verdict() -> void:
	# Arrange — see diagnostic_last_guard_verdict()'s doc comment: a
	# non-Control registration must record NOT_APPLICABLE, never PASSED —
	# the guard's two conditions never actually ran against it.
	var registry := CursorSurfaceRegistry.new()
	var node: Node2D = auto_free(Node2D.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, node)

	# Act / Assert
	assert_int(
		registry.diagnostic_last_guard_verdict(CursorTypes.SurfaceType.BOARD_TILE)
	).is_equal(CursorSurfaceRegistry.GuardVerdict.NOT_APPLICABLE)


func test_compliant_control_registration_records_passed_guard_verdict() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	control.focus_mode = Control.FOCUS_NONE
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, control)

	# Act / Assert
	assert_int(
		registry.diagnostic_last_guard_verdict(CursorTypes.SurfaceType.BOARD_TILE)
	).is_equal(CursorSurfaceRegistry.GuardVerdict.PASSED)


func test_rejected_control_registration_records_rejected_guard_verdict() -> void:
	# Arrange
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	control.focus_mode = Control.FOCUS_ALL
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, control)

	# Act / Assert
	assert_int(
		registry.diagnostic_last_guard_verdict(CursorTypes.SurfaceType.BOARD_TILE)
	).is_equal(CursorSurfaceRegistry.GuardVerdict.REJECTED)


func test_never_registered_tag_guard_verdict_is_never_attempted() -> void:
	# Arrange — no register() call under this tag at all, on a fresh registry.
	var registry := CursorSurfaceRegistry.new()

	# Act / Assert
	assert_int(
		registry.diagnostic_last_guard_verdict(CursorTypes.SurfaceType.BOARD_TILE)
	).is_equal(CursorSurfaceRegistry.GuardVerdict.NEVER_ATTEMPTED)


func test_guard_verdict_is_retained_after_unregister() -> void:
	# Arrange — diagnostic_last_guard_verdict()'s documented contract: it
	# records "the verdict of the LAST register() call", a historical fact,
	# and is deliberately NOT cleared by unregister() (unlike _surfaces /
	# get_surface(), which DO reflect current mount state).
	var registry := CursorSurfaceRegistry.new()
	var control: Control = auto_free(Control.new())
	control.focus_mode = Control.FOCUS_NONE
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, control)

	# Act
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)

	# Assert — surface itself is gone, but the guard verdict record persists
	assert_object(registry.get_surface(CursorTypes.SurfaceType.BOARD_TILE)).is_null()
	assert_int(
		registry.diagnostic_last_guard_verdict(CursorTypes.SurfaceType.BOARD_TILE)
	).is_equal(CursorSurfaceRegistry.GuardVerdict.PASSED)


func test_violating_control_with_already_occupied_tag_still_returns_duplicate_tag_rejected() -> void:
	# Arrange — contract 第二節's hard placement constraint: the guard runs
	# AFTER the duplicate-tag check, so it must NEVER override an existing
	# DUPLICATE_TAG_REJECTED verdict with a different rejection code. This is
	# the test the contract names as its own acceptance criterion ("既有測試
	# 應一條都不變色" — this specific scenario, a violating node on an
	# occupied tag, previously returned DUPLICATE_TAG_REJECTED and must still
	# do so after the guard was added).
	var registry := CursorSurfaceRegistry.new()
	var first_node: Node = auto_free(Node.new())
	registry.register(CursorTypes.SurfaceType.BOARD_TILE, first_node)
	var violating_control: Control = auto_free(Control.new())
	violating_control.focus_mode = Control.FOCUS_ALL

	# Act
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, violating_control
	)

	# Assert
	assert_int(result).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)
