# Story 054 接線整合測試 —— 走真實 BattleScreen.tscn:
# 被「結束角色行動」的我方單位,畫面上必須「棋子變暗」,且鞋/劍圖示只反映真正用過的旗標。
#
# 屬性:甲類(讀 assets/data/ 底下已進版控的真實關卡/名冊,唯讀,不寫檔);沿用同目錄
# battle_screen_enemy_phase_playback_test.gd 的先例(載入真實 BattleScreen.tscn 是唯一能觀察
# battle_screen.gd 傳給 BoardView 的欄位的方式)。不證明窮盡:只驅動 vs01 名冊的第 1 位我方單位。
#
# 敏感度證明(mutant):在 BoardView 節點進樹前換成「丟掉 done/move_used/attack_used 三欄」的
# 子類別,等效於「battle_screen 沒把這三欄傳進 render_pieces」。Case A(進樹前 set_script)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _BOARD_VIEW_PATH: String = "WorldViewportContainer/WorldViewport/BoardView"
const _UNIT_ID: int = 1

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


# mutant:模擬 battle_screen 沒傳三個新欄位(欄位在傳入 render_pieces 的途中被丟掉)
class _StripNewFieldsBoardView extends BoardView:
	func render_pieces(pieces: Array[Dictionary]) -> void:
		var stripped: Array[Dictionary] = []
		for p: Dictionary in pieces:
			var q: Dictionary = p.duplicate()
			q.erase("done")
			q.erase("move_used")
			q.erase("attack_used")
			stripped.append(q)
		super.render_pieces(stripped)


func _make_screen(strip_fields: bool) -> BattleScreen:
	var screen: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	if strip_fields:
		screen.get_node(_BOARD_VIEW_PATH).set_script(_StripNewFieldsBoardView)
	add_child(screen)
	return screen


func _piece_modulate_for_first_player(screen: BattleScreen) -> Color:
	# 我方單位依名冊順序、cell y 遞增畫出;以位置找對應 sprite 太繞,改用「任一棋子 Sprite
	# 的 modulate 集合」不夠精確 —— 所以直接找 PiecesLayer 中 position 等於該單位格錨點者。
	var board: BoardView = screen.get_node(_BOARD_VIEW_PATH)
	var cell: Vector2i = screen._state.position_of(_UNIT_ID)
	var anchor: Vector2 = board._piece_anchor(cell)
	for s: Node in board.get_node("PiecesLayer").get_children():
		if (s as Sprite2D).position == anchor:
			return (s as Sprite2D).modulate
	return Color(-1.0, -1.0, -1.0, -1.0)


func _icon_names_for_unit(screen: BattleScreen) -> Array[String]:
	var board: BoardView = screen.get_node(_BOARD_VIEW_PATH)
	var cell: Vector2i = screen._state.position_of(_UNIT_ID)
	var origin: Vector2 = BoardCoords.grid_to_local(cell)
	var names: Array[String] = []
	var layer: Node = board.get_node("ActionFlagLayer")
	var stack: Array[Node] = [layer]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Sprite2D and (n as Sprite2D).position.y < origin.y \
				and absf((n as Sprite2D).position.x - origin.x) < BoardCoords.CELL_SIZE:
			names.append(String(n.name))
		stack.append_array(n.get_children())
	names.sort()
	return names


# 觀測:結束(未移動未攻擊)後的 (modulate, 圖示)。
func _ended_without_acting(screen: BattleScreen) -> Array:
	assert_bool(screen._controller.select_unit(_UNIT_ID)).is_true()
	screen._perform_end_unit_turn()
	return [_piece_modulate_for_first_player(screen), _icon_names_for_unit(screen)]


# 觀測:只移動後結束。
func _moved_then_ended(screen: BattleScreen) -> Array:
	assert_bool(screen._controller.select_unit(_UNIT_ID)).is_true()
	var cells: Array[Vector2i] = screen._controller.move_targets().cells
	assert_bool(cells.is_empty()).is_false()
	screen._controller.click_tile(cells[0])
	screen._refresh_view()
	# 防空洞:移動後、結束前,單位未做完 → 不暗,且只有鞋
	assert_object(_piece_modulate_for_first_player(screen)).is_equal(Color.WHITE)
	assert_array(_icon_names_for_unit(screen)).is_equal(["ShoeIcon"])
	assert_bool(screen._controller.select_unit(_UNIT_ID)).is_true()
	screen._perform_end_unit_turn()
	return [_piece_modulate_for_first_player(screen), _icon_names_for_unit(screen)]


func _dim() -> Color:
	var c: float = BoardView.DONE_PIECE_DIM
	return Color(c, c, c, 1.0)


func test_battle_screen_ended_without_acting_dims_piece_and_draws_no_icons() -> void:
	var screen: BattleScreen = _make_screen(false)
	# 防空洞:開局未做完 → 不暗、無圖示
	assert_object(_piece_modulate_for_first_player(screen)).is_equal(Color.WHITE)
	assert_array(_icon_names_for_unit(screen)).is_empty()
	var observed: Array = _ended_without_acting(screen)
	assert_object(observed[0]).is_equal(_dim())
	assert_array(observed[1]).is_empty()


func test_battle_screen_moved_then_ended_dims_piece_and_draws_only_shoe() -> void:
	var screen: BattleScreen = _make_screen(false)
	var observed: Array = _moved_then_ended(screen)
	assert_object(observed[0]).is_equal(_dim())
	assert_array(observed[1]).is_equal(["ShoeIcon"])


func test_sensitivity_proof_screen_not_passing_new_fields_detected() -> void:
	# mutant 下,「結束未行動」應偏離預期(實機會變成:action_flag=DONE → 變暗仍成立,
	# 但圖示變成鞋+劍)—— 偵測的是圖示差異。
	var screen: BattleScreen = _make_screen(true)
	var observed: Array = _ended_without_acting(screen)
	assert_bool((observed[1] as Array).is_empty()).append_failure_message(
		"mutant 丟掉三欄後,被結束的單位應被畫成鞋+劍(偏離預期的空集合),實得 %s" % [observed[1]]
	).is_false()
