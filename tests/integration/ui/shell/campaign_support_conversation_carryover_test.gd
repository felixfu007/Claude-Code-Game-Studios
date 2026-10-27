# production/epics/game-shell/story-005-manual-scene-handoff-and-leave-to-title.md
# 整合測試 —— Unit B:AC4(支援對話的寫入真的進入下一場)。
#
# 載入真實 BattleScreen.tscn,經 SceneRouter(production 的切換入口)進樹,
# 戰鬥以真實 BattleController.click_tile() 打到 VICTORY / 以真實敵方回合打到 DEFEAT。
#
# 檔案存取:本檔讀取的只有被測程式自己讀的、已進版控的 assets/data 資料檔
# (甲類例外,見 .claude/rules/test-standards.md);本檔自己不做任何 I/O。
#
# 🔴 揭露(與派工單不同之處,寫在這裡讓讀者不必跳去報告):
#   - (2026-10-27 協調者更新)實作者交件時 campaign_sequence.txt 只有第 1 列,
#     本段原寫「本檔不斷言場次推進」。同日協調者補上第 2 列,(a) 已改為斷言
#     勝利後 current_mission() == 2,且以「第 2 場、無累積記錄」的開局為對照基準。
#   - 第一場用夾具資料(vs01 要打倒五個敵人才勝利,不適合單元級驅動);
#     夾具以 SceneRouter.switch_to() 自行注入 override + 同一個
#     CampaignProgress.start_mission_affinity_ledger() 入口。第二場走
#     SceneRouter.enter_battle() 本體(真實 vs01 資料)。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_VICTORY_ALLY_PATH: String = "res://assets/data/units/test_fixture_roster_victory_with_ally.txt"
const _ROSTER_DOOMED_PATH: String = "res://assets/data/units/test_fixture_roster_doomed.txt"


## 常駐變種(敏感度證明):拿掉「勝利時觸發支援對話」這一步。
class _MutantNoSupportTrigger extends BattleScreen:
	func _trigger_support_conversations_for_finished_mission() -> void:
		pass


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


## 先放一個替身標題當 current_scene(SceneRouter 會釋放舊場景,不能讓它釋放測試執行器),
## 再經 SceneRouter.switch_to 進入夾具戰鬥。回傳戰鬥實例。
func _enter_fixture_battle(roster_path: String, script: Script = null) -> BattleScreen:
	var stand_in: Node = load(_TITLE_SCENE_PATH).instantiate()
	get_tree().root.call_deferred("add_child", stand_in)
	await _wait_swap()
	get_tree().current_scene = stand_in
	var configure: Callable = func(node: Node) -> void:
		# 🔴 set_script 必須在賦值 override 之前(見 coding-standards.md 兩個陷阱之一)。
		if script != null:
			node.set_script(script)
		var battle: BattleScreen = node as BattleScreen
		battle.terrain_path_override = _TERRAIN_DUEL_PATH
		battle.roster_path_override = roster_path
		battle.campaign_ledger_override = CampaignProgress.start_mission_affinity_ledger()
	var created: Node = SceneRouter.switch_to(
		get_tree(), SceneRouter.BATTLE_SCENE_PATH, configure
	)
	await _wait_swap()
	return created as BattleScreen


func _win(battle: BattleScreen) -> void:
	var select_result: Dictionary = battle._controller.click_tile(Vector2i(0, 0))
	assert_that(select_result["action"]).is_equal(&"selected")
	var attack_result: Dictionary = battle._controller.click_tile(Vector2i(1, 0))
	assert_that(attack_result["action"]).is_equal(&"attacked")
	assert_int(battle._controller.outcome()).is_equal(BattleState.Outcome.VICTORY)


## 釋放戰鬥場景(連同它勝利後裝的 RESULT_DISPLAY_SECONDS 子 Timer)。
func _release(node: Node, original: Node) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()
		await get_tree().process_frame
	get_tree().current_scene = original


func _c1_c2_count(battle: BattleScreen) -> int:
	var read: AffinityDataPool.AffinityReadResult = (
		battle._affinity_pool.combat_strength_read(AffinityTypes.Pair.C1_C2)
	)
	return read.n_pair


# ── (a) 端對端:勝利 -> SC-01 寫進累積記錄 -> 下一場開局池子裡多一筆 ──────────
func test_victory_support_conversation_is_written_to_ledger_and_replayed_next_battle() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var battle1: BattleScreen = await _enter_fixture_battle(_ROSTER_VICTORY_ALLY_PATH)
	assert_object(battle1).is_not_null()
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()
	assert_int(ledger.records().size()).append_failure_message(
		"precondition:勝利之前累積記錄應只有 2 筆起始關係(STORY_EVENT),沒有支援對話"
	).is_equal(2)
	assert_int(_count_source(ledger, AffinityTypes.Source.STORY_EVENT)).is_equal(2)
	# Act
	_win(battle1)

	# Assert — 2026-10-27 協調者補:序列表已有第 2 列,勝利必須真的推進到第 2 場
	assert_int(CampaignProgress.current_mission()).append_failure_message(
		"第 1 場勝利後應推進到第 2 場(campaign_sequence.txt 有 2 列)"
	).is_equal(2)
	# Assert — 累積記錄 = 2 筆起始關係 + 恰有一筆 SC-01(甲乙 = C1_C2,來源為支援對話)
	var records: Array[CampaignAffinityLedger.Entry] = ledger.records()
	assert_int(_count_source(ledger, AffinityTypes.Source.SUPPORT_CONVERSATION)).append_failure_message(
		"勝利後累積記錄應恰有 1 筆 SC-01,實得 %d(總筆數 %d)" % [_count_source(ledger, AffinityTypes.Source.SUPPORT_CONVERSATION), records.size()]
	).is_equal(1)
	assert_int(records.size()).is_equal(3)
	assert_int(records[2].source).is_equal(AffinityTypes.Source.SUPPORT_CONVERSATION)
	assert_int(records[2].pair).is_equal(AffinityTypes.Pair.C1_C2)

	# Act 2 — 釋放第一場,經 production 入口進入下一場
	await _release(battle1, original)

	# 對照基準:同樣是第 2 場、但【不注入】累積記錄的開局(第 1 場已釋放後才建,
	# 避免它離樹時的 BOARD_TILE 解除註冊波及第 1 場)。
	# 🔴 2026-10-27 協調者覆核更正:原本拿第 1 場開局當基準,而 vs01/vs02 的甲乙初始關係
	# 逐字相同(各 1 筆 POSITIVE),所以「比第 1 場多 1」是兩份資料碰巧一致才成立 ——
	# 日後任一份改了,本測試會為錯的理由變紅或變綠。改成同場次對照。
	var control: BattleScreen = load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	add_child(control)
	var baseline: int = _c1_c2_count(control)
	remove_child(control)
	control.free()

	var stand_in: Node = load(_TITLE_SCENE_PATH).instantiate()
	get_tree().root.call_deferred("add_child", stand_in)
	await _wait_swap()
	get_tree().current_scene = stand_in
	SceneRouter.enter_battle(get_tree())
	await _wait_swap()
	var battle2: BattleScreen = get_tree().current_scene as BattleScreen

	# Assert — 第二場開局的好感度池看得到那一筆(C1_C2 比第一場開局多 1 筆)
	assert_object(battle2).is_not_null()
	assert_int(_c1_c2_count(battle2)).append_failure_message(
		"第二場開局 C1_C2 的 n_pair 應比第一場開局(%d)多 1 筆" % baseline
	).is_equal(baseline + 1)

	# Cleanup
	await _release(battle2, original)


# ── (b) 戰敗:不觸發支援對話 ────────────────────────────────────────────────
func test_defeat_does_not_write_support_conversation_and_mission_stays() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(_ROSTER_DOOMED_PATH)
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()

	# Act — 敵方回合一擊殺死我方唯一單位
	await battle._end_faction_phase_pressed()
	assert_int(battle._controller.outcome()).is_equal(BattleState.Outcome.DEFEAT)

	# Assert
	assert_int(_count_source(ledger, AffinityTypes.Source.SUPPORT_CONVERSATION)).append_failure_message(
		"戰敗不得寫入任何支援對話記錄(起始關係那 2 筆 STORY_EVENT 不計)"
	).is_equal(0)
	assert_int(CampaignProgress.current_mission()).is_equal(1)

	# Cleanup
	await _release(battle, original)


# ── (c) 敏感度證明:拿掉觸發那一步,(a) 的核心斷言會抓到 ─────────────────────
func test_sensitivity_proof_removing_support_trigger_leaves_ledger_empty() -> void:
	# Arrange
	var original: Node = get_tree().current_scene
	var battle: BattleScreen = await _enter_fixture_battle(
		_ROSTER_VICTORY_ALLY_PATH, _MutantNoSupportTrigger
	)
	var ledger: CampaignAffinityLedger = CampaignProgress.start_mission_affinity_ledger()

	# Act
	_win(battle)

	# Assert — 變種下累積記錄為空;(a) 要求恰有 1 筆,所以 (a) 在變種下會紅
	assert_int(_count_source(ledger, AffinityTypes.Source.SUPPORT_CONVERSATION)).append_failure_message(
		"變種(沒有觸發步驟)的支援對話記錄應為空,證明 (a) 的斷言確實偵測得到「沒觸發」"
	).is_equal(0)

	# Cleanup
	await _release(battle, original)


## story-004:第 1 場開局會把關卡起始關係(STORY_EVENT)寫進累積記錄,
## 所以「記錄為空」不再成立;改數特定來源的筆數。
func _count_source(ledger: CampaignAffinityLedger, source: AffinityTypes.Source) -> int:
	var n: int = 0
	for entry: CampaignAffinityLedger.Entry in ledger.records():
		if entry.source == source:
			n += 1
	return n
