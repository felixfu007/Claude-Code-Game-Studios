## Story-003b AC8 — covers ADR-0001 Validation Criteria 4d / 4e / 4f / 4i / 4j /
## 4l (docs/architecture/adr-0001-tactical-query-atomicity-contract.md,
## Validation Criteria table — grep `| 4d \|| 4e \|| 4f \|| 4i \|| 4j \|| 4l `
## in that file to re-locate the authoritative wording this file tests
## against; read before trusting this comment's paraphrase).
##
## Split out from the guard-rejection tests (mutator_guard_rejection_test.gd)
## per .claude/docs/coding-standards.md: a failing test aborts the rest of its
## own suite, so version-increment semantics and per-mutator guard rejection
## are kept in separate files to avoid one failure masking the other group.
##
## 4a/4b/4c are already covered by
## tests/unit/gameplay/battle/attack_los_blocked_query_test.gd — confirmed by
## reading that file before writing this one: its four
## test_combat_state_version_* functions assert exactly those three rows
## (unchanged on rejected move / pure queries, +1 on move, +1 on
## resolve_attack) plus the external-write-rejection test, which is a
## different concern (Mechanism One's read-only property, not a Validation
## Criteria row).
##
## Fixture convention follows battle_controller_test.gd / battle_loop_test.gd:
## empty terrain (PackedStringArray(), all-open 13x6 board), minimal
## hand-authored rosters, no Node ever constructed (every class in this call
## chain — Board/Unit/TurnOrder/BattleState/BattleController/BattleLoop — is
## RefCounted or static), so nothing here leaves an orphan.
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

# Builds a minimal BattleState/TurnOrder/BattleController trio over empty
# (all-open) terrain. decide defaults to an unset Callable (GreedyTacticalAI
# fallback); tests that need deterministic enemy behavior pass their own.
func _build(
	roster_lines: Array[String],
	player_ids: Array[int],
	enemy_ids: Array[int],
	decide: Callable = Callable()
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order, Callable(), decide)
	return {"state": state, "order": order, "controller": controller}


# decide Callable shared by the 4d test below: attacks player unit 1 whenever
# the attack flag is still available, never requests a move. Used instead of
# the default GreedyTacticalAI so the action count per enemy is exactly
# predictable (2 _process_enemy_unit() calls per unit: attack, then
# end-turn-without-acting) rather than depending on pathfinding/targeting.
func _always_attack_player_1(
	_state: BattleState, _unit_id: int, _can_move: bool, can_attack: bool
) -> Dictionary:
	if can_attack:
		return {"move_to": null, "attack": 1}
	return {"move_to": null, "attack": -1}


# ---- 4d: 一次敵方回合整批結算完成 → 恰好 +1(多單位、多動作仍只 +1,不是 +N) ----

func test_4d_enemy_batch_settlement_with_two_units_two_actions_increments_version_by_exactly_one() -> void:
	# Arrange — 2 個敵方單位、1 個玩家單位,玩家 DEF=100 保證承傷恆為 0
	# (CombatRules.damage = max(0, atk - def + phi),atk=5 時必為 0),battle
	# 全程 ONGOING,不會有勝負判定提前結束迴圈干擾本測試的計次。兩個敵方
	# 單位各自需要兩次 _process_enemy_unit() 呼叫才會「done」(第一次攻擊、
	# 第二次因攻擊旗標已用盡且不移動而 end_unit_turn()),藉此確保這是一次
	# 真正的「多單位、多動作」整批結算,而不是巧合的單一動作就通過。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,0,100,0,1,1,0,0",
		"2,E1,ENEMY,20,5,0,0,1,1,1,0",
		"3,E2,ENEMY,20,5,0,0,1,1,0,1",
	]
	var bundle: Dictionary = _build(
		roster, [1], [2, 3], Callable(self, "_always_attack_player_1")
	)
	var state: BattleState = bundle["state"]
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	var before: int = state.combat_state_version

	# Act
	var log: Array[String] = controller.run_enemy_phase()

	# Assert — 恰好 +1(不是 +2 或更多),且確實發生了兩個單位的動作(非空批次)。
	# 🔴 不可用 order.is_done(2)/is_done(3) 驗證「兩個單位都動作過」——
	# run_enemy_phase() 內部的 _finalize_enemy_phase() 在同一次提交裡呼叫
	# advance_faction(),而 TurnOrder.advance_faction() 的文件註解明文:
	# 「結束中的那個陣營,每個單位的旗標與 done 狀態一律清空」——敵方done
	# 狀態在 run_enemy_phase() 返回前就已被這個 reset-on-boundary 規則清掉,
	# 不是本測試的受測對象(已改用 log 內容驗證兩個單位確實都有動作)。
	assert_int(state.combat_state_version).is_equal(before + 1)
	assert_bool(log.is_empty()).is_false()
	var combined_log: String = "\n".join(log)
	assert_bool(combined_log.contains("E1")).is_true()
	assert_bool(combined_log.contains("E2")).is_true()
	assert_int(order.round_number()).is_equal(2)
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


# ---- 4e: 一次玩家主動結束單位行動(end_unit_turn)→ 恰好 +1 -----------------

func test_4e_player_end_unit_turn_increments_version_by_exactly_one() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	var before: int = state.combat_state_version

	# Act
	var ended: bool = controller.end_unit_turn(1)

	# Assert
	assert_bool(ended).is_true()
	assert_bool(order.is_done(1)).is_true()
	assert_int(state.combat_state_version).is_equal(before + 1)


# ---- 4f: 一次玩家結束陣營回合(advance_faction 的玩家呼叫點)→ 恰好 +1 ------
# ---- (與 4d 經 run_enemy_phase() 內部觸發的 advance_faction 是不同呼叫點) ---

func test_4f_player_end_faction_phase_increments_version_by_exactly_one() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	var before: int = state.combat_state_version

	# Act — 直接呼叫 end_faction_phase(),不接著呼叫 run_enemy_phase():本測試
	# 只關心這一個呼叫點本身的遞增量,不與 4d 的 run_enemy_phase() 混在一起量。
	controller.end_faction_phase()

	# Assert
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	assert_int(state.combat_state_version).is_equal(before + 1)


# ---- 4i: 單位選取 / 取消選取 → 版本不變(明文裁定不是權威寫入) --------------

func test_4i_select_and_deselect_unit_leave_version_unchanged() -> void:
	# Arrange
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	var before: int = state.combat_state_version

	# Act / Assert — 選取後版本不變
	assert_bool(controller.select_unit(1)).is_true()
	assert_int(state.combat_state_version).is_equal(before)

	# Act / Assert — 取消選取後版本仍不變
	controller.deselect()
	assert_int(controller.selected_unit()).is_equal(-1)
	assert_int(state.combat_state_version).is_equal(before)


# ---- 4j: 經 BattleLoop 而非 BattleController 驅動的同類寫入 → 恰好 +1 ------
# ---- (兩條驅動路徑平行且互不呼叫,只測 BattleController 會讓 BattleLoop ----
# ---- 這條路徑的繞過完全不可觀測 —— 本測試獨立驗證 BattleLoop 這一條)-------

func test_4j_battle_loop_driven_round_increments_version_by_exactly_the_predicted_commit_count() -> void:
	# Arrange — 場景設計使整回合的提交次數可以逐步推導、精確預測:
	#   1) PLAYER 階段批次提交(單位 1 的 decide 恆回 move=null/attack=-1,
	#      第一次 _process_unit() 就 did_something=false → end_unit_turn()
	#      → done)                                                     +1
	#   2) PLAYER -> ENEMY 的 advance_faction() 提交                    +1
	#   3) ENEMY 階段批次提交(2 個敵方單位、各自需要兩次 _process_unit()
	#      才 done:第一次攻擊、第二次因攻擊旗標已用盡且不移動而結束回合;
	#      整批無論內部動作數多寡,仍只計一次提交)                       +1
	#   4) ENEMY -> PLAYER 的 advance_faction() 提交(round_number 進到 2;
	#      begin_player_turn() 不貢獻額外的版本遞增)                    +1
	#      🔴 2026-10-12 更正(story-003c 落地後):本行原寫
	#      「begin_player_turn() 依路徑⑥的裁決刻意留在本次提交窗口之外
	#      [story-003c 的範圍]」—— 那句話現在是假的。story-003c 已把
	#      advance_faction() 與 begin_player_turn() 收進【同一個】
	#      commit_authoritative_change() Callable(見 battle_loop.gd 的
	#      _advance_faction_and_start_next_turn())。
	#      ⚠️ 本測試的 +1 與總數【完全不受影響】,但原因變了:
	#        變更前 = 它在窗口【之外】,所以不遞增。
	#        變更後 = 它在窗口【之內】,但屬巢狀提交,只有深度歸 0 才遞增
	#                 (ADR-0001 第二次修訂的深度計數器語意)。
	#      兩個不同的機制給出同一個數字 —— 這正是為什麼光看數字對不對
	#      無法察覺這段註解已經過時。
	# max_rounds=1 保證迴圈在完成以上 4 次提交後,於 round_number()=2 的
	# 下一次迴圈頂端立即因 2 > 1 而中止,不會有第 5 次提交發生。
	# 玩家 DEF=100 保證敵方攻擊造成的傷害恆為 0(CombatRules.damage 公式),
	# battle 全程 ONGOING,不會有勝負判定提前結束迴圈干擾本測試的計次。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,0,100,0,1,1,0,0",
		"2,E1,ENEMY,20,5,0,0,1,1,1,0",
		"3,E2,ENEMY,20,5,0,0,1,1,0,1",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var decide: Callable = func(
		s: BattleState, unit_id: int, _can_move: bool, can_attack: bool
	) -> Dictionary:
		var unit: Unit = s.unit_by_id(unit_id)
		if unit.faction == Unit.Faction.ENEMY and can_attack:
			return {"move_to": null, "attack": 1}
		return {"move_to": null, "attack": -1}
	var loop: BattleLoop = BattleLoop.new(state, order, decide)
	var before: int = state.combat_state_version

	# Act
	var result: Dictionary = loop.run(1)

	# Assert
	assert_bool(bool(result["aborted"])).is_true()
	assert_str(String(result["abort_reason"])).is_equal("max_rounds_reached")
	assert_int(order.round_number()).is_equal(2)
	assert_int(state.combat_state_version).is_equal(before + 4)


# ---- 4l: 巢狀提交 —— 外層 commit_authoritative_change() 內再開一次 ---------

func test_4l_nested_commit_increments_version_once_inner_window_stays_open_until_outer_closes() -> void:
	# Arrange — 直接對 BattleState.commit_authoritative_change() 白箱佈置巢狀
	# 呼叫,不透過 BattleController:這是驗證 ADR-0001 表格 4l 三項斷言最直接
	# 的方式,三項斷言都只能在巢狀呼叫「進行中」的當下量到(呼叫全部結束、
	# 控制權還給測試之後,GDScript 單執行緒、同步呼叫鏈已經沒有任何中間狀態
	# 可觀察了)。probe 用 Dictionary 承接,原因同本檔其餘測試與既有先例——
	# lambda 對區域變數是傳值捕捉,bool 區域變數在 lambda 內賦值傳不出來。
	var bundle: Dictionary = _build(
		["1,P1,PLAYER,20,10,0,0,1,1,0,0", "2,E1,ENEMY,20,5,0,0,1,1,1,0"], [1], [2]
	)
	var state: BattleState = bundle["state"]
	var before: int = state.combat_state_version
	var probe: Dictionary = {}

	# Act
	state.commit_authoritative_change(func() -> void:
		state.commit_authoritative_change(func() -> void:
			pass
		)
		probe["window_open_after_inner_closes"] = state.write_window_is_open()
	)
	probe["window_open_after_outer_closes"] = state.write_window_is_open()

	# Assert — 恰好 +1(不是 +2);內層結束後窗口仍開;外層結束後窗口才關閉
	assert_int(state.combat_state_version).is_equal(before + 1)
	assert_bool(bool(probe["window_open_after_inner_closes"])).is_true()
	assert_bool(bool(probe["window_open_after_outer_closes"])).is_false()


func test_4l_nested_commit_via_real_apply_attack_and_resolve_attack_increments_version_by_exactly_one() -> void:
	# Arrange — ADR-0001 原文 4l 點名的實際例子:_apply_attack()(外層)呼叫
	# resolve_attack()(內層自己也開一次 commit_authoritative_change())。
	# 這裡用生產程式碼的真實呼叫鏈(click_tile())複驗同一條規則,而非只信任
	# 上一條對底層機制的直接測試 —— 兩者互補:上一條證明機制本身正確,這一條
	# 證明生產程式碼真的走上了這個機制(_apply_attack -> resolve_attack 確實
	# 構成巢狀,不是各自獨立)。敵方 DEF=0、玩家 ATK=10、敵方 HP=20,一擊不死
	# (10 傷害 < 20 HP),避免死亡清除佔位的額外寫入路徑混進本測試的計次。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,20,0,0,0,1,1,1,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	assert_bool(controller.select_unit(1)).is_true()
	var before: int = state.combat_state_version

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert
	assert_str(String(result["action"])).is_equal("attacked")
	assert_bool(bool(result["target_died"])).is_false()
	assert_int(state.combat_state_version).is_equal(before + 1)


# ---- story-003d: 敏感度證明 —— 證明上方六條版本遞增測試的斷言真的會抓到對應 ---
# ---- 缺陷,而不是巧合綠燈(.claude/rules/test-standards.md「敏感度證明的 -------
# ---- 完成門檻」節,2026-09-16 管理者裁決)。間諜/突變子類別手法,不使用手動 -----
# ---- 注入(改壞 -> 跑 -> 改回)—— 後者已於同節淘汰,理由是它在版本庫裡不留 -----
# ---- 任何痕跡。 ------------------------------------------------------------
#
# 三個突變子類別對應兩種不同的缺陷形狀:
#   _MutantSkipsVersionIncrement —— 深度計數器本身正確運作(守衛檢查不受影響),
#     但永遠不遞增 _combat_state_version。涵蓋「忘記遞增」這一類缺陷,用於 4e、
#     4f、4j(單次或整批、非巢狀觀點的遞增量)。
#   _MutantIncrementsVersionOnEveryNestedCommit —— 深度計數器本身正確運作,但
#     每一次 commit_authoritative_change() 呼叫都無條件遞增,不論巢狀深度是否
#     真的回到 0。這正是 ADR-0001「第二次修訂」文件明文點名、boolean 版本必然
#     撞上的那一類缺陷(巢狀內層多算),用於兩條 4l。
#   _MutantControllerTreatsSelectionAsCommit —— 選取/取消選取被誤當成權威寫入,
#     用於 4i(4i 的機制不是 commit_authoritative_change() 本身的缺陷,而是
#     select_unit()/deselect() 不該呼叫它卻呼叫了)。

class _MutantSkipsVersionIncrement extends BattleState:
	func commit_authoritative_change(mutator: Callable) -> void:
		_authoritative_write_depth += 1
		mutator.call()
		_authoritative_write_depth -= 1
		# BUG(刻意植入):深度計數器正確增減,守衛判定不受影響,但
		# _combat_state_version 永遠不遞增。


class _MutantIncrementsVersionOnEveryNestedCommit extends BattleState:
	func commit_authoritative_change(mutator: Callable) -> void:
		_authoritative_write_depth += 1
		mutator.call()
		_authoritative_write_depth -= 1
		# BUG(刻意植入):不論巢狀深度是否真的歸零,每次呼叫都遞增 —— 正是
		# ADR-0001「第二次修訂」文件推導「為什麼不能是布林」時點名的那一類缺陷。
		_combat_state_version += 1


class _MutantControllerTreatsSelectionAsCommit extends BattleController:
	func select_unit(id: int) -> bool:
		var result: bool = super.select_unit(id)
		if result:
			_state.commit_authoritative_change(func() -> void:
				pass
			)
		return result


# 共用於下方多條敏感度證明:重建 BattleState.create() 自己的本體(與
# src/gameplay/battle/battle_state.gd 核對一致),但作用在一個已經 .new() 出來
# 的突變子類別實例上 —— 因為 create() 是靜態工廠,內部硬寫死 BattleState.new(),
# 永遠回傳基底類別,不會回傳子類別。同一手法已見於
# battle_controller_finalize_enemy_phase_turn_start_commit_test.gd 的
# _create_spy_state()。
func _populate_mutant_state(mutant_state: BattleState, roster_lines: Array[String]) -> void:
	mutant_state.board = Board.from_ascii(PackedStringArray())
	var roster: Array[Unit] = Unit.roster_from_text("\n".join(roster_lines))
	for unit: Unit in roster:
		mutant_state._units[unit.id] = unit
		mutant_state._positions[unit.id] = unit.start_pos
		mutant_state.board._set_occupant(unit.start_pos, unit.id)
	mutant_state.board.attach_write_guard(Callable(mutant_state, "write_window_is_open"))
	for unit: Unit in roster:
		unit.attach_write_guard(Callable(mutant_state, "write_window_is_open"))


# ---- 4e 的敏感度證明 ---------------------------------------------------------

func test_sensitivity_proof_4e_version_increment_test_catches_a_mutant_that_skips_it() -> void:
	# Arrange — 與 test_4e_player_end_unit_turn_... 相同的名冊/場景,state 換成
	# _MutantSkipsVersionIncrement。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var mutant_state: _MutantSkipsVersionIncrement = _MutantSkipsVersionIncrement.new()
	_populate_mutant_state(mutant_state, roster)
	var order: TurnOrder = TurnOrder.new([1], [2])
	var controller: BattleController = BattleController.new(mutant_state, order)
	assert_bool(controller.select_unit(1)).is_true()
	var before: int = mutant_state.combat_state_version

	# Act
	var ended: bool = controller.end_unit_turn(1)

	# Assert — 與真正版本相反:寫入確實成功(守衛未擋下),但版本沒有遞增
	assert_bool(ended).is_true()
	assert_bool(order.is_done(1)).is_true()
	assert_int(mutant_state.combat_state_version).is_equal(before)


# ---- 4f 的敏感度證明 ---------------------------------------------------------

func test_sensitivity_proof_4f_version_increment_test_catches_a_mutant_that_skips_it() -> void:
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var mutant_state: _MutantSkipsVersionIncrement = _MutantSkipsVersionIncrement.new()
	_populate_mutant_state(mutant_state, roster)
	var order: TurnOrder = TurnOrder.new([1], [2])
	var controller: BattleController = BattleController.new(mutant_state, order)
	var before: int = mutant_state.combat_state_version

	# Act
	controller.end_faction_phase()

	# Assert
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	assert_int(mutant_state.combat_state_version).is_equal(before)


# ---- 4i 的敏感度證明 ---------------------------------------------------------

func test_sensitivity_proof_4i_selection_unchanged_test_catches_a_mutant_that_commits_on_select() -> void:
	# Arrange — 這裡的缺陷不在 commit_authoritative_change() 本身,而在
	# select_unit() 誤呼叫了它,所以用真正的 BattleState,突變的是 controller。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var mutant: _MutantControllerTreatsSelectionAsCommit = (
		_MutantControllerTreatsSelectionAsCommit.new(state, order)
	)
	var before: int = state.combat_state_version

	# Act
	assert_bool(mutant.select_unit(1)).is_true()

	# Assert — 與真正版本相反:選取這個動作讓版本動了
	assert_int(state.combat_state_version).is_not_equal(before)


# ---- 4j 的敏感度證明 ---------------------------------------------------------

func test_sensitivity_proof_4j_battle_loop_version_test_catches_a_mutant_that_skips_increment() -> void:
	# Arrange — 與 test_4j_battle_loop_driven_round_... 相同的名冊/decide/場景,
	# state 換成 _MutantSkipsVersionIncrement。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,0,100,0,1,1,0,0",
		"2,E1,ENEMY,20,5,0,0,1,1,1,0",
		"3,E2,ENEMY,20,5,0,0,1,1,0,1",
	]
	var mutant_state: _MutantSkipsVersionIncrement = _MutantSkipsVersionIncrement.new()
	_populate_mutant_state(mutant_state, roster)
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var decide: Callable = func(
		s: BattleState, unit_id: int, _can_move: bool, can_attack: bool
	) -> Dictionary:
		var unit: Unit = s.unit_by_id(unit_id)
		if unit.faction == Unit.Faction.ENEMY and can_attack:
			return {"move_to": null, "attack": 1}
		return {"move_to": null, "attack": -1}
	var loop: BattleLoop = BattleLoop.new(mutant_state, order, decide)
	var before: int = mutant_state.combat_state_version

	# Act
	var result: Dictionary = loop.run(1)

	# Assert — 與真正版本相反:整回合跑完(4 次成功的 commit 呼叫),版本卻
	# 完全沒動
	assert_bool(bool(result["aborted"])).is_true()
	assert_int(order.round_number()).is_equal(2)
	assert_int(mutant_state.combat_state_version).is_equal(before)


# ---- 4l(白箱直測)的敏感度證明 -----------------------------------------------

func test_sensitivity_proof_4l_nested_direct_test_catches_a_mutant_that_double_counts() -> void:
	# Arrange — 與 test_4l_nested_commit_increments_version_once_... 一樣,這個
	# 場景完全不碰 board/unit,裸的突變實例即可。
	var mutant_state: _MutantIncrementsVersionOnEveryNestedCommit = (
		_MutantIncrementsVersionOnEveryNestedCommit.new()
	)
	var before: int = mutant_state.combat_state_version

	# Act
	mutant_state.commit_authoritative_change(func() -> void:
		mutant_state.commit_authoritative_change(func() -> void:
			pass
		)
	)

	# Assert — 與真正版本相反:+2,不是 +1
	assert_int(mutant_state.combat_state_version).is_equal(before + 2)


# ---- 4l(經真實 click_tile() 呼叫鏈)的敏感度證明 ------------------------------

func test_sensitivity_proof_4l_nested_real_code_path_test_catches_a_mutant_that_double_counts() -> void:
	# Arrange — 與 test_4l_nested_commit_via_real_apply_attack_and_resolve_
	# attack_... 相同的名冊/場景,state 換成
	# _MutantIncrementsVersionOnEveryNestedCommit:_apply_attack()(外層)呼叫
	# resolve_attack()(內層)構成的巢狀,在這個突變下應該各自遞增一次。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,10,0,0,1,1,0,0",
		"2,E1,ENEMY,20,0,0,0,1,1,1,0",
	]
	var mutant_state: _MutantIncrementsVersionOnEveryNestedCommit = (
		_MutantIncrementsVersionOnEveryNestedCommit.new()
	)
	_populate_mutant_state(mutant_state, roster)
	var order: TurnOrder = TurnOrder.new([1], [2])
	var controller: BattleController = BattleController.new(mutant_state, order)
	assert_bool(controller.select_unit(1)).is_true()
	var before: int = mutant_state.combat_state_version

	# Act
	var result: Dictionary = controller.click_tile(Vector2i(1, 0))

	# Assert — 與真正版本相反:外層 + 內層各自遞增,+2 不是 +1
	assert_str(String(result["action"])).is_equal("attacked")
	assert_bool(bool(result["target_died"])).is_false()
	assert_int(mutant_state.combat_state_version).is_equal(before + 2)


# ---- story-003b AC11 的兩條專屬驗收向量(story-003b 收尾時未寫,移入本 story)-
# ---- 出處:story-003b 的 QA Test Cases 節。step_enemy_phase() 是正式遊戲 -------
# ---- 唯一在用的生產路徑(battle_screen.gd),run_enemy_phase() 是整批路徑 -----
# ---- (測試/未來驅動器用)—— 兩條都要驗,只驗一條會讓另一條的繞過不可觀測。 ---

func test_ac11_step_enemy_phase_standalone_finalize_call_increments_version_by_exactly_one() -> void:
	# Arrange — 一個被動敵人(hp=100/atk=0/def=100/mp=0,位置遠在攻擊範圍外),
	# 與 battle_controller_step_enemy_phase_test.gd 的 _idle_two_enemy_roster()
	# 同款手法:恰好兩次 step_enemy_phase() 呼叫即可推進到收尾 —— 第一次推進該
	# 敵人(它自己的 commit,+1),第二次 _next_enemy_step_id() 回傳 -1、
	# 獨立觸發 _finalize_enemy_phase()(本測試的量測對象)。
	var roster: Array[String] = [
		"1,P1,PLAYER,100,0,100,0,1,1,0,0",
		"2,E1,ENEMY,100,0,100,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	var first: Dictionary = controller.step_enemy_phase()
	assert_bool(bool(first["has_next"])).is_false()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	var before: int = state.combat_state_version

	# Act — 這次呼叫只做收尾:_next_enemy_step_id() 回傳 -1 -> _finalize_enemy_phase()
	var second: Dictionary = controller.step_enemy_phase()

	# Assert
	assert_array(second["log"]).is_empty()
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(state.combat_state_version).is_equal(before + 1)


func test_ac11_run_enemy_phase_nested_finalize_commit_converges_to_exactly_one_total() -> void:
	# Arrange — 同一份被動敵人名冊,這次整批 run_enemy_phase() 一次跑完:外層
	# commit 開啟窗口,單一單位的動作與 _finalize_enemy_phase() 自己的 commit
	# 皆巢狀在這個已開啟的窗口內 —— 驗證兩層巢狀收斂成恰好 +1,不是逐層各自 +1
	# 的錯誤實作(+2 或更多)。
	var roster: Array[String] = [
		"1,P1,PLAYER,100,0,100,0,1,1,0,0",
		"2,E1,ENEMY,100,0,100,0,1,1,12,5",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var state: BattleState = bundle["state"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()
	var before: int = state.combat_state_version

	# Act
	var log: Array[String] = controller.run_enemy_phase()

	# Assert
	assert_bool(log.is_empty()).is_false()
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(state.combat_state_version).is_equal(before + 1)
