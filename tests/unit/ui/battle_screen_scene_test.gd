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
