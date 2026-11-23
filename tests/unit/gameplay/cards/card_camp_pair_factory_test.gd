## card_camp_pair_factory_test.gd
##
## 實作依據:production/epics/campfire/story-003-campfire-card-generation.md「Affected Files」;
## docs/reviews/campfire-003-card-construction-2026-11-23.md(工廠草案)。
## 檔案存取:無(全記憶體)。
##
## 範圍:Card.new_camp_pair_card() 的欄位落位與值域拒絕。
## 敏感度證明:本檔的拒絕/落位斷言對象是 static 純函式(證明不了類 A:沒有繼承鏈可覆寫);
## 工廠被產卡器呼叫的接線由 tests/unit/gameplay/campfire/campfire_card_generator_test.gd 的
## test_sensitivity_proof_* 覆蓋(mutant ④ 正是「E 不寫進 delta_*」)。
extends GdUnitTestSuite


func _make() -> Card:
	return Card.new_camp_pair_card("camp_x", 0, 3, 2, 1, 5, 1, 2, 3)


func test_camp_pair_factory_all_fields_land() -> void:
	# Arrange / Act
	var card: Card = Card.new_camp_pair_card("camp_x", 4, -2, 2, 5, 1, 1, 2, 4)
	# Assert
	assert_object(card).is_not_null()
	assert_str(card.id).is_equal("camp_x")
	assert_int(card.category).is_equal(Card.Category.TEMPORARY_STAT_MODIFIER)
	assert_int(card.delta_atk).is_equal(4)
	assert_int(card.delta_def).is_equal(-2)
	assert_int(card.duration_rounds).is_equal(2)
	assert_int(card.named_unit_id).is_equal(5)
	assert_int(card.partner_unit_id).is_equal(1)
	assert_int(card.cost_type).is_equal(Card.CostType.PAIR)
	assert_int(card.cost_amount).is_equal(1)
	assert_int(card.target_range).is_equal(2)
	assert_int(card.effect_value).is_equal(4)
	assert_int(card.source).is_equal(Card.Source.CAMP)


func test_camp_pair_factory_rejects_negative_cost_amount() -> void:
	assert_object(Card.new_camp_pair_card("x", 0, 1, 2, 1, 2, -1, 2, 1)).is_null()


func test_camp_pair_factory_rejects_partner_below_one() -> void:
	assert_object(Card.new_camp_pair_card("x", 0, 1, 2, 1, 0, 1, 2, 1)).is_null()
	assert_object(Card.new_camp_pair_card("x", 0, 1, 2, 1, -1, 1, 2, 1)).is_null()


func test_camp_pair_factory_rejects_payer_below_one() -> void:
	assert_object(Card.new_camp_pair_card("x", 0, 1, 2, 0, 2, 1, 2, 1)).is_null()
	assert_object(Card.new_camp_pair_card("x", 0, 1, 2, -1, 2, 1, 2, 1)).is_null()


func test_camp_pair_factory_rejects_negative_effect_value() -> void:
	assert_object(Card.new_camp_pair_card("x", 0, 1, 2, 1, 2, 1, 2, -1)).is_null()


func test_camp_pair_factory_leaves_existing_factories_unchanged() -> void:
	# 既有工廠的預設值不受新增影響。
	var c: Card = Card.new_temporary_stat_modifier("old", 1, 2, 1)
	assert_int(c.cost_type).is_equal(Card.CostType.NONE)
	assert_int(c.source).is_equal(Card.Source.BASE)
	assert_int(c.partner_unit_id).is_equal(-1)
	assert_object(_make()).is_not_null()
