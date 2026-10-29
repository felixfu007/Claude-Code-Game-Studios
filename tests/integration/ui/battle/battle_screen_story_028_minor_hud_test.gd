extends GdUnitTestSuite

# Story 028(試玩次要問題)I / M / G 的結構斷言。N / O 見該工作單回報(未做時不在此檔)。
# 檔案存取:無(不屬甲/乙類例外)。
# 敏感度:I、G 各有一條常駐 test_sensitivity_proof_*(偵測器抓得到植入的缺陷);
# 另有手動注入驗證記錄在交付回報。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _MIN_WINDOW: Vector2i = Vector2i(960, 540)
const _BIG_WINDOW: Vector2i = Vector2i(1920, 1080)

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	get_tree().paused = false


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _count_fills(layer: Node, color: Color) -> int:
	var n: int = 0
	for child: Node in layer.get_children():
		if child is ColorRect and (child as ColorRect).color == color:
			n += 1
	return n


# ---- I:移動範圍亮藍半透明 ---------------------------------------------------------

func test_move_highlight_draws_one_blue_translucent_fill_per_cell() -> void:
	var instance: BattleScreen = _fresh_instance()
	var layer: Node2D = instance._board_view.get_node("MoveHighlightLayer")
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1)]

	instance._board_view.set_move_highlights(cells)

	assert_int(layer.get_child_count()).append_failure_message("PRECONDITION: 每格應有貼圖+填色共 2 個子節點").is_equal(6)
	assert_int(_count_fills(layer, BoardView.MOVE_FILL_COLOR)).is_equal(cells.size())
	assert_float(BoardView.MOVE_FILL_COLOR.a).is_between(0.2, 0.6)
	assert_bool(BoardView.MOVE_FILL_COLOR.b > BoardView.MOVE_FILL_COLOR.r and BoardView.MOVE_FILL_COLOR.b > BoardView.MOVE_FILL_COLOR.g).is_true()


func test_move_highlight_repeated_calls_do_not_accumulate_or_crash() -> void:
	# 覆核疑點:迴圈內 add_child(ColorRect),第二次呼叫是否會把 ColorRect 當 Sprite2D 轉型。
	var instance: BattleScreen = _fresh_instance()
	var layer: Node2D = instance._board_view.get_node("MoveHighlightLayer")
	var first: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 1)]
	var second: Array[Vector2i] = [Vector2i(5, 3), Vector2i(6, 3)]
	instance._board_view.set_move_highlights(first)
	assert_int(_count_fills(layer, BoardView.MOVE_FILL_COLOR)).append_failure_message("PRECONDITION: 第一次呼叫後填色數 == 3").is_equal(3)

	instance._board_view.set_move_highlights(second)

	assert_int(_count_fills(layer, BoardView.MOVE_FILL_COLOR)).is_equal(second.size())
	assert_int(layer.get_child_count()).is_equal(second.size() * 2)
	instance._board_view.set_move_highlights([] as Array[Vector2i])
	assert_int(layer.get_child_count()).is_equal(0)


func test_threat_fill_color_is_unchanged_red() -> void:
	assert_object(BoardView.THREAT_FILL_COLOR).is_equal(Color(0.85, 0.15, 0.1, 0.3))


func test_sensitivity_proof_move_fill_detector_rejects_non_blue_fill() -> void:
	# 偵測器(藍色主導判斷)抓得到「灰底」缺陷。
	var gray: Color = Color(0.3, 0.3, 0.3, 0.4)
	assert_bool(gray.b > gray.r and gray.b > gray.g).is_false()


# ---- M:按鈕平常就有底色與外框 -------------------------------------------------------

func test_hud_action_buttons_have_resting_background_and_border() -> void:
	var instance: BattleScreen = _fresh_instance()
	for button: Button in [instance._hand_button, instance._menu_button]:
		assert_object(button).append_failure_message("PRECONDITION: 按鈕存在").is_not_null()
		var style: StyleBox = button.get_theme_stylebox(&"normal")
		assert_bool(style is StyleBoxFlat).is_true()
		var flat: StyleBoxFlat = style as StyleBoxFlat
		assert_int(flat.border_width_left).is_greater(0)
		assert_float(flat.bg_color.a).is_greater(0.0)
		assert_object(flat.border_color).is_equal(BattleScreen.HUD_BUTTON_BORDER_COLOR)


# ---- G:小視窗說明列不蓋棋盤最下一列 ---------------------------------------------------

func _board_bottom_at_min_window() -> float:
	# 960x540 時世界層從 (0,0) 起、倍率 N,棋盤底 = (原點y + 列數*格)*N。
	var n: int = WorldLayout.compute_scale(_MIN_WINDOW)
	return (BoardCoords.BOARD_ORIGIN.y + BoardCoords.BOARD_ROWS * BoardCoords.CELL_SIZE) * float(n)


func _bar_overlaps_board(bar: Rect2, board_bottom: float) -> bool:
	return bar.position.y < board_bottom


func test_min_window_hint_bar_does_not_cover_bottom_board_row() -> void:
	var bar: Rect2 = HudLayout.controls_hint_bg_rect(_MIN_WINDOW)
	assert_bool(HudLayout.is_compact_hint_bar(_MIN_WINDOW)).append_failure_message("PRECONDITION: 960x540 應為單行模式").is_true()
	assert_bool(_bar_overlaps_board(bar, _board_bottom_at_min_window())).append_failure_message(
		"說明列頂 %s 不應高於棋盤底 %s" % [bar.position.y, _board_bottom_at_min_window()]).is_false()


func test_min_window_buttons_stay_inside_bar_and_do_not_overlap_each_other() -> void:
	var bar: Rect2 = HudLayout.controls_hint_bg_rect(_MIN_WINDOW)
	var a: Rect2 = HudLayout.hud_action_button_rect(_MIN_WINDOW, 0)
	var b: Rect2 = HudLayout.hud_action_button_rect(_MIN_WINDOW, 1)
	assert_bool(bar.encloses(a) and bar.encloses(b)).is_true()
	assert_bool(a.intersects(b)).is_false()
	assert_float(a.size.y).is_greater_equal(float(HudLayout.font_size(_MIN_WINDOW)))


func test_min_window_compact_hint_text_fits_left_of_buttons() -> void:
	var instance: BattleScreen = _fresh_instance()
	var full: String = Loc.localize(BattleScreen.TEXT_CONTROLS_HINT)
	var compact: String = HudLayout.compact_hint_text(full)
	assert_bool(compact.is_empty() or compact.contains("\n")).append_failure_message("單行文字不得含換行且非空").is_false()
	var font: Font = HudLayoutScaler.HUD_FONT
	var width: float = font.get_string_size(compact, HORIZONTAL_ALIGNMENT_LEFT, -1, HudLayout.font_size(_MIN_WINDOW)).x
	var bar: Rect2 = HudLayout.controls_hint_bg_rect(_MIN_WINDOW)
	var left_button: Rect2 = HudLayout.hud_action_button_rect(_MIN_WINDOW, 1)
	assert_float(bar.position.x + width).is_less(left_button.position.x)
	assert_object(instance).is_not_null()


func test_large_window_keeps_two_line_hint_bar_and_stacked_buttons() -> void:
	assert_bool(HudLayout.is_compact_hint_bar(_BIG_WINDOW)).append_failure_message("PRECONDITION: 1920x1080 不是單行模式").is_false()
	var bar: Rect2 = HudLayout.controls_hint_bg_rect(_BIG_WINDOW)
	var fpx: float = float(HudLayout.font_size(_BIG_WINDOW))
	assert_float(bar.size.y).is_equal_approx(fpx * HudLayout.CONTROLS_HINT_BG_HEIGHT_MULTIPLIER, 0.01)
	var a: Rect2 = HudLayout.hud_action_button_rect(_BIG_WINDOW, 0)
	var b: Rect2 = HudLayout.hud_action_button_rect(_BIG_WINDOW, 1)
	assert_float(a.position.x).is_equal_approx(b.position.x, 0.01)


func test_sensitivity_proof_overlap_detector_catches_two_line_bar_at_min_window() -> void:
	# 植入缺陷:小視窗仍用兩行高度。偵測器必須判為蓋住。
	var safe: Rect2 = HudLayout.safe_rect(_MIN_WINDOW)
	var fpx: float = float(HudLayout.font_size(_MIN_WINDOW))
	var h: float = fpx * HudLayout.CONTROLS_HINT_BG_HEIGHT_MULTIPLIER
	var bad_bar: Rect2 = Rect2(safe.position.x, safe.end.y - h, safe.size.x, h)
	assert_bool(_bar_overlaps_board(bad_bar, _board_bottom_at_min_window())).is_true()


# ---- O:敵方回合不留游標空框 -----------------------------------------------------------

func test_cursor_box_hidden_during_enemy_phase_and_shown_in_player_phase() -> void:
	var instance: BattleScreen = _fresh_instance()
	instance._update_cursor_visual()
	assert_bool(instance._board_view._cursor_sprite.visible).append_failure_message(
		"PRECONDITION: 我方回合游標應顯示").is_true()

	instance._controller.end_faction_phase()
	assert_int(instance._controller.phase()).append_failure_message(
		"PRECONDITION: 應已進入敵方行動").is_equal(BattleController.Phase.ENEMY_ACTING)
	instance._update_cursor_visual()

	assert_bool(instance._board_view._cursor_sprite.visible).is_false()
