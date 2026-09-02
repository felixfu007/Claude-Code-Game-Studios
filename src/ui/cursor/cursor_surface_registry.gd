## Two structurally independent registration tables for the cursor/
## highlight-state system (ADR-0005 機制三, TR-cursor-003).
##
## [b]Table 1 — registered cursor surfaces[/b] ([method register] /
## [method unregister] / [method get_surface] /
## [method registered_surfaces_sorted]): single-tag, single-instance,
## [code]CursorTypes.SurfaceType[/code]-keyed. Owned by whichever system
## mounts/unmounts that surface type; lifecycle managed via explicit
## [method unregister] calls (no automatic cleanup — see rationale below).
##
## [b]Table 2 — AC-60 native-pointer exception whitelist[/b]
## ([method register_native_pointer_exception] /
## [method unregister_native_pointer_exception] /
## [method is_native_pointer_exception]): unbounded, untagged, come-and-go
## [Control] nodes that are NOT under this system's jurisdiction (GDD AC-60)
## but need to be recognized by 機制十三之二's hover-based native-pointer
## restoration.
##
## [b]Why two independent tables and not one table with a flag[/b] (ADR-0005
## 機制三): the two have different lifecycle owners. Table 1 is governed by
## this system's registration contract (one tag, one instance, explicit
## unregister). Table 2 is explicitly OUTSIDE this system's jurisdiction —
## it can have any number of entries, no tags, and free entry/exit. Merging
## them would force an "excepted from jurisdiction, but listed inside the
## jurisdiction table" contradiction, and would pollute
## [method registered_surfaces_sorted]'s iteration semantics.
##
## [b]This story (003) implements the registry only[/b] — not [code]CursorState[/code]
## (Stories 002/007) and not the presentation-layer hover consumer (Story 011).
## See [code]tests/unit/cursor/surface_registry_test.gd[/code]'s doc comment for
## exactly which half of each GDD acceptance criterion is exercised at this
## layer versus deferred to a later story.
class_name CursorSurfaceRegistry
extends RefCounted


## Result of [method register] / [method unregister] (table 1 only).
## Deliberately a SEPARATE enum from [enum ExceptionRegisterResult] — see
## class doc comment on why the two tables do not share a return type either
## (2026-08-21, R6-13): sharing one enum let [constant DUPLICATE_TAG_REJECTED]
## (a tag concept) leak into table 2's return type, which explicitly has no
## tag concept.
enum RegisterResult { REGISTERED, DUPLICATE_TAG_REJECTED, UNREGISTERED_NOT_FOUND }

## Result of [method register_native_pointer_exception] /
## [method unregister_native_pointer_exception] (table 2 only).
enum ExceptionRegisterResult { REGISTERED, ALREADY_EXCEPTED, NOT_REGISTERED, INVALID_NODE }

# ─── Table 1: registered cursor surfaces ────────────────────────────────────
var _surfaces: Dictionary[CursorTypes.SurfaceType, Node] = {}

# ─── Table 2: AC-60 native-pointer exception whitelist ──────────────────────
var _native_pointer_exceptions: Array[Control] = []


## Registers [param node] under [param surface]. Fails loud
## ([constant DUPLICATE_TAG_REJECTED]) on an already-occupied tag — does
## [b]NOT[/b] overwrite (TR-cursor-003), matching ADR-0002's
## [code]notify_death()[/code] idempotent-rejection convention.
##
## [param node] is deliberately a generic [Node], not [Control] — this ADR
## does not require registered surfaces to be [Control] (機制十四 "專家發現 F"):
## forcing a single type would upgrade a presentation-layer constraint into an
## architectural restriction on how the tactical board is implemented.
func register(surface: CursorTypes.SurfaceType, node: Node) -> RegisterResult:
	if _surfaces.has(surface):
		return RegisterResult.DUPLICATE_TAG_REJECTED
	_surfaces[surface] = node
	return RegisterResult.REGISTERED


## Removes the surface currently registered under [param surface], if any.
## Returns [constant UNREGISTERED_NOT_FOUND] (not silently a no-op) when
## nothing is registered under that tag — including a second call after an
## already-successful unregister.
func unregister(surface: CursorTypes.SurfaceType) -> RegisterResult:
	if not _surfaces.has(surface):
		return RegisterResult.UNREGISTERED_NOT_FOUND
	_surfaces.erase(surface)
	return RegisterResult.REGISTERED


## Returns the [Node] registered under [param surface], or [code]null[/code]
## if no surface is currently registered under that tag.
func get_surface(surface: CursorTypes.SurfaceType) -> Node:
	return _surfaces.get(surface)


## Returns all currently-registered surface tags, sorted by the enum's
## underlying [int] value. [b]Callers MUST use this method for any
## iteration[/b] — never iterate [code]_surfaces[/code] directly (forbidden
## pattern [code]relying_on_container_iteration_order[/code], ADR-0001,
## cited by ADR-0005 機制三). [code]Dictionary[/code] does not guarantee
## insertion order is preserved across all operations, and this method's
## contract is explicitly "sorted by tag value", independent of registration
## order.
func registered_surfaces_sorted() -> Array[CursorTypes.SurfaceType]:
	var tags: Array[CursorTypes.SurfaceType] = []
	for tag: CursorTypes.SurfaceType in _surfaces.keys():
		tags.append(tag)
	tags.sort()
	return tags


## Registers [param node] as an AC-60 native-pointer exception — a surface
## explicitly outside this system's jurisdiction that should still let the
## player see the native OS/engine mouse pointer while hovered (機制十三之二).
##
## [b]is_instance_valid() is checked BEFORE any subsequent operation on
## [param node], including [method Object.connect]-equivalent
## [signal Node.tree_exited] wiring[/b] — calling a method on an already-freed
## object aborts the calling function outright (verified,
## [code]prototypes/engine-verification-spike-2026-08-20/[/code] C2/F-10), so
## [constant INVALID_NODE] could never be returned if the check ran after any
## such operation.
##
## [b]Engine finding (2026-09-02, this story's own test run)[/b]: for a
## statically [Control]-typed parameter like this one, an already-freed
## (non-null) argument never reaches this method's body at all — GDScript's
## typed-parameter boundary check rejects it with a script error
## ("previously freed... not a subclass of the expected argument class")
## and aborts the CALLER, one level higher than the C2/F-10 finding above.
## [constant INVALID_NODE] is therefore only reachable in practice via a
## [code]null[/code] argument; see
## [code]tests/unit/cursor/surface_registry_test.gd[/code] for the test that
## exercises this and documents the boundary in full.
##
## Auto-deregisters on [signal Node.tree_exited] — NOT
## [constant CONNECT_ONE_SHOT], and no caller-side unregister discipline is
## required, matching this table's "come and go freely" contract (unlike
## table 1's explicit-unregister contract). [b]Caveat (ADR-0005 explicit)[/b]:
## [signal Node.tree_exited] fires on ANY removal from the tree, not only
## deletion — a surface that manages its visibility via
## [code]add_child[/code]/[code]remove_child[/code] rather than
## [member CanvasItem.visible] will silently lose its exception status on
## every hide, and must call this method again after remounting. The failure
## direction stays safe (native pointer hidden — AC-60 convenience lost, Core
## Rules #5 not violated), but it is worth knowing before debugging a
## "the pointer disappeared on this panel" report.
func register_native_pointer_exception(node: Control) -> ExceptionRegisterResult:
	if not is_instance_valid(node):
		return ExceptionRegisterResult.INVALID_NODE
	if _native_pointer_exceptions.has(node):
		return ExceptionRegisterResult.ALREADY_EXCEPTED
	node.tree_exited.connect(_on_exception_node_tree_exited.bind(node))
	_native_pointer_exceptions.append(node)
	return ExceptionRegisterResult.REGISTERED


## Explicit removal, in addition to the automatic [signal Node.tree_exited]
## handler above. Same [code]is_instance_valid()[/code]-first discipline as
## [method register_native_pointer_exception].
func unregister_native_pointer_exception(node: Control) -> ExceptionRegisterResult:
	if not is_instance_valid(node):
		return ExceptionRegisterResult.INVALID_NODE
	if not _native_pointer_exceptions.has(node):
		return ExceptionRegisterResult.NOT_REGISTERED
	_native_pointer_exceptions.erase(node)
	return ExceptionRegisterResult.REGISTERED


## Whitelist membership check for 機制十三之二's hover judgment — walks
## [param node]'s ancestor chain, since [method Viewport.gui_get_hovered_control]
## may return a descendant of a registered exception surface rather than the
## exception surface's own root node.
func is_native_pointer_exception(node: Node) -> bool:
	var current: Node = node
	while current != null:
		if current in _native_pointer_exceptions:
			return true
		current = current.get_parent()
	return false


func _on_exception_node_tree_exited(node: Control) -> void:
	_native_pointer_exceptions.erase(node)
