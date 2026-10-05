# Board（src/gameplay/board/board.gd）from_ascii() 載入時驗證（結構性 +
# 組成性檢查）與 reachable_tiles() AC6 獨立防護的單元測試。
#
# 對應 production/epics/tactical-combat/story-016-terrain-load-time-validation.md
# 的 Acceptance Criteria（AC1-AC7）與 QA Test Cases。
#
# ⚠️ 獨立成一個測試檔（與 board_test.gd/board_passable_test.gd/
# board_reachable_tiles_test.gd 分開）：同套件內任一測試失敗會中止其後全部
# 測試（.claude/docs/coding-standards.md），理由同 story-003b，見本 story
# 文件 Affected Files 節。
#
# ⚠️ 命名慣例：依既有範本沿用 test_[scenario]_[expected]（不含 [system] 前綴）。
extends GdUnitTestSuite


## 測試專用 Board 子類：覆寫 _is_move_cost_usable()（board.gd 為 Story 016
## AC6 新增的測試接縫，同構於既有 _terrain_entry()/_on_tile_visited() 接縫）
## 永遠回傳 true，精確重現「AC6 防護被移除」時 reachable_tiles() 的行為——
## 用於下方 test_sensitivity_proof_* 測試，而不是手動改壞 board.gd 本體一次
## （.claude/rules/test-standards.md 2026-09-16 條目：手動注入已淘汰，
## 常駐間諜/突變子類別才算數）。
class _BoardWithMoveCostGuardRemoved extends Board:
	func _is_move_cost_usable(_move_cost: int) -> bool:
		return true


## 測試專用 Board 子類：覆寫 passable() 永遠回傳 true，模擬「上游 passable()
## 閘門未來被改動/失效」的情境。用於驗證 AC6 原文要求的 defense-in-depth：
## get_move_cost() 呼叫端自身的防護，不得只依賴上游的 passable() 閘門——
## 即使上游閘門被繞過（本子類別），獨立防護仍須生效。
class _BoardWithPassableAlwaysTrue extends Board:
	func passable(_pos: Vector2i) -> bool:
		return true


# 建一份全開闊（13x6，全 '.'）的 ascii 版面，供多個測試共用起點。
func _build_open_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		rows.append(".............")
	return rows


# --- AC4：既有合法棋盤零誤報（迴歸防護） ------------------------------------

func test_from_ascii_legal_open_board_triggers_zero_push_errors() -> void:
	# Arrange — 13x6 全開闊合法版面
	var rows: PackedStringArray = _build_open_rows()

	# Act & Assert — is_success() 要求本次呼叫完全沒有任何錯誤/警告紀錄
	# （不只是沒有 push_error，是整個呼叫過程的錯誤紀錄為空）
	var call_from_ascii: Callable = func() -> void:
		var _discard: Board = Board.from_ascii(rows)
	await assert_error(call_from_ascii).is_success()


func test_from_ascii_legal_mixed_terrain_board_triggers_zero_push_errors() -> void:
	# Arrange — 與 board_test.gd 相同的平地/灌木/倒木混合版面，是既有 24 處
	# Board.from_ascii() 呼叫點的代表性樣本
	var rows: PackedStringArray = PackedStringArray([
		".............",
		".....,,......",
		"....,##,.....",
		"....,##,.....",
		".....,,......",
		".............",
	])

	# Act & Assert
	var call_from_ascii: Callable = func() -> void:
		var _discard: Board = Board.from_ascii(rows)
	await assert_error(call_from_ascii).is_success()


# --- AC1：結構性驗證 — 列數不符 ---------------------------------------------

func test_from_ascii_row_count_mismatch_triggers_structural_push_error() -> void:
	# Arrange — 只有 5 列（非 BOARD_HEIGHT=6）
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(5):
		rows.append(".............")
	var expected_message: String = (
		"Board.from_ascii: expected %d rows, got %d" % [Board.BOARD_HEIGHT, rows.size()]
	)

	# Act & Assert — 訊息與 board.gd 的格式字串逐字相符
	var call_from_ascii: Callable = func() -> void:
		var _discard: Board = Board.from_ascii(rows)
	await assert_error(call_from_ascii).is_push_error(expected_message)


func test_from_ascii_row_count_mismatch_still_returns_usable_board_with_existing_rows_stored() -> void:
	# Arrange — 同上，5 列的棋盤
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(5):
		rows.append(".............")

	# Act — 驗證不中止建構（AC5），既有列內容仍正確儲存（Out of Scope 條款：
	# 驗證是純附加訊號，不改變既有解析/儲存邏輯）
	var board: Board = Board.from_ascii(rows)

	# Assert
	assert_object(board).is_not_null()
	assert_str(board.get_terrain(Vector2i(0, 0))).is_equal(".")
	assert_int(board.get_move_cost(Vector2i(0, 4))).is_equal(1)


# --- AC1：結構性驗證 — 列長不符 ---------------------------------------------

func test_from_ascii_row_length_mismatch_triggers_structural_push_error_with_row_index() -> void:
	# Arrange — 第 0 列只有 10 字元（非 BOARD_WIDTH=13）
	var rows: PackedStringArray = _build_open_rows()
	rows[0] = ".........."
	var expected_message: String = (
		"Board.from_ascii: row %d has length %d, expected %d"
		% [0, rows[0].length(), Board.BOARD_WIDTH]
	)

	# Act & Assert
	var call_from_ascii: Callable = func() -> void:
		var _discard: Board = Board.from_ascii(rows)
	await assert_error(call_from_ascii).is_push_error(expected_message)


func test_from_ascii_row_length_mismatch_existing_characters_still_stored() -> void:
	# Arrange — 第 0 列只有 10 字元；該列已有字元仍應正確儲存（純附加診斷
	# 訊號，不改變解析/儲存邏輯——Out of Scope 條款）
	var rows: PackedStringArray = _build_open_rows()
	rows[0] = ".........."

	# Act
	var board: Board = Board.from_ascii(rows)

	# Assert — 該列前 10 格仍正確儲存為平地
	for x: int in range(10):
		assert_str(board.get_terrain(Vector2i(x, 0))).is_equal(".")


# --- AC2：組成性驗證 — 單一未登記字元 ---------------------------------------

func test_from_ascii_single_unregistered_terrain_character_triggers_compositional_push_error() -> void:
	# Arrange — 恰好一格使用未登記字元 'Z'
	var rows: PackedStringArray = _build_open_rows()
	var pos: Vector2i = Vector2i(3, 1)
	rows[1] = rows[1].left(pos.x) + "Z" + rows[1].substr(pos.x + 1)
	var expected_message: String = (
		"Board.from_ascii: unregistered terrain character '%s' at %s" % ["Z", pos]
	)

	# Act & Assert — 訊息含座標與字元（與 board.gd 的格式字串逐字相符）
	var call_from_ascii: Callable = func() -> void:
		var _discard: Board = Board.from_ascii(rows)
	await assert_error(call_from_ascii).is_push_error(expected_message)


# --- AC2：組成性驗證 — 多個未登記字元各自觸發、不因第一個就停止掃描 --------

func test_from_ascii_multiple_unregistered_terrain_characters_each_trigger_their_own_push_error() -> void:
	# Arrange — 兩個分散於不同列的未登記字元
	var rows: PackedStringArray = _build_open_rows()
	var pos_a: Vector2i = Vector2i(3, 1)
	var pos_b: Vector2i = Vector2i(7, 4)
	rows[1] = rows[1].left(pos_a.x) + "Z" + rows[1].substr(pos_a.x + 1)
	rows[4] = rows[4].left(pos_b.x) + "Y" + rows[4].substr(pos_b.x + 1)
	var expected_message_a: String = (
		"Board.from_ascii: unregistered terrain character '%s' at %s" % ["Z", pos_a]
	)
	var expected_message_b: String = (
		"Board.from_ascii: unregistered terrain character '%s' at %s" % ["Y", pos_b]
	)
	var call_from_ascii: Callable = func() -> void:
		var _discard: Board = Board.from_ascii(rows)

	# Act & Assert — 兩次獨立重跑同一個 callable，各自驗證各自座標的
	# push_error 均被觸發。若掃描在第一個未登記字元後就提前中止，第二個
	# 斷言會找不到相符的 push_error 紀錄而回報失敗——這正是本測試要抓的迴歸。
	await assert_error(call_from_ascii).is_push_error(expected_message_a)
	await assert_error(call_from_ascii).is_push_error(expected_message_b)


# --- AC3：驗證路徑不使用 assert() -------------------------------------------

func test_from_ascii_validation_failure_triggers_push_error_not_assert() -> void:
	# Arrange — 同時觸發結構性與組成性兩種失敗的版面
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(5):
		rows.append(".............")
	rows[0] = rows[0].left(2) + "Z" + rows[0].substr(3)

	# Act & Assert — 這條斷言本身就是要抓的迴歸：is_push_error() 只認
	# PUSH_ERROR 類型紀錄；若驗證改用 assert()，assert() 失敗產生的是
	# SCRIPT_ERROR 紀錄，is_push_error() 會找不到相符項目而回報失敗
	# （手法與 board_passable_test.gd 的
	# test_unregistered_terrain_character_triggers_push_error_not_assert 一致）
	var call_from_ascii: Callable = func() -> void:
		var _discard: Board = Board.from_ascii(rows)
	await assert_error(call_from_ascii).is_push_error(any_string())


# --- AC5：永遠回傳有效 Board 物件 -------------------------------------------

func test_from_ascii_with_both_structural_and_compositional_failures_still_returns_valid_board() -> void:
	# Arrange — 同時觸發兩種失敗
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(5):
		rows.append(".............")
	rows[0] = rows[0].left(2) + "Z" + rows[0].substr(3)

	# Act
	var board: Board = Board.from_ascii(rows)

	# Assert — AC5：永遠是有效物件，不為 null，既有查詢方法可正常呼叫
	assert_object(board).is_not_null()
	assert_bool(board.is_in_bounds(Vector2i(0, 0))).is_true()


# --- AC6：reachable_tiles() 不再被未登記地形腐蝕成本 -------------------------

func test_reachable_tiles_ignore_passability_true_excludes_unregistered_terrain_neighbor() -> void:
	# Arrange — origin (0,0)，鄰接格 (1,0) 為未登記地形字元 'Z'（直接寫入
	# _terrain，不經 from_ascii，避免該呼叫自身的載入時驗證 push_error 混進
	# 這條測試要觀察的訊號）。mp=0 是邊界值：若 (1,0) 的
	# MOVE_COST_UNKNOWN_TERRAIN(-1) 被誤併入成本加法，candidate_cost 會變成
	# -1（<= mp=0），該格會被誤判納入；正確防護下，mp=0 理應沒有任何格可達。
	var board: Board = Board.new()
	var origin: Vector2i = Vector2i(0, 0)
	var corrupted: Vector2i = Vector2i(1, 0)
	board._terrain[corrupted] = "Z"

	# Act
	var result: Array[Vector2i] = board.reachable_tiles(origin, 0, true, true)

	# Assert — 正確防護下，該格不出現在可達集合中
	assert_bool(result.has(corrupted)).is_false()


func test_reachable_tiles_move_cost_guard_is_independent_of_upstream_passable_gate() -> void:
	# Arrange — AC6 原文：「即使該間接防護未來被改動,get_move_cost() 呼叫端
	# 自身也要有獨立防護,不得只依賴上游的 passable() 閘門」。本測試用
	# _BoardWithPassableAlwaysTrue 模擬「上游 passable() 閘門失效」的情境
	# （ignore_passability=false 時，閘門理應擋下未登記地形，但本子類別讓它
	# 永遠放行），藉此單獨驗證 get_move_cost() 呼叫端自身是否仍有獨立防護。
	var board: _BoardWithPassableAlwaysTrue = _BoardWithPassableAlwaysTrue.new()
	var origin: Vector2i = Vector2i(0, 0)
	var corrupted: Vector2i = Vector2i(1, 0)
	board._terrain[corrupted] = "Z"

	# Act — ignore_passability=false：上游閘門「理應」擋下，但已被本測試子
	# 類別繞過；真正把關的應是 get_move_cost() 呼叫端自身的獨立防護
	var result: Array[Vector2i] = board.reachable_tiles(origin, 0, true, false)

	# Assert — 即使上游 passable() 閘門被繞過，獨立防護仍然擋下該格
	assert_bool(result.has(corrupted)).is_false()


func test_sensitivity_proof_move_cost_guard_removal_lets_unregistered_terrain_corrupt_reachable_set() -> void:
	# Arrange — 與 test_reachable_tiles_ignore_passability_true_excludes_
	# unregistered_terrain_neighbor 完全相同的資料形狀，但改用
	# _BoardWithMoveCostGuardRemoved（覆寫 _is_move_cost_usable() 永遠回傳
	# true，精確重現「AC6 防護被移除」時 reachable_tiles() 的行為，不手動
	# 改壞 board.gd 本體一次——.claude/rules/test-standards.md 2026-09-16
	# 條目：手動注入已淘汰，常駐間諜/突變子類別才算數）
	var board: _BoardWithMoveCostGuardRemoved = _BoardWithMoveCostGuardRemoved.new()
	var origin: Vector2i = Vector2i(0, 0)
	var corrupted: Vector2i = Vector2i(1, 0)
	board._terrain[corrupted] = "Z"

	# Act
	var result: Array[Vector2i] = board.reachable_tiles(origin, 0, true, true)

	# Assert — 防護被移除後，該格的負數成本貢獻（best_cost=0 + (-1) = -1 <=
	# mp=0）讓它被誤判納入可達集合，證明上一條測試的「不出現」確實是 AC6
	# 防護的效果，不是一條恆綠的裝飾測試
	assert_bool(result.has(corrupted)).is_true()
