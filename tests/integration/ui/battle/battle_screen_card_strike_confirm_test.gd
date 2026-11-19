# Story 020c(production/epics/skill-card-system/story-020-card-confirm-panel-cost-and-unplayable-reason.md)
# AC4:直傷選敵(UX AC-5:選敵期間 card_target 層出現、移動/攻擊/威脅層隱藏;選敵後一律再經確認面板)、
# c12 合擊面板兩擊(UX AC-7:略過 + 「代價照付，不退」、結算數字 = 預告);018 第 4 題:卡牌擊殺後
# battle_screen 的收尾(棋子移除、勝負、選取狀態)。
#
# 載入【真實】BattleScreen.tscn:instantiate() -> (set_script,僅 mutant)-> 設 override -> add_child();
# 順序見 .claude/docs/coding-standards.md「set_script() 會清掉先前賦值的屬性」。
# 檔案存取:甲類 —— 只讀 assets/data/ 的版控夾具(經 BattleScreen 的 override 路徑讀入),不寫任何檔案。
# 敏感度證明(常駐 test_sensitivity_proof_*,一個 mutant 一次):
#   ① 選敵期間不隱藏移動層(_is_selecting_enemy_for_damage_card 恆 false)-> 選敵隱藏斷言回 false
#   ② 面板預告多算 1 -> 預告文字斷言抓得到
#   ③ 擊殺後不重繪(_refresh_view 空操作)-> 棋子移除斷言抓得到
# 誠實登記:AC-5 只讀 BoardView 的圖層節點數與集合,不驗圖形長相(需開窗人眼);
# 「視線被擋章/框+X」兩種不合法樣式本檔未逐一斷言(只斷言有 card_target 層節點)。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_PATH: String = "res://assets/data/units/test_fixture_roster_strike.txt"
const _WIDE_RANGE: int = 99

var _host_snap: CursorHostSnapshot = null


## ① 選敵期間不隱藏移動層。
class _MutantKeepsMoveLayer extends BattleScreen:
	func _is_selecting_enemy_for_damage_card() -> bool:
		return false


## ② 預告把每擊傷害多算 1。
class _MutantPreviewOffByOne extends BattleScreen:
	func _open_card_confirm_panel() -> void:
		super()
		var rows: Array[Dictionary] = []
		for entry: Dictionary in _controller.preview_strikes():
			rows.append({
				"caster_name": "X", "enemy_name": "Y", "damage": int(entry["damage"]) + 1,
				"hp_before": int(entry["hp_before"]), "hp_after": int(entry["hp_after"]),
				"skipped": bool(entry["skipped"]),
			})
		_card_confirm_panel.show_strike_confirmation(
			_controller.selected_card().id, "", rows, true
		)


## ③ 擊殺後不重繪畫面。
class _MutantNoRefresh extends BattleScreen:
	func _refresh_view() -> void:
		pass


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
	instance.terrain_path_override = _TERRAIN_PATH
	instance.roster_path_override = _ROSTER_PATH
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


func _direct_card(damage: int) -> Card:
	var card: Card = Card.new()
	card.id = "t020c_direct"
	card.category = Card.Category.DIRECT_DAMAGE
	card.cost_type = Card.CostType.HP
	card.cost_amount = 3
	card.effect_value = damage
	card.named_unit_id = 1
	return card


func _combo_card(damage: int) -> Card:
	var card: Card = Card.new()
	card.id = "t020c_combo"
	card.category = Card.Category.COMBO_DAMAGE
	card.cost_type = Card.CostType.HP
	card.cost_amount = 1
	card.effect_value = damage
	card.named_unit_id = 1
	card.partner_unit_id = 2
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
	instance._refresh_view()


func _wound_to(instance: BattleScreen, unit: Unit, target_hp: int) -> void:
	var amount: int = unit.hp - target_hp
	instance._state.commit_authoritative_change(func() -> void: unit.take_damage(amount))


## 走真實輸入路徑到「選敵」(具名出手者,不需選付款人)。
func _enter_enemy_selection(instance: BattleScreen) -> void:
	instance._input(_pressed(&"battle_open_hand"))
	instance._input(_pressed(&"battle_confirm"))
	instance._refresh_view()


func _pick_enemy(instance: BattleScreen, enemy_id: int) -> bool:
	if not instance._controller.select_target(enemy_id):
		return false
	instance._after_target_selection_advanced()
	return true


func _press_confirm(instance: BattleScreen) -> void:
	instance._input(_pressed(&"battle_confirm"))
	instance._process(0.0)


func _enemy(instance: BattleScreen, id: int) -> Unit:
	return instance._state.unit_by_id(id)


# ---- 直傷選敵 ------------------------------------------------------------------------

func _scn_direct_selection_hides_layers(script: GDScript = null) -> bool:
	var instance: BattleScreen = _instance(script)
	_install_card(instance, _direct_card(6))
	# 先選中我方單位,使移動/攻擊層本來就有東西可畫(否則「隱藏」斷言恆真、證不出任何事)。
	if not instance._controller.select_unit(1):
		return false
	instance._refresh_view()
	if instance._board_view._move_highlight_layer.get_child_count() == 0:
		return false
	_enter_enemy_selection(instance)
	if not instance._card_selecting_target or instance._card_confirming:
		return false
	var board: BoardView = instance._board_view
	return (
		board._move_highlight_layer.get_child_count() == 0
		and board._attack_cells.is_empty()
		and board._threat_cells.is_empty()
		and board._card_target_highlight_layer.get_child_count() > 0
	)


func test_direct_damage_enemy_selection_shows_card_target_and_hides_other_layers() -> void:
	assert_bool(_scn_direct_selection_hides_layers()).is_true()


func test_sensitivity_proof_move_layer_not_hidden_is_caught() -> void:
	assert_bool(_scn_direct_selection_hides_layers(_MutantKeepsMoveLayer)).is_false()


func test_direct_damage_legal_enemies_exclude_out_of_reach_one() -> void:
	var instance: BattleScreen = _instance()
	_install_card(instance, _direct_card(6))
	_enter_enemy_selection(instance)
	var legal: Array[int] = instance._controller.legal_targets()
	assert_bool(legal.has(9) and legal.has(10)).is_true()
	assert_bool(legal.has(11)).is_false()


func test_direct_damage_enemy_pick_goes_through_confirm_panel_then_settles_to_preview() -> void:
	var instance: BattleScreen = _instance()
	_install_card(instance, _direct_card(6))
	_enter_enemy_selection(instance)
	assert_bool(_pick_enemy(instance, 9)).is_true()
	# 選敵後一律經面板:尚未結算。
	assert_bool(instance._card_confirming).is_true()
	assert_int(_enemy(instance, 9).hp).is_equal(20)
	var panel_text: String = instance._card_confirm_panel.diagnostic_strike_text()
	assert_str(panel_text).contains("−6").contains("HP 20 → 14")
	_press_confirm(instance)
	assert_int(_enemy(instance, 9).hp).is_equal(14)


func test_direct_damage_cancel_from_panel_returns_to_enemy_selection_with_zero_writes() -> void:
	var instance: BattleScreen = _instance()
	_install_card(instance, _direct_card(6))
	_enter_enemy_selection(instance)
	_pick_enemy(instance, 9)
	instance._input(_pressed(&"battle_cancel"))
	assert_bool(instance._card_confirming).is_false()
	assert_bool(instance._card_selecting_target).is_true()
	assert_int(_enemy(instance, 9).hp).is_equal(20)
	assert_int(_enemy(instance, 1).hp).is_equal(20)


# ---- c12 合擊 ------------------------------------------------------------------------

func _combo_scenario(enemy_hp: int, script: GDScript = null) -> Dictionary:
	var instance: BattleScreen = _instance(script)
	_wound_to(instance, _enemy(instance, 9), enemy_hp)
	_install_card(instance, _combo_card(6))
	_enter_enemy_selection(instance)
	var picked: bool = _pick_enemy(instance, 9)
	var text: String = instance._card_confirm_panel.diagnostic_strike_text()
	var note: String = instance._card_confirm_panel.diagnostic_strike_note_text()
	var preview_total: int = 0
	for entry: Dictionary in instance._controller.preview_strikes():
		preview_total += int(entry["damage"])
	_press_confirm(instance)
	var after_hp: int = _enemy(instance, 9).hp if _enemy(instance, 9).is_alive() else 0
	return {
		"picked": picked, "text": text, "note": note, "preview_total": preview_total,
		"actual_total": enemy_hp - after_hp, "instance": instance,
	}


func test_combo_panel_two_strikes_and_settlement_equals_preview() -> void:
	var r: Dictionary = _combo_scenario(14)
	assert_bool(r["picked"]).is_true()
	assert_str(r["text"]).contains("第一擊").contains("HP 14 → 8").contains("第二擊").contains("HP 8 → 2")
	assert_str(r["note"]).is_empty()
	assert_int(r["actual_total"]).is_equal(r["preview_total"])
	assert_int(r["actual_total"]).is_equal(12)


func test_combo_first_strike_kill_shows_skip_and_cost_not_refunded() -> void:
	var r: Dictionary = _combo_scenario(5)
	assert_str(r["text"]).contains("第二擊").contains("略過")
	assert_str(r["note"]).is_equal(Loc.localize(CardConfirmPanel.TEXT_COST_NOT_REFUNDED))
	var instance: BattleScreen = r["instance"]
	assert_int(r["actual_total"]).is_equal(5)
	assert_int(r["preview_total"]).is_equal(5)
	assert_bool(_enemy(instance, 9).is_alive()).is_false()


func test_sensitivity_proof_preview_off_by_one_is_caught() -> void:
	var r: Dictionary = _combo_scenario(14, _MutantPreviewOffByOne)
	assert_bool(String(r["text"]).contains("−6")).is_false()


# ---- 018 第 4 題:卡牌擊殺後的收尾 -------------------------------------------------------

func _kill_scenario(script: GDScript = null) -> Dictionary:
	var instance: BattleScreen = _instance(script)
	_install_card(instance, _direct_card(99))
	var pieces_before: int = instance._board_view._pieces_layer.get_child_count()
	_enter_enemy_selection(instance)
	_pick_enemy(instance, 9)
	_press_confirm(instance)
	return {"instance": instance, "pieces_before": pieces_before}


func test_card_kill_not_last_enemy_cleans_up_screen_state() -> void:
	var r: Dictionary = _kill_scenario()
	var instance: BattleScreen = r["instance"]
	assert_bool(_enemy(instance, 9).is_alive()).is_false()
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_bool(instance._card_confirming).is_false()
	assert_bool(instance._card_selecting_target).is_false()
	assert_bool(instance._card_confirm_panel.visible).is_false()
	assert_int(instance._board_view._pieces_layer.get_child_count()).is_equal(r["pieces_before"] - 1)


func test_sensitivity_proof_kill_without_redraw_leaves_piece_and_is_caught() -> void:
	var r: Dictionary = _kill_scenario(_MutantNoRefresh)
	var instance: BattleScreen = r["instance"]
	assert_int(instance._board_view._pieces_layer.get_child_count()).is_equal(r["pieces_before"])


func test_card_kill_of_last_enemy_finishes_battle_with_victory() -> void:
	var instance: BattleScreen = _instance()
	_install_card(instance, _direct_card(99))
	# 先把 E2/E3 清掉,讓 E1 成為最後一個敵人(走狀態層權威寫入,與其他測試同一做法)。
	for enemy_id: int in [10, 11]:
		_wound_to(instance, _enemy(instance, enemy_id), 0)
	_enter_enemy_selection(instance)
	_pick_enemy(instance, 9)
	_press_confirm(instance)
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.FINISHED)
	assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
