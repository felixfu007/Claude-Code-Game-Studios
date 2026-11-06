## audio-foundation story-001 AC-6 / AC-7 / AC-8。純函式,不碰檔案。
## 註:亂碼輸入時引擎自己的 ConfigFile.parse 會在 stderr 印 ERROR(非本專案 push_error),
## 回傳碼非 OK,decode 回全預設。
extends GdUnitTestSuite


func _defaults() -> Dictionary:
	return GameSettings.default_values()


func _custom() -> Dictionary:
	return {
		SettingsCodec.KEY_EGM: true,
		SettingsCodec.KEY_HIDE_AFFINITY: true,
		SettingsCodec.KEY_MASTER: 0.25,
		SettingsCodec.KEY_MUSIC: 0.125,
		SettingsCodec.KEY_SFX: 1.0,
		SettingsCodec.KEY_MUTED: true,
	}


func test_roundtrip_all_six_items() -> void:
	var decoded: Dictionary = SettingsCodec.decode(SettingsCodec.encode(_custom()), _defaults())
	for key: String in _custom():
		assert_that(decoded[key]).is_equal(_custom()[key])


func test_empty_and_garbage_return_defaults() -> void:
	assert_dict(SettingsCodec.decode("", _defaults())).is_equal(_defaults())
	assert_dict(SettingsCodec.decode("   \n", _defaults())).is_equal(_defaults())
	assert_dict(SettingsCodec.decode("@@@ not [ valid ===", _defaults())).is_equal(_defaults())


func test_missing_key_only_defaults_that_key() -> void:
	var text: String = "[settings]\nmaster_volume=0.2\nmuted=true\n"
	var d: Dictionary = SettingsCodec.decode(text, _defaults())
	assert_float(float(d[SettingsCodec.KEY_MASTER])).is_equal(0.2)
	assert_bool(bool(d[SettingsCodec.KEY_MUTED])).is_true()
	assert_float(float(d[SettingsCodec.KEY_MUSIC])).is_equal(GameSettings.DEFAULT_MUSIC_VOLUME)
	assert_bool(bool(d[SettingsCodec.KEY_EGM])).is_false()


func test_non_numeric_and_out_of_range_default_only_that_key() -> void:
	var text: String = "[settings]\nmaster_volume=\"abc\"\nmusic_volume=7.5\nsfx_volume=0.4\negm_enabled=\"yes\"\nhide_affinity_display=true\n"
	var d: Dictionary = SettingsCodec.decode(text, _defaults())
	assert_float(float(d[SettingsCodec.KEY_MASTER])).is_equal(GameSettings.DEFAULT_MASTER_VOLUME)
	assert_float(float(d[SettingsCodec.KEY_MUSIC])).is_equal(GameSettings.DEFAULT_MUSIC_VOLUME)
	assert_float(float(d[SettingsCodec.KEY_SFX])).is_equal(0.4)
	assert_bool(bool(d[SettingsCodec.KEY_EGM])).is_false()
	assert_bool(bool(d[SettingsCodec.KEY_HIDE_AFFINITY])).is_true()


func test_old_file_without_audio_keys_gets_audio_defaults() -> void:
	var text: String = "[settings]\negm_enabled=true\nhide_affinity_display=true\n"
	var d: Dictionary = SettingsCodec.decode(text, _defaults())
	assert_bool(bool(d[SettingsCodec.KEY_EGM])).is_true()
	assert_bool(bool(d[SettingsCodec.KEY_HIDE_AFFINITY])).is_true()
	assert_float(float(d[SettingsCodec.KEY_MASTER])).is_equal(GameSettings.DEFAULT_MASTER_VOLUME)
	assert_float(float(d[SettingsCodec.KEY_MUSIC])).is_equal(GameSettings.DEFAULT_MUSIC_VOLUME)
	assert_float(float(d[SettingsCodec.KEY_SFX])).is_equal(GameSettings.DEFAULT_SFX_VOLUME)
	assert_bool(bool(d[SettingsCodec.KEY_MUTED])).is_false()
