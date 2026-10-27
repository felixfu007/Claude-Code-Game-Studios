## Throwaway probe (2026-10-27, qa-lead audit). NOT a real test: it never asserts
## anything about production code. It only PRINTS the shared CursorStateHost's
## mutable state at suite start, so a run of "<some test file> + this file"
## shows what that file left behind. Reads only; writes nothing.
## Method: engine executes the project's REAL CursorStateHost autoload and the
## REAL test files; this probe re-implements no rule.
extends GdUnitTestSuite


func before() -> void:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var reg: CursorSurfaceRegistry = host.get(&"_registry")
	var state: CursorState = host.get(&"_state")
	var tgt: CursorTarget = state.get_current_target()
	var surfaces: Array = []
	for s: int in reg.registered_surfaces_sorted():
		var n: Node = reg.get_surface(s)
		surfaces.append("%s->%s" % [CursorTypes.SurfaceType.find_key(s), str(n)])
	print("ISOPROBE surfaces=", surfaces,
		" authority=", CursorTypes.Authority.find_key(state.get_device_authority()),
		" target=", "%s/%d/valid=%s" % [CursorTypes.SurfaceType.find_key(tgt.surface), tgt.id, tgt.is_valid],
		" suspended=", host.get(&"_arbitration_suspended"),
		" frame_events=", (host.get(&"_frame_events") as Array).size(),
		" tree_paused=", get_tree().paused,
		" root_children=", get_tree().root.get_child_count())


func test_probe_noop() -> void:
	assert_bool(true).is_true()
