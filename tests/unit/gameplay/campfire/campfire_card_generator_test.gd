## campfire_card_generator_test.gd
##
## 實作依據:production/epics/campfire/story-003-campfire-card-generation.md
## AC1(合作卡公式與夾限)、AC2(競爭卡鏡像)、AC3(快照)、AC4(欄位/含麥子健)、
## AC5(戰鬥中打出:真實 BattleState + CardPlaySession)、AC6(敏感度證明)。
##
## 檔案存取:僅 test_template_data_file_* 一條讀 assets/data/campfire/campfire_card_template.txt
## (註冊例外 1:唯讀、版控內真實資料檔;不證明窮盡性)。其餘純記憶體。
##
## 池值來源:真實 [AffinityDataPool] 連寫 +1.0(STORY_EVENT),實測 v = 1.0, 1.94, 2.8236, 3.654,
## 4.435, 5.169(n = 1..6,含時間衰減);測試先斷言 v 落在預期區間再斷言 E,
## 衰減常數若被調校,前置斷言會先紅並指出是池值變了而非公式壞了。
##
## 🔴 AC5 的限制(誠實登記):用真實 BattleState + CardPlaySession(與 tests/integration/gameplay/
## cards/card_cost_pair_state_test.gd 同一做法),【不是】載入真實 BattleScreen.tscn ——
## BattleScreen 沒有「注入手牌」的縫(未逐行驗證),本單未新增。
##
## 敏感度證明:常駐 test_sensitivity_proof_*,一個 mutant 一條、各自獨立;mutant 為
## CampfireCardGenerator 子類別覆寫受保護覆寫點,與真品共用同一個情境函式。
## mutant ③「產卡後讀即時池值」是【模擬】:Card 是純值、不持有池,無法真的即時讀;
## mutant 以「每次產新卡就把先前發出的卡改寫成新值」重現「卡面跟著池走」的行為。
extends GdUnitTestSuite

const _C := AffinityTypes.Character
const _P: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2
const _TEMPLATE_TEXT: String = "base_value,2\nmax_bonus,4\npool_step,2\nduration_rounds,2\ncost_amount,1\ntarget_range,2\ncompetitive_delta_def,-2\n"
const _CARE: CampfireWritePort.Action = CampfireWritePort.Action.CARE
const _QUESTION: CampfireWritePort.Action = CampfireWritePort.Action.QUESTION


# ---- mutants(僅供敏感度證明)------------------------------------------------

## ① 公式漏扣 k。
class _MutantNoK extends CampfireCardGenerator:
	func _k() -> float:
		return 0.0


## ② 競爭卡用 v 而非 -v。
class _MutantQuestionUsesPlusV extends CampfireCardGenerator:
	func _signed_v(_action: CampfireWritePort.Action, v: float) -> float:
		return v


## ③ 卡面跟著池走(模擬):新產一張卡就把先前發出的卡改寫成新卡的值。
class _MutantLiveRead extends CampfireCardGenerator:
	var issued: Array[Card] = []

	func generate(card_id: String, first: AffinityTypes.Character, second: AffinityTypes.Character, action: CampfireWritePort.Action, pool: AffinityDataPool) -> Card:
		var fresh: Card = super(card_id, first, second, action, pool)
		for old: Card in issued:
			old.delta_atk = fresh.delta_atk
			old.delta_def = fresh.delta_def
			old.effect_value = fresh.effect_value
		issued.append(fresh)
		return fresh


## ④ E 只寫 effect_value,不寫 delta_*。
class _MutantNoDeltas extends CampfireCardGenerator:
	func _deltas(_action: CampfireWritePort.Action, _e: int) -> Vector2i:
		return Vector2i(0, 0)


# ---- helpers -----------------------------------------------------------------

func _template() -> CampfireCardTemplate:
	var t: CampfireCardTemplate = CampfireCardTemplate.from_text(_TEMPLATE_TEXT)
	assert_object(t).is_not_null()
	return t


func _pool_with(m: float, times: int) -> AffinityDataPool:
	var pool: AffinityDataPool = AffinityDataPool.new()
	for i: int in range(times):
		var r: AffinityDataPool.WriteRejection = pool.append_record(_P, m, AffinityTypes.Source.STORY_EVENT)
		if r != AffinityDataPool.WriteRejection.NONE:
			fail("fixture append_record rejected: %d" % r)
	return pool


func _v(pool: AffinityDataPool) -> float:
	return pool.combat_strength_read(_P).value


# ---- 情境函式(真品回 true、mutant 回 false)--------------------------------------

## AC1:k=0.5、step 2、max_bonus 4 的邊界(純公式,直接餵 v_signed)。
func _scn_formula_boundaries(gen: CampfireCardGenerator) -> bool:
	return gen._strength(0.5) == 2 and gen._strength(2.4) == 2 and gen._strength(2.5) == 3 \
		and gen._strength(4.5) == 4 and gen._strength(8.5) == 6 and gen._strength(100.0) == 6 \
		and gen._strength(-3.0) == 2


## AC2:池為負(v≈-2.82)時,質問卡拿到加成 E=3、關心卡只有 base 2。
func _scn_question_mirror(gen: CampfireCardGenerator) -> bool:
	var pool: AffinityDataPool = _pool_with(-1.0, 3)
	var q: Card = gen.generate("q", _C.CHARACTER_1, _C.CHARACTER_2, _QUESTION, pool)
	var c: Card = gen.generate("c", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, pool)
	return q != null and c != null and q.effect_value == 3 and q.delta_atk == 3 and q.delta_def == -2 \
		and c.effect_value == 2 and c.delta_def == 2 and c.delta_atk == 0


## AC3:產卡後再寫池,先前那張卡的 E 不變(且新卡確實不同,證明池真的動了)。
func _scn_snapshot(gen: CampfireCardGenerator) -> bool:
	var pool: AffinityDataPool = _pool_with(1.0, 3)
	var a: Card = gen.generate("a", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, pool)
	for i: int in range(3):
		pool.append_record(_P, 1.0, AffinityTypes.Source.STORY_EVENT)
	var b: Card = gen.generate("b", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, pool)
	return a != null and b != null and a.effect_value == 3 and a.delta_def == 3 \
		and b.effect_value == 4 and b.delta_def == 4


## AC5 用:建一個含 P1..P3 的真實戰鬥狀態(P1 (0,0)、P2 (1,0))。
func _build_state() -> BattleState:
	var lines: Array[String] = [
		"1,P1,PLAYER,20,10,3,1,1,1,0,0",
		"2,P2,PLAYER,20,8,2,1,1,1,1,0",
		"3,P3,PLAYER,20,8,2,1,1,1,6,0",
		"9,E1,ENEMY,20,5,3,1,1,1,3,3",
	]
	return BattleState.create(PackedStringArray(), "\n".join(lines))


func _play_camp_card(card: Card, state: BattleState, pool: AffinityDataPool) -> bool:
	var deck: CardDeck = CardDeck.new([card] as Array[Card], RandomNumberGenerator.new())
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = CardPlaySession.new(deck, state, links, NullAffinityWritePort.new())
	session.attach_affinity_pool(pool)
	if not session.open_hand() or not session.select_card(card):
		return false
	if session.step() != CardPlaySession.Step.CONFIRMING and not session.select_target(1):
		return false
	return session.confirm()


## AC5:合作卡打出後,兩人身上都掛上 def_delta == E 的修正。
func _scn_battle_modifiers(gen: CampfireCardGenerator) -> bool:
	var pool: AffinityDataPool = _pool_with(1.0, 3)
	var card: Card = gen.generate("camp", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, pool)
	if card == null:
		return false
	var state: BattleState = _build_state()
	if not _play_camp_card(card, state, AffinityDataPool.new()):
		return false
	for id: int in [1, 2]:
		var mods: Array[CardModifier] = state.unit_by_id(id).active_modifiers()
		if mods.size() != 1 or mods[0].def_delta != 3:
			return false
	return state.unit_by_id(3).active_modifiers().is_empty()


# ---- AC1 ---------------------------------------------------------------------

func test_camp_card_ac1_formula_boundaries_with_k() -> void:
	assert_bool(_scn_formula_boundaries(CampfireCardGenerator.new(_template(), 0.5))).is_true()


func test_camp_card_ac1_care_from_real_pool_v_at_or_below_k_is_base() -> void:
	# Arrange:n=1 -> v=1.0;k=1.0 -> v<=k
	var pool: AffinityDataPool = _pool_with(1.0, 1)
	assert_float(_v(pool)).is_between(0.99, 1.01)
	var card: Card = CampfireCardGenerator.new(_template(), 1.0).generate("c", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, pool)
	assert_int(card.effect_value).is_equal(2)
	assert_int(card.delta_def).is_equal(2)
	assert_int(card.delta_atk).is_equal(0)


func test_camp_card_ac1_care_from_real_pool_middle_value() -> void:
	var pool: AffinityDataPool = _pool_with(1.0, 3)
	assert_float(_v(pool)).is_between(2.82, 2.83)
	var card: Card = CampfireCardGenerator.new(_template(), 0.5).generate("c", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, pool)
	assert_int(card.effect_value).is_equal(3)
	assert_int(card.delta_def).is_equal(3)
	assert_int(card.delta_atk).is_equal(0)


func test_camp_card_ac1_care_clamps_at_base_plus_max_bonus() -> void:
	# max_bonus 1 的模板:v≈5.17 遠大於 k,夾在 2+1。
	var t: CampfireCardTemplate = CampfireCardTemplate.from_text(_TEMPLATE_TEXT.replace("max_bonus,4", "max_bonus,1"))
	var pool: AffinityDataPool = _pool_with(1.0, 6)
	assert_float(_v(pool)).is_between(5.16, 5.17)
	var card: Card = CampfireCardGenerator.new(t, 0.0).generate("c", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, pool)
	assert_int(card.effect_value).is_equal(3)
	assert_int(card.delta_def).is_equal(3)


# ---- AC2 ---------------------------------------------------------------------

func test_camp_card_ac2_question_mirror_gets_bonus_on_negative_pool() -> void:
	assert_bool(_scn_question_mirror(CampfireCardGenerator.new(_template(), 0.5))).is_true()


func test_camp_card_ac2_question_on_positive_pool_is_base_only() -> void:
	var pool: AffinityDataPool = _pool_with(1.0, 3)
	var card: Card = CampfireCardGenerator.new(_template(), 0.5).generate("q", _C.CHARACTER_1, _C.CHARACTER_2, _QUESTION, pool)
	assert_int(card.effect_value).is_equal(2)
	assert_int(card.delta_atk).is_equal(2)
	assert_int(card.delta_def).is_equal(-2)


# ---- AC3 ---------------------------------------------------------------------

func test_camp_card_ac3_card_is_snapshot_after_later_writes() -> void:
	assert_bool(_scn_snapshot(CampfireCardGenerator.new(_template(), 0.5))).is_true()


# ---- AC4 ---------------------------------------------------------------------

func test_camp_card_ac4_fields_and_selection_order_with_mai() -> void:
	# CHARACTER_5(麥子健,roster 5)為第一人、CHARACTER_1 為第二人;空池 -> E = base。
	var pool: AffinityDataPool = AffinityDataPool.new()
	var card: Card = CampfireCardGenerator.new(_template(), 0.0).generate("m", _C.CHARACTER_5, _C.CHARACTER_1, _CARE, pool)
	assert_object(card).is_not_null()
	assert_int(card.cost_type).is_equal(Card.CostType.PAIR)
	assert_int(card.source).is_equal(Card.Source.CAMP)
	assert_int(card.named_unit_id).is_equal(5)
	assert_int(card.partner_unit_id).is_equal(1)
	assert_int(card.duration_rounds).is_equal(2)
	assert_int(card.cost_amount).is_equal(1)
	assert_int(card.target_range).is_equal(2)


func test_camp_card_invalid_inputs_return_null() -> void:
	var gen: CampfireCardGenerator = CampfireCardGenerator.new(_template(), 0.0)
	var pool: AffinityDataPool = AffinityDataPool.new()
	assert_object(gen.generate("x", _C.CHARACTER_1, _C.CHARACTER_1, _CARE, pool)).is_null()
	assert_object(gen.generate("x", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, null)).is_null()
	assert_object(gen.generate("x", _C.CHARACTER_1, _C.CHARACTER_2, 99 as CampfireWritePort.Action, pool)).is_null()


# ---- AC5 ---------------------------------------------------------------------

func test_camp_card_ac5_play_attaches_modifier_to_both_units() -> void:
	assert_bool(_scn_battle_modifiers(CampfireCardGenerator.new(_template(), 0.5))).is_true()


func test_camp_card_ac5_none_pays_hp_from_both() -> void:
	var gen: CampfireCardGenerator = CampfireCardGenerator.new(_template(), 0.5)
	var card: Card = gen.generate("camp", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, AffinityDataPool.new())
	var state: BattleState = _build_state()
	assert_bool(_play_camp_card(card, state, AffinityDataPool.new())).is_true()
	assert_int(state.unit_by_id(1).hp).is_less(20)
	assert_int(state.unit_by_id(2).hp).is_less(20)
	assert_int(state.pair_wear(_P)).is_equal(0)


func test_camp_card_ac5_pos_and_neg_go_to_wear_not_hp() -> void:
	for m: float in [1.0, -1.0]:
		var gen: CampfireCardGenerator = CampfireCardGenerator.new(_template(), 0.0)
		var card: Card = gen.generate("camp", _C.CHARACTER_1, _C.CHARACTER_2, _CARE, AffinityDataPool.new())
		var state: BattleState = _build_state()
		assert_bool(_play_camp_card(card, state, _pool_with(m, 1))).is_true()
		assert_int(state.unit_by_id(1).hp).is_equal(20)
		assert_int(state.unit_by_id(2).hp).is_equal(20)
		assert_int(state.pair_wear(_P)).is_equal(1)


# ---- 資料檔 --------------------------------------------------------------------

func test_template_data_file_parses() -> void:
	var t: CampfireCardTemplate = CampfireCardTemplate.from_file()
	assert_object(t).is_not_null()
	assert_int(t.base_value).is_equal(2)
	assert_int(t.max_bonus).is_equal(4)
	assert_int(t.pool_step).is_equal(2)
	assert_int(t.competitive_delta_def).is_equal(-2)


func test_template_rejects_missing_unknown_and_bad_values() -> void:
	assert_object(CampfireCardTemplate.from_text("base_value,2\n")).is_null()
	assert_object(CampfireCardTemplate.from_text(_TEMPLATE_TEXT + "extra,1\n")).is_null()
	assert_object(CampfireCardTemplate.from_text(_TEMPLATE_TEXT.replace("pool_step,2", "pool_step,0"))).is_null()
	assert_object(CampfireCardTemplate.from_text(_TEMPLATE_TEXT.replace("max_bonus,4", "max_bonus,x"))).is_null()
	assert_object(CampfireCardTemplate.from_text(_TEMPLATE_TEXT + "base_value,3\n")).is_null()


# ---- AC6 敏感度證明(常駐)------------------------------------------------------

func test_sensitivity_proof_real_generator_passes_every_scenario() -> void:
	assert_bool(_scn_formula_boundaries(CampfireCardGenerator.new(_template(), 0.5))).is_true()
	assert_bool(_scn_question_mirror(CampfireCardGenerator.new(_template(), 0.5))).is_true()
	assert_bool(_scn_snapshot(CampfireCardGenerator.new(_template(), 0.5))).is_true()
	assert_bool(_scn_battle_modifiers(CampfireCardGenerator.new(_template(), 0.5))).is_true()


func test_sensitivity_proof_mutant1_formula_ignores_k_fails_ac1() -> void:
	assert_bool(_scn_formula_boundaries(_MutantNoK.new(_template(), 0.5))).is_false()


func test_sensitivity_proof_mutant2_question_uses_plus_v_fails_ac2() -> void:
	assert_bool(_scn_question_mirror(_MutantQuestionUsesPlusV.new(_template(), 0.5))).is_false()


func test_sensitivity_proof_mutant3_live_read_fails_ac3() -> void:
	assert_bool(_scn_snapshot(_MutantLiveRead.new(_template(), 0.5))).is_false()


func test_sensitivity_proof_mutant4_effect_value_only_fails_ac5() -> void:
	assert_bool(_scn_battle_modifiers(_MutantNoDeltas.new(_template(), 0.5))).is_false()
