## Probe: runs REAL CampaignAffinityLedger + CampaignAffinityPoolRebuilder + AffinityDataPool.
## Re-implements NOTHING. Question: value read next battle after ledger write with each Source.
extends SceneTree

func _read(src: AffinityTypes.Source, m: float, extra_dead: bool = false) -> void:
	var ledger := CampaignAffinityLedger.new()
	ledger.append(AffinityTypes.Pair.C1_C2, m, src)
	var pool: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(ledger)
	var nd = pool.narrative_depth_read(AffinityTypes.Pair.C1_C2)
	var cs = pool.combat_strength_read(AffinityTypes.Pair.C1_C2)
	print("PROBE src=", AffinityTypes.Source.find_key(src), " m=", m,
		" narrative_depth=", nd.value, " combat_strength=", cs.value, " n_pair=", nd.n_pair, " rej=", nd.rejection)

func _init() -> void:
	for s in [AffinityTypes.Source.SUPPORT_CONVERSATION, AffinityTypes.Source.STORY_EVENT, AffinityTypes.Source.COMBAT_CARD]:
		_read(s, 3.0)
		_read(s, -3.0)
	# order: support conv first then campfire, vs reverse (same pair), source SUPPORT_CONVERSATION both
	for order in [[2.0, 3.0], [3.0, 2.0]]:
		var l := CampaignAffinityLedger.new()
		for m in order:
			l.append(AffinityTypes.Pair.C1_C2, m, AffinityTypes.Source.SUPPORT_CONVERSATION)
		var p: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(l)
		print("PROBE order=", order, " narrative_depth=", p.narrative_depth_read(AffinityTypes.Pair.C1_C2).value)
	# order across pairs/opposite signs
	for order in [[3.0, -1.0], [-1.0, 3.0]]:
		var l2 := CampaignAffinityLedger.new()
		for m in order:
			l2.append(AffinityTypes.Pair.C1_C2, m, AffinityTypes.Source.SUPPORT_CONVERSATION)
		var p2: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(l2)
		print("PROBE order=", order, " narrative_depth=", p2.narrative_depth_read(AffinityTypes.Pair.C1_C2).value)
	# does a fresh rebuilt pool carry death state?
	var l3 := CampaignAffinityLedger.new()
	l3.append(AffinityTypes.Pair.C1_C2, 2.0, AffinityTypes.Source.SUPPORT_CONVERSATION)
	var p3: AffinityDataPool = CampaignAffinityPoolRebuilder.rebuild(l3)
	print("PROBE fresh pool t_death(C1_C2)=", p3.t_death(AffinityTypes.Pair.C1_C2))
	quit()
