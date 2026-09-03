## Unit tests for Story 007 — the seven gated public write entries and the
## four read queries on [code]src/ui/cursor/cursor_state.gd[/code]
## (ADR-0005 機制十 + 機制十一's 甲/乙 branches).
##
## Covers AC-3 / AC-24 / AC-25 / AC-29 / AC-32 / AC-33 / AC-37 / AC-39 /
## AC-50 / AC-54 from
## [code]production/epics/cursor-highlight-state/story-007-write-read-interface.md[/code].
## [b]Not every one of those ten is fully verifiable at this layer[/b] — the
## per-test doc comments below state exactly which half each one exercises,
## following the same honesty convention Stories 001–004 established. Two of
## them (AC-3, AC-54) name a verification method that is explicitly NOT an
## automated test; see their tests' comments and this story's final report.
##
## [b]Determinism[/b]: [CursorState] is a pure [RefCounted] dependency-injection
## core. Every collaborator here is a hand-built test double — a recording
## [MouseReclaimPolicy] subclass, a real [CursorSurfaceRegistry] with
## explicitly registered nodes, and a named-method [Callable] returning a
## constant coordinate. No random seed, no timer, no [code]await[/code], no
## file or network I/O, and nothing reads real [Input] state.
##
## [b]Isolation[/b]: [method before_test] rebuilds every fixture from scratch,
## so no test depends on execution order. The one shared piece of global state
## in this project (the [code]CursorStateHost[/code] Autoload) is deliberately
## NOT touched by any test in this file — every test builds its own
## [CursorState].
extends GdUnitTestSuite


## Constant coordinate the injected [param mouse_position_provider] returns.
## Deliberately not [constant Vector2.ZERO]: the production
## [method CursorState._safe_mouse_position] fallback value IS
## [constant Vector2.ZERO], so a zero probe value could not tell a real
## provider call apart from the fallback path.
const _MOUSE_POSITION: Vector2 = Vector2(123.0, 456.0)

## Surface tag registered by [method before_test]. Targets built on this tag
## are expected to pass [method CursorState._validate_target_writable].
const _REGISTERED_SURFACE: CursorTypes.SurfaceType = CursorTypes.SurfaceType.BOARD_TILE

## Surface tag deliberately left UNregistered by [method before_test], so
## tests can exercise the [constant CursorState.SetTargetResult.SURFACE_NOT_REGISTERED]
## rejection without hand-faking a registry.
const _UNREGISTERED_SURFACE: CursorTypes.SurfaceType = CursorTypes.SurfaceType.RELATION_MINIMAP_NODE


## Recording [MouseReclaimPolicy] test double. [CursorState] holds
## [member CursorState._reclaim] completely privately (no getter), so the only
## way to observe the reset calls 機制十/機制十一 mandate is to record them
## from the policy side.
##
## [b]All four [code]@abstract[/code] methods are implemented[/b] — a bare
## signature would be a compile-time error here (forbidden pattern
## [code]abstract_func_with_body[/code] is about the ABSTRACT declaration; a
## concrete override must have a body).
class _RecordingReclaimPolicy extends MouseReclaimPolicy:
	## One entry per [method reset] call, in call order:
	## [code]{"position": Vector2, "trigger": CursorTypes.ResetTrigger}[/code].
	var reset_calls: Array[Dictionary] = []
	## Value [method reclaim_progress] returns; tests set it to prove
	## [method CursorState.reclaim_progress] is a pure forward and not a
	## hardcoded literal.
	var progress: float = 0.0
	var _seed: Vector2 = Vector2.ZERO

	func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
		return false

	func reclaim_progress() -> float:
		return progress

	func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void:
		_seed = seed_position
		reset_calls.append({"position": seed_position, "trigger": trigger})
		# Emit so the CursorState._init() forwarding wiring (R5-3) is
		# exercised too, exactly as the real Story 014 policy will.
		reset_triggered.emit(trigger)

	func diagnostic_seed_position() -> Vector2:
		return _seed

	## Returns the recorded triggers only, so tests can assert on an
	## [code]Array[/code] of enum values rather than picking through
	## dictionaries.
	func triggers() -> Array[CursorTypes.ResetTrigger]:
		var out: Array[CursorTypes.ResetTrigger] = []
		for call_record: Dictionary in reset_calls:
			out.append(call_record["trigger"])
		return out


## Subscriber that calls a public write entry back from inside
## [signal CursorState.target_changed]'s handler — ADR-0005 機制十's own
## description of the real reentrancy risk (a downstream handler re-entering
## the write interface synchronously, because signals are emitted while
## [code]_mutation_in_progress[/code] is still raised).
##
## [b]This is the only honest way to produce a real reentrant call[/b]:
## setting [code]_mutation_in_progress[/code] by reflection would test the
## latch's [code]if[/code] statement, not the property that matters (that
## signals really are emitted inside the latched region).
class _ReentrantWriter extends RefCounted:
	enum Entry {
		SET_TARGET,
		MARK_PENDING_RERESOLVE,
		HANDOFF_BEFORE_UNLOAD,
		HANDOFF_AFTER_MOUNT,
		ARBITRATE_DEVICE_AUTHORITY,
		APPLY_BUFFERED_NAVIGATION,
		RESEED_RECLAIM,
	}

	var state: CursorState
	var entry: Entry = Entry.SET_TARGET
	## Target handed to the re-entering call, for the entries that take one.
	var payload: CursorTarget
	## How many times the handler ran. Guards against unbounded recursion if
	## a future implementation ever emits from inside the rejected path.
	var invocations: int = 0
	## Result the re-entering call returned, as [int] (both result enums are
	## [int]-backed). [code]-1[/code] means "the handler never ran".
	var result: int = -1
	## [member CursorState.diagnostic_reentrant_rejection_count] read
	## immediately AFTER the re-entering call — the only observable the three
	## [code]void[/code] entries have.
	var rejection_count_after: int = -1
	var _no_events: Array[InputEvent] = []

	func on_target_changed() -> void:
		invocations += 1
		if invocations > 1:
			return
		match entry:
			Entry.SET_TARGET:
				result = state.set_target(payload, false)
			Entry.MARK_PENDING_RERESOLVE:
				result = state.mark_pending_reresolve(payload)
			Entry.HANDOFF_BEFORE_UNLOAD:
				result = state.handoff_before_unload()
			Entry.HANDOFF_AFTER_MOUNT:
				result = state.handoff_after_mount(payload)
			Entry.ARBITRATE_DEVICE_AUTHORITY:
				state.arbitrate_device_authority(_no_events)
			Entry.APPLY_BUFFERED_NAVIGATION:
				state.apply_buffered_navigation(_no_events)
			Entry.RESEED_RECLAIM:
				state.reseed_reclaim_on_focus_regained()
		rejection_count_after = state.diagnostic_reentrant_rejection_count

	## Breaks the [CursorState] -> signal connection -> this object -> [CursorState]
	## reference cycle so neither side leaks after the test.
	func release() -> void:
		state = null
		payload = null


var _registry: CursorSurfaceRegistry
var _reclaim: _RecordingReclaimPolicy
var _state: CursorState
var _target_changed_count: int = 0
var _authority_changed_count: int = 0
var _forwarded_reset_triggers: Array[CursorTypes.ResetTrigger] = []


func before_test() -> void:
	_registry = CursorSurfaceRegistry.new()
	_registry.register(_REGISTERED_SURFACE, auto_free(Node.new()))
	_reclaim = _RecordingReclaimPolicy.new()
	_state = CursorState.new(
		_reclaim,
		_registry,
		Callable(self, "_test_mouse_position")
	)
	_target_changed_count = 0
	_authority_changed_count = 0
	_forwarded_reset_triggers = []
	_state.target_changed.connect(_on_target_changed)
	_state.device_authority_changed.connect(_on_device_authority_changed)
	_state.reclaim_reset_triggered.connect(_on_reclaim_reset_triggered)


## Named-method [Callable] target, matching this system's own convention of a
## named binding rather than a lambda literal (機制十 專家發現 G / S-1).
func _test_mouse_position() -> Vector2:
	return _MOUSE_POSITION


func _on_target_changed() -> void:
	_target_changed_count += 1


## Second independent subscriber, used only by the AC-29 test. Two subscribers
## are required there: with one, "notified every subscriber exactly once" and
## "emitted exactly once in total" are indistinguishable.
var _secondary_target_changed_count: int = 0


func _on_target_changed_secondary() -> void:
	_secondary_target_changed_count += 1


func _on_device_authority_changed() -> void:
	_authority_changed_count += 1


func _on_reclaim_reset_triggered(trigger: CursorTypes.ResetTrigger) -> void:
	_forwarded_reset_triggers.append(trigger)


## A target on the surface [method before_test] registered — expected to pass
## validation.
func _registered_target(id: int) -> CursorTarget:
	return CursorTarget.make(_REGISTERED_SURFACE, id)


## A target on a surface nobody registered — expected to be rejected.
func _unregistered_target(id: int) -> CursorTarget:
	return CursorTarget.make(_UNREGISTERED_SURFACE, id)


## Writes a valid current target through the real public entry and asserts the
## write took, so a downstream assertion failure is not silently caused by an
## unmet precondition. Resets the observation counters afterwards, so each
## test's assertions only see what the test itself provoked.
func _seed_valid_target(id: int) -> CursorTarget:
	var target: CursorTarget = _registered_target(id)
	var result: int = _state.set_target(target, false)
	assert_int(result).append_failure_message(
		"PRECONDITION: set_target() must apply a freshly registered target before "
		+ "this test's real assertions can mean anything. Got result %d." % result
	).is_equal(CursorState.SetTargetResult.APPLIED)
	_target_changed_count = 0
	_authority_changed_count = 0
	_forwarded_reset_triggers = []
	_reclaim.reset_calls = []
	return target


## Empty, correctly typed argument for the two [code]Array[InputEvent][/code]
## entries. Their bodies are Story 005's; this story only owns their gate.
func _no_events() -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	return events


# ─── Read interface (TR-cursor-014) ─────────────────────────────────────────

## get_current_target() must hand out a freshly allocated copy, never the
## internal instance (forbidden pattern returning_internal_container_references).
func test_read_get_current_target_returns_a_freshly_allocated_copy() -> void:
	# Arrange
	var written: CursorTarget = _seed_valid_target(7)

	# Act — two reads of the same unchanged state
	var first: CursorTarget = _state.get_current_target()
	var second: CursorTarget = _state.get_current_target()

	# Assert — equal by VALUE...
	assert_object(first).append_failure_message(
		"get_current_target() returned null on a state holding a valid target."
	).is_not_null()
	assert_object(second).is_not_null()
	assert_bool(first.equals(second)).append_failure_message(
		"two consecutive reads of unchanged state disagreed on surface/id"
	).is_true()
	assert_bool(first.is_valid).is_true()

	# ...but three DISTINCT instances. Identity, not value, is the point here:
	# a caller must never receive an object this system mutates underneath it.
	assert_object(first).append_failure_message(
		"two calls handed out the SAME instance — that is the internal field, "
		+ "not a copy (forbidden pattern returning_internal_container_references)."
	).is_not_same(second)
	assert_object(first).append_failure_message(
		"the object returned is the very instance the caller passed to "
		+ "set_target(); the write path stored it by reference and the read path "
		+ "handed it straight back."
	).is_not_same(written)


## 重點 2: proves the copy is a real defence, not just value equality — mutating
## what the caller received must not reach the internal field.
func test_read_mutating_the_returned_copy_leaves_internal_state_untouched() -> void:
	# Arrange
	var written: CursorTarget = _seed_valid_target(11)
	var copy: CursorTarget = _state.get_current_target()
	assert_bool(copy.equals(written)).append_failure_message(
		"PRECONDITION: the read query did not return the value just written."
	).is_true()

	# Act — a caller doing exactly what the copy exists to make harmless.
	# CursorTarget is "designed immutable", but immutability by discipline is
	# what the copy turns into a structural guarantee — so this test attacks it.
	copy.id = 999
	copy.surface = _UNREGISTERED_SURFACE
	copy.is_valid = false

	# Assert — internal state is completely unaffected
	var after: CursorTarget = _state.get_current_target()
	assert_int(after.id).append_failure_message(
		"mutating the returned object changed the internal target id — the read "
		+ "query handed out the internal instance, not a copy."
	).is_equal(11)
	assert_int(after.surface).is_equal(_REGISTERED_SURFACE)
	assert_bool(after.is_valid).is_true()
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"mutating the returned copy flipped the system's own validity flag."
	).is_true()


## reclaim_progress() is a pure forward to the injected policy (R5-3), not a
## hardcoded literal.
##
## 🔴 [b]This test depends on [method before_test] injecting a NON-NULL
## [MouseReclaimPolicy] double[/b], and that is not incidental. The production
## class treats an absent policy as "return [code]0.0[/code]", so run against a
## [code]null[/code] policy this test would still see [code]0.0[/code] and read
## as passing — while verifying the fallback branch instead of the forward.
## [b]The two are indistinguishable from the return value alone[/b], which is
## why the assertions below use non-zero values the fallback cannot produce.
## The fallback itself has its own test, immediately below.
func test_read_reclaim_progress_is_a_pure_forward_to_the_injected_policy() -> void:
	# Arrange / Act / Assert — TWO NON-ZERO values, because a single value
	# cannot distinguish "forwards the policy" from "returns a constant that
	# happens to match", and 0.0 specifically cannot distinguish a forward from
	# the absent-policy fallback (see this test's doc comment).
	_reclaim.progress = 0.42
	assert_float(_state.reclaim_progress()).append_failure_message(
		"reclaim_progress() is not a pure forward — the policy reports 0.42."
	).is_equal_approx(0.42, 0.0001)

	_reclaim.progress = 1.0
	assert_float(_state.reclaim_progress()).is_equal_approx(1.0, 0.0001)


## The counterpart to the test above, and the reason that one insists on
## non-zero values: the production class tolerates an ABSENT
## [MouseReclaimPolicy] (the Autoload still injects [code]null[/code] until
## Story 014 lands) by returning [code]0.0[/code] rather than aborting.
##
## 🔴 [b]Two tests in this file construct [CursorState] with a [code]null[/code]
## policy — this one and the seven-entry degradation test below[/b], both
## deliberately. Every other test injects a real [_RecordingReclaimPolicy]
## double: without one, every [code]_reclaim.reset()[/code] call site is skipped
## by a [code]null[/code] guard and the reset assertions elsewhere would pass
## while observing an empty code path.
func test_read_reclaim_progress_returns_zero_without_aborting_when_no_policy_is_injected() -> void:
	# Arrange — the interim wiring CursorStateHost still uses today.
	var stateless: CursorState = CursorState.new(
		null,
		CursorSurfaceRegistry.new(),
		Callable(self, "_test_mouse_position")
	)

	# Act
	var progress: float = stateless.reclaim_progress()

	# Assert — 0.0, and control returned at all (a method call on a null
	# collaborator would abort this function before the assert ran).
	assert_float(progress).append_failure_message(
		"absent-policy fallback should be 0.0. NOTE: this 0.0 is the FALLBACK, "
		+ "not a forward — see this test's doc comment for why the forwarding "
		+ "test above must never assert on 0.0."
	).is_equal_approx(0.0, 0.0001)


# ─── Absent MouseReclaimPolicy — the configuration the shipped build runs ───

## 🔴 [b]This is the wiring [code]CursorStateHost[/code] actually constructs
## today[/b] ([code]reclaim = null[/code]; Story 014 is unbuilt, and the
## Autoload is registered in [code].claude/docs/technical-preferences.md[/code]).
## Every other test in this file injects a recording double, so without this one
## the only configuration that SHIPS would be the only configuration never
## exercised through the write interface.
##
## [b]What it proves[/b]: all seven gated public write entries survive an absent
## policy, and — the part that matters — the reentrancy latch is still clear
## afterwards. [code]cursor_state.gd[/code]'s class doc comment spells out the
## failure being guarded against: a method call on a [code]null[/code]
## collaborator ABORTS the enclosing function, and those call sites sit inside
## an already-raised latch, so the abort would skip the line that lowers it and
## every later public call would return
## [constant CursorState.SetTargetResult.REJECTED_REENTRANT] forever — "a loud
## one-off error followed by a permanently and silently dead system".
##
## 🔴 The final [method CursorState.set_target] below is therefore the assertion
## that carries the test. "Nothing crashed" is not the claim; "the gate still
## opens afterwards" is. Without that last step this test would still pass
## against a permanently wedged instance.
func test_absent_policy_all_seven_write_entries_degrade_without_wedging_the_gate() -> void:
	# Arrange — same registered surface before_test() uses, so every validation
	# outcome below is about the absent policy and nothing else.
	var registry: CursorSurfaceRegistry = CursorSurfaceRegistry.new()
	registry.register(_REGISTERED_SURFACE, auto_free(Node.new()))
	var stateless: CursorState = CursorState.new(
		null, registry, Callable(self, "_test_mouse_position")
	)

	# Act — all seven entries, ordered so each one has REAL work to do. An entry
	# that returns early (nothing to mark, nothing to write) would never reach
	# its _reclaim call site, and this test would then prove nothing about it.
	var set_result: int = stateless.set_target(_registered_target(41), false)
	var mark_result: int = stateless.mark_pending_reresolve(_registered_target(41))
	var mount_result: int = stateless.handoff_after_mount(_registered_target(42))
	var unload_result: int = stateless.handoff_before_unload()
	stateless.arbitrate_device_authority(_no_events())
	stateless.apply_buffered_navigation(_no_events())
	stateless.reseed_reclaim_on_focus_regained()

	# Assert (a) — every value-returning entry did its job. Asserting the exact
	# code rather than merely "not REJECTED_REENTRANT" also rules out an entry
	# that silently degraded into a no-op when the policy went missing.
	assert_int(set_result).append_failure_message(
		"set_target() did not apply with an absent MouseReclaimPolicy"
	).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(mark_result).append_failure_message(
		"mark_pending_reresolve() did not apply with an absent policy"
	).is_equal(CursorState.MarkResult.APPLIED)
	assert_int(mount_result).append_failure_message(
		"handoff_after_mount() (乙) did not apply with an absent policy"
	).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(unload_result).append_failure_message(
		"handoff_before_unload() (甲) did not apply with an absent policy"
	).is_equal(CursorState.MarkResult.APPLIED)

	# Assert (b) — 🔴 THE POINT. If any of the seven aborted mid-body, the latch
	# it raised was never lowered and this call comes back REJECTED_REENTRANT.
	var after_all_seven: int = stateless.set_target(_registered_target(43), false)
	assert_int(after_all_seven).append_failure_message(
		"the write interface is WEDGED after walking all seven entries with an "
		+ "absent MouseReclaimPolicy: a call on a null collaborator aborted its "
		+ "function before lowering _mutation_in_progress, so every public call "
		+ "from now on is rejected as reentrant. This is the configuration the "
		+ "shipped build runs today — check the `if _reclaim != null` guards in "
		+ "cursor_state.gd, one of them is missing or was moved."
	).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(stateless.diagnostic_reentrant_rejection_count).append_failure_message(
		"a reentrancy rejection was counted although no test double ever "
		+ "re-entered — the latch is being left raised by one of the seven"
	).is_equal(0)

	# ...and the state that last write produced is really readable back, so
	# "APPLIED" above cannot be a return code with no write behind it.
	assert_int(stateless.get_current_target().id).is_equal(43)
	assert_bool(stateless.is_current_target_valid()).is_true()
	assert_float(stateless.reclaim_progress()).append_failure_message(
		"absent-policy reclaim_progress() fallback stopped returning 0.0 after "
		+ "the seven entries ran"
	).is_equal_approx(0.0, 0.0001)


# ─── AC-25 (partial): the caller-delegated resolution path really works ────
# ─── query-interface half only; the rendering half is Stories 010/011 ──────

## AC-25 — [b]VERIFIED HERE: the query interface only.[/b]
##
## ✅ What this test does verify: after the owning system calls
## [method CursorState.set_target] on an invalidated target, the coordinates
## equal the new value and the validity flag flips back to true.
##
## ❌ What it CANNOT verify: AC-25's THEN clause also requires
## 「…或任一掛載的 UI 表面渲染,皆讀取到此新值與有效旗標」
## ([code]story-007-write-read-interface.md[/code] line 66). Nothing renders
## yet — that is Stories 010/011, and no test here fakes a surface to pretend
## otherwise. [b]Same boundary and same wording as AC-29 below[/b]: unlike
## AC-33 and AC-50, AC-25 carries no clause delegating the rendering half to
## the downstream system's own acceptance, so that half stays open here.
## (An earlier draft recorded AC-25 as fully covered while marking the
## structurally identical AC-29 partial — two standards for one shape.
## Corrected per
## [code]docs/reviews/story-007-test-evidence-review-2026-09-03.md[/code] §4.3.)
func test_ac25_partial_set_target_writes_the_new_coordinates_and_flips_validity_back_to_true() -> void:
	# Arrange — AC-24's situation: a target the owning system has declared
	# pending re-resolve.
	var original: CursorTarget = _seed_valid_target(5)
	assert_int(_state.mark_pending_reresolve(original)).append_failure_message(
		"PRECONDITION: could not put the state into the pending-re-resolve "
		+ "situation AC-25 starts from."
	).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(_state.is_current_target_valid()).is_false()

	# Act — the caller system (e.g. tactical move/engage) takes the delegated
	# resolution path AC-25 exists to prove actually works.
	var replacement: CursorTarget = _registered_target(9)
	var result: int = _state.set_target(replacement, false)

	# Assert — coordinates equal the caller's value, flag immediately back to
	# valid, with no intermediate state a reader could observe.
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"validity flag did not flip back to true — a target built by "
		+ "CursorTarget.make() is valid by construction, so writing it whole "
		+ "must restore validity implicitly."
	).is_true()
	var current: CursorTarget = _state.get_current_target()
	assert_int(current.id).is_equal(9)
	assert_int(current.surface).is_equal(_REGISTERED_SURFACE)
	assert_bool(current.is_valid).is_true()


## AC-25 (second half) — [b]VERIFIED HERE: the query interface only.[/b]
##
## ✅ What this test does verify: no stale coordinate and no stale invalid flag
## survives into any later query.
##
## ❌ What it CANNOT verify: the 「或任一掛載的 UI 表面渲染」 half of the same
## THEN clause — see the boundary note on the AC-25 test above. Stories 010/011.
func test_ac25_partial_no_stale_coordinate_or_invalid_flag_survives_a_later_query() -> void:
	# Arrange — invalidate, then resolve via the caller-delegated path
	var original: CursorTarget = _seed_valid_target(3)
	assert_int(_state.mark_pending_reresolve(original)).is_equal(CursorState.MarkResult.APPLIED)
	assert_int(_state.set_target(_registered_target(21), false)).is_equal(
		CursorState.SetTargetResult.APPLIED
	)

	# Act — "此後任何時間點查詢" — repeated reads, plus one read after an
	# unrelated REJECTED write, which must not resurrect the old value either.
	# Observations are collected in the loop and asserted OUTSIDE it, so an
	# empty loop cannot produce a zero-assertion pass.
	var observed_ids: Array[int] = []
	var observed_validity: Array[bool] = []
	for _i in range(3):
		var seen: CursorTarget = _state.get_current_target()
		observed_ids.append(seen.id)
		observed_validity.append(_state.is_current_target_valid())
	var rejected: int = _state.set_target(_unregistered_target(3), false)
	var after_rejection: CursorTarget = _state.get_current_target()
	observed_ids.append(after_rejection.id)
	observed_validity.append(_state.is_current_target_valid())

	# Assert — exact membership, not merely "not empty": both a drifting value
	# and a loop that silently ran zero times must fail this.
	var expected_ids: Array[int] = [21, 21, 21, 21]
	var expected_validity: Array[bool] = [true, true, true, true]
	assert_array(observed_ids).append_failure_message(
		"a stale coordinate resurfaced on a later query (4 reads, the last one "
		+ "taken after a rejected write)"
	).contains_exactly(expected_ids)
	assert_array(observed_validity).append_failure_message(
		"a stale invalid flag resurfaced on a later query"
	).contains_exactly(expected_validity)
	assert_int(rejected).append_failure_message(
		"the unregistered-surface write was expected to be rejected; if it was "
		+ "applied, the last observation above proves nothing."
	).is_not_equal(CursorState.SetTargetResult.APPLIED)


# ─── AC-24: this system never auto-clears or auto-re-resolves ──────────────

## AC-24: a target that failed in the GAME WORLD is invisible to this system —
## with nobody calling mark/set, every query keeps returning the original values.
func test_ac24_a_target_that_failed_in_the_game_world_is_never_auto_cleared_by_this_system() -> void:
	# Arrange — a valid current target. AC-24's GIVEN ("the target itself
	# became invalid") is a GAME-WORLD fact: the unit died, the tile was
	# destroyed. This system has no channel through which to observe that, and
	# must not pretend to — which is exactly what the AC asks it to prove.
	var target: CursorTarget = _seed_valid_target(4)

	# Act — reads happen; nobody calls mark_pending_reresolve() or set_target().
	# Observations are collected here and asserted OUTSIDE the loop, so a loop
	# that ran zero times cannot produce a zero-assertion pass.
	var observed_ids: Array[int] = []
	var observed_validity: Array[bool] = []
	for _i in range(4):
		observed_ids.append(_state.get_current_target().id)
		observed_validity.append(_state.is_current_target_valid())

	# Assert — exact membership, four reads, original values throughout
	var expected_ids: Array[int] = [4, 4, 4, 4]
	var expected_validity: Array[bool] = [true, true, true, true]
	assert_array(observed_ids).append_failure_message(
		"the coordinate drifted across repeated reads with no write in between"
	).contains_exactly(expected_ids)
	assert_array(observed_validity).append_failure_message(
		"the validity flag changed with no write in between — this system "
		+ "auto-detected something it has no channel to detect."
	).contains_exactly(expected_validity)
	assert_bool(_state.get_current_target().equals(target)).append_failure_message(
		"the target was silently re-resolved to some other target"
	).is_true()
	assert_int(_target_changed_count).append_failure_message(
		"no write entry was called, so target_changed must not fire at all"
	).is_equal(0)
	assert_array(_reclaim.reset_calls).append_failure_message(
		"merely reading state reset the reclaim accumulator"
	).is_empty()


## AC-24: once marked pending-re-resolve, the coordinates are preserved (only
## the flag flipped) and stay stable across repeated queries.
func test_ac24_a_marked_target_keeps_its_original_coordinates_and_flag_across_repeated_queries() -> void:
	# Arrange — the same AC-24 invariant on the OTHER side of the flip: once
	# marked pending re-resolve, the system must keep the coordinates (only the
	# flag moved) rather than clearing to some placeholder.
	var target: CursorTarget = _seed_valid_target(8)
	assert_int(_state.mark_pending_reresolve(target)).append_failure_message(
		"PRECONDITION: could not mark the current target pending re-resolve"
	).is_equal(CursorState.MarkResult.APPLIED)
	_target_changed_count = 0
	_reclaim.reset_calls = []

	# Act — nobody calls set_target(); the target simply stays pending.
	var observed_ids: Array[int] = []
	var observed_surfaces: Array[int] = []
	var observed_validity: Array[bool] = []
	for _i in range(3):
		var seen: CursorTarget = _state.get_current_target()
		observed_ids.append(seen.id)
		observed_surfaces.append(seen.surface)
		observed_validity.append(_state.is_current_target_valid())

	# Assert — coordinates preserved, flag stably false, nothing self-healing
	var expected_ids: Array[int] = [8, 8, 8]
	var expected_surfaces: Array[int] = [
		_REGISTERED_SURFACE, _REGISTERED_SURFACE, _REGISTERED_SURFACE
	]
	var expected_validity: Array[bool] = [false, false, false]
	assert_array(observed_ids).append_failure_message(
		"the id was cleared or drifted after being marked pending re-resolve"
	).contains_exactly(expected_ids)
	assert_array(observed_surfaces).append_failure_message(
		"the surface tag was cleared after being marked pending re-resolve"
	).contains_exactly(expected_surfaces)
	assert_array(observed_validity).append_failure_message(
		"the flag flipped back on its own — no caller asked for a re-resolve"
	).contains_exactly(expected_validity)
	assert_int(_target_changed_count).append_failure_message(
		"reading a pending target must not emit anything"
	).is_equal(0)


# ─── AC-37 / TR-cursor-013: the staleness race guard ────────────────────────

## AC-37 first half: a stale `expected` returns STALE_NOT_APPLIED and changes
## NOTHING — coordinates, validity flag, authority and signals all untouched.
func test_ac37_stale_expected_returns_stale_not_applied_and_changes_nothing() -> void:
	# Arrange — the exact race AC-37 describes: the caller detected a failure
	# while the cursor was on target 2, but the PLAYER navigated to target 30
	# before the caller got round to making the call.
	var stale_belief: CursorTarget = _seed_valid_target(2)
	assert_int(_state.set_target(_registered_target(30), false)).append_failure_message(
		"PRECONDITION: the player's navigation away from the stale target failed"
	).is_equal(CursorState.SetTargetResult.APPLIED)
	var before: CursorTarget = _state.get_current_target()
	var authority_before: int = _state.get_device_authority()
	_target_changed_count = 0
	_authority_changed_count = 0
	_forwarded_reset_triggers = []
	_reclaim.reset_calls = []

	# Act — the late call arrives, carrying the caller's now-stale belief
	var result: int = _state.mark_pending_reresolve(stale_belief)

	# Assert — an explicit structured result, NOT a silent no-return...
	assert_int(result).append_failure_message(
		"a stale expected target must return STALE_NOT_APPLIED so the caller "
		+ "can tell 'not applied' from 'applied' programmatically (AC-37's "
		+ "2026-08-06 amendment)."
	).is_equal(CursorState.MarkResult.STALE_NOT_APPLIED)
	assert_int(result).append_failure_message(
		"the two outcomes must be programmatically distinguishable"
	).is_not_equal(CursorState.MarkResult.APPLIED)

	# ...and the player's legitimate current target is completely untouched
	var after: CursorTarget = _state.get_current_target()
	assert_int(after.id).append_failure_message(
		"a stale mark call damaged the target the player currently holds"
	).is_equal(before.id)
	assert_int(after.surface).is_equal(before.surface)
	assert_bool(after.is_valid).append_failure_message(
		"the validity flag was flipped by a call that reported it had not been"
	).is_true()
	assert_bool(_state.is_current_target_valid()).is_true()
	assert_int(_state.get_device_authority()).append_failure_message(
		"AC-39: a rejected mark must not move device authority either"
	).is_equal(authority_before)
	assert_int(_target_changed_count).append_failure_message(
		"nothing changed, so no subscriber may be told anything did"
	).is_equal(0)
	assert_int(_authority_changed_count).is_equal(0)
	assert_array(_reclaim.reset_calls).append_failure_message(
		"a rejected mark reset the reclaim accumulator"
	).is_empty()


## AC-37 second half: a matching `expected` returns APPLIED and flips validity.
func test_ac37_matching_expected_returns_applied_and_flips_the_validity_flag() -> void:
	# Arrange
	var current: CursorTarget = _seed_valid_target(6)
	assert_bool(_state.is_current_target_valid()).is_true()

	# Act — the caller passes a RECONSTRUCTED, equal-valued target rather than
	# the same instance. That is deliberate: the race check must use
	# CursorTarget.equals() value semantics (機制三), so an identity comparison
	# in the production code would reject every legitimate call and this test
	# is what catches that.
	var expected: CursorTarget = _registered_target(6)
	assert_object(expected).append_failure_message(
		"test setup error: expected and current must be different instances "
		+ "for this test to prove value semantics"
	).is_not_same(current)
	var result: int = _state.mark_pending_reresolve(expected)

	# Assert
	assert_int(result).append_failure_message(
		"a matching expected target must return APPLIED"
	).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"the validity flag did not flip to false"
	).is_false()

	# Same surface and id — this is a validity flip, not a re-target
	var after: CursorTarget = _state.get_current_target()
	assert_int(after.id).is_equal(6)
	assert_int(after.surface).is_equal(_REGISTERED_SURFACE)
	assert_bool(after.is_valid).is_false()
	assert_int(_target_changed_count).append_failure_message(
		"a validity flip with identical coordinates must still notify "
		+ "subscribers — equals() ignores is_valid, so only "
		+ "_target_changed_from()'s SECOND condition can catch this (R6-7)."
	).is_equal(1)
	assert_array(_reclaim.reset_calls).append_failure_message(
		"marking goes through CursorTarget.invalidated(), NOT "
		+ "_write_target_internal(), so it must not fire a reclaim reset at all "
		+ "— a TARGET_CHANGED here would lie to the presentation layer."
	).is_empty()


## 🔴 [b]ADR-0005 DOES NOT DEFINE THIS BOUNDARY — this test pins the current
## implementation's chosen reading, NOT a contract.[/b] The ADR names
## [constant CursorState.MarkResult.NO_CURRENT_TARGET] in the enum and never
## states when it is returned. [member CursorState._target] is never
## [code]null[/code] after [method CursorState._init], so the implementation
## reads the member as "there is no CURRENT (valid) target to invalidate"
## (its own doc comment on
## [code]_mark_pending_reresolve_internal()[/code] records the reasoning and
## the alternative it rejected).
##
## If the architecture owner rules differently, [b]change this test rather
## than treating it as a regression[/b]. It is here so the chosen reading is
## at least visible and executable instead of buried in a comment — flagged
## as an open boundary in this story's final report.
func test_ac37_mark_pending_reresolve_with_no_valid_current_target_returns_no_current_target() -> void:
	# Arrange — a freshly constructed CursorState. _init() leaves _target as a
	# default CursorTarget with is_valid == false and no caller has written a
	# real one yet (GDD AC-15 makes that the calling screen's job).
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"PRECONDITION: a fresh CursorState must start with no valid target"
	).is_false()

	# Act
	var result: int = _state.mark_pending_reresolve(_registered_target(1))

	# Assert — see this test's doc comment: undefined boundary, current reading
	assert_int(result).append_failure_message(
		"IMPLEMENTATION-DEFINED, NOT CONTRACT: expected NO_CURRENT_TARGET for "
		+ "'nothing valid to invalidate'. ADR-0005 does not specify when this "
		+ "member is returned; if the reading changed, update this test."
	).is_equal(CursorState.MarkResult.NO_CURRENT_TARGET)
	assert_int(_target_changed_count).append_failure_message(
		"a rejected mark must not notify anyone"
	).is_equal(0)


# ─── AC-39: target and device authority are orthogonal fields ──────────────

## AC-39: set_target(..., from_ui_action = false) must not touch authority.
func test_ac39_set_target_not_from_ui_action_leaves_device_authority_unchanged() -> void:
	# Arrange — authority must hold a NON-default value first, or "unchanged"
	# would be indistinguishable from "was never set". No public setter exists
	# (authority arbitration is 機制六 / Story 005), so this seeds the field
	# directly — the same documented stand-in state_host_test.gd already uses.
	_state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)
	var _ignored: CursorTarget = _seed_valid_target(1)
	_authority_changed_count = 0

	# Act — a system-initiated re-target (all three handoff branches and every
	# caller-driven re-target pass false here).
	# 🔴 Only the from_ui_action == false half is exercised. The true half is
	# device-authority arbitration (機制六 / Story 005) and AC-39's own text
	# covers only the false case — this test does not fake the other one.
	var result: int = _state.set_target(_registered_target(42), false)

	# Assert — the write landed...
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(_state.get_current_target().id).is_equal(42)
	# ...and authority is bit-for-bit what it was
	assert_int(_state.get_device_authority()).append_failure_message(
		"writing a target moved device authority — the two are orthogonal "
		+ "fields (GDD Core Rules #4) and writing one must never imply the other."
	).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
	assert_int(_authority_changed_count).append_failure_message(
		"device_authority_changed fired for a write that did not touch authority"
	).is_equal(0)


## AC-39: mark_pending_reresolve() must not touch authority either.
func test_ac39_mark_pending_reresolve_leaves_device_authority_unchanged() -> void:
	# Arrange — same non-default authority seeding as the set_target() case
	_state.set(&"_device_authority", CursorTypes.Authority.MOUSE)
	var target: CursorTarget = _seed_valid_target(3)
	_authority_changed_count = 0

	# Act — marking is also a system-initiated write, never a ui_* action
	var result: int = _state.mark_pending_reresolve(target)

	# Assert — the mark landed...
	assert_int(result).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(_state.is_current_target_valid()).is_false()
	# ...and authority is untouched. This matters concretely: if marking a
	# target pending re-resolve dropped mouse authority, the player's next
	# click would be refused for the WRONG reason and the feedback AC-54
	# requires would point at the wrong recovery action.
	assert_int(_state.get_device_authority()).append_failure_message(
		"marking a target pending re-resolve moved device authority"
	).is_equal(CursorTypes.Authority.MOUSE)
	assert_int(_authority_changed_count).is_equal(0)


# ─── 重點 5: _target_changed_from()'s OR condition (R6-7) ───────────────────

## equals() ignores is_valid (機制三), so a validity flip with IDENTICAL
## coordinates must still emit target_changed — caught only by the 2nd condition.
func test_target_changed_fires_on_a_validity_flip_to_false_with_identical_coordinates() -> void:
	# Arrange
	var target: CursorTarget = _seed_valid_target(12)
	var before: CursorTarget = _state.get_current_target()

	# Act — a validity flip on the SAME surface and id
	assert_int(_state.mark_pending_reresolve(target)).is_equal(CursorState.MarkResult.APPLIED)
	var after: CursorTarget = _state.get_current_target()

	# Assert — first, prove the premise this test rests on: equals() genuinely
	# CANNOT see this change. Without this pair of assertions the emission
	# assertion below would not prove the OR's second condition is present.
	assert_bool(before.equals(after)).append_failure_message(
		"premise broken: equals() must ignore is_valid (機制三). If it started "
		+ "comparing is_valid, mark_pending_reresolve()'s race check would "
		+ "return STALE_NOT_APPLIED for every legitimate call."
	).is_true()
	assert_bool(before.is_valid).is_true()
	assert_bool(after.is_valid).is_false()

	# ...and the signal fired anyway, which only the second OR condition
	# (old.is_valid != new.is_valid) can achieve.
	assert_int(_target_changed_count).append_failure_message(
		"no target_changed for a validity flip with identical coordinates — "
		+ "subscribe-only downstreams would never learn the target became "
		+ "pending re-resolve (R6-7)."
	).is_equal(1)


## The save-reload case R6-7 was written for: is_valid false -> true on the same
## surface and id must emit, or subscribe-only downstreams stay stuck forever.
func test_target_changed_fires_on_a_validity_flip_back_to_true_with_identical_coordinates() -> void:
	# Arrange — the concrete scenario R6-7 was written for: loading a save back
	# onto the SAME board. Surface and id are identical; only is_valid moves
	# false -> true.
	var target: CursorTarget = _seed_valid_target(19)
	assert_int(_state.mark_pending_reresolve(target)).is_equal(CursorState.MarkResult.APPLIED)
	var before: CursorTarget = _state.get_current_target()
	_target_changed_count = 0
	_reclaim.reset_calls = []

	# Act — the owning system re-resolves to the very same surface and id
	var result: int = _state.set_target(_registered_target(19), false)
	var after: CursorTarget = _state.get_current_target()

	# Assert — same premise check as the false-direction test
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_bool(before.equals(after)).append_failure_message(
		"premise broken: the two targets must be equal by value for this test "
		+ "to exercise the validity-flip branch at all"
	).is_true()
	assert_bool(before.is_valid).is_false()
	assert_bool(after.is_valid).is_true()

	assert_int(_target_changed_count).append_failure_message(
		"no target_changed on a false->true validity flip. This is the exact "
		+ "regression R6-7 fixed: every subscribe-only downstream stays stuck "
		+ "on the pending-re-resolve visual forever, and polling downstreams "
		+ "never see the bug."
	).is_equal(1)


## Counterpart proving the condition is not "always emit": rewriting an
## identical, already-valid target emits nothing.
func test_target_changed_does_not_fire_when_an_identical_valid_target_is_rewritten() -> void:
	# Arrange — a valid target, then the SAME value written again
	var _ignored: CursorTarget = _seed_valid_target(77)

	# Act
	var result: int = _state.set_target(_registered_target(77), false)

	# Assert — the write is accepted, but nothing actually changed, so nothing
	# is announced. This is the counterpart that stops the two tests above from
	# passing against a trivially wrong "always emit" implementation.
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(_target_changed_count).append_failure_message(
		"target_changed fired for a rewrite that changed neither the "
		+ "coordinates nor the validity flag"
	).is_equal(0)
	assert_array(_reclaim.reset_calls).append_failure_message(
		"CONDITIONAL_ON_CHANGE fired a TARGET_CHANGED reset for an unchanged "
		+ "target — that is the conditional path behaving unconditionally."
	).is_empty()


# ─── Shared pre-write validation (專家發現 2b) ──────────────────────────────

## set_target() rejects a target whose surface was never registered.
func test_set_target_rejects_an_unregistered_surface_with_surface_not_registered() -> void:
	# Arrange — before_test() registers BOARD_TILE only, so
	# _UNREGISTERED_SURFACE (RELATION_MINIMAP_NODE) has no mounted surface.
	var _ignored: CursorTarget = _seed_valid_target(1)
	var before: CursorTarget = _state.get_current_target()

	# Act
	var result: int = _state.set_target(_unregistered_target(5), false)

	# Assert — a specific rejection code, never a silent no-op
	assert_int(result).append_failure_message(
		"writing a target on a surface nobody registered must be rejected with "
		+ "SURFACE_NOT_REGISTERED"
	).is_equal(CursorState.SetTargetResult.SURFACE_NOT_REGISTERED)

	# ...and nothing was written on the way to that rejection
	var after: CursorTarget = _state.get_current_target()
	assert_bool(after.equals(before)).append_failure_message(
		"the rejected target was written anyway"
	).is_true()
	assert_bool(after.is_valid).is_true()
	assert_int(_target_changed_count).is_equal(0)
	assert_array(_reclaim.reset_calls).is_empty()


## 乙 runs the SAME validation as set_target() via the shared private path —
## same input, same result code, and nothing written.
func test_handoff_after_mount_rejects_an_unregistered_surface_with_the_same_result_as_set_target() -> void:
	# Arrange — the same offending target put through both entries
	var _ignored: CursorTarget = _seed_valid_target(1)
	var offending: CursorTarget = _unregistered_target(5)

	# Act
	var via_set_target: int = _state.set_target(offending, false)
	var via_handoff: int = _state.handoff_after_mount(offending)

	# Assert — 乙 must run the SAME validation, through the shared ungated
	# private path (專家發現 2b). A divergence here means it either borrowed
	# the public set_target() (and hit its own latch) or skipped validation and
	# let an unregistered surface in under the SURFACE_HANDOFF trust assumption
	# nobody checks — the ADR names that as the most likely next defect.
	assert_int(via_handoff).is_equal(CursorState.SetTargetResult.SURFACE_NOT_REGISTERED)
	assert_int(via_handoff).append_failure_message(
		"handoff_after_mount() and set_target() disagreed on the same input; "
		+ "they are required to share one validation path."
	).is_equal(via_set_target)

	# 🔴 Depends on before_test() injecting a NON-NULL MouseReclaimPolicy
	# double: with a null policy every reset() call site is skipped by a null
	# guard and this assertion would pass while observing nothing.
	assert_array(_reclaim.reset_calls).append_failure_message(
		"乙 fired its UNCONDITIONAL SURFACE_HANDOFF reset for a target it "
		+ "rejected — validation must gate the write, not follow it."
	).is_empty()
	assert_int(_target_changed_count).is_equal(0)
	assert_bool(_state.get_current_target().equals(_registered_target(1))).is_true()


# ─── 機制十一 甲 branch: handoff_before_unload() ────────────────────────────

## 重點 6: proves 甲 really took effect. If it (wrongly) called the PUBLIC
## mark_pending_reresolve(), its own latch would reject that call and the mark
## would never happen — this test goes red in exactly that case.
func test_handoff_before_unload_marks_the_current_target_without_being_blocked_by_its_own_gate() -> void:
	# Arrange
	var target: CursorTarget = _seed_valid_target(14)
	assert_bool(_state.is_current_target_valid()).is_true()

	# Act — 甲: a load flow begins, before the old surface is torn down
	var result: int = _state.handoff_before_unload()

	# Assert — 🔴 this is the test that catches ADR-0005's named near-deadlock.
	# 機制十一's prose says 甲 must "call mark_pending_reresolve()", but BOTH
	# are gated public entries: doing that literally has 甲 rejected by the
	# latch it raised itself, and the marking never happens. The correct shape
	# routes through the ungated _mark_pending_reresolve_internal(). Both
	# assertions below go red in exactly that misrouted case — the first names
	# the cause, the second proves the effect.
	assert_int(result).append_failure_message(
		"handoff_before_unload() returned REJECTED_REENTRANT: it called the "
		+ "PUBLIC mark_pending_reresolve() and was rejected by its own gate "
		+ "(ADR-0005 R5-1, the same shape as R4-4)."
	).is_not_equal(CursorState.MarkResult.REJECTED_REENTRANT)
	assert_int(result).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"甲 reported a result but the target is still valid — the marking did "
		+ "not actually take effect."
	).is_false()

	# It is a validity flip on the same surface/id, not a re-target
	var after: CursorTarget = _state.get_current_target()
	assert_int(after.id).is_equal(14)
	assert_int(after.surface).is_equal(_REGISTERED_SURFACE)
	assert_bool(after.equals(target)).is_true()
	assert_int(_target_changed_count).append_failure_message(
		"subscribers were not told the target became pending re-resolve"
	).is_equal(1)


## 甲 also reseeds the reclaim accumulator unconditionally with SURFACE_HANDOFF
## at the current mouse position (GDD Core Rules #7 F2-2).
func test_handoff_before_unload_reseeds_the_reclaim_accumulator_with_surface_handoff() -> void:
	# 🔴 Depends on before_test() injecting a NON-NULL MouseReclaimPolicy
	# double. The production code guards every reset() call site with
	# `if _reclaim != null` (the Autoload still injects null until Story 014),
	# so run against a null policy this test would pass while observing an
	# entirely empty code path — the exact "assertions present, nothing
	# exercised" failure this project has already been caught by once.
	# Arrange
	var _ignored: CursorTarget = _seed_valid_target(15)

	# Act
	assert_int(_state.handoff_before_unload()).is_equal(CursorState.MarkResult.APPLIED)

	# Assert — exactly one reset, carrying SURFACE_HANDOFF. Pinned by exact
	# membership rather than "contains", so a second stray reset also fails.
	var expected_triggers: Array[CursorTypes.ResetTrigger] = [
		CursorTypes.ResetTrigger.SURFACE_HANDOFF
	]
	assert_array(_reclaim.triggers()).append_failure_message(
		"甲 must reseed the reclaim accumulator exactly once with "
		+ "SURFACE_HANDOFF (GDD Core Rules #7 F2-2). TARGET_CHANGED here would "
		+ "lie to the presentation layer: 甲 does not change the target."
	).contains_exactly(expected_triggers)

	# Seeded at the coordinate obtained through the injected provider, NOT the
	# Vector2.ZERO fallback — which is why _MOUSE_POSITION is deliberately
	# non-zero (see its doc comment).
	assert_vector(_reclaim.reset_calls[0]["position"]).append_failure_message(
		"the accumulator was seeded with the _safe_mouse_position() fallback "
		+ "instead of a live provider read"
	).is_equal(_MOUSE_POSITION)

	# The forward to the presentation layer (R5-3) carried the same trigger
	assert_array(_forwarded_reset_triggers).append_failure_message(
		"CursorState.reclaim_reset_triggered did not forward the policy's reset"
	).contains_exactly(expected_triggers)


## 甲 with [b]nothing to mark[/b] — the case the two 甲 tests above both miss,
## because both seed a valid target first.
##
## GDD Core Rules #7 F2-2 requires the accumulated displacement to zero
## "regardless of whether there was anything to mark", which is why
## [code]cursor_state.gd[/code] puts 甲's reset OUTSIDE the result check.
## 🔴 Moving those two lines inside [code]if result == MarkResult.APPLIED:[/code]
## leaves every other test in this file green (measured during the 2026-09-03
## test-evidence review, §8 G-2) while the mandated zeroing silently stops
## happening in exactly the situation it exists for: the old surface is being
## torn down and there is no valid target to mark.
##
## 🔴 Depends on [method before_test] injecting a NON-NULL policy double, like
## the two 甲 tests above — with the interim null policy the reset call site is
## skipped and this test would pass while observing nothing. (The absent-policy
## configuration has its own test near the top of this file.)
func test_handoff_before_unload_reseeds_unconditionally_even_with_nothing_to_mark() -> void:
	# Arrange — a state deliberately NOT seeded: before_test() builds it with
	# the construction-time placeholder target, which is not valid, so 甲 has
	# nothing to mark. Asserted rather than assumed, because if a future
	# before_test() ever seeded a target this test would quietly become a
	# duplicate of the one above instead of failing.
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"PRECONDITION: this test needs a state with NO valid current target; "
		+ "something seeded one before the act."
	).is_false()
	assert_array(_reclaim.reset_calls).append_failure_message(
		"PRECONDITION: construction must not have reset the policy, or the "
		+ "assertion below could not tell 甲's reset apart from that one."
	).is_empty()

	# Act
	var result: int = _state.handoff_before_unload()

	# Assert — there really was nothing to mark...
	assert_int(result).append_failure_message(
		"expected NO_CURRENT_TARGET: without it this test is no longer "
		+ "exercising the 'nothing to mark' path it exists for."
	).is_equal(CursorState.MarkResult.NO_CURRENT_TARGET)

	# ...and the reseed happened ANYWAY, exactly once, carrying 甲's trigger.
	var expected_triggers: Array[CursorTypes.ResetTrigger] = [
		CursorTypes.ResetTrigger.SURFACE_HANDOFF
	]
	assert_array(_reclaim.triggers()).append_failure_message(
		"甲 skipped the reseed because there was nothing to mark. GDD Core "
		+ "Rules #7 F2-2 requires the zeroing REGARDLESS — the old seed and the "
		+ "surface it was anchored to stop meaning anything either way. Check "
		+ "that handoff_before_unload()'s reset is still OUTSIDE the "
		+ "`result == APPLIED` check."
	).contains_exactly(expected_triggers)
	assert_vector(_reclaim.reset_calls[0]["position"]).append_failure_message(
		"the accumulator was seeded with the _safe_mouse_position() fallback "
		+ "instead of a live provider read"
	).is_equal(_MOUSE_POSITION)
	assert_array(_forwarded_reset_triggers).append_failure_message(
		"CursorState.reclaim_reset_triggered did not forward the policy's reset"
	).contains_exactly(expected_triggers)

	# Nothing was announced as changed: 甲 marked nothing and wrote nothing.
	assert_int(_target_changed_count).append_failure_message(
		"target_changed was emitted although 甲 had no target to invalidate"
	).is_equal(0)
	assert_bool(_state.is_current_target_valid()).is_false()


# ─── 機制十一 乙 branch: handoff_after_mount() ──────────────────────────────

## 重點 7: UNCONDITIONAL means the reset happens even when the newly computed
## target happens to equal the current one — the case a conditional reset would
## silently skip.
func test_handoff_after_mount_resets_unconditionally_even_when_the_target_did_not_change() -> void:
	# 🔴 Depends on before_test() injecting a NON-NULL MouseReclaimPolicy
	# double — with the interim null policy every reset() call site is skipped
	# and this test would pass while observing nothing.
	# Arrange
	var target: CursorTarget = _seed_valid_target(23)

	# Act — 乙 where the newly computed target happens to EQUAL the current
	# one. This is precisely the case a conditional reset silently skips, while
	# GDD Core Rules #7 F2-2 mandates the zeroing regardless.
	var result: int = _state.handoff_after_mount(_registered_target(23))

	# Assert
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	var expected_triggers: Array[CursorTypes.ResetTrigger] = [
		CursorTypes.ResetTrigger.SURFACE_HANDOFF
	]
	assert_array(_reclaim.triggers()).append_failure_message(
		"乙's reset is UNCONDITIONAL. An empty list here means the conditional "
		+ "path ran instead and the mandated zeroing silently did not happen — "
		+ "the fourth problem R5-1 was written to close."
	).contains_exactly(expected_triggers)
	assert_vector(_reclaim.reset_calls[0]["position"]).is_equal(_MOUSE_POSITION)

	# The signal condition stays orthogonal to reset_policy (機制十): the target
	# did not change, so nothing is announced even though a reset did fire.
	assert_int(_target_changed_count).append_failure_message(
		"target_changed must depend only on whether the target changed, never "
		+ "on which reset path ran."
	).is_equal(0)
	assert_bool(_state.get_current_target().equals(target)).is_true()
	assert_bool(_state.is_current_target_valid()).is_true()


## 專家發現 A / forbidden pattern independent_ifs_for_cursor_target_reset_policy:
## 乙's NORMAL case (unconditional AND genuinely changed) must fire reset ONCE,
## with SURFACE_HANDOFF only — two independent ifs would fire twice.
func test_handoff_after_mount_fires_exactly_one_reset_when_the_target_really_changed() -> void:
	# 🔴 Same non-null MouseReclaimPolicy dependency as the test above.
	# Arrange
	var _ignored: CursorTarget = _seed_valid_target(23)

	# Act — 乙's NORMAL case: unconditional AND a genuinely different target
	var result: int = _state.handoff_after_mount(_registered_target(31))

	# Assert — 🔴 exactly ONE reset. Written as two independent `if`s instead
	# of `if`/`elif`, this case fires reset() twice in a single write and puts
	# two DIFFERENT triggers on reclaim_reset_triggered, at which point
	# Validation Criteria #15 passes or fails depending on implementation
	# detail (專家發現 A, forbidden pattern
	# independent_ifs_for_cursor_target_reset_policy).
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(_reclaim.reset_calls.size()).append_failure_message(
		"expected exactly 1 reset call; 2 means the two reset paths were "
		+ "written as independent ifs rather than if/elif."
	).is_equal(1)
	var expected_triggers: Array[CursorTypes.ResetTrigger] = [
		CursorTypes.ResetTrigger.SURFACE_HANDOFF
	]
	assert_array(_reclaim.triggers()).append_failure_message(
		"乙 must emit SURFACE_HANDOFF only — a TARGET_CHANGED alongside it is "
		+ "the two-independent-ifs signature."
	).contains_exactly(expected_triggers)
	assert_array(_forwarded_reset_triggers).contains_exactly(expected_triggers)

	# ...and the write itself landed
	assert_int(_state.get_current_target().id).is_equal(31)
	assert_bool(_state.is_current_target_valid()).is_true()
	assert_int(_target_changed_count).is_equal(1)


# ─── 重點 1: the reentrancy gate on all seven public entries ────────────────

## The four entries with a return value must answer REJECTED_REENTRANT.
func test_reentrant_set_target_is_rejected_with_rejected_reentrant() -> void:
	# Arrange — a downstream subscriber that calls straight back into the write
	# interface from inside target_changed's handler. Signals are emitted while
	# the latch is still raised, so the inner call lands mid-write. Note the
	# payload is a REGISTERED, genuinely different target: absent the gate the
	# inner call would succeed, so REJECTED_REENTRANT cannot be confused with
	# an ordinary validation failure.
	var _ignored: CursorTarget = _seed_valid_target(50)
	var writer: _ReentrantWriter = _ReentrantWriter.new()
	writer.state = _state
	writer.entry = _ReentrantWriter.Entry.SET_TARGET
	writer.payload = _registered_target(51)
	_state.target_changed.connect(writer.on_target_changed)

	# Act — an outer write that really changes the target, so the signal fires
	var outer: int = _state.set_target(_registered_target(60), false)

	# Assert
	assert_int(outer).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(writer.invocations).append_failure_message(
		"the handler never ran, so this test did not exercise reentrancy at "
		+ "all — target_changed was not emitted for a changed target."
	).is_equal(1)
	assert_int(writer.result).append_failure_message(
		"a reentrant set_target() must return REJECTED_REENTRANT. APPLIED here "
		+ "means signals are emitted AFTER the latch is cleared, and the gate "
		+ "protects nothing."
	).is_equal(CursorState.SetTargetResult.REJECTED_REENTRANT)
	assert_int(_state.get_current_target().id).append_failure_message(
		"the rejected reentrant write was applied anyway"
	).is_equal(60)

	writer.release()


func test_reentrant_mark_pending_reresolve_is_rejected_with_rejected_reentrant() -> void:
	# Arrange — the reentrant payload MATCHES what the state holds at the
	# moment the handler runs (the outer write to 60 has already landed before
	# the signal fires). That matters: with a mismatched payload the inner call
	# would return STALE_NOT_APPLIED and mask whether the gate did anything.
	var _ignored: CursorTarget = _seed_valid_target(50)
	var writer: _ReentrantWriter = _ReentrantWriter.new()
	writer.state = _state
	writer.entry = _ReentrantWriter.Entry.MARK_PENDING_RERESOLVE
	writer.payload = _registered_target(60)
	_state.target_changed.connect(writer.on_target_changed)

	# Act
	var outer: int = _state.set_target(_registered_target(60), false)

	# Assert
	assert_int(outer).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(writer.invocations).append_failure_message(
		"the handler never ran, so reentrancy was not exercised"
	).is_equal(1)
	assert_int(writer.result).append_failure_message(
		"a reentrant mark_pending_reresolve() must return REJECTED_REENTRANT, "
		+ "and specifically NOT STALE_NOT_APPLIED — the two mean opposite "
		+ "things to the caller (retry later vs your belief is out of date)."
	).is_equal(CursorState.MarkResult.REJECTED_REENTRANT)
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"the rejected reentrant mark flipped the validity flag anyway"
	).is_true()

	writer.release()


func test_reentrant_handoff_before_unload_is_rejected_with_rejected_reentrant() -> void:
	# Arrange — 甲 takes no argument, and at the moment the handler runs the
	# state holds a valid target, so absent the gate the inner call would
	# return APPLIED.
	var _ignored: CursorTarget = _seed_valid_target(50)
	var writer: _ReentrantWriter = _ReentrantWriter.new()
	writer.state = _state
	writer.entry = _ReentrantWriter.Entry.HANDOFF_BEFORE_UNLOAD
	_state.target_changed.connect(writer.on_target_changed)

	# Act
	var outer: int = _state.set_target(_registered_target(60), false)

	# Assert
	assert_int(outer).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(writer.invocations).append_failure_message(
		"the handler never ran, so reentrancy was not exercised"
	).is_equal(1)
	assert_int(writer.result).append_failure_message(
		"a reentrant handoff_before_unload() must return REJECTED_REENTRANT"
	).is_equal(CursorState.MarkResult.REJECTED_REENTRANT)
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"the rejected reentrant 甲 marked the target anyway"
	).is_true()
	assert_array(_reclaim.triggers()).append_failure_message(
		"the rejected reentrant 甲 reseeded the reclaim accumulator anyway — a "
		+ "rejected entry must write NOTHING, not merely skip the target field."
	).not_contains([CursorTypes.ResetTrigger.SURFACE_HANDOFF])

	writer.release()


func test_reentrant_handoff_after_mount_is_rejected_with_rejected_reentrant() -> void:
	# Arrange — a registered payload, so absent the gate the inner call would
	# return APPLIED rather than a validation failure.
	var _ignored: CursorTarget = _seed_valid_target(50)
	var writer: _ReentrantWriter = _ReentrantWriter.new()
	writer.state = _state
	writer.entry = _ReentrantWriter.Entry.HANDOFF_AFTER_MOUNT
	writer.payload = _registered_target(70)
	_state.target_changed.connect(writer.on_target_changed)

	# Act
	var outer: int = _state.set_target(_registered_target(60), false)

	# Assert
	assert_int(outer).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(writer.invocations).append_failure_message(
		"the handler never ran, so reentrancy was not exercised"
	).is_equal(1)
	assert_int(writer.result).append_failure_message(
		"a reentrant handoff_after_mount() must return REJECTED_REENTRANT"
	).is_equal(CursorState.SetTargetResult.REJECTED_REENTRANT)
	assert_int(_state.get_current_target().id).append_failure_message(
		"the rejected reentrant 乙 wrote its target anyway"
	).is_equal(60)
	assert_array(_reclaim.triggers()).append_failure_message(
		"the rejected reentrant 乙 fired its UNCONDITIONAL reset anyway"
	).not_contains([CursorTypes.ResetTrigger.SURFACE_HANDOFF])

	writer.release()


## The void entries cannot return a code: reentry is a total no-op plus one
## increment of diagnostic_reentrant_rejection_count (ADR-0005 機制十).
func test_reentrant_arbitrate_device_authority_is_a_total_no_op_and_counts_the_rejection() -> void:
	# Arrange — arbitrate_device_authority() returns void and therefore CANNOT
	# report REJECTED_REENTRANT. ADR-0005 機制十 permits that narrow exception
	# to the never-silent rule only because its sole caller is this system's
	# own CursorStateHost; the price is that the rejection must still leave a
	# trace, via diagnostic_reentrant_rejection_count.
	var _ignored: CursorTarget = _seed_valid_target(50)
	var writer: _ReentrantWriter = _ReentrantWriter.new()
	writer.state = _state
	writer.entry = _ReentrantWriter.Entry.ARBITRATE_DEVICE_AUTHORITY
	_state.target_changed.connect(writer.on_target_changed)
	var rejections_before: int = _state.diagnostic_reentrant_rejection_count
	var authority_before: int = _state.get_device_authority()

	# Act
	var outer: int = _state.set_target(_registered_target(60), false)

	# Assert
	assert_int(outer).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(writer.invocations).append_failure_message(
		"the handler never ran, so reentrancy was not exercised"
	).is_equal(1)
	assert_int(writer.rejection_count_after).append_failure_message(
		"the void entry rejected the reentrant call without counting it — the "
		+ "rejection is then completely traceless, which is the one thing "
		+ "ADR-0005 required in exchange for allowing a silent no-op here."
	).is_equal(rejections_before + 1)

	# Total no-op: nothing this entry owns moved
	assert_int(_state.get_device_authority()).append_failure_message(
		"a rejected reentrant arbitration changed device authority"
	).is_equal(authority_before)
	assert_int(_state.get_current_target().id).is_equal(60)

	writer.release()


func test_reentrant_apply_buffered_navigation_is_a_total_no_op_and_counts_the_rejection() -> void:
	# Arrange — same void-entry contract as arbitrate_device_authority().
	# 🔴 The BODY of this entry is Story 005's (機制六); this story owns its
	# gate, and that is all this test asserts. It does not fake or assert any
	# navigation-application behaviour.
	var _ignored: CursorTarget = _seed_valid_target(50)
	var writer: _ReentrantWriter = _ReentrantWriter.new()
	writer.state = _state
	writer.entry = _ReentrantWriter.Entry.APPLY_BUFFERED_NAVIGATION
	_state.target_changed.connect(writer.on_target_changed)
	var rejections_before: int = _state.diagnostic_reentrant_rejection_count

	# Act
	var outer: int = _state.set_target(_registered_target(60), false)

	# Assert
	assert_int(outer).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(writer.invocations).append_failure_message(
		"the handler never ran, so reentrancy was not exercised"
	).is_equal(1)
	assert_int(writer.rejection_count_after).append_failure_message(
		"the void entry rejected the reentrant call without counting it"
	).is_equal(rejections_before + 1)
	assert_int(_state.get_current_target().id).append_failure_message(
		"a rejected reentrant apply_buffered_navigation() wrote a target"
	).is_equal(60)

	writer.release()


## R6-10 overrides the generic "total no-op" for THIS entry only: a reseed
## request arriving while the latch is up is deferred, not discarded, and the
## holding entry drains it before clearing the latch.
func test_reentrant_reseed_request_is_deferred_not_discarded_and_drained_before_the_gate_clears() -> void:
	# Arrange — R6-10 OVERRIDES the generic "total no-op" for this ONE entry.
	# A reseed arriving while the latch is up is recorded in _pending_reseed
	# and replayed by the holding entry through _drain_pending_reseed() BEFORE
	# the latch clears. Discarding it was the original behaviour and silently
	# reopened the very gap this entry was added to close — and with a void
	# return the caller could not even find out.
	#
	# ⚠️ This test deliberately does NOT assert on
	# diagnostic_reentrant_rejection_count for this entry: ADR-0005 line ~934
	# says the three void entries count a rejection, while R6-10 replaces the
	# rejection with a deferral for this one, and never says whether the count
	# still applies. Registered as an open boundary in this story's report.
	#
	# 🔴 Depends on before_test() injecting a NON-NULL MouseReclaimPolicy.
	var _ignored: CursorTarget = _seed_valid_target(50)
	var writer: _ReentrantWriter = _ReentrantWriter.new()
	writer.state = _state
	writer.entry = _ReentrantWriter.Entry.RESEED_RECLAIM
	_state.target_changed.connect(writer.on_target_changed)

	# Act — the outer write emits target_changed; the handler asks for a reseed
	# (a REASONABLE downstream design per 專家發現 D, not misuse)
	var outer: int = _state.set_target(_registered_target(60), false)

	# Assert
	assert_int(outer).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(writer.invocations).append_failure_message(
		"the handler never ran, so reentrancy was not exercised"
	).is_equal(1)

	# The reseed happened at all — and by the time set_target() returned, so
	# the only code that could have run it is the drain inside that entry.
	var triggers: Array[CursorTypes.ResetTrigger] = _reclaim.triggers()
	assert_array(triggers).append_failure_message(
		"the deferred reseed was DISCARDED rather than drained: the reclaim "
		+ "accumulator stays seeded at a stale coordinate (R6-10)."
	).contains([CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED])
	assert_int(triggers[triggers.size() - 1]).append_failure_message(
		"the drained reseed must be the LAST thing the holding entry does "
		+ "before clearing the latch"
	).is_equal(CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED)
	assert_vector(_reclaim.diagnostic_seed_position()).append_failure_message(
		"the drained reseed did not seed at the current mouse position"
	).is_equal(_MOUSE_POSITION)

	writer.release()


## The latch must be released on every normal exit — a gate that stays raised
## rejects every later call forever, which no single test above would catch.
func test_the_gate_is_released_after_every_normal_call_so_the_next_call_is_accepted() -> void:
	# Arrange / Act — every entry called NORMALLY, in sequence, with no
	# reentrancy anywhere. If any one of them failed to clear
	# _mutation_in_progress on exit, every later call would be rejected
	# forever. No single-entry test above can see that: each of those makes
	# exactly one outer call and would pass against a permanently stuck latch.
	var results: Array[int] = []
	results.append(_state.set_target(_registered_target(1), false))
	results.append(_state.handoff_after_mount(_registered_target(2)))
	results.append(_state.mark_pending_reresolve(_registered_target(2)))
	results.append(_state.set_target(_registered_target(3), false))
	results.append(_state.handoff_before_unload())
	_state.arbitrate_device_authority(_no_events())
	_state.apply_buffered_navigation(_no_events())
	_state.reseed_reclaim_on_focus_regained()
	results.append(_state.set_target(_registered_target(4), false))

	# Assert — exact membership pins the values AND the count, so a short list
	# (an early abort) fails just as loudly as a wrong value would.
	var expected: Array[int] = [
		CursorState.SetTargetResult.APPLIED,
		CursorState.SetTargetResult.APPLIED,
		CursorState.MarkResult.APPLIED,
		CursorState.SetTargetResult.APPLIED,
		CursorState.MarkResult.APPLIED,
		CursorState.SetTargetResult.APPLIED,
	]
	assert_array(results).append_failure_message(
		"an entry left _mutation_in_progress raised on exit — from that point "
		+ "every public write on this instance is rejected forever."
	).contains_exactly(expected)
	assert_int(_state.diagnostic_reentrant_rejection_count).append_failure_message(
		"a void entry counted a rejection although no call in this sequence "
		+ "was reentrant"
	).is_equal(0)
	assert_int(_state.get_current_target().id).is_equal(4)
	assert_bool(_state.is_current_target_valid()).is_true()


# ─── AC-33 / AC-50 / AC-54 / AC-3 / AC-29 / AC-32 ──────────────────────────

## AC-33: the confirm/select gate query returns false while pending re-resolve.
## This system guarantees only that the ANSWER is correct; whether callers obey
## is each caller's own acceptance scope.
func test_ac33_is_current_target_valid_returns_false_while_the_target_is_pending_reresolve() -> void:
	# Arrange
	var target: CursorTarget = _seed_valid_target(5)
	var when_valid: bool = _state.is_current_target_valid()

	# Act
	assert_int(_state.mark_pending_reresolve(target)).is_equal(CursorState.MarkResult.APPLIED)
	var when_pending: bool = _state.is_current_target_valid()

	# Assert — the query a caller uses as its confirm/select precondition must
	# answer false while the target is pending re-resolve. Whether callers
	# actually OBEY the answer is each caller's own acceptance scope, recorded
	# in the GDD's Dependencies chapter — this system guarantees only that the
	# answer is correct.
	assert_bool(when_valid).append_failure_message(
		"PRECONDITION: a freshly written target must read as confirmable"
	).is_true()
	assert_bool(when_pending).append_failure_message(
		"the confirm gate reported the target as confirmable while it was "
		+ "pending re-resolve — every caller would let a confirm through."
	).is_false()

	# ...and it is a stable answer, not a one-shot that resets after a read
	var repeated: Array[bool] = []
	for _i in range(3):
		repeated.append(_state.is_current_target_valid())
	var expected: Array[bool] = [false, false, false]
	assert_array(repeated).append_failure_message(
		"the confirm gate's answer changed across reads with no write between"
	).contains_exactly(expected)


## AC-50: same split as AC-33 for downstream preview consumers — verified here
## is that the flag flips back to true once the owning system re-resolves, so a
## preview that suppressed itself can un-suppress.
func test_ac50_the_validity_flag_flips_back_to_true_once_the_owning_system_re_resolves() -> void:
	# Arrange — AC-50's split is identical to AC-33's: this system guarantees
	# only that the flag query answers correctly. Whether a downstream preview
	# (movement range, engagement range, affinity link preview) suppresses
	# itself is that system's own acceptance scope.
	var target: CursorTarget = _seed_valid_target(9)
	var observed: Array[bool] = []

	# Act — the full round trip a preview consumer sees
	observed.append(_state.is_current_target_valid())        # confident preview allowed
	assert_int(_state.mark_pending_reresolve(target)).is_equal(CursorState.MarkResult.APPLIED)
	observed.append(_state.is_current_target_valid())        # preview must suppress
	assert_int(_state.set_target(_registered_target(9), false)).is_equal(
		CursorState.SetTargetResult.APPLIED
	)
	observed.append(_state.is_current_target_valid())        # preview may un-suppress

	# Assert — the THIRD value is the one that matters here. A flag that never
	# flips back leaves every downstream preview suppressed forever, and a test
	# that only checked the false direction would never see it. Note the
	# re-resolution deliberately reuses the SAME surface and id, which is the
	# common case (reloading onto the same board) and the one where equals()
	# alone cannot detect that anything happened.
	var expected: Array[bool] = [true, false, true]
	assert_array(observed).append_failure_message(
		"the validity flag did not complete the valid -> pending -> valid "
		+ "round trip a downstream preview consumer depends on"
	).contains_exactly(expected)


## AC-54 — [b]VERIFIED HERE: only the structural precondition.[/b]
##
## ✅ What this test does verify: two separate read queries
## ([method CursorState.is_current_target_valid] and
## [method CursorState.get_device_authority]) let a caller tell AC-54's two
## rejection causes apart programmatically.
##
## ❌ What it CANNOT verify, and does not pretend to: that the resulting
## feedback is [i]perceptually[/i] distinguishable. AC-54's own text sets its
## verification method as Visual/Feel evidence (recording + lead sign-off,
## ADVISORY per coding-standards.md), and the concrete feedback — sound
## timbre, rumble pattern — [b]does not exist in code yet[/b]; it is left to
## [code]/art-bible[/code] and the sound designer. No automated test can reach
## it, and none here tries.
func test_ac54_partial_the_two_rejection_causes_are_distinguishable_through_two_separate_queries() -> void:
	# Arrange / Act — build AC-54's two rejection situations one after the
	# other, reading BOTH queries in each.
	# (a) the click is refused because authority is not the mouse, while the
	#     target itself is perfectly fine:
	var _ignored: CursorTarget = _seed_valid_target(2)
	_state.set(&"_device_authority", CursorTypes.Authority.KEYBOARD_GAMEPAD)
	var cause_a: Array = [_state.is_current_target_valid(), _state.get_device_authority()]

	# (b) the click is refused because the target is pending re-resolve, while
	#     authority IS the mouse:
	_state.set(&"_device_authority", CursorTypes.Authority.MOUSE)
	assert_int(_state.mark_pending_reresolve(_registered_target(2))).is_equal(
		CursorState.MarkResult.APPLIED
	)
	var cause_b: Array = [_state.is_current_target_valid(), _state.get_device_authority()]

	# Assert — each situation reads exactly as expected...
	var expected_a: Array = [true, CursorTypes.Authority.KEYBOARD_GAMEPAD]
	var expected_b: Array = [false, CursorTypes.Authority.MOUSE]
	assert_array(cause_a).append_failure_message(
		"cause (a): target valid, authority not mouse"
	).contains_exactly(expected_a)
	assert_array(cause_b).append_failure_message(
		"cause (b): authority mouse, target pending re-resolve"
	).contains_exactly(expected_b)

	# ...and, the actual point, the two are DISTINGUISHABLE from the read
	# interface alone. Folded into one merged "can I confirm?" boolean both
	# would read false, and the caller would be STRUCTURALLY unable to produce
	# different feedback — while the two correct recoveries are opposites
	# (wait / navigate elsewhere, versus MOVE the mouse to reclaim authority).
	assert_bool(cause_a == cause_b).append_failure_message(
		"the two rejection causes are indistinguishable through the read "
		+ "interface, so no caller can tell the player which fix to try."
	).is_false()


## AC-3 — [b]VERIFIED HERE: the interface surface only.[/b]
##
## ✅ What this test does verify: [CursorState] exposes exactly the seven
## gated write entries and four read queries ADR-0005's Key Interfaces
## section defines, and nothing else public. It is a tripwire: a new public
## method cannot appear without someone re-running AC-3's review.
##
## ❌ What it CANNOT verify: that no bypass path exists. [b]AC-3's own text
## already says so[/b] — "驗證方式:程式碼審查/靜態分析為主;執行期測試僅能
## 驗證「有」繞過路徑的反例存在與否,無法窮舉證明「不存在」". This test does
## not claim more than the AC claims for itself. The other half of AC-3 (that
## no input source writes a rendered highlight directly, bypassing this
## interface) needs the presentation layer, which is Stories 010/011.
func test_ac3_partial_cursor_state_exposes_exactly_the_seven_write_entries_and_four_read_queries() -> void:
	# Arrange — enumerate the class's PUBLIC method surface by reflection.
	# get_script_method_list() reports only methods declared on this script.
	# Underscore-prefixed names are the private paths (deliberately excluded:
	# they are not reachable entry points for an input source), and "@"-
	# prefixed names are engine-synthesised entries.
	var method_names: Array[String] = []
	for method: Dictionary in _state.get_script().get_script_method_list():
		var method_name: String = String(method.get("name", ""))
		if method_name.begins_with("_") or method_name.begins_with("@"):
			continue
		method_names.append(method_name)
	method_names.sort()

	# Assert — the loop above is the only loop in this test, and every
	# assertion is OUTSIDE it: an empty method list produces an empty array and
	# fails contains_exactly() loudly, rather than passing with zero assertions.
	var expected: Array[String] = [
		"apply_buffered_navigation",
		"arbitrate_device_authority",
		"get_current_target",
		"get_device_authority",
		"handoff_after_mount",
		"handoff_before_unload",
		"is_current_target_valid",
		"mark_pending_reresolve",
		"reclaim_progress",
		"reseed_reclaim_on_focus_regained",
		"set_target",
	]
	expected.sort()
	assert_array(method_names).append_failure_message(
		"CursorState's public surface changed. ADDED a public method? That is "
		+ "a new way for an input source to reach cursor state — re-run AC-3's "
		+ "review (does every input source still go through ONE write "
		+ "interface?) and only then update this list. REMOVED one? A caller "
		+ "named in ADR-0005's Key Interfaces just lost its entry point."
	).contains_exactly(expected)
	assert_int(method_names.size()).append_failure_message(
		"expected exactly 7 write entries + 4 read queries"
	).is_equal(11)


## AC-29 — [b]VERIFIED HERE: this system's side of the obligation only.[/b]
##
## ✅ What this test does verify: marking a target pending re-resolve notifies
## every subscriber exactly once, and the state then holds until a caller
## writes a new target.
##
## ❌ What it CANNOT verify: that all mounted UI surfaces actually RENDER the
## unified pending-re-resolve visual on the next frame. Nothing renders yet —
## that is Stories 010/011, and no test here fakes a surface to pretend
## otherwise.
func test_ac29_partial_marking_pending_reresolve_notifies_every_subscriber_exactly_once() -> void:
	# Arrange — TWO independent subscribers. With one, "notified every
	# subscriber exactly once" cannot be distinguished from "emitted exactly
	# once in total", and AC-29's whole point is that surfaces must not
	# disagree with each other.
	var target: CursorTarget = _seed_valid_target(13)
	_state.target_changed.connect(_on_target_changed_secondary)
	_secondary_target_changed_count = 0

	# Act
	assert_int(_state.mark_pending_reresolve(target)).is_equal(CursorState.MarkResult.APPLIED)

	# Assert — one notification, delivered to both, carrying no payload (N4):
	# subscribers re-read through the queries rather than holding a copy that
	# could drift into per-surface disagreement.
	assert_int(_target_changed_count).append_failure_message(
		"the first subscriber was notified %d times, expected exactly 1"
		% _target_changed_count
	).is_equal(1)
	assert_int(_secondary_target_changed_count).append_failure_message(
		"the second subscriber was not notified exactly once — mounted "
		+ "surfaces would disagree about whether the target is pending "
		+ "re-resolve, the per-implementation inconsistency AC-29 forbids."
	).is_equal(1)

	# ...and both read the same unified answer back
	assert_bool(_state.is_current_target_valid()).is_false()

	# The presentation state persists until the caller writes a new target: no
	# further notification, and no drift, with nothing else called.
	var stable: Array[bool] = []
	for _i in range(3):
		stable.append(_state.is_current_target_valid())
	var expected: Array[bool] = [false, false, false]
	assert_array(stable).contains_exactly(expected)
	assert_int(_target_changed_count).append_failure_message(
		"extra notifications arrived with no further write"
	).is_equal(1)


## AC-32 — 🔴 [b]NOT COVERED. BLOCKED ON STORY 005.[/b]
##
## This test does [b]not[/b] verify AC-32 — and it is [b]not[/b] a tripwire
## for it either (that claim used to live at the bottom of this comment; it
## was wrong, see there). It is a gap declaration written down in code, so
## the gap stays visible instead of quietly becoming someone's assumption.
##
## AC-32's WHEN clause is player navigation, which reaches this system only
## through [method CursorState.apply_buffered_navigation] — and that method's
## body is an explicit "STORY 005 SEAM": its gate, diagnostic counter and
## drain are implemented, but the "decide what to apply from the buffered
## events" half is not. There is therefore no honest way to observe AC-32's
## THEN clause from this story.
##
## 🔴 [b]Deliberately NOT substituted with a [method CursorState.set_target]
## call.[/b] That would exercise the caller-delegated path — the exact
## opposite of what AC-32 asks (that the player unsticks themselves with NO
## caller system involved) — while wearing AC-32's name. A false green is
## worse here than an admitted gap.
##
## 🔴 [b]This test does NOT go red when Story 005 lands.[/b] Two independent
## properties of its own inputs guarantee "nothing was written", regardless
## of whether the seam above is still empty or fully implemented:
##   1. the event array passed in is EMPTY ([method _no_events]) — no correct
##      機制六 body can derive a new target from zero events;
##   2. [code]_device_authority[/code] is never set in this test, so it is
##      UNINITIALIZED — which the seam comment itself calls a no-op.
## The assertion below therefore measures a RESULT ("still invalid") that has
## a second cause the test itself supplies. It is insensitive to the very
## change it names.
##
## 🔴 [b]Do not try to "fix" the tripwire.[/b] Three stronger-looking
## rewrites were examined and rejected in
## [code]docs/reviews/story-007-test-evidence-review-2026-09-03.md[/code] §4.5
## (feed real [code]ui_*[/code] events + set authority: guesses at an event
## shape Story 005 has not decided yet, and guessing wrong yields a MORE
## convincing false green; assert on the production file's source text:
## tests a comment, not behaviour, and there are two "STORY 005 SEAM" markers
## so deleting one still matches; assert on private state: equivalent to the
## current assertion). A weak tripwire that looks strong is a negative change.
##
## What this comment must therefore not say is that anything here will remind
## anyone. The failure message below still spells out what to write instead,
## and THAT part is worth keeping — but the only defence that will actually be
## executed is AC-32 being verified as part of Story 005's own acceptance.
## ⚠️ As of 2026-09-03 it is NOT registered there: searching the whole epic for
## "AC-32" matches only this story's work order
## ([code]story-007-write-read-interface.md[/code] line 69), not
## [code]story-005-frame-buffer-ordering.md[/code]. Registering it is
## recommendation 2 of §4.5 of the review above and has [b]not[/b] been done —
## do not read this comment as evidence that it has.
func test_ac32_blocked_apply_buffered_navigation_is_still_a_story_005_seam_and_writes_no_target() -> void:
	# Arrange — AC-32's GIVEN: a target whose validity flag is invalid
	# (pending re-resolve), and no caller system about to intervene.
	var _ignored: CursorTarget = _seed_valid_target(17)
	assert_int(_state.mark_pending_reresolve(_registered_target(17))).is_equal(
		CursorState.MarkResult.APPLIED
	)
	assert_bool(_state.is_current_target_valid()).is_false()
	_target_changed_count = 0
	_reclaim.reset_calls = []

	# Act — AC-32's WHEN: the player navigates. apply_buffered_navigation() is
	# the only entry that carries player navigation into this system.
	_state.apply_buffered_navigation(_no_events())

	# Assert — 🔴 THIS TEST ASSERTS THE GAP, NOT THE BEHAVIOUR.
	# AC-32's THEN (coordinate becomes the newly navigated one, validity flips
	# back to true, the stall lifts with no caller system involved) cannot
	# happen yet: this entry's body is an explicit "STORY 005 SEAM" — the gate,
	# the diagnostic counter and the drain are implemented, the "decide what to
	# apply from the buffered events" half is not. Confirmed by reading the
	# production method, not assumed.
	assert_bool(_state.is_current_target_valid()).append_failure_message(
		"apply_buffered_navigation() now writes a target — the Story 005 seam "
		+ "has been filled. THAT IS GOOD NEWS AND THIS TEST IS NOW WRONG: "
		+ "delete it and write the real AC-32 test (KEYBOARD_GAMEPAD "
		+ "authority, real NAVIGATION-class ui_* events, assert the coordinate "
		+ "becomes the navigated one and validity flips back to true with no "
		+ "caller system involved). Until that happens AC-32 is UNCOVERED — "
		+ "do not let this test's green stand in for it."
	).is_false()
	assert_int(_state.get_current_target().id).is_equal(17)
	assert_int(_target_changed_count).is_equal(0)
	assert_array(_reclaim.reset_calls).is_empty()

	# The half this story DOES own still behaves: a normal, non-reentrant call
	# is accepted and counts no rejection.
	assert_int(_state.diagnostic_reentrant_rejection_count).append_failure_message(
		"a normal call to a void entry counted a reentrancy rejection"
	).is_equal(0)
