# Unit（src/gameplay/units/unit.gd）的單元測試。
#
# 純資料類別（RefCounted），不建立任何 Node，也不需要 tear-down，
# 不會留下孤兒節點。命名慣例沿用既有先例
# tests/unit/gameplay/combat/combat_rules_test.gd 的 test_[scenario]_[expected]。
#
# 🔴 本檔只測資料解析與 hp 夾值，不測任何戰鬥數學（傷害、射程判定、敵方數值
# 縮放）—— 那些屬於 CombatRules，已有 tests/unit/gameplay/combat/combat_rules_test.gd。
extends GdUnitTestSuite


# ---- from_csv_line() ------------------------------------------------------

func test_from_csv_line_parses_jia_every_field_correctly() -> void:
	# Arrange — 名冊第一行，甲
	var line: String = "1,甲,PLAYER,30,16,8,6,1,1,0,2"

	# Act
	var unit: Unit = Unit.from_csv_line(line)

	# Assert
	assert_int(unit.id).is_equal(1)
	assert_str(unit.code_name).is_equal("甲")
	assert_int(unit.faction).is_equal(Unit.Faction.PLAYER)
	assert_int(unit.hp_max).is_equal(30)
	assert_int(unit.atk).is_equal(16)
	assert_int(unit.def).is_equal(8)
	assert_int(unit.mp).is_equal(6)
	assert_int(unit.min_range).is_equal(1)
	assert_int(unit.max_range).is_equal(1)
	assert_vector(unit.start_pos).is_equal(Vector2i(0, 2))


func test_from_csv_line_initializes_hp_equal_to_hp_max() -> void:
	# Arrange — E1 分級後的數值（見 vs01_roster.txt）
	var line: String = "6,E1,ENEMY,36,20,10,6,1,1,10,0"

	# Act
	var unit: Unit = Unit.from_csv_line(line)

	# Assert
	assert_int(unit.hp).is_equal(unit.hp_max)
	assert_int(unit.hp).is_equal(36)


func test_from_csv_line_parses_enemy_faction() -> void:
	# Arrange — 只測 faction 解析，數值不是重點，用明顯的測試夾具而非真實敵人資料
	var line: String = "7,TEST_B,ENEMY,10,10,10,5,1,2,11,1"

	# Act
	var unit: Unit = Unit.from_csv_line(line)

	# Assert
	assert_int(unit.faction).is_equal(Unit.Faction.ENEMY)


func test_from_csv_line_bing_start_pos_and_range() -> void:
	# Arrange — 丙：start_pos 應為 (1, 3)，射程 min/max 為 2/4
	var line: String = "3,丙,PLAYER,22,20,4,3,2,4,1,3"

	# Act
	var unit: Unit = Unit.from_csv_line(line)

	# Assert
	assert_vector(unit.start_pos).is_equal(Vector2i(1, 3))
	assert_int(unit.min_range).is_equal(2)
	assert_int(unit.max_range).is_equal(4)


# ---- roster_from_text() ---------------------------------------------------

func test_roster_from_text_parses_full_roster_returns_ten_units() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string("res://assets/data/units/vs01_roster.txt")
	assert_str(text).is_not_empty()

	# Act
	var roster: Array[Unit] = Unit.roster_from_text(text)

	# Assert
	assert_array(roster).has_size(10)


func test_roster_from_text_skips_comment_and_blank_lines() -> void:
	# Arrange — 混入註解行與空行，只有兩行是真正資料
	var text: String = (
		"# this is a comment\n"
		+ "\n"
		+ "1,甲,PLAYER,30,16,8,6,1,1,0,2\n"
		+ "   \n"
		+ "# another comment\n"
		+ "2,乙,PLAYER,26,14,6,5,1,2,0,3\n"
	)

	# Act
	var roster: Array[Unit] = Unit.roster_from_text(text)

	# Assert
	assert_array(roster).has_size(2)
	assert_str(roster[0].code_name).is_equal("甲")
	assert_str(roster[1].code_name).is_equal("乙")


func test_roster_from_text_loads_vs01_roster_file_without_crashing() -> void:
	# Arrange — 讀實際會放在 assets/data/units 的名冊資料檔，
	# 沿用 tests/unit/gameplay/board/board_test.gd 讀檔測試的既有先例
	var file: FileAccess = FileAccess.open(
		"res://assets/data/units/vs01_roster.txt", FileAccess.READ
	)
	assert_object(file).is_not_null()
	var text: String = file.get_as_text()
	file.close()

	# Act
	var roster: Array[Unit] = Unit.roster_from_text(text)

	# Assert
	assert_array(roster).has_size(10)
	assert_int(roster[9].id).is_equal(10)
	assert_str(roster[9].code_name).is_equal("E5")


func test_roster_from_text_enemy_hp_max_values_are_all_distinct() -> void:
	# 迴歸測試 — 修這次之前，五隻敵人的數值完全相同（33/20/8），是本次要修的缺陷。
	# 沒有這個測試守著，下次重算數值時可能又塌回同一組數字而沒人發現。
	# Arrange
	var text: String = FileAccess.get_file_as_string("res://assets/data/units/vs01_roster.txt")
	var roster: Array[Unit] = Unit.roster_from_text(text)

	# Act — 收集所有敵人的 hp_max
	var enemies_by_code: Dictionary = {}
	var enemy_hp_values: Array[int] = []
	for unit in roster:
		if unit.faction == Unit.Faction.ENEMY:
			enemies_by_code[unit.code_name] = unit
			enemy_hp_values.append(unit.hp_max)

	var unique_hp_values: Dictionary = {}
	for hp_value in enemy_hp_values:
		unique_hp_values[hp_value] = true

	# Assert — 五隻敵人，hp_max 互不相同
	assert_array(enemy_hp_values).has_size(5)
	assert_int(unique_hp_values.size()).is_equal(5)

	# Assert — E5 最大、E3 最小
	var e3: Unit = enemies_by_code["E3"]
	var e5: Unit = enemies_by_code["E5"]
	for hp_value in enemy_hp_values:
		if hp_value != e5.hp_max:
			assert_int(e5.hp_max).is_greater(hp_value)
		if hp_value != e3.hp_max:
			assert_int(e3.hp_max).is_less(hp_value)


# ---- is_alive() / take_damage() -------------------------------------------

func test_take_damage_clamps_at_zero_never_negative() -> void:
	# Arrange — hp_max 30，打 999 點應夾在 0，絕不變負數
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")

	# Act
	unit.take_damage(999)

	# Assert
	assert_int(unit.hp).is_equal(0)
	assert_bool(unit.is_alive()).is_false()


func test_take_damage_exact_amount_reaches_zero() -> void:
	# Arrange — hp_max 30，剛好打滿 30 點
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")

	# Act
	unit.take_damage(30)

	# Assert
	assert_int(unit.hp).is_equal(0)
	assert_bool(unit.is_alive()).is_false()


func test_take_damage_partial_amount_keeps_unit_alive() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")

	# Act
	unit.take_damage(10)

	# Assert
	assert_int(unit.hp).is_equal(20)
	assert_bool(unit.is_alive()).is_true()


func test_is_alive_true_immediately_after_construction() -> void:
	# Arrange & Act — 只測 is_alive()，數值不是重點，用明顯的測試夾具而非真實敵人資料
	var unit: Unit = Unit.from_csv_line("6,TEST_A,ENEMY,10,10,10,6,1,1,10,0")

	# Assert
	assert_bool(unit.is_alive()).is_true()
