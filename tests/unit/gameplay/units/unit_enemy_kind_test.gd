# story-051 AC1/AC2:Unit 第 13 欄 enemy_kind 的解析、拒絕與型別內編號。
# 純資料測試(RefCounted),不建節點。
# 讀取版控唯讀名冊 assets/data/units/vs01_roster.txt(test-standards.md 登記例外①);
# 不證明窮盡 —— 只證明 vs01 這一份的編號。
extends GdUnitTestSuite

const _VS01_PATH: String = "res://assets/data/units/vs01_roster.txt"


func test_13_field_enemy_row_parses_kind() -> void:
	var u: Unit = Unit.from_csv_line("6,E1,ENEMY,23,14,6,6,1,1,10,0,,melee")
	assert_object(u).is_not_null()
	assert_str(String(u.enemy_kind)).is_equal("melee")
	assert_bool(u.lone_guard).is_false()


func test_13_field_with_lone_flag_and_kind() -> void:
	var u: Unit = Unit.from_csv_line("6,E1,ENEMY,23,14,6,6,1,1,10,0,1,mid")
	assert_bool(u.lone_guard).is_true()
	assert_str(String(u.enemy_kind)).is_equal("mid")


func test_11_and_12_field_rows_have_no_kind() -> void:
	var a: Unit = Unit.from_csv_line("6,E1,ENEMY,23,14,6,6,1,1,10,0")
	var b: Unit = Unit.from_csv_line("6,E1,ENEMY,23,14,6,6,1,1,10,0,1")
	assert_str(String(a.enemy_kind)).is_equal("")
	assert_str(String(b.enemy_kind)).is_equal("")


func test_invalid_kind_key_rejected() -> void:
	assert_object(Unit.from_csv_line("6,E1,ENEMY,23,14,6,6,1,1,10,0,,boss")).is_null()
	assert_array(Unit.roster_from_text("6,E1,ENEMY,23,14,6,6,1,1,10,0,,boss")).is_empty()


func test_player_row_with_kind_rejected() -> void:
	assert_object(Unit.from_csv_line("1,甲,PLAYER,30,16,8,6,1,1,0,2,,melee")).is_null()


func test_14_fields_rejected() -> void:
	assert_object(Unit.from_csv_line("6,E1,ENEMY,23,14,6,6,1,1,10,0,,melee,x")).is_null()


func test_vs01_ordinals_by_kind() -> void:
	var f: FileAccess = FileAccess.open(_VS01_PATH, FileAccess.READ)
	var roster: Array[Unit] = Unit.roster_from_text(f.get_as_text())
	var got: Dictionary = {}
	for u: Unit in roster:
		if u.faction == Unit.Faction.ENEMY:
			got[u.code_name] = "%s %d" % [u.enemy_kind, u.kind_ordinal]
	assert_dict(got).is_equal({
		"E1": "melee 1", "E5": "melee 2", "E2": "mid 1", "E4": "mid 2", "E3": "ranged 1",
	})


func test_ordinal_follows_row_order_not_id() -> void:
	# E1 列放在 E5 之後:編號隨列順序,不隨 id。
	var text: String = (
		"10,E5,ENEMY,24,14,6,6,1,1,11,5,,melee\n"
		+ "6,E1,ENEMY,23,14,6,6,1,1,10,0,,melee\n"
	)
	var roster: Array[Unit] = Unit.roster_from_text(text)
	assert_str(roster[0].code_name).is_equal("E5")
	assert_int(roster[0].kind_ordinal).is_equal(1)
	assert_int(roster[1].kind_ordinal).is_equal(2)
