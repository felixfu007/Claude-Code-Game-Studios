# Story 057 -- 我方棋子首字深色襯底(α0.72)。
# production/epics/tactical-combat/story-057-piece-initial-dark-backdrop.md
#
# AC1 顯示規則 / AC2 結構層(游標停在棋子上,經真實 BattleScreen + CursorStateHost)/
# AC3 不暗化 / AC4 池子重用 / AC5 敵方不套。AC2 像素層與 AC7 人眼屬開窗驗收,不在本檔。
# 屬性:本檔讀 assets/data/ 的 vs01 真實資料檔(登記例外 1,唯讀),只經 BattleScreen 注入路徑;
# 不證明窮盡。headless 不 rasterize,只驗節點結構/位置/顏色/層序。
# 敏感度證明:mutant 以暫時改 src 逐一執行,不留在本檔。
extends GdUnitTestSuite

const _BOARD_SCENE: String = "res://src/ui/battle/BoardView.tscn"
const _SCREEN_SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const _T: String = "res://assets/data/levels/vs01_terrain.txt"
const _R: String = "res://assets/data/units/vs01_roster.txt"
const _A: String = "res://assets/data/affinity/vs01_affinity_links.txt"
const _C: String = "res://assets/data/cards/vs01_cards.txt"
const _CT: String = "res://assets/data/cards/vs01_card_text.txt"
const _XU_CELL: Vector2i = Vector2i(0, 3)

var _host_snap: CursorHostSnapshot = null


# AC2 會改寫共用 Autoload CursorStateHost;依 tests/helpers/cursor_host_snapshot.gd 慣例還原。
func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _view() -> BoardView:
	var v: BoardView = auto_free(load(_BOARD_SCENE).instantiate())
	add_child(v)
	return v


func _piece(cell: Vector2i, faction: String, label: String, extra: Dictionary = {}) -> Dictionary:
	var p: Dictionary = {
		"cell": cell, "faction": faction, "sprite_index": 0, "hp": 10, "hp_max": 10, "label": label,
	}
	p.merge(extra, true)
	return p


func _visible_backdrops(view: BoardView) -> Array[ColorRect]:
	var out: Array[ColorRect] = []
	var layer: Node = view.get_node_or_null("PieceLabelBackdropLayer")
	if layer == null:
		return out
	for c: Node in layer.get_children():
		if c is ColorRect and (c as ColorRect).visible:
			out.append(c)
	return out


func _expected_rect(cell: Vector2i) -> Rect2:
	var r: Rect2 = BoardView.piece_label_rect_in_cell()
	return Rect2(BoardCoords.grid_to_local(cell) + r.position, r.size)


func test_ac1_backdrop_only_for_ally_with_label() -> void:
	var view: BoardView = _view()
	var pieces: Array[Dictionary] = [
		_piece(Vector2i(1, 1), "PLAYER", "甲"),
		_piece(Vector2i(2, 1), "PLAYER", ""),
		_piece(Vector2i(3, 1), "ENEMY", "1"),
	]
	view.render_pieces(pieces)
	var found: Array[ColorRect] = _visible_backdrops(view)
	assert_int(found.size()).append_failure_message("恰 1 個(我方有首字)").is_equal(1)
	var bd: ColorRect = found[0]
	assert_vector(bd.position).is_equal(_expected_rect(Vector2i(1, 1)).position)
	assert_vector(bd.size).is_equal(_expected_rect(Vector2i(1, 1)).size)
	assert_float(bd.color.r).is_equal_approx(BoardView.PIECE_LABEL_BACKDROP_COLOR.r, 0.0001)
	assert_float(bd.color.g).is_equal_approx(BoardView.PIECE_LABEL_BACKDROP_COLOR.g, 0.0001)
	assert_float(bd.color.b).is_equal_approx(BoardView.PIECE_LABEL_BACKDROP_COLOR.b, 0.0001)
	assert_float(bd.color.a).is_equal_approx(0.72, 0.0001)
	assert_float(BoardView.PIECE_LABEL_BACKDROP_COLOR.a).is_equal_approx(0.72, 0.0001)
	assert_str(BoardView.PIECE_LABEL_BACKDROP_COLOR.to_html(false)).is_equal("0e0f14")


func test_ac1_ally_without_label_and_enemy_alone_yield_none() -> void:
	var view: BoardView = _view()
	var pieces: Array[Dictionary] = [_piece(Vector2i(2, 1), "PLAYER", ""), _piece(Vector2i(3, 1), "ENEMY", "2")]
	view.render_pieces(pieces)
	assert_int(_visible_backdrops(view).size()).is_equal(0)


func test_ac3_done_ally_backdrop_and_label_not_dimmed() -> void:
	var view: BoardView = _view()
	var pieces: Array[Dictionary] = [
		_piece(Vector2i(1, 1), "PLAYER", "甲"),
		_piece(Vector2i(2, 1), "PLAYER", "乙", {"done": true}),
	]
	view.render_pieces(pieces)
	var found: Array[ColorRect] = _visible_backdrops(view)
	assert_int(found.size()).is_equal(2)
	for bd: ColorRect in found:
		assert_object(bd.modulate).is_equal(Color.WHITE)
	for l: Node in view.get_node("PieceLabelLayer").get_children():
		assert_object((l as Label).modulate).is_equal(Color.WHITE)
	# 防空洞:確有做完案例(棋子貼圖確實被暗化)
	var dimmed: int = 0
	for s: Node in view.get_node("PiecesLayer").get_children():
		if (s as CanvasItem).modulate != Color.WHITE:
			dimmed += 1
	assert_int(dimmed).is_equal(1)


func test_ac4_pool_reuse_leaves_no_stale_backdrops_and_follows_position() -> void:
	var view: BoardView = _view()
	var first: Array[Dictionary] = [
		_piece(Vector2i(1, 1), "PLAYER", "甲"), _piece(Vector2i(2, 1), "PLAYER", "乙"),
		_piece(Vector2i(3, 1), "PLAYER", "丙"),
	]
	view.render_pieces(first)
	assert_int(_visible_backdrops(view).size()).is_equal(3)
	var second: Array[Dictionary] = [_piece(Vector2i(4, 4), "PLAYER", "丁")]
	view.render_pieces(second)
	var found: Array[ColorRect] = _visible_backdrops(view)
	assert_int(found.size()).is_equal(1)
	assert_vector(found[0].position).is_equal(_expected_rect(Vector2i(4, 4)).position)


func test_ac5_enemy_never_gets_backdrop_even_with_preview() -> void:
	var view: BoardView = _view()
	var pieces: Array[Dictionary] = [
		_piece(Vector2i(3, 1), "ENEMY", "1", {"hp_preview": 3, "show_hp_text": true}),
	]
	view.render_pieces(pieces)
	assert_int(_visible_backdrops(view).size()).is_equal(0)
	var layer: Node = view.get_node_or_null("PieceLabelBackdropLayer")
	var n: int = 0 if layer == null else layer.get_child_count()
	assert_int(n).append_failure_message("敵方:襯底節點集合為空").is_equal(0)


# b 的索引大於 a = b 畫在 a 之上(同為 BoardView 直屬子節點)
func _above(view: BoardView, upper: String, lower: String) -> bool:
	return view.get_node(upper).get_index() > view.get_node(lower).get_index()


func test_ac2_structural_cursor_on_ally_backdrop_still_visible_and_above_overlays() -> void:
	var inst: BattleScreen = auto_free(load(_SCREEN_SCENE).instantiate())
	inst.terrain_path_override = _T
	inst.roster_path_override = _R
	inst.affinity_path_override = _A
	inst.cards_path_override = _C
	inst.card_text_path_override = _CT
	add_child(inst)
	await await_idle_frame()
	await await_idle_frame()
	var host: Node = get_tree().root.get_node("CursorStateHost")
	var types: GDScript = load("res://src/ui/cursor/cursor_types.gd")
	var tgt: Object = (load("res://src/ui/cursor/cursor_target.gd") as GDScript).make(
		types.SurfaceType.BOARD_TILE, types.encode_tile(_XU_CELL, BoardCoords.BOARD_COLS))
	host.set_target(tgt)
	for i: int in range(4):
		await await_idle_frame()
	assert_bool(inst._cursor_active).append_failure_message("前置:游標已在徐培恩格").is_true()
	assert_vector(Vector2(inst._cursor_cell)).is_equal(Vector2(_XU_CELL))
	var view: BoardView = inst.get_node("WorldViewportContainer/WorldViewport/BoardView")
	var matched: ColorRect = null
	for bd: ColorRect in _visible_backdrops(view):
		if bd.position.is_equal_approx(_expected_rect(_XU_CELL).position):
			matched = bd
	assert_object(matched).append_failure_message("徐培恩格應有可見襯底").is_not_null()
	var n: Node = matched
	while n != null and n != get_tree().root:
		if n is CanvasItem:
			assert_bool((n as CanvasItem).visible).append_failure_message("祖先 %s 不可見" % n.name).is_true()
		n = n.get_parent()
	# 襯底層必須在所有棋盤高亮層之上、首字層之下;游標與動作圖示在其上(游標為外框,不填滿)。
	for lower: String in ["PiecesLayer", "MoveUnreachableLayer", "AffinityLineLayer", "ThreatHighlightLayer",
			"AttackHighlightLayer", "AttackLosBlockedLayer", "CardTargetHighlightLayer", "StatsLayer"]:
		assert_bool(_above(view, "PieceLabelBackdropLayer", lower)).append_failure_message(
			"襯底層應在 %s 之上" % lower).is_true()
	assert_bool(_above(view, "PieceLabelLayer", "PieceLabelBackdropLayer")).is_true()
	assert_bool(_above(view, "CursorSprite", "PieceLabelBackdropLayer")).is_true()
	assert_bool(_above(view, "ActionFlagLayer", "PieceLabelBackdropLayer")).is_true()
