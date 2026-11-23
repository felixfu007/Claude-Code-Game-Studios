## campfire story-005:CampaignCardResolver + CampaignDeck 登記區/快照。
##
## 檔案存取例外聲明(.claude/rules/test-standards.md 2026-09-16 裁決,甲類:唯讀真實資料檔):
## - 讀 assets/data/campfire/default_deck.txt(經 CampaignDeckDefaultsLoader)與
##   assets/data/cards/vs0N_cards.txt / vs0N_card_text.txt。
## - ⚠️ 自陳:vs02~vs05 一致性測試只證明【預設牌組用到的那 14 個 id】逐行相同,
##   不證明整檔相同、也不證明未來新增的 id 一致。
## 敏感度證明(常駐 test_sensitivity_proof_*):三個 mutant 各自一條。
extends GdUnitTestSuite

const _DECK_IDS: Array[String] = [
	"card_11", "card_12", "card_13", "card_14", "card_15", "card_16", "card_17", "card_18",
	"card_20", "card_22", "card_07", "card_08",
]
const _CARDS_DIR: String = "res://assets/data/cards/"


## mutant ①:改回讀固定牌表(整批 vs02 牌表,而非確認牌組)。
class _MutantFixedTable extends CampaignCardResolver:
	func _ids_for(_deck: CampaignDeck) -> Array[String]:
		var all: Array[String] = []
		var parsed: Variant = Card.cards_from_text(FileAccess.get_file_as_string(CampaignCardResolver.CATALOG_PATH))
		for c: Card in (parsed as Array[Card]):
			all.append(c.id)
		return all


## mutant ②:忽略移出(牌組 + 收藏區全部都解析)。
class _MutantIgnoreRemoval extends CampaignCardResolver:
	func _ids_for(deck: CampaignDeck) -> Array[String]:
		var ids: Array[String] = deck.confirmed_deck_ids()
		ids.append_array(deck.collection_ids())
		return ids


## mutant ③:第 1 場也改讀牌組。
class _MutantFirstMissionToo extends CampaignCardResolver:
	func _uses_confirmed_deck(_mission: int) -> bool:
		return true


func _ids(cards: Array[Card]) -> Array[String]:
	var out: Array[String] = []
	for c: Card in cards:
		out.append(c.id)
	return out


func _camp_card(id: String) -> Card:
	return Card.new_camp_pair_card(id, 1, 1, 2, 1, 2, 1, 3, 2)


func _resolve(r: CampaignCardResolver, mission: int, deck: CampaignDeck) -> Array[Card]:
	var v: Variant = r.cards_for_battle(mission, deck)
	assert_object(v).is_not_null()
	var out: Array[Card] = v
	return out


# ---- AC1 / AC2 / AC3(單元層)-------------------------------------------------

func test_mission2_cards_equal_confirmed_deck_in_order() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_array(_ids(_resolve(CampaignCardResolver.new(), 2, deck))).is_equal(_DECK_IDS)


func test_removed_card_absent_and_new_camp_card_present() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_bool(deck.move_to_collection("card_07")).is_true()
	assert_int(deck.confirm()).is_equal(CampaignDeck.ConfirmResult.OK)
	assert_bool(deck.add_new_card("camp_x", _camp_card("camp_x"))).is_true()
	var ids: Array[String] = _ids(_resolve(CampaignCardResolver.new(), 3, deck))
	assert_array(ids).not_contains(["card_07"])
	assert_array(ids).contains(["camp_x"])
	assert_int(ids.size()).is_equal(deck.confirmed_deck_ids().size())


func test_mission1_and_below_not_injected() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_int(_resolve(CampaignCardResolver.new(), 1, deck).size()).is_equal(0)
	assert_int(_resolve(CampaignCardResolver.new(), 0, deck).size()).is_equal(0)


func test_unresolved_id_returns_null_not_partial() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	var ids: Array[String] = ["card_11", "no_such_card"]
	var catalog: Array[Card] = []
	assert_object(CampaignCardResolver.new().resolve(ids, deck, catalog)).is_null()


# ---- 登記區 / 快照 -------------------------------------------------------------

func test_registry_set_by_add_new_card_and_not_overwritten_when_owned() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	var first: Card = _camp_card("camp_a")
	assert_bool(deck.add_new_card("camp_a", first)).is_true()
	assert_bool(deck.add_new_card("camp_a", _camp_card("camp_a"))).is_false()
	assert_object(deck.registered_card("camp_a")).is_same(first)
	assert_object(deck.registered_card("card_11")).is_null()


func test_clear_empties_registry() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	deck.add_new_card("camp_a", _camp_card("camp_a"))
	deck.clear()
	assert_object(deck.registered_card("camp_a")).is_null()


func test_snapshot_restore_roundtrip_rolls_back_new_card_and_registry() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	var snap: Dictionary = deck.snapshot()
	deck.add_new_card("camp_a", _camp_card("camp_a"))
	deck.move_to_collection("card_11")  # 未確認的編輯
	assert_bool(deck.restore(snap)).is_true()
	assert_array(deck.confirmed_deck_ids()).is_equal(_DECK_IDS)
	assert_array(deck.working_deck_ids()).is_equal(_DECK_IDS)
	assert_bool(deck.is_new("camp_a")).is_false()
	assert_object(deck.registered_card("camp_a")).is_null()
	# 再度入帳同 id:登記區覆蓋為新卡
	var again: Card = _camp_card("camp_a")
	assert_bool(deck.add_new_card("camp_a", again)).is_true()
	assert_object(deck.registered_card("camp_a")).is_same(again)


func test_restore_malformed_snapshot_rejected_and_state_untouched() -> void:
	var deck: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_bool(deck.restore({"confirmed_deck": 1})).is_false()
	assert_array(deck.confirmed_deck_ids()).is_equal(_DECK_IDS)


# ---- 資料一致性(釘住「以 vs02 為權威」的前提)-------------------------------

func _line_for(path: String, id: String) -> String:
	for raw: String in FileAccess.get_file_as_string(path).split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with(id + ","):
			return line
	return ""


func test_default_deck_ids_have_identical_card_rows_across_vs02_to_vs05() -> void:
	var all_ids: Array[String] = _DECK_IDS.duplicate()
	all_ids.append_array(["card_19", "card_21"])
	for id: String in all_ids:
		var ref: String = _line_for(_CARDS_DIR + "vs02_cards.txt", id)
		assert_str(ref).is_not_empty()
		for n: String in ["vs03", "vs04", "vs05"]:
			assert_str(_line_for(_CARDS_DIR + n + "_cards.txt", id)).is_equal(ref)


func test_card_08_text_differs_in_vs04_and_keeps_old_turf_wording() -> void:
	var vs04: Dictionary[String, String] = CardText.flavor_texts_from_text(
		FileAccess.get_file_as_string(_CARDS_DIR + "vs04_card_text.txt"))
	var vs02: Dictionary[String, String] = CardText.flavor_texts_from_text(
		FileAccess.get_file_as_string(_CARDS_DIR + "vs02_card_text.txt"))
	assert_str(vs04["card_08"]).contains("這是他待過的地方")
	assert_str(vs02["card_08"]).not_contains("這是他待過的地方")


# ---- AC4 敏感度證明(單元層;三條各自在對應 mutant 下應紅)-----------------------
# 這三條斷言的是「正確行為」,對 mutant 跑。常駐版本的做法:斷言 mutant 的輸出
# 與正確輸出【不同】,證明對應的正確性斷言有能力抓到它。

func test_sensitivity_proof_fixed_table_mutant_differs_from_ac1() -> void:
	var d: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	var got: Array[String] = _ids(_resolve(_MutantFixedTable.new(), 2, d))
	assert_bool(got == _DECK_IDS).is_false()


func test_sensitivity_proof_ignore_removal_mutant_differs_from_ac2() -> void:
	var d: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	d.move_to_collection("card_07")
	d.confirm()
	assert_array(_ids(_resolve(_MutantIgnoreRemoval.new(), 3, d))).contains(["card_07"])


func test_sensitivity_proof_first_mission_mutant_differs_from_ac3() -> void:
	var d: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_int(_resolve(_MutantFirstMissionToo.new(), 1, d).size()).is_greater(0)
