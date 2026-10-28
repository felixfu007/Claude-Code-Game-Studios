extends SceneTree
## Throwaway balance measurement. See README.md. Prototype: not for src/.

const MAX_ROUNDS := 30
const SEQ := "res://assets/data/levels/campaign_sequence.txt"

func _init() -> void:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(SEQ).split("\n"):
		var l := line.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		rows.append(l.split(","))
	for r in rows:
		for strat in ["A_greedy", "B_cautious"]:
			_run(int(r[0]), r[1], r[2], strat)
	quit()

func _run(idx: int, terrain_path: String, roster_path: String, strat: String) -> void:
	var trows: PackedStringArray = _rows(FileAccess.get_file_as_string(terrain_path))
	var state: BattleState = BattleState.create(trows, FileAccess.get_file_as_string(roster_path))
	var pids: Array[int] = []
	var eids: Array[int] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): pids.append(u.id)
	for u: Unit in state.units_of(Unit.Faction.ENEMY): eids.append(u.id)
	var order := TurnOrder.new(pids, eids)
	var decide: Callable = func(s: BattleState, id: int, cm: bool, ca: bool) -> Dictionary:
		var u: Unit = s.unit_by_id(id)
		if strat == "B_cautious" and u.faction == Unit.Faction.PLAYER:
			return _decide_cautious(s, id, cm, ca)
		return GreedyTacticalAI.decide(s, id, cm, ca)
	var loop := BattleLoop.new(state, order, decide)
	var res: Dictionary = loop.run(MAX_ROUNDS)
	var log: Array = res["log"]
	var first_down := "none"
	var p_attacks := 0
	for i in range(log.size()):
		var s: String = log[i]
		if " PLAYER: " in s and " attacks " in s:
			p_attacks += 1
		if first_down == "none" and s.ends_with(" is defeated"):
			first_down = "%s (after: %s)" % [s, log[i - 1]]
	var oc: String = String(BattleState.Outcome.find_key(res["outcome"]))
	var ps: Array = []
	var es: Array = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): ps.append("%s:%d/%d" % [u.code_name, u.hp, u.hp_max])
	for u: Unit in state.units_of(Unit.Faction.ENEMY): es.append("%s:%d/%d" % [u.code_name, u.hp, u.hp_max])
	print("RESULT vs0%d %s outcome=%s rounds=%d aborted=%s reason=%s player_attacks=%d first_down=[%s]" % [idx, strat, oc, res["rounds"], res["aborted"], res["abort_reason"], p_attacks, first_down])
	print("  END players=%s enemies=%s" % [ps, es])

# Expected total damage enemies can deal to `unit` at `tile` next enemy phase.
# Uses only formal queries: legal_moves, is_attack_reachable, preview_damage.
func _threat(s: BattleState, unit: Unit, tile: Vector2i) -> int:
	var total := 0
	for e: Unit in s.units_of(Unit.Faction.ENEMY):
		var froms: Array[Vector2i] = [s.position_of(e.id)]
		froms.append_array(s.legal_moves(e.id))
		for f in froms:
			if s.is_attack_reachable(e.id, f, tile):
				total += s.preview_damage(e.id, unit.id, 0).damage
				break
	return total

func _decide_cautious(s: BattleState, id: int, can_move: bool, can_attack: bool) -> Dictionary:
	var unit: Unit = s.unit_by_id(id)
	var enemies: Array[Unit] = s.units_of(Unit.Faction.ENEMY)
	if enemies.is_empty():
		return {"move_to": null, "attack": -1}
	var origin: Vector2i = s.position_of(id)
	var cands: Array[Vector2i] = [origin]
	if can_move:
		cands.append_array(s.legal_moves(id))
	var threat := {}
	for t in cands:
		threat[t] = _threat(s, unit, t)
	var pool: Array[Vector2i] = []
	for t in cands:
		if threat[t] < unit.hp:
			pool.append(t)
	if pool.is_empty():
		var mn := 1 << 30
		for t in cands:
			mn = mini(mn, threat[t])
		for t in cands:
			if threat[t] == mn:
				pool.append(t)
	var chosen: Vector2i = pool[0]
	var ca: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, chosen, enemies)
	var cd: int = GreedyTacticalAI._distance_to_nearest(chosen, s, enemies)
	for i in range(1, pool.size()):
		var t: Vector2i = pool[i]
		var a: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, t, enemies)
		var d: int = GreedyTacticalAI._distance_to_nearest(t, s, enemies)
		if GreedyTacticalAI._is_better_tile(t, not a.is_empty(), d, chosen, not ca.is_empty(), cd):
			chosen = t; ca = a; cd = d
	var mv: Variant = null
	if can_move and chosen != origin:
		mv = chosen
	var at := -1
	if can_attack:
		at = GreedyTacticalAI._best_target(ca)
	return {"move_to": mv, "attack": at}

# Re-implements BattleScreen._parse_terrain_rows (battle_screen.gd): split on \n, strip \r, drop blank lines.
func _rows(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in text.split("\n"):
		var l: String = raw.replace("\r", "")
		if not l.is_empty():
			out.append(l)
	return out
