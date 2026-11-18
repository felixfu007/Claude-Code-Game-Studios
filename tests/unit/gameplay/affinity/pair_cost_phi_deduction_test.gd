# story-016 折損扣減並肩貢獻(規格 quick-spec card-campfire-rework-v1 第 5.1 節)。
#
# 甲類例外?否 —— 本檔不讀任何檔案。全部資料在測試內建構(AffinityLink.new() 與內嵌 roster 字串)。
# 扣減只在 AffinityRules.bonus_breakdown_for_at 內做一次;N 經注入的 Callable(unit_id, partner_id)->int 傳入。
# S 已編碼在「線」本身:S==NONE 的配對沒有線(provider 的 links() 不產生),故 NONE 恆貢獻 0。
#
# 敏感度證明:常駐 test_sensitivity_proof_* 把「會區分正確實作與各 mutant 的數值」寫成會通過的斷言;
# AffinityRules 是 static,無法子類別覆寫,故 mutant 以「暫時改壞正式碼 -> 單檔跑 -> 還原」逐一執行,
# 結果記在交付回報。⚠ mutant ④(NONE 也扣)在此結構下沒有可改的分支(NONE 沒有線),見回報。
extends GdUnitTestSuite

const _ROSTER_TWO: String = "1,P1,PLAYER,20,10,0,0,1,1,0,0\n2,P2,PLAYER,20,10,0,0,1,1,1,0"


func _link(pol: AffinityLink.Polarity, a: int, b: int, amp: int = 1) -> AffinityLink:
	var l: AffinityLink = AffinityLink.new()
	l.unit_a = a
	l.unit_b = b
	l.polarity = pol
	l.amp = amp
	return l


func _wear(n: int) -> Callable:
	return func(_a: int, _b: int) -> int: return n


## unit 1 at (0,0), partner 2 at (distance,0); returns clamped Φ for unit 1.
func _phi(pol: AffinityLink.Polarity, distance: int, wear: int) -> int:
	var positions: Dictionary[int, Vector2i] = {1: Vector2i(0, 0), 2: Vector2i(distance, 0)}
	var links: Array[AffinityLink] = [_link(pol, 1, 2)]
	return AffinityRules.bonus_for(1, positions, links, null, _wear(wear))


# ---- AC1:5.1 表每列 ---------------------------------------------------------

func test_none_pair_contributes_zero_at_any_wear_and_distance() -> void:
	var positions: Dictionary[int, Vector2i] = {1: Vector2i(0, 0), 2: Vector2i(1, 0)}
	var no_links: Array[AffinityLink] = []
	for n: int in [0, 1, 2, 3]:
		assert_int(AffinityRules.bonus_for(1, positions, no_links, null, _wear(n))).is_equal(0)


func test_pos_adjacent_wear_reduces_then_floors_at_zero() -> void:
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 1, 0)).is_equal(3)
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 1, 1)).is_equal(1)
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 1, 2)).is_equal(0)
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 1, 3)).is_equal(0)


func test_pos_far_and_distance_two_unchanged_by_wear() -> void:
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 3, 0)).is_equal(-1)
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 3, 2)).is_equal(-1)
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 2, 0)).is_equal(0)
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 2, 2)).is_equal(0)


func test_neg_rows_subtract_wear_times_negative_loss() -> void:
	assert_int(_phi(AffinityLink.Polarity.NEGATIVE, 1, 1)).is_equal(-2)
	assert_int(_phi(AffinityLink.Polarity.NEGATIVE, 3, 1)).is_equal(1)
	assert_int(_phi(AffinityLink.Polarity.NEGATIVE, 2, 1)).is_equal(-1)


# ---- AC2:夾限順序 ----------------------------------------------------------

func _three_amp2_pos_links() -> Array[AffinityLink]:
	var links: Array[AffinityLink] = [
		_link(AffinityLink.Polarity.POSITIVE, 1, 2, 2),
		_link(AffinityLink.Polarity.POSITIVE, 1, 3, 2),
		_link(AffinityLink.Polarity.POSITIVE, 1, 4, 2),
	]
	return links


func _adjacent_positions() -> Dictionary[int, Vector2i]:
	return {1: Vector2i(5, 5), 2: Vector2i(4, 5), 3: Vector2i(6, 5), 4: Vector2i(5, 4)}


func test_deduction_applies_before_clamp_and_clamp_happens_once() -> void:
	# 每條 c0=6(3×amp2)、N=1 扣 2 -> 4;三條合計 12 = PHI_MAX,raw_sum 即扣後總和 12。
	var b: AffinityBonusBreakdown = AffinityRules.bonus_breakdown_for_at(
		1, Vector2i(5, 5), _adjacent_positions(), _three_amp2_pos_links(), null, _wear(1))
	assert_int(b.raw_sum).is_equal(12)
	assert_int(b.clamped_sum).is_equal(12)
	# 對照:無折損 raw 18 被夾到 12。先夾再扣會得 12-6=6,與 12 不同。
	var b0: AffinityBonusBreakdown = AffinityRules.bonus_breakdown_for_at(
		1, Vector2i(5, 5), _adjacent_positions(), _three_amp2_pos_links(), null, _wear(0))
	assert_int(b0.raw_sum).is_equal(18)
	assert_int(b0.clamped_sum).is_equal(12)


func test_sensitivity_proof_clamp_order_distinguishes_deduct_then_clamp() -> void:
	# 兩種順序的結果必須不同,且實作等於「先扣再夾」。
	var deduct_then_clamp: int = clampi(3 * (6 - 2), AffinityRules.PHI_MIN, AffinityRules.PHI_MAX)
	var clamp_then_deduct: int = clampi(18, AffinityRules.PHI_MIN, AffinityRules.PHI_MAX) - 3 * 2
	assert_int(deduct_then_clamp).is_not_equal(clamp_then_deduct)
	assert_int(AffinityRules.bonus_for_at(
		1, Vector2i(5, 5), _adjacent_positions(), _three_amp2_pos_links(), null, _wear(1))
	).is_equal(deduct_then_clamp)


# ---- AC1 mutant 敏感度(數值鎖):各 mutant 會讓下列其一變紅 --------------------

func test_sensitivity_proof_pos_nonpositive_not_deducted_and_neg_uses_negative_loss() -> void:
	# mutant①(POS c0<=0 也被扣):距離 3,N=2 會變 -3 而非 -1。
	assert_int(_phi(AffinityLink.Polarity.POSITIVE, 3, 2)).is_equal(-1)
	# mutant②(NEG 用 positive 係數):NEG 相鄰 N=1 會變 -3 而非 -2。
	assert_int(_phi(AffinityLink.Polarity.NEGATIVE, 1, 1)).is_equal(-2)
	# mutant⑤(改 amp 代替扣減):amp2 的 POS 相鄰 N=1 -> 6-2=4;改 amp 會得 3×1=3。
	var positions: Dictionary[int, Vector2i] = {1: Vector2i(0, 0), 2: Vector2i(1, 0)}
	var links: Array[AffinityLink] = [_link(AffinityLink.Polarity.POSITIVE, 1, 2, 2)]
	assert_int(AffinityRules.bonus_for(1, positions, links, null, _wear(1))).is_equal(4)


# ---- AC3 / AC5 / 真實 provider 路徑 -----------------------------------------

func _provider_setup() -> Dictionary:
	var state: BattleState = BattleState.create(PackedStringArray(), _ROSTER_TWO)
	var pool: AffinityDataPool = AffinityDataPool.new()
	assert_int(pool.append_record(AffinityTypes.Pair.C1_C2, 1.0, AffinityTypes.Source.STORY_EVENT)).is_equal(AffinityDataPool.WriteRejection.NONE)
	return {"state": state, "pool": pool, "provider": AffinityPhiProvider.new(state, pool)}


func _add_wear(state: BattleState, n: int) -> void:
	state.commit_authoritative_change(func() -> void: state.add_pair_wear(int(AffinityTypes.Pair.C1_C2), n, 3))


func test_s_flip_pos_none_pos_keeps_wear_and_reapplies() -> void:
	var ctx: Dictionary = _provider_setup()
	var state: BattleState = ctx["state"]
	var pool: AffinityDataPool = ctx["pool"]
	var provider: AffinityPhiProvider = ctx["provider"]
	assert_int(provider.phi_of(1)).is_equal(3)  # N=0
	_add_wear(state, 2)
	assert_int(provider.phi_of(1)).is_equal(0)  # POS, N=2 下限
	# S=NONE:同一個 state(折損住在這裡)配空池 -> 無線。(池內追加 -1.0 得 NEG 而非 0,故不用追加法翻 NONE;
	# 已實測 phi=-3,即 NEG 線 -1-2×1。)
	var none_provider: AffinityPhiProvider = AffinityPhiProvider.new(state, AffinityDataPool.new())
	assert_int(none_provider.phi_of(1)).is_equal(0)  # NONE
	assert_int(provider.phi_of(1)).is_equal(0)  # 回 POS,N 仍 2(N=0 時會是 3)


func test_wear_changes_phi_but_not_pool_or_state() -> void:
	var ctx: Dictionary = _provider_setup()
	var state: BattleState = ctx["state"]
	var pool: AffinityDataPool = ctx["pool"]
	var provider: AffinityPhiProvider = ctx["provider"]
	var k: float = state.affinity_tuning.neutral_band()
	var v_before: float = pool.combat_strength_read(AffinityTypes.Pair.C1_C2).value
	var s_before: int = AffinityRelation.state_of(pool, AffinityTypes.Pair.C1_C2, k)
	_add_wear(state, 1)
	assert_int(provider.phi_of(1)).is_equal(1)
	assert_float(pool.combat_strength_read(AffinityTypes.Pair.C1_C2).value).is_equal(v_before)
	assert_int(AffinityRelation.state_of(pool, AffinityTypes.Pair.C1_C2, k)).is_equal(s_before)
