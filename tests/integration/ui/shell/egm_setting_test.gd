## story-002-minimal-settings-screen.md —— 整合測試,涵蓋:
##   - AC1(GameSettings 預設關閉)
##   - AC3(戰鬥開始後改設定,不影響進行中那一場;連帶證明 AC2「只讀一次」)
##   - AC8(戰鬥中 BattleMenu 顯示唯讀 EGM 狀態)
##   - story-004(標題畫面自動開戰旗標,管理者 2026-10-19 裁決「跟著 story-002 一起做」)
##
## 🔴 AC4/AC5/AC6/AC7(設定畫面本體的場景切換、三種輸入裝置導覽、在地化)— 誠實
## 登記為本檔【未涵蓋】,不是遺漏:協調者明文指示若來回切換測試會花掉很多回合就跳過,
## 優先交付一份誠實的部分交付。`src/ui/shell/settings_screen.gd` /
## `src/ui/shell/SettingsScreen.tscn` 的實作本身已完成(比照 `title_screen.gd` 的
## 既有慣例:FOCUS_ALL + 手動 focus_neighbor + 原生 CheckButton/Button),但本批
## 沒有寫 `title_screen_scene_switch_test.gd` 那樣的場景切換回歸測試。
##
## 真實場景載入,比照既有慣例(`battle_screen_battle_outcome_test.gd` 等):
## load() 真實 .tscn,不自組替身節點鏈。
##
## 🔴 凡呼叫 GameSettings.set_egm_enabled() 的測試,收尾一律呼叫
## GameSettings.reset_for_test() —— 本專案已實機驗證 static var 會跨測試檔案共用
## 狀態(見 `prototypes/godot-specialist-static-var-probe-2026-10-19/README.md`),
## 不清理會污染同一次 headless 執行期間的其他測試。
extends GdUnitTestSuite

const _BATTLE_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


# ---- AC1:預設關閉 ---------------------------------------------------------

func test_game_settings_defaults_to_disabled() -> void:
	# Arrange — 先重置,確保不受同一次 run 裡其他測試殘留值影響
	GameSettings.reset_for_test()

	# Act / Assert
	assert_bool(GameSettings.is_egm_enabled()).append_failure_message(
		"AC1:GameSettings 的 EGM 開關應預設關閉(迴歸安全 —— EGM 關閉時行為須與現狀" +
		"完全相同)"
	).is_false()

	# Cleanup
	GameSettings.reset_for_test()


# ---- AC2/AC3:只在 _ready() 讀一次,戰鬥開始後改設定不影響進行中那一場 --------

func test_battle_in_progress_is_unaffected_by_later_setting_change() -> void:
	# Arrange
	GameSettings.reset_for_test()
	GameSettings.set_egm_enabled(true)
	var instance: BattleScreen = auto_free(load(_BATTLE_SCENE_PATH).instantiate())

	# Act — 真正讓 _ready() 跑一次,快取當下的 GameSettings 值
	add_child(instance)
	assert_bool(instance.is_egm_enabled_for_this_battle()).append_failure_message(
		"AC2:BattleScreen._ready() 應讀到 GameSettings 當時的值(true)並快取"
	).is_true()

	# Act — 戰鬥已經開始之後才改變設定
	GameSettings.set_egm_enabled(false)

	# Assert — AC3 核心斷言:進行中這一場不受影響,快取值維持原樣
	assert_bool(instance.is_egm_enabled_for_this_battle()).append_failure_message(
		"AC3:戰鬥開始後變更 GameSettings 不應影響進行中這一場 —— " +
		"BattleScreen 只在 _ready() 讀一次,這裡應仍是 true,不應跟著變成 false"
	).is_true()

	# Cleanup
	GameSettings.reset_for_test()


# ---- AC8:戰鬥中 BattleMenu 顯示唯讀 EGM 狀態 ---------------------------------

func test_battle_menu_shows_readonly_egm_status_when_opened() -> void:
	# Arrange
	GameSettings.reset_for_test()
	GameSettings.set_egm_enabled(true)
	var instance: BattleScreen = auto_free(load(_BATTLE_SCENE_PATH).instantiate())
	add_child(instance)

	var menu: BattleMenu = instance.get_node("UILayer/BattleMenu")
	assert_bool(menu.egm_enabled).append_failure_message(
		"前提:BattleScreen._ready() 應已把快取值注入 BattleMenu.egm_enabled"
	).is_true()

	# Act — 開啟選單(_refresh_egm_status_label() 的第二個呼叫點,見 battle_menu.gd
	# 的 doc comment:_ready() 執行當下子節點先於父節點就緒,egm_enabled 此刻仍是
	# 預設 false,必須靠 open() 重新讀一次才會反映真值)
	var result: BattleMenu.OpenResult = menu.open()
	assert_int(result).append_failure_message(
		"前提:open() 不應被拒絕(本測試未注入任何權威寫入/強制棄牌情境)"
	).is_equal(BattleMenu.OpenResult.OPENED)

	# Assert — AC8 核心斷言:唯讀狀態行顯示的是「開啟」,且是透過 Loc.localize()
	# 格式化出來的文字,不是硬編字面值(AC7 同一精神延伸到這個新元件)
	var status_label: Label = menu.get_node("EgmStatusLabel")
	var expected_text: String = Loc.localize(BattleMenu.EGM_STATUS_FORMAT) % [
		Loc.localize(BattleMenu.EGM_STATUS_ON)
	]
	assert_str(status_label.text).append_failure_message(
		"AC8:戰鬥中 BattleMenu 應顯示 EGM 目前值(開啟),實得 '%s'" % status_label.text
	).is_equal(expected_text)

	# Assert — 🔴 本行是 AC8「不可互動變更」的結構性證明:本檔案找不到任何地方把
	# EgmStatusLabel 接上可觸發寫入的信號 —— 它是純 Label,FOCUS_NONE、
	# mouse_filter=IGNORE(見 BattleMenu.tscn 的節點宣告),玩家沒有任何操作路徑
	# 能從這裡改變 GameSettings。
	assert_int(status_label.focus_mode).append_failure_message(
		"AC8:唯讀狀態行不應可被鍵盤/手把導覽選取到(focus_mode 應為 FOCUS_NONE)"
	).is_equal(Control.FOCUS_NONE)

	# Cleanup — 與 open() 配對,恢復 get_tree().paused / CursorStateHost 裁定狀態
	menu.close()
	GameSettings.reset_for_test()


# ---- story-004:標題畫面自動開戰旗標(純函式,見 title_screen.gd 的揭露) --------

func test_should_auto_start_battle_true_when_flag_present() -> void:
	# Arrange
	var args: PackedStringArray = ["--headless", "--path", ".", TitleScreen.AUTO_START_BATTLE_FLAG]

	# Act / Assert
	assert_bool(TitleScreen.should_auto_start_battle(args)).append_failure_message(
		"story-004:命令列參數內含 AUTO_START_BATTLE_FLAG 時應回傳 true"
	).is_true()


func test_should_auto_start_battle_false_when_flag_absent() -> void:
	# Arrange
	var args: PackedStringArray = ["--headless", "--path", "."]

	# Act / Assert
	assert_bool(TitleScreen.should_auto_start_battle(args)).append_failure_message(
		"story-004:命令列參數不含 AUTO_START_BATTLE_FLAG 時應回傳 false —— " +
		"兩個方向都要測,只測有旗標那一邊無法分辨函式是不是恆真回傳 true"
	).is_false()
