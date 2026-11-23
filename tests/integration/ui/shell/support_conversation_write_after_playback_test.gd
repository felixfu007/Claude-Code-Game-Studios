# production/epics/campfire/story-013-support-conversation-write-after-playback.md
# 整合測試 —— 支援對話的好感度改在「對話播完」才寫入累積記錄。
#
# 依據:管理者 2026-11-23 裁決第 2 題「改成對話播完才寫入」。載入真實 BattleScreen.tscn /
# SupportConversationScreen.tscn,經 SceneRouter(production 的切換入口)換場;
# 對話以真實畫面的 request_advance() 播到結束,不手動 emit 完成訊號。
#
# 檔案存取:甲類例外 —— 只有被測程式自己讀的、已進版控的 assets/data 資料檔;本檔不做 I/O。
#
# 🔴 揭露:
#   - 戰鬥內容用夾具(duel 地形 + 勝利名冊),不是真實 vs0N 關卡。
#   - AC3(多段順序)用合成的待寫入表直接驅動 SceneRouter.go_to_support_conversation,
#     因為真實資料每個槽位只有一段對話,打不出「同一場多段」。證明的是「播放順序 = 寫入順序」,
#     不證明真實資料有多段時的挑段結果。
#   - AC6③ 的 mutant 在 _on_result_display_finished 以「播放當下」的存活重濾挑段結果;
#     這是 AC4「挑段結果不變」的結構性替身(正式程式碼在播放期間根本沒有存活判斷可重跑)。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_VICTORY_ALLY_PATH: String = "res://assets/data/units/test_fixture_roster_victory_with_ally.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const _MAX_ADVANCE_STEPS: int = 600


## AC6①:舊行為 —— 勝利當下就把暫存的寫入量寫進累積記錄。
class _MutantWriteAtVictory extends BattleScreen:
	func _trigger_support_conversations_for_finished_mission() -> void:
		super()
		var port: SupportConversationLedgerWritePort = SupportConversationLedgerWritePort.new(campaign_ledger_override)
		for id: String in _pending_support_writes:
			for entry: SupportConversationBufferedWritePort.Entry in _pending_support_writes[id]:
				port.append_record(entry.pair, entry.m, entry.source)
		_pending_support_writes = {}


## AC6②:播完不寫 —— 帶去對話畫面的待寫入表是空的。
class _MutantNoWriteOnPlayback extends BattleScreen:
	func _on_result_display_finished() -> void:
		_pending_support_writes = {}
		super()


## AC6③:播放當下才用「現在」的存活判斷重新篩選挑段結果(乙 id=2 陣亡就不播)。
class _MutantReselectAtPlayback extends BattleScreen:
	func _on_result_display_finished() -> void:
		var kept: Array[String] = []
		var ally: Unit = _state.unit_by_id(2)
		if ally != null and ally.is_alive():
			kept = _completed_support_conversation_ids
		_completed_support_conversation_ids = kept
		super()


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


## 用真實畫面的 request_advance() 把對話播到結束(第一下顯示整句、第二下下一句)。
func _play_through(screen: SupportConversationScreen) -> void:
	var steps: int = 0
	while not screen.diagnostic_is_finished() and steps < _MAX_ADVANCE_STEPS:
		screen.request_advance()
		steps += 1
	assert_bool(screen.diagnostic_is_finished()).append_failure_message(
		"對話在 %d 步內沒有播完" % _MAX_ADVANCE_STEPS
	).is_true()


func _support_entries(ledger: CampaignAffinityLedger) -> Array[CampaignAffinityLedger.Entry]:
	var out: Array[CampaignAffinityLedger.Entry] = []
	for entry: CampaignAffinityLedger.Entry in ledger.records():
		if entry.source == AffinityTypes.Source.SUPPORT_CONVERSATION:
			out.append(entry)
	return out


func _c1_c2_count(battle: BattleScreen) -> int:
	return battle._affinity_pool.combat_strength_read(AffinityTypes.Pair.C1_C2).n_pair


# ── AC1 + AC2 ───────────────────────────────────────────────────────────────
func test_write_after_playback_ac1_nothing_at_victory_ac2_written_after_playback() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	_win(battle)

	# AC1:勝利後、對話開始播放前,累積記錄沒有本場對話的筆數
	assert_int(_support_entries(ledger).size()).append_failure_message(
		"AC1:勝利當下累積記錄不得已有支援對話筆數"
	).is_equal(0)

	battle._on_result_display_finished()
	await _wait_swap()
	# story-006:結果顯示後先進營火(管理者 2026-11-20 第 2 題),離開營火才進對話。
	(get_tree().current_scene as CampfireShellScreen).left_campfire.emit()
	await _wait_swap()
	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).is_not_null()
	assert_int(_support_entries(ledger).size()).append_failure_message(
		"AC1:對話畫面剛開、尚未播放,仍不得有筆數"
	).is_equal(0)

	# AC2:播完後新增 1 筆,配對/數值/來源與舊行為逐筆相同(SC-01 = 甲乙 = C1_C2、正向)
	_play_through(screen)
	var written: Array[CampaignAffinityLedger.Entry] = _support_entries(ledger)
	assert_int(written.size()).append_failure_message("AC2:播完後應恰有 1 筆").is_equal(1)
	if written.size() == 1:
		assert_int(written[0].pair).is_equal(AffinityTypes.Pair.C1_C2)
		assert_float(written[0].m).is_equal(
			SupportConversationRules.magnitude_for_valence(SupportConversationRecord.Valence.POSITIVE)
		)
		assert_int(written[0].source).is_equal(AffinityTypes.Source.SUPPORT_CONVERSATION)
	await _wait_swap()
	await _release_current(original)


# ── AC3:多段 —— 寫入順序 = 播放順序 ─────────────────────────────────────────
func test_write_after_playback_ac3_write_order_equals_playback_order() -> void:
	var original: Node = get_tree().current_scene
	var stand_in: Node = load(_TITLE_SCENE_PATH).instantiate()
	get_tree().root.call_deferred("add_child", stand_in)
	await _wait_swap()
	get_tree().current_scene = stand_in
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var first: SupportConversationBufferedWritePort.Entry = SupportConversationBufferedWritePort.Entry.new(
		AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)
	var second: SupportConversationBufferedWritePort.Entry = SupportConversationBufferedWritePort.Entry.new(
		AffinityTypes.Pair.C2_C4, -1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)
	var pending: Dictionary = {"SC-01": [first], "SC-03": [second]}
	var ids: Array[String] = ["SC-01", "SC-03"]
	SceneRouter.go_to_support_conversation(get_tree(), ids, pending, ledger)
	await _wait_swap()
	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).is_not_null()
	assert_int(ledger.records().size()).is_equal(0)

	_play_through(screen)
	var records: Array[CampaignAffinityLedger.Entry] = ledger.records()
	assert_int(records.size()).is_equal(2)
	if records.size() == 2:
		assert_int(records[0].pair).append_failure_message("先播的 SC-01 應先寫").is_equal(AffinityTypes.Pair.C1_C2)
		assert_int(records[1].pair).append_failure_message("後播的 SC-03 應後寫").is_equal(AffinityTypes.Pair.C2_C4)
	await _wait_swap()
	await _release_current(original)


# ── AC4:挑段結果不變 ─────────────────────────────────────────────────────────
func test_write_after_playback_ac4_selection_fixed_at_victory_even_if_roster_changes_later() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	_win(battle)
	assert_array(battle._completed_support_conversation_ids).is_equal(["SC-01"])

	# 勝利之後、播放之前乙陣亡:挑段已在勝利當下決定,不得因此改變
	battle._state.unit_by_id(2).take_damage(999999)
	assert_bool(battle._state.unit_by_id(2).is_alive()).append_failure_message("前置:乙應已陣亡").is_false()
	battle._on_result_display_finished()
	await _wait_swap()
	# story-006:結果顯示後先進營火(管理者 2026-11-20 第 2 題),離開營火才進對話。
	(get_tree().current_scene as CampfireShellScreen).left_campfire.emit()
	await _wait_swap()
	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).append_failure_message("挑段應維持勝利當下結果 -> 仍進對話畫面").is_not_null()
	if screen != null:
		assert_array(screen.conversation_ids).is_equal(["SC-01"])
	await _release_current(original)


func test_write_after_playback_ac4_dead_participant_conversation_still_not_triggered() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_DUEL_PATH)
	_win(battle)
	assert_array(battle._completed_support_conversation_ids).is_empty()
	assert_dict(battle._pending_support_writes).is_empty()
	await _release_current(original)


# ── AC5:下一場開局重播後讀到的關係與舊行為相同 ───────────────────────────────
func test_write_after_playback_ac5_next_battle_replays_the_written_entry() -> void:
	var original: Node = get_tree().current_scene
	var battle1: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	_win(battle1)
	battle1._on_result_display_finished()
	await _wait_swap()
	# story-006:結果顯示後先進營火(管理者 2026-11-20 第 2 題),離開營火才進對話。
	(get_tree().current_scene as CampfireShellScreen).left_campfire.emit()
	await _wait_swap()
	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).is_not_null()

	# 同場次對照基準(第 2 場、不注入累積記錄);此刻舊戰鬥已離樹,不會有 BOARD_TILE 衝突
	var control: BattleScreen = load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	add_child(control)
	var baseline: int = _c1_c2_count(control)
	remove_child(control)
	control.free()

	_play_through(screen)
	await _wait_swap()
	# story-006:對話之後先進牌組編輯,確認牌組才進下一場。
	(get_tree().current_scene as DeckEditShellScreen).confirmed.emit()
	await _wait_swap()
	var battle2: BattleScreen = get_tree().current_scene as BattleScreen
	assert_object(battle2).is_not_null()
	assert_int(_c1_c2_count(battle2)).append_failure_message(
		"AC5:第二場開局 C1_C2 的 n_pair 應為基準 %d + 1" % baseline
	).is_equal(baseline + 1)
	await _release_current(original)


# ── AC6 敏感度證明(常駐;每個 mutant 各自獨立)────────────────────────────────
func test_sensitivity_proof_write_at_victory_mutant_fails_ac1() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH, _MutantWriteAtVictory)
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	_win(battle)
	# 舊行為:勝利當下就有 1 筆 —— AC1 要求 0,變種會被 AC1 的斷言抓到
	assert_int(_support_entries(ledger).size()).is_equal(1)
	await _release_current(original)


func test_sensitivity_proof_no_write_on_playback_mutant_fails_ac2() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH, _MutantNoWriteOnPlayback)
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	# story-006:結果顯示後先進營火(管理者 2026-11-20 第 2 題),離開營火才進對話。
	(get_tree().current_scene as CampfireShellScreen).left_campfire.emit()
	await _wait_swap()
	var screen: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
	assert_object(screen).is_not_null()
	_play_through(screen)
	# 播完不寫:0 筆 —— AC2 要求 1,變種會被 AC2 的斷言抓到
	assert_int(_support_entries(ledger).size()).is_equal(0)
	await _wait_swap()
	await _release_current(original)


func test_sensitivity_proof_reselect_at_playback_mutant_fails_ac4() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH, _MutantReselectAtPlayback)
	_win(battle)
	battle._state.unit_by_id(2).take_damage(999999)
	battle._on_result_display_finished()
	await _wait_swap()
	# story-006:結果顯示後先進營火(管理者 2026-11-20 第 2 題),離開營火才進對話。
	(get_tree().current_scene as CampfireShellScreen).left_campfire.emit()
	await _wait_swap()
	# 播放當下重挑:乙陣亡 -> 不進對話畫面 —— AC4 要求仍進(ids == ["SC-01"]),變種會被抓到
	assert_bool(get_tree().current_scene is SupportConversationScreen).is_false()
	await _release_current(original)
