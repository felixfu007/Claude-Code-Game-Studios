extends RefCounted
## Protocol-2 attempt-2 decision function (registration docs/reviews/protocol2-attempt2-registration-2026-10-30.md
## section 3, as amended by the coordinator's pre-commit correction: steps 1,2,4 apply to BOTH arms, only step 3
## (affinity maximisation) is use-arm only). Copied from ../protocol2-computer-measure/p2_decision.gd.
## Structural-audit target: every affinity/guard read is inside the `if use_affinity:` block.

## ===== RETREAT RULE CONSTANTS (added 2026-11-03; see README) =====
const RETREAT_LETHAL_MARGIN := 0   # retreat when predicted_hit + MARGIN >= hp (0 = "could be killed")
const RETREAT_TEAM_RADIUS := 2     # retreat tile must be within this Manhattan distance of some other living player unit (if any such tile exists)
var retreat_enabled := false       # runner sets from --retreat=on|off
var retreat_radius := RETREAT_TEAM_RADIUS  # runner may override with --radius=N (diagnostic only)

var use_affinity := false
var k1 := 0
var k3 := 0
var prov: AffinityPhiProvider = null  # null whenever use_affinity == false

func _init(p_use_affinity: bool, p_k1: int, p_k3: int, p_prov: AffinityPhiProvider) -> void:
	use_affinity = p_use_affinity
	k1 = p_k1
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

# killable-this-turn first, then lowest hp, then LOWER id (old K2 tie key retired).
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

static func _yx_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x

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
	# Step 1 (both arms): K1 safety pool; empty -> lowest threat. Fixed (y,x) ascending order.
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
	pool.sort_custom(_yx_less)

	# Step 2 (both arms): attack priority filter.
	var focus := -1
	var will_attack := false  # H3 sec.1: true iff step 2 actually shrank the pool to attackable tiles
	if can_attack:
		var atk_tiles: Array[Vector2i] = []
		var union: Array[Unit] = []
		for t in pool:
			var att: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, t, enemies)
			if not att.is_empty():
				atk_tiles.append(t)
				for e: Unit in att:
					if not union.has(e):
						union.append(e)
		if not atk_tiles.is_empty():
			pool = atk_tiles
			will_attack = true
			focus = _focus_pick(s, union)

	# Step 3 (USE ARM ONLY): maximise Phi(t) + guard_total(t); guard_total via the official functions.
	if use_affinity:
		var pos: Dictionary[int, Vector2i] = prov.positions()  # snapshot BEFORE this unit moves
		var lk: Array[AffinityLink] = prov.links()
		var best := -(1 << 30)
		var scores: Array[int] = []
		for t in pool:
			var phi_t: int = AffinityRules.bonus_for_at(id, t, pos, lk)
			var gt: int = CombatRules.guard_total(CombatRules.guard(phi_t), s.lone_guard_if_at(id, t, will_attack))
			scores.append(phi_t + gt)
			best = maxi(best, phi_t + gt)
		var kept: Array[Vector2i] = []
		for i in range(pool.size()):
			if scores[i] == best:
				kept.append(pool[i])
		pool = kept

	# Step 4 (both arms): within the (tied) pool prefer tiles that can attack focus F, then _is_better_tile, then pool order.
	if focus != -1:
		var sub: Array[Vector2i] = []
		for t in pool:
			for e: Unit in GreedyTacticalAI._attackable_from(s, unit, t, enemies):
				if e.id == focus:
					sub.append(t)
					break
		if not sub.is_empty():
			pool = sub
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
	# ===== RETREAT (added; only when retreat_enabled) =====
	# Trigger: the tile the original steps chose is predicted lethal (threat + margin >= hp) and unit may move.
	# Action: among ALL legal tiles (incl. staying) prefer those within TEAM_RADIUS of a teammate (all tiles if none),
	# take minimum predicted hit; ties -> tile that can attack AND is safe, then farther from nearest enemy, then (y,x).
	# Switch only if strictly lower predicted hit than the original choice; else keep original behaviour.
	var retreated := false
	if retreat_enabled and can_move and threat[chosen] + RETREAT_LETHAL_MARGIN >= unit.hp:
		print("RTRIG unit=%d hp=%d at=%s chosen=%s thr_chosen=%d thr_origin=%d" % [id, unit.hp, origin, chosen, threat[chosen], threat[origin]])
		var mates: Array[Vector2i] = []
		for p: Unit in s.units_of(Unit.Faction.PLAYER):
			if p.id != id and p.is_alive():
				mates.append(s.position_of(p.id))
		var near: Array[Vector2i] = []
		for t in cands:
			for m in mates:
				if absi(t.x - m.x) + absi(t.y - m.y) <= retreat_radius:
					near.append(t)
					break
		var rp: Array[Vector2i] = near if not near.is_empty() else cands
		var rbest: Vector2i = rp[0]
		var rb_thr: int = threat[rbest]
		var rb_safe_atk := false
		var rb_d := -1
		for t in rp:
			var tt: int = threat[t]
			var tatt: Array[Unit] = GreedyTacticalAI._attackable_from(s, unit, t, enemies)
			var safe_atk: bool = can_attack and (not tatt.is_empty()) and tt < unit.hp
			var td: int = GreedyTacticalAI._distance_to_nearest(t, s, enemies)
			var better := false
			if t == rp[0]:
				better = true
			elif tt != rb_thr:
				better = tt < rb_thr
			elif safe_atk != rb_safe_atk:
				better = safe_atk
			elif td != rb_d:
				better = td > rb_d
			else:
				better = _yx_less(t, rbest)
			if better:
				rbest = t
				rb_thr = tt
				rb_safe_atk = safe_atk
				rb_d = td
		if rb_thr < threat[chosen]:
			chosen = rbest
			ca = GreedyTacticalAI._attackable_from(s, unit, chosen, enemies)
			retreated = true
	# ===== END RETREAT =====
	var mv: Variant = null
	if can_move and chosen != origin:
		mv = chosen
	var at := -1
	if can_attack and not (retreated and threat[chosen] + RETREAT_LETHAL_MARGIN >= unit.hp):
		var can_f := false
		for e: Unit in ca:
			if e.id == focus:
				can_f = true
		at = focus if (focus != -1 and can_f) else GreedyTacticalAI._best_target(ca)
	return {"move_to": mv, "attack": at}
