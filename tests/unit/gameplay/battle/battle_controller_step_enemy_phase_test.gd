# BattleController 的「敵方階段逐步演出」入口(step_enemy_phase())測試。
# story-018-enemy-phase-stepped-playback.md AC-E1 / AC-E2。
#
# 命名慣例、_build() 手法沿用 battle_controller_test.gd —— 刻意不共用同一支
# _build(),兩支測試檔各自獨立、互不相依是既有慣例(見該檔檔頭)。
#
# 不建立任何 Node —— 全鏈路(BattleController/BattleState/TurnOrder/Board/Unit/
# GreedyTacticalAI)皆為 RefCounted 或 static,不會留下孤兒節點。
#
# 🔴 本檔案 I/O 使用揭露(.claude/rules/test-standards.md「單元測試不得碰檔案系統」
# 節,2026-09-16 管理者裁決的甲/乙兩類明文例外):
#
#   乙類(掃 src/**/*.gd 原始碼文字,斷言原始碼紀律)——
#   test_step_enemy_phase_call_chain_has_no_yield_point() 讀 battle_controller.gd
#   的原始碼文字,擷取 step_enemy_phase() / _next_enemy_step_id() /
#   _finalize_enemy_phase() 三個函式本體,斷言裡面沒有 await / call_deferred( /
#   CONNECT_DEFERRED 這三種字面文字 —— 這是 AC-E1 的替代證據(ADR-0001 的
#   authoritative_write_in_progress 旗標在 src/ 裡零實作,見該測試自己的完整
#   說明)。🔴 自陳範圍不窮盡:本掃描只看這三個函式「自己的」原始碼文字,看不到
#   它們呼叫的其他函式(_process_enemy_unit 等)內部是否引入 deferred 路徑、看不到
#   反射呼叫,也無法證明「日後不會有人加一個 await 進來又忘記更新這支測試要掃的
#   函式清單」——它只保證「今天,這三個函式自己的本體裡沒有這三種字面文字」。
#
# 🔴 敏感度證明索引(.claude/rules/test-standards.md「敏感度證明的完成門檻」節,
# 2026-09-16 管理者裁決):本檔每一條斷「新行為」的測試都配一條
# test_sensitivity_proof_* —— 用突變子類別模擬一種具體會被上面斷言擋下的錯誤
# 實作,證明斷言真的會抓,而不是巧合綠燈。唯一已知例外,明文標註而非默默略過:
# _next_enemy_step_id() 裡的 is_done() 防衛分支,沒有任何測試斷言它被走到過
# —— 未涵蓋,不強行造假涵蓋。
#
# 🔴 2026-09-17 更正理由(獨立覆核的探針推翻了原本寫的理由):
# 本行原寫該分支「目前不可達」。**那是假的**,而且錯得有後果 ——
# 「不可達」正是當初決定不測它的理由。
# 實測 prototypes/step-enemy-phase-removal-parity-probe-2026-09-17/
# (Godot 4.7.1 headless,exit 0)當場走到了這個分支:任何呼叫
# TurnOrder.remove_unit() 的機制,都能讓一個仍活著的 _enemy_step_snapshot
# 裡尚未走訪的 id 失效。
#
# 真正為真、而原措辭講過頭的那件較窄的事實是:**戰鬥結算走不到它** ——
# BattleState.can_attack() 無條件拒絕同陣營目標,而那道檢查正是本專案
# remove_unit() 唯一正式呼叫點的前提。探針是繞過結算直接呼叫才觸發的。
#
# 行為本身兩條路徑一致(探針逐項比對 log / phase / round / is_done / HP / 座標
# 全部相等)。**缺口仍然是真的,但當初給的理由不是。**
extends GdUnitTestSuite


# ---- 突變子類別(僅供下方 test_sensitivity_proof_* 使用,不修改 battle_
# controller.gd 本體) ----------------------------------------------------------

# 模擬「一次呼叫偷跑兩個單位」:第一次呼叫真正的 step_enemy_phase() 之後,若
# 階段仍在進行、且回報「還有下一個」,就不聲張地再呼叫一次並把兩次的 log 併起來
# 當成一次回傳 —— 從外部呼叫端的角度看起來只呼叫了一次。
class _MutantAdvancesTwoUnitsPerCall extends BattleController:
	func step_enemy_phase() -> Dictionary:
		var first: Dictionary = super.step_enemy_phase()
		var combined_log: Array[String] = first["log"]
		var combined_has_next: bool = first["has_next"]
		if _phase == Phase.ENEMY_ACTING and combined_has_next:
			var second: Dictionary = super.step_enemy_phase()
			var second_log: Array[String] = second["log"]
			combined_log.append_array(second_log)
			combined_has_next = second["has_next"]
		return {"log": combined_log, "has_next": combined_has_next}


# 模擬「完全略過 ENEMY_ACTING 相位檢查」:不檢查 _phase 就直接推進下一個單位。
class _MutantIgnoresEnemyActingGuard extends BattleController:
	func step_enemy_phase() -> Dictionary:
		var log: Array[String] = []
		var id: int = _next_enemy_step_id()
		if id == -1:
			return {"log": log, "has_next": false}
		_process_enemy_unit(id, log)
		return {"log": log, "has_next": true}


# 模擬「只要推進過一個單位就收尾,不管還有沒有下一個」。
class _MutantFinalizesAfterFirstUnit extends BattleController:
	var _already_advanced_once: bool = false

	func step_enemy_phase() -> Dictionary:
		if _already_advanced_once and _phase == Phase.ENEMY_ACTING:
			_finalize_enemy_phase()
			return {"log": [], "has_next": false}
		var result: Dictionary = super.step_enemy_phase()
		if _phase == Phase.ENEMY_ACTING:
			_already_advanced_once = true
		return result


# 模擬「逐步入口與 run_enemy_phase() 對同一份快照選了不同處理順序」:每次重新
# 取快照後立刻反向排列。刻意複製 _next_enemy_step_id() 的殼而不是呼叫 super,
# 因為要改的正是「先處理誰」這件事本身,包出去呼叫 super 改不到這一點。
class _MutantReversesEnemyProcessingOrder extends BattleController:
	# Same flat while-with-break shape as the fixed _next_enemy_step_id() in
	# battle_controller.gd (see that method's doc comment for why the nested
	# while-inside-while-true form does not compile) — only the reversal line
	# is new.
	func _next_enemy_step_id() -> int:
		var result: int = -1
		while true:
			if _enemy_step_index >= _enemy_step_snapshot.size():
				_enemy_step_snapshot = _order.units_with_flags_remaining()
				_enemy_step_snapshot.reverse()
				_enemy_step_index = 0
				if _enemy_step_snapshot.is_empty():
					break
			var candidate: int = _enemy_step_snapshot[_enemy_step_index]
			_enemy_step_index += 1
			if not _order.is_done(candidate):
				result = candidate
				break
		return result


# ---- fixtures ----------------------------------------------------------------

func _build(
	roster_lines: Array[String],
	player_ids: Array[int],
	enemy_ids: Array[int],
	phi_provider: Callable = Callable(),
	decide: Callable = Callable()
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	var controller: BattleController = BattleController.new(state, order, phi_provider, decide)
	return {"state": state, "order": order, "controller": controller}


# 兩個被動敵人(mp=0、射程互不可及):每個敵人被推進時唯一會發生的事是「什麼都
# 不做,結束回合」——把焦點放在「推進了幾個單位、階段何時收尾」本身,而不是戰鬥
# 細節。與既有 test_run_enemy_phase_returns_to_player_phase_with_flags_reset()
# 同款手法,只是敵人數從 1 改成 2。
func _idle_two_enemy_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,100,0,100,0,1,1,0,0",
		"2,E1,ENEMY,100,0,100,0,1,1,12,5",
		"3,E2,ENEMY,100,0,100,0,1,1,12,4",
	]


# 兩個敵人各自固定移動目的地,mp=1:單位 2 想搬進單位 3 目前站的格子,單位 3
# 想搬進一個原本空的格子。誰先動決定誰搬得成——這是「處理順序」測試要的場景,
# 完全不依賴 GreedyTacticalAI 的實際決策細節。
func _order_sensitive_two_enemy_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,999,0,999,0,1,1,10,5",
		"2,E1,ENEMY,100,0,100,1,1,1,0,0",
		"3,E2,ENEMY,100,0,100,1,1,1,1,0",
	]


func _fixed_swap_decide() -> Callable:
	var target_by_id: Dictionary = {2: Vector2i(1, 0), 3: Vector2i(2, 0)}
	return func(
		_decide_state: BattleState, unit_id: int, can_move: bool, _can_attack: bool
	) -> Dictionary:
		if can_move and target_by_id.has(unit_id):
			return {"move_to": target_by_id[unit_id], "attack": -1}
		return {"move_to": null, "attack": -1}


# ---- AC-E1: 一次呼叫恰好推進一個敵方單位 --------------------------------------

func test_step_enemy_phase_advances_exactly_one_unit_per_call() -> void:
	# Arrange
	var bundle: Dictionary = _build(_idle_two_enemy_roster(), [1], [2, 3])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)

	# Act
	var step1: Dictionary = controller.step_enemy_phase()

	# Assert — 恰好推進單位 2(依 TurnOrder 建構順序),單位 3 仍未動
	assert_bool(order.is_done(2)).is_true()
	assert_bool(order.is_done(3)).is_false()
	assert_bool(step1["has_next"]).is_true()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	var log1: Array[String] = step1["log"]
	assert_bool(log1.is_empty()).is_false()


# 敏感度證明——用「一次呼叫偷跑兩個單位」的間諜子類別證明上面那條測試的斷言
# (單位 3 一次呼叫後仍未完成)真的會抓到這類缺陷。
func test_sensitivity_proof_one_unit_per_call_test_catches_a_mutant_that_advances_two() -> void:
	# Arrange — 名冊與上面那條測試相同,控制器換成間諜子類別
	var roster: Array[String] = _idle_two_enemy_roster()
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var mutant: _MutantAdvancesTwoUnitsPerCall = _MutantAdvancesTwoUnitsPerCall.new(state, order)
	mutant.end_faction_phase()

	# Act
	mutant.step_enemy_phase()

	# Assert — 與真正版本相反:兩個敵人都已推進完
	assert_bool(order.is_done(2)).is_true()
	assert_bool(order.is_done(3)).is_true()


func test_step_enemy_phase_second_call_advances_the_remaining_unit() -> void:
	# Arrange
	var bundle: Dictionary = _build(_idle_two_enemy_roster(), [1], [2, 3])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()
	controller.step_enemy_phase()

	# Act
	var step2: Dictionary = controller.step_enemy_phase()

	# Assert — 兩個敵人都已推進完,has_next 回報 false,但階段尚未終結
	# (終結是下一次呼叫的事,見下面 test_step_enemy_phase_finalizes_phase_on_
	# next_call_after_all_units_done())
	assert_bool(order.is_done(2)).is_true()
	assert_bool(order.is_done(3)).is_true()
	assert_bool(step2["has_next"]).is_false()
	assert_int(controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)


func test_step_enemy_phase_finalizes_phase_on_next_call_after_all_units_done() -> void:
	# Arrange
	var bundle: Dictionary = _build(_idle_two_enemy_roster(), [1], [2, 3])
	var order: TurnOrder = bundle["order"]
	var controller: BattleController = bundle["controller"]
	controller.end_faction_phase()
	controller.step_enemy_phase()
	controller.step_enemy_phase()

	# Act — 第三次呼叫:兩個敵人都已完成,這次呼叫只做收尾
	var step3: Dictionary = controller.step_enemy_phase()

	# Assert
	assert_array(step3["log"]).is_empty()
	assert_bool(step3["has_next"]).is_false()
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(controller.round_number()).is_equal(2)
	assert_bool(order.can_move(1)).is_true()
	assert_bool(order.can_attack(1)).is_true()


# 敏感度證明——用「推進過一個單位就收尾」的間諜子類別,證明上面兩條測試
# (第二次呼叫時單位 3 應完成、階段應直到第三次呼叫才收尾)真的會抓到這類缺陷。
func test_sensitivity_proof_finalize_only_when_empty_test_catches_an_early_finalizer() -> void:
	# Arrange
	var roster: Array[String] = _idle_two_enemy_roster()
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2, 3])
	var mutant: _MutantFinalizesAfterFirstUnit = _MutantFinalizesAfterFirstUnit.new(state, order)
	mutant.end_faction_phase()
	mutant.step_enemy_phase()  # 推進單位 2

	# Act — 第二次呼叫:真正版本應該推進單位 3,間諜版本直接收尾
	var step2: Dictionary = mutant.step_enemy_phase()

	# Assert — 與真正版本的斷言完全相反:單位 3 從未被推進、階段已經(錯誤地)
	# 提前收尾
	assert_bool(order.is_done(3)).is_false()
	assert_int(mutant.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_array(step2["log"]).is_empty()


func test_step_enemy_phase_is_noop_outside_enemy_acting() -> void:
	# Arrange — 尚未呼叫 end_faction_phase(),仍在 PLAYER_INPUT
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var bundle: Dictionary = _build(roster, [1], [2])
	var controller: BattleController = bundle["controller"]

	# Act
	var step: Dictionary = controller.step_enemy_phase()

	# Assert
	assert_array(step["log"]).is_empty()
	assert_bool(step["has_next"]).is_false()
	assert_int(controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)


# 敏感度證明——用「完全略過相位檢查」的間諜子類別,證明上面那條測試(log 應為空)
# 真的會抓到這類缺陷。
func test_sensitivity_proof_phase_guard_test_catches_a_mutant_that_skips_it() -> void:
	# Arrange — 與上面同一份名冊/id,不呼叫 end_faction_phase(),TurnOrder 的
	# current_faction() 仍是 PLAYER —— units_with_flags_remaining() 這時回傳的
	# 其實是玩家單位 1
	var roster: Array[String] = [
		"1,P1,PLAYER,100,0,100,0,1,1,0,0",
		"2,E1,ENEMY,100,0,100,0,1,1,12,5",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var mutant: _MutantIgnoresEnemyActingGuard = _MutantIgnoresEnemyActingGuard.new(state, order)

	# Act
	var step: Dictionary = mutant.step_enemy_phase()

	# Assert — 與真正版本相反:log 不是空的(單位 1 被當成敵人推進了一次)
	var log: Array[String] = step["log"]
	assert_bool(log.is_empty()).is_false()


# ---- AC-E2 / Implementation Note ①③:兩條路徑共用同一份規則 -------------------

func test_step_enemy_phase_matches_run_enemy_phase_for_same_scenario() -> void:
	# Arrange — 兩份完全獨立的 state/order/controller,同一份名冊、同一組 id、
	# 同一個固定 decide:一份走 run_enemy_phase()(既有一次跑完入口),一份走
	# step_enemy_phase() 重複呼叫直到不再是 ENEMY_ACTING —— 直接驗證兩條路徑
	# 是否真的算出同一件事,而不只是相信文件註解的宣稱
	var roster: Array[String] = _order_sensitive_two_enemy_roster()
	var batch_bundle: Dictionary = _build(roster, [1], [2, 3], Callable(), _fixed_swap_decide())
	var stepped_bundle: Dictionary = _build(roster, [1], [2, 3], Callable(), _fixed_swap_decide())

	var batch_controller: BattleController = batch_bundle["controller"]
	var stepped_controller: BattleController = stepped_bundle["controller"]
	batch_controller.end_faction_phase()
	stepped_controller.end_faction_phase()

	# Act
	var batch_log: Array[String] = batch_controller.run_enemy_phase()

	var stepped_log: Array[String] = []
	var guard: int = 0
	while stepped_controller.phase() == BattleController.Phase.ENEMY_ACTING:
		guard += 1
		if guard > 20:
			break
		var step: Dictionary = stepped_controller.step_enemy_phase()
		var step_log: Array[String] = step["log"]
		stepped_log.append_array(step_log)
	assert_int(guard).is_less_equal(20)

	# Assert — log 逐行相同、最終狀態相同
	assert_array(stepped_log).is_equal(batch_log)
	assert_int(stepped_controller.phase()).is_equal(batch_controller.phase())
	assert_int(stepped_controller.round_number()).is_equal(batch_controller.round_number())

	var batch_state: BattleState = batch_bundle["state"]
	var stepped_state: BattleState = stepped_bundle["state"]
	for id: int in [1, 2, 3]:
		assert_int(stepped_state.unit_by_id(id).hp).is_equal(batch_state.unit_by_id(id).hp)
		assert_vector(stepped_state.position_of(id)).is_equal(batch_state.position_of(id))


# 敏感度證明——用「反向處理順序」的間諜子類別,證明上面那條 parity 測試(逐步
# 入口與 run_enemy_phase() 的最終盤面必須相同)真的會抓到「兩條路徑選了不同
# 處理順序」這類缺陷。單位 2 想搬進單位 3 目前站的格子,只有在單位 3 先讓開
# 之後才搬得成——順序反過來,單位 2 的最終位置就會不一樣。
func test_sensitivity_proof_processing_order_test_catches_a_reversed_order_mutant() -> void:
	# Arrange — 一份走「真正」控制器(正向順序),一份走反向順序間諜,名冊、id、
	# decide 完全相同
	var roster: Array[String] = _order_sensitive_two_enemy_roster()
	var real_state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var real_order: TurnOrder = TurnOrder.new([1], [2, 3])
	var real_controller: BattleController = BattleController.new(
		real_state, real_order, Callable(), _fixed_swap_decide()
	)
	real_controller.end_faction_phase()

	var mutant_state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var mutant_order: TurnOrder = TurnOrder.new([1], [2, 3])
	var mutant: _MutantReversesEnemyProcessingOrder = _MutantReversesEnemyProcessingOrder.new(
		mutant_state, mutant_order, Callable(), _fixed_swap_decide()
	)
	mutant.end_faction_phase()

	# Act
	real_controller.run_enemy_phase()
	var guard: int = 0
	while mutant.phase() == BattleController.Phase.ENEMY_ACTING:
		guard += 1
		if guard > 20:
			break
		mutant.step_enemy_phase()
	assert_int(guard).is_less_equal(20)

	# Assert — 與上面 parity 測試的斷言直接相反:順序反過來之後,單位 2 的最終
	# 位置不同
	assert_vector(mutant_state.position_of(2)).is_not_equal(real_state.position_of(2))


# ---- AC-E1 替代證據:呼叫鏈本身沒有讓出點 -------------------------------------

func test_step_enemy_phase_call_chain_has_no_yield_point() -> void:
	# Arrange
	var file: FileAccess = FileAccess.open(
		"res://src/gameplay/battle/battle_controller.gd", FileAccess.READ
	)
	assert_object(file).is_not_null()
	var source: String = file.get_as_text()
	file.close()

	var step_body: String = _extract_function_body(
		source, "func step_enemy_phase() -> Dictionary:"
	)
	var next_id_body: String = _extract_function_body(source, "func _next_enemy_step_id() -> int:")
	var finalize_body: String = _extract_function_body(
		source, "func _finalize_enemy_phase() -> void:"
	)

	# Act / Assert — 三個函式本體都不得出現這三種讓出點的字面文字
	for forbidden: String in ["await ", "call_deferred(", "CONNECT_DEFERRED"]:
		assert_bool(step_body.contains(forbidden)).is_false()
		assert_bool(next_id_body.contains(forbidden)).is_false()
		assert_bool(finalize_body.contains(forbidden)).is_false()


# 敏感度證明——用一段假原始碼(不觸碰真實檔案)證明上面那條掃描邏輯真的能認出
# 一個被注入的 await,而不是巧合通過。
func test_sensitivity_proof_yield_point_scan_catches_an_injected_await() -> void:
	var fake_source: String = (
		"func step_enemy_phase() -> Dictionary:\n"
		+ "\tawait get_tree().process_frame\n"
		+ "\treturn {}\n"
		+ "func _next_enemy_step_id() -> int:\n"
		+ "\treturn -1\n"
	)

	var step_body: String = _extract_function_body(
		fake_source, "func step_enemy_phase() -> Dictionary:"
	)

	assert_bool(step_body.contains("await ")).is_true()


# 從原始碼文字裡切出「從 header 這一行開始，到下一個縮排等於 0 的非空行為止」的
# 區段 —— 只服務上面兩支測試，故不追求泛用；假設 tab 縮排（本專案的 GDScript
# 慣例）。
func _extract_function_body(source: String, header: String) -> String:
	var start: int = source.find(header)
	assert_int(start).is_greater_equal(0)
	var body_start: int = start + header.length()
	var lines: PackedStringArray = source.substr(body_start).split("\n")
	var body_lines: Array[String] = []
	for line: String in lines:
		if line.length() > 0 and not line.begins_with("\t"):
			break
		body_lines.append(line)
	return "\n".join(body_lines)
