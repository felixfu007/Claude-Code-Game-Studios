# story-042 AC3 -- 資訊卡「擋視線」行與「攻擊：視線被擋」行並讀用同一個詞、不含「遮蔽」。
#
# 甲類檔案 I/O 揭露(.claude/rules/test-standards.md):載入真實 BattleScreen.tscn,
# 以 terrain_path_override / roster_path_override 注入合成夾具
# assets/data/levels/test_fixture_terrain_los.txt 與 assets/data/units/test_fixture_roster_los.txt
# (唯讀、已進版控;terrain 檔不可含註解——# 是倒木字元;兩份彼此相容:5 格走廊,(2,0) 倒木,我方 (0,0) 射程 1-4,敵方 (4,0))。
# 為何不能用純注入:要驗的是真實面板文字(Loc 取得的 CSV 值),不是 format 函式本身。
# 揭露:只證明「兩行用同一個詞」,不證明玩家讀得懂(像素層見 story-042 AC5)。
# 敏感度:static/資料字面值,無繼承鏈可覆寫;以手動 mutant(改回 CSV 舊字、對調分支)證明,見交付回報。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_PATH: String = "res://assets/data/levels/test_fixture_terrain_los.txt"
const _ROSTER_PATH: String = "res://assets/data/units/test_fixture_roster_los.txt"

var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	_host_snap.restore()


func _load() -> BattleScreen:
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.terrain_path_override = _TERRAIN_PATH
	instance.roster_path_override = _ROSTER_PATH
	auto_free(instance)
	add_child(instance)
	return instance


func test_los_wording_blocked_enemy_on_open_ground_shows_consistent_terms() -> void:
	# Arrange
	var screen: BattleScreen = _load()
	assert_bool(screen._controller.select_unit(1)).is_true()
	var enemy_cell: Vector2i = screen._state.position_of(2)
	assert_vector(enemy_cell).is_equal(Vector2i(4, 0))
	# 前提:夾具真的讓視線被擋(否則測試空轉)
	assert_int(screen._controller.attack_block_reason_for(2)).override_failure_message(
		"前提失敗:夾具沒有造成視線被擋").is_equal(CombatRules.AttackBlockReason.LOS_BLOCKED)

	# Act
	screen._cursor_active = true
	screen._cursor_cell = enemy_cell
	screen._tile_info_cursor_valid = true
	screen._update_tile_info_panel()
	var text: String = screen._tile_info_panel_label.text

	# Assert
	assert_bool(text.contains("擋視線：否")).override_failure_message(text).is_true()
	assert_bool(text.contains("攻擊：視線被擋")).override_failure_message(text).is_true()
	assert_bool(text.contains("遮蔽")).override_failure_message(text).is_false()
