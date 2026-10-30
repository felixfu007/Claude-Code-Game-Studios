extends SceneTree
## Probes BattleLoop.run(max_rounds) boundary. Terrain = real fixture (padded to 13x6), roster = fixture text (PLAYER atk 1->20 and ENEMY hp_max 999->N, in memory)
## edited so a kill is possible (unedited fixture never ends). Both sides use GreedyTacticalAI.

func _battle(enemy_hp: int, max_rounds: int) -> Dictionary:
	var rows := PackedStringArray()
	for raw in FileAccess.get_file_as_string("res://assets/data/levels/test_fixture_terrain.txt").split("\n"):
		var l: String = raw.replace("\r", "")
		if not l.is_empty():
			while l.length() < 13: l += "."
			rows.append(l)
	while rows.size() < 6: rows.append(".".repeat(13))
	var roster := FileAccess.get_file_as_string("res://assets/data/units/test_fixture_roster.txt").replace("1,TESTFIX,PLAYER,999,1,", "1,TESTFIX,PLAYER,999,20,").replace("2,TESTENEMY,ENEMY,999,", "2,TESTENEMY,ENEMY,%d," % enemy_hp)
	var state: BattleState = BattleState.create(rows, roster)
	var pids: Array[int] = []
	var eids: Array[int] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): pids.append(u.id)
	for u: Unit in state.units_of(Unit.Faction.ENEMY): eids.append(u.id)
	var loop := BattleLoop.new(state, TurnOrder.new(pids, eids), func(s: BattleState, id: int, cm: bool, can: bool) -> Dictionary: return GreedyTacticalAI.decide(s, id, cm, can))
	return loop.run(max_rounds)

func _init() -> void:
	for hp in [1, 15, 40, 80]:
		var base := _battle(hp, 30)
		var oc := String(BattleState.Outcome.find_key(base["outcome"]))
		print("PROBE enemy_hp=%d max=30 -> outcome=%s rounds=%d aborted=%s" % [hp, oc, base["rounds"], base["aborted"]])
		if base["outcome"] == BattleState.Outcome.VICTORY and base["rounds"] >= 2:
			var R: int = base["rounds"]
			for m in [R + 1, R, R - 1]:
				var r := _battle(hp, m)
				print("PROBE   victory_round=%d run(%d) -> outcome=%s rounds=%d aborted=%s reason=%s" % [R, m, String(BattleState.Outcome.find_key(r["outcome"])), r["rounds"], r["aborted"], r["abort_reason"]])
	print("DONE")
	quit()
