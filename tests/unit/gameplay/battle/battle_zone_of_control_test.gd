# BattleState 層的阻擋規則(Zone of Control)測試 —— AC-2a 的 ZoC-5 ~ ZoC-9。
# 來源:production/epics/tactical-combat/story-027-zone-of-control-missing-tests.md;
# 規格:design/gdd/tactical-combat-system.md Core Rules #2a / AC-2a。
# Story 類型:Logic / BLOCKING。ZoC-1~4(Board 層)在
# tests/unit/gameplay/board/board_zone_of_control_test.gd,本檔不重複。
#
# 本檔不讀任何檔案:地形與名冊都是檔內常數(開闊 13x6 棋盤 + 內嵌 CSV),不屬任何檔案 I/O 例外。
#
# 共用盤面(皆為開闊地形,每格成本 1,MP 4):
#   佈局 B(敵方被擋):敵 id2 在 (0,0),我方 id1 在 (3,1)。
#     我方阻擋區 = (3,0)(2,1)(4,1)(3,2)。(4,0) 只能沿 y=0 經 (3,0) 抵達 —— (3,1) 被佔位、
#     繞下方要 >4 步 —— 所以無阻擋時 4 步可達、有阻擋時不可達。
#   佈局 A(我方不被擋):把兩邊陣營對調 —— 我方在 (0,0)、敵方在 (3,1)。
#
# 敏感度證明:本檔不含常駐 test_sensitivity_* 測試(要常駐須間諜子類別,而被測的
# legal_moves / zone_of_control_cells 是 BattleState 自己的方法,測試無法在不改正式程式下替換它們,
# 屬 test-standards.md 的 D 類「唯一注入點在受限範圍外」)。ZoC-5、ZoC-7 的敏感度證明是
# 交付當下的手動注入(改壞正式程式→轉紅→改回),輸出記在回報中,版本庫不留痕跡。
extends GdUnitTestSuite

const _PLAYER_ID: int = 1
const _ENEMY_ID: int = 2
const _MP: int = 4


# id,code_name,faction,hp_max,atk,def,mp,min_range,max_range,start_x,start_y
func _roster_line(id: int, faction: String, pos: Vector2i) -> String:
	return "%d,U%d,%s,30,5,5,%d,1,1,%d,%d\n" % [id, id, faction, _MP, pos.x, pos.y]


func _open_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		rows.append(".............")
	return rows


func _state(roster_text: String) -> BattleState:
	return BattleState.create(_open_rows(), roster_text)


## 佈局 B:敵方在 (0,0),我方在 (3,1)。
func _layout_enemy_blocked() -> BattleState:
	return _state(
		_roster_line(_PLAYER_ID, "PLAYER", Vector2i(3, 1)) + _roster_line(_ENEMY_ID, "ENEMY", Vector2i(0, 0))
	)


## 佈局 A:我方在 (0,0),敵方在 (3,1)。
func _layout_player_unblocked() -> BattleState:
	return _state(
		_roster_line(_PLAYER_ID, "PLAYER", Vector2i(0, 0)) + _roster_line(_ENEMY_ID, "ENEMY", Vector2i(3, 1))
	)


# ---------------------------------------------------------------- ZoC-5

func test_zoc5_player_unit_is_not_blocked_by_adjacent_enemy() -> void:
	# Arrange
	var state: BattleState = _layout_player_unblocked()
	var past_enemy_zone: Vector2i = Vector2i(4, 0)
	var enemy_adjacent: Vector2i = Vector2i(3, 0)
	# 前提:阻擋區若套用在我方身上,(3,0) 本會是阻擋格(敵人在 (3,1) 的正上方)
	assert_bool(state.zone_of_control_cells(Unit.Faction.ENEMY).has(enemy_adjacent)).append_failure_message(
		"前提失敗:(3,0) 應在敵方單位的四向鄰格內"
	).is_true()

	# Act
	var moves: Array[Vector2i] = state.legal_moves(_PLAYER_ID)

	# Assert
	assert_bool(moves.has(enemy_adjacent)).append_failure_message("我方可進入敵人鄰格").is_true()
	assert_bool(moves.has(past_enemy_zone)).append_failure_message(
		"我方 4 步經 (3,0) 抵達 (4,0):不受敵方阻擋,應可達"
	).is_true()


func test_zoc5_player_legal_moves_equal_unrestricted_reach() -> void:
	# Arrange
	var state: BattleState = _layout_player_unblocked()

	# Act:legal_moves_relaxed(false,false) 不帶阻擋區,是「無阻擋」基準
	var moves: Array[Vector2i] = state.legal_moves(_PLAYER_ID)
	var baseline: Array[Vector2i] = state.legal_moves_relaxed(_PLAYER_ID, false, false)

	# Assert
	assert_int(baseline.size()).append_failure_message("前提失敗:基準可達集合不應為空").is_greater(0)
	assert_array(moves).contains_exactly_in_any_order(baseline)


func test_zoc5_enemy_unit_is_blocked_by_adjacent_player_control_group() -> void:
	# Arrange(對照組:同一幾何、陣營對調)
	var state: BattleState = _layout_enemy_blocked()
	var baseline: Array[Vector2i] = state.legal_moves_relaxed(_ENEMY_ID, false, false)
	# 前提:無阻擋時 (4,0) 可達
	assert_bool(baseline.has(Vector2i(4, 0))).append_failure_message("前提失敗:無阻擋時 (4,0) 應可達").is_true()

	# Act
	var moves: Array[Vector2i] = state.legal_moves(_ENEMY_ID)

	# Assert
	assert_bool(moves.has(Vector2i(3, 0))).append_failure_message("敵方可進入阻擋格").is_true()
	assert_bool(moves.has(Vector2i(4, 0))).append_failure_message("敵方不可穿越阻擋格 (3,0)").is_false()


# ---------------------------------------------------------------- ZoC-6

func test_zoc6_zone_contains_only_four_orthogonal_neighbours() -> void:
	# Arrange — 我方在棋盤中央附近 (5,2)
	var state: BattleState = _state(_roster_line(_PLAYER_ID, "PLAYER", Vector2i(5, 2)))

	# Act
	var zone: Dictionary = state.zone_of_control_cells(Unit.Faction.PLAYER)

	# Assert
	assert_int(zone.size()).is_equal(4)
	for cell: Vector2i in [Vector2i(5, 1), Vector2i(5, 3), Vector2i(4, 2), Vector2i(6, 2)]:
		assert_bool(zone.has(cell)).append_failure_message("四向鄰格 %s 應在阻擋區" % cell).is_true()
	for diagonal: Vector2i in [Vector2i(4, 1), Vector2i(6, 1), Vector2i(4, 3), Vector2i(6, 3)]:
		assert_bool(zone.has(diagonal)).append_failure_message("斜角格 %s 不應在阻擋區" % diagonal).is_false()
	assert_bool(zone.has(Vector2i(5, 2))).append_failure_message("單位自己的格子不屬阻擋區").is_false()


func test_zoc6_corner_unit_zone_excludes_out_of_bounds_cells() -> void:
	# Arrange — 左上角 (0,0) 與右下角 (12,5),兩個單位各自只剩 2 個棋盤內鄰格
	var state: BattleState = _state(
		_roster_line(_PLAYER_ID, "PLAYER", Vector2i(0, 0))
		+ _roster_line(3, "PLAYER", Vector2i(Board.BOARD_WIDTH - 1, Board.BOARD_HEIGHT - 1))
	)

	# Act
	var zone: Dictionary = state.zone_of_control_cells(Unit.Faction.PLAYER)

	# Assert
	var expected: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(Board.BOARD_WIDTH - 2, Board.BOARD_HEIGHT - 1), Vector2i(Board.BOARD_WIDTH - 1, Board.BOARD_HEIGHT - 2),
	]
	assert_array(zone.keys()).contains_exactly_in_any_order(expected)
	for cell: Vector2i in zone.keys():
		assert_bool(state.board.is_in_bounds(cell)).append_failure_message("阻擋區不得含棋盤外格 %s" % cell).is_true()


func test_zoc6_diagonal_cell_does_not_stop_enemy() -> void:
	# Arrange — 我方 (3,1),敵方 (0,0) MP4。(2,0) 是我方的斜角格(非阻擋格),(3,0) 才是。
	var state: BattleState = _layout_enemy_blocked()
	var diagonal: Vector2i = Vector2i(2, 0)
	assert_bool(state.zone_of_control_cells(Unit.Faction.PLAYER).has(diagonal)).append_failure_message(
		"前提失敗:(2,0) 為斜角格,不應在阻擋區"
	).is_false()

	# Act
	var moves: Array[Vector2i] = state.legal_moves(_ENEMY_ID)

	# Assert:(0,0)->(1,0)->(2,0)->(3,0) 共 3 步,若斜角格 (2,0) 被當成阻擋格,(3,0) 就會不可達
	assert_bool(moves.has(diagonal)).append_failure_message("敵方可進入斜角格").is_true()
	assert_bool(moves.has(Vector2i(3, 0))).append_failure_message(
		"斜角格不是阻擋格,可從其繼續走到 (3,0)(阻擋格,作終點)"
	).is_true()


# ---------------------------------------------------------------- ZoC-7

func test_zoc7_dead_player_unit_produces_no_zone() -> void:
	# Arrange
	var state: BattleState = _layout_enemy_blocked()
	# 前提:存活時有阻擋區,且 (4,0) 被截斷
	assert_bool(state.zone_of_control_cells(Unit.Faction.PLAYER).has(Vector2i(3, 0))).append_failure_message(
		"前提失敗:存活時 (3,0) 應在阻擋區"
	).is_true()
	assert_bool(state.legal_moves(_ENEMY_ID).has(Vector2i(4, 0))).append_failure_message(
		"前提失敗:存活時 (4,0) 應被阻擋截斷"
	).is_false()

	# Act
	state.unit_by_id(_PLAYER_ID).take_damage(999)

	# Assert
	assert_bool(state.unit_by_id(_PLAYER_ID).is_alive()).append_failure_message("前提失敗:應已陣亡").is_false()
	assert_bool(state.zone_of_control_cells(Unit.Faction.PLAYER).is_empty()).append_failure_message(
		"陣亡後阻擋區應為空"
	).is_true()
	assert_bool(state.legal_moves(_ENEMY_ID).has(Vector2i(4, 0))).append_failure_message(
		"陣亡後 (4,0) 不再被截斷(沿 y=0 不經佔位格)"
	).is_true()


func test_zoc7_only_the_dead_unit_zone_disappears() -> void:
	# Arrange — 兩名我方,其一陣亡:另一名的阻擋區仍在
	var state: BattleState = _state(
		_roster_line(_PLAYER_ID, "PLAYER", Vector2i(3, 1)) + _roster_line(3, "PLAYER", Vector2i(9, 4))
	)
	assert_int(state.zone_of_control_cells(Unit.Faction.PLAYER).size()).append_failure_message(
		"前提失敗:兩名存活時共 8 格(兩區不重疊)"
	).is_equal(8)

	# Act
	state.unit_by_id(_PLAYER_ID).take_damage(999)
	var zone: Dictionary = state.zone_of_control_cells(Unit.Faction.PLAYER)

	# Assert
	assert_int(zone.size()).is_equal(4)
	assert_bool(zone.has(Vector2i(9, 3))).is_true()
	assert_bool(zone.has(Vector2i(3, 0))).is_false()


# ---------------------------------------------------------------- ZoC-8

func test_zoc8_overlapping_zones_are_deduplicated() -> void:
	# Arrange — 我方 (3,1) 與 (5,1):兩區重疊於 (4,1)
	var state: BattleState = _state(
		_roster_line(_PLAYER_ID, "PLAYER", Vector2i(3, 1)) + _roster_line(3, "PLAYER", Vector2i(5, 1))
	)
	var single: BattleState = _state(_roster_line(_PLAYER_ID, "PLAYER", Vector2i(3, 1)))
	# 前提:單一單位時 (4,1) 在阻擋區、區大小 4
	assert_int(single.zone_of_control_cells(Unit.Faction.PLAYER).size()).append_failure_message("前提失敗").is_equal(4)
	assert_bool(single.zone_of_control_cells(Unit.Faction.PLAYER).has(Vector2i(4, 1))).is_true()

	# Act
	var zone: Dictionary = state.zone_of_control_cells(Unit.Faction.PLAYER)

	# Assert:4 + 4 - 1 重疊 = 7
	assert_int(zone.size()).is_equal(7)
	assert_bool(zone.has(Vector2i(4, 1))).is_true()


func test_zoc8_overlap_cell_behaves_like_single_stop_cell() -> void:
	# Arrange — 敵方 (4,5) MP5、我方 (3,1)/(5,1)。(4,0) 的三個鄰格 (3,0)(5,0)(4,1) 全是阻擋格,
	# 進得去就出不來 → 不可達;(4,1) 是重疊格,可進入。
	var state: BattleState = _state(
		_roster_line(_PLAYER_ID, "PLAYER", Vector2i(3, 1))
		+ _roster_line(3, "PLAYER", Vector2i(5, 1))
		+ "%d,E,ENEMY,30,5,5,5,1,1,4,5\n" % _ENEMY_ID
	)
	var baseline: Array[Vector2i] = state.legal_moves_relaxed(_ENEMY_ID, false, false)
	assert_bool(baseline.has(Vector2i(4, 0))).append_failure_message("前提失敗:無阻擋時 (4,0) 5 步可達").is_true()
	assert_bool(baseline.has(Vector2i(4, 1))).append_failure_message("前提失敗:無阻擋時 (4,1) 可達").is_true()

	# Act
	var moves: Array[Vector2i] = state.legal_moves(_ENEMY_ID)

	# Assert
	assert_bool(moves.has(Vector2i(4, 1))).append_failure_message("重疊阻擋格可進入").is_true()
	assert_bool(moves.has(Vector2i(4, 0))).append_failure_message("不可穿越重疊阻擋格").is_false()


# ---------------------------------------------------------------- ZoC-9

func test_zoc9_move_unit_rejects_destination_beyond_stop_cell() -> void:
	# Arrange
	var state: BattleState = _layout_enemy_blocked()
	var dest: Vector2i = Vector2i(4, 0)
	# 前提:無阻擋時 (4,0) 在放寬版可達集合內(證明被拒絕的原因是阻擋規則,不是 MP 不足)
	assert_bool(state.legal_moves_relaxed(_ENEMY_ID, false, false).has(dest)).append_failure_message(
		"前提失敗:無阻擋時 (4,0) 應可達"
	).is_true()
	var version_before: int = state.combat_state_version

	# Act
	var accepted: bool = state.move_unit(_ENEMY_ID, dest)

	# Assert
	assert_bool(accepted).append_failure_message("move_unit 應拒絕穿越阻擋格的目的地").is_false()
	assert_that(state.position_of(_ENEMY_ID)).is_equal(Vector2i(0, 0))
	assert_int(state.combat_state_version).append_failure_message("拒絕不得遞增版本號").is_equal(version_before)


func test_zoc9_move_unit_accepts_the_stop_cell_itself() -> void:
	# Arrange(對照組:阻擋格本身可作終點)
	var state: BattleState = _layout_enemy_blocked()

	# Act
	var accepted: bool = state.move_unit(_ENEMY_ID, Vector2i(3, 0))

	# Assert
	assert_bool(accepted).is_true()
	assert_that(state.position_of(_ENEMY_ID)).is_equal(Vector2i(3, 0))
