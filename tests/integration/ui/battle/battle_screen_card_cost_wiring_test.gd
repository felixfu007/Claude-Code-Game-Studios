# Story 026(production/epics/skill-card-system/story-026-card-cost-production-wiring.md):
# 出卡代價結算的生產接線。載入【真實】BattleScreen.tscn,經真實公開入口
# (BattleController.open_hand -> select_card -> select_target -> confirm)出卡。
#
# 檔案存取:甲類例外 —— 唯讀 assets/data/ 版控夾具(tuning / cards / units / levels / affinity),
# 不寫入任何檔案。無法改用注入:要證的正是 BattleScreen 讀資料檔、建 controller、接線那條路徑。
# ⚠️ 不證明窮盡性。
#
# 注入順序:instantiate() -> set_script()(僅 mutant)-> 設 override -> add_child()。
# set_script() 必須先於設 override(會清回宣告預設值,見 coding-standards)。
# 本檔沿用既有 BattleScreen 整合測試慣例直接在測試函式內 add_child()。
#
# 夾具相容性:vs01_terrain.txt(此處用真實 vs01_terrain.txt 13x6;duel 5x3 會觸發 Board.from_ascii 尺寸錯誤)與 test_fixture_roster_card_cost.txt
# (座標 (0,0)(1,0)(12,5))互相對得上;牌表兩張牌 cost_amount=2,旋鈕夾具 hp_cost_none=4、
# pair_cost_cap=5,兩者皆 != 預設(3/3)與 != cost_amount,故「沒接上」與「接上了」可區分。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):BattleScreen 的 mutant 子類別在 super._ready() 之後
# 把 session 的接線改壞(等效於拿掉/改接 production 的 attach 呼叫):
#   ① 池接 null(= 拿掉 attach_affinity_pool)-> AC2、AC3 情境回 false
#   ② 旋鈕退回預設(= 拿掉 attach_cost_tuning)-> AC2 情境回 false
#   ③ 接到另建的池 -> AC3 情境回 false
# 證明不了的(誠實登記):
#   ④「旋鈕載入失敗時改為靜默退回預設」—— 該分支在 BattleScreen._ready() 內部、沒有可覆寫的 seam,
#   mutant 子類別在 super._ready() 之後無法撤銷已設的 _load_failed(D 類:唯一注入點在受限範圍外,
#   要證它得改 production 檔)。AC4 的斷言本身(_load_failed / 錯誤標籤 / _state==null)就是對該行為的
#   直接檢查;若有人把失敗改成靜默預設,AC4 測試會紅,但本檔沒有「偵測器偵測到植入缺陷」的常駐證明。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"
const _ROSTER: String = "res://assets/data/units/test_fixture_roster_card_cost.txt"
const _CARDS: String = "res://assets/data/cards/test_fixture_cards_cost.txt"
const _AFFINITY: String = "res://assets/data/affinity/tutorial_no_links.txt"
const _TUNING_NONDEFAULT: String = "res://assets/data/tuning/test_fixture_tuning_card_cost_nondefault.txt"
const _TUNING_OUT_OF_RANGE: String = "res://assets/data/tuning/test_fixture_tuning_card_cost_out_of_range.txt"

const _PAIR_C1_C2: AffinityTypes.Pair = AffinityTypes.Pair.C1_C2

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


# ---- mutants(BattleScreen 子類別;super._ready() 之後把 session 接線改壞)-------------

## ① 拿掉 attach_affinity_pool:池為 null。
class _MutantNoPool extends BattleScreen:
	func _ready() -> void:
		super()
		if _controller != null:
			_controller._card_play_session.attach_affinity_pool(null)


## ② 拿掉 attach_cost_tuning:退回預設旋鈕。
class _MutantDefaultTuning extends BattleScreen:
	func _ready() -> void:
		super()
		if _controller != null:
			_controller._card_play_session.attach_cost_tuning(CardCostTuning.defaults())


## ③ 接到另建的池,而非 BattleScreen 的 _affinity_pool。
class _MutantOtherPool extends BattleScreen:
	func _ready() -> void:
		super()
		if _controller != null:
			_controller._card_play_session.attach_affinity_pool(AffinityDataPool.new())


# ---- 夾具/輔助 -----------------------------------------------------------------------

## 載入真實 BattleScreen.tscn 並注入夾具。[param script] 非 null 時先 set_script()(再設 override)。
func _load_screen(script: GDScript = null, tuning_path: String = _TUNING_NONDEFAULT) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		instance.set_script(script)
	instance.terrain_path_override = _TERRAIN
	instance.roster_path_override = _ROSTER
	instance.cards_path_override = _CARDS
	instance.affinity_path_override = _AFFINITY
	instance.tuning_path_override = tuning_path
	add_child(instance)
	return instance


func _discard(instance: BattleScreen) -> void:
	remove_child(instance)
	instance.free()


func _card_in_hand(instance: BattleScreen, card_id: String) -> Card:
	for card: Card in instance._state.card_deck().hand():
		if card.id == card_id:
			return card
	return null


func _play(instance: BattleScreen, card: Card, target: int) -> bool:
	var controller: BattleController = instance._controller
	if not controller.open_hand():
		return false
	if not controller.select_card(card):
		controller.cancel()
		return false
	if controller._card_play_session.step() != CardPlaySession.Step.CONFIRMING and not controller.select_target(target):
		controller.cancel()
		return false
	return controller.confirm()


func _fixture_hp_cost_none() -> int:
	var parsed: Variant = CardCostTuning.from_text(FileAccess.get_file_as_string(_TUNING_NONDEFAULT))
	return (parsed as CardCostTuning).hp_cost_none()


func _fixture_pair_cost_cap() -> int:
	var parsed: Variant = CardCostTuning.from_text(FileAccess.get_file_as_string(_TUNING_NONDEFAULT))
	return (parsed as CardCostTuning).pair_cost_cap()


# ---- 情境函式(真品回 true;mutant 回 false)---------------------------------------------

## AC1:付血卡。付款人 hp == 舊 hp - 該卡的 cost_amount(取自夾具卡表,不手抄)。
func _scn_hp_card_pays(script: GDScript = null) -> bool:
	var s: BattleScreen = _load_screen(script)
	if s._load_failed or s._controller == null:
		_discard(s)
		return false
	var card: Card = _card_in_hand(s, "hp_card")
	var before_payer: int = s._state.unit_by_id(1).hp
	var before_other: int = s._state.unit_by_id(2).hp
	var played: bool = card != null and _play(s, card, 1)
	var ok: bool = played \
		and card.cost_type == Card.CostType.HP \
		and s._state.unit_by_id(1).hp == before_payer - card.cost_amount \
		and s._state.unit_by_id(2).hp == before_other
	_discard(s)
	return ok


## AC2:池為空 -> 關係 NONE -> PAIR 卡可打,兩付款人各扣「載入旋鈕」的 hp_cost_none(夾具 4 != 預設 3)。
func _scn_pair_none_pays_fixture_knob(script: GDScript = null) -> bool:
	var s: BattleScreen = _load_screen(script)
	if s._load_failed or s._controller == null:
		_discard(s)
		return false
	var session: CardPlaySession = s._controller._card_play_session
	var card: Card = _card_in_hand(s, "pair_card")
	var expected: int = _fixture_hp_cost_none()
	var playable: bool = card != null and session.is_card_playable(card) \
		and session.card_unplayable_reason(card) != CardCostPlan.Reason.RELATION_UNRESOLVED
	var played: bool = playable and _play(s, card, 1)
	var ok: bool = played \
		and s._state.unit_by_id(1).hp == 20 - expected \
		and s._state.unit_by_id(2).hp == 20 - expected \
		and s._state.pair_wear(_PAIR_C1_C2) == 0
	_discard(s)
	return ok


## AC3:經 BattleScreen 的池寫入 POS 後,同一張 PAIR 卡改走折損(不付血)—— 證明接的是同一個池。
func _scn_pair_follows_screen_pool(script: GDScript = null) -> bool:
	var s: BattleScreen = _load_screen(script)
	if s._load_failed or s._controller == null:
		_discard(s)
		return false
	var session: CardPlaySession = s._controller._card_play_session
	var card: Card = _card_in_hand(s, "pair_card")
	if card == null:
		_discard(s)
		return false
	var before: CardCostPlan = session.preview_cost(card, 1)
	var rejection: AffinityDataPool.WriteRejection = s._affinity_pool.append_record(
		_PAIR_C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT
	)
	var after: CardCostPlan = session.preview_cost(card, 1)
	var played: bool = _play(s, card, 1)
	var ok: bool = rejection == AffinityDataPool.WriteRejection.NONE \
		and before.kind == CardCostPlan.Kind.HP \
		and after.kind == CardCostPlan.Kind.WEAR \
		and played \
		and s._state.unit_by_id(1).hp == 20 and s._state.unit_by_id(2).hp == 20 \
		and s._state.pair_wear(_PAIR_C1_C2) == mini(card.cost_amount, _fixture_pair_cost_cap())
	_discard(s)
	return ok


# ---- AC1 ~ AC5 -------------------------------------------------------------------------

func test_ac1_pay_hp_card_reduces_payer_hp() -> void:
	assert_bool(_scn_hp_card_pays()).append_failure_message(
		"真實 BattleScreen 打付血卡後,付款人 hp 應為舊 hp 減 cost_amount"
	).is_true()


func test_ac2_pair_card_playable_and_pays_loaded_knob_when_relation_none() -> void:
	# 前置:夾具旋鈕確實 != 預設,否則「沒接上」與「接上了」無法區分
	assert_int(_fixture_hp_cost_none()).is_not_equal(CardCostTuning.defaults().hp_cost_none())
	assert_bool(_scn_pair_none_pays_fixture_knob()).append_failure_message(
		"PAIR 卡不應為 RELATION_UNRESOLVED,且兩付款人各扣夾具旋鈕的 hp_cost_none"
	).is_true()


func test_ac3_pair_card_follows_the_screens_own_pool() -> void:
	assert_bool(_scn_pair_follows_screen_pool()).append_failure_message(
		"經 BattleScreen._affinity_pool 寫入 POS 後,PAIR 卡應由付血改走折損(同一個池實例)"
	).is_true()


func test_ac4_cost_knob_out_of_range_fails_load_explicitly() -> void:
	# 對照:合法夾具載入成功,且載入的值進了 BattleScreen
	var ok_screen: BattleScreen = _load_screen()
	assert_bool(ok_screen._load_failed).is_false()
	assert_int(ok_screen._card_cost_tuning.hp_cost_none()).is_equal(_fixture_hp_cost_none())
	_discard(ok_screen)

	var s: BattleScreen = _load_screen(null, _TUNING_OUT_OF_RANGE)
	assert_bool(s._load_failed).append_failure_message("值域外的旋鈕檔必須載入失敗,不得靜默退回預設").is_true()
	assert_bool(s._load_error_label.visible).is_true()
	assert_str(s._load_error_label.text).is_equal(
		BattleScreen.load_failure_message(BattleScreen.LoadFailure.PARSE_ERROR, _TUNING_OUT_OF_RANGE))
	assert_object(s._state).is_null()
	_discard(s)


func test_ac5_no_card_deck_controller_builds_without_session_and_does_not_throw() -> void:
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,E1,ENEMY,20,5,3,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var links: Array[AffinityLink] = []

	# 帶著池與旋鈕、但無牌組:沿用現行行為(不建 session、不注入、不拋錯)
	var controller: BattleController = BattleController.new(
		state, order, Callable(), Callable(), null, links, null, Callable(),
		AffinityDataPool.new(), CardCostTuning.defaults()
	)

	assert_bool(controller.is_card_play_in_progress()).is_false()
	assert_bool(controller.open_hand()).is_false()
	assert_object(controller._card_play_session).is_null()


# ---- AC6 常駐敏感度證明 -------------------------------------------------------------------

func test_sensitivity_proof_missing_pool_attach_is_caught_by_ac2_and_ac3() -> void:
	assert_bool(_scn_pair_none_pays_fixture_knob(_MutantNoPool)).is_false()
	assert_bool(_scn_pair_follows_screen_pool(_MutantNoPool)).is_false()


func test_sensitivity_proof_missing_tuning_attach_is_caught_by_ac2() -> void:
	assert_bool(_scn_pair_none_pays_fixture_knob(_MutantDefaultTuning)).is_false()


func test_sensitivity_proof_wrong_pool_instance_is_caught_by_ac3() -> void:
	assert_bool(_scn_pair_follows_screen_pool(_MutantOtherPool)).is_false()
	# 對照:此 mutant 不影響 NONE 分支與付血卡(證明偵測器抓的是「池」而不是別的東西)
	assert_bool(_scn_hp_card_pays(_MutantOtherPool)).is_true()
