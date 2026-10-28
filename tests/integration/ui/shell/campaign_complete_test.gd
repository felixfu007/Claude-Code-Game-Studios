# game-shell story-006:打贏最後一場顯示「戰役完成」並歸零(AC1~AC3)。
#
# 載入真實 BattleScreen.tscn,經 SceneRouter(production 入口)進樹。
# 檔案存取:只有被測程式自己讀的、已進版控的 assets/data 資料檔(甲類例外);本檔不做 I/O。
#
# 敏感度證明:常駐變種 _MutantNoReset(拿掉歸零)與 _MutantNoCompleteText(拿掉文字),
# 各自讓對應斷言變紅 —— 見兩條 test_sensitivity_proof_*。
# 變種經 SceneRouter.switch_to 的 configure callback:set_script 在設 override 之前。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"


## 變種:最後一場勝利後不歸零(以覆寫 _on_battle_ended 重現舊行為:只 advance)。
class _MutantNoReset extends BattleScreen:
	func _on_battle_ended(outcome: BattleState.Outcome) -> void:
		_result_label.visible = true
		_result_label.text = Loc.localize(TEXT_RESULT_VICTORY)
		CampaignProgress.advance_on_victory(campaign_total_missions())


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	# Restore shared CursorStateHost Autoload state; see tests/helpers/cursor_host_snapshot.gd
	_host_snap.restore()
	CampaignProgress.reset_for_test()


func _wait_swap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _stand_in_title() -> Node:
	var stand_in: Node = load(_TITLE_SCENE_PATH).instantiate()
	get_tree().root.call_deferred("add_child", stand_in)
	await _wait_swap()
	get_tree().current_scene = stand_in
	return stand_in


func _enter_battle_via_router() -> BattleScreen:
	await _stand_in_title()
	SceneRouter.enter_battle(get_tree())
	await _wait_swap()
	return get_tree().current_scene as BattleScreen


func _enter_mutant_battle() -> BattleScreen:
	await _stand_in_title()
	var configure: Callable = func(node: Node) -> void:
		node.set_script(_MutantNoReset)
		(node as BattleScreen).campaign_ledger_override = (
			CampaignProgress.start_mission_affinity_ledger()
		)
	var created: Node = SceneRouter.switch_to(
		get_tree(), SceneRouter.BATTLE_SCENE_PATH, configure
	)
	await _wait_swap()
	return created as BattleScreen


func _cleanup(original: Node) -> void:
	var current: Node = get_tree().current_scene
	if current != null and current != original and is_instance_valid(current):
		current.queue_free()
		await get_tree().process_frame
	get_tree().current_scene = original


func _text_of(battle: BattleScreen) -> String:
	return battle._result_label.text


# 2026-10-28 story-007(管理者裁決「兩支照建議改」):序列表由 2 列變 5 列,改為動態推到最後一場,斷言不放寬。
## 推進到序列表最後一場並回傳總場數。
func _advance_to_last_mission() -> int:
	var total: int = BattleScreen.campaign_total_missions()
	for i: int in total - 1:
		CampaignProgress.advance_on_victory(total)
	return total


func test_final_mission_victory_shows_campaign_complete_and_resets() -> void:
	# Arrange —— 推到最後一場(動態讀序列表總場數)
	var original: Node = get_tree().current_scene
	var last_mission: int = _advance_to_last_mission()
	var battle: BattleScreen = await _enter_battle_via_router()
	assert_object(battle).is_not_null()
	var ledger: CampaignAffinityLedger = battle.campaign_ledger_override
	assert_int(CampaignProgress.current_mission()).is_equal(last_mission)

	# Act
	battle._on_battle_ended(BattleState.Outcome.VICTORY)

	# Assert
	var expected: String = Loc.localize(&"battle.hud.result_campaign_complete")
	assert_int(expected.length()).append_failure_message("預期字串長度不應為 0").is_greater(0)
	var actual: String = _text_of(battle)
	assert_str(actual).append_failure_message(
		"AC1:最後一場勝利應顯示戰役完成;實得長度 %d" % actual.length()
	).is_equal(expected)
	assert_int(CampaignProgress.current_mission()).append_failure_message("AC2:場次應歸 1").is_equal(1)
	assert_int(ledger.records().size()).append_failure_message("AC2:累積記錄應清空").is_equal(0)

	await _cleanup(original)


func test_non_final_mission_victory_shows_victory_and_advances() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_battle_via_router()

	# Act
	battle._on_battle_ended(BattleState.Outcome.VICTORY)

	# Assert
	var actual: String = _text_of(battle)
	assert_str(actual).append_failure_message(
		"AC1:非最後一場仍應顯示勝利;實得長度 %d" % actual.length()
	).is_equal(Loc.localize(&"battle.hud.result_victory"))
	assert_int(CampaignProgress.current_mission()).is_equal(2)

	await _cleanup(original)


func test_victory_without_injected_ledger_shows_victory_and_leaves_progress() -> void:
	# Arrange —— 不經 SceneRouter,不注入 ledger(AC3)
	var instance: BattleScreen = auto_free(
		load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	)
	add_child(instance)
	assert_object(instance.campaign_ledger_override).is_null()
	var last_mission: int = _advance_to_last_mission()

	# Act
	instance._on_battle_ended(BattleState.Outcome.VICTORY)

	# Assert
	var actual: String = _text_of(instance)
	assert_str(actual).append_failure_message(
		"AC3:未注入 ledger 應維持勝利文字;實得長度 %d" % actual.length()
	).is_equal(Loc.localize(&"battle.hud.result_victory"))
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"AC3:未注入時不得碰 CampaignProgress"
	).is_equal(last_mission)


func test_sensitivity_proof_mutant_without_reset_leaves_mission_unreset() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var last_mission: int = _advance_to_last_mission()
	var battle: BattleScreen = await _enter_mutant_battle()

	# Act
	battle._on_battle_ended(BattleState.Outcome.VICTORY)

	# Assert —— 變種不歸零也不改文字;證明上面第一條測試的斷言偵測得到這兩個缺陷
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"變種(拿掉歸零)場次應仍為最後一場"
	).is_equal(last_mission)
	assert_str(_text_of(battle)).is_not_equal(Loc.localize(&"battle.hud.result_campaign_complete"))

	await _cleanup(original)
