extends SceneTree
## ATTEMPT-2 (v2). Registration: docs/reviews/protocol2-attempt2-registration-2026-10-30.md. Copied from ../protocol2-computer-measure/.
## Level 1 (vs01) additionally requires --r2=yes (anti-accident guard; coordinator-only run R2).
## Protocol-2 computer measurement runner. Spec: docs/reviews/protocol2-threshold-locked-2026-10-30.md
## Prototype only. Usage (after `--`):
##   --level=<n>            row of campaign_sequence.txt (default 2; vs01 must be chosen explicitly: --level=1)
##   --terrain= --roster= --affinity=   explicit res:// paths (override --level; for fixture debugging)
##   --arms=ignore,use      default both
##   --variants=0,1,...,7   default all 8
##   --max-rounds=12        default 12 (spec 2.1)
## Output: one `RESULT ...` line per game, then `DONE`.

const SEQ := "res://assets/data/levels/campaign_sequence.txt"
const Decision := preload("res://prototypes/protocol2-diagnosis-attempt4-2026-10-30/p2_decision.gd")

var _keep: Array = []
var _g_events := 0
var _g_nonzero := 0
var _sigs := {}  # arm -> Array of signature strings
var _args := {}

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--") and "=" in s:
			var kv := s.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var level: int = int(_args.get("level", "2"))
	if level == 1 and _args.get("r2", "") != "yes" and not _args.has("terrain"):
		push_error("level 1 refused (needs --r2=yes)")
		quit(4)
		return
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
	print("HEADER tool=protocol2-computer-measure-v3 build_commit=%s engine=%s level=%s terrain=%s roster=%s affinity=%s max_rounds=%d" % [
		String(out[0]).strip_edges() if out.size() > 0 else "unknown", v.get("string", "?"),
		_args.get("level", "2"), terrain, roster, affinity, max_rounds])
	for vi in variants:
		for arm in arms:
			_run(arm, int(vi), terrain, roster, affinity, max_rounds)
	for arm in arms:
		var seen := {}
		for sg in _sigs.get(arm, []):
			seen[sg] = true
		print("SIGSUM arm=%s distinct=%d of %d" % [arm, seen.size(), _sigs.get(arm, []).size()])
	print("GUARDSUM guard_events=%d guard_nonzero=%d" % [_g_events, _g_nonzero])
	if _g_nonzero == 0:
		print("FATAL guard never applied")
		print("DONE")
		quit(3)
		return
	print("DONE")
	quit()

func _run(arm: String, vi: int, terrain_path: String, roster_path: String, affinity_path: String, max_rounds: int) -> void:
	var use_aff: bool = arm == "use"
	var k1: int = (vi >> 2) & 1
	var k2: int = (vi >> 1) & 1  # pids order: 0 ascending, 1 descending
	var k3: int = vi & 1
	var state: BattleState = BattleState.create(_rows(FileAccess.get_file_as_string(terrain_path)), FileAccess.get_file_as_string(roster_path))
	var pids: Array[int] = []
	var eids: Array[int] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER): pids.append(u.id)
	for u: Unit in state.units_of(Unit.Faction.ENEMY): eids.append(u.id)
	pids.sort()
	eids.sort()
	if k2 == 1:
		pids.reverse()
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
	var phi_cb: Callable = func(attacker_id: int, target_id: int) -> int:
		return prov.phi(attacker_id, target_id)

	# Defender-side guard: BOTH arms (silently 0 if not attached).
	state.attach_defense_phi_provider(Callable(prov, "phi_of"))
	var dec = Decision.new(use_aff, k1, k3, prov if use_aff else null)
	var first_round := [-1]
	var pending := [{}]
	var g_events := [0]
	var g_nonzero := [0]

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
		var pd: Dictionary = pending[0]
		if not pd.is_empty():
			var tu: Unit = state.unit_by_id(pd["target"])
			if tu.hp < pd["hp"] or pd["damage"] == 0:
				g_events[0] += 1
				if pd["guard"] != 0:
					g_nonzero[0] += 1
			pending[0] = {}
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

	var decide: Callable = func(s: BattleState, id: int, cm: bool, can: bool) -> Dictionary:
		# Called before every unit action => state here = state after the previous attack resolved.
		scan.call()
		var u: Unit = s.unit_by_id(id)
		if u.faction == Unit.Faction.PLAYER:
			if first_round[0] == -1:
				first_round[0] = order.round_number()
			var cm2: bool = cm and not (k3 == 1 and order.round_number() == 1)
			var pr: Dictionary = dec.decide(s, id, cm2, can)
			if _args.get("trace", "") == "yes":
				print("TRACE arm=%s v=%d round=%d unit=%d can_move=%s cm2=%s at=%s move_to=%s attack=%d" % [arm, vi, order.round_number(), id, cm, cm2, s.position_of(id), pr["move_to"], pr["attack"]])
			return pr
		# first ENEMY action of a round => all player units are done for this round.
		sample_phi.call()
		var er: Dictionary = GreedyTacticalAI.decide(s, id, cm, can)
		var tg: int = int(er["attack"])
		if tg != -1 and s.unit_by_id(tg) != null and s.unit_by_id(tg).faction == Unit.Faction.PLAYER:
			var bd: Dictionary = s.preview_damage_breakdown(id, tg, 0).breakdown
			pending[0] = {"target": tg, "hp": s.unit_by_id(tg).hp, "guard": int(bd["guard"]), "damage": int(bd["damage"])}
		return er
	var loop := BattleLoop.new(state, order, decide, null, Callable(), phi_cb)
	var res: Dictionary = loop.run(max_rounds)
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
	var hpv := PackedStringArray()
	for id in pids_sorted_for_sig(state):
		hpv.append(str(state.unit_by_id(id).hp))
	var hp_str := ",".join(hpv)
	_g_events += g_events[0]
	_g_nonzero += g_nonzero[0]
	if not _sigs.has(arm):
		_sigs[arm] = []
	_sigs[arm].append("%s|%d|%d|%s" % [outcome, rounds, nd, hp_str])
	print("RESULT arm=%s v=%d outcome=%s rounds=%d neardeath=%d phi_avg=%.3f raw_outcome=%s aborted=%s reason=%s phi_samples=%d final_hp=%s first_round=%d guard_events=%d guard_nonzero=%d" % [
		arm, vi, outcome, rounds, nd, phi_avg, oc, res["aborted"], res["abort_reason"], phi_samples[0], hp_str, first_round[0], g_events[0], g_nonzero[0]])

func pids_sorted_for_sig(state: BattleState) -> Array[int]:
	var r: Array[int] = []
	for u: Unit in state.units_of(Unit.Faction.PLAYER):
		r.append(u.id)
	r.sort()
	return r

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
