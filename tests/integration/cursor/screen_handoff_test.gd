## Integration tests for Story 009 — the 甲/乙/丙 screen-handoff calling
## convention (ADR-0005 機制十一) built on top of [CursorState] (Story 007) and
## [CursorSurfaceRegistry] (Story 003).
##
## Covers AC-61 / AC-62 / AC-63a / AC-63b from
## [code]production/epics/cursor-highlight-state/story-009-screen-handoff.md[/code].
##
## [b]This is an INTEGRATION suite, not a duplicate of
## [code]tests/unit/cursor/write_read_interface_test.gd[/code][/b]: that file
## already has 8 tests exercising [method CursorState.handoff_before_unload]
## and [method CursorState.handoff_after_mount] as bare method calls. This
## file instead assembles [CursorState] + [CursorSurfaceRegistry] together and
## walks the SCENARIO SHAPE each AC's GIVEN/WHEN/THEN describes (a surface
## actually being torn down and removed from the registry, two independently
## constructed states standing in for two different call paths, a
## cancel-and-return sequence), which is what a bare unit test of one method
## in isolation cannot exercise.
##
## 🔴 [b]No real caller of this system exists anywhere in this codebase yet[/b]
## (the tactical move/engage system is undesigned; [code]battle_screen.gd[/code]
## maintains its own pre-existing [code]_cursor_cell[/code], tracked separately
## in [code]docs/tech-debt-register.md[/code] and out of this story's scope).
## Every "呼叫方" action below is therefore performed BY THIS TEST FILE directly
## against [CursorState]'s public API — exactly what AC-62's own text
## anticipates and explicitly permits ("測試驅動端記錄到的、對本系統介面的呼叫
## 序列由測試框架自行發出、自行計數,不需要本系統提供任何生產或診斷觀測介面").
##
## [b]Determinism / Isolation[/b]: same conventions as
## [code]write_read_interface_test.gd[/code] — [CursorState] is a pure
## [RefCounted] DI core, every collaborator is a hand-built test double or a
## real [CursorSurfaceRegistry] with explicitly registered nodes, no random
## seed/timer/[code]await[/code]/file/network I/O, and the [code]CursorStateHost[/code]
## Autoload is never touched by any test in this file — every test builds its
## own [CursorState] instance(s).
extends GdUnitTestSuite


## Surface tag every test in this file registers and targets. Deliberately
## the same convention as [code]write_read_interface_test.gd[/code]'s
## [code]_REGISTERED_SURFACE[/code] — [b]not[/b] shared code, a separate
## constant in a separate file, because this suite's fixtures are independent
## (Isolation).
const _REGISTERED_SURFACE: CursorTypes.SurfaceType = CursorTypes.SurfaceType.BOARD_TILE

## Constant coordinate the injected [param mouse_position_provider] returns.
## Non-zero for the same reason as [code]write_read_interface_test.gd[/code]'s
## [code]_MOUSE_POSITION[/code]: the production fallback value IS
## [constant Vector2.ZERO], so a zero probe could not distinguish a real
## provider read from that fallback.
const _MOUSE_POSITION: Vector2 = Vector2(321.0, 654.0)

## 🔴 [b]Trap "乙" from this story's dispatch brief[/b]: a NON-ZERO seed for the
## injected [MouseReclaimPolicy] double's [code]progress[/code] field, used
## everywhere this file needs to prove a reset actually zeroed the mouse-reclaim
## accumulator. [member CursorState.reclaim_progress] against the REAL
## [code]CursorStateHost[/code] Autoload is UNCONDITIONALLY [code]0.0[/code]
## today (Story 014 unbuilt — see [code]cursor_state.gd[/code]'s
## [constant CursorState.ERR_RECLAIM_POLICY_ABSENT]), so asserting "0.0 after
## the call" against that instance would pass whether or not any reset ever
## fired. Seeding a double at a non-zero value first, then asserting it reads
## [code]0.0[/code] only AFTER the call under test, is the only way this
## assertion has any content — see [code]_RecordingReclaimPolicy.reset()[/code]
## below for how the double stays behaviourally honest about this.
const _STALE_RECLAIM_PROGRESS_SENTINEL: float = 0.73


## Recording [MouseReclaimPolicy] test double — same shape as
## [code]write_read_interface_test.gd[/code]'s [code]_RecordingReclaimPolicy[/code],
## duplicated rather than imported: GDScript inner classes are not cheaply
## shared across files without a third [code]class_name[/code]d file neither
## story asked for, and this suite's fixtures are meant to be independent of
## that file's (Isolation).
##
## [b]One behavioural addition over the unit-test version[/b]: [method reset]
## zeros [member progress], mirroring what the real Story 014 policy will do
## (a reset zeros the accumulator, and [method CursorState.reclaim_progress]
## is a pure forward to it). Without this, seeding
## [constant _STALE_RECLAIM_PROGRESS_SENTINEL] would be theatre — the double
## would keep reporting the stale value forever regardless of whether
## production code ever called [method reset].
class _RecordingReclaimPolicy extends MouseReclaimPolicy:
	var reset_calls: Array[Dictionary] = []
	var progress: float = 0.0

	func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
		return false

	func reclaim_progress() -> float:
		return progress

	func reset(seed_position: Vector2, trigger: CursorTypes.ResetTrigger) -> void:
		reset_calls.append({"position": seed_position, "trigger": trigger})
		# See class doc comment: a real policy's reset() zeros the accumulator.
		progress = 0.0
		reset_triggered.emit(trigger)

	func diagnostic_seed_position() -> Vector2:
		return Vector2.ZERO


## Named-method [Callable] target for [member CursorState._mouse_position_provider]
## — a named binding, not a lambda literal, matching this project's own
## convention (機制十 專家發現 G / S-1).
func _test_mouse_position() -> Vector2:
	return _MOUSE_POSITION


## A target on [constant _REGISTERED_SURFACE].
func _target(id: int) -> CursorTarget:
	return CursorTarget.make(_REGISTERED_SURFACE, id)


## Builds one fresh, independent (state, registry, reclaim-double) triple. Each
## call produces objects with no relationship to any other call's objects —
## used by AC-62's test, which needs TWO completely independent setups to
## compare, not two views of the same one.
func _build_fixture() -> Dictionary:
	var registry: CursorSurfaceRegistry = CursorSurfaceRegistry.new()
	registry.register(_REGISTERED_SURFACE, auto_free(Node.new()))
	var reclaim: _RecordingReclaimPolicy = _RecordingReclaimPolicy.new()
	reclaim.progress = _STALE_RECLAIM_PROGRESS_SENTINEL
	var state: CursorState = CursorState.new(
		reclaim, registry, Callable(self, "_test_mouse_position")
	)
	return {"state": state, "registry": registry, "reclaim": reclaim}


## Reads the four comparison points AC-62 names: [b](游標目標座標,
## 有效性旗標, 裝置權威, 滑鼠奪權累積位移量)[/b]. "座標" is represented here as
## the [code](surface, id)[/code] pair — this system has no x/y geometry
## ([CursorTarget]'s own class doc comment: "Does NOT contain hitbox/collision
## geometry"), so [code](surface, id)[/code] IS this system's target-identity
## coordinate. Flattened to 5 array slots rather than a nested structure purely
## for a readable [code]assert_array[/code] diff on failure.
func _observe_four_tuple(state: CursorState) -> Array:
	var current: CursorTarget = state.get_current_target()
	return [
		current.surface,
		current.id,
		state.is_current_target_valid(),
		state.get_device_authority(),
		state.reclaim_progress(),
	]


# ═══════════════════════════════════════════════════════════════════════════
# AC-61 (F2-2 甲分支): 舊表面存在時讀檔 — 交接義務在存檔讀取路徑上確實履行
# ═══════════════════════════════════════════════════════════════════════════

## GIVEN 戰鬥進行中、游標目標為戰棋表面上的某個單位格、該表面已掛載,WHEN 玩家
## 經暫停選單確認載入另一份存檔、流程進入非互動式載入過場、舊戰棋表面即將拆除,
## THEN 呼叫方在拆除之前呼叫 [method CursorState.handoff_before_unload],且
## 檢視此刻狀態時有效性旗標為無效、不存在任何指向已拆除表面的有效目標.
##
## [b]Two independent proofs for the THEN clause's second half[/b] — "不存在
## 任何指向已拆除表面的有效目標" is checked two ways so neither could pass by
## accident: (a) this system's OWN validity flag still reads false after the
## surface is actually gone, and (b) the surface itself is structurally
## unresolvable through the registry (proving the teardown really happened,
## not merely that this test called the right method name).
func test_ac61_handoff_before_unload_leaves_no_valid_target_on_the_torn_down_surface() -> void:
	# Arrange — GIVEN: battle in progress, valid target on a mounted surface.
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var registry: CursorSurfaceRegistry = fixture["registry"]

	var original: CursorTarget = _target(23)
	assert_int(state.set_target(original, false)).append_failure_message(
		"PRECONDITION: could not seed the valid target AC-61 starts from."
	).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_bool(state.is_current_target_valid()).is_true()

	# Act — WHEN: the caller marks the target pending-re-resolve BEFORE tearing
	# the old surface down (機制十一 甲, the entry this story's own hard rule
	# names as the branch's ONLY entry point).
	var mark_result: int = state.handoff_before_unload()

	# Assert (first half of THEN) — invalid BEFORE the surface is actually gone.
	assert_int(mark_result).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"AC-61: the target must already be pending-re-resolve BEFORE the old "
		+ "surface tears down — that ordering is the entire point of 甲."
	).is_false()

	# Act (continued) — the old surface actually tears down. The only way this
	# system's own registry observes teardown is an explicit unregister() call
	# (CursorSurfaceRegistry's own class doc comment: table 1 has "no automatic
	# cleanup" — nothing here fires on its own).
	assert_int(registry.unregister(_REGISTERED_SURFACE)).append_failure_message(
		"PRECONDITION: the surface must really be removed from the registry, or "
		+ "the second half of this AC's THEN clause proves nothing."
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)

	# Assert (second half of THEN) — 不存在任何指向已拆除表面的有效目標.
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"validity flipped back to true on its own after the surface tore down — "
		+ "AC-24 requires this system to never auto-heal a pending target."
	).is_false()
	assert_object(registry.get_surface(_REGISTERED_SURFACE)).append_failure_message(
		"AC-61: the torn-down surface must be structurally unresolvable through "
		+ "the registry — otherwise 'no valid target on it' is an accident of "
		+ "this system's state, not a fact about the surface being gone."
	).is_null()

	# Target identity (surface/id) is preserved — only the flag moved. This is
	# handoff_before_unload()'s Story-007 contract, restated here because this
	# story's own AC is what requires it, not borrowed trust from that file.
	var after: CursorTarget = state.get_current_target()
	assert_int(after.surface).is_equal(_REGISTERED_SURFACE)
	assert_int(after.id).is_equal(23)


# ═══════════════════════════════════════════════════════════════════════════
# AC-62 (F2-2 乙分支): 無舊表面時讀檔 — 乙-直接路徑與新開局路徑的等價性斷言
# ═══════════════════════════════════════════════════════════════════════════
#
# ✅ [b]ARCHITECTURAL READING THIS TEST GROUP PINS DOWN — RULED 2026-09-04.[/b]
# Reading (b) below was originally a godot-gdscript-specialist determination
# made while writing this test, flagged as unconfirmed. It was escalated and
# [b]the manager ruled reading (b) on 2026-09-04[/b]. The ruling and its three
# stated reasons now live in ADR-0005 機制十一, in the paragraph headed
# "🔴 `新開局` 走哪一個入口" — [b]that section is the authority, not this
# comment[/b]. If the two ever disagree, the ADR wins and this file is wrong.
#
# AC-62 requires the "乙-直接路徑" (title screen → direct load) and "新開局
# 路徑" (brand new game) call sequences to be "完全相同". Two readings exist
# and they are NOT equivalent:
#   (a) a brand-new game calls [method CursorState.set_target] — the general
#       write interface, and the literal text of GDD Core Rules #7's own
#       "乙" paragraph, which predates this ADR's dedicated 乙 entry and never
#       names one; or
#   (b) a brand-new game's first-ever mount is ALSO "a new surface mounting"
#       under 機制十一's own definition, so it ALSO calls
#       [method CursorState.handoff_after_mount].
# Reading (a) makes AC-62's call-sequence clause structurally unsatisfiable:
# this story's own hard rule ("乙分支必須有專屬入口,不能重用 set_target()")
# forces 乙-直接 onto [method CursorState.handoff_after_mount], and two
# DIFFERENT entry points can never produce a "完全相同" call sequence no
# matter what arguments are passed. This test implements reading (b): ANY
# first-time mount of a cursor surface — preceded by a real 甲 teardown, by a
# direct load, or by nothing at all — goes through
# [method CursorState.handoff_after_mount], because "a surface just mounted
# and needs its initial target set, unconditionally reset" is a property of
# THE MOUNT EVENT, not of whether a save was involved.
#
# [b]Consequence, stated plainly rather than left implicit[/b]: because BOTH
# simulated callers below invoke the identical [method _mount_initial_target]
# helper, the call-sequence assertion has NO independent power to catch a
# real divergence TODAY — there is no second, independently-authored caller
# module yet to diverge from (see this file's header note: no real caller of
# this system exists anywhere in this codebase). Its value is as a PINNED
# CONTRACT for the future: when a real "new game" flow and a real "load flow"
# caller are implemented (by the undesigned tactical move/engage system),
# each should be checked against calling [method CursorState.handoff_after_mount]
# the same way this test does.
#
# 🔴 [b]So whoever builds those two flows must read ADR-0005 機制十一's
# "🔴 `新開局` 走哪一個入口" paragraph BEFORE writing them.[/b] The ADR points
# back at this file by name; this is the pair. A pinned contract that nobody
# is told to read is not a contract — it is a comment.


## Shared "設定新目標" helper standing in for BOTH the 新開局 and 乙-直接
## simulated callers — see this test group's header note for why both use
## [method CursorState.handoff_after_mount] rather than
## [method CursorState.set_target]. Appends a description of the call to
## [param call_log] so this AC's "呼叫序列比對" clause has something concrete
## to compare (AC-62 explicitly permits the test framework to record its own
## call sequence rather than requiring a production observability hook).
func _mount_initial_target(state: CursorState, target_id: int, call_log: Array[String]) -> int:
	call_log.append("handoff_after_mount(surface=%d, id=%d)" % [_REGISTERED_SURFACE, target_id])
	return state.handoff_after_mount(_target(target_id))


## The cross-path equivalence assertion itself: identical initial battlefield
## configuration, three checkpoints, four-tuple + call-sequence comparison.
func test_ac62_direct_load_and_new_game_paths_share_four_tuple_and_call_sequence() -> void:
	# Arrange — "以相同的初始戰場配置" — two INDEPENDENT fixtures (not two
	# views of the same state/registry), each seeded with the same non-zero
	# reclaim-progress sentinel (trap 乙, see that constant's doc comment).
	var new_game: Dictionary = _build_fixture()
	var direct_load: Dictionary = _build_fixture()
	var new_game_state: CursorState = new_game["state"]
	var direct_load_state: CursorState = direct_load["state"]
	var target_id: int = 7

	# ─── Checkpoint 1: 「設定新目標」介面被呼叫之前 ─────────────────────────
	var new_game_cp1: Array = _observe_four_tuple(new_game_state)
	var direct_load_cp1: Array = _observe_four_tuple(direct_load_state)
	assert_array(new_game_cp1).append_failure_message(
		"checkpoint 1 differs between the two fixtures before either caller has "
		+ "done anything — both CursorState instances were constructed the same "
		+ "way, so this must hold trivially. A failure here means the fixtures "
		+ "were NOT built identically and nothing below this line can be trusted."
	).is_equal(direct_load_cp1)
	assert_bool(new_game_state.is_current_target_valid()).append_failure_message(
		"PRECONDITION: checkpoint 1 must be a not-yet-mounted state."
	).is_false()
	assert_float(new_game_cp1[4]).append_failure_message(
		"PRECONDITION for trap-乙: checkpoint 1 must read the non-zero stale "
		+ "sentinel — otherwise a later 0.0 reading proves nothing about "
		+ "whether a reset actually fired."
	).is_equal_approx(_STALE_RECLAIM_PROGRESS_SENTINEL, 0.0001)

	# ─── Act: both paths mount via the SAME shared helper (see this test ───
	# group's header note on why, and what this pins down vs. what it cannot
	# prove given no independently-authored caller exists yet).
	var new_game_log: Array[String] = []
	var direct_load_log: Array[String] = []
	var new_game_result: int = _mount_initial_target(new_game_state, target_id, new_game_log)
	var direct_load_result: int = _mount_initial_target(
		direct_load_state, target_id, direct_load_log
	)
	assert_int(new_game_result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(direct_load_result).is_equal(CursorState.SetTargetResult.APPLIED)

	# ─── Checkpoint 2: 「設定新目標」介面回傳之後 ───────────────────────────
	var new_game_cp2: Array = _observe_four_tuple(new_game_state)
	var direct_load_cp2: Array = _observe_four_tuple(direct_load_state)

	# ─── Checkpoint 3: 玩家可互動的第一個影格 ───────────────────────────────
	# 🔴 Collapses to a second read with nothing executed in between:
	# [CursorState] is a scene-tree-less [RefCounted] with no timer/_process of
	# its own (機制六 arbitration lives on Story 005's node, not here), so
	# nothing autonomously changes it between "the write returns" and "the
	# next frame" without an explicit call this test does not make. Included
	# anyway because AC-62 names it explicitly, and it retains narrow real
	# power: it would catch a hypothetical future regression where a field
	# drifts on its own between calls — the same "nothing changes without an
	# explicit write" invariant AC-24's unit tests already pin, re-exercised
	# here at the integration layer across two independent instances.
	var new_game_cp3: Array = _observe_four_tuple(new_game_state)
	var direct_load_cp3: Array = _observe_four_tuple(direct_load_state)

	# ─── Assert: four-tuple correct AND identical across paths/checkpoints ──
	var expected_post_mount: Array = [
		_REGISTERED_SURFACE, target_id, true, CursorTypes.Authority.UNINITIALIZED, 0.0,
	]
	var observations: Dictionary = {
		"new_game checkpoint 2": new_game_cp2,
		"direct_load checkpoint 2": direct_load_cp2,
		"new_game checkpoint 3": new_game_cp3,
		"direct_load checkpoint 3": direct_load_cp3,
	}
	for label: String in observations:
		assert_array(observations[label]).append_failure_message(
			(
				"AC-62: %s must equal (surface=%d, id=%d, valid=true, "
				+ "authority=UNINITIALIZED, displacement=0.0). Got %s"
			) % [label, _REGISTERED_SURFACE, target_id, observations[label]]
		).is_equal(expected_post_mount)

	# ─── Assert: 呼叫序列完全相同 (AC-62's explicit test-framework allowance) ─
	assert_array(new_game_log).append_failure_message(
		"AC-62: the two simulated callers' recorded call sequences diverged. "
		+ "See this test group's header note on the architectural reading this "
		+ "assertion pins down, and on what it can/cannot prove today."
	).is_equal(direct_load_log)


## AC-62's own "裝置權威維持呼叫前的值不變" clause, and its explicit "與甲→乙
## 路徑的區隔" note. [b]Deliberately NOT part of the cross-path equivalence
## test above[/b] — AC-62's own text states the 甲→乙 sub-case's checkpoint-one
## authority is LEGITIMATELY ALLOWED to differ from a brand-new game's
## (UNINITIALIZED), so this is checked path-relative (before vs. after, on the
## SAME instance), never compared against the other path.
func test_ac62_authority_survives_a_甲_to_乙_transition_unchanged() -> void:
	# Arrange — a player was already using the mouse before the save-load began.
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	state.set(&"_device_authority", CursorTypes.Authority.MOUSE)
	assert_int(state.set_target(_target(3), false)).is_equal(
		CursorState.SetTargetResult.APPLIED
	)
	var authority_before: int = state.get_device_authority()

	# Act — 甲: old surface tears down...
	assert_int(state.handoff_before_unload()).is_equal(CursorState.MarkResult.APPLIED)
	var authority_after_甲: int = state.get_device_authority()

	# ...then 乙 (甲→乙 sub-case): new surface mounts with a caller-computed target.
	var mount_result: int = state.handoff_after_mount(_target(4))
	var authority_after_乙: int = state.get_device_authority()

	# Assert — untouched at every step (Core Rules #4: orthogonal fields).
	assert_int(mount_result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(authority_after_甲).append_failure_message(
		"甲 must not touch device authority."
	).is_equal(authority_before)
	assert_int(authority_after_乙).append_failure_message(
		"AC-62: 甲→乙 must preserve the device authority held before the "
		+ "transition began — this is exactly what distinguishes it from a "
		+ "brand-new game's UNINITIALIZED starting authority (AC-62's own "
		+ "'與甲→乙路徑的區隔' clause)."
	).is_equal(CursorTypes.Authority.MOUSE)


# ═══════════════════════════════════════════════════════════════════════════
# AC-63a / AC-63b (F2-2 丙分支): 讀檔取消後返回 — 原目標有效沿用 / 已失效重算
# ═══════════════════════════════════════════════════════════════════════════
#
# Both branches call [method CursorState.set_target] — cursor_state.gd's own
# doc comment names it "TR-cursor-012's dual-input write interface, and the 丙
# handoff branch's entry (機制十一)", distinct from 乙's dedicated
# [method CursorState.handoff_after_mount]. Neither AC alone can prove the
# conditional branch really branches (Story 009's own text: "任一 AC 皆無法
# 單獨佐證另一支的正確性") — 63a proves reuse works, 63b proves recomputation
# is genuinely reachable and produces a DIFFERENT identity than 63a's reused X.
#
# ❌ Not verified by either test below: actual rendering ("高亮以一般高亮樣式
# 呈現"). Stories 010/011 own the presentation layer. The proxy verified here
# is [method CursorState.is_current_target_valid] — Core Rules #2 ties
# downstream preview suppression to exactly this flag, so a caller correctly
# reading it back as [code]true[/code] is what makes "not suppressed" true.
# 🔴 Also not verified, and not verifiable at this system's boundary: the hard
# rule "丙分支呼叫方必須主動重設,不得讓游標停在待重新解析狀態返回一個可互動
# 畫面" is a CALLER obligation. No real caller exists in this codebase (see
# this file's header note), so there is nothing to check that a hypothetical
# future caller "remembers" to make this call at all — these tests can only
# prove the interface behaves correctly WHEN called, not that it always will
# be.


## AC-63a: the original target is still valid (原表面未拆除、原目標所指實體
## 仍存在) — the caller reuses X directly, with no Core Rules #6 recompute.
func test_ac63a_original_target_still_valid_is_reused_without_recomputation() -> void:
	# Arrange — GIVEN: 甲 already ran, holding X = surface/id (BOARD_TILE, 5).
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var x: CursorTarget = _target(5)
	assert_int(state.set_target(x, false)).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(state.handoff_before_unload()).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"PRECONDITION: AC-63a starts from the pending-re-resolve state 甲 leaves."
	).is_false()

	# WHEN: load flow cancelled; the entity X points at still exists. THEN:
	# caller reuses X verbatim — no separate "compute a new target" step exists
	# anywhere in this test, which is this test's own proof that no Core Rules
	# #6 recomputation happened (there is no compute logic to have run: the
	# caller — this test — only ever holds the value X it already had).
	var result: int = state.set_target(x, false)

	# THEN — 傳入的目標識別恰為 X(原值,不重新計算),有效性旗標轉回有效.
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"AC-63a: validity must flip back to true when the caller reuses X."
	).is_true()
	var after: CursorTarget = state.get_current_target()
	assert_int(after.surface).is_equal(_REGISTERED_SURFACE)
	assert_int(after.id).append_failure_message(
		"AC-63a: the reused target's id must be exactly X (5), not recomputed."
	).is_equal(5)

	# THEN (rendering proxy, see this AC group's header note) — not suppressed.
	assert_bool(state.is_current_target_valid()).is_true()
	# Device authority untouched (from_ui_action == false, hard rule).
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.UNINITIALIZED)


## AC-63b: the original target's underlying entity has failed (原目標已失效)
## — the caller must recompute per Core Rules #6, and the result must be
## observably DIFFERENT from AC-63a's reused X, or the two ACs would not be
## independently falsifiable (Story 009's own stated reason for splitting them).
func test_ac63b_original_target_invalidated_is_replaced_by_a_freshly_computed_target() -> void:
	# Arrange — identical starting shape to AC-63a: 甲 already ran, holding
	# the SAME X = (BOARD_TILE, 5), so the only variable that differs between
	# this test and the one above is whether X is still valid in the game
	# world — the fact this system cannot see and must not compute itself
	# (Core Rules #2/#7's own "不理解遊戲實體語意" stance).
	var fixture: Dictionary = _build_fixture()
	var state: CursorState = fixture["state"]
	var x: CursorTarget = _target(5)
	assert_int(state.set_target(x, false)).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_int(state.handoff_before_unload()).is_equal(CursorState.MarkResult.APPLIED)
	assert_bool(state.is_current_target_valid()).is_false()

	# WHEN: X's underlying entity no longer exists. THEN: the caller computes a
	# genuinely different initial target per Core Rules #6 — standing in here
	# for a real tactical-movement-system computation that does not exist in
	# this codebase yet (see this file's header note).
	var recomputed: CursorTarget = _target(9)  # deliberately != X's id (5)
	var result: int = state.set_target(recomputed, false)

	# THEN — the replacement is the freshly computed target, NOT the stale X.
	assert_int(result).is_equal(CursorState.SetTargetResult.APPLIED)
	assert_bool(state.is_current_target_valid()).append_failure_message(
		"AC-63b: validity must flip back to true for the recomputed target too."
	).is_true()
	var after: CursorTarget = state.get_current_target()
	assert_int(after.id).append_failure_message(
		"AC-63b: the replacement must be the freshly computed target (9), not "
		+ "the stale, now-invalid X (5) — that is AC-63a's case, not this one."
	).is_equal(9)
	assert_int(after.id).append_failure_message(
		"if this ever matches X's id, AC-63a and AC-63b would no longer be "
		+ "distinguishable from each other by their outcome alone."
	).is_not_equal(5)

	# THEN (rendering proxy) + device authority untouched, same as AC-63a.
	assert_bool(state.is_current_target_valid()).is_true()
	assert_int(state.get_device_authority()).is_equal(CursorTypes.Authority.UNINITIALIZED)
