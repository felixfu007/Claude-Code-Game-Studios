# Story tactical-031 AC6 —— 右上資訊框傷害拆解的「減傷」列。
# 被測:BattleScreen._guard_line_text(bd, hide_affinity)(static 純函式)+ 一條真實場景整合檢查。
#
# 檔頭揭露:
# - 餵進去的 bd 是 in-test 構造的 Dictionary(鍵名取自 BattleState._attack_damage_breakdown 的
#   回傳),不是真實戰鬥算出來的;「真實 breakdown 的鍵與符號確實如此」由 gameplay 側測試負責。
# - 文字比對用 Loc.localize 取同一把 key(不寫死中文),故本檔證明「選對 key、帶對數字」,
#   不證明字面中文(字面值屬真實資料檔,類別 A′)。
# - 敏感度證明:被測物是 static 純函式,無繼承鏈可覆寫(test-standards 類 A),
#   不蓋常駐 mutant;改以手動注入並於交件回報貼紅燈原始行(版本庫不留痕,已知限制)。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host == null:
		return
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


static func _bd(guard_phi: int, lone: int, total: int) -> Dictionary:
	return {"guard_phi": guard_phi, "lone_guard": lone, "guard": total}


func test_guard_positive_shows_reduction_line_with_amount() -> void:
	var text: String = BattleScreen._guard_line_text(_bd(2, 0, 2), false)
	assert_str(text).is_equal(Loc.localize(&"battle.attack_confirm.guard_format") % 2)


func test_guard_negative_shows_extra_damage_line_with_absolute_amount() -> void:
	var text: String = BattleScreen._guard_line_text(_bd(-1, 0, -1), false)
	assert_str(text).is_equal(Loc.localize(&"battle.attack_confirm.guard_penalty_format") % 1)


func test_guard_zero_shows_no_line() -> void:
	assert_str(BattleScreen._guard_line_text(_bd(0, 0, 0), false)).is_equal("")
	# 好感度減傷與獨行加傷恰好抵銷:總 guard 為 0,不顯示。
	assert_str(BattleScreen._guard_line_text(_bd(1, -1, 0), false)).is_equal("")


func test_hide_affinity_hides_phi_part_keeps_lone_part() -> void:
	# guard_phi=2、lone=2、總 4:隱藏時只剩獨行的 2,不得顯示 4。
	var text: String = BattleScreen._guard_line_text(_bd(2, 2, 4), true)
	assert_str(text).is_equal(Loc.localize(&"battle.attack_confirm.guard_format") % 2)


func test_hide_affinity_with_only_phi_guard_shows_no_line() -> void:
	assert_str(BattleScreen._guard_line_text(_bd(2, 0, 2), true)).is_equal("")


func test_hide_affinity_lone_penalty_still_shown_as_extra_damage() -> void:
	var text: String = BattleScreen._guard_line_text(_bd(1, -1, 0), true)
	assert_str(text).is_equal(Loc.localize(&"battle.attack_confirm.guard_penalty_format") % 1)


# 真實場景:敵人為被攻擊方時 guard 恆為 0(只有我方被攻擊才有 guard),預覽文字不得出現減傷列。
func test_real_screen_enemy_target_preview_has_no_guard_line() -> void:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	var attacker: Unit = instance._state.units_of(Unit.Faction.PLAYER)[0]
	var enemy: Unit = instance._state.units_of(Unit.Faction.ENEMY)[0]
	var text: String = instance._build_attack_preview_text(attacker.id, enemy.id)
	assert_str(text).append_failure_message("PRECONDITION: 預覽文字應非空").is_not_empty()
	assert_str(text).not_contains(Loc.localize(&"battle.attack_confirm.guard_format").substr(0, 2))
	assert_str(text).not_contains(Loc.localize(&"battle.attack_confirm.guard_penalty_format").substr(0, 4))
