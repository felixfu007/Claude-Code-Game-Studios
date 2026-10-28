# production/epics/support-conversation-ui/story-004-transition-wiring.md
# 整合測試 —— 勝利 -> (支援對話畫面) -> 下一場 的轉場分流。
#
# 載入真實 BattleScreen.tscn / SupportConversationScreen.tscn,經 SceneRouter(production
# 的切換入口)換場。測試直接呼叫 BattleScreen._on_result_display_finished()(結果顯示計時器
# 的 timeout 處理函式),不等 RESULT_DISPLAY_SECONDS 真實時間。
#
# 檔案存取:只有被測程式自己讀的、已進版控的 assets/data 資料檔(甲類例外);本檔不做 I/O。
#
# 🔴 揭露(2026-10-28 story-007 更新):
#   - 序列表現為 5 列。AC2「第 4 場勝利 -> 第 5 場」改為真實第 4 場(CampaignProgress 推進到
#     第 4 場、不手動清空播放清單),分流由「第 4 槽位在 support_conversations.txt 無記錄」決定。
#   - 戰鬥內容用夾具(duel 地形 + 勝利名冊),不是 vs03~vs05 真實關卡;真實關卡載入由
#     campaign_all_missions_load_test.gd 負責。本檔證明的是「第 N 場勝利 -> 分流」,
#     不證明在真實 vs0N 關卡上能打贏(未驗證)。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_VICTORY_ALLY_PATH: String = "res://assets/data/units/test_fixture_roster_victory_with_ally.txt"
const _ROSTER_FOUR_ALLIES_PATH: String = "res://assets/data/units/test_fixture_roster_victory_with_four_allies.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const _ROSTER_DOOMED_PATH: String = "res://assets/data/units/test_fixture_roster_doomed.txt"


## 敏感度變種:結果顯示後一律回標題(舊行為)。
class _MutantAlwaysTitle extends BattleScreen:
	func _on_result_display_finished() -> void:
		return_to_title_screen()


## 敏感度變種:不濾 SKIPPED,對話一律視為已觸發。
class _MutantNoSkippedFilter extends BattleScreen:
	func _trigger_support_conversations_for_finished_mission() -> void:
		_completed_support_conversation_ids.append("SC-01")


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	CampaignProgress.reset_for_test()


func after_test() -> void:
	_host_snap.restore()
	CampaignProgress.reset_for_test()


func _wait_swap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _enter_fixture_battle(roster_path: String, script: Script = null) -> BattleScreen:
	var stand_in: Node = load(_TITLE_SCENE_PATH).instantiate()
	get_tree().root.call_deferred("add_child", stand_in)
	await _wait_swap()
	get_tree().current_scene = stand_in
	var configure: Callable = func(node: Node) -> void:
		# 🔴 set_script 必須在賦值 override 之前。
		if script != null:
			node.set_script(script)
		var battle: BattleScreen = node as BattleScreen
		battle.terrain_path_override = _TERRAIN_DUEL_PATH
		battle.roster_path_override = roster_path
		battle.campaign_ledger_override = CampaignProgress.start_mission_affinity_ledger()
	var created: Node = SceneRouter.switch_to(get_tree(), SceneRouter.BATTLE_SCENE_PATH, configure)
	await _wait_swap()
	return created as BattleScreen


func _win(battle: BattleScreen) -> void:
	battle._controller.click_tile(Vector2i(0, 0))
	battle._controller.click_tile(Vector2i(1, 0))
	assert_int(battle._controller.outcome()).is_equal(BattleState.Outcome.VICTORY)


func _release_current(original: Node) -> void:
	var cur: Node = get_tree().current_scene
	if cur != null and is_instance_valid(cur) and cur != original:
		cur.queue_free()
		await get_tree().process_frame
	get_tree().current_scene = original


func _scene_name() -> String:
	var cur: Node = get_tree().current_scene
	return cur.name if cur != null else "null"


# ── AC1 ─────────────────────────────────────────────────────────────────────
func test_ac1_victory_with_triggered_conversation_goes_to_conversation_then_next_battle() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	_win(battle)

	battle._on_result_display_finished()
	await _wait_swap()

	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).append_failure_message(
		"AC1: 勝利後應切到支援對話畫面,實得 %s" % _scene_name()
	).is_not_null()
	assert_array(screen.conversation_ids).is_equal(["SC-01"])

	screen.all_conversations_finished.emit()
	await _wait_swap()
	var next_battle: BattleScreen = get_tree().current_scene as BattleScreen
	assert_object(next_battle).append_failure_message(
		"AC1: 對話完成後應進下一場戰鬥,實得 %s" % _scene_name()
	).is_not_null()
	assert_int(CampaignProgress.current_mission()).is_equal(2)

	await _release_current(original)


# ── AC2(等價分支,見檔頭揭露)──────────────────────────────────────────────
func test_ac2_victory_without_conversation_goes_straight_to_next_battle() -> void:
	var original: Node = get_tree().current_scene
	for i: int in 3:
		CampaignProgress.advance_on_victory(BattleScreen.campaign_total_missions())
	assert_int(CampaignProgress.current_mission()).is_equal(4)
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_FOUR_ALLIES_PATH)
	_win(battle)
	# 2026-10-28:原本手動清空播放清單模擬;現為真實第 4 場(槽位 4 無對話記錄)

	battle._on_result_display_finished()
	await _wait_swap()

	assert_bool(get_tree().current_scene is SupportConversationScreen).append_failure_message(
		"AC2: 無對話時不得出現對話畫面"
	).is_false()
	assert_bool(get_tree().current_scene is BattleScreen).append_failure_message(
		"AC2: 應直接進下一場戰鬥,實得 %s" % _scene_name()
	).is_true()
	assert_int(CampaignProgress.current_mission()).is_equal(5)

	await _release_current(original)


# ── AC3:參與者陣亡 / 缺席 -> SKIPPED -> 不播 ───────────────────────────────
func test_ac3_skipped_conversation_is_not_played_and_goes_to_next_battle() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_DUEL_PATH)
	_win(battle)

	assert_array(battle._completed_support_conversation_ids).append_failure_message(
		"SC-01 的參與者乙不存活 -> SKIPPED -> 不得列入要播的清單"
	).is_empty()
	battle._on_result_display_finished()
	await _wait_swap()

	assert_bool(get_tree().current_scene is SupportConversationScreen).is_false()
	assert_bool(get_tree().current_scene is BattleScreen).append_failure_message(
		"AC3: 應直接進下一場戰鬥,實得 %s" % _scene_name()
	).is_true()

	await _release_current(original)


# ── AC4:戰敗 / 戰役完成 -> 標題 ─────────────────────────────────────────────
func test_ac4_defeat_returns_to_title() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_DOOMED_PATH)
	await battle._end_faction_phase_pressed()
	assert_int(battle._controller.outcome()).is_equal(BattleState.Outcome.DEFEAT)

	battle._on_result_display_finished()
	await _wait_swap()

	assert_str(_scene_name()).is_equal("TitleScreen")
	await _release_current(original)


func test_ac4_campaign_complete_returns_to_title() -> void:
	var original: Node = get_tree().current_scene
	# 推進到最後一場(序列表共 5 場)再打贏
	_advance_to_mission(BattleScreen.campaign_total_missions())  # 2026-10-28:原為單次 advance(序列表 2 場時等於最後一場)
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	_win(battle)

	battle._on_result_display_finished()
	await _wait_swap()

	assert_str(_scene_name()).append_failure_message(
		"戰役完成應回標題(戰役完成顯示後)"
	).is_equal("TitleScreen")
	await _release_current(original)



# ── story-007 AC4:第 2、3 場勝利 -> 對應支援對話 ────────────────────────────
func _advance_to_mission(n: int) -> void:
	for i: int in n - 1:
		CampaignProgress.advance_on_victory(BattleScreen.campaign_total_missions())
	assert_int(CampaignProgress.current_mission()).is_equal(n)


func test_story007_ac4_mission_2_victory_plays_sc02() -> void:
	var original: Node = get_tree().current_scene
	_advance_to_mission(2)
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_FOUR_ALLIES_PATH)
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).append_failure_message("第 2 場勝利應切到對話畫面,實得 %s" % _scene_name()).is_not_null()
	assert_array(screen.conversation_ids).is_equal(["SC-02"])
	await _release_current(original)


func test_story007_ac4_mission_3_victory_plays_sc03() -> void:
	var original: Node = get_tree().current_scene
	_advance_to_mission(3)
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_FOUR_ALLIES_PATH)
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).append_failure_message("第 3 場勝利應切到對話畫面,實得 %s" % _scene_name()).is_not_null()
	assert_array(screen.conversation_ids).is_equal(["SC-03"])
	await _release_current(original)


func test_story007_ac4_mission_5_victory_is_campaign_complete_back_to_title() -> void:
	var original: Node = get_tree().current_scene
	_advance_to_mission(5)
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_FOUR_ALLIES_PATH)
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	assert_bool(get_tree().current_scene is SupportConversationScreen).is_false()
	assert_str(_scene_name()).is_equal("TitleScreen")
	await _release_current(original)

# ── 敏感度證明(常駐)────────────────────────────────────────────────────────
func test_sensitivity_proof_always_title_mutant_fails_ac1_expectation() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH, _MutantAlwaysTitle)
	_win(battle)

	battle._on_result_display_finished()
	await _wait_swap()

	# AC1 要求對話畫面;變種(舊行為)回標題 -> AC1 的斷言會抓到
	assert_bool(get_tree().current_scene is SupportConversationScreen).is_false()
	assert_str(_scene_name()).is_equal("TitleScreen")
	await _release_current(original)


func test_sensitivity_proof_unfiltered_skipped_mutant_would_show_conversation_in_ac3() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_DUEL_PATH, _MutantNoSkippedFilter)
	_win(battle)

	battle._on_result_display_finished()
	await _wait_swap()

	# AC3 要求不出現對話畫面;不濾 SKIPPED 的變種會出現 -> AC3 的斷言會抓到
	assert_bool(get_tree().current_scene is SupportConversationScreen).is_true()
	await _release_current(original)
