# 卡表(vsNN_cards.txt)與牌面文字表(vsNN_card_text.txt)的編號集合一致性,逐關(vs01~vs05)——
# story-022(原 U-017 只檢 vs01)。
#
# vs01_cards.txt 檔頭逐字:「本檔每一列新增/刪除都必須同步那張表的對應列」。
# 本檔同時載入每一關的兩張表比對,另鎖 14 張新卡(實際入表 12 張)的數值、c03 站位欄、
# 教學場空表、舊卡(vs01)不變、以及「新表零 card_01~card_06」(D4 退役)。
#
# 🔴 檔案讀取為已登記的唯讀例外(.claude/rules/test-standards.md 例外 1:讀版控資料檔,
# 不證明窮舉)。全鏈路為 static 純函式解析,不建立 Node。
#
# 🔴 c13/c14(card_23/card_24)刻意不入任何戰鬥牌表(2026-11-19 管理者裁決:牌組張數照規格 14,
# 補血卡待營火/牌組編輯批)。牌面文字仍在 design/narrative/card-face-text-14-2026-11-18.md。
extends GdUnitTestSuite


const _DIR: String = "res://assets/data/cards/"
const _LEVELS: Array[int] = [1, 2, 3, 4, 5]

# 規格行號:design/quick-specs/card-rework-cost-and-pool-2026-11-12.md
# 欄位:[category, atk, def, dur, named, cost_type, cost_amount, effect, partner, range, 規格行號]
const _SPEC: Dictionary = {
	"card_11": [Card.Category.DIRECT_DAMAGE, 0, 0, 0, 1, Card.CostType.HP, 5, 12, -1, -1, 80],
	"card_12": [Card.Category.DIRECT_DAMAGE, 0, 0, 0, 3, Card.CostType.HP, 3, 8, -1, -1, 81],
	"card_13": [Card.Category.DIRECT_DAMAGE, 0, 0, 0, -1, Card.CostType.HP, 8, 18, -1, 2, 82],
	"card_14": [Card.Category.HEAL, 0, 0, 0, 2, Card.CostType.HP, 6, 10, -1, 1, 83],
	"card_15": [Card.Category.TEMPORARY_STAT_MODIFIER, 3, 0, 1, -1, Card.CostType.HP, 4, 0, -1, 0, 84],
	"card_16": [Card.Category.TEMPORARY_STAT_MODIFIER, 3, -2, 2, 1, Card.CostType.HP, 3, 0, -1, 0, 85],
	"card_17": [Card.Category.TEMPORARY_STAT_MODIFIER, 0, 3, 2, 5, Card.CostType.HP, 4, 0, -1, 2, 86],
	"card_18": [Card.Category.TEMPORARY_STAT_MODIFIER, 3, 0, 2, 3, Card.CostType.HP, 6, 0, -1, 0, 87],
	"card_19": [Card.Category.TEMPORARY_STAT_MODIFIER, 2, 0, 1, 1, Card.CostType.PAIR, 1, 0, 2, 2, 92],
	"card_20": [Card.Category.TEMPORARY_STAT_MODIFIER, 0, 2, 2, 1, Card.CostType.PAIR, 1, 0, 2, 2, 93],
	"card_21": [Card.Category.TEMPORARY_STAT_MODIFIER, 2, 0, 1, 3, Card.CostType.PAIR, 1, 0, 4, 2, 94],
	"card_22": [Card.Category.COMBO_DAMAGE, 0, 0, 0, 3, Card.CostType.PAIR, 2, 6, 4, -1, 95],
}

const _RETIRED_IDS: Array[String] = [
	"card_01", "card_02", "card_03", "card_04", "card_05", "card_06",
]
const _KEPT_IDS: Array[String] = ["card_07", "card_08"]


func _cards_path(n: int) -> String:
	return _DIR + "vs0%d_cards.txt" % n


func _text_path(n: int) -> String:
	return _DIR + "vs0%d_card_text.txt" % n


func _parse_cards(path: String) -> Array[Card]:
	var parsed: Variant = Card.cards_from_text(FileAccess.get_file_as_string(path))
	assert_bool(parsed != null).append_failure_message("解析失敗: " + path).is_true()
	var cards: Array[Card] = []
	if parsed != null:
		cards.assign(parsed)
	return cards


## 兩表 id 集合是否完全相同;卡表解析失敗 -> false。供真實表與替身表共用(敏感度證明)。
func _id_sets_match(cards_text: String, card_text_text: String) -> bool:
	var parsed: Variant = Card.cards_from_text(cards_text)
	if parsed == null:
		return false
	var cards: Array[Card] = []
	cards.assign(parsed)
	var flavor: Dictionary[String, String] = CardText.flavor_texts_from_text(card_text_text)
	var card_ids: Dictionary = {}
	for card: Card in cards:
		card_ids[card.id] = true
	if card_ids.size() != flavor.size():
		return false
	for id: String in flavor.keys():
		if not card_ids.has(id):
			return false
	return true


# ---- AC1 + AC2:5 關各一條 ----------------------------------------------------
func test_level_1_tables_parse_and_have_identical_id_sets() -> void:
	_assert_level(1)


func test_level_2_tables_parse_and_have_identical_id_sets() -> void:
	_assert_level(2)


func test_level_3_tables_parse_and_have_identical_id_sets() -> void:
	_assert_level(3)


func test_level_4_tables_parse_and_have_identical_id_sets() -> void:
	_assert_level(4)


func test_level_5_tables_parse_and_have_identical_id_sets() -> void:
	_assert_level(5)


func _assert_level(n: int) -> void:
	var parsed: Variant = Card.cards_from_text(FileAccess.get_file_as_string(_cards_path(n)))
	assert_bool(parsed != null).is_true()
	assert_bool(
		_id_sets_match(
			FileAccess.get_file_as_string(_cards_path(n)),
			FileAccess.get_file_as_string(_text_path(n))
		)
	).append_failure_message("第 %d 關兩表 id 集合不一致" % n).is_true()


# ---- AC3:14 張新卡(入表 12 張)數值逐張鎖死(vs02~vs05 各一次)----------------
func test_new_cards_match_spec_in_every_new_level_table() -> void:
	for n: int in [2, 3, 4, 5]:
		var by_id: Dictionary = {}
		for card: Card in _parse_cards(_cards_path(n)):
			by_id[card.id] = card
		for id: String in _SPEC.keys():
			assert_bool(by_id.has(id)).append_failure_message("vs0%d 缺 %s" % [n, id]).is_true()
			if not by_id.has(id):
				continue
			var c: Card = by_id[id]
			var s: Array = _SPEC[id]
			var tag: String = "vs0%d %s(規格第 %d 行)" % [n, id, s[10]]
			assert_int(c.category).append_failure_message(tag + " category").is_equal(s[0])
			assert_int(c.delta_atk).append_failure_message(tag + " atk").is_equal(s[1])
			assert_int(c.delta_def).append_failure_message(tag + " def").is_equal(s[2])
			assert_int(c.duration_rounds).append_failure_message(tag + " dur").is_equal(s[3])
			assert_int(c.named_unit_id).append_failure_message(tag + " named").is_equal(s[4])
			assert_int(c.cost_type).append_failure_message(tag + " cost_type").is_equal(s[5])
			assert_int(c.cost_amount).append_failure_message(tag + " cost").is_equal(s[6])
			assert_int(c.effect_value).append_failure_message(tag + " effect").is_equal(s[7])
			assert_int(c.partner_unit_id).append_failure_message(tag + " partner").is_equal(s[8])
			assert_int(c.target_range).append_failure_message(tag + " range").is_equal(s[9])
			assert_int(c.source).append_failure_message(tag + " source").is_equal(Card.Source.BASE)


# 🔴 c03(card_13)借用 target_range 表達「與另一名我方距離 <= 2」(2026-11-19 管理者裁決);
# 誤填 -1 會靜默失去條件、測試與載入都不報錯,故單獨鎖死。
func test_c03_card_13_target_range_is_two_in_every_new_level_table() -> void:
	for n: int in [2, 3, 4, 5]:
		var found: bool = false
		for card: Card in _parse_cards(_cards_path(n)):
			if card.id == "card_13":
				found = true
				assert_int(card.target_range).append_failure_message(
					"vs0%d card_13 target_range 必須為 2" % n
				).is_equal(2)
		assert_bool(found).is_true()


# ---- D4:vs02~vs05 退役 card_01~06;保留 card_07/08;c13/c14 不入表 -----------------
func test_new_level_tables_have_no_retired_cards_and_exactly_fourteen_rows() -> void:
	for n: int in [2, 3, 4, 5]:
		var ids: Array[String] = []
		for card: Card in _parse_cards(_cards_path(n)):
			ids.append(card.id)
		assert_int(ids.size()).append_failure_message("vs0%d 應 14 列" % n).is_equal(14)
		for retired: String in _RETIRED_IDS:
			assert_bool(ids.has(retired)).append_failure_message("vs0%d 不應有 %s" % [n, retired]).is_false()
		for kept: String in _KEPT_IDS:
			assert_bool(ids.has(kept)).is_true()
		assert_bool(ids.has("card_23") or ids.has("card_24")).is_false()


# ---- AC4:vs01 與教學場不變 ------------------------------------------------------
func test_vs01_keeps_original_eight_cards_and_tutorial_table_still_loads_empty() -> void:
	var ids: Array[String] = []
	for card: Card in _parse_cards(_cards_path(1)):
		ids.append(card.id)
	assert_array(ids).contains_exactly(
		["card_01", "card_02", "card_03", "card_04", "card_05", "card_06", "card_07", "card_08"]
	)
	var tutorial: Variant = Card.cards_from_text(
		FileAccess.get_file_as_string(_DIR + "tutorial_cards.txt")
	)
	assert_bool(tutorial != null).is_true()
	assert_int((tutorial as Array).size()).is_equal(0)


# 牌面文字不得寫死卡表數字:凡卡表數字一律用記號(新 12 列不含半形數字,代價行的「付出 N」亦走記號)。
func test_new_card_texts_carry_no_hardcoded_digits() -> void:
	for n: int in [2, 3, 4, 5]:
		var flavor: Dictionary[String, String] = CardText.flavor_texts_from_text(
			FileAccess.get_file_as_string(_text_path(n))
		)
		for id: String in _SPEC.keys():
			assert_bool(flavor.has(id)).is_true()
			var digit: RegEx = RegEx.create_from_string("[0-9]")
			assert_bool(digit.search(flavor[id]) == null).append_failure_message(
				"vs0%d %s 牌面含寫死數字" % [n, id]
			).is_true()


# ---- AC6 敏感度證明(記憶體內替身表,一個 mutant 一次獨立執行)------------------
const _GOOD_CARDS: String = (
	"card_a,TEMPORARY_STAT_MODIFIER,1,0,1,-1,-1,0,1,ONLY\n"
	+ "card_b,PERMANENT_AFFINITY_WRITE,0,0,0,1,2,2,-1,ONLY\n"
)
const _GOOD_TEXT: String = "card_a,名甲,文字甲\ncard_b,名乙,文字乙\n"


func test_sensitivity_proof_baseline_substitute_tables_pass() -> void:
	assert_bool(_id_sets_match(_GOOD_CARDS, _GOOD_TEXT)).is_true()


# ① 牌面文字表少一列 -> AC2 紅
func test_sensitivity_proof_missing_text_row_is_caught() -> void:
	assert_bool(_id_sets_match(_GOOD_CARDS, "card_a,名甲,文字甲\n")).is_false()


# ② 牌表多一列、無文字 -> AC2 紅
func test_sensitivity_proof_extra_card_row_without_text_is_caught() -> void:
	var extra: String = _GOOD_CARDS + "card_c,TEMPORARY_STAT_MODIFIER,1,0,1,-1,-1,0,1,ONLY\n"
	assert_bool(_id_sets_match(extra, _GOOD_TEXT)).is_false()


# ③ 欄數 12 的列 -> AC1 紅(解析回 null)
func test_sensitivity_proof_twelve_field_row_fails_parse() -> void:
	var bad: String = _GOOD_CARDS + "card_c,HEAL,0,0,0,-1,-1,0,1,ONLY,HP,3\n"
	assert_bool(Card.cards_from_text(bad) == null).is_true()


# ④ 類別字串拼錯 -> AC1 紅
func test_sensitivity_proof_misspelled_category_fails_parse() -> void:
	var bad: String = _GOOD_CARDS + "card_c,DIRECT_DAMAG,0,0,0,-1,-1,0,1,ONLY,HP,3,5,-1,-1,BASE\n"
	assert_bool(Card.cards_from_text(bad) == null).is_true()


# ⑤ c03 站位欄誤填 -1 -> 鎖死測試所用的判準會抓到
func test_sensitivity_proof_c03_range_minus_one_is_caught() -> void:
	var line: String = "card_13,DIRECT_DAMAGE,0,0,0,-1,-1,0,-1,ONLY,HP,8,18,-1,-1,BASE"
	var card: Card = Card.from_csv_line(line)
	assert_bool(card != null and card.target_range == 2).is_false()
