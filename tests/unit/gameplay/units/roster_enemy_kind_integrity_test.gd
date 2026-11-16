# story-051 AC5:真實名冊(tut01~04、vs01~05)每個 ENEMY 列都有合法 enemy_kind。
# 🔴 資料檔讀取例外:讀版控唯讀固定資料 assets/data/units/*(test-standards.md 登記例外①)。
# ⚠️ 不證明窮盡:只涵蓋下列 9 份名冊;之後新增的名冊需自行加進清單。
extends GdUnitTestSuite

const _ROSTERS: Array[String] = [
	"tut01", "tut02", "tut03", "tut04", "vs01", "vs02", "vs03", "vs04", "vs05",
]


func test_every_enemy_row_in_real_rosters_has_valid_kind() -> void:
	var raw_enemy_rows: int = 0
	var parsed_enemy_rows: int = 0
	for name: String in _ROSTERS:
		var path: String = "res://assets/data/units/%s_roster.txt" % name
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_object(f).is_not_null()
		var text: String = f.get_as_text()
		for line: String in text.split("\n"):
			var l: String = line.strip_edges()
			if not l.begins_with("#") and l.contains(",ENEMY,"):
				raw_enemy_rows += 1
		var roster: Array[Unit] = Unit.roster_from_text(text)
		assert_bool(roster.is_empty()).is_false()
		for u: Unit in roster:
			if u.faction == Unit.Faction.ENEMY:
				parsed_enemy_rows += 1
				assert_bool(Unit.ENEMY_KINDS.has(u.enemy_kind)).append_failure_message(
					"%s %s 缺合法 enemy_kind" % [name, u.code_name]
				).is_true()
	# 防空洞:掃到的列數 == 檔案實際列數,且至少有列。
	assert_int(raw_enemy_rows).is_greater(0)
	assert_int(parsed_enemy_rows).is_equal(raw_enemy_rows)
