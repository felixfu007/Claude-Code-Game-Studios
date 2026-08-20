# ─────────────────────────────────────────────────────────────────────────────
# Engine Verification Spike — 主控腳本
#
# 設計原則(這四條是刻意的,別「順手優化」掉):
#
#   1. 逐項即時列印,不緩衝到最後才輸出。
#      有兩項檢查可能讓執行期直接中止;若緩衝輸出,中止就會把前面全部的結果一起吃掉。
#
#   2. 兩項有中止風險的檢查排在最後,且各自先印一行橫幅。
#      **報告在橫幅之後就斷掉,本身就是答案**(代表該操作導致硬中止)。
#
#   3. 任何「是否存在於 4.7.1」未經查證的 API,一律隔離到獨立檔案並用 load() 動態載入。
#      靜態型別下呼叫不存在的方法是**編譯期**錯誤,會把整個 runner 一起弄爆;
#      隔離之後,「那一檔編譯失敗」是一筆乾淨的結果,不污染其他檢查。
#
#   4. 對 load() 回傳值一律用**未標型別**的 var 承接(`var s = load(...)` 而非 `:=`)。
#      load() 的靜態回傳型別是 Resource,對它呼叫 build()/run() 會編譯失敗。
#      用 Variant 承接才能走執行期動態派發。
# ─────────────────────────────────────────────────────────────────────────────
extends Node

const SCRIPTS := "res://scripts/"

# c2 探針以 preload 取得類別,這樣 probe.make_capturing_lambda() 才有靜態型別可解析。
# (若寫成 Node.new(),靜態分析會判定 Node 上沒有該方法 → 編譯失敗。)
const CallableProbe := preload("res://scripts/c2_callable_probe.gd")

var _named_after_free: Callable
var _lambda_after_free: Callable


func _ready() -> void:
	_hr("=")
	print("ENGINE VERIFICATION SPIKE — 2026-08-20")
	print("Godot version string : %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	print("Version info         : %s" % str(Engine.get_version_info()))
	print("DisplayServer        : %s" % DisplayServer.get_name())
	_hr("=")
	print("把從這一行到結尾的全部輸出貼回對話即可。")
	print("**引擎的紅色錯誤訊息也要一起貼** —— 那些是證據,不是雜訊。")
	print("")

	_section_a3_pow()
	_section_a2_enum_key()
	_section_c3_project_settings()
	_section_c1_abstract()
	_section_a1_typed_dict_safe()
	await _section_c2_callable_validity()

	_hr("=")
	print("以上為安全區段,全部完成。以下兩項有硬中止風險。")
	_hr("=")

	_risky_1_callable_call_after_free()
	_risky_2_typed_dict_dynamic()

	_hr("=")
	print("REPORT COMPLETE — 全部檢查跑完,無硬中止。")
	_hr("=")
	get_tree().quit()


# ─── A3 ──────────────────────────────────────────────────────────────────────
func _section_a3_pow() -> void:
	_section("A3", "pow(0.0, 0.0) 的實際回傳值", "ADR-0002 VR #3")
	var s = load(SCRIPTS + "a3_pow_zero_probe.gd")
	if s == null:
		print("  !! 探針編譯失敗 —— 見上方引擎錯誤")
		print("")
		return
	_print_dict(s.run())
	print("")
	print("  判讀:GDD Formulas 明文『不可依賴引擎預設行為』。即使這裡回傳 1.0,")
	print("        ADR-0002 公式一/二仍應顯式特判 —— 本項的用途是決定特判的**理由**寫成")
	print("        「引擎行為與 0^0:=1 慣例一致但不保證」還是「引擎行為與慣例相反」。")
	print("")


# ─── A2 ──────────────────────────────────────────────────────────────────────
func _section_a2_enum_key() -> void:
	_section("A2", "enum 當 Dictionary 鍵的雜湊/相等語意", "ADR-0002 VR #2")
	var s = load(SCRIPTS + "a2_enum_key_probe.gd")
	if s == null:
		print("  !! 探針編譯失敗 —— 見上方引擎錯誤")
		print("")
		return
	_print_dict(s.run())
	print("")
	print("  關鍵判讀 —— 看 lookup_with_raw_int_0 這一列:")
	print("    · 若為 inserted_with_enum → enum 鍵在底層就是 int,裸 int 可以命中 enum 鍵。")
	print("      型別化 Dictionary 的鍵檢查對此**無能為力**,ADR-0002 機制四的『型別安全』")
	print("      只到靜態分析為止,執行期沒有防線。")
	print("    · 若為 <MISS> → enum 是獨立的鍵型別,型別化字典的保證是真的。")
	print("")
	print("  另看 cross_enum_family_size:若為 1,代表兩個不同 enum 家族的相同序數值會")
	print("  互相覆蓋。ADR-0002 的 _records 用 Pair、_death_marks 用 Character,兩張表")
	print("  各自獨立所以目前安全 —— 但這是必須寫下來的限制,不是可以假設的事。")
	print("")


# ─── C3 ──────────────────────────────────────────────────────────────────────
func _section_c3_project_settings() -> void:
	_section("C3", "Agile Event Flushing 的設定鍵真名", "ADR-0005 VR #3")
	var guess := "input_devices/buffering/agile_event_flushing"
	print("  ADR-0005 推測的鍵名 : %s" % guess)
	print("  has_setting(推測值)  : %s" % str(ProjectSettings.has_setting(guess)))
	print("")
	print("  ── 實際存在、名稱以 'input_devices' 開頭的全部鍵 ──")
	_dump_settings_matching("input_devices", true)
	print("")
	print("  ── 名稱含 'agile' 或 'flush' 的任何鍵(不限前綴)──")
	_dump_settings_matching("agile|flush", false)
	print("")
	print("  判讀:機制七目前以 has_setting() 防衛,鍵不存在時回報")
	print("        AGILE_FLUSHING_SETTING_KEY_UNKNOWN 而非視為通過 —— 那個防衛必須保留。")
	print("        上面若掃出真名,ADR-0005 可以把推測值換成已查證值(防衛仍不移除)。")
	print("")


func _dump_settings_matching(pattern: String, is_prefix: bool) -> void:
	var found := 0
	for p in ProjectSettings.get_property_list():
		var n: String = str(p.get("name", ""))
		if n.is_empty():
			continue
		var hit := false
		if is_prefix:
			hit = n.begins_with(pattern)
		else:
			var low := n.to_lower()
			for frag in pattern.split("|"):
				if frag in low:
					hit = true
					break
		if not hit:
			continue
		found += 1
		var val := "<has_setting=false>"
		if ProjectSettings.has_setting(n):
			val = str(ProjectSettings.get_setting(n))
		print("    %s = %s" % [n, val])
	if found == 0:
		print("    (零筆)")
		print("    注意:get_property_list() 只列出已註冊/已顯式設定者。零筆**不代表**")
		print("    該設定不存在 —— 這種情況下 has_setting() 的結果才是唯一有效證據。")


# ─── C1 ──────────────────────────────────────────────────────────────────────
func _section_c1_abstract() -> void:
	_section("C1", "@abstract 的正確語法與各回傳型別", "ADR-0005 VR #1 / R4-2、ADR-0004 VR #6 / #6a")
	print("  2026-08-20 第一次執行已確定:參考庫 current-best-practices.md 第 41-49 行的")
	print("  「冒號 + pass 主體」形式在 4.7.1 是 parser error。本輪改測裸簽章形式,")
	print("  並保留一檔錯誤寫法作為永久證據。")
	print("")

	print("  ── (0) 已知錯誤形式(保留為證據,預期 FAILED)──")
	_load_report("冒號 + pass 主體 —— 參考庫範例的逐字照抄", "c1_pass_body_record.gd")

	print("")
	print("  ── (1) 裸簽章形式,各回傳型別分別編譯 ──")
	print("      第五輪明文要求「各建一檔分別編譯,不可只測一種外推」。")
	var entries := [
		["Array[T]   ←對照組", "c1_bare_array_control.gd"],
		["bool", "c1_bare_bool.gd"],
		["float", "c1_bare_float.gd"],
		["void", "c1_bare_void.gd"],
		["Vector2    ←R4-2 BLOCKING 修法所依賴者", "c1_bare_vector2.gd"],
		["類別內同時有 signal + 兩個 @abstract func(MouseReclaimPolicy 的實際形狀)", "c1_bare_with_signal.gd"],
	]
	for entry in entries:
		_load_report(str(entry[0]), str(entry[1]))

	print("")
	print("  ── (2) 語法變體:@abstract 與 func 同一行 ──")
	_load_report("@abstract func inline_declared() -> bool", "c1_syntax_inline.gd")
	print("      若兩種都可以,ADR 有選擇自由;若只有一種可以,那一種必須寫進 ADR,")
	print("      不能留給實作者猜。")

	print("")
	print("  ── (3) ADR-0004 VR #6a:子類別漏實作抽象方法,是編譯期還是執行期錯誤 ──")
	_load_report("完整實作全部抽象方法(對照組)", "c1_subclass_complete.gd")
	_load_report("**故意漏實作** diagnostic_seed_position()", "c1_subclass_incomplete.gd")
	print("      判讀:漏實作那一檔若 FAILED → 編譯期錯誤,@abstract 的「保證子類別必須")
	print("            實作」是**結構保證**。若 COMPILED OK → 只在該方法被呼叫時才於執行期")
	print("            顯現,那個保證就只是「呼叫到才會爆」,ADR-0004/0005 的相關宣稱要改寫。")
	print("")


func _load_report(label: String, filename: String) -> void:
	var res = load(SCRIPTS + filename)
	var verdict := "COMPILED OK       " if res != null else "FAILED TO COMPILE "
	print("    [%s]  %s" % [verdict, label])


# ─── A1(安全部分)─────────────────────────────────────────────────────────
func _section_a1_typed_dict_safe() -> void:
	_section("A1", "型別化 Dictionary[K,V] 的鍵值型別檢查在哪一層生效", "ADR-0002 VR #1")

	print("  (a) 正確用法 —— ADR-0002 機制四的真實宣告")
	print("      Dictionary[AffinityTypes.Pair, Array[AffinityRecord]]")
	var ok_script = load(SCRIPTS + "a1_typed_dict_ok.gd")
	if ok_script == null:
		print("      !! FAILED TO COMPILE —— 這是 BLOCKING:")
		print("         ADR-0002 的核心資料結構在 4.7.1 寫不出來。見上方引擎錯誤。")
	else:
		var d: Dictionary = ok_script.build()
		print("      [COMPILED OK] size = %d" % d.size())
		print("      巢狀型別(enum 當鍵、Array[Class] 當值)可宣告且可插入。")
		_introspect_dictionary(d)

	print("")
	print("  (b) 靜態可見的錯誤**鍵**型別(字面量 String 當鍵)—— 只 load,不執行")
	var bad_k = load(SCRIPTS + "a1_typed_dict_bad_key_static.gd")
	if bad_k == null:
		print("      FAILED TO COMPILE  → 編譯期就擋下,靜態鍵型別檢查是真的")
	else:
		print("      COMPILED OK        → 編譯期**沒有**擋下;只可能在執行期擋(見 RISKY 2)")

	print("")
	print("  (c) 靜態可見的錯誤**值**型別(int 當值)—— 只 load,不執行")
	var bad_v = load(SCRIPTS + "a1_typed_dict_bad_value_static.gd")
	if bad_v == null:
		print("      FAILED TO COMPILE  → 編譯期就擋下")
	else:
		print("      COMPILED OK        → 編譯期**沒有**擋下")
	print("")


func _introspect_dictionary(d: Dictionary) -> void:
	print("      ── 容器內省(隔離在 a1_introspect.gd,失敗不影響其他檢查)──")
	var probe = load(SCRIPTS + "a1_introspect.gd")
	if probe == null:
		print("        探針編譯失敗 → 4.7.1 沒有 is_typed_key()/get_typed_key_builtin()")
		print("        這一族內省 API。這不是缺陷,只是無法從執行期確認型別標記。")
		return
	_print_dict(probe.run(d), "        ")


# ─── C2(安全部分:只讀 is_valid(),不呼叫)────────────────────────────────
func _section_c2_callable_validity() -> void:
	_section("C2", "Callable.is_valid() 對已釋放綁定物件的偵測行為", "ADR-0005 VR #15 / S-1 / 發現 G")

	var probe := CallableProbe.new()
	probe.name = "CallableProbe"
	add_child(probe)

	var named := Callable(probe, "probe_value")
	var lambda: Callable = probe.make_capturing_lambda()

	print("  釋放前:")
	print("    named.is_valid()  = %s" % str(named.is_valid()))
	print("    lambda.is_valid() = %s" % str(lambda.is_valid()))
	print("    named.call()      = %s" % str(named.call()))
	print("    lambda.call()     = %s" % str(lambda.call()))

	probe.queue_free()
	# queue_free() 是延後釋放 —— 必須等影格,否則測到的是還活著的物件。
	await get_tree().process_frame
	await get_tree().process_frame

	print("")
	print("  queue_free() + 等兩個影格後:")
	print("    is_instance_valid(probe) = %s" % str(is_instance_valid(probe)))
	print("    named.is_valid()         = %s    ←具名綁定 Callable(obj, \"method\")" % str(named.is_valid()))
	print("    lambda.is_valid()        = %s    ←lambda 隱式捕獲 self" % str(lambda.is_valid()))
	print("")
	print("  判讀:S-1 的整套防禦(_safe_mouse_position() 每次取值前 is_valid())押在")
	print("        『is_valid() 會回傳 false』上。上面兩列若有任何一列是 true,該防禦")
	print("        形同虛設,Validation Criteria #18 驗的是一個不成立的假設。")
	print("        兩列若**不一致**,就證實了發現 G:具名綁定與 lambda 行為確實不同,")
	print("        第三次修訂改採具名綁定是對的(而且是必要的,不只是比較明確)。")
	print("")

	_named_after_free = named
	_lambda_after_free = lambda


# ─── 有中止風險的兩項 ────────────────────────────────────────────────────────
func _risky_1_callable_call_after_free() -> void:
	_hr("!")
	print("RISKY 1/2 —— 對已釋放物件的 Callable 實際呼叫 call()")
	print("若報告在這一行之後就斷掉,答案就是:call() 造成硬中止(而非乾淨地失敗)。")
	print("那本身就是 VR #15 要的結論之一,不算 spike 失敗 —— 照樣把輸出貼回來。")
	_hr("!")
	print("  named.call()  → %s" % str(_named_after_free.call()))
	print("  lambda.call() → %s" % str(_lambda_after_free.call()))
	print("  (兩行都印出來 = 沒有硬中止;回傳值本身也是證據)")
	print("")


func _risky_2_typed_dict_dynamic() -> void:
	_hr("!")
	print("RISKY 2/2 —— 經 Variant 藏起來的錯誤鍵/值,實際寫入型別化 Dictionary")
	print("這是 A1 的執行期那一半:編譯器看不見,只有執行期檢查能擋。")
	print("若報告在這一行之後就斷掉 = 執行期檢查以硬中止的方式生效。")
	_hr("!")
	var s = load(SCRIPTS + "a1_typed_dict_bad_dynamic.gd")
	if s == null:
		print("  探針編譯失敗(不預期)—— 見上方錯誤")
		print("")
		return
	print("  嘗試寫入錯誤**鍵**...")
	s.run_bad_key()
	print("    → 沒有硬中止(引擎錯誤訊息若有,見上方)")
	print("  嘗試寫入錯誤**值**...")
	s.run_bad_value()
	print("    → 沒有硬中止(引擎錯誤訊息若有,見上方)")
	print("")


# ─── 排版工具 ────────────────────────────────────────────────────────────────
func _hr(ch: String) -> void:
	print(ch.repeat(78))


func _section(id: String, title: String, source: String) -> void:
	print("")
	_hr("-")
	print("[%s] %s" % [id, title])
	print("     來源:%s" % source)
	_hr("-")


func _print_dict(d: Dictionary, indent: String = "    ") -> void:
	for k in d.keys():
		print("%s%-26s = %s" % [indent, str(k), str(d[k])])
