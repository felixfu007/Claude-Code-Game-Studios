# BattleScreen（src/ui/battle/battle_screen.gd）_ready() 內「不可通行地形掃描」
# （story-015，commit 5624ba3，約第 1251~1257 行）的整合測試。
#
# 背景：這段程式碼在提交當天沒有任何測試驅動過（實作者自行誠實登記），而
# tests/integration/ui/action_flag_impassable_terrain_test.gd 的檔頭（第 13~16 行）
# 已明文登記這段範圍為「battle_screen.gd 內 … _ready() 內的不可通行格掃描邏輯需要
# 完整的 BattleController/BattleState 盤面夾具才能驅動到，不在本輪範圍內——誠實
# 登記為未覆蓋，不代為斷言它已被驗證」。本檔補的就是那個已登記的洞：真正驗證
# BattleScreen._ready() 會呼叫 Board.passable() 掃完整個棋盤、把回傳 false 的格子
# 收集起來、轉交給 BoardView.set_impassable_terrain_highlights() —— 不是重測
# set_impassable_terrain_highlights() 這個消費端函式本身（那已由上述姊妹檔涵蓋）。
#
# 🔴 走的是哪條路徑、為什麼只能走這條（決定本檔能證明什麼，必讀）：
# Board.TERRAIN_TABLE（src/gameplay/board/board.gd）目前三個登記地形字元全部
# passable=true（design/gdd/tactical-combat-system.md Tuning Knobs #4 明文裁決，
# 起始三地形皆可通行），所以 Board.passable() 目前只有一條路徑能回傳 false：
# pos 的地形字元「未登記」（board.gd passable() 文件註解「Design tradeoff」段落——
# 這條路徑同時觸發 push_error()，回傳值與「已登記但 passable=false」那條【目前在
# production 資料裡不存在】的路徑無法用回傳值區分）。本檔因此只能、也只走「未登記
# 字元」這條路徑來讓 battle_screen.gd 的掃描迴圈成立。
#
# 本檔證明的是：
#   「掃描迴圈會把 Board.passable() 回傳 false 的格子正確收集，且正確轉交給
#     BoardView.set_impassable_terrain_highlights()」
# 本檔【不能】證明的是：
#   「不可通行地形」這個設計概念的完整行為——例如移動力計算（reachable_tiles()）
#   是否正確排除它、或視覺上「不可通行」與「地形資料打錯字」這兩種不同情境有沒有
#   分開——因為目前沒有任何合法登記的 passable=false 地形可驅動，production 從未
#   走過語意上「真正的」不可通行路徑。
#   tests/unit/gameplay/board/board_passable_test.gd 的 _BoardWithImpassableTestTerrain
#   用子類別覆寫 _terrain_entry() 繞過這個限制，但那個覆寫接縫只對直接 new() 建構
#   的 Board 有效；battle_screen.gd 是透過 Board.from_ascii(terrain_rows) 建構真正
#   的 production Board，沒有任何注入點可以把它換成那個測試子類別——這是刻意的
#   設計（見 board.gd _terrain_entry() 文件註解：接縫是為了「不把測試專用地形字元
#   塞進正式關卡資料」，不是為了讓 production 的建構路徑可替換）。本檔不新增這種
#   注入點，也不新增第四種地形到 TERRAIN_TABLE——兩者都是設計決定，不在本工作單
#   權限內。
#
# push_error() 怎麼處理：本檔刻意【不】用 assert_error() 包住 add_child(instance)
# ——不是遺漏，是跟隨既有先例：board_passable_test.gd 的
# test_unregistered_terrain_character_returns_explicit_sentinels_not_silent_fallback()
# 直接呼叫 board.passable(pos)（未登記地形），完全沒有包 assert_error()，而那條
# 測試是本專案目前綠燈基線（1245 test cases | 0 failures）的一部分——證明 GdUnit4
# 不會只因為測試執行期間某處呼叫了 push_error() 就判定該測試失敗（assert_error()
# 的用途是「斷言某次呼叫確實觸發了 push_error()」，不是「壓制 push_error() 以免
# 測試變紅」）。本檔新增的合成地形會讓 _ready() 在 Board.from_ascii()（載入期
# 驗證，board.gd 第 129~143 行）與後續每一次 Board.passable()/get_move_cost()
# 查詢各觸發一次 push_error()，執行時終端機會印出對應的 SCRIPT ERROR 訊息，屬
# 預期噪音，不是測試失敗的跡象。
#
# 新增合成夾具：assets/data/levels/test_fixture_terrain_impassable.txt（6 列 x
# 13 欄，與 Board.BOARD_HEIGHT/BOARD_WIDTH 完全相同尺寸，避免 from_ascii() 額外
# 因尺寸不符而噴出無關的 push_error，干擾判讀），全部為合法平地字元 '.'，僅
# (6,1) 與 (3,3) 兩格換成未登記字元 'X'——刻意挑選不與 vs01_roster.txt 任何單位
# 起始座標重疊的位置（該檔 PLAYER 在 x∈{0,1}，ENEMY 在 x∈{7,9,10,11}）。只注入
# terrain_path_override，roster 維持預設（vs01_roster.txt），依
# tests/unit/ui/battle_screen_data_path_override_test.gd 既有先例的時機合約：
# instantiate() 之後、add_child() 之前。
#
# 命名慣例依既有先例：test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _BOARD_VIEW_RELATIVE_PATH: String = "WorldViewportContainer/WorldViewport/BoardView"
const _FIXTURE_TERRAIN_IMPASSABLE_PATH: String = (
	"res://assets/data/levels/test_fixture_terrain_impassable.txt"
)

# 與夾具檔案【當下的實際內容】綁死——若有人改動該檔案的未登記字元位置，這裡的
# 斷言必須跟著改（test-standards.md 甲類例外同一種情境，見本檔頭已說明理由）。
const _EXPECTED_IMPASSABLE_CELLS: Array[Vector2i] = [Vector2i(6, 1), Vector2i(3, 3)]


func test_ready_scans_board_and_forwards_unregistered_terrain_cells_to_board_view() -> void:
	# Arrange
	var instance: BattleScreen = auto_free(load(SCENE_PATH).instantiate())
	instance.terrain_path_override = _FIXTURE_TERRAIN_IMPASSABLE_PATH

	# Act — add_child() 觸發 _ready()，走完整個載入 + 掃描管線
	add_child(instance)

	# Assert — 先確認真的走到了掃描那一步，不是碰巧在更早的階段就判定載入失敗退出：
	# classify_content() 只檢查「內容非空、解析筆數非零」，不檢查地形字元是否登記，
	# 所以未登記字元不會被 battle_screen.gd 的載入管線判定為失敗
	assert_bool(instance._load_failed).is_false()

	# Assert — BoardView 收到的不可通行標記數量，與夾具裡未登記字元的格數一致
	var layer: Node2D = instance._board_view._impassable_terrain_layer
	var count_message: String = (
		"夾具有 2 個未登記地形字元格，BoardView 的 ImpassableTerrainLayer 應收到同樣" +
		"數量的標記根節點，實得 %d" % layer.get_child_count()
	)
	assert_int(layer.get_child_count()).append_failure_message(count_message).is_equal(
		_EXPECTED_IMPASSABLE_CELLS.size()
	)

	# Assert — 逐格核對：每個標記根節點換算回棋盤座標，必須恰好是夾具裡的那兩格，
	# 不多不少（呼叫專案既有的真實座標轉換函式 BoardCoords.local_to_grid() 反推，
	# 不自行重新實作一份座標數學 —— technical-preferences.md「(A) 的精確定義」節）
	# （讀 global_position 而非 position——依
	# tests/integration/ui/action_flag_impassable_terrain_test.gd
	# _filled_pip_x_positions() 既有先例，不假設中間任何圖層節點本身位移為零）
	var marked_cells: Array[Vector2i] = []
	for marker: Node in layer.get_children():
		var quadrant: Control = marker.get_child(0) as Control
		marked_cells.append(BoardCoords.local_to_grid(quadrant.global_position))
	for expected_cell: Vector2i in _EXPECTED_IMPASSABLE_CELLS:
		assert_bool(marked_cells.has(expected_cell)).append_failure_message(
			"預期不可通行格 %s 沒有出現在 BoardView 實際收到的標記清單 %s 裡"
			% [expected_cell, marked_cells]
		).is_true()

	# Assert — 與 production Board 實例自己的查詢結果交叉核對：不只信 BoardView
	# 收到的結果，確認它跟 _state.board 這個真實物件回報的 passable()/
	# get_move_cost() 一致
	for expected_cell: Vector2i in _EXPECTED_IMPASSABLE_CELLS:
		assert_bool(instance._state.board.passable(expected_cell)).is_false()
		assert_int(instance._state.board.get_move_cost(expected_cell)).is_equal(
			Board.MOVE_COST_UNKNOWN_TERRAIN
		)

	# Assert — 棋盤上其餘合法地形（平地）不應被誤標記為不可通行：用一個已知是 '.'
	# 的格子（夾具裡未被替換過的 (0,0)）確認掃描沒有過度標記，證明迴圈的 if 判斷
	# 方向沒有反過來
	assert_bool(instance._state.board.passable(Vector2i(0, 0))).is_true()
	assert_bool(marked_cells.has(Vector2i(0, 0))).is_false()


## 敏感度證明用 mutant——見 test_sensitivity_proof_scan_wiring_regression_detected()。
## 只覆寫 BoardView 這一側的轉交入口（讓它變成空操作），模擬「battle_screen.gd
## 仍然算出了 impassable_cells，但轉交給 BoardView 那一行被誤刪／改壞」這個回歸
## 形狀——不是改 battle_screen.gd 本身（本工作單不得修改 src/ 底下任何程式碼）。
## 在 add_child() 之前換腳本，屬 .claude/rules/test-standards.md 登記的「Case A
## （進樹前換腳本）—— 安全」情境，非「進樹後換腳本」那個已知無補救寫法的 Case B。
class _MutantBoardViewSwallowsImpassableHighlights extends BoardView:
	func set_impassable_terrain_highlights(_cells: Array[Vector2i]) -> void:
		pass


func test_sensitivity_proof_scan_wiring_regression_detected() -> void:
	# Arrange — 依 Case A 時機合約：set_script() 在 add_child() 之前，此時整個
	# instance 子樹（含 BoardView 節點）都還沒進入場景樹
	var instance: BattleScreen = auto_free(load(SCENE_PATH).instantiate())
	instance.terrain_path_override = _FIXTURE_TERRAIN_IMPASSABLE_PATH
	var board_view_node: Node = instance.get_node(_BOARD_VIEW_RELATIVE_PATH)
	board_view_node.set_script(_MutantBoardViewSwallowsImpassableHighlights)

	# Act
	add_child(instance)

	# Assert —— mutant 吞掉了轉交呼叫，ImpassableTerrainLayer 應該是空的（0 個
	# 標記），證明上面那條測試的 is_equal(_EXPECTED_IMPASSABLE_CELLS.size()) 斷言
	# 會抓到「算完但沒轉交給 BoardView」這個回歸
	assert_bool(instance._load_failed).is_false()
	var layer: Node2D = instance._board_view._impassable_terrain_layer
	assert_int(layer.get_child_count()).append_failure_message(
		"mutant 應該吞掉所有 set_impassable_terrain_highlights() 呼叫，圖層應為空，" +
		"若這裡量到非 0，代表本注入手法本身有問題"
	).is_equal(0)

# ⚠️ 誠實登記（test-standards.md「不可證的理由必須逐條寫下」義務）：上面這個
# 敏感度證明只涵蓋「算完但沒轉交」這一半回歸。另一半——battle_screen.gd 第
# 1251~1257 行那段掃描迴圈本身算錯（例如 range() 邊界錯、if 條件方向反過來、
# 漏掉某一軸的巢狀迴圈）——沒有獨立的 mutant 可以證明會被抓到，因為那段迴圈是
# 寫死在 BattleScreen._ready() 內部的私有邏輯，不是可覆寫的虛擬方法，也不透過
# 任何可注入的介面暴露；要證明它需要能替換 _ready() 的這段邏輯本身，而那等於
# 修改 src/ui/battle/battle_screen.gd，不在本工作單允許修改的範圍內。
# test_ready_scans_board_and_forwards_unregistered_terrain_cells_to_board_view()
# 對這段邏輯的保障來自直接斷言：它拿真實的 2 格 X 座標、真實的 production
# Board.passable() 查詢結果、以及一個已知合法的 (0,0) 對照組三方比對，而不是靠
# mutant 證明——這是比「證明不了就不寫」更弱但誠實的保障層級，記錄在此供下一個
# 人判斷是否要在未來一次 src/ 變更中把這段迴圈抽成可注入的介面。
