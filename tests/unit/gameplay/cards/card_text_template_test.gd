# CardText.render()(story-028 牌面數字樣板)單元測試。
#
# 🔴 本檔屬甲類明文例外(.claude/rules/test-standards.md):AC2 一條讀 assets/data/cards/
# 下 vs01~vs05 的真實牌面文字檔,驗「現行文字經 render() 後與替換前逐字相同」。
# 誠實登記:該條只證明「現有檔內沒有被誤替換的 {…} 字樣」,不證明未來新增的檔也如此。
# 敏感度證明(常駐 test_sensitivity_proof_*,一個 mutant 一次):
#   ① render 回傳原字串 -> AC1 紅(見 _mutant_render_identity 與對應情境)
# 做法:render 以 Callable 注入,真品綁 CardText.render,mutant 綁恆等函式。
extends GdUnitTestSuite

const _CARD_TEXT_FILES: Array[String] = [
	"res://assets/data/cards/vs01_card_text.txt",
	"res://assets/data/cards/vs02_card_text.txt",
	"res://assets/data/cards/vs03_card_text.txt",
	"res://assets/data/cards/vs04_card_text.txt",
	"res://assets/data/cards/vs05_card_text.txt",
]


func _card() -> Card:
	var card: Card = Card.new()
	card.id = "t028"
	card.cost_amount = 3
	card.effect_value = 12
	card.target_range = 2
	card.delta_atk = 3
	card.delta_def = -2
	card.duration_rounds = 2
	return card


func _mutant_render_identity(_card: Card, text: String) -> String:
	return text


## AC1 情境:真品回 true;傳入的 render 函式若不替換則回 false。
func _scn_ac1(render_fn: Callable) -> bool:
	var card: Card = _card()
	var a: String = render_fn.call(card, "付出 {cost_amount} 點血,造成 {effect_value} 傷害")
	var b: String = render_fn.call(card, "攻擊 +{delta_atk}、防禦 {delta_def},持續 {duration_rounds} 回合,{target_range} 格")
	return a == "付出 3 點血,造成 12 傷害" \
		and b == "攻擊 +3、防禦 \u22122,持續 2 回合,2 格"


func test_ac1_tokens_replaced_with_card_fields_incl_negative() -> void:
	assert_bool(_scn_ac1(CardText.render)).is_true()


func test_sensitivity_proof_ac1_identity_render_goes_red() -> void:
	# 常駐:mutant(原樣回傳)必須讓 AC1 情境回 false,證明 AC1 對替換行為敏感。
	assert_bool(_scn_ac1(_mutant_render_identity)).is_false()


func test_negative_uses_u2212_not_ascii_hyphen() -> void:
	var out: String = CardText.render(_card(), "{delta_def}")
	assert_str(out).is_equal("\u22122")
	assert_bool(out.contains("-")).is_false()


func test_ac2_text_without_tokens_is_verbatim() -> void:
	assert_str(CardText.render(_card(), "孤注一擲——全押")).is_equal("孤注一擲——全押")
	assert_str(CardText.render(_card(), "")).is_equal("")


func test_ac2_real_card_text_files_unchanged_by_render() -> void:
	var card: Card = _card()
	var checked: int = 0
	for path: String in _CARD_TEXT_FILES:
		var table: Dictionary[String, String] = CardText.flavor_texts_from_text(
			FileAccess.get_file_as_string(path)
		)
		for id: String in table:
			checked += 1
			assert_str(CardText.render(card, table[id])).append_failure_message(
				"%s / %s 被 render 改動" % [path, id]
			).is_equal(table[id])
	assert_int(checked).is_greater(0)


func test_ac3_unknown_token_kept_verbatim_with_error() -> void:
	var result: Array[String] = [""]
	var call: Callable = func() -> void:
		result[0] = CardText.render(_card(), "傷害 {no_such_field} 點,{cost_amount}")
	await assert_error(call).is_push_error(any_string())
	assert_str(result[0]).is_equal("傷害 {no_such_field} 點,3")


func test_null_card_returns_text_unchanged() -> void:
	assert_str(CardText.render(null, "{cost_amount}")).is_equal("{cost_amount}")
