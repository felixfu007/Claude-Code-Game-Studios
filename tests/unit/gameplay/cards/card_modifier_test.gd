# CardModifier / CardModifierRules（src/gameplay/cards/）與
# Unit.effective_atk()/effective_def()/add_modifier()/active_modifiers()
# 的單元測試。對應 production/epics/skill-card-system/story-001-modifier-model.md。
#
# 純資料/純函式測試 —— CardModifier、CardModifierRules、Unit 全部是 RefCounted，
# 不建立任何 Node，也不需要 tear-down，不會留下孤兒節點。AC-2 額外用一份最小的
# BattleState（兩個測試替身單位，1x2 開闊地形，不涉及任何真實名冊/地形資料）
# 走到生產程式碼唯一的傷害入口 BattleState.resolve_attack()，不在測試裡重算
# atk-def+phi 這條公式。
#
# 命名慣例沿用既有先例 tests/unit/gameplay/combat/combat_rules_test.gd 的
# test_[scenario]_[expected]。每個測試自建自拆，不共用可變狀態，因此不依賴
# 執行順序。
extends GdUnitTestSuite


# 建一個乾淨的測試替身單位，數值刻意簡單、與任何真實名冊資料無關。
func _dummy_unit(atk: int, def: int) -> Unit:
	return Unit.from_csv_line("1,DUMMY,PLAYER,10,%d,%d,1,1,1,0,0" % [atk, def])


# ---- AC-1:逐條加總,不取最大 ------------------------------------------------

func test_ac1_two_modifiers_sum_by_addition_not_max() -> void:
	# Arrange — 基準 ATK=10,掛兩個修正 +2、+3
	var unit: Unit = _dummy_unit(10, 5)
	unit.add_modifier(CardModifier.new("card_a", 2, 0, 1))
	unit.add_modifier(CardModifier.new("card_b", 3, 0, 1))

	# Act
	var effective: int = unit.effective_atk()

	# Assert — 10 + (2+3) = 15,不是 10 + max(2,3) = 13
	assert_int(effective).is_equal(15)


# ---- AC-2:減益溢出不轉傷害,Φ 與攻擊方 ATK 鎖死 -----------------------------
#
# 攻擊方 ATK_base=6 無修正;防禦方 DEF_base=3 受 -5 減益(夾限至 -3,DEF_eff=0);
# Φ 以字面 0 傳入 resolve_attack() —— 這是本測試唯一需要的「鎖死」手段:
# BattleState.resolve_attack() 的 phi 是呼叫端直接傳入的參數,並非本測試場景
# 內部由好感度系統推算而來,不存在任何路徑能讓好感度資料悄悄改動它。
# 兩個單位是全新的測試替身(id 1/2,PLAYER/ENEMY),與任何真實名冊/關係線資料
# 無關,滿足「以測試替身或無關係線的單位隔離」的要求。

func _build_ac2_state() -> BattleState:
	var terrain_rows: PackedStringArray = PackedStringArray([
		"..",
		"..",
	])
	var roster_text: String = (
		"1,ATTACKER,PLAYER,10,6,0,1,1,1,0,0\n"
		+ "2,TARGET,ENEMY,10,0,3,1,1,1,1,0\n"
	)
	return BattleState.create(terrain_rows, roster_text)


func test_ac2_debuff_overflow_does_not_translate_into_extra_damage() -> void:
	# Arrange
	var state: BattleState = _build_ac2_state()
	var attacker: Unit = state.unit_by_id(1)
	var target: Unit = state.unit_by_id(2)
	target.add_modifier(CardModifier.new("test_debuff", 0, -5, 1))

	# Act — Φ 鎖死為字面 0;攻擊方無任何修正,ATK 鎖死為基準值 6
	var effective_def: int = target.effective_def()
	var dealt: int = state.resolve_attack(1, 2, 0)

	# Assert — DEF_eff 夾在 0(不是負值),傷害恰為 6,不多不少
	assert_int(attacker.effective_atk()).is_equal(6)
	assert_int(effective_def).is_equal(0)
	assert_int(dealt).is_equal(6)


# ---- 逐條可讀的查詢(GDD OQ-12)----------------------------------------------

func test_active_modifiers_reports_source_signed_values_and_remaining_turns() -> void:
	# Arrange
	var unit: Unit = _dummy_unit(10, 5)
	unit.add_modifier(CardModifier.new("card_atk_up", 2, 0, 2))
	unit.add_modifier(CardModifier.new("card_def_down", 0, -1, 1))

	# Act
	var entries: Array[CardModifier] = unit.active_modifiers()

	# Assert — 逐條可讀,順序與掛載順序一致
	assert_int(entries.size()).is_equal(2)
	assert_str(entries[0].source_name).is_equal("card_atk_up")
	assert_int(entries[0].atk_delta).is_equal(2)
	assert_int(entries[0].def_delta).is_equal(0)
	assert_int(entries[0].remaining_turns).is_equal(2)
	assert_str(entries[1].source_name).is_equal("card_def_down")
	assert_int(entries[1].atk_delta).is_equal(0)
	assert_int(entries[1].def_delta).is_equal(-1)
	assert_int(entries[1].remaining_turns).is_equal(1)


func test_active_modifiers_returned_array_is_read_only_copy() -> void:
	# Arrange
	var unit: Unit = _dummy_unit(10, 5)
	unit.add_modifier(CardModifier.new("card_a", 2, 0, 1))

	# Act — 拿到查詢結果後,對回傳的陣列與其中的物件動手腳
	var entries: Array[CardModifier] = unit.active_modifiers()
	entries.append(CardModifier.new("injected", 999, 0, 1))
	entries[0].atk_delta = 999

	# Assert — 內部狀態完全沒被上面兩個動作影響
	var entries_again: Array[CardModifier] = unit.active_modifiers()
	assert_int(entries_again.size()).is_equal(1)
	assert_int(entries_again[0].atk_delta).is_equal(2)
	assert_int(unit.effective_atk()).is_equal(12)


# ---- 補測:甲類修正隨宿主單位陣亡消失 ---------------------------------------

func test_supplementary_modifiers_vanish_when_host_dies() -> void:
	# Arrange
	var unit: Unit = _dummy_unit(10, 5)
	unit.add_modifier(CardModifier.new("card_a", 3, 0, 1))
	assert_int(unit.effective_atk()).is_equal(13)

	# Act — 打到 hp 剛好歸零
	unit.take_damage(10)

	# Assert — is_alive() 為 false,且沒有任何路徑仍讀得到那條修正
	assert_bool(unit.is_alive()).is_false()
	assert_int(unit.active_modifiers().size()).is_equal(0)
	assert_int(unit.effective_atk()).is_equal(10)


func test_supplementary_modifiers_survive_non_lethal_damage() -> void:
	# 對照組 —— 只要單位還活著,修正不該被意外清掉
	# Arrange
	var unit: Unit = _dummy_unit(10, 5)
	unit.add_modifier(CardModifier.new("card_a", 3, 0, 1))

	# Act
	unit.take_damage(1)

	# Assert
	assert_bool(unit.is_alive()).is_true()
	assert_int(unit.active_modifiers().size()).is_equal(1)
	assert_int(unit.effective_atk()).is_equal(13)


# ---- 補測:累計夾限真的會夾 --------------------------------------------------

func test_supplementary_clamp_caps_atk_sum_at_plus_six() -> void:
	# Arrange — 掛四張 +3(Σ=+12)
	var unit: Unit = _dummy_unit(10, 5)
	for i: int in range(4):
		unit.add_modifier(CardModifier.new("card_%d" % i, 3, 0, 1))

	# Act / Assert — 只加 +6:10 + clamp(12, -4, 6) = 16
	assert_int(unit.effective_atk()).is_equal(16)


func test_supplementary_clamp_caps_atk_sum_at_minus_four() -> void:
	# Arrange — 掛三張 -3(Σ=-9)
	var unit: Unit = _dummy_unit(10, 5)
	for i: int in range(3):
		unit.add_modifier(CardModifier.new("card_%d" % i, -3, 0, 1))

	# Act / Assert — 只減 -4:10 + clamp(-9, -4, 6) = 6
	assert_int(unit.effective_atk()).is_equal(6)


func test_supplementary_clamp_caps_def_sum_at_plus_four() -> void:
	# Arrange — DEF 側夾限較窄:[-3, +4]。掛三張 +2(Σ=+6)
	var unit: Unit = _dummy_unit(10, 5)
	for i: int in range(3):
		unit.add_modifier(CardModifier.new("card_%d" % i, 0, 2, 1))

	# Act / Assert — 只加 +4:5 + clamp(6, -3, 4) = 9
	assert_int(unit.effective_def()).is_equal(9)


func test_supplementary_clamp_caps_def_sum_at_minus_three() -> void:
	# Arrange — 掛兩張 -2(Σ=-4)
	var unit: Unit = _dummy_unit(10, 5)
	for i: int in range(2):
		unit.add_modifier(CardModifier.new("card_%d" % i, 0, -2, 1))

	# Act / Assert — 只減 -3:5 + clamp(-4, -3, 4) = 2
	assert_int(unit.effective_def()).is_equal(2)


func test_effective_atk_floors_at_zero_when_debuff_exceeds_base() -> void:
	# Arrange — 基準 ATK=2,減益 -4(在夾限範圍內,未被夾限本身擋下)
	var unit: Unit = _dummy_unit(2, 5)
	unit.add_modifier(CardModifier.new("card_debuff", -4, 0, 1))

	# Act / Assert — max(0, 2-4) = 0,不是負數
	assert_int(unit.effective_atk()).is_equal(0)


func test_effective_def_floors_at_zero_when_debuff_exceeds_base() -> void:
	# Arrange — 基準 DEF=2,減益 -3
	var unit: Unit = _dummy_unit(10, 2)
	unit.add_modifier(CardModifier.new("card_debuff", 0, -3, 1))

	# Act / Assert
	assert_int(unit.effective_def()).is_equal(0)


# ---- 補測:基準欄位全程不變 --------------------------------------------------

func test_supplementary_base_fields_unchanged_after_modifiers_and_clamping() -> void:
	# Arrange — 用真實名冊數值(甲),掛超過夾限的修正並反覆查詢
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")
	var atk_before: int = unit.atk
	var def_before: int = unit.def
	for i: int in range(4):
		unit.add_modifier(CardModifier.new("atk_up_%d" % i, 3, 0, 1))
	for i: int in range(3):
		unit.add_modifier(CardModifier.new("def_down_%d" % i, 0, -3, 1))

	# Act — 反覆查詢有效值(不得就地改動基準欄位)
	unit.effective_atk()
	unit.effective_atk()
	unit.effective_def()

	# Assert — atk/def 與初始值逐字相同
	assert_int(unit.atk).is_equal(atk_before)
	assert_int(unit.atk).is_equal(16)
	assert_int(unit.def).is_equal(def_before)
	assert_int(unit.def).is_equal(8)


# ---- CardModifierRules:純函式底層行為(不經過 Unit)---------------------------

func test_card_modifier_rules_effective_atk_sums_modifiers() -> void:
	var modifiers: Array[CardModifier] = [
		CardModifier.new("a", 2, 0, 1),
		CardModifier.new("b", 3, 0, 1),
	]
	assert_int(CardModifierRules.effective_atk(10, modifiers)).is_equal(15)


func test_card_modifier_rules_empty_modifiers_returns_base_unchanged() -> void:
	var modifiers: Array[CardModifier] = []
	assert_int(CardModifierRules.effective_atk(7, modifiers)).is_equal(7)
	assert_int(CardModifierRules.effective_def(4, modifiers)).is_equal(4)


func test_card_modifier_rules_effective_def_clamps_upper_bound() -> void:
	# Σ=+6,DEF 側上界為 +4
	var modifiers: Array[CardModifier] = [
		CardModifier.new("a", 0, 3, 1),
		CardModifier.new("b", 0, 3, 1),
	]
	assert_int(CardModifierRules.effective_def(5, modifiers)).is_equal(9)


func test_card_modifier_rules_effective_def_clamps_lower_bound() -> void:
	# Σ=-4,DEF 側下界為 -3
	var modifiers: Array[CardModifier] = [
		CardModifier.new("a", 0, -2, 1),
		CardModifier.new("b", 0, -2, 1),
	]
	assert_int(CardModifierRules.effective_def(5, modifiers)).is_equal(2)


func test_card_modifier_clone_returns_independent_instance_with_same_values() -> void:
	# Arrange
	var original: CardModifier = CardModifier.new("card_x", 2, -1, 2)

	# Act
	var cloned: CardModifier = original.clone()
	cloned.atk_delta = 999

	# Assert — clone 出來的是獨立實例,改它不影響原本那個
	assert_str(cloned.source_name).is_equal("card_x")
	assert_int(cloned.def_delta).is_equal(-1)
	assert_int(cloned.remaining_turns).is_equal(2)
	assert_int(original.atk_delta).is_equal(2)
