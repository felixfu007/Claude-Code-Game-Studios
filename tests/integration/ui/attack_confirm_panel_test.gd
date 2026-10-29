# Story 013（`production/epics/tactical-combat/story-013-attack-confirm-panel.md`）
# —— 攻擊確認面板（二段確認）。
#
# 🔴 2026-10-29 管理者裁決(story-023)取代 story-013 的二段確認:攻擊直接結算,不再開面板;
# 本檔原二段確認測試已改寫為直接攻擊測試(見「2026-10-29 管理者裁決」節),面板元件自身測試保留。
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


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


## 同 card_confirm_panel_test.gd 的既有 after_test() 慣例逐字——本檔多數測試
## 都會讓 BOARD_TILE 走過 register（_ready() 本身就會註冊一次），不清理會讓
## 下一個測試檔撞到 "Trying to return a previously freed instance."。
func after_test() -> void:
	# Full shared-Autoload restore (target/authority/flags/buffer/registry); see
	# tests/helpers/cursor_host_snapshot.gd. Kept the pre-existing cleanup below.
	_host_snap.restore()
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


# ─── 2026-10-29 管理者裁決取代 story-013 的二段確認(story-023)──────────────────
# 攻擊不再跳確認框:鍵盤/手把/滑鼠一律立即結算,且走同一條路徑
# _handle_click_tile_result(_click_tile_with_egm(cell))。
# 取代的舊測試(原 story-013):test_attack_confirm_open_is_zero_write_and_matches_breakdown、
# test_second_confirm_applies_attack_and_matches_preview、test_cancel_returns_to_t2_zero_write、
# test_panel_open_rejects_hand_menu_and_mouse、
# test_second_confirm_same_frame_keyboard_and_gamepad_applies_once。


## 敏感度證明用變種(2026-10-29):把「直接結算」改回「開確認框」。
class _MutantKeyboardOpensPanel extends BattleScreen:
	func _confirm_at_cursor() -> void:
		if _cursor_attack_target_id() != -1:
			_attack_confirm_panel.show_attack_confirmation("a", "b", 1, 1, 0, 0, 1, 2, 1)
			return
		super()


class _MutantMouseOpensPanel extends BattleScreen:
	func _handle_mouse_button(event: InputEventMouseButton) -> void:
		var cell: Vector2i = _window_pos_to_cell(event.position)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
				and BoardCoords.is_in_bounds(cell) and _controller.attack_targets().cells.has(cell):
			_attack_confirm_panel.show_attack_confirmation("a", "b", 1, 1, 0, 0, 1, 2, 1)
			return
		super(event)


func _fresh_instance_with_script(script: Script) -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	if script != null:
		instance.set_script(script)  # 進樹前換腳本(Case A)
	add_child(instance)
	return instance


func _click_event_on_cell(instance: BattleScreen, cell: Vector2i) -> InputEventMouseButton:
	var transform: Transform2D = WorldLayout.canvas_to_window_transform(instance.get_window().size)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = BoardCoords.grid_to_window(cell, transform, Vector2.ZERO)
	return event


## 觀察一次攻擊動作:回傳 {version_delta, panel_visible, hp_delta, expected_damage}。
## [param how] = "keyboard" / "gamepad" / "mouse"。
func _observe_attack(instance: BattleScreen, how: String) -> Dictionary:
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var attacker: Unit = setup["attacker"]
	var enemy: Unit = setup["enemy"]
	var enemy_cell: Vector2i = instance._state.position_of(enemy.id)
	var phi: int = instance._phi.phi(attacker.id, enemy.id)
	var expected_damage: int = instance._state.preview_damage_breakdown(
		attacker.id, enemy.id, phi
	).breakdown["damage"]
	var hp_before: int = enemy.hp
	var version_before: int = instance._state.combat_state_version
	if how == "mouse":
		var click: InputEventMouseButton = _click_event_on_cell(instance, enemy_cell)
		assert_vector(Vector2(instance._window_pos_to_cell(click.position))).append_failure_message(
			"PRECONDITION: 滑鼠座標應換算回敵方格"
		).is_equal(Vector2(enemy_cell))
		instance._handle_mouse_button(click)
	else:
		instance._cursor_cell = enemy_cell
		instance._cursor_active = true
		if how == "gamepad":
			instance._input(_real_gamepad_pressed_event(&"battle_confirm"))
		else:
			instance._input(_real_pressed_event(&"battle_confirm"))
	instance._process(0.0)
	return {
		"version_delta": instance._state.combat_state_version - version_before,
		"panel_visible": instance._attack_confirm_panel.visible,
		"hp_delta": hp_before - enemy.hp,
		"expected_damage": mini(expected_damage, hp_before),
	}


func _assert_direct_attack(result: Dictionary, label: String) -> void:
	assert_bool(result["panel_visible"]).append_failure_message("%s:不得開啟 AttackConfirmPanel" % label).is_false()
	assert_int(result["version_delta"]).append_failure_message(
		"%s:一次確認應恰好結算一次攻擊(combat_state_version +1),實得 +%d" % [label, result["version_delta"]]
	).is_equal(1)
	assert_int(result["hp_delta"]).append_failure_message("%s:扣血應等於預覽傷害" % label).is_equal(result["expected_damage"])


# AC1 + AC4
func test_keyboard_confirm_on_attack_target_attacks_immediately() -> void:
	_assert_direct_attack(_observe_attack(_fresh_instance(), "keyboard"), "鍵盤")


# AC3
func test_gamepad_confirm_on_attack_target_attacks_immediately() -> void:
	_assert_direct_attack(_observe_attack(_fresh_instance(), "gamepad"), "手把")


# AC2 + AC4
func test_mouse_click_on_attack_target_attacks_immediately() -> void:
	_assert_direct_attack(_observe_attack(_fresh_instance(), "mouse"), "滑鼠")


# AC2:鍵盤與滑鼠結果一致(同一條結算路徑)
func test_keyboard_and_mouse_attack_produce_same_outcome() -> void:
	var k: Dictionary = _observe_attack(_fresh_instance(), "keyboard")
	var m: Dictionary = _observe_attack(_fresh_instance(), "mouse")
	assert_int(m["hp_delta"]).is_equal(k["hp_delta"])
	assert_int(m["version_delta"]).is_equal(k["version_delta"])


# 敏感度證明 AC1:變種把鍵盤攻擊改回開面板 → 偵測用斷言條件確實成立(面板可見、版本不動)
func test_sensitivity_proof_keyboard_panel_regression_is_detected() -> void:
	var result: Dictionary = _observe_attack(_fresh_instance_with_script(_MutantKeyboardOpensPanel), "keyboard")
	assert_bool(result["panel_visible"]).append_failure_message("變種應被偵測到:面板可見").is_true()
	assert_int(result["version_delta"]).append_failure_message("變種應被偵測到:未結算").is_equal(0)


# 敏感度證明 AC2
func test_sensitivity_proof_mouse_panel_regression_is_detected() -> void:
	var result: Dictionary = _observe_attack(_fresh_instance_with_script(_MutantMouseOpensPanel), "mouse")
	assert_bool(result["panel_visible"]).append_failure_message("變種應被偵測到:面板可見").is_true()
	assert_int(result["version_delta"]).append_failure_message("變種應被偵測到:未結算").is_equal(0)


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
