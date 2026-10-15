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
##
## [b]Story 012 (ADR-0005 機制十四 guard, 2026-10-15)[/b]: [method register]
## enforces 機制十四's two conditions on any [param node] that [code]is
## Control[/code] (see that method's own doc comment and
## [enum RegisterResult]'s two new members for the mechanics). Governing
## execution contract: [code]docs/reviews/cursor-surface-register-guard-contract-2026-10-15.md[/code]
## ("甲案" — reject at the [method register] entry point rather than register
## and merely log).
class_name CursorSurfaceRegistry
extends RefCounted


## Result of [method register] / [method unregister] (table 1 only).
## Deliberately a SEPARATE enum from [enum ExceptionRegisterResult] — see
## class doc comment on why the two tables do not share a return type either
## (2026-08-21, R6-13): sharing one enum let [constant DUPLICATE_TAG_REJECTED]
## (a tag concept) leak into table 2's return type, which explicitly has no
## tag concept.
## [b]INVALID_NODE added 2026-09-02 (three-way-review remediation)[/b]: before
## this, [method register] had no validity check on [param node] at all — an
## invalid/[code]null[/code] node was silently accepted, reported as
## [constant REGISTERED], stored, and then permanently squatted the tag (a
## later, genuine registration under the same tag would be rejected as
## [constant DUPLICATE_TAG_REJECTED] with no way to tell why). This mirrors
## the check [method register_native_pointer_exception] already had for table
## 2; the two tables now handle the same failure the same way. No enum member
## was removed or reordered, so no existing caller comparing against the
## other three named members is affected — see
## [code]tests/unit/cursor/surface_registry_test.gd[/code] for the
## corresponding tests.
## [b]FOCUS_MODE_NOT_NONE_REJECTED / NATIVE_HOVER_THEME_REJECTED added
## 2026-10-15 (Story 012, ADR-0005 機制十四 guard)[/b]: appended at the END
## (ordinals 4/5) — same discipline as [constant INVALID_NODE] above, no
## existing member removed or reordered. Returned only when [param node]
## [code]is Control[/code] (機制十四's two conditions are structurally
## inapplicable to any other node type — see [method register]'s doc
## comment). When [b]both[/b] conditions are violated simultaneously,
## [method register] returns [constant FOCUS_MODE_NOT_NONE_REJECTED] (the
## lower ordinal) — deterministic by construction, not by which check
## happens to run first — but its [method @GlobalScope.push_error] message
## always reports BOTH conditions' verdicts, so a caller is never left having
## to fix one violation only to immediately hit the other with no warning.
enum RegisterResult {
	REGISTERED,                    # 0 — unchanged
	DUPLICATE_TAG_REJECTED,        # 1 — unchanged
	UNREGISTERED_NOT_FOUND,        # 2 — unchanged
	INVALID_NODE,                  # 3 — unchanged
	FOCUS_MODE_NOT_NONE_REJECTED,  # 4 — new: 機制十四 condition 1 violated (focus_mode != FOCUS_NONE)
	NATIVE_HOVER_THEME_REJECTED,   # 5 — new: 機制十四 condition 2 violated (built-in hover/focus theme state)
}

## QA/diagnostic-only verdict of the LAST [method register] call's 機制十四
## guard evaluation for a given [param surface] tag — see
## [method diagnostic_last_guard_verdict]. [b]Downstream business logic must
## NEVER branch on this[/b] (same convention as this project's other
## [code]diagnostic_*[/code] accessors, 機制十五). Deliberately a 4-value enum,
## not 3: [constant NOT_APPLICABLE] means "the guard ran and the node's type
## structurally exempts it" (non-[Control] — see [method register]);
## [constant NEVER_ATTEMPTED] means "no [method register] call has ever been
## made under this tag" — collapsing the two into one value would recreate
## the exact ambiguity this contract was written to avoid (see
## [code]docs/reviews/cursor-surface-register-guard-contract-2026-10-15.md[/code]
## 第四節, and this project's 2026-09-23 Check-4 "N/A ≠ PASS" precedent in
## [code].claude/docs/coding-standards.md[/code]).
## [b]Lifecycle (implementer's call — contract 第四節 left this undecided,
## flagged "stop and ask before implementing")[/b]: a verdict is recorded
## only on a [method register] call that actually reaches the guard (i.e.
## NOT on [constant INVALID_NODE] or [constant DUPLICATE_TAG_REJECTED] early
## returns, which never touch the guard at all) and is [b]retained[/b] across
## a later [method unregister] — this is "the verdict from the last
## register() call", a historical fact about that call, not "is this tag
## currently mounted". [method unregister] does not clear it.
enum GuardVerdict { NOT_APPLICABLE, PASSED, REJECTED, NEVER_ATTEMPTED }

## Result of [method register_native_pointer_exception] /
## [method unregister_native_pointer_exception] (table 2 only).
enum ExceptionRegisterResult { REGISTERED, ALREADY_EXCEPTED, NOT_REGISTERED, INVALID_NODE }

# ─── Table 1: registered cursor surfaces ────────────────────────────────────
var _surfaces: Dictionary[CursorTypes.SurfaceType, Node] = {}

## QA/diagnostic-only — see [enum GuardVerdict] and
## [method diagnostic_last_guard_verdict]. NOT consulted by [method register]
## or [method unregister]'s own control flow.
var _guard_verdicts: Dictionary[CursorTypes.SurfaceType, GuardVerdict] = {}

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
##
## [b]is_instance_valid() is checked BEFORE the duplicate-tag check[/b] (added
## 2026-09-02, three-way-review remediation), matching
## [method register_native_pointer_exception]'s existing discipline for table
## 2. Without this, a [code]null[/code] [param node] was silently accepted,
## reported as [constant REGISTERED], and the tag was then permanently
## unusable — [method get_surface] returns the invalid value forever, and no
## later genuine registration under that tag can ever succeed, since it will
## report [constant DUPLICATE_TAG_REJECTED] against an entry nobody can see
## is broken. Per this project's release-build-safe error handling ruling
## (`production/session-state/active.md`, 2026-09-02 "裁決二": guards that
## must survive into shipping builds return an explicit failure value rather
## than rely on [method @GlobalScope.assert], which the engine may strip from
## release export builds), this returns [constant INVALID_NODE] rather than
## asserting.
##
## [b]As with [method register_native_pointer_exception] (see that method's
## own "Engine finding" note)[/b]: for a statically typed [Node] parameter
## like this one, an already-freed (non-null) argument never reaches this
## method's body at all — GDScript's typed-parameter boundary check rejects
## it and aborts the CALLER before this line runs. [constant INVALID_NODE] is
## therefore only reachable in practice via a [code]null[/code] argument, not
## a use-after-free of a previously-valid reference.
##
## [b]ADR-0005 機制十四 guard (Story 012, 2026-10-15) — runs AFTER the
## duplicate-tag check above, BEFORE storing[/b]
## ([code]docs/reviews/cursor-surface-register-guard-contract-2026-10-15.md[/code]
## 第二節's placement contract: the guard may only turn an input that would
## otherwise have returned [constant REGISTERED] into a rejection — it must
## NEVER change what would otherwise have been [constant DUPLICATE_TAG_REJECTED]
## into a different rejection code). Applies ONLY when [param node]
## [code]is Control[/code] (機制十四's type-split table: non-[Control] node
## types have neither a [code]focus_mode[/code] nor a theme StyleBox and are
## structurally exempt, not merely assumed compliant — see
## [enum GuardVerdict]).
##
## Two conditions, [b]both[/b] required:
## 1. [member Control.focus_mode] [code]== Control.FOCUS_NONE[/code].
## 2. No built-in mouse-hover (or keyboard/gamepad-focus) theme StyleBox.
##    Mechanical proxy for the ADR's "visually indistinguishable" requirement
##    (engine-verified 2026-10-15,
##    [code]prototypes/godot-gdscript-specialist-cursor-guard-probe-2026-10-15/[/code]):
##    a "hover" (or "focus") theme StyleBox is a violation unless it is the
##    [b]exact same resource instance[/b] (reference-equal, via
##    [method Control.get_theme_stylebox]) as the "normal" StyleBox.
##    [b]Escape hatch[/b]: call
##    [code]add_theme_stylebox_override(&"hover", <the SAME instance used for
##    "normal">)[/code] (and likewise for [code]&"focus"[/code]) — confirmed
##    by the probe above to compare reference-equal afterward.
##    [b]Known, accepted over-rejection[/b] (probe Case 3): two DIFFERENT
##    [StyleBox] instances that are visually identical still compare
##    reference-UNEQUAL and are judged a violation. This is a stricter
##    constraint than the ADR's own wording and is the contract's deliberate
##    choice (reject-on-doubt, not pass-on-doubt) — use the same instance, not
##    a second instance with matching properties.
##
## Violating EITHER condition rejects the registration outright (does
## [b]NOT[/b] store [param node] — [method get_surface] keeps returning
## whatever it already returned for [param surface]). Violating BOTH returns
## [constant FOCUS_MODE_NOT_NONE_REJECTED] (the lower ordinal — deterministic,
## not evaluation-order-dependent), but [method @GlobalScope.push_error] always
## reports both conditions' verdicts so a caller does not fix one violation
## only to discover the other on the next attempt. [b]No [code]assert()[/code]
## is used in this guard[/b] (2026-09-15 ordinal-0 finding,
## [code].claude/docs/coding-standards.md[/code]: an [code]assert()[/code]
## failure aborts the function and yields ordinal 0 of its declared return
## type — [constant REGISTERED] here — silently reporting success for a
## rejected write).
func register(surface: CursorTypes.SurfaceType, node: Node) -> RegisterResult:
	if not is_instance_valid(node):
		return RegisterResult.INVALID_NODE
	if _surfaces.has(surface):
		return RegisterResult.DUPLICATE_TAG_REJECTED

	if node is Control:
		var control: Control = node as Control
		var focus_mode_ok: bool = control.focus_mode == Control.FOCUS_NONE
		var hover_violates: bool = _stylebox_state_differs_from_normal(control, &"hover")
		var focus_violates: bool = _stylebox_state_differs_from_normal(control, &"focus")
		var hover_theme_ok: bool = not (hover_violates or focus_violates)
		if not focus_mode_ok or not hover_theme_ok:
			_guard_verdicts[surface] = GuardVerdict.REJECTED
			push_error(
				(
					"CursorSurfaceRegistry register() rejected surface %s by ADR-0005 " +
					"機制十四 guard -- node_class=%s node_path=%s. " +
					"Condition 1 (focus_mode == FOCUS_NONE): %s (actual focus_mode=%d, " +
					"FOCUS_NONE=%d). Condition 2 (no built-in hover/focus theme state): " +
					"%s (hover_differs_from_normal=%s, focus_differs_from_normal=%s). " +
					"Fix: set focus_mode = Control.FOCUS_NONE, and if this node type has " +
					"a built-in theme, override its hover/focus StyleBox with the SAME " +
					"instance used for its normal StyleBox via add_theme_stylebox_override() " +
					"so they compare reference-equal."
				) % [
					CursorTypes.SurfaceType.find_key(surface),
					control.get_class(),
					(control.get_path() if control.is_inside_tree() else "<not in tree>"),
					("OK" if focus_mode_ok else "VIOLATED"),
					control.focus_mode,
					Control.FOCUS_NONE,
					("OK" if hover_theme_ok else "VIOLATED"),
					hover_violates,
					focus_violates,
				]
			)
			if not focus_mode_ok:
				return RegisterResult.FOCUS_MODE_NOT_NONE_REJECTED
			return RegisterResult.NATIVE_HOVER_THEME_REJECTED
		_guard_verdicts[surface] = GuardVerdict.PASSED
	else:
		# Structurally exempt (not merely "assumed compliant") — see
		# [enum GuardVerdict]'s doc comment on why this must be recorded as
		# NOT_APPLICABLE and never as PASSED.
		_guard_verdicts[surface] = GuardVerdict.NOT_APPLICABLE

	_surfaces[surface] = node
	return RegisterResult.REGISTERED


## Mechanism-14 guard helper (condition 2) — returns [code]true[/code] (a
## violation) when [param control] has a theme StyleBox for [param theme_key]
## ([code]&"hover"[/code] or [code]&"focus"[/code]) that is NOT the exact same
## resource instance as its [code]&"normal"[/code] StyleBox. See
## [method register]'s doc comment for the engine evidence this relies on and
## the known over-rejection case. [b]Single source of this comparison rule in
## the codebase[/b] — do not re-derive it elsewhere (this project has already
## been burned by two independent implementations of the same formula
## quietly drifting apart; see [code].claude/docs/technical-preferences.md[/code]
## 的「世界層縮放與定位改為手動管理」一節的 single-source-of-truth 教訓).
func _stylebox_state_differs_from_normal(control: Control, theme_key: StringName) -> bool:
	if not control.has_theme_stylebox(theme_key):
		return false
	var state_stylebox: StyleBox = control.get_theme_stylebox(theme_key)
	var normal_stylebox: StyleBox = (
		control.get_theme_stylebox(&"normal") if control.has_theme_stylebox(&"normal") else null
	)
	return state_stylebox != normal_stylebox


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


## QA/diagnostic-only accessor — see [enum GuardVerdict]'s doc comment for the
## full rationale (why [constant GuardVerdict.NOT_APPLICABLE] must not be
## conflated with "passed", and why this value survives [method unregister]).
## Downstream business logic must NEVER branch on this (機制十五 convention).
## Returns [constant GuardVerdict.NEVER_ATTEMPTED] for a [param surface] tag
## that has never had a [method register] call reach the guard at all (either
## no [method register] call was ever made under this tag, or every call made
## under it was rejected before reaching the guard by
## [constant RegisterResult.INVALID_NODE] or
## [constant RegisterResult.DUPLICATE_TAG_REJECTED]).
func diagnostic_last_guard_verdict(surface: CursorTypes.SurfaceType) -> GuardVerdict:
	return _guard_verdicts.get(surface, GuardVerdict.NEVER_ATTEMPTED)


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
