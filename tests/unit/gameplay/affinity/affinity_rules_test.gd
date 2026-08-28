# AffinityRules(src/gameplay/affinity/affinity_rules.gd)的單元測試。
#
# 對照組是原型 prototypes/affinity-position-concept-v5/prototype.html 的
# affinityDelta() 與 activeDeltasAt():
#   正關係 距離1 → +3、距離2 → 0、距離3 以上 → -1
#   負關係 距離1 → -1、距離2 → 0、距離3 以上 → +2
#   同一單位同時只有「最近的那一條正關係」生效,其餘被抑制(delta 0)。
#
# 純函式、無狀態、無節點 —— 不建立任何 Node,也不需要 tear-down,
# 不會留下孤兒節點。每個測試自備 positions 與 links,不共用狀態,
# 因此不依賴執行順序。命名慣例沿用既有先例
# tests/unit/gameplay/combat/combat_rules_test.gd 的 test_[scenario]_[expected]。
extends GdUnitTestSuite

# 配對表以資料列字串提供,經正式解析路徑建立,不手動塞欄位。
# ⚠️ 以下常數是為了驗證「規則」而合成的假配對,不是本作的真實人際關係。
# 遊戲的真實配對(甲乙正、丙丁負、戊無線)來自
# design/narrative/characters.md 第三節,只在 affinity_link_test.gd 裡斷言。
const LINK_1_2_POSITIVE: String = "1,2,POSITIVE,1"
const LINK_3_4_POSITIVE: String = "3,4,POSITIVE,1"
const LINK_2_5_NEGATIVE: String = "2,5,NEGATIVE,1"
const LINK_1_3_POSITIVE: String = "1,3,POSITIVE,1"
const LINK_1_4_POSITIVE: String = "1,4,POSITIVE,1"

const ORIGIN: Vector2i = Vector2i(0, 0)


# ---- 測試資料工廠 --------------------------------------------------------

func _links(lines: Array[String]) -> Array[AffinityLink]:
	return AffinityLink.links_from_text("\n".join(lines))


# 讓「單位 1 與夥伴相距 distance 格」的一組座標。
func _pair_positions(partner_id: int, distance: int) -> Dictionary[int, Vector2i]:
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[partner_id] = ORIGIN + Vector2i(distance, 0)
	return positions


# ---- delta():正關係三種距離 -------------------------------------------

func test_delta_positive_distance_one_returns_plus_three() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 1, 1)).is_equal(3)


func test_delta_positive_distance_two_returns_zero() -> void:
	# 距離 2 是刻意的死區:靠近才有獎勵,離太遠才有懲罰,中間不動
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 2, 1)).is_equal(0)


func test_delta_positive_distance_three_returns_minus_one() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 3, 1)).is_equal(-1)


func test_delta_positive_distance_far_beyond_three_stays_minus_one() -> void:
	# 3 以上是同一段,不隨距離加深
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 9, 1)).is_equal(-1)


# ---- delta():負關係三種距離 -------------------------------------------

func test_delta_negative_distance_one_returns_minus_one() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 1, 1)).is_equal(-1)


func test_delta_negative_distance_two_returns_zero() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 2, 1)).is_equal(0)


func test_delta_negative_distance_three_returns_plus_two() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 3, 1)).is_equal(2)


func test_delta_distance_zero_returns_zero_for_both_polarities() -> void:
	# 同格在盤面上不會發生,但規則必須有定義且不得爆炸
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 0, 1)).is_equal(0)
	assert_int(AffinityRules.delta(AffinityLink.Polarity.NEGATIVE, 0, 1)).is_equal(0)


func test_delta_amp_multiplies_the_base_value() -> void:
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 1, 2)).is_equal(6)


# ---- bonus_for():整體加成 ----------------------------------------------

func test_bonus_for_positive_pair_adjacent_grants_plus_three() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 1)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(3)


func test_bonus_for_positive_pair_far_apart_costs_one() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 4)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(-1)


func test_bonus_for_negative_pair_adjacent_costs_one() -> void:
	# Arrange — 從單位 2 的角度看 2-5 這條負關係
	var links: Array[AffinityLink] = _links([LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[5] = ORIGIN + Vector2i(1, 0)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(2, positions, links)).is_equal(-1)


func test_bonus_for_negative_pair_far_apart_grants_plus_two() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[5] = ORIGIN + Vector2i(0, 3)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(2, positions, links)).is_equal(2)


func test_bonus_for_positive_and_negative_links_sum_together() -> void:
	# Arrange — 單位 2:與 1 相鄰(正 +3),與 5 相距 3(負 +2)
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[1] = ORIGIN + Vector2i(1, 0)
	positions[5] = ORIGIN + Vector2i(0, 3)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(2, positions, links)).is_equal(5)


func test_bonus_for_unit_with_no_links_is_zero() -> void:
	# Arrange — 單位 5 不在任何一條配對上
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_3_4_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(2, 0)
	positions[4] = ORIGIN + Vector2i(3, 0)
	positions[5] = ORIGIN + Vector2i(4, 0)

	# Act / Assert
	assert_int(AffinityRules.bonus_for(5, positions, links)).is_equal(0)


func test_bonus_for_unit_absent_from_positions_is_zero() -> void:
	# Arrange — 單位不在盤面上(陣亡或尚未上場)
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(0)


func test_bonus_for_ignores_link_whose_partner_is_absent() -> void:
	# Arrange — 夥伴陣亡後那條線整條不算,原型同樣跳過死亡夥伴
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN

	# Act / Assert
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(0)


# ---- 只有最近的一條正關係生效 -------------------------------------------

func test_bonus_for_two_positive_links_only_the_nearest_one_counts() -> void:
	# Arrange — 單位 1 同時與 2(距離 1)和 3(距離 5)有兩條正關係
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_1_3_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(5, 0)

	# Act / Assert — 若兩條都生效會是 3 + (-1) = 2;只取最近的一條 → 3
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(3)


func test_lines_for_marks_the_farther_positive_link_suppressed() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE, LINK_1_3_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(5, 0)

	# Act
	var lines: Array[AffinityLineStatus] = AffinityRules.lines_for(1, positions, links)

	# Assert — 被抑制的那條仍要回報(畫成灰線),但 delta 必須是 0
	assert_int(lines.size()).is_equal(2)
	assert_int(lines[0].state).is_equal(AffinityLineStatus.State.POSITIVE)
	assert_int(lines[0].delta).is_equal(3)
	assert_int(lines[1].state).is_equal(AffinityLineStatus.State.SUPPRESSED)
	assert_int(lines[1].delta).is_equal(0)
	assert_int(lines[1].distance).is_equal(5)


func test_active_positive_link_tie_breaks_on_lower_partner_id() -> void:
	# Arrange — 3 與 4 到單位 1 的距離相同,結果必須固定為較小的 id(3)
	var links: Array[AffinityLink] = _links([LINK_1_4_POSITIVE, LINK_1_3_POSITIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[3] = ORIGIN + Vector2i(2, 0)
	positions[4] = ORIGIN + Vector2i(0, 2)

	# Act
	var active: AffinityLink = AffinityRules.active_positive_link(1, ORIGIN, positions, links)

	# Assert — 與配對表順序無關,故換一種順序仍應相同
	assert_int(active.partner_of(1)).is_equal(3)
	var reordered: Array[AffinityLink] = _links([LINK_1_3_POSITIVE, LINK_1_4_POSITIVE])
	var again: AffinityLink = AffinityRules.active_positive_link(1, ORIGIN, positions, reordered)
	assert_int(again.partner_of(1)).is_equal(3)


func test_negative_links_are_never_suppressed_by_each_other() -> void:
	# Arrange — 抑制規則只作用在正關係;負關係一律全部生效
	var lines_text: Array[String] = ["1,2,NEGATIVE,1", "1,3,NEGATIVE,1"]
	var links: Array[AffinityLink] = _links(lines_text)
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(3, 0)

	# Act / Assert — -1 + 2 = 1
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(1)


# ---- 給畫線用的介面 ------------------------------------------------------

func test_lines_for_reports_endpoints_distance_and_state() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_2_5_NEGATIVE])
	var positions: Dictionary[int, Vector2i] = {}
	positions[2] = ORIGIN
	positions[5] = ORIGIN + Vector2i(1, 0)

	# Act
	var lines: Array[AffinityLineStatus] = AffinityRules.lines_for(2, positions, links)

	# Assert
	assert_int(lines.size()).is_equal(1)
	assert_int(lines[0].unit_id).is_equal(2)
	assert_int(lines[0].partner_id).is_equal(5)
	assert_int(lines[0].distance).is_equal(1)
	assert_int(lines[0].delta).is_equal(-1)
	assert_int(lines[0].state).is_equal(AffinityLineStatus.State.NEGATIVE)


func test_lines_for_distance_two_reports_neutral_state() -> void:
	# Arrange
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 2)

	# Act
	var lines: Array[AffinityLineStatus] = AffinityRules.lines_for(1, positions, links)

	# Assert — 有連線但目前不影響數值,畫中性色
	assert_int(lines[0].state).is_equal(AffinityLineStatus.State.NEUTRAL)
	assert_int(lines[0].delta).is_equal(0)


func test_board_lines_returns_one_entry_per_link_with_both_units_present() -> void:
	# Arrange — 三條配對,但單位 5 不在盤面上,故 2-5 那條不畫
	var links: Array[AffinityLink] = _links(
		[LINK_1_2_POSITIVE, LINK_3_4_POSITIVE, LINK_2_5_NEGATIVE]
	)
	var positions: Dictionary[int, Vector2i] = {}
	positions[1] = ORIGIN
	positions[2] = ORIGIN + Vector2i(1, 0)
	positions[3] = ORIGIN + Vector2i(0, 4)
	positions[4] = ORIGIN + Vector2i(1, 4)

	# Act
	var lines: Array[AffinityLineStatus] = AffinityRules.board_lines(positions, links)

	# Assert
	assert_int(lines.size()).is_equal(2)
	assert_int(lines[0].unit_id).is_equal(1)
	assert_int(lines[0].partner_id).is_equal(2)
	assert_int(lines[0].state).is_equal(AffinityLineStatus.State.POSITIVE)
	assert_int(lines[1].unit_id).is_equal(3)
	assert_int(lines[1].partner_id).is_equal(4)


func test_bonus_for_at_previews_a_move_without_touching_positions() -> void:
	# Arrange — 單位 1 目前離夥伴 4 格(-1),預覽走到相鄰格(+3)
	var links: Array[AffinityLink] = _links([LINK_1_2_POSITIVE])
	var positions: Dictionary[int, Vector2i] = _pair_positions(2, 4)
	var preview_cell: Vector2i = positions[2] + Vector2i(1, 0)

	# Act
	var current: int = AffinityRules.bonus_for(1, positions, links)
	var preview: int = AffinityRules.bonus_for_at(1, preview_cell, positions, links)

	# Assert — 預覽不得改動輸入
	assert_int(current).is_equal(-1)
	assert_int(preview).is_equal(3)
	assert_int(positions[1].x).is_equal(ORIGIN.x)
	assert_int(positions[1].y).is_equal(ORIGIN.y)


# ---- 與既有戰鬥的距離定義一致 -------------------------------------------

func test_manhattan_distance_agrees_with_combat_rules_range_check() -> void:
	# Arrange — 好感度用的距離必須與武器射程用的是同一種,否則「兩格遠」
	# 在兩個系統會意義不同
	var from_cell: Vector2i = Vector2i(2, 3)
	var to_cell: Vector2i = Vector2i(4, 4)

	# Act
	var distance: int = AffinityRules.manhattan_distance(from_cell, to_cell)

	# Assert
	assert_int(distance).is_equal(3)
	assert_bool(CombatRules.is_in_range(from_cell, to_cell, 1, distance)).is_true()
	assert_bool(CombatRules.is_in_range(from_cell, to_cell, 1, distance - 1)).is_false()
