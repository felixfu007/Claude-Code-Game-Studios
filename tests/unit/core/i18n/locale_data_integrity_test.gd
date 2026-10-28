# Locale 資料檔格式驗證 —— Story 003（localization-infrastructure）A 節第 4 項。
# （production/epics/localization-infrastructure/story-003-fallback-missing-key-regression-tests.md）
#
# 🔴 本檔只負責 A 節「key 格式驗證」（無重複 key、無空值）。A 節其餘三項
# （真實 key 逐字命中、缺 key 不 crash、缺 key 不顯示裸 key）已由
# tests/unit/core/i18n/loc_localize_test.gd 涵蓋，本檔不重複：
#   - test_localize_dot_notation_key_battle_hud_status_format_returns_registered_translation
#   - test_localize_dot_notation_key_battle_menu_leave_confirm_title_returns_registered_translation
#   - test_localize_missing_key_never_returns_bare_key_string
#   - test_localize_missing_key_debug_build_returns_identifiable_placeholder
# 見該檔內容，不在此重寫同一份斷言。
#
# 🔴 甲類例外（.claude/rules/test-standards.md 2026-09-16 裁決）：本檔下半部分的
# `test_strings_csv_*` 三條測試直接用 FileAccess 唯讀 assets/data/locales/strings.csv
# （已進版控的真實資料檔，不寫入、不讀 user:// 或暫存目錄）。不能用依賴注入取代的理由：
# 斷言對象就是「這份真實資料檔本身有沒有打錯」——資料檔被改錯字 / 整列被複製貼上兩次
# 這種錯，寫死在測試裡的假資料永遠測不到，本專案已有「資料檔沒打包、遊戲靜默畫空棋盤、
# 151 條測試全綠」的前例。
#
# 下半部分的 `test_sensitivity_proof_*` 兩條測試，以及 `test_csv_parser_*` 一條，
# 完全不碰檔案系統 —— 餵給 `_parse_csv_rows()` 的是本檔自己定義的 in-test 字串常數，
# 不屬於甲/乙任何一類，也不需要援引該例外。
#
# 🔴 敏感度證明：本檔要驗的是「CSV 原始文字裡有沒有重複 key / 空值」，而
# TranslationServer 本身的行為會把這類瑕疵「吸收掉」——後面那次重複的 key 會覆蓋前一次
# （CSV 匯入管線的既定行為），而空值 key 查找照樣回傳空字串、不會拋錯，兩者都不會在
# `Loc.localize()` 層級產生任何可觀測的異常。換句話說，光靠呼叫 `Loc.localize()`
# 永遠證明不了這兩種資料瑕疵存在與否 —— 唯一能測到的手段是直接讀 CSV 原始文字自己解析。
# 這落在 test-standards.md 登記的「類 A′：斷言對象是真實資料檔內容，沒有類別可注入
# 錯誤版本」—— 對真實檔案那三條測試而言確實如此（無法把 strings.csv 抽換成一個會回傳
# 錯誤內容的子類別）。但本檔額外把偵測邏輯（`_parse_csv_rows` 本身）抽成純函式，讓
# `test_sensitivity_proof_*` 兩條可以直接餵入「刻意植入重複 key / 空值」的假 CSV 文字
# （in-test 常數，不碰檔案系統），證明偵測邏輯本身真的會抓到這兩種瑕疵 —— 這是比純
# 「類 A′ 做不到」更進一步的證明：證不了的只有「真實檔案目前這份內容」這件事本身的
# 替身測試，偵測邏輯的正確性是可證的，而且已經證了。
#
# 🔴 CSV 解析陷阱（協調者已登記，本檔已處理）：strings.csv 含雙引號包住的多行欄位
# （例如 battle.load_error.failure_format、battle.menu.leave_confirm_body 的值裡有
# 真實換行字元）。逐行處理的解析器會把續行誤判成新的 key —— 本檔的 `_parse_csv_rows()`
# 改用逐字元、狀態機式解析（追蹤「目前是否在雙引號欄位內」），不依賴行為界線；
# `test_csv_parser_treats_quoted_multiline_field_as_single_record` 直接證明這一點。
extends GdUnitTestSuite


## 把 CSV 文字解析成列的陣列，每列是一個固定長度的欄位陣列（本專案目前固定兩欄：
## key, zh_TW）。採逐字元狀態機解析，正確處理雙引號欄位內的逗號、真實換行字元與
## 「""」轉義雙引號，不依賴「一行一筆資料」的假設（strings.csv 的多行欄位會違反這個
## 假設，見檔頭說明）。檔尾若有單一空字串欄位的殘留空列（檔案結尾多一個換行造成），
## 會被丟棄，不計入回傳結果。
static func _parse_csv_rows(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var fields: PackedStringArray = PackedStringArray()
		while true:
			var field: String = ""
			if i < n and text[i] == "\"":
				i += 1
				while i < n:
					if text[i] == "\"":
						if i + 1 < n and text[i + 1] == "\"":
							field += "\""
							i += 2
						else:
							i += 1
							break
					else:
						field += text[i]
						i += 1
			else:
				while i < n and text[i] != "," and text[i] != "\n" and text[i] != "\r":
					field += text[i]
					i += 1
			fields.append(field)
			if i < n and text[i] == ",":
				i += 1
				continue
			break
		rows.append(fields)
		if i < n and text[i] == "\r":
			i += 1
		if i < n and text[i] == "\n":
			i += 1
	if rows.size() > 0 and rows[rows.size() - 1].size() == 1 and rows[rows.size() - 1][0] == "":
		rows.remove_at(rows.size() - 1)
	return rows


## 讀取真實 assets/data/locales/strings.csv 並回傳「排除標頭列」的資料列。
## 三條 test_strings_csv_* 測試共用這個讀取步驟，避免同一份檔案被重複開關三次。
static func _load_real_data_rows() -> Array[PackedStringArray]:
	var f: FileAccess = FileAccess.open("res://assets/data/locales/strings.csv", FileAccess.READ)
	# 🔴 協調者 2026-10-13 改寫：原本這裡是 assert()，下一行緊接著 f.get_as_text()。
	# 兩個問題，而且第二個比第一個嚴重：
	#   1. assert() 在 release 建置會被剝除 —— 剝除之後，下一行就是對 null 解參考。
	#   2. 🔴 就算 assert 生效，它中止本函式後產生的是回傳型別的預設值（空陣列），
	#      於是呼叫端量到「0 列」，失敗訊息會說「預期 45 列、實得 0」——
	#      把「檔案開不起來」偽裝成「資料列數不對」。本專案登記最多次的失效形狀就是
	#      這個：一個看起來合理的數字，回答的不是你以為它在回答的問題。
	# 改法依 .claude/docs/coding-standards.md 2026-09-15 的實測條目：
	# push_error() 把【真正的成因】留在 log 裡，再明確 return 一個空陣列讓呼叫端自然變紅。
	# 兩者都要：log 說明為什麼，斷言負責讓它紅。
	if f == null:
		push_error(
			"locale_data_integrity_test: 開不起來 res://assets/data/locales/strings.csv"
			+ "（FileAccess.get_open_error() = %d）。本檔全部 test_strings_csv_* 測試的前置條件失敗，"
			+ "它們接下來會因為『0 列』而變紅 —— 真正的成因是這一行，不是資料列數。"
			% FileAccess.get_open_error()
		)
		return [] as Array[PackedStringArray]
	var text: String = f.get_as_text()
	f.close()
	var rows: Array[PackedStringArray] = _parse_csv_rows(text)
	return rows.slice(1)


# ---- 真實資料檔：結構完整性（甲類，唯讀 assets/data/locales/strings.csv）-----------



func test_strings_csv_has_no_duplicate_keys() -> void:
	# Arrange
	var data_rows: Array[PackedStringArray] = _load_real_data_rows()
	var seen: Dictionary = {}
	var duplicates: Array[String] = []

	# Act
	for row: PackedStringArray in data_rows:
		var key: String = row[0]
		if seen.has(key):
			duplicates.append(key)
		seen[key] = true

	# Assert
	assert_array(duplicates).append_failure_message(
		"strings.csv 內不應有重複的 key，實測發現重複：%s —— CSV 匯入管線對重複 key 的" % [
			str(duplicates)
		] + "既定行為是後面那筆覆蓋前面那筆（靜默，不報錯），所以重複 key 不會在" +
		"Loc.localize() 層級產生任何可觀測症狀，只能從原始檔案文字抓到"
	).is_empty()


func test_strings_csv_has_no_empty_translation_values() -> void:
	# Arrange
	var data_rows: Array[PackedStringArray] = _load_real_data_rows()
	var empty_value_keys: Array[String] = []

	# Act
	for row: PackedStringArray in data_rows:
		if row[1] == "":
			empty_value_keys.append(row[0])

	# Assert — 目前本專案的 key 命名慣例與資料內容裡，沒有任何「刻意留空」的合法設計
	# （例如用空字串表示「這個欄位目前不顯示任何文字」）。若未來真的需要這種語意，
	# 需要先在 CSV 或命名慣例上訂出一個可區分「刻意留空」與「遺漏」的標記，
	# 再回來调整本測試的判準 —— 目前沒有這種標記，所以任何空值都視為遺漏。
	assert_array(empty_value_keys).append_failure_message(
		"strings.csv 內不應有翻譯內容為空字串的 key，實測發現：%s —— 若這是刻意設計" % [
			str(empty_value_keys)
		] + "（例如某個欄位故意不顯示文字），目前的資料格式無法表達這個意圖，需要回頭" +
		"決定一個可區分的標記，不能讓它跟『忘記填』長得一模一樣"
	).is_empty()


# ---- 解析器正確性：雙引號多行欄位不被誤判成新 key（純函式，無檔案 I/O）-------------

func test_csv_parser_treats_quoted_multiline_field_as_single_record() -> void:
	# Arrange — 模擬 strings.csv 真實存在的雙引號多行欄位形狀（真實案例見
	# battle.load_error.failure_format / battle.menu.leave_confirm_body）
	var fixture: String = "keys,zh_TW\na.b,\"line1\nline2\"\na.c,plain\n"

	# Act
	var data_rows: Array[PackedStringArray] = _parse_csv_rows(fixture).slice(1)

	# Assert — 若解析器錯把續行當成新 key，這裡會量到 3 列而不是 2 列
	assert_int(data_rows.size()).append_failure_message(
		"逐行解析（不追蹤引號狀態）會把雙引號欄位內的換行誤判成新的一列，預期 2 列" +
		"（a.b 一列、a.c 一列），實得 %d 列：%s" % [data_rows.size(), str(data_rows)]
	).is_equal(2)
	assert_str(data_rows[0][0]).is_equal("a.b")
	assert_str(data_rows[0][1]).append_failure_message(
		"雙引號欄位內的真實換行字元應保留在解析結果裡，不應被截斷成只有 'line1'"
	).is_equal("line1\nline2")


# ---- 敏感度證明：偵測邏輯對「刻意植入的瑕疵」真的會抓到 ----------------------------

func test_sensitivity_proof_duplicate_key_detector_flags_injected_duplicate() -> void:
	# Arrange — 刻意植入重複 key 的假 CSV 文字（in-test 常數，不碰檔案系統）
	var fixture: String = "keys,zh_TW\na.b,one\na.b,two\na.c,three\n"
	var data_rows: Array[PackedStringArray] = _parse_csv_rows(fixture).slice(1)
	var seen: Dictionary = {}
	var duplicates: Array[String] = []

	# Act — 與 test_strings_csv_has_no_duplicate_keys 完全相同的偵測邏輯
	for row: PackedStringArray in data_rows:
		var key: String = row[0]
		if seen.has(key):
			duplicates.append(key)
		seen[key] = true

	# Assert — 證明：若真實資料檔真的出現重複 key，上面那條測試不會放行
	assert_array(duplicates).append_failure_message(
		"敏感度證明失敗：植入了重複 key 'a.b'，偵測邏輯卻沒有抓到，代表" +
		"test_strings_csv_has_no_duplicate_keys 即使資料檔壞掉也會綠燈"
	).is_equal(["a.b"] as Array[String])


func test_sensitivity_proof_empty_value_detector_flags_injected_empty_value() -> void:
	# Arrange — 刻意植入空值的假 CSV 文字（in-test 常數，不碰檔案系統）
	var fixture: String = "keys,zh_TW\na.b,\na.c,fine\n"
	var data_rows: Array[PackedStringArray] = _parse_csv_rows(fixture).slice(1)
	var empty_value_keys: Array[String] = []

	# Act — 與 test_strings_csv_has_no_empty_translation_values 完全相同的偵測邏輯
	for row: PackedStringArray in data_rows:
		if row[1] == "":
			empty_value_keys.append(row[0])

	# Assert — 證明：若真實資料檔真的出現空值，上面那條測試不會放行
	assert_array(empty_value_keys).append_failure_message(
		"敏感度證明失敗：植入了空值 key 'a.b'，偵測邏輯卻沒有抓到，代表" +
		"test_strings_csv_has_no_empty_translation_values 即使資料檔壞掉也會綠燈"
	).is_equal(["a.b"] as Array[String])


# ---- 🔴 寫死總數的斷言：刻意放在本檔【最後一條】（2026-10-19 管理者裁決）--------
# 裁決逐字選項：「改數字 + 移到檔案最後一條（推薦）」。
# 被跳過的兩個：「只改數字（75→78），其他不動」、「改成『下限 + 不重複 + 無空值』」。
#
# 為什麼是「移到最後」而不是「換掉斷言形狀」：
#   保留精確總數 → 少掉一列馬上會被抓到（下限式斷言擋不住單列誤刪，而字串少一列的
#   症狀是畫面上冒出一個原始代號，很容易被當成「還沒做完」而不是「壞了」）。
#   但本專案的引擎行為是「一條測試失敗會中止同 suite 剩餘測試」—— 這條原本是本檔
#   第一條，撞紅時會連帶讓同檔另外 5 條一次都不執行，全套總數出現一個要另外花時間
#   追的落差。移到最後，精確保護保留、連帶代價消失。
#
# 📌 它今天（2026-10-19，game-shell story-001）第三次被撞紅，前兩次是 2026-10-15
#    同一天內的 story-012（+23）與 story-013（+7）。三次都不是該 story 做錯事，
#    只是新增了 key。**下一張新增字串的工作單仍然要改一次這個數字，這是裁決接受的代價。**
func test_strings_csv_parses_to_known_data_row_count_with_two_columns() -> void:
	# Arrange / Act
	var data_rows: Array[PackedStringArray] = _load_real_data_rows()

	# Assert — 84 筆是 assets/data/locales/strings.csv 目前的真實資料列數。
	# 🔴 2026-10-15 第二次更新(同一天內):45 → 68(story-012 格位資訊面板 +23)
	# → 75(story-013 攻擊確認面板 +7)。
	# 🔴 2026-10-19 第三次更新:75 → 78(story-001-title-screen-and-scene-switching.md
	# 新增 shell.title.start_battle / shell.title.settings / shell.title.quit 三列)。
	# 🔴 2026-10-19 第四次更新(同一天內):78 → 83
	# (story-002-minimal-settings-screen.md 新增 shell.settings.egm_toggle /
	# shell.settings.back / battle.menu.egm_status_format /
	# battle.menu.egm_status_on / battle.menu.egm_status_off 五列)。延續前三次的
	# 同一處理方式(直接更新數字),不是對檔尾「待裁決」重新下裁決。
	# 🔴 2026-10-27 第五次更新:83 → 84(game-shell story-005 新增 battle.menu.leave_confirm_return_to_title 一列)。
	# 🔴 2026-10-28 再續:96 → 140(support-conversation-ui story-002 新增 character.name.1~5 共 5 列 + support.sc01~03.line* 共 39 列;依工作單 Affected Files 與 AC4,延續同日同一處理方式)。
	# 🔴 2026-10-28 續:95 → 96(battle-hud story-003 新增 battle.hud.consistency_counter_format 一列;依工作單 Affected Files,延續同日同一處理方式)。
	# 🔴 2026-10-28 更新:85 → 95(battle-hud story-002 新增 10 列 battle.hud.guess_*;管理者 10/28 裁決「把 85 改成 95」,
	# 被跳過的選項:改成「下限 + 不重複 + 無空值」/ 先不動)。刻意不寫「第幾次」—— 上一行寫第五次是 84,而改前已是 85。
	# 這是本檔自己在上面登記過「待裁決」的那個維護成本第三次發生,延續前兩次的
	# 同一處理方式(直接更新數字),不是對那條「待裁決」重新下裁決 —— 是否改成
	# 「下限 + 不重複 + 無空值」的組合仍然沒有被本次更新決定,留給下一次有人真的
	# 要處理那個待裁決項時再做。
	# ⚠️ **這個寫死的數字一天之內被兩張不同的工作單撞紅兩次**,而且兩次都是
	# 「該 story 本身沒做錯任何事,只是新增了 key」。兩次都讓這支檔案的
	# **第一條**測試失敗,連帶中止它後面 5 條(本專案已登記「一條失敗會中止
	# 它所在 suite 的剩餘測試」),使全套總數看起來少 5 筆 —— 那個落差
	# 本身也要花時間追。
	# 📌 **登記為待裁決**:這個斷言要防的是「資料列意外消失」,而寫死總數
	# 讓每一張新增 key 的 story 都得付一次維護成本。是否改成「下限 + 不重複
	# + 無空值」的組合(後兩者本檔已有獨立測試),是一次設計決定,不在本次修正範圍。
	# 🔴 2026-10-15 更正：本處原寫「45 筆與 i18n_migrated_strings_test.gd 的
	# test_total_migrated_key_count_is_forty_five 是同一個數字，兩處故意分別驗證不同
	# 事實，CSV 筆數變動時兩處要一起改」——這句話描述的「同步維護」關係並不成立，只是
	# 兩個數字在某個時間點剛好相等。那條測試量的是「story-002 遷移批次涵蓋的 key 數」，
	# 範圍固定在遷移當時搬過去的 45 筆，不隨 CSV 之後新增的內容而成長；這裡量的是
	# 「CSV 目前實際有幾列資料」，會隨任何新 story 往 CSV 加 key 而成長。
	# story-012（格位資訊面板）直接透過 Loc API 新增 23 筆 key（68 = 45 + 23）——
	# 這些 key 從未以硬寫字串的形式存在過，不是「被遷移」的對象，因此不屬於
	# i18n_migrated_strings_test.gd 的涵蓋範圍；這批內容的字面值由
	# tests/integration/ui/battle_screen_tile_info_test.gd 另行驗證。
	# 兩處測試的數字此後預期會持續分道，不應再被當成需要互相同步的同一個數字。
	assert_int(data_rows.size()).append_failure_message(
		"strings.csv 資料列數應為 140（CSV 目前實際列數——與 i18n_migrated_strings_test.gd 的 " +
		"test_total_migrated_key_count_is_forty_five 是兩個刻意不再同步的不同數字，見上方註解），" +
		"實得 %d" % data_rows.size()
	).is_equal(140)

	for row: PackedStringArray in data_rows:
		assert_int(row.size()).append_failure_message(
			"資料列 %s 應恰好 2 欄（key, zh_TW），實得 %d 欄 —— 欄數不對通常代表某個值" % [
				str(row), row.size()
			] + "裡的雙引號沒有正確收尾，導致解析器把下一欄/下一列併了進來"
		).is_equal(2)
