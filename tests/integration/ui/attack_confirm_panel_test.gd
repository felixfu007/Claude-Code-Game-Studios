# Story 013（`production/epics/tactical-combat/story-013-attack-confirm-panel.md`）
# —— 攻擊確認面板（二段確認）。
#
# 🔴 涵蓋範圍的誠實揭露（不用「全部涵蓋」蓋過缺口，同 card_confirm_panel_test.gd
# 的既有慣例）：
#
# 本檔測的是「真實 _input()/_process() 分派路徑」下的攻擊二段確認——
# attack_confirm_panel.gd 本體、battle_screen.gd 新增的
# _open_attack_confirm_panel() / _apply_pending_attack_confirm() /
# _handle_attack_confirm_cancel_transition() / _confirm_at_cursor() 的拆分、
# 以及 _input() 的 _attack_confirming 分派。
#
# 🔴 「單位選取/游標落點」本檔不透過真實的方向鍵游標移動或滑鼠點擊選取驅動——
# 那是既有的、與本 story 無關的輸入路徑；本檔直接呼叫
# BattleController.select_unit()（真實呼叫，非重新實作）並直接寫入
# battle_screen.gd 自己的 _cursor_cell 欄位（與既有測試檔直接指派
# instance._card_confirm_target_a 等欄位的既有手法一致），把測試焦點放在
# 「按下確認鍵之後發生什麼事」上。
#
# 🔴 「單位如何進入彼此的攻擊範圍」——預設的 vs01 關卡在開局第一回合內任兩個
# 單位都不在彼此攻擊範圍內（雙方相距 10+ 格，MP 3~6），本檔用 _walk_unit_toward()
# 這個測試專用 helper，透過真實的 BattleState.legal_moves()/move_unit()（不是
# 重新實作移動規則）逐步把攻擊方移到最近的敵方單位的攻擊範圍內，再用
# BattleController.attack_targets() 這個公開查詢核對「真的進入範圍了」，不假設。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


## 同 card_confirm_panel_test.gd 的既有 after_test() 慣例逐字——本檔多數測試
## 都會讓 BOARD_TILE 走過 register（_ready() 本身就會註冊一次），不清理會讓
## 下一個測試檔撞到 "Trying to return a previously freed instance."。
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


func _real_gamepad_pressed_event(action: StringName) -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var duplicated: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 測試專用 helper——用真實的 BattleState.legal_moves()/move_unit()（絕不重新
## 實作移動規則）把 [param unit_id] 逐步移向 [param target_cell]，每步都從
## legal_moves() 回傳的真實可達集合中挑距離目標最近的一格。純粹是測試佈置
## （vs01 預設開局任兩單位開局都不在彼此攻擊範圍內），之後的攻擊合法性一律
## 由 BattleController.attack_targets()/BattleState.can_attack() 真實查詢核對，
## 本函式不代為斷言「已經進入範圍」。
func _walk_unit_toward(instance: BattleScreen, unit_id: int, target_cell: Vector2i, max_steps: int) -> void:
	for _i in range(max_steps):
		var current: Vector2i = instance._state.position_of(unit_id)
		if _manhattan(current, target_cell) <= 1:
			return
		var reachable: Array[Vector2i] = instance._state.legal_moves(unit_id)
		if reachable.is_empty():
			return
		var best: Vector2i = reachable[0]
		var best_dist: int = _manhattan(best, target_cell)
		for cell: Vector2i in reachable:
			var d: int = _manhattan(cell, target_cell)
			if d < best_dist:
				best = cell
				best_dist = d
		instance._state.move_unit(unit_id, best)


## 選攻擊方（固定用我方第 0 位)與離它最近的敵方單位，走到攻擊範圍內，並用
## 真實的 attack_targets() 公開查詢核對「真的進入範圍了」（PRECONDITION，而非
## 假設 _walk_unit_toward() 一定成功)。回傳 {"attacker": Unit, "enemy": Unit}。
func _setup_attacker_in_range(instance: BattleScreen) -> Dictionary:
	var player_units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var enemy_units: Array[Unit] = instance._state.units_of(Unit.Faction.ENEMY)
	var attacker: Unit = player_units[0]
	var nearest: Unit = enemy_units[0]
	var nearest_dist: int = _manhattan(
		instance._state.position_of(attacker.id), instance._state.position_of(nearest.id)
	)
	for enemy: Unit in enemy_units:
		var d: int = _manhattan(
			instance._state.position_of(attacker.id), instance._state.position_of(enemy.id)
		)
		if d < nearest_dist:
			nearest = enemy
			nearest_dist = d

	_walk_unit_toward(instance, attacker.id, instance._state.position_of(nearest.id), 4)

	assert_bool(instance._controller.select_unit(attacker.id)).append_failure_message(
		"PRECONDITION: select_unit(%d) 應該成功" % attacker.id
	).is_true()
	assert_array(instance._controller.attack_targets().cells).append_failure_message(
		"PRECONDITION: _walk_unit_toward() 應該已經讓 %s 進入 %s 的攻擊範圍，實得攻擊範圍清單 %s 不含目標格 %s"
		% [
			attacker.code_name, nearest.code_name, instance._controller.attack_targets().cells,
			instance._state.position_of(nearest.id),
		]
	).contains([instance._state.position_of(nearest.id)])

	return {"attacker": attacker, "enemy": nearest}


## 開到 T2'（攻擊確認面板開啟），游標落在敵方目標格上，面板確認鍵觸發
## _confirm_at_cursor() -> _open_attack_confirm_panel()。回傳 setup 字典。
func _open_attack_confirm(instance: BattleScreen) -> Dictionary:
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var enemy: Unit = setup["enemy"]
	instance._cursor_cell = instance._state.position_of(enemy.id)
	instance._cursor_active = true
	instance._input(_real_pressed_event(&"battle_confirm"))
	assert_bool(instance._attack_confirming).append_failure_message(
		"PRECONDITION: 按下確認鍵後應進入 T2'（攻擊確認面板開啟）"
	).is_true()
	return setup


# ─── 二段確認第一次：開面板零寫入，欄位與 preview_damage_breakdown() 一致 ─────


func test_attack_confirm_open_is_zero_write_and_matches_breakdown() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var attacker: Unit = setup["attacker"]
	var enemy: Unit = setup["enemy"]
	instance._cursor_cell = instance._state.position_of(enemy.id)
	instance._cursor_active = true
	var version_before: int = instance._state.combat_state_version
	var phi: int = instance._phi.phi(attacker.id, enemy.id)
	var expected: Dictionary = instance._state.preview_damage_breakdown(
		attacker.id, enemy.id, phi
	).breakdown

	# Act
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert — 零寫入
	assert_bool(instance._attack_confirming).is_true()
	assert_bool(instance._attack_confirm_panel.visible).append_failure_message(
		"面板應該已經可見"
	).is_true()
	assert_int(instance._state.combat_state_version).append_failure_message(
		"開啟攻擊確認面板必須零寫入，開啟前 %d、開啟後 %d"
		% [version_before, instance._state.combat_state_version]
	).is_equal(version_before)

	# Assert — 欄位與同一份 preview_damage_breakdown() 一致，不是另外算的
	var panel: AttackConfirmPanel = instance._attack_confirm_panel
	assert_str(panel.diagnostic_atk_text()).contains(str(expected["atk"]))
	assert_str(panel.diagnostic_def_text()).contains(str(expected["def"]))
	assert_str(panel.diagnostic_phi_text()).contains(AttackConfirmPanel.format_signed(int(expected["phi"])))
	assert_str(panel.diagnostic_damage_text()).contains(str(expected["damage"]))
	assert_str(panel.diagnostic_target_hp_text()).contains(str(expected["target_hp_after"]))


# ─── 二段確認第二次：真正觸發 click_tile()/_apply_attack()，與預覽一致 ────────


func test_second_confirm_applies_attack_and_matches_preview() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _open_attack_confirm(instance)
	var attacker: Unit = setup["attacker"]
	var enemy: Unit = setup["enemy"]
	var phi: int = instance._phi.phi(attacker.id, enemy.id)
	var expected_damage: int = instance._state.preview_damage_breakdown(
		attacker.id, enemy.id, phi
	).breakdown["damage"]
	var hp_before: int = enemy.hp
	var version_before: int = instance._state.combat_state_version

	# Act — 面板上再次確認
	instance._input(_real_pressed_event(&"battle_confirm"))
	instance._process(0.0)

	# Assert
	assert_bool(instance._attack_confirming).append_failure_message(
		"第二次確認後應離開 T2'"
	).is_false()
	assert_bool(instance._attack_confirm_panel.visible).is_false()
	assert_int(instance._state.combat_state_version).append_failure_message(
		"第二次確認應觸發權威寫入，combat_state_version 應該遞增，開啟前 %d、確認後 %d"
		% [version_before, instance._state.combat_state_version]
	).is_greater(version_before)
	assert_int(enemy.hp).append_failure_message(
		"結算後血量應與面板顯示的預覽傷害一致，預覽傷害 %d，血量 %d -> %d"
		% [expected_damage, hp_before, enemy.hp]
	).is_equal(maxi(0, hp_before - expected_damage))


# ─── 取消回上一步：零寫入，選取不受影響 ──────────────────────────────────────


func test_cancel_returns_to_t2_zero_write() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var setup: Dictionary = _open_attack_confirm(instance)
	var attacker: Unit = setup["attacker"]
	var enemy: Unit = setup["enemy"]
	var version_before: int = instance._state.combat_state_version
	var hp_before: int = enemy.hp

	# Act
	instance._input(_real_pressed_event(&"battle_cancel"))

	# Assert
	assert_bool(instance._attack_confirming).append_failure_message(
		"取消後應離開 T2'"
	).is_false()
	assert_bool(instance._attack_confirm_panel.visible).is_false()
	assert_int(instance._state.combat_state_version).append_failure_message(
		"取消必須零寫入，取消前 %d、取消後 %d" % [version_before, instance._state.combat_state_version]
	).is_equal(version_before)
	assert_int(enemy.hp).is_equal(hp_before)
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"取消只回到 T2（攻擊目標可視），攻擊方的選取不應被清除"
	).is_equal(attacker.id)


# ─── 面板開啟期間：開手牌/開選單/滑鼠點擊皆被拒絕 ─────────────────────────────


func test_panel_open_rejects_hand_menu_and_mouse() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	_open_attack_confirm(instance)

	# Act / Assert — 開手牌
	instance._input(_real_pressed_event(&"battle_open_hand"))
	assert_bool(instance._controller.is_card_play_in_progress()).append_failure_message(
		"T2' 期間按開手牌鍵不應該真的開啟手牌"
	).is_false()
	assert_bool(instance._attack_confirming).is_true()

	# Act / Assert — 開選單
	instance._input(_real_pressed_event(&"battle_menu"))
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"T2' 期間按開選單鍵不應該真的開啟選單"
	).is_false()
	assert_bool(instance._attack_confirming).is_true()

	# Act / Assert — 滑鼠點擊（任意位置）不應改變面板狀態或觸發攻擊
	var version_before: int = instance._state.combat_state_version
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10.0, 10.0)
	instance._input(click)
	assert_bool(instance._attack_confirming).append_failure_message(
		"T2' 期間滑鼠點擊不應該改變面板狀態"
	).is_true()
	assert_int(instance._state.combat_state_version).is_equal(version_before)


# ─── 同幀鍵盤+手把各一次確認，只提交一次 ─────────────────────────────────────


func test_second_confirm_same_frame_keyboard_and_gamepad_applies_once() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	_open_attack_confirm(instance)
	var version_before: int = instance._state.combat_state_version

	# Act —— 同一幀內鍵盤與手把各送一次確認
	instance._input(_real_pressed_event(&"battle_confirm"))
	var gamepad_confirm: InputEventJoypadButton = _real_gamepad_pressed_event(&"battle_confirm")
	assert_object(gamepad_confirm).append_failure_message(
		"battle_confirm 應該有手把綁定（project.godot [input]）"
	).is_not_null()
	instance._input(gamepad_confirm)
	instance._process(0.0)

	# Assert —— 只提交一次（版本只 +1）
	assert_int(instance._state.combat_state_version).append_failure_message(
		"同幀兩次確認應該只套用一次攻擊，實得版本 %d（預期 %d）"
		% [instance._state.combat_state_version, version_before + 1]
	).is_equal(version_before + 1)

	# 再跑一次 _process() 確認沒有殘留的 pending press 會造成第二次套用
	instance._process(0.0)
	assert_int(instance._state.combat_state_version).is_equal(version_before + 1)


# ─── Φ=0 仍顯示；夾限時面板能表達「原始值 != 結算值」(協調者補件要求) ─────────


func test_panel_shows_phi_zero_and_discloses_clamping() -> void:
	# Arrange / Act — Φ=0 時仍應顯示，不應隱藏或省略
	var instance: BattleScreen = _fresh_instance()
	var panel: AttackConfirmPanel = instance._attack_confirm_panel
	panel.show_attack_confirmation("甲", "E1", 10, 5, 0, 0, 5, 20, 15)

	# Assert
	assert_str(panel.diagnostic_phi_text()).append_failure_message(
		"Φ=0 仍必須顯示，實得「%s」" % panel.diagnostic_phi_text()
	).contains("+0")
	assert_bool(panel.diagnostic_phi_clamped_visible()).append_failure_message(
		"phi == phi_input 時不應顯示夾限提示"
	).is_false()

	# Act — phi(3) != phi_input(7)：好感度加成被夾限砍掉一部分
	panel.show_attack_confirmation("甲", "E1", 10, 5, 3, 7, 8, 20, 12)

	# Assert
	assert_bool(panel.diagnostic_phi_clamped_visible()).append_failure_message(
		"phi(3) != phi_input(7) 時應該顯示夾限提示，讓玩家看得出好感度加成被砍掉一部分"
	).is_true()
	assert_str(panel.diagnostic_phi_clamped_text()).contains("+7")
	assert_str(panel.diagnostic_phi_clamped_text()).contains("+3")


# ─── 零裸字串常數（QA Test Cases 明文要求，乙類例外：讀本 story 新增檔案原始碼
# 文字斷言靜態紀律，唯讀、不寫入，對象無法用注入取代）────────────────────────


func test_new_panel_file_has_zero_bare_string_constants() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/ui/battle/attack_confirm_panel.gd")
	var violations: Array[String] = []
	for line: String in content.split("\n"):
		var stripped: String = line.strip_edges()
		if stripped.begins_with("const ") and stripped.contains(": String ="):
			violations.append(stripped)
	assert_array(violations).append_failure_message(
		"attack_confirm_panel.gd 不應有裸字串常數（StringName key 除外），實得：%s" % str(violations)
	).is_empty()
