# production/epics/tuning-data/story-004-combat-rules-tuning.md AC1 / AC3 / AC5
# CombatTuning 與 CombatRules(guard_total / lone_guard / hold_back)注入的單元測試。
# 零檔案 I/O(全用 in-test 字串)。
extends GdUnitTestSuite


const _BASE: String = "deck,opening_hand_size,5\ndeck,hand_size_limit,5\ndeck,cards_drawn_per_turn,1\n" \
	+ "card_modifier,atk_delta_min,-4\ncard_modifier,atk_delta_max,6\ncard_modifier,def_delta_min,-3\ncard_modifier,def_delta_max,4\n" \
	+ "combat,guard_min,-2\ncombat,guard_max,3\ncombat,lone_far_distance,3\ncombat,lone_far_guard,0\ncombat,lone_near_distance,1\n" \
	+ "combat,lone_near_guard,-1\ncombat,lone_mid_guard,2\ncombat,hold_back_distance,2\ncombat,hold_back_penalty,1\n" \
	+ "affinity,delta_positive_adjacent,3\naffinity,delta_positive_far,-1\naffinity,delta_negative_adjacent,-1\naffinity,delta_negative_far,2\naffinity,delta_neutral,0\naffinity,phi_min,-4\naffinity,phi_max,12\n"


func _with(from: String, to: String) -> String:
	return _BASE.replace(from, to)


func test_defaults_equal_todays_values() -> void:
	var t: CombatTuning = CombatTuning.defaults()
	# 今日值錨點:字面數字刻意寫死。
	assert_int(t.guard_min()).is_equal(-2)
	assert_int(t.guard_max()).is_equal(3)
	assert_int(t.lone_far_distance()).is_equal(3)
	assert_int(t.lone_far_guard()).is_equal(0)
	assert_int(t.lone_near_distance()).is_equal(1)
	assert_int(t.lone_near_guard()).is_equal(-1)
	assert_int(t.lone_mid_guard()).is_equal(2)
	assert_int(t.hold_back_distance()).is_equal(2)
	assert_int(t.hold_back_penalty()).is_equal(1)


func test_initial_data_text_equals_defaults() -> void:
	var t: CombatTuning = CombatTuning.from_text(_BASE) as CombatTuning
	var d: CombatTuning = CombatTuning.defaults()
	assert_int(t.guard_min()).is_equal(d.guard_min())
	assert_int(t.guard_max()).is_equal(d.guard_max())
	assert_int(t.lone_far_distance()).is_equal(d.lone_far_distance())
	assert_int(t.lone_far_guard()).is_equal(d.lone_far_guard())
	assert_int(t.lone_near_distance()).is_equal(d.lone_near_distance())
	assert_int(t.lone_near_guard()).is_equal(d.lone_near_guard())
	assert_int(t.lone_mid_guard()).is_equal(d.lone_mid_guard())
	assert_int(t.hold_back_distance()).is_equal(d.hold_back_distance())
	assert_int(t.hold_back_penalty()).is_equal(d.hold_back_penalty())


func test_missing_key_returns_null_and_pushes_error() -> void:
	var text: String = _BASE.replace("combat,hold_back_penalty,1\n", "")
	var result: Array = [false]
	await assert_error(func() -> void: result[0] = CombatTuning.from_text(text) == null) \
		.is_push_error("TuningKnobs.from_text: missing required key 'combat.hold_back_penalty'")
	assert_bool(result[0]).is_true()


func test_non_integer_returns_null_and_pushes_error() -> void:
	var text: String = _with("combat,guard_max,3", "combat,guard_max,x")
	var result: Array = [false]
	await assert_error(func() -> void: result[0] = CombatTuning.from_text(text) == null) \
		.is_push_error("TuningKnobs.from_text: line 9: value 'x' is not an integer")
	assert_bool(result[0]).is_true()


func test_guard_min_greater_than_max_returns_null_and_pushes_error() -> void:
	var text: String = _with("combat,guard_min,-2", "combat,guard_min,4")
	var result: Array = [false]
	await assert_error(func() -> void: result[0] = CombatTuning.from_text(text) == null) \
		.is_push_error("CombatTuning: combat.guard_min (4) must be <= guard_max (3)")
	assert_bool(result[0]).is_true()


func test_lone_near_not_less_than_far_returns_null_and_pushes_error() -> void:
	var text: String = _with("combat,lone_near_distance,1", "combat,lone_near_distance,3")
	var result: Array = [false]
	await assert_error(func() -> void: result[0] = CombatTuning.from_text(text) == null) \
		.is_push_error("CombatTuning: combat.lone_near_distance (3) must be < lone_far_distance (3)")
	assert_bool(result[0]).is_true()


func test_lone_near_distance_below_one_returns_null_and_pushes_error() -> void:
	var text: String = _with("combat,lone_near_distance,1", "combat,lone_near_distance,0")
	var result: Array = [false]
	await assert_error(func() -> void: result[0] = CombatTuning.from_text(text) == null) \
		.is_push_error("CombatTuning: combat.lone_near_distance (0) must be >= 1 (distance between two distinct units is never < 1)")
	assert_bool(result[0]).is_true()


func test_hold_back_distance_below_one_returns_null_and_pushes_error() -> void:
	var text: String = _with("combat,hold_back_distance,2", "combat,hold_back_distance,0")
	var result: Array = [false]
	await assert_error(func() -> void: result[0] = CombatTuning.from_text(text) == null) \
		.is_push_error("CombatTuning: combat.hold_back_distance (0) must be >= 1 (distance between two distinct units is never < 1)")
	assert_bool(result[0]).is_true()


func test_hold_back_penalty_negative_returns_null_and_pushes_error() -> void:
	var text: String = _with("combat,hold_back_penalty,1", "combat,hold_back_penalty,-1")
	var result: Array = [false]
	await assert_error(func() -> void: result[0] = CombatTuning.from_text(text) == null) \
		.is_push_error("CombatTuning: combat.hold_back_penalty (-1) must be >= 0 (negative would increase damage)")
	assert_bool(result[0]).is_true()


func test_boundary_values_still_accepted() -> void:
	# 邊界:near=1、hold_back_distance=1、penalty=0 皆合法。
	var text: String = _with("combat,hold_back_distance,2", "combat,hold_back_distance,1").replace("combat,hold_back_penalty,1", "combat,hold_back_penalty,0")
	assert_bool(CombatTuning.from_text(text) != null).is_true()


func test_lone_guard_null_tuning_unchanged_for_d_min_range() -> void:
	# 零行為變更:刪除 LONE_MID_DISTANCE 前後 d_min -1..4 的回傳值(舊實作:fallthrough 得中段)。
	var expected: Dictionary = {-1: 0, 0: -1, 1: -1, 2: 2, 3: 0, 4: 0}
	for d: int in expected:
		assert_int(CombatRules.lone_guard(d)).is_equal(int(expected[d]))
		assert_int(CombatRules.lone_guard(d, CombatTuning.defaults())).is_equal(int(expected[d]))


func test_sensitivity_proof_lone_guard_follows_injected_tuning() -> void:
	var text: String = _with("combat,lone_far_distance,3", "combat,lone_far_distance,4").replace("combat,lone_mid_guard,2", "combat,lone_mid_guard,5")
	var t: CombatTuning = CombatTuning.from_text(text) as CombatTuning
	assert_int(CombatRules.lone_guard(3, t)).is_equal(5)
	assert_int(CombatRules.lone_guard(3)).is_equal(0)
	assert_int(CombatRules.lone_guard(2, t)).is_equal(5)


func test_sensitivity_proof_hold_back_follows_injected_tuning() -> void:
	var text: String = _with("combat,hold_back_penalty,1", "combat,hold_back_penalty,3").replace("combat,hold_back_distance,2", "combat,hold_back_distance,1")
	var t: CombatTuning = CombatTuning.from_text(text) as CombatTuning
	assert_int(CombatRules.hold_back(true, 1, t)).is_equal(3)
	assert_int(CombatRules.hold_back(true, 2, t)).is_equal(0)
	assert_int(CombatRules.hold_back(true, 2)).is_equal(1)
	assert_int(CombatRules.hold_back(false, 1, t)).is_equal(0)
