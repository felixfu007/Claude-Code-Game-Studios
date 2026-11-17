extends GdUnitTestSuite
## Story 014:麥子健(戊,id=5)騎牆 = 與場上【存活】其餘四人 4 組 state_of 全為 NONE。
## 規格:production/epics/skill-card-system/story-014-lone-guard-follows-relation-state.md
## 同一個布林同時驅動:貼身 d=1 的 -1、d=2 的 +2(lone_guard)、留一手(hold_back)。
##
## 檔案存取:AC3 讀 src/gameplay/combat/combat_rules.gd 原始碼文字(乙類例外,唯讀;
## 只掃這一支檔、只證明「原始碼裡沒有池/state_of 引用」,不證明執行期行為,
## 也不等於窮盡性 —— 反射/動態呼叫不在掃描視野內)。其餘全為記憶體內夾具。
##
## 敏感度證明(常駐 test_sensitivity_proof_*):
##   ② 只看 4 組中的 3 組(mutant provider 略過 C4_C5)→ AC5 丁那條紅
##   ③ 開機快取 → AC2 紅
##   ④ CombatRules 內直接讀池 → AC3 偵測器抓得到(對植入字串)
##   ① 只關 lone_guard 不關 hold_back / 保留貼身 -1:【證明不了】——
##      三項由 BattleState.straddle_is_valid 的同一個布林驅動,mutant 要分歧必須改正式
##      程式(D 類:注入點在受限範圍外)。由 AC1 逐項斷言各自可觀察結果防守,
##      協調者另行手動改壞抽查。

var _keep_alive: Array[AffinityPhiProvider] = []

const _ROW: String = "............."
const _TERRAIN: PackedStringArray = [_ROW, _ROW, _ROW, _ROW, _ROW, _ROW]
const _COMBAT_RULES_PATH: String = "res://src/gameplay/combat/combat_rules.gd"


## 甲=1 在 (0,0);乙=2、丙=3、丁=4 遠在 x=7;戊=5 在 (lone_x,0);敵 6 在 (7,2)(DEF6、ATK14)。
func _build(lone_x: int) -> BattleState:
	var lines: PackedStringArray = []
	lines.append("1,甲,PLAYER,30,16,8,6,1,1,0,0")
	lines.append("2,乙,PLAYER,30,16,8,6,1,1,7,0")
	lines.append("3,丙,PLAYER,30,16,8,6,1,1,7,1")
	lines.append("4,丁,PLAYER,30,16,8,6,1,1,6,1")
	lines.append("5,戊,PLAYER,30,16,8,6,1,1,%d,0,1" % lone_x)
	lines.append("6,E1,ENEMY,300,14,6,6,1,1,7,2")
	return BattleState.create(_TERRAIN, "\n".join(lines))


func _wire(state: BattleState, pool: AffinityDataPool, provider: AffinityPhiProvider = null) -> AffinityPhiProvider:
	var p: AffinityPhiProvider = provider if provider != null else AffinityPhiProvider.new(state, pool)
	_keep_alive.append(p)
	state.attach_straddle_provider(Callable(p, "straddle_valid"))
	return p


func _write(pool: AffinityDataPool, pair: AffinityTypes.Pair, m: float) -> void:
	var r: AffinityDataPool.WriteRejection = pool.append_record(pair, m, AffinityTypes.Source.STORY_EVENT)
	assert_int(r).is_equal(AffinityDataPool.WriteRejection.NONE)


func _enemy_dmg_on_5(s: BattleState) -> int:
	return int(s.preview_damage_breakdown(6, 5, 0).breakdown["damage"])


func _lone5(s: BattleState) -> int:
	return int(s.preview_damage_breakdown(6, 5, 0).breakdown["lone_guard"])


func _atk5_bd(s: BattleState) -> Dictionary:
	return s.preview_damage_breakdown(5, 6, 0).breakdown


# ---- AC1 全 NONE → 三項開;任一非 NONE → 三項歸零 ------------------------------

func test_lone_guard_all_none_d1_minus1_d2_plus2_hold_back_on() -> void:
	var s1: BattleState = _build(1)
	_wire(s1, AffinityDataPool.new())
	assert_int(_lone5(s1)).is_equal(-1)
	assert_int(_enemy_dmg_on_5(s1)).is_equal(7)
	var s2: BattleState = _build(2)
	_wire(s2, AffinityDataPool.new())
	assert_int(_lone5(s2)).is_equal(2)
	assert_int(_enemy_dmg_on_5(s2)).is_equal(4)
	assert_int(int(_atk5_bd(s2)["hold_back"])).is_equal(1)
	assert_int(int(_atk5_bd(s2)["damage"])).is_equal(9)


func test_lone_guard_one_relation_zeroes_all_three_items() -> void:
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, AffinityTypes.Pair.C2_C5, 1.0)
	# d=2:+2 歸零、留一手歸零
	var s2: BattleState = _build(2)
	_wire(s2, pool)
	assert_int(_lone5(s2)).is_equal(0)
	assert_int(_enemy_dmg_on_5(s2)).is_equal(6)
	assert_int(int(_atk5_bd(s2)["hold_back"])).is_equal(0)
	assert_int(int(_atk5_bd(s2)["damage"])).is_equal(10)
	# d=1:貼身沒有額外 -1
	var s1: BattleState = _build(1)
	_wire(s1, pool)
	assert_int(_lone5(s1)).is_equal(0)
	assert_int(_enemy_dmg_on_5(s1)).is_equal(6)


# ---- AC2 即時 ----------------------------------------------------------------

func test_lone_guard_flips_live_when_pool_written_mid_battle() -> void:
	var pool: AffinityDataPool = AffinityDataPool.new()
	var s: BattleState = _build(2)
	_wire(s, pool)
	assert_int(_lone5(s)).is_equal(2)
	_write(pool, AffinityTypes.Pair.C3_C5, -1.0)
	assert_int(_lone5(s)).is_equal(0)
	assert_int(int(_atk5_bd(s)["hold_back"])).is_equal(0)


# ---- AC3 CombatRules 無池知識 --------------------------------------------------

func _has_pool_reference(source_text: String) -> bool:
	for line: String in source_text.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		if line.contains("affinity") or line.contains("state_of") or line.contains("AffinityRelation"):
			return true
	return false


func test_combat_rules_source_has_no_pool_or_state_of_reference() -> void:
	var f: FileAccess = FileAccess.open(_COMBAT_RULES_PATH, FileAccess.READ)
	assert_object(f).is_not_null()
	assert_bool(_has_pool_reference(f.get_as_text())).is_false()


# ---- AC5 逐組 POS / NEG ---------------------------------------------------------

func _each_pair() -> Array[AffinityTypes.Pair]:
	return [
		AffinityTypes.Pair.C1_C5, AffinityTypes.Pair.C2_C5,
		AffinityTypes.Pair.C3_C5, AffinityTypes.Pair.C4_C5,
	]


func test_lone_guard_lost_for_each_of_four_pairs_positive_and_negative() -> void:
	for pair: AffinityTypes.Pair in _each_pair():
		for m: float in [1.0, -1.0]:
			var pool: AffinityDataPool = AffinityDataPool.new()
			_write(pool, pair, m)
			var s: BattleState = _build(2)
			_wire(s, pool)
			assert_int(_lone5(s)).is_equal(0)


func test_lone_guard_dead_ally_relation_is_ignored() -> void:
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, AffinityTypes.Pair.C2_C5, 1.0)
	var s: BattleState = _build(2)
	_wire(s, pool)
	assert_int(_lone5(s)).is_equal(0)
	s.unit_by_id(2).take_damage(999)
	assert_int(_lone5(s)).is_equal(2)


# ---- AC6 敏感度證明 -------------------------------------------------------------

## ② 只看 4 組中的 3 組(略過 C4_C5)。
class _MutantThreeOfFour extends AffinityPhiProvider:
	func straddle_valid(unit_id: int) -> bool:
		for other: Unit in _state.units_of(Unit.Faction.PLAYER):
			if other.id == unit_id or other.id == 4:
				continue
			var pair: AffinityTypes.Pair = AffinityTypes.pair_of(
				AffinityRosterCharacterMapper.character_for_roster_id(unit_id),
				AffinityRosterCharacterMapper.character_for_roster_id(other.id)
			)
			if AffinityRelation.state_of(_pool, pair, 0.0) != AffinityRelation.RelationState.NONE:
				return false
		return true


## ③ 開機快取:第一次答案永遠沿用。
class _MutantCached extends AffinityPhiProvider:
	var _cached: Variant = null
	func straddle_valid(unit_id: int) -> bool:
		if _cached == null:
			_cached = super(unit_id)
		return _cached


func test_sensitivity_proof_three_of_four_pairs_is_caught_by_ac5() -> void:
	var pool: AffinityDataPool = AffinityDataPool.new()
	_write(pool, AffinityTypes.Pair.C4_C5, 1.0)
	var s: BattleState = _build(2)
	_wire(s, pool, _MutantThreeOfFour.new(s, pool))
	# 正式實作應為 0;mutant 漏看丁 → 仍是 2,AC5 的斷言(is_equal(0))會紅。
	assert_int(_lone5(s)).is_equal(2)


func test_sensitivity_proof_cached_state_is_caught_by_ac2() -> void:
	var pool: AffinityDataPool = AffinityDataPool.new()
	var s: BattleState = _build(2)
	_wire(s, pool, _MutantCached.new(s, pool))
	assert_int(_lone5(s)).is_equal(2)
	_write(pool, AffinityTypes.Pair.C3_C5, -1.0)
	# 正式實作應翻成 0;快取 mutant 仍 2,AC2 的斷言會紅。
	assert_int(_lone5(s)).is_equal(2)


func test_sensitivity_proof_pool_reference_in_combat_rules_is_caught_by_ac3() -> void:
	var planted: String = "static func lone_guard(d: int) -> int:\n\tvar x = AffinityRelation.state_of(null, 0, 0.0)\n\treturn 0\n"
	assert_bool(_has_pool_reference(planted)).is_true()
	assert_bool(_has_pool_reference("# affinity only in a comment\nvar a: int = 1\n")).is_false()
