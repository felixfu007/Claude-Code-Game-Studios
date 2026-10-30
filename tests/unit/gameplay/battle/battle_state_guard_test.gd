# story-031 AC2/AC4:BattleState 的好感度減傷(guard)與獨行減傷(lone_guard)。
# 規格:docs/reviews/affinity-core-redesign-spec-2026-10-30.md 第 1、2 節。
# 全部用測試內聯的迷你地形/名冊(不讀任何檔案、不載入 vs01 對局)。
# 名冊第 12 欄 lone_guard=1 為資料驅動旗標(Unit.lone_guard),不寫死單位 id。
extends GdUnitTestSuite

const _TERRAIN: PackedStringArray = ["......", "......", "......"]


# 固定回傳 Φ_def 的替身提供者(RefCounted,測試持有強參照)。
class _StubPhi extends RefCounted:
	var value: int = 0
	func phi_of(_unit_id: int) -> int:
		return value


func _build(ally_x: int, with_ally: bool = true, lone_flag: bool = true) -> BattleState:
	var lines: PackedStringArray = []
	if with_ally:
		lines.append("1,甲,PLAYER,30,16,8,6,1,1,0,0")
	lines.append("5,戊,PLAYER,30,16,8,6,1,1,%d,0%s" % [ally_x, ",1" if lone_flag else ""])
	lines.append("6,E1,ENEMY,30,14,6,6,1,1,2,2")
	return BattleState.create(_TERRAIN, "\n".join(lines))


func _enemy_dmg_on(state: BattleState, target_id: int) -> int:
	return int(state.preview_damage_breakdown(6, target_id, 0).breakdown["damage"])


# ---- AC4:敵方攻擊時 guard 照算 ----------------------------------------------

func test_guard_enemy_attack_on_player_with_phi_def_3_deals_2_less() -> void:
	var state: BattleState = _build(5, true, false)
	var stub: _StubPhi = _StubPhi.new()
	stub.value = 3
	assert_int(_enemy_dmg_on(state, 1)).is_equal(6)  # 未掛載:舊規則 14-8
	state.attach_defense_phi_provider(Callable(stub, "phi_of"))
	var bd: Dictionary = state.preview_damage_breakdown(6, 1, 0).breakdown
	assert_int(int(bd["phi"])).is_equal(0)       # 敵方 Φ_att 仍為 0
	assert_int(int(bd["phi_def"])).is_equal(3)
	assert_int(int(bd["guard"])).is_equal(2)
	assert_int(int(bd["damage"])).is_equal(4)


func test_guard_resolve_attack_matches_preview() -> void:
	var state: BattleState = _build(5, true, false)
	var stub: _StubPhi = _StubPhi.new()
	stub.value = 3
	state.attach_defense_phi_provider(Callable(stub, "phi_of"))
	var previewed: int = state.preview_damage(6, 1, 0).damage
	var dealt: int = state.resolve_attack(6, 1, 0)
	assert_int(dealt).is_equal(previewed)
	assert_int(dealt).is_equal(4)
	assert_int(state.unit_by_id(1).hp).is_equal(26)


func test_guard_negative_phi_def_adds_damage() -> void:
	var state: BattleState = _build(5, true, false)
	var stub: _StubPhi = _StubPhi.new()
	stub.value = -4
	state.attach_defense_phi_provider(Callable(stub, "phi_of"))
	assert_int(_enemy_dmg_on(state, 1)).is_equal(8)  # 6 + 2


func test_guard_enemy_defender_never_guards() -> void:
	var state: BattleState = _build(5, true, false)
	var stub: _StubPhi = _StubPhi.new()
	stub.value = 12
	state.attach_defense_phi_provider(Callable(stub, "phi_of"))
	var bd: Dictionary = state.preview_damage_breakdown(1, 6, 0).breakdown
	assert_int(int(bd["guard"])).is_equal(0)
	assert_int(int(bd["damage"])).is_equal(16 - 6)


func test_guard_clamped_to_guard_max() -> void:
	var state: BattleState = _build(5, true, false)
	var stub: _StubPhi = _StubPhi.new()
	stub.value = 12
	state.attach_defense_phi_provider(Callable(stub, "phi_of"))
	assert_int(int(state.preview_damage_breakdown(6, 1, 0).breakdown["guard"])).is_equal(CombatRules.GUARD_MAX)


# ---- AC2:戊獨行(旗標驅動)---------------------------------------------------

func test_lone_guard_far_ally_distance_4_gives_plus_2() -> void:
	assert_int(_enemy_dmg_on(_build(4), 5)).is_equal(14 - 8 - 2)


func test_lone_guard_distance_3_is_threshold_gives_plus_2() -> void:
	assert_int(_enemy_dmg_on(_build(3), 5)).is_equal(14 - 8 - 2)


func test_lone_guard_distance_2_is_dead_zone() -> void:
	assert_int(_enemy_dmg_on(_build(2), 5)).is_equal(14 - 8)


func test_lone_guard_distance_1_is_minus_1() -> void:
	assert_int(_enemy_dmg_on(_build(1), 5)).is_equal(14 - 8 + 1)


func test_lone_guard_no_living_ally_gives_plus_2() -> void:
	assert_int(_enemy_dmg_on(_build(4, false), 5)).is_equal(14 - 8 - 2)


func test_lone_guard_unflagged_unit_gets_nothing() -> void:
	assert_int(_enemy_dmg_on(_build(4, true, false), 5)).is_equal(14 - 8)


func test_lone_guard_nearest_ally_used_not_sum() -> void:
	# 戊(1,0) 距甲(0,0)=1 -> -1,不因另有遠處隊友而改變。
	assert_int(int(_build(1).preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])).is_equal(-1)
