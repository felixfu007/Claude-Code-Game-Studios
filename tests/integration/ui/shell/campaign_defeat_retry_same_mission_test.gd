# story-056(管理者 2026-11-13 裁決「直接重打同一場,不回標題」)。
#
# 載入真實 BattleScreen.tscn,經 SceneRouter(production 入口)進樹;戰敗經真實訊號
# BattleController.battle_ended -> _on_battle_ended(DEFEAT),再 _on_result_display_finished()
# (計時器 timeout 處理函式,測試直接呼叫、不等真實秒數)-> SceneRouter.enter_battle() 新 BattleScreen。
#
# 檔案存取:只有被測程式自己讀的、已進版控的 assets/data 資料檔(甲類例外);本檔不做 I/O。
# 資料為真實 vs01 關卡(enter_battle 不注入夾具路徑),基準是「第一次進入該場」的同一份資料。
#
# 🔴 揭露:
#   - 牌組快照只比「張數」(pool/hand/used/total),不比牌的順序或身分 ——
#     牌池開局是時間種子洗牌,順序本來就每次不同。
#   - 戰敗前的累積是測試手動 append / draw_for_turn 製造的,不是真打出來的。
#   - 敏感度證明 ②(略過 rollback)與 ③(戰敗誤入對話分流)為常駐變種;① 是 AC1 對「回標題」的直接斷言
#     (舊行為常駐變種見 support_conversation_transition_flow_test.gd 的 _MutantAlwaysTitle,僅勝利分流用)。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"


## ① 戰役戰敗分支漏設旗標(舊行為:回標題)。
class _MutantNoRetryFlag extends BattleScreen:
	func _on_result_display_finished() -> void:
		_retry_same_mission = false
		super._on_result_display_finished()


## ② 戰敗時略過 rollback_on_defeat()(重打會帶著本場累積)。
class _MutantSkipsRollback extends BattleScreen:
	func _on_battle_ended(outcome: BattleState.Outcome) -> void:
		# 復原 rollback 的效果以外的一切:先記下累積筆數,呼叫 super 後把被回滾的筆數補回去。
		var before: int = campaign_ledger_override.records().size()
		var kept: Array[CampaignAffinityLedger.Entry] = campaign_ledger_override.records()
		super._on_battle_ended(outcome)
		while campaign_ledger_override.records().size() < before:
			var e: CampaignAffinityLedger.Entry = kept[campaign_ledger_override.records().size()]
			campaign_ledger_override.append(e.pair, e.m, e.source)


## ③ 戰敗旗標誤併入 _proceed_to_next_mission(戰敗誤入對話分流)。
class _MutantDefeatIntoConversation extends BattleScreen:
	func _on_result_display_finished() -> void:
		_retry_same_mission = false
		_proceed_to_next_mission = true
		_completed_support_conversation_ids.append("SC-01")
		super._on_result_display_finished()


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


func _enter_battle(script: Script) -> BattleScreen:
	var stand_in: Node = load(_TITLE_SCENE_PATH).instantiate()
	get_tree().root.call_deferred("add_child", stand_in)
	await _wait_swap()
	get_tree().current_scene = stand_in
	if script == null:
		SceneRouter.enter_battle(get_tree())
		await _wait_swap()
		return get_tree().current_scene as BattleScreen
	var configure: Callable = func(node: Node) -> void:
		# 🔴 set_script 必須在賦值 override 之前。
		node.set_script(script)
		(node as BattleScreen).campaign_ledger_override = CampaignProgress.start_mission_affinity_ledger()
	var created: Node = SceneRouter.switch_to(get_tree(), SceneRouter.BATTLE_SCENE_PATH, configure)
	await _wait_swap()
	return created as BattleScreen


func _pool_snapshot(battle: BattleScreen) -> Array[String]:
	var out: Array[String] = []
	for pair: int in AffinityTypes.Pair.values():
		var r: AffinityDataPool.AffinityReadResult = battle._affinity_pool.combat_strength_read(pair)
		out.append("%d:%d:%.6f" % [pair, r.n_pair, r.value])
	return out


func _deck_snapshot(battle: BattleScreen) -> Array[int]:
	var deck: CardDeck = battle._state.card_deck()
	return [deck.pool_size(), deck.hand_size(), deck.used_size(), deck.total_card_count()]


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	if current != null and is_instance_valid(current):
		current.queue_free()
		await get_tree().process_frame


## 進場 -> 記基準 -> 製造本場累積 -> 真實訊號戰敗 -> 結果顯示結束。回傳 [舊, 新, 基準 ledger 筆數, 累積後筆數]。
func _play_to_defeat_and_finish(script: Script, out: Dictionary) -> void:
	var old: BattleScreen = await _enter_battle(script)
	var mission_before: int = CampaignProgress.current_mission()
	out["old_id"] = old.get_instance_id()
	out["mission_before"] = mission_before
	out["records_base"] = old.campaign_ledger_override.records().size()
	out["pool_base"] = _pool_snapshot(old)
	out["deck_base"] = _deck_snapshot(old)

	# 製造本場累積:好感度記錄 + 牌組狀態
	old.campaign_ledger_override.append(
		AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)
	old._state.card_deck().draw_for_turn()
	out["records_dirty"] = old.campaign_ledger_override.records().size()
	out["deck_dirty"] = _deck_snapshot(old)

	old._controller.battle_ended.emit(BattleState.Outcome.DEFEAT)
	old._on_result_display_finished()
	await _wait_swap()
	out["new"] = get_tree().current_scene


# AC1 + AC2
func test_campaign_defeat_retries_same_mission_with_no_residue() -> void:
	var r: Dictionary = {}
	await _play_to_defeat_and_finish(null, r)

	# 防空洞:戰敗前累積確實存在
	assert_int(r["records_dirty"]).is_greater(r["records_base"])
	assert_array(r["deck_dirty"]).is_not_equal(r["deck_base"])
	# AC1:換場
	var fresh: Node = r["new"]
	assert_bool(fresh is BattleScreen).is_true()
	assert_str(fresh.name).is_not_equal("TitleScreen")
	assert_int(fresh.get_instance_id()).is_not_equal(r["old_id"])
	assert_int(CampaignProgress.current_mission()).is_equal(r["mission_before"])
	# AC2:無殘留
	var nb: BattleScreen = fresh as BattleScreen
	assert_int(nb.campaign_ledger_override.records().size()).is_equal(r["records_base"])
	assert_array(_pool_snapshot(nb)).is_equal(r["pool_base"])
	assert_array(_deck_snapshot(nb)).is_equal(r["deck_base"])
	await _cleanup()


func test_sensitivity_proof_no_retry_flag_goes_back_to_title() -> void:
	var r: Dictionary = {}
	await _play_to_defeat_and_finish(_MutantNoRetryFlag, r)
	assert_str((r["new"] as Node).name).is_equal("TitleScreen")
	await _cleanup()


func test_sensitivity_proof_skipped_rollback_leaves_residue() -> void:
	var r: Dictionary = {}
	await _play_to_defeat_and_finish(_MutantSkipsRollback, r)
	var nb: BattleScreen = r["new"] as BattleScreen
	assert_object(nb).is_not_null()
	# 變種造成殘留:新場筆數與基準不同(證明 AC2 的筆數斷言會抓到)
	assert_int(nb.campaign_ledger_override.records().size()).is_not_equal(r["records_base"])
	await _cleanup()


func test_sensitivity_proof_defeat_into_conversation_branch_is_not_battle() -> void:
	var r: Dictionary = {}
	await _play_to_defeat_and_finish(_MutantDefeatIntoConversation, r)
	assert_bool((r["new"] as Node) is BattleScreen).is_false()
	await _cleanup()
