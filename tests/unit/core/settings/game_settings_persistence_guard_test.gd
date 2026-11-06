## audio-foundation story-001 AC-9 ~ AC-13。以假薄殼(子類別覆寫)計數,全程不碰檔案。
extends GdUnitTestSuite


class FakeStore extends SettingsFileStore:
	var reads: int = 0
	var writes: int = 0
	var last_written: String = ""
	var canned: String = ""

	func read_text() -> String:
		reads += 1
		return canned

	func write_text(text: String) -> bool:
		writes += 1
		last_written = text
		return true


func before_test() -> void:
	GameSettings.reset_for_test()


func after_test() -> void:
	GameSettings.reset_for_test()


func test_persistence_off_by_default_setters_do_not_write() -> void:
	var fake: FakeStore = FakeStore.new()
	GameSettings.inject_store_without_enabling_for_test(fake)
	GameSettings.set_egm_enabled(true)
	GameSettings.set_master_volume(0.2)
	GameSettings.set_muted(true)
	assert_bool(GameSettings.is_persistence_enabled()).is_false()
	assert_int(fake.writes).is_equal(0)


func test_enabled_each_setter_writes_exactly_once_with_all_six_items() -> void:
	var fake: FakeStore = FakeStore.new()
	GameSettings.enable_persistence_for_test(fake)
	GameSettings.set_egm_enabled(true)
	assert_int(fake.writes).is_equal(1)
	GameSettings.set_hide_affinity_display(true)
	assert_int(fake.writes).is_equal(2)
	GameSettings.set_master_volume(0.3)
	assert_int(fake.writes).is_equal(3)
	GameSettings.set_music_volume(0.3)
	assert_int(fake.writes).is_equal(4)
	GameSettings.set_sfx_volume(0.3)
	assert_int(fake.writes).is_equal(5)
	GameSettings.set_muted(true)
	assert_int(fake.writes).is_equal(6)
	var decoded: Dictionary = SettingsCodec.decode(fake.last_written, GameSettings.default_values())
	assert_bool(bool(decoded[SettingsCodec.KEY_EGM])).is_true()
	assert_bool(bool(decoded[SettingsCodec.KEY_HIDE_AFFINITY])).is_true()
	assert_float(float(decoded[SettingsCodec.KEY_MASTER])).is_equal(0.3)
	assert_float(float(decoded[SettingsCodec.KEY_MUSIC])).is_equal(0.3)
	assert_float(float(decoded[SettingsCodec.KEY_SFX])).is_equal(0.3)
	assert_bool(bool(decoded[SettingsCodec.KEY_MUTED])).is_true()


func test_reset_after_enable_does_not_write_and_disables() -> void:
	var fake: FakeStore = FakeStore.new()
	GameSettings.enable_persistence_for_test(fake)
	GameSettings.reset_for_test()
	assert_int(fake.writes).is_equal(0)
	assert_bool(GameSettings.is_persistence_enabled()).is_false()
	GameSettings.set_muted(true)
	assert_int(fake.writes).is_equal(0)


func test_boot_load_in_headless_is_noop() -> void:
	var fake: FakeStore = FakeStore.new()
	assert_bool(GameSettings.boot_load(fake, true)).is_false()
	assert_int(fake.reads).is_equal(0)
	assert_int(fake.writes).is_equal(0)
	assert_bool(GameSettings.is_persistence_enabled()).is_false()


func test_headless_detection_true_under_test_run() -> void:
	# 全套測試以 --headless 跑,boot_load() 預設偵測依此判為 no-op,不會碰真實 user://。
	assert_str(DisplayServer.get_name()).is_equal("headless")


func test_boot_load_loads_once_when_called_twice() -> void:
	var fake: FakeStore = FakeStore.new()
	fake.canned = "[settings]\nmaster_volume=0.2\negm_enabled=true\n"
	assert_bool(GameSettings.boot_load(fake, false)).is_true()
	assert_bool(GameSettings.boot_load(fake, false)).is_false()
	assert_int(fake.reads).is_equal(1)
	assert_int(fake.writes).is_equal(0)
	assert_float(GameSettings.get_master_volume()).is_equal(0.2)
	assert_bool(GameSettings.is_egm_enabled()).is_true()
	assert_bool(GameSettings.is_persistence_enabled()).is_true()
