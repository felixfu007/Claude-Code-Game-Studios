## Story-003b AC8 — covers ADR-0001 Validation Criteria 4k: 「守衛:寫入窗口
## 未開時,直接呼叫三個零件的任一 mutator → 觸發 push_error() 且目標值不變。
## 每個 mutator 各一條」(docs/architecture/adr-0001-tactical-query-atomicity-
## contract.md,Validation Criteria 表格 — grep `| 4k ` 於該檔可重新定位原文)。
##
## 七個 mutator(story-003b Scope 第 2 項逐字列出):
##   Board._set_occupant / Board._clear_occupant /
##   TurnOrder.use_move / TurnOrder.use_attack / TurnOrder.end_unit_turn /
##   TurnOrder.advance_faction / TurnOrder.remove_unit
##
## 每條測試的共同形狀:建一個「已掛載守衛、寫入窗口未開」的 BattleState(即
## 從未呼叫過 commit_authoritative_change()),直接繞過單一提交入口呼叫
## mutator,斷言 (1) push_error() 被觸發、(2) 目標值真的沒有被改動。
##
## 分檔理由同 commit_authoritative_change_version_test.gd 檔頭:同一套件內
## 任一測試失敗會中止其後全部測試,七個 mutator 各自獨立,不希望其中一個
## 守衛失靈時連帶讓另外六個「看起來」也失敗(其實根本沒跑過)。
##
## 不建立任何 Node —— Board/TurnOrder/BattleState 全是 RefCounted,不會留下
## 孤兒節點。
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

# 建一個已掛載守衛(create()/attach_turn_order() 皆已跑過)、寫入窗口未開的
# BattleState + TurnOrder —— 不呼叫 commit_authoritative_change(),所以
# write_window_is_open() 全程為 false,七個 mutator 的守衛檢查理應全部拒絕。
func _build_guarded_idle(
	roster_lines: Array[String], player_ids: Array[int], enemy_ids: Array[int]
) -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(roster_lines))
	var order: TurnOrder = TurnOrder.new(player_ids, enemy_ids)
	state.attach_turn_order(order)
	return {"state": state, "order": order}


func _roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,5,0,3,1,1,5,5",
	]


# ---- Board._set_occupant ----------------------------------------------------

func test_4k_board_set_occupant_rejected_when_write_window_not_open() -> void:
	# Arrange — (3,3) 目前無人佔據
	var bundle: Dictionary = _build_guarded_idle(_roster(), [1], [2])
	var state: BattleState = bundle["state"]
	var target: Vector2i = Vector2i(3, 3)
	assert_bool(state.board.has_occupant(target)).is_false()

	# Act
	var call_set: Callable = func() -> void:
		state.board._set_occupant(target, 1)

	# Assert
	await assert_error(call_set).is_push_error(any_string())
	assert_bool(state.board.has_occupant(target)).is_false()


# ---- Board._clear_occupant ---------------------------------------------------

func test_4k_board_clear_occupant_rejected_when_write_window_not_open() -> void:
	# Arrange — (0,0) 是單位 1 的出生格,已被佔據
	var bundle: Dictionary = _build_guarded_idle(_roster(), [1], [2])
	var state: BattleState = bundle["state"]
	var origin: Vector2i = Vector2i(0, 0)
	assert_int(state.board.get_occupant(origin)).is_equal(1)

	# Act
	var call_clear: Callable = func() -> void:
		state.board._clear_occupant(origin)

	# Assert
	await assert_error(call_clear).is_push_error(any_string())
	assert_int(state.board.get_occupant(origin)).is_equal(1)


# ---- TurnOrder.use_move ------------------------------------------------------

func test_4k_turn_order_use_move_rejected_when_write_window_not_open() -> void:
	# Arrange
	var bundle: Dictionary = _build_guarded_idle(_roster(), [1], [2])
	var order: TurnOrder = bundle["order"]
	assert_bool(order.can_move(1)).is_true()

	# Act
	var out: Dictionary = {}
	var call_use_move: Callable = func() -> void:
		out["result"] = order.use_move(1)

	# Assert
	await assert_error(call_use_move).is_push_error(any_string())
	assert_bool(bool(out["result"])).is_false()
	assert_bool(order.can_move(1)).is_true()  # 旗標未被消耗,狀態不變


# ---- TurnOrder.use_attack -----------------------------------------------------

func test_4k_turn_order_use_attack_rejected_when_write_window_not_open() -> void:
	# Arrange
	var bundle: Dictionary = _build_guarded_idle(_roster(), [1], [2])
	var order: TurnOrder = bundle["order"]
	assert_bool(order.can_attack(1)).is_true()

	# Act
	var out: Dictionary = {}
	var call_use_attack: Callable = func() -> void:
		out["result"] = order.use_attack(1)

	# Assert
	await assert_error(call_use_attack).is_push_error(any_string())
	assert_bool(bool(out["result"])).is_false()
	assert_bool(order.can_attack(1)).is_true()


# ---- TurnOrder.end_unit_turn --------------------------------------------------

func test_4k_turn_order_end_unit_turn_rejected_when_write_window_not_open() -> void:
	# Arrange
	var bundle: Dictionary = _build_guarded_idle(_roster(), [1], [2])
	var order: TurnOrder = bundle["order"]
	assert_bool(order.is_done(1)).is_false()

	# Act
	var out: Dictionary = {}
	var call_end_unit_turn: Callable = func() -> void:
		out["result"] = order.end_unit_turn(1)

	# Assert
	await assert_error(call_end_unit_turn).is_push_error(any_string())
	assert_bool(bool(out["result"])).is_false()
	assert_bool(order.is_done(1)).is_false()


# ---- TurnOrder.advance_faction ------------------------------------------------

func test_4k_turn_order_advance_faction_rejected_when_write_window_not_open() -> void:
	# Arrange
	var bundle: Dictionary = _build_guarded_idle(_roster(), [1], [2])
	var order: TurnOrder = bundle["order"]
	assert_int(order.current_faction()).is_equal(TurnOrder.Side.PLAYER)
	assert_int(order.round_number()).is_equal(1)

	# Act
	var call_advance: Callable = func() -> void:
		order.advance_faction()

	# Assert
	await assert_error(call_advance).is_push_error(any_string())
	assert_int(order.current_faction()).is_equal(TurnOrder.Side.PLAYER)
	assert_int(order.round_number()).is_equal(1)


# ---- TurnOrder.remove_unit -----------------------------------------------------

func test_4k_turn_order_remove_unit_rejected_when_write_window_not_open() -> void:
	# Arrange — 移除生效的話 is_actionable() 會變 false,can_move()/can_attack()
	# 會連帶變 false;用這兩個查詢做「移除是否真的生效」的證據。
	var bundle: Dictionary = _build_guarded_idle(_roster(), [1], [2])
	var order: TurnOrder = bundle["order"]
	assert_bool(order.can_move(1)).is_true()
	assert_bool(order.can_attack(1)).is_true()

	# Act
	var call_remove: Callable = func() -> void:
		order.remove_unit(1)

	# Assert
	await assert_error(call_remove).is_push_error(any_string())
	assert_bool(order.can_move(1)).is_true()
	assert_bool(order.can_attack(1)).is_true()


# ---- story-003d: 敏感度證明 —— 證明上方七條守衛拒絕測試的斷言真的會抓到「守衛
# ---- 被繞過」這類缺陷,而不是巧合綠燈(.claude/rules/test-standards.md「敏感度
# ---- 證明的完成門檻」節,2026-09-16 管理者裁決)。間諜/突變子類別手法 ——
# ---- 手動注入(把 board.gd/turn_order.gd 的 _write_allowed() 改成一句恆真的
# ---- 短路判斷式,使守衛條件實質失效)在這台機器上已實測走不通(被本機安全
# ---- 分類器以「削弱安全機制」為由拒絕執行後續指令,見 story-003d 文件本身),
# ---- 子類別覆寫不受影響,因為新增的是測試檔裡的子類別,不是削弱產品碼。
#
# 兩個突變子類別,各自覆寫 _write_allowed(),無條件回傳 true —— 完全繞過
# 「寫入窗口是否開啟」這個判斷,不論附掛的 guard callable 實際回報什麼。

class _BoardBypassesWriteGuard extends Board:
	func _write_allowed() -> bool:
		return true


class _TurnOrderBypassesWriteGuard extends TurnOrder:
	func _write_allowed() -> bool:
		return true


# 共用於下方五條 TurnOrder 敏感度證明:建一個已掛載「永遠回報關閉」guard 的
# 突變 TurnOrder —— 與 _build_guarded_idle() 的「guard 已掛載、窗口未開」場景
# 同構,只是這裡的 TurnOrder 本身會無條件繞過這個 guard。
func _mutant_guarded_idle() -> _TurnOrderBypassesWriteGuard:
	var order: _TurnOrderBypassesWriteGuard = _TurnOrderBypassesWriteGuard.new([1], [2])
	order.attach_write_guard(func() -> bool: return false)
	return order


# ---- Board._set_occupant 的敏感度證明 -----------------------------------------

func test_sensitivity_proof_board_set_occupant_guard_test_catches_a_mutant_that_bypasses_it() -> void:
	# Arrange — guard 已掛載且回報關閉(模擬寫入窗口未開),(3,3) 目前無人佔據
	var board: _BoardBypassesWriteGuard = _BoardBypassesWriteGuard.new()
	board.attach_write_guard(func() -> bool: return false)
	var target: Vector2i = Vector2i(3, 3)
	assert_bool(board.has_occupant(target)).is_false()

	# Act
	board._set_occupant(target, 1)

	# Assert — 與真正版本相反:guard 回報關閉,寫入仍然生效
	assert_bool(board.has_occupant(target)).is_true()
	assert_int(board.get_occupant(target)).is_equal(1)


# ---- Board._clear_occupant 的敏感度證明 ---------------------------------------

func test_sensitivity_proof_board_clear_occupant_guard_test_catches_a_mutant_that_bypasses_it() -> void:
	# Arrange — 先佔位(此時 _write_allowed() 本就恆真,佔位本身不是受測對象,
	# 只是佈置前置狀態),再驗證「guard 回報關閉時」_clear_occupant() 是否仍被
	# 不當放行
	var board: _BoardBypassesWriteGuard = _BoardBypassesWriteGuard.new()
	var origin: Vector2i = Vector2i(0, 0)
	board._set_occupant(origin, 1)
	board.attach_write_guard(func() -> bool: return false)
	assert_int(board.get_occupant(origin)).is_equal(1)

	# Act
	board._clear_occupant(origin)

	# Assert — 與真正版本相反:guard 回報關閉,清除仍然生效
	assert_int(board.get_occupant(origin)).is_equal(Board.NO_OCCUPANT)


# ---- TurnOrder.use_move 的敏感度證明 ------------------------------------------

func test_sensitivity_proof_turn_order_use_move_guard_test_catches_a_mutant_that_bypasses_it() -> void:
	var order: _TurnOrderBypassesWriteGuard = _mutant_guarded_idle()
	assert_bool(order.can_move(1)).is_true()

	# Act
	var result: bool = order.use_move(1)

	# Assert — 與真正版本相反:旗標被消耗,儘管 guard 回報關閉
	assert_bool(result).is_true()
	assert_bool(order.can_move(1)).is_false()


# ---- TurnOrder.use_attack 的敏感度證明 ----------------------------------------

func test_sensitivity_proof_turn_order_use_attack_guard_test_catches_a_mutant_that_bypasses_it() -> void:
	var order: _TurnOrderBypassesWriteGuard = _mutant_guarded_idle()
	assert_bool(order.can_attack(1)).is_true()

	# Act
	var result: bool = order.use_attack(1)

	# Assert
	assert_bool(result).is_true()
	assert_bool(order.can_attack(1)).is_false()


# ---- TurnOrder.end_unit_turn 的敏感度證明 -------------------------------------

func test_sensitivity_proof_turn_order_end_unit_turn_guard_test_catches_a_mutant_that_bypasses_it() -> void:
	var order: _TurnOrderBypassesWriteGuard = _mutant_guarded_idle()
	assert_bool(order.is_done(1)).is_false()

	# Act
	var result: bool = order.end_unit_turn(1)

	# Assert
	assert_bool(result).is_true()
	assert_bool(order.is_done(1)).is_true()


# ---- TurnOrder.advance_faction 的敏感度證明 -----------------------------------

func test_sensitivity_proof_turn_order_advance_faction_guard_test_catches_a_mutant_that_bypasses_it() -> void:
	var order: _TurnOrderBypassesWriteGuard = _mutant_guarded_idle()
	assert_int(order.current_faction()).is_equal(TurnOrder.Side.PLAYER)

	# Act
	order.advance_faction()

	# Assert — 與真正版本相反:陣營確實推進,儘管 guard 回報關閉
	assert_int(order.current_faction()).is_equal(TurnOrder.Side.ENEMY)


# ---- TurnOrder.remove_unit 的敏感度證明 ---------------------------------------

func test_sensitivity_proof_turn_order_remove_unit_guard_test_catches_a_mutant_that_bypasses_it() -> void:
	var order: _TurnOrderBypassesWriteGuard = _mutant_guarded_idle()
	assert_bool(order.can_move(1)).is_true()
	assert_bool(order.can_attack(1)).is_true()

	# Act
	order.remove_unit(1)

	# Assert — 與真正版本相反:移除確實生效(is_done() 對不再追蹤的 id 回報
	# true,同 TurnOrder.is_done() 自己的文件規則),儘管 guard 回報關閉
	assert_bool(order.can_move(1)).is_false()
	assert_bool(order.can_attack(1)).is_false()
	assert_bool(order.is_done(1)).is_true()
