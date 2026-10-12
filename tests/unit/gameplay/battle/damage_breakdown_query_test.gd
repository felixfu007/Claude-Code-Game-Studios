## Story: production/epics/tactical-combat/story-006-atk-def-phi-breakdown-query.md
## Tests for BattleState.preview_damage_breakdown() — the ATK/DEF/Φ damage
## breakdown query GDD UI Requirements §4 calls for. The companion baseline/
## effective stat access layer (Unit.stat_access_view()) is tested in
## tests/unit/gameplay/units/unit_test.gd instead, alongside Unit's existing
## effective_atk()/effective_def() tests — keeping the "two relatively
## independent interfaces" split the story's own Implementation Notes #1
## describes.
##
## 🔴 2026-10-12 migrated to ADR-0001's QueryResult contract type
## (docs/architecture/query-result-scope-boundary-2026-10-12.md): this query
## is now one of the two breakdown queries the manager ruled must move to the
## new type. preview_damage_breakdown() now returns a DamageBreakdownResult
## (or null for an unknown unit id — see test_unknown_*_returns_null() below,
## renamed from *_returns_empty_dictionary() because the behavior itself
## changed, not just its wrapper). The payload Dictionary moved from the
## return value itself to result.breakdown; the "combat_state_version" key
## is gone from that Dictionary entirely — read result.version instead.
##
## Fixtures: minimal 2-unit rosters built inline, same technique as
## movement_range_query_test.gd / threat_range_query_test.gd — no Node is
## ever created (BattleState/Board/Unit are all RefCounted or static), so
## nothing here leaves orphans.
extends GdUnitTestSuite


# ---- fixtures --------------------------------------------------------------

# Builds a real BattleState (full Board + write-guard wiring, exactly as
# BattleState.create() always has) from a minimal 2-unit roster. Empty
# terrain is valid input (Board.from_ascii() defaults every unset tile to
# TERRAIN_OPEN) — same precedent as movement_range_query_test.gd's
# sensitivity-proof fixture.
func _build(attacker_line: String, target_line: String) -> BattleState:
	return BattleState.create(PackedStringArray(), attacker_line + "\n" + target_line)


# =============================================================================
# 1. 拆解欄位完整性(AC 對照 / QA 案例一):ATK=12, DEF=8, Φ=+3 -> 傷害=7
# =============================================================================

func test_breakdown_returns_all_five_fields_with_correct_values() -> void:
	# Arrange — QA 案例逐字數字
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,8,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 3)

	# Assert
	assert_int(result.breakdown["atk"]).is_equal(12)
	assert_int(result.breakdown["def"]).is_equal(8)
	assert_int(result.breakdown["phi"]).is_equal(3)
	assert_int(result.breakdown["phi_input"]).is_equal(3)
	assert_int(result.breakdown["damage"]).is_equal(7)
	assert_int(result.breakdown["target_hp_after"]).is_equal(20 - 7)


# =============================================================================
# 2. Φ=0 仍可讀(Visual/Audio §2 對照 / QA 案例二)
# =============================================================================

func test_phi_zero_key_still_present() -> void:
	# Arrange
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,8,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 0)

	# Assert — 鍵必須存在,值必須恰好是 0,不得省略或以空值代替
	assert_bool(result.breakdown.has("phi")).is_true()
	assert_int(result.breakdown["phi"]).is_equal(0)


# =============================================================================
# 3. 極端正值無截斷(QA 案例三)
# =============================================================================

func test_phi_large_positive_no_truncation() -> void:
	# Arrange — Φ=+500,目標 HP 夠高以避免與夾限邏輯混淆(那是另一條測試的範圍)
	var state: BattleState = _build(
		"1,P1,PLAYER,999,1,0,3,1,1,0,0",
		"2,E1,ENEMY,999,0,1,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 500)

	# Assert — 1 - 1 + 500 = 500,無任何截斷或溢位
	assert_int(result.breakdown["damage"]).is_equal(500)
	assert_int(result.breakdown["target_hp_after"]).is_equal(999 - 500)


# =============================================================================
# 4. 極端負值 -> 傷害夾在 0 下界
# =============================================================================

func test_phi_extreme_negative_damage_floored_at_zero() -> void:
	# Arrange — ATK=5, DEF=20, Φ=-500 -> raw = -515,必須夾在 0
	var state: BattleState = _build(
		"1,P1,PLAYER,20,5,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,20,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, -500)

	# Assert
	assert_int(result.breakdown["damage"]).is_equal(0)
	assert_int(result.breakdown["target_hp_after"]).is_equal(20)


# =============================================================================
# 4b. 傷害超過目標當前 HP -> target_hp_after 夾在 0(設計選擇,見
#     battle_state.gd preview_damage_breakdown() 文件註解:回報「結算後 HP」
#     必須與 Unit.take_damage() 的真實下限一致,不得回報負數)
# =============================================================================

func test_target_hp_after_clamped_at_zero_on_overkill() -> void:
	# Arrange — 傷害(12-0+0=12)遠超目標當前 HP(5)
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,5,0,0,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 0)

	# Assert
	assert_int(result.breakdown["damage"]).is_equal(12)
	assert_int(result.breakdown["target_hp_after"]).is_equal(0)


# =============================================================================
# 5. ENEMY 攻擊方 -> Φ 歸零,phi_input 保留原值(協調者裁決二)
# =============================================================================

func test_enemy_attacker_phi_zeroed_but_phi_input_preserved() -> void:
	# Arrange — 攻擊方改為 ENEMY,其餘數值與案例一相同
	var state: BattleState = _build(
		"1,E1,ENEMY,20,12,0,0,1,1,0,0",
		"2,P1,PLAYER,20,0,8,3,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 3)

	# Assert — phi 已歸零(ENEMY 攻擊方規則,resolve_attack() 既有行為),
	# phi_input 保留呼叫端原始傳入值,兩者此時不同
	assert_int(result.breakdown["phi"]).is_equal(0)
	assert_int(result.breakdown["phi_input"]).is_equal(3)
	assert_int(result.breakdown["damage"]).is_equal(4)  # 12 - 8 + 0


# =============================================================================
# 6. 零寫入驗證(QA 案例四)
# =============================================================================

func test_zero_write_no_state_mutation() -> void:
	# Arrange
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,8,0,1,1,5,5",
	)
	var version_before: int = state.combat_state_version
	var hp_before: int = state.unit_by_id(2).hp
	var occupant_before: int = state.board.get_occupant(Vector2i(5, 5))
	var position_before: Vector2i = state.position_of(2)

	# Act — 呼叫多次,模擬 UI 預判模式每幀重複查詢
	state.preview_damage_breakdown(1, 2, 3)
	state.preview_damage_breakdown(1, 2, -500)
	state.preview_damage_breakdown(1, 2, 0)

	# Assert — 全部完全相同
	assert_int(state.combat_state_version).is_equal(version_before)
	assert_int(state.unit_by_id(2).hp).is_equal(hp_before)
	assert_int(state.board.get_occupant(Vector2i(5, 5))).is_equal(occupant_before)
	assert_vector(state.position_of(2)).is_equal(position_before)


# =============================================================================
# 7. 回傳的 damage 與 preview_damage() 逐值相同(證明共用同一條路徑)
# =============================================================================

func test_damage_matches_preview_damage_same_inputs() -> void:
	# Arrange
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,8,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 7)
	var legacy_result: int = state.preview_damage(1, 2, 7)

	# Assert
	assert_int(result.breakdown["damage"]).is_equal(legacy_result)


# =============================================================================
# 8. QueryResult.version 反映當下 combat_state_version(ADR-0001 即時性義務)
# =============================================================================

func test_result_version_reflects_current_combat_state_version() -> void:
	# Arrange
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,8,0,1,1,5,5",
	)

	# Act / Assert — 尚未有任何已提交變化:版本號為 0
	var result_before: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 3)
	assert_int(result_before.version).is_equal(0)
	assert_int(result_before.version).is_equal(state.combat_state_version)

	# Act — 觸發一次已提交的變化(實際結算一次攻擊,bump 版本號)
	state.resolve_attack(1, 2, 3)

	# Assert — 新查詢必須反映新版本號,不得沿用舊值
	var result_after: DamageBreakdownResult = state.preview_damage_breakdown(1, 2, 3)
	assert_int(result_after.version).is_equal(state.combat_state_version)
	assert_int(result_after.version).is_greater(result_before.version)
	assert_bool(result_before.is_stale()).is_true()
	assert_bool(result_after.is_stale()).is_false()


# =============================================================================
# 9. 查無單位時的行為(絕不 assert():見 .claude/docs/coding-standards.md
#    2026-09-15 條目)—— 回傳 null,不得回傳夾帶零值的「假成功」結果
# =============================================================================

func test_unknown_attacker_id_returns_null() -> void:
	# Arrange
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,8,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(999, 2, 3)

	# Assert — null,不是帶著 0 值的結果物件(兩者不可混淆)
	assert_object(result).is_null()


func test_unknown_target_id_returns_null() -> void:
	# Arrange
	var state: BattleState = _build(
		"1,P1,PLAYER,20,12,0,3,1,1,0,0",
		"2,E1,ENEMY,20,0,8,0,1,1,5,5",
	)

	# Act
	var result: DamageBreakdownResult = state.preview_damage_breakdown(1, 999, 3)

	# Assert
	assert_object(result).is_null()


# =============================================================================
# 敏感度證明
# =============================================================================

# 間諜子類別 1 —— 重現硬性要求明文禁止的反模式:在 preview_damage_breakdown()
# 裡直接重新實作 max(0, atk-def+phi),而非透過共用的 _attack_damage_breakdown()/
# _compute_attack_damage()。這個反模式最容易忘記的,正是 ENEMY 攻擊方必須把 Φ
# 歸零的規則 —— 這是「同一條公式兩份實作、只是今天答案一致」這個本專案已登記過的
# 失效模式的具體示範。
#
# 建構手法:不透過 BattleState.create()(它是 static method,內部寫死呼叫
# `BattleState.new()`,無法產生子類別實例),改為直接組裝 _units —— GDScript
# 沒有真正的存取限制,底線開頭只是慣例,外部腳本可直接讀寫,movement_range_
# query_test.gd 的 _MutantBypassesMoveLegalityCheck 已是同一手法的先例
# (直接存取 _state.board / _state._positions)。本測試只呼叫
# preview_damage_breakdown()/preview_damage(),兩者都只讀 _units 與
# combat_state_version,不需要 board,因此略過 board/write-guard 設置是安全的。
#
# 🔴 override 的回傳型別必須與基底類別完全一致(DamageBreakdownResult),否則
# GdUnit4 測試收集階段會以 Parse Error 中止(exit 105,見
# .claude/docs/coding-standards.md 的「Exit code 105」條目)。
class _MutantReimplementsFormulaWithoutEnemyPhiZeroing extends BattleState:
	func preview_damage_breakdown(attacker_id: int, target_id: int, phi: int) -> DamageBreakdownResult:
		var attacker: Unit = unit_by_id(attacker_id)
		var target: Unit = unit_by_id(target_id)
		var atk: int = attacker.effective_atk()
		var def: int = target.effective_def()
		# BUG: 不像 _attack_damage_breakdown() 那樣在 ENEMY 攻擊方時把 phi 歸零。
		var dealt: int = maxi(0, atk - def + phi)
		return DamageBreakdownResult.new(self, {
			"atk": atk,
			"def": def,
			"phi": phi,
			"phi_input": phi,
			"damage": dealt,
			"target_hp_after": maxi(0, target.hp - dealt),
		})


func _build_mutant_a(roster_text: String) -> _MutantReimplementsFormulaWithoutEnemyPhiZeroing:
	var state: _MutantReimplementsFormulaWithoutEnemyPhiZeroing = (
		_MutantReimplementsFormulaWithoutEnemyPhiZeroing.new()
	)
	for unit: Unit in Unit.roster_from_text(roster_text):
		state._units[unit.id] = unit
	return state


func test_sensitivity_proof_duplicated_formula_divergence_caught() -> void:
	# Arrange — ENEMY 攻擊方,真正的路徑會把 Φ 歸零(resolve_attack()/
	# preview_damage() 既有規則)
	var roster_text: String = (
		"1,E1,ENEMY,20,12,0,0,1,1,0,0\n"
		+ "2,P1,PLAYER,20,0,8,3,1,1,5,5\n"
	)
	var mutant: _MutantReimplementsFormulaWithoutEnemyPhiZeroing = _build_mutant_a(roster_text)

	# Ground truth — 這個 mutant 繼承、未覆寫的真正 preview_damage() 仍會把
	# ENEMY 攻擊方的 Φ 歸零。
	var trusted_damage: int = mutant.preview_damage(1, 2, 3)
	assert_int(trusted_damage).is_equal(4)  # 12 - 8 + 0(歸零後)

	# Act — mutant 自己覆寫的 preview_damage_breakdown() 重新實作了公式,
	# 忘記歸零規則。
	var result: DamageBreakdownResult = mutant.preview_damage_breakdown(1, 2, 3)

	# Assert — 證明若正式程式碼真的這樣重新實作,
	# test_damage_matches_preview_damage_same_inputs() 與
	# test_enemy_attacker_phi_zeroed_but_phi_input_preserved() 的斷言真的會
	# 被踩中:這裡 damage=7、phi=3,與信任路徑的 4/0 不同,不是巧合同值。
	assert_int(result.breakdown["damage"]).is_not_equal(trusted_damage)
	assert_int(result.breakdown["damage"]).is_equal(7)
	assert_int(result.breakdown["phi"]).is_equal(3)


# 間諜子類別 2 —— 重現 AC「Φ=0 仍須可讀」明文禁止的反模式:把「省略零值」當成
# 一種無害的最佳化,在 phi 剛好等於 0 時整個拔掉這個鍵。
class _MutantOmitsPhiKeyWhenZero extends BattleState:
	func preview_damage_breakdown(attacker_id: int, target_id: int, phi: int) -> DamageBreakdownResult:
		var breakdown: Dictionary = _attack_damage_breakdown(attacker_id, target_id, phi)
		var target: Unit = unit_by_id(target_id)
		var dealt: int = int(breakdown["damage"])
		breakdown["target_hp_after"] = maxi(0, target.hp - dealt)
		# BUG: 把 Φ=0 當成「不值得回傳」,違反 AC「Φ=0 仍須可讀,不得省略」。
		if int(breakdown["phi"]) == 0:
			breakdown.erase("phi")
		return DamageBreakdownResult.new(self, breakdown)


func _build_mutant_b(roster_text: String) -> _MutantOmitsPhiKeyWhenZero:
	var state: _MutantOmitsPhiKeyWhenZero = _MutantOmitsPhiKeyWhenZero.new()
	for unit: Unit in Unit.roster_from_text(roster_text):
		state._units[unit.id] = unit
	return state


func test_sensitivity_proof_missing_phi_key_caught() -> void:
	# Arrange
	var roster_text: String = (
		"1,P1,PLAYER,20,12,0,3,1,1,0,0\n"
		+ "2,E1,ENEMY,20,0,8,0,1,1,5,5\n"
	)
	var mutant: _MutantOmitsPhiKeyWhenZero = _build_mutant_b(roster_text)

	# Act
	var result: DamageBreakdownResult = mutant.preview_damage_breakdown(1, 2, 0)

	# Assert — 證明若正式程式碼真的這樣「省略零值」,
	# test_phi_zero_key_still_present() 的斷言
	# (assert_bool(result.breakdown.has("phi")).is_true())真的會被踩中:這裡該鍵
	# 不存在,不是巧合同值。
	assert_bool(result.breakdown.has("phi")).is_false()
