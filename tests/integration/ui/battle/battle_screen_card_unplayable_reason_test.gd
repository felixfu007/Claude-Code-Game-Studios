# Story 020b(production/epics/skill-card-system/story-020-card-confirm-panel-cost-and-unplayable-reason.md)
# AC3 / AC6 ③:手牌 Z3 對不可打的卡顯示【原因文字】,且不同原因顯示不同句。
#
# 載入【真實】BattleScreen.tscn;原因由引擎 CardPlaySession.card_unplayable_reason 決定,
# 測試先斷言「引擎回傳的 Reason == 情境預期」(前提),再比對 HandBar Z3 原因行 == 該 Reason 對應 UX 鍵文案。
# 檔案存取:無。
# 敏感度證明(常駐 test_sensitivity_proof_*):mutant ③ 不可打原因恆顯示同一句 -> 多原因情境回 false。
# 揭露:UX 1.3 #6~#9 引擎目前回傳不出來(見 BattleScreen.unplayable_reason_key 註解),本檔不測;
# 折損已滿(WEAR_CAP_REACHED)需配對關係態夾具,本檔未涵蓋。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


## ③ 不可打原因恆顯示同一句。
class _MutantConstantReason extends BattleScreen:
	func card_unplayable_reason_text(card: Card) -> String:
		if super(card) == "":
			return ""
		return "夥伴不在場"


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _instance(mutant: GDScript = null) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if mutant != null:
		instance.set_script(mutant)
	auto_free(instance)
	add_child(instance)
	return instance


func _install_card(instance: BattleScreen, card: Card) -> void:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards)
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = CardPlaySession.new(
		deck, instance._state, links, NullAffinityWritePort.new()
	)
	session.attach_affinity_pool(AffinityDataPool.new())
	instance._controller._card_play_session = session


## 開手牌、展開到 1.0、重畫,回傳 Z3 原因行文字。
func _reason_line(instance: BattleScreen) -> String:
	instance._handle_open_hand_pressed()
	instance._hand_bar._set_expand_progress(1.0)
	instance._refresh_view()
	return instance._hand_bar.diagnostic_detail_reason_text()


func _players(instance: BattleScreen) -> Array[Unit]:
	return instance._state.units_of(Unit.Faction.PLAYER)


func _kill(instance: BattleScreen, unit: Unit) -> void:
	instance._state.commit_authoritative_change(func() -> void: unit.take_damage(unit.hp))


func _wound_to(instance: BattleScreen, unit: Unit, target_hp: int) -> void:
	var amount: int = unit.hp - target_hp
	instance._state.commit_authoritative_change(func() -> void: unit.take_damage(amount))


func _duo(a: int, b: int, range_limit: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("t020b_duo", 2, 1, 2, a)
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.partner_unit_id = b
	card.target_range = range_limit
	return card


## 夥伴不在場
func _scn_partner_absent(script: GDScript = null) -> bool:
	var s: BattleScreen = _instance(script)
	var p: Array[Unit] = _players(s)
	_install_card(s, _duo(p[0].id, p[1].id, 99))
	_kill(s, p[1])
	if s._controller._card_play_session.card_unplayable_reason(s._state.card_deck().hand()[0]) \
			!= CardCostPlan.Reason.PARTNER_ABSENT:
		return false
	return _reason_line(s) == Loc.localize(&"battle.card_reason.partner_absent")


## 血量不足(帶付款人姓名)
func _scn_hp_insufficient(script: GDScript = null) -> bool:
	var s: BattleScreen = _instance(script)
	var payer: Unit = _players(s)[0]
	var card: Card = Card.new_temporary_stat_modifier("t020b_hp", 1, 0, 1, payer.id)
	card.cost_type = Card.CostType.HP
	card.cost_amount = 2
	_install_card(s, card)
	_wound_to(s, payer, 2)
	if s._controller._card_play_session.card_unplayable_reason(card) != CardCostPlan.Reason.CANNOT_AFFORD_HP:
		return false
	var expect: String = Loc.localize(&"battle.card_reason.hp_insufficient_format") \
		% BattleScreen.unit_display_name(payer)
	return _reason_line(s) == expect


## 兩人距離太遠
func _scn_too_far(script: GDScript = null) -> bool:
	var s: BattleScreen = _instance(script)
	var p: Array[Unit] = _players(s)
	# 取距離最遠的一對我方,射程設為「剛好差 1」,確保必超出。
	var best_a: Unit = p[0]
	var best_b: Unit = p[1]
	var best_d: int = -1
	for ua: Unit in p:
		for ub: Unit in p:
			if ua.id == ub.id:
				continue
			var d: int = AffinityRules.manhattan_distance(
				s._state.position_of(ua.id), s._state.position_of(ub.id)
			)
			if d > best_d:
				best_d = d
				best_a = ua
				best_b = ub
	if best_d < 2:
		return false
	_install_card(s, _duo(best_a.id, best_b.id, best_d - 1))
	if s._controller._card_play_session.card_unplayable_reason(s._state.card_deck().hand()[0]) \
			!= CardCostPlan.Reason.OUT_OF_RANGE:
		return false
	return _reason_line(s) == Loc.localize(&"battle.card_reason.too_far_apart")


## 站位條件(c03):付款人 2 格內無隊友 —— 殺光其他我方。
func _scn_need_ally(script: GDScript = null) -> bool:
	var s: BattleScreen = _instance(script)
	var p: Array[Unit] = _players(s)
	var card: Card = Card.new()
	card.id = "t020b_c03"
	card.category = Card.Category.DIRECT_DAMAGE
	card.cost_type = Card.CostType.HP
	card.cost_amount = 1
	card.effect_value = 5
	card.target_range = 2
	card.named_unit_id = p[0].id
	_install_card(s, card)
	for i: int in range(1, p.size()):
		_kill(s, p[i])
	if s._controller._card_play_session.card_unplayable_reason(card) != CardCostPlan.Reason.NEED_ALLY_NEARBY:
		return false
	return _reason_line(s) == Loc.localize(&"battle.card_reason.need_ally_within_2")


## 可打的卡:原因行為空。
func _scn_playable_blank(script: GDScript = null) -> bool:
	var s: BattleScreen = _instance(script)
	var payer: Unit = _players(s)[0]
	var card: Card = Card.new_temporary_stat_modifier("t020b_ok", 1, 0, 1, payer.id)
	card.cost_type = Card.CostType.HP
	card.cost_amount = 1
	_install_card(s, card)
	if s._controller._card_play_session.card_unplayable_reason(card) != CardCostPlan.Reason.NONE:
		return false
	return _reason_line(s) == ""


func test_ac3_partner_absent_shows_reason() -> void:
	assert_bool(_scn_partner_absent()).is_true()


func test_ac3_hp_insufficient_shows_reason_with_payer_name() -> void:
	assert_bool(_scn_hp_insufficient()).is_true()


func test_ac3_too_far_shows_reason() -> void:
	assert_bool(_scn_too_far()).is_true()


func test_ac3_need_ally_shows_reason() -> void:
	assert_bool(_scn_need_ally()).is_true()


func test_ac3_playable_card_has_no_reason_line() -> void:
	assert_bool(_scn_playable_blank()).is_true()


func test_sensitivity_proof_constant_reason_mutant_is_caught() -> void:
	# 真品全綠、mutant ③ 至少有一個多原因情境變 false。
	assert_bool(_scn_hp_insufficient()).is_true()
	assert_bool(_scn_too_far()).is_true()
	var caught: bool = not _scn_hp_insufficient(_MutantConstantReason) \
		or not _scn_too_far(_MutantConstantReason) \
		or not _scn_need_ally(_MutantConstantReason)
	assert_bool(caught).append_failure_message("mutant ③ 應被多原因情境抓出").is_true()
