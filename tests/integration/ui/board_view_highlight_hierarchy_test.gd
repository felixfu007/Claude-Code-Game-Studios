# story-044 -- 高亮層級:可攻擊 > 被擋 > 威脅,同格互斥、角標、降調、禁區、選牌時隱藏攻擊族標記。
#
# 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BoardView.tscn / BattleScreen.tscn;
# BattleScreen 以 terrain_path_override / roster_path_override 注入合成夾具
# test_fixture_terrain_los.txt / test_fixture_roster_los.txt(唯讀、已進版控、兩份彼此相容:
# 5 格走廊,(2,0) 密林,我方 (0,0) 射程 1-4,敵方 (4,0))。
# 揭露:headless 不 rasterize,本檔只證明節點樹結構與矩形,不證明畫面看起來對(見 AC8 待補拍)。
# 揭露:威脅斜紋是整格貼圖(Sprite2D),不在矩形禁區斷言內(規格把它當不靠顏色的通道保留);
#      斜紋覆蓋量 THREAT_STRIPE_AREA_PX 是規格值,不是量測值。
# 敏感度:各 AC 的 mutant 為手動注入(一個 mutant 一次獨立執行),記錄在交付回報。
extends GdUnitTestSuite

const _BOARD_SCENE: String = "res://src/ui/battle/BoardView.tscn"
const _SCREEN_SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_PATH: String = "res://assets/data/levels/test_fixture_terrain_los.txt"
const _ROSTER_PATH: String = "res://assets/data/units/test_fixture_roster_los.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _board() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_SCENE).instantiate())
	add_child(instance)
	return instance


func _screen() -> BattleScreen:
	var instance: BattleScreen = load(_SCREEN_SCENE).instantiate()
	instance.terrain_path_override = _TERRAIN_PATH
	instance.roster_path_override = _ROSTER_PATH
	auto_free(instance)
	add_child(instance)
	return instance


## 一個標記根節點內所有繪製元素的格內矩形(ColorRect 取自身矩形,Line2D 取含線寬包圍盒)。
func _rects_of(root: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child: Node in root.get_children():
		if child is ColorRect:
			rects.append(Rect2((child as ColorRect).position, (child as ColorRect).size))
		elif child is Line2D:
			var line: Line2D = child as Line2D
			var bounds: Rect2 = Rect2(line.points[0], Vector2.ZERO)
			for p: Vector2 in line.points:
				bounds = bounds.expand(p)
			rects.append(bounds.grow(line.width * 0.5))
	return rects


func _forbidden_zones() -> Array[Rect2]:
	return [
		BoardView.hp_text_rect_in_cell(),
		BoardView.piece_label_rect_in_cell(),
		BoardView.hp_bar_rect_in_cell(),
		BoardView.BODY_CORE_RECT,
	]


func _marker_roots(layer: Node) -> Array[Node2D]:
	var roots: Array[Node2D] = []
	for child: Node in layer.get_children():
		if child is Node2D and not child is Sprite2D:
			roots.append(child as Node2D)
	return roots


func _cell_of(root: Node2D) -> Vector2i:
	return Vector2i((root.position - BoardCoords.BOARD_ORIGIN) / BoardCoords.CELL_SIZE)


func _cells_in(layer: Node) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for root: Node2D in _marker_roots(layer):
		cells.append(_cell_of(root))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return cells


## 從節點樹算視覺權重 W = 面積 × alpha(Line2D 以像素數 × 線寬 × alpha;斜紋貼圖以規格覆蓋量 × modulate.a)。
func _rendered_weight(layer: Node) -> float:
	var total: float = 0.0
	for child: Node in layer.get_children():
		if child is Sprite2D:
			total += BoardView.THREAT_STRIPE_AREA_PX * (child as Sprite2D).modulate.a
			continue
		for part: Node in child.get_children():
			if part is ColorRect:
				var rect: ColorRect = part as ColorRect
				total += rect.size.x * rect.size.y * rect.color.a
			elif part is Line2D:
				var line: Line2D = part as Line2D
				var d: Vector2 = (line.points[1] - line.points[0]).abs()
				total += (maxf(d.x, d.y) + 1.0) * line.width * line.default_color.a
	return total


func _layer(view: BoardView, name: String) -> Node2D:
	return view.get_node(name)


# ---- AC1 互斥與優先序 ------------------------------------------------------------

func test_same_cell_never_draws_two_attack_family_markers() -> void:
	var view: BoardView = _board()
	var a: Vector2i = Vector2i(3, 2)
	var b: Vector2i = Vector2i(4, 2)
	var c: Vector2i = Vector2i(5, 2)

	view.set_threat_highlights([a, b, c] as Array[Vector2i])
	view.set_attack_los_blocked_highlights([a, b] as Array[Vector2i])
	view.set_attack_highlights([a] as Array[Vector2i])

	assert_array(_cells_in(_layer(view, "AttackHighlightLayer"))).is_equal([a])
	assert_array(_cells_in(_layer(view, "AttackLosBlockedLayer"))).is_equal([b])
	assert_array(_cells_in(_layer(view, "ThreatHighlightLayer"))).is_equal([c])


func test_priority_does_not_depend_on_call_order() -> void:
	var view: BoardView = _board()
	var a: Vector2i = Vector2i(3, 2)
	var b: Vector2i = Vector2i(4, 2)

	view.set_attack_highlights([a] as Array[Vector2i])
	view.set_attack_los_blocked_highlights([a, b] as Array[Vector2i])
	view.set_threat_highlights([a, b, Vector2i(6, 2)] as Array[Vector2i])

	assert_array(_cells_in(_layer(view, "AttackHighlightLayer"))).is_equal([a])
	assert_array(_cells_in(_layer(view, "AttackLosBlockedLayer"))).is_equal([b])
	assert_array(_cells_in(_layer(view, "ThreatHighlightLayer"))).is_equal([Vector2i(6, 2)])


func test_attack_family_layers_draw_above_pieces_in_documented_order() -> void:
	var view: BoardView = _board()
	var pieces: int = _layer(view, "PiecesLayer").get_index()
	var threat: int = _layer(view, "ThreatHighlightLayer").get_index()
	var attack: int = _layer(view, "AttackHighlightLayer").get_index()
	var stats: int = _layer(view, "StatsLayer").get_index()
	assert_int(threat).is_greater(pieces)
	assert_int(attack).is_greater(threat)
	assert_int(stats).is_greater(attack)


# ---- AC2 被擋縮成角標 ------------------------------------------------------------
# story-052 註記:本測試是 BoardView 單元層級,「每個被餵入的格恰一章」由呼叫端決定餵哪些格;
# 不代表「所有被擋格都畫」(BattleScreen 只餵被擋 ∩ 存活敵兵格)。

func test_blocked_cell_draws_exactly_one_corner_stamp_outside_label_zone() -> void:
	var view: BoardView = _board()
	var cells: Array[Vector2i] = [Vector2i(3, 3), Vector2i(6, 1)]

	view.set_attack_los_blocked_highlights(cells)

	var layer: Node2D = _layer(view, "AttackLosBlockedLayer")
	assert_int(layer.get_child_count()).append_failure_message("每個被擋格恰一個標記根節點").is_equal(2)
	var center: Vector2 = Vector2.ONE * BoardCoords.CELL_SIZE * 0.5
	for root: Node2D in _marker_roots(layer):
		var rects: Array[Rect2] = _rects_of(root)
		assert_int(rects.size()).append_failure_message("章 + 斜線 = 2 個元素").is_equal(2)
		for rect: Rect2 in rects:
			assert_bool(rect.has_point(center)).append_failure_message("角標不得涵蓋格中心").is_false()
			assert_bool(rect.intersects(BoardView.piece_label_rect_in_cell())).is_false()
		# 不再有整格框:任何元素都遠小於整格
		for rect: Rect2 in rects:
			assert_float(rect.get_area()).is_less(BoardCoords.CELL_SIZE * BoardCoords.CELL_SIZE * 0.1)


# ---- AC3 可攻擊為主訊號(W 用節點樹算,預言機取自規格常數函式)-------------------------

func test_attack_weight_strictly_exceeds_threat_and_blocked() -> void:
	var view: BoardView = _board()
	view.set_attack_highlights([Vector2i(2, 2)] as Array[Vector2i])
	view.set_attack_los_blocked_highlights([Vector2i(3, 2)] as Array[Vector2i])
	view.set_threat_highlights([Vector2i(4, 2)] as Array[Vector2i])

	var w_attack: float = _rendered_weight(_layer(view, "AttackHighlightLayer"))
	var w_blocked: float = _rendered_weight(_layer(view, "AttackLosBlockedLayer"))
	var w_threat: float = _rendered_weight(_layer(view, "ThreatHighlightLayer"))

	# 防空洞:三種各至少渲染了一個
	assert_int(_marker_roots(_layer(view, "AttackHighlightLayer")).size()).is_equal(1)
	assert_int(_marker_roots(_layer(view, "AttackLosBlockedLayer")).size()).is_equal(1)
	assert_int(_marker_roots(_layer(view, "ThreatHighlightLayer")).size()).is_equal(1)
	assert_float(w_attack).append_failure_message("W_可攻擊=%s W_威脅=%s W_被擋=%s" % [w_attack, w_threat, w_blocked]).is_greater(w_threat)
	assert_float(w_threat).is_greater(w_blocked)
	# 節點樹與規格常數函式一致
	assert_float(w_attack).is_equal_approx(BoardView.attack_marker_weight(), 0.001)
	assert_float(w_blocked).is_equal_approx(BoardView.blocked_marker_weight(), 0.001)
	assert_float(w_threat).is_equal_approx(BoardView.threat_marker_weight(), 0.001)


# ---- AC4 威脅降調 ----------------------------------------------------------------

func test_threat_has_no_full_cell_fill_and_keeps_stripes() -> void:
	var view: BoardView = _board()
	var cells: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2)]

	view.set_threat_highlights(cells)

	var layer: Node2D = _layer(view, "ThreatHighlightLayer")
	var stripes: int = 0
	for child: Node in layer.get_children():
		if child is Sprite2D:
			stripes += 1
			assert_float((child as Sprite2D).modulate.a).is_less(0.3)
		assert_bool(child is ColorRect).append_failure_message("不得有整格底色 ColorRect").is_false()
		for part: Node in child.get_children():
			if part is ColorRect:
				var rect: ColorRect = part as ColorRect
				assert_float(rect.size.x * rect.size.y).is_less(BoardCoords.CELL_SIZE * 4.0)
				assert_float(rect.color.a).is_less(0.3 + 0.3)  # 邊環 0.55 為規格值,仍遠小於實心底
	assert_int(stripes).append_failure_message("斜線形狀保留,每格一張").is_equal(cells.size())
	# 畫在棋子上方的既有約束仍成立,但沒有任何實心底可蓋掉棋子
	assert_int(layer.get_index()).is_greater(_layer(view, "PiecesLayer").get_index())


# ---- AC5 禁區 --------------------------------------------------------------------

func test_markers_stay_out_of_label_text_bar_and_body_zones() -> void:
	var view: BoardView = _board()
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 2), Vector2i(8, 5)]
	view.set_attack_highlights([cells[0]] as Array[Vector2i])
	view.set_attack_los_blocked_highlights([cells[1]] as Array[Vector2i])
	view.set_threat_highlights([cells[2]] as Array[Vector2i])

	for name: String in ["AttackHighlightLayer", "AttackLosBlockedLayer", "ThreatHighlightLayer"]:
		var roots: Array[Node2D] = _marker_roots(_layer(view, name))
		assert_int(roots.size()).append_failure_message("%s 應有標記" % name).is_equal(1)
		for root: Node2D in roots:
			for rect: Rect2 in _rects_of(root):
				for zone: Rect2 in _forbidden_zones():
					assert_bool(rect.intersects(zone)).append_failure_message(
						"%s 的矩形 %s 與禁區 %s 相交" % [name, rect, zone]
					).is_false()


func test_real_scene_markers_on_unit_cells_avoid_forbidden_zones() -> void:
	var screen: BattleScreen = _screen()
	assert_bool(screen._controller.select_unit(1)).is_true()
	screen._refresh_view()
	var view: BoardView = screen._board_view
	var occupied: Dictionary[Vector2i, bool] = {}
	for faction: int in [Unit.Faction.PLAYER, Unit.Faction.ENEMY]:
		for unit: Unit in screen._state.units_of(faction):
			occupied[screen._state.position_of(unit.id)] = true

	var on_units: int = 0
	for name: String in ["AttackHighlightLayer", "AttackLosBlockedLayer", "ThreatHighlightLayer"]:
		for root: Node2D in _marker_roots(_layer(view, name)):
			if occupied.has(_cell_of(root)):
				on_units += 1
			for rect: Rect2 in _rects_of(root):
				for zone: Rect2 in _forbidden_zones():
					assert_bool(rect.intersects(zone)).is_false()
	assert_int(on_units).append_failure_message("防空洞:至少一個標記落在含單位的格上").is_greater(0)


# ---- 選牌時隱藏攻擊族標記(管理者 2026-11-12 裁決)--------------------------------

func _attack_family_child_count(view: BoardView) -> int:
	return (
		_layer(view, "AttackHighlightLayer").get_child_count()
		+ _layer(view, "AttackLosBlockedLayer").get_child_count()
		+ _layer(view, "ThreatHighlightLayer").get_child_count()
	)


func test_card_target_selection_hides_attack_family_markers_and_restores_after() -> void:
	var screen: BattleScreen = _screen()
	assert_bool(screen._controller.select_unit(1)).is_true()
	screen._refresh_view()
	assert_int(_attack_family_child_count(screen._board_view)).append_failure_message(
		"PRECONDITION:選牌前、已選單位時攻擊族標記存在"
	).is_greater(0)

	screen._card_selecting_target = true
	screen._refresh_view()
	assert_int(_layer(screen._board_view, "AttackHighlightLayer").get_child_count()).is_equal(0)
	assert_int(_layer(screen._board_view, "AttackLosBlockedLayer").get_child_count()).is_equal(0)
	assert_int(_layer(screen._board_view, "ThreatHighlightLayer").get_child_count()).is_equal(0)

	screen._card_selecting_target = false
	screen._refresh_view()
	assert_int(_attack_family_child_count(screen._board_view)).is_greater(0)


func test_card_target_selection_backfills_unreachable_marks_on_hidden_attack_cells() -> void:
	var screen: BattleScreen = _screen()
	assert_bool(screen._controller.select_unit(1)).is_true()
	screen._refresh_view()
	var view: BoardView = screen._board_view
	var hidden_cells: Array[Vector2i] = []
	hidden_cells.append_array(_cells_in(_layer(view, "AttackHighlightLayer")))
	hidden_cells.append_array(_cells_in(_layer(view, "ThreatHighlightLayer")))
	var breakdown: Dictionary = screen._controller.move_targets_breakdown().breakdown
	var unreachable: Dictionary[Vector2i, bool] = {}
	for key: String in ["blocked_by_occupancy", "blocked_by_terrain", "out_of_range"]:
		for cell: Vector2i in breakdown[key]:
			unreachable[cell] = true
	var holes: Array[Vector2i] = []
	for cell: Vector2i in hidden_cells:
		if unreachable.has(cell):
			holes.append(cell)
	assert_int(holes.size()).append_failure_message(
		"防空洞:至少一個原屬可攻擊/威脅的格也在不可達三態內"
	).is_greater(0)

	screen._card_selecting_target = true
	screen._refresh_view()

	var mark_rects: Array[Rect2] = []
	for root: Node in _layer(view, "MoveUnreachableLayer").get_children():
		for part: Node in root.get_children():
			if part is ColorRect:
				mark_rects.append(Rect2((part as ColorRect).position, (part as ColorRect).size))
			elif part is Line2D:
				pass
	for cell: Vector2i in holes:
		var cell_rect: Rect2 = Rect2(
			BoardCoords.grid_to_local(cell), Vector2.ONE * BoardCoords.CELL_SIZE
		)
		var drawn: bool = false
		for rect: Rect2 in mark_rects:
			if rect.intersects(cell_rect):
				drawn = true
				break
		assert_bool(drawn).append_failure_message("格 %s 選牌時攻擊族隱藏後沒有補畫不可達標記" % cell).is_true()
