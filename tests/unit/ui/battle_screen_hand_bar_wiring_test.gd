# battle_screen.gd 為 Story U-011（Z1 手牌縮圖帶）新增的三支映射函式的測試 ——
# 依 2026-09-17 協調者裁決一拆出獨立檔案(理由:既有 tests/unit/ui/battle_screen_*_test.gd
# 5 支皆按關注點切開;U-017 就是「一條測試放錯檔案」的補登記前例)。
#
# 涵蓋:
#   - hand_bar_slot_kind_for()：Card.Category -> HandBar.SlotKind 映射
#     （含 2026-09-17 協調者覆核發現的 catch-all 分支，見 battle_screen.gd
#     該函式的 doc comment)
#   - hand_bar_slot_kinds()：保序映射整手牌
#   - availability_for()：BattleController.Phase -> HandBar.Availability
#     映射，三個 phase 各一條（2026-09-17 協調者裁決二的記錄義務）
#   - HandBar 節點確實掛在 BattleScreen.tscn 的 UILayer 下（同
#     battle_screen_scene_test.gd 既有慣例，防「.tscn 漏節點」——本檔沒有
#     修改那份既有檔案，改在這裡補一條同等防護)
#
# 依 .claude/rules/test-standards.md 完成門檻：本檔全部測試對象皆為 static 純
# 函式，屬「已知證明不了的五類」之 A 類（無繼承鏈可覆寫），不做敏感度證明。
#
# 命名慣例依 tests/unit/ui/battle_screen_cursor_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


# ─── hand_bar_slot_kind_for() ───────────────────────────────────────────────


func test_hand_bar_slot_kind_for_maps_temporary_stat_modifier_to_temporary_modifier() -> void:
	var result: HandBar.SlotKind = BattleScreen.hand_bar_slot_kind_for(
		Card.Category.TEMPORARY_STAT_MODIFIER
	)
	assert_int(result).is_equal(HandBar.SlotKind.TEMPORARY_MODIFIER)


func test_hand_bar_slot_kind_for_maps_permanent_affinity_write_to_permanent_write() -> void:
	var result: HandBar.SlotKind = BattleScreen.hand_bar_slot_kind_for(
		Card.Category.PERMANENT_AFFINITY_WRITE
	)
	assert_int(result).is_equal(HandBar.SlotKind.PERMANENT_WRITE)


# 2026-09-17 協調者覆核發現的分支：Card.Category 目前只有兩個成員（本測試
# 直接傳一個不屬於任一成員的 int,GDScript 的 enum 型別參數只檢查底層是 int,
# 不檢查是否為已宣告成員,因此這是可構造的輸入,不是假想情境)。斷言的是
# 「優雅但不沉默」的退化結果 —— 仍回傳 TEMPORARY_MODIFIER(不崩潰、不擋畫面),
# push_error() 本身依本專案既有慣例（push_warning/push_error 文字不另立測試,
# 見 battle_screen.gd 既有的 _LOG_CARDS_ZERO_PARSED_FORMAT 等)不在此斷言範圍。
func test_hand_bar_slot_kind_for_falls_back_gracefully_for_an_unmapped_category() -> void:
	var unmapped: Card.Category = 99 as Card.Category
	var result: HandBar.SlotKind = BattleScreen.hand_bar_slot_kind_for(unmapped)
	assert_int(result).append_failure_message(
		"未知 Category 應優雅退化為 TEMPORARY_MODIFIER 的形狀,而不是崩潰或回傳無效值"
	).is_equal(HandBar.SlotKind.TEMPORARY_MODIFIER)


# ─── hand_bar_slot_kinds() ──────────────────────────────────────────────────


func test_hand_bar_slot_kinds_preserves_hand_order() -> void:
	var hand: Array[Card] = [
		Card.new_permanent_affinity_write("c1", 1, 2, 1),
		Card.new_temporary_stat_modifier("c2", 1, 0, 1),
		Card.new_temporary_stat_modifier("c3", 0, 1, 2),
	]
	var result: Array[HandBar.SlotKind] = BattleScreen.hand_bar_slot_kinds(hand)
	assert_int(result.size()).is_equal(3)
	assert_int(result[0]).is_equal(HandBar.SlotKind.PERMANENT_WRITE)
	assert_int(result[1]).is_equal(HandBar.SlotKind.TEMPORARY_MODIFIER)
	assert_int(result[2]).is_equal(HandBar.SlotKind.TEMPORARY_MODIFIER)


func test_hand_bar_slot_kinds_of_empty_hand_is_empty() -> void:
	var result: Array[HandBar.SlotKind] = BattleScreen.hand_bar_slot_kinds([])
	assert_int(result.size()).is_equal(0)


# ─── availability_for() —— 三個 phase 各一條(2026-09-17 協調者裁決二的記錄義務)──


func test_availability_for_maps_player_input_to_normal() -> void:
	var result: HandBar.Availability = BattleScreen.availability_for(
		BattleController.Phase.PLAYER_INPUT
	)
	assert_int(result).is_equal(HandBar.Availability.NORMAL)


func test_availability_for_maps_enemy_acting_to_locked() -> void:
	var result: HandBar.Availability = BattleScreen.availability_for(
		BattleController.Phase.ENEMY_ACTING
	)
	assert_int(result).is_equal(HandBar.Availability.LOCKED)


# 2026-09-17 協調者裁決二：FINISHED 併入 LOCKED,依據是規格 S5 列的「不可用——
# 現在不是你的回合/結算中」——「結算中」本來就在規格字面裡,不是本檔擴張。
func test_availability_for_maps_finished_to_locked() -> void:
	var result: HandBar.Availability = BattleScreen.availability_for(
		BattleController.Phase.FINISHED
	)
	assert_int(result).append_failure_message(
		"FINISHED 顯示成可用是明確錯的 —— 2026-09-17 協調者裁決二要求併入 LOCKED"
	).is_equal(HandBar.Availability.LOCKED)


# ─── 場景冒煙測試 —— 同 battle_screen_scene_test.gd 既有慣例，防「.tscn 漏節點」──
#
# 未修改 battle_screen_scene_test.gd 本體（不在協調者本批核准的寫入清單內），
# 在本檔補一條同等防護，涵蓋本 story 新增的 @onready var _hand_bar 這個節點路徑。


func test_hand_bar_node_resolves_under_ui_layer_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node("UILayer/HandBar")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is HandBar).is_true()
