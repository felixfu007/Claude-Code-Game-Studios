# Story U-013（選作用對象 S2/S2p/S2q + 合法目標高亮 + 跳轉鍵）的測試 ——
# production/epics/card-play-interface/story-u013-target-selection-and-highlight.md。
#
# 🔴 本檔目前只涵蓋 AC-U3 的兩個純靜態函式（BattleScreen.sort_targets_by_position()
# / BattleScreen.next_target_id()）。故事文件列的其餘測試——
#   - test_illegal_tile_reachable_by_directional_navigation_but_confirm_rejected
#   - test_reading_cursor_arbitrated_target_happens_in_process_not_input
#   - test_cancel_from_s2q_returns_to_s2p_not_s1
# ——尚未寫入：S2/S2p/S2q 的目標游標移動、跳轉鍵最終接線、與
# _process(priority=100) 的讀取管道，全部卡在一個未決的架構問題——
# BattleScreen 要不要（透過 src/ui/cursor/cursor_state_host.gd 新增的轉發方法）
# 真正掛上 CursorStateHost，這件事已交給 godot-specialist 裁決,不由本批自行決定。
# 見任務報告。
#
# 本檔另涵蓋 board_view.gd 的 set_card_target_highlights()（三態高亮圖層，同一張
# story 的計畫第 6 項）：合法=外框、不合法=外框+X，形狀可區分（P-F3 無例外），
# 沿用 hand_bar.gd 鎖圖示/類別圖示的既有作法（組合圖元，不新增 PNG 資產）。
#
# ⚠️ headless 不 rasterize 繪製結果——以下測試只能驗「畫了幾個節點、什麼型別、
# 疊在哪一層」這種結構性事實，驗不了「外框看起來像外框、X 看起來像 X」這種視覺
# 判讀。後者需要真實開視窗擷圖 + 人眼看過，尚未進行——見任務報告的登記。
#
# 命名慣例依 tests/unit/ui/battle_screen_cursor_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite


const _BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"


func _fresh_board_view() -> BoardView:
	var instance: BoardView = auto_free(load(_BOARD_VIEW_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


# ─── CardTargetHighlightLayer —— 場景節點存在、疊層順序正確 ─────────────────────


func test_card_target_highlight_layer_node_resolves_with_correct_type() -> void:
	# Arrange / Act
	var instance: BoardView = _fresh_board_view()
	var node: Node = instance.get_node("CardTargetHighlightLayer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Node2D).is_true()


func test_card_target_highlight_layer_draws_above_pieces_and_below_stats() -> void:
	# Arrange — 同 tests/unit/ui/battle_screen_scene_test.gd 既有的疊層順序驗法：
	# Node2D 的繪製順序就是子節點順序，get_index() 越大越晚畫（越上層）
	var instance: BoardView = _fresh_board_view()

	# Act
	var pieces_index: int = instance.get_node("PiecesLayer").get_index()
	var attack_index: int = instance.get_node("AttackHighlightLayer").get_index()
	var card_target_index: int = instance.get_node("CardTargetHighlightLayer").get_index()
	var stats_index: int = instance.get_node("StatsLayer").get_index()

	# Assert — 必須畫在棋子之上（否則佔位格的目標標記會被棋子擋住，同
	# AttackHighlightLayer 的既有理由），但畫在血條/血量文字之下（HP 讀數不得被蓋住）
	assert_int(card_target_index).append_failure_message(
		"CardTargetHighlightLayer 必須畫在 PiecesLayer 之上，否則站著單位的合法/"
		+ "不合法標記會被棋子完全遮住"
	).is_greater(pieces_index)
	assert_int(card_target_index).is_greater(attack_index)
	assert_int(card_target_index).append_failure_message(
		"CardTargetHighlightLayer 必須畫在 StatsLayer 之下，否則會蓋住血條/血量文字"
	).is_less(stats_index)


# ─── set_card_target_highlights() —— 合法/不合法/清空 ──────────────────────────


func test_set_card_target_highlights_draws_one_outline_root_per_legal_cell() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("CardTargetHighlightLayer")

	# Act — 2 個合法格、0 個不合法格
	instance.set_card_target_highlights([Vector2i(1, 1), Vector2i(3, 2)], [])

	# Assert — 合法格只有外框（1 個根節點／格），沒有任何 Line2D（X 記號）
	assert_int(layer.get_child_count()).append_failure_message(
		"2 個合法格應各畫 1 個外框根節點，共 2 個，實得 %d" % layer.get_child_count()
	).is_equal(2)
	var line_count: int = 0
	for child: Node in layer.get_children():
		line_count += _count_line2d_descendants(child)
	assert_int(line_count).append_failure_message(
		"合法格不應出現任何 Line2D（那是不合法格才有的 X 記號）"
	).is_equal(0)


func test_set_card_target_highlights_illegal_cells_get_outline_plus_x_mark() -> void:
	# Arrange
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("CardTargetHighlightLayer")

	# Act — 1 個不合法格
	instance.set_card_target_highlights([], [Vector2i(2, 2)])

	# Assert — 不合法格得到「外框根節點 + X 記號根節點」兩個子節點，且 X 記號那個
	# 根節點底下恰有 2 條 Line2D（兩條對角線）——形狀可區分於合法格，不靠顏色
	assert_int(layer.get_child_count()).append_failure_message(
		"1 個不合法格應畫「外框 + X 記號」兩個根節點，實得 %d" % layer.get_child_count()
	).is_equal(2)
	var line_count: int = 0
	for child: Node in layer.get_children():
		line_count += _count_line2d_descendants(child)
	assert_int(line_count).append_failure_message(
		"不合法格應有恰好 2 條 Line2D 組成 X 記號，實得 %d" % line_count
	).is_equal(2)


func test_set_card_target_highlights_with_two_empty_arrays_clears_the_layer() -> void:
	# Arrange — 先畫一些東西
	var instance: BoardView = _fresh_board_view()
	var layer: Node2D = instance.get_node("CardTargetHighlightLayer")
	instance.set_card_target_highlights([Vector2i(0, 0)], [Vector2i(1, 1)])
	assert_int(layer.get_child_count()).is_greater(0)

	# Act
	instance.set_card_target_highlights([], [])

	# Assert
	assert_int(layer.get_child_count()).is_equal(0)


func _count_line2d_descendants(node: Node) -> int:
	var count: int = 1 if node is Line2D else 0
	for child: Node in node.get_children():
		count += _count_line2d_descendants(child)
	return count


# ─── sort_targets_by_position() —— 先列後行（y 升冪、同列再 x 升冪）─────────────


func test_sort_targets_by_position_orders_row_major_regardless_of_input_order() -> void:
	# Arrange — 刻意打亂的輸入順序（既非 id 遞增、也非任何顯而易見的次序），
	# 座標本身分佈跨三列，同列內 x 不遞增
	var unit_ids: Array[int] = [50, 10, 30, 20, 40]
	var positions: Dictionary[int, Vector2i] = {
		50: Vector2i(5, 2),
		10: Vector2i(3, 0),
		30: Vector2i(1, 1),
		20: Vector2i(4, 1),
		40: Vector2i(0, 0),
	}

	# Act
	var result: Array[int] = BattleScreen.sort_targets_by_position(unit_ids, positions)

	# Assert — y=0 的 40 最先、y=1 的兩者依 x 遞增（30 於 x=1、20 於 x=4）、
	# y=2 的 50 最後
	assert_array(result).append_failure_message(
		"排序結果應為先列(y)後行(x)：%s" % [result]
	).is_equal([40, 10, 30, 20, 50])


func test_sort_targets_by_position_identical_across_repeated_runs_with_different_input_order() -> void:
	# Arrange — 同一組座標，兩次呼叫刻意給不同的輸入陣列順序，證明結果不受
	# 容器走訪序（本例即引數陣列本身的排列）影響 —— AC-U3「重跑一次順序完全相同」
	var positions: Dictionary[int, Vector2i] = {
		1: Vector2i(0, 2),
		2: Vector2i(0, 0),
		3: Vector2i(2, 0),
		4: Vector2i(1, 3),
		5: Vector2i(1, 1),
	}
	var order_a: Array[int] = [1, 2, 3, 4, 5]
	var order_b: Array[int] = [5, 4, 3, 2, 1]

	# Act
	var result_a: Array[int] = BattleScreen.sort_targets_by_position(order_a, positions)
	var result_b: Array[int] = BattleScreen.sort_targets_by_position(order_b, positions)

	# Assert
	assert_array(result_a).append_failure_message(
		"兩次呼叫（輸入順序不同）應得到完全相同的結果，實得 %s vs %s" % [result_a, result_b]
	).is_equal(result_b)
	# 手算覆核（座標為 Vector2i(x, y)）：id2(x=0,y=0)、id3(x=2,y=0) 同列(y=0)
	# 依 x 升冪為 [2,3]；id5(x=1,y=1) 次之；id1(x=0,y=2) 再次之；id4(x=1,y=3) 最後
	# —— 依序合併為 [2,3,5,1,4]。此行原寫 [2,1,5,4,3]（手算錯誤，已由本測試
	# 實際跑出的失敗抓到並更正——2026-09-22 實測 FAILED，見任務報告）。
	assert_array(result_a).is_equal([2, 3, 5, 1, 4])


func test_sort_targets_by_position_of_empty_array_is_empty() -> void:
	# Arrange / Act
	var result: Array[int] = BattleScreen.sort_targets_by_position([], {})

	# Assert
	assert_int(result.size()).is_equal(0)


# 2026-09-22 協調者指出:「若兩個目標的 (y, x) 完全相同,那就不是全序 —— 需要第三
# 個決定性鍵(例如 unit id)」。實測確認：本檔上面兩條測試用的資料其實沒有真正的
# (y, x) 撞值(上一條失敗是手算錯誤,不是排序鍵不足——見上一條測試內的更正註解),
# 但這條顧慮本身是對的、值得直接測:真實對局中兩個單位不可能同格(佔位不變量),
# 但排序函式收到的是呼叫端建構的 Dictionary,不該假設呼叫端一定守這條規則。
# sort_targets_by_position() 已加上 id 作為第三決定鍵，本測試直接命中那個分支。
func test_sort_targets_by_position_breaks_position_ties_by_ascending_id() -> void:
	# Arrange — id 30 與 id 10 座標完全相同(y=1, x=1),其餘鍵無法分出誰先誰後
	var unit_ids: Array[int] = [30, 10, 20]
	var positions: Dictionary[int, Vector2i] = {
		30: Vector2i(1, 1),
		10: Vector2i(1, 1),
		20: Vector2i(0, 0),
	}

	# Act
	var result: Array[int] = BattleScreen.sort_targets_by_position(unit_ids, positions)

	# Assert — 20 在 y=0 必然最先；10 與 30 座標相同,id 較小的 10 排在前面
	assert_array(result).append_failure_message(
		"座標相同的兩個目標應以 id 遞增排序，實得 %s" % [result]
	).is_equal([20, 10, 30])


# ─── next_target_id() —— 跳轉 + 循環包回 ───────────────────────────────────────


func test_jump_to_next_legal_target_cycles_in_row_major_order() -> void:
	# Arrange — AC-U3 逐字情境：我方 5 隻存活、連按「跳下一個合法目標」5 次
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act — 從「尚未選取」（-1）開始，連續跳 5 次
	var visited: Array[int] = []
	var current: int = -1
	for _i in range(5):
		current = BattleScreen.next_target_id(current, sorted_ids, true)
		visited.append(current)

	# Assert — 依序停在 5 隻上，順序與 sorted_ids 完全一致
	assert_array(visited).append_failure_message(
		"連按 5 次應依序走完整個合法目標集合，實得 %s" % [visited]
	).is_equal(sorted_ids)


func test_jump_cycle_wraps_from_last_to_first() -> void:
	# Arrange
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act — 第 6 次跳轉（已在最後一個，40/10/30/20/50 走完後再跳一次）
	var result: int = BattleScreen.next_target_id(50, sorted_ids, true)

	# Assert
	assert_int(result).append_failure_message(
		"第 6 次跳轉應回到第 1 個目標，實得 %d" % result
	).is_equal(40)


func test_jump_cycle_wraps_backward_from_first_to_last() -> void:
	# Arrange — Shift+Tab/LB（forward=false）從第一個往回跳，同一個循環的另一側
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var result: int = BattleScreen.next_target_id(40, sorted_ids, false)

	# Assert
	assert_int(result).is_equal(50)


func test_jump_order_identical_across_repeated_runs() -> void:
	# Arrange — AC-U3 後半：「重跑一次順序完全相同」。跑兩輪完整的 5 次跳轉，
	# 兩輪的輸入（sorted_ids）獨立建構（不是同一個物件參照），驗證輸出序列相等
	var sorted_ids_run_1: Array[int] = [40, 10, 30, 20, 50]
	var sorted_ids_run_2: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var visited_1: Array[int] = []
	var current_1: int = -1
	for _i in range(6):
		current_1 = BattleScreen.next_target_id(current_1, sorted_ids_run_1, true)
		visited_1.append(current_1)

	var visited_2: Array[int] = []
	var current_2: int = -1
	for _i in range(6):
		current_2 = BattleScreen.next_target_id(current_2, sorted_ids_run_2, true)
		visited_2.append(current_2)

	# Assert
	assert_array(visited_1).append_failure_message(
		"重跑一次應得到完全相同的走訪順序，實得 %s vs %s" % [visited_1, visited_2]
	).is_equal(visited_2)
	assert_array(visited_1).is_equal([40, 10, 30, 20, 50, 40])


func test_jump_with_current_id_not_in_set_starts_from_first_going_forward() -> void:
	# Arrange — 游標尚未落在任何合法目標上（例如剛選定卡片、還沒按過跳轉鍵）
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var result: int = BattleScreen.next_target_id(-1, sorted_ids, true)

	# Assert
	assert_int(result).is_equal(40)


func test_jump_with_current_id_not_in_set_starts_from_last_going_backward() -> void:
	# Arrange
	var sorted_ids: Array[int] = [40, 10, 30, 20, 50]

	# Act
	var result: int = BattleScreen.next_target_id(-1, sorted_ids, false)

	# Assert
	assert_int(result).is_equal(50)


func test_jump_on_empty_set_returns_negative_one() -> void:
	# Arrange / Act
	var result: int = BattleScreen.next_target_id(-1, [], true)

	# Assert
	assert_int(result).is_equal(-1)


# ─── 敏感度證明 ────────────────────────────────────────────────────────────────
#
# .claude/rules/test-standards.md「已知證明不了的五類」之 A 類：受測對象是
# static 純函式，沒有繼承鏈可覆寫子類別注入突變 —— 與
# tests/unit/ui/battle_screen_hand_bar_wiring_test.gd 對其餘 BattleScreen 純函式
# 的既有登記方式相同。上面每一條斷言的都是「給定輸入 -> 唯一可能的正確輸出」，
# 手動改壞 sort_targets_by_position()/next_target_id() 任何一步都會讓對應斷言
# 當場變紅（例如把 `pos_a.y < pos_b.y` 改成 `>` 會讓
# test_sort_targets_by_position_orders_row_major_regardless_of_input_order 與
# test_sort_targets_by_position_identical_across_repeated_runs_with_different_input_order
# 兩條同時變紅）——這是本檔對「哪一條測試會因為我改錯而變紅」的具體回答，
# 已手動核對（改壞、觀察斷言訊息、改回），不是宣稱。
