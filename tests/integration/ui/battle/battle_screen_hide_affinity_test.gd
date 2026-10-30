## story-009(game-shell)—— 隱藏好感度顯示:AC3 三項 + AC4 結算不變 + 設定畫面列(AC2)。
## 真實場景載入(BattleScreen.tscn / SettingsScreen.tscn),不組替身。
##
## 🔴 敏感度證明:常駐變種 _MutantIgnoresHide(把快取旗標強制改回 false 後重繪)+
##   test_sensitivity_proof_*,證明「三個偵測器」在顯示未被隱藏時真的會報。
##   證明不了:設定畫面列的在地化文字(真實資料檔,類別 A′)、AC4 的「結算數字不變」
##   本身是兩次獨立執行相比,沒有可注入的第三方。
## 🔴 未驗證:畫面實際外觀(只 headless);僅涵蓋戰鬥內已知三處顯示,
##   手牌好感度卡與預判模式選擇器本 story 刻意不動(見工作單)。
extends GdUnitTestSuite

const _BATTLE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _SETTINGS_PATH: String = "res://src/ui/shell/SettingsScreen.tscn"

var _host_snap: CursorHostSnapshot = null


## 缺陷:設定已開,但本場快取被改回 false(等於沒隱藏)。
class _MutantIgnoresHide extends BattleScreen:
	func _ready() -> void:
		super()
		_hide_affinity_display_for_this_battle = false
		_relation_toggle_button.visible = true
		_refresh_view()


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


func _battle(hide: bool, mutant: Script = null) -> BattleScreen:
	GameSettings.set_hide_affinity_display(hide)
	var instance: BattleScreen = auto_free(load(_BATTLE_PATH).instantiate())
	if mutant != null:
		instance.set_script(mutant)
	add_child(instance)
	return instance


func _key_r() -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(&"battle_toggle_relation_map"):
		if event is InputEventKey:
			var k: InputEventKey = (event as InputEventKey).duplicate()
			k.pressed = true
			return k
	return null


func _board_line_node_count(instance: BattleScreen) -> int:
	return instance._board_view._affinity_line_layer.get_child_count()


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## 與 battle_info_panel_attack_preview_test.gd 同一手法:我方第 0 位走進最近敵人射程並選定。
func _setup_attacker_in_range(instance: BattleScreen) -> Dictionary:
	var attacker: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var nearest: Unit = instance._state.units_of(Unit.Faction.ENEMY)[0]
	for enemy: Unit in instance._state.units_of(Unit.Faction.ENEMY):
		if _manhattan(instance._state.position_of(attacker.id), instance._state.position_of(enemy.id)) \
				< _manhattan(instance._state.position_of(attacker.id), instance._state.position_of(nearest.id)):
			nearest = enemy
	for _i in range(4):
		var current: Vector2i = instance._state.position_of(attacker.id)
		if _manhattan(current, instance._state.position_of(nearest.id)) <= 1:
			break
		var reachable: Array[Vector2i] = instance._state.legal_moves(attacker.id)
		if reachable.is_empty():
			break
		var best: Vector2i = reachable[0]
		for cell: Vector2i in reachable:
			if _manhattan(cell, instance._state.position_of(nearest.id)) \
					< _manhattan(best, instance._state.position_of(nearest.id)):
				best = cell
		instance._state.move_unit(attacker.id, best)
	assert_bool(instance._controller.select_unit(attacker.id)).append_failure_message("PRECONDITION: select_unit").is_true()
	assert_array(instance._controller.attack_targets().cells).append_failure_message(
		"PRECONDITION: 目標格應在 attack_targets() 內"
	).contains([instance._state.position_of(nearest.id)])
	return {"attacker": attacker, "enemy": nearest}


func _hover(instance: BattleScreen, cell: Vector2i) -> void:
	instance._cursor_cell = cell
	instance._cursor_active = true
	instance._tile_info_cursor_valid = true
	instance._update_tile_info_panel()


# ---- AC3① 棋盤連線 -------------------------------------------------------------

func test_board_lines_drawn_when_setting_off() -> void:
	var instance: BattleScreen = _battle(false)
	assert_int(_board_line_node_count(instance)).append_failure_message(
		"PRECONDITION/對照組:設定關閉時開局棋盤應畫有好感度連線(否則『隱藏』測不出差異)"
	).is_greater(0)


func test_board_lines_not_drawn_when_setting_on() -> void:
	var instance: BattleScreen = _battle(true)
	assert_bool(instance.is_hide_affinity_display_for_this_battle()).is_true()
	assert_int(_board_line_node_count(instance)).append_failure_message(
		"AC3①:隱藏好感度顯示開啟時,棋盤不得畫任何好感度連線"
	).is_equal(0)


# ---- AC3② 關係圖 ---------------------------------------------------------------

func test_minimap_toggle_button_hidden_and_key_inert_when_setting_on() -> void:
	var instance: BattleScreen = _battle(true)
	assert_bool(instance._relation_toggle_button.visible).append_failure_message(
		"AC3②:開啟時關係圖按鈕應隱藏"
	).is_false()
	instance._input(_key_r())
	assert_bool(instance.diagnostic_relation_minimap_visible()).append_failure_message(
		"AC3②:開啟時按 R 不得打開關係圖"
	).is_false()
	instance._toggle_relation_minimap()
	assert_bool(instance.diagnostic_relation_minimap_visible()).append_failure_message(
		"AC3②:開啟時按鈕路徑(_toggle_relation_minimap)也不得打開關係圖"
	).is_false()


func test_minimap_opens_and_button_visible_when_setting_off() -> void:
	var instance: BattleScreen = _battle(false)
	assert_bool(instance._relation_toggle_button.visible).is_true()
	instance._input(_key_r())
	assert_bool(instance.diagnostic_relation_minimap_visible()).append_failure_message(
		"對照組:設定關閉時 R 應能打開關係圖"
	).is_true()


# ---- AC3③ 傷害拆解 Φ 列;傷害總數與數值不變 ------------------------------------

func _breakdown_text(hide: bool, mutant: Script = null) -> Dictionary:
	var instance: BattleScreen = _battle(hide, mutant)
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var enemy: Unit = setup["enemy"]
	var attacker: Unit = setup["attacker"]
	var phi: int = instance._phi.phi(attacker.id, enemy.id)
	var bd: Dictionary = instance._state.preview_damage_breakdown(attacker.id, enemy.id, phi).breakdown
	_hover(instance, instance._state.position_of(enemy.id))
	return {"text": instance._tile_info_panel_label.text, "bd": bd, "phi": phi}


func test_breakdown_phi_row_present_when_setting_off() -> void:
	var r: Dictionary = _breakdown_text(false)
	assert_str(r["text"]).append_failure_message("對照組:關閉時應有 Φ 列").contains("Φ：")


func test_breakdown_phi_row_hidden_but_damage_unchanged_when_setting_on() -> void:
	var r: Dictionary = _breakdown_text(true)
	var text: String = r["text"]
	assert_str(text).append_failure_message("AC3③:開啟時拆解不得出現 Φ 列;實得:" + text).not_contains("Φ")
	assert_str(text).append_failure_message("AC3③:傷害總數照常顯示").contains("結果傷害：%d" % int(r["bd"]["damage"]))
	assert_str(text).contains("ATK：%d" % int(r["bd"]["atk"]))
	assert_str(text).contains("DEF：%d" % int(r["bd"]["def"]))


func test_breakdown_damage_value_identical_on_and_off() -> void:
	var off: Dictionary = _breakdown_text(false)
	var on: Dictionary = _breakdown_text(true)
	assert_int(int(on["bd"]["damage"])).append_failure_message(
		"AC3③/AC4:好感度仍在算,傷害數值開/關必須相同"
	).is_equal(int(off["bd"]["damage"]))
	assert_int(int(on["phi"])).is_equal(int(off["phi"]))


# ---- AC4 戰鬥結算不變 ----------------------------------------------------------

func _attack_hp_loss(hide: bool) -> int:
	var instance: BattleScreen = _battle(hide)
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var enemy: Unit = setup["enemy"]
	var cell: Vector2i = instance._state.position_of(enemy.id)
	_hover(instance, cell)
	var hp_before: int = enemy.hp
	instance._handle_click_tile_result(instance._controller.click_tile(cell))
	return hp_before - enemy.hp


func test_settlement_hp_loss_identical_on_and_off() -> void:
	var loss_off: int = _attack_hp_loss(false)
	assert_int(loss_off).append_failure_message("PRECONDITION: 攻擊應真的結算並扣血").is_greater(0)
	var loss_on: int = _attack_hp_loss(true)
	assert_int(loss_on).append_failure_message(
		"AC4:開啟隱藏好感度顯示時,同一組動作的扣血必須與關閉時相同(關 %d / 開 %d)" % [loss_off, loss_on]
	).is_equal(loss_off)


# ---- 敏感度證明(AC5)----------------------------------------------------------

func test_sensitivity_proof_board_lines_detector_catches_unhidden() -> void:
	var instance: BattleScreen = _battle(true, _MutantIgnoresHide)
	assert_int(_board_line_node_count(instance)).append_failure_message(
		"敏感度證明:變種把隱藏取消後,『棋盤無連線』偵測器必須看得到連線"
	).is_greater(0)


func test_sensitivity_proof_minimap_detector_catches_unhidden() -> void:
	var instance: BattleScreen = _battle(true, _MutantIgnoresHide)
	assert_bool(instance._relation_toggle_button.visible).is_true()
	instance._input(_key_r())
	assert_bool(instance.diagnostic_relation_minimap_visible()).is_true()


func test_sensitivity_proof_phi_row_detector_catches_unhidden() -> void:
	var instance: BattleScreen = _battle(true, _MutantIgnoresHide)
	var setup: Dictionary = _setup_attacker_in_range(instance)
	var enemy: Unit = setup["enemy"]
	_hover(instance, instance._state.position_of(enemy.id))
	assert_str(instance._tile_info_panel_label.text).contains("Φ：")


# ---- AC2 設定畫面列 ------------------------------------------------------------

func _settings() -> SettingsScreen:
	var s: SettingsScreen = auto_free(load(_SETTINGS_PATH).instantiate())
	add_child(s)
	return s


func test_settings_row_reflects_default_off() -> void:
	var s: SettingsScreen = _settings()
	var row: CheckButton = s.get_node("Panel/ContentMargin/Rows/HideAffinityRow")
	assert_bool(row.button_pressed).is_false()
	assert_str(row.text).is_equal("隱藏好感度顯示")


func test_settings_row_toggle_writes_game_settings() -> void:
	var s: SettingsScreen = _settings()
	var row: CheckButton = s.get_node("Panel/ContentMargin/Rows/HideAffinityRow")
	row.button_pressed = true
	assert_bool(GameSettings.is_hide_affinity_display()).is_true()
	row.button_pressed = false
	assert_bool(GameSettings.is_hide_affinity_display()).is_false()


func test_settings_row_syncs_from_game_settings_on_open() -> void:
	GameSettings.set_hide_affinity_display(true)
	var s: SettingsScreen = _settings()
	var row: CheckButton = s.get_node("Panel/ContentMargin/Rows/HideAffinityRow")
	assert_bool(row.button_pressed).is_true()


func test_settings_focus_chain_reaches_new_row_and_is_bounded() -> void:
	var s: SettingsScreen = _settings()
	var egm: CheckButton = s.get_node("Panel/ContentMargin/Rows/EgmToggleRow")
	var hide_row: CheckButton = s.get_node("Panel/ContentMargin/Rows/HideAffinityRow")
	var back: Button = s.get_node("Panel/ContentMargin/Rows/BackRow")
	assert_bool(hide_row.focus_mode == Control.FOCUS_ALL).is_true()
	assert_object(egm.get_node(egm.focus_neighbor_bottom)).is_same(hide_row)
	assert_object(hide_row.get_node(hide_row.focus_neighbor_top)).is_same(egm)
	assert_object(hide_row.get_node(hide_row.focus_neighbor_bottom)).is_same(back)
	assert_object(back.get_node(back.focus_neighbor_top)).is_same(hide_row)
	assert_object(back.get_node(back.focus_neighbor_bottom)).is_same(back)
