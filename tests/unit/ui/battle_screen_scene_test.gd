# BattleScreen（src/ui/battle/BattleScreen.tscn / battle_screen.gd）場景冒煙測試。
#
# 背景：2026-08-27 匯出成獨立執行檔實測，BattleScreen.tscn 缺少 battle_screen.gd
# 第 101 行 @onready 宣告的 UILayer/ControlsHintBg/ControlsHintLabel 節點，一啟動
# 就 "ERROR: Node not found: UILayer/ControlsHintBg/ControlsHintLabel" 而整個場景
# 無法運作——但當時全套 145 個單元測試仍然全過、exit 0，因為沒有任何測試真的
# load() 過這份 .tscn。這份測試補上那個缺口：只驗證場景樹解析得出來（節點路徑
# 存在、型別正確），不測輸入（headless 環境下引擎不送任何 InputEvent，見
# .claude/docs/coding-standards.md）。
#
# 刻意 add_child() 進測試套件自己的節點樹（GdUnitTestSuite.add_child() 的多載，
# 見 addons/gdUnit4/src/GdUnitTestSuite.gd 第 135 行；測試套件本身在執行期間會被
# 掛進 SceneTree.root，見 addons/gdUnit4/src/core/execution/GdUnitTestSuiteExecutor.gd
# 第 47 行），而不是像 tests/unit/core/display_pixel_settings_test.gd 那樣只
# instantiate() 不進樹：這裡要重現的正是 @onready 解析失敗的那個當機模式，而
# @onready 只在節點真正進入 SceneTree、_ready() 被呼叫時才會求值——只
# instantiate() 不進樹不會觸發它，也就抓不到這個 bug。
#
# 每個測試各自重新 load()/instantiate()，不共用單一 fixture 節點，依
# .claude/rules/test-standards.md「每個測試各自 setup/teardown 自己的狀態」。
#
# 命名慣例依 tests/unit/ui/board_coords_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


# 進樹時若任何 @onready 節點路徑解析失敗，add_child() 這一步本身就會噴
# "Node not found" 而讓測試失敗——這是與 2026-08-27 匯出檔實測完全同一條當機路徑。
func test_scene_instantiates_and_enters_tree_without_error() -> void:
	# Arrange
	var packed: PackedScene = load(SCENE_PATH)
	assert_object(packed).is_not_null()

	# Act — auto_free() 先註冊釋放（見前面測試的註解），add_child() 才會真正觸發
	# _ready()／所有 @onready 引用的解析。
	var instance: Node = auto_free(packed.instantiate())
	add_child(instance)

	# Assert — 走到這裡代表進樹沒有拋錯，_ready() 順利跑完
	assert_object(instance).is_not_null()


func test_world_viewport_container_node_resolves_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node("WorldViewportContainer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is SubViewportContainer).is_true()


func test_board_view_node_resolves_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node("WorldViewportContainer/WorldViewport/BoardView")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is BoardView).is_true()


func test_status_label_node_resolves_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node("UILayer/StatusLabel")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Label).is_true()


func test_result_label_node_resolves_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node("UILayer/ResultLabel")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Label).is_true()


# 本檔存在的直接理由：2026-08-27 之前這個路徑在 .tscn 裡不存在，
# battle_screen.gd 第 101 行的 @onready 宣告會在 _ready() 當掉，而全套測試
# 從未 load() 過這份場景，所以從沒被抓到過。
func test_controls_hint_label_node_resolves_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node("UILayer/ControlsHintBg/ControlsHintLabel")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Label).is_true()


# 同一個風險的最新一例：2026-08-28 新增的 battle_screen.gd 載入失敗畫面
# （@onready var _load_error_label = $UILayer/LoadErrorLabel）同樣是「.tscn 若漏了
# 這個節點，_ready() 就會整個當掉」的模式——這份測試確保 .tscn 這一次確實補上了。
func test_load_error_label_node_resolves_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node("UILayer/LoadErrorLabel")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Label).is_true()


# ---- BoardView 高亮圖層 —— 2026-08-28 新增 ------------------------------------
#
# 同一個「.tscn 漏節點就整個當掉」的模式,這次是 board_view.gd 的
# @onready var _threat_highlight_layer = $ThreatHighlightLayer。
const BOARD_VIEW_PATH: String = "WorldViewportContainer/WorldViewport/BoardView"


func test_threat_highlight_layer_node_resolves_with_correct_type() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)

	# Act
	var node: Node = instance.get_node(BOARD_VIEW_PATH + "/ThreatHighlightLayer")

	# Assert
	assert_object(node).is_not_null()
	assert_bool(node is Node2D).is_true()


# 這一條擋的不是「節點不存在」,而是「節點存在但畫出來看不見」——比前者難抓得多,
# 因為場景載得起來、測試全過、程式也確實把 sprite 加進去了,只是玩家一個像素都
# 看不到。
#
# 背景(2026-08-28 實測):佔位棋子貼圖是完全不透明的 32x40 色塊
# (piece_enemy_01.png 的 1280 個像素全是同一個顏色,以 Image.get_pixel() 逐點讀出
# 確認),而棋子的錨點讓它蓋滿整格 32x32 再往上多出 8px。因此任何畫在棋子「下面」
# 又落在有人站的格子上的東西,會被 100% 遮住。
#
# AttackHighlightLayer 在此之前就是排在 PiecesLayer 前面(=畫在下面),而它標記的
# 正好只有「敵人所在的格」——也就是說「現在打得到誰」這個高亮從來沒有被畫面顯示過
# 一次。ThreatHighlightLayer 標記的格子同樣可能有人站。兩者都必須排在 PiecesLayer
# 之後。
#
# MoveHighlightLayer 則刻意留在 PiecesLayer 之前:可移動的格依定義不可能有人站
# (Board.reachable_tiles() 會跳過被佔的格),所以它不會被遮到,留在下面還能讓棋子
# 的上緣正常疊在高亮之上。這個不對稱是刻意的,不是疏漏。
func test_threat_and_attack_layers_draw_above_pieces_layer_but_move_layer_below() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)
	var board_view: Node = instance.get_node(BOARD_VIEW_PATH)

	# Act — Node2D 的繪製順序就是子節點順序,get_index() 越大越晚畫(越上層)
	var move_index: int = board_view.get_node("MoveHighlightLayer").get_index()
	var pieces_index: int = board_view.get_node("PiecesLayer").get_index()
	var threat_index: int = board_view.get_node("ThreatHighlightLayer").get_index()
	var attack_index: int = board_view.get_node("AttackHighlightLayer").get_index()

	# Assert
	assert_int(move_index).is_less(pieces_index)
	assert_int(threat_index).is_greater(pieces_index)
	assert_int(attack_index).is_greater(pieces_index)


# set_threat_highlights() 是純繪製呼叫:給幾格就畫幾個 sprite,給空陣列就清空。
# 與 set_move_highlights()/set_attack_highlights() 共用 _render_highlight_layer(),
# 這裡驗證第三層確實接上了同一條路徑,而不是宣告了卻沒有人畫。
func test_set_threat_highlights_renders_one_sprite_per_cell_and_clears_on_empty() -> void:
	# Arrange
	var instance: Node = auto_free(load(SCENE_PATH).instantiate())
	add_child(instance)
	var board_view: BoardView = instance.get_node(BOARD_VIEW_PATH)
	var layer: Node2D = board_view.get_node("ThreatHighlightLayer")
	var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 1), Vector2i(12, 5)]

	# Act
	board_view.set_threat_highlights(cells)
	var drawn_count: int = layer.get_child_count()
	board_view.set_threat_highlights([])
	var cleared_count: int = layer.get_child_count()

	# Assert
	assert_int(drawn_count).is_equal(cells.size())
	assert_int(cleared_count).is_equal(0)
