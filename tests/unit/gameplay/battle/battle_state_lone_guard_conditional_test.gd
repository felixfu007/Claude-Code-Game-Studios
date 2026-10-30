# story-033 AC2/AC3/AC4:戊獨行減傷條件化(本回合出手過才取消正向)。
# 規格:docs/reviews/affinity-core-redesign-spec-amend1-2026-10-30.md 第 1 節。
# 全部用測試內聯迷你地形/名冊(不讀任何檔案、不載入 vs01 對局、不跑自動對戰)。
# 旗標寫入點:BattleState.resolve_attack 的 commit_authoritative_change 內;
# 清除點:BattleState.begin_player_turn(兩個 driver 皆包在提交窗內)。
extends GdUnitTestSuite

const _TERRAIN: PackedStringArray = ["......", "......", "......"]


# 戊 id=5 在 (ally_x... 此處 x 為戊的 x),甲 id=1 在 (0,0);敵 id=6 在 (2,2)。
func _build(lone_x: int) -> BattleState:
	var lines: PackedStringArray = [
		"1,甲,PLAYER,30,16,8,6,1,1,0,0",
		"5,戊,PLAYER,30,16,8,6,1,1,%d,0,1" % lone_x,
		"6,E1,ENEMY,300,14,6,6,1,1,2,2",
	]
	return BattleState.create(_TERRAIN, "\n".join(lines))


func _enemy_dmg_on_5(state: BattleState) -> int:
	return int(state.preview_damage_breakdown(6, 5, 0).breakdown["damage"])


# ---- 旗標生命週期 -------------------------------------------------------------

func test_flag_initially_false_enemy_first_battle_counts_as_not_attacked() -> void:
	var s: BattleState = _build(4)
	assert_bool(s.attacked_this_phase(5)).is_false()
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 - 2)  # 未出手 d=4 -> +2


func test_flag_set_when_lone_unit_resolves_attack_as_attacker() -> void:
	var s: BattleState = _build(4)
	s.resolve_attack(5, 6, 0)
	assert_bool(s.attacked_this_phase(5)).is_true()
	assert_bool(s.attacked_this_phase(1)).is_false()


func test_flag_not_set_by_being_attacked_or_moving() -> void:
	var s: BattleState = _build(4)
	s.resolve_attack(6, 5, 0)  # 戊被打
	assert_bool(s.attacked_this_phase(5)).is_false()


func test_flag_cleared_when_new_player_phase_begins() -> void:
	var s: BattleState = _build(4)
	s.resolve_attack(5, 6, 0)
	assert_bool(s.attacked_this_phase(5)).is_true()
	s.begin_player_turn()
	assert_bool(s.attacked_this_phase(5)).is_false()
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 - 2)  # 又回到 +2


func test_flag_write_goes_through_commit_window_version_bumps_once() -> void:
	var s: BattleState = _build(4)
	var v0: int = s.combat_state_version
	s.resolve_attack(5, 6, 0)
	assert_int(s.combat_state_version).is_equal(v0 + 1)
	assert_bool(s.write_window_is_open()).is_false()


# ---- 條件化的減傷值 -----------------------------------------------------------

func test_not_attacked_d3_plus_2_attacked_d3_zero() -> void:
	var s: BattleState = _build(3)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 - 2)
	s.resolve_attack(5, 6, 0)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8)  # +2 被取消 -> 6
	assert_int(int(s.preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])).is_equal(0)


func test_attacked_d1_minus_1_is_kept() -> void:
	var s: BattleState = _build(1)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 + 1)
	s.resolve_attack(5, 6, 0)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 + 1)  # 不受旗標影響 -> 7


func test_attacked_d2_stays_zero() -> void:
	var s: BattleState = _build(2)
	s.resolve_attack(5, 6, 0)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8)


func test_other_units_not_affected_by_lone_units_flag() -> void:
	var s: BattleState = _build(4)
	s.resolve_attack(5, 6, 0)
	assert_int(int(s.preview_damage_breakdown(6, 1, 0).breakdown["lone_guard"])).is_equal(0)


# ---- 查詢介面:lone_guard_if_at(unit_id, tile, will_attack) -----------------

func test_lone_guard_if_at_will_attack_param_is_hypothetical_and_ignores_live_flag() -> void:
	var s: BattleState = _build(1)  # 戊 (1,0)
	assert_int(s.lone_guard_if_at(5, Vector2i(5, 2), false)).is_equal(2)
	assert_int(s.lone_guard_if_at(5, Vector2i(5, 2), true)).is_equal(0)
	assert_int(s.lone_guard_if_at(5, Vector2i(2, 0), true)).is_equal(0)
	assert_int(s.lone_guard_if_at(5, Vector2i(0, 1), true)).is_equal(-1)
	assert_int(s.lone_guard_if_at(5, Vector2i(0, 1), false)).is_equal(-1)
	# 兩參數呼叫 = will_attack=false(完整值),即使真實旗標為真
	s.resolve_attack(5, 6, 0)
	assert_int(s.lone_guard_if_at(5, Vector2i(5, 2))).is_equal(2)
	# 無副作用
	assert_that(s.position_of(5)).is_equal(Vector2i(1, 0))


func test_breakdown_equals_lone_guard_if_at_with_real_position_and_real_flag() -> void:
	var s: BattleState = _build(4)
	s.resolve_attack(5, 6, 0)
	var via_breakdown: int = int(s.preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])
	assert_int(via_breakdown).is_equal(s.lone_guard_if_at(5, s.position_of(5), s.attacked_this_phase(5)))
	assert_int(via_breakdown).is_equal(0)
