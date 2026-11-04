# production/epics/tuning-data/story-003-card-modifier-tuning.md AC1 / AC3 / AC5
# CardModifierTuning 與 CardModifierRules 注入的單元測試。零檔案 I/O(全用 in-test 字串)。
extends GdUnitTestSuite


# story-004:補上 combat 九行(只補行)。
const _COMBAT: String = "combat,guard_min,-2\ncombat,guard_max,3\ncombat,lone_far_distance,3\ncombat,lone_far_guard,0\ncombat,lone_near_distance,1\ncombat,lone_near_guard,-1\ncombat,lone_mid_guard,2\ncombat,hold_back_distance,2\ncombat,hold_back_penalty,1\n" \
	+ "affinity,delta_positive_adjacent,3\naffinity,delta_positive_far,-1\naffinity,delta_negative_adjacent,-1\naffinity,delta_negative_far,2\naffinity,delta_neutral,0\naffinity,phi_min,-4\naffinity,phi_max,12\n"
const _DECK: String = "deck,opening_hand_size,5\ndeck,hand_size_limit,5\ndeck,cards_drawn_per_turn,1\n" + _COMBAT
const _NARROW: String = "card_modifier,atk_delta_min,-1\ncard_modifier,atk_delta_max,2\ncard_modifier,def_delta_min,-1\ncard_modifier,def_delta_max,1\n"


func _mods(atk: int, def: int) -> Array[CardModifier]:
	var out: Array[CardModifier] = [CardModifier.new("m", atk, def, 1)]
	return out


func test_defaults_equal_todays_constants() -> void:
	var t: CardModifierTuning = CardModifierTuning.defaults()
	assert_int(t.atk_delta_min()).is_equal(CardModifierRules.ATK_DELTA_MIN)
	assert_int(t.atk_delta_max()).is_equal(CardModifierRules.ATK_DELTA_MAX)
	assert_int(t.def_delta_min()).is_equal(CardModifierRules.DEF_DELTA_MIN)
	assert_int(t.def_delta_max()).is_equal(CardModifierRules.DEF_DELTA_MAX)
	# 今日值錨點:字面數字刻意寫死。
	assert_int(t.atk_delta_min()).is_equal(-4)
	assert_int(t.atk_delta_max()).is_equal(6)
	assert_int(t.def_delta_min()).is_equal(-3)
	assert_int(t.def_delta_max()).is_equal(4)


func test_from_text_valid_returns_values() -> void:
	var parsed: Variant = CardModifierTuning.from_text(_DECK + _NARROW)
	assert_bool(parsed != null).is_true()
	var t: CardModifierTuning = parsed as CardModifierTuning
	assert_int(t.atk_delta_min()).is_equal(-1)
	assert_int(t.atk_delta_max()).is_equal(2)
	assert_int(t.def_delta_min()).is_equal(-1)
	assert_int(t.def_delta_max()).is_equal(1)


func test_missing_key_returns_null() -> void:
	var text: String = _DECK + "card_modifier,atk_delta_min,-1\ncard_modifier,atk_delta_max,2\ncard_modifier,def_delta_min,-1\n"
	assert_bool(CardModifierTuning.from_text(text) == null).is_true()


func test_non_integer_returns_null() -> void:
	var text: String = _DECK + _NARROW.replace("atk_delta_max,2", "atk_delta_max,abc")
	assert_bool(CardModifierTuning.from_text(text) == null).is_true()


func test_atk_min_greater_than_max_returns_null() -> void:
	var text: String = _DECK + _NARROW.replace("atk_delta_min,-1", "atk_delta_min,3")
	assert_bool(CardModifierTuning.from_text(text) == null).is_true()


func test_def_min_greater_than_max_returns_null() -> void:
	var text: String = _DECK + _NARROW.replace("def_delta_min,-1", "def_delta_min,2")
	assert_bool(CardModifierTuning.from_text(text) == null).is_true()


func test_rules_null_tuning_equals_defaults() -> void:
	# 零行為變更:今日常數夾限(+6 / -4 / +4 / -3)。
	assert_int(CardModifierRules.effective_atk(10, _mods(99, 0))).is_equal(16)
	assert_int(CardModifierRules.effective_atk(10, _mods(-99, 0))).is_equal(6)
	assert_int(CardModifierRules.effective_def(10, _mods(0, 99))).is_equal(14)
	assert_int(CardModifierRules.effective_def(10, _mods(0, -99))).is_equal(7)


func test_sensitivity_proof_rules_follow_injected_tuning() -> void:
	var t: CardModifierTuning = CardModifierTuning.from_text(_DECK + _NARROW) as CardModifierTuning
	assert_int(CardModifierRules.effective_atk(10, _mods(99, 0), t)).is_equal(12)
	assert_int(CardModifierRules.effective_atk(10, _mods(-99, 0), t)).is_equal(9)
	assert_int(CardModifierRules.effective_def(10, _mods(0, 99), t)).is_equal(11)
	assert_int(CardModifierRules.effective_def(10, _mods(0, -99), t)).is_equal(9)


func test_battle_state_create_pushes_error_when_card_modifier_knobs_invalid() -> void:
	# 反向 atk 夾限的 knobs;BattleState.create() 不得靜默退回 defaults()。
	var knobs: TuningKnobs = TuningKnobs.from_text(_DECK + _NARROW.replace("atk_delta_min,-1", "atk_delta_min,3")) as TuningKnobs
	assert_bool(knobs != null).is_true()
	var result: Array = [null]
	await assert_error(func() -> void:
		result[0] = BattleState.create(PackedStringArray(["..", ".."]), "", knobs)) \
		.is_push_error("BattleState.create: card_modifier tuning invalid (see preceding CardModifierTuning error) -- falling back to CardModifierTuning.defaults(); production path (BattleScreen) validates first and never reaches here")
	var state: BattleState = result[0] as BattleState
	assert_bool(state != null).is_true()
	assert_int(state.card_modifier_tuning.atk_delta_max()).is_equal(CardModifierRules.ATK_DELTA_MAX)
