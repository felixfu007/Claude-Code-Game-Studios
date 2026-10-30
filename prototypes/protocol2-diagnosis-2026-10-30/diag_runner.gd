extends SceneTree
## DIAGNOSTIC COPY of ../protocol2-computer-measure/protocol2_runner.gd (that file is untouched).
## Adds per-action TRACE lines, per-game SUMMARY, and --arms=use_tb (affinity as OLD tie key; diagnosis only, NOT a formal arm).
## Extra args: --variants=0,4 --arms=ignore,use,use_tb
## Protocol-2 computer measurement runner. Spec: docs/reviews/protocol2-threshold-locked-2026-10-30.md
## Prototype only. Usage (after `--`):
##   --level=<n>            row of campaign_sequence.txt (default 2; vs01 must be chosen explicitly: --level=1)
##   --terrain= --roster= --affinity=   explicit res:// paths (override --level; for fixture debugging)
##   --arms=ignore,use      default both
##   --variants=0,1,...,7   default all 8
##   --max-rounds=12        default 12 (spec 2.1)
## Output: one `RESULT ...` line per game, then `DONE`.

const SEQ := "res://assets/data/levels/campaign_sequence.txt"
const Decision := preload("res://prototypes/protocol2-diagnosis-2026-10-30/p2_decision_traced.gd")

var _keep: Array = []
var _args := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--") and "=" in s:
			var kv := s.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var level: int = int(_args.get("level", "2"))
	var terrain: String = _args.get("terrain", "")
	var roster: String = _args.get("roster", "")
	var affinity: String = _args.get("affinity", "")
	if terrain.is_empty():
		for line in FileAccess.get_file_as_string(SEQ).split("\n"):
			var l := line.strip_edges()
			if l.is_empty() or l.begins_with("#"):
				continue
			var r := l.split(",")
			if int(r[0]) == level:
				terrain = r[1]
				roster = r[2]
				affinity = r[3]
	if terrain.is_empty() or roster.is_empty():
		push_error("level not found / paths missing")
		quit(2)
		return
	var arms: PackedStringArray = String(_args.get("arms", "ignore,use")).split(",")
	var variants: PackedStringArray = String(_args.get("variants", "0,1,2,3,4,5,6,7")).split(",")
	var max_rounds: int = int(_args.get("max-rounds", "12"))

	var out: Array = []
	OS.execute("git", ["rev-parse", "HEAD"], out)
	var v := Engine.get_version_info()
	print("HEADER build_commit=%s engine=%s level=%s terrain=%s roster=%s affinity=%s max_rounds=%d" % [
		String(out[0]).strip_edges() if out.size() > 0 else "unknown", v.get("string", "?"),
		_args.get("level", "2"), terrain, roster, affinity, max_rounds])
	for vi in variants:
		for arm in arms:
			_run(arm, int(vi), terrain, roster, affinity, max_rounds)
	print("DONE")
	quit()

func _run(arm: String, vi: int, terrain_path: String, roster_path: String, affinity_path: String, max_rounds: int) -> void:
	var use_aff: bool = arm == "use" or arm == "use_tb"
	var k1: int = (vi >> 2) & 1
	var k2: int = (vi >> 1) & 1
	var k3: int = vi & 1
	var state: BattleState = BattleState.create(_rows(FileAccess.get_file_as_string(terrain_path)), FileAccess.get_file_as_string(roster_path))
	var pids: Array[int] = []
	var eids: Array[int] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): pids.append(u.id)
	for u: Unit in state.units_of(Unit.Faction.ENEMY): eids.append(u.id)
	var order := TurnOrder.new(pids, eids)

	# Affinity pool seeded from the level's links (same seeding as autoplay_v2 / BattleScreen).
	var pool := AffinityDataPool.new()
	if not affinity_path.is_empty():
		var links_v: Variant = AffinityLink.links_from_text(FileAccess.get_file_as_string(affinity_path))
		if links_v != null:
			for link: AffinityLink in links_v:
				var ca: Variant = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_a)
				var cb: Variant = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_b)
				if ca == null or cb == null:
					continue
				var pair: AffinityTypes.Pair = AffinityTypes.pair_of(ca, cb)
				var amp: float = float(AffinityLink.AMP_EXPECTED) if link.polarity == AffinityLink.Polarity.POSITIVE else -float(AffinityLink.AMP_EXPECTED)
				var rej: AffinityDataPool.WriteRejection = pool.append_record(pair, amp, AffinityTypes.Source.STORY_EVENT)
				if rej != AffinityDataPool.WriteRejection.NONE:
					push_error("seed rejected %d" % rej)
	var prov := AffinityPhiProvider.new(state, pool)
	_keep.append(prov)
	_keep.append(pool)
	# Engine-side Phi damage: ON for both arms (spec 3.1).
	var G := {"last_phi": [], "phi_sum": 0, "p_attacks": 0, "p_dmg": 0, "e_attacks": 0, "e_dmg": 0,
		"first_player_fall": "none", "first_enemy_fall": "none", "p_could_attack": 0, "p_actions": 0, "p_decisions_noattack_but_could": 0}
	var phi_cb: Callable = func(attacker_id: int, target_id: int) -> int:
		var ph: int = prov.phi(attacker_id, target_id)
		G["last_phi"].append([attacker_id, target_id, ph])
		G["phi_sum"] += ph
		return ph

	var dec = Decision.new(use_aff, true, k1, k2, k3, prov if use_aff else null)
	dec.tiebreak_mode = (arm == "use_tb")

	# Measurement bookkeeping (NOT part of the decision; both arms identical).
	var min_hp := {}      # player id -> lowest hp seen at any scan
	var hp_max := {}
	for u: Unit in state.units_of(Unit.Faction.PLAYER):
		min_hp[u.id] = u.hp
		hp_max[u.id] = u.hp_max
	var phi_sum := [0.0]
	var phi_samples := [0]
	var last_sampled_round := [-1]
	var scan := func() -> void:
		for u: Unit in state.units_of(Unit.Faction.PLAYER):
			min_hp[u.id] = mini(min_hp[u.id], u.hp)
	var sample_phi := func() -> void:
		if last_sampled_round[0] == order.round_number():
			return
		last_sampled_round[0] = order.round_number()
		var pos: Dictionary[int, Vector2i] = prov.positions()
		var lk: Array[AffinityLink] = prov.links()
		var tot := 0
		for u: Unit in state.units_of(Unit.Faction.PLAYER):
			if u.is_alive():
				tot += AffinityRules.bonus_for_at(u.id, pos[u.id], pos, lk)
		phi_sum[0] += tot
		phi_samples[0] += 1

	var all_units: Array[Unit] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): all_units.append(u)
	for u: Unit in state.units_of(Unit.Faction.ENEMY): all_units.append(u)
	var prev := {}
	var snap_hp := {}
	var snap_pos := {}
	var tag := "%s v=%d" % [arm, vi]
	var snapshot := func() -> void:
		for u: Unit in all_units:
			snap_hp[u.id] = u.hp
			snap_pos[u.id] = state.position_of(u.id) if u.is_alive() else Vector2i(-1, -1)
	var flush := func() -> void:
		if prev.is_empty():
			return
		var changes := []
		for u: Unit in all_units:
			if int(snap_hp[u.id]) != u.hp:
				changes.append("%s %d->%d" % [u.code_name, snap_hp[u.id], u.hp])
				if u.faction == Unit.Faction.PLAYER and u.hp <= 0 and G["first_player_fall"] == "none":
					G["first_player_fall"] = "R%d %s felled by %s" % [prev["round"], u.code_name, prev["name"]]
				if u.faction == Unit.Faction.ENEMY and u.hp <= 0 and G["first_enemy_fall"] == "none":
					G["first_enemy_fall"] = "R%d %s felled by %s" % [prev["round"], u.code_name, prev["name"]]
		var attacked: bool = not G["last_phi"].is_empty()
		var phis := []
		for r in G["last_phi"]:
			phis.append("phi=%d(%d->%d)" % [r[2], r[0], r[1]])
		var enemy_side: bool = prev["side"] == "E"
		var dmg_total := 0
		for u: Unit in all_units:
			var d: int = int(snap_hp[u.id]) - u.hp
			if d > 0 and ((u.faction == Unit.Faction.ENEMY) != enemy_side):
				dmg_total += d
		if enemy_side:
			if dmg_total > 0:
				G["e_attacks"] += 1
				G["e_dmg"] += dmg_total
		else:
			G["p_actions"] += 1
			if prev.get("chosen_attackable", false) or prev["can_attack_here"]:
				G["p_could_attack"] += 1
			if attacked:
				G["p_attacks"] += 1
				G["p_dmg"] += dmg_total
			elif prev["could_attack"]:
				G["p_decisions_noattack_but_could"] += 1
		print("TRACE %s R%d %s %s EFFECT after=%s did_attack=%s %s dmg=%d hp_changes=[%s]" % [tag, prev["round"], prev["side"], prev["name"],
			state.position_of(prev["id"]) if state.unit_by_id(prev["id"]).is_alive() else "dead", attacked, " ".join(phis), dmg_total, ", ".join(changes)])
		G["last_phi"] = []
	var sample_round_start := func() -> void:
		pass
	var decide: Callable = func(s: BattleState, id: int, cm: bool, can: bool) -> Dictionary:
		flush.call()
		scan.call()
		var u: Unit = s.unit_by_id(id)
		var is_player: bool = u.faction == Unit.Faction.PLAYER
		if not is_player:
			sample_phi.call()
		var d: Dictionary
		if is_player:
			d = dec.decide(s, id, cm, can)
		else:
			d = GreedyTacticalAI.decide(s, id, cm, can)
		var tr: Dictionary = dec.trace if is_player else {}
		var from_pos: Vector2i = s.position_of(id)
		var hps := []
		for pu: Unit in s.units_of(Unit.Faction.PLAYER):
			hps.append("%s:%d" % [pu.code_name, pu.hp])
		print("TRACE %s R%d %s %s hp=%d from=%s can_move=%s can_attack=%s | %s | decision move_to=%s attack=%d" % [tag, order.round_number(),
			"P" if is_player else "E", u.code_name, u.hp, from_pos, cm, can, str(tr) if is_player else "(greedy enemy)",
			str(d["move_to"]), int(d["attack"])])
		# could this unit attack at all this action (from origin or any reachable tile)?
		var could := false
		if is_player and can:
			var enemies: Array[Unit] = s.units_of(Unit.Faction.ENEMY)
			var cs: Array[Vector2i] = [from_pos]
			if cm:
				cs.append_array(s.legal_moves(id))
			for t in cs:
				if not GreedyTacticalAI._attackable_from(s, u, t, enemies).is_empty():
					could = true
					break
		prev.clear()
		prev.merge({"id": id, "name": u.code_name, "round": order.round_number(), "side": "P" if is_player else "E",
			"could_attack": could, "can_attack_here": false, "chosen_attackable": tr.get("chosen_attackable", false)})
		snapshot.call()
		return d
	var loop := BattleLoop.new(state, order, decide, null, Callable(), phi_cb)
	snapshot.call()  # placeholder so a final flush has a baseline of the last state
	var res: Dictionary = loop.run(max_rounds)
	flush.call()
	scan.call()
	# Round ended in player phase (victory) => the final round's phi was not sampled yet.
	# (Aborted runs already sampled their last real round in the enemy phase; round_number is then max+1.)
	if not res["aborted"]:
		sample_phi.call()

	var rounds: int = res["rounds"]
	var oc: String = String(BattleState.Outcome.find_key(res["outcome"]))
	var outcome := "TIMEOUT"
	if res["outcome"] == BattleState.Outcome.VICTORY and not res["aborted"] and rounds <= max_rounds:
		outcome = "VICTORY"
	elif res["outcome"] == BattleState.Outcome.DEFEAT:
		outcome = "DEFEAT"
	var nd := 0
	if outcome == "VICTORY":
		for id in min_hp.keys():
			if min_hp[id] > 0 and 3 * int(min_hp[id]) <= int(hp_max[id]):
				nd += 1
	else:
		nd = min_hp.size()  # spec 2.2: non-clear = all player units
	var phi_avg: float = phi_sum[0] / maxf(1.0, float(phi_samples[0]))
	print("KNOBCOUNT %s k2_tie_hits=%d k3_order_dependent=%d" % [tag, dec.k2_tie_hits, dec.k3_order_dependent])
	print("SUMMARY %s p_actions=%d p_could_attack_at_decision=%d p_actual_attacks=%d p_decisions_could_but_did_not=%d p_dmg_dealt=%d sum_phi_on_attacks=%d enemy_damaging_actions=%d enemy_dmg_dealt=%d first_player_fall=[%s] first_enemy_fall=[%s]" % [tag, G["p_actions"], G["p_could_attack"], G["p_attacks"], G["p_decisions_noattack_but_could"], G["p_dmg"], G["phi_sum"], G["e_attacks"], G["e_dmg"], G["first_player_fall"], G["first_enemy_fall"]])
	print("RESULT arm=%s v=%d outcome=%s rounds=%d neardeath=%d phi_avg=%.3f raw_outcome=%s aborted=%s reason=%s phi_samples=%d" % [
		arm, vi, outcome, rounds, nd, phi_avg, oc, res["aborted"], res["abort_reason"], phi_samples[0]])

func _rows(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in text.split("\n"):
		var l: String = raw.replace("\r", "")
		if not l.is_empty():
			# Fixture-only convenience: the 5x3 test fixture is smaller than Board 13x6; pad with open ground.
			# Real levels are already 13x6 so this never triggers on them.
			while l.length() < 13:
				l += "."
			out.append(l)
	var blank := ".".repeat(13)
	while out.size() < 6:
		out.append(blank)
	return out
