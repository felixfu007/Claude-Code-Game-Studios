## production/epics/game-shell/story-003-campaign-flow-and-transition-slots.md
## AC3(勝利推進 + 最後一場終態)/ AC4(失敗不前進)。
##
## 🔴 本檔動到 [CampaignProgress] 的 static var —— 每條會呼叫
## [method CampaignProgress.advance_on_victory] 的測試,開頭與收尾一律呼叫
## [method CampaignProgress.reset_for_test](比照 [code]GameSettings[/code] 的
## 既有紀律,見該檔類別文件註解「已知代價」第 2 點)。
extends GdUnitTestSuite

const _TOTAL_MISSIONS: int = 5


func test_default_current_mission_is_one() -> void:
	# Arrange
	CampaignProgress.reset_for_test()

	# Act / Assert
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"全新戰役應從第 1 場開始(FIRST_MISSION_INDEX)"
	).is_equal(1)

	# Cleanup
	CampaignProgress.reset_for_test()


func test_victory_advances_to_next_mission() -> void:
	# Arrange
	CampaignProgress.reset_for_test()

	# Act
	var result: CampaignProgress.AdvanceResult = CampaignProgress.advance_on_victory(_TOTAL_MISSIONS)

	# Assert
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"AC3:第 1 場勝利後應前進到第 2 場"
	).is_equal(2)
	assert_int(result).append_failure_message(
		"AC3:尚未到最後一場,advance_on_victory() 應回傳 ADVANCED"
	).is_equal(CampaignProgress.AdvanceResult.ADVANCED)

	# Cleanup
	CampaignProgress.reset_for_test()


func test_victory_on_last_mission_reaches_campaign_complete_without_advancing_past_it() -> void:
	# Arrange — 連續推進到最後一場(第 5 場)
	CampaignProgress.reset_for_test()
	for _i in range(_TOTAL_MISSIONS - 1):
		CampaignProgress.advance_on_victory(_TOTAL_MISSIONS)
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"precondition:應已推進到第 %d 場" % _TOTAL_MISSIONS
	).is_equal(_TOTAL_MISSIONS)

	# Act — 最後一場再度勝利
	var result: CampaignProgress.AdvanceResult = CampaignProgress.advance_on_victory(_TOTAL_MISSIONS)

	# Assert
	assert_int(result).append_failure_message(
		"AC3:終態必須是明確的狀態 —— 最後一場勝利後應回傳 CAMPAIGN_COMPLETE," +
		"不是靜默停住"
	).is_equal(CampaignProgress.AdvanceResult.CAMPAIGN_COMPLETE)
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"最後一場勝利後不應再前進出界(仍應停在第 %d 場)" % _TOTAL_MISSIONS
	).is_equal(_TOTAL_MISSIONS)

	# Cleanup
	CampaignProgress.reset_for_test()


func test_defeat_does_not_advance_mission() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	CampaignProgress.advance_on_victory(_TOTAL_MISSIONS)  # 先推進到第 2 場
	var before: int = CampaignProgress.current_mission()

	# Act
	CampaignProgress.rollback_on_defeat()

	# Assert
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"AC4:失敗不應改變場次編號"
	).is_equal(before)

	# Cleanup
	CampaignProgress.reset_for_test()


## 敏感度證明:reset_for_test() 真的把狀態還原,不是巧合地看起來還原。
func test_sensitivity_proof_reset_for_test_restores_default() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	CampaignProgress.advance_on_victory(_TOTAL_MISSIONS)
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"precondition:advance_on_victory() 應已改變狀態,否則下面的斷言證明不了任何事"
	).is_not_equal(1)

	# Act
	CampaignProgress.reset_for_test()

	# Assert
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"reset_for_test() 應該把 static var 還原成預設值 1,否則會污染同一次執行" +
		"期間的其他測試"
	).is_equal(1)


# ============================================================================
# 第三輪接線(story-003-cross-mission-affinity-continuity.md「下一輪接線」)——
# CampaignAffinityLedger 持有者選「甲」,掛在本類別上。
# ============================================================================


## 🔴 陷阱防線的證明(見 campaign_affinity_ledger.gd 類別文件註解「忘了呼叫的
## 後果」,以及 campaign_progress.gd 類別文件註解「結構防線」段)—— 本輪選的是
## (a) 結構上不可能忘記:[method CampaignProgress.start_mission_affinity_ledger]
## 是取得 ledger 的唯一入口,內部必定呼叫 [method CampaignAffinityLedger.begin_mission]。
##
## 本測試分兩段:先繞過 CampaignProgress、手動 [code]CampaignAffinityLedger.new()[/code]
## 卻忘了呼叫 begin_mission(),重現陷阱本身(證明它是真的會發生,不是編出來的
## 假設);再透過 [method CampaignProgress.start_mission_affinity_ledger] 走同樣的
## 操作序列,證明歷史不會被一起清空——因為呼叫端沒有任何管道能繞過 begin_mission()。
func test_sensitivity_proof_start_mission_affinity_ledger_prevents_forgotten_begin_mission() -> void:
	# ---- 重現陷阱本身:繞過 CampaignProgress,手動持有 ledger、忘了呼叫 begin_mission() ----
	var raw_ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	raw_ledger.append(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT)  # 第 1 場的歷史
	raw_ledger.append(AffinityTypes.Pair.C3_C4, 1.0, AffinityTypes.Source.STORY_EVENT)  # 第 1 場的歷史
	# 「第 2 場」忘了呼叫 begin_mission() —— 直接疊加新變化
	raw_ledger.append(AffinityTypes.Pair.C1_C3, -1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	raw_ledger.rollback_current_mission()
	assert_int(raw_ledger.records().size()).append_failure_message(
		"重現陷阱:忘了呼叫 begin_mission() 時,基準點停在建構當下的 0," +
		"rollback_current_mission() 會把連同更早場次的歷史一起清空 —— 這是上一輪" +
		"實作者主動揭露的陷阱,本斷言證明它是真的會發生,不是假設"
	).is_equal(0)

	# ---- 透過 CampaignProgress 走正確路徑:同樣的操作序列,歷史不會被清掉 ----
	CampaignProgress.reset_for_test()
	var ledger1: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	ledger1.append(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT)
	ledger1.append(AffinityTypes.Pair.C3_C4, 1.0, AffinityTypes.Source.STORY_EVENT)
	CampaignProgress.advance_on_victory(_TOTAL_MISSIONS)  # 第 1 場勝利,併入歷史

	# 第 2 場開始 —— 呼叫端唯一的入口,結構上必定重新 begin_mission()
	var ledger2: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	ledger2.append(AffinityTypes.Pair.C1_C3, -1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	CampaignProgress.rollback_on_defeat()  # 第 2 場打輸

	assert_int(ledger2.records().size()).append_failure_message(
		"透過 CampaignProgress.start_mission_affinity_ledger() 取得 ledger 時," +
		"結構上不可能忘記呼叫 begin_mission() —— 回滾應只丟棄第 2 場新增的 1 筆," +
		"保留前 2 筆歷史,實得 %d 筆" % ledger2.records().size()
	).is_equal(2)

	# Cleanup
	CampaignProgress.reset_for_test()


## [method start_mission_affinity_ledger] 回傳的是同一個共用實例的參照,不是
## 每次呼叫重新 new() 一份 —— 這是上面那條敏感度證明成立的前提(ledger1/ledger2
## 操作的必須是同一份累積歷史),本測試單獨把這個前提釘住。
func test_start_mission_affinity_ledger_returns_same_instance_across_calls() -> void:
	# Arrange
	CampaignProgress.reset_for_test()

	# Act
	var first: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	var second: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()

	# Assert
	assert_object(second).append_failure_message(
		"start_mission_affinity_ledger() 應回傳同一個共用實例的參照,否則第二次" +
		"呼叫取得的 ledger 看不到前一場累積的歷史"
	).is_same(first)

	# Cleanup
	CampaignProgress.reset_for_test()


## AC4(失敗回滾)在 CampaignProgress 這一層的直接驗證:rollback_on_defeat()
## 真的呼叫了 ledger 的 rollback_current_mission(),不是場次編號不前進那半句
## pass 被誤讀成「什麼都不用做」。
func test_rollback_on_defeat_discards_entries_added_since_start_mission() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	ledger.append(AffinityTypes.Pair.C2_C5, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	assert_int(ledger.records().size()).append_failure_message(
		"precondition:append() 應已讓記錄非空,否則下面的斷言證明不了任何事"
	).is_equal(1)

	# Act
	CampaignProgress.rollback_on_defeat()

	# Assert
	assert_int(ledger.records().size()).append_failure_message(
		"rollback_on_defeat() 應該呼叫 CampaignAffinityLedger.rollback_current_mission()" +
		"把本場新增的記錄丟棄"
	).is_equal(0)

	# Cleanup
	CampaignProgress.reset_for_test()


## reset_for_test() 的敏感度證明延伸:連 ledger 也一併清空,不是只清場次編號。
func test_sensitivity_proof_reset_for_test_also_clears_affinity_ledger() -> void:
	# Arrange
	CampaignProgress.reset_for_test()
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	ledger.append(AffinityTypes.Pair.C1_C4, 1.0, AffinityTypes.Source.STORY_EVENT)
	assert_int(ledger.records().size()).append_failure_message(
		"precondition:append() 應已讓記錄非空,否則下面的斷言證明不了任何事"
	).is_equal(1)

	# Act
	CampaignProgress.reset_for_test()

	# Assert —— 重新取得的 ledger(同一個共用實例)應該是空的
	var ledger_after_reset: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	assert_int(ledger_after_reset.records().size()).append_failure_message(
		"reset_for_test() 應該把 _affinity_ledger 也清空,否則會污染同一次執行" +
		"期間的其他測試(跨測試靜態狀態洩漏,見 .claude/rules/gameplay-code.md" +
		"2026-10-19 裁決④的已知代價)"
	).is_equal(0)

	# Cleanup
	CampaignProgress.reset_for_test()
