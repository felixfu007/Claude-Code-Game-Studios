# Story 041 —— 血量文字條 / 棋子首字框 / 血條 三者在格內互不重疊。
# production/epics/tactical-combat/story-041-hp-text-vs-piece-label-overlap.md
#
# AC1 -> test_ac1_*(單一出處函式:幾何與 _build_* 實際位置一致,見下);
# AC2 -> test_ac2_*(走實際渲染出的節點樹);AC3 -> test_ac3_*(四種 HP 文字狀態 + 個位數/低血量)。
#
# 為什麼兩層預言機(AC2):
#   - test_ac1_single_source_rects_pairwise_disjoint 只驗三個單一出處函式的回傳值,
#     三者同出自一處,改壞常數時會一起漂移而仍綠 —— 它只證明「規則本身自洽」。
#   - test_ac2/ac3 走 render_pieces() 之後的節點樹,取 Label/ColorRect 實際 position/size
#     (含 Label 因字形最小尺寸被撐大的情形)換算成格內座標再比相交,不重算規則;
#     而且先斷言血量 Label 真的被畫出(防「沒畫就不重疊」的空洞綠燈)。
# 敏感度證明:見交付報告(一次一個 mutant、改壞 -> 紅 -> 還原),本檔不留 mutant。
# 本檔不讀任何檔案;headless 不 rasterize,像素層由截圖 + 人眼確認(AC6)。
extends GdUnitTestSuite


const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"
const _CELL: Vector2i = Vector2i(2, 2)


func _fresh_board_view() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _piece(
	faction: String, label: String, hp: int, hp_max: int, preview: int, illegal: bool
) -> Dictionary:
	return {
		"cell": _CELL, "faction": faction, "sprite_index": 0, "label": label,
		"hp": hp, "hp_max": hp_max, "hp_preview": preview,
		"show_hp_text": true, "card_target_illegal": illegal,
	}


func _cell_origin(view: BoardView) -> Vector2:
	return view.global_position + BoardCoords.grid_to_local(_CELL)


## 取節點在格內座標的實際矩形(含 clip_contents 祖先裁切後的可見部分)。
func _rect_in_cell(view: BoardView, control: Control) -> Rect2:
	var rect: Rect2 = Rect2(control.global_position - _cell_origin(view), control.size)
	# 祖先若是 clip_contents 的 Control,可見部分只剩與其矩形的交集。
	var anc: Node = control.get_parent()
	while anc != null and anc != view:
		if anc is Control and (anc as Control).clip_contents:
			var c: Control = anc
			rect = rect.intersection(Rect2(c.global_position - _cell_origin(view), c.size))
		anc = anc.get_parent()
	return rect


func _collect(node: Node, out_labels: Array[Label], out_rects: Array[ColorRect]) -> void:
	if node is Label:
		out_labels.append(node)
	elif node is ColorRect:
		out_rects.append(node)
	for child: Node in node.get_children():
		_collect(child, out_labels, out_rects)


func _disjoint(a: Rect2, b: Rect2) -> bool:
	return not a.intersects(b, false)


func test_ac1_single_source_rects_pairwise_disjoint() -> void:
	var text_rect: Rect2 = BoardView.hp_text_rect_in_cell()
	var label_rect: Rect2 = BoardView.piece_label_rect_in_cell()
	var bar_rect: Rect2 = BoardView.hp_bar_rect_in_cell()
	var cell: Rect2 = Rect2(0, 0, BoardCoords.CELL_SIZE, BoardCoords.CELL_SIZE)
	assert_bool(_disjoint(text_rect, label_rect)).is_true()
	assert_bool(_disjoint(text_rect, bar_rect)).is_true()
	assert_bool(_disjoint(label_rect, bar_rect)).is_true()
	for r: Rect2 in [text_rect, label_rect, bar_rect]:
		assert_bool(cell.encloses(r)).append_failure_message("矩形超出格 %s" % [r]).is_true()


func test_ac1_builders_position_nodes_from_the_single_source() -> void:
	var view: BoardView = _fresh_board_view()
	var pieces: Array[Dictionary] = [_piece("PLAYER", "藍", 10, 30, -1, false)]
	view.render_pieces(pieces)
	var labels: Array[Label] = []
	var rects: Array[ColorRect] = []
	_collect(view.get_node("StatsLayer"), labels, rects)
	var strip: ColorRect = null
	var bar_bg: ColorRect = null
	for r: ColorRect in rects:
		if r.size.y == BoardView.hp_text_rect_in_cell().size.y and r.size.x == float(BoardCoords.CELL_SIZE):
			strip = r
		if r.size == BoardView.hp_bar_rect_in_cell().size:
			bar_bg = r
	assert_object(strip).is_not_null()
	assert_object(bar_bg).is_not_null()
	assert_that(_rect_in_cell(view, strip)).is_equal(BoardView.hp_text_rect_in_cell())
	assert_that(_rect_in_cell(view, bar_bg)).is_equal(BoardView.hp_bar_rect_in_cell())
	var piece_label: Label = view.get_node("PieceLabelLayer").get_child(0)
	assert_that(_rect_in_cell(view, piece_label).position).is_equal(
		BoardView.piece_label_rect_in_cell().position
	)


## 四種 HP 文字狀態 x 我方/敵方 x 位數(個位數、低血量、兩位數)。
func _cases() -> Array[Dictionary]:
	return [
		_piece("PLAYER", "藍", 10, 30, -1, false),
		_piece("PLAYER", "董", 22, 22, 15, false),
		_piece("PLAYER", "徐", 6, 26, -1, false),
		_piece("PLAYER", "麥", 4, 22, -1, true),
		_piece("ENEMY", "2", 20, 20, -1, false),
		_piece("ENEMY", "3", 18, 18, 7, true),
		_piece("ENEMY", "1", 4, 22, -1, false),
	]


func test_ac2_ac3_rendered_node_tree_rects_do_not_overlap() -> void:
	for data: Dictionary in _cases():
		var view: BoardView = _fresh_board_view()
		var pieces: Array[Dictionary] = [data]
		view.render_pieces(pieces)
		var tag: String = "%s %s %d/%d prev=%d illegal=%s" % [
			data["faction"], data["label"], data["hp"], data["hp_max"],
			data["hp_preview"], data["illegal" if false else "card_target_illegal"]
		]
		var labels: Array[Label] = []
		var rects: Array[ColorRect] = []
		_collect(view.get_node("StatsLayer"), labels, rects)
		# 防空洞:HP 文字 Label 與襯底必須真的畫出。
		assert_int(labels.size()).append_failure_message("沒畫血量 Label:" + tag).is_equal(1)
		var hp_label: Label = labels[0]
		var expected_text: String = (
			"%d→%d" % [data["hp"], data["hp_preview"]] if data["hp_preview"] >= 0
			else "%d/%d" % [data["hp"], data["hp_max"]]
		)
		assert_str(hp_label.text).is_equal(expected_text)
		var piece_label: Label = view.get_node("PieceLabelLayer").get_child(0)
		assert_bool(piece_label.visible).append_failure_message("首字未顯示:" + tag).is_true()
		var text_rects: Array[Rect2] = [_rect_in_cell(view, hp_label)]
		var bar_rects: Array[Rect2] = []
		for r: ColorRect in rects:
			var rr: Rect2 = _rect_in_cell(view, r)
			if r.size.x == float(BoardCoords.CELL_SIZE):
				text_rects.append(rr)
			else:
				bar_rects.append(rr)
		assert_int(text_rects.size()).is_equal(2)
		assert_int(bar_rects.size()).is_equal(2)
		var label_rect: Rect2 = _rect_in_cell(view, piece_label)
		var cell: Rect2 = Rect2(0, 0, BoardCoords.CELL_SIZE, BoardCoords.CELL_SIZE)
		for t: Rect2 in text_rects:
			assert_bool(_disjoint(t, label_rect)).append_failure_message(
				"血量文字 %s 與首字框 %s 相交:%s" % [t, label_rect, tag]).is_true()
			assert_bool(cell.encloses(t)).append_failure_message(
				"血量文字 %s 超出格:%s" % [t, tag]).is_true()
			for b: Rect2 in bar_rects:
				assert_bool(_disjoint(t, b)).append_failure_message(
					"血量文字 %s 與血條 %s 相交:%s" % [t, b, tag]).is_true()
		for b: Rect2 in bar_rects:
			assert_bool(_disjoint(label_rect, b)).append_failure_message(
				"首字框與血條相交:" + tag).is_true()


# ─── 敏感度證明(常駐間諜子類別,進樹前 set_script(),Case A)────────────────────
# 每個間諜植入一種缺陷;對應測試斷言「與 AC2/AC1 相同的偵測邏輯」確實抓到它。

## ① 血量文字條往下挪(回到會蓋到首字框的舊位置)。
class _MutantStripMovedDown extends BoardView:
	func _build_hp_text(
		cell_top_left: Vector2, hp: int, hp_max: int, hp_preview: int, illegal: bool
	) -> Node2D:
		var node: Node2D = super._build_hp_text(cell_top_left, hp, hp_max, hp_preview, illegal)
		node.position.y += 3.0
		return node


## ② 首字框往上挪,壓進血量文字條。
class _MutantPieceLabelMovedUp extends BoardView:
	func _apply_piece_label(index: int, top_left: Vector2, text: String, is_ally: bool) -> void:
		super._apply_piece_label(index, top_left, text, is_ally)
		_piece_label_pool[index].position.y -= 4.0


## ③ _build_hp_text 不用單一出處函式,自帶舊常數(1px 邊距、10px 高)。
class _MutantOwnConstants extends BoardView:
	func _build_hp_text(
		cell_top_left: Vector2, _hp: int, _hp_max: int, _hp_preview: int, _illegal: bool
	) -> Node2D:
		var node: Node2D = Node2D.new()
		node.position = cell_top_left + Vector2(0.0, 1.0)
		var bg: ColorRect = ColorRect.new()
		bg.size = Vector2(BoardCoords.CELL_SIZE, 10.0)
		node.add_child(bg)
		return node


func _mutant_view(script: GDScript) -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	instance.set_script(script)
	add_child(instance)
	return instance


func _text_label_overlap_found(view: BoardView) -> bool:
	var pieces: Array[Dictionary] = [_piece("PLAYER", "藍", 10, 30, -1, false)]
	view.render_pieces(pieces)
	var labels: Array[Label] = []
	var rects: Array[ColorRect] = []
	_collect(view.get_node("StatsLayer"), labels, rects)
	var piece_rect: Rect2 = _rect_in_cell(view, view.get_node("PieceLabelLayer").get_child(0))
	for r: ColorRect in rects:
		if r.size.x == float(BoardCoords.CELL_SIZE) and not _disjoint(_rect_in_cell(view, r), piece_rect):
			return true
	for l: Label in labels:
		if not _disjoint(_rect_in_cell(view, l), piece_rect):
			return true
	return false


func test_sensitivity_proof_strip_moved_down_is_detected_as_overlap() -> void:
	assert_bool(_text_label_overlap_found(_mutant_view(_MutantStripMovedDown))).is_true()


func test_sensitivity_proof_piece_label_moved_up_is_detected_as_overlap() -> void:
	assert_bool(_text_label_overlap_found(_mutant_view(_MutantPieceLabelMovedUp))).is_true()


func test_sensitivity_proof_own_constants_diverge_from_single_source() -> void:
	var view: BoardView = _mutant_view(_MutantOwnConstants)
	var pieces: Array[Dictionary] = [_piece("PLAYER", "藍", 10, 30, -1, false)]
	view.render_pieces(pieces)
	var labels: Array[Label] = []
	var rects: Array[ColorRect] = []
	_collect(view.get_node("StatsLayer"), labels, rects)
	var matches: bool = false
	for r: ColorRect in rects:
		if r.size.x == float(BoardCoords.CELL_SIZE) and _rect_in_cell(view, r) == BoardView.hp_text_rect_in_cell():
			matches = true
	assert_bool(matches).is_false()
