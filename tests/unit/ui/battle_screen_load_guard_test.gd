# BattleScreen（src/ui/battle/battle_screen.gd）載入失敗分類的單元測試。
#
# 背景：2026-08-27 匯出成獨立執行檔實測，打包漏收兩個資料檔（terrain/roster）後，
# BattleScreen._ready() 對讀不到的檔案完全靜默——FileAccess.get_file_as_string()
# 對不存在的檔回傳 ""，Board.from_ascii(PackedStringArray()) 與
# Unit.roster_from_text("") 都欣然接受空輸入、產生空棋盤空名冊。全套測試仍然
# 全綠、打包無錯、畫面一片空白，沒有任何一處報錯。這份測試鎖住四種失敗分類
# （MISSING / EMPTY_CONTENT / PARSED_EMPTY / NONE）與訊息組字，防止這個靜默
# 失敗模式再次發生而沒有測試抓到。
#
# 三支受測函式都是 static、不依賴節點或場景樹（見 battle_screen.gd 的 doc
# comment），因此這裡全程不 load()/instantiate() BattleScreen 場景——場景樹相關
# 的冒煙測試在 tests/unit/ui/battle_screen_scene_test.gd。
#
# ⚠️ UNREADABLE（檔案存在但 FileAccess.open() 失敗，例如權限被拒或檔案被其他
# 行程鎖定）刻意不測：在 headless CI 環境下沒有可靠、確定性的方式製造「檔案
# 存在但打不開」這個狀態而不真的動到磁碟權限（.claude/docs/coding-standards.md
# 「Unit tests do not call external APIs, databases, or file I/O」），勉強做出來
# 也會因平台而異、不確定性。分類邏輯本身（classify_file_access 的 file == null
# 分支）很單純，风险低到不值得為了測它而引入一個不確定的測試。
#
# 命名慣例依 tests/unit/ui/board_coords_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
extends GdUnitTestSuite

const _MISSING_PATH: String = "res://does/not/exist.txt"


# --- classify_file_access() ---

func test_classify_file_access_missing_path_returns_missing() -> void:
	# Arrange
	var path: String = _MISSING_PATH

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_file_access(path)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.MISSING)


func test_classify_file_access_real_terrain_path_returns_none() -> void:
	# Arrange — 專案實際存在的資料檔，供正常路徑對照
	var path: String = BattleScreen.TERRAIN_PATH

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_file_access(path)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


func test_classify_file_access_real_roster_path_returns_none() -> void:
	# Arrange
	var path: String = BattleScreen.ROSTER_PATH

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_file_access(path)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


# --- classify_content() ---

func test_classify_content_empty_string_returns_empty_content() -> void:
	# Arrange
	var text: String = ""

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_content(text, 0)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.EMPTY_CONTENT)


func test_classify_content_whitespace_only_returns_empty_content() -> void:
	# Arrange — 只有空白與換行，strip_edges() 後應等同空字串
	var text: String = "  \n\n  "

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_content(text, 0)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.EMPTY_CONTENT)


func test_classify_content_comments_only_with_zero_parsed_returns_parsed_empty() -> void:
	# Arrange — 內容非空，但呼叫端的解析器（例如 Unit.roster_from_text()，會跳過
	# 註解行與空白行）算出 0 筆可用內容
	var text: String = "# comment\n\n"

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_content(text, 0)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.PARSED_EMPTY)


func test_classify_content_nonempty_with_positive_parsed_returns_none() -> void:
	# Arrange — 正常內容，解析器算出至少 1 筆
	var text: String = "1,Hero,PLAYER,20,5,3,4,1,1,0,0"

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_content(text, 1)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


# --- load_failure_message() ---

func test_load_failure_message_missing_contains_reason_and_path() -> void:
	# Arrange
	var failure: BattleScreen.LoadFailure = BattleScreen.LoadFailure.MISSING
	var path: String = _MISSING_PATH

	# Act
	var message: String = BattleScreen.load_failure_message(failure, path)

	# Assert
	assert_str(message).contains(BattleScreen.TEXT_LOAD_REASON_MISSING)
	assert_str(message).contains(path)


func test_load_failure_message_empty_content_contains_matching_reason() -> void:
	# Arrange
	var failure: BattleScreen.LoadFailure = BattleScreen.LoadFailure.EMPTY_CONTENT
	var path: String = BattleScreen.ROSTER_PATH

	# Act
	var message: String = BattleScreen.load_failure_message(failure, path)

	# Assert
	assert_str(message).contains(BattleScreen.TEXT_LOAD_REASON_EMPTY_CONTENT)
	assert_str(message).contains(path)
	# 不該混進其他三種理由文字
	assert_str(message).not_contains(BattleScreen.TEXT_LOAD_REASON_MISSING)
	assert_str(message).not_contains(BattleScreen.TEXT_LOAD_REASON_UNREADABLE)
	assert_str(message).not_contains(BattleScreen.TEXT_LOAD_REASON_PARSED_EMPTY)


func test_load_failure_message_parsed_empty_contains_matching_reason() -> void:
	# Arrange
	var failure: BattleScreen.LoadFailure = BattleScreen.LoadFailure.PARSED_EMPTY
	var path: String = BattleScreen.ROSTER_PATH

	# Act
	var message: String = BattleScreen.load_failure_message(failure, path)

	# Assert
	assert_str(message).contains(BattleScreen.TEXT_LOAD_REASON_PARSED_EMPTY)
	assert_str(message).contains(path)


func test_load_failure_message_unreadable_contains_matching_reason() -> void:
	# Arrange
	var failure: BattleScreen.LoadFailure = BattleScreen.LoadFailure.UNREADABLE
	var path: String = BattleScreen.TERRAIN_PATH

	# Act
	var message: String = BattleScreen.load_failure_message(failure, path)

	# Assert
	assert_str(message).contains(BattleScreen.TEXT_LOAD_REASON_UNREADABLE)
	assert_str(message).contains(path)
