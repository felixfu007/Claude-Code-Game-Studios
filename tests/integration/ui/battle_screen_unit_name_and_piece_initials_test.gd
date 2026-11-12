# Story 039 —— 資訊卡顯示正式姓名 + 棋子標姓名首字/敵兵編號。
# production/epics/tactical-combat/story-039-unit-name-and-piece-initials.md
#
# AC1 → test_ac1_*;AC2 → test_ac2_*;AC3 → test_ac3_*;AC4/AC5 → test_ac4_* / test_ac5_*。
# 純格式化函式與 BoardView 結構斷言;headless 不 rasterize,像素層由午休截圖/目視確認。
# 敏感度證明:見交付報告(改壞 → 紅 → 還原),本檔不留 mutant。
extends GdUnitTestSuite


const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"


func _fresh_board_view() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _labels_in(view: BoardView) -> Array[Label]:
	var found: Array[Label] = []
	var stats: Node = view.get_node("StatsLayer")
	_collect_labels(stats, found)
	return found


func _collect_labels(node: Node, out: Array[Label]) -> void:
	if node is Label:
		out.append(node)
	for child: Node in node.get_children():
		_collect_labels(child, out)


func _piece_labels_in(view: BoardView) -> Array[Label]:
	# 棋子標記 Label 在常駐的 PieceLabelLayer(Label 池);只算 visible 者。
	var result: Array[Label] = []
	var layer: Node = view.get_node_or_null("PieceLabelLayer")
	if layer == null:
		return result
	for child: Node in layer.get_children():
		if child is Label and (child as Label).visible:
			result.append(child as Label)
	return result

func _piece(cell: Vector2i, faction: String, label: String) -> Dictionary:
	return {
		"cell": cell, "faction": faction, "sprite_index": 0,
		"hp": 10, "hp_max": 10, "label": label,
	}


# ---- AC1 ----------------------------------------------------------------

func test_ac1_player_identity_line_uses_localized_name() -> void:
	assert_str(
		BattleScreen.format_tile_info_identity_line(Unit.Faction.PLAYER, 1, "甲")
	).is_equal("藍亭萱（我方）")
	assert_str(
		BattleScreen.format_tile_info_identity_line(Unit.Faction.PLAYER, 5, "戊")
	).is_equal("麥子健（我方）")


func test_ac1_build_tile_info_text_player_replaces_faction_line_same_line_count() -> void:
	var text: String = BattleScreen.build_tile_info_text(
		Board.TERRAIN_OPEN, 1, false,
		true, Unit.Faction.PLAYER, 30, 30, TurnOrder.ActionState.NOT_FOUND, 1, 1, 6,
		1, "甲"
	)
	var lines: PackedStringArray = text.split("\n")
	assert_int(lines.size()).is_equal(8)
	assert_str(lines[3]).is_equal("藍亭萱（我方）")
	assert_bool(text.contains("陣營")).is_false()


# ---- AC2 ----------------------------------------------------------------

func test_ac2_enemy_identity_line_uses_fixed_number_from_code_name() -> void:
	assert_str(
		BattleScreen.format_tile_info_identity_line(Unit.Faction.ENEMY, 8, "E3")
	).is_equal("敵兵 3（敵方）")


func test_ac2_enemy_number_unaffected_by_unit_id() -> void:
	# 編號取自 code_name,不取自 id 或存活順序。
	assert_str(
		BattleScreen.format_tile_info_identity_line(Unit.Faction.ENEMY, 6, "E5")
	).is_equal("敵兵 5（敵方）")


func test_ac2_bad_code_name_falls_back_to_faction_line() -> void:
	# push_error 會被 GdUnit4 視為錯誤?不會 —— push_error 只印;斷言退回原陣營行。
	assert_str(
		BattleScreen.format_tile_info_identity_line(Unit.Faction.ENEMY, 6, "X9")
	).is_equal("陣營：敵方")
	assert_int(BattleScreen.enemy_number_from_code_name("E")).is_equal(-1)
	assert_int(BattleScreen.enemy_number_from_code_name("Ex")).is_equal(-1)
	assert_int(BattleScreen.enemy_number_from_code_name("")).is_equal(-1)
	assert_int(BattleScreen.enemy_number_from_code_name("E12")).is_equal(12)


# ---- AC3 ----------------------------------------------------------------

func test_ac3_piece_label_text_player_first_char_enemy_number() -> void:
	assert_str(BattleScreen.piece_label_text(Unit.Faction.PLAYER, 1, "甲")).is_equal("藍")
	assert_str(BattleScreen.piece_label_text(Unit.Faction.PLAYER, 4, "丁")).is_equal("秦")
	assert_str(BattleScreen.piece_label_text(Unit.Faction.ENEMY, 9, "E4")).is_equal("4")


func test_ac3_board_view_draws_label_with_art_director_style() -> void:
	var view: BoardView = _fresh_board_view()
	var pieces: Array[Dictionary] = [
		_piece(Vector2i(2, 3), "PLAYER", "藍"),
		_piece(Vector2i(5, 1), "ENEMY", "3"),
	]
	view.render_pieces(pieces)
	var labels: Array[Label] = _piece_labels_in(view)
	assert_int(labels.size()).is_equal(2)
	var ally: Label = labels[0]
	var enemy: Label = labels[1]
	assert_str(ally.text).is_equal("藍")
	assert_str(enemy.text).is_equal("3")
	assert_bool(ally.label_settings.font_color == Color("#FFFFFF")).is_true()
	assert_bool(enemy.label_settings.font_color == Color("#FF5252")).is_true()
	assert_bool(ally.label_settings.outline_color == Color("#0E0F14")).is_true()
	assert_int(ally.label_settings.outline_size).is_equal(1)
	# 字框左上角 = 棋子圖座標 (0,16) = 格左緣、格頂 + 8(棋子圖頂 = 格頂 - 8)。
	var cell_tl: Vector2 = BoardCoords.grid_to_local(Vector2i(2, 3))
	assert_vector(ally.position).is_equal(Vector2(cell_tl.x, cell_tl.y + 8.0))


# ---- AC4 ----------------------------------------------------------------

func test_ac4_label_follows_piece_on_move_and_removed_on_death() -> void:
	var view: BoardView = _fresh_board_view()
	view.render_pieces([_piece(Vector2i(1, 1), "ENEMY", "2")] as Array[Dictionary])
	var before: Vector2 = _piece_labels_in(view)[0].position
	view.render_pieces([_piece(Vector2i(4, 2), "ENEMY", "2")] as Array[Dictionary])
	var after_labels: Array[Label] = _piece_labels_in(view)
	assert_int(after_labels.size()).is_equal(1)
	var cell_tl: Vector2 = BoardCoords.grid_to_local(Vector2i(4, 2))
	assert_vector(after_labels[0].position).is_equal(Vector2(cell_tl.x, cell_tl.y + 8.0))
	assert_bool(after_labels[0].position != before).is_true()
	view.render_pieces([] as Array[Dictionary])
	assert_int(_piece_labels_in(view).size()).is_equal(0)


# ---- AC5 ----------------------------------------------------------------

func test_ac5_no_label_field_draws_no_label_and_hp_text_still_drawn() -> void:
	var view: BoardView = _fresh_board_view()
	var piece: Dictionary = _piece(Vector2i(0, 2), "PLAYER", "")
	piece["show_hp_text"] = true
	view.render_pieces([piece] as Array[Dictionary])
	assert_int(_piece_labels_in(view).size()).is_equal(0)
	# HP 文字 Label(8px)仍在。
	assert_int(_labels_in(view).size()).is_equal(1)
