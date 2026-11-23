# production/epics/campfire/story-006-campfire-in-campaign-flow.md
# 整合測試 —— 勝利 -> 營火 -> 支援對話(若有)-> 牌組編輯 -> 下一場。
#
# 載入真實 BattleScreen.tscn / CampfireShellScreen.tscn / SupportConversationScreen.tscn /
# DeckEditShellScreen.tscn,經真實 SceneRouter 換場;測試直接呼叫 BattleScreen._on_result_display_finished()
# 並以發出畫面自己的完成訊號代替玩家按鈕(與 support_conversation_transition_flow_test.gd 同慣例)。
# 檔案存取:只有被測程式自己讀的、已進版控的 assets/data 資料檔(甲類例外);本檔不做 I/O。
#
# 🔴 揭露:營火/牌組編輯畫面目前是【最小殼層】(真畫面是 story-007/008),本檔證明的是「流程順序與閘門」,
# 不證明真畫面。戰鬥內容用夾具(duel 地形 + 勝利名冊),不證明在真實 vs0N 關卡上能打贏。
extends GdUnitTestSuite

const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_VICTORY_ALLY_PATH: String = "res://assets/data/units/test_fixture_roster_victory_with_ally.txt"
const _ROSTER_FOUR_ALLIES_PATH: String = "res://assets/data/units/test_fixture_roster_victory_with_four_allies.txt"
const _ROSTER_DOOMED_PATH: String = "res://assets/data/units/test_fixture_roster_doomed.txt"


## ① 勝利後略過營火(直接對話 / 牌組編輯)。
class _MutantSkipCampfire extends BattleScreen:
	func _proceed_after_victory() -> void:
		SceneRouter.go_to_deck_edit(get_tree())


## ④ 順序顛倒:對話在營火之前(舊行為,營火根本沒機會出現)。
class _MutantConversationFirst extends BattleScreen:
	func _proceed_after_victory() -> void:
		SceneRouter.go_to_support_conversation(
			get_tree(), _completed_support_conversation_ids, _pending_support_writes, campaign_ledger_override
		)


## ③ 最後一場仍進營火。
class _MutantLastMissionStillCampfire extends BattleScreen:
	func _on_result_display_finished() -> void:
		_proceed_to_next_mission = true
		super()


## ② 編輯頁未確認即放行。
class _MutantDeckEditAutoConfirm extends DeckEditShellScreen:
	func _ready() -> void:
		confirmed.emit.call_deferred()


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


func _advance_to_mission(n: int) -> void:
	for i: int in n - 1:
		CampaignProgress.advance_on_victory(BattleScreen.campaign_total_missions())
	assert_int(CampaignProgress.current_mission()).is_equal(n)


## 走完「勝利 -> 營火 -> (對話)-> 牌組編輯 -> 下一場」的共用流程,逐步斷言順序。
func _walk_full_flow(battle: BattleScreen, expect_conversation_id: String) -> void:
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()

	var campfire: CampfireShellScreen = get_tree().current_scene as CampfireShellScreen
	assert_object(campfire).append_failure_message("AC1: 勝利後應先進營火,實得 %s" % _scene_name()).is_not_null()
	if campfire == null:
		return
	campfire.left_campfire.emit()
	await _wait_swap()

	if expect_conversation_id != "":
		var conv: SupportConversationScreen = get_tree().current_scene as SupportConversationScreen
		assert_object(conv).append_failure_message("AC1: 營火後應進支援對話,實得 %s" % _scene_name()).is_not_null()
		if conv == null:
			return
		assert_array(conv.conversation_ids).is_equal([expect_conversation_id])
		conv.all_conversations_finished.emit()
		await _wait_swap()

	var deck: DeckEditShellScreen = get_tree().current_scene as DeckEditShellScreen
	assert_object(deck).append_failure_message("AC1/AC4: 應進牌組編輯,實得 %s" % _scene_name()).is_not_null()
	if deck == null:
		return
	# AC2:未確認前不得已進下一場
	assert_bool(get_tree().current_scene is BattleScreen).is_false()
	deck.confirmed.emit()
	await _wait_swap()
	assert_bool(get_tree().current_scene is BattleScreen).append_failure_message(
		"AC1: 確認牌組後應進下一場,實得 %s" % _scene_name()
	).is_true()


# ── AC1 ─────────────────────────────────────────────────────────────────────
func test_campfire_flow_victory_goes_campfire_conversation_deck_edit_next_battle() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	await _walk_full_flow(battle, "SC-01")
	assert_int(CampaignProgress.current_mission()).is_equal(2)
	await _release_current(original)


# ── AC4:本場沒有對話 -> 營火 -> 牌組編輯 ──────────────────────────────────────
func test_campfire_flow_without_conversation_skips_conversation_step() -> void:
	var original: Node = get_tree().current_scene
	_advance_to_mission(4)
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_FOUR_ALLIES_PATH)
	await _walk_full_flow(battle, "")
	assert_int(CampaignProgress.current_mission()).is_equal(5)
	await _release_current(original)


# ── AC2:牌組未確認不得進下一場;編輯頁沒有回營火的路徑 ─────────────────────────
func test_campfire_flow_deck_edit_unconfirmed_stays_and_has_no_way_back() -> void:
	var original: Node = get_tree().current_scene
	SceneRouter.go_to_deck_edit(get_tree())
	await _wait_swap()
	var deck: DeckEditShellScreen = get_tree().current_scene as DeckEditShellScreen
	assert_object(deck).is_not_null()
	await _wait_swap()
	assert_bool(get_tree().current_scene is DeckEditShellScreen).append_failure_message(
		"AC2: 未確認牌組,畫面不得離開編輯頁,實得 %s" % _scene_name()
	).is_true()
	# 唯一的自訂訊號是 confirmed(沒有任何回營火的出口)。
	var own_signals: Array[String] = []
	for entry: Dictionary in deck.get_script().get_script_signal_list():
		own_signals.append(String(entry["name"]))
	assert_array(own_signals).is_equal(["confirmed"])
	await _release_current(original)


# ── AC3:最後一場勝利 -> 不進營火 ────────────────────────────────────────────
func test_campfire_flow_last_mission_victory_skips_campfire() -> void:
	var original: Node = get_tree().current_scene
	_advance_to_mission(BattleScreen.campaign_total_missions())
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	assert_bool(get_tree().current_scene is CampfireShellScreen).is_false()
	assert_str(_scene_name()).is_equal("TitleScreen")
	await _release_current(original)


# ── AC3:教學場 -> 不進營火(教學場不注入戰役累積記錄,走教學分流)─────────────────
func test_campfire_flow_tutorial_victory_skips_campfire() -> void:
	var original: Node = get_tree().current_scene
	TutorialProgress.begin()
	var configure: Callable = func(node: Node) -> void:
		var tb: BattleScreen = node as BattleScreen
		tb.terrain_path_override = _TERRAIN_DUEL_PATH
		tb.roster_path_override = _ROSTER_VICTORY_ALLY_PATH
	var created: Node = SceneRouter.switch_to(get_tree(), SceneRouter.BATTLE_SCENE_PATH, configure)
	await _wait_swap()
	var battle: BattleScreen = created as BattleScreen
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	assert_bool(get_tree().current_scene is CampfireShellScreen).append_failure_message(
		"AC3: 教學場勝利不得進營火"
	).is_false()
	TutorialProgress.reset_for_test()
	await _release_current(original)


# ── AC5:戰敗 -> 直接重打(回歸)────────────────────────────────────────────
func test_campfire_flow_defeat_retries_same_mission_without_campfire() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_DOOMED_PATH)
	var mission_before: int = CampaignProgress.current_mission()
	await battle._end_faction_phase_pressed()
	assert_int(battle._controller.outcome()).is_equal(BattleState.Outcome.DEFEAT)
	battle._on_result_display_finished()
	await _wait_swap()
	assert_bool(get_tree().current_scene is CampfireShellScreen).is_false()
	assert_bool(get_tree().current_scene is BattleScreen).is_true()
	assert_object(get_tree().current_scene).is_not_same(battle)
	assert_int(CampaignProgress.current_mission()).is_equal(mission_before)
	await _release_current(original)


# ── AC6 敏感度證明(常駐;每個 mutant 各自獨立,斷言「偵測條件抓得到它」)──────────
func test_sensitivity_proof_skip_campfire_mutant_never_shows_campfire() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH, _MutantSkipCampfire)
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	# AC1 要求營火;變種直接進牌組編輯 -> AC1 的「應為 CampfireShellScreen」斷言會紅
	assert_bool(get_tree().current_scene is CampfireShellScreen).is_false()
	assert_bool(get_tree().current_scene is DeckEditShellScreen).is_true()
	await _release_current(original)


func test_sensitivity_proof_conversation_first_mutant_shows_conversation_not_campfire() -> void:
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH, _MutantConversationFirst)
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	# AC1 要求第一站是營火;對話在前的變種第一站是對話 -> AC1 斷言會紅
	assert_bool(get_tree().current_scene is CampfireShellScreen).is_false()
	assert_bool(get_tree().current_scene is SupportConversationScreen).is_true()
	await _release_current(original)


func test_sensitivity_proof_last_mission_mutant_enters_campfire() -> void:
	var original: Node = get_tree().current_scene
	_advance_to_mission(BattleScreen.campaign_total_missions())
	var battle: BattleScreen = await _enter_fixture_battle(
		_ROSTER_VICTORY_ALLY_PATH, _MutantLastMissionStillCampfire
	)
	_win(battle)
	battle._on_result_display_finished()
	await _wait_swap()
	# AC3 要求最後一場不進營火;變種進了 -> AC3 斷言會紅
	assert_bool(get_tree().current_scene is CampfireShellScreen).is_true()
	await _release_current(original)


func test_sensitivity_proof_auto_confirm_mutant_leaves_deck_edit_unconfirmed() -> void:
	var original: Node = get_tree().current_scene
	var mutate: Callable = func(node: Node) -> void:
		node.set_script(_MutantDeckEditAutoConfirm)
	SceneRouter.go_to_deck_edit(get_tree(), mutate)
	await _wait_swap()
	await _wait_swap()
	# AC2 要求未確認不得進下一場;變種自動放行 -> AC2 斷言會紅
	assert_bool(get_tree().current_scene is BattleScreen).is_true()
	await _release_current(original)


# ── 殼層暫時文字(管理者 2026-11-23 裁決):按鈕與標題不得空白 ─────────────────────
func test_campfire_flow_shell_screens_show_non_empty_localized_text() -> void:
	var camp: CampfireShellScreen = load(SceneRouter.CAMPFIRE_SCENE_PATH).instantiate()
	var deck: DeckEditShellScreen = load(SceneRouter.DECK_EDIT_SCENE_PATH).instantiate()
	add_child(camp)
	add_child(deck)
	await get_tree().process_frame
	for screen: Control in [camp, deck]:
		var button: Button = screen.get_node("%LeaveButton" if screen == camp else "%ConfirmButton")
		var title: Label = screen.get_node("%TitleLabel")
		assert_str(button.text).append_failure_message("%s 按鈕文字不得為空" % screen.name).is_not_empty()
		assert_str(title.text).append_failure_message("%s 標題文字不得為空" % screen.name).is_not_empty()
	camp.queue_free()
	deck.queue_free()
