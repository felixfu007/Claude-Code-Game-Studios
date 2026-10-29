extends SceneTree
## Throwaway balance measurement, v2. See README.md section "第二版". Prototype: not for src/.
## v1 (autoplay.gd) is left untouched. This file has its own copy of the
## B logic with the threat-estimate fix.

const MAX_ROUNDS := 30
const SEQ := "res://assets/data/levels/campaign_sequence.txt"
const STRATS := ["A_greedy", "B_cautious_fixed", "C_focus_affinity", "C_focus_phi0"]

var _phi_nonzero := 0
var _phi_total := 0
var _phi_printed := 0
var _keep: Array = []  # strong refs (Callable bound to RefCounted does not keep it alive)

func _init() -> void:
	var ua := OS.get_cmdline_user_args()
	var affinity: String = ua[1]
	for line in FileAccess.get_file_as_string(ua[0]).split("
"):
		var l := line.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		var f := l.split(",")
		for strat in STRATS:
			_run(0, f[1], f[2], affinity, strat, f[0])
	quit()

func _run(idx: int, terrain_path: String, roster_path: String, affinity_path: String, strat: String, label: String) -> void:
	var state: BattleState = BattleState.create(_rows(FileAccess.get_file_as_string(terrain_path)), FileAccess.get_file_as_string(roster_path))
	var pids: Array[int] = []
	var eids: Array[int] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): pids.append(u.id)
	for u: Unit in state.units_of(Unit.Faction.ENEMY): eids.append(u.id)
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
					print("  PHI_RAW %s %s attacker=%d target=%d phi=%d" % [label, strat, attacker_id, target_id, v])
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
	if OS.get_cmdline_user_args().size() > 2:
		for ls in log:
			print("  LOG %s %s %s" % [label, strat, ls])
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
	print("RESULT %s %s outcome=%s rounds=%d aborted=%s reason=%s player_attacks=%d seeded_links=%d phi_calls=%d phi_nonzero=%d first_down=[%s]" % [label, strat, oc, res["rounds"], res["aborted"], res["abort_reason"], p_attacks, seeded, _phi_total, _phi_nonzero, first_down])
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
