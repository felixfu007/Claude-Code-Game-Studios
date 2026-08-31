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
# ⚠️ UNREADABLE（檔案存在但 FileAccess.open() 失敗）刻意不測 —— 這不是懶得測，
# 是實機驗證過兩種製造手段都做不出決定性結果之後的結論（2026-08-31 任務，godot
# 4.7.1 headless，本機 Windows）：
#
#   1. 把目錄路徑當檔案路徑丟給 classify_file_access()，指望 file_exists() 為
#      true 但 open() 失敗。實測結果：
#        res://assets/data/levels   exists=false opened=false open_error=12
#        res://assets/data          exists=false opened=false open_error=12
#        res://tests/unit/ui        exists=false opened=false open_error=12
#      FileAccess.file_exists() 對目錄本身就回傳 false，classify_file_access()
#      的第一個 if 就已經判成 MISSING —— 這條路徑完全不會命中 UNREADABLE 分支，
#      不是比較弱，是根本走不到那一行。
#
#   2. 在暫存目錄建一個真實檔案、chmod 000，指望 open() 失敗。實機結果：
#        chmod 000 後 ls -la 顯示 -r--r--r--（唯讀屬性，不是拒讀）
#        FileAccess.open(path, FileAccess.READ) → exists=true opened=true open_error=0
#      在這台機器的 NTFS 上 chmod 000 只映射成唯讀屬性，FileAccess.READ 模式本來
#      就不管可不可寫，所以照樣開得起來。若改用 icacls 之類 Windows 專屬的拒讀
#      ACL 或許能逼出失敗，但那與 CI 用的 Linux runner 行為會不一致 ——
#      ⚠️ Linux 上實際行為未實機驗證，這是推定，不是量測到的事實；但即使沒驗證，
#      「同一條測試在兩個平台給出不同答案」這件事本身就已經是拒絕這條路的理由，
#      不需要等兩邊都測過才能下判斷。
#
#   兩條路都繞不開一件事：無論哪種手段都是讓測試結果依賴作業系統的檔案系統/
#   權限狀態，直接違反 .claude/rules/test-standards.md 第 10 行「Unit tests
#   must not depend on external state (filesystem, network, database)」。
#
# 若日後真的要涵蓋這條分支，正確做法不是想辦法在磁碟層面製造失敗，而是把
# classify_file_access() 開檔那一步抽成可注入的相依，讓測試端塞一個永遠回傳
# null 的假 Callable 進去，命中 UNREADABLE 且 100% 決定性、不碰磁碟。例如
# 讓函式簽章多一個 opener: Callable 參數，預設指向真正的開檔呼叫。
# ⚠️ 這只是方向提示，不是可直接抄的解法 —— 本專案已實測抓到過 18 處憑記憶
# 寫錯的呼叫寫法，「對類別本身（而非實例）的靜態方法建 Callable」這類寫法尤其
# 容易寫錯，動手前請先實機驗證語法。這個改動屬於 src/ui/battle/battle_screen.gd
# 的產品程式碼，需要另外走核准，不在這份測試檔的授權範圍內。
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
