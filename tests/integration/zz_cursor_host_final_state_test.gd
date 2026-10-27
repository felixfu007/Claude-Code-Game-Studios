extends GdUnitTestSuite
## Final-state check: after every other suite has run, the shared
## CursorStateHost Autoload must be back at its pristine initial state.
## Initial values taken from the actual code, not guessed:
##  - CursorState._init: _target = CursorTarget.new() (surface = enum ordinal 0
##    = BOARD_TILE, id = 0, is_valid = false), _device_authority = UNINITIALIZED
##  - CursorStateHost: _arbitration_suspended = false, _frame_events = []
##  - CursorSurfaceRegistry: _surfaces / _guard_verdicts / exceptions empty
## ORDER ASSUMPTION (full-run log shows this suite last in tests/integration, 2026-10-27, but NOT a GdUnit4 guarantee): GdUnit4's scanner
## walks directories via DirAccess.get_next() (GdUnitTestSuiteScanner.gd), so
## order is filesystem order, not a guarantee. This suite must be the LAST one
## to run for its check to mean anything; "zz_" only makes that likely.
## Fails list ALL residues in one message so the culprit is easy to bisect.


func test_cursor_host_is_pristine_after_all_other_suites() -> void:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	assert_object(host).is_not_null()
	var state: CursorState = host.get(&"_state")
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	var residue: PackedStringArray = []
	var surfaces: Dictionary = registry.get(&"_surfaces")
	if not surfaces.is_empty():
		residue.append("registry._surfaces=%s" % str(surfaces))
	var verdicts: Dictionary = registry.get(&"_guard_verdicts")
	if not verdicts.is_empty():
		residue.append("registry._guard_verdicts=%s" % str(verdicts))
	var exceptions: Array = registry.get(&"_native_pointer_exceptions")
	if not exceptions.is_empty():
		residue.append("registry._native_pointer_exceptions=%s" % str(exceptions))
	var tgt: CursorTarget = state.get_current_target()
	if tgt.is_valid or tgt.id != 0 or tgt.surface != CursorTypes.SurfaceType.BOARD_TILE:
		residue.append("target=%s/%d/valid=%s" % [
			CursorTypes.SurfaceType.find_key(tgt.surface), tgt.id, tgt.is_valid])
	if state.get_device_authority() != CursorTypes.Authority.UNINITIALIZED:
		residue.append("authority=%s" % CursorTypes.Authority.find_key(state.get_device_authority()))
	if host.get(&"_arbitration_suspended") != false:
		residue.append("_arbitration_suspended=true")
	if (host.get(&"_frame_events") as Array).size() != 0:
		residue.append("_frame_events.size=%d" % (host.get(&"_frame_events") as Array).size())
	if get_tree().paused:
		residue.append("tree.paused=true")
	assert_str(", ".join(residue)).override_failure_message(
		"CursorStateHost left dirty by earlier suites: " + ", ".join(residue)).is_empty()
