# 甲類卡「點名單位」限定(skill-card-system Story 009,管理者 2026-11-03 裁決
# 「限定只能給點名者」)。
#
# 驗:點名者存活 → 唯一目標;點名者倒下 → 空且這張牌打不出;點名者不在本場 → 空;
# 未點名(-1)的甲類與丙類行為不變;CSV 第 9 欄解析;真實卡表點名正確。
#
# 檔案存取例外聲明(.claude/rules/test-standards.md 兩項登記例外之第 1 項):
# 末段讀 assets/data/cards/vs0*_cards.txt 與 assets/data/units/vs0*_roster.txt
# 唯讀版控資料,不證明窮舉。
extends GdUnitTestSuite

const P1: int = 1
const P2: int = 2
const P3: int = 3
const ENEMY: int = 9
const NOT_ON_FIELD: int = 5  # 本檔名冊裡沒有這個我方單位


func _build_state() -> BattleState:
	var lines: Array[String] = [
		"%d,P1,PLAYER,20,10,3,1,1,1,0,0" % P1,
		"%d,P2,PLAYER,20,8,2,1,1,1,5,0" % P2,
		"%d,P3,PLAYER,20,8,2,1,1,1,6,0" % P3,
		"%d,E1,ENEMY,20,5,3,1,1,1,1,0" % ENEMY,
	]
	return BattleState.create(PackedStringArray(), "\n".join(lines))


func _link(a: int, b: int) -> AffinityLink:
	var link: AffinityLink = AffinityLink.new()
	link.unit_a = a
	link.unit_b = b
	link.polarity = AffinityLink.Polarity.POSITIVE
	link.amp = 1
	return link


class _Port extends AffinityWritePort:
	func append_record(_a: int, _b: int, _m: int, _source: StringName) -> Rejection:
		return Rejection.NONE


func _session(state: BattleState, card: Card) -> CardPlaySession:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = [_link(P1, P2), _link(P2, P3)]
	var session: CardPlaySession = CardPlaySession.new(deck, state, links, _Port.new())
	session.open_hand()
	return session


## 敏感度證明用變異體:忽略點名,回到「全體存活我方」的舊行為。
class _MutantIgnoresNaming extends CardPlaySession:
	func _legal_targets_for_stat_card(_card: Card) -> Array[int]:
		return _alive_player_unit_ids()


func test_sensitivity_proof_unrestricted_mutant_is_caught_by_the_exact_target_assertion() -> void:
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, P2)
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = [_link(P1, P2), _link(P2, P3)]
	var mutant: CardPlaySession = _MutantIgnoresNaming.new(deck, _build_state(), links, _Port.new())
	mutant.open_hand()
	mutant.select_card(card)
	var targets: Array[int] = mutant.legal_targets()
	targets.sort()
	# 真實測試斷言 contains_exactly([P2]);變異體回傳 [P1,P2,P3],該斷言會紅。
	assert_array(targets).is_equal([P1, P2, P3])
	assert_array(targets).is_not_equal([P2])


## 排除模式的變異體:把 EXCLUDE 當成 ONLY(只給點名者)。
class _MutantExcludeActsAsOnly extends CardPlaySession:
	func _legal_targets_for_stat_card(card: Card) -> Array[int]:
		var alive: Array[int] = _alive_player_unit_ids()
		var only: Array[int] = []
		if alive.has(card.named_unit_id):
			only.append(card.named_unit_id)
		return only


func test_sensitivity_proof_exclude_treated_as_only_is_caught() -> void:
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, P2, Card.NamedMode.EXCLUDE)
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = [_link(P1, P2), _link(P2, P3)]
	var mutant: CardPlaySession = _MutantExcludeActsAsOnly.new(deck, _build_state(), links, _Port.new())
	mutant.open_hand()
	mutant.select_card(card)
	var targets: Array[int] = mutant.legal_targets()
	# 真實測試斷言 contains_exactly([P1, P3]);變異體回傳 [P2],該斷言會紅。
	assert_array(targets).is_equal([P2])
	assert_array(targets).is_not_equal([P1, P3])


func test_exclude_mode_targets_other_alive_units_and_not_the_named_one() -> void:
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, P2, Card.NamedMode.EXCLUDE)
	var session: CardPlaySession = _session(_build_state(), card)
	assert_bool(session.select_card(card)).is_true()
	var targets: Array[int] = session.legal_targets()
	targets.sort()
	assert_array(targets).contains_exactly([P1, P3])


func test_exclude_mode_named_unit_dead_still_playable_on_others() -> void:
	var state: BattleState = _build_state()
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, P2, Card.NamedMode.EXCLUDE)
	var session: CardPlaySession = _session(state, card)
	state.unit_by_id(P2).take_damage(9999)
	assert_bool(session.is_card_playable(card)).is_true()
	assert_bool(session.select_card(card)).is_true()
	var targets: Array[int] = session.legal_targets()
	targets.sort()
	assert_array(targets).contains_exactly([P1, P3])


func test_exclude_mode_named_unit_not_on_field_leaves_everyone_alive() -> void:
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, NOT_ON_FIELD, Card.NamedMode.EXCLUDE)
	var session: CardPlaySession = _session(_build_state(), card)
	assert_bool(session.select_card(card)).is_true()
	var targets: Array[int] = session.legal_targets()
	targets.sort()
	assert_array(targets).contains_exactly([P1, P2, P3])


func test_from_csv_line_reads_named_mode_and_rejects_unknown_mode() -> void:
	var exclude: Card = Card.from_csv_line("c,TEMPORARY_STAT_MODIFIER,0,1,2,-1,-1,0,2,EXCLUDE")
	assert_int(exclude.named_mode).is_equal(Card.NamedMode.EXCLUDE)
	var only: Card = Card.from_csv_line("c,TEMPORARY_STAT_MODIFIER,0,1,2,-1,-1,0,2,ONLY")
	assert_int(only.named_mode).is_equal(Card.NamedMode.ONLY)
	var nine: Card = Card.from_csv_line("c,TEMPORARY_STAT_MODIFIER,0,1,2,-1,-1,0,2")
	assert_int(nine.named_mode).is_equal(Card.NamedMode.ONLY)
	# 未知模式字串 → null(整表載入失敗),不得靜默當成 ONLY。
	var bad: Card = Card.from_csv_line("c,TEMPORARY_STAT_MODIFIER,0,1,2,-1,-1,0,2,exclude")
	assert_object(bad).is_null()


func test_named_card_with_alive_named_unit_has_exactly_that_target() -> void:
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, P2)
	var session: CardPlaySession = _session(_build_state(), card)
	assert_bool(session.select_card(card)).is_true()
	assert_array(session.legal_targets()).contains_exactly([P2])


func test_named_unit_dead_makes_card_unplayable_and_targets_empty() -> void:
	var state: BattleState = _build_state()
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, P2)
	var session: CardPlaySession = _session(state, card)
	state.unit_by_id(P2).take_damage(9999)
	assert_bool(state.unit_by_id(P2).is_alive()).is_false()  # sanity
	assert_bool(session.is_card_playable(card)).is_false()
	# 選牌被拒 → 留在 S1,不進入「空合法集合的 S2」(BattleScreen 會把它誤讀成 CONFIRMING)
	assert_bool(session.select_card(card)).is_false()
	assert_array(session.legal_targets()).is_empty()


func test_named_unit_dies_after_selection_gives_empty_targets() -> void:
	var state: BattleState = _build_state()
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, P2)
	var session: CardPlaySession = _session(state, card)
	session.select_card(card)
	state.unit_by_id(P2).take_damage(9999)
	assert_array(session.legal_targets()).is_empty()


func test_named_unit_not_on_field_gives_unplayable_card() -> void:
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1, NOT_ON_FIELD)
	var session: CardPlaySession = _session(_build_state(), card)
	assert_bool(session.is_card_playable(card)).is_false()
	assert_bool(session.select_card(card)).is_false()
	assert_array(session.legal_targets()).is_empty()


func test_unrestricted_stat_card_still_targets_every_alive_player_unit() -> void:
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1)
	var session: CardPlaySession = _session(_build_state(), card)
	assert_bool(session.select_card(card)).is_true()
	var targets: Array[int] = session.legal_targets()
	targets.sort()
	assert_array(targets).contains_exactly([P1, P2, P3])


func test_affinity_card_ignores_named_unit_field() -> void:
	# 丙類(配對類)行為完全不變:即使人為塞一個點名值也不影響。
	var card: Card = Card.new_permanent_affinity_write("bond", P1, P2, 1)
	card.named_unit_id = NOT_ON_FIELD
	var session: CardPlaySession = _session(_build_state(), card)
	assert_bool(session.is_card_playable(card)).is_true()
	assert_bool(session.select_card(card)).is_true()
	var targets: Array[int] = session.legal_targets()
	targets.sort()
	assert_array(targets).contains_exactly([P1, P2, P3])


func test_from_csv_line_reads_optional_ninth_column() -> void:
	var with_col: Card = Card.from_csv_line("c,TEMPORARY_STAT_MODIFIER,0,1,2,-1,-1,0,3")
	assert_int(with_col.named_unit_id).is_equal(3)
	var without_col: Card = Card.from_csv_line("c,TEMPORARY_STAT_MODIFIER,0,1,2,-1,-1,0")
	assert_int(without_col.named_unit_id).is_equal(Card.UNRESTRICTED_TARGET)
	var affinity: Card = Card.from_csv_line("b,PERMANENT_AFFINITY_WRITE,0,0,0,1,2,2,-1")
	assert_int(affinity.named_unit_id).is_equal(Card.UNRESTRICTED_TARGET)


# ---- 真實卡表(唯讀版控資料,不證明窮舉)---------------------------------------

# id -> [點名單位, 模式]。card_02/03 的牌面是「乙」鼓勵隊友 → 排除乙(2026-11-03 裁決)。
const _EXPECTED_NAMED: Dictionary = {
	"card_01": [1, Card.NamedMode.ONLY],
	"card_02": [2, Card.NamedMode.EXCLUDE],
	"card_03": [2, Card.NamedMode.EXCLUDE],
	"card_04": [4, Card.NamedMode.ONLY],
	"card_05": [5, Card.NamedMode.ONLY],
	"card_06": [3, Card.NamedMode.ONLY],
}


func test_every_real_card_table_names_the_expected_unit_that_exists_in_its_roster() -> void:
	for n: int in [1, 2, 3, 4, 5]:
		var cards_text: String = FileAccess.get_file_as_string("res://assets/data/cards/vs0%d_cards.txt" % n)
		var roster_text: String = FileAccess.get_file_as_string("res://assets/data/units/vs0%d_roster.txt" % n)
		var parsed: Variant = Card.cards_from_text(cards_text)
		assert_bool(parsed != null).is_true()
		var cards: Array[Card] = []
		cards.assign(parsed)
		var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
		for card: Card in cards:
			if card.category == Card.Category.TEMPORARY_STAT_MODIFIER:
				var expected: Array = _EXPECTED_NAMED[card.id]
				assert_int(card.named_unit_id).is_equal(expected[0])
				assert_int(card.named_mode).is_equal(expected[1])
				var unit: Unit = state.unit_by_id(card.named_unit_id)
				assert_bool(unit != null and unit.faction == Unit.Faction.PLAYER).is_true()
			else:
				assert_int(card.named_unit_id).is_equal(Card.UNRESTRICTED_TARGET)
