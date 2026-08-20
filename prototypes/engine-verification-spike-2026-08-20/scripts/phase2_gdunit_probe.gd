# ─────────────────────────────────────────────────────────────────────────────
# Phase 2 — GdUnit4 介面形狀探針
#
# 對應 tests/README.md「待驗證項」六項中的 1 / 3 / 4 / 5 / 6。
# (第 2 項 gdUnit4-action@v1 對 4.7.1 的支援只能在 CI 上驗,不在本 spike 範圍。)
#
# 刻意採**純內省**,不寫任何真的測試案例:
#   寫測試會需要先假設 GdUnitTestSuite 的名稱與 assert_* 的簽章 —— 而那兩件事
#   正是待驗證項本身。假設錯了會得到編譯期錯誤,而編譯期錯誤沒辦法告訴我們
#   「正確的名稱是什麼」。內省則會直接把實際存在的東西列出來。
#
# 前置:GdUnit4 必須已安裝到本 spike 專案(見 README「Phase 2」)。
# 未安裝時本探針不會失敗,只會如實回報「未安裝」。
# ─────────────────────────────────────────────────────────────────────────────
extends Node

# tests/gdunit4_runner.gd 目前逐一嘗試的四個候選路徑,逐字照抄以便直接對帳。
const RUNNER_CANDIDATES: Array[String] = [
	"res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
	"res://addons/gdunit4/bin/GdUnitCmdTool.gd",
	"res://addons/gdUnit4/GdUnitRunner.gd",
	"res://addons/gdunit4/GdUnitRunner.gd",
]


func _ready() -> void:
	_hr("=")
	print("PHASE 2 — GdUnit4 介面形狀探針")
	print("Godot: %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	_hr("=")
	print("把從這一行到結尾的全部輸出貼回對話。")
	print("")

	var installed := _section_addons_present()
	_section_runner_path()
	_section_global_classes()
	if installed:
		_section_runner_interface()
		_section_assertion_api()
	else:
		print("")
		print("GdUnit4 未安裝 —— 第 3 / 6 項無法探測。安裝方式見 README「Phase 2」。")

	_hr("=")
	print("PHASE 2 REPORT COMPLETE")
	_hr("=")
	get_tree().quit()


# ─── 第 4 項:整體是否安裝/載入 ──────────────────────────────────────────────
func _section_addons_present() -> bool:
	_section("P2-4", "GdUnit4 是否安裝、目錄實際結構(含大小寫)", "tests/README.md #4")
	if not DirAccess.dir_exists_absolute("res://addons"):
		print("  res://addons/ 不存在 —— GdUnit4 未安裝。")
		print("")
		return false

	var dirs := DirAccess.get_directories_at("res://addons")
	print("  res://addons/ 底下的目錄(**大小寫照實列出**,runner 的候選路徑要照這個對):")
	if dirs.is_empty():
		print("    (空)")
		print("")
		return false
	var found_gdunit := false
	for d in dirs:
		var mark := ""
		if "gdunit" in d.to_lower():
			mark = "   ← GdUnit4"
			found_gdunit = true
		print("    %s%s" % [d, mark])
		# 列出該 addon 的第一層內容,直接看見 bin/ 之類的實際結構
		for sub in DirAccess.get_directories_at("res://addons/" + d):
			print("        %s/" % sub)
		for f in DirAccess.get_files_at("res://addons/" + d):
			print("        %s" % f)
	print("")
	return found_gdunit


# ─── 第 1 項:CLI 入口路徑 ───────────────────────────────────────────────────
func _section_runner_path() -> void:
	_section("P2-1", "GdUnit4 CLI 入口的實際路徑", "tests/README.md #1")
	print("  tests/gdunit4_runner.gd 目前的四個候選路徑,逐一實測:")
	var any := false
	for p in RUNNER_CANDIDATES:
		var exists := ResourceLoader.exists(p)
		if exists:
			any = true
		print("    [%s]  %s" % ["FOUND  " if exists else "MISSING", p])
	print("")
	if any:
		print("  → 至少一個候選命中。把命中的那一條記回 tests/README.md 第 1 項。")
	else:
		print("  → 四個全落空。這正是 runner 設計成 fail-loud 的情境(quit(1)),")
		print("     不是靜默通過。請從上方 P2-4 的實際目錄結構找出真正的入口檔,")
		print("     再更新 RUNNER_CANDIDATES。")
	print("")


# ─── 第 5 項:GdUnitTestSuite 基底類別名稱 ──────────────────────────────────
func _section_global_classes() -> void:
	_section("P2-5", "GdUnit4 註冊的全域 class_name(找出測試基底類別真名)", "tests/README.md #5")
	var hits := 0
	for entry in ProjectSettings.get_global_class_list():
		var cls: String = str(entry.get("class", ""))
		if "gdunit" in cls.to_lower():
			hits += 1
			print("    class=%-32s base=%-24s path=%s" % [
				cls, str(entry.get("base", "")), str(entry.get("path", ""))
			])
	if hits == 0:
		print("    (零筆 —— GdUnit4 未安裝,或未註冊任何全域 class_name)")
	print("")
	print("  判讀:tests/unit/harness/harness_selfcheck_test.gd 寫 `extends GdUnitTestSuite`。")
	print("        上面若列出的名稱不是 GdUnitTestSuite,那一行必須改 —— 屬編譯期錯誤,")
	print("        不會靜默,但會擋下整個檔案。")
	print("")


# ─── 第 3 項:run_tests() 的回傳型別 ────────────────────────────────────────
func _section_runner_interface() -> void:
	_section("P2-3", "CLI 入口的方法清單與 run_tests() 回傳型別", "tests/README.md #3")
	var runner_path := ""
	for p in RUNNER_CANDIDATES:
		if ResourceLoader.exists(p):
			runner_path = p
			break
	if runner_path.is_empty():
		print("  找不到入口(見 P2-1),本項跳過。")
		print("")
		return

	var s = load(runner_path)
	if s == null:
		print("  入口檔存在但**載入失敗** —— 見上方引擎錯誤。")
		print("  這是 tests/README.md 第 4 項(GdUnit4 對 4.7.1 的整體相容性)的直接證據。")
		print("")
		return

	print("  入口檔:%s  (載入成功)" % runner_path)
	print("  ── 該腳本宣告的方法 ──")
	var has_run_tests := false
	for m in s.get_script_method_list():
		var mname: String = str(m.get("name", ""))
		if mname.begins_with("_") and mname != "_init":
			continue
		var ret: Dictionary = m.get("return", {})
		var ret_type := _type_name(int(ret.get("type", 0)))
		if mname == "run_tests":
			has_run_tests = true
			print("    %-30s -> %s     ← runner 假設的入口" % [mname, ret_type])
		else:
			print("    %-30s -> %s" % [mname, ret_type])
	print("")
	if has_run_tests:
		print("  → run_tests() 存在。上面的回傳型別就是 tests/README.md 第 3 項的答案。")
		print("     gdunit4_runner.gd 目前同時處理 int 與 bool,無法判讀時視為失敗;")
		print("     若實際型別是第三種,那段判讀邏輯要補。")
	else:
		print("  → **run_tests() 不存在**。gdunit4_runner.gd 的核心假設不成立,")
		print("     該檔的 has_method() 守衛會讓它 quit(1)(fail-loud,不是假綠燈),")
		print("     但整個入口方式需要照上面的實際方法清單重寫。")
	print("")


# ─── 第 6 項:assert_failure() 的 API 形狀 ──────────────────────────────────
func _section_assertion_api() -> void:
	_section("P2-6", "assert_failure() 等斷言 API 的實際簽章", "tests/README.md #6")
	var suite_path := ""
	for entry in ProjectSettings.get_global_class_list():
		var cls: String = str(entry.get("class", ""))
		if cls.to_lower() == "gdunittestsuite":
			suite_path = str(entry.get("path", ""))
			break
	if suite_path.is_empty():
		print("  找不到 GdUnitTestSuite 的註冊路徑(見 P2-5),本項跳過。")
		print("")
		return

	var s = load(suite_path)
	if s == null:
		print("  %s 載入失敗 —— 見上方引擎錯誤。" % suite_path)
		print("")
		return

	print("  GdUnitTestSuite: %s" % suite_path)
	print("  ── 名稱含 'assert' 的方法及其參數 ──")
	var hits := 0
	for m in s.get_script_method_list():
		var mname: String = str(m.get("name", ""))
		if not ("assert" in mname.to_lower()):
			continue
		hits += 1
		var args: Array = m.get("args", [])
		var sig := PackedStringArray()
		for a in args:
			sig.append("%s: %s" % [str(a.get("name", "?")), _type_name(int(a.get("type", 0)))])
		var ret: Dictionary = m.get("return", {})
		print("    %s(%s) -> %s" % [mname, ", ".join(sig), _type_name(int(ret.get("type", 0)))])
	if hits == 0:
		print("    (零筆 —— 斷言可能定義在別的類別或以其他方式提供)")
	print("")
	print("  判讀:tests/unit/harness/harness_selfcheck_test.gd 用")
	print("        `assert_failure(Callable).is_failed()` 驗證「框架真的會判失敗」。")
	print("        上面若沒有 assert_failure,或簽章不符,該項自我檢查要改寫。")
	print("")


# ─── 工具 ────────────────────────────────────────────────────────────────────
func _type_name(t: int) -> String:
	# type_string() 是 4.x 的內建函式;若此版本沒有,退回印數字。
	if t == 0:
		return "Variant/void"
	return type_string(t)


func _hr(ch: String) -> void:
	print(ch.repeat(78))


func _section(id: String, title: String, source: String) -> void:
	print("")
	_hr("-")
	print("[%s] %s" % [id, title])
	print("     來源:%s" % source)
	_hr("-")
