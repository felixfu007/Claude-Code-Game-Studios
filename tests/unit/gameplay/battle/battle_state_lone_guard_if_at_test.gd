# story-031:BattleState.lone_guard_if_at(unit_id, tile) —— 「假設站在 tile」的獨行減傷。
# 規格:docs/reviews/affinity-core-redesign-spec-2026-10-30.md 第 2.2 節。
# 全部用測試內聯迷你地形/名冊,不讀任何檔案。
extends GdUnitTestSuite

const _TERRAIN: PackedStringArray = ["......", "......", "......"]


func _build(ally_x: int, with_ally: bool = true, lone_flag: bool = true) -> BattleState:
	var lines: PackedStringArray = []
	if with_ally:
		lines.append("1,甲,PLAYER,30,16,8,6,1,1,0,0")
	lines.append("5,戊,PLAYER,30,16,8,6,1,1,%d,0%s" % [ally_x, ",1" if lone_flag else ""])
	lines.append("6,E1,ENEMY,30,14,6,6,1,1,2,2")
	return BattleState.create(_TERRAIN, "\n".join(lines))


func _breakdown_lone(state: BattleState) -> int:
	return int(state.preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])


# ① 真實位置:與 preview_damage_breakdown 的 lone_guard 一致(d_min = 4 / 2 / 1 / 無隊友)
func test_lone_guard_if_at_real_position_matches_breakdown_far() -> void:
	var s: BattleState = _build(4)
	assert_int(s.lone_guard_if_at(5, s.position_of(5))).is_equal(_breakdown_lone(s))
	assert_int(_breakdown_lone(s)).is_equal(2)


func test_lone_guard_if_at_real_position_matches_breakdown_dead_zone() -> void:
	var s: BattleState = _build(2)
	assert_int(s.lone_guard_if_at(5, s.position_of(5))).is_equal(_breakdown_lone(s))
	assert_int(_breakdown_lone(s)).is_equal(0)


func test_lone_guard_if_at_real_position_matches_breakdown_adjacent() -> void:
	var s: BattleState = _build(1)
	assert_int(s.lone_guard_if_at(5, s.position_of(5))).is_equal(_breakdown_lone(s))
	assert_int(_breakdown_lone(s)).is_equal(-1)


func test_lone_guard_if_at_real_position_matches_breakdown_no_ally() -> void:
	var s: BattleState = _build(4, false)
	assert_int(s.lone_guard_if_at(5, s.position_of(5))).is_equal(_breakdown_lone(s))
	assert_int(_breakdown_lone(s)).is_equal(2)


# ② 假設位置(戊實際在 (1,0),甲在 (0,0))
func test_lone_guard_if_at_hypothetical_tiles_follow_spec() -> void:
	var s: BattleState = _build(1)
	assert_int(s.lone_guard_if_at(5, Vector2i(5, 2))).is_equal(2)   # d=7 >=3
	assert_int(s.lone_guard_if_at(5, Vector2i(3, 0))).is_equal(2)   # d=3 門檻
	assert_int(s.lone_guard_if_at(5, Vector2i(2, 0))).is_equal(0)   # d=2
	assert_int(s.lone_guard_if_at(5, Vector2i(0, 1))).is_equal(-1)  # d=1
	# 查詢不得移動單位
	assert_that(s.position_of(5)).is_equal(Vector2i(1, 0))


# ③ 非獨行旗標、敵方、未知 id 恆為 0
func test_lone_guard_if_at_unflagged_unit_is_always_zero() -> void:
	var s: BattleState = _build(4, true, false)
	assert_int(s.lone_guard_if_at(5, Vector2i(5, 2))).is_equal(0)
	assert_int(s.lone_guard_if_at(5, Vector2i(0, 1))).is_equal(0)
	assert_int(s.lone_guard_if_at(1, Vector2i(5, 2))).is_equal(0)


func test_lone_guard_if_at_enemy_and_unknown_id_are_zero() -> void:
	var s: BattleState = _build(4)
	assert_int(s.lone_guard_if_at(6, Vector2i(5, 2))).is_equal(0)
	assert_int(s.lone_guard_if_at(999, Vector2i(5, 2))).is_equal(0)
