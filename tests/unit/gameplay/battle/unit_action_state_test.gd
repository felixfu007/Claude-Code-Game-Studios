# TurnOrder.unit_action_state() / BattleController.unit_action_state() 的單元測試。
#
# 對應 production/epics/tactical-combat/story-004-unit-action-four-state-getter.md。
# 驗證重點（工作單 Acceptance Criteria 逐條）：
#   1. 四態（皆未用／只剩攻擊／只剩移動／已行動）各自正確回傳。
#   2. 查詢不受 _is_actionable() 的陣營/回合閘門影響 —— 非當前回合陣營的單位，
#      仍必須回傳其真實旗標狀態，不得被陣營閘門攔成與「已行動」同值的假訊號。
#      這是 M1 查證指出的現況缺口的直接回歸測試。
#   3. 陣亡/不存在的單位，查詢結果必須與「已行動」可區分。
#   4. BattleController 的公開轉發方法與直接查詢 TurnOrder 結果一致，
#      且不需要任何前置選取（不必先呼叫 select_unit()）。
#
# 純狀態機、無節點 —— 不建立任何 Node，也不需要 tear-down，不會留下孤兒節點。
# 命名慣例沿用既有先例 tests/unit/gameplay/battle/turn_order_test.gd 的
# test_[scenario]_[expected]。BattleController 夾具建法沿用
# tests/unit/gameplay/battle/battle_controller_test.gd 的 roster CSV 格式
# （"id,code_name,FACTION,...units.gd 其餘數值欄位"）。
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# 間諜子類別：複製「忘記繞過 _is_actionable()」這個錯誤實作的形狀，用於下方
# test_sensitivity_proof_faction_gate_bypass_is_detected()。
#
# 這不是對 TurnOrder.unit_action_state() 本身的覆寫（正式實作不呼叫
# _is_actionable()，沒有東西可攔截）——而是在子類別新增一個方法，重現「誤用
# can_move()/can_attack() 的陣營閘門」這個植入缺陷，藉此證明
# test_unit_action_state_non_current_faction_unit_still_reports_real_flags()
# 真的會對這種錯誤實作敏感，而不是兩者剛好同值。
class _BuggyTurnOrderReusingGate extends TurnOrder:
	func _init(player_ids: Array[int], enemy_ids: Array[int]) -> void:
		super._init(player_ids, enemy_ids)

	# 錯誤實作：複用 can_move()/can_attack()，兩者都經過 _is_actionable()
	# 的陣營/回合閘門——這正是 M1 查證指出的現況缺口，也是本 story 明文禁止
	# 的寫法（工作單 Implementation Notes 第 2 點）。
	func buggy_unit_action_state(id: int) -> TurnOrder.ActionState:
		var move_ok: bool = can_move(id)
		var attack_ok: bool = can_attack(id)
		if not move_ok and not attack_ok:
			return TurnOrder.ActionState.DONE
		if not move_ok:
			return TurnOrder.ActionState.ATTACK_ONLY
		if not attack_ok:
			return TurnOrder.ActionState.MOVE_ONLY
		return TurnOrder.ActionState.NONE_USED


# ---------------------------------------------------------------------------
# 1. 四態各自正確回傳
# ---------------------------------------------------------------------------

func test_unit_action_state_both_flags_unused_returns_none_used() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act / Assert
	assert_int(turn_order.unit_action_state(1)).is_equal(TurnOrder.ActionState.NONE_USED)


func test_unit_action_state_move_used_only_returns_attack_only() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.use_move(1)

	# Assert
	assert_int(turn_order.unit_action_state(1)).is_equal(TurnOrder.ActionState.ATTACK_ONLY)


func test_unit_action_state_attack_used_only_returns_move_only() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.use_attack(1)

	# Assert
	assert_int(turn_order.unit_action_state(1)).is_equal(TurnOrder.ActionState.MOVE_ONLY)


func test_unit_action_state_both_flags_used_returns_done() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act
	turn_order.use_move(1)
	turn_order.use_attack(1)

	# Assert
	assert_int(turn_order.unit_action_state(1)).is_equal(TurnOrder.ActionState.DONE)


# 額外補充（非 AC 明文要求，但驗證本實作文件記載的「_done 優先於旗標組合」
# 設計決定）：顯式 end_unit_turn() 即使只花了一個旗標，仍須回傳 DONE，
# 不得回傳 ATTACK_ONLY/MOVE_ONLY。
func test_unit_action_state_explicitly_ended_with_one_flag_spent_still_returns_done() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])
	turn_order.use_move(1)

	# Act
	turn_order.end_unit_turn(1)

	# Assert
	assert_int(turn_order.unit_action_state(1)).is_equal(TurnOrder.ActionState.DONE)


# ---------------------------------------------------------------------------
# 2. 不受陣營/回合閘門影響（M1 缺口回歸測試）
# ---------------------------------------------------------------------------

func test_unit_action_state_non_current_faction_unit_still_reports_real_flags() -> void:
	# Arrange — TurnOrder 建構後當前陣營預設為 PLAYER（見 current_faction()
	# 文件註解），單位 10 屬於 ENEMY，因此是「非當前回合陣營的單位」。
	#
	# 這個狀態（非當前陣營 + 旗標已用）無法透過公開 API 自然產生：
	# use_move()/use_attack() 本身就受 _is_actionable() 的陣營閘門擋下，只有
	# 當前陣營的單位能花旗標；而 advance_faction() 在交棒時永遠把「剛結束
	# 那一方」的旗標整批重置回未用（見 TurnOrder.advance_faction() 文件註解
	# 「Reset is a faction-boundary rule」）。所以在正常流程下，任何時刻
	# 非當前陣營的單位旗標必定是乾淨的——這正是本測試要繞過的那個正常流程，
	# 直接改寫底層 Dictionary 來重現「旗標已用、但不是當前陣營」這個邊界，
	# 驗證 unit_action_state() 不會像 can_move()/can_attack() 一樣被
	# _is_actionable() 的陣營檢查蓋住真實旗標值。
	var turn_order: TurnOrder = TurnOrder.new([1], [10])
	turn_order._move_used[10] = true

	# Act / Assert
	assert_int(turn_order.current_faction()).is_equal(TurnOrder.Side.PLAYER)
	assert_int(turn_order.unit_action_state(10)).is_equal(TurnOrder.ActionState.ATTACK_ONLY)
	assert_int(turn_order.unit_action_state(10)).is_not_equal(TurnOrder.ActionState.DONE)


## 敏感度證明：證明上面那條回歸測試真的會抓到「誤用 can_move()/can_attack()
## 陣營閘門」這個植入缺陷，而不是兩種實作剛好同值。
func test_sensitivity_proof_faction_gate_bypass_is_detected() -> void:
	# Arrange — 與上面那條回歸測試完全相同的狀態佈置，只是改用會重現錯誤
	# 實作形狀的間諜子類別。
	var spy: _BuggyTurnOrderReusingGate = _BuggyTurnOrderReusingGate.new([1], [10])
	spy._move_used[10] = true

	# Act
	var buggy_result: TurnOrder.ActionState = spy.buggy_unit_action_state(10)

	# Assert — 錯誤實作裡 can_move(10)/can_attack(10) 都因 10 不屬於當前
	# 陣營（PLAYER）而被 _is_actionable() 擋成 false，兩者皆 false 的分支
	# 回傳 DONE——這正是上面那條回歸測試斷言「不得等於 DONE」的假訊號，
	# 也與它期望的 ATTACK_ONLY 不同，證明該測試對這個植入缺陷敏感。
	assert_int(buggy_result).is_equal(TurnOrder.ActionState.DONE)
	assert_int(buggy_result).is_not_equal(TurnOrder.ActionState.ATTACK_ONLY)


# ---------------------------------------------------------------------------
# 3. 陣亡/不存在單位可與「已行動」區分
# ---------------------------------------------------------------------------

func test_unit_action_state_unknown_id_is_distinguishable_from_done() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act / Assert — 999 從未註冊過
	assert_int(turn_order.unit_action_state(999)).is_equal(TurnOrder.ActionState.NOT_FOUND)
	assert_int(turn_order.unit_action_state(999)).is_not_equal(TurnOrder.ActionState.DONE)


func test_unit_action_state_removed_unit_is_distinguishable_from_done() -> void:
	# Arrange
	var turn_order: TurnOrder = TurnOrder.new([1], [10])

	# Act — remove_unit() 模擬陣亡
	turn_order.remove_unit(1)

	# Assert
	assert_int(turn_order.unit_action_state(1)).is_equal(TurnOrder.ActionState.NOT_FOUND)
	assert_int(turn_order.unit_action_state(1)).is_not_equal(TurnOrder.ActionState.DONE)


# ---------------------------------------------------------------------------
# 4. BattleController 公開轉發
# ---------------------------------------------------------------------------

func test_battle_controller_unit_action_state_matches_turn_order_without_selection() -> void:
	# Arrange — 最小名冊 + 全開闊地，沿用 battle_controller_test.gd 既有慣例
	# （PackedStringArray() 空地形、roster CSV 欄位格式）。
	var roster: Array[String] = [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,10,0",
	]
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster))
	var order: TurnOrder = TurnOrder.new([1], [2])
	var controller: BattleController = BattleController.new(state, order)

	# Act — 不呼叫 select_unit()，直接讓單位 1 花掉移動旗標再查詢。
	# BattleController 建構時已透過 BattleState.attach_turn_order() 對 order
	# 掛上 ADR-0001 的寫入守衛，直接呼叫 order.use_move() 會被守衛拒絕
	# （"write window is not open"）——必須包在 commit_authoritative_change()
	# 開啟的寫入窗口內，與 battle_controller.gd 自己的 _apply_move() 同寫法。
	state.commit_authoritative_change(func() -> void:
		order.use_move(1)
	)

	# Assert — 轉發結果與直接查詢同一個 TurnOrder 實例一致，且全程未選取
	# 任何單位（selected_unit() 維持 -1）。
	assert_int(controller.unit_action_state(1)).is_equal(order.unit_action_state(1))
	assert_int(controller.unit_action_state(1)).is_equal(TurnOrder.ActionState.ATTACK_ONLY)
	assert_int(controller.selected_unit()).is_equal(-1)
