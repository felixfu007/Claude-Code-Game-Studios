## Unit tests for Story U-006 (`production/epics/card-play-interface/
## story-u006-cursor-host-pause-exclusion.md`) — [CursorStateHost]'s
## [member Node.process_mode] pause-exclusion + diagnostic tick counter
## (ADR-0005 機制九, `design/ux/battle-menu.md` BM-9 / BM-10, AC-M14's stated
## precondition half — see that AC's own note that the "後半段" of AC-M14
## requires U-008's actual `SceneTree.paused = true` call site and is NOT
## claimed as covered here).
##
## [b]Why this is a real engine-behavior test, not the `Input.mouse_mode`
## no-op-under-headless trap[/b] (`.claude/docs/coding-standards.md`'s "What
## NOT to Automate"): that trap is specific to engine writes that reach an
## OS/window surface. [member SceneTree.paused] and [member Node.process_mode]
## are pure scheduling logic with no OS/window dependency. This was NOT taken
## on faith — confirmed directly with a throwaway headless probe before
## writing any assertion below:
##
## [codeblock]
## extends SceneTree
## class ProbeNode extends Node:
##     var tick_count: int = 0
##     func _process(_delta: float) -> void: tick_count += 1
## func _init() -> void:
##     var default_mode_node := ProbeNode.new()
##     var always_mode_node := ProbeNode.new()
##     always_mode_node.process_mode = Node.PROCESS_MODE_ALWAYS
##     root.add_child(default_mode_node)
##     root.add_child(always_mode_node)
##     await process_frame
##     await process_frame
##     paused = true
##     default_mode_node.tick_count = 0
##     always_mode_node.tick_count = 0
##     await process_frame
##     await process_frame
##     await process_frame
##     print("DURING PAUSE default=", default_mode_node.tick_count,
##           " always=", always_mode_node.tick_count)
##     quit()
## [/codeblock]
##
## Run via
## [code]godot --headless --path . -s <probe file>[/code]. Measured output
## (Godot 4.7.1.stable, this machine, 2026-09-16):
## [code]DURING PAUSE default=0 always=3[/code] — i.e. a default-process_mode
## Node's [method Node._process] is genuinely halted by
## [member SceneTree.paused] = [code]true[/code] under [code]--headless[/code]
## in this engine build, and [constant Node.PROCESS_MODE_ALWAYS] genuinely
## survives it. This is the load-bearing fact the tests below depend on.
##
## [b]Isolation — deliberately touches the real registered Autoload[/b],
## unlike [code]tests/integration/cursor/focus_pause_gating_test.gd[/code]'s
## stricter "never touch the real Autoload" convention (that convention lives
## in a different file/directory for a different reason: steering the
## injected mouse-position [Callable] to controlled coordinates, which needs a
## detached instance). This file follows
## [code]tests/unit/cursor/state_host_test.gd[/code]'s own precedent instead
## (same directory, same "Shared-Autoload write hazard" section) — that file
## already reads/mutates the real Autoload's [member _frame_events] directly,
## with defensive clear-before/after discipline. [member SceneTree.paused] is
## SceneTree-level, not Autoload-level, so there is no other way to prove the
## engine actually honors [member Node.process_mode] during a real pause: a
## node never added to a live tree (this file's OWN [method _fresh_host]
## below, used by the third test) receives NO automatic per-frame ticking at
## all, so a direct/manual [method Node._process] call proves nothing about
## whether the engine itself would have called it.
##
## Every test that touches [member SceneTree.paused] follows the same
## discipline as [code]state_host_test.gd[/code]'s buffer tests: a defensive
## precondition assertion that the shared flag was not already left dirty by
## an earlier test, and an unconditional restore to [code]false[/code] BEFORE
## the test's own final assertion (not after) — so the flag is back to
## [code]false[/code] regardless of whether that final assertion passes.
extends GdUnitTestSuite


## [code]CursorStateHost[/code] deliberately declares NO [code]class_name[/code]
## (see that file's own class doc comment) — this [preload] is the only way to
## construct a detached instance ([method GDScript.new]) for the third test
## below, matching the convention already established in
## [code]tests/unit/cursor/state_host_test.gd[/code] and
## [code]tests/integration/cursor/focus_pause_gating_test.gd[/code].
const _CursorStateHostScript: GDScript = preload("res://src/ui/cursor/cursor_state_host.gd")


## Control group for the pause-exclusion test below. Deliberately left at the
## engine default [member Node.process_mode]
## ([constant Node.PROCESS_MODE_INHERIT], with no ancestor overriding it once
## added directly under this suite's own node) — its [member tick_count] MUST
## NOT advance while [member SceneTree.paused] = [code]true[/code].
##
## [b]Why this exists[/b]: without a control group verified in the SAME
## engine-executed run, the main assertion ("the host's counter increases
## while paused") would also pass in a broken universe where
## [member SceneTree.paused] has no effect on [method Node._process] at all
## headless — that would prove nothing about [constant Node.PROCESS_MODE_ALWAYS]
## specifically, only that the counter keeps incrementing regardless of
## anything. This closes that gap by checking BOTH directions inside one
## executable test, rather than resting on the throwaway probe script quoted
## in this file's class doc comment (that probe is real evidence too, but it
## is a separate, non-repeated, manually-run script — this control group makes
## the same fact re-provable by anyone re-running this suite).
class _DefaultModeControlProbe extends Node:
	var tick_count: int = 0
	func _process(_delta: float) -> void:
		tick_count += 1


# ─── Structural: process_mode itself ─────────────────────────────────────────

func test_process_mode_is_set_to_always_or_equivalent() -> void:
	# Arrange / Act
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")

	# Assert
	assert_object(host).append_failure_message(
		"PRECONDITION: CursorStateHost Autoload not found at /root."
	).is_not_null()
	assert_int(host.process_mode).append_failure_message(
		"CursorStateHost.process_mode is not PROCESS_MODE_ALWAYS — "
		+ "SceneTree.paused = true would stop this Autoload's _process() "
		+ "entirely, silently disabling 機制九's _arbitration_suspended check "
		+ "along with everything else in it (BM-9 not closed)."
	).is_equal(Node.PROCESS_MODE_ALWAYS)


# ─── Engine-applied: _process() genuinely keeps running during a real pause ──

func test_process_continues_incrementing_diagnostic_counter_while_scene_tree_paused() -> void:
	# Arrange — this half of the coding-standards.md "split the target" rule
	# (assert the DECISION headless, assert the engine APPLIED it — both, not
	# either) needs the engine's own automatic per-frame ticking
	# (await get_tree().process_frame) on the REAL registered Autoload, not a
	# manually-invoked _process() call. See this file's class doc comment for
	# why the real Autoload is used here (Isolation section) and for the
	# probe that confirmed this is not the Input.mouse_mode no-op-headless trap.
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	assert_object(host).append_failure_message(
		"PRECONDITION: CursorStateHost Autoload not found at /root."
	).is_not_null()
	assert_bool(get_tree().paused).append_failure_message(
		"PRECONDITION: SceneTree already paused before this test ran — a "
		+ "prior test in this run leaked paused = true without restoring it. "
		+ "This test's own result would be meaningless on top of that leak."
	).is_false()

	# Control group — see _DefaultModeControlProbe's own doc comment for why
	# this is required, not decorative.
	var control: _DefaultModeControlProbe = _DefaultModeControlProbe.new()
	add_child(control)
	auto_free(control)
	assert_int(control.process_mode).append_failure_message(
		"PRECONDITION: control probe is not PROCESS_MODE_INHERIT — the "
		+ "control group itself is misconfigured, so it cannot prove anything."
	).is_equal(Node.PROCESS_MODE_INHERIT)

	await get_tree().process_frame
	var host_count_before: int = host.get(&"diagnostic_process_tick_count")
	var control_count_before: int = control.tick_count

	# Act
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var host_count_during: int = host.get(&"diagnostic_process_tick_count")
	var control_count_during: int = control.tick_count

	# Cleanup BEFORE the assertions — SceneTree.paused is global, process-wide
	# state shared with every other test file in the same run; it must not
	# leak regardless of whether the assertions below pass or fail.
	get_tree().paused = false
	await get_tree().process_frame

	# Assert — control group first: a PROCESS_MODE_INHERIT Node's _process()
	# must be genuinely halted by the pause. If this fails, the assertion
	# below is meaningless — get_tree().paused would not be gating anything
	# headless in this engine build, and the host's counter moving would say
	# nothing about PROCESS_MODE_ALWAYS specifically.
	assert_int(control_count_during).append_failure_message((
		"CONTROL GROUP FAILED: a PROCESS_MODE_INHERIT Node's tick counter " +
		"advanced during get_tree().paused = true (before=%d, during=%d). " +
		"If SceneTree.paused does not gate _process() headless in this " +
		"engine build, the next assertion proves nothing about " +
		"PROCESS_MODE_ALWAYS at all."
	) % [control_count_before, control_count_during]).is_equal(control_count_before)

	# Assert — the host itself: PROCESS_MODE_ALWAYS survives the same pause
	# the control group above just proved is real in this run.
	assert_int(host_count_during).append_failure_message((
		"diagnostic_process_tick_count did not increase while " +
		"get_tree().paused = true (before=%d, during=%d) — " +
		"CursorStateHost.process_mode is not correctly excluding it from " +
		"the pause. BM-9 is not actually closed: _process() would stop " +
		"running under a real pause menu, silently disabling 機制九's " +
		"suspend_arbitration()/resume_arbitration() flag check along with " +
		"everything else in this Autoload."
	) % [host_count_before, host_count_during]).is_greater(host_count_before)


# ─── Diagnostic field is observation-only, never a decision input ───────────

## Detached instance, never added to a live SceneTree — same convention as
## [code]tests/integration/cursor/focus_pause_gating_test.gd[/code]'s
## [code]_fresh_host()[/code] (duplicated rather than shared across files,
## same Isolation reasoning already documented there). This test needs no
## engine-driven ticking at all: it only asks a pure code-level question
## ("does writing to diagnostic_process_tick_count change
## _arbitration_suspended"), which plain direct method calls answer completely.
func _fresh_host() -> Node:
	var host: Node = _CursorStateHostScript.new()
	host._ready()
	auto_free(host)
	return host


func test_diagnostic_state_does_not_affect_arbitration_suspended_flag() -> void:
	# Arrange
	var host: Node = _fresh_host()
	var suspended_before: bool = host.get(&"_arbitration_suspended")
	var tick_before: int = host.get(&"diagnostic_process_tick_count")

	# Act — direct calls, same convention as state_host_test.gd's _process()
	# coverage: a detached instance never added to a live tree receives no
	# automatic engine ticking, so the override is invoked directly.
	for _i in range(5):
		host._process(0.0)

	# Assert — the counter moved (precondition: the test exercised something)
	# but the arbitration flag did not.
	assert_int(host.get(&"diagnostic_process_tick_count")).append_failure_message(
		"PRECONDITION: diagnostic_process_tick_count did not increase across "
		+ "5 direct _process() calls — this test would be vacuous."
	).is_equal(tick_before + 5)
	assert_bool(host.get(&"_arbitration_suspended")).append_failure_message(
		"diagnostic_process_tick_count incrementing changed "
		+ "_arbitration_suspended — control-manifest's diagnostic_* "
		+ "convention requires QA counters to be read-only observation, "
		+ "never a feedback input into any decision."
	).is_equal(suspended_before)
