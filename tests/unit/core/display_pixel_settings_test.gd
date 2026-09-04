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


func test_stretch_mode_is_disabled_per_2026_09_01_screen_architecture_decision() -> void:
	# 🔴 2026-09-04（Story 001，screen-scaling epic）更新：`design/art/screen-architecture.md`
	# 2026-09-01 裁決把 `window/stretch/mode` 從 `"canvas_items"` 改為 `"disabled"` —— 世界層
	# 縮放與定位改為手動管理（見 src/ui/battle/world_layout.gd + world_viewport_scaler.gd），
	# 理由是 `canvas_items`+`keep`+`integer` 的縮放很少剛好填滿視窗，留白部分是引擎渲染目標
	# 沒有涵蓋的範圍，物理上畫不進東西（2026-09-01 spike 實測，2K 視窗截圖曾量到 2400x1350
	# 而非 2560x1440）。本測試取代原本斷言 `"canvas_items"` 的版本。

	# Arrange
	var mode: String = ProjectSettings.get_setting("display/window/stretch/mode")

	# Act — 無（純讀取）

	# Assert — mode 絕不可為 "viewport"（CanvasLayer 不繼承 Viewport，會讓
	# 介面文字模糊，見 technical-preferences.md 反噬事實 1）——這條約束在
	# "disabled" 下依然成立，一併保留斷言精神。
	assert_str(mode).is_not_equal("viewport")
	assert_str(mode).is_equal("disabled")


func test_stretch_aspect_and_scale_mode_keys_are_removed_and_fall_back_to_engine_defaults() -> void:
	# 🔴 2026-09-04（Story 001）：`window/stretch/aspect` 與 `window/stretch/scale_mode`
	# 這兩個設定鍵在 `window/stretch/mode = "disabled"` 下不再產生任何作用（`disabled`
	# 模式下引擎完全不做縮放，aspect/scale_mode 只在 canvas_items 等縮放模式下才有意義）。
	# 本次變更決定把兩個鍵從 project.godot 整個移除，而不是留著舊值造成「設定還在但其實
	# 沒作用」的誤導——本專案已有多次「文件寫著已取消但設定還留著」的教訓
	# （見 .claude/docs/technical-preferences.md「流程劑量上限」節、`docs/consistency-failures.md`）。
	#
	# 移除鍵後 ProjectSettings.get_setting() 不會回傳空值，而是回退到該設定鍵自己的引擎內建
	# 預設值——這是實機驗證過的行為，見
	# prototypes/story-001-manual-scaling-verification-2026-09-04/run_output.txt：
	# aspect 的引擎預設剛好也是 "keep"（與本專案原本手動設定的值一致，純屬巧合）；
	# scale_mode 的引擎預設是 "fractional"，不是本專案原本手動設定的 "integer"。
	# 兩者在 "disabled" 模式下都不影響任何畫面行為。

	# Arrange
	var aspect_has_setting: bool = ProjectSettings.has_setting("display/window/stretch/aspect")
	var aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect")
	var scale_mode_has_setting: bool = ProjectSettings.has_setting("display/window/stretch/scale_mode")
	var scale_mode: String = ProjectSettings.get_setting("display/window/stretch/scale_mode")

	# Act — 無（純讀取）

	# Assert — has_setting() 仍為 true（回退到引擎內建預設，不是「沒有這個設定」），
	# 且值等於引擎的內建預設，證明 project.godot 真的沒有手動覆寫這兩個鍵。
	assert_bool(aspect_has_setting).append_failure_message(
		"display/window/stretch/aspect: has_setting() is false — this key does not exist "
		+ "as a registered engine property at all, which contradicts the 2026-09-04 probe"
	).is_true()
	assert_str(aspect).is_equal("keep")

	assert_bool(scale_mode_has_setting).append_failure_message(
		"display/window/stretch/scale_mode: has_setting() is false — this key does not "
		+ "exist as a registered engine property at all, which contradicts the 2026-09-04 probe"
	).is_true()
	assert_str(scale_mode).is_equal("fractional")


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
	# auto_free()（非 queue_free()）：queue_free() 是延後到下一影格才真正釋放，
	# 但 GdUnit4 的孤兒節點檢查在那之前就跑完了，會誤報孤兒節點。
	var container: SubViewportContainer = auto_free(SubViewportContainer.new())

	# Act — 無（讀剛建立節點的預設值）

	# Assert
	assert_int(container.texture_filter).is_equal(0)  # 0 == Inherit


func test_game_root_scene_world_container_overrides_filter_to_nearest() -> void:
	# Arrange
	var packed: PackedScene = load("res://src/ui/GameRoot.tscn")
	assert_object(packed).is_not_null()

	# auto_free()（非 queue_free()）：見上一個測試的註解。
	var instance: Node = auto_free(packed.instantiate())

	# Act
	var world_container: Node = instance.get_node("WorldViewportContainer")

	# Assert
	assert_bool(world_container is SubViewportContainer).is_true()
	assert_int(world_container.texture_filter).is_equal(1)  # 1 == Nearest，非預設 Inherit
	assert_bool(world_container.stretch).is_true()
	assert_int(world_container.stretch_shrink).is_equal(1)


func test_game_root_scene_has_world_viewport_and_ui_layer() -> void:
	# Arrange
	var packed: PackedScene = load("res://src/ui/GameRoot.tscn")
	# auto_free()（非 queue_free()）：見前面測試的註解。
	var instance: Node = auto_free(packed.instantiate())

	# Act
	var world_container: Node = instance.get_node("WorldViewportContainer")
	var world_viewport: Node = world_container.get_node("WorldViewport")
	var ui_layer: Node = instance.get_node("UILayer")

	# Assert
	assert_bool(world_viewport is SubViewport).is_true()
	assert_bool(ui_layer is CanvasLayer).is_true()
