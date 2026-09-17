# 拋棄式探針 —— 覆核 U-018 時協調者指定要補的洞:
#
# 「當某個敵方單位在『舊快照已建立、但該單位尚未被走訪』的時間窗內被移出回合序時,
#  run_enemy_phase() 與 step_enemy_phase() 的最終盤面與 log 是否仍然逐項一致?」
#
# 🔴 本探針【呼叫專案自己的類別】(BattleController / TurnOrder / BattleState),
#    不重新實作任何一條規則 —— run_enemy_phase() / step_enemy_phase() / TurnOrder.
#    remove_unit() / TurnOrder.is_done() / TurnOrder.units_with_flags_remaining() 全部
#    是直接呼叫,本檔不重寫這些方法的任何一行邏輯。
#
# ── Part 0:確認「自然觸發」這個時間窗是否可達 ──────────────────────────────────
# 在動手做合成情境之前,先直接呼叫 BattleState.can_attack() 確認:敵方階段裡,一個
# 敵人是否可能透過正常攻擊解算殺死「另一個」敵人(這是唯一會呼叫
# TurnOrder.remove_unit() 的正式程式碼路徑 —— 見 battle_controller.gd:1017)。
# can_attack() 的原始碼(battle_state.gd:224-231)在 target.faction == attacker.faction
# 時直接回傳 false —— 讀原始碼可以推出「同陣營必被拒絕」,但本探針不滿足於推論,
# 直接呼叫這個方法,拿真實引擎的回傳值。
#
# ── Part 1:合成觸發 ────────────────────────────────────────────────────────
# 由於 Part 0 預期會證實「同陣營攻擊在遊戲規則下走不到 remove_unit()」,本探針改用
# 一個側效應注入的 decide callable,在處理 E2(單位 3)時,直接呼叫真正的
# TurnOrder.remove_unit(4)(E3 的 id)—— 這一步繞過了戰鬥解算(不透過
# _state.resolve_attack()/can_attack()),但呼叫的是 TurnOrder 真正的移除 API,
# 不是重新實作的假版本。目的是製造協調者指定的那個時間窗:E3 的 id 已經被收進
# run_enemy_phase() 的 acting_ids 快照 / step_enemy_phase() 的 _enemy_step_snapshot
# 快照裡,但迴圈走到它之前就被移除。
#
# 誠實揭露:這個側效應**不是**真實死亡(BattleState 裡 E3 的 HP/位置完全不受影響,
# 只有 TurnOrder 的簿記被動了手腳)——因為 Part 0 已經確認正式規則下不存在「敵人殺
# 敵人」這條路徑,要製造這個時間窗只能繞開戰鬥解算、直接操作 TurnOrder 本身。這是
# 探針的已知限制,不是被隱藏的簡化。
extends SceneTree


func _idle_three_enemy_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,999,0,999,0,1,1,0,0",
		"2,E1,ENEMY,100,0,100,0,1,1,12,5",
		"3,E2,ENEMY,100,0,100,0,1,1,12,4",
		"4,E3,ENEMY,100,0,100,0,1,1,12,3",
	]


# 側效應注入:處理 trigger_id 時,直接呼叫真正的 TurnOrder.remove_unit(remove_id) ——
# 呼叫的是 order 這個真實 TurnOrder 實例的真實方法,不是重新實作。
func _make_decide(order: TurnOrder, trigger_id: int, remove_id: int) -> Callable:
	return func(
		_decide_state: BattleState, unit_id: int, _can_move: bool, _can_attack: bool
	) -> Dictionary:
		if unit_id == trigger_id:
			order.remove_unit(remove_id)
		return {"move_to": null, "attack": -1}


func _build(decide_factory: Callable) -> Dictionary:
	var roster: Array[String] = _idle_three_enemy_roster()
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2, 3, 4])
	var decide: Callable = decide_factory.call(order)
	var controller: BattleController = BattleController.new(state, order, Callable(), decide)
	return {"state": state, "order": order, "controller": controller}


func _init() -> void:
	var ok: bool = true

	# ── Part 0 ──────────────────────────────────────────────────────────────
	print("=== Part 0: 自然觸發路徑是否可達(同陣營攻擊是否被 can_attack() 擋下)===")
	var probe_state: BattleState = BattleState.create(
		PackedStringArray(), "\n".join(_idle_three_enemy_roster())
	)
	var same_faction_can_attack: bool = probe_state.can_attack(2, 3)  # E1 attacks E2, both ENEMY
	print("BattleState.can_attack(2, 3) [E1→E2, 同陣營] = %s (expected: false)" % same_faction_can_attack)
	if same_faction_can_attack:
		print("🔴 UNEXPECTED: 同陣營攻擊未被擋下 —— 這代表自然觸發路徑可能存在,")
		print("   Part 1 的『侵入式』做法就不是唯一手段,請回報協調者重新設計探針。")
		ok = false
	else:
		print("確認:can_attack() 對同陣營目標回傳 false —— 敵人殺敵人這條路徑,在目前")
		print("規則下無法透過正式攻擊解算走到 TurnOrder.remove_unit()。Part 1 改用側效應注入。")

	# ── Part 1:兩條路徑各自跑一遍相同情境 ───────────────────────────────────
	print("")
	print("=== Part 1: run_enemy_phase() vs step_enemy_phase() —— 移除發生在快照未走訪的區段 ===")

	var batch_bundle: Dictionary = _build(
		func(order: TurnOrder) -> Callable: return _make_decide(order, 3, 4)
	)
	var stepped_bundle: Dictionary = _build(
		func(order: TurnOrder) -> Callable: return _make_decide(order, 3, 4)
	)

	var batch_controller: BattleController = batch_bundle["controller"]
	var batch_order: TurnOrder = batch_bundle["order"]
	var batch_state: BattleState = batch_bundle["state"]
	var stepped_controller: BattleController = stepped_bundle["controller"]
	var stepped_order: TurnOrder = stepped_bundle["order"]
	var stepped_state: BattleState = stepped_bundle["state"]

	batch_controller.end_faction_phase()
	stepped_controller.end_faction_phase()

	# Act — batch
	var batch_log: Array[String] = batch_controller.run_enemy_phase()

	# Act — stepped, 逐次呼叫直到不再是 ENEMY_ACTING,附防呆上限（比照既有測試慣例）
	var stepped_log: Array[String] = []
	var call_count: int = 0
	var guard: int = 0
	while stepped_controller.phase() == BattleController.Phase.ENEMY_ACTING:
		guard += 1
		if guard > 20:
			print("🔴 GUARD TRIPPED — stepped 路徑超過 20 次呼叫仍未結束，視為異常。")
			ok = false
			break
		var step: Dictionary = stepped_controller.step_enemy_phase()
		call_count += 1
		var step_log: Array[String] = step["log"]
		stepped_log.append_array(step_log)
		print(
			"  call #%d: log=%s has_next=%s phase=%s"
			% [call_count, step_log, step["has_next"], stepped_controller.phase()]
		)

	print("")
	print("batch_log   = %s" % [batch_log])
	print("stepped_log = %s" % [stepped_log])
	print("logs_equal? %s" % (batch_log == stepped_log))
	if batch_log != stepped_log:
		ok = false

	print("")
	print("batch  : phase=%s round=%d" % [batch_controller.phase(), batch_controller.round_number()])
	print("stepped: phase=%s round=%d" % [stepped_controller.phase(), stepped_controller.round_number()])
	var phase_equal: bool = batch_controller.phase() == stepped_controller.phase()
	var round_equal: bool = batch_controller.round_number() == stepped_controller.round_number()
	print("phase_equal? %s   round_equal? %s" % [phase_equal, round_equal])
	if not phase_equal or not round_equal:
		ok = false

	print("")
	print("--- TurnOrder 簿記狀態逐一比對 ---")
	for id: int in [2, 3, 4]:
		var b_done: bool = batch_order.is_done(id)
		var s_done: bool = stepped_order.is_done(id)
		print("id=%d  batch.is_done=%s  stepped.is_done=%s  equal=%s" % [id, b_done, s_done, b_done == s_done])
		if b_done != s_done:
			ok = false

	print("")
	print("--- BattleState 逐一比對（確認側效應真的只動了 TurnOrder，沒有動到戰鬥狀態本身）---")
	for id: int in [1, 2, 3, 4]:
		var b_unit: Unit = batch_state.unit_by_id(id)
		var s_unit: Unit = stepped_state.unit_by_id(id)
		var hp_equal: bool = b_unit.hp == s_unit.hp
		var pos_equal: bool = batch_state.position_of(id) == stepped_state.position_of(id)
		print(
			"id=%d  batch_hp=%d stepped_hp=%d hp_equal=%s  pos_equal=%s"
			% [id, b_unit.hp, s_unit.hp, hp_equal, pos_equal]
		)
		if not hp_equal or not pos_equal:
			ok = false

	print("")
	if ok:
		print("=== RESULT: PASS —— 兩條路徑在這個時間窗下逐項一致 ===")
	else:
		print("=== RESULT: FAIL —— 兩條路徑出現分歧，見上方標記 ===")

	quit(0 if ok else 1)
