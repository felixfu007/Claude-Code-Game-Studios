# BattleLoop（src/gameplay/battle/battle_loop.gd）的單元測試。
#
# 這是本專案第一個「會自己動」的東西：BattleLoop 把 TurnOrder 與 BattleState
# 串起來，靠注入的 decide Callable 把一整場戰鬥從頭跑到尾。這裡不使用、也不
# 引用任何真正的 AI（如 GreedyTacticalAI）——每個測試都用自己寫的 stub
# Callable，只在乎它是否遵守 decide.call(state, unit_id, can_move, can_attack)
# -> {"move_to": ..., "attack": ...} 這個固定簽章。
#
# 盤面與名冊都是各測試自組的最小資料，不讀 assets/data 底下的真實關卡檔——
# 命名慣例沿用 tests/unit/gameplay/combat/combat_rules_test.gd 的
# test_[scenario]_[expected]。
#
# 不建立任何 Node —— BattleLoop 全鏈路（TurnOrder/BattleState/Board/Unit/
# CombatRules）都是 RefCounted，不會留下孤兒節點。
extends GdUnitTestSuite


# 「無視 can_move 旗標」decide 自我上限，只給
# test_battle_aborts_when_decide_ignores_can_move_flag() 用。旗標閘門正常運作時
# 這個上限永遠碰不到（該測試裡玩家單位每輪只會被問到 2 次就因旗標已花掉而
# did_something 為 false、觸發 end_unit_turn()）——手法與命名對照
# tests/unit/gameplay/battle/battle_controller_test.gd 的
# _RELENTLESS_DECIDE_CALL_LIMIT，兩者守的是同一類「閘門失效會讓同步無限
# 迴圈掛住整個測試 job」的缺陷，故意讓讀起來一眼看出是同一個手法。
const _RELENTLESS_DECIDE_CALL_LIMIT: int = 50


# ---- victory + dead-unit-removal from turn order ---------------------------
#
# 場景：玩家 1 人 vs 敵人 2 人，三者互為射程 1 內的鄰居，mp=0（誰都無法移動，
# 排除移動路徑的干擾）。玩家的 decide 永遠優先打活著的敵人 2，2 死了才轉打
# 3；敵人的 decide 永遠打玩家 1，但玩家防禦極高，敵人的攻擊必定造成 0 傷害，
# 不會意外觸發 DEFEAT。
#
# 這個場景刻意讓敵人 2 死於玩家的回合（第 1 輪玩家階段），也就是敵人 2
# 自己的回合（第 1 輪敵人階段）根本還沒開始。用 call_counts 數 decide 以
# unit_id=2 被呼叫幾次：正確移除的話恆為 0（死在自己的回合開始之前，永遠
# 輪不到它）；如果 BattleLoop 忘記在它死亡當下呼叫 order.remove_unit()，
# 它會繼續留在 TurnOrder 的敵方名單裡、is_actionable() 判定仍為可行動，
# 敵人階段就會真的呼叫到它的 decide（call_counts 變成 ≥1），並讓
# BattleState 對著它已被抹除的座標算出從 Vector2i(0,0) 起算的錯誤答案。
func test_battle_runs_to_victory_and_removes_dead_unit_from_turn_order() -> void:
	# Arrange
	var roster_text: String = "\n".join([
		"1,P1,PLAYER,100,50,100,0,1,1,0,0",
		"2,E1,ENEMY,10,1,0,0,1,1,1,0",
		"3,E2,ENEMY,60,1,40,0,1,1,0,1",
	])
	var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var call_counts: Dictionary = {}
	var decide: Callable = _make_decide(call_counts, 2, 3, 1)
	var loop: BattleLoop = BattleLoop.new(state, order, decide)

	# Act
	var result: Dictionary = loop.run(20)

	# Assert
	var outcome: BattleState.Outcome = result["outcome"]
	var rounds: int = result["rounds"]
	var aborted: bool = result["aborted"]
	assert_int(outcome).is_equal(BattleState.Outcome.VICTORY)
	assert_int(rounds).is_equal(7)
	assert_bool(aborted).is_false()
	assert_int(call_counts.get(2, 0)).is_equal(0)


# ---- defeat ------------------------------------------------------------

func test_battle_runs_to_defeat_when_player_dies() -> void:
	# Arrange — 玩家永不出手（decide 恆回不動不打），敵人每輪必打玩家；
	# 玩家 def=0、hp=10，敵人 atk=20，第 1 擊即可致死（20-0=20≥10）
	var roster_text: String = "\n".join([
		"1,P1,PLAYER,10,1,0,0,1,1,0,0",
		"2,E1,ENEMY,50,20,100,0,1,1,1,0",
	])
	var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var order: TurnOrder = TurnOrder.new([1], [2])
	var decide: Callable = _make_decide({}, -1, -1, 1)
	var loop: BattleLoop = BattleLoop.new(state, order, decide)

	# Act
	var result: Dictionary = loop.run(20)

	# Assert
	var outcome: BattleState.Outcome = result["outcome"]
	var rounds: int = result["rounds"]
	var aborted: bool = result["aborted"]
	assert_int(outcome).is_equal(BattleState.Outcome.DEFEAT)
	assert_int(rounds).is_equal(1)
	assert_bool(aborted).is_false()


# ---- max_rounds abort ----------------------------------------------------

func test_battle_aborts_at_max_rounds_without_hanging() -> void:
	# Arrange — 兩邊 decide 恆不動不打（僵局），確保迴圈不會真的卡住，只會
	# 撞到安全閥
	var roster_text: String = "\n".join([
		"1,P1,PLAYER,100,1,100,0,1,1,0,0",
		"2,E1,ENEMY,100,1,100,0,1,1,5,5",
	])
	var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var order: TurnOrder = TurnOrder.new([1], [2])
	var never_act: Callable = func(
		_state: BattleState, _unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		return {"move_to": null, "attack": -1}
	var loop: BattleLoop = BattleLoop.new(state, order, never_act)

	# Act
	var result: Dictionary = loop.run(3)

	# Assert
	var outcome: BattleState.Outcome = result["outcome"]
	var rounds: int = result["rounds"]
	var aborted: bool = result["aborted"]
	assert_bool(aborted).is_true()
	assert_int(outcome).is_equal(BattleState.Outcome.ONGOING)
	assert_int(rounds).is_equal(3)


# ---- regression: decide ignoring can_move must not hang run() -------------
#
# 主 session 探針證實：修好之前，一個「無視 can_move 旗標、永遠回傳合法
# move_to」的 decide 會讓 run() 真的無限迴圈，40 秒 timeout 才砍得掉——
# 不是 max_rounds 檢查位置錯了，是 _process_unit() 對 state.move_unit() 的
# 呼叫完全不看 TurnOrder 的旗標，導致 did_something 恆為 true、
# end_unit_turn() 永遠不會被呼叫、round_number() 永遠不會推進，
# max_rounds 因此永遠等不到檢查的機會。
#
# 這裡的 decide 對玩家單位在 (0,0)/(1,0) 兩格之間來回要求移動，兩格互相
# mp=1 可達，因此 state.move_unit() 每次都會合法成功，完全不管 can_move
# 是否已經是 false——這正是探針重現的手法。敵人單位永遠不動不打，只是
# 陪著撐住 ONGOING，不讓 outcome() 提前用「沒有敵人」的空集合判定 VICTORY。
#
# 🔴 這條測試曾經是「閘門失效時不會失敗，而是掛住」的缺陷本身：GDScript 是
# 同步執行，while 迴圈裡沒有 await，GdUnit4 的逾時機制攔不住一個同步無限
# 迴圈，斷言那幾行永遠執行不到——CI 上的後果不是紅燈，是整個 job 卡死等
# 外部逾時。修法對照 battle_controller_test.gd 的
# test_run_enemy_phase_terminates_when_injected_decide_ignores_flags()：
# decide 本身帶了 _RELENTLESS_DECIDE_CALL_LIMIT 這個自我上限——耍賴滿 50
# 次之後改回傳「什麼都不做」，讓迴圈必然終止。這不是為了讓測試「通過」而
# 妥協：旗標閘門正常運作時，玩家單位每輪只會被問到 2 次（一次因旗標未花掉
# 而合法移動、一次因旗標已花掉而被擋下、did_something 為 false、觸發
# end_unit_turn()），3 輪跑滿共 6 次，上限永遠碰不到，語意與行為完全不變。
# 上限只在閘門失效那一分支才有意義：它把「run() 永遠不返回」變成「run()
# 會返回，但 call_counts 遠高於 6」——讓下面的 assert 真的執行得到、真的
# 能印出「期望值是什麼、實際值是什麼」，而不是讓整個測試 job 卡死等外部
# 逾時。
func test_battle_aborts_when_decide_ignores_can_move_flag() -> void:
	# Arrange
	var roster_text: String = "\n".join([
		"1,P1,PLAYER,100,1,100,1,1,1,0,0",
		"2,E1,ENEMY,100,0,100,0,1,1,10,10",
	])
	var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var order: TurnOrder = TurnOrder.new([1], [2])
	var call_counts: Dictionary = {}
	var relentless_move: Callable = func(
		decide_state: BattleState, unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		call_counts[unit_id] = call_counts.get(unit_id, 0) + 1
		if call_counts[unit_id] > _RELENTLESS_DECIDE_CALL_LIMIT:
			return {"move_to": null, "attack": -1}
		var unit: Unit = decide_state.unit_by_id(unit_id)
		if unit.faction == Unit.Faction.ENEMY:
			return {"move_to": null, "attack": -1}
		var current_pos: Vector2i = decide_state.position_of(unit_id)
		var target_pos: Vector2i = (
			Vector2i(1, 0) if current_pos == Vector2i(0, 0) else Vector2i(0, 0)
		)
		return {"move_to": target_pos, "attack": -1}
	var loop: BattleLoop = BattleLoop.new(state, order, relentless_move)

	# Act — 旗標閘門生效的話，無論 decide 怎麼耍賴，run() 必須在
	# call_counts 遠低於自我上限的第 6 次呼叫附近就正常返回；閘門若失效，
	# 這行仍然會返回（因為自我上限保底），但下面的斷言會清楚失敗
	var result: Dictionary = loop.run(3)

	# Assert
	var aborted: bool = result["aborted"]
	var rounds: int = result["rounds"]
	assert_bool(aborted).is_true()
	assert_int(rounds).is_equal(3)
	assert_int(call_counts.get(1, 0)).is_equal(6)


# ---- rounds count, isolated from outcome complexity ------------------------
#
# 前面幾條測試的 rounds 斷言都附帶在勝利/中止的情境裡，順帶被驗到。這裡直接
# 用捕捉到的 order 讀 round_number() 來控制「玩家在第幾輪才出手」，讓
# rounds 的正確性不必依賴任何傷害/血量算術，只單純驗證回合計數本身。
func test_run_reports_exact_round_count_elapsed() -> void:
	# Arrange — 第 1、2 輪雙方什麼都不做；玩家在第 3 輪才一擊必殺，battle
	# 應該在 round_number() 仍是 3 的當下就結束
	var roster_text: String = "\n".join([
		"1,P1,PLAYER,100,50,100,0,1,1,0,0",
		"2,E1,ENEMY,10,0,0,0,1,1,1,0",
	])
	var state: BattleState = BattleState.create(PackedStringArray(), roster_text)
	var order: TurnOrder = TurnOrder.new([1], [2])
	var wait_then_strike: Callable = func(
		decide_state: BattleState, unit_id: int, _can_move: bool, can_attack: bool
	) -> Dictionary:
		var unit: Unit = decide_state.unit_by_id(unit_id)
		if unit.faction == Unit.Faction.ENEMY or not can_attack:
			return {"move_to": null, "attack": -1}
		if order.round_number() < 3:
			return {"move_to": null, "attack": -1}
		return {"move_to": null, "attack": 2}
	var loop: BattleLoop = BattleLoop.new(state, order, wait_then_strike)

	# Act
	var result: Dictionary = loop.run(10)

	# Assert
	var outcome: BattleState.Outcome = result["outcome"]
	var rounds: int = result["rounds"]
	assert_int(outcome).is_equal(BattleState.Outcome.VICTORY)
	assert_int(rounds).is_equal(3)


# ---- fixtures ------------------------------------------------------------

# Builds a decide Callable that counts every call into call_counts (keyed by
# unit_id), and: for a PLAYER unit, attacks primary_target if it is still
# alive, else secondary_target; for an ENEMY unit, always attacks
# enemy_target. Only ever attacks (never moves) — every roster in this file
# uses mp=0, so movement is irrelevant to these scenarios.
func _make_decide(
	call_counts: Dictionary, primary_target: int, secondary_target: int, enemy_target: int
) -> Callable:
	return func(
		state: BattleState, unit_id: int, _can_move: bool, can_attack: bool
	) -> Dictionary:
		call_counts[unit_id] = call_counts.get(unit_id, 0) + 1
		if not can_attack:
			return {"move_to": null, "attack": -1}

		var unit: Unit = state.unit_by_id(unit_id)
		if unit.faction == Unit.Faction.ENEMY:
			return {"move_to": null, "attack": enemy_target}

		if primary_target != -1 and state.unit_by_id(primary_target).is_alive():
			return {"move_to": null, "attack": primary_target}
		if secondary_target != -1:
			return {"move_to": null, "attack": secondary_target}
		return {"move_to": null, "attack": -1}
