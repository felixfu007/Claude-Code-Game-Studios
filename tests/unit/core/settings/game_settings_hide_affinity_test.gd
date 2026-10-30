## story-009 AC1 —— GameSettings「隱藏好感度顯示」。
## 敏感度證明:類別 A(static 純函式,沒有繼承鏈可覆寫)——【證明不了】,理由已逐條寫於此。
extends GdUnitTestSuite


func before_test() -> void:
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()


func test_hide_affinity_defaults_to_disabled() -> void:
	assert_bool(GameSettings.is_hide_affinity_display()).is_false()


func test_hide_affinity_set_then_get_roundtrips() -> void:
	GameSettings.set_hide_affinity_display(true)
	assert_bool(GameSettings.is_hide_affinity_display()).is_true()
	GameSettings.set_hide_affinity_display(false)
	assert_bool(GameSettings.is_hide_affinity_display()).is_false()


func test_reset_for_test_clears_hide_affinity() -> void:
	GameSettings.set_hide_affinity_display(true)
	GameSettings.reset_for_test()
	assert_bool(GameSettings.is_hide_affinity_display()).is_false()


func test_hide_affinity_independent_of_egm() -> void:
	GameSettings.set_hide_affinity_display(true)
	assert_bool(GameSettings.is_egm_enabled()).is_false()
	GameSettings.reset_for_test()
	GameSettings.set_egm_enabled(true)
	assert_bool(GameSettings.is_hide_affinity_display()).is_false()
