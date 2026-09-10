# CardDeck（src/gameplay/cards/card_deck.gd）與 Card（src/gameplay/cards/card.gd）
# 的單元測試 —— Story 003:卡池、手牌、已用區。
#
# 純狀態機、無節點 —— 不建立任何 Node，也不需要 tear-down，不會留下孤兒節點。
# 命名慣例沿用既有先例 tests/unit/gameplay/battle/turn_order_test.gd 的
# test_[scenario]_[expected]。
#
# 隨機源的固定方式：每個需要決定性抽牌順序的測試都自建一個
# RandomNumberGenerator 並設定固定 seed，再注入建構子 —— CardDeck 內部絕不呼叫
# 全域 randi()/randi_range()，這是 Story 003 工作單的硬性要求（測試必須逐次結果
# 相同，且結算路徑之外的抽牌隨機仍須是「注入的」而非隱式的全域狀態）。
extends GdUnitTestSuite


# 建立 count 張獨立的甲類卡，id 各不相同（"c0".."c(count-1)"），供不需要關心
# 卡面內容、只在意「這是不是同一張物件」的測試使用。
func _make_unique_cards(count: int) -> Array[Card]:
	var cards: Array[Card] = []
	for i: int in range(count):
		cards.append(Card.new_temporary_stat_modifier("c%d" % i, 1, 0, 1))
	return cards


# ---- Card：欄位可讀性的基本檢查（非 AC，純資料型別自我一致性） ------------

func test_new_temporary_stat_modifier_sets_category_and_fields() -> void:
	# Arrange / Act
	var card: Card = Card.new_temporary_stat_modifier("atk_up_1", 3, -1, 2)

	# Assert
	assert_int(card.category).is_equal(Card.Category.TEMPORARY_STAT_MODIFIER)
	assert_str(card.id).is_equal("atk_up_1")
	assert_int(card.delta_atk).is_equal(3)
	assert_int(card.delta_def).is_equal(-1)
	assert_int(card.duration_rounds).is_equal(2)


func test_new_permanent_affinity_write_sets_category_and_fields() -> void:
	# Arrange / Act
	var card: Card = Card.new_permanent_affinity_write("bond_up_1", 1, 2, 3)

	# Assert
	assert_int(card.category).is_equal(Card.Category.PERMANENT_AFFINITY_WRITE)
	assert_str(card.id).is_equal("bond_up_1")
	assert_int(card.affinity_character_a).is_equal(1)
	assert_int(card.affinity_character_b).is_equal(2)
	assert_int(card.affinity_magnitude).is_equal(3)


# ---- construction / opening hand -------------------------------------------

func test_deal_opening_hand_deals_five_when_pool_has_enough() -> void:
	# Arrange
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), rng)

	# Act
	deck.deal_opening_hand()

	# Assert
	assert_int(deck.hand_size()).is_equal(5)
	assert_int(deck.pool_size()).is_equal(5)
	assert_int(deck.used_size()).is_equal(0)


# 補測:卡池張數少於開局手牌數 -> 開局發不滿 5 張，合法且不報錯
func test_deal_opening_hand_with_small_pool_deals_partial_hand_without_error() -> void:
	# Arrange — pool only has 3 cards, fewer than OPENING_HAND_SIZE (5)
	var deck: CardDeck = CardDeck.new(_make_unique_cards(3), RandomNumberGenerator.new())

	# Act
	deck.deal_opening_hand()

	# Assert — dealt exactly what existed, no error, no crash
	assert_int(deck.hand_size()).is_equal(3)
	assert_int(deck.pool_size()).is_equal(0)
	assert_int(deck.total_card_count()).is_equal(3)


# ---- AC-10（邏輯半）：滿手時補牌 -> 阻塞 + 系統未代選 ------------------------

func test_ac10_draw_for_turn_on_full_hand_grows_hand_to_six_and_sets_pending_discard() -> void:
	# Arrange — deal exactly a full hand of 5 first
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), rng)
	deck.deal_opening_hand()
	assert_int(deck.hand_size()).is_equal(5)  # sanity check before the act
	assert_bool(deck.has_pending_discard()).is_false()  # sanity check before the act

	# Act — the start-of-turn draw while the hand is already full
	deck.draw_for_turn()

	# Assert ① — the newly drawn card is NOT silently dropped: hand grows to 6
	assert_int(deck.hand_size()).is_equal(6)
	# Assert ② — an observable "awaiting discard" state is true
	assert_bool(deck.has_pending_discard()).is_true()


func test_ac10_pending_discard_does_not_alter_the_five_original_cards() -> void:
	# Arrange
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), rng)
	deck.deal_opening_hand()
	var hand_before: Array[Card] = deck.hand()

	# Act
	deck.draw_for_turn()

	# Assert ③ — until the player picks, the hand's original content is
	# untouched: every one of the 5 pre-draw cards is still present, by the
	# same object identity (not a re-drawn / re-shuffled substitute).
	var hand_after: Array[Card] = deck.hand()
	for card: Card in hand_before:
		assert_bool(hand_after.has(card)).is_true()
	assert_int(hand_after.size()).is_equal(hand_before.size() + 1)


func test_ac10_resolving_pending_discard_via_discard_card_clears_the_flag() -> void:
	# Arrange
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), rng)
	deck.deal_opening_hand()
	deck.draw_for_turn()
	assert_bool(deck.has_pending_discard()).is_true()  # sanity check before the act
	var to_discard: Card = deck.hand()[0]

	# Act — the player's own choice; the deck never picks for them
	var result: bool = deck.discard_card(to_discard)

	# Assert
	assert_bool(result).is_true()
	assert_bool(deck.has_pending_discard()).is_false()
	assert_int(deck.hand_size()).is_equal(5)


func test_ac10_playing_a_card_instead_of_discarding_does_not_clear_pending_discard() -> void:
	# Arrange — GDD Detailed Rules 二 requires the forced choice specifically
	# be a DISCARD ("強制玩家棄一張"), not any card leaving the hand.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), rng)
	deck.deal_opening_hand()
	deck.draw_for_turn()
	assert_bool(deck.has_pending_discard()).is_true()  # sanity check before the act
	var to_play: Card = deck.hand()[0]

	# Act
	deck.play_card(to_play)

	# Assert — playing removed a card from hand, but the forced discard is
	# still owed
	assert_int(deck.hand_size()).is_equal(5)
	assert_bool(deck.has_pending_discard()).is_true()


# ---- 每回合出牌數不限 -------------------------------------------------------

func test_playing_three_cards_in_the_same_turn_all_succeed() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_unique_cards(5), RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var hand: Array[Card] = deck.hand()

	# Act — no rule caps plays per turn
	var result_1: bool = deck.play_card(hand[0])
	var result_2: bool = deck.play_card(hand[1])
	var result_3: bool = deck.play_card(hand[2])

	# Assert — the third play is not rejected
	assert_bool(result_1).is_true()
	assert_bool(result_2).is_true()
	assert_bool(result_3).is_true()
	assert_int(deck.used_size()).is_equal(3)
	assert_int(deck.hand_size()).is_equal(2)


# ---- 卡池抽空：結構上不會發生，反覆抽仍不崩潰且總量恆定 ---------------------

func test_drawing_past_an_empty_pool_does_not_crash_and_total_stays_constant() -> void:
	# Arrange — a pool with fewer cards than the hand cap, so the hand never
	# reaches HAND_SIZE_LIMIT and draw_for_turn() never trips the pending-
	# discard assertion while we hammer it well past exhaustion.
	var deck: CardDeck = CardDeck.new(_make_unique_cards(3), RandomNumberGenerator.new())
	deck.deal_opening_hand()  # hand=3, pool=0
	var total_before: int = deck.total_card_count()

	# Act — pool is already empty; every one of these must silently no-op
	for _i: int in range(10):
		deck.draw_for_turn()

	# Assert — no crash reaching this line, and nothing was fabricated or lost
	assert_int(deck.total_card_count()).is_equal(total_before)
	assert_int(deck.hand_size()).is_equal(3)
	assert_int(deck.pool_size()).is_equal(0)
	assert_bool(deck.has_pending_discard()).is_false()


# ---- AC-11b：戰鬥結束 -> 手牌與已用區全數退回卡池 ---------------------------

func test_ac11b_battle_end_returns_hand_and_used_cards_to_pool() -> void:
	# Arrange
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var deck: CardDeck = CardDeck.new(_make_unique_cards(8), rng)
	deck.deal_opening_hand()  # hand=5, pool=3
	var played: Card = deck.hand()[0]
	deck.play_card(played)  # hand=4, used=1, pool=3

	# Act
	deck.return_all_to_pool()

	# Assert — every card is back in the pool, nothing left in hand or used
	assert_int(deck.hand_size()).is_equal(0)
	assert_int(deck.used_size()).is_equal(0)
	assert_int(deck.pool_size()).is_equal(8)
	assert_int(deck.total_card_count()).is_equal(8)


func test_ac11b_battle_end_clears_any_pending_discard() -> void:
	# Arrange — leave a forced discard unresolved when the battle ends
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), rng)
	deck.deal_opening_hand()
	deck.draw_for_turn()
	assert_bool(deck.has_pending_discard()).is_true()  # sanity check before the act

	# Act
	deck.return_all_to_pool()

	# Assert
	assert_bool(deck.has_pending_discard()).is_false()


# ---- AC-12：連續打出並棄掉 20 次 -> 三區總張數與開局相同 --------------------

func test_ac12_playing_and_discarding_20_times_preserves_total_card_count() -> void:
	# Arrange — pool large enough (30) that 20 rounds of "remove one, then
	# draw one" never run the pool dry mid-test.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var deck: CardDeck = CardDeck.new(_make_unique_cards(30), rng)
	deck.deal_opening_hand()
	var total_before: int = deck.total_card_count()

	# Act — 20 rounds, alternating play/discard. Removing a card from hand
	# BEFORE drawing keeps the hand below HAND_SIZE_LIMIT at every
	# draw_for_turn() call, so no forced discard ever triggers here — this
	# test is deliberately isolated to the AC-12 count invariant alone.
	for i: int in range(20):
		var card: Card = deck.hand()[0]
		if i % 2 == 0:
			deck.play_card(card)
		else:
			deck.discard_card(card)
		deck.draw_for_turn()

	# Assert — nothing was created or destroyed across 20 moves
	assert_int(deck.total_card_count()).is_equal(total_before)
	assert_int(deck.total_card_count()).is_equal(30)


# ---- 敏感度證明專用：打出/棄掉必須進「已用區」，不得立刻回卡池 --------------
#
# 這兩條分別對應工作單完成判準②的第一項注入目標:
# 「把『打出後進已用區』改成『打出後立刻回卡池』→ 重複抽牌的測試轉紅」。
# 直接斷言「剛打出/棄掉的那張牌不在 pool() 裡、在 used() 裡」，比繞一大圈去抽牌
# 更直接命中該行為本身，且不受隨機抽牌順序影響。

func test_play_card_moves_card_to_used_not_immediately_back_to_pool() -> void:
	# Arrange
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var deck: CardDeck = CardDeck.new(_make_unique_cards(5), rng)
	deck.deal_opening_hand()  # pool now empty: hand=5, pool=0
	var played: Card = deck.hand()[0]

	# Act
	deck.play_card(played)

	# Assert — must be in the used pile, and must NOT have gone straight
	# back into the pool (which would let it be re-drawn this same battle)
	assert_bool(deck.used().has(played)).is_true()
	assert_bool(deck.pool().has(played)).is_false()


func test_discard_card_moves_card_to_used_not_immediately_back_to_pool() -> void:
	# Arrange
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var deck: CardDeck = CardDeck.new(_make_unique_cards(5), rng)
	deck.deal_opening_hand()  # pool now empty: hand=5, pool=0
	var discarded: Card = deck.hand()[0]

	# Act
	deck.discard_card(discarded)

	# Assert
	assert_bool(deck.used().has(discarded)).is_true()
	assert_bool(deck.pool().has(discarded)).is_false()


# ---- deterministic draw / fixed seed sanity --------------------------------

func test_same_seed_produces_the_same_opening_hand_membership() -> void:
	# Arrange — two independently constructed decks, identical card pools
	# (matching ids) and identically-seeded RNGs
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 123
	var deck_a: CardDeck = CardDeck.new(_make_unique_cards(10), rng_a)

	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 123
	var deck_b: CardDeck = CardDeck.new(_make_unique_cards(10), rng_b)

	# Act
	deck_a.deal_opening_hand()
	deck_b.deal_opening_hand()

	# Assert — same seed, same card ids in the pool -> same draw sequence,
	# proving the RNG is genuinely injected (not falling back to global,
	# time-seeded state)
	var ids_a: Array = deck_a.hand().map(func(c: Card) -> String: return c.id)
	var ids_b: Array = deck_b.hand().map(func(c: Card) -> String: return c.id)
	assert_array(ids_a).contains_exactly(ids_b)
