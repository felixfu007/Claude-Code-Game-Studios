# Story 020a(production/epics/skill-card-system/story-020-card-confirm-panel-cost-and-unplayable-reason.md)
# AC1 / AC2 / AC6 ①② + 兩個 story-017 佔位(補血 0/0 列、雙人卡只顯示付款人)。
#
# 載入【真實】BattleScreen.tscn(technical-preferences 第 5 點):instantiate() -> (set_script,僅 mutant)
# -> add_child();資料用場景預設真實關卡資料,出牌走真實輸入路徑
# (battle_open_hand / battle_confirm -> _after_target_selection_advanced -> 面板)。
# 檔案存取:無(不讀不寫任何檔案;文案經 Loc 取鍵)。
#
# AC1 判準:面板上的「代價數字 + 付款人前後 HP / 折損進度」== 確認後單位 HP / 折損的實際變化
# (讀引擎執行後的真值,不在測試裡重算扣款規則)。
# 敏感度證明(常駐 test_sensitivity_proof_*,一個 mutant 一次獨立執行):
#   ① _build_cost_block 自行重算且算錯(多算 1)-> AC1 情境回 false
#   ② 付不起時確認鈕仍可用(區塊降級為 NONE)-> AC2 情境回 false
# 誠實登記:Mutant ② 覆蓋的是「面板的啟用旗標」;_apply_pending_card_confirm 的 early-return 閘門
# 本身(連 controller.confirm 都不呼叫)無法由結果區分 —— CardPlaySession.confirm() 本來就會因
# 付不起而回 false、零寫入(015),所以閘門是第二道防線,本檔不另證其敏感度。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _WIDE_RANGE: int = 99

var _host_snap: CursorHostSnapshot = null


## ① 面板代價自行重算且算錯:多算 1 點。
class _MutantWrongAmount extends BattleScreen:
	func _build_cost_block(card: Card, caster_id: int) -> CardConfirmPanel.CostBlock:
		var block: CardConfirmPanel.CostBlock = super(card, caster_id)
		block.amount += 1
		for i: int in block.hp_after.size():
			block.hp_after[i] -= 1
		return block


## ② 付不起時確認鈕仍可用:把「付不起」降級成無代價區塊。
class _MutantAlwaysEnabled extends BattleScreen:
	func _build_cost_block(card: Card, caster_id: int) -> CardConfirmPanel.CostBlock:
		var block: CardConfirmPanel.CostBlock = super(card, caster_id)
		if block.kind == CardConfirmPanel.CostBlock.Kind.UNAFFORDABLE:
			block.kind = CardConfirmPanel.CostBlock.Kind.NONE
		return block


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


# ---- 夾具/輔助 -----------------------------------------------------------------------

func _instance(mutant: GDScript = null) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if mutant != null:
		instance.set_script(mutant)
	auto_free(instance)
	add_child(instance)
	return instance


func _pressed(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


## 不指定付款人、單人付血的甲類卡:付款人 = 玩家選的對象(named < 1)。
func _hp_card(amount: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("t020_hp", 1, 0, 1, Card.UNRESTRICTED_TARGET)
	card.cost_type = Card.CostType.HP
	card.cost_amount = amount
	return card


func _duo_buff(a: int, b: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("t020_duo", 2, 1, 2, a)
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.partner_unit_id = b
	card.target_range = _WIDE_RANGE
	return card


func _directed_heal(payer: int, recipient: int) -> Card:
	var card: Card = Card.new()
	card.id = "t020_heal"
	card.category = Card.Category.HEAL
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.effect_value = 2
	card.named_unit_id = payer
	card.partner_unit_id = recipient
	card.target_range = _WIDE_RANGE
	return card


## 裝上單張牌的手牌 + 新 session;回傳該 session 用的好感池(測試可直接寫入以改變關係態)。
func _install_card(instance: BattleScreen, card: Card) -> AffinityDataPool:
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards)
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	var links: Array[AffinityLink] = []
	var session: CardPlaySession = CardPlaySession.new(
		deck, instance._state, links, NullAffinityWritePort.new()
	)
	var pool: AffinityDataPool = AffinityDataPool.new()
	session.attach_affinity_pool(pool)
	instance._controller._card_play_session = session
	return pool


func _wound_to(instance: BattleScreen, unit: Unit, target_hp: int) -> void:
	var amount: int = unit.hp - target_hp
	instance._state.commit_authoritative_change(func() -> void: unit.take_damage(amount))


## 走真實輸入路徑把畫面帶到確認面板(固定目標卡直接進;否則再選一個對象)。
func _enter_confirming(instance: BattleScreen, target_id: int = -1) -> void:
	instance._input(_pressed(&"battle_open_hand"))
	instance._input(_pressed(&"battle_confirm"))
	if not instance._card_confirming and target_id >= 1:
		if instance._controller.select_target(target_id):
			instance._after_target_selection_advanced()


func _press_confirm(instance: BattleScreen) -> void:
	instance._input(_pressed(&"battle_confirm"))
	instance._process(0.0)


func _name_of(unit: Unit) -> String:
	return BattleScreen.unit_display_name(unit)


# ---- 情境函式(真品回 true;mutant 回 false)---------------------------------------------

## AC1:單人付血。面板顯示的付款人/點數/前後 HP == 確認後的真實 HP 變化。
func _scn_ac1_hp_single(script: GDScript = null) -> bool:
	var s: BattleScreen = _instance(script)
	var payer: Unit = s._state.units_of(Unit.Faction.PLAYER)[0]
	_install_card(s, _hp_card(2))
	_enter_confirming(s, payer.id)
	if not s._card_confirming:
		return false
	var panel: CardConfirmPanel = s._card_confirm_panel
	var hp_before: int = payer.hp
	var cost_text: String = panel.diagnostic_cost_text()
	var detail_text: String = panel.diagnostic_cost_detail_text()
	_press_confirm(s)
	var paid: int = hp_before - payer.hp
	var expect_cost: String = Loc.localize(&"battle.card_confirm.cost_hp_format") % [_name_of(payer), paid]
	var expect_detail: String = Loc.localize(&"battle.card_confirm.hp_change_format") % [hp_before, payer.hp]
	return paid > 0 and cost_text == expect_cost and detail_text == expect_detail


## AC2:付不起。面板不關、確認鈕停用且鈕面 `無法出牌`、付不起者那列有 ✕ 與文字、零寫入。
func _scn_ac2_unaffordable(script: GDScript = null) -> bool:
	var s: BattleScreen = _instance(script)
	var payer: Unit = s._state.units_of(Unit.Faction.PLAYER)[0]
	_install_card(s, _hp_card(2))
	_wound_to(s, payer, 2)
	var version_before: int = s._state.combat_state_version
	var hp_before: int = payer.hp
	_enter_confirming(s, payer.id)
	if not s._card_confirming:
		return false
	var panel: CardConfirmPanel = s._card_confirm_panel
	var row: String = Loc.localize(&"battle.card_confirm.unaffordable_row_format") % _name_of(payer)
	var shows_unaffordable: bool = panel.diagnostic_unaffordable_text() == row \
		and panel.diagnostic_unaffordable_text().begins_with("✕") \
		and panel.diagnostic_button_text() == Loc.localize(&"battle.card_confirm.button_unplayable") \
		and not panel.is_confirm_enabled()
	_press_confirm(s)
	return shows_unaffordable \
		and panel.visible \
		and s._card_confirming \
		and payer.hp == hp_before \
		and s._state.combat_state_version == version_before


# ---- AC1 ------------------------------------------------------------------------------

func test_ac1_hp_single_panel_matches_actual_deduction() -> void:
	assert_bool(_scn_ac1_hp_single()).append_failure_message(
		"單人付血:面板代價文字/HP 前後應等於確認後的實際扣款"
	).is_true()


func test_ac1_pair_relation_none_both_pay_panel_matches_actual_deduction() -> void:
	var s: BattleScreen = _instance()
	var units: Array[Unit] = s._state.units_of(Unit.Faction.PLAYER)
	var a: Unit = units[0]
	var b: Unit = units[1]
	_install_card(s, _duo_buff(a.id, b.id))
	_enter_confirming(s)
	assert_bool(s._card_confirming).is_true()
	var panel: CardConfirmPanel = s._card_confirm_panel
	var a_before: int = a.hp
	var b_before: int = b.hp
	var relation_text: String = panel.diagnostic_relation_text()
	var cost_text: String = panel.diagnostic_cost_text()
	var detail_text: String = panel.diagnostic_cost_detail_text()
	var note_text: String = panel.diagnostic_cost_note_text()
	var target_text: String = panel.diagnostic_target_text()

	_press_confirm(s)

	var paid: int = a_before - a.hp
	assert_int(paid).append_failure_message("付款人應確實被扣血").is_greater(0)
	assert_int(b_before - b.hp).append_failure_message("兩人各付同額").is_equal(paid)
	assert_str(relation_text).is_equal(
		Loc.localize(&"battle.card_confirm.relation_current_format") % Loc.localize(&"battle.relation.state.none")
	)
	assert_str(cost_text).is_equal(Loc.localize(&"battle.card_confirm.cost_both_format") % paid)
	var row_format: String = Loc.localize(&"battle.card_confirm.cost_both_row_format")
	assert_str(detail_text).is_equal(
		"\n".join(PackedStringArray([
			row_format % [_name_of(a), a_before, a.hp],
			row_format % [_name_of(b), b_before, b.hp],
		]))
	)
	assert_str(note_text).is_equal(Loc.localize(&"battle.card_confirm.relation_none_pays_hp"))
	# 佔位修正:雙人卡「作用對象」顯示兩人(夥伴也吃到修正),不只付款人。
	assert_str(target_text).is_equal(
		Loc.localize(&"battle.card_confirm.target_format_pair") % [_name_of(a), _name_of(b)]
	)


func test_ac1_pair_relation_pos_shows_fray_and_matches_actual_wear() -> void:
	var s: BattleScreen = _instance()
	var units: Array[Unit] = s._state.units_of(Unit.Faction.PLAYER)
	var a: Unit = units[0]
	var b: Unit = units[1]
	var pool: AffinityDataPool = _install_card(s, _duo_buff(a.id, b.id))
	var pair: Variant = CardCostPlan.pair_of_units(a.id, b.id)
	assert_bool(pair != null).append_failure_message("兩單位應構成合法配對").is_true()
	pool.append_record(int(pair) as AffinityTypes.Pair, 1.0, AffinityTypes.Source.STORY_EVENT)
	var wear_before: int = s._state.pair_wear(int(pair))
	var hp_a: int = a.hp
	var hp_b: int = b.hp
	_enter_confirming(s)
	assert_bool(s._card_confirming).is_true()
	var panel: CardConfirmPanel = s._card_confirm_panel
	var relation_text: String = panel.diagnostic_relation_text()
	var cost_text: String = panel.diagnostic_cost_text()
	var detail_text: String = panel.diagnostic_cost_detail_text()
	var note_text: String = panel.diagnostic_cost_note_text()

	_press_confirm(s)

	var cap: int = CardCostTuning.defaults().pair_cost_cap()
	var wear_after: int = s._state.pair_wear(int(pair))
	assert_int(a.hp).append_failure_message("折損不付血").is_equal(hp_a)
	assert_int(b.hp).is_equal(hp_b)
	assert_str(relation_text).is_equal(
		Loc.localize(&"battle.card_confirm.relation_current_format") % Loc.localize(&"battle.relation.state.pos")
	)
	assert_str(cost_text).is_equal(Loc.localize(&"battle.card_confirm.cost_fray_format") % 1)
	assert_str(detail_text).is_equal(
		Loc.localize(&"battle.card_confirm.fray_progress_format") % [_name_of(a), _name_of(b), wear_before, cap]
	)
	assert_str(note_text).is_equal("")
	assert_int(wear_after).append_failure_message("折損實際增加量應等於面板代價").is_equal(mini(wear_before + 1, cap))


# ---- AC2 ------------------------------------------------------------------------------

func test_ac2_unaffordable_payer_keeps_panel_open_button_disabled_zero_writes() -> void:
	assert_bool(_scn_ac2_unaffordable()).append_failure_message(
		"付不起:面板不關、鈕面 無法出牌、✕ 列、零寫入"
	).is_true()


func test_ac2_unaffordable_reason_row_and_card_reason_both_say_hp_insufficient() -> void:
	# UX 裁定(2026-11-19)待決 1:兩個鍵可以,但渲染後都必須含「血量不足」,防止兩鍵各自改字而脫節。
	var row: String = Loc.localize(&"battle.card_confirm.unaffordable_row_format") % "某人"
	var reason: String = Loc.localize(&"battle.card_reason.hp_insufficient_format") % "某人"
	assert_str(row).contains("血量不足")
	assert_str(reason).contains("血量不足")


# ---- 017 佔位 ----------------------------------------------------------------------------

func test_heal_panel_no_longer_shows_zero_stat_rows() -> void:
	var s: BattleScreen = _instance()
	var units: Array[Unit] = s._state.units_of(Unit.Faction.PLAYER)
	var recipient: Unit = units[1]
	_wound_to(s, recipient, recipient.hp - 4)
	_install_card(s, _directed_heal(units[0].id, recipient.id))
	_enter_confirming(s)
	assert_bool(s._card_confirming).is_true()
	var panel: CardConfirmPanel = s._card_confirm_panel
	assert_bool(panel._delta_atk_label.visible).append_failure_message("補血卡不顯示 ΔATK").is_false()
	assert_bool(panel._delta_def_label.visible).is_false()
	# story-020d:補血卡的「合併後」列改顯示「回復：HP 前 → 後」(UX 缺口二),不再隱藏。
	assert_str(panel.diagnostic_effective_text()).contains("回復：HP")
	assert_str(panel.diagnostic_effective_text()).contains("→")
	assert_str(panel.diagnostic_target_text()).contains(_name_of(recipient))


# ---- AC6 敏感度證明 -----------------------------------------------------------------------

func test_sensitivity_proof_mutant_wrong_amount_turns_ac1_red() -> void:
	assert_bool(_scn_ac1_hp_single(_MutantWrongAmount)).append_failure_message(
		"mutant ① 面板多算 1 點,AC1 偵測器必須判 false;若為 true 代表抓不到自行重算的缺陷"
	).is_false()


func test_sensitivity_proof_mutant_always_enabled_turns_ac2_red() -> void:
	assert_bool(_scn_ac2_unaffordable(_MutantAlwaysEnabled)).append_failure_message(
		"mutant ② 付不起時鈕仍可用,AC2 偵測器必須判 false;若為 true 代表抓不到"
	).is_false()
