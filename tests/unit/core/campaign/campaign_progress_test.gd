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
