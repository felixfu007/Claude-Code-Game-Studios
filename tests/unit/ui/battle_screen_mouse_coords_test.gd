# Regression test for the mouse-coordinate conversion battle_screen.gd
# switched to on 2026-09-04 (Story 001, screen-scaling epic).
#
# Background: until this story, window/stretch/mode was "canvas_items" and
# the engine transformed InputEvent positions into 480x270 base-canvas space
# BEFORE delivering them to _input() — so this screen computed a clicked cell
# with plain subtraction (event.position - WorldViewportContainer
# .global_position), never BoardCoords.window_to_grid(). Switching to
# "disabled" removes that automatic transform: InputEvent positions now
# arrive as raw OS window-physical pixels, and the plain-subtraction formula
# silently produces a cell off by roughly a factor of WorldLayout
# .compute_scale(window_size) at any resolution above 1x. This is exactly the
# kind of failure the project's own coding standards call out as "wrong
# without erroring" — see WorldLayout's and BoardCoords' updated doc
# comments.
#
# This test exercises battle_screen.gd's actual private helper
# (_window_pos_to_cell), not a re-implementation of the conversion math —
# GDScript's underscore-prefix convention is not an access-control
# mechanism, so calling it directly from a test is a normal, supported way
# to unit-test screen-scoped conversion logic without waiting for a real
# InputEvent (headless Godot delivers none — see
# .claude/docs/coding-standards.md).
#
# Isolation: resizes get_tree().root.size (the technique
# prototypes/story-010-headless-resolution-probe-2026-09-04/ established as
# the only one that actually engages content scaling under GdUnit4's
# headless runtime — DisplayServer.window_set_size() is a silent no-op
# there) and restores it in after_test(), matching
# tests/unit/cursor/cursor_layer_transform_test.gd's convention for the same
# reason: this project's other suites share one engine process.
#
# 命名慣例依 tests/unit/ui/board_coords_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _original_root_size: Vector2i


func before_test() -> void:
	_original_root_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _original_root_size


func _spawn_battle_screen() -> Node:
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func test_window_pos_to_cell_at_minimum_window_size_960x540_resolves_the_correct_cell() -> void:
	# Arrange — 🔴 this used to test 1x (480x270) directly, which turned out to
	# be UNREACHABLE and gave a genuinely wrong answer, not just a test bug:
	# world_viewport_scaler.gd's _ready() sets Window.min_size = (960, 540),
	# and setting min_size ABOVE a window's CURRENT size clamps that size up
	# IMMEDIATELY, not merely on the next resize (confirmed live — a 480x270
	# root.size became 960x540 the instant min_size was assigned, in a
	# standalone reproduction at
	# prototypes/story-001-manual-scaling-verification-2026-09-04/verify_minsize_clamp.gd).
	# So the moment this test's BattleScreen instance entered the tree, root
	# silently grew to 960x540 out from under the test's own "get_tree().root.size
	# = Vector2i(480, 270)" line above — the resulting scale was 2, not 1, and
	# the un-adjusted assertion below failed by exactly the amount that
	# discrepancy predicts. This is not a bug in _window_pos_to_cell(): 1x is
	# now a real, permanently unreachable resolution by design (the whole
	# point of the manager's min_size ruling), so a test asserting behavior
	# AT 1x was asserting behavior for a state the shipped game can never
	# enter. 960x540 (scale=2, zero margin) is the actual reachable minimum,
	# and is what this test now exercises instead.
	get_tree().root.size = Vector2i(960, 540)
	var instance: Node = _spawn_battle_screen()
	var target_cell: Vector2i = Vector2i(3, 2)
	var local_center: Vector2 = BoardCoords.grid_to_local_center(target_cell)
	var window_pos: Vector2 = WorldLayout.canvas_to_window_transform(Vector2i(960, 540)) * local_center

	# Act
	var cell: Vector2i = instance._window_pos_to_cell(window_pos)

	# Assert
	assert_vector(cell).append_failure_message(
		"at the minimum window size 960x540 (scale=2), clicking the screen-space "
		+ "center of cell %s (window pos %s) resolved to %s instead" % [
			target_cell, window_pos, cell
		]
	).is_equal(target_cell)


func test_window_pos_to_cell_at_5x_2k_resolves_the_correct_cell() -> void:
	# Arrange — this is the exact case the pre-fix formula got wrong: at 2K
	# (scale=5, centering offset (80,45)), plain "event.position -
	# global_position" without dividing by scale would land roughly 5x too
	# far from the board origin, almost always resolving to an out-of-bounds
	# cell for any on-board click.
	get_tree().root.size = Vector2i(2560, 1440)
	var instance: Node = _spawn_battle_screen()
	var target_cell: Vector2i = Vector2i(6, 3)
	var local_center: Vector2 = BoardCoords.grid_to_local_center(target_cell)
	var window_pos: Vector2 = WorldLayout.canvas_to_window_transform(Vector2i(2560, 1440)) * local_center

	# Act
	var cell: Vector2i = instance._window_pos_to_cell(window_pos)

	# Assert
	assert_vector(cell).append_failure_message(
		(
			"at 2K (scale=5, offset=(80,45)), clicking the screen-space center of "
			+ "cell %s (window pos %s) resolved to %s instead — the pre-2026-09-04 "
			+ "formula (plain subtraction, no scale division) would have failed "
			+ "this exact case"
		) % [target_cell, window_pos, cell]
	).is_equal(target_cell)


func test_window_pos_to_cell_at_4k_resolves_the_correct_cell() -> void:
	# Arrange — 4K is a zero-margin case (scale=8, offset=(0,0)) — covers the
	# other branch (no centering offset to get wrong, only the scale division).
	get_tree().root.size = Vector2i(3840, 2160)
	var instance: Node = _spawn_battle_screen()
	var target_cell: Vector2i = Vector2i(0, 5)
	var local_center: Vector2 = BoardCoords.grid_to_local_center(target_cell)
	var window_pos: Vector2 = WorldLayout.canvas_to_window_transform(Vector2i(3840, 2160)) * local_center

	# Act
	var cell: Vector2i = instance._window_pos_to_cell(window_pos)

	# Assert
	assert_vector(cell).is_equal(target_cell)


func test_window_pos_to_cell_in_2k_margin_is_out_of_bounds() -> void:
	# Arrange — a raw window position inside 2K's letterbox margin (left of
	# the centered world rect) should resolve to a cell outside the board,
	# same as the pre-existing letterbox behavior BoardCoords.window_to_grid
	# already covers in board_coords_test.gd — this just confirms the screen
	# wiring preserves that, not just the pure function.
	get_tree().root.size = Vector2i(2560, 1440)
	var instance: Node = _spawn_battle_screen()
	var margin_window_pos: Vector2 = Vector2(10.0, 720.0)  # x=10 < margin left edge (80)

	# Act
	var cell: Vector2i = instance._window_pos_to_cell(margin_window_pos)

	# Assert
	assert_bool(BoardCoords.is_in_bounds(cell)).append_failure_message(
		"window pos %s (inside 2K's left margin) resolved to in-bounds cell %s" % [
			margin_window_pos, cell
		]
	).is_false()
