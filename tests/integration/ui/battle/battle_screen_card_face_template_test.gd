# Story 028 AC4 / AC5②:確認面板與手牌說明框兩處,牌面文字皆為【替換後】數字。
#
# 載入真實 BattleScreen.tscn(instantiate -> (set_script,僅 mutant)-> add_child),
# 出牌走真實輸入路徑(battle_open_hand / battle_confirm);牌面文字樣板直接寫進
# 畫面的 _card_flavor_texts(該表本來就是 _ready 讀檔後的快取),不讀不寫任何檔案。
# 敏感度證明(常駐,一個 mutant 一次):② _card_face_text 繞過替換 -> AC4 情境回 false。
# 誠實登記:兩處取用共用同一個 _card_face_text,mutant 只能同時繞過兩處,無法單獨證明
# 「只有手牌那處」敏感;兩處各自的斷言(下方兩條 test_ac4_*)分別守各自的顯示結果。
extends GdUnitTestSuite

## story-029:牌名欄。Z3 顯示 牌名+換行+效果;確認面板標題只顯示牌名。
const _NAME: String = "測試牌名"
const _EXPECTED_Z3: String = _NAME + "\n" + "付出 3 點血,防禦 −2"
const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TEMPLATE: String = "付出 {cost_amount} 點血,防禦 {delta_def}"
const _EXPECTED: String = "付出 3 點血,防禦 \u22122"

var _host_snap: CursorHostSnapshot = null


## ② 繞過替換:回傳未替換的原字串。
class _MutantBypass extends BattleScreen:
	func _card_face_text(card: Card) -> String:
		return _card_flavor_texts.get(card.id, "")


## story-029 AC6①:牌名欄與效果欄對調。
class _MutantSwapColumns extends BattleScreen:
	func _card_face_text(card: Card) -> String:
		return _card_names.get(card.id, "")

	func _card_face_name(card: Card) -> String:
		return CardText.render(card, _card_flavor_texts.get(card.id, ""))


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _pressed(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _instance(mutant: GDScript = null) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if mutant != null:
		instance.set_script(mutant)
	auto_free(instance)
	add_child(instance)
	return instance


## 固定單張:不指定付款人的血代價牌,文字樣板含兩個記號、其中一個為負數欄位。
func _install_card(instance: BattleScreen) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("t028_face", 1, -2, 1, Card.UNRESTRICTED_TARGET)
	card.cost_type = Card.CostType.HP
	card.cost_amount = 3
	instance._card_flavor_texts["t028_face"] = _TEMPLATE
	instance._card_names["t028_face"] = _NAME
	instance._card_names["t028_face"] = _NAME
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
	return card


## 手牌處:打開手牌、游標在第 0 張,說明框文字。
func _hand_text(script: GDScript = null) -> String:
	var s: BattleScreen = _instance(script)
	_install_card(s)
	s._input(_pressed(&"battle_open_hand"))
	s._refresh_view()
	s._hand_bar._set_expand_progress(1.0)
	return s._hand_bar.diagnostic_detail_panel_text()


## 確認面板處:選牌、選對象,進入 CONFIRMING 後面板標題文字。
func _confirm_text(script: GDScript = null) -> String:
	var s: BattleScreen = _instance(script)
	_install_card(s)
	var payer: Unit = s._state.units_of(Unit.Faction.PLAYER)[0]
	s._input(_pressed(&"battle_open_hand"))
	s._input(_pressed(&"battle_confirm"))
	if not s._card_confirming and s._controller.select_target(payer.id):
		s._after_target_selection_advanced()
	if not s._card_confirming:
		return "<<not confirming>>"
	return s._card_confirm_panel.diagnostic_title_text()


func _scn_ac4(script: GDScript = null) -> bool:
	return _hand_text(script) == _EXPECTED_Z3 and _confirm_text(script) == _NAME


func test_ac4_hand_detail_panel_shows_substituted_numbers() -> void:
	assert_str(_hand_text()).is_equal(_EXPECTED_Z3)


func test_ac4_confirm_panel_shows_substituted_numbers() -> void:
	assert_str(_confirm_text()).is_equal(_NAME)


func test_sensitivity_proof_bypass_render_goes_red() -> void:
	assert_bool(_scn_ac4(_MutantBypass)).is_false()


## story-029 AC6①:欄位對調 -> AC4 情境回 false(基準:未對調時為 true)。
func test_sensitivity_proof_swapped_name_and_effect_columns_goes_red() -> void:
	assert_bool(_scn_ac4()).is_true()
	assert_bool(_scn_ac4(_MutantSwapColumns)).is_false()
