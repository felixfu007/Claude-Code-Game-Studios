## audio-foundation story-001 AC-3 / AC-4 / AC-5。headless 下音訊輸出是 no-op,
## 只驗決策值與 AudioServer 可讀回的 bus 結構,不斷言「真的響了」。
## 註:ensure_buses() 會在全域 AudioServer 加三條 bus(冪等,之後各測試共用,無害)。
extends GdUnitTestSuite


func test_volume_to_db_full_is_zero() -> void:
	assert_float(AudioBuses.volume_to_db(1.0)).is_equal(0.0)


func test_volume_to_db_zero_is_finite_silent_value() -> void:
	var db: float = AudioBuses.volume_to_db(0.0)
	assert_float(db).is_equal(AudioBuses.SILENT_DB)
	assert_bool(is_nan(db) or is_inf(db)).is_false()


func test_volume_to_db_nan_and_out_of_range_are_safe() -> void:
	assert_float(AudioBuses.volume_to_db(NAN)).is_equal(AudioBuses.SILENT_DB)
	assert_float(AudioBuses.volume_to_db(-3.0)).is_equal(AudioBuses.SILENT_DB)
	assert_float(AudioBuses.volume_to_db(5.0)).is_equal(0.0)


func test_volume_to_db_monotonic() -> void:
	var prev: float = AudioBuses.volume_to_db(0.0)
	for v: float in [0.001, 0.01, 0.1, 0.25, 0.5, 0.75, 1.0]:
		var cur: float = AudioBuses.volume_to_db(v)
		assert_bool(cur > prev).is_true()
		prev = cur


func test_mute_decision_true_for_all_buses_and_volumes_untouched() -> void:
	var state: Dictionary = AudioBuses.compute_bus_state(0.7, 0.5, 0.3, true)
	for bus_name: StringName in [AudioBuses.BUS_MASTER, AudioBuses.BUS_MUSIC, AudioBuses.BUS_SFX, AudioBuses.BUS_UI]:
		assert_bool(bool(state[bus_name]["mute"])).is_true()
	# 靜音與否不影響 dB 值(音量值未被改寫)
	var unmuted: Dictionary = AudioBuses.compute_bus_state(0.7, 0.5, 0.3, false)
	for bus_name: StringName in state:
		assert_float(float(state[bus_name]["db"])).is_equal(float(unmuted[bus_name]["db"]))
		assert_bool(bool(unmuted[bus_name]["mute"])).is_false()


func test_ensure_buses_creates_three_children_sent_to_master() -> void:
	AudioBuses.ensure_buses()
	assert_str(AudioBuses.BUS_MUSIC).is_equal("Music")
	assert_str(AudioBuses.BUS_SFX).is_equal("SFX")
	assert_str(AudioBuses.BUS_UI).is_equal("UI")
	for bus_name: StringName in AudioBuses.CHILD_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_bool(idx >= 0).is_true()
		assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")


func test_ensure_buses_is_idempotent() -> void:
	AudioBuses.ensure_buses()
	var count_before: int = AudioServer.bus_count
	AudioBuses.ensure_buses()
	AudioBuses.ensure_buses()
	assert_int(AudioServer.bus_count).is_equal(count_before)
