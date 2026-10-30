# story-034 AC1~AC3:戊「騎牆 + 留一手」。
# 規格:docs/reviews/affinity-core-redesign-spec-amend2-2026-10-30.md 第 1~3 節。
# 全部用測試內聯迷你地形/名冊(不讀任何檔案、不載入 vs01 對局、不跑自動對戰)。
# 敏感度證明屬「A 類:斷言對象含 static 純函式」,無法做常駐間諜子類別;
# 已改為手動注入兩次(拿掉留一手、d=2 減傷改錯)並還原,原始紅燈行見工作單回報。
extends GdUnitTestSuite

const _TERRAIN: PackedStringArray = ["........", "........", "........"]


# 甲 id=1 在 (0,0);戊 id=5 在 (lone_x,0);敵 id=6 在 (7,2)(DEF 6、ATK 14)。
# with_ally=false 時不放甲(無存活隊友)。
func _build(lone_x: int, with_ally: bool = true) -> BattleState:
	var lines: PackedStringArray = []
	if with_ally:
		lines.append("1,甲,PLAYER,30,16,8,6,1,1,0,0")
	lines.append("5,戊,PLAYER,30,16,8,6,1,1,%d,0,1" % lone_x)
	lines.append("6,E1,ENEMY,300,14,6,6,1,1,7,2")
	return BattleState.create(_TERRAIN, "\n".join(lines))


func _enemy_dmg_on_5(s: BattleState) -> int:
	return int(s.preview_damage_breakdown(6, 5, 0).breakdown["damage"])


func _atk_bd(s: BattleState, attacker_id: int) -> Dictionary:
	return s.preview_damage_breakdown(attacker_id, 6, 0).breakdown


# ---- AC1 新表 ----------------------------------------------------------------

func test_lone_guard_table_d1_minus1_d2_plus2_far_and_none_zero() -> void:
	assert_int(CombatRules.lone_guard(1)).is_equal(-1)
	assert_int(CombatRules.lone_guard(2)).is_equal(2)
	assert_int(CombatRules.lone_guard(3)).is_equal(0)
	assert_int(CombatRules.lone_guard(9)).is_equal(0)
	assert_int(CombatRules.lone_guard(CombatRules.NO_ALLY)).is_equal(0)


func test_enemy_damage_on_straddler_d3_d2_d1_is_6_4_7() -> void:
	assert_int(_enemy_dmg_on_5(_build(3))).is_equal(6)
	assert_int(_enemy_dmg_on_5(_build(2))).is_equal(4)
	assert_int(_enemy_dmg_on_5(_build(1))).is_equal(7)


func test_enemy_damage_on_straddler_no_ally_is_6() -> void:
	assert_int(_enemy_dmg_on_5(_build(4, false))).is_equal(6)


func test_will_attack_param_is_ignored_same_result_true_false() -> void:
	var s: BattleState = _build(2)
	for tile: Vector2i in [Vector2i(2, 0), Vector2i(1, 0), Vector2i(5, 0), Vector2i(4, 2)]:
		assert_int(s.lone_guard_if_at(5, tile, true)).is_equal(s.lone_guard_if_at(5, tile, false))
	assert_int(s.lone_guard_if_at(5, Vector2i(2, 0), true)).is_equal(2)
	assert_int(CombatRules.lone_guard_effective(2, true)).is_equal(2)
	assert_int(CombatRules.lone_guard_effective(-1, true)).is_equal(-1)


func test_attacking_no_longer_cancels_straddler_guard() -> void:
	var s: BattleState = _build(2)
	s.resolve_attack(5, 6, 0)
	assert_int(_enemy_dmg_on_5(s)).is_equal(4)


# ---- AC2 留一手 --------------------------------------------------------------

func test_hold_back_pure_function() -> void:
	assert_int(CombatRules.hold_back(true, 2)).is_equal(1)
	assert_int(CombatRules.hold_back(true, 1)).is_equal(0)
	assert_int(CombatRules.hold_back(true, 3)).is_equal(0)
	assert_int(CombatRules.hold_back(true, CombatRules.NO_ALLY)).is_equal(0)
	assert_int(CombatRules.hold_back(false, 2)).is_equal(0)


func test_straddler_attacking_from_d2_deals_9() -> void:
	var bd: Dictionary = _atk_bd(_build(2), 5)
	assert_int(int(bd["hold_back"])).is_equal(1)
	assert_int(int(bd["damage"])).is_equal(9)


func test_straddler_attacking_from_d1_or_far_deals_10() -> void:
	for x: int in [1, 3, 5]:
		var bd: Dictionary = _atk_bd(_build(x), 5)
		assert_int(int(bd["hold_back"])).is_equal(0)
		assert_int(int(bd["damage"])).is_equal(10)


func test_straddler_with_no_ally_deals_10() -> void:
	var bd: Dictionary = _atk_bd(_build(2, false), 5)
	assert_int(int(bd["hold_back"])).is_equal(0)
	assert_int(int(bd["damage"])).is_equal(10)


func test_non_flagged_player_unit_not_affected_by_hold_back() -> void:
	# 甲在 (0,0),戊在 (2,0):甲的最近隊友 d=2,但甲不是騎牆者。
	var bd: Dictionary = _atk_bd(_build(2), 1)
	assert_int(int(bd["hold_back"])).is_equal(0)
	assert_int(int(bd["damage"])).is_equal(10)


func test_enemy_attacker_has_no_hold_back() -> void:
	var bd: Dictionary = _build(2).preview_damage_breakdown(6, 5, 0).breakdown
	assert_int(int(bd["hold_back"])).is_equal(0)


func test_hold_back_floors_damage_at_zero() -> void:
	# ATK 16 vs DEF 16 -> 0;留一手不得變負。
	var lines: PackedStringArray = [
		"1,甲,PLAYER,30,16,8,6,1,1,0,0",
		"5,戊,PLAYER,30,16,8,6,1,1,2,0,1",
		"6,E1,ENEMY,300,14,16,6,1,1,7,2",
	]
	var s: BattleState = BattleState.create(_TERRAIN, "\n".join(lines))
	assert_int(int(_atk_bd(s, 5)["damage"])).is_equal(0)


func test_resolve_attack_matches_preview_single_source() -> void:
	var s: BattleState = _build(2)
	var predicted: int = int(_atk_bd(s, 5)["damage"])
	var hp0: int = s.unit_by_id(6).hp
	s.resolve_attack(5, 6, 0)
	assert_int(hp0 - s.unit_by_id(6).hp).is_equal(predicted)
	assert_int(predicted).is_equal(9)


# ---- AC3 breakdown 欄位 ------------------------------------------------------

func test_breakdown_has_hold_back_key_for_every_attack() -> void:
	var s: BattleState = _build(2)
	assert_bool(s.preview_damage_breakdown(1, 6, 0).breakdown.has("hold_back")).is_true()
	assert_bool(s.preview_damage_breakdown(6, 1, 0).breakdown.has("hold_back")).is_true()
