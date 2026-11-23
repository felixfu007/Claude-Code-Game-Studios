## campfire story-005:BattleScreen 牌庫改從確認牌組(真實 BattleScreen.tscn)。
##
## 檔案存取例外聲明(甲類:唯讀已進版控真實資料檔):載入真實場景,其 _ready() 讀
## vs01 關卡資料與 vs0N_cards / card_text;牌組讀 default_deck.txt。唯讀、不寫檔。
## ⚠️ 自陳:只證明這批資料與這條注入路徑,不證明 SceneRouter.enter_battle 的整條
## 場景切換(該接線見檔尾 _inject 的直接呼叫測試)。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _VS04_TEXT: String = "res://assets/data/cards/vs04_card_text.txt"

var _host_snap: CursorHostSnapshot = null


## mutant:無視注入,永遠讀固定牌表(AC1 應能抓到)。
class _MutantIgnoresOverride extends BattleScreen:
	func _ready() -> void:
		confirmed_deck_override = []
		super._ready()


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


func _all_ids(screen: BattleScreen) -> Array[String]:
	var d: CardDeck = screen._state.card_deck()
	var ids: Array[String] = []
	for c: Card in d.pool():
		ids.append(c.id)
	for c: Card in d.hand():
		ids.append(c.id)
	for c: Card in d.used():
		ids.append(c.id)
	ids.sort()
	return ids


func _cards_for(mission: int, deck: CampaignDeck) -> Array[Card]:
	var v: Variant = CampaignCardResolver.new().cards_for_battle(mission, deck)
	var out: Array[Card] = v
	return out


func _spawn(override: Array[Card], script: Script = null) -> BattleScreen:
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	if script != null:
		inst.set_script(script)
	inst.confirmed_deck_override = override
	auto_free(inst)
	add_child(inst)
	return inst


func test_ac1_injected_deck_is_exactly_the_battle_pool() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	var expected: Array[String] = deck.confirmed_deck_ids()
	expected.sort()
	var screen: BattleScreen = _spawn(_cards_for(2, deck))
	assert_array(_all_ids(screen)).is_equal(expected)


func test_ac2_removed_card_absent_new_camp_card_present() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	deck.move_to_collection("card_07")
	deck.confirm()
	deck.add_new_card("camp_x", Card.new_camp_pair_card("camp_x", 1, 1, 2, 1, 2, 1, 3, 2))
	var ids: Array[String] = _all_ids(_spawn(_cards_for(3, deck)))
	assert_array(ids).not_contains(["card_07"])
	assert_array(ids).contains(["camp_x"])


func test_ac3_not_injected_keeps_fixed_table() -> void:
	var fixed: Array[String] = []
	var parsed: Variant = Card.cards_from_text(
		FileAccess.get_file_as_string("res://assets/data/cards/vs01_cards.txt"))
	for c: Card in (parsed as Array[Card]):
		fixed.append(c.id)
	fixed.sort()
	var none: Array[Card] = []
	assert_array(_all_ids(_spawn(none))).is_equal(fixed)


func test_ac3_mission1_resolver_yields_empty_so_battle_keeps_fixed_table() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_int(_cards_for(1, deck).size()).is_equal(0)


func test_card_text_still_read_from_scene_file_card_08_keeps_vs04_wording() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	inst.card_text_path_override = _VS04_TEXT
	inst.confirmed_deck_override = _cards_for(4, deck)
	auto_free(inst)
	add_child(inst)
	assert_str(inst._card_flavor_texts["card_08"]).contains("這是他待過的地方")


func test_scene_router_injection_wires_deck_from_campaign_progress_mission2() -> void:
	CampaignProgress.reset_for_test()
	CampaignProgress.advance_on_victory(5)  # 第 2 場
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	SceneRouter._inject_campaign_ledger(inst)
	auto_free(inst)
	var expected: Array[String] = CampaignProgress.deck().confirmed_deck_ids()
	var got: Array[String] = []
	for c: Card in inst.confirmed_deck_override:
		got.append(c.id)
	assert_array(got).is_equal(expected)


func test_scene_router_injection_mission1_does_not_inject() -> void:
	CampaignProgress.reset_for_test()
	var inst: BattleScreen = load(_SCENE_PATH).instantiate()
	SceneRouter._inject_campaign_ledger(inst)
	auto_free(inst)
	assert_int(inst.confirmed_deck_override.size()).is_equal(0)


func test_sensitivity_proof_ignoring_override_breaks_ac1() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	var expected: Array[String] = deck.confirmed_deck_ids()
	expected.sort()
	var screen: BattleScreen = _spawn(_cards_for(2, deck), _MutantIgnoresOverride)
	assert_bool(_all_ids(screen) == expected).is_false()
