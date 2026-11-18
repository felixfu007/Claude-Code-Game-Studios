# story-017 (`production/epics/skill-card-system/story-017-heal-and-two-target-buff-cards.md`)
# —— 固定目標卡(雙人加成型、c13/c14 型固定承受者補血)走真實 BattleScreen.tscn:
#   A:選卡後不經目標選取,直接進確認面板;確認後效果生效。
#   B:從確認面板取消 -> 回到選卡(手牌),零寫入。
#
# 涵蓋範圍誠實揭露:
# - 驅動走真實 _input()(battle_open_hand / battle_confirm / battle_cancel)與 _process();
#   未驅動真實游標管線(U-013 自己的職責)。
# - 不涵蓋 HEAL / 雙人甲類確認面板的版面內容(story-020)。
# - 敏感度證明為常駐 mutant 子類別(set_script() 在 add_child 之前、先於任何屬性設定,
#   見 .claude/docs/coding-standards.md「set_script() 會清屬性」):
#   A 把 _open_card_confirm_panel 覆寫成 no-op;B 把取消轉場覆寫成舊行為。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _WIDE_RANGE: int = 99

var _host_snap: CursorHostSnapshot = null


## Mutant A:確認面板永遠不開 -> 「選卡後 _card_confirming」斷言必須轉紅。
class _MutantNoConfirmPanel extends BattleScreen:
	func _open_card_confirm_panel() -> void:
		pass


## Mutant B:固定目標卡取消時沿用舊行為(當作有目標步驟可退回)。
class _MutantOldCancelBehavior extends BattleScreen:
	func _handle_card_confirm_cancel_transition() -> void:
		_card_confirming = false
		_card_confirm_panel.hide_panel()
		_card_selecting_target = true


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _instance(mutant: GDScript = null) -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	if mutant != null:
		instance.set_script(mutant)
	auto_free(instance)
	add_child(instance)
	return instance


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _duo_buff(a: int, b: int) -> Card:
	var card: Card = Card.new_temporary_stat_modifier("t017_duo", 2, 1, 2, a)
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.partner_unit_id = b
	card.target_range = _WIDE_RANGE
	return card


func _directed_heal(payer: int, recipient: int, effect: int) -> Card:
	var card: Card = Card.new()
	card.id = "t017_heal"
	card.category = Card.Category.HEAL
	card.cost_type = Card.CostType.PAIR
	card.cost_amount = 1
	card.effect_value = effect
	card.named_unit_id = payer
	card.partner_unit_id = recipient
	card.target_range = _WIDE_RANGE
	return card


func _install_card(instance: BattleScreen, card: Card) -> void:
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


func _wound(instance: BattleScreen, unit: Unit, amount: int) -> void:
	instance._state.commit_authoritative_change(func() -> void: unit.take_damage(amount))


func _open_hand_and_select(instance: BattleScreen) -> void:
	instance._input(_real_pressed_event(&"battle_open_hand"))
	instance._input(_real_pressed_event(&"battle_confirm"))


func _assert_confirming_without_target_step(instance: BattleScreen) -> void:
	assert_bool(instance._card_confirming).append_failure_message(
		"固定目標卡選卡後應直接進確認面板(_card_confirming)"
	).is_true()
	assert_bool(instance._card_selecting_target).append_failure_message(
		"固定目標卡不應有目標選取步驟(_card_selecting_target)"
	).is_false()


# ─── A:免選目標,直接確認 ────────────────────────────────────────────────────


func test_fixed_target_duo_buff_skips_target_selection_and_confirm_attaches_both() -> void:
	# Arrange
	var instance: BattleScreen = _instance()
	var units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var unit_a: Unit = units[0]
	var unit_b: Unit = units[1]
	_install_card(instance, _duo_buff(unit_a.id, unit_b.id))
	var a_before: int = unit_a.active_modifiers().size()
	var b_before: int = unit_b.active_modifiers().size()

	# Act
	_open_hand_and_select(instance)
	_assert_confirming_without_target_step(instance)
	instance._input(_real_pressed_event(&"battle_confirm"))
	instance._process(0.0)

	# Assert
	assert_int(unit_a.active_modifiers().size()).append_failure_message(
		"確認後付款人應掛上 1 筆修正"
	).is_equal(a_before + 1)
	assert_int(unit_b.active_modifiers().size()).append_failure_message(
		"確認後搭檔應掛上 1 筆修正"
	).is_equal(b_before + 1)


func test_fixed_target_directed_heal_skips_target_selection_and_confirm_heals_recipient() -> void:
	# Arrange
	var instance: BattleScreen = _instance()
	var units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var payer: Unit = units[0]
	var recipient: Unit = units[1]
	_wound(instance, recipient, 4)
	_install_card(instance, _directed_heal(payer.id, recipient.id, 2))
	var hp_before: int = recipient.hp

	# Act
	_open_hand_and_select(instance)
	_assert_confirming_without_target_step(instance)
	instance._input(_real_pressed_event(&"battle_confirm"))
	instance._process(0.0)

	# Assert
	assert_int(recipient.hp).append_failure_message(
		"確認後承受者 HP 應回復(補 2;承受者非付款人不付血)"
	).is_equal(hp_before + 2)


func test_sensitivity_proof_mutant_no_confirm_panel_turns_fixed_target_test_red() -> void:
	# Arrange
	var instance: BattleScreen = _instance(_MutantNoConfirmPanel)
	var units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	_install_card(instance, _duo_buff(units[0].id, units[1].id))

	# Act
	_open_hand_and_select(instance)

	# Assert —— 偵測器(_card_confirming 斷言)對 mutant 必須判定「沒進確認」
	assert_bool(instance._card_confirming).append_failure_message(
		"mutant 的 _open_card_confirm_panel 為 no-op,_card_confirming 應為 false;" +
		"若為 true 代表 A 組測試抓不到該缺陷"
	).is_false()


# ─── B:確認面板取消 -> 回選卡,零寫入 ─────────────────────────────────────────


func _assert_cancel_returns_to_hand_with_zero_writes(
	instance: BattleScreen, watched: Array[Unit]
) -> void:
	var version_before: int = instance._state.combat_state_version
	var hp_before: Array[int] = []
	var mods_before: Array[int] = []
	for unit: Unit in watched:
		hp_before.append(unit.hp)
		mods_before.append(unit.active_modifiers().size())

	instance._input(_real_pressed_event(&"battle_cancel"))

	assert_bool(instance._card_confirming).is_false()
	assert_bool(instance._card_selecting_from_hand).append_failure_message(
		"取消後應回到選卡(_card_selecting_from_hand)"
	).is_true()
	assert_bool(instance._card_selecting_target).append_failure_message(
		"取消後不應進入目標選取(固定目標卡沒有該步驟)"
	).is_false()
	assert_int(instance._state.combat_state_version).append_failure_message(
		"取消不得遞增 combat_state_version"
	).is_equal(version_before)
	for i: int in watched.size():
		assert_int(watched[i].hp).is_equal(hp_before[i])
		assert_int(watched[i].active_modifiers().size()).is_equal(mods_before[i])


func test_fixed_target_duo_buff_cancel_returns_to_hand_selection_with_zero_writes() -> void:
	# Arrange
	var instance: BattleScreen = _instance()
	var units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	_install_card(instance, _duo_buff(units[0].id, units[1].id))
	_open_hand_and_select(instance)
	_assert_confirming_without_target_step(instance)

	# Act / Assert
	var watched: Array[Unit] = [units[0], units[1]]
	_assert_cancel_returns_to_hand_with_zero_writes(instance, watched)


func test_fixed_target_directed_heal_cancel_returns_to_hand_selection_with_zero_writes() -> void:
	# Arrange
	var instance: BattleScreen = _instance()
	var units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	_wound(instance, units[1], 4)
	_install_card(instance, _directed_heal(units[0].id, units[1].id, 2))
	_open_hand_and_select(instance)
	_assert_confirming_without_target_step(instance)

	# Act / Assert
	var watched: Array[Unit] = [units[0], units[1]]
	_assert_cancel_returns_to_hand_with_zero_writes(instance, watched)


func test_sensitivity_proof_mutant_old_cancel_behavior_is_detected() -> void:
	# Arrange
	var instance: BattleScreen = _instance(_MutantOldCancelBehavior)
	var units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	_install_card(instance, _duo_buff(units[0].id, units[1].id))
	_open_hand_and_select(instance)

	# Act
	instance._input(_real_pressed_event(&"battle_cancel"))

	# Assert —— 舊行為會落在「目標選取」而非「選卡」:B 組斷言必須因此為紅
	assert_bool(instance._card_selecting_target).append_failure_message(
		"mutant 沿用舊行為應落入 _card_selecting_target=true(B 組斷言要它為 false)"
	).is_true()
	assert_bool(instance._card_selecting_from_hand).append_failure_message(
		"mutant 不會回到選卡"
	).is_false()
