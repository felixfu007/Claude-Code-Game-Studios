## audio-foundation story-001 AC-1 / AC-2。
extends GdUnitTestSuite


func before_test() -> void:
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()


func test_defaults_are_named_constants_and_conservative() -> void:
	assert_float(GameSettings.get_master_volume()).is_equal(GameSettings.DEFAULT_MASTER_VOLUME)
	assert_float(GameSettings.get_music_volume()).is_equal(GameSettings.DEFAULT_MUSIC_VOLUME)
	assert_float(GameSettings.get_sfx_volume()).is_equal(GameSettings.DEFAULT_SFX_VOLUME)
	assert_bool(GameSettings.is_muted()).is_false()
	assert_bool(GameSettings.DEFAULT_MASTER_VOLUME <= 1.0).is_true()


func test_out_of_range_is_clamped() -> void:
	GameSettings.set_master_volume(-0.5)
	assert_float(GameSettings.get_master_volume()).is_equal(0.0)
	GameSettings.set_master_volume(1.7)
	assert_float(GameSettings.get_master_volume()).is_equal(1.0)
	GameSettings.set_music_volume(9.0)
	assert_float(GameSettings.get_music_volume()).is_equal(1.0)
	GameSettings.set_sfx_volume(-1.0)
	assert_float(GameSettings.get_sfx_volume()).is_equal(0.0)


func test_in_range_values_roundtrip_and_mute_keeps_volumes() -> void:
	GameSettings.set_master_volume(0.3)
	GameSettings.set_music_volume(0.4)
	GameSettings.set_sfx_volume(0.6)
	GameSettings.set_muted(true)
	assert_bool(GameSettings.is_muted()).is_true()
	assert_float(GameSettings.get_master_volume()).is_equal(0.3)
	assert_float(GameSettings.get_music_volume()).is_equal(0.4)
	assert_float(GameSettings.get_sfx_volume()).is_equal(0.6)


func test_reset_restores_audio_defaults() -> void:
	GameSettings.set_master_volume(0.1)
	GameSettings.set_muted(true)
	GameSettings.reset_for_test()
	assert_float(GameSettings.get_master_volume()).is_equal(GameSettings.DEFAULT_MASTER_VOLUME)
	assert_bool(GameSettings.is_muted()).is_false()
