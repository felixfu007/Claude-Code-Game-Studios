## Story-001(支援對話系統,規格 AC-6／OBL-009):好感度池寫入介面的呼叫點
## 在支援對話系統裡恰好 1 處。
##
## 🔴 [b]這是乙類(原始碼紀律掃描)例外[/b],依 `.claude/rules/test-standards.md`
## 2026-09-16 裁決 —— 必要揭露:
## [br]
## 1. [b]無法用依賴注入或執行期檢查取代[/b]:「原始碼裡有幾處呼叫點」是文字層級的
##    事實,不是任何物件的執行期行為 —— 一個被呼叫兩次的函式,與兩個各自只呼叫
##    一次的獨立呼叫點,從外部黑箱觀察完全無法區分。只有讀原始碼文字能分得出來。
## 2. [b]掃描範圍刻意限定在 res://src/gameplay/narrative[/b] —— 本系統(系統 #8)的
##    整個邏輯層只住在這個目錄(本 story 的全部交付檔案),這正是規格 AC-6「篩出屬於
##    支援對話系統的部分」這句話的具體作法。本檔自身住在 res://tests,結構上不可能
##    掃到自己。
## 3. [b]比對手法刻意不是 shell grep[/b](本專案 2026-10-12 登記的陷阱:
##    「一條寫在註解裡的 grep 指令會命中它自己那一行」,且 `grep -v ":#"` 只能過濾
##    [b]行首沒有縮排[/b]的註解,縮排後的 `\t## ...` 不會被攔到)。本檔改用
##    [method _scan_line] 對每一行先 [method String.strip_edges] 再檢查是否以
##    [code]#[/code] 開頭 —— 不論縮排多深,任何純註解行都會被排除,結構上不可能把
##    文件註解裡提到「呼叫寫入埠」的文字算成一次呼叫。
## 4. [b]已知缺口(誠實揭露,非窮盡性證明)[/b]:本掃描只數「呼叫端」(
##    [code].append_record([/code] 前面緊接一個點號),不數「宣告端」(
##    [code]func append_record([/code] 前面沒有點號,天生不計入,見
##    [method test_sensitivity_proof_ignores_the_abstract_declaration_itself])。
##    未來 story-002 接上真實轉場系統時,若在 [code]res://src/gameplay/narrative[/code]
##    [b]以外[/b]另開一個呼叫點(例如轉場管理器繞過
##    [method SupportConversationRules.trigger] 直接呼叫寫入埠),本測試攔不到 ——
##    這是刻意的窄範圍(本 story 的交付範圍就是這個目錄),不是疏漏。
extends GdUnitTestSuite


const _SCAN_ROOT: String = "res://src/gameplay/narrative"

## 要求 [code].append_record([/code] 前面緊接一個點號才算呼叫 —— 藉此排除
## [code]func append_record(...)[/code] 宣告本身(宣告前面沒有點)。
const _CALL_SITE_PATTERN: String = "\\.append_record\\("


func test_support_conversation_write_port_call_site_count_equals_one() -> void:
	# Arrange
	var call_site_regex := RegEx.new()
	var compile_error: Error = call_site_regex.compile(_CALL_SITE_PATTERN)
	assert_int(compile_error).append_failure_message(
		"本測試自己的呼叫點比對 RegEx 編譯失敗(error %s)—— 掃描本身壞掉,"
		% error_string(compile_error)
		+ "這跟正式程式碼無關,先修比對式。"
	).is_equal(OK)

	# Act
	var matches: Array = []
	_scan_dir(_SCAN_ROOT, call_site_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(_match_message(matches)).is_equal(1)


func _match_message(matches: Array) -> String:
	var lines: Array = []
	for m in matches:
		lines.append("  %s:%d: %s" % [m["path"], m["line"], m["text"]])
	return (
		"規格 AC-6(OBL-009)要求 SupportConversationWritePort.append_record() 在支援對話"
		+ "系統(res://src/gameplay/narrative)內恰好被呼叫 1 次。找到 %d 處:\n%s\n"
		+ "0 處代表漏接(觸發邏輯忘了寫入);2 處以上代表呼叫點分散、難以稽核 —— "
		+ "兩者都是規格明文要避免的情況。"
	) % [matches.size(), "\n".join(lines)]


func _scan_dir(dir_path: String, call_site_regex: RegEx, matches: Array) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_error(
			"support_conversation_write_call_site_count_test: 無法開啟目錄 '%s'" % dir_path
		)
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full_path, call_site_regex, matches)
		elif entry.ends_with(".gd"):
			_scan_file(full_path, call_site_regex, matches)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_file(file_path: String, call_site_regex: RegEx, matches: Array) -> void:
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error(
			(
				"support_conversation_write_call_site_count_test: 無法讀取 '%s'(error %s)—— "
				+ "本檔會被當成零處理,可能悄悄低估。"
			) % [file_path, error_string(FileAccess.get_open_error())]
		)
		return
	var line_number: int = 0
	while not f.eof_reached():
		var raw_line: String = f.get_line()
		line_number += 1
		_scan_line(file_path, line_number, raw_line, call_site_regex, matches)


## 純函式、不碰檔案系統 —— 與 [method _scan_file](真實檔案)及本檔的
## test_sensitivity_proof_* 案例(合成文字)共用同一份邏輯,敏感度證明測的是真正的
## 掃描邏輯,不是另一份可能悄悄分岔的複本。
func _scan_line(
	source_label: String, line_number: int, raw_line: String, call_site_regex: RegEx, matches: Array
) -> void:
	var trimmed: String = raw_line.strip_edges()
	if trimmed.begins_with("#"):
		return
	if call_site_regex.search(raw_line) != null:
		matches.append({"path": source_label, "line": line_number, "text": trimmed})


# ---- 敏感度證明 ---------------------------------------------------------------

func test_sensitivity_proof_detects_a_second_call_site() -> void:
	# Arrange
	var call_site_regex := RegEx.new()
	call_site_regex.compile(_CALL_SITE_PATTERN)
	var synthetic_lines: Array = [
		"\tport.append_record(pair, m, AffinityTypes.Source.SUPPORT_CONVERSATION)",
		"\tother_port.append_record(pair2, m2, AffinityTypes.Source.SUPPORT_CONVERSATION)",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], call_site_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"敏感度證明失敗:植入了第二個呼叫點,掃描卻沒有抓到 —— 真正的測試即使出現"
		+ "第二個呼叫點也會照樣通過,這正是本測試要防的回歸。"
	).is_equal(2)


func test_sensitivity_proof_detects_zero_call_sites() -> void:
	# Arrange — 模擬「漏接」:整段都不是呼叫
	var call_site_regex := RegEx.new()
	call_site_regex.compile(_CALL_SITE_PATTERN)
	var synthetic_lines: Array = [
		"\tpass  # 忘了呼叫寫入埠的佔位行",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], call_site_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"敏感度證明失敗:本來應為 0,掃描卻算出別的數字。"
	).is_equal(0)


func test_sensitivity_proof_ignores_comment_lines_mentioning_append_record() -> void:
	# Arrange — 只在註解裡提到呼叫,從未真的呼叫(2026-10-12 coding-standards.md
	# 登記的「查核指令寫在註解裡會命中自己」同一個失效形狀)。刻意混入縮排的 ##
	# 文件註解,證明本掃描不像 shell 的 `grep -v ":#"` 只能擋住行首沒縮排的註解。
	var call_site_regex := RegEx.new()
	call_site_regex.compile(_CALL_SITE_PATTERN)
	var synthetic_lines: Array = [
		"## 本函式呼叫寫入埠的 .append_record( 方法,寫入一筆記錄。",
		"\t## 縮排過的文件註解,同樣提到 .append_record( 這個字樣。",
		"# .append_record(pair, m, source)  (舊寫法,已移除)",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], call_site_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"敏感度證明失敗:三行都是註解,從未真的呼叫,掃描卻把它們算進去了。"
	).is_equal(0)


func test_sensitivity_proof_ignores_the_abstract_declaration_itself() -> void:
	# Arrange — SupportConversationWritePort 本身的抽象宣告,前面沒有點號
	var call_site_regex := RegEx.new()
	call_site_regex.compile(_CALL_SITE_PATTERN)
	var synthetic_lines: Array = [
		(
			"func append_record(pair: AffinityTypes.Pair, m: float, "
			+ "source: AffinityTypes.Source) -> void"
		),
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], call_site_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"敏感度證明失敗:這是介面本身的宣告(前面沒有點號),不是呼叫,不該被計入。"
	).is_equal(0)


func test_sensitivity_proof_detects_the_one_real_call_site() -> void:
	# Arrange — 正式呼叫點真正的那一行文字(SupportConversationRules.trigger() 裡的
	# 那一行),證明掃描認得出真正的呼叫長相,不只是認得合成的簡化版本。
	var call_site_regex := RegEx.new()
	call_site_regex.compile(_CALL_SITE_PATTERN)
	var synthetic_lines: Array = [
		"\tport.append_record(pair, m, AffinityTypes.Source.SUPPORT_CONVERSATION)",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], call_site_regex, matches)

	# Assert
	assert_int(matches.size()).is_equal(1)
