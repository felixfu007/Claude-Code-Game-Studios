# game-shell story-010 AC1/AC3/AC4:標題畫面顯示遊戲名稱,文字走 Loc,且不擋焦點順序。
extends GdUnitTestSuite

const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"


func test_title_screen_game_name_label_text_equals_localized_key() -> void:
	# Arrange
	var title: TitleScreen = auto_free(load(_TITLE_SCENE_PATH).instantiate())
	add_child(title)
	await get_tree().process_frame

	# Act
	var label: Label = title.get_node_or_null("Panel/ContentMargin/Rows/GameNameLabel")

	# Assert
	assert_object(label).append_failure_message("AC1: 應有 GameNameLabel 節點").is_not_null()
	assert_str(label.text).is_equal(Loc.localize(TitleScreen.TEXT_GAME_NAME))
	assert_str(label.text).append_failure_message("名稱不應為空或回退成 key").is_not_empty()
	assert_str(label.text).is_not_equal(String(TitleScreen.TEXT_GAME_NAME))


func test_title_screen_game_name_label_does_not_take_focus_or_steal_start_focus() -> void:
	# Arrange
	var title: TitleScreen = auto_free(load(_TITLE_SCENE_PATH).instantiate())
	add_child(title)
	await get_tree().process_frame

	# Act
	var label: Label = title.get_node("Panel/ContentMargin/Rows/GameNameLabel")
	var start_row: Button = title.get_node("Panel/ContentMargin/Rows/StartBattleRow")

	# Assert — AC3
	assert_int(label.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_bool(start_row.has_focus()).is_true()
