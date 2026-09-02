## Unit tests for the cursor/highlight-state system's shared types (Story 001):
## [code]src/ui/cursor/cursor_types.gd[/code], [code]cursor_target.gd[/code],
## [code]mouse_reclaim_policy.gd[/code]. Covers AC-53 (scope note below) and
## AC-S001-a/b/c from
## [code]production/epics/cursor-highlight-state/story-001-shared-types.md[/code].
##
## All three production files are pure RefCounted value types / a static
## namespace with no node, Input, or file-I/O dependency — every test below
## constructs directly with [code]new()[/code] / static factories, headless,
## no random seed, no time dependency.
##
## AC-53 scope note: the GDD's full text asks to inspect every UI surface
## label currently mounted in the system and confirm each traces back to this
## one shared enum. Stories 002 (CursorState/Host) and 003 (surface registry
## behaviour) are out of scope here and not yet implemented, so there are no
## mounted surfaces to inspect yet. What IS verifiable at this story's stage
## is narrower: that the shared enum is a single declaration with exactly the
## ADR-0005 機制二-defined members, in the ADR's order (order matters because
## the underlying int values feed [method CursorTarget.equals] and any future
## persistence). Full-scope AC-53 coverage has to wait until Story 003 lands
## real mounted surfaces — flagged in this story's final report rather than
## silently assumed covered here.
##
## AC-S001-c scope note: only the "positive shape" half (signal + 4 methods
## all compile and are callable together) is exercised here, via a complete
## inner-class subclass. The "negative" half (a subclass missing one method
## fails to COMPILE, naming the missing method) cannot be reproduced inside
## this project's own test suite without placing a deliberately
## non-compiling .gd file somewhere under this repo — forbidden by this
## story's own instructions, since a non-compiling script anywhere in the
## project would break the whole GdUnit4 run. That half is verified
## separately by the throwaway probe under
## [code]prototypes/story-001-abstract-probe-2026-09-02/[/code].
extends GdUnitTestSuite


## Minimal concrete subclass implementing all four @abstract methods, used
## only to prove the base contract's positive shape is usable end-to-end.
class _CompleteReclaimPolicyStub extends MouseReclaimPolicy:
	var _seed: Vector2 = Vector2.ZERO

	func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
		return false

	func reclaim_progress() -> float:
		return 0.0

	func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void:
		_seed = seed_position
		reset_triggered.emit(trigger)

	func diagnostic_seed_position() -> Vector2:
		return _seed


# ─── AC-53 (narrowed scope — see class doc comment) ─────────────────────────

func test_surface_type_enum_has_exactly_the_four_adr_defined_members_in_order() -> void:
	# Arrange — ADR-0005 機制二 verbatim declaration order. Order matters:
	# the underlying int values are what CursorTarget.equals() and any
	# future persistence actually compare/store.
	var expected_order: Array[String] = [
		"BOARD_TILE", "RELATION_MINIMAP_NODE", "CARD_SLOT", "DIALOGUE_CHOICE",
	]

	# Act
	var actual_keys: Array = CursorTypes.SurfaceType.keys()

	# Assert
	assert_array(actual_keys).is_equal(expected_order)
	for i in range(expected_order.size()):
		assert_int(CursorTypes.SurfaceType[expected_order[i]]).is_equal(i)


# ─── AC-S001-a: CursorTarget.equals() 相等判定 ──────────────────────────────

func test_equals_same_surface_and_id_different_validity_returns_true() -> void:
	# Arrange — one valid, one invalidated-from-it: surface/id identical,
	# is_valid differs (true vs false).
	var valid_target: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 42)
	var invalid_target: CursorTarget = CursorTarget.invalidated(valid_target)

	# Act / Assert — is_valid must NOT participate in the comparison
	assert_bool(valid_target.equals(invalid_target)).is_true()
	assert_bool(invalid_target.equals(valid_target)).is_true()


func test_equals_different_surface_returns_false() -> void:
	# Arrange — same id, different surface
	var a: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 7)
	var b: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.CARD_SLOT, 7)

	# Act / Assert
	assert_bool(a.equals(b)).is_false()


func test_equals_different_id_returns_false() -> void:
	# Arrange — same surface, different id
	var a: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 1)
	var b: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 2)

	# Act / Assert
	assert_bool(a.equals(b)).is_false()


# ─── AC-S001-b: CursorTypes.encode_tile() / decode_tile() 雙射 ─────────────

func test_encode_decode_round_trip_returns_original_coordinate() -> void:
	# Arrange — representative spread across the production board's actual
	# dimensions (13 wide). 13 here is a boundary-value literal (the real
	# board width), not a magic-number stand-in — see
	# .claude/docs/coding-standards.md's boundary-value exception to
	# "no hardcoded data". This file deliberately does not import
	# Board.BOARD_WIDTH / BoardCoords.BOARD_COLS — see cursor_types.gd's doc
	# comment on why encode_tile()/decode_tile() take board_width as a
	# parameter instead of owning a constant.
	var board_width := 13
	var cells: Array[Vector2i] = [
		Vector2i(0, 0),    # origin
		Vector2i(12, 0),   # right edge, top row
		Vector2i(0, 5),    # left edge, bottom row
		Vector2i(6, 3),    # interior
		Vector2i(12, 5),   # far corner
	]

	for cell in cells:
		# Act
		var encoded: int = CursorTypes.encode_tile(cell, board_width)
		var decoded: Vector2i = CursorTypes.decode_tile(encoded, board_width)

		# Assert
		assert_vector(decoded).is_equal(cell)


func test_encode_distinct_cells_produce_distinct_ids() -> void:
	# Arrange — every cell across the production board's actual dimensions
	# (13x6). Same boundary-value rationale as the round-trip test above.
	var board_width := 13
	var board_height := 6
	var seen_ids: Dictionary = {}

	for y in range(board_height):
		for x in range(board_width):
			# Act
			var id: int = CursorTypes.encode_tile(Vector2i(x, y), board_width)

			# Assert — no collision with any previously-encoded cell
			assert_bool(seen_ids.has(id)).is_false()
			seen_ids[id] = true


# ─── AC-S001-c: MouseReclaimPolicy 契約形狀(正面半段,見類別 doc comment)──

func test_complete_subclass_implements_all_four_abstract_methods_and_signal() -> void:
	# Arrange
	var policy: MouseReclaimPolicy = _CompleteReclaimPolicyStub.new()

	# Act
	policy.reset(Vector2(10, 20), CursorTypes.ResetTrigger.AUTHORITY_TRANSFER)

	# Assert — all four abstract methods are callable end-to-end through the
	# base-typed reference, and the signal exists on the base contract
	assert_bool(policy.evaluate(Vector2.ZERO, CursorTypes.SurfaceType.BOARD_TILE)).is_false()
	assert_float(policy.reclaim_progress()).is_equal(0.0)
	assert_vector(policy.diagnostic_seed_position()).is_equal(Vector2(10, 20))
	assert_bool(policy.has_signal("reset_triggered")).is_true()


func test_reset_triggered_signal_emits_with_the_trigger_passed_to_reset() -> void:
	# Arrange — Array[int] capture cell per this project's documented lambda
	# capture-by-value trap (see tests/unit/ui/device_authority_test.gd):
	# a bare int local would make the closure mutate its own copy, leaving
	# the outer variable at its initial value forever — a false-negative
	# that would make this test pass even if the signal never fired.
	var policy: MouseReclaimPolicy = _CompleteReclaimPolicyStub.new()
	var captured: Array[CursorTypes.ResetTrigger] = []
	policy.reset_triggered.connect(
		func(trigger: CursorTypes.ResetTrigger) -> void: captured.append(trigger)
	)

	# Act
	policy.reset(Vector2(1, 2), CursorTypes.ResetTrigger.VETOED_SAME_FRAME)

	# Assert
	assert_array(captured).is_equal([CursorTypes.ResetTrigger.VETOED_SAME_FRAME])
