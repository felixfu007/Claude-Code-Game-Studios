extends SceneTree
## Throwaway: initial-state R1 enemy threat map per level. Only formal queries:
## BattleState.create / legal_moves_relaxed / is_attack_reachable / preview_damage / position_of.
## Re-implemented rules: terrain row parsing (_rows, copy of BattleScreen._parse_terrain_rows). Nothing else.
const SEQ := "res://assets/data/levels/campaign_sequence.txt"
func _init() -> void:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(SEQ).split("\n"):
		var l := line.strip_edges()
		if l.is_empty() or l.begins_with("#"): continue
		rows.append(l.split(","))
	var ua := OS.get_cmdline_user_args()
	for r in rows:
		if ua.size() > 0 and not (str(int(r[0])) in ua[0].split(",")): continue
		_map(int(r[0]), r[1], r[2])
	quit()
func _rows(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in text.split("\n"):
		var l: String = raw.replace("\r", "")
		if not l.is_empty(): out.append(l)
	return out
func _map(idx: int, tp: String, rp: String) -> void:
	var s: BattleState = BattleState.create(_rows(FileAccess.get_file_as_string(tp)), FileAccess.get_file_as_string(rp))
	var es: Array[Unit] = s.units_of(Unit.Faction.ENEMY)
	var line := ""
	for e in es: line += "%s@%s " % [e.code_name, s.position_of(e.id)]
	print("MAP vs0%d enemies: %s" % [idx, line])
	var reach := {}
	for e in es:
		var froms: Array[Vector2i] = [s.position_of(e.id)]
		froms.append_array(s.legal_moves_relaxed(e.id, true, false))
		reach[e.id] = froms
	for y in range(6):
		var cnt := ""
		var dmg := ""
		for x in range(13):
			var n := 0
			var d := 0
			for e in es:
				for f in reach[e.id]:
					if s.is_attack_reachable(e.id, f, Vector2i(x, y)):
						n += 1
						d += s.preview_damage(e.id, 1, 0).damage
						break
			cnt += "%d " % n
			dmg += "%2d " % d
		print("MAP vs0%d y=%d  n_enemies: %s | dmg_on_jia: %s" % [idx, y, cnt, dmg])
	# per column: min over y of n (safest cell in that column), and first column where every cell has >=1 / >=3 threatening
	var firstcol3 := -1
	for x in range(13):
		var mn := 99
		for y in range(6):
			var n := 0
			for e in es:
				for f in reach[e.id]:
					if s.is_attack_reachable(e.id, f, Vector2i(x, y)):
						n += 1
						break
			mn = mini(mn, n)
		print("MAP vs0%d col x=%d min_enemies_over_y=%d" % [idx, x, mn])
