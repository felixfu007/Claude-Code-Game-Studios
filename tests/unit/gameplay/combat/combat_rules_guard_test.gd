# story-031 AC1:CombatRules.guard() / guard_total() / damage(..., guard_total) 單元測試。
# 規格:docs/reviews/affinity-core-redesign-spec-2026-10-30.md 第 1.2~1.4 節。
# 純函式,無節點、無檔案存取。
extends GdUnitTestSuite


func test_guard_zero_phi_is_zero() -> void:
	assert_int(CombatRules.guard(0)).is_equal(0)


func test_guard_positive_phi_rounds_up() -> void:
	assert_int(CombatRules.guard(1)).is_equal(1)
	assert_int(CombatRules.guard(2)).is_equal(1)
	assert_int(CombatRules.guard(3)).is_equal(2)
	assert_int(CombatRules.guard(4)).is_equal(2)
	assert_int(CombatRules.guard(12)).is_equal(6)


# story-033 AC1 (amend1 §2): negative side rounds UP symmetrically: -ceil(|Φ|/2).
# old -> new: -1: 0 -> -1; -2: -1 -> -1 (unchanged); -3: -1 -> -2; -4: -2 -> -2 (unchanged).
func test_guard_negative_phi_is_extra_damage_ceil_abs_half() -> void:
	assert_int(CombatRules.guard(-1)).is_equal(-1)
	assert_int(CombatRules.guard(-2)).is_equal(-1)
	assert_int(CombatRules.guard(-3)).is_equal(-2)
	assert_int(CombatRules.guard(-4)).is_equal(-2)


# tuning-data story-004:原「CombatRules.GUARD_MAX/MIN 等於字面值」兩條斷言已刪除(資料驅動後等於把資料檔釘死);
# 改為行為斷言,期望值取自 defaults() 或內聯 CombatTuning.from_text,並含一組非預設夾限。
func test_guard_total_clamps_upper_bound() -> void:
	var t: CombatTuning = CombatTuning.defaults()
	assert_int(CombatRules.guard_total(6, 0)).is_equal(t.guard_max())
	assert_int(CombatRules.guard_total(2, 2)).is_equal(t.guard_max())
	assert_int(CombatRules.guard_total(6, 0, t)).is_equal(t.guard_max())


func test_guard_total_clamps_lower_bound() -> void:
	var t: CombatTuning = CombatTuning.defaults()
	assert_int(CombatRules.guard_total(-2, -1)).is_equal(t.guard_min())
	assert_int(CombatRules.guard_total(-5, 0)).is_equal(t.guard_min())
	assert_int(CombatRules.guard_total(-5, 0, t)).is_equal(t.guard_min())


func test_guard_total_clamp_comes_from_injected_tuning_not_constants() -> void:
	# 非預設夾限 [-1, 1]:Φ 極大 -> 1(預設會是 3);極小 -> -1(預設會是 -2)。
	var t: CombatTuning = _tuning_with("combat,guard_min,-2", "combat,guard_min,-1", "combat,guard_max,3", "combat,guard_max,1")
	assert_bool(t != null).is_true()
	assert_int(CombatRules.guard_total(6, 0, t)).is_equal(1)
	assert_int(CombatRules.guard_total(-5, 0, t)).is_equal(-1)
	assert_int(CombatRules.guard_total(6, 0)).is_not_equal(1)


# 以預設資料檔文字為底,逐項替換後解析(只換指定行)。
func _tuning_with(from_a: String, to_a: String, from_b: String, to_b: String) -> CombatTuning:
	var base: String = "deck,opening_hand_size,5
deck,hand_size_limit,5
deck,cards_drawn_per_turn,1
" 		+ "card_modifier,atk_delta_min,-4
card_modifier,atk_delta_max,6
card_modifier,def_delta_min,-3
card_modifier,def_delta_max,4
" 		+ "combat,guard_min,-2
combat,guard_max,3
combat,lone_far_distance,3
combat,lone_far_guard,0
combat,lone_near_distance,1
" 		+ "combat,lone_near_guard,-1
combat,lone_mid_guard,2
combat,hold_back_distance,2
combat,hold_back_penalty,1
affinity,delta_positive_adjacent,3
affinity,delta_positive_far,-1
affinity,delta_negative_adjacent,-1
affinity,delta_negative_far,2
affinity,delta_neutral,0
affinity,phi_min,-4
affinity,phi_max,12
"
	return CombatTuning.from_text(base.replace(from_a, to_a).replace(from_b, to_b)) as CombatTuning


func test_guard_total_within_bounds_is_sum() -> void:
	assert_int(CombatRules.guard_total(1, 1)).is_equal(2)
	assert_int(CombatRules.guard_total(0, 0)).is_equal(0)


# 規格 1.4 算例 1:甲 DEF 8、Φ_def=+3,被 ATK 14 打 → 4(舊 6)
func test_spec_example_1_jia_takes_4() -> void:
	var g: int = CombatRules.guard_total(CombatRules.guard(3), 0)
	assert_int(CombatRules.damage(14, 8, 0, g)).is_equal(4)


# 算例 2:丙 DEF 7、Φ_def=+2,被 ATK 13 打 → 5(舊 6)
func test_spec_example_2_bing_takes_5() -> void:
	var g: int = CombatRules.guard_total(CombatRules.guard(2), 0)
	assert_int(CombatRules.damage(13, 7, 0, g)).is_equal(5)


# 算例 3(story-033 修訂):丁 DEF 6、Φ_def=-1,被 ATK 13 打 → 8(舊 7)、ATK 14 → 9(舊 8)
func test_spec_example_3_ding_takes_8() -> void:
	var g: int = CombatRules.guard_total(CombatRules.guard(-1), 0)
	assert_int(CombatRules.damage(13, 6, 0, g)).is_equal(8)
	assert_int(CombatRules.damage(14, 6, 0, g)).is_equal(9)


# story-034 (amend2): 原 story-033 AC3(出手過 → min(lone, 0))作廢:舊值 (2,true)→0 / (0,true)→0
# 新值 (2,true)→2 / (0,true)→0;該參數已棄用,忽略,兩種取值結果相同。
func test_lone_guard_effective_ignores_attacked_flag() -> void:
	assert_int(CombatRules.lone_guard_effective(2, true)).is_equal(2)
	assert_int(CombatRules.lone_guard_effective(0, true)).is_equal(0)
	assert_int(CombatRules.lone_guard_effective(-1, true)).is_equal(-1)
	assert_int(CombatRules.lone_guard_effective(2, false)).is_equal(2)
	assert_int(CombatRules.lone_guard_effective(-1, false)).is_equal(-1)


func test_damage_default_guard_matches_old_rule() -> void:
	assert_int(CombatRules.damage(12, 8, 3)).is_equal(7)


func test_damage_negative_guard_adds_damage_and_floors_at_zero() -> void:
	assert_int(CombatRules.damage(10, 8, 0, -2)).is_equal(4)
	assert_int(CombatRules.damage(5, 9, 0, 3)).is_equal(0)
