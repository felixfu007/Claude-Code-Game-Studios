extends SceneTree

# Probe 1 (dispatch brief §2): does `Array[QueryResult]` accept subclass
# instances (MoveTargetsBreakdownResult, DamageBreakdownResult)?
func _init() -> void:
	var terrain: PackedStringArray = PackedStringArray([".....", ".....", "....."])
	var roster: String = "1,Hero,PLAYER,10,5,3,3,1,1,0,0\n2,Goon,ENEMY,10,5,3,3,1,1,4,2"
	var state: BattleState = BattleState.create(terrain, roster)

	var move_result: MoveTargetsBreakdownResult = MoveTargetsBreakdownResult.new(state, {"legal": []})
	var dmg_result: DamageBreakdownResult = DamageBreakdownResult.new(state, {"damage": 5})

	var results: Array[QueryResult] = [move_result, dmg_result]
	print("PROBE1: Array[QueryResult] accepted %d subclass instances" % results.size())
	print("PROBE1: assert_same_version same-version -> ", QueryResult.assert_same_version(results))

	# Force a version bump, then test mixed-version detection.
	state.move_unit(1, Vector2i(1, 0))
	var stale_result: QueryResult = QueryResult.new(state)
	# move_result.version is now behind state.combat_state_version.
	var mixed: Array[QueryResult] = [move_result, stale_result]
	print("PROBE1: assert_same_version mixed-version -> ", QueryResult.assert_same_version(mixed))
	print("PROBE1: move_result.is_stale() -> ", move_result.is_stale())
	print("PROBE1: stale_result.is_stale() -> ", stale_result.is_stale())
	print("PROBE1: DONE")
	quit()
