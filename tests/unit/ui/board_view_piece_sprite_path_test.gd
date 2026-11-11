# Story 037 -- piece sprite path resolution + draw order.
#
# AC-2 handling: "final art exists" is simulated by an INJECTED exists predicate
# (no file is written to assets/). AC-1 uses the real ResourceLoader.exists, which
# is false for the not-yet-delivered final art; if the final art is later added,
# test_missing_final_art_falls_back_to_placeholder_real_check must be re-pointed.
# This file reads no data files and writes nothing.
extends GdUnitTestSuite

const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"
const _FINAL_JIA: String = "res://assets/art/characters/pieces/char_jia_piece_idle_01.png"


func _always_exists(_path: String) -> bool:
	return true


func _never_exists(_path: String) -> bool:
	return false


func test_missing_final_art_falls_back_to_placeholder_for_all_five() -> void:
	for i: int in range(5):
		var path: String = BoardView.resolve_piece_sprite_path("PLAYER", i, _never_exists)
		assert_str(path).is_equal(BoardView.ALLY_SPRITE_PATHS[i])


func test_missing_final_art_falls_back_to_placeholder_real_check() -> void:
	# Real ResourceLoader.exists; valid only while final art is not delivered.
	var path: String = BoardView.resolve_piece_sprite_path("PLAYER", 0)
	if ResourceLoader.exists(_FINAL_JIA):
		assert_str(path).is_equal(_FINAL_JIA)
	else:
		assert_str(path).is_equal(BoardView.ALLY_SPRITE_PATHS[0])


func test_existing_final_art_is_preferred() -> void:
	var codes: Array[String] = ["jia", "yi", "bing", "ding", "wu"]
	for i: int in range(5):
		var path: String = BoardView.resolve_piece_sprite_path("PLAYER", i, _always_exists)
		assert_str(path).is_equal(
			"res://assets/art/characters/pieces/char_%s_piece_idle_01.png" % codes[i]
		)


func test_out_of_range_index_is_clamped() -> void:
	assert_str(BoardView.resolve_piece_sprite_path("PLAYER", 99, _never_exists)).is_equal(
		BoardView.ALLY_SPRITE_PATHS[4]
	)
	assert_str(BoardView.resolve_piece_sprite_path("PLAYER", -3, _never_exists)).is_equal(
		BoardView.ALLY_SPRITE_PATHS[0]
	)
	assert_str(BoardView.resolve_piece_sprite_path("PLAYER", 99, _always_exists)).contains(
		"char_wu_piece_idle_01.png"
	)


func test_enemy_keeps_placeholder_even_if_final_exists() -> void:
	assert_str(BoardView.resolve_piece_sprite_path("ENEMY", 0, _always_exists)).is_equal(
		BoardView.ENEMY_SPRITE_PATH
	)


func test_draw_order_is_cell_y_ascending_and_stable() -> void:
	var pieces: Array[Dictionary] = [
		{"cell": Vector2i(0, 3)},
		{"cell": Vector2i(2, 1)},
		{"cell": Vector2i(5, 1)},
		{"cell": Vector2i(1, 2)},
	]
	var order: Array[int] = BoardView.piece_draw_order(pieces)
	assert_array(order).is_equal([1, 2, 3, 0])


func test_render_pieces_adds_lower_row_sprite_after_upper_row() -> void:
	var view: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	add_child(view)
	# Array order deliberately puts the LOWER piece (y=4) first.
	var pieces: Array[Dictionary] = [
		{"cell": Vector2i(1, 4), "faction": "PLAYER", "sprite_index": 0},
		{"cell": Vector2i(1, 3), "faction": "ENEMY", "sprite_index": 0},
	]
	view.render_pieces(pieces)
	var layer: Node2D = view.get_node("PiecesLayer")
	assert_int(layer.get_child_count()).is_equal(2)
	var first: Sprite2D = layer.get_child(0)
	var second: Sprite2D = layer.get_child(1)
	assert_bool(first.position.y < second.position.y).is_true()
	assert_object(first.texture).is_not_null()
	assert_object(second.texture).is_not_null()
