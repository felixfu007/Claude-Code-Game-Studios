extends SceneTree
## Single-point check (registration hard requirement 1): on the vs02 start state, 甲(id1) stands at (0,1) next to
## 乙(id2) at (0,2) with a POSITIVE link => Phi(甲)=+3 => guard must be 2 when E1(id6) attacks 甲.
## Mirrors the runner's seeding and its attach_defense_phi_provider wiring. Reads real vs02 data files.
var _keep: Array = []
func _rows(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for raw in text.split("\n"):
		var l: String = raw.replace("\r", "")
		if not l.is_empty():
			out.append(l)
	return out
func _init() -> void:
	var state: BattleState = BattleState.create(_rows(FileAccess.get_file_as_string("res://assets/data/levels/vs02_terrain.txt")), FileAccess.get_file_as_string("res://assets/data/units/vs02_roster.txt"))
	var pool := AffinityDataPool.new()
	var links_v: Variant = AffinityLink.links_from_text(FileAccess.get_file_as_string("res://assets/data/affinity/vs02_affinity_links.txt"))
	for link: AffinityLink in links_v:
		var ca: Variant = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_a)
		var cb: Variant = AffinityRosterCharacterMapper.character_for_roster_id(link.unit_b)
		var amp: float = float(AffinityLink.AMP_EXPECTED) if link.polarity == AffinityLink.Polarity.POSITIVE else -float(AffinityLink.AMP_EXPECTED)
		pool.append_record(AffinityTypes.pair_of(ca, cb), amp, AffinityTypes.Source.STORY_EVENT)
	var prov := AffinityPhiProvider.new(state, pool)
	_keep.append(prov)
	_keep.append(pool)
	var before: Dictionary = state.preview_damage_breakdown(6, 1, 0).breakdown
	print("GUARDCHECK before attach: ", before)
	state.attach_defense_phi_provider(Callable(prov, "phi_of"))
	var after: Dictionary = state.preview_damage_breakdown(6, 1, 0).breakdown
	print("GUARDCHECK after attach : ", after)
	print("GUARDCHECK phi_of(1)=%d expected_phi_def=3 guard=%d expected_guard=2 -> %s" % [prov.phi_of(1), int(after["guard"]), "OK" if (int(after["phi_def"]) == 3 and int(after["guard"]) == 2) else "MISMATCH"])
	quit()
