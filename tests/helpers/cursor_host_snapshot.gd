class_name CursorHostSnapshot
extends RefCounted
## Test helper (2026-10-27, qa-lead isolation audit -> manager ruling "fix the test side").
##
## Snapshots and restores the mutable state of the process-wide [code]CursorStateHost[/code]
## Autoload, which every test file shares. Typical use:
## [codeblock]
## var _snap: CursorHostSnapshot
## func before_test() -> void: _snap = CursorHostSnapshot.capture()
## func after_test() -> void: _snap.restore()
## [/codeblock]
##
## Covered state (see docs/reviews/cursor-host-test-isolation-audit-2026-10-27.md):
## CursorState._target (copy, incl. is_valid), CursorState._device_authority,
## CursorStateHost._arbitration_suspended, CursorStateHost._frame_events,
## CursorStateHost._state / _registry object identity (re-pinned),
## CursorSurfaceRegistry._surfaces / _guard_verdicts / _native_pointer_exceptions,
## SceneTree.paused.
## NOT covered (flagged, not silently omitted): CursorState._last_mouse_position,
## _pending_reseed, _provider_error_reported, diagnostic_* counters, the reclaim
## policy's accumulator, host.diagnostic_process_tick_count, and signal
## connections added to the shared CursorState (state_host_test.gd's reseed
## lambda -- the audit lists it separately).
##
## RISK / WHY PRIVATE FIELDS: this is a test helper and reads/writes underscore
## fields via Object.get()/set() because no public API can restore a target or
## authority without going through gated write paths (which emit signals and
## apply policy). If src renames any of those fields, [method capture] push_errors
## (fails loud, never silent) -- update this file together with the rename.
##
## Freed nodes: registry entries whose node was freed between capture and
## restore are dropped on restore (re-registering a freed instance is what
## caused "Trying to return a previously freed instance." historically).
## Entries whose node is still valid are restored.

const _HOST_PATH: NodePath = ^"/root/CursorStateHost"

var _ok: bool = false
var _suspended: bool = false
var _frame_events: Array[InputEvent] = []
var _target: CursorTarget = null
var _authority: int = 0
var _surfaces: Dictionary = {}
var _guard_verdicts: Dictionary = {}
var _exceptions: Array = []
var _tree_paused: bool = false
var _state_ref: CursorState = null        ## original host._state object (state_host_test swaps spies in)
var _registry_ref: CursorSurfaceRegistry = null  ## original host._registry object


static func capture() -> CursorHostSnapshot:
	var snap: CursorHostSnapshot = CursorHostSnapshot.new()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var host: Node = tree.root.get_node_or_null(_HOST_PATH) if tree != null else null
	if host == null:
		push_error("CursorHostSnapshot.capture: CursorStateHost autoload not found")
		return snap
	var state: CursorState = host.get(&"_state") as CursorState
	var registry: CursorSurfaceRegistry = host.get(&"_registry") as CursorSurfaceRegistry
	if state == null or registry == null:
		push_error("CursorHostSnapshot.capture: host._state/_registry missing (src field renamed?)")
		return snap
	var cur: CursorTarget = state.get_current_target()
	snap._target = CursorTarget.new()
	snap._target.surface = cur.surface
	snap._target.id = cur.id
	snap._target.is_valid = cur.is_valid
	snap._authority = state.get_device_authority()
	snap._suspended = host.get(&"_arbitration_suspended")
	var events: Array = host.get(&"_frame_events")
	snap._frame_events.assign(events)
	snap._surfaces = (registry.get(&"_surfaces") as Dictionary).duplicate()
	snap._guard_verdicts = (registry.get(&"_guard_verdicts") as Dictionary).duplicate()
	snap._exceptions = (registry.get(&"_native_pointer_exceptions") as Array).duplicate()
	snap._tree_paused = tree.paused
	snap._state_ref = state
	snap._registry_ref = registry
	snap._ok = true
	return snap


func restore() -> void:
	if not _ok:
		push_error("CursorHostSnapshot.restore: snapshot was not captured successfully")
		return
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var host: Node = tree.root.get_node_or_null(_HOST_PATH)
	if host == null:
		push_error("CursorHostSnapshot.restore: CursorStateHost autoload not found")
		return
	# Unpause first, same ordering convention as battle_menu_gating_test.
	tree.paused = _tree_paused
	# Re-pin the ORIGINAL collaborator objects first: a test that swapped in a spy
	# and was interrupted before its inline restore would otherwise make us
	# restore into the spy.
	host.set(&"_state", _state_ref)
	host.set(&"_registry", _registry_ref)
	var state: CursorState = _state_ref
	var registry: CursorSurfaceRegistry = _registry_ref
	host.set(&"_arbitration_suspended", _suspended)
	var events: Array = host.get(&"_frame_events")
	events.clear()
	events.append_array(_frame_events)
	var target: CursorTarget = CursorTarget.new()
	target.surface = _target.surface
	target.id = _target.id
	target.is_valid = _target.is_valid
	state.set(&"_target", target)
	state.set(&"_device_authority", _authority)

	var surfaces: Dictionary = registry.get(&"_surfaces")
	surfaces.clear()
	for key: Variant in _surfaces:
		var node: Object = _surfaces[key]
		if is_instance_valid(node):
			surfaces[key] = node
	var verdicts: Dictionary = registry.get(&"_guard_verdicts")
	verdicts.clear()
	for key: Variant in _guard_verdicts:
		verdicts[key] = _guard_verdicts[key]
	var exceptions: Array = registry.get(&"_native_pointer_exceptions")
	exceptions.clear()
	for node: Object in _exceptions:
		if is_instance_valid(node):
			exceptions.append(node)
