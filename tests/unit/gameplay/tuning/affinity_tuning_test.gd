# production/epics/tuning-data/story-005-affinity-rules-tuning.md AC1 / AC3 / AC5
# AffinityTuning 與 AffinityRules 注入的單元測試。零檔案 I/O(全用 in-test 字串)。
extends GdUnitTestSuite


const _OTHERS: String = "deck,opening_hand_size,5\ndeck,hand_size_limit,5\ndeck,cards_drawn_per_turn,1\n" \
	+ "card_modifier,atk_delta_min,-4\ncard_modifier,atk_delta_max,6\ncard_modifier,def_delta_min,-3\ncard_modifier,def_delta_max,4\n" \
	+ "combat,guard_min,-2\ncombat,guard_max,3\ncombat,lone_far_distance,3\ncombat,lone_far_guard,0\ncombat,lone_near_distance,1\n" \
	+ "combat,lone_near_guard,-1\ncombat,lone_mid_guard,2\ncombat,hold_back_distance,2\ncombat,hold_back_penalty,1\n"
const _AFF: String = "affinity,delta_positive_adjacent,3\naffinity,delta_positive_far,-1\naffinity,delta_negative_adjacent,-1\naffinity,delta_negative_far,2\naffinity,delta_neutral,0\naffinity,phi_min,-4\naffinity,phi_max,12\n"


func _tuning(aff: String) -> Variant:
	return AffinityTuning.from_text(_OTHERS + aff)


func _link(pol: AffinityLink.Polarity, a: int, b: int) -> AffinityLink:
	var l: AffinityLink = AffinityLink.new()
	l.unit_a = a
	l.unit_b = b
	l.polarity = pol
	l.amp = AffinityLink.AMP_EXPECTED
	return l


func test_affinity_tuning_defaults_equal_today_constants() -> void:
	var t: AffinityTuning = AffinityTuning.defaults()
	assert_int(t.delta_positive_adjacent()).is_equal(AffinityRules.DELTA_POSITIVE_ADJACENT)
	assert_int(t.delta_positive_far()).is_equal(AffinityRules.DELTA_POSITIVE_FAR)
	assert_int(t.delta_negative_adjacent()).is_equal(AffinityRules.DELTA_NEGATIVE_ADJACENT)
	assert_int(t.delta_negative_far()).is_equal(AffinityRules.DELTA_NEGATIVE_FAR)
	assert_int(t.delta_neutral()).is_equal(AffinityRules.DELTA_NEUTRAL)
	assert_int(t.phi_min()).is_equal(-4)
	assert_int(t.phi_max()).is_equal(12)


func test_affinity_tuning_text_equal_to_defaults_parses_to_same_values() -> void:
	var t: AffinityTuning = _tuning(_AFF) as AffinityTuning
	assert_bool(t != null).is_true()
	assert_int(t.phi_max()).is_equal(AffinityTuning.defaults().phi_max())
	assert_int(t.phi_min()).is_equal(AffinityTuning.defaults().phi_min())


func test_affinity_tuning_missing_key_returns_null_and_pushes_error() -> void:
	var text: String = _OTHERS + _AFF.replace("affinity,phi_max,12\n", "")
	var result: Array = [AffinityTuning.defaults()]
	await assert_error(func() -> void: result[0] = AffinityTuning.from_text(text)) \
		.is_push_error("TuningKnobs.from_text: missing required key 'affinity.phi_max'")
	assert_bool(result[0] == null).is_true()


func test_affinity_tuning_non_integer_returns_null_and_pushes_error() -> void:
	var text: String = _OTHERS + _AFF.replace("affinity,phi_max,12", "affinity,phi_max,abc")
	var result: Array = [AffinityTuning.defaults()]
	await assert_error(func() -> void: result[0] = AffinityTuning.from_text(text)) \
		.is_push_error("TuningKnobs.from_text: line 23: value 'abc' is not an integer")
	assert_bool(result[0] == null).is_true()


func test_affinity_tuning_phi_min_greater_than_max_returns_null_and_pushes_error() -> void:
	var text: String = _OTHERS + _AFF.replace("affinity,phi_min,-4", "affinity,phi_min,13")
	var result: Array = [AffinityTuning.defaults()]
	await assert_error(func() -> void: result[0] = AffinityTuning.from_text(text)) \
		.is_push_error("AffinityTuning: affinity.phi_min (13) must be <= phi_max (12)")
	assert_bool(result[0] == null).is_true()


func test_affinity_rules_injected_delta_curve_changes_delta() -> void:
	var t: AffinityTuning = _tuning(_AFF.replace("delta_positive_adjacent,3", "delta_positive_adjacent,5")) as AffinityTuning
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 1, 1)).is_equal(3)
	assert_int(AffinityRules.delta(AffinityLink.Polarity.POSITIVE, 1, 1, t)).is_equal(5)


func test_affinity_rules_clamp_applies_once_to_sum_not_per_line() -> void:
	# 3 條相鄰正向線,各 +3 => 總和 9。phi_max=6:總和夾一次 => 6。
	# 若逐線各夾一次(每線夾到 6 不變)再相加 => 9;若挪位/夾兩次 => 結果不同。
	var t: AffinityTuning = _tuning(_AFF.replace("phi_max,12", "phi_max,6")) as AffinityTuning
	var links: Array[AffinityLink] = [
		_link(AffinityLink.Polarity.POSITIVE, 1, 2),
		_link(AffinityLink.Polarity.POSITIVE, 1, 3),
		_link(AffinityLink.Polarity.POSITIVE, 1, 4),
	]
	var positions: Dictionary[int, Vector2i] = {1: Vector2i(1, 1), 2: Vector2i(0, 1), 3: Vector2i(2, 1), 4: Vector2i(1, 0)}
	var bd: AffinityBonusBreakdown = AffinityRules.bonus_breakdown_for(1, positions, links, t)
	assert_int(bd.raw_sum).is_equal(9)
	assert_int(bd.clamped_sum).is_equal(6)
	assert_int(AffinityRules.bonus_for(1, positions, links, t)).is_equal(6)
	# 不傳設定 => 預設上限 12,不夾
	assert_int(AffinityRules.bonus_for(1, positions, links)).is_equal(9)
