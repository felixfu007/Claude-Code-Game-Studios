# BattleScreen（src/ui/battle/battle_screen.gd）terrain_path_override /
# roster_path_override 注入點的單元測試。
#
# 背景（2026-09-23,管理者裁決「把洞堵掉:讓畫面可以被餵不同的資料」）：
# godot-specialist 當日實測確認可以直接 load("res://src/ui/battle/BattleScreen.tscn")
# 把真實戰鬥畫面載進量測腳本、成本幾乎是零，但 TERRAIN_PATH/ROSTER_PATH 兩個常數
# 寫死、零注入點，量測腳本只能自己組一段局部子樹來擺出真實名冊擺不出來的棋子佈局
# ——而「自己組子樹」正是上週那個假缺陷（U-013 第 194 筆違規誤判）的成因。這份測試
# 鎖住新增的兩個 var 注入點的合約，而不是重新驗證載入失敗分類本身（那已由
# battle_screen_load_guard_test.gd / battle_screen_card_deck_wiring_test.gd 涵蓋）。
#
# 命名慣例依 tests/unit/ui/board_coords_test.gd 先例：
# test_[scenario]_[expected]，extends GdUnitTestSuite。
#
# 每個測試各自重新 load()/instantiate()，依 .claude/rules/test-standards.md
# 「每個測試各自 setup/teardown 自己的狀態」——與 battle_screen_scene_test.gd 同一慣例：
# override 必須在 instantiate() 之後、add_child() 之前設定（battle_screen.gd 該兩個
# var 的 doc comment 明文的時機合約），因為 _ready() 只在 add_child() 進樹時求值一次。
#
# ---- test-standards.md 甲/乙類例外宣告(2026-09-23 第二輪，新增③節後重新判斷，
# 不沿用第一版的結論)-----------------------------------------------------------
#
# 前四條測試(①不設 override、②注入不存在路徑)維持第一版判斷:不宣告例外。
# 沒有任何測試函式自己呼叫 FileAccess/DirAccess——讀真實資料檔（vs01_terrain.txt/
# vs01_roster.txt）與讀「保證不存在的路徑」都是透過 BattleScreen._ready() 這個公開
# 進場點觸發的 production 行為，與 battle_screen_scene_test.gd /
# battle_screen_card_deck_wiring_test.gd 兩份既有姊妹檔完全同一種寫法，那兩份也都
# 沒有宣告例外。「保證不存在的路徑」這件事本身也不構成「依賴外部狀態」——它依賴的是
# 一個路徑【不】存在這個恆真條件，不是磁碟上某份檔案當下的實際內容。
#
# 🔴 第③節(test_terrain_path_override_with_valid_fixture_.../
# test_roster_path_override_with_valid_fixture_...)不一樣，重新判斷後屬【甲類】:
# 這兩條的斷言直接綁死在 assets/data/levels/test_fixture_terrain.txt /
# assets/data/units/test_fixture_roster.txt 這兩個新增夾具檔【當下的實際內容】
# ((0,0) 是 '#'、id=1 是 TESTFIX/999 這些具體值)——如果有人改動這兩個檔案的內容，
# 測試的斷言就必須跟著改，這正是 test-standards.md 甲類定義的「依賴 assets/data/
# 底下已進版控資料檔內容」的核心情境，比前四條測試(只依賴「檔案存在與否」)更直接。
# 為什麼不能用注入(在記憶體裡塞假的 PackedStringArray/Array[Unit])取代:這兩條要
# 證明的正是「BattleScreen._ready() 真的從磁碟讀取 override 指定的路徑」這件事本身
# ——注入內容會繞過 FileAccess 這一步，等於沒有測到它宣稱要測的東西。
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

# 刻意套用 battle_screen_load_guard_test.gd 既有的「不存在路徑」寫法
# （該檔 _MISSING_PATH = "res://does/not/exist.txt"）而不是新建一個真實假資料檔——
# 這裡要證明的是「注入的路徑字串真的被拿去用了」，不是「注入路徑指向的內容能正確解析」，
# 一個保證不存在的路徑就足以把兩者分開：若程式碼默默退回讀 TERRAIN_PATH/ROSTER_PATH，
# 這兩個真實檔案都存在，_ready() 就會成功、_load_failed 仍是 false；只有注入路徑真的
# 被使用時,才會因為 MISSING 而 _load_failed 變 true、且錯誤訊息裡出現的是這個假路徑
# 而不是原本的常數路徑。
const _MISSING_TERRAIN_PATH: String = "res://does/not/exist/terrain.txt"
const _MISSING_ROSTER_PATH: String = "res://does/not/exist/roster.txt"


# ---- ① 不設定 override 時，行為與 override 這個功能加入之前完全相同 -------------

func test_no_override_set_loads_real_terrain_and_roster_paths_unchanged() -> void:
	# Arrange — 不動 terrain_path_override / roster_path_override，維持宣告時的
	# 預設空字串
	var instance: BattleScreen = auto_free(load(SCENE_PATH).instantiate())

	# Act
	add_child(instance)

	# Assert — 兩個 override 欄位維持預設空字串；且真正走完 _ready() 沒有進入失敗畫面
	# （專案裡只有一份 vs01_terrain.txt / 一份 vs01_roster.txt，兩者都存在，所以載入
	# 成功這件事本身就足以證明讀到的是原本的常數路徑而非某個不存在的路徑——任何非
	# TERRAIN_PATH/ROSTER_PATH 的路徑在這個專案裡都不存在，會直接落入 MISSING）
	assert_str(instance.terrain_path_override).is_equal("")
	assert_str(instance.roster_path_override).is_equal("")
	assert_bool(instance._load_failed).is_false()

	var status_label: Label = instance.get_node("UILayer/StatusLabel")
	assert_bool(status_label.visible).is_true()


# ---- ② 設定 override 後，_ready() 真的改讀 override 指定的路徑 ------------------

func test_terrain_path_override_set_before_add_child_is_used_over_default() -> void:
	# Arrange — 時機依 battle_screen.gd terrain_path_override 的 doc comment 合約：
	# instantiate() 之後、add_child() 之前
	var instance: BattleScreen = auto_free(load(SCENE_PATH).instantiate())
	instance.terrain_path_override = _MISSING_TERRAIN_PATH

	# Act
	add_child(instance)

	# Assert — 若程式碼忽略 override、繼續讀 TERRAIN_PATH（該檔真實存在），這裡會是
	# _load_failed=false；實際讀到 override 路徑（不存在）才會落入 MISSING、顯示失敗畫面，
	# 且畫面訊息裡出現的是注入路徑本身,不是 BattleScreen.TERRAIN_PATH 這個常數
	assert_bool(instance._load_failed).is_true()
	var load_error_label: Label = instance.get_node("UILayer/LoadErrorLabel")
	assert_bool(load_error_label.visible).is_true()
	assert_str(load_error_label.text).contains(BattleScreen.TEXT_LOAD_REASON_MISSING)
	assert_str(load_error_label.text).contains(_MISSING_TERRAIN_PATH)
	assert_str(load_error_label.text).not_contains(BattleScreen.TERRAIN_PATH)


func test_roster_path_override_set_before_add_child_is_used_over_default() -> void:
	# Arrange — 同上，改換 roster 這一側的注入點
	var instance: BattleScreen = auto_free(load(SCENE_PATH).instantiate())
	instance.roster_path_override = _MISSING_ROSTER_PATH

	# Act
	add_child(instance)

	# Assert
	assert_bool(instance._load_failed).is_true()
	var load_error_label: Label = instance.get_node("UILayer/LoadErrorLabel")
	assert_bool(load_error_label.visible).is_true()
	assert_str(load_error_label.text).contains(BattleScreen.TEXT_LOAD_REASON_MISSING)
	assert_str(load_error_label.text).contains(_MISSING_ROSTER_PATH)
	assert_str(load_error_label.text).not_contains(BattleScreen.ROSTER_PATH)


# ---- ③ override 指向一份存在、內容不同的合成夾具 —— 證明「內容真的換了」，不只是
# 「沒有失敗」(2026-09-23 第二輪管理者裁決「今天證完」)-------------------------
#
# 上面②的兩條刻意選了保證不存在的路徑,結構上永遠短路在 classify_file_access()
# 就回傳 MISSING,從來沒有執行到「if xxx_failure == LoadFailure.NONE:」裡面那幾行
# 真正呼叫 FileAccess.get_file_as_string(xxx_path) / 解析內容的成功分支 —— 若未來
# 有人不小心把成功分支那一行改回讀寫死的常數(同時仍保留 classify_file_access()
# 那一行改吃 override),②的兩條測試不會發現。這裡的兩條測試存在的唯一理由就是
# 補上這個結構性盲點。
const _FIXTURE_TERRAIN_PATH: String = "res://assets/data/levels/test_fixture_terrain.txt"
const _FIXTURE_ROSTER_PATH: String = "res://assets/data/units/test_fixture_roster.txt"


func test_terrain_path_override_with_valid_fixture_reads_fixture_content_not_default() -> void:
	# Arrange — test_fixture_terrain.txt(5 寬 x 3 高)在 (0,0) 是 '#'(倒木);
	# 真實 vs01_terrain.txt 同一格是 '.'(平地)——刻意選這一格做為可斷言的差異點。
	# 注意:Board 的座標邊界(BOARD_WIDTH=13/BOARD_HEIGHT=6)是固定常數,不受
	# terrain 內容影響,所以維持預設 roster 的單位起始座標不會因為夾具棋盤變小
	# 而越界。
	var instance: BattleScreen = auto_free(load(SCENE_PATH).instantiate())
	instance.terrain_path_override = _FIXTURE_TERRAIN_PATH

	# Act — 唯有走進 terrain_failure == LoadFailure.NONE 的成功分支才會到這裡
	# (get_file_as_string() + _parse_terrain_rows() + classify_content()),
	# 不像②的兩條在 classify_file_access() 就短路
	add_child(instance)

	# Assert — 先確認真的成功了(不是碰巧也失敗、才「看起來像換了」),再確認讀到的
	# 是夾具內容而不是真實檔案的內容
	assert_bool(instance._load_failed).is_false()
	assert_str(instance._state.board.get_terrain(Vector2i(0, 0))).is_equal(Board.TERRAIN_FALLEN_LOG)


func test_roster_path_override_with_valid_fixture_reads_fixture_content_not_default() -> void:
	# Arrange — test_fixture_roster.txt 只有 2 個單位(1 PLAYER + 1 ENEMY),真實
	# vs01_roster.txt 是 5 PLAYER + 5 ENEMY;且 id=1 在夾具裡是 code_name=TESTFIX、
	# hp_max=999,真實檔案裡 id=1 是 code_name=甲、hp_max=30 —— 三個維度刻意都不同,
	# 任一項都足以分辨讀到的是哪一份檔案
	var instance: BattleScreen = auto_free(load(SCENE_PATH).instantiate())
	instance.roster_path_override = _FIXTURE_ROSTER_PATH

	# Act
	add_child(instance)

	# Assert
	assert_bool(instance._load_failed).is_false()
	assert_int(instance._state.units_of(Unit.Faction.PLAYER).size()).is_equal(1)
	assert_int(instance._state.units_of(Unit.Faction.ENEMY).size()).is_equal(1)
	var first_unit: Unit = instance._state.unit_by_id(1)
	assert_str(first_unit.code_name).is_equal("TESTFIX")
	assert_int(first_unit.hp_max).is_equal(999)
