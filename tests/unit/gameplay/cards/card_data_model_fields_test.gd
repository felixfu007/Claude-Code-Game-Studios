# 卡牌資料模型擴欄(16 欄、新列舉、confirm 的 else 改 match)——
# production/epics/skill-card-system/story-011-card-data-model-16-fields.md
#
# 本檔不讀任何檔案(無 FileAccess/DirAccess),夾具全在測試內,不屬甲/乙類例外。
# 敏感度證明(常駐 test_sensitivity_proof_*):mutant 為內嵌的錯誤實作,斷言本檔的
# 預言機分得出來。①區間式欄數 ②Enum[name]下標 ④列舉重排 ⑤NONE不檢cost_amount 為
# 本檔內的 mutant 解析器(重現錯誤形狀);③else 還原為 CardPlaySession 子類別 mutant。
# 不可證的部分:mutant 解析器是「重現該錯誤形狀」的複本而非對 card.gd 的注入
# (card.gd 為 static 純函式,無繼承鏈可覆寫 → 類別 A);它證明的是「本檔的斷言
# 判得出該形狀」,不是「card.gd 沒有該形狀」(後者由 AC1/AC3 的正向測試承擔)。
extends GdUnitTestSuite


const P1: int = 1
const P2: int = 2
const ENEMY: int = 9

const LEGACY_8: String = "c1,TEMPORARY_STAT_MODIFIER,2,0,2,-1,-1,0"
const COST_SUFFIX_OK: String = "PAIR,0,0,2,-1,BASE"


## 組一列:前 10 欄固定,後面接 extra 個數的新欄(以逗號串接)。
func _line_n(total_fields: int) -> String:
	var parts: PackedStringArray = PackedStringArray(
		["c1", "TEMPORARY_STAT_MODIFIER", "2", "0", "2", "-1", "-1", "0", "-1", "ONLY"]
	)
	while parts.size() < total_fields:
		parts.append("0")
	return ",".join(parts.slice(0, total_fields))


func _line16(cost_type: String = "PAIR", cost_amount: String = "0", effect_value: String = "0",
		partner: String = "2", target_range: String = "-1", source: String = "BASE",
		category: String = "TEMPORARY_STAT_MODIFIER") -> String:
	return "c1,%s,2,0,2,-1,-1,0,1,ONLY,%s,%s,%s,%s,%s,%s" % [
		category, cost_type, cost_amount, effect_value, partner, target_range, source]


# ---- AC1 欄數集合 {8,9,10,16} ----------------------------------------------

func test_card_fields_8_columns_legal() -> void:
	assert_object(Card.from_csv_line(_line_n(8))).is_not_null()

func test_card_fields_9_columns_legal() -> void:
	assert_object(Card.from_csv_line(_line_n(9))).is_not_null()

func test_card_fields_10_columns_legal() -> void:
	assert_object(Card.from_csv_line(_line_n(10))).is_not_null()

func test_card_fields_16_columns_legal() -> void:
	assert_object(Card.from_csv_line(_line16())).is_not_null()

func test_card_fields_11_columns_rejected() -> void:
	assert_object(Card.from_csv_line(_line_n(11))).is_null()

func test_card_fields_12_columns_rejected() -> void:
	assert_object(Card.from_csv_line(_line_n(12))).is_null()

func test_card_fields_13_columns_rejected() -> void:
	assert_object(Card.from_csv_line(_line_n(13))).is_null()

func test_card_fields_14_columns_rejected() -> void:
	assert_object(Card.from_csv_line(_line_n(14))).is_null()

func test_card_fields_15_columns_rejected() -> void:
	assert_object(Card.from_csv_line(_line_n(15))).is_null()

func test_card_fields_17_columns_rejected() -> void:
	assert_object(Card.from_csv_line(_line_n(17))).is_null()


# ---- AC2 舊列語意 ------------------------------------------------------------

func test_legacy_8_column_line_gets_new_field_defaults() -> void:
	var card: Card = Card.from_csv_line(LEGACY_8)
	assert_object(card).is_not_null()
	assert_int(card.cost_type).is_equal(Card.CostType.NONE)
	assert_int(card.source).is_equal(Card.Source.BASE)
	assert_int(card.target_range).is_equal(-1)
	assert_int(card.cost_amount).is_equal(0)
	assert_int(card.partner_unit_id).is_equal(-1)


func test_legacy_10_column_line_gets_new_field_defaults() -> void:
	var card: Card = Card.from_csv_line(_line_n(10))
	assert_int(card.cost_type).is_equal(Card.CostType.NONE)
	assert_int(card.source).is_equal(Card.Source.BASE)
	assert_int(card.target_range).is_equal(-1)


# ---- AC3 新列舉 / 值域 ---------------------------------------------------------

func test_cost_type_all_legal_strings_parse() -> void:
	assert_int(Card.from_csv_line(_line16("NONE", "0")).cost_type).is_equal(Card.CostType.NONE)
	assert_int(Card.from_csv_line(_line16("HP", "3")).cost_type).is_equal(Card.CostType.HP)
	assert_int(Card.from_csv_line(_line16("AFFINITY", "1")).cost_type).is_equal(Card.CostType.AFFINITY)
	assert_int(Card.from_csv_line(_line16("PAIR", "0")).cost_type).is_equal(Card.CostType.PAIR)


func test_source_all_legal_strings_parse() -> void:
	assert_int(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "-1", "BASE")).source).is_equal(Card.Source.BASE)
	assert_int(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "-1", "CAMP")).source).is_equal(Card.Source.CAMP)


func test_new_categories_all_legal_strings_parse() -> void:
	assert_int(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "-1", "BASE", "DIRECT_DAMAGE")).category).is_equal(Card.Category.DIRECT_DAMAGE)
	assert_int(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "-1", "BASE", "HEAL")).category).is_equal(Card.Category.HEAL)
	assert_int(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "-1", "BASE", "COMBO_DAMAGE")).category).is_equal(Card.Category.COMBO_DAMAGE)


func test_sixteen_column_values_land_in_fields() -> void:
	var card: Card = Card.from_csv_line(_line16("PAIR", "2", "7", "3", "4", "CAMP"))
	assert_int(card.cost_amount).is_equal(2)
	assert_int(card.effect_value).is_equal(7)
	assert_int(card.partner_unit_id).is_equal(3)
	assert_int(card.target_range).is_equal(4)


func test_unknown_cost_type_rejected() -> void:
	assert_object(Card.from_csv_line(_line16("GOLD"))).is_null()


func test_unknown_source_rejected() -> void:
	assert_object(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "-1", "SHOP"))).is_null()


func test_unknown_category_rejected_in_16_column_line() -> void:
	assert_object(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "-1", "BASE", "NUKE"))).is_null()


func test_cost_type_none_with_nonzero_cost_amount_rejected() -> void:
	assert_object(Card.from_csv_line(_line16("NONE", "5"))).is_null()


func test_negative_cost_amount_rejected() -> void:
	assert_object(Card.from_csv_line(_line16("HP", "-1"))).is_null()


func test_affinity_and_pair_with_partner_below_one_rejected() -> void:
	assert_object(Card.from_csv_line(_line16("AFFINITY", "1", "0", "0"))).is_null()
	assert_object(Card.from_csv_line(_line16("PAIR", "0", "0", "-1"))).is_null()


func test_non_integer_in_each_new_integer_column_rejected() -> void:
	assert_object(Card.from_csv_line(_line16("HP", "abc"))).is_null()
	assert_object(Card.from_csv_line(_line16("PAIR", "0", "x"))).is_null()
	assert_object(Card.from_csv_line(_line16("PAIR", "0", "0", "b"))).is_null()
	assert_object(Card.from_csv_line(_line16("PAIR", "0", "0", "2", "?"))).is_null()


func test_enum_values_are_appended_not_reordered() -> void:
	assert_dict(_expected_values_diff(Card.CostType, {"NONE": 0, "HP": 1, "AFFINITY": 2, "PAIR": 3})).is_empty()
	assert_dict(_expected_values_diff(Card.Source, {"BASE": 0, "CAMP": 1})).is_empty()
	assert_dict(_expected_values_diff(Card.Category, {
		"TEMPORARY_STAT_MODIFIER": 0, "PERMANENT_AFFINITY_WRITE": 1,
		"DIRECT_DAMAGE": 2, "HEAL": 3, "COMBO_DAMAGE": 4})).is_empty()


## 預言機:回傳「期望名稱→值」與實際列舉不符的項目(空 = 全對)。
func _expected_values_diff(actual: Dictionary, expected: Dictionary) -> Dictionary:
	var diff: Dictionary = {}
	for key: String in expected:
		if actual.get(key, -999) != expected[key]:
			diff[key] = actual.get(key, -999)
	return diff


# ---- AC5 工廠預設 ---------------------------------------------------------------

func test_factory_cards_have_default_new_fields() -> void:
	var cards: Array[Card] = [
		Card.new_temporary_stat_modifier("a", 1, 0, 1),
		Card.new_permanent_affinity_write("b", 1, 2, 1),
	]
	for card: Card in cards:
		assert_int(card.cost_type).is_equal(Card.CostType.NONE)
		assert_int(card.cost_amount).is_equal(0)
		assert_int(card.effect_value).is_equal(0)
		assert_int(card.partner_unit_id).is_equal(-1)
		assert_int(card.target_range).is_equal(-1)
		assert_int(card.source).is_equal(Card.Source.BASE)


# ---- AC4 confirm():新 Category 被拒、牌不消耗、不掛修正器 ----------------------------

## 測試用:直接把 Session 推到 CONFIRMING(新 Category 的牌 select_card 走不到)。
class _Driver extends CardPlaySession:
	func force_confirming(card: Card, target_id: int) -> void:
		_selected_card = card
		_selected_target_a = target_id
		_step = Step.CONFIRMING


## ③ else 還原:非丙類一律當甲類。
class _MutantElseRestored extends _Driver:
	func confirm() -> bool:
		if _step != Step.CONFIRMING:
			return false
		if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
			return super.confirm()
		_state.commit_authoritative_change(func() -> void:
			_state.unit_by_id(_selected_target_a).add_modifier(CardModifier.new(
				_selected_card.id, _selected_card.delta_atk, _selected_card.delta_def, _selected_card.duration_rounds))
			_deck.play_card(_selected_card))
		_reset_to_closed()
		return true


func _build_state() -> BattleState:
	var lines: Array[String] = [
		"%d,P1,PLAYER,20,10,3,1,1,1,0,0" % P1,
		"%d,P2,PLAYER,20,8,2,1,1,1,5,0" % P2,
		"%d,E1,ENEMY,20,5,3,1,1,1,1,0" % ENEMY,
	]
	return BattleState.create(PackedStringArray(), "\n".join(lines))


## 回傳 {confirmed, in_hand, modifiers, version_delta}。
func _confirm_new_category(session_script: GDScript, category: Card.Category) -> Dictionary:
	var state: BattleState = _build_state()
	var card: Card = Card.new()
	card.id = "new_cat"
	card.category = category
	var deck: CardDeck = CardDeck.new([card] as Array[Card], RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var s: _Driver = session_script.new(deck, state, [] as Array[AffinityLink], NullAffinityWritePort.new())
	s.force_confirming(card, P1)
	var before: int = state.combat_state_version
	var ok: bool = s.confirm()
	return {
		"confirmed": ok,
		"in_hand": deck.hand().has(card),
		"modifiers": state.unit_by_id(P1).active_modifiers().size(),
		"version_delta": state.combat_state_version - before,
	}


func _new_category_rejected_cleanly(session_script: GDScript, category: Card.Category) -> bool:
	var r: Dictionary = _confirm_new_category(session_script, category)
	return not r["confirmed"] and r["in_hand"] and r["modifiers"] == 0 and r["version_delta"] == 0


func test_confirm_rejects_direct_damage_without_consuming_or_modifying() -> void:
	assert_bool(_new_category_rejected_cleanly(_Driver, Card.Category.DIRECT_DAMAGE)).is_true()


func test_confirm_rejects_heal_without_consuming_or_modifying() -> void:
	assert_bool(_new_category_rejected_cleanly(_Driver, Card.Category.HEAL)).is_true()


func test_confirm_rejects_combo_damage_without_consuming_or_modifying() -> void:
	assert_bool(_new_category_rejected_cleanly(_Driver, Card.Category.COMBO_DAMAGE)).is_true()


# ---- AC7 敏感度證明(常駐;mutant 內嵌,見檔頭「不可證的部分」)----------------------

func _count_set_violations(accepts: Callable) -> int:
	var legal: Array[int] = [8, 9, 10, 16]
	var bad: int = 0
	for n: int in range(8, 18):
		if bool(accepts.call(n)) != legal.has(n):
			bad += 1
	return bad


func test_sensitivity_proof_range_style_field_count_is_detected() -> void:
	var real: Callable = func(n: int) -> bool:
		return Card.from_csv_line(_line16() if n == 16 else _line_n(n)) != null
	var mutant: Callable = func(n: int) -> bool: return n >= 8 and n <= 16
	assert_int(_count_set_violations(real)).is_equal(0)
	assert_int(_count_set_violations(mutant)).is_greater(0)


## 預言機:未知字串必須被拒;回傳「被錯誤接受」的個數。
func _unknown_cost_type_violations(accepts: Callable) -> int:
	var bad: int = 0
	for word: String in ["GOLD", "pair", "", "Hp"]:
		if bool(accepts.call(word)):
			bad += 1
	return bad


func test_sensitivity_proof_unknown_string_mapped_to_ordinal_zero_is_detected() -> void:
	var real: Callable = func(word: String) -> bool:
		return Card.from_csv_line(_line16(word)) != null
	# 錯誤形狀:未知字串落到預設序數 0,視為合法。
	var mutant: Callable = func(word: String) -> bool:
		return int(Card.CostType.get(word, 0)) == 0
	assert_int(_unknown_cost_type_violations(real)).is_equal(0)
	assert_int(_unknown_cost_type_violations(mutant)).is_greater(0)


enum _BadCostType { NONE, INSERTED, HP, AFFINITY, PAIR }


func test_sensitivity_proof_reordered_enum_is_detected() -> void:
	var expected: Dictionary = {"NONE": 0, "HP": 1, "AFFINITY": 2, "PAIR": 3}
	assert_dict(_expected_values_diff(Card.CostType, expected)).is_empty()
	assert_dict(_expected_values_diff(_BadCostType, expected)).is_not_empty()


## 預言機:cost_type=NONE 時 cost_amount 非 0 必須被拒;回傳違規數。
func _none_amount_violations(accepts: Callable) -> int:
	var bad: int = 0
	for amount: String in ["5", "1"]:
		if bool(accepts.call(amount)):
			bad += 1
	if not bool(accepts.call("0")):
		bad += 1
	return bad


func test_sensitivity_proof_none_cost_amount_unchecked_is_detected() -> void:
	var real: Callable = func(amount: String) -> bool:
		return Card.from_csv_line(_line16("NONE", amount)) != null
	var mutant: Callable = func(_amount: String) -> bool: return true
	assert_int(_none_amount_violations(real)).is_equal(0)
	assert_int(_none_amount_violations(mutant)).is_greater(0)


func test_sensitivity_proof_else_restored_session_is_detected() -> void:
	assert_bool(_new_category_rejected_cleanly(_Driver, Card.Category.DIRECT_DAMAGE)).is_true()
	assert_bool(_new_category_rejected_cleanly(_MutantElseRestored, Card.Category.DIRECT_DAMAGE)).is_false()
