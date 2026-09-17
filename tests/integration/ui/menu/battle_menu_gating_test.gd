## Integration tests for Story U-008 — 選單開關閘控 (suspend/resume pairing,
## [member SceneTree.paused], N5 rejection) on [code]src/ui/menu/battle_menu.gd[/code].
##
## Covers AC-M3 / AC-M8 / AC-M9 from
## [code]production/epics/card-play-interface/story-u008-battle-menu-gating.md[/code]
## (all three BLOCKING).
##
## ─── Why this file touches the REAL registered [CursorStateHost] Autoload ───
## Unlike [code]tests/integration/cursor/*_test.gd[/code]'s own convention of
## building a fresh detached [CursorStateHost]-script instance to avoid
## shared-global-state hazards, that option is not available here:
## [code]battle_menu.gd[/code]'s production code calls the bare
## [code]CursorStateHost[/code] Autoload identifier directly (a design
## mandate — `design/ux/battle-menu.md`'s "呼叫既有介面" requirement, not this
## file's choice, and this file does not inject a substitute). Proving
## [code]battle_menu.gd[/code] really calls through therefore means observing
## the one real singleton. [method before_test] / [method after_test] capture
## and restore every field this file touches
## ([code]_arbitration_suspended[/code], [code]_frame_events[/code],
## [CursorState]'s [code]_target[/code] / [code]_device_authority[/code], and
## [member SceneTree.paused] itself) so nothing here leaks into any other
## file sharing this one engine process — matching
## [code]tests/unit/ui/battle_screen_mouse_coords_test.gd[/code]'s established
## capture/restore-in-[method after_test] convention, extended to more fields
## because this file mutates more of them.
##
## [b]Reflection reads/writes[/b] ([code].get()[/code] / [code].set()[/code]
## on private fields) mirror the established convention
## [code]tests/integration/cursor/focus_pause_gating_test.gd[/code] and
## [code]tests/unit/cursor/cursor_layer_transform_test.gd[/code] already use
## against this exact Autoload.
##
## ─── Sensitivity-proof coverage (`.claude/rules/test-standards.md`,
## 2026-09-16 manager ruling) ───
## Every test below is annotated with which of the two accepted forms applies:
##   [常駐敏感度證明] = a companion [code]test_sensitivity_proof_*[/code] below
##                       proves the detection technique catches the injected
##                       defect.
##   [直接因果 — 不需另建突變]  = this test exercises a PRESENCE claim with a
##                       clear, freshly-introduced default (the flag/pause
##                       state starts at a known rest value and only changes
##                       if the production code under test actually runs) —
##                       deleting the line under test flips the assertion
##                       immediately, so a separate mutant subclass would be
##                       redundant, not a stronger proof. This category is
##                       distinct from `test-standards.md`'s "已知證明不了的
##                       五類" — those are cases sensitivity CANNOT be shown;
##                       this is a case where the causal chain is already
##                       direct enough that a mutant would prove the same
##                       thing a second way, not a new way. Reserved for
##                       ABSENCE claims (see 常駐敏感度證明 tests below), where
##                       "nothing happened" is otherwise ambiguous between
##                       "the guard exists" and "the guard was never reached".
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"


# ── Fixtures ────────────────────────────────────────────────────────────────


func _instantiate() -> BattleMenu:
	return auto_free(load(SCENE_PATH).instantiate())


func _host() -> Node:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	assert_object(host).append_failure_message(
		"CursorStateHost autoload not found at /root — is it still " +
		"registered in project.godot's [autoload] section?"
	).is_not_null()
	return host


func _real_ui_right_event() -> InputEventKey:
	# Same convention as battle_menu_layout_test.gd's _real_ui_key_event() /
	# focus_pause_gating_test.gd's _real_event(): pull the REAL InputMap-bound
	# event rather than hand-guessing a keycode.
	for event: InputEvent in InputMap.action_get_events(&"ui_right"):
		if event is InputEventKey:
			var dup: InputEventKey = (event as InputEventKey).duplicate()
			dup.pressed = true
			return dup
	fail("PRECONDITION: no real InputEventKey bound to ui_right in this engine's InputMap.")
	return null


var _original_arbitration_suspended: bool
var _original_device_authority: int
var _original_target: CursorTarget
var _original_tree_paused: bool


func before_test() -> void:
	var host: Node = _host()
	_original_arbitration_suspended = host.get(&"_arbitration_suspended")
	var state: CursorState = host.get(&"_state")
	_original_target = state.get_current_target()
	_original_device_authority = state.get_device_authority()
	_original_tree_paused = get_tree().paused


func after_test() -> void:
	# Restored in this specific order: paused=false FIRST, so that if any
	# assertion above already failed and returned early, the rest of this
	# suite (and every later test file in this engine process) is not left
	# frozen behind a paused SceneTree.
	get_tree().paused = _original_tree_paused
	var host: Node = _host()
	host.set(&"_arbitration_suspended", _original_arbitration_suspended)
	host.set(&"_frame_events", [])
	var state: CursorState = host.get(&"_state")
	state.set(&"_target", _original_target)
	state.set(&"_device_authority", _original_device_authority)
	# Unconditional, idempotent cleanup for the two AC-M9 tests' fake surface
	# registration — harmless UNREGISTERED_NOT_FOUND on every OTHER test in
	# this file, which never registers anything under this tag.
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)


# ═══════════════════════════════════════════════════════════════════════════
# AC-M3 (BLOCKING): open() suspends arbitration + pauses; close() resumes +
# unpauses; pairing holds across multiple cycles; post-close cursor movement
# genuinely resumes producing effects.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]:_arbitration_suspended / SceneTree.paused both
## start at a known rest value (false/false, restored by before_test's
## capture — this test additionally forces them at Arrange time so it never
## depends on some earlier test's leftover state) and only move if open()'s
## body actually runs the two calls under test.
func test_opening_menu_calls_suspend_arbitration_and_sets_scene_tree_paused() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	var host: Node = _host()
	host.set(&"_arbitration_suspended", false)
	get_tree().paused = false

	# Act
	var result: BattleMenu.OpenResult = instance.open()

	# Assert
	assert_int(result).is_equal(BattleMenu.OpenResult.OPENED)
	assert_bool(host.get(&"_arbitration_suspended")).append_failure_message(
		"open() did not call CursorStateHost.suspend_arbitration()."
	).is_true()
	assert_bool(get_tree().paused).append_failure_message(
		"open() did not set SceneTree.paused = true."
	).is_true()

	# Cleanup within the test itself, not only after_test(): leaving the REAL
	# SceneTree paused for the remainder of this test function would affect
	# anything else this same test does before after_test() ever runs.
	instance.close()
	get_tree().paused = false


## [直接因果 — 不需另建突變]: same reasoning as above, mirrored.
func test_closing_menu_calls_resume_arbitration_and_unsets_scene_tree_paused() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	var host: Node = _host()
	assert_int(instance.open()).append_failure_message(
		"PRECONDITION: open() must succeed before this test can exercise close()."
	).is_equal(BattleMenu.OpenResult.OPENED)
	assert_bool(host.get(&"_arbitration_suspended")).is_true()
	assert_bool(get_tree().paused).is_true()

	# Act
	instance.close()

	# Assert
	assert_bool(host.get(&"_arbitration_suspended")).append_failure_message(
		"close() did not call CursorStateHost.resume_arbitration()."
	).is_false()
	assert_bool(get_tree().paused).append_failure_message(
		"close() did not set SceneTree.paused = false."
	).is_false()


## [常駐敏感度證明] — this is an ABSENCE claim across a loop ("resume is
## called EVERY time, never skipped"), so a companion mutant proves the
## detection actually catches a skipped resume — see
## [code]test_sensitivity_proof_pairing_detection_catches_close_that_never_resumes[/code]
## below.
func test_suspend_and_resume_are_always_called_in_pairs_across_multiple_open_close_cycles() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	var host: Node = _host()

	# Act / Assert — three full cycles.
	for cycle_index: int in range(3):
		assert_int(instance.open()).append_failure_message(
			"cycle %d: open() unexpectedly rejected." % cycle_index
		).is_equal(BattleMenu.OpenResult.OPENED)
		assert_bool(host.get(&"_arbitration_suspended")).append_failure_message(
			"cycle %d: open() did not suspend arbitration." % cycle_index
		).is_true()
		assert_bool(get_tree().paused).append_failure_message(
			"cycle %d: open() did not pause the tree." % cycle_index
		).is_true()

		instance.close()
		assert_bool(host.get(&"_arbitration_suspended")).append_failure_message(
			("cycle %d: close() did not resume arbitration — a menu that never " +
				"un-suspends is exactly AC-M3's silent failure mode (highlight " +
				"stays frozen at its last value, no error).") % cycle_index
		).is_false()
		assert_bool(get_tree().paused).append_failure_message(
			"cycle %d: close() did not unpause the tree." % cycle_index
		).is_false()


## Mutant for the sensitivity proof below: close() still hides the panel and
## unpauses, but deliberately skips resume_arbitration() — the exact
## regression `battle-menu.md` names ("只暫停不恢復...而那不會報錯").
class _MutantCloseNeverResumes extends BattleMenu:
	func close() -> void:
		visible = false
		get_tree().paused = false
		# Deliberately DOES NOT call CursorStateHost.resume_arbitration().


func test_sensitivity_proof_pairing_detection_catches_close_that_never_resumes() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantCloseNeverResumes)
	auto_free(mutant)
	add_child(mutant)
	var host: Node = _host()

	assert_int(mutant.open()).is_equal(BattleMenu.OpenResult.OPENED)
	mutant.close()

	assert_bool(host.get(&"_arbitration_suspended")).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant's close() deliberately skips " +
		"resume_arbitration(), so _arbitration_suspended must still read " +
		"TRUE here — if it reads FALSE, the pairing test above cannot tell a " +
		"correct close() from a broken one."
	).is_true()

	# Manual cleanup since the mutant's own close() will not do it.
	host.set(&"_arbitration_suspended", false)


## AC-M3's second half: "關閉後移動游標,高亮確實更新". This project's own
## cursor system already proves the PRESENTATION half unconditionally
## redraws from [CursorState] every frame regardless of suspension (see
## [code]focus_pause_gating_test.gd[/code]'s own AC-30 comment,
## "SelfDrawnReclaimCursor._process() ... re-derive their output from _state
## UNCONDITIONALLY every frame") — what THIS test proves is the half
## [code]battle_menu.gd[/code] is actually responsible for: that
## [method BattleMenu.close] genuinely un-suspends the REAL arbitration
## pipeline so a subsequent real input event produces an observable change,
## not merely that a private flag reads false (that half is already covered
## by the two tests above).
##
## Uses DEVICE-AUTHORITY arbitration ([method CursorState.arbitrate_device_authority])
## rather than navigation-application
## ([method CursorState.apply_buffered_navigation]) specifically because the
## latter needs a [CursorSurface] registered under the target's tag —
## mutating the REAL, shared [CursorSurfaceRegistry] from this file would
## risk exactly the cross-test pollution
## [code]tests/integration/cursor/write_read_interface_test.gd[/code]'s own
## Isolation note warns against. Device-authority transfer needs no
## registered surface at all.
##
## [直接因果 — 不需另建突變]: the "while suspended, no change" half and the
## "after close, changes" half are the SAME assertion technique applied
## twice with the suspend flag flipped — the test already demonstrates it
## can tell the two states apart, without needing a third mutant instance.
func test_moving_cursor_after_close_updates_highlight() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	var host: Node = _host()
	var state: CursorState = host.get(&"_state")
	var nav_event: InputEventKey = _real_ui_right_event()

	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	var authority_before: int = state.get_device_authority()

	# Act (i) — WHILE the menu is open (suspended): feed the real event
	# through the REAL Autoload's real _input()/_process()/
	# flush_buffered_navigation(), called as plain direct method calls
	# (matching tests/integration/cursor/focus_pause_gating_test.gd's own
	# established convention for driving this exact Autoload deterministically).
	host._input(nav_event)
	host._process(0.0)
	host.flush_buffered_navigation()

	# Assert (i)
	assert_int(state.get_device_authority()).append_failure_message(
		"device authority changed while the menu was open — arbitration " +
		"should still be suspended at this point."
	).is_equal(authority_before)

	# Act (ii)
	instance.close()
	host._input(nav_event)
	host._process(0.0)
	host.flush_buffered_navigation()

	# Assert (ii) — the identical event now DOES move device authority,
	# proving the pipeline is genuinely un-suspended, not merely that a flag
	# reads false.
	assert_int(state.get_device_authority()).append_failure_message(
		"after close(), a real ui_right event did not transfer device " +
		"authority to KEYBOARD_GAMEPAD — the arbitration pipeline is still " +
		"effectively suspended even though close() was called."
	).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)


# ═══════════════════════════════════════════════════════════════════════════
# AC-M8 (BLOCKING): authoritative-write-in-progress rejects open() observably,
# distinguishably from the (not-yet-real) forced-discard cause.
#
# ⚠️ Limitation (EPIC.md's registered Limitation #1, this story's own Out of
# Scope section): BattleState.authoritative_write_in_progress has ZERO
# implementation anywhere in src/ as of this writing — these tests use a test
# double Callable to simulate the flag being true. This proves "the gate is
# wired and observably rejects", not "the real flag can become true" — a true
# positive is not constructible today. See battle_menu.gd's own doc comment
# on authoritative_write_in_progress_check for the verification this claim
# rests on.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: the injected Callable is the ONLY thing that
## changed between "would open" and "must reject" — deleting open()'s
## rejection check flips this test's result from REJECTED_AUTHORITATIVE_WRITE
## to OPENED immediately, and the earlier tests in this file already prove
## the OPENED path (visible/paused/suspended) works when NOT rejected, so
## this test does not need to re-prove that half.
func test_menu_key_rejected_while_authoritative_write_flag_true() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	monitor_signals(instance)
	var host: Node = _host()
	# 🔴 Establish a known CLOSED baseline first. Freshly instantiated,
	# BattleMenu inherits U-007's _ready() default (Control.visible starts
	# true; this story deliberately did not add a "closed by default"
	# _ready() change, to avoid risking U-007's own focus-grab tests — see
	# battle_menu.gd's open()/close() doc comments). Without this call,
	# is_open() reads true from the very start (never having been opened),
	# and the "must not have opened" assertion below is vacuously wrong
	# about what it is even comparing against. Found by actually running
	# this test, not assumed correct — it was red until this line was added.
	instance.close()
	instance.authoritative_write_in_progress_check = func() -> bool: return true

	# Act
	var result: BattleMenu.OpenResult = instance.open()

	# Assert
	assert_int(result).append_failure_message(
		"open() must reject while the authoritative-write check reports true."
	).is_equal(BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE)
	assert_bool(instance.is_open()).append_failure_message(
		"the menu must not have become visible/open on a rejected open()."
	).is_false()
	assert_bool(get_tree().paused).append_failure_message(
		"a rejected open() must not pause the tree."
	).is_false()
	assert_bool(host.get(&"_arbitration_suspended")).append_failure_message(
		"a rejected open() must not suspend cursor arbitration."
	).is_false()
	await assert_signal(instance).is_emitted(
		"open_rejected",
		BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE,
		BattleMenu.REJECTION_MESSAGE_AUTHORITATIVE_WRITE
	)


## Implementation Note #5's "預留兩種外觀可區分的空間" — U-015 has not wired a
## real forced-discard check yet, so this proves the MECHANISM (two
## independent injection points feeding two distinguishable results/messages),
## not a real forced-discard scenario. See battle_menu.gd's
## [member forced_discard_in_progress_check] doc comment and this story's
## report.
##
## [直接因果 — 不需另建突變]: the two constants compared here are read
## directly from production code (not re-derived), and the two open() calls
## are driven by two independently-true injected Callables — there is no
## intermediate step a mutant could target that these direct assertions do
## not already cover.
func test_rejection_appearance_differs_between_authoritative_write_and_forced_discard() -> void:
	# Arrange
	var authoritative_instance: BattleMenu = _instantiate()
	add_child(authoritative_instance)
	monitor_signals(authoritative_instance)
	authoritative_instance.authoritative_write_in_progress_check = func() -> bool: return true

	var discard_instance: BattleMenu = _instantiate()
	add_child(discard_instance)
	monitor_signals(discard_instance)
	discard_instance.forced_discard_in_progress_check = func() -> bool: return true

	# Act
	var authoritative_result: BattleMenu.OpenResult = authoritative_instance.open()
	var discard_result: BattleMenu.OpenResult = discard_instance.open()

	# Assert — distinguishable by enum value...
	assert_int(authoritative_result).is_equal(BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE)
	assert_int(discard_result).is_equal(BattleMenu.OpenResult.REJECTED_FORCED_DISCARD)
	assert_int(authoritative_result).append_failure_message(
		"the two rejection causes must resolve to a DIFFERENT enum value from each other."
	).is_not_equal(discard_result)

	# ...and by message text (`design/ux/battle-menu.md` N5: "兩種原因的拒絕
	# 回饋外觀須可區分").
	assert_str(BattleMenu.REJECTION_MESSAGE_AUTHORITATIVE_WRITE).append_failure_message(
		"the two rejection causes must have DIFFERENT message text — a shared " +
		"string would violate N5's distinguishability requirement."
	).is_not_equal(BattleMenu.REJECTION_MESSAGE_FORCED_DISCARD)

	await assert_signal(authoritative_instance).is_emitted(
		"open_rejected",
		BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE,
		BattleMenu.REJECTION_MESSAGE_AUTHORITATIVE_WRITE
	)
	await assert_signal(discard_instance).is_emitted(
		"open_rejected",
		BattleMenu.OpenResult.REJECTED_FORCED_DISCARD,
		BattleMenu.REJECTION_MESSAGE_FORCED_DISCARD
	)


# ═══════════════════════════════════════════════════════════════════════════
# AC-M9 (BLOCKING): board selection preserved across a full open()/close()
# cycle.
# ═══════════════════════════════════════════════════════════════════════════


## Minimal registrable stand-in so [method CursorState.set_target] validates
## (`_validate_target_writable` requires SOME [Node] registered under the
## target's [enum CursorTypes.SurfaceType] tag — [CursorSurfaceRegistry.register]'s
## own doc comment). No [code]cursor_navigate()[/code] needed: this file never
## exercises navigation-application, only device-authority-free direct
## [method CursorState.set_target] writes.
class _FakeBoardSurface extends Node:
	pass


## Registers [_FakeBoardSurface] under [constant CursorTypes.SurfaceType.BOARD_TILE]
## on the REAL Autoload's REAL [CursorSurfaceRegistry] — found necessary by
## actually running [method CursorState.set_target] against the real registry
## first (it returned [constant CursorState.SetTargetResult.SURFACE_NOT_REGISTERED],
## not [constant CursorState.SetTargetResult.APPLIED], because nothing in
## [code]src/[/code] registers this tag yet — see [code]cursor_state.gd[/code]'s
## own "🔴 as of this story, NOTHING in src/ calls
## CursorSurfaceRegistry.register()" note). [method after_test] always calls
## [method CursorSurfaceRegistry.unregister] on this same tag unconditionally
## (idempotent — a harmless [constant CursorSurfaceRegistry.RegisterResult.UNREGISTERED_NOT_FOUND]
## if nothing is left to remove), so this file never leaves a surface
## registered on the shared singleton for any other test file to trip over.
func _register_fake_board_surface(host: Node) -> Node:
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	var surface: Node = _FakeBoardSurface.new()
	add_child(surface)
	auto_free(surface)
	var result: CursorSurfaceRegistry.RegisterResult = registry.register(
		CursorTypes.SurfaceType.BOARD_TILE, surface
	)
	assert_int(result).append_failure_message(
		"PRECONDITION: could not register the fake BOARD_TILE surface " +
		"(result=%d) — a leftover registration from a previous test?" % result
	).is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	return surface


## [常駐敏感度證明] — this is an ABSENCE claim ("close() never touches board
## selection"), proven via a companion mutant below.
func test_board_selection_preserved_across_menu_open_and_close() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	var host: Node = _host()
	var state: CursorState = host.get(&"_state")
	_register_fake_board_surface(host)
	var target: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 42)
	assert_int(state.set_target(target)).append_failure_message(
		"PRECONDITION: could not set an initial board selection target."
	).is_equal(CursorState.SetTargetResult.APPLIED)

	# Act
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	instance.close()

	# Assert
	var after: CursorTarget = state.get_current_target()
	assert_bool(after.equals(target)).append_failure_message(
		"the board's current selection target changed across an open()/" +
		"close() cycle — this menu must never touch board/gameplay state (AC-M9)."
	).is_true()
	assert_bool(after.is_valid).append_failure_message(
		"the board's current selection validity changed across an open()/close() cycle."
	).is_true()


## Mutant for the sensitivity proof below: close() does everything the real
## one does, PLUS invalidates the board's current selection target — the
## exact regression AC-M9 exists to forbid.
class _MutantCloseAlsoInvalidatesBoardSelection extends BattleMenu:
	func close() -> void:
		super.close()
		var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
		var state: CursorState = host.get(&"_state")
		state.mark_pending_reresolve(state.get_current_target())


func test_sensitivity_proof_board_selection_detection_catches_a_close_that_touches_it() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantCloseAlsoInvalidatesBoardSelection)
	auto_free(mutant)
	add_child(mutant)
	var host: Node = _host()
	var state: CursorState = host.get(&"_state")
	_register_fake_board_surface(host)
	var target: CursorTarget = CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, 7)
	assert_int(state.set_target(target)).append_failure_message(
		"PRECONDITION: could not set an initial board selection target."
	).is_equal(CursorState.SetTargetResult.APPLIED)

	assert_int(mutant.open()).is_equal(BattleMenu.OpenResult.OPENED)
	mutant.close()

	assert_bool(state.get_current_target().is_valid).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant's close() deliberately invalidates " +
		"the board's current target, so is_valid must read FALSE here — if " +
		"it reads TRUE, the real test's detection technique cannot tell a " +
		"close() that preserves board selection from one that does not."
	).is_false()
