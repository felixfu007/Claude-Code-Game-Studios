# production/epics/game-shell/story-008-tutorial-sequence.md
# 整合測試 —— AC1(標題「開始」/「略過教學」)、AC2(序列檔)、AC3(勝利接續/第 4 場後進戰役、無支援對話)、
# AC4(戰敗重打同一場)、AC5(戰役狀態不變)、AC6(空卡/空連線不報錯)、AC7(教學第 4 場無「戰役完成」)、
# AC8(4 場各一條引擎載入)。
#
# 檔案存取:甲類例外 —— 唯讀 assets/data/ 已進版控的真實資料檔。⚠️ 不證明資料內容在設計上正確。
# 寫法比照 campaign_all_missions_load_test.gd / title_screen_scene_switch_test.gd:載入真實場景檔,
# call_deferred 進樹並等 2 幀;切場景測試保存/還原 current_scene。
# 教學進度為靜態狀態 —— 前後都 TutorialProgress.reset_for_test() + CampaignProgress.reset_for_test()。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _BATTLE_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TUTORIAL_SEQUENCE_PATH: String = "res://assets/data/levels/tutorial_sequence.txt"
const _VS01_TERRAIN: String = "res://assets/data/levels/vs01_terrain.txt"

var _host_snap: CursorHostSnapshot = null
var _original_scene: Node = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()
	TutorialProgress.reset_for_test()
	CampaignProgress.reset_for_test()
	_original_scene = get_tree().current_scene


func after_test() -> void:
	var cur: Node = get_tree().current_scene
	if cur != null and cur != _original_scene and is_instance_valid(cur):
		cur.queue_free()
		await get_tree().process_frame
	get_tree().current_scene = _original_scene
	_host_snap.restore()
	TutorialProgress.reset_for_test()
	CampaignProgress.reset_for_test()


func _records() -> Array:
	var parsed: Variant = CampaignSequence.sequence_from_text(FileAccess.get_file_as_string(_TUTORIAL_SEQUENCE_PATH))
	assert_bool(parsed != null).is_true()
	return parsed as Array


func _mount_at_root(node: Node) -> void:
	get_tree().root.call_deferred("add_child", node)
	await get_tree().process_frame
	await get_tree().process_frame


## 讓 TutorialProgress 停在第 [param index] 場(只用公開 API)。
func _set_tutorial_index(index: int) -> void:
	TutorialProgress.begin()
	for i: int in range(index - 1):
		TutorialProgress.advance_on_victory(4)
	assert_int(TutorialProgress.current_index()).is_equal(index)


## 以 production 的方式掛上一個教學戰鬥(不給任何 override,走序列表解析)並設為 current_scene。
func _mount_tutorial_battle() -> BattleScreen:
	var battle: BattleScreen = load(_BATTLE_SCENE_PATH).instantiate()
	await _mount_at_root(battle)
	get_tree().current_scene = battle
	return battle


func _current_battle() -> BattleScreen:
	return get_tree().current_scene as BattleScreen


## 回傳結果畫面文字(舊戰鬥畫面切換後會被釋放,所以要在切換前讀)。
func _advance_via_result(battle: BattleScreen, outcome: BattleState.Outcome) -> String:
	battle._on_battle_ended(outcome)
	var result_text: String = battle._result_label.text
	battle._on_result_display_finished()
	await get_tree().process_frame
	await get_tree().process_frame
	return result_text


# ── AC2 ───────────────────────────────────────────────────────────────────
func test_sequence_file_parses_via_campaign_sequence_in_order_tut01_to_tut04() -> void:
	var records: Array = _records()
	assert_int(records.size()).is_equal(4)
	for i: int in range(4):
		var rec: CampaignSequence = records[i]
		assert_int(rec.mission_index).is_equal(i + 1)
		assert_str(rec.terrain_path).is_equal("res://assets/data/levels/tut0%d_terrain.txt" % (i + 1))
		assert_str(rec.roster_path).is_equal("res://assets/data/units/tut0%d_roster.txt" % (i + 1))
	assert_int(BattleScreen.tutorial_total_missions()).is_equal(4)


# ── AC8 + AC6:4 場各載入真實 BattleScreen,不給 override ─────────────────────
func _assert_tutorial_mission_loads(index: int) -> void:
	_set_tutorial_index(index)
	var rec: CampaignSequence = _records()[index - 1]
	var battle: BattleScreen = await _mount_tutorial_battle()
	var label: String = "教學第 %d 場" % index
	assert_bool(battle._load_failed).append_failure_message(label + ": 資料載入失敗").is_false()
	var resolved: Dictionary = battle.diagnostic_resolved_data_paths()
	assert_str(resolved.get("terrain", "")).append_failure_message(label).is_equal(rec.terrain_path)
	assert_str(resolved.get("roster", "")).append_failure_message(label).is_equal(rec.roster_path)
	var roster: Array[Unit] = Unit.roster_from_text(FileAccess.get_file_as_string(rec.roster_path))
	var want_players: int = 0
	for u: Unit in roster:
		if u.faction == Unit.Faction.PLAYER:
			want_players += 1
	assert_int(battle._state.units_of(Unit.Faction.PLAYER).size()).append_failure_message(label).is_equal(want_players)
	assert_int(battle._state.units_of(Unit.Faction.ENEMY).size()).append_failure_message(label).is_equal(roster.size() - want_players)
	# AC6:無技能卡(不得退回 vs01_cards.txt 的卡)
	assert_int(battle._state.card_deck().total_card_count()).append_failure_message(label + ": 教學場應零張技能卡").is_equal(0)
	assert_int(battle._state.card_deck().hand_size()).is_equal(0)


func test_tutorial_mission_1_loads() -> void:
	await _assert_tutorial_mission_loads(1)


func test_tutorial_mission_2_loads() -> void:
	await _assert_tutorial_mission_loads(2)


func test_tutorial_mission_3_loads() -> void:
	await _assert_tutorial_mission_loads(3)


func test_tutorial_mission_4_loads() -> void:
	await _assert_tutorial_mission_loads(4)


# ── AC1:標題兩列 ──────────────────────────────────────────────────────────
func test_title_start_row_enters_tutorial_mission_1() -> void:
	var title: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title)
	get_tree().current_scene = title
	assert_bool(TutorialProgress.is_active()).append_failure_message("前提:教學尚未啟動").is_false()

	title.get_node("Panel/ContentMargin/Rows/StartBattleRow").pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var battle: BattleScreen = _current_battle()
	assert_object(battle).is_not_null()
	assert_bool(TutorialProgress.is_active()).is_true()
	assert_int(TutorialProgress.current_index()).is_equal(1)
	assert_str(battle.diagnostic_resolved_data_paths().get("terrain", "")).is_equal(
		"res://assets/data/levels/tut01_terrain.txt")


func test_title_skip_row_enters_campaign_mission_1_and_ends_tutorial() -> void:
	var title: TitleScreen = load(_TITLE_SCENE_PATH).instantiate()
	await _mount_at_root(title)
	get_tree().current_scene = title
	var skip: Button = title.get_node("Panel/ContentMargin/Rows/SkipTutorialRow")
	assert_str(skip.text).is_equal(Loc.localize(TitleScreen.TEXT_SKIP_TUTORIAL))
	assert_bool(skip.text.is_empty()).is_false()
	assert_int(skip.focus_mode).is_equal(Control.FOCUS_ALL)
	TutorialProgress.begin()  # 前提:先有殘留的教學狀態,略過教學必須清掉

	skip.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	var battle: BattleScreen = _current_battle()
	assert_object(battle).is_not_null()
	assert_bool(TutorialProgress.is_active()).is_false()
	assert_str(battle.diagnostic_resolved_data_paths().get("terrain", "")).is_equal(_VS01_TERRAIN)
	assert_int(CampaignProgress.current_mission()).is_equal(1)


# ── AC3:第 4 場勝利 → 戰役第 1 場,且不進支援對話 ───────────────────────────
func test_tutorial_mission_4_victory_enters_campaign_mission_1_without_support_conversation() -> void:
	_set_tutorial_index(4)
	var battle: BattleScreen = await _mount_tutorial_battle()
	# 前提:確實是教學第 4 場
	assert_str(battle.diagnostic_resolved_data_paths().get("terrain", "")).is_equal(
		"res://assets/data/levels/tut04_terrain.txt")

	await _advance_via_result(battle, BattleState.Outcome.VICTORY)

	var next: Node = get_tree().current_scene
	assert_str(next.name).append_failure_message("不得進支援對話畫面").is_equal("BattleScreen")
	assert_bool(TutorialProgress.is_active()).is_false()
	assert_str((next as BattleScreen).diagnostic_resolved_data_paths().get("terrain", "")).is_equal(_VS01_TERRAIN)
	assert_int(CampaignProgress.current_mission()).is_equal(1)


# ── AC3 + AC5 + AC7:跑完整個教學序列 ───────────────────────────────────────
func test_full_tutorial_chain_advances_in_order_and_leaves_campaign_state_untouched() -> void:
	TutorialProgress.begin()
	var mission_before: int = CampaignProgress.current_mission()
	var ledger_before: int = CampaignProgress._affinity_ledger.records().size()
	var battle: BattleScreen = await _mount_tutorial_battle()
	for k: int in range(1, 5):
		# 前提:目前確實是教學第 k 場
		assert_int(TutorialProgress.current_index()).is_equal(k)
		assert_str(battle.diagnostic_resolved_data_paths().get("terrain", "")).is_equal(
			"res://assets/data/levels/tut0%d_terrain.txt" % k)
		var result_text: String = await _advance_via_result(battle, BattleState.Outcome.VICTORY)
		assert_str(result_text).append_failure_message("AC7: 結果畫面仍須顯示勝利文字").is_equal(Loc.localize(BattleScreen.TEXT_RESULT_VICTORY))
		if k == 4:
			# AC7:第 4 場結果文字不是「戰役完成」
			assert_str(result_text).is_not_equal(Loc.localize(BattleScreen.TEXT_RESULT_CAMPAIGN_COMPLETE))
		assert_int(CampaignProgress.current_mission()).append_failure_message(
			"AC5: 教學第 %d 場勝利後戰役場次被改動" % k).is_equal(mission_before)
		# 戰役累積記錄:教學場內不寫入。(k==4 之後已進戰役第 1 場,它自己的開局種子會合法寫入,不在此斷言。)
		if k < 4:
			assert_int(CampaignProgress._affinity_ledger.records().size()).append_failure_message(
				"AC5: 教學第 %d 場勝利後戰役好感度記錄被寫入" % k).is_equal(ledger_before)
		var next: Node = get_tree().current_scene
		if k < 4:
			battle = next as BattleScreen
			await get_tree().process_frame
	assert_bool(TutorialProgress.is_active()).is_false()


# ── AC4:戰敗重打同一場,不回標題、不影響戰役 ──────────────────────────────
func test_tutorial_defeat_reloads_the_same_mission() -> void:
	_set_tutorial_index(2)
	var battle: BattleScreen = await _mount_tutorial_battle()
	assert_str(battle.diagnostic_resolved_data_paths().get("terrain", "")).is_equal(
		"res://assets/data/levels/tut02_terrain.txt")

	await _advance_via_result(battle, BattleState.Outcome.DEFEAT)

	var next: Node = get_tree().current_scene
	assert_str(next.name).is_equal("BattleScreen")
	assert_bool(next != battle).is_true()
	assert_bool(TutorialProgress.is_active()).is_true()
	assert_int(TutorialProgress.current_index()).is_equal(2)
	assert_str((next as BattleScreen).diagnostic_resolved_data_paths().get("terrain", "")).is_equal(
		"res://assets/data/levels/tut02_terrain.txt")
	assert_int(CampaignProgress.current_mission()).is_equal(1)
