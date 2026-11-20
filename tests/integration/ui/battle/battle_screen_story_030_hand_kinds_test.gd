extends GdUnitTestSuite

# Story 030 AC3:真實 BattleScreen.tscn 以 vs02 資料開場,手牌每張的 SlotKind 都與其
# Card.Category 的明確對應一致(未對應者會退成 TEMPORARY_MODIFIER 而在此露餡)。
# 檔案存取:唯讀 assets/data/ 版控資料檔(甲類例外;經真實場景載入)。
# 揭露:未直接攔截 push_error 輸出,改以「對應結果與期望表逐張相等」間接證明;
# 發牌為時間種子洗牌,故逐張比對手牌而非假設內容。

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


var _host_snap: CursorHostSnapshot


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	# 還原共用的 CursorStateHost Autoload 狀態(見 tests/helpers/cursor_host_snapshot.gd)。
	_host_snap.restore()


func _expected_kind(category: Card.Category) -> HandBar.SlotKind:
	match category:
		Card.Category.PERMANENT_AFFINITY_WRITE:
			return HandBar.SlotKind.PERMANENT_WRITE
		Card.Category.DIRECT_DAMAGE, Card.Category.COMBO_DAMAGE:
			return HandBar.SlotKind.DAMAGE
		Card.Category.HEAL:
			return HandBar.SlotKind.HEAL
		_:
			return HandBar.SlotKind.TEMPORARY_MODIFIER


func test_vs02_real_scene_hand_kinds_match_category_mapping() -> void:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.terrain_path_override = "res://assets/data/levels/vs02_terrain.txt"
	instance.roster_path_override = "res://assets/data/units/vs02_roster.txt"
	instance.affinity_path_override = "res://assets/data/affinity/vs02_affinity_links.txt"
	instance.cards_path_override = "res://assets/data/cards/vs02_cards.txt"
	instance.card_text_path_override = "res://assets/data/cards/vs02_card_text.txt"
	get_tree().root.call_deferred("add_child", instance)
	await get_tree().process_frame
	await get_tree().process_frame

	var hand: Array[Card] = instance._state.card_deck().hand()
	assert_int(hand.size()).append_failure_message("PRECONDITION: 手牌不得為空").is_greater(0)
	var kinds: Array = instance._hand_bar._slot_kinds
	assert_int(kinds.size()).is_equal(hand.size())
	for i: int in range(hand.size()):
		assert_int(kinds[i]).append_failure_message(
			"手牌第 %d 張 category=%d 的 SlotKind 與對應表不符" % [i, hand[i].category]
		).is_equal(_expected_kind(hand[i].category))
