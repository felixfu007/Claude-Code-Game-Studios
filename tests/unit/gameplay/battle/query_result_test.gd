## Story: ADR-0001 QueryResult contract type
## (docs/architecture/adr-0001-tactical-query-atomicity-contract.md,
## docs/architecture/query-result-scope-boundary-2026-10-12.md).
## Tests for src/gameplay/battle/query_result.gd — the version-stamped query
## result base class every ADR-0001-scoped query result
## (MoveTargetsBreakdownResult, DamageBreakdownResult) is built on. Covers
## both independent presentation-layer obligations ADR-0001 specifies:
## per-result staleness (is_stale()) and cross-result version agreement for a
## merged display frame (assert_same_version()) — see query_result.gd's own
## doc comment for why these are two separate obligations, not one function.
##
## Fixtures: minimal 1-unit roster built inline on an empty board — BattleState/
## Board/Unit are all RefCounted or static, so nothing here leaves orphans.
## Same technique as damage_breakdown_query_test.gd / movement_range_query_test.gd.
extends GdUnitTestSuite


func _build() -> BattleState:
	return BattleState.create(PackedStringArray(), "1,P1,PLAYER,20,10,0,3,1,1,0,0")


# =============================================================================
# 1. version 在建構時取得當下 combat_state_version 的快照
# =============================================================================

func test_version_captures_combat_state_version_at_construction() -> void:
	# Arrange
	var state: BattleState = _build()

	# Act
	var result: QueryResult = QueryResult.new(state)

	# Assert
	assert_int(result.version).is_equal(0)
	assert_int(result.version).is_equal(state.combat_state_version)


# =============================================================================
# 2. is_stale():寫入前為假,權威寫入後轉真
# =============================================================================

func test_is_stale_false_before_authoritative_write() -> void:
	# Arrange / Act
	var state: BattleState = _build()
	var result: QueryResult = QueryResult.new(state)

	# Assert
	assert_bool(result.is_stale()).is_false()


func test_is_stale_true_after_authoritative_write() -> void:
	# Arrange
	var state: BattleState = _build()
	var result: QueryResult = QueryResult.new(state)

	# Act — 一次已提交的變化(合法移動,bump 版本號)
	assert_bool(state.move_unit(1, Vector2i(1, 0))).is_true()

	# Assert
	assert_bool(result.is_stale()).is_true()


# =============================================================================
# 3. assert_same_version():同版本回 true;混版本回 false 且觸發 push_error
#    (生產碼走 push_error + 明確 return,不是靜默吞掉 —— 2026-09-15 條目:
#    絕不可用 assert() 守衛回傳 enum/bool 的分支)
# =============================================================================

func test_assert_same_version_true_when_all_results_share_a_version() -> void:
	# Arrange
	var state: BattleState = _build()
	var a: QueryResult = QueryResult.new(state)
	var b: QueryResult = QueryResult.new(state)
	var results: Array[QueryResult] = [a, b]

	# Act / Assert
	assert_bool(QueryResult.assert_same_version(results)).is_true()


func test_assert_same_version_false_when_versions_differ() -> void:
	# Arrange
	var state: BattleState = _build()
	var before: QueryResult = QueryResult.new(state)
	assert_bool(state.move_unit(1, Vector2i(1, 0))).is_true()
	var after: QueryResult = QueryResult.new(state)
	var results: Array[QueryResult] = [before, after]

	# Act / Assert
	assert_bool(QueryResult.assert_same_version(results)).is_false()


# =============================================================================
# 4. 邊界:0 或 1 個元素恆回 true(沒有「彼此」可比較)
# =============================================================================

func test_assert_same_version_true_for_empty_array() -> void:
	var results: Array[QueryResult] = []
	assert_bool(QueryResult.assert_same_version(results)).is_true()


func test_assert_same_version_true_for_single_element_array() -> void:
	var state: BattleState = _build()
	var results: Array[QueryResult] = [QueryResult.new(state)]
	assert_bool(QueryResult.assert_same_version(results)).is_true()


# =============================================================================
# 5. 子類別實例可放進 Array[QueryResult]
#    (固化自 prototypes/query-result-probe-2026-10-12/probe_array_typing.gd 的
#    探針 1 —— 探針會被丟掉,這條常駐測試不會)
# =============================================================================

func test_subclass_instances_accepted_into_typed_query_result_array() -> void:
	# Arrange
	var state: BattleState = _build()
	var move_result: MoveTargetsBreakdownResult = MoveTargetsBreakdownResult.new(state, {"legal": []})
	var dmg_result: DamageBreakdownResult = DamageBreakdownResult.new(state, {"damage": 5})

	# Act
	var results: Array[QueryResult] = [move_result, dmg_result]

	# Assert — 型別化陣列接受兩種子類別實例,且 assert_same_version() 能跨子類別運作
	assert_int(results.size()).is_equal(2)
	assert_bool(QueryResult.assert_same_version(results)).is_true()


# =============================================================================
# 敏感度證明
# =============================================================================

# 間諜子類別 1 —— 重現「is_stale() 恆回 false」這個會讓過期結果看起來仍新鮮的
# 缺陷形狀。is_stale() 是一般 instance method,可用真正的多型覆寫(與
# movement_range_query_test.gd 等既有先例同一手法)。
class _MutantNeverStale extends QueryResult:
	func is_stale() -> bool:
		return false


func test_sensitivity_proof_is_stale_detects_permanently_fresh_mutant() -> void:
	# Arrange
	var state: BattleState = _build()
	var mutant: _MutantNeverStale = _MutantNeverStale.new(state)
	var trusted: QueryResult = QueryResult.new(state)

	# Act — 一次已提交的變化(合法移動,bump 版本號)
	assert_bool(state.move_unit(1, Vector2i(1, 0))).is_true()

	# Ground truth — 同一次建構、同一次寫入,真正的 QueryResult 會正確轉真,
	# 這正是 test_is_stale_true_after_authoritative_write() 已經斷言的行為。
	assert_bool(trusted.is_stale()).is_true()

	# Assert — 證明若 is_stale() 真的被改成恆回 false,上面那條斷言真的會被踩中:
	# 同一個版本推進下,mutant 仍回報「新鮮」,不是巧合同值。
	assert_bool(mutant.is_stale()).is_false()


# 間諜子類別 2 —— 重現「assert_same_version() 改成永遠回 true」這個會讓混版本
# 合併顯示悄悄過關的缺陷形狀。assert_same_version() 是 static func,GDScript
# 沒有真正的虛擬派發可覆寫 static 方法;本測試改用「同名遮蔽」(shadowing)——
# 直接對子類別呼叫 _MutantAssertAlwaysTrue.assert_same_version(...),示範「這個
# 安全網若真的被換成恆真的樁函式」時,
# test_assert_same_version_false_when_versions_differ() 原本會抓到的混版本案例
# 會悄悄通過。
class _MutantAssertAlwaysTrue extends QueryResult:
	static func assert_same_version(_results: Array[QueryResult]) -> bool:
		return true


func test_sensitivity_proof_assert_same_version_detects_stubbed_always_true() -> void:
	# Arrange — 與 test_assert_same_version_false_when_versions_differ() 完全相同的
	# 混版本場景。
	var state: BattleState = _build()
	var before: QueryResult = QueryResult.new(state)
	assert_bool(state.move_unit(1, Vector2i(1, 0))).is_true()
	var after: QueryResult = QueryResult.new(state)
	var results: Array[QueryResult] = [before, after]

	# Ground truth — 真正的 QueryResult.assert_same_version() 正確回 false,這正是
	# test_assert_same_version_false_when_versions_differ() 已經斷言的行為。
	assert_bool(QueryResult.assert_same_version(results)).is_false()

	# Act / Assert — 證明若這個安全網真的被換成恆真的樁函式,上面那條斷言會被
	# 踩中:同一組混版本輸入,mutant 版本回 true,不是巧合同值。
	assert_bool(_MutantAssertAlwaysTrue.assert_same_version(results)).is_true()
