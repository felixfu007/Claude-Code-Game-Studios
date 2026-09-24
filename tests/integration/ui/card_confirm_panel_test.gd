# Story U-014（`production/epics/card-play-interface/story-u014-confirm-panel.md`）
# —— 確認面板(S3)。
#
# 🔴 涵蓋範圍的誠實揭露（不用「全部涵蓋」蓋過缺口）：
#
# 本檔測的是「S3 一旦被進入之後」的行為 —— card_confirm_panel.gd 本體、
# battle_screen.gd 新增的 _open_card_confirm_panel() / _apply_pending_card_confirm() /
# _handle_card_confirm_cancel_transition() / S3 的 _input() 分派 —— 這些是本 story
# 實際新增的程式碼。
#
# 🔴 「從真實游標裁定走到 CONFIRMING」這一段（_apply_target_confirm_from_cursor_state()
# 呼叫 select_target()/select_second_target() 成功後那兩行新增的
# _card_confirm_target_a/_b 賦值）本檔【不】透過真實 CursorStateHost 裁定管線驅動 ——
# 那條管線是 U-013 自己的既有職責與既有測試涵蓋範圍（tests/integration/ui/card_target_selection_test.gd）。
# 本檔改用「直接呼叫 BattleController.select_target()/select_second_target()（真實呼叫,
# 非重新實作）+ 手動指派 _card_confirm_target_a/_b（模擬那兩行新增賦值會做的事)」
# 的方式驅動到 CONFIRMING,把測試焦點放在本 story 真正新增的下游行為上。
# 這代表：那兩行賦值本身的「有沒有從真實呼叫端接對」不是被本檔獨立驗證的,
# 是讀過程式碼確認過的（見任務報告)。
#
# 沿用既有慣例：真正 load()/instantiate() BattleScreen.tscn 並 add_child()（觸發真實
# _ready()),之後用 tests/integration/ui/card_target_selection_test.gd 的
# 「換掉 _card_play_session」手法換上一個決定性(非隨機開局手牌)的 CardPlaySession ——
# 理由同該檔:_ready() 用 rng=null 的真實時間種子洗牌,寫死抽卡結果會違反
# Determinism 規則。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


## 同 tests/integration/ui/battle/battle_screen_card_play_wiring_test.gd 與
## tests/integration/ui/card_target_selection_test.gd 的既有 after_test() 慣例逐字——
## 本檔多數測試都會讓 BOARD_TILE 走過 register/unregister,不清理會讓下一個測試檔
## 撞到 "Trying to return a previously freed instance."。
func after_test() -> void:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


## AC-U5 —— 全手把路徑用:同一個 action，改抓 InputEventJoypadButton 那個綁定，
## 而不是 InputEventKey。
func _real_gamepad_pressed_event(action: StringName) -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var duplicated: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


## 記錄呼叫次數的 AffinityWritePort 間諜——AC-U7 用來斷言「取消不應該讓寫入埠
## 被呼叫過」。NullAffinityWritePort 做不到這件事（它吞掉呼叫、不留紀錄）。
class _SpyWritePort extends AffinityWritePort:
	var call_count: int = 0

	func append_record(
		_character_a: int, _character_b: int, _m: int, _source: StringName
	) -> AffinityWritePort.Rejection:
		call_count += 1
		return AffinityWritePort.Rejection.NONE


func _build_temporary_card(
	id: String, delta_atk: int, delta_def: int, duration_rounds: int
) -> Card:
	return Card.new_temporary_stat_modifier(id, delta_atk, delta_def, duration_rounds)


func _build_permanent_card(id: String, magnitude: int) -> Card:
	# affinity_character_a/b 故意填與真實棋盤單位不相符的值（99/98）——
	# test_confirm_panel_丙類_reflects_player_selected_pair_not_card_fields 要驗的
	# 正是「面板顯示的姓名不是從這兩個欄位讀出來的」。
	return Card.new_permanent_affinity_write(id, 99, 98, magnitude)


func _link(unit_a: int, unit_b: int) -> AffinityLink:
	var link: AffinityLink = AffinityLink.new()
	link.unit_a = unit_a
	link.unit_b = unit_b
	link.polarity = AffinityLink.Polarity.POSITIVE
	return link


## 換掉 instance._controller._card_play_session，改用 [param cards] 建構的決定性
## CardDeck（單張或少數幾張牌，非隨機洗牌抽樣的疑慮不存在——見本檔檔頭說明）。
func _install_session(
	instance: BattleScreen, cards: Array[Card], links: Array[AffinityLink],
	write_port: AffinityWritePort
) -> CardDeck:
	var deck: CardDeck = CardDeck.new(cards)
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	instance._controller._card_play_session = CardPlaySession.new(
		deck, instance._state, links, write_port
	)
	return deck


## 開手牌 -> 選牌（真實呼叫 battle_screen.gd 的 _confirm_selected_card()，這正是
## 本 story 新增 _card_confirm_card 賦值的地方）。假設 [param cards] 只有一張牌
## （hand_bar 游標預設在索引 0）。
func _open_hand_and_select_first_card(instance: BattleScreen) -> void:
	instance._input(_real_pressed_event(&"battle_open_hand"))
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"PRECONDITION: battle_open_hand 應該成功開啟 S1"
	).is_true()
	instance._input(_real_pressed_event(&"battle_confirm"))
	assert_bool(instance._card_selecting_target).append_failure_message(
		"PRECONDITION: 選牌成功後應進入 S2/S2p（_card_selecting_target）"
	).is_true()


## 驅動甲類卡片一路到 CONFIRMING（S3），面板應已開啟。見本檔檔頭「涵蓋範圍的
## 誠實揭露」——target 選取本身用直接呼叫 + 手動指派模擬，不走真實游標管線。
func _drive_temporary_modifier_to_confirming(
	instance: BattleScreen, target: Unit
) -> void:
	_open_hand_and_select_first_card(instance)
	var advanced: bool = instance._controller.select_target(target.id)
	assert_bool(advanced).append_failure_message(
		"PRECONDITION: select_target(%d) 應該成功（甲類合法目標=我方單位）" % target.id
	).is_true()
	instance._card_confirm_target_a = target.id
	instance._after_target_selection_advanced()
	assert_int(instance._controller._card_play_session.step()).append_failure_message(
		"PRECONDITION: 甲類只有一個目標，選定後應直接進入 CONFIRMING"
	).is_equal(CardPlaySession.Step.CONFIRMING)
	assert_bool(instance._card_confirming).append_failure_message(
		"PRECONDITION: _after_target_selection_advanced() 應該已開啟確認面板"
	).is_true()


## 同上，丙類版本——兩個目標都要手動指派 _card_confirm_target_a/_b。
func _drive_permanent_write_to_confirming(
	instance: BattleScreen, target_a: Unit, target_b: Unit
) -> void:
	_open_hand_and_select_first_card(instance)
	var advanced_a: bool = instance._controller.select_target(target_a.id)
	assert_bool(advanced_a).append_failure_message(
		"PRECONDITION: select_target(%d) 應該成功（丙類 S2p 合法首選）" % target_a.id
	).is_true()
	instance._card_confirm_target_a = target_a.id
	instance._after_target_selection_advanced()
	assert_int(instance._controller._card_play_session.step()).append_failure_message(
		"PRECONDITION: 丙類選完第一人應進入 S2q（SELECTING_TARGET_B）"
	).is_equal(CardPlaySession.Step.SELECTING_TARGET_B)

	var advanced_b: bool = instance._controller.select_second_target(target_b.id)
	assert_bool(advanced_b).append_failure_message(
		"PRECONDITION: select_second_target(%d) 應該成功（%d 的合法搭檔）"
		% [target_b.id, target_a.id]
	).is_true()
	instance._card_confirm_target_b = target_b.id
	instance._after_target_selection_advanced()
	assert_bool(instance._card_confirming).append_failure_message(
		"PRECONDITION: 兩人皆選定後應進入 CONFIRMING 並開啟確認面板"
	).is_true()


# ─── AC-U1（透過既有 preview_damage()，不自算）──────────────────────────────


func test_damage_preview_reflects_new_effective_atk_after_confirm() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var player_units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var enemy_units: Array[Unit] = instance._state.units_of(Unit.Faction.ENEMY)
	var attacker: Unit = player_units[0]
	var enemy: Unit = enemy_units[0]
	var card: Card = _build_temporary_card("test_atk3", 3, 0, 1)
	_install_session(instance, [card], [], NullAffinityWritePort.new())

	var damage_before: int = instance._state.preview_damage(attacker.id, enemy.id, 0)

	# Act
	_drive_temporary_modifier_to_confirming(instance, attacker)
	instance._input(_real_pressed_event(&"battle_confirm"))
	instance._process(0.0)

	# Assert —— 同一份 preview_damage()，confirm 前後各查一次，不自算傷害公式
	var damage_after: int = instance._state.preview_damage(attacker.id, enemy.id, 0)
	assert_int(damage_after).append_failure_message(
		"ATK +3 之後，preview_damage() 應該剛好增加 3（damage=max(0,atk-def+phi)，" +
		"phi 兩次皆為 0，def 未變），confirm 前 %d、confirm 後 %d"
		% [damage_before, damage_after]
	).is_equal(damage_before + 3)
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"confirm 成功後應回到 S0（CLOSED）"
	).is_false()


# ─── AC-U5（全手把路徑）────────────────────────────────────────────────────


func test_gamepad_only_path_completes_full_and_cancel_flows() -> void:
	# Arrange —— 確認流程：手把 battle_confirm（A）能從 S3 完成確認
	var confirm_instance: BattleScreen = _fresh_instance()
	var confirm_target: Unit = confirm_instance._state.units_of(Unit.Faction.PLAYER)[0]
	var confirm_card: Card = _build_temporary_card("test_gamepad_confirm", 1, 0, 1)
	_install_session(confirm_instance, [confirm_card], [], NullAffinityWritePort.new())
	_drive_temporary_modifier_to_confirming(confirm_instance, confirm_target)

	# Act — 純手把事件，不含任何 InputEventKey
	var gamepad_confirm: InputEventJoypadButton = _real_gamepad_pressed_event(&"battle_confirm")
	assert_object(gamepad_confirm).append_failure_message(
		"battle_confirm 應該有手把綁定（project.godot [input]）"
	).is_not_null()
	confirm_instance._input(gamepad_confirm)
	confirm_instance._process(0.0)

	# Assert
	assert_bool(confirm_instance._controller.is_card_play_in_progress()).append_failure_message(
		"純手把 battle_confirm 應該能從 S3 完成確認"
	).is_false()

	# Arrange —— 取消流程：手把 battle_cancel（B）能從 S3 退回上一步
	var cancel_instance: BattleScreen = _fresh_instance()
	var cancel_target: Unit = cancel_instance._state.units_of(Unit.Faction.PLAYER)[0]
	var cancel_card: Card = _build_temporary_card("test_gamepad_cancel", 1, 0, 1)
	_install_session(cancel_instance, [cancel_card], [], NullAffinityWritePort.new())
	_drive_temporary_modifier_to_confirming(cancel_instance, cancel_target)

	# Act
	var gamepad_cancel: InputEventJoypadButton = _real_gamepad_pressed_event(&"battle_cancel")
	assert_object(gamepad_cancel).append_failure_message(
		"battle_cancel 應該有手把綁定（project.godot [input]）"
	).is_not_null()
	cancel_instance._input(gamepad_cancel)

	# Assert
	assert_bool(cancel_instance._card_confirming).append_failure_message(
		"純手把 battle_cancel 應該能讓面板從 S3 退回上一步（_card_confirming 應變 false）"
	).is_false()
	assert_bool(cancel_instance._controller.is_card_play_in_progress()).append_failure_message(
		"取消只退一步，session 應仍是開啟狀態（回到目標選取，不是整個關閉）"
	).is_true()


# ─── AC-U7（確認前取消）────────────────────────────────────────────────────


func test_cancel_before_confirm_leaves_zero_new_records() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var player_units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var target_a: Unit = player_units[0]
	var target_b: Unit = player_units[1]
	var card: Card = _build_permanent_card("test_cancel_before_confirm", 2)
	var link: AffinityLink = _link(target_a.id, target_b.id)
	var spy: _SpyWritePort = _SpyWritePort.new()
	_install_session(instance, [card], [link], spy)
	_drive_permanent_write_to_confirming(instance, target_a, target_b)

	var atk_modifier_count_before: int = target_a.active_modifiers().size()

	# Act
	instance._input(_real_pressed_event(&"battle_cancel"))

	# Assert
	assert_int(spy.call_count).append_failure_message(
		"確認前取消不應該呼叫 AffinityWritePort.append_record() 任何一次"
	).is_equal(0)
	assert_int(target_a.active_modifiers().size()).append_failure_message(
		"丙類卡不產生任何甲類修正，取消前後都應該是 0"
	).is_equal(atk_modifier_count_before)
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"取消只退一步（S3 -> S2q），session 應仍是開啟狀態"
	).is_true()


# ─── AC-U11（同幀鍵盤+手把各一次，只提交一次）───────────────────────────────


func test_second_confirm_same_frame_applies_only_once() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var target: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var card: Card = _build_temporary_card("test_dedup", 2, 0, 1)
	_install_session(instance, [card], [], NullAffinityWritePort.new())
	_drive_temporary_modifier_to_confirming(instance, target)

	# Act —— 同一幀內鍵盤與手把各送一次確認：兩個事件都在下一次 _process() 之前
	# 送達，兩者都只會把 _card_confirm_pending_press 設成 true（本身是 idempotent
	# 的），_process() 只跑一次、只呼叫一次 confirm()。
	instance._input(_real_pressed_event(&"battle_confirm"))
	var gamepad_confirm: InputEventJoypadButton = _real_gamepad_pressed_event(&"battle_confirm")
	instance._input(gamepad_confirm)
	instance._process(0.0)

	# Assert —— 好感度記錄本測試用甲類卡驗證不了（沒有好感度記錄），改驗
	# CardModifier 只被附加一次：若去重失效，target 會被附加兩次相同的修正
	assert_int(target.active_modifiers().size()).append_failure_message(
		"同幀兩次確認應該只套用一次修正，實得 %d 筆" % target.active_modifiers().size()
	).is_equal(1)
	assert_bool(instance._controller.is_card_play_in_progress()).is_false()

	# 再跑一次 _process() 確認沒有殘留的 pending press 會造成第二次套用
	instance._process(0.0)
	assert_int(target.active_modifiers().size()).is_equal(1)


# ─── AC-U13（丙類配對回顯，不讀卡片欄位；換一對不殘留）──────────────────────


func test_confirm_panel_丙類_reflects_player_selected_pair_not_card_fields() -> void:
	# Arrange —— 卡片的 affinity_character_a/b 故意填 99/98（不存在的單位），
	# 真正的配對由本測試模擬玩家在棋盤上選定的 1 號、2 號
	var instance: BattleScreen = _fresh_instance()
	var player_units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var unit_1: Unit = player_units[0]
	var unit_2: Unit = player_units[1]
	var card: Card = _build_permanent_card("test_pair_reflect", 2)
	var link: AffinityLink = _link(unit_1.id, unit_2.id)
	_install_session(instance, [card], [link], NullAffinityWritePort.new())

	# Act
	_drive_permanent_write_to_confirming(instance, unit_1, unit_2)

	# Assert
	var target_text: String = instance._card_confirm_panel.diagnostic_target_text()
	assert_str(target_text).append_failure_message(
		"確認面板應顯示玩家實際選取的 %s / %s，實得「%s」"
		% [unit_1.code_name, unit_2.code_name, target_text]
	).contains(unit_1.code_name)
	assert_str(target_text).contains(unit_2.code_name)
	assert_int(instance._card_confirm_panel.diagnostic_category()).is_equal(
		CardConfirmPanel.Category.PERMANENT_WRITE
	)


func test_confirm_panel_丙類_pair_updates_after_reselecting_without_residue() -> void:
	# Arrange —— 兩組合法配對：1↔2、3↔4
	var instance: BattleScreen = _fresh_instance()
	var player_units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	assert_int(player_units.size()).append_failure_message(
		"PRECONDITION: 需要至少 4 個我方單位才能測兩組獨立配對，實得 %d"
		% player_units.size()
	).is_greater_equal(4)
	var unit_1: Unit = player_units[0]
	var unit_2: Unit = player_units[1]
	var unit_3: Unit = player_units[2]
	var unit_4: Unit = player_units[3]
	var card: Card = _build_permanent_card("test_pair_reselect", 2)
	var links: Array[AffinityLink] = [_link(unit_1.id, unit_2.id), _link(unit_3.id, unit_4.id)]
	_install_session(instance, [card], links, NullAffinityWritePort.new())

	_drive_permanent_write_to_confirming(instance, unit_1, unit_2)
	assert_str(instance._card_confirm_panel.diagnostic_target_text()).contains(unit_1.code_name)

	# Act —— 取消兩次，退回 S2p，改選另一對
	instance._input(_real_pressed_event(&"battle_cancel"))  # S3 -> S2q
	assert_int(instance._controller._card_play_session.step()).is_equal(
		CardPlaySession.Step.SELECTING_TARGET_B
	)
	instance._input(_real_pressed_event(&"battle_cancel"))  # S2q -> S2p
	assert_int(instance._controller._card_play_session.step()).is_equal(
		CardPlaySession.Step.SELECTING_TARGET
	)
	assert_int(instance._card_confirm_target_a).append_failure_message(
		"退回 S2p 後 _card_confirm_target_a 鏡像應清空，不殘留 unit_1"
	).is_equal(-1)

	var advanced_a: bool = instance._controller.select_target(unit_3.id)
	assert_bool(advanced_a).is_true()
	instance._card_confirm_target_a = unit_3.id
	instance._after_target_selection_advanced()
	var advanced_b: bool = instance._controller.select_second_target(unit_4.id)
	assert_bool(advanced_b).is_true()
	instance._card_confirm_target_b = unit_4.id
	instance._after_target_selection_advanced()

	# Assert —— 面板同步顯示丙(unit_3)/丁(unit_4)，不殘留前一對(unit_1/unit_2)
	var target_text: String = instance._card_confirm_panel.diagnostic_target_text()
	assert_str(target_text).append_failure_message(
		"改選另一對後應顯示 %s / %s，不殘留 %s / %s，實得「%s」"
		% [unit_3.code_name, unit_4.code_name, unit_1.code_name, unit_2.code_name, target_text]
	).contains(unit_3.code_name)
	assert_str(target_text).contains(unit_4.code_name)
	assert_str(target_text).append_failure_message(
		"不得殘留前一對的姓名，實得「%s」" % target_text
	).not_contains(unit_1.code_name)
	assert_str(target_text).not_contains(unit_2.code_name)


# ─── 甲類欄位（Δatk/Δdef 帶號含 0、逐條修正並列合併值）────────────────────────


func test_confirm_panel_甲類_shows_delta_atk_def_with_sign_and_zero_visible() -> void:
	# Arrange —— delta_def=0 是合法的「這張牌不動這個軸」，不是 sentinel，必須
	# 仍然顯示，不得省略或留白
	var instance: BattleScreen = _fresh_instance()
	var target: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var card: Card = _build_temporary_card("test_zero_visible", 3, 0, 1)
	_install_session(instance, [card], [], NullAffinityWritePort.new())

	# Act
	_drive_temporary_modifier_to_confirming(instance, target)

	# Assert
	var panel: CardConfirmPanel = instance._card_confirm_panel
	assert_int(panel.diagnostic_category()).is_equal(CardConfirmPanel.Category.TEMPORARY_MODIFIER)
	assert_str(panel.diagnostic_delta_atk_text()).append_failure_message(
		"ΔATK 應帶正號顯示 +3，實得「%s」" % panel.diagnostic_delta_atk_text()
	).contains("+3")
	assert_str(panel.diagnostic_delta_def_text()).append_failure_message(
		"ΔDEF=0 仍必須顯示（0 是合法值不是缺資料），實得「%s」" % panel.diagnostic_delta_def_text()
	).contains("+0")
	assert_str(panel.diagnostic_duration_text()).contains("1")
	assert_str(panel.diagnostic_target_text()).contains(target.code_name)


func test_confirm_panel_甲類_shows_per_entry_modifiers_alongside_merged_effective_value() -> void:
	# Arrange —— 先給目標一筆既有修正，再打出第二張
	var instance: BattleScreen = _fresh_instance()
	var target: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var existing_modifier: CardModifier = CardModifier.new("existing_source", 1, 0, 2)
	target.add_modifier(existing_modifier)
	var card: Card = _build_temporary_card("test_merged", 3, 0, 1)
	_install_session(instance, [card], [], NullAffinityWritePort.new())

	var expected_hypothetical: Array[CardModifier] = target.active_modifiers()
	expected_hypothetical.append(CardModifier.new(card.id, card.delta_atk, card.delta_def, card.duration_rounds))
	var expected_atk: int = CardModifierRules.effective_atk(target.atk, expected_hypothetical)
	var expected_def: int = CardModifierRules.effective_def(target.def, expected_hypothetical)

	# Act
	_drive_temporary_modifier_to_confirming(instance, target)

	# Assert —— 逐條列表必須有那一筆既有修正，且合併值不得取代它（GDD UI
	# Requirements #7）：兩者同時存在，不是二選一
	var panel: CardConfirmPanel = instance._card_confirm_panel
	assert_int(panel.diagnostic_existing_modifier_count()).append_failure_message(
		"應該有恰好 1 筆生效中的既有修正"
	).is_equal(1)
	assert_str(panel.diagnostic_existing_modifier_line(0)).contains("existing_source")
	assert_str(panel.diagnostic_effective_text()).append_failure_message(
		"合併後有效值應反映 base+既有+本張的加總與夾限，預期 ATK_eff=%d DEF_eff=%d，實得「%s」"
		% [expected_atk, expected_def, panel.diagnostic_effective_text()]
	).contains(str(expected_atk))
	assert_str(panel.diagnostic_effective_text()).contains(str(expected_def))


# ─── AC-U14（好感度箭頭恰好一次；兩欄無箭頭版本必須轉紅）──────────────────────


func test_confirm_panel_arrow_layout_required_two_column_no_arrow_variant_must_fail() -> void:
	# Arrange / Act —— 正確版面：本檔唯一產生它的函式
	var correct_text: String = CardConfirmPanel.format_strength_arrow(3, 4)

	# 刻意實作「兩欄並排、無箭頭關聯」的版本——同樣兩個數字，但用 tab 分隔，
	# 完全不含 ARROW_GLYPH
	var violating_text: String = "%s\t%s" % [
		CardConfirmPanel.format_signed(3), CardConfirmPanel.format_signed(4)
	]

	# Assert
	assert_bool(CardConfirmPanel.text_uses_required_arrow_format(correct_text)).append_failure_message(
		"正確的箭頭格式「%s」應該通過判準" % correct_text
	).is_true()
	assert_bool(CardConfirmPanel.text_uses_required_arrow_format(violating_text)).append_failure_message(
		"「兩欄並排、無箭頭關聯」的版本「%s」必須讓判準轉紅——AC-U14 後半句要求的鑑別力"
	).is_false()


func test_confirm_panel_丙類_strength_field_shows_placeholder_not_zero_when_unavailable() -> void:
	# Arrange —— 2026-09-24 管理者裁決「維持留白＋提示」：
	# card_confirm_strength_provider 未設定是今天唯一存在的狀態
	var instance: BattleScreen = _fresh_instance()
	var player_units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var unit_a: Unit = player_units[0]
	var unit_b: Unit = player_units[1]
	var card: Card = _build_permanent_card("test_strength_placeholder", 2)
	var link: AffinityLink = _link(unit_a.id, unit_b.id)
	_install_session(instance, [card], [link], NullAffinityWritePort.new())
	assert_bool(instance.card_confirm_strength_provider.is_valid()).append_failure_message(
		"PRECONDITION: 本 story 不應該注入任何真正的好感度數值來源（2026-09-24 管理者裁決）"
	).is_false()

	# Act
	_drive_permanent_write_to_confirming(instance, unit_a, unit_b)

	# Assert —— 不得顯示 0、不得省略欄位，必須顯示佔位提示
	var strength_text: String = instance._card_confirm_panel.diagnostic_strength_text()
	assert_str(strength_text).append_failure_message(
		"UX-13 未關閉前，好感度數值欄位應顯示佔位提示，實得「%s」" % strength_text
	).is_equal(CardConfirmPanel.TEXT_STRENGTH_UNAVAILABLE)
	assert_bool(CardConfirmPanel.text_uses_required_arrow_format(strength_text)).append_failure_message(
		"佔位提示不應該被誤判成一組合法的箭頭格式"
	).is_false()
	assert_bool(instance._card_confirm_panel.diagnostic_permanent_warning_visible()).append_failure_message(
		"丙類確認面板的「永久」警示必須可見"
	).is_true()


# ─── 回歸測試：_card_confirm_card == null 時的兩個防禦點（獨立覆核抓到的缺陷）──
#
# 覆核者指出：_open_card_confirm_panel() 原本把 _card_confirming = true 設在
# null 檢查之前，導致對 null card 早退時 _card_confirming 殘留 true；而
# _handle_card_confirm_cancel_transition() 對 _card_confirm_card.category 完全
# 沒有 null 防護，與本 story 最初撞到的那個崩潰同一個形狀，只是換了呼叫點。
# 以下兩條測試各自直接對準一個防禦點，已用「暫時還原成 bug 版本 -> 重跑 -> 應
# 轉紅 -> 還原修正 -> 重跑 -> 應轉綠」的方式驗證過（原始輸出見任務報告，不寫在
# 這裡——本專案的既有慣例是敏感度證明的紅燈輸出留在報告，不留在版控裡的原始碼）。


func test_open_confirm_panel_with_null_card_does_not_leave_card_confirming_stuck_true() -> void:
	# Arrange —— 模擬「某呼叫端繞過 _confirm_selected_card() 自行推進 session」
	# 這個既有測試（card_target_selection_test.gd 的 mutant-session 敏感度證明）
	# 已經在撞的情境：_card_confirm_card 從未被設定，維持 null，但 session 本身
	# 已經真的推進到 CONFIRMING。
	var instance: BattleScreen = _fresh_instance()
	var target: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var card: Card = _build_temporary_card("test_null_card_ordering", 1, 0, 1)
	_install_session(instance, [card], [], NullAffinityWritePort.new())
	_open_hand_and_select_first_card(instance)
	var advanced: bool = instance._controller.select_target(target.id)
	assert_bool(advanced).append_failure_message(
		"PRECONDITION: select_target() 應該成功"
	).is_true()
	instance._card_confirm_card = null  # 模擬繞過 _confirm_selected_card() 的情境

	# Act
	instance._after_target_selection_advanced()

	# Assert —— 修正前：_card_confirming 在 null 檢查之前就被設 true，早退後殘留
	# true，這裡會量到 true 而轉紅；修正後：null 檢查通過前不設 true，早退時維持
	# false
	assert_bool(instance._card_confirming).append_failure_message(
		"_open_card_confirm_panel() 對 null card 早退時，_card_confirming 不應該" +
		"殘留 true——那會讓 _input() 把後續 battle_confirm/battle_cancel 誤導向" +
		"『S3 進行中』分支，卻沒有任何面板資料可用"
	).is_false()


func test_handle_card_confirm_cancel_transition_with_null_card_does_not_crash() -> void:
	# Arrange —— 直接重現覆核者描述的狀態組合：_card_confirming 已是 true，但
	# _card_confirm_card 是 null。這與上一條測試不同：上一條驗的是「不會走到這個
	# 狀態」，這一條驗的是「萬一走到了，這個函式本身不會崩潰」——雙重防線各自
	# 有測試。
	var instance: BattleScreen = _fresh_instance()
	instance._card_confirming = true
	instance._card_confirm_card = null

	# Act —— 修正前：_card_confirm_card.category 對 null 解參考，
	# SCRIPT ERROR「Invalid access to property or key 'category' on a base
	# object of type 'Nil'」，測試以錯誤中止；修正後：不崩潰，正常完成
	instance._handle_card_confirm_cancel_transition()

	# Assert
	assert_bool(instance._card_confirming).append_failure_message(
		"呼叫後 _card_confirming 應該變 false"
	).is_false()
	assert_bool(instance._card_selecting_target).append_failure_message(
		"防禦分支仍應完成完整的退回流程（回到目標選取），不是卡在半路"
	).is_true()
	assert_int(instance._card_confirm_target_a).append_failure_message(
		"category 未知時應防禦性清空兩個目標鏡像，不留殘值"
	).is_equal(-1)
	assert_int(instance._card_confirm_target_b).is_equal(-1)
