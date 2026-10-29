# Story 024 —— 右上資訊框只在游標指到單位時出現。
#
# 手法:載入真實 BattleScreen.tscn(production 場景檔),進樹後直接設定
# _cursor_active / _tile_info_cursor_valid / _cursor_cell 三個欄位並呼叫
# _update_tile_info_panel(),讀 _tile_info_panel_bg.visible。headless 下引擎不送
# InputEvent,所以不能靠真實游標移動;這三個欄位正是 _refresh_view() 實際讀的來源。
# 單位格/空地格由場景自己載入的 _state 動態找出(不寫死座標)。
#
# 前提斷言:每條測試先斷言「選到的格確實有/沒有單位」,避免前提不成立時照樣綠。
# 敏感度:已手動注入(見交付報告),本檔不含常駐間諜子類別;
# tile_info_panel_should_show() 是 static 純函式(A 類,無繼承鏈可覆寫)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _make_screen() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _find_cell(screen: BattleScreen, want_occupied: bool) -> Vector2i:
	for row: int in range(BoardCoords.BOARD_ROWS):
		for col: int in range(BoardCoords.BOARD_COLS):
			var cell: Vector2i = Vector2i(col, row)
			if (screen._state.unit_at(cell) != null) == want_occupied:
				return cell
	return Vector2i(-1, -1)


func _point_cursor(screen: BattleScreen, cell: Vector2i) -> void:
	screen._cursor_cell = cell
	screen._cursor_active = true
	screen._tile_info_cursor_valid = true
	screen._update_tile_info_panel()


# ---- 純函式 --------------------------------------------------------------

func test_should_show_only_when_resolved_occupied_and_not_enemy_acting() -> void:
	assert_bool(BattleScreen.tile_info_panel_should_show(true, true, false)).is_true()
	assert_bool(BattleScreen.tile_info_panel_should_show(true, false, false)).is_false()
	assert_bool(BattleScreen.tile_info_panel_should_show(false, true, false)).is_false()
	assert_bool(BattleScreen.tile_info_panel_should_show(true, true, true)).is_false()


# ---- AC1 ---------------------------------------------------------------

func test_ac1_cursor_on_unit_shows_panel_with_content() -> void:
	var screen: BattleScreen = _make_screen()
	var cell: Vector2i = _find_cell(screen, true)
	assert_bool(screen._state.unit_at(cell) != null).is_true() # 前提:該格真的有單位

	_point_cursor(screen, cell)

	assert_bool(screen._tile_info_panel_bg.visible).is_true()
	assert_bool(screen._tile_info_panel_label.text.is_empty()).is_false()


func test_ac1_cursor_on_enemy_unit_also_shows_panel() -> void:
	var screen: BattleScreen = _make_screen()
	var cell: Vector2i = Vector2i(-1, -1)
	for row: int in range(BoardCoords.BOARD_ROWS):
		for col: int in range(BoardCoords.BOARD_COLS):
			var u: Unit = screen._state.unit_at(Vector2i(col, row))
			if u != null and u.faction == Unit.Faction.ENEMY:
				cell = Vector2i(col, row)
	assert_bool(cell != Vector2i(-1, -1)).is_true() # 前提:場上有敵方單位

	_point_cursor(screen, cell)

	assert_bool(screen._tile_info_panel_bg.visible).is_true()


# ---- AC2 ---------------------------------------------------------------

func test_ac2_cursor_on_empty_tile_hides_panel() -> void:
	var screen: BattleScreen = _make_screen()
	var occupied: Vector2i = _find_cell(screen, true)
	var empty: Vector2i = _find_cell(screen, false)
	assert_bool(screen._state.unit_at(empty) == null).is_true() # 前提:空地真的沒單位
	# 先指到單位讓框顯示,證明「隱藏」是這次切換造成的,不是初始值
	_point_cursor(screen, occupied)
	assert_bool(screen._tile_info_panel_bg.visible).is_true()

	_point_cursor(screen, empty)

	assert_bool(screen._tile_info_panel_bg.visible).is_false()


func test_ac2_cursor_off_board_hides_panel_even_if_cell_has_unit() -> void:
	var screen: BattleScreen = _make_screen()
	var occupied: Vector2i = _find_cell(screen, true)
	_point_cursor(screen, occupied)
	assert_bool(screen._tile_info_panel_bg.visible).is_true()

	screen._cursor_active = false
	screen._update_tile_info_panel()

	assert_bool(screen._tile_info_panel_bg.visible).is_false()
