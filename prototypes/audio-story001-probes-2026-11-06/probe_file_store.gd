extends SceneTree
## AC-14 探針:SettingsFileStore 檔案層。只用暫存路徑,絕不碰 user://settings.cfg。
## 檔案放在 OS 暫存目錄(由命令列 -- 後參數注入)。

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else ""
	if dir.is_empty():
		print("PROBE ABORT: need temp dir arg")
		quit(2)
		return
	var path: String = dir + "/probe_settings.cfg"
	var store: SettingsFileStore = SettingsFileStore.new(path)
	print("PROBE path = ", path, "  default path untouched = ", SettingsFileStore.DEFAULT_PATH)
	print("PROBE read missing file -> [", store.read_text(), "] (expect empty)")
	var d: Dictionary = GameSettings.default_values()
	d[SettingsCodec.KEY_EGM] = true
	d[SettingsCodec.KEY_MASTER] = 0.25
	d[SettingsCodec.KEY_MUTED] = true
	var text: String = SettingsCodec.encode(d)
	print("PROBE write ok = ", store.write_text(text))
	var back: String = store.read_text()
	print("PROBE read back text equals written = ", back == text)
	var dec: Dictionary = SettingsCodec.decode(back, GameSettings.default_values())
	print("PROBE roundtrip equal = ", dec == d, " egm=", dec[SettingsCodec.KEY_EGM], " master=", dec[SettingsCodec.KEY_MASTER], " muted=", dec[SettingsCodec.KEY_MUTED])
	var bad: SettingsFileStore = SettingsFileStore.new(dir + "/no_such_dir/x.cfg")
	print("PROBE write to impossible path -> ", bad.write_text("x"), " (expect false, no crash)")
	# boot_load 以注入薄殼(非 headless 覆寫)走真實檔案層
	GameSettings.reset_for_test()
	print("PROBE boot_load(real store, headless=false) = ", GameSettings.boot_load(store, false), " master=", GameSettings.get_master_volume(), " egm=", GameSettings.is_egm_enabled())
	GameSettings.set_master_volume(0.5)
	print("PROBE after setter, file master -> ", SettingsCodec.decode(store.read_text(), GameSettings.default_values())[SettingsCodec.KEY_MASTER], " (expect 0.5)")
	print("PROBE bus count after boot_load = ", AudioServer.bus_count, " music mute=", AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	GameSettings.reset_for_test()
	DirAccess.remove_absolute(path)
	quit()
