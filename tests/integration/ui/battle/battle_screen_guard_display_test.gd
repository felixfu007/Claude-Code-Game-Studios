## story-032 —— 減傷顯示(指到我方角色 + 移動預覽)+ 隱藏好感度設定補漏。
## 真實場景載入(BattleScreen.tscn),不組替身。
##
## 檔頭揭露:
## - 數值對照一律用正式函式(CombatRules.guard / guard_total、AffinityRules.bonus_for[_at]、
##   BattleState.lone_guard_if_at)現場算出期望值,不寫死數字;故本檔證明「顯示的是正式計算的結果」,
##   不證明規則本身(規則由 gameplay 側測試負責)。
## - 文字比對用 Loc.localize 取同一把 key,不證明字面中文(真實資料檔,類別 A′)。
## - 預判模式(EGM)本 story 不動,本檔不測。
## - 🔴 敏感度證明:常駐變種 _MutantIgnoresHide(隱藏旗標被改回 false 後重繪)+
##   test_sensitivity_proof_*;與 battle_screen_hide_affinity_test.gd 同一手法。
extends GdUnitTestSuite

const _BATTLE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


class _MutantIgnoresHide extends BattleScreen:
	func _ready() -> void:
		super()
		_hide_affinity_display_for_this_battle = false
		_card_confirm_panel.hide_strength_row = false
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


func _hover(instance: BattleScreen, cell: Vector2i) -> void:
	instance._cursor_cell = cell
	instance._cursor_active = true
	instance._tile_info_cursor_valid = true
	instance._update_tile_info_panel()
	instance._refresh_view()


## 找一名我方單位並讓它有可觀的 Φ:回傳 id。測試內把它標成獨行(Unit.lone_guard 為公開欄位)。
func _player(instance: BattleScreen, idx: int) -> Unit:
	return instance._state.units_of(Unit.Faction.PLAYER)[idx]


func _expected_lone(instance: BattleScreen, u: Unit, tile: Vector2i) -> int:
	return instance._state.lone_guard_if_at(u.id, tile)


# ---- 純函式 ---------------------------------------------------------------------

func test_displayed_guard_hide_keeps_only_lone() -> void:
	assert_int(BattleScreen.displayed_guard(4, 2, true)).is_equal(CombatRules.guard_total(0, 2))
	assert_int(BattleScreen.displayed_guard(4, 2, false)).is_equal(CombatRules.guard_total(CombatRules.guard(4), 2))
	assert_int(BattleScreen.displayed_guard(4, -1, true)).is_equal(CombatRules.guard_total(0, -1))


func test_format_guard_value_and_move_texts() -> void:
	assert_str(BattleScreen.format_guard_value(0)).is_equal("")
	assert_str(BattleScreen.format_guard_value(2)).is_equal(Loc.localize(&"battle.attack_confirm.guard_format") % 2)
	assert_str(BattleScreen.format_guard_value(-1)).is_equal(Loc.localize(&"battle.attack_confirm.guard_penalty_format") % 1)
	assert_str(BattleScreen.format_guard_move(0, 0)).is_equal("")
	assert_str(BattleScreen.format_guard_move(0, 2)).is_equal(Loc.localize(&"battle.hud.guard_move_format") % [0, 2])
	assert_str(BattleScreen.compose_info_line("a", "")).is_equal("a")
	assert_str(BattleScreen.compose_info_line("", "b")).is_equal("b")
	assert_str(BattleScreen.compose_info_line("a", "b")).is_equal("a  b")


# ---- AC1 指到我方角色 -----------------------------------------------------------

func test_ac1_hover_own_unit_shows_guard_from_formal_functions() -> void:
	var instance: BattleScreen = _battle(false)
	var u: Unit = _player(instance, 0)
	u.lone_guard = true
	var cell: Vector2i = instance._state.position_of(u.id)
	var expected: int = BattleScreen.displayed_guard(
		instance._phi.phi_of(u.id), _expected_lone(instance, u, cell), false
	)
	assert_int(expected).append_failure_message("PRECONDITION: 夾具需產生非 0 減傷").is_not_equal(0)
	_hover(instance, cell)
	assert_str(instance._tile_info_panel_label.text).contains(BattleScreen.format_guard_value(expected))


# ---- AC2 移動預覽 ---------------------------------------------------------------

func test_ac2_move_preview_shows_guard_arrow_beside_affinity() -> void:
	var instance: BattleScreen = _battle(false)
	var u: Unit = _player(instance, 0)
	u.lone_guard = true
	assert_bool(instance._controller.select_unit(u.id)).is_true()
	var positions: Dictionary[int, Vector2i] = instance._phi.positions()
	var found: bool = false
	for cell: Vector2i in instance._state.legal_moves(u.id):
		var hypo: Dictionary[int, Vector2i] = instance._phi.positions_with(u.id, cell)
		var now: int = BattleScreen.displayed_guard(
			AffinityRules.bonus_for(u.id, positions, instance._phi.links()),
			instance._state.lone_guard_if_at(u.id, positions[u.id]), false)
		var after: int = BattleScreen.displayed_guard(
			AffinityRules.bonus_for_at(u.id, cell, hypo, instance._phi.links()),
			instance._state.lone_guard_if_at(u.id, cell), false)
		if now == after:
			continue
		_hover(instance, cell)
		assert_str(instance._info_label.text).contains(Loc.localize(&"battle.hud.guard_move_format") % [now, after])
		found = true
		break
	assert_bool(found).append_failure_message("PRECONDITION: 需有一格使減傷改變").is_true()


# ---- AC3 隱藏設定 ---------------------------------------------------------------

func test_ac3_hide_removes_affinity_text_and_card_row_keeps_lone() -> void:
	var instance: BattleScreen = _battle(true)
	var u: Unit = _player(instance, 0)
	u.lone_guard = true
	assert_bool(instance._controller.select_unit(u.id)).is_true()
	var aff_marker: String = Loc.localize(&"battle.hud.affinity_preview_format").substr(0, 3)
	var lone_shown: bool = false
	for cell: Vector2i in instance._state.legal_moves(u.id):
		_hover(instance, cell)
		assert_str(instance._info_label.text).not_contains(aff_marker)
		if instance._info_label.text != "":
			lone_shown = true
	assert_bool(lone_shown).append_failure_message("獨行減傷應照常顯示(至少一格)").is_true()
	# 卡牌面板「好感度:」列
	var panel: CardConfirmPanel = instance._card_confirm_panel
	panel.show_permanent_write_confirmation("c", "f", "a", "b", false, 0, 0)
	assert_bool(panel.diagnostic_strength_row_visible()).is_false()


func test_ac3_setting_off_card_row_visible() -> void:
	var instance: BattleScreen = _battle(false)
	var panel: CardConfirmPanel = instance._card_confirm_panel
	panel.show_permanent_write_confirmation("c", "f", "a", "b", false, 0, 0)
	assert_bool(panel.diagnostic_strength_row_visible()).is_true()


func test_ac3_hover_linked_unit_current_affinity_hidden_when_setting_on() -> void:
	var hidden: BattleScreen = _battle(true)
	var shown: BattleScreen = _battle(false)
	var found: bool = false
	for u: Unit in shown._state.units_of(Unit.Faction.PLAYER):
		if not shown._unit_has_link(u.id, shown._phi.links()):
			continue
		_hover(shown, shown._state.position_of(u.id))
		assert_str(shown._info_label.text).append_failure_message("PRECONDITION: 對照組應有好感度文字").is_not_empty()
		_hover(hidden, hidden._state.position_of(u.id))
		assert_str(hidden._info_label.text).is_equal("")
		found = true
		break
	assert_bool(found).is_true()


# ---- AC5 結算不變 ---------------------------------------------------------------

func test_ac5_hide_setting_does_not_change_damage_preview() -> void:
	var a: BattleScreen = _battle(false)
	var b: BattleScreen = _battle(true)
	var atk_a: Unit = _player(a, 0)
	var en_a: Unit = a._state.units_of(Unit.Faction.ENEMY)[0]
	var atk_b: Unit = _player(b, 0)
	var en_b: Unit = b._state.units_of(Unit.Faction.ENEMY)[0]
	var ra: DamageBreakdownResult = a._state.preview_damage_breakdown(atk_a.id, en_a.id, a._phi.phi(atk_a.id, en_a.id))
	var rb: DamageBreakdownResult = b._state.preview_damage_breakdown(atk_b.id, en_b.id, b._phi.phi(atk_b.id, en_b.id))
	assert_int(int(rb.breakdown["damage"])).is_equal(int(ra.breakdown["damage"]))


# ---- 雙值顯示(2026-10-30 管理者裁決「現在做雙值」)---------------------------------
# 以「will_attack=false / true 兩次呼叫結果是否不同」為準,不寫死單位 id。

func test_format_guard_move_dual_differs_and_same() -> void:
	assert_str(BattleScreen.format_guard_move_dual(0, 2, 0)).is_equal(
		Loc.localize(&"battle.hud.guard_move_dual_format") % [0, 2, 0])
	assert_str(BattleScreen.format_guard_move_dual(0, 2, 2)).is_equal(BattleScreen.format_guard_move(0, 2))
	assert_str(BattleScreen.format_guard_move_dual(0, 0, 0)).is_equal("")


## 找一格:獨行段在「出手/不出手」兩種情況下顯示減傷不同;回傳 [cell, no_attack, attack] 或空陣列。
func _find_dual_cell(instance: BattleScreen, u: Unit, want_differ: bool) -> Array:
	var positions: Dictionary[int, Vector2i] = instance._phi.positions()
	for cell: Vector2i in instance._state.legal_moves(u.id):
		var hypo: Dictionary[int, Vector2i] = instance._phi.positions_with(u.id, cell)
		var no_atk: int = instance._displayed_guard_at(u.id, cell, hypo, false)
		var atk: int = instance._displayed_guard_at(u.id, cell, hypo, true)
		if (no_atk != atk) == want_differ:
			return [cell, instance._displayed_guard_at(u.id, positions[u.id], positions), no_atk, atk]
	return []


func _dual_case(hide: bool, want_differ: bool, mutant: Script = null) -> Array:
	var instance: BattleScreen = _battle(hide, mutant)
	var u: Unit = _player(instance, 0)
	u.lone_guard = true
	assert_bool(instance._controller.select_unit(u.id)).is_true()
	var found: Array = _find_dual_cell(instance, u, want_differ)
	assert_bool(not found.is_empty()).append_failure_message("PRECONDITION: 需有符合條件的一格").is_true()
	_hover(instance, found[0])
	return [instance, found]


func test_move_preview_shows_dual_when_attack_changes_guard() -> void:
	for hide: bool in [false, true]:
		var r: Array = _dual_case(hide, true)
		var f: Array = r[1]
		assert_str(r[0]._info_label.text).contains(
			Loc.localize(&"battle.hud.guard_move_dual_format") % [f[1], f[2], f[3]])


func test_move_preview_shows_single_when_attack_does_not_change_guard() -> void:
	var r: Array = _dual_case(false, false)
	var f: Array = r[1]
	var text: String = r[0]._info_label.text
	assert_str(text).not_contains(Loc.localize(&"battle.hud.guard_move_dual_format").get_slice("%d", 2))
	if f[1] != f[2]:
		assert_str(text).contains(Loc.localize(&"battle.hud.guard_move_format") % [f[1], f[2]])


# ---- 敏感度證明 -----------------------------------------------------------------

## 變種:忽略 will_attack(永遠當作不出手)→ 雙值永遠退化為單值。
class _MutantIgnoresWillAttack extends BattleScreen:
	func _displayed_guard_at(
			unit_id: int, tile: Vector2i, hypo_positions: Dictionary[int, Vector2i], _will_attack: bool = false
	) -> int:
		return super(unit_id, tile, hypo_positions, false)


func test_sensitivity_proof_ignoring_will_attack_loses_dual() -> void:
	var instance: BattleScreen = _battle(false, _MutantIgnoresWillAttack)
	var u: Unit = _player(instance, 0)
	u.lone_guard = true
	assert_bool(instance._controller.select_unit(u.id)).is_true()
	# 以正式(未被變種覆寫的)規則找出「出手與否不同」的格,再讓變種畫面去顯示它。
	var cell: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in instance._state.legal_moves(u.id):
		if instance._state.lone_guard_if_at(u.id, c, false) != instance._state.lone_guard_if_at(u.id, c, true):
			cell = c
			break
	assert_bool(cell != Vector2i(-1, -1)).append_failure_message("PRECONDITION: 需有出手與否獨行段不同的格").is_true()
	_hover(instance, cell)
	assert_str(instance._info_label.text).append_failure_message(
		"變種忽略 will_attack → 不應出現雙值(偵測器抓到:正常版本此格必含「出手則」字樣)"
	).not_contains(Loc.localize(&"battle.hud.guard_move_dual_format").get_slice("%d", 2))


func test_sensitivity_proof_ignoring_hide_is_detected() -> void:
	var instance: BattleScreen = _battle(true, _MutantIgnoresHide)
	var panel: CardConfirmPanel = instance._card_confirm_panel
	panel.show_permanent_write_confirmation("c", "f", "a", "b", false, 0, 0)
	assert_bool(panel.diagnostic_strength_row_visible()).append_failure_message(
		"變種忽略隱藏 → 卡牌好感度列應可見(偵測器抓到)"
	).is_true()


# ---- story-033 銜接:戊出手後 AC1 的獨行段為 0 -------------------------------------

func test_ac1_lone_guard_part_is_zero_after_unit_attacked() -> void:
	var instance: BattleScreen = _battle(true)   # 隱藏好感度 → 只剩獨行段,隔離變因
	var u: Unit = _player(instance, 0)
	u.lone_guard = true
	# 移到一個獨行減傷為正的格(未出手值 > 0;出手後正值歸零,負值維持由規則決定)。
	var cell: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in instance._state.legal_moves(u.id):
		if instance._state.lone_guard_if_at(u.id, c, false) > 0:
			cell = c
			break
	assert_bool(cell != Vector2i(-1, -1)).append_failure_message("PRECONDITION: 需有一格獨行減傷 > 0").is_true()
	instance._state.move_unit(u.id, cell)
	var full: int = instance._state.lone_guard_if_at(u.id, cell, false)
	_hover(instance, cell)
	assert_str(instance._tile_info_panel_label.text).contains(BattleScreen.format_guard_value(full))
	# 出手旗標為真(經 BattleState 內部表,與 attacked_this_phase() 讀同一份):獨行段不顯示。
	instance._state._attacked_this_phase[u.id] = true
	assert_bool(instance._state.attacked_this_phase(u.id)).is_true()
	_hover(instance, cell)
	assert_str(instance._tile_info_panel_label.text).not_contains(BattleScreen.format_guard_value(full))
