# Story 017 補血卡與雙人甲類(距離過濾、夾限、免選目標)的單元測試。
# production/epics/skill-card-system/story-017-heal-and-two-target-buff-cards.md
#
# 檔案存取:乙類例外(唯讀原始碼文字)—— 只有 AC6 一條測試讀 res://src/gameplay/cards/card_play_session.gd
# 的文字,斷言「距離一律呼叫既有 AffinityRules.manhattan_distance、本檔案內沒有自寫曼哈頓」。
# 為何不能用注入取代:斷言對象就是原始碼文字本身。
# 🔴 自陳範圍(非窮盡):只掃 card_play_session.gd 一個檔;別的檔案長出第三份距離實作,
# 這條測試看不見。全庫掃描請用工單 AC6 的 grep 指令。其餘測試全為記憶體內夾具。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):CardPlaySession 的私有 seam 可被子類別覆寫,
# 每個 mutant 跑與真品相同的情境函式,真品必須回 true、mutant 必須回 false;每個 mutant
# 各自是一條獨立測試(一次一個)。
# 證明不了的(誠實登記):①AC2 的 mutant 只證明「邊界值 == target_range 可打」;距離計算本身
# 用的是共用函式,其正確性不在本檔證明範圍。
extends GdUnitTestSuite

const _SOURCE_PATH: String = "res://src/gameplay/cards/card_play_session.gd"


# ---- 夾具 -------------------------------------------------------------------

## [param xs]:unit id -> x 座標(全部在 y=0 一列,距離 = x 差)。四個我方 hp_max 20,一個敵人。
func _build_state(xs: Dictionary) -> BattleState:
	var lines: Array[String] = []
	for id: int in [1, 2, 3, 4]:
		lines.append("%d,P%d,PLAYER,20,10,3,1,1,1,%d,0" % [id, id, int(xs.get(id, id))])
	lines.append("9,E1,ENEMY,20,5,3,1,1,1,0,3")
	return BattleState.create(PackedStringArray(), "\n".join(lines))


func _wound(state: BattleState, unit_id: int, hp: int) -> void:
	state.commit_authoritative_change(func() -> void:
		state.unit_by_id(unit_id).hp = hp
	)


func _kill(state: BattleState, unit_id: int) -> void:
	state.unit_by_id(unit_id).take_damage(999)


func _session(script: GDScript, state: BattleState, cards: Array[Card]) -> CardPlaySession:
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = script.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(AffinityDataPool.new())  # 空池 -> 關係態 NONE -> 付血 hp_cost_none
	return session


## c04 輸血:徐培恩付 6 血,補距離 <=1 的缺血隊友 10。
func _c04(payer: int) -> Card:
	var card: Card = Card.new()
	card.id = "c04"
	card.category = Card.Category.HEAL
	card.cost_type = Card.CostType.HP
	card.cost_amount = 6
	card.effect_value = 10
	card.named_unit_id = payer
	card.target_range = 1
	return card


## c06 咬牙衝刺:自己 ATK +3 且 DEF -2,2 回合,付 3 血(target_range 0 = 自己)。
func _c06(payer: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("c06", 3, -2, 2, payer)
	card.cost_type = Card.CostType.HP
	card.cost_amount = 3
	card.target_range = 0
	return card


## c07 扛下:麥子健付 4 血,玩家選一名 <=2 的隊友 DEF +3,2 回合。
func _c07(payer: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("c07", 0, 3, 2, payer)
	card.cost_type = Card.CostType.HP
	card.cost_amount = 4
	card.target_range = 2
	return card


## c09/c10/c11 型:雙人甲類,兩人自動為目標,距離 <=2。
func _duo_buff(id: String, a: int, b: int, atk: int, def: int, duration: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier(id, atk, def, duration, a)
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.partner_unit_id = b
	card.target_range = 2
	return card


## c13/c14 型:付款 a、承受 b(partner),補 [param effect]。
func _directed_heal(id: String, payer: int, recipient: int, effect: int, range_limit: int) -> Card:
	var card: Card = Card.new()
	card.id = id
	card.category = Card.Category.HEAL
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.effect_value = effect
	card.named_unit_id = payer
	card.partner_unit_id = recipient
	card.target_range = range_limit
	return card


func _play_pick(session: CardPlaySession, card: Card, target: int) -> bool:
	if not session.open_hand() or not session.select_card(card):
		return false
	if not session.select_target(target):
		session.cancel()
		return false
	return session.confirm()


func _play_fixed(session: CardPlaySession, card: Card) -> bool:
	if not session.open_hand() or not session.select_card(card):
		return false
	return session.confirm()


class _GuardSpy extends RefCounted:
	var calls: int = 0
	var state: BattleState

	func _init(p_state: BattleState) -> void:
		state = p_state

	func check() -> bool:
		calls += 1
		return state.write_window_is_open()


# ---- mutants(每個只覆寫一個 seam)-------------------------------------------------

## ① 距離判斷 < 取代 <=。
class _MutantStrictRange extends CardPlaySession:
	func _within_range(distance: int, range_limit: int) -> bool:
		return distance < range_limit


## ② 補血不夾限。
class _MutantNoClamp extends CardPlaySession:
	func _heal_amount(_unit: Unit, effect_value: int) -> int:
		return effect_value


## ③ 只掛一人修正器。
class _MutantOneModifier extends CardPlaySession:
	func _attach_stat_modifiers(card: Card, unit_ids: Array[int]) -> void:
		var first_only: Array[int] = [unit_ids[0]]
		super(card, first_only)


## ④ 雙人不查存活。
class _MutantNoAliveCheck extends CardPlaySession:
	func _is_present(unit: Unit) -> bool:
		return unit != null


## ⑥ 補血繞過守衛(窗口外寫法:直接寫私有欄位)。
class _MutantHealBypassesGuard extends CardPlaySession:
	func _apply_heal_in_window(unit: Unit, amount: int) -> void:
		unit._hp = unit._hp + amount


# ---- 情境函式(true = 該 AC 成立)--------------------------------------------------

func _scn_ac2_boundaries(script: GDScript) -> bool:
	# c07 範圍 2:距離 2 的隊友合法;c09 範圍 2:兩人距離 2 可打、距離 3 不可打。
	var state: BattleState = _build_state({1: 0, 2: 2, 3: 5, 4: 8})
	var c07: Card = _c07(1)
	var near: Card = _duo_buff("c09_near", 1, 2, 2, 0, 1)
	var far: Card = _duo_buff("c09_far", 1, 3, 2, 0, 1)
	var session: CardPlaySession = _session(script, state, [c07, near, far])
	session.open_hand()
	session.select_card(c07)
	var c07_ok: bool = session.legal_targets().has(2)
	session.cancel()
	return c07_ok and session.is_card_playable(near) and not session.is_card_playable(far)


func _scn_ac1_heal_clamp(script: GDScript) -> bool:
	var state: BattleState = _build_state({})
	_wound(state, 2, 18)
	var card: Card = _directed_heal("c13", 1, 2, 12, 3)
	var session: CardPlaySession = _session(script, state, [card])
	var played: bool = _play_fixed(session, card)
	return played and state.unit_by_id(2).hp == 20


func _scn_ac4_both_modifiers(script: GDScript) -> bool:
	var state: BattleState = _build_state({})
	var card: Card = _duo_buff("c09", 1, 2, 2, 0, 1)
	var session: CardPlaySession = _session(script, state, [card])
	var played: bool = _play_fixed(session, card)
	return played and state.unit_by_id(1).active_modifiers().size() == 1 \
		and state.unit_by_id(2).active_modifiers().size() == 1


func _scn_ac3_dead_partner(script: GDScript) -> bool:
	var state: BattleState = _build_state({})
	_kill(state, 2)
	var card: Card = _duo_buff("c09", 1, 2, 2, 0, 1)
	card.target_range = -1  # 不查距離:隔離出「存活」這一個條件(死者位置不保證可讀)
	var session: CardPlaySession = _session(script, state, [card])
	# 正向關係 -> 折損代價(不付血);否則死者會先被「付不起血(hp 0)」擋下,
	# 存活檢查就不是唯一把關者,mutant 會被別的條件掩蓋。
	var pool: AffinityDataPool = AffinityDataPool.new()
	pool.append_record(AffinityTypes.Pair.C1_C2 as AffinityTypes.Pair, 1.0, AffinityTypes.Source.STORY_EVENT)
	session.attach_affinity_pool(pool)
	var version: int = state.combat_state_version
	var played: bool = _play_fixed(session, card)
	return not played and not session.is_card_playable(card) \
		and state.combat_state_version == version \
		and state.unit_by_id(1).active_modifiers().is_empty()


func _scn_ac7_heal_inside_window(script: GDScript) -> bool:
	var state: BattleState = _build_state({})
	_wound(state, 2, 5)
	var card: Card = _directed_heal("c13", 1, 2, 12, 3)
	var session: CardPlaySession = _session(script, state, [card])
	var spy: _GuardSpy = _GuardSpy.new(state)
	state.unit_by_id(2).attach_write_guard(spy.check)
	var version: int = state.combat_state_version
	var played: bool = _play_fixed(session, card)
	return played and state.unit_by_id(2).hp == 17 and spy.calls >= 1 \
		and state.combat_state_version == version + 1


# ---- AC1 補血 ----------------------------------------------------------------

func test_heal_ac1_c04_heals_effect_value_to_a_wounded_teammate() -> void:
	var state: BattleState = _build_state({1: 0, 2: 1})
	_wound(state, 2, 5)
	var card: Card = _c04(1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	assert_bool(_play_pick(session, card, 2)).is_true()
	assert_int(state.unit_by_id(2).hp).is_equal(15)
	assert_int(state.unit_by_id(1).hp).is_equal(14)  # 付款人付 6 血


func test_heal_ac1_amount_never_exceeds_max_hp() -> void:
	assert_bool(_scn_ac1_heal_clamp(CardPlaySession)).is_true()


func test_heal_ac1_full_health_recipient_makes_card_unplayable() -> void:
	var state: BattleState = _build_state({1: 0, 2: 1})
	var c04: Card = _c04(1)
	var c13: Card = _directed_heal("c13", 3, 4, 12, 3)
	var session: CardPlaySession = _session(CardPlaySession, state, [c04, c13])
	assert_int(session.card_unplayable_reason(c04)).is_equal(CardCostPlan.Reason.TARGET_HP_FULL)
	assert_int(session.card_unplayable_reason(c13)).is_equal(CardCostPlan.Reason.TARGET_HP_FULL)


func test_heal_ac1_c04_payer_is_never_a_legal_recipient_even_when_wounded() -> void:
	var state: BattleState = _build_state({1: 0, 2: 1})
	_wound(state, 1, 10)
	_wound(state, 2, 10)
	var card: Card = _c04(1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	session.open_hand()
	session.select_card(card)
	assert_array(session.legal_targets()).is_equal([2])
	assert_bool(session.select_target(1)).is_false()


func test_heal_ac1_c07_buffs_only_the_one_chosen_teammate() -> void:
	var state: BattleState = _build_state({1: 0, 2: 1, 3: 2})
	var card: Card = _c07(1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	session.open_hand()
	session.select_card(card)
	assert_array(session.legal_targets()).contains_exactly_in_any_order([2, 3])  # 不含麥子健自己
	assert_bool(session.select_target(2)).is_true()
	assert_bool(session.confirm()).is_true()
	assert_int(state.unit_by_id(2).active_modifiers().size()).is_equal(1)
	assert_int(state.unit_by_id(3).active_modifiers().size()).is_equal(0)
	assert_int(state.unit_by_id(1).active_modifiers().size()).is_equal(0)


# ---- AC2 距離 ----------------------------------------------------------------

func test_heal_ac2_c04_range_one_inside_and_plus_one_outside() -> void:
	var inside: BattleState = _build_state({1: 0, 2: 1})
	_wound(inside, 2, 5)
	var outside: BattleState = _build_state({1: 0, 2: 2})
	_wound(outside, 2, 5)
	var card: Card = _c04(1)
	assert_bool(_session(CardPlaySession, inside, [card]).is_card_playable(card)).is_true()
	assert_bool(_session(CardPlaySession, outside, [card]).is_card_playable(card)).is_false()


func test_heal_ac2_c07_range_two_inside_and_plus_one_outside() -> void:
	var state: BattleState = _build_state({1: 0, 2: 2, 3: 3})
	var card: Card = _c07(1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	session.open_hand()
	session.select_card(card)
	assert_array(session.legal_targets()).is_equal([2])


func test_heal_ac2_c13_range_three_boundary() -> void:
	var card: Card = _directed_heal("c13", 1, 2, 12, 3)
	for case: Array in [[3, true], [4, false]]:
		var state: BattleState = _build_state({1: 0, 2: int(case[0])})
		_wound(state, 2, 5)
		assert_bool(_session(CardPlaySession, state, [card]).is_card_playable(card)).is_equal(case[1])


func test_heal_ac2_c14_range_two_boundary() -> void:
	var card: Card = _directed_heal("c14", 3, 1, 10, 2)
	for case: Array in [[2, true], [3, false]]:
		var state: BattleState = _build_state({3: 0, 1: int(case[0])})
		_wound(state, 1, 5)
		assert_bool(_session(CardPlaySession, state, [card]).is_card_playable(card)).is_equal(case[1])


func test_buff_ac2_c09_c10_c11_range_two_boundary_each() -> void:
	var cards: Array[Card] = [
		_duo_buff("c09", 1, 2, 2, 0, 1),
		_duo_buff("c10", 1, 2, 0, 2, 2),
		_duo_buff("c11", 3, 4, 2, 0, 1),
	]
	for card: Card in cards:
		for case: Array in [[2, true], [3, false]]:
			var xs: Dictionary = {card.named_unit_id: 0, card.partner_unit_id: int(case[0])}
			var state: BattleState = _build_state(xs)
			assert_bool(_session(CardPlaySession, state, [card]).is_card_playable(card)) \
				.append_failure_message("%s at distance %d" % [card.id, int(case[0])]).is_equal(case[1])


# ---- AC3 雙人存活 ---------------------------------------------------------------

func test_buff_ac3_dead_partner_or_dead_payer_blocks_play_with_zero_writes() -> void:
	assert_bool(_scn_ac3_dead_partner(CardPlaySession)).is_true()
	var state: BattleState = _build_state({})
	_kill(state, 1)
	var card: Card = _duo_buff("c09", 1, 2, 2, 0, 1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	var version: int = state.combat_state_version
	assert_bool(_play_fixed(session, card)).is_false()
	assert_int(state.combat_state_version).is_equal(version)
	assert_int(state.unit_by_id(2).hp).is_equal(20)


func test_heal_ac3_dead_recipient_blocks_fixed_heal_with_zero_writes() -> void:
	var state: BattleState = _build_state({})
	_kill(state, 2)
	var card: Card = _directed_heal("c13", 1, 2, 12, 3)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	var version: int = state.combat_state_version
	assert_bool(_play_fixed(session, card)).is_false()
	assert_int(state.combat_state_version).is_equal(version)
	assert_int(state.unit_by_id(1).hp).is_equal(20)


# ---- AC4 雙人甲類 ------------------------------------------------------------------

func test_buff_ac4_both_units_get_a_modifier_with_the_card_values() -> void:
	assert_bool(_scn_ac4_both_modifiers(CardPlaySession)).is_true()
	var state: BattleState = _build_state({})
	var card: Card = _duo_buff("c09", 1, 2, 2, 0, 1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	assert_bool(_play_fixed(session, card)).is_true()
	for id: int in [1, 2]:
		var mods: Array[CardModifier] = state.unit_by_id(id).active_modifiers()
		assert_int(mods[0].atk_delta).is_equal(2)
		assert_int(mods[0].remaining_turns).is_equal(1)


func test_buff_ac4_c06_atk_plus3_and_def_minus2_with_existing_fields() -> void:
	var state: BattleState = _build_state({})
	var card: Card = _c06(1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	assert_bool(_play_pick(session, card, 1)).is_true()
	var mods: Array[CardModifier] = state.unit_by_id(1).active_modifiers()
	assert_int(mods.size()).is_equal(1)
	assert_int(mods[0].atk_delta).is_equal(3)
	assert_int(mods[0].def_delta).is_equal(-2)
	assert_int(mods[0].remaining_turns).is_equal(2)


# ---- AC5 免選目標 ---------------------------------------------------------------------

func test_buff_ac5_fixed_target_card_skips_target_selection_and_cancel_steps_back_to_hand() -> void:
	var state: BattleState = _build_state({})
	var card: Card = _duo_buff("c09", 1, 2, 2, 0, 1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	var version: int = state.combat_state_version
	session.open_hand()
	assert_bool(session.select_card(card)).is_true()
	assert_int(session.step()).is_equal(CardPlaySession.Step.CONFIRMING)
	assert_array(session.legal_targets()).is_empty()
	assert_int(session.selected_target_a()).is_equal(1)
	assert_int(session.selected_target_b()).is_equal(2)
	session.cancel()
	assert_int(session.step()).is_equal(CardPlaySession.Step.SELECTING_CARD)
	assert_object(session.selected_card()).is_null()
	assert_int(state.combat_state_version).is_equal(version)
	assert_int(state.unit_by_id(1).hp).is_equal(20)
	assert_int(state.unit_by_id(1).active_modifiers().size()).is_equal(0)


func test_buff_ac5_fixed_heal_card_also_skips_target_selection() -> void:
	var state: BattleState = _build_state({})
	_wound(state, 2, 5)
	var card: Card = _directed_heal("c13", 1, 2, 12, 3)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	session.open_hand()
	session.select_card(card)
	assert_int(session.step()).is_equal(CardPlaySession.Step.CONFIRMING)


func test_buff_ac5_ordinary_single_target_card_still_goes_through_target_selection() -> void:
	var state: BattleState = _build_state({})
	var card: Card = Card.new_temporary_stat_modifier("plain", 1, 0, 1)
	var session: CardPlaySession = _session(CardPlaySession, state, [card])
	session.open_hand()
	session.select_card(card)
	assert_int(session.step()).is_equal(CardPlaySession.Step.SELECTING_TARGET)
	assert_array(session.legal_targets()).is_not_empty()


# ---- AC6 不新增距離實作(乙類:讀原始碼文字)-----------------------------------------------

## 自寫曼哈頓的偵測器:非註解行含 abs(..)+abs(..) 或 func 名稱含 manhattan。
func _own_distance_impl_count(text: String) -> int:
	var pattern: RegEx = RegEx.new()
	pattern.compile("abs\\(.*\\)\\s*\\+\\s*abs\\(|^(static\\s+)?func\\s+\\w*manhattan")
	var count: int = 0
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("#"):
			continue
		if pattern.search(line) != null:
			count += 1
	return count


func test_heal_ac6_session_source_defines_no_distance_function_and_calls_the_existing_one() -> void:
	var file: FileAccess = FileAccess.open(_SOURCE_PATH, FileAccess.READ)
	assert_object(file).is_not_null()
	var text: String = file.get_as_text()
	assert_int(_own_distance_impl_count(text)).is_equal(0)
	assert_bool(text.contains("AffinityRules.manhattan_distance(")).is_true()


# ---- AC7 提交內 ---------------------------------------------------------------------------

func test_heal_ac7_heal_goes_through_the_guarded_setter_and_bumps_version_once() -> void:
	assert_bool(_scn_ac7_heal_inside_window(CardPlaySession)).is_true()


# ---- AC8 敏感度證明(常駐)---------------------------------------------------------------

func test_sensitivity_proof_real_session_passes_every_scenario() -> void:
	assert_bool(_scn_ac2_boundaries(CardPlaySession)).is_true()
	assert_bool(_scn_ac1_heal_clamp(CardPlaySession)).is_true()
	assert_bool(_scn_ac4_both_modifiers(CardPlaySession)).is_true()
	assert_bool(_scn_ac3_dead_partner(CardPlaySession)).is_true()
	assert_bool(_scn_ac7_heal_inside_window(CardPlaySession)).is_true()


func test_sensitivity_proof_mutant1_strict_range_fails_ac2() -> void:
	assert_bool(_scn_ac2_boundaries(_MutantStrictRange)).is_false()


func test_sensitivity_proof_mutant2_unclamped_heal_fails_ac1() -> void:
	assert_bool(_scn_ac1_heal_clamp(_MutantNoClamp)).is_false()


func test_sensitivity_proof_mutant3_single_modifier_fails_ac4() -> void:
	assert_bool(_scn_ac4_both_modifiers(_MutantOneModifier)).is_false()


func test_sensitivity_proof_mutant4_no_alive_check_fails_ac3() -> void:
	assert_bool(_scn_ac3_dead_partner(_MutantNoAliveCheck)).is_false()


## ⑤ 自寫一份曼哈頓:偵測器對含自寫實作的文字必須回非 0(對真品原始碼回 0 見 AC6 測試)。
func test_sensitivity_proof_mutant5_own_manhattan_fails_ac6() -> void:
	var planted: String = "func _dist(a: Vector2i, b: Vector2i) -> int:\n\treturn abs(a.x - b.x) + abs(a.y - b.y)\n"
	assert_int(_own_distance_impl_count(planted)).is_equal(1)
	var named: String = "static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:\n\treturn 0\n"
	assert_int(_own_distance_impl_count(named)).is_equal(1)


func test_sensitivity_proof_mutant6_heal_outside_guard_fails_ac7() -> void:
	assert_bool(_scn_ac7_heal_inside_window(_MutantHealBypassesGuard)).is_false()
