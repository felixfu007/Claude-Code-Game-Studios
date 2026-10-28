## BattleScreen._ready() 開局四個資料路徑(terrain/roster/affinity/cards)改為
## 查戰役序列表(production/epics/game-shell/
## story-003-campaign-flow-and-transition-slots.md 下一輪接線)的整合測試。
##
## 解析順序(見 [member BattleScreen.terrain_path_override] 文件註解):
## *_path_override(既有注入慣例,永遠最優先)-> [constant
## BattleScreen.CAMPAIGN_SEQUENCE_PATH] 裡 [method CampaignProgress.current_mission]
## 對應的那一列 -> 都沒有才回退到 TERRAIN_PATH/ROSTER_PATH/AFFINITY_PATH/CARDS_PATH
## 四個既有常數。
##
## 本檔用新加的 [method BattleScreen.diagnostic_resolved_data_paths]
## (QA/test-only,比照本檔既有的 [code]diagnostic_*[/code] 慣例)直接斷言「解析到
## 了哪一個路徑字串」,不透過載入結果反推——這條測試要釘住的就是「選中了哪個
## 字串」本身,不是那個字串指向的檔案內容對不對(後者已由既有的載入/解析測試覆蓋)。
##
## 載入真實場景的寫法沿用既有先例:
## tests/integration/ui/battle_screen_impassable_terrain_scan_test.gd(override
## 時機合約:instantiate() 之後、add_child() 之前)。
##
## 🔴 本檔每條測試一律在開頭與收尾呼叫 [method CampaignProgress.reset_for_test]
## ——[CampaignProgress] 是跨測試共用的 static 狀態(.claude/rules/gameplay-code.md
## 2026-10-19 裁決④登記在案的已知代價),比照
## tests/unit/core/campaign/campaign_progress_test.gd 的既有紀律。
##
## ⚠️ 敏感度證明——誠實登記為「做不到」(test-standards.md 門檻義務,屬 D 類:
## 「唯一有意義的注入點在受限範圍外」):本檔三條測試斷言的都是
## [method BattleScreen._ready] 內部一段寫死的直線邏輯(四個 if/else 路徑解析),
## 不透過任何可覆寫的虛擬方法或可注入的介面暴露——要證明「這段邏輯被正確執行」,
## 必須能替換 [method BattleScreen._ready] 本身的這一小段,等於再改一次
## src/ui/battle/battle_screen.gd 的生產邏輯。本檔直接斷言真實 production
## [method BattleScreen.diagnostic_resolved_data_paths] 的回傳值作為保障層級,
## 是比「證明不了就不寫」更弱但誠實的保障(同類情境見
## battle_screen_campaign_affinity_ledger_seeding_test.gd 檔頭的誠實登記)。
extends GdUnitTestSuite


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	# Restore shared CursorStateHost Autoload state; see tests/helpers/cursor_host_snapshot.gd
	_host_snap.restore()


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"


# ---- 迴歸鎖(本工作單裡最重要的一條):不設任何 override、目前場次為 1 時,
# 四個路徑與既有常數完全相同 ----
#
# campaign_sequence.txt 第 1 列今天逐字等於 TERRAIN_PATH/ROSTER_PATH/AFFINITY_PATH/
# CARDS_PATH 四個既有常數(見該檔自己的註解);這條測試釘住的是「改用序列表查詢之
# 後,這個逐字相同的結果沒有被破壞」。
func test_ready_without_override_at_mission_1_resolves_to_existing_constants() -> void:
	# Arrange —— 目前場次確保是全新戰役的預設值 1
	CampaignProgress.reset_for_test()
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())

	# Act
	add_child(instance)

	# Assert —— 載入沒有失敗(先確認這條測試真的測到了完整的 _ready() 路徑)
	assert_bool(instance._load_failed).is_false()

	var resolved: Dictionary = instance.diagnostic_resolved_data_paths()
	assert_str(resolved.get("terrain", "")).append_failure_message(
		"目前場次為 1、無 override 時,terrain 路徑應與既有常數 TERRAIN_PATH 完全相同"
	).is_equal(BattleScreen.TERRAIN_PATH)
	assert_str(resolved.get("roster", "")).append_failure_message(
		"目前場次為 1、無 override 時,roster 路徑應與既有常數 ROSTER_PATH 完全相同"
	).is_equal(BattleScreen.ROSTER_PATH)
	assert_str(resolved.get("affinity", "")).append_failure_message(
		"目前場次為 1、無 override 時,affinity 路徑應與既有常數 AFFINITY_PATH 完全相同"
	).is_equal(BattleScreen.AFFINITY_PATH)
	assert_str(resolved.get("cards", "")).append_failure_message(
		"目前場次為 1、無 override 時,cards 路徑應與既有常數 CARDS_PATH 完全相同"
	).is_equal(BattleScreen.CARDS_PATH)

	# Cleanup
	CampaignProgress.reset_for_test()


# ---- 目前場次是序列表裡沒有的場次時,回退到既有常數,且不當掉 ----
#
# campaign_sequence.txt 今天只有第 1 列(第 2~5 場尚未製作,level-designer 的工作,
# 見該檔自己的註解)。用 advance_on_victory(5) 推進兩次把目前場次帶到 3——
# total_missions=5 這個參數純粹是為了繞過 advance_on_victory() 自己「已到最後一場」
# 的守衛,不是在宣稱序列表今天真的有 5 列。
func test_ready_at_mission_not_in_sequence_table_falls_back_to_existing_constants() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	# 2026-10-28 story-007(管理者裁決「兩支照建議改」):序列表已有 5 列,第 3 場不再「查不到」;
	# 改為推進到「總場數 + 1」(讀序列表,不寫死),斷言不放寬。
	var absent_mission: int = BattleScreen.campaign_total_missions() + 1
	for i: int in absent_mission - 1:
		CampaignProgress.advance_on_victory(absent_mission)
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"precondition:應已推進到總場數+1,否則下面的斷言證明不了「查不到」這個情境"
	).is_equal(absent_mission)

	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())

	# Act
	add_child(instance)

	# Assert —— 回退乾淨,不當掉,也不應被誤判為載入失敗
	assert_bool(instance._load_failed).append_failure_message(
		"場次 3 不在 campaign_sequence.txt 裡時應回退到既有常數——這是明文行為," +
		"不應被 _ready() 誤判為載入失敗"
	).is_false()

	var resolved: Dictionary = instance.diagnostic_resolved_data_paths()
	assert_str(resolved.get("terrain", "")).append_failure_message(
		"場次 3 查不到時,terrain 路徑應回退到既有常數 TERRAIN_PATH"
	).is_equal(BattleScreen.TERRAIN_PATH)
	assert_str(resolved.get("roster", "")).append_failure_message(
		"場次 3 查不到時,roster 路徑應回退到既有常數 ROSTER_PATH"
	).is_equal(BattleScreen.ROSTER_PATH)
	assert_str(resolved.get("affinity", "")).append_failure_message(
		"場次 3 查不到時,affinity 路徑應回退到既有常數 AFFINITY_PATH"
	).is_equal(BattleScreen.AFFINITY_PATH)
	assert_str(resolved.get("cards", "")).append_failure_message(
		"場次 3 查不到時,cards 路徑應回退到既有常數 CARDS_PATH"
	).is_equal(BattleScreen.CARDS_PATH)

	# Cleanup
	CampaignProgress.reset_for_test()


# ---- *_path_override 仍然壓過序列表(證明既有測試的注入路徑沒被破壞) ----
#
# 刻意在目前場次「查得到」的情況下(預設值 1,序列表有這一列)測 override 優先——
# 比只在「查不到」時測更嚴格:證明的是 override 的優先序無條件成立,不是只在序列表
# 沒有答案時才順位輪到它。terrain/roster 設 override,affinity/cards 不設,驗證兩種
# 路徑在同一次 _ready() 裡互不干擾。
func test_path_override_still_wins_over_sequence_table_at_mission_1() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH

	# Act
	add_child(instance)

	# Assert
	assert_bool(instance._load_failed).is_false()

	var resolved: Dictionary = instance.diagnostic_resolved_data_paths()
	assert_str(resolved.get("terrain", "")).append_failure_message(
		"terrain_path_override 應該永遠最優先,即使序列表查得到目前場次那一列"
	).is_equal(_TERRAIN_DUEL_PATH)
	assert_str(resolved.get("roster", "")).append_failure_message(
		"roster_path_override 應該永遠最優先,即使序列表查得到目前場次那一列"
	).is_equal(_ROSTER_DUEL_PATH)
	# 沒設定 override 的兩個仍走序列表/既有常數路徑(今天逐字相同,見第一條測試)
	assert_str(resolved.get("affinity", "")).append_failure_message(
		"affinity 沒有設定 override,應不受 terrain/roster 的 override 影響,仍解析為" +
		"既有常數 AFFINITY_PATH"
	).is_equal(BattleScreen.AFFINITY_PATH)
	assert_str(resolved.get("cards", "")).append_failure_message(
		"cards 沒有設定 override,應不受 terrain/roster 的 override 影響,仍解析為" +
		"既有常數 CARDS_PATH"
	).is_equal(BattleScreen.CARDS_PATH)

	# Cleanup
	CampaignProgress.reset_for_test()


# ---- 技術債(2026-10-27):卡面文字表跟著場次切換 ----
#
# 序列表第 6 欄 card_text_path。解析順序與 terrain/roster 相同:
# override -> 序列表該列 -> CARD_TEXT_PATH。
func test_card_text_path_follows_mission_from_sequence_table() -> void:
	# Arrange —— 場次 1:vs01
	CampaignProgress.reset_for_test()
	var m1: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(m1)
	var m1_path: String = m1.diagnostic_resolved_data_paths().get("card_text", "")
	remove_child(m1)

	# Arrange —— 場次 2:vs02
	CampaignProgress.advance_on_victory(2)
	assert_int(CampaignProgress.current_mission()).is_equal(2)
	var m2: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())

	# Act
	add_child(m2)
	var m2_path: String = m2.diagnostic_resolved_data_paths().get("card_text", "")

	# Assert
	assert_str(m1_path).is_equal("res://assets/data/cards/vs01_card_text.txt")
	assert_str(m2_path).append_failure_message(
		"第 2 場開局應讀 vs02_card_text.txt,而不是寫死的 vs01 表"
	).is_equal("res://assets/data/cards/vs02_card_text.txt")

	# Cleanup
	CampaignProgress.reset_for_test()


func test_card_text_path_override_wins_and_unknown_mission_falls_back_to_constant() -> void:
	# Arrange —— override 優先(場次 1,序列表查得到)
	CampaignProgress.reset_for_test()
	var with_override: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	with_override.card_text_path_override = "res://assets/data/cards/vs02_card_text.txt"

	# Act
	add_child(with_override)

	# Assert
	assert_str(with_override.diagnostic_resolved_data_paths().get("card_text", "")).is_equal(
		"res://assets/data/cards/vs02_card_text.txt"
	)
	remove_child(with_override)

	# Arrange —— 場次 3 不在序列表:回退 CARD_TEXT_PATH
	# 2026-10-28 story-007(管理者裁決「兩支照建議改」):同上,改為推進到「總場數 + 1」。
	var absent_mission: int = BattleScreen.campaign_total_missions() + 1
	for i: int in absent_mission - 1:
		CampaignProgress.advance_on_victory(absent_mission)
	var fallback: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())

	# Act
	add_child(fallback)

	# Assert
	assert_str(fallback.diagnostic_resolved_data_paths().get("card_text", "")).is_equal(
		BattleScreen.CARD_TEXT_PATH
	)

	# Cleanup
	CampaignProgress.reset_for_test()
