# 戰鬥中途「回主選單」回滾本場累積記錄(game-shell story-005 後續技術債,2026-10-27)。
#
# 載入真實 BattleScreen.tscn,經 SceneRouter(production 入口)進樹。
# 檔案存取:只有被測程式自己讀的、已進版控的 assets/data 資料檔(甲類例外);
# 本檔自己不做 I/O。
#
# 涵蓋:(a) 放棄 -> 本場記錄消失、前一場還在、場次不變、回到標題;
#       (b) 對照:勝利後計時器走的 return_to_title_screen() 不回滾;
#       (c) 接線:BattleMenu.return_to_title_callable 有效。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"


## 常駐變種(敏感度證明):abandon_mission_to_title 拿掉回滾。
class _MutantAbandonNoRollback extends BattleScreen:
	func abandon_mission_to_title() -> void:
		if not is_inside_tree():
			return
		SceneRouter.go_to_title(get_tree())


func before_test() -> void:
	CampaignProgress.reset_for_test()


func after_test() -> void:
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


## 先放「前一場」留下的一筆記錄,再進戰鬥(begin_mission 把基準點挪到它之後)。
func _append_earlier_mission_record() -> void:
	CampaignProgress.start_mission_affinity_ledger().append(
		AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)


func _append_this_mission_record(battle: BattleScreen) -> void:
	battle.campaign_ledger_override.append(
		AffinityTypes.Pair.C1_C3, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)


func _enter_battle_via_router() -> BattleScreen:
	await _stand_in_title()
	SceneRouter.enter_battle(get_tree())
	await _wait_swap()
	return get_tree().current_scene as BattleScreen


func _enter_mutant_battle() -> BattleScreen:
	await _stand_in_title()
	var configure: Callable = func(node: Node) -> void:
		# 🔴 set_script 必須在賦值 override 之前(coding-standards.md 已登記)。
		node.set_script(_MutantAbandonNoRollback)
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


func test_abandon_rolls_back_this_mission_but_keeps_earlier_missions() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	_append_earlier_mission_record()
	var battle: BattleScreen = await _enter_battle_via_router()
	assert_object(battle).is_not_null()
	var ledger: CampaignAffinityLedger = battle.campaign_ledger_override
	assert_object(ledger).is_not_null()
	_append_this_mission_record(battle)
	assert_int(ledger.records().size()).is_equal(2)
	var mission_before: int = CampaignProgress.current_mission()

	# Act
	battle.abandon_mission_to_title()
	await _wait_swap()

	# Assert
	var records: Array[CampaignAffinityLedger.Entry] = ledger.records()
	assert_int(records.size()).append_failure_message(
		"放棄後只應剩前一場的 1 筆,實得 %d" % records.size()
	).is_equal(1)
	assert_int(records[0].pair).is_equal(AffinityTypes.Pair.C1_C2)
	assert_int(CampaignProgress.current_mission()).is_equal(mission_before)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(_TITLE_SCENE_PATH)

	await _cleanup(original)


func test_return_to_title_screen_after_victory_does_not_roll_back() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	_append_earlier_mission_record()
	var battle: BattleScreen = await _enter_battle_via_router()
	var ledger: CampaignAffinityLedger = battle.campaign_ledger_override
	_append_this_mission_record(battle)

	# Act
	battle.return_to_title_screen()
	await _wait_swap()

	# Assert
	assert_int(ledger.records().size()).append_failure_message(
		"return_to_title_screen()(勝利後計時器走的路徑)不得回滾"
	).is_equal(2)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(_TITLE_SCENE_PATH)

	await _cleanup(original)


func test_battle_menu_return_to_title_is_wired_to_battle_screen() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_battle_via_router()

	# Act
	var menu: Node = battle._battle_menu

	# Assert
	assert_bool(menu.return_to_title_callable.is_valid()).is_true()
	assert_bool(menu.diagnostic_would_call_real_return_to_title()).is_false()
	assert_bool(menu.return_to_title_callable == Callable(battle, "abandon_mission_to_title")).is_true()

	await _cleanup(original)


func test_sensitivity_proof_mutant_without_rollback_keeps_this_mission_record() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	_append_earlier_mission_record()
	var battle: BattleScreen = await _enter_mutant_battle()
	var ledger: CampaignAffinityLedger = battle.campaign_ledger_override
	_append_this_mission_record(battle)

	# Act
	battle.abandon_mission_to_title()
	await _wait_swap()

	# Assert — 變種沒回滾,本場那筆仍在;上面第一條測試要求只剩 1 筆,所以它在變種下會紅
	assert_int(ledger.records().size()).append_failure_message(
		"變種(拿掉回滾)應留下 2 筆,證明第一條測試的斷言偵測得到「沒回滾」"
	).is_equal(2)

	await _cleanup(original)
