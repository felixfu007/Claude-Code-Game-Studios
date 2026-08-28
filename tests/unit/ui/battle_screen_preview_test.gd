# BattleScreen 游標預覽那一組純函式的測試。
#
# 預覽本身要有游標事件才跑得起來,而 headless 下引擎不送 InputEvent
# (見 .claude/docs/coding-standards.md),所以 _refresh_view() 沒辦法在這裡直接測。
# 能測的是它拆出來的六個 static 純函式:狀態→顏色的對應、線段端點的組裝、
# 傷害後血量的下限,以及三個顯示字串的格式。這些函式不碰節點、不碰場景樹,
# 每一個都自己建自己拆,不留孤兒節點。
#
# 其中 affinity_line_dicts() 那兩個案例是整批工作的核心行為縮影:端點一律從
# 傳進來的 positions 取,所以傳一份「假設的」座標表進去,回來的線就會落在
# 假設的位置上 —— 這正是游標移動時線會跟著甩過去的原因。
#
# 命名慣例依 tests/unit/ui/battle_screen_cursor_test.gd 先例。
extends GdUnitTestSuite

# 兩個互不相鄰的固定座標,單純當「可辨識的端點」用,與棋盤規則無關。
const CELL_A: Vector2i = Vector2i(2, 1)
const CELL_B: Vector2i = Vector2i(5, 4)
const CELL_HYPOTHETICAL: Vector2i = Vector2i(9, 0)

const UNIT_A: int = 1
const UNIT_B: int = 2
const UNIT_ABSENT: int = 99


# 造一個 AffinityLineStatus,不經過檔案也不經過 BattleState。
func _status(
	from_unit: int, to_unit: int, state: AffinityLineStatus.State
) -> AffinityLineStatus:
	var s: AffinityLineStatus = AffinityLineStatus.new()
	s.unit_id = from_unit
	s.partner_id = to_unit
	s.polarity = AffinityLink.Polarity.POSITIVE
	s.distance = 1
	s.delta = 0
	s.state = state
	return s


func test_positive_state_maps_to_positive_tone() -> void:
	assert_int(BattleScreen.line_tone_for(AffinityLineStatus.State.POSITIVE)).is_equal(
		BoardView.LineTone.POSITIVE
	)


func test_negative_state_maps_to_negative_tone() -> void:
	assert_int(BattleScreen.line_tone_for(AffinityLineStatus.State.NEGATIVE)).is_equal(
		BoardView.LineTone.NEGATIVE
	)


func test_neutral_state_maps_to_muted_tone() -> void:
	assert_int(BattleScreen.line_tone_for(AffinityLineStatus.State.NEUTRAL)).is_equal(
		BoardView.LineTone.MUTED
	)


func test_suppressed_state_maps_to_muted_tone() -> void:
	assert_int(BattleScreen.line_tone_for(AffinityLineStatus.State.SUPPRESSED)).is_equal(
		BoardView.LineTone.MUTED
	)


func test_line_dicts_read_endpoints_from_given_positions() -> void:
	# Arrange
	var positions: Dictionary[int, Vector2i] = {UNIT_A: CELL_A, UNIT_B: CELL_B}
	var statuses: Array[AffinityLineStatus] = [
		_status(UNIT_A, UNIT_B, AffinityLineStatus.State.POSITIVE)
	]

	# Act
	var result: Array[Dictionary] = BattleScreen.affinity_line_dicts(statuses, positions)

	# Assert
	assert_int(result.size()).is_equal(1)
	assert_vector(result[0]["from"]).is_equal(CELL_A)
	assert_vector(result[0]["to"]).is_equal(CELL_B)
	assert_int(result[0]["tone"]).is_equal(BoardView.LineTone.POSITIVE)


func test_line_dicts_follow_a_hypothetical_position_table() -> void:
	# Arrange — 同一組狀態,但座標表把 UNIT_A 挪到別的格。這就是游標預覽:
	# 單位還沒真的移動,線卻必須畫在「如果他走過去」的位置上。
	var hypothetical: Dictionary[int, Vector2i] = {
		UNIT_A: CELL_HYPOTHETICAL, UNIT_B: CELL_B
	}
	var statuses: Array[AffinityLineStatus] = [
		_status(UNIT_A, UNIT_B, AffinityLineStatus.State.NEGATIVE)
	]

	# Act
	var result: Array[Dictionary] = BattleScreen.affinity_line_dicts(statuses, hypothetical)

	# Assert
	assert_vector(result[0]["from"]).is_equal(CELL_HYPOTHETICAL)
	assert_int(result[0]["tone"]).is_equal(BoardView.LineTone.NEGATIVE)


func test_line_dicts_skip_status_with_missing_endpoint() -> void:
	# Arrange — 夥伴不在座標表裡(等同已陣亡或不在場上)
	var positions: Dictionary[int, Vector2i] = {UNIT_A: CELL_A}
	var statuses: Array[AffinityLineStatus] = [
		_status(UNIT_A, UNIT_ABSENT, AffinityLineStatus.State.POSITIVE)
	]

	# Act
	var result: Array[Dictionary] = BattleScreen.affinity_line_dicts(statuses, positions)

	# Assert
	assert_array(result).is_empty()


func test_projected_hp_subtracts_damage() -> void:
	assert_int(BattleScreen.projected_hp(32, 12)).is_equal(20)


func test_projected_hp_at_exactly_lethal_damage_is_zero() -> void:
	# 邊界值本身就是重點,所以這裡直接寫數字
	assert_int(BattleScreen.projected_hp(12, 12)).is_equal(0)


func test_projected_hp_never_goes_below_zero() -> void:
	assert_int(BattleScreen.projected_hp(5, 40)).is_equal(0)


func test_affinity_preview_shows_both_values_with_signs() -> void:
	assert_str(BattleScreen.format_affinity_preview(3, -1)).is_equal("好感度 +3→-1")


func test_affinity_current_shows_signed_value() -> void:
	assert_str(BattleScreen.format_affinity_current(-1)).is_equal("好感度 -1")


func test_damage_preview_shows_damage_and_hp_transition() -> void:
	assert_str(BattleScreen.format_damage_preview(12, 32, 20)).is_equal("打擊 12　血量 32→20")
