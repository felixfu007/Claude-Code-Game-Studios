extends GdUnitTestSuite

# Story 029(手牌列)E1 / E2 / F / N 的結構斷言。檔案存取:無。
# 矩形一律呼叫 HudLayout / HandBar / BattleMenu / WorldLayout 既有函式,不自算倍率。
# 敏感度:E1、F 各一條常駐 test_sensitivity_proof_*(偵測器抓得到舊行為/植入缺陷)。
# F 的判準(照實):避開棋盤最下一列「中間」格子(欄 3..BOARD_COLS-4),不是完全不壓格;
# 貼右緣後仍會壓到最下一列右端(欄 10..12)的格子,見 test_f_collapsed_hand_still_overlaps_some_bottom_row_cells。

const _SCENE_PATH: String = "res://src/ui/battle/HandBar.tscn"
const _SIZES: Array[Vector2i] = [Vector2i(1440, 810), Vector2i(1920, 1080), Vector2i(960, 540)]
const _MAX_SLOTS: int = 5
const _MIDDLE_COL_MARGIN: int = 3


func _bottom_row_cells(ws: Vector2i, only_middle: bool) -> Array[Rect2]:
	var n: float = float(WorldLayout.compute_scale(ws))
	var wr: Rect2i = WorldLayout.compute_rect(ws)
	var out: Array[Rect2] = []
	var first: int = _MIDDLE_COL_MARGIN if only_middle else 0
	var last: int = BoardCoords.BOARD_COLS - 1 - (_MIDDLE_COL_MARGIN if only_middle else 0)
	for col in range(first, last + 1):
		var x: float = float(wr.position.x) + (BoardCoords.BOARD_ORIGIN.x + float(col * BoardCoords.CELL_SIZE)) * n
		var y: float = float(wr.position.y) + (BoardCoords.BOARD_ORIGIN.y + float((BoardCoords.BOARD_ROWS - 1) * BoardCoords.CELL_SIZE)) * n
		out.append(Rect2(x, y, float(BoardCoords.CELL_SIZE) * n, float(BoardCoords.CELL_SIZE) * n))
	return out


func _any_intersects(rect: Rect2, cells: Array[Rect2]) -> bool:
	for c: Rect2 in cells:
		if rect.intersects(c):
			return true
	return false


func _fresh_bar() -> HandBar:
	var bar: HandBar = auto_free(load(_SCENE_PATH).instantiate())
	add_child(bar)
	return bar


# ---- F ---------------------------------------------------------------------------------

func test_f_collapsed_hand_avoids_middle_bottom_row_cells_at_all_sizes() -> void:
	for ws: Vector2i in _SIZES:
		var vis: Rect2 = HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS)
		var middle: Array[Rect2] = _bottom_row_cells(ws, true)
		assert_bool(vis.size.x > 0.0 and middle.size() == BoardCoords.BOARD_COLS - 2 * _MIDDLE_COL_MARGIN).append_failure_message(
			"PRECONDITION %s: 背板與中間欄數有效" % ws).is_true()
		assert_bool(_any_intersects(vis, middle)).append_failure_message(
			"%s: 收合手牌 %s 壓到最下一列中間格" % [ws, vis]).is_false()


func test_f_collapsed_hand_does_not_touch_hint_bar_or_action_buttons() -> void:
	for ws: Vector2i in _SIZES:
		var vis: Rect2 = HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS)
		var bar: Rect2 = HudLayout.controls_hint_bg_rect(ws)
		var b0: Rect2 = HudLayout.hud_action_button_rect(ws, 0)
		var b1: Rect2 = HudLayout.hud_action_button_rect(ws, 1)
		assert_bool(bar.has_area() and b0.has_area() and b1.has_area()).append_failure_message(
			"PRECONDITION %s: 說明列與按鈕矩形有面積" % ws).is_true()
		assert_bool(vis.intersects(bar)).append_failure_message("%s: 與說明列相交 %s vs %s" % [ws, vis, bar]).is_false()
		assert_bool(vis.intersects(b0)).append_failure_message("%s: 與按鈕0相交" % ws).is_false()
		assert_bool(vis.intersects(b1)).append_failure_message("%s: 與按鈕1相交" % ws).is_false()
		var safe: Rect2 = HudLayout.safe_rect(ws)
		assert_bool(safe.grow(0.01).encloses(vis)).append_failure_message("%s: 超出安全區" % ws).is_true()


func test_f_collapsed_hand_still_overlaps_some_bottom_row_cells() -> void:
	# 誠實揭露:本修法不是「完全不壓格」。1080p 棋盤滿版,右下角仍是棋盤格。
	var overlaps_any: bool = false
	for ws: Vector2i in _SIZES:
		if _any_intersects(HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS), _bottom_row_cells(ws, false)):
			overlaps_any = true
	assert_bool(overlaps_any).is_true()


func test_sensitivity_proof_f_detector_catches_old_centered_position() -> void:
	# 植入缺陷 = 舊的置中位置(未位移)。偵測器必須判為壓到中間格。
	for ws: Vector2i in _SIZES:
		var centered: Rect2 = HandBar._collapsed_backing_window_rect_unshifted(ws, _MAX_SLOTS)
		assert_bool(_any_intersects(centered, _bottom_row_cells(ws, true))).append_failure_message(
			"%s: 偵測器沒抓到置中缺陷 %s" % [ws, centered]).is_true()


func test_f_node_backing_matches_static_collapsed_rect() -> void:
	var bar: HandBar = _fresh_bar()
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.TEMPORARY_MODIFIER]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL)
	var ws: Vector2i = bar.get_window().size
	var expected: Rect2 = HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS)
	var back: ColorRect = bar.get_child(0) as ColorRect
	var actual: Rect2 = back.get_global_transform() * Rect2(Vector2.ZERO, back.size)
	assert_float(bar.diagnostic_expand_progress()).append_failure_message("PRECONDITION: 收合").is_equal(0.0)
	assert_float(actual.position.x).is_equal_approx(expected.position.x, 0.5)
	assert_float(actual.end.y).is_equal_approx(expected.end.y, 0.5)
	assert_float(actual.size.x).is_equal_approx(expected.size.x, 0.5)


# ---- E1 --------------------------------------------------------------------------------

func _expanded_cards_window(ws: Vector2i, count: int) -> Array[Rect2]:
	var origin: Vector2 = HandBar.expanded_slot_bar_rect(ws, _MAX_SLOTS).position
	var out: Array[Rect2] = []
	for i in range(count):
		var r: Rect2 = HandBar.expanded_slot_rect(i, ws)
		out.append(Rect2(origin + r.position, r.size))
	return out


func test_e1_expanded_backing_encloses_all_cards_at_all_sizes() -> void:
	for ws: Vector2i in _SIZES:
		for count in [_MAX_SLOTS, _MAX_SLOTS + 1]:
			var backing: Rect2 = HandBar.expanded_backing_window_rect(count, ws, _MAX_SLOTS)
			var cards: Array[Rect2] = _expanded_cards_window(ws, count)
			assert_int(cards.size()).append_failure_message("PRECONDITION: 卡片數").is_equal(count)
			for c: Rect2 in cards:
				assert_bool(backing.encloses(c)).append_failure_message(
					"%s/%d張: 背板 %s 未涵蓋卡片 %s" % [ws, count, backing, c]).is_true()


func test_sensitivity_proof_e1_old_fixed_backing_fails_to_enclose_cards() -> void:
	# 植入缺陷 = 舊版固定 Z1 footprint 的背板。偵測器必須判為未涵蓋。
	for ws: Vector2i in _SIZES:
		var origin: Vector2 = HandBar.expanded_slot_bar_rect(ws, _MAX_SLOTS).position
		var old_local: Rect2 = HandBar.backing_rect(_MAX_SLOTS, ws)
		var old_backing: Rect2 = Rect2(origin + old_local.position, old_local.size)
		var all_enclosed: bool = true
		for c: Rect2 in _expanded_cards_window(ws, _MAX_SLOTS):
			if not old_backing.encloses(c):
				all_enclosed = false
		assert_bool(all_enclosed).append_failure_message("%s: 偵測器沒抓到舊背板缺陷" % ws).is_false()


func test_e1_node_backing_at_full_expand_matches_static_rect() -> void:
	var bar: HandBar = _fresh_bar()
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.PERMANENT_WRITE]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL, true)
	bar._set_expand_progress(1.0)
	var ws: Vector2i = bar.get_window().size
	var expected: Rect2 = HandBar.expanded_backing_window_rect(_MAX_SLOTS, ws, _MAX_SLOTS)
	var back: ColorRect = bar.get_child(0) as ColorRect
	var actual: Rect2 = back.get_global_transform() * Rect2(Vector2.ZERO, back.size)
	assert_float(bar.diagnostic_expand_progress()).append_failure_message("PRECONDITION: 已展開").is_equal(1.0)
	assert_float(actual.position.x).is_equal_approx(expected.position.x, 0.5)
	assert_float(actual.position.y).is_equal_approx(expected.position.y, 0.5)
	assert_float(actual.size.x).is_equal_approx(expected.size.x, 0.5)
	assert_float(actual.size.y).is_equal_approx(expected.size.y, 0.5)


# ---- E2 --------------------------------------------------------------------------------

func test_e2_slots_never_rotate_and_adjacent_slots_do_not_overlap() -> void:
	var bar: HandBar = _fresh_bar()
	var kinds: Array[HandBar.SlotKind] = [
		HandBar.SlotKind.PERMANENT_WRITE, HandBar.SlotKind.TEMPORARY_MODIFIER, HandBar.SlotKind.PERMANENT_WRITE,
	]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL, true)
	bar._set_expand_progress(1.0)
	assert_int(bar.diagnostic_slot_node_count()).append_failure_message("PRECONDITION: 卡格已建立").is_equal(_MAX_SLOTS)
	for i in range(bar._slot_nodes.size()):
		assert_float(bar._slot_nodes[i].rotation_degrees).is_equal(0.0)
	for i in range(bar._slot_nodes.size() - 1):
		var a: Rect2 = Rect2(bar._slot_nodes[i].position, bar._slot_nodes[i].size)
		var b: Rect2 = Rect2(bar._slot_nodes[i + 1].position, bar._slot_nodes[i + 1].size)
		assert_bool(a.intersects(b)).append_failure_message("卡格 %d 與 %d 重疊" % [i, i + 1]).is_false()


func test_e2_category_is_kept_as_rotated_icon_on_card_face() -> void:
	var bar: HandBar = _fresh_bar()
	var kinds: Array[HandBar.SlotKind] = [HandBar.SlotKind.PERMANENT_WRITE, HandBar.SlotKind.TEMPORARY_MODIFIER]
	bar.render(kinds, _MAX_SLOTS, HandBar.Availability.NORMAL)
	var perm_icon: ColorRect = bar._slot_nodes[0].get_child(0)
	var temp_icon: ColorRect = bar._slot_nodes[1].get_child(0)
	assert_float(temp_icon.rotation_degrees).append_failure_message("PRECONDITION: 甲類圖示不旋轉").is_equal(0.0)
	assert_float(perm_icon.rotation_degrees).is_equal(45.0)


# ---- N ---------------------------------------------------------------------------------

func test_n_egm_status_label_does_not_overlap_hand_backing_or_panel() -> void:
	for ws: Vector2i in _SIZES:
		var egm: Rect2 = BattleMenu.egm_status_rect(ws)
		var panel: Rect2 = BattleMenu.panel_rect(ws)
		var collapsed: Rect2 = HandBar.collapsed_backing_window_rect(ws, _MAX_SLOTS)
		var expanded: Rect2 = HandBar.expanded_backing_window_rect(_MAX_SLOTS + 1, ws, _MAX_SLOTS)
		assert_bool(egm.has_area() and panel.has_area() and collapsed.has_area()).append_failure_message(
			"PRECONDITION %s" % ws).is_true()
		assert_bool(egm.intersects(collapsed)).append_failure_message("%s: 疊在收合背板" % ws).is_false()
		assert_bool(egm.intersects(expanded)).append_failure_message("%s: 疊在展開背板" % ws).is_false()
		assert_bool(egm.intersects(panel)).append_failure_message("%s: 疊在選單面板" % ws).is_false()
		assert_bool(HudLayout.safe_rect(ws).encloses(egm)).append_failure_message("%s: 超出安全區" % ws).is_true()
