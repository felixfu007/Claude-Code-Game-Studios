# 本地化紀律回歸測試 —— Story 003（localization-infrastructure）B 節。
# （production/epics/localization-infrastructure/story-003-fallback-missing-key-regression-tests.md）
#
# 斷言「src/**/*.gd 底下不存在裸中文字串常數」——防止 story-002 遷移完成後，未來有人
# 在不知情（或趕時間）的情況下又直接寫死一個中文 const，繞過 Loc.localize() 的 key 系統。
#
# 🔴 乙類例外（.claude/rules/test-standards.md 2026-09-16 裁決，唯讀 src/**/*.gd 與
# tests/**/*.gd 文字，用於斷言原始碼紀律）：本檔下半部分
# `test_no_bare_cjk_string_constants_under_src()` 直接用 DirAccess/FileAccess 遞迴掃描
# `res://src` 底下全部 `.gd` 檔案的純文字內容。不能用依賴注入取代的理由：斷言對象就是
# 原始碼文字本身——「這個檔案裡有沒有一行寫著裸中文字串」不是一個可以注入假依賴的執行期
# 行為，必須真的讀取檔案文字才有東西可斷言。本 story 的工作單明文只要求掃描範圍涵蓋
# `src/**/*.gd`（不含 `tests/**/*.gd`），故本檔的乙類掃描只對 `res://src` 執行。
#
# 🔴 斷言範圍不等於窮盡性（乙類例外附帶義務第 2 項，逐條列出，不得用一句總結蓋過）：
#
# 1. **只認 `const` 宣告，不認所有裸字串。** 本測試的掃描對象明文是「裸中文字串常數」，
#    也就是具名的 `const` 宣告——`const X: String = "..."`、`const X := "..."`、
#    `const X = "..."` 三種寫法都會被抓到（見下方 `_CONST_STRING_PATTERN`），但若有人
#    直接把中文字面值寫在一個函式呼叫的參數位置、或指派給一個 `var`（非 `const`），
#    例如 `label.text = "你好"` 或 `push_error("某段中文訊息")`，本測試完全看不見。
#    這不是遺漏，是 story-002 原本遷移範圍本來就只鎖定 `const` 宣告（見
#    `production/epics/localization-infrastructure/EPIC.md` Q2 的現況查證指令
#    `grep -rn "^const TEXT_" src/`），本測試是它的回歸守門，範圍同步。
# 2. **動態組字串看不到。** 例如 `"回" + "合"` 或用字串插值／格式化在執行期才拼出一段
#    中文（任何一個片段單獨看都不構成完整的「裸中文字串常數」），不會被本測試的逐行
#    正規表示式比對抓到。
# 3. **`.tres` 資源檔內文字、`.tscn` 場景檔節點屬性內的裸字串，完全不在本測試範圍內。**
#    後者是 story-002 自己的遷移範圍一部分（`BattleScreen.tscn`、`BattleMenu.tscn` 的
#    `text =` 屬性），本測試的掃描範圍明文只涵蓋 `.gd` 純文字，不涵蓋 `.tscn`／`.tres`
#    —— 這點也是本 story 工作單 Out of Scope 節明文排除的項目，本檔不重複嘗試。
# 4. **跨越多個物理行的 `const` 宣告看不到。** 本測試逐「行」比對（以 `\n` 切分），若
#    字串字面值用多個物理行的字面值相鄰拼接（GDScript 允許相鄰字串字面值自動串接）或用
#    `+` 跨行組出一個 `const`，不會被單行正規表示式比對抓到。
# 5. **反射/索引存取看不到**（例如 `set("some_const", "中文")`），與本專案既有乙類範例
#    （`cursor_modulate_alpha_single_writer_test.gd`）揭露的同類缺口同形狀。
# 6. **"沒有找到裸字串常數" 不等於 "這個畫面對玩家顯示的文字都正確"** —— 本測試只防
#    「用 const 寫死中文」這一種失效模式，不驗證 key 查找是否接回正確的翻譯內容
#    （那是 tests/unit/core/i18n/i18n_migrated_strings_test.gd 的職責）。
#
# 🔴 敏感度證明：真正的掃描對象是 `res://src` 底下的真實生產檔案，而本 story 明文禁止
# 本測試的作者改動 `src/` 任何正式程式碼（見 story-003 派工單「你可以動什麼」表）——
# 這正是 test-standards.md 登記的「類 D：唯一有意義的注入點在受限範圍外，注入等於改
# 該處正式程式碼」的字面情況。因此本檔把掃描邏輯拆成兩層：
#   - `_scan_text_for_bare_cjk_consts(text, ...)`：純函式，輸入是一段文字字串，
#     完全不碰檔案系統。
#   - `_scan_directory_for_bare_cjk_consts(root, ...)`：唯一碰檔案系統的那一層，
#     只負責「找出 .gd 檔案、讀出文字」，實際比對邏輯全部委派給上面那個純函式。
# `test_no_bare_cjk_string_constants_under_src()` 呼叫後者掃描真實 `res://src`；
# `test_sensitivity_proof_bare_cjk_const_scan_detects_injected_violation()` 直接呼叫
# 前者、餵入一段刻意植入裸中文字串的 in-test 假文字（不寫入任何檔案），證明「比對邏輯
# 本身」真的會抓到違規，且正確跳過註解行、`res://` 路徑、`_LOG_*` 開發者訊息。
# 🔴 誠實揭露這個證明的邊界：它證明的是「比對邏輯對的」，**沒有**也**不能**證明
# 「對 `res://src` 的真實遞迴目錄走訪（`DirAccess`/`FileAccess` 那一層）本身沒有臭蟲」
# ——要證明那一層，唯一辦法是真的在 `src/` 底下放一個帶裸中文字串的檔案，而那正是
# 本 story 明文禁止的動作。這個缺口誠實登記，不假裝已經證明。
extends GdUnitTestSuite


const _SRC_ROOT: String = "res://src"

## 比對 `const X: String = "..."`、`const X := "..."`、`const X = "..."` 三種寫法，
## 擷取雙引號內的字面值到捕獲群組 1（含對 `\"` 轉義的處理，不會在轉義雙引號處提前
## 結束比對）。已實機驗證（Godot 4.7.1 headless）：會比對 `: String =`／`:=`／`=` 三種
## 寫法；不會比對非 const 的 `var`／`if x == "..."` 這類賦值或比較；對 res:// 路徑、
## `_LOG_*` 常數照樣比對成功（擷取內容不含中文字元，由下面的 CJK 偵測排除）。
const _CONST_STRING_PATTERN: String = (
	"const\\s+[A-Za-z_]\\w*\\s*(?::\\s*String\\s*=|:=|=)\\s*\"((?:\\\\.|[^\"\\\\])*)\""
)

## 偵測字串內是否含有中文／全形標點字元。涵蓋範圍：CJK 統一表意文字（4E00–9FFF，
## 本專案目前全部正體中文內容都落在這個區段）、CJK 統一表意文字擴充 A（3400–4DBF）、
## CJK 符號與標點（3000–303F，例如「。」「、」）、全形字元（FF00–FFEF，例如「？」
## 「，」）。已實機驗證：純 ASCII 不命中、純中文命中、中英混合命中、純全形標點
## （無任何中文表意文字）亦命中。不含日文假名／韓文諺文區段——本專案不支援這兩種語言，
## 刻意不擴大偵測範圍。
const _CJK_PATTERN: String = "[　-〿＀-￯㐀-䶿一-鿿]"


## 純函式——對一段文字（通常是整份檔案內容）逐行比對，找出「const 字串宣告且字面值
## 含中文」的所有違規行。完全不碰檔案系統，是本檔敏感度證明唯一的注入點（見檔頭說明）。
## 跳過規則與 cursor_modulate_alpha_single_writer_test.gd 一致：一行的去頭尾空白版本若
## 以 `#` 開頭（涵蓋本專案 `##` 文件註解慣例），整行跳過，不比對。
static func _scan_text_for_bare_cjk_consts(
	text: String, const_regex: RegEx, cjk_regex: RegEx
) -> Array:
	var violations: Array = []
	var lines: PackedStringArray = text.split("\n")
	for idx in range(lines.size()):
		var raw_line: String = lines[idx]
		var trimmed: String = raw_line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		var m: RegExMatch = const_regex.search(raw_line)
		if m == null:
			continue
		var literal: String = m.get_string(1)
		if cjk_regex.search(literal) != null:
			violations.append({"line": idx + 1, "text": trimmed})
	return violations


## 唯一碰檔案系統的一層——遞迴走訪 [param root] 底下全部 `.gd` 檔案，讀出文字後
## 委派給 `_scan_text_for_bare_cjk_consts()` 做實際比對，彙整路徑資訊回傳。
static func _scan_directory_for_bare_cjk_consts(
	root: String, const_regex: RegEx, cjk_regex: RegEx
) -> Array:
	var violations: Array = []
	_scan_dir(root, const_regex, cjk_regex, violations)
	return violations


static func _scan_dir(
	dir_path: String, const_regex: RegEx, cjk_regex: RegEx, violations: Array
) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full_path, const_regex, cjk_regex, violations)
		elif entry.ends_with(".gd"):
			var f: FileAccess = FileAccess.open(full_path, FileAccess.READ)
			if f != null:
				var text: String = f.get_as_text()
				f.close()
				for v in _scan_text_for_bare_cjk_consts(text, const_regex, cjk_regex):
					violations.append({"path": full_path, "line": v["line"], "text": v["text"]})
		entry = dir.get_next()
	dir.list_dir_end()


func _compile_patterns() -> Dictionary:
	var const_regex := RegEx.new()
	var err1: Error = const_regex.compile(_CONST_STRING_PATTERN)
	assert(err1 == OK, "本測試自己的 _CONST_STRING_PATTERN 編譯失敗，這個失敗代表測試" +
		"本身壞掉，與生產程式碼無關，請先修正這個正規表示式")
	var cjk_regex := RegEx.new()
	var err2: Error = cjk_regex.compile(_CJK_PATTERN)
	assert(err2 == OK, "本測試自己的 _CJK_PATTERN 編譯失敗，這個失敗代表測試本身壞掉，" +
		"與生產程式碼無關，請先修正這個正規表示式")
	return {"const_regex": const_regex, "cjk_regex": cjk_regex}


# ---- 真實掃描：res://src 底下零個裸中文字串常數（乙類，唯讀 src/**/*.gd 文字）-------

func test_no_bare_cjk_string_constants_under_src() -> void:
	# Arrange
	var regexes: Dictionary = _compile_patterns()

	# Act
	var violations: Array = _scan_directory_for_bare_cjk_consts(
		_SRC_ROOT, regexes["const_regex"], regexes["cjk_regex"]
	)

	# Assert
	var lines: Array = []
	for v in violations:
		lines.append("  %s:%d: %s" % [v["path"], v["line"], v["text"]])
	assert_array(violations).append_failure_message(
		(
			"story-002 遷移後，res://src 底下不應再出現裸中文字串常數，實測發現 %d 處：\n%s\n"
			% [violations.size(), "\n".join(lines)]
		) + "——把這段文字改成 Loc.localize() 查找、在 assets/data/locales/strings.csv " +
		"登記對應 key，而不是直接寫死中文字面值"
	).is_empty()


# ---- 敏感度證明：比對邏輯對「刻意植入的違規」真的會抓到（純函式，無檔案 I/O）-------

func test_sensitivity_proof_bare_cjk_const_scan_detects_injected_violation() -> void:
	# Arrange — 刻意混合「不該誤判的三種情況」與「該被抓到的一種情況」，
	# 證明掃描邏輯不只是「看到中文就報」，而是正確辨識 const 宣告、跳過註解行、
	# 不誤判 res:// 路徑與開發者 log 常數。
	var regexes: Dictionary = _compile_patterns()
	var fixture: String = (
		"extends Node\n" +
		"const PATH: String = \"res://assets/sprites/unit.png\"\n" +
		"const _LOG_TAG: String = \"[Something]\"\n" +
		"# const BAD_COMMENTED: String = \"回合\"\n" +
		"const BAD_LABEL: String = \"這是裸中文字串\"\n" +
		"func foo() -> void:\n" +
		"\tpass\n"
	)

	# Act
	var violations: Array = _scan_text_for_bare_cjk_consts(
		fixture, regexes["const_regex"], regexes["cjk_regex"]
	)

	# Assert — 恰好 1 筆，且是第 5 行那個真正的違規，不是 res:// 路徑、_LOG_TAG
	# 或被註解掉的那一行
	assert_int(violations.size()).append_failure_message(
		"敏感度證明失敗：植入了 1 處裸中文字串常數，掃描邏輯卻回報 %d 處——代表" % [
			violations.size()
		] + "test_no_bare_cjk_string_constants_under_src 即使 src/ 出現裸中文字串也可能" +
		"綠燈，或者誤判了不該報的行（res:// 路徑 / _LOG_TAG / 被註解掉的行）"
	).is_equal(1)
	if violations.size() == 1:
		assert_int(violations[0]["line"]).is_equal(5)
		assert_str(violations[0]["text"]).is_equal(
			"const BAD_LABEL: String = \"這是裸中文字串\""
		)
