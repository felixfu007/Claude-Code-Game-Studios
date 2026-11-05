# story-033/034:戊獨行減傷(出手條件已於 story-034 取消;舊旗標機制於 story-035 移除)。
# 規格:docs/reviews/affinity-core-redesign-spec-amend1-2026-10-30.md 第 1 節。
# 全部用測試內聯迷你地形/名冊(不讀任何檔案、不載入 vs01 對局、不跑自動對戰)。
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


# ---- 條件化的減傷值 -----------------------------------------------------------

# story-034 (amend2): 舊:未出手 14-8-2、出手後 14-8;新:d=3 為 0,出手與否皆 14-8
func test_d3_zero_regardless_of_attacking() -> void:
	var s: BattleState = _build(3)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8)
	s.resolve_attack(5, 6, 0)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8)
	assert_int(int(s.preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])).is_equal(0)


func test_attacked_d1_minus_1_is_kept() -> void:
	var s: BattleState = _build(1)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 + 1)
	s.resolve_attack(5, 6, 0)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 + 1)  # 不受旗標影響 -> 7


# 舊值 14-8(d=2 為 0)→ 新值 14-8-2(d=2 為 +2,出手後仍有)
func test_attacked_d2_keeps_plus_2() -> void:
	var s: BattleState = _build(2)
	s.resolve_attack(5, 6, 0)
	assert_int(_enemy_dmg_on_5(s)).is_equal(14 - 8 - 2)


func test_other_units_not_affected_by_lone_unit_attacking() -> void:
	var s: BattleState = _build(4)
	s.resolve_attack(5, 6, 0)
	assert_int(int(s.preview_damage_breakdown(6, 1, 0).breakdown["lone_guard"])).is_equal(0)


# ---- 查詢介面:lone_guard_if_at(unit_id, tile) ----------------------------------


func test_breakdown_equals_lone_guard_if_at_with_real_position() -> void:
	var s: BattleState = _build(4)
	s.resolve_attack(5, 6, 0)
	var via_breakdown: int = int(s.preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])
	assert_int(via_breakdown).is_equal(s.lone_guard_if_at(5, s.position_of(5)))
	assert_int(via_breakdown).is_equal(0)
