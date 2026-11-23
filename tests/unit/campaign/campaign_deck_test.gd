## campfire story-004:CampaignDeck / 牌組與收藏區。
##
## 檔案存取例外聲明(.claude/rules/test-standards.md 2026-09-16 裁決):
## - 甲類:AC1 讀 assets/data/campfire/default_deck.txt(已進版控的真實資料檔,唯讀)。
##   不能用注入取代:要抓的就是「資料檔本身打錯字/與規格不符」。
## - 乙類:AC4 讀 src/gameplay/campaign/campaign_deck*.gd 的原始碼【文字】,斷言沒有寫檔 API。
##   ⚠️ 自陳:此掃描不等於窮盡 —— 反射(call("..."))、別的檔案、GDExtension 都在視野外;
##   它只證明「這兩支檔的文字裡沒有出現下列字樣」。
##
## 敏感度證明(常駐 test_sensitivity_proof_*):三個 mutant 各自一條,見檔尾。
## 證明不了的:AC4 的 reset_campaign() 接線(static 方法、單例,無法注入 mutant)——
## 該接線由 test_campaign_progress_reset_restores_default_deck 真實呼叫覆蓋,
## 其敏感度由實作者手動注入一次驗證,不在版本庫留痕。
extends GdUnitTestSuite

const _DEFAULT_PATH: String = "res://assets/data/campfire/default_deck.txt"
const _EXPECTED_DEFAULT_DECK: Array[String] = [
	"card_11", "card_12", "card_13", "card_14", "card_15", "card_16", "card_17", "card_18",
	"card_20", "card_22", "card_07", "card_08",
]

## 8 張牌組 + 7 張收藏區,上下限 8/14。
const _FIXTURE_TEXT: String = """
deck_min,8
deck_max,14
deck,d1
deck,d2
deck,d3
deck,d4
deck,d5
deck,d6
deck,d7
deck,d8
collection,c1
collection,c2
collection,c3
collection,c4
collection,c5
collection,c6
collection,c7
"""


class _MutantBoundsOffByOne extends CampaignDeck:
	func _check_size(count: int) -> ConfirmResult:
		if count <= _min:
			return ConfirmResult.TOO_FEW
		if count >= _max:
			return ConfirmResult.TOO_MANY
		return ConfirmResult.OK


class _MutantRemoveDeletes extends CampaignDeck:
	func _remove_from_deck(card_id: String) -> void:
		_deck.erase(card_id)


class _MutantClearNoop extends CampaignDeck:
	func clear() -> void:
		pass


func after_test() -> void:
	CampaignProgress.reset_for_test()


func _fixture() -> CampaignDeck:
	var d: CampaignDeck = CampaignDeck.from_text(_FIXTURE_TEXT)
	assert_object(d).is_not_null()
	return d


func _fixture_of(d: CampaignDeck) -> CampaignDeck:
	assert_bool(d.apply_text(_FIXTURE_TEXT)).is_true()
	return d


# ---- 檢查函式:回傳 true = 符合規格。真測試與 mutant 證明共用。 ----

func _check_bounds(d: CampaignDeck) -> bool:
	var ok: bool = true
	# 8 張:可確認
	ok = ok and d.confirm() == CampaignDeck.ConfirmResult.OK
	# 7 張:拒絕
	d.move_to_collection("d1")
	ok = ok and d.confirm() == CampaignDeck.ConfirmResult.TOO_FEW
	d.cancel_edit()
	# 14 張:可確認
	for i: int in range(1, 7):
		d.move_to_deck("c%d" % i)
	ok = ok and d.working_deck_ids().size() == 14
	ok = ok and d.confirm() == CampaignDeck.ConfirmResult.OK
	# 15 張:拒絕
	d.move_to_deck("c7")
	ok = ok and d.confirm() == CampaignDeck.ConfirmResult.TOO_MANY
	return ok


func _check_remove_returns_to_collection(d: CampaignDeck) -> bool:
	var ok: bool = d.move_to_collection("d3")
	ok = ok and d.collection_ids().has("d3")
	ok = ok and not d.working_deck_ids().has("d3")
	ok = ok and d.move_to_deck("d3")
	ok = ok and d.working_deck_ids().has("d3")
	return ok


func _check_clear_restores_defaults(d: CampaignDeck) -> bool:
	d.move_to_collection("d1")
	d.move_to_deck("c1")
	d.confirm()
	d.add_new_card("camp_x")
	d.clear()
	return d.confirmed_deck_ids() == d.working_deck_ids() \
		and d.confirmed_deck_ids().size() == 8 \
		and d.confirmed_deck_ids().has("d1") \
		and not d.confirmed_deck_ids().has("camp_x") \
		and d.collection_ids().size() == 7 \
		and not d.is_new("camp_x")


# ---- AC1 ----

func test_default_deck_file_gives_twelve_expected_cards() -> void:
	var d: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_array(d.confirmed_deck_ids()).is_equal(_EXPECTED_DEFAULT_DECK)
	assert_array(d.working_deck_ids()).is_equal(_EXPECTED_DEFAULT_DECK)


func test_default_deck_file_collection_matches_placeholder() -> void:
	var d: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	assert_array(d.collection_ids()).is_equal(["card_19", "card_21"])
	assert_int(d.deck_min()).is_equal(8)
	assert_int(d.deck_max()).is_equal(14)


func test_default_deck_file_has_no_card_id_in_both_zones() -> void:
	var d: CampaignDeck = CampaignDeckDefaultsLoader.load_defaults()
	for id: String in d.collection_ids():
		assert_bool(d.confirmed_deck_ids().has(id)).is_false()


func test_from_text_rejects_malformed_inputs() -> void:
	assert_object(CampaignDeck.from_text("deck_min,8\ndeck_max,14\nbogus,1\n")).is_null()
	assert_object(CampaignDeck.from_text("deck_min,8\n")).is_null()
	assert_object(CampaignDeck.from_text("deck_min,x\ndeck_max,14\n")).is_null()
	assert_object(CampaignDeck.from_text("deck_min,2\ndeck_max,3\ndeck,a\ndeck,a\n")).is_null()
	assert_object(CampaignDeck.from_text("deck_min,2\ndeck_max,3\ndeck,a\n")).is_null()


# ---- AC2 ----

func test_confirm_bounds_7_and_15_rejected_8_and_14_accepted() -> void:
	assert_bool(_check_bounds(_fixture())).is_true()


func test_confirm_rejection_has_readable_reason_and_changes_nothing() -> void:
	var d: CampaignDeck = _fixture()
	d.move_to_collection("d1")
	var r: CampaignDeck.ConfirmResult = d.confirm()
	assert_int(r).is_equal(CampaignDeck.ConfirmResult.TOO_FEW)
	assert_str(d.rejection_reason(r)).contains("8")
	assert_int(d.confirmed_deck_ids().size()).is_equal(8)
	d.cancel_edit()
	d.move_to_deck("c1")
	d.move_to_deck("c2")
	d.move_to_deck("c3")
	d.move_to_deck("c4")
	d.move_to_deck("c5")
	d.move_to_deck("c6")
	d.move_to_deck("c7")
	var r2: CampaignDeck.ConfirmResult = d.confirm()
	assert_int(r2).is_equal(CampaignDeck.ConfirmResult.TOO_MANY)
	assert_str(d.rejection_reason(r2)).contains("14")
	assert_str(d.rejection_reason(CampaignDeck.ConfirmResult.OK)).is_empty()


# ---- AC3 ----

func test_removed_card_stays_in_collection_and_can_return() -> void:
	assert_bool(_check_remove_returns_to_collection(_fixture())).is_true()


func test_new_card_auto_joins_when_not_full_and_is_marked_new() -> void:
	var d: CampaignDeck = _fixture()
	assert_bool(d.add_new_card("camp_1")).is_true()
	assert_bool(d.confirmed_deck_ids().has("camp_1")).is_true()
	assert_bool(d.working_deck_ids().has("camp_1")).is_true()
	assert_bool(d.is_new("camp_1")).is_true()


func test_new_card_stays_in_collection_when_deck_full() -> void:
	var d: CampaignDeck = _fixture()
	for i: int in range(1, 7):
		d.move_to_deck("c%d" % i)
	assert_int(d.confirm()).is_equal(CampaignDeck.ConfirmResult.OK)
	assert_bool(d.add_new_card("camp_1")).is_true()
	assert_bool(d.confirmed_deck_ids().has("camp_1")).is_false()
	assert_bool(d.collection_ids().has("camp_1")).is_true()
	assert_bool(d.is_new("camp_1")).is_false()


func test_new_mark_cleared_on_successful_confirm() -> void:
	var d: CampaignDeck = _fixture()
	d.add_new_card("camp_1")
	assert_int(d.confirm()).is_equal(CampaignDeck.ConfirmResult.OK)
	assert_bool(d.is_new("camp_1")).is_false()


func test_add_new_card_duplicate_id_rejected() -> void:
	var d: CampaignDeck = _fixture()
	assert_bool(d.add_new_card("d1")).is_false()
	assert_bool(d.add_new_card("c1")).is_false()
	assert_int(d.confirmed_deck_ids().size()).is_equal(8)


func test_add_new_card_discards_unconfirmed_edits() -> void:
	var d: CampaignDeck = _fixture()
	d.move_to_collection("d1")
	d.add_new_card("camp_1")
	assert_bool(d.working_deck_ids().has("d1")).is_true()
	assert_int(d.working_deck_ids().size()).is_equal(9)


# ---- AC4 ----

func test_clear_restores_default_deck_and_collection() -> void:
	assert_bool(_check_clear_restores_defaults(_fixture())).is_true()


func test_campaign_progress_reset_restores_default_deck() -> void:
	var d: CampaignDeck = CampaignProgress.deck()
	d.move_to_collection("card_11")
	d.confirm()
	d.add_new_card("camp_1")
	CampaignProgress.reset_campaign()
	assert_array(CampaignProgress.deck().confirmed_deck_ids()).is_equal(_EXPECTED_DEFAULT_DECK)
	assert_bool(CampaignProgress.deck().is_new("camp_1")).is_false()


func test_campaign_progress_reset_still_clears_has_progress_flag() -> void:
	CampaignProgress.start_mission_affinity_ledger()
	assert_bool(CampaignProgress.has_progress()).is_true()
	CampaignProgress.reset_campaign()
	assert_bool(CampaignProgress.has_progress()).is_false()


func test_deck_sources_contain_no_file_write_api() -> void:
	# 乙類:掃原始碼文字。pattern 用字元類別拆開,避免本檔自己命中自己。
	var forbidden: PackedStringArray = [
		"FileAccess\\.[W]RITE", "FileAccess\\.[W]RITE_READ", "store_[a-z0-9_]+\\(", "Dir[A]ccess", "save_[t]o",
	]
	var paths: PackedStringArray = [
		"res://src/gameplay/campaign/campaign_deck.gd",
		"res://src/gameplay/campaign/campaign_deck_defaults_loader.gd",
	]
	for p: String in paths:
		var text: String = FileAccess.get_file_as_string(p)
		assert_str(text).is_not_empty()
		for pat: String in forbidden:
			var re: RegEx = RegEx.create_from_string("^[^#]*" + pat)
			assert_object(re.search(text)).is_null()
	# CampaignDeck 本體連唯讀的 FileAccess 都不碰
	var body: String = FileAccess.get_file_as_string(paths[0])
	var re2: RegEx = RegEx.create_from_string("^[^#]*File[A]ccess")
	assert_object(re2.search(body)).is_null()


# ---- AC6 敏感度證明(一個 mutant 一條,常駐) ----

func test_sensitivity_proof_bounds_off_by_one_is_caught() -> void:
	var good: CampaignDeck = _fixture()
	assert_bool(_check_bounds(good)).is_true()
	var mutant: CampaignDeck = _fixture_of(_MutantBoundsOffByOne.new())
	assert_bool(_check_bounds(mutant)).is_false()


func test_sensitivity_proof_remove_deletes_is_caught() -> void:
	var mutant: CampaignDeck = _fixture_of(_MutantRemoveDeletes.new())
	assert_bool(_check_remove_returns_to_collection(mutant)).is_false()


func test_sensitivity_proof_clear_noop_is_caught() -> void:
	var mutant: CampaignDeck = _fixture_of(_MutantClearNoop.new())
	assert_bool(_check_clear_restores_defaults(mutant)).is_false()


# ---- AC5 ----

func test_defeat_rollback_keeps_last_confirmed_deck() -> void:
	var d: CampaignDeck = CampaignProgress.deck()
	d.move_to_collection("card_11")
	assert_int(d.confirm()).is_equal(CampaignDeck.ConfirmResult.OK)
	var confirmed: Array[String] = d.confirmed_deck_ids()
	CampaignProgress.start_mission_affinity_ledger()
	CampaignProgress.rollback_on_defeat()
	assert_array(CampaignProgress.deck().confirmed_deck_ids()).is_equal(confirmed)
	assert_bool(confirmed.has("card_11")).is_false()
