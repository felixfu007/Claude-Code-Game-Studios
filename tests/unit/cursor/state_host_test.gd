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
	var known_collaborator_fields: Array[StringName] = [&"_registry", &"_mouse_position_provider"]
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
		if property_name in known_collaborator_fields:
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
	assert_array(all_field_names).contains([&"_registry", &"_mouse_position_provider"])


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


func test_host_state_reclaim_is_null_pending_story_014() -> void:
	# Arrange / Act — documented interim decision (see cursor_state_host.gd's
	# class doc comment): MouseReclaimPolicy's only concrete subclass is
	# Story 014's, which depends on this story and therefore cannot exist
	# before it. Nothing built so far calls a method on _reclaim, so this is
	# safe for THIS story only.
	# 🔴 This test MUST be updated in the same change that gives
	# CursorStateHost a real concrete MouseReclaimPolicy (Story 014) — it is
	# a regression guard for the interim value, not an assertion that null is
	# permanently correct.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	var state: CursorState = host.get(&"_state")

	# Assert
	assert_object(state.get(&"_reclaim")).is_null()


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
