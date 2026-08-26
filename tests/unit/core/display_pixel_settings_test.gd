# 像素風專案設定的正式驗證測試
#
# 對應 .claude/docs/technical-preferences.md「美術方向與像素風專案設定」節裁決的
# project.godot 設定鍵，以及 GameRoot.tscn 的世界層/介面層分層骨架。
#
# ⚠️ 命名慣例注意：本檔函式名依 .claude/docs/coding-standards.md 與既有範本
# tests/unit/harness/harness_selfcheck_test.gd 的 test_[scenario]_[expected] 慣例。
# .claude/rules/test-standards.md 另外記載 test_[system]_[scenario]_[expected_result]
# 慣例（多一段 [system]），兩份文件對函式命名的規定不一致。本檔選用前者，理由是
# harness_selfcheck_test.gd 明文自稱「命名慣例的範本」且是同類（引擎/專案基礎設施）
# 驗證測試最直接的先例；這個不一致本身沒有在本次任務範圍內裁決，留給下一次
# 文件覆核處理。
#
# ⚠️ GdUnit4 本身仍未實測（tests/README.md 明文記載：本專案 addons/ 目錄尚不存在，
# GdUnit4 未安裝）。本檔照現有慣例（extends GdUnitTestSuite）寫成，但截至撰寫時
# 從未真正跑過 —— 跟 harness_selfcheck_test.gd 目前的實際狀態相同。
extends GdUnitTestSuite


func test_viewport_resolution_is_480x270() -> void:
	# Arrange — 讀專案設定，不建立任何節點
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")

	# Act — 無（純讀取）

	# Assert
	assert_int(width).is_equal(480)
	assert_int(height).is_equal(270)


func test_stretch_settings_match_pixel_art_decision() -> void:
	# Arrange
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode")
	var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect")
	var scale_mode: String = ProjectSettings.get_setting("display/window/stretch/scale_mode")

	# Act — 無（純讀取）

	# Assert — mode 絕不可為 "viewport"（CanvasLayer 不繼承 Viewport，會讓
	# 介面文字模糊，見 technical-preferences.md 反噬事實 1）
	assert_str(mode).is_equal("canvas_items")
	assert_str(aspect).is_equal("keep")
	assert_str(scale_mode).is_equal("integer")


func test_default_texture_filter_is_nearest() -> void:
	# Arrange
	var filter_value: int = ProjectSettings.get_setting(
		"rendering/textures/canvas_textures/default_texture_filter"
	)

	# Act — 無（純讀取）

	# Assert — 0 對應引擎列舉字串 "Nearest"（本專案已實機驗證，
	# 見 .claude/docs/technical-preferences.md 對應表）
	assert_int(filter_value).is_equal(0)


func test_fresh_subviewportcontainer_default_filter_is_inherit_not_nearest() -> void:
	# 這個測試記錄的是「陷阱本身」：SubViewportContainer.texture_filter 的預設值
	# 是 Inherit，不是 Nearest，必須逐一手動覆寫。這個測試失敗代表引擎預設值變了，
	# 不代表 GameRoot.tscn 裡的覆寫失效（那件事由下一個測試單獨驗證）。

	# Arrange
	var container := SubViewportContainer.new()

	# Act — 無（讀剛建立節點的預設值）

	# Assert
	assert_int(container.texture_filter).is_equal(0)  # 0 == Inherit

	container.queue_free()


func test_game_root_scene_world_container_overrides_filter_to_nearest() -> void:
	# Arrange
	var packed: PackedScene = load("res://src/ui/GameRoot.tscn")
	assert_object(packed).is_not_null()

	var instance: Node = packed.instantiate()

	# Act
	var world_container: Node = instance.get_node("WorldViewportContainer")

	# Assert
	assert_bool(world_container is SubViewportContainer).is_true()
	assert_int(world_container.texture_filter).is_equal(1)  # 1 == Nearest，非預設 Inherit
	assert_bool(world_container.stretch).is_true()
	assert_int(world_container.stretch_shrink).is_equal(1)

	instance.queue_free()


func test_game_root_scene_has_world_viewport_and_ui_layer() -> void:
	# Arrange
	var packed: PackedScene = load("res://src/ui/GameRoot.tscn")
	var instance: Node = packed.instantiate()

	# Act
	var world_container: Node = instance.get_node("WorldViewportContainer")
	var world_viewport: Node = world_container.get_node("WorldViewport")
	var ui_layer: Node = instance.get_node("UILayer")

	# Assert
	assert_bool(world_viewport is SubViewport).is_true()
	assert_bool(ui_layer is CanvasLayer).is_true()

	instance.queue_free()
