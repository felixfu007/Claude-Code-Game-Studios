extends RefCounted
## DIAGNOSTIC COPY of ../protocol2-computer-measure/p2_decision.gd (that file is untouched). Adds `trace` output and `tiebreak_mode`.
## Protocol-2 decision function (locked spec 3.1/3.2). Copied from autoplay_v2.gd `_decide_cautious`,
## `_threat`, `_can_hit`, `_focus_pick`; changed ONLY as the spec dictates (flags, knobs, step 2).
## This file is the structural-audit target (spec 3.2 point 4). Measurement code (phi_avg) lives in
## protocol2_runner.gd, NOT here, so no affinity read can hide in this file outside the use_affinity guard.

var use_affinity := false
var focus_on := true
var k1 := 0
var k2 := 0
var k3 := 0
var tiebreak_mode := false  # diagnostic only: affinity used as OLD tie key (after step 3/4 tile comparison) instead of step-2 filter
var trace := {}
var k2_tie_hits := 0        # times _focus_pick reached the id tie-break (kill flag equal AND hp equal)
var k3_order_dependent := 0 # times step-4's result changed when the pool was scanned in reverse order
var prov: AffinityPhiProvider = null  # null whenever use_affinity == false

func _init(p_use_affinity: bool, p_focus_on: bool, p_k1: int, p_k2: int, p_k3: int, p_prov: AffinityPhiProvider) -> void:
	use_affinity = p_use_affinity
	focus_on = p_focus_on
	k1 = p_k1
	k2 = p_k2
	k3 = p_k3
	prov = p_prov if p_use_affinity else null

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

func _can_hit(s: BattleState, p: Unit, e: Unit) -> bool:
	var froms: Array[Vector2i] = [s.position_of(p.id)]
	froms.append_array(s.legal_moves(p.id))
	for f in froms:
		if s.is_attack_reachable(p.id, f, s.position_of(e.id)):
			return true
	return false

# killable-this-turn first, then lowest hp, then id (K2=0: lower id; K2=1: HIGHER id).
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
		elif k2 == 0:
			k2_tie_hits += 1
			better = e.id < best_id
		else:
			k2_tie_hits += 1
			better = e.id > best_id
		if better:
			best_id = e.id
			best_kill = kill
			best_hp = e.hp
	return best_id

static func _yx_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x

static func _yx_greater(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y > b.y
	return a.x > b.x

func decide(s: BattleState, id: int, can_move: bool, can_attack: bool) -> Dictionary:
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
	# Step 1: K1 safety threshold -> candidate pool (empty -> fall back to lowest threat).
	var pool: Array[Vector2i] = []
	for t in cands:
		var safe: bool = (threat[t] < unit.hp) if k1 == 0 else (threat[t] * 2 < unit.hp)
		if safe:
			pool.append(t)
	if pool.is_empty():
		var mn := 1 << 30
		for t in cands:
			mn = mini(mn, threat[t])
		for t in cands:
			if threat[t] == mn:
				pool.append(t)
	trace = {"origin": origin, "cands": cands.size(), "pool_step1": pool.size(), "cand_attackable": 0}
	for t in cands:
		if not GreedyTacticalAI._attackable_from(s, unit, t, enemies).is_empty():
			trace["cand_attackable"] += 1
	# K3 ordering, both arms.
	if k3 == 0:
		pool.sort_custom(_yx_less)
	else:
		pool.sort_custom(_yx_greater)

	# Step 2 (the ONLY arm difference): keep the tiles with maximal affinity bonus.
	trace["pool_before_step2"] = pool.size()
	var pool_attackable := 0
	for t in pool:
		if not GreedyTacticalAI._attackable_from(s, unit, t, enemies).is_empty():
			pool_attackable += 1
	trace["pool_attackable_before_step2"] = pool_attackable
	if use_affinity and not tiebreak_mode:
		var pos: Dictionary[int, Vector2i] = prov.positions()  # snapshot BEFORE this unit moves
		var lk: Array[AffinityLink] = prov.links()
		var best := -(1 << 30)
		var scores: Array[int] = []
		for t in pool:
			var b: int = AffinityRules.bonus_for_at(id, t, pos, lk)
			scores.append(b)
			best = maxi(best, b)
		var kept: Array[Vector2i] = []
		for i in range(pool.size()):
			if scores[i] == best:
				kept.append(pool[i])
		pool = kept

	trace["pool_after_step2"] = pool.size()
	trace["pool_attackable_after_step2"] = 0
	for t in pool:
		if not GreedyTacticalAI._attackable_from(s, unit, t, enemies).is_empty():
			trace["pool_attackable_after_step2"] += 1
	# Step 3: identical for both arms (focus fire + existing tile comparison).
	var focus := -1
	if focus_on and can_attack:
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

	trace["pool_after_step3"] = pool.size()
	trace["focus"] = focus
	# Step 4: first-in-order wins ties (pool already K3-ordered).
	var chosen: Vector2i = pool[0]
	var ca: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, chosen, enemies)
	var cd: int = GreedyTacticalAI._distance_to_nearest(chosen, s, enemies)
	for i in range(1, pool.size()):
		var t: Vector2i = pool[i]
		var a: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, t, enemies)
		var d: int = GreedyTacticalAI._distance_to_nearest(t, s, enemies)
		if GreedyTacticalAI._is_better_tile(t, not a.is_empty(), d, chosen, not ca.is_empty(), cd):
			chosen = t
			ca = a
			cd = d
	# DIAGNOSTIC: re-run the step-4 scan with the pool reversed; does K3's order matter at all?
	var rchosen: Vector2i = pool[pool.size() - 1]
	var rca: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, rchosen, enemies)
	var rcd: int = GreedyTacticalAI._distance_to_nearest(rchosen, s, enemies)
	for i in range(pool.size() - 2, -1, -1):
		var t3: Vector2i = pool[i]
		var a3: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, t3, enemies)
		var d3: int = GreedyTacticalAI._distance_to_nearest(t3, s, enemies)
		if GreedyTacticalAI._is_better_tile(t3, not a3.is_empty(), d3, rchosen, not rca.is_empty(), rcd):
			rchosen = t3
			rca = a3
			rcd = d3
	if rchosen != chosen:
		k3_order_dependent += 1
	if use_affinity and tiebreak_mode:
		# DIAGNOSTIC: old-style tie key. Among tiles NOT distinguishable from `chosen` by the existing
		# comparison (same can-attack flag, same distance), take max affinity bonus; first in K3 order wins ties.
		var pos2: Dictionary[int, Vector2i] = prov.positions()
		var lk2: Array[AffinityLink] = prov.links()
		var equiv: Array[Vector2i] = []
		for t in pool:
			var a2: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, t, enemies)
			var d2: int = GreedyTacticalAI._distance_to_nearest(t, s, enemies)
			if (not a2.is_empty()) == (not ca.is_empty()) and d2 == cd:
				equiv.append(t)
		trace["tiebreak_equiv"] = equiv.size()
		var bestb := -(1 << 30)
		for t in equiv:
			var b2: int = AffinityRules.bonus_for_at(id, t, pos2, lk2)
			if b2 > bestb:
				bestb = b2
				chosen = t
		ca = GreedyTacticalAI._attackable_from(s, unit, chosen, enemies)
	trace["chosen"] = chosen
	trace["chosen_attackable"] = not ca.is_empty()
	var mv: Variant = null
	if can_move and chosen != origin:
		mv = chosen
	var at := -1
	if can_attack:
		if focus_on and focus != -1:
			at = focus
		else:
			at = GreedyTacticalAI._best_target(ca)
	return {"move_to": mv, "attack": at}
