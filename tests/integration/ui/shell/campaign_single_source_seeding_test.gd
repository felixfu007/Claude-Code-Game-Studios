# 關係單一來源(support-conversation story-004,管理者 2026-10-27 裁決
# 「只有第 1 場灌,之後靠累積(推薦)」)。
#
# 載入真實 BattleScreen.tscn,經 SceneRouter(production 入口)進樹。
# 檔案存取:只有被測程式自己讀的、已進版控的 assets/data 資料檔(甲類例外);
# 本檔自己不做 I/O。
#
# 涵蓋:(a) 第 1 場:起始關係寫進累積記錄,池子與「未注入」同場逐值相同(AC1);
#       (b) 第 2 場:不灌 links,池子只反映累積記錄(AC2);
#       (c) 第 1 場打輸重打:開局狀態與第一次相同(AC3);
#       (d) 敏感度證明:常駐變種「第 2 場仍灌 links」會被 (b) 的量測抓到。
#
# ⚠️ (d) 的誠實揭露:BattleScreen._ready() 內的灌入段沒有注入縫,變種是在
# super._ready() 之後額外補灌 C1_C2 —— 它模擬的是「第 2 場以後仍灌 links」
# 這個錯誤的【可觀測後果】,不是把那段 if 守衛本身改壞。它證明的是 (b) 量測
# 的量(C1_C2 的 n_pair)對這個錯誤有反應,不證明守衛的每個分支。
extends GdUnitTestSuite


const _TITLE_SCENE_PATH: String = "res://src/ui/shell/TitleScreen.tscn"
const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


## 常駐變種:第 2 場以後仍然把 vs0N 的起始關係灌進池子(C1_C2 正向)。
class _MutantStillSeedsLinks extends BattleScreen:
	func _ready() -> void:
		super._ready()
		_apply_opening_affinity_record(
			AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT, "mutant"
		)


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


func _enter_battle_via_router() -> BattleScreen:
	SceneRouter.enter_battle(get_tree())
	await _wait_swap()
	return get_tree().current_scene as BattleScreen


func _enter_mutant_battle() -> BattleScreen:
	var configure: Callable = func(node: Node) -> void:
		# 🔴 set_script 必須在賦值 override 之前(coding-standards.md 已登記)。
		node.set_script(_MutantStillSeedsLinks)
		(node as BattleScreen).campaign_ledger_override = (
			CampaignProgress.start_mission_affinity_ledger()
		)
	var created: Node = SceneRouter.switch_to(
		get_tree(), SceneRouter.BATTLE_SCENE_PATH, configure
	)
	await _wait_swap()
	return created as BattleScreen


func _cleanup() -> void:
	var current: Node = get_tree().current_scene
	if current != null and is_instance_valid(current):
		current.queue_free()
		await get_tree().process_frame


func _read(battle: BattleScreen, pair: AffinityTypes.Pair) -> AffinityDataPool.AffinityReadResult:
	return battle._affinity_pool.combat_strength_read(pair)


## 把全部 10 對配對的 (n_pair, value) 攤成字串陣列,供逐值比對。
func _pool_snapshot(battle: BattleScreen) -> Array[String]:
	var out: Array[String] = []
	for pair: int in AffinityTypes.Pair.values():
		var r: AffinityDataPool.AffinityReadResult = _read(battle, pair)
		out.append("%d:%d:%.6f" % [pair, r.n_pair, r.value])
	return out


func _has_record(ledger: CampaignAffinityLedger, pair: AffinityTypes.Pair, source: AffinityTypes.Source) -> bool:
	for entry: CampaignAffinityLedger.Entry in ledger.records():
		if entry.pair == pair and entry.source == source:
			return true
	return false


# (a) AC1
func test_mission_one_seeds_links_into_ledger_and_pool_matches_non_campaign() -> void:
	# Arrange — 對照組:未注入 ledger 的同場
	var baseline: BattleScreen = load(_SCENE_PATH).instantiate()
	add_child(baseline)
	var baseline_snapshot: Array[String] = _pool_snapshot(baseline)
	baseline.queue_free()
	await get_tree().process_frame

	await _stand_in_title()

	# Act
	var battle: BattleScreen = await _enter_battle_via_router()

	# Assert
	assert_object(battle).is_not_null()
	assert_bool(battle._load_failed).is_false()
	var ledger: CampaignAffinityLedger = battle.campaign_ledger_override
	assert_int(ledger.records().size()).is_equal(2)
	assert_bool(_has_record(ledger, AffinityTypes.Pair.C1_C2, AffinityTypes.Source.STORY_EVENT)).is_true()
	assert_bool(_has_record(ledger, AffinityTypes.Pair.C3_C4, AffinityTypes.Source.STORY_EVENT)).is_true()
	assert_array(_pool_snapshot(battle)).is_equal(baseline_snapshot)
	assert_int(_read(battle, AffinityTypes.Pair.C1_C2).n_pair).is_equal(1)
	assert_int(_read(battle, AffinityTypes.Pair.C3_C4).n_pair).is_equal(1)

	await _cleanup()


# (b) AC2
func test_mission_two_does_not_seed_links_pool_reflects_ledger_only() -> void:
	# Arrange — 推到第 2 場,模擬第 1 場留下 C3_C4 正向一筆(與 vs02 起始關係不同)
	CampaignProgress.advance_on_victory(2)
	CampaignProgress.start_mission_affinity_ledger().append(
		AffinityTypes.Pair.C3_C4, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)
	await _stand_in_title()

	# Act
	var battle: BattleScreen = await _enter_battle_via_router()

	# Assert
	assert_int(CampaignProgress.current_mission()).is_equal(2)
	assert_int(battle.campaign_ledger_override.records().size()).is_equal(1)
	assert_int(_read(battle, AffinityTypes.Pair.C1_C2).n_pair).append_failure_message(
		"第 2 場不該灌 vs02 的 C1_C2 起始關係"
	).is_equal(0)
	assert_int(_read(battle, AffinityTypes.Pair.C3_C4).n_pair).is_equal(1)
	assert_bool(_read(battle, AffinityTypes.Pair.C3_C4).value > 0.0).is_true()

	await _cleanup()


# (c) AC3
func test_mission_one_defeat_replay_starts_in_same_state_without_duplicates() -> void:
	# Arrange
	await _stand_in_title()
	var first: BattleScreen = await _enter_battle_via_router()
	var first_count: int = first.campaign_ledger_override.records().size()
	var first_snapshot: Array[String] = _pool_snapshot(first)

	# Act — 打輸回滾,重打
	CampaignProgress.rollback_on_defeat()
	var second: BattleScreen = await _enter_battle_via_router()

	# Assert
	assert_int(first_count).is_equal(2)
	assert_int(second.campaign_ledger_override.records().size()).is_equal(first_count)
	assert_array(_pool_snapshot(second)).is_equal(first_snapshot)

	await _cleanup()


# (d) 敏感度證明
func test_sensitivity_mutant_that_still_seeds_links_on_mission_two_is_caught() -> void:
	# Arrange — 與 (b) 完全相同的場景,只換成變種
	CampaignProgress.advance_on_victory(2)
	CampaignProgress.start_mission_affinity_ledger().append(
		AffinityTypes.Pair.C3_C4, 1.0, AffinityTypes.Source.SUPPORT_CONVERSATION
	)
	await _stand_in_title()

	# Act
	var battle: BattleScreen = await _enter_mutant_battle()

	# Assert — (b) 量的那個量(C1_C2 n_pair)在變種下不再是 0
	assert_object(battle).is_not_null()
	assert_int(_read(battle, AffinityTypes.Pair.C1_C2).n_pair).is_equal(1)

	await _cleanup()
