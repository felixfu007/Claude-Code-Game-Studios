extends SceneTree
## 協議 1 替代量測(電腦半)。依 docs/reviews/protocol1-computer-half-lock-plan-2026-11-05.md 第 1~5 節。
## 真實管線:load() BattleScreen.tscn -> instantiate -> 設 override -> call_deferred add_child -> 等 2 幀。
## 正解 = BattleScreen._guess_delta_for_cell() -> EffectGuessTracker.classify_delta。
## 腳本內不重寫 delta / 夾限 / 距離 / 可移動範圍:全部呼叫 AffinityRules / BattleController。

const SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const POS: int = EffectGuessTracker.EffectDirection.POSITIVE
const NEG: int = EffectGuessTracker.EffectDirection.NEGATIVE
const NEU: int = EffectGuessTracker.EffectDirection.NEUTRAL

const PRIMARY: Array[String] = ["tut04", "vs02", "vs03"]
const SECONDARY: Array[String] = ["vs04", "vs05"]

var _results: Dictionary = {}


func _initialize() -> void:
	_run()


func _cls_name(c: int) -> String:
	return {POS: "正", NEG: "負", NEU: "無"}[c]


func _paths(level: String) -> Dictionary:
	var is_tut: bool = level == "tut04"
	return {
		"terrain": "res://assets/data/levels/%s_terrain.txt" % level,
		"roster": "res://assets/data/units/%s_roster.txt" % level,
		"affinity": "res://assets/data/affinity/%s_affinity_links.txt" % level,
		"cards": "res://assets/data/cards/%s" % ("tutorial_cards.txt" if is_tut else "%s_cards.txt" % level),
		"card_text": "res://assets/data/cards/%s" % ("tutorial_card_text.txt" if is_tut else "%s_card_text.txt" % level),
	}


func _sym(state: int) -> int:
	if state == AffinityLineStatus.State.POSITIVE:
		return 1
	if state == AffinityLineStatus.State.NEGATIVE:
		return -1
	return 0


func _run() -> void:
	var all_levels: Array[String] = []
	all_levels.append_array(PRIMARY)
	all_levels.append_array(SECONDARY)
	for level: String in all_levels:
		await _measure_level(level)
	_report()
	print("ENGINE-SCRIPT-DONE")
	quit(0)


func _measure_level(level: String) -> void:
	var p: Dictionary = _paths(level)
	var scene: PackedScene = load(SCENE_PATH)
	var screen: Node = scene.instantiate()
	screen.terrain_path_override = p["terrain"]
	screen.roster_path_override = p["roster"]
	screen.affinity_path_override = p["affinity"]
	screen.cards_path_override = p["cards"]
	screen.card_text_path_override = p["card_text"]
	root.call_deferred("add_child", screen)
	await process_frame
	await process_frame

	print("=== LEVEL %s ===" % level)
	var wvc: Node = screen.find_child("WorldViewportContainer", true, false)
	var wv: Node = screen.find_child("WorldViewport", true, false)
	if wvc != null and wv != null:
		print("HOSTCHAIN %s: WorldViewportContainer.position=%s size=%s stretch_shrink=%s WorldViewport.size=%s" % [
			level, str(wvc.position), str(wvc.size), str(wvc.stretch_shrink), str(wv.size)])
	else:
		print("HOSTCHAIN %s: WorldViewportContainer/WorldViewport NOT FOUND" % level)

	var state: BattleState = screen._state
	var phi: AffinityPhiProvider = screen._phi
	var ctl: BattleController = screen._controller
	var t: AffinityTuning = state.affinity_tuning
	print("TUNING %s: delta_pos_adj=%d delta_pos_far=%d delta_neg_adj=%d delta_neg_far=%d delta_neutral=%d phi_min=%d phi_max=%d" % [
		level, t.delta_positive_adjacent(), t.delta_positive_far(), t.delta_negative_adjacent(),
		t.delta_negative_far(), t.delta_neutral(), t.phi_min(), t.phi_max()])
	var links: Array[AffinityLink] = phi.links()
	for l: AffinityLink in links:
		print("LINK %s: %d-%d polarity=%s amp=%d" % [level, l.unit_a, l.unit_b,
			"POSITIVE" if l.polarity == AffinityLink.Polarity.POSITIVE else "NEGATIVE", l.amp])
	var positions: Dictionary[int, Vector2i] = phi.positions()
	var pk: Array = positions.keys()
	pk.sort()
	for k: int in pk:
		print("POS %s: unit %d at %s" % [level, k, str(positions[k])])
	print("PHASE %s: phase=%s selectable=%s" % [level, str(ctl.phase()), str(ctl.selectable_units())])

	var acc: Dictionary = {
		"N_d": 0, "N_c": 0, "excluded": 0,
		"truth": {POS: 0, NEG: 0, NEU: 0},
		"p0n": 0, "p0p": 0, "p0g": 0, "p0c": 0,
		"p1": 0, "p2s": 0, "p2t": 0, "u_cells": 0, "u_decisions": 0,
		"p2_decidable_wrong": 0, "p2_decidable": 0,
		"recall": {"p0n": _z3(), "p0p": _z3(), "p0g": _z3(), "p0c": _z3(), "p1": _z3(), "p2s": _z3(), "p2t": _z3()},
	}

	for uid: int in ctl.selectable_units():
		# 該單位畫面上看得到的連線 = 有連線且對象在棋盤上
		var mine: Array[AffinityLink] = []
		for l: AffinityLink in links:
			if l.involves(uid) and positions.has(l.partner_of(uid)):
				mine.append(l)
		if mine.is_empty():
			acc["excluded"] += 1
			print("EXCLUDED %s: unit %d (no live link)" % [level, uid])
			continue
		if not ctl.select_unit(uid):
			print("ERROR %s: select_unit(%d) failed" % [level, uid])
			continue
		var cells: Array[Vector2i] = ctl.move_targets().cells.duplicate()
		ctl.deselect()
		# 行優先(y 再 x)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
		print("DECISION %s: unit %d at %s links=%d candidate_cells=%d" % [
			level, uid, str(positions[uid]), mine.size(), cells.size()])
		acc["N_d"] += 1

		# 畫面符號(目前狀態)
		var cur_syms: Array[int] = []
		var cur_dist: Array[int] = []
		var consistent: Array = []  # 每條連線:一致的極性列表
		for l: AffinityLink in mine:
			var st: AffinityLineStatus = AffinityRules.lines_for(uid, positions, [l] as Array[AffinityLink], t)[0]
			var s: int = _sym(st.state)
			cur_syms.append(s)
			cur_dist.append(st.distance)
			var ok: Array[int] = []
			for pol: int in [AffinityLink.Polarity.POSITIVE, AffinityLink.Polarity.NEGATIVE]:
				var h: AffinityLink = AffinityLink.new()
				h.unit_a = l.unit_a
				h.unit_b = l.unit_b
				h.amp = l.amp
				h.polarity = pol
				var hs: AffinityLineStatus = AffinityRules.lines_for(uid, positions, [h] as Array[AffinityLink], t)[0]
				if _sym(hs.state) == s:
					ok.append(pol)
			consistent.append(ok)
		# 極性假設笛卡兒積
		var combos: Array = [[]]
		for ok_list: Array in consistent:
			var nxt: Array = []
			for c0: Array in combos:
				for pol: int in ok_list:
					var c1: Array = c0.duplicate()
					c1.append(pol)
					nxt.append(c1)
			combos = nxt
		var decision_ambiguous: bool = false
		var cyc: int = 0
		var cyc_order: Array[int] = [POS, NEG, NEU]
		for cell: Vector2i in cells:
			var truth: int = EffectGuessTracker.classify_delta(screen._guess_delta_for_cell(uid, cell))
			acc["N_c"] += 1
			acc["truth"][truth] += 1
			# P0
			var g_cyc: int = cyc_order[cyc % 3]
			cyc += 1
			_score(acc, "p0n", NEU, truth)
			_score(acc, "p0p", POS, truth)
			_score(acc, "p0g", NEG, truth)
			_score(acc, "p0c", g_cyc, truth)
			# P1
			var votes: int = 0
			for i: int in range(mine.size()):
				var pp: Vector2i = positions[mine[i].partner_of(uid)]
				var d0: int = AffinityRules.manhattan_distance(positions[uid], pp)
				var d1: int = AffinityRules.manhattan_distance(cell, pp)
				votes += cur_syms[i] * signi(d0 - d1)
			var g1: int = POS if votes > 0 else (NEG if votes < 0 else NEU)
			_score(acc, "p1", g1, truth)
			# P2
			var counts: Dictionary = {POS: 0, NEG: 0, NEU: 0}
			for combo: Array in combos:
				var hl: Array[AffinityLink] = []
				for l: AffinityLink in links:
					var idx: int = mine.find(l)
					if idx == -1:
						hl.append(l)
					else:
						var h: AffinityLink = AffinityLink.new()
						h.unit_a = l.unit_a
						h.unit_b = l.unit_b
						h.amp = l.amp
						h.polarity = combo[idx]
						hl.append(h)
				var hypo: Dictionary[int, Vector2i] = phi.positions_with(uid, cell)
				var dl: int = AffinityRules.bonus_for_at(uid, cell, hypo, hl, t) \
					- AffinityRules.bonus_for(uid, positions, hl, t)
				counts[EffectGuessTracker.classify_delta(dl)] += 1
			var distinct: int = 0
			for k: int in counts:
				if counts[k] > 0:
					distinct += 1
			var tie_guess: int = NEU
			var best: int = -1
			for k: int in [POS, NEG, NEU]:
				if counts[k] > best:
					best = counts[k]
					tie_guess = k
				elif counts[k] == best and k != NEU and tie_guess != NEU:
					tie_guess = NEU  # 平手 -> 無效果
			# 平手一律 NEU:重新判定
			var maxc: int = maxi(counts[POS], maxi(counts[NEG], counts[NEU]))
			var top: Array[int] = []
			for k: int in [POS, NEG, NEU]:
				if counts[k] == maxc:
					top.append(k)
			tie_guess = top[0] if top.size() == 1 else NEU
			_score(acc, "p2t", tie_guess, truth)
			if distinct == 1:
				acc["p2_decidable"] += 1
				var only: int = top[0]
				if only != truth:
					acc["p2_decidable_wrong"] += 1
				_score(acc, "p2s", only, truth)
			else:
				acc["u_cells"] += 1
				decision_ambiguous = true
				# strict:無法決定算答錯(不給 recall 的 hit)
				acc["recall"]["p2s"][truth][1] += 1
		if decision_ambiguous:
			acc["u_decisions"] += 1
	_results[level] = acc
	screen.queue_free()
	await process_frame
	await process_frame


func _z3() -> Dictionary:
	return {POS: [0, 0], NEG: [0, 0], NEU: [0, 0]}


func _score(acc: Dictionary, key: String, guess: int, truth: int) -> void:
	acc["recall"][key][truth][1] += 1
	if guess == truth:
		acc[key] += 1
		acc["recall"][key][truth][0] += 1


func _pct(a: int, b: int) -> float:
	return 100.0 * float(a) / float(b) if b > 0 else 0.0


func _report() -> void:
	print("")
	print("##### REPORT #####")
	var per_level: Dictionary = {}
	for level: String in PRIMARY + SECONDARY:
		var a: Dictionary = _results[level]
		var n: int = a["N_c"]
		var p0: float = maxf(maxf(_pct(a["p0n"], n), _pct(a["p0p"], n)), maxf(_pct(a["p0g"], n), _pct(a["p0c"], n)))
		var m: Dictionary = {
			"P0": p0, "P0n": _pct(a["p0n"], n), "P0p": _pct(a["p0p"], n), "P0g": _pct(a["p0g"], n), "P0c": _pct(a["p0c"], n),
			"P1": _pct(a["p1"], n), "P2s": _pct(a["p2s"], n), "P2t": _pct(a["p2t"], n),
			"U": _pct(a["u_cells"], n), "Ud": _pct(a["u_decisions"], a["N_d"]),
		}
		per_level[level] = m
		print("REPORT %s: N_d=%d N_c=%d excluded_units=%d truth(正/負/無)=%.2f%%/%.2f%%/%.2f%% (%d/%d/%d)" % [
			level, a["N_d"], n, a["excluded"], _pct(a["truth"][POS], n), _pct(a["truth"][NEG], n), _pct(a["truth"][NEU], n),
			a["truth"][POS], a["truth"][NEG], a["truth"][NEU]])
		print("REPORT %s: P0-neutral=%.2f P0-positive=%.2f P0-negative=%.2f P0-cycle=%.2f  P0(max)=%.2f" % [
			level, m["P0n"], m["P0p"], m["P0g"], m["P0c"], p0])
		print("REPORT %s: P1=%.2f P2-strict=%.2f P2-tie=%.2f U_cells=%.2f%% (%d/%d) U_decisions=%.2f%% (%d/%d) P2_decidable=%d P2_decidable_wrong=%d" % [
			level, m["P1"], m["P2s"], m["P2t"], m["U"], a["u_cells"], n, m["Ud"], a["u_decisions"], a["N_d"],
			a["p2_decidable"], a["p2_decidable_wrong"]])
		for key: String in ["p0n", "p0p", "p0g", "p0c", "p1", "p2s", "p2t"]:
			var r: Dictionary = a["recall"][key]
			print("RECALL %s %s: 正 %d/%d  負 %d/%d  無 %d/%d" % [level, key,
				r[POS][0], r[POS][1], r[NEG][0], r[NEG][1], r[NEU][0], r[NEU][1]])
	for grp: Array in [["PRIMARY", PRIMARY], ["SECONDARY", SECONDARY]]:
		var names: Array = grp[1]
		var keys: Array[String] = ["P0", "P1", "P2s", "P2t", "U"]
		var line: String = "AVG(unweighted) %s:" % grp[0]
		for k: String in keys:
			var s: float = 0.0
			for lv: String in names:
				s += per_level[lv][k]
			line += " %s=%.2f" % [k, s / float(names.size())]
		print(line)

	print("")
	print("##### DIAGNOSIS (計畫第 4 節判讀表,逐關;無通過/未通過) #####")
	for level: String in PRIMARY + SECONDARY:
		var m: Dictionary = per_level[level]
		var a: Dictionary = _results[level]
		var tag: String = "[主要]" if PRIMARY.has(level) else "[次要]"
		if a["p2_decidable_wrong"] > 0:
			print("DIAG %s %s: 停止解讀 -- P2 可決定部分有 %d 筆答錯,視為腳本/規則不一致缺陷,交 lead-programmer" % [tag, level, a["p2_decidable_wrong"]])
			continue
		if m["P0"] >= 80.0:
			print("DIAG %s %s: P0=%.2f >= 80 -> 80%% 門檻無鑑別力(不讀畫面也過線);發現,非失敗" % [tag, level, m["P0"]])
		elif m["P0"] >= 70.0:
			print("DIAG %s %s: P0=%.2f 在 [70,80) -> 門檻鑑別力弱" % [tag, level, m["P0"]])
		else:
			print("DIAG %s %s: P0=%.2f < 70 -> 門檻在這關有鑑別空間" % [tag, level, m["P0"]])
		if m["P2s"] >= 80.0 and m["U"] <= 20.0:
			print("DIAG %s %s: P2-strict=%.2f>=80 且 U=%.2f<=20 -> 畫面資訊邏輯上足以達 80%%(僅上限,不代表人類做得到)" % [tag, level, m["P2s"], m["U"]])
		if m["U"] > 20.0:
			print("DIAG %s %s: U=%.2f > 20 -> UI 資訊不足診斷訊號,轉 ux-designer 評估(本計畫不改 UI)" % [tag, level, m["U"]])
		if m["P1"] < m["P0"] + 5.0:
			print("DIAG %s %s: P1=%.2f < P0+5=%.2f -> 天真讀法沒有比亂猜好多少(符號易誤導診斷訊號)" % [tag, level, m["P1"], m["P0"] + 5.0])
		if m["P1"] >= 80.0:
			print("DIAG %s %s: P1=%.2f >= 80 -> 天真讀法已過線,80%% 對略讀者可能偏易(非人類證據)" % [tag, level, m["P1"]])
		if m["P2s"] - m["P1"] >= 20.0:
			print("DIAG %s %s: P2-strict - P1 = %.2f >= 20 -> 教學曲線是關鍵變數" % [tag, level, m["P2s"] - m["P1"]])
		if m["P2t"] - m["P1"] >= 20.0:
			print("DIAG %s %s: P2-tie - P1 = %.2f >= 20 -> 教學曲線是關鍵變數" % [tag, level, m["P2t"] - m["P1"]])
