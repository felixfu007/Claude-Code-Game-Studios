# production/epics/tuning-data/story-002-card-deck-tuning.md AC1 / AC3 / AC5
# DeckTuning 與 CardDeck 注入的單元測試。零檔案 I/O(全用 in-test 字串)。
# 「資料檔錯誤使 BattleScreen 失敗」見 tests/integration/ui/battle/battle_screen_deck_tuning_wiring_test.gd。
extends GdUnitTestSuite


const _CM: String = "card_modifier,atk_delta_min,-4\ncard_modifier,atk_delta_max,6\ncard_modifier,def_delta_min,-3\ncard_modifier,def_delta_max,4\n"
const _VALID: String = "deck,opening_hand_size,3\ndeck,hand_size_limit,4\ndeck,cards_drawn_per_turn,1\n" + _CM
const _LIMIT3: String = "deck,opening_hand_size,3\ndeck,hand_size_limit,3\ndeck,cards_drawn_per_turn,1\n" + _CM


func _cards(n: int) -> Array[Card]:
	var out: Array[Card] = []
	for i: int in range(n):
		out.append(Card.new_temporary_stat_modifier("c%d" % i, 1, 0, 1))
	return out


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_defaults_equal_todays_card_deck_constants() -> void:
	var d: DeckTuning = DeckTuning.defaults()
	assert_int(d.opening_hand_size()).is_equal(CardDeck.OPENING_HAND_SIZE)
	assert_int(d.hand_size_limit()).is_equal(CardDeck.HAND_SIZE_LIMIT)
	assert_int(d.cards_drawn_per_turn()).is_equal(CardDeck.CARDS_DRAWN_PER_TURN)
	# 今日值錨點:字面數字刻意寫死,常數被誤改時本測試變紅。
	assert_int(d.opening_hand_size()).is_equal(5)
	assert_int(d.hand_size_limit()).is_equal(5)
	assert_int(d.cards_drawn_per_turn()).is_equal(1)


func test_from_text_valid_returns_values() -> void:
	var parsed: Variant = DeckTuning.from_text(_VALID)
	assert_bool(parsed != null).is_true()
	var d: DeckTuning = parsed as DeckTuning
	assert_int(d.opening_hand_size()).is_equal(3)
	assert_int(d.hand_size_limit()).is_equal(4)
	assert_int(d.cards_drawn_per_turn()).is_equal(1)


func test_from_text_draw_two_returns_null_and_pushes_error() -> void:
	var result: Array = [_VALID]
	await assert_error(func() -> void:
		result[0] = DeckTuning.from_text("deck,opening_hand_size,3\ndeck,hand_size_limit,4\ndeck,cards_drawn_per_turn,2\n" + _CM)) \
		.is_push_error("DeckTuning: deck.cards_drawn_per_turn must be 1 (got 2): CardDeck tracks an owed discard with a single flag, so drawing more than 1 per turn needs a code change first")
	assert_bool(result[0] == null).is_true()


func test_from_text_missing_key_returns_null_and_pushes_error() -> void:
	var result: Array = [_VALID]
	await assert_error(func() -> void:
		result[0] = DeckTuning.from_text("deck,opening_hand_size,3\ndeck,hand_size_limit,4\n")) \
		.is_push_error("TuningKnobs.from_text: missing required key 'deck.cards_drawn_per_turn'")
	assert_bool(result[0] == null).is_true()


func test_from_text_non_integer_returns_null_and_pushes_error() -> void:
	var result: Array = [_VALID]
	await assert_error(func() -> void:
		result[0] = DeckTuning.from_text("deck,opening_hand_size,3\ndeck,hand_size_limit,4.5\ndeck,cards_drawn_per_turn,1\n" + _CM)) \
		.is_push_error("TuningKnobs.from_text: line 2: value '4.5' is not an integer")
	assert_bool(result[0] == null).is_true()


func test_from_text_hand_limit_zero_returns_null_and_pushes_error() -> void:
	var result: Array = [_VALID]
	await assert_error(func() -> void:
		result[0] = DeckTuning.from_text("deck,opening_hand_size,1\ndeck,hand_size_limit,0\ndeck,cards_drawn_per_turn,1\n" + _CM)) \
		.is_push_error("DeckTuning: all of deck.opening_hand_size / deck.hand_size_limit / deck.cards_drawn_per_turn must be >= 1 (got 1 / 0 / 1)")
	assert_bool(result[0] == null).is_true()


func test_from_text_opening_exceeds_limit_returns_null_and_pushes_error() -> void:
	var result: Array = [_VALID]
	await assert_error(func() -> void:
		result[0] = DeckTuning.from_text("deck,opening_hand_size,5\ndeck,hand_size_limit,3\ndeck,cards_drawn_per_turn,1\n" + _CM)) \
		.is_push_error("DeckTuning: deck.opening_hand_size (5) must be <= deck.hand_size_limit (3)")
	assert_bool(result[0] == null).is_true()


func test_card_deck_without_tuning_behaves_as_defaults() -> void:
	var deck: CardDeck = CardDeck.new(_cards(12), _rng(1))
	deck.deal_opening_hand()
	assert_int(deck.hand_size()).is_equal(5)
	assert_int(deck.hand_size_limit()).is_equal(5)


func test_card_deck_honors_injected_tuning() -> void:
	var tuning: DeckTuning = DeckTuning.from_text(_VALID) as DeckTuning
	var deck: CardDeck = CardDeck.new(_cards(12), _rng(1), tuning)
	deck.deal_opening_hand()
	assert_int(deck.hand_size()).is_equal(3)
	deck.draw_for_turn()  # 抽 1 張 -> 4 = 上限 4,未超過 -> 不欠棄牌
	assert_int(deck.hand_size()).is_equal(4)
	assert_bool(deck.has_pending_discard()).is_false()
	deck.draw_for_turn()  # 手牌已滿再抽 -> 欠一次棄牌
	assert_bool(deck.has_pending_discard()).is_true()


func test_sensitivity_proof_forced_discard_timing_follows_injected_limit() -> void:
	var limit3: DeckTuning = DeckTuning.from_text(_LIMIT3) as DeckTuning
	var small: CardDeck = CardDeck.new(_cards(12), _rng(7), limit3)
	var normal: CardDeck = CardDeck.new(_cards(12), _rng(7))
	small.deal_opening_hand()
	normal.deal_opening_hand()
	small.draw_for_turn()
	normal.draw_for_turn()
	assert_bool(small.has_pending_discard()).is_true()
	assert_bool(normal.has_pending_discard()).is_true()
	# 同一次抽牌後:上限 3 的手牌 4 張、預設的 6 張 —— 數字確實跟著注入的設定走。
	assert_int(small.hand_size()).is_equal(4)
	assert_int(normal.hand_size()).is_equal(6)
