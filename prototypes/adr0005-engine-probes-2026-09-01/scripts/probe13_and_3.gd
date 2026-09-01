extends Node
# ADR-0005 Probe #13 + #3 —— 兩項都是零外部依賴、可 headless 執行的安全探針。
# 不宣告 class_name(拋棄式探針,避免額外要求 --import 重建 class_name 快取)。

func _ready() -> void:
	_hr("=")
	print("ADR-0005 ENGINE PROBES — SAFE/HEADLESS SECTION (#13 echo filter, #3 agile flushing key)")
	print("日期:2026-09-01  Godot: %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	_hr("=")
	_probe_13_echo_filter()
	_probe_3_agile_flushing_key()
	_hr("=")
	print("REPORT COMPLETE (safe section)")
	_hr("=")
	get_tree().quit()


func _probe_13_echo_filter() -> void:
	_section("13", "InputMap.event_is_action() 是否過濾 InputEventKey.echo", "ADR-0005 VR #13")
	if not InputMap.has_action("ui_up"):
		print("  !! InputMap 沒有內建 action 'ui_up' —— 環境異常,無法測試")
		return

	var e_first := InputEventKey.new()
	e_first.keycode = KEY_UP
	e_first.physical_keycode = KEY_UP
	e_first.pressed = true
	e_first.echo = false

	var e_echo := InputEventKey.new()
	e_echo.keycode = KEY_UP
	e_echo.physical_keycode = KEY_UP
	e_echo.pressed = true
	e_echo.echo = true

	var e_released := InputEventKey.new()
	e_released.keycode = KEY_UP
	e_released.physical_keycode = KEY_UP
	e_released.pressed = false
	e_released.echo = false

	var r_first: bool = InputMap.event_is_action(e_first, "ui_up")
	var r_echo: bool = InputMap.event_is_action(e_echo, "ui_up")
	var r_released: bool = InputMap.event_is_action(e_released, "ui_up")

	print("  event_is_action(pressed=true,  echo=false, ui_up) = %s" % str(r_first))
	print("  event_is_action(pressed=true,  echo=true,  ui_up) = %s" % str(r_echo))
	print("  event_is_action(pressed=false, echo=false, ui_up) = %s   (對照組:放開鍵)" % str(r_released))
	print("")

	if r_first and r_echo:
		print("  判定:echo 事件【沒有】被 event_is_action() 過濾 —— pressed+echo=true 與")
		print("        pressed+echo=false 回傳結果相同(皆 true)。機制四之二 classify_action()")
		print("        若不自行加 `event is InputEventKey and event.echo` 過濾,玩家按住方向鍵")
		print("        產生的每一個重複事件都會被判為 NAVIGATION、每一影格都主張裝置權威。")
		print("        ADR-0005 第 404-406 行的疑慮成立,VR #13 由『未查證』轉為『已查證:不過濾』。")
	elif r_first and not r_echo:
		print("  判定:echo 事件【被】event_is_action() 過濾 —— echo=true 時回傳 false。")
		print("        機制四之二不需要自行加過濾;VR #13 由『未查證』轉為『已查證:有過濾』。")
	else:
		print("  判定:非預期組合(r_first=%s, r_echo=%s)—— 需要人工檢視,可能是 ui_up 的實際綁定與假設不符。" % [str(r_first), str(r_echo)])
	print("")


func _probe_3_agile_flushing_key() -> void:
	_section("3", "Agile Event Flushing 設定鍵真名(corroborate 2026-08-20 spike F-4)", "ADR-0005 VR #3")
	var guess := "input_devices/buffering/agile_event_flushing"
	print("  ADR-0005 推測鍵名    : %s" % guess)
	print("  has_setting(推測值)  : %s" % str(ProjectSettings.has_setting(guess)))
	if ProjectSettings.has_setting(guess):
		print("  get_setting(推測值)  : %s" % str(ProjectSettings.get_setting(guess)))
	print("")
	print("  ── 名稱以 'input_devices' 開頭的全部已知鍵(交叉核對)──")
	var found := 0
	for p in ProjectSettings.get_property_list():
		var n: String = str(p.get("name", ""))
		if n.begins_with("input_devices"):
			found += 1
			var val: String = "<no value>"
			if ProjectSettings.has_setting(n):
				val = str(ProjectSettings.get_setting(n))
			print("    %s = %s" % [n, val])
	if found == 0:
		print("    (零筆 —— get_property_list() 只列出已顯式設定過的鍵,零筆不代表不存在)")
	print("")


func _section(id: String, title: String, source: String) -> void:
	print("")
	_hr("-")
	print("[%s] %s" % [id, title])
	print("     來源:%s" % source)
	_hr("-")


func _hr(ch: String) -> void:
	print(ch.repeat(78))
