# story-058 -- 可攻擊琥珀框在「只選取、游標不在該敵」時也成閉合一圈。
#
# 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BoardView.tscn / BattleScreen.tscn
# (後者以 terrain/roster_path_override 唯讀餵入 assets/data/ 下已進版控的 duel 夾具);不寫任何檔案。
# 揭露:headless 不 rasterize,本檔只證明節點樹矩形與圖例同源;像素層另見
#      prototypes/story-058-attack-ring-evidence-2026-11-17/(開窗,AC2)。不證明窮盡性。
# 預言機:一律取自 BoardView.attack_ring_rects_in_cell() / ring_rects_in_cell() 等單一出處,
#        不在測試裡另設座標;「本單前的三邊集合」由 ring_rects_in_cell(ATTACK_RING_WIDTH) 取得(它未被改動)。
# 敏感度:mutant 為手動注入,一個 mutant 一次獨立執行,記錄在交付回報。
extends GdUnitTestSuite

const _BOARD_SCENE: String = "res://src/ui/battle/BoardView.tscn"
const _SCREEN_SCENE: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const _ENEMY_CELL: Vector2i = Vector2i(4, 0)

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


func after_test() -> void:
	get_tree().paused = false
	_host_snap.restore()
	CampaignProgress.reset_for_test()
	TutorialProgress.end()


func _board() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_SCENE).instantiate())
	add_child(instance)
	return instance


func _ring_rects_drawn(view: BoardView, cell: Vector2i) -> Array[Rect2]:
	var layer: Node2D = view.get_node("AttackHighlightLayer")
	var rects: Array[Rect2] = []
	for root: Node in layer.get_children():
		if root is Node2D and (root as Node2D).position == BoardCoords.grid_to_local(cell):
			for part: Node in root.get_children():
				if part is ColorRect:
					rects.append(Rect2((part as ColorRect).position, (part as ColorRect).size))
	return rects


func _key(r: Rect2) -> String:
	return "%s|%s" % [r.position, r.size]


func _as_keys(rects: Array[Rect2]) -> Array[String]:
	var keys: Array[String] = []
	for r: Rect2 in rects:
		keys.append(_key(r))
	keys.sort()
	return keys


func _render_enemy(view: BoardView, show_hp_text: bool) -> void:
	var pieces: Array[Dictionary] = [{
		"cell": _ENEMY_CELL, "faction": "ENEMY", "hp": 10, "hp_max": 20,
		"label": "E", "show_hp_text": show_hp_text,
	}]
	view.render_pieces(pieces)
	view.set_attack_highlights([_ENEMY_CELL] as Array[Vector2i])


# ---- AC1 兩狀態皆閉合 ------------------------------------------------------------

func test_ring_has_four_edges_joined_at_corners() -> void:
	var cell: float = BoardCoords.CELL_SIZE
	var rects: Array[Rect2] = BoardView.attack_ring_rects_in_cell()
	var top: Rect2 = Rect2()
	var bottom: Rect2 = Rect2()
	var right: Rect2 = Rect2()
	var lefts: Array[Rect2] = []
	for r: Rect2 in rects:
		if r.size.x == cell and r.position.y == 0.0:
			top = r
		elif r.size.x == cell and r.end.y == cell:
			bottom = r
		elif r.end.x == cell and r.size.y > r.size.x:
			right = r
		elif r.position.x == 0.0 and r.size.y > r.size.x:
			lefts.append(r)
	assert_float(top.size.y).append_failure_message("缺上邊").is_greater(0.0)
	assert_float(bottom.size.y).append_failure_message("缺下邊").is_greater(0.0)
	assert_float(right.size.y).append_failure_message("缺右邊").is_greater(0.0)
	assert_int(lefts.size()).append_failure_message("左邊應為首字框上、下兩段").is_equal(2)
	lefts.sort_custom(func(p: Rect2, q: Rect2) -> bool: return p.position.y < q.position.y)
	var left_upper: Rect2 = lefts[0]
	var left_lower: Rect2 = lefts[1]
	assert_float(top.size.y).is_equal(BoardView.ATTACK_RING_WIDTH)
	# 角落相接:右邊上端接上邊下緣、下端接底邊上緣(左邊的首字框缺口是 044 設計,不在此條)
	assert_float(right.position.y).is_equal(top.end.y)
	assert_float(right.end.y).is_equal(bottom.position.y)
	# 管理者 2026-11-17 裁決 A:左上段自上邊下緣接到首字框上緣;下段自首字框下緣接到底邊上緣;
	# 只留首字框本身(041 函式)的缺口
	var label: Rect2 = BoardView.piece_label_rect_in_cell()
	assert_float(left_upper.position.y).is_equal(top.end.y)
	assert_float(left_upper.end.y).is_equal(label.position.y)
	assert_float(left_lower.position.y).is_equal(label.end.y)
	assert_float(left_lower.end.y).is_equal(bottom.position.y)
	# 互不重疊(像素數可逐一加總;touching 不算 intersects)
	for i: int in range(rects.size()):
		for j: int in range(i + 1, rects.size()):
			assert_bool(rects[i].intersects(rects[j])).append_failure_message(
				"%s 與 %s 重疊" % [rects[i], rects[j]]).is_false()


func test_ring_rect_set_same_with_and_without_hp_text_bar() -> void:
	var without_bar: BoardView = _board()
	_render_enemy(without_bar, false)
	var with_bar: BoardView = _board()
	_render_enemy(with_bar, true)

	var a: Array[Rect2] = _ring_rects_drawn(without_bar, _ENEMY_CELL)
	var b: Array[Rect2] = _ring_rects_drawn(with_bar, _ENEMY_CELL)
	assert_int(a.size()).append_failure_message("防空洞:環應有矩形").is_greater(0)
	assert_array(_as_keys(a)).is_equal(_as_keys(BoardView.attack_ring_rects_in_cell()))
	assert_array(_as_keys(b)).is_equal(_as_keys(a))
	# 文字條顯示時是它蓋在環上邊之上:StatsLayer 在 AttackHighlightLayer 之後
	var attack_i: int = with_bar.get_node("AttackHighlightLayer").get_index()
	assert_int(with_bar.get_node("StatsLayer").get_index()).is_greater(attack_i)


func test_closed_ring_differs_from_pre_story_three_edge_set() -> void:
	# 防空洞:證明上面的斷言真的會因本單改動而翻轉
	var three_edges: Array[Rect2] = BoardView.ring_rects_in_cell(BoardView.ATTACK_RING_WIDTH)
	var now: Array[Rect2] = BoardView.attack_ring_rects_in_cell()
	assert_int(three_edges.size()).is_equal(3)
	assert_array(_as_keys(now)).is_not_equal(_as_keys(three_edges))
	var area_before: float = 0.0
	for r: Rect2 in three_edges:
		area_before += r.get_area()
	assert_float(BoardView.attack_marker_weight()).is_greater(area_before * BoardView.ATTACK_RING_COLOR.a)


# ---- AC3 威脅環不動、不等式仍成立 ---------------------------------------------------

func test_threat_ring_unchanged_and_inequality_holds() -> void:
	var threat: Array[Rect2] = BoardView.threat_ring_rects_in_cell()
	assert_int(threat.size()).is_equal(3)
	assert_array(_as_keys(threat)).is_equal(_as_keys(BoardView.ring_rects_in_cell(BoardView.THREAT_RING_WIDTH)))
	for r: Rect2 in threat:
		assert_bool(r.position.y == 0.0).append_failure_message("威脅環不得有上邊").is_false()
	assert_float(BoardView.attack_marker_weight()).is_greater(BoardView.threat_marker_weight())
	assert_float(BoardView.threat_marker_weight()).is_greater(BoardView.blocked_marker_weight())


# ---- AC5 圖例同源 ----------------------------------------------------------------

func test_legend_attack_sample_draws_same_closed_ring_rects() -> void:
	var sample: Node2D = BoardView.build_legend_sample(BoardView.MarkerKind.ATTACK_RANGE)
	auto_free(sample)
	var drawn: Array[Rect2] = []
	for rect: Node in sample.find_children("*", "ColorRect", true, false):
		if (rect as ColorRect).color == BoardView.ATTACK_RING_COLOR:
			drawn.append(Rect2((rect as ColorRect).position, (rect as ColorRect).size))
	assert_int(drawn.size()).is_greater(0)
	assert_array(_as_keys(drawn)).is_equal(_as_keys(BoardView.attack_ring_rects_in_cell()))
	# 圖例範例也含上邊(閉合):至少一個矩形貼格頂且整格寬
	var has_top: bool = false
	for r: Rect2 in drawn:
		if r.position.y == 0.0 and r.size.x == BoardCoords.CELL_SIZE:
			has_top = true
	assert_bool(has_top).is_true()


func test_legend_panel_icon_is_built_from_same_sample() -> void:
	var instance: BattleScreen = load(_SCREEN_SCENE).instantiate()
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH
	auto_free(instance)
	add_child(instance)
	var panel: LegendPanel = instance.legend_panel()
	panel.open(Vector2i(960, 540))
	var drawn: Array[Rect2] = []
	for rect: Node in panel.icon_for(BoardView.MarkerKind.ATTACK_RANGE).find_children("*", "ColorRect", true, false):
		if (rect as ColorRect).color == BoardView.ATTACK_RING_COLOR:
			drawn.append(Rect2((rect as ColorRect).position, (rect as ColorRect).size))
	assert_array(_as_keys(drawn)).is_equal(_as_keys(BoardView.attack_ring_rects_in_cell()))
	panel.close()
