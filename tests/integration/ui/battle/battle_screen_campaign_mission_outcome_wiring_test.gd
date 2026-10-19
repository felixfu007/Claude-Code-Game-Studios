## BattleScreen._on_battle_ended() 接上 CampaignProgress / CampaignAffinityLedger
## 的生命週期 —— 裁決①第三輪(production/epics/support-conversation/
## story-003-cross-mission-affinity-continuity.md「下一輪接線」)。
##
## 本檔涵蓋:
##   - 持有者裁決(甲:掛在既有的 CampaignProgress 上)在 BattleScreen 這一端的
##     實際效果 —— CampaignProgress.start_mission_affinity_ledger() 取得的 ledger
##     注入 campaign_ledger_override 後,_on_battle_ended() 對 VICTORY/DEFEAT
##     兩種結算的接線。
##   - AC4 真正的驗收:打輸再打一次,開局狀態與第一次相同。
##
## 🔴 本檔不涵蓋、刻意誠實登記(任務報告重複一次,這裡也寫一份,讀這個檔案的人
## 不必跳去另一個檔案才看得到):
##   - 本輪沒有把任何「戰鬥中產生好感度變化」的寫入口接到 campaign_ledger_override
##     ——AC4 測試用直接呼叫 ledger.append() 模擬「這一場打到一半有新變化」,
##     不經過真實的卡牌/支援對話寫入路徑(那些路徑本身尚未接線)。
##   - production 尚未真的把 campaign_ledger_override 接起來(title_screen.gd 用
##     change_scene_to_file() 切場景,沒有資料注入的時機窗)—— 見
##     campaign_ledger_override 自己的 doc comment。本檔測試一律手動注入。
##
## 載入真實場景的寫法沿用既有先例:
## tests/integration/ui/battle_screen_impassable_terrain_scan_test.gd(override
## 時機合約:instantiate() 之後、add_child() 之前)。
##
## 🔴 直接呼叫 instance._on_battle_ended(outcome) 而非像
## battle_screen_battle_outcome_test.gd 那樣驅動真實戰鬥到結算 —— 這是刻意的
## 範圍選擇:本檔要驗證的是「_on_battle_ended() 收到某個 outcome 之後怎麼反應」,
## 不是「outcome 怎麼被判定出來」,後者已經由 battle_screen_battle_outcome_test.gd
## 涵蓋。這個技巧與該檔自己文件註解描述的 return_to_title_screen() 測試慣例
## 「測試直接呼叫公開方法,不模擬 InputEvent/計時器」同一精神。
##
## ⚠️ 敏感度證明——誠實登記為「做不到」(test-standards.md 門檻義務,屬已知
## 證明不了的 D 類:「唯一有意義的注入點在受限範圍外」):本檔斷言的
## CampaignProgress/CampaignAffinityLedger 側已經由
## tests/unit/core/campaign/campaign_progress_test.gd 的常駐敏感度證明覆蓋
## (test_sensitivity_proof_start_mission_affinity_ledger_prevents_forgotten_begin_mission
## 等)。本檔要再證明一次「如果 _on_battle_ended() 忘了呼叫 rollback_on_defeat()
## 會怎樣」,唯一有意義的注入點就是改寫 _on_battle_ended() 本身的生產邏輯 ——
## 本檔改用 AC4 的端對端斷言(第二次開局狀態與第一次相同)作為保障層級,
## 比「證明不了就不寫」更弱但誠實。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


func _load_instance_with_ledger(ledger: CampaignAffinityLedger) -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.campaign_ledger_override = ledger
	add_child(instance)
	return instance


# ---- AC4 真正的驗收:打輸再打一次,開局狀態與第一次相同 ----
func test_defeat_then_replay_same_mission_starts_from_identical_affinity_state() -> void:
	# Arrange —— 第一次挑戰:透過 CampaignProgress 取得 ledger(唯一入口,內部已
	# begin_mission())
	CampaignProgress.reset_for_test()
	var ledger_run1: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()

	var instance1: BattleScreen = _load_instance_with_ledger(ledger_run1)
	assert_bool(instance1._load_failed).is_false()

	# 第一次開局時,戰役層累積記錄還是空的 —— 用 _phi.links()(與既有迴歸鎖測試
	# battle_screen_campaign_affinity_ledger_seeding_test.gd 同一個既有慣例)確認
	# 只有靜態 AFFINITY_PATH 灌入的那兩條關係
	var links_run1_opening: int = instance1._phi.links().size()
	assert_int(links_run1_opening).append_failure_message(
		"precondition:第一次開局應只看到靜態 AFFINITY_PATH 的關係,ledger 還是空的," +
		"實得 %d 條" % links_run1_opening
	).is_equal(2)

	# Act —— 模擬「這一場打到一半,產生了新的好感度變化」:直接 append 進
	# campaign_ledger_override 持有的同一個 ledger 參照(本輪沒有接真正的寫入口,
	# 見本檔檔頭誠實登記)
	ledger_run1.append(AffinityTypes.Pair.C1_C4, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	assert_int(ledger_run1.records().size()).is_equal(1)

	# Act —— 這一場打輸了
	instance1._on_battle_ended(BattleState.Outcome.DEFEAT)

	# Assert —— 回滾後,戰役層累積記錄回到開打前(AC4 的核心保證)
	assert_int(ledger_run1.records().size()).append_failure_message(
		"DEFEAT 應該呼叫 CampaignProgress.rollback_on_defeat() 把本場新增的記錄" +
		"丟棄,實得 %d 筆殘留" % ledger_run1.records().size()
	).is_equal(0)

	# Act —— 再打一次同一場:production 真正的下一步就是再呼叫一次
	# start_mission_affinity_ledger()(陷阱防線所在 —— 它必定重新 begin_mission())
	var ledger_run2: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	assert_object(ledger_run2).append_failure_message(
		"start_mission_affinity_ledger() 應回傳同一個共用實例,否則第二次挑戰拿不到" +
		"第一次累積(或這裡應為零)的歷史"
	).is_same(ledger_run1)

	var instance2: BattleScreen = _load_instance_with_ledger(ledger_run2)
	assert_bool(instance2._load_failed).is_false()

	# Assert —— 第二次開局的好感度關係數與第一次完全相同(AC4:「開局狀態與第一次
	# 相同」),而不是把那筆被打輸丟掉的記錄也一起帶進來
	var links_run2_opening: int = instance2._phi.links().size()
	assert_int(links_run2_opening).append_failure_message(
		(
			"打輸再打一次,開局好感度關係數應與第一次相同(第一次 %d 條),實得 %d 條" +
			" —— 代表回滾沒有生效,殘留了這一場輸掉之前新增的變化"
		) % [links_run1_opening, links_run2_opening]
	).is_equal(links_run1_opening)

	# Cleanup
	CampaignProgress.reset_for_test()


# ---- 勝利路徑:VICTORY 應呼叫 CampaignProgress.advance_on_victory(),不回滾 ----
#
# campaign_sequence.txt 目前只有第 1 列(見該檔自己的註解:第 2~5 場尚未製作),
# 所以 campaign_total_missions() == 1,第 1 場勝利即達成 CAMPAIGN_COMPLETE——
# 這不是本測試編造的情境,是資料驅動下今天真實會發生的結果(coding-standards.md:
# gameplay values 一律外部設定檔,本檔不得改寫成假的場次總數)。
func test_victory_advances_campaign_progress_and_keeps_new_entries() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	var instance: BattleScreen = _load_instance_with_ledger(ledger)
	assert_bool(instance._load_failed).is_false()

	ledger.append(AffinityTypes.Pair.C2_C5, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)

	# Act
	instance._on_battle_ended(BattleState.Outcome.VICTORY)

	# Assert —— AC3:勝利併入累積(不回滾,新記錄留著)
	assert_int(ledger.records().size()).append_failure_message(
		"VICTORY 不應呼叫 rollback_current_mission() —— 本場新增的記錄應該保留" +
		"(AC3:併入累積),實得 %d 筆" % ledger.records().size()
	).is_equal(1)

	# Assert —— AC3:場次推進判斷。campaign_sequence.txt 今天只有 1 列,
	# 故預期終態是 CAMPAIGN_COMPLETE(見本函式文件註解)
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"campaign_sequence.txt 今天只有 1 列,VICTORY 不應該把場次推進到不存在的" +
		"第 2 場"
	).is_equal(1)

	# Cleanup
	CampaignProgress.reset_for_test()


# ---- 迴歸鎖:不注入 campaign_ledger_override 時,_on_battle_ended() 完全不碰 CampaignProgress ----
func test_on_battle_ended_without_campaign_ledger_override_does_not_touch_campaign_progress() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	assert_object(instance.campaign_ledger_override).is_null()
	var mission_before: int = CampaignProgress.current_mission()

	# Act —— 不注入 campaign_ledger_override 時,VICTORY 與 DEFEAT 都不該動
	# CampaignProgress 的靜態狀態
	instance._on_battle_ended(BattleState.Outcome.VICTORY)

	# Assert
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"campaign_ledger_override 為 null 時,_on_battle_ended() 不應呼叫" +
		"CampaignProgress.advance_on_victory() —— 既有的、沒有被注入戰役層 ledger" +
		"的 BattleScreen 實例(本專案目前絕大多數既有測試)不應受本輪接線影響"
	).is_equal(mission_before)

	# Cleanup
	CampaignProgress.reset_for_test()
