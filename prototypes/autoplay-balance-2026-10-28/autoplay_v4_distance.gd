extends SceneTree
## Throwaway balance sweep, v3 (C only, in-memory stat tweaks). See README "第三版". Prototype: not for src/.
## v1 (autoplay.gd) is left untouched. This file has its own copy of the
## B logic with the threat-estimate fix.

const MAX_ROUNDS := 30
const SEQ := "res://assets/data/levels/campaign_sequence.txt"
const STRAT := "C_focus_affinity"
# name, enemy ATK factor, player HP factor, drop_last_enemy
const MAX_SHIFT := 3
const BOARD_W := 13
# name, enemy ATK factor, player HP factor, drop_last_enemy, shift_east
const SETTINGS := [
	["base", 1.0, 1.0, false, false],
	["dist+k", 1.0, 1.0, false, true],
	["eATK_x0.7", 0.7, 1.0, false, false],
	["eATK_x0.7+dist+k", 0.7, 1.0, false, true],
]

var _phi_nonzero := 0
var _phi_total := 0
var _phi_printed := 0
var _keep: Array = []  # strong refs (Callable bound to RefCounted does not keep it alive)

func _init() -> void:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(SEQ).split("\n"):
		var l := line.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		rows.append(l.split(","))
	for r in rows:
		for st in SETTINGS:
			_run(int(r[0]), r[1], r[2], r[3], STRAT, st)
	quit()

func _run(idx: int, terrain_path: String, roster_path: String, affinity_path: String, strat: String, st: Array) -> void:
	var roster_text: String = FileAccess.get_file_as_string(roster_path)
	var k := 0
	if st[4]:
		var terr_rows := _rows(FileAccess.get_file_as_string(terrain_path))
		var r: Array = _shift_enemies(roster_text, terr_rows)
		roster_text = r[0]
		k = r[1]
	var state: BattleState = BattleState.create(_rows(FileAccess.get_file_as_string(terrain_path)), roster_text)
	state.commit_authoritative_change(func() -> void:
		for u: Unit in state.units_of(Unit.Faction.ENEMY):
			if st[1] != 1.0:
				u.atk = roundi(float(u.atk) * float(st[1]))
		for u: Unit in state.units_of(Unit.Faction.PLAYER):
			if st[2] != 1.0:
				u.hp_max = roundi(float(u.hp_max) * float(st[2]))
				u.hp = u.hp_max)
	var pids: Array[int] = []
	var eids: Array[int] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): pids.append(u.id)
	for u: Unit in state.units_of(Unit.Faction.ENEMY): eids.append(u.id)
	var n_p0: int = pids.size()
	var n_e0: int = eids.size()
	var order := TurnOrder.new(pids, eids)

	# Affinity pool seeded from this level's own starting links
	# (same seeding BattleScreen does on the non-campaign path: +-AMP_EXPECTED, Source.STORY_EVENT).
	var pool := AffinityDataPool.new()
	var links_v: Variant = AffinityLink.links_from_text(FileAccess.get_file_as_string(affinity_path))
	var seeded := 0
	if links_v != null:
		for link: AffinityLink in links_v:
			var ca: Variant = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_a)
			var cb: Variant = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_b)
			if ca == null or cb == null:
				continue
			var pair: AffinityTypes.Pair = AffinityTypes.pair_of(ca, cb)
			var v: float = float(AffinityLink.AMP_EXPECTED) if link.polarity == AffinityLink.Polarity.POSITIVE else -float(AffinityLink.AMP_EXPECTED)
			var rej: AffinityDataPool.WriteRejection = pool.append_record(pair, v, AffinityTypes.Source.STORY_EVENT)
			if rej != AffinityDataPool.WriteRejection.NONE:
				push_error("seed rejected %d" % rej)
			else:
				seeded += 1
	var prov := AffinityPhiProvider.new(state, pool)
	_keep.append(prov)
	_keep.append(pool)
	_phi_nonzero = 0
	_phi_total = 0
	_phi_printed = 0
	var use_phi: bool = strat != "C_focus_phi0"
	var phi_cb := Callable()
	if use_phi:
		phi_cb = func(attacker_id: int, target_id: int) -> int:
			var v: int = prov.phi(attacker_id, target_id)
			_phi_total += 1
			if v != 0:
				_phi_nonzero += 1
				if _phi_printed < 1:
					_phi_printed += 1
					print("  PHI_RAW vs0%d %s attacker=%d target=%d phi=%d" % [idx, strat, attacker_id, target_id, v])
			return v

	var decide: Callable = func(s: BattleState, id: int, cm: bool, can: bool) -> Dictionary:
		var u: Unit = s.unit_by_id(id)
		if u.faction == Unit.Faction.PLAYER:
			if strat == "B_cautious_fixed":
				return _decide_cautious(s, id, cm, can, null)
			if strat.begins_with("C_"):
				return _decide_cautious(s, id, cm, can, prov)
		return GreedyTacticalAI.decide(s, id, cm, can)
	var loop := BattleLoop.new(state, order, decide, null, Callable(), phi_cb)
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
	var alive_p: int = state.units_of(Unit.Faction.PLAYER).size()
	var dead_e: int = n_e0 - state.units_of(Unit.Faction.ENEMY).size()
	print("SWEEP vs0%d %s outcome=%s rounds=%d player_attacks=%d enemies_killed=%d/%d players_alive=%d/%d shift_k=%d first_down=[%s]" % [idx, st[0], oc, res["rounds"], p_attacks, dead_e, n_e0, alive_p, n_p0, k, first_down.get_slice(" (after", 0)])
	print("RESULT vs0%d %s outcome=%s rounds=%d aborted=%s reason=%s player_attacks=%d seeded_links=%d phi_calls=%d phi_nonzero=%d first_down=[%s]" % [idx, st[0], oc, res["rounds"], res["aborted"], res["abort_reason"], p_attacks, seeded, _phi_total, _phi_nonzero, first_down])
	print("  END players=%s enemies=%s" % [ps, es])

# Expected total damage enemies can deal to `unit` at `tile` next enemy phase.
# v2 FIX: enemy reach uses legal_moves_relaxed(e, ignore_occupancy=true, false) instead of legal_moves(e).
# v1's legal_moves(e) treats allied enemies as blockers at snapshot time, but enemies move one at a time and
# vacate cells (diagnosis in README). Only formal queries: legal_moves_relaxed, is_attack_reachable, preview_damage.
func _threat(s: BattleState, unit: Unit, tile: Vector2i) -> int:
	var total := 0
	for e: Unit in s.units_of(Unit.Faction.ENEMY):
		var froms: Array[Vector2i] = [s.position_of(e.id)]
		froms.append_array(s.legal_moves_relaxed(e.id, true, false))
		for f in froms:
			if s.is_attack_reachable(e.id, f, tile):
				total += s.preview_damage(e.id, unit.id, 0).damage
				break
	return total

# Can player unit `p` hit enemy `e` this turn (formal queries; ignores whether p already acted).
func _can_hit(s: BattleState, p: Unit, e: Unit) -> bool:
	var froms: Array[Vector2i] = [s.position_of(p.id)]
	froms.append_array(s.legal_moves(p.id))
	for f in froms:
		if s.is_attack_reachable(p.id, f, s.position_of(e.id)):
			return true
	return false

# C focus-fire: killable-this-turn first (sum of preview_damage(p,e,0) over player units that _can_hit e >= e.hp),
# then lowest hp, then lowest id.
func _focus_pick(s: BattleState, cands: Array[Unit]) -> int:
	var best_id := -1
	var best_kill := false
	var best_hp := 0
	for e: Unit in cands:
		var sum := 0
		for p: Unit in s.units_of(Unit.Faction.PLAYER):
			if _can_hit(s, p, e):
				sum += s.preview_damage(p.id, e.id, 0).damage
		var kill: bool = sum >= e.hp
		var better := false
		if best_id == -1:
			better = true
		elif kill != best_kill:
			better = kill
		elif e.hp != best_hp:
			better = e.hp < best_hp
		else:
			better = e.id < best_id
		if better:
			best_id = e.id
			best_kill = kill
			best_hp = e.hp
	return best_id

# prov == null -> B (fixed). prov != null -> C (focus fire + affinity tile preference).
func _decide_cautious(s: BattleState, id: int, can_move: bool, can_attack: bool, prov: AffinityPhiProvider) -> Dictionary:
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

	var focus := -1
	if prov != null and can_attack:
		var union: Array[Unit] = []
		for t in pool:
			for e: Unit in GreedyTacticalAI._attackable_from(s, unit, t, enemies):
				if not union.has(e):
					union.append(e)
		if not union.is_empty():
			focus = _focus_pick(s, union)
		if focus != -1:
			var sub: Array[Vector2i] = []
			for t in pool:
				for e: Unit in GreedyTacticalAI._attackable_from(s, unit, t, enemies):
					if e.id == focus:
						sub.append(t)
						break
			pool = sub

	var links: Array[AffinityLink] = []
	var pos: Dictionary[int, Vector2i] = {}
	if prov != null:
		links = prov.links()
		pos = prov.positions()
	var chosen: Vector2i = pool[0]
	var ca: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, chosen, enemies)
	var cd: int = GreedyTacticalAI._distance_to_nearest(chosen, s, enemies)
	var caff := 0
	if prov != null:
		caff = AffinityRules.bonus_for_at(id, chosen, pos, links)
	for i in range(1, pool.size()):
		var t: Vector2i = pool[i]
		var a: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, t, enemies)
		var d: int = GreedyTacticalAI._distance_to_nearest(t, s, enemies)
		var aff := 0
		if prov != null:
			aff = AffinityRules.bonus_for_at(id, t, pos, links)
		var take := false
		if prov != null and aff != caff and (not a.is_empty()) == (not ca.is_empty()) and (focus != -1 or d == cd):
			# affinity decides among equally attack-capable tiles (all focus-capable when focus != -1)
			take = aff > caff
		else:
			take = GreedyTacticalAI._is_better_tile(t, not a.is_empty(), d, chosen, not ca.is_empty(), cd)
		if take:
			chosen = t
			ca = a
			cd = d
			caff = aff
	var mv: Variant = null
	if can_move and chosen != origin:
		mv = chosen
	var at := -1
	if can_attack:
		if prov != null and focus != -1:
			at = focus
		else:
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

# Input-text change (not a rule change): delete the ENEMY row with the largest id.
func _drop_last_enemy(text: String) -> String:
	var best := -1
	for raw in text.split("\n"):
		var l := raw.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		var f := l.split(",")
		if f.size() > 2 and f[2] == "ENEMY":
			best = maxi(best, int(f[0]))
	var out: Array[String] = []
	for raw in text.split("\n"):
		var l := raw.strip_edges()
		if not l.is_empty() and not l.begins_with("#") and l.split(",")[0] == str(best):
			continue
		out.append(raw)
	return "\n".join(out)

# Input-text change (not a rule change): move every ENEMY start_x east by k = min(MAX_SHIFT, BOARD_W-1-max enemy x).
# Uniform shift of the whole group => no overlap among enemies; player starts are x<=1, never reached.
# Terrain: reports the terrain char under each new cell; no cell is blocked by rule (Board has no impassable concept; '#' cost 3).
func _shift_enemies(text: String, terr: PackedStringArray) -> Array:
	var maxx := 0
	for raw in text.split("
"):
		var l := raw.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		var f := l.split(",")
		if f.size() > 10 and f[2] == "ENEMY":
			maxx = maxi(maxx, int(f[9]))
	var k: int = clampi(BOARD_W - 1 - maxx, 0, MAX_SHIFT)
	var out: Array[String] = []
	var tchars := ""
	for raw in text.split("
"):
		var l := raw.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			out.append(raw)
			continue
		var f := l.split(",")
		if f.size() > 10 and f[2] == "ENEMY":
			var ox := int(f[9])
			var oy := int(f[10])
			f[9] = str(ox + k)
			tchars += "%s(%d,%d)->(%d,%d)terr'%s' " % [f[1], ox, oy, ox + k, oy, terr[oy][ox + k]]
			out.append(",".join(f))
		else:
			out.append(raw)
	print("FEAS maxx=%d k=%d %s" % [maxx, k, tchars])
	return ["
".join(out), k]
