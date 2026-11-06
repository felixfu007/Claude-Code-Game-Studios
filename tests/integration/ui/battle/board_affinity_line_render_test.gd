## relation-minimap story-002(第一段:棋盤)—— 載入真實 BoardView.tscn / BattleScreen.tscn 的節點層測試。
## AC-P2(線節點 default_color)/ AC-P3(0 效果無節點)/ AC-P5(預覽重算)/
## AC-P8(線層無 Label)+ 線形設定、符號牌位置與重疊規則。
##
## 🔴 未驗證:畫面實際外觀(headless 取不到像素);鋸齒是否糊成實線、符號牌是否被高亮/
##   HP 文字蓋住,全靠樣張(AC-P6 為開窗項,本檔不涵蓋)。
## 🔴 敏感度證明:見交付回報。
extends GdUnitTestSuite

const _BOARD_VIEW_PATH: String = "res://src/ui/battle/BoardView.tscn"
const _BATTLE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _board_view() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_PATH).instantiate())
	add_child(instance)
	return instance


func _entry(
	from_cell: Vector2i, to_cell: Vector2i, shape: BoardView.LineShape, tone: BoardView.LineTone
) -> Dictionary:
	var symbol: BoardView.LineSymbol = (
		BoardView.LineSymbol.PLUS if tone == BoardView.LineTone.POSITIVE else BoardView.LineSymbol.MINUS
	)
	return {"from": from_cell, "to": to_cell, "tone": tone, "shape": shape, "symbol": symbol}


func _lines(view: BoardView) -> Array[Line2D]:
	var result: Array[Line2D] = []
	for child: Node in view._affinity_line_layer.get_children():
		if child is Line2D:
			result.append(child)
	return result


func _plaques(view: BoardView) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for child: Node in view._affinity_line_layer.get_children():
		if child is Node2D and not (child is Line2D):
			result.append(child)
	return result


static func _mid(a: Vector2i, b: Vector2i) -> Vector2i:
	return Vector2i(((BoardCoords.grid_to_local_center(a) + BoardCoords.grid_to_local_center(b)) * 0.5).round())


func _draw_lines(view: BoardView, entries: Array[Dictionary]) -> void:
	view.set_affinity_lines(entries)


# ---- 線形、顏色(AC-P2)、Line2D 設定 ------------------------------------------------

func test_solid_and_zigzag_strokes_have_expected_shape_and_settings() -> void:
	var view: BoardView = _board_view()
	_draw_lines(view, [
		_entry(Vector2i(0, 0), Vector2i(3, 0), BoardView.LineShape.SOLID, BoardView.LineTone.NEGATIVE),
		_entry(Vector2i(0, 1), Vector2i(3, 1), BoardView.LineShape.ZIGZAG, BoardView.LineTone.NEGATIVE),
	])
	var lines: Array[Line2D] = _lines(view)
	assert_int(lines.size()).is_equal(4)  # 每條 = 底襯 + 線身
	# [0]/[1] = 實線底襯/線身;[2]/[3] = 鋸齒底襯/線身
	assert_int(lines[1].points.size()).is_equal(2)
	assert_int(lines[3].points.size()).is_greater(2)
	assert_float(lines[0].width).is_equal(BoardView.AFFINITY_LINE_BACKING_WIDTH)
	assert_float(lines[2].width).is_equal(BoardView.AFFINITY_LINE_BACKING_WIDTH)
	assert_array(lines[2].points).is_equal(lines[3].points)  # 底襯跟著鋸齒走
	# AC-P2:兩者同為負效果 → 同色;形狀不同
	assert_object(lines[1].default_color).is_equal(BoardView.AFFINITY_LINE_COLOR_NEGATIVE)
	assert_object(lines[3].default_color).is_equal(BoardView.AFFINITY_LINE_COLOR_NEGATIVE)
	for line: Line2D in lines:
		assert_int(line.joint_mode).is_equal(Line2D.LINE_JOINT_SHARP)
		assert_int(line.begin_cap_mode).is_equal(Line2D.LINE_CAP_NONE)
		assert_int(line.end_cap_mode).is_equal(Line2D.LINE_CAP_NONE)
		assert_bool(line.antialiased).is_false()


func test_ac_p9_stroke_width_is_constant_across_lines() -> void:
	var view: BoardView = _board_view()
	_draw_lines(view, [
		_entry(Vector2i(0, 0), Vector2i(1, 0), BoardView.LineShape.SOLID, BoardView.LineTone.POSITIVE),
		_entry(Vector2i(0, 1), Vector2i(4, 3), BoardView.LineShape.ZIGZAG, BoardView.LineTone.NEGATIVE),
	])
	var lines: Array[Line2D] = _lines(view)
	assert_float(lines[1].width).is_equal(BoardView.AFFINITY_LINE_STROKE_WIDTH)
	assert_float(lines[3].width).is_equal(BoardView.AFFINITY_LINE_STROKE_WIDTH)


# ---- AC-P3 / AC-P8 ------------------------------------------------------------------

func test_ac_p3_no_entries_means_no_nodes() -> void:
	var view: BoardView = _board_view()
	_draw_lines(view, [_entry(Vector2i(0, 0), Vector2i(2, 0), BoardView.LineShape.SOLID, BoardView.LineTone.POSITIVE)])
	assert_int(view._affinity_line_layer.get_child_count()).is_greater(0)
	_draw_lines(view, [])
	assert_int(view._affinity_line_layer.get_child_count()).is_equal(0)


func test_ac_p8_line_layer_contains_no_label() -> void:
	var view: BoardView = _board_view()
	_draw_lines(view, [
		_entry(Vector2i(0, 0), Vector2i(3, 0), BoardView.LineShape.SOLID, BoardView.LineTone.POSITIVE),
		_entry(Vector2i(0, 1), Vector2i(3, 1), BoardView.LineShape.ZIGZAG, BoardView.LineTone.NEGATIVE),
	])
	var stack: Array[Node] = [view._affinity_line_layer]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		assert_bool(node is Label).is_false()
		stack.append_array(node.get_children())


# ---- 符號牌 ----------------------------------------------------------------------

func test_plaque_is_7x7_at_mid_minus_3_with_5x5_glyph_inset_1() -> void:
	var view: BoardView = _board_view()
	var a: Vector2i = Vector2i(0, 0)
	var b: Vector2i = Vector2i(3, 0)
	_draw_lines(view, [_entry(a, b, BoardView.LineShape.SOLID, BoardView.LineTone.POSITIVE)])
	var plaques: Array[Node2D] = _plaques(view)
	assert_int(plaques.size()).is_equal(1)
	var tile: ColorRect = plaques[0].get_child(0)
	var top_left: Vector2 = Vector2(_mid(a, b) - Vector2i(3, 3))
	assert_vector(tile.position).is_equal(top_left)
	assert_vector(tile.size).is_equal(Vector2(7, 7))
	# + 號 = 橫 5x1 + 豎 1x5,左上 = 牌左上 + (1,1)
	var bar_h: ColorRect = plaques[0].get_child(1)
	var bar_v: ColorRect = plaques[0].get_child(2)
	assert_vector(bar_h.position).is_equal(top_left + Vector2(1, 3))
	assert_vector(bar_h.size).is_equal(Vector2(5, 1))
	assert_vector(bar_v.position).is_equal(top_left + Vector2(3, 1))
	assert_vector(bar_v.size).is_equal(Vector2(1, 5))
	assert_object(bar_h.color).is_equal(BoardView.AFFINITY_LINE_COLOR_POSITIVE)


func test_minus_plaque_has_only_the_horizontal_bar() -> void:
	var view: BoardView = _board_view()
	_draw_lines(view, [_entry(Vector2i(0, 0), Vector2i(3, 0), BoardView.LineShape.ZIGZAG, BoardView.LineTone.NEGATIVE)])
	var plaque: Node2D = _plaques(view)[0]
	assert_int(plaque.get_child_count()).is_equal(2)
	assert_object((plaque.get_child(1) as ColorRect).color).is_equal(BoardView.AFFINITY_LINE_COLOR_NEGATIVE)


func test_same_midpoint_same_sign_draws_one_plaque() -> void:
	var view: BoardView = _board_view()
	# (0,0)-(3,0) 與 (1,0)-(2,0) 中點相同,同為加成
	_draw_lines(view, [
		_entry(Vector2i(0, 0), Vector2i(3, 0), BoardView.LineShape.SOLID, BoardView.LineTone.POSITIVE),
		_entry(Vector2i(1, 0), Vector2i(2, 0), BoardView.LineShape.SOLID, BoardView.LineTone.POSITIVE),
	])
	assert_int(_plaques(view).size()).is_equal(1)


func test_same_midpoint_opposite_sign_draws_two_side_by_side_plus_left_minus_right() -> void:
	var view: BoardView = _board_view()
	_draw_lines(view, [
		_entry(Vector2i(0, 0), Vector2i(3, 0), BoardView.LineShape.ZIGZAG, BoardView.LineTone.NEGATIVE),
		_entry(Vector2i(1, 0), Vector2i(2, 0), BoardView.LineShape.SOLID, BoardView.LineTone.POSITIVE),
	])
	var plaques: Array[Node2D] = _plaques(view)
	assert_int(plaques.size()).is_equal(2)
	var mid: Vector2i = _mid(Vector2i(0, 0), Vector2i(3, 0))
	var plus_tile: ColorRect = null
	var minus_tile: ColorRect = null
	for plaque: Node2D in plaques:
		if plaque.get_child_count() == 3:
			plus_tile = plaque.get_child(0)
		else:
			minus_tile = plaque.get_child(0)
	assert_vector(plus_tile.position).is_equal(Vector2(mid + Vector2i(-4, 0) - Vector2i(3, 3)))
	assert_vector(minus_tile.position).is_equal(Vector2(mid + Vector2i(4, 0) - Vector2i(3, 3)))


# ---- AC-P5:預覽依假想站位重算 -----------------------------------------------------

func test_ac_p5_move_preview_redraws_board_lines_from_hypothetical_layout() -> void:
	var instance: BattleScreen = auto_free(load(_BATTLE_PATH).instantiate())
	add_child(instance)
	for unit: Unit in instance._state.units_of(Unit.Faction.PLAYER):
		if not instance._controller.select_unit(unit.id):
			continue
		for cell: Vector2i in instance._controller.move_targets().cells:
			if cell == instance._state.position_of(unit.id):
				continue
			instance._cursor_cell = cell
			instance._cursor_active = true
			instance._refresh_view()
			var hypo: Dictionary[int, Vector2i] = instance._phi.positions_with(unit.id, cell)
			var expected: Array[AffinityLineStatus] = AffinityRules.board_lines(
				hypo, instance._phi.links(), instance._state.affinity_tuning
			)
			var drawn: int = 0
			var zigzag: int = 0
			for status: AffinityLineStatus in expected:
				if status.state == AffinityLineStatus.State.NEUTRAL:
					continue
				drawn += 1
				if status.polarity == AffinityLink.Polarity.NEGATIVE:
					zigzag += 1
			var line_nodes: Array[Line2D] = _lines(instance._board_view)
			var zigzag_nodes: int = 0
			for line: Line2D in line_nodes:
				if line.points.size() > 2:
					zigzag_nodes += 1
			assert_int(line_nodes.size()).is_equal(drawn * 2)
			assert_int(zigzag_nodes).is_equal(zigzag * 2)
			return
		instance._controller.deselect()
	fail("找不到可預覽的移動格")
