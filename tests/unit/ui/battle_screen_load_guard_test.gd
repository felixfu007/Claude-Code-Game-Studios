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


# 2026-09-16 管理者裁決(PROJECT-STATUS.md「等你裁決」第二項,選項甲「響亮地
# 停」):名冊陣營欄打錯字,遊戲必須不啟動。這條測試不是憑空斷言「應該會停」——
# 它串起 _ready() 實際呼叫的兩個真實靜態函式(Unit.roster_from_text() 與
# BattleScreen.classify_content()),證明「一列陣營欄打錯字」確實會走到
# _ready() 用來觸發 _fail_load() 的同一個判斷式(roster_failure != NONE)。
# 不 load()/instantiate() BattleScreen 場景 —— 與本檔其餘測試同一個理由,見檔頭。
# 文字本身完全在記憶體中建構,不讀寫 assets/data/ 底下任何檔案。
func test_roster_load_pipeline_unknown_faction_row_yields_parsed_empty() -> void:
	# Arrange — 陣營欄故意打錯字(ENEMEY),前後各放一個合法列，證明合法列不會
	# 被誤留下來、讓 parsed_count 剛好卡在 1 以上而躲過 PARSED_EMPTY 判定。
	var text: String = (
		"1,甲,PLAYER,30,16,8,6,1,1,0,2\n"
		+ "7,丁,ENEMEY,10,10,10,5,1,2,11,1\n"
		+ "2,乙,PLAYER,26,14,6,5,1,2,0,3\n"
	)

	# Act — 與 battle_screen.gd _ready() 完全相同的兩步：先解析，再分類
	var roster: Array[Unit] = Unit.roster_from_text(text)
	var result: BattleScreen.LoadFailure = BattleScreen.classify_content(text, roster.size())

	# Assert — roster_from_text() 整份作廢（見 unit_test.gd 的對應迴歸測試），
	# 而 classify_content() 把「內容非空、但解析出 0 筆」判成 PARSED_EMPTY ——
	# 這正是 _ready() 呼叫 _fail_load() 並把 _load_failed 設為 true 的條件。
	assert_int(roster.size()).is_equal(0)
	assert_int(result).is_equal(BattleScreen.LoadFailure.PARSED_EMPTY)
	assert_int(result).is_not_equal(BattleScreen.LoadFailure.NONE)


# --- classify_affinity_parse() ---
#
# 2026-09-16 第二次管理者裁決:AffinityLink.links_from_text() 改回傳
# Variant(null = 解析失敗、Array[AffinityLink] = 合法結果,可能是空陣列)。
# 這裡鎖住 classify_affinity_parse() 這個純函式把該 Variant 轉成 LoadFailure
# 的三種輸入型態,不碰場景樹。

func test_classify_affinity_parse_null_returns_parse_error() -> void:
	# Arrange — links_from_text() 解析失敗時的回傳值
	var parsed: Variant = null

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_affinity_parse(parsed)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.PARSE_ERROR)


func test_classify_affinity_parse_empty_array_returns_none() -> void:
	# Arrange — 合法的零配對(戊沒有任何關係線)絕不可被誤判為失敗 —— 這是這次
	# 改動最重要的迴歸防護,見本檔案標頭與 battle_screen.gd 的 AFFINITY_PATH
	# 文件註解。
	var parsed: Array[AffinityLink] = []

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_affinity_parse(parsed)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


func test_classify_affinity_parse_nonempty_array_returns_none() -> void:
	# Arrange — 正常、非空的配對表
	var parsed: Array[AffinityLink] = [AffinityLink.from_csv_line("1,2,POSITIVE,1")]

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_affinity_parse(parsed)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


# 2026-09-16 第二次管理者裁決(選項甲「響亮地停」的迴歸終點):關係表某一列打
# 錯字,遊戲必須不啟動 —— 與上面 test_roster_load_pipeline_unknown_faction_row_
# yields_parsed_empty() 同一種串接手法,但這裡鎖的是 _ready() 實際呼叫的兩個
# 真實函式(AffinityLink.links_from_text() 與 BattleScreen.classify_affinity_parse()),
# 而不是只斷言其中一個。文字全部在記憶體中建構,不讀寫 assets/data/ 底下任何檔案。
func test_affinity_load_pipeline_unknown_polarity_row_yields_parse_error() -> void:
	# Arrange — polarity 欄位打錯字,前後各放一個合法列,證明合法列不會被誤留
	var text: String = "1,2,POSITIVE,1\n1,3,BADVALUE,1\n2,5,NEGATIVE,1"

	# Act — 與 battle_screen.gd _ready() 完全相同的兩步:先解析,再分類
	var parsed: Variant = AffinityLink.links_from_text(text)
	var result: BattleScreen.LoadFailure = BattleScreen.classify_affinity_parse(parsed)

	# Assert
	assert_object(parsed).is_null()
	assert_int(result).is_equal(BattleScreen.LoadFailure.PARSE_ERROR)
	assert_int(result).is_not_equal(BattleScreen.LoadFailure.NONE)


# 迴歸防護的另一半:合法的零配對(檔案內容為空白/僅註解)不可被這次改動牽連
# 誤判成失敗 —— 這正是這次裁決要保留、不能弄壞的既有設計(「拿掉所有配對」
# 必須仍是可表達的合法狀態)。
func test_affinity_load_pipeline_comments_only_table_still_yields_none() -> void:
	# Arrange — 合法的「沒有任何配對」
	var text: String = "# 只有註解\n# 沒有任何資料列\n"

	# Act
	var parsed: Variant = AffinityLink.links_from_text(text)
	var result: BattleScreen.LoadFailure = BattleScreen.classify_affinity_parse(parsed)

	# Assert
	assert_object(parsed).is_not_null()
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


# 第三種情況:正常資料(現行 vs01_affinity_links.txt 的兩列)一樣照常通過。
# 甲類例外(讀 assets/data/ 底下已進版控的真實資料檔)——見
# .claude/rules/test-standards.md「單元測試不得碰檔案系統」節;本檔其餘測試
# （test_classify_file_access_real_terrain_path_returns_none 等）已是同一類先例。
func test_affinity_load_pipeline_real_vs01_file_yields_none() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(
		"res://assets/data/affinity/vs01_affinity_links.txt"
	)

	# Act
	var parsed: Variant = AffinityLink.links_from_text(text)
	var result: BattleScreen.LoadFailure = BattleScreen.classify_affinity_parse(parsed)

	# Assert
	assert_object(parsed).is_not_null()
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


func test_load_failure_message_parse_error_contains_matching_reason() -> void:
	# Arrange — 2026-09-16 第二次管理者裁決新增的分類
	var failure: BattleScreen.LoadFailure = BattleScreen.LoadFailure.PARSE_ERROR
	var path: String = BattleScreen.AFFINITY_PATH

	# Act
	var message: String = BattleScreen.load_failure_message(failure, path)

	# Assert
	assert_str(message).contains(BattleScreen.TEXT_LOAD_REASON_PARSE_ERROR)
	assert_str(message).contains(path)
