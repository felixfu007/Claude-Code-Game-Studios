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
## - [b]AC-5[/b] ("a new, previously nonexistent third-party surface — e.g.
##   card selection — plugs into the shared read/write interface without
##   modifying this system's own code"): fully verifiable at this layer.
##   [constant CursorTypes.SurfaceType.CARD_SLOT] is registered through the
##   exact same generic [method CursorSurfaceRegistry.register] API used for
##   [constant CursorTypes.SurfaceType.BOARD_TILE], with identical contract
##   behavior (duplicate rejection, retrieval, sorted iteration) and no
##   surface-type-specific branch anywhere in the production code.
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
