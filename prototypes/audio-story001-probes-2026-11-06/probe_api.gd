extends SceneTree
## 拋棄式探針:確認 AudioServer / linear_to_db / ConfigFile / headless 判斷法(story-001)。
## 只用暫存路徑,不碰 user://settings.cfg。headless 執行,必 quit()。

func _init() -> void:
	print("PROBE DisplayServer.get_name() = ", DisplayServer.get_name())
	print("PROBE bus_count(initial) = ", AudioServer.bus_count)
	for i in AudioServer.bus_count:
		print("PROBE bus[", i, "] name=", AudioServer.get_bus_name(i), " send=", AudioServer.get_bus_send(i))
	print("PROBE get_bus_index('Music') before = ", AudioServer.get_bus_index("Music"))
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_send(idx, "Master")
	print("PROBE after add: count=", AudioServer.bus_count, " idx('Music')=", AudioServer.get_bus_index("Music"), " send=", AudioServer.get_bus_send(idx))
	AudioServer.set_bus_volume_db(idx, -6.0)
	print("PROBE readback volume_db = ", AudioServer.get_bus_volume_db(idx))
	AudioServer.set_bus_mute(idx, true)
	print("PROBE readback mute = ", AudioServer.is_bus_mute(idx))
	print("PROBE linear_to_db(1.0)=", linear_to_db(1.0), " (0.5)=", linear_to_db(0.5), " (0.0)=", linear_to_db(0.0), " (0.0001)=", linear_to_db(0.0001))
	print("PROBE is_inf(linear_to_db(0.0)) = ", is_inf(linear_to_db(0.0)))

	var cf: ConfigFile = ConfigFile.new()
	cf.set_value("settings", "egm", true)
	cf.set_value("settings", "vol", 0.5)
	var text: String = cf.encode_to_text()
	print("PROBE encode_to_text = [", text, "]")
	var cf2: ConfigFile = ConfigFile.new()
	print("PROBE parse ok err = ", cf2.parse(text))
	print("PROBE roundtrip egm=", cf2.get_value("settings", "egm", "DEF"), " vol=", cf2.get_value("settings", "vol", "DEF"), " missing=", cf2.get_value("settings", "nokey", "DEF"))
	var cf3: ConfigFile = ConfigFile.new()
	print("PROBE parse garbage err = ", cf3.parse("@@@ not [ valid ==="))
	print("PROBE parse empty err = ", cf3.parse(""))
	var cf4: ConfigFile = ConfigFile.new()
	print("PROBE parse type-mismatch: ", cf4.parse("[settings]\nvol=\"abc\"\n"), " vol=", cf4.get_value("settings", "vol", "DEF"))
	quit()
