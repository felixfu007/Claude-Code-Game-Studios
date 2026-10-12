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


# 2026-09-16 管理者裁決(產出於 PROJECT-STATUS.md「等你裁決」第二項):名冊未知
# 陣營字串一律「響亮地停」,不得靜默落回列舉序數 0
# (.claude/docs/coding-standards.md 2026-09-15 條目所禁止的
# assert(false)+return 序數0 寫法,兩者恰好都是 0 == Faction.PLAYER,今天測不出
# 行為差異,但陣營欄打錯字會被靜默當成我方單位)。
func test_from_csv_line_unknown_faction_returns_null() -> void:
	# Arrange — faction 欄位打錯字(例如把 ENEMY 拼錯)
	var line: String = "7,丁,ENEMEY,10,10,10,5,1,2,11,1"

	# Act
	var unit: Unit = Unit.from_csv_line(line)

	# Assert
	assert_object(unit).is_null()


# ---- roster_from_text() ---------------------------------------------------

func test_roster_from_text_parses_full_roster_returns_ten_units() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string("res://assets/data/units/vs01_roster.txt")
	assert_str(text).is_not_empty()

	# Act
	var roster: Array[Unit] = Unit.roster_from_text(text)

	# Assert
	assert_array(roster).has_size(10)


# 迴歸測試(2026-09-16 裁決)— 見 test_from_csv_line_unknown_faction_returns_null()
# 的裁決背景。這裡鎖住 roster_from_text() 這一層的行為:一列打錯字,不是只丟掉
# 那一列,是整份名冊當作解析失敗、回傳空陣列 —— 這正是讓 battle_screen.gd 的
# _ready() 判為 LoadFailure.PARSED_EMPTY、整個畫面停掉的那個條件(見
# tests/unit/ui/battle_screen_load_guard_test.gd 對同一條鏈路的驗證)。刻意在
# 打錯字那一列前後各放一個合法列,證明合法列不會被誤留下來。
func test_roster_from_text_unknown_faction_discards_entire_roster() -> void:
	# Arrange
	var text: String = (
		"1,甲,PLAYER,30,16,8,6,1,1,0,2\n"
		+ "7,丁,ENEMEY,10,10,10,5,1,2,11,1\n"
		+ "2,乙,PLAYER,26,14,6,5,1,2,0,3\n"
	)

	# Act
	var roster: Array[Unit] = Unit.roster_from_text(text)

	# Assert — 不是 2(只丟壞列)也不是 1(只留一筆),必須是 0(整份名冊作廢)
	assert_int(roster.size()).is_equal(0)


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


# ---- effective_atk() / effective_def() (base/effective value seam) --------
#
# 🔴 更新(story-001-modifier-model.md,skill-card-system #6):修正來源
# (CardModifier/CardModifierRules)已經存在。以下兩條測試只鎖住「一張修正都
# 沒掛」這個特例(effective == base 是 CardModifierRules 對空清單的自然結果,
# 不是 Unit 特別為了這個案例寫的分支)。掛了修正之後的加總/夾限/下限行為屬於
# CardModifierRules 的職責,測試在
# tests/unit/gameplay/cards/card_modifier_test.gd,不在本檔重複。

func test_effective_atk_equals_base_atk_with_no_modifier_source() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")

	# Act / Assert
	assert_int(unit.effective_atk()).is_equal(unit.atk)
	assert_int(unit.effective_atk()).is_equal(16)


func test_effective_def_equals_base_def_with_no_modifier_source() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")

	# Act / Assert
	assert_int(unit.effective_def()).is_equal(unit.def)
	assert_int(unit.effective_def()).is_equal(8)


# ---- stat_access_view() (story-006-atk-def-phi-breakdown-query.md — #6
# skill-card-system's registered reverse dependency) -----------------------
#
# 🔴 HP/MP 不與 ATK/DEF 同構,不得類推套用(GDD 明文)——以下四組測試刻意
# 分開驗證,不假設任何一組的通過可以代表其他組也對。

func test_stat_access_view_atk_def_base_equals_effective_with_no_modifier() -> void:
	# Arrange
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")

	# Act
	var view: Dictionary = unit.stat_access_view()

	# Assert
	assert_int(view["atk"]["base"]).is_equal(16)
	assert_int(view["atk"]["effective"]).is_equal(unit.effective_atk())
	assert_int(view["def"]["base"]).is_equal(8)
	assert_int(view["def"]["effective"]).is_equal(unit.effective_def())


func test_stat_access_view_hp_base_is_hp_max_effective_is_current_hp() -> void:
	# Arrange — hp_max 30,扣 10 點後當前 hp 應為 20,base 仍是 30(不隨 take_damage 改變)
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")
	unit.take_damage(10)

	# Act
	var view: Dictionary = unit.stat_access_view()

	# Assert
	assert_int(view["hp"]["base"]).is_equal(30)
	assert_int(view["hp"]["effective"]).is_equal(20)
	assert_int(view["hp"]["effective"]).is_equal(unit.hp)


func test_stat_access_view_mp_base_equals_effective_always() -> void:
	# Arrange — 今天沒有任何 MP 修正機制(已查證 grep -rn "\.mp\b"
	# src/gameplay/cards/ 零命中),base 必須恆等於 effective
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")

	# Act
	var view: Dictionary = unit.stat_access_view()

	# Assert
	assert_int(view["mp"]["base"]).is_equal(6)
	assert_int(view["mp"]["effective"]).is_equal(6)


func test_stat_access_view_returns_fresh_dictionary_each_call() -> void:
	# Arrange — 證明每次呼叫都是新建的 Dictionary,不是同一個內部容器的參照
	var unit: Unit = Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2")
	var first: Dictionary = unit.stat_access_view()

	# Act — 竄改第一次拿到的回傳值
	first["atk"]["base"] = 999999

	# Assert — 第二次呼叫不受影響
	var second: Dictionary = unit.stat_access_view()
	assert_int(second["atk"]["base"]).is_equal(16)


# ---- stat_access_view() 敏感度證明 -----------------------------------------

# 間諜子類別 —— 重現本方法文件註解明文警告的錯誤:把 "hp" 的 effective 誤當成
# 像 "atk"/"def" 一樣永遠等於 base(忽略 take_damage() 已造成的當前損耗)。
class _MutantTreatsHpLikeAtkDef extends Unit:
	func stat_access_view() -> Dictionary:
		return {
			"atk": {"base": atk, "effective": effective_atk()},
			"def": {"base": def, "effective": effective_def()},
			"hp": {"base": hp_max, "effective": hp_max},  # BUG: 應為 hp,不是 hp_max
			"mp": {"base": mp, "effective": mp},
		}


func test_sensitivity_proof_stat_access_view_hp_effective_tracks_current_hp() -> void:
	# Arrange
	var mutant: _MutantTreatsHpLikeAtkDef = _MutantTreatsHpLikeAtkDef.new()
	mutant.id = 1
	mutant.code_name = "MutantTest"
	mutant.faction = Unit.Faction.PLAYER
	mutant.hp_max = 30
	mutant.hp = 30
	mutant.atk = 10
	mutant.def = 5
	mutant.mp = 3
	mutant.take_damage(12)

	# Act
	var view: Dictionary = mutant.stat_access_view()

	# Assert — 證明若正式程式碼真的犯這個錯,
	# test_stat_access_view_hp_base_is_hp_max_effective_is_current_hp() 的斷言
	# (effective 必須等於扣血後的 hp)真的會被踩中:這裡它回報 30(hp_max),
	# 不是 18(扣 12 點後的當前 hp),不是巧合同值。
	assert_int(view["hp"]["effective"]).is_equal(30)
	assert_int(view["hp"]["effective"]).is_not_equal(mutant.hp)
