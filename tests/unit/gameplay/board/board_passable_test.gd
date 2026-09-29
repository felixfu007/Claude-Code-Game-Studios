# Board（src/gameplay/board/board.gd）passable() 與 get_move_cost() 對未登記
# 地形字元之明確失敗路徑的單元測試。
#
# 對應 production/epics/tactical-combat/story-001-terrain-passable-flag.md
# 的 Acceptance Criteria 與 QA Test Cases（四組:起始三地形皆 true、新增
# passable=false 地形正確排除、未登記地形字元明確失敗、passable=false 地形
# 的 cost 欄位是合法佔位值）。
#
# ⚠️ 命名慣例：依既有範本 board_test.gd 沿用 test_[scenario]_[expected]（不含
# [system] 前綴），理由同該檔檔頭註解。
extends GdUnitTestSuite


## 測試專用 Board 子類：新增一個「已登記、但 passable=false」的地形字元,
## 用來演練「已登記但不可通行」這條路徑(QA Test Cases 2、4),同時：
##   - 不去動到唯讀的 TERRAIN_TABLE 常數 —— GDScript 的 `const Dictionary`
##     在執行期是唯讀的(見
##     docs/engine-reference/godot/modules/scripting-typing.md
##     「const Dictionary 是唯讀」一節),嘗試在測試裡直接改寫
##     `Board.TERRAIN_TABLE` 的內容會在執行期出錯；
##   - 不把測試專用地形字元塞進正式關卡資料或正式 TERRAIN_TABLE。
## Board._terrain_entry() 是專為此設計的覆寫接縫(見 board.gd 該函式文件註解)。
class _BoardWithImpassableTestTerrain extends Board:
	## 測試專用地形字元：已登記、passable=false、cost=1
	## (AC #5 要求的合法佔位值 —— 不得留空)。
	const IMPASSABLE_CHAR: String = "Z"

	func _terrain_entry(terrain: String) -> Variant:
		if terrain == IMPASSABLE_CHAR:
			return {"cost": 1, "passable": false}
		return super._terrain_entry(terrain)


# 建一份全開闊（13x6，全 '.'）的 ascii 版面，供多個測試共用起點。
func _build_open_rows() -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for _y: int in range(Board.BOARD_HEIGHT):
		rows.append(".............")
	return rows


# --- QA Test Case 1: passable() 起始三地形皆為 true -------------------------

func test_passable_three_existing_terrains_return_true() -> void:
	# Arrange — 含平地（.）、灌木（,）、倒木（#）三種既有地形的版面
	var rows: PackedStringArray = PackedStringArray([
		".............",
		".....,,......",
		"....,##,.....",
		"....,##,.....",
		".....,,......",
		".............",
	])
	var board: Board = Board.from_ascii(rows)

	# Act — 無（純查詢）

	# Assert
	assert_bool(board.passable(Vector2i(0, 0))).is_true()  # 平地
	assert_bool(board.passable(Vector2i(5, 1))).is_true()  # 灌木
	assert_bool(board.passable(Vector2i(5, 2))).is_true()  # 倒木


func test_passable_origin_tile_is_always_true_for_well_formed_terrain() -> void:
	# Arrange — GDD 公式三：passable(origin) 這一隱性不變量,在本 story 範圍內
	# （靜態地形表、單位起點必為合法可站立地形）恆成立。
	var board: Board = Board.from_ascii(_build_open_rows())
	var origin: Vector2i = Vector2i(6, 3)

	# Act — 無（純查詢）

	# Assert
	assert_bool(board.passable(origin)).is_true()


# --- QA Test Case 2 / AC #5: passable=false 新地形正確排除,cost 為合法佔位值 --

func test_passable_false_registered_terrain_excluded_from_movement() -> void:
	# Arrange — 測試專用地形字元 'Z'：已登記、passable=false
	var board: _BoardWithImpassableTestTerrain = _BoardWithImpassableTestTerrain.new()
	var pos: Vector2i = Vector2i(3, 3)
	board._terrain[pos] = _BoardWithImpassableTestTerrain.IMPASSABLE_CHAR

	# Act
	var is_passable: bool = board.passable(pos)
	var move_cost: int = board.get_move_cost(pos)

	# Assert — passable=false,但同格 get_move_cost() 仍是合法佔位值
	# （非崩潰、非負值、非「未登記」哨兵）
	assert_bool(is_passable).is_false()
	assert_int(move_cost).is_greater_equal(1)
	assert_int(move_cost).is_not_equal(Board.MOVE_COST_UNKNOWN_TERRAIN)


# --- QA Test Case 4 / AC #5(獨立成一條測試,對應 story 文件的獨立條目) -------

func test_passable_false_terrain_move_cost_is_legal_placeholder_value() -> void:
	# Arrange — 與上一測試相同的資料形狀,獨立驗證「cost 欄位合法佔位值」這一項
	var board: _BoardWithImpassableTestTerrain = _BoardWithImpassableTestTerrain.new()
	var pos: Vector2i = Vector2i(2, 2)
	board._terrain[pos] = _BoardWithImpassableTestTerrain.IMPASSABLE_CHAR

	# Act
	var move_cost: int = board.get_move_cost(pos)

	# Assert — 合法佔位值：>=1 的整數,不是崩潰、不是哨兵值
	assert_int(move_cost).is_greater_equal(1)
	assert_int(move_cost).is_not_equal(Board.MOVE_COST_UNKNOWN_TERRAIN)


# --- QA Test Case 3: 未登記地形字元明確失敗 --------------------------------

func test_unregistered_terrain_character_returns_explicit_sentinels_not_silent_fallback() -> void:
	# Arrange — 一個從未在 TERRAIN_TABLE 登記過的地形字元
	var rows: PackedStringArray = _build_open_rows()
	rows[0] = "?" + rows[0].substr(1)
	var board: Board = Board.from_ascii(rows)
	var pos: Vector2i = Vector2i(0, 0)

	# Act
	var is_passable: bool = board.passable(pos)
	var move_cost: int = board.get_move_cost(pos)

	# Assert — 不得靜默 fallback 到「平地成本 1」或「passable=true」；
	# 必須是明確定義的非成功哨兵。
	assert_bool(is_passable).is_false()
	assert_int(move_cost).is_equal(Board.MOVE_COST_UNKNOWN_TERRAIN)


func test_unregistered_terrain_character_triggers_push_error_not_assert() -> void:
	# Arrange — 同上,未登記地形字元
	var rows: PackedStringArray = _build_open_rows()
	rows[0] = "?" + rows[0].substr(1)
	var board: Board = Board.from_ascii(rows)
	var pos: Vector2i = Vector2i(0, 0)

	# Act & Assert — 驗證失敗路徑走的是 push_error(),不是 assert()。
	#
	# 這條斷言本身就是本測試要抓的迴歸：GdUnit4 的 is_push_error() 只認
	# PUSH_ERROR 類型的紀錄；若未來有人把 passable()/get_move_cost() 的這個
	# 分支改回 assert(),assert() 失敗產生的是 SCRIPT_ERROR 紀錄而非
	# PUSH_ERROR 紀錄,is_push_error() 會找不到相符項目而回報失敗 —— 測試會
	# 變紅。這條路徑不依賴比對回傳值(passable() 回傳 false 這件事本身無法
	# 分辨「push_error 的正確實作」與「assert() 誤用」,兩者回傳值相同,
	# 見 board.gd 的 passable() 文件註解「Design tradeoff」段落),而是直接
	# 偵測「push_error() 真的被呼叫了」這個機制本身,兩種失敗路徑產生的
	# ErrorLogEntry.TYPE 不同,可以正確區分。
	var call_passable: Callable = func() -> void:
		var _discard_passable: bool = board.passable(pos)
	await assert_error(call_passable).is_push_error(any_string())

	var call_get_move_cost: Callable = func() -> void:
		var _discard_cost: int = board.get_move_cost(pos)
	await assert_error(call_get_move_cost).is_push_error(any_string())
