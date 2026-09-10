# CardPlaySession 接進 BattleController（story-008-play-session-wiring.md）的整合
# 測試 —— 涵蓋 AC-P1 ~ AC-P8。獨立測試檔,不與 card_play_session_test.gd
# （story 005,直接對 CardPlaySession 測)、card_battle_wiring_test.gd（story 006)
# 或 card_forced_discard_gate_test.gd（story 007)共用,理由同專案慣例（一條真實
# 失敗會讓同檔案後面的測試全部不執行,拆檔避免互相拖累)。
#
# 本檔只測「透過 BattleController 這一層」的行為 —— CardPlaySession 自己的四步
# 流程規則(取消零寫入、確認去重、丙類配對合法性等)已由 story-005 的
# card_play_session_test.gd 覆蓋,不在此重複。
#
# 全鏈路（BattleState/BattleController/TurnOrder/Unit/CardDeck/Card/
# CardModifier/AffinityLink/PermanentAffinityWriteRules/AffinityWritePort/
# CardPlaySession/NullAffinityWritePort)都是 RefCounted,不建立任何 Node,
# 不會留下孤兒節點。
extends GdUnitTestSuite


const P1: int = 1
const P2: int = 2
const ENEMY: int = 9


## 記錄型測試替身,滿足 AffinityWritePort 的 @abstract 契約 —— 沿用
## tests/integration/gameplay/cards/card_play_session_test.gd 的既有慣例。
class _FakeAffinityWritePort extends AffinityWritePort:
	var calls: Array[Dictionary] = []
	var accepted_count: int = 0
	var force_rejection: Rejection = Rejection.NONE

	func append_record(character_a: int, character_b: int, m: int, source: StringName) -> Rejection:
		calls.append({
			"character_a": character_a,
			"character_b": character_b,
			"m": m,
			"source": source,
		})
		if force_rejection != Rejection.NONE:
			return force_rejection
		accepted_count += 1
		return Rejection.NONE


# ---- fixtures ---------------------------------------------------------------

func _roster_lines() -> Array[String]:
	return [
		"%d,P1,PLAYER,20,10,3,1,1,1,0,0" % P1,
		"%d,P2,PLAYER,20,8,2,1,1,1,5,0" % P2,
		"%d,E1,ENEMY,20,5,3,0,1,1,1,0" % ENEMY,
	]


func _make_link(a: int, b: int, polarity: AffinityLink.Polarity) -> AffinityLink:
	var link: AffinityLink = AffinityLink.new()
	link.unit_a = a
	link.unit_b = b
	link.polarity = polarity
	link.amp = 1
	return link


# P1-P2 一條關係線 —— 供丙類卡的 AC-P7 測試使用。
func _default_links() -> Array[AffinityLink]:
	return [_make_link(P1, P2, AffinityLink.Polarity.POSITIVE)]


func _make_unique_cards(count: int) -> Array[Card]:
	var cards: Array[Card] = []
	for i: int in range(count):
		cards.append(Card.new_temporary_stat_modifier("c%d" % i, 1, 0, 1))
	return cards


func _seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _no_op_decide() -> Callable:
	return func(
		_state: BattleState, _unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		return {"move_to": null, "attack": -1}


# 沿用 story-006/007 的既有手法建構 controller,額外接上 affinity_links /
# write_port 兩個 story-008 新增的可選參數。deck == null 時,BattleController
# 完全不建立 CardPlaySession(AC-P6)。
func _build_controller(
	roster_lines: Array[String],
	deck: CardDeck,
	links: Array[AffinityLink] = [],
	write_port: AffinityWritePort = null
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new([P1, P2], [ENEMY])
	var controller: BattleController = BattleController.new(
		state, order, Callable(), _no_op_decide(), deck, links, write_port
	)
	return {"state": state, "order": order, "controller": controller}


# 逼進「欠棄牌」狀態:滿手甲類卡的牌池 + 走完一輪玩家->敵人->玩家的轉換。沿用
# card_forced_discard_gate_test.gd 的 _controller_with_pending_discard() 手法。
func _controller_with_pending_discard(seed_value: int) -> Dictionary:
	var deck: CardDeck = CardDeck.new(_make_unique_cards(10), _seeded_rng(seed_value))
	var built: Dictionary = _build_controller(_roster_lines(), deck)
	var controller: BattleController = built["controller"]
	controller.end_faction_phase()
	controller.run_enemy_phase()
	built["deck"] = deck
	return built


# ---- AC-P1:附卡池與埠的戰鬥,完整打出一張甲類卡 -------------------------------

func test_ac_p1_full_flow_via_controller_updates_effective_atk_and_moves_card_out_of_hand() -> void:
	# Arrange
	var atk_card: Card = Card.new_temporary_stat_modifier("atk_up_3", 3, 0, 2)
	var deck: CardDeck = CardDeck.new([atk_card], RandomNumberGenerator.new())
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var built: Dictionary = _build_controller(_roster_lines(), deck, _default_links(), write_port)
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	assert_int(deck.hand_size()).is_equal(1)
	var atk_before: int = state.unit_by_id(P1).effective_atk()

	# Act — 開手牌 -> 選甲類 -> 選我方單位 -> 確認,全部透過 controller
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(atk_card)).is_true()
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.confirm()).is_true()

	# Assert — effective_atk() 反映卡片 delta_atk,牌離開手牌
	assert_int(state.unit_by_id(P1).effective_atk()).is_equal(atk_before + 3)
	assert_bool(deck.hand().has(atk_card)).is_false()
	assert_bool(deck.used().has(atk_card)).is_true()
	# 甲類卡不觸及好感度寫入埠
	assert_int(write_port.calls.size()).is_equal(0)


# ---- AC-P2:確認前取消 -> 手牌逐字未變、無任何修正產生、盤面未變 -----------------

func test_ac_p2_cancel_before_confirm_leaves_hand_modifiers_and_board_untouched() -> void:
	# Arrange
	var atk_card: Card = Card.new_temporary_stat_modifier("atk_up_3", 3, 0, 2)
	var deck: CardDeck = CardDeck.new([atk_card], RandomNumberGenerator.new())
	var built: Dictionary = _build_controller(_roster_lines(), deck)
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	var atk_before: int = state.unit_by_id(P1).effective_atk()

	# Act — 走到確認前一步(選好對象,S2 -> S3),然後一路取消回 S0,從未呼叫 confirm()
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(atk_card)).is_true()
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.cancel()).is_true()  # CONFIRMING -> SELECTING_TARGET
	assert_bool(controller.cancel()).is_true()  # SELECTING_TARGET -> SELECTING_CARD
	assert_bool(controller.cancel()).is_true()  # SELECTING_CARD -> CLOSED

	# Assert — 手牌逐字未變、無任何修正產生、盤面未變
	assert_int(deck.hand_size()).is_equal(1)
	assert_bool(deck.hand().has(atk_card)).is_true()
	assert_int(deck.used_size()).is_equal(0)
	assert_int(state.unit_by_id(P1).active_modifiers().size()).is_equal(0)
	assert_int(state.unit_by_id(P1).effective_atk()).is_equal(atk_before)


# ---- AC-P3:欠棄牌時 open_hand/select_card 不擋,select_target/confirm/cancel 全擋 --
#
# 🔴 正面控制組先行:下面第一條測試證明「不欠棄牌時,同一條 select_target() ->
# confirm() 呼叫序列透過 controller 確實會成功」——沒有這一條,第二條測試在
# select_target()/confirm() 兩個方法根本沒接上 CardPlaySession(永遠回傳 false)
# 的情況下,一樣會通過。

func test_ac_p3_positive_control_select_target_and_confirm_succeed_when_not_pending_discard() -> void:
	# Arrange
	var atk_card: Card = Card.new_temporary_stat_modifier("atk_up_1", 1, 0, 1)
	var deck: CardDeck = CardDeck.new([atk_card], RandomNumberGenerator.new())
	var built: Dictionary = _build_controller(_roster_lines(), deck)
	var controller: BattleController = built["controller"]
	assert_bool(controller.has_pending_discard()).is_false()

	# Act / Assert — 未欠棄牌,同一組呼叫序列必須成功
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(atk_card)).is_true()
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.confirm()).is_true()


func test_ac_p3_select_target_confirm_cancel_blocked_while_open_hand_select_card_legal_targets_are_not() -> void:
	# Arrange — 逼進欠棄牌狀態
	var built: Dictionary = _controller_with_pending_discard(803)
	var deck: CardDeck = built["deck"]
	var controller: BattleController = built["controller"]
	assert_bool(controller.has_pending_discard()).is_true()

	# Act / Assert — 三個不擋的動作:玩家要靠它們挑棄哪一張,且手牌必須攤開、
	# 收不起來(design/ux/skill-card-play.md S4)
	assert_bool(controller.open_hand()).is_true()
	var card_in_hand: Card = deck.hand()[0]
	assert_bool(controller.select_card(card_in_hand)).is_true()
	assert_array(controller.legal_targets()).is_not_empty()

	# Act / Assert — 三個被擋的動作,拒絕可觀測(回傳 false,不是靜默無反應)
	assert_bool(controller.select_target(P1)).is_false()
	assert_bool(controller.confirm()).is_false()
	assert_bool(controller.cancel()).is_false()


# ---- AC-P4:棄掉一張 -> 上述被擋的三個動作全部恢復可用 --------------------------

func test_ac_p4_discarding_resolves_gate_and_select_target_confirm_cancel_resume() -> void:
	# Arrange
	var built: Dictionary = _controller_with_pending_discard(804)
	var deck: CardDeck = built["deck"]
	var controller: BattleController = built["controller"]
	assert_bool(controller.open_hand()).is_true()
	var hand_now: Array[Card] = deck.hand()
	var card_to_discard: Card = hand_now[0]
	var card_to_play: Card = hand_now[1]
	assert_bool(controller.select_card(card_to_play)).is_true()

	# Act 1 / Assert 1 — 解閘前,select_target() 仍被擋
	assert_bool(controller.select_target(P1)).is_false()

	# Act 2 — 玩家指定哪一張棄掉,解閘
	assert_bool(controller.resolve_forced_discard(card_to_discard)).is_true()
	assert_bool(controller.has_pending_discard()).is_false()

	# Act 3 / Assert 2 — select_target -> cancel -> select_target -> confirm,
	# 三個動作全部恢復可用(cancel 退回 SELECTING_TARGET,不是被拒的 false)
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.cancel()).is_true()
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.confirm()).is_true()
	assert_bool(deck.hand().has(card_to_play)).is_false()
	assert_bool(deck.used().has(card_to_play)).is_true()


# ---- AC-P5:打牌不消耗移動/攻擊旗標,且同回合可連打 ------------------------------

func test_ac_p5_playing_cards_does_not_consume_flags_and_allows_multiple_plays_per_turn() -> void:
	# Arrange
	var cards: Array[Card] = [
		Card.new_temporary_stat_modifier("c1", 1, 0, 1),
		Card.new_temporary_stat_modifier("c2", 1, 0, 1),
	]
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	var built: Dictionary = _build_controller(_roster_lines(), deck)
	var order: TurnOrder = built["order"]
	var controller: BattleController = built["controller"]
	assert_bool(order.can_move(P1)).is_true()
	assert_bool(order.can_attack(P1)).is_true()

	# Act — 同一回合連打兩張
	for card: Card in cards:
		assert_bool(controller.open_hand()).is_true()
		assert_bool(controller.select_card(card)).is_true()
		assert_bool(controller.select_target(P1)).is_true()
		assert_bool(controller.confirm()).is_true()

	# Assert — 兩個旗標逐字不變,兩張牌都真的打出去了
	assert_bool(order.can_move(P1)).is_true()
	assert_bool(order.can_attack(P1)).is_true()
	assert_int(deck.used_size()).is_equal(2)


# ---- AC-P6:未附卡池 -> 打牌相關查詢安全回傳「沒有」,整場戰鬥不崩潰 --------------

func test_ac_p6_battle_without_card_deck_returns_safe_defaults_and_never_crashes() -> void:
	# Arrange
	var built: Dictionary = _build_controller(_roster_lines(), null)
	var controller: BattleController = built["controller"]

	# Act / Assert — 每一個打牌相關方法都安全回傳「沒有」,不崩潰
	assert_bool(controller.open_hand()).is_false()
	assert_bool(controller.select_card(Card.new_temporary_stat_modifier("x", 1, 0, 1))).is_false()
	assert_array(controller.legal_targets()).is_empty()
	assert_bool(controller.select_target(P1)).is_false()
	assert_bool(controller.select_second_target(P1)).is_false()
	assert_bool(controller.confirm()).is_false()
	assert_bool(controller.cancel()).is_false()

	# Assert — 整場戰鬥仍能正常跑完一輪轉換(比照 AC-W6)
	controller.end_faction_phase()
	controller.run_enemy_phase()
	assert_int(controller.round_number()).is_equal(2)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


# ---- AC-P7:未附寫入埠 -> 丙類確認回傳可觀測拒絕,好感度零寫入,不崩潰、不靜默成功 --
#
# 對照組寫在下面第二條:同樣的丙類流程,這次附上一個會接受寫入的假埠 —— 證明
# 第一條測試的失敗確實是「沒附埠」造成的(NullAffinityWritePort 真的被觸及),
# 不是這條打牌路徑本身其他地方的缺陷。

func test_ac_p7_missing_write_port_rejects_confirm_without_crashing_or_silent_success() -> void:
	# Arrange — 丙類卡,合法配對(P1-P2 有關係線且皆存活),建構時刻意不附 write_port
	var bond_card: Card = Card.new_permanent_affinity_write("bond_test", P1, P2, 2)
	var deck: CardDeck = CardDeck.new([bond_card], RandomNumberGenerator.new())
	var built: Dictionary = _build_controller(_roster_lines(), deck, _default_links())
	var controller: BattleController = built["controller"]

	# Act
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(bond_card)).is_true()
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.select_second_target(P2)).is_true()
	var confirmed: bool = controller.confirm()

	# Assert — 不崩潰(能跑到這裡本身就是證明)、可觀測拒絕、零寫入
	assert_bool(confirmed).is_false()
	assert_bool(deck.hand().has(bond_card)).is_true()
	assert_int(deck.used_size()).is_equal(0)


func test_ac_p7_positive_control_confirm_succeeds_when_a_real_write_port_is_supplied() -> void:
	# Arrange — 同樣的丙類流程,這次附上真的會接受寫入的假埠
	var bond_card: Card = Card.new_permanent_affinity_write("bond_test", P1, P2, 2)
	var deck: CardDeck = CardDeck.new([bond_card], RandomNumberGenerator.new())
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var built: Dictionary = _build_controller(_roster_lines(), deck, _default_links(), write_port)
	var controller: BattleController = built["controller"]

	# Act
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(bond_card)).is_true()
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.select_second_target(P2)).is_true()
	var confirmed: bool = controller.confirm()

	# Assert — 這次真的成功,證明上一條測試的拒絕確實是「沒附埠」造成的
	assert_bool(confirmed).is_true()
	assert_int(write_port.accepted_count).is_equal(1)
	assert_bool(deck.hand().has(bond_card)).is_false()
	assert_bool(deck.used().has(bond_card)).is_true()


# ---- AC-P8:打牌後,與畫面呈現同一份的傷害預判查詢反映新值 ----------------------

func test_ac_p8_preview_damage_after_playing_a_card_reflects_new_value_via_state_preview_damage() -> void:
	# Arrange
	var atk_card: Card = Card.new_temporary_stat_modifier("atk_up_3", 3, 0, 2)
	var deck: CardDeck = CardDeck.new([atk_card], RandomNumberGenerator.new())
	var built: Dictionary = _build_controller(_roster_lines(), deck)
	var state: BattleState = built["state"]
	var controller: BattleController = built["controller"]
	# 🔴 必須呼叫 BattleState.preview_damage() 本身,不得自行重算 CombatRules.damage()
	var damage_before: int = state.preview_damage(P1, ENEMY, 0)

	# Act
	assert_bool(controller.open_hand()).is_true()
	assert_bool(controller.select_card(atk_card)).is_true()
	assert_bool(controller.select_target(P1)).is_true()
	assert_bool(controller.confirm()).is_true()
	var damage_after: int = state.preview_damage(P1, ENEMY, 0)

	# Assert
	assert_int(damage_after).is_equal(damage_before + 3)
