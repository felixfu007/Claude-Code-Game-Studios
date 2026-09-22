## Unit tests for [code]src/ui/cursor/cursor_state.gd[/code] and
## [code]src/ui/cursor/cursor_state_host.gd[/code] (Story 002) — the
## Autoload shell + dependency-injection core + three-field state
## (ADR-0005 機制一). Covers AC-1 / AC-2 / AC-15 / AC-16 from
## [code]production/epics/cursor-highlight-state/story-002-state-host.md[/code].
##
## [b]Scope narrowing — read before extending or "fixing" these tests[/b]:
## this story only builds the constructor + field shape. None of the
## following exist yet, and no test below fakes them into existing:
## - Story 005's frame-buffered arbitration timing.
## - Story 007's seven gated public write entries AND its read queries
##   ([code]get_current_target()[/code] / [code]get_device_authority()[/code] /
##   [code]is_current_target_valid()[/code] / [code]reclaim_progress()[/code] —
##   confirmed against that story's own work order, which owns
##   [code]TR-cursor-014[/code]'s read half, not this one).
## - Story 010's presentation [CanvasLayer] / rendered highlight visuals.
## - Story 014's concrete [MouseReclaimPolicy] subclass.
##
## Where the GDD's AC text describes behavior that spans those later stories,
## each test below documents exactly what IS verified at this layer and what
## is deferred — following the same pattern Story 001's
## [code]shared_types_test.gd[/code] and Story 003's
## [code]surface_registry_test.gd[/code] already established. This deferral
## is also pre-registered in [code]docs/tech-debt-register.md[/code]
## (2026-09-02 entry) so it is not silently assumed covered.
##
## - [b]AC-1[/b] ("exactly 3 top-level fields, no undocumented 4th"): fully
##   verifiable at this layer via script reflection
##   ([method Script.get_script_property_list]) — matching AC-1's own stated
##   verification method ("驗證方式:程式碼審查/靜態分析,非執行期黑盒測試").
##   [member CursorState._registry] and [member CursorState._mouse_position_provider]
##   are excluded from the count by name: they are constructor-injected
##   collaborators the frozen ADR-0005 Key Interfaces contract names
##   explicitly, not undocumented GDD state. [b]No manager ruling exists on
##   this question — do not cite one.[/b] The reading is this story's own
##   argument from AC-1's source text, independently checked during the
##   2026-09-02 three-way review (see [code]cursor_state.gd[/code]'s class doc
##   comment for the full argument and the review confirmation).
## - [b]AC-2[/b] (narrowed — "exactly one hover highlight across all mounted
##   surfaces"): no surface is mounted and nothing renders a highlight yet, so
##   the full invariant cannot be exercised. What IS verified here is the
##   structural precondition: [member CursorState._target] is a single scalar
##   [CursorTarget] field, not a collection — a plural container would make
##   "more than one authoritative target" possible by construction, regardless
##   of any rendering code. Full AC-2 verification is Story 007 (real mounted
##   surfaces) / Story 010 (real rendered highlight).
## - [b]AC-15[/b] (narrowed — see class-level scope note above): only the
##   "device authority field is UNINITIALIZED at construction, before any
##   device has produced a [code]ui_*[/code] action" clause is verified. No
##   public getter exists yet ([code]get_device_authority()[/code] is Story
##   007), so this test reads the field directly via [method Object.get] as a
##   documented, temporary stand-in. Deferred: "current target equals the
##   caller-specified initial target" (needs Story 007's write interface) and
##   "the corresponding highlight visual is already displayed" (needs Stories
##   010/011/012's presentation layer).
## - [b]AC-16[/b] (narrowed — heavily): the actual behavior ("the first
##   [code]ui_*[/code] action from any device causes departure from
##   UNINITIALIZED into that device's authority state") requires
##   [code]arbitrate_device_authority()[/code], one of the seven gated public
##   entries that belong entirely to Story 007 (confirmed against that
##   story's own work order). Nothing in this story implements or simulates
##   that entry point, and this test does not fake it. What IS verified, as
##   the narrowest honest fragment: [member CursorState._device_authority] is
##   a plain mutable field capable of holding a value other than
##   UNINITIALIZED — a structural precondition for Story 007's arbitration to
##   be able to do its job at all, not evidence that any arbitration logic
##   exists. This is intentionally close to a tautology; flagged as such in
##   this story's final report rather than presented as full coverage.
##
## All production code under test is either pure [RefCounted]
## ([CursorState]) or a Node whose only behavior is building that RefCounted
## at [method Node._ready] ([CursorStateHost], registered as an Autoload) —
## no random seed, no time-dependent assertion, no external I/O.
extends GdUnitTestSuite


## [code]CursorStateHost[/code] deliberately declares NO [code]class_name[/code]
## (see that file's class doc comment — a `class_name` identical to its own
## Autoload registration name is a parse-time error, verified during this
## story's own test run). This [preload] is the only way to identify "is this
## node running this exact script" without one.
const _CursorStateHostScript: GDScript = preload("res://src/ui/cursor/cursor_state_host.gd")



## The two constructor-injected collaborators AC-1 excludes from its field
## count: the frozen ADR-0005 Key Interfaces contract names both explicitly,
## so neither is undocumented GDD state.
##
## 🔴 [b]This is a script-level constant on purpose.[/b] It is consumed by BOTH
## the AC-1 field-count test (which subtracts it) and the existence test below
## (which asserts every name really is declared on the script). While the list
## was hand-copied into each of those places, adding a name to one copy and not
## the other left both tests green with AC-1's filter quietly widened. Sharing
## one identifier makes "changed one copy only" unrepresentable
## ([code]docs/reviews/story-007-test-evidence-review-2026-09-03.md[/code] §5).
const EXCLUDED_COLLABORATOR_FIELDS: Array[StringName] = [
	&"_registry", &"_mouse_position_provider",
]

## The six 機制十 fields Story 007 added to AC-1's exclusion set — same
## single-source-of-truth reason as [constant EXCLUDED_COLLABORATOR_FIELDS]
## above, and the same two consumers.
##
## 🔴 Story 007 widened this exclusion set, and every name below weakens AC-1's
## guard by exactly one slot — a genuine fourth GDD state field could hide
## behind a plausible-looking mechanism name. So each is justified individually,
## not waved through as a group. The question AC-1 asks is "is there an
## undocumented FOURTH GDD Core Rules #1 state field?", not "does the class
## declare more than three variables" — the same reading already applied to the
## two collaborators above. A field qualifies for exclusion only if it is not
## part of the cursor's observable state: nothing downstream reads it to decide
## what the cursor is pointing at, how valid it is, or which device holds
## authority.
##
## · [code]_mutation_in_progress[/code] — reentrancy latch. [b]Observable BY
##   EFFECT while it is raised[/b]: [signal CursorState.target_changed] is
##   emitted from inside the latched region (in
##   [method CursorState._write_target_internal], before the owning entry drops
##   the latch), which is exactly what the reentrancy tests in
##   [code]tests/unit/cursor/write_read_interface_test.gd[/code] exercise — a
##   handler re-entering from there sees [code]REJECTED_REENTRANT[/code]. It is
##   still control flow rather than cursor state: nothing downstream reads it to
##   decide what the cursor points at, and it is always false between calls.
##   (An earlier version of this note asserted the latch is unobservable to any
##   caller. That was wrong in a load-bearing way — were it true, the whole
##   reentrancy test group could not exist. Corrected per §5 of the review.)
## · [code]_pending_reseed[/code] — "a reseed arrived while the latch was up"
##   note-to-self, always drained before the same entry returns (R6-10). Never
##   outlives one call.
## · [code]_provider_error_reported[/code] — one-shot latch so
##   [method @GlobalScope.push_error] fires once rather than per frame. Log
##   bookkeeping. (It does outlive a call, unlike the two above; AC-1 asks
##   whether there is a fourth GDD state field, not whether there is a fourth
##   surviving variable.)
## · [code]_last_mouse_position[/code] — last coordinate the provider returned
##   (S-1 fallback). It [b]is[/b] declared, written and read by this class
##   ([method CursorState._safe_mouse_position] writes it on success and returns
##   it when the provider has gone invalid), it does outlive a call, and the
##   value read back changes behaviour: it seeds
##   [method MouseReclaimPolicy.reset]. An earlier version of this note said the
##   field belongs to nobody here, which is not true. The real reason it is
##   excluded is narrower: Core Rules #1's third field is the ACCUMULATED
##   displacement, which [code]_reclaim[/code] owns. This is a seed INPUT, not
##   that accumulator.
##   🔴 Revisit if 機制八 ever moves the seed into [CursorState] — it would then
##   shadow the third field.
## · [code]diagnostic_reentrant_rejection_count[/code]
## · [code]diagnostic_invalid_mouse_provider_count[/code] — QA-only counters,
##   explicitly marked "downstream logic must not depend on these" (機制十五
##   convention, as ADR-0002's [code]diagnostic_visited_count[/code]). Monotonic
##   tallies of events, not state anything reads back.
## · [code]_surface_navigation_error_reported[/code] — Story 005 (機制六③,
##   Option E). Same shape and same reason as [code]_provider_error_reported[/code]
##   above: a one-shot latch guarding a single [method @GlobalScope.push_error]
##   call, not a fourth GDD state field.
## · [code]diagnostic_surface_navigation_unsupported_count[/code] — Story 005.
##   Same shape and same reason as [code]diagnostic_invalid_mouse_provider_count[/code]
##   above: a QA-only monotonic counter, explicitly not something downstream
##   gameplay logic may depend on.
const EXCLUDED_MECHANISM_FIELDS: Array[StringName] = [
	&"_mutation_in_progress", &"_pending_reseed", &"_provider_error_reported",
	&"_last_mouse_position", &"diagnostic_reentrant_rejection_count",
	&"diagnostic_invalid_mouse_provider_count",
	&"_surface_navigation_error_reported",
	&"diagnostic_surface_navigation_unsupported_count",
]

## Minimal concrete subclass implementing all four @abstract methods, used as
## a test double so [CursorState] can be constructed directly (matching the
## pattern already established by Story 001's [code]shared_types_test.gd[/code]
## and reused here per this story's own instructions: "AC-2 與 AC-15 在這個
## 階段只能對測試替身斷言").
class _FakeMouseReclaimPolicy extends MouseReclaimPolicy:
	func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
		return false

	func reclaim_progress() -> float:
		return 0.0

	func reset(_seed_position: Vector2, _trigger: CursorTypes.ResetTrigger) -> void:
		pass

	func diagnostic_seed_position() -> Vector2:
		return Vector2.ZERO


## Named-method target for building a [Callable] test double for
## [param mouse_position_provider] — matching this system's own convention of
## a NAMED binding rather than a lambda literal (機制十 專家發現 G / S-1).
func _test_mouse_position() -> Vector2:
	return Vector2.ZERO


func _make_state() -> CursorState:
	return CursorState.new(
		_FakeMouseReclaimPolicy.new(),
		CursorSurfaceRegistry.new(),
		Callable(self, "_test_mouse_position")
	)


# ─── AC-1: exactly 3 top-level state fields, no undocumented 4th ────────────

func test_ac1_cursor_state_declares_exactly_three_top_level_state_fields() -> void:
	# Arrange — script-level reflection (this AC's own prescribed verification
	# method is "code review / static analysis", not runtime black-box
	# behavior). get_script_property_list() returns only fields declared
	# directly on this script, not anything inherited from RefCounted.
	var state: CursorState = _make_state()
	# The exclusion sets and the individual justification for every name in
	# them live on the two script-level constants at the top of this file —
	# deliberately not restated here, so there is exactly one copy to change.
	var state_field_names: Array[StringName] = []

	# Act — get_script_property_list() also returns a synthetic
	# PROPERTY_USAGE_CATEGORY header entry (name = the script's file name,
	# e.g. "cursor_state.gd") used by the editor Inspector as a section
	# label, not an actual declared variable; it must be filtered out or it
	# reads as a false "4th field". Verified directly during this story's
	# own test run (first attempt failed with exactly this extra entry).
	for property: Dictionary in state.get_script().get_script_property_list():
		if property.get("usage", 0) & PROPERTY_USAGE_CATEGORY != 0:
			continue
		var property_name: StringName = property.get("name")
		if property_name in EXCLUDED_COLLABORATOR_FIELDS or property_name in EXCLUDED_MECHANISM_FIELDS:
			continue
		state_field_names.append(property_name)
	state_field_names.sort()

	# Assert — exactly the 3 GDD Core Rules #1 fields, nothing else
	var expected: Array[StringName] = [&"_device_authority", &"_reclaim", &"_target"]
	expected.sort()
	assert_array(state_field_names).is_equal(expected)


func test_ac1_known_collaborator_fields_are_excluded_from_the_state_field_count_by_design() -> void:
	# Arrange / Act — sanity check that the two excluded names above actually
	# exist on the script (i.e. the previous test is narrowing a real set, not
	# vacuously passing because the names never matched anything).
	var state: CursorState = _make_state()
	var all_field_names: Array[StringName] = []
	for property: Dictionary in state.get_script().get_script_property_list():
		all_field_names.append(property.get("name"))

	# Assert
	assert_int(EXCLUDED_COLLABORATOR_FIELDS.size()).append_failure_message(
		"the collaborator exclusion set changed size. Every name in it costs AC-1 "
		+ "one slot of guard, so the count is asserted deliberately: justify the "
		+ "change in the constant's doc comment, then update this number."
	).is_equal(2)
	assert_array(all_field_names).contains(EXCLUDED_COLLABORATOR_FIELDS)


func test_ac1_known_mechanism_fields_are_excluded_from_the_state_field_count_by_design() -> void:
	# Arrange / Act — same discipline as the collaborator-field check above,
	# for the six 機制十 fields Story 007 added to the exclusion list. Without
	# this, a renamed or misspelled entry in that list would widen AC-1's
	# filter SILENTLY: the exclusion would simply match nothing, the field it
	# was meant to cover would reappear, and the AC-1 test would fail for a
	# reason that looks like a real fourth state field. Worse, an entry left
	# behind after a field is deleted would sit there permanently pre-approving
	# a name nobody is watching.
	var state: CursorState = _make_state()
	var all_field_names: Array[StringName] = []
	for property: Dictionary in state.get_script().get_script_property_list():
		all_field_names.append(property.get("name"))

	# Assert
	assert_int(EXCLUDED_MECHANISM_FIELDS.size()).append_failure_message(
		"the mechanism exclusion set changed size. Adding a name here is the "
		+ "dangerous direction: it widens AC-1's filter by one slot and no other "
		+ "assertion in this file can tell whether the new name DESERVES to be "
		+ "excluded. Justify it in the constant's doc comment, then update this "
		+ "number deliberately."
	).is_equal(8)
	assert_array(all_field_names).contains(EXCLUDED_MECHANISM_FIELDS)


# ─── AC-2 (narrowed — see class doc comment): single-target substrate ───────

func test_ac2_partial_target_field_is_a_single_scalar_not_a_collection() -> void:
	# Arrange — the structural precondition for "exactly one hover highlight
	# across all mounted surfaces" (full behavioral verification is Story
	# 007/010, see class doc comment): CursorState must hold ONE CursorTarget,
	# not an Array/Dictionary of concurrently-authoritative targets.
	var state: CursorState = _make_state()
	var target_property: Dictionary = {}

	# Act
	for property: Dictionary in state.get_script().get_script_property_list():
		if property.get("name") == &"_target":
			target_property = property
			break

	# Assert — a single OBJECT-typed field of class CursorTarget, not an array
	assert_dict(target_property).is_not_empty()
	assert_int(target_property.get("type")).is_equal(TYPE_OBJECT)
	assert_str(target_property.get("class_name")).is_equal("CursorTarget")


# ─── AC-15 (narrowed — see class doc comment): uninitialized-state default ──

func test_ac15_partial_device_authority_defaults_to_uninitialized_on_construction() -> void:
	# Arrange / Act — no public getter exists yet (get_device_authority() is
	# Story 007); read the field directly via Object.get() as a documented,
	# temporary stand-in. See class doc comment for the two deferred halves
	# of this AC (initial target value, and the highlight actually displayed).
	var state: CursorState = _make_state()

	# Assert
	assert_int(state.get(&"_device_authority")).is_equal(CursorTypes.Authority.UNINITIALIZED)


func test_ac15_partial_target_starts_invalid_pending_the_callers_write_interface() -> void:
	# Arrange / Act — AC-15 explicitly makes setting the REAL initial target
	# the calling screen's responsibility via the write interface (Story 007)
	# before the screen becomes interactive; this constructor does not accept
	# an initial target parameter (see ADR-0005's frozen _init() signature).
	# What IS verified here: construction does not fabricate a fake "already
	# valid" target — it starts invalid, so a caller that forgets to write a
	# real one cannot be masked by an accidentally-valid default.
	var state: CursorState = _make_state()
	var target: CursorTarget = state.get(&"_target")

	# Assert
	assert_bool(target.is_valid).is_false()


# ─── AC-16 (narrowed heavily — see class doc comment): field mutability only ─

func test_ac16_partial_device_authority_field_is_mutable_away_from_uninitialized() -> void:
	# Arrange — see class doc comment: this is deliberately the narrowest
	# honest fragment. The real AC-16 behavior (first ui_* action from any
	# device causes departure from UNINITIALIZED) needs
	# arbitrate_device_authority(), entirely Story 007's scope. This test does
	# not simulate or fake that entry point; it only proves the field itself
	# is a plain mutable enum var capable of holding a non-UNINITIALIZED
	# value, the structural precondition Story 007's arbitration will need.
	var state: CursorState = _make_state()

	# Act
	state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)

	# Assert
	assert_int(state.get(&"_device_authority")).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)


# ─── Implementation Notes coverage (not AC-numbered, but explicit rules) ────

func test_mouse_position_provider_is_stored_as_a_valid_named_binding_not_a_lambda() -> void:
	# Arrange / Act — Implementation Notes #3: "採具名方法綁定,不用 lambda 字面量".
	var state: CursorState = _make_state()
	var provider: Callable = state.get(&"_mouse_position_provider")

	# Assert
	assert_bool(provider.is_valid()).is_true()
	assert_str(provider.get_method()).is_equal("_test_mouse_position")


func test_construction_does_not_require_a_scene_tree() -> void:
	# Arrange / Act / Assert — ADR-0005 Validation Criteria #2: CursorState
	# must be new()-able with no scene tree. This test itself IS the proof:
	# if construction touched the scene tree, GdUnitTestSuite's own headless
	# unit-test context would fail rather than silently succeed.
	var state: CursorState = _make_state()
	assert_object(state).is_not_null()


# ─── CursorStateHost: Autoload shell + lifecycle ────────────────────────────

func test_host_is_registered_as_an_autoload_and_reachable_at_root() -> void:
	# Arrange / Act
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")

	# Assert — no class_name exists on this script (see preload const's doc
	# comment above), so identity is checked via the attached Script resource.
	assert_object(host).is_not_null()
	assert_object(host.get_script()).is_equal(_CursorStateHostScript)


func test_host_sets_process_priority_to_negative_100() -> void:
	# Arrange / Act
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")

	# Assert — ADR-0005 機制一/機制六: 行為者① is the earliest of the six
	# process-priority actors.
	assert_int(host.process_priority).is_equal(-100)


func test_host_builds_a_single_cursor_state_instance_on_ready() -> void:
	# Arrange / Act
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: Variant = host.get(&"_state")

	# Assert
	assert_object(state).is_not_null()
	assert_bool(state is CursorState).is_true()


func test_host_state_reclaim_forwards_reset_signal_proving_a_live_policy_is_wired() -> void:
	# Arrange — 🔴 UPDATED 2026-09-07 (Story 011 step 1), in the same change
	# that wires a real MouseReclaimPolicy into CursorStateHost, per this
	# test's own prior obligation (see cursor_state_host.gd's class doc
	# comment, "Interim collaborator gap — CLOSED"). This test used to assert
	# _reclaim was null pending Story 014.
	#
	# 🔴 2026-09-07 coordinator correction: the FIRST version of this
	# replacement read `state.get(&"_reclaim") is ThresholdMouseReclaimPolicy`
	# — a direct external read of CursorState's private MouseReclaimPolicy
	# instance, which is EXACTLY the forbidden pattern
	# `external_access_to_cursor_reclaim_instance`
	# (`docs/registry/architecture.yaml`, ADR-0005 R5-3): "Any code outside
	# CursorState holding, reading, or calling the MouseReclaimPolicy instance
	# directly... The only legal channels are CursorState's own forwards:
	# reseed_reclaim_on_focus_regained(), reclaim_progress(), and the
	# forwarded signal reclaim_reset_triggered." The registry names no test
	# exception. Rewritten below to use ONLY those legal forwards.
	#
	# This test proves something STRONGER than a type check would have: not
	# merely "the field holds an object of the right class", but "the
	# forwarding chain is actually connected end-to-end" — calling the public,
	# gated reseed entry really invokes MouseReclaimPolicy.reset() on a LIVE
	# policy, which really emits reset_triggered, which CursorState really
	# forwards verbatim as reclaim_reset_triggered (R5-3). A null _reclaim
	# (the old interim value) makes reseed_reclaim_on_focus_regained() a
	# silent no-op that never touches _reclaim at all (see
	# CursorState.ERR_RECLAIM_POLICY_ABSENT's own doc comment) — so this
	# signal firing (or not) is exactly the legally-observable difference
	# between "null" and "a real, connected policy".
	#
	# 🔴 Observed directly, not assumed (2026-09-07): with
	# cursor_state_host.gd temporarily reverted to `reclaim = null`, this
	# exact test FAILED — `captured` stayed `[]`, `reclaim_reset_triggered`
	# never fired. Restored to the real ThresholdMouseReclaimPolicy wiring,
	# it PASSED. See this story's report for the exact before/after test
	# output.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")

	var captured: Array[CursorTypes.ResetTrigger] = []
	state.reclaim_reset_triggered.connect(
		func(trigger: CursorTypes.ResetTrigger) -> void: captured.append(trigger)
	)

	# Act — the one legal way to make a live policy observably do something:
	# the public, gated reseed entry (機制九's focus-regain path).
	state.reseed_reclaim_on_focus_regained()

	# Assert
	assert_array(captured).append_failure_message(
		"reclaim_reset_triggered did not fire after "
		+ "reseed_reclaim_on_focus_regained() — CursorStateHost is not wired "
		+ "to a live MouseReclaimPolicy (or the forwarding chain is broken)."
	).is_equal([CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED])


func test_host_state_registry_is_a_real_registry_instance() -> void:
	# Arrange / Act — unlike _reclaim, CursorSurfaceRegistry already exists
	# (Story 003), so the host wires in a real instance, not null.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")

	# Assert
	assert_bool(state.get(&"_registry") is CursorSurfaceRegistry).is_true()


func test_host_mouse_position_provider_is_bound_to_the_host_itself() -> void:
	# Arrange / Act — ADR-0005 機制十: get_viewport().get_mouse_position() may
	# only appear at the one call site building this Callable, bound by name.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")
	var provider: Callable = state.get(&"_mouse_position_provider")

	# Assert
	assert_bool(provider.is_valid()).is_true()
	assert_str(provider.get_method()).is_equal("_get_mouse_position")
	assert_object(provider.get_object()).is_equal(host)


# ─── Story 005: frame-buffered arbitration timing (機制五/機制六①③) ────────
#
# 🔴 [b]Scope of this section — read before extending[/b]: every test below
# verifies STRUCTURE and TIMING only — that the six-actor process_priority
# ladder's ①/③ tier split exists and that the buffer is appended in
# [method Node._input], survives ①'s [method Node._process]
# (process_priority -100), and is cleared only by ③'s
# [method CursorStateHost.flush_buffered_navigation] (process_priority -25).
# [b]None of these tests exercise the STORY 005 SEAM[/b] (the "decide what to
# apply from the buffered events" body inside
# [method CursorState.arbitrate_device_authority] /
# [method CursorState.apply_buffered_navigation] — both still empty, per this
# story's phase-1/phase-2 split). The [InputEvent] instances below are
# deliberately NOT bound to any [code]ui_*[/code] action; content-agnostic
# buffering is exactly what 機制五 promises regardless of what the SEAM
# eventually does with the contents.
#
# ⚠️ [b]Shared-Autoload write hazard[/b] (this file's own class doc comment,
# "Story 005/007 一旦出現會改寫全域狀態的測試...需要顯式 setup/teardown 紀律"):
# [code]CursorStateHost[/code] is the ONE Autoload instance shared by every
# test in this suite. [member CursorStateHost._frame_events] is mutated
# in-place ([Array] is a reference type) by every test below — each one
# clears it in [b]both[/b] Arrange (defensive, in case a prior test left
# residue) [b]and[/b] a final cleanup step, so no test's leftover buffer
# state can leak into another test in this file OR into a future story's
# tests reusing the same Autoload.


## Returns the [b]live reference[/b] to [member CursorStateHost._frame_events],
## not a copy — [code]host.get()[/code] on a typed [Array] field hands back
## the same underlying array, so [code].clear()[/code]/[code].append()[/code]
## on the returned value mutates the host's real buffer. Used by every test
## in this section for both the defensive pre-clear and the assertions
## themselves.
func _host_frame_events(host: Node) -> Array:
	return host.get(&"_frame_events")


func test_cursor_navigation_applier_exists_as_a_child_of_the_host() -> void:
	# Arrange / Act — R4-1: 機制六③ cannot live on the same node as ① (this
	# host, process_priority -100), so it must exist as a distinct child.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var applier: Node = host.get_node_or_null("CursorNavigationApplier")

	# Assert — [CursorNavigationApplier] DOES declare class_name (unlike
	# CursorStateHost, which cannot — see that file's own class doc comment),
	# so identity is checked the same way [CursorSurfaceRegistry] etc. are
	# checked elsewhere in this project: a plain `is` check.
	assert_object(applier).append_failure_message(
		"CursorStateHost has no child named \"CursorNavigationApplier\" — "
		+ "Story 005's 機制六③ node was never added in _ready()."
	).is_not_null()
	assert_bool(applier is CursorNavigationApplier).append_failure_message(
		"a node named \"CursorNavigationApplier\" exists but does not run "
		+ "the CursorNavigationApplier script."
	).is_true()


func test_cursor_navigation_applier_sets_process_priority_to_negative_25() -> void:
	# Arrange / Act — ADR-0005 機制六③'s architecture-mandated value, strictly
	# between the caller's own 機制六② interval ceiling (-25, exclusive) and
	# 機制六①'s -100 (this host).
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var applier: Node = host.get_node_or_null("CursorNavigationApplier")

	# Assert
	assert_object(applier).append_failure_message(
		"PRECONDITION: CursorNavigationApplier does not exist — see the "
		+ "existence test above."
	).is_not_null()
	assert_int(applier.process_priority).is_equal(-25)


func test_input_appends_events_to_the_frame_buffer() -> void:
	# Arrange
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	_host_frame_events(host).clear()
	var event := InputEventKey.new()

	# Act — calling the override directly, same convention this project
	# already uses for _process() in native_pointer_visibility_arbiter_test.gd
	# / self_drawn_reclaim_cursor_test.gd: headless test runs receive no real
	# InputEvent dispatch (coding-standards.md), so the override is invoked
	# directly rather than relying on the engine to deliver one.
	host._input(event)

	# Assert
	var buffered: Array = _host_frame_events(host)
	assert_int(buffered.size()).append_failure_message(
		"_input() did not append the event to _frame_events."
	).is_equal(1)
	assert_object(buffered[0]).is_same(event)

	# Cleanup — shared-Autoload write hazard, see section header comment.
	_host_frame_events(host).clear()


func test_process_at_priority_negative_100_does_not_clear_the_frame_buffer() -> void:
	# Arrange — this is 機制五 R4-1's own stated contract: the buffer's clear
	# point moved to -25 specifically so ①'s _process() (this host, -100)
	# must NOT be the one to clear it, because ③ still needs to read it.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	_host_frame_events(host).clear()
	host._input(InputEventKey.new())
	var count_before: int = _host_frame_events(host).size()

	# Act
	host._process(0.0)

	# Assert
	assert_int(count_before).append_failure_message(
		"PRECONDITION: the buffer was empty before calling _process() — the "
		+ "test proves nothing."
	).is_equal(1)
	assert_int(_host_frame_events(host).size()).append_failure_message(
		"CursorStateHost._process() (機制六①, priority -100) cleared "
		+ "_frame_events — R4-1 requires the LAST consumer (機制六③, "
		+ "flush_buffered_navigation()) to do this, not the arbitration step."
	).is_equal(1)

	# Cleanup — shared-Autoload write hazard, see section header comment.
	_host_frame_events(host).clear()


func test_flush_buffered_navigation_clears_the_frame_buffer() -> void:
	# Arrange — 機制五 R4-1: the buffer's LAST consumer for the frame is
	# flush_buffered_navigation() (機制六③, called by CursorNavigationApplier
	# at process_priority -25), not the host's own -100 _process().
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	_host_frame_events(host).clear()
	host._input(InputEventKey.new())

	# Act
	host.flush_buffered_navigation()

	# Assert
	assert_int(_host_frame_events(host).size()).append_failure_message(
		"flush_buffered_navigation() did not clear _frame_events after "
		+ "consuming it — the next frame would start with stale events from "
		+ "this frame still buffered."
	).is_equal(0)


func test_process_and_flush_are_both_no_ops_on_an_empty_buffer() -> void:
	# Arrange — the empty-buffer early-return guard on both entry points
	# (mirrors the ADR pseudocode's `_frame_events.is_empty(): return`).
	# Calling into CursorState.arbitrate_device_authority() /
	# apply_buffered_navigation() with an empty array is exercised by this
	# test only insofar as "does it throw" — the SEAM itself is still empty,
	# so there is nothing further to assert about their effects yet.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	_host_frame_events(host).clear()

	# Act / Assert — must not raise a script error either way.
	host._process(0.0)
	host.flush_buffered_navigation()
	assert_int(_host_frame_events(host).size()).is_equal(0)


# ─── Story U-013: thin forwarding read/write/registration entries ──────────
#
# 🔴 Same shared-Autoload write hazard as the 機制五/機制六 section above:
# CursorStateHost is the ONE Autoload instance shared by every test in this
# suite, and _state/_registry are built once in _ready() and never
# reassigned. Every test below that mutates _state's _target /
# _device_authority fields, or _registry's surface table, restores a neutral
# baseline in a final cleanup step so no test's leftover state can leak into
# another test in this file or a future story's tests reusing the same
# Autoload.

## Surface tag these tests register/target. Sharing [CursorTypes.SurfaceType]
## with production code is fine here — these tests always unregister
## whatever they register within the same test, so no residue survives past
## it (unlike a real production surface, which stays registered for the
## screen's lifetime).
const _U013_SURFACE: CursorTypes.SurfaceType = CursorTypes.SurfaceType.BOARD_TILE


## Restores [param state]'s two mutable top-level fields to a neutral
## baseline (invalid target on [constant _U013_SURFACE], id 0;
## UNINITIALIZED authority) — the same shape [method CursorState._init] leaves
## a fresh instance in, so a later test in this file finds the shared
## Autoload's [CursorState] exactly as prior sections already expect it.
func _reset_state_target_and_authority(state: CursorState) -> void:
	state.set(&"_target", CursorTarget.invalidated(CursorTarget.make(_U013_SURFACE, 0)))
	state.set(&"_device_authority", CursorTypes.Authority.UNINITIALIZED)


func test_get_current_target_forwards_to_state_and_still_returns_a_copy() -> void:
	# Arrange
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")
	var seeded: CursorTarget = CursorTarget.make(_U013_SURFACE, 42)
	state.set(&"_target", seeded)

	# Act
	var forwarded: CursorTarget = host.get_current_target()

	# Assert — the forward really reached the live _state (values match)...
	assert_int(forwarded.surface).is_equal(_U013_SURFACE)
	assert_int(forwarded.id).is_equal(42)
	assert_bool(forwarded.is_valid).is_true()
	# ...and the copy discipline CursorState.get_current_target() already
	# guarantees survives being forwarded through the Host: this must NOT be
	# the same instance CursorState holds internally.
	assert_object(forwarded).append_failure_message(
		"host.get_current_target() returned the SAME instance CursorState "
		+ "holds internally — the forward must not leak the internal "
		+ "reference (forbidden pattern returning_internal_container_references, "
		+ "ADR-0001)."
	).is_not_same(seeded)

	# Cleanup
	_reset_state_target_and_authority(state)


func test_get_device_authority_forwards_to_state() -> void:
	# Arrange
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")
	state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)

	# Act / Assert
	assert_int(host.get_device_authority()).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)

	# Cleanup
	_reset_state_target_and_authority(state)


func test_is_current_target_valid_forwards_to_state() -> void:
	# Arrange
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")
	state.set(&"_target", CursorTarget.invalidated(CursorTarget.make(_U013_SURFACE, 1)))

	# Act / Assert
	assert_bool(host.is_current_target_valid()).append_failure_message(
		"host.is_current_target_valid() did not forward to the live _state's "
		+ "own is_current_target_valid()."
	).is_false()

	# Cleanup
	_reset_state_target_and_authority(state)


func test_register_surface_and_unregister_surface_forward_to_registry() -> void:
	# Arrange
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var node: Node = auto_free(Node.new())

	# Act / Assert — first registration succeeds
	assert_int(host.register_surface(_U013_SURFACE, node)).append_failure_message(
		"host.register_surface() did not forward to _registry.register()."
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)

	# Act / Assert — a second registration under the SAME tag is rejected,
	# not silently overwritten (TR-cursor-003, single-tag single-instance).
	assert_int(host.register_surface(_U013_SURFACE, auto_free(Node.new()))).is_equal(
		CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED
	)

	# Act / Assert — unregister forwards too
	assert_int(host.unregister_surface(_U013_SURFACE)).append_failure_message(
		"host.unregister_surface() did not forward to _registry.unregister()."
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)

	# Act / Assert — a second unregister of the same, now-empty tag reports
	# NOT_FOUND rather than a silent no-op (matches CursorSurfaceRegistry's
	# own contract).
	assert_int(host.unregister_surface(_U013_SURFACE)).is_equal(
		CursorSurfaceRegistry.RegisterResult.UNREGISTERED_NOT_FOUND
	)


func test_set_target_forwards_to_state_and_applies_against_a_registered_surface() -> void:
	# Arrange
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")
	var node: Node = auto_free(Node.new())
	host.register_surface(_U013_SURFACE, node)

	# Act
	var result: CursorState.SetTargetResult = host.set_target(CursorTarget.make(_U013_SURFACE, 7))

	# Assert — the write really landed on the shared _state, not a local no-op
	assert_int(result).append_failure_message(
		"host.set_target() did not forward to _state.set_target() — expected "
		+ "APPLIED against a registered surface."
	).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(host.get_current_target().id).is_equal(7)

	# Cleanup
	_reset_state_target_and_authority(state)
	host.unregister_surface(_U013_SURFACE)


# ─── Story U-013: sensitivity proof for the six forwarding methods ─────────
#
# 🔴 Per `.claude/rules/test-standards.md`'s 2026-09-16 ruling, manual
# break/run/revert injection is deprecated for this project (it leaves no
# trace in the repo — a claim of "I injected a fault and it went red" cannot
# be checked by a second reader). The sanctioned, persistent form is a spy
# subclass + a `test_sensitivity_proof_*` test asserting the spy was actually
# reached. This proves the six methods above really DELEGATE through
# whatever object [member CursorStateHost._state] / [CursorStateHost._registry]
# currently holds, rather than e.g. a hardcoded return value that happens to
# equal what the earlier, non-spy tests in this section expect.

## Spy [CursorState] subclass — overrides exactly the four methods
## [method is_current_target_valid] / [method get_device_authority] /
## [method get_current_target] / [method set_target] forward to. Each
## override returns a sentinel value production logic could not plausibly
## produce by coincidence (an out-of-range-looking id, [constant
## CursorTypes.Authority.UNINITIALIZED] where the real state would never be
## uninitialized once seeded, [constant SetTargetResult.REJECTED_REENTRANT]
## on a call this spy never actually gates), and counts how many times it was
## called.
class _SpyCursorState extends CursorState:
	var current_target_call_count: int = 0
	var device_authority_call_count: int = 0
	var target_valid_call_count: int = 0
	var set_target_call_count: int = 0
	var last_set_target_arg: CursorTarget = null

	func get_current_target() -> CursorTarget:
		current_target_call_count += 1
		return CursorTarget.make(CursorTypes.SurfaceType.DIALOGUE_CHOICE, 918273)

	func get_device_authority() -> CursorTypes.Authority:
		device_authority_call_count += 1
		return CursorTypes.Authority.UNINITIALIZED

	func is_current_target_valid() -> bool:
		target_valid_call_count += 1
		return true

	func set_target(target: CursorTarget) -> SetTargetResult:
		set_target_call_count += 1
		last_set_target_arg = target
		return SetTargetResult.REJECTED_REENTRANT


## Spy [CursorSurfaceRegistry] subclass — overrides [method register] /
## [method unregister], each returning a sentinel result code and counting
## calls, same reasoning as [_SpyCursorState] above.
class _SpyCursorSurfaceRegistry extends CursorSurfaceRegistry:
	var register_call_count: int = 0
	var unregister_call_count: int = 0
	var last_register_node: Node = null

	func register(surface: CursorTypes.SurfaceType, node: Node) -> RegisterResult:
		register_call_count += 1
		last_register_node = node
		return RegisterResult.INVALID_NODE

	func unregister(surface: CursorTypes.SurfaceType) -> RegisterResult:
		unregister_call_count += 1
		return RegisterResult.UNREGISTERED_NOT_FOUND


func _make_spy_state() -> _SpyCursorState:
	return _SpyCursorState.new(
		_FakeMouseReclaimPolicy.new(),
		CursorSurfaceRegistry.new(),
		Callable(self, "_test_mouse_position")
	)


func test_sensitivity_proof_all_six_u013_forwards_delegate_through_live_state_and_registry() -> void:
	# Arrange — swap the shared Autoload's two collaborator fields for spies.
	# Both originals are captured first so they can be restored unconditionally
	# below regardless of what happens in between: GdUnit4 assertions record
	# a failure and CONTINUE rather than throwing, so the restoration lines at
	# the bottom still run even if an assertion above them fails — the shared
	# Autoload cannot leak spy state into any later test in this suite.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var original_state: CursorState = host.get(&"_state")
	var original_registry: CursorSurfaceRegistry = host.get(&"_registry")
	var spy_state: _SpyCursorState = _make_spy_state()
	var spy_registry: _SpyCursorSurfaceRegistry = _SpyCursorSurfaceRegistry.new()
	host.set(&"_state", spy_state)
	host.set(&"_registry", spy_registry)

	# Act / Assert — is_current_target_valid()
	assert_bool(host.is_current_target_valid()).append_failure_message(
		"host.is_current_target_valid() did not surface the SPY's sentinel "
		+ "return value — it is not delegating through the live _state field."
	).is_true()
	assert_int(spy_state.target_valid_call_count).is_equal(1)

	# Act / Assert — get_device_authority()
	assert_int(host.get_device_authority()).append_failure_message(
		"host.get_device_authority() did not surface the SPY's sentinel "
		+ "return value."
	).is_equal(CursorTypes.Authority.UNINITIALIZED)
	assert_int(spy_state.device_authority_call_count).is_equal(1)

	# Act / Assert — get_current_target()
	var forwarded_target: CursorTarget = host.get_current_target()
	assert_int(forwarded_target.id).append_failure_message(
		"host.get_current_target() did not surface the SPY's sentinel target "
		+ "— it is not delegating through the live _state field."
	).is_equal(918273)
	assert_int(spy_state.current_target_call_count).is_equal(1)

	# Act / Assert — set_target()
	var probe_target: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.CARD_SLOT, 55)
	assert_int(host.set_target(probe_target)).append_failure_message(
		"host.set_target() did not surface the SPY's sentinel return value."
	).is_equal(CursorState.SetTargetResult.REJECTED_REENTRANT)
	assert_int(spy_state.set_target_call_count).is_equal(1)
	assert_object(spy_state.last_set_target_arg).append_failure_message(
		"host.set_target() did not pass its argument through to the live "
		+ "_state's set_target() unchanged."
	).is_same(probe_target)

	# Act / Assert — register_surface()
	var probe_node: Node = auto_free(Node.new())
	assert_int(host.register_surface(_U013_SURFACE, probe_node)).append_failure_message(
		"host.register_surface() did not surface the SPY registry's sentinel "
		+ "return value — it is not delegating through the live _registry field."
	).is_equal(CursorSurfaceRegistry.RegisterResult.INVALID_NODE)
	assert_int(spy_registry.register_call_count).is_equal(1)
	assert_object(spy_registry.last_register_node).is_same(probe_node)

	# Act / Assert — unregister_surface()
	assert_int(host.unregister_surface(_U013_SURFACE)).append_failure_message(
		"host.unregister_surface() did not surface the SPY registry's "
		+ "sentinel return value."
	).is_equal(CursorSurfaceRegistry.RegisterResult.UNREGISTERED_NOT_FOUND)
	assert_int(spy_registry.unregister_call_count).is_equal(1)

	# Cleanup — restore the REAL collaborators regardless of which assertions
	# above passed or failed.
	host.set(&"_state", original_state)
	host.set(&"_registry", original_registry)
