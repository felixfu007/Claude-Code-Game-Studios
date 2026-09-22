## Integration tests for Story U-010 — M4 (離開確認), the leave-game
## confirmation panel that overlays M1 on [code]src/ui/menu/battle_menu.gd[/code]
## (`design/ux/battle-menu.md` State N4).
##
## Covers AC-M6 (default focus on Cancel + double-confirm does not quit,
## BLOCKING) and AC-M7 (body text states the consequence, ADVISORY), plus the
## Test Evidence section's own named supporting claims (M4 overlays M1
## without hiding it, focus containment, the irreversible-action safety
## mechanism).
##
## Placed under [code]tests/integration/ui/menu/[/code] to match this
## project's EXISTING directory for [code]battle_menu.gd[/code] integration
## tests ([code]battle_menu_gating_test.gd[/code] / [code]battle_menu_end_turn_wiring_test.gd[/code]
## already live here) — the story's own Test Evidence section names a flat
## [code]tests/integration/ui/battle_menu_leave_confirmation_test.gd[/code]
## path with no [code]menu/[/code] subdirectory, which does not match
## precedent. Flagged as a dispatch/story inaccuracy rather than followed
## silently (same correction U-009's own file header already made for its
## own path).
##
## ─── 🔴 Headless engine limitation (inherited unchanged from U-009's own
## probe, not re-measured here) ─────────────────────────────────────────────
## [Button.pressed] cannot be made to fire from ANY simulated activation in
## this engine's [code]--headless[/code] mode (see
## [code]prototypes/u009-menu-pause-input-probe-2026-09-22/[/code]). Every
## test below that needs "selecting this row/button does X" fires the real
## [signal BaseButton.pressed] DIRECTLY ([code].pressed.emit()[/code]) rather
## than via a simulated key event — proving the WIRING (decision layer), never
## that a real gamepad/keyboard press actually reaches that signal in
## production (applied layer). AC-M6's own "連按兩次確認" claim is therefore
## proven at the decision layer ONLY: this file proves that whichever
## button/row holds focus at the moment of the second press is Cancel, not
## Leave (via direct signal emission), and registers the real "press the same
## physical key twice" scenario as needing manual/windowed verification — see
## this story's report for the explicit three-way split.
##
## 🔴 [b]battle_cancel is DIFFERENT and IS fully provable headless[/b] —
## unlike [code]ui_accept[/code] activating a focused [Button], `battle_cancel`
## is a real registered [InputMap] action (`project.godot`: Esc / gamepad B)
## reaching [method BattleMenu._unhandled_input] rather than native [Button]
## activation, so the tests exercising it below use a REAL simulated
## [InputEventKey] via [method Viewport.push_input], not a direct signal
## emission. Do not let "half of this story can't be proven headless" read as
## "none of it can" — the coordinator flagged this distinction explicitly.
##
## ─── 🔴 Irreversible-action safety (read before editing this file) ────────
## [member BattleMenu.quit_callable]'s UNSET default calls the REAL
## [method SceneTree.quit] — the opposite of this file's other two injectable
## Callables. EVERY test below that presses [member _leave_button] MUST
## inject a stub into [code]instance.quit_callable[/code] FIRST, or it will
## kill this engine process mid test-run. See [method
## BattleMenu.quit_callable]'s own doc comment and
## [code]test_uninjected_quit_callable_would_call_real_quit_by_design[/code]
## below for how the "falls back to real quit" claim is proven WITHOUT ever
## invoking it.
##
## ─── Sensitivity-proof coverage (`.claude/rules/test-standards.md`,
## 2026-09-16 manager ruling) ───────────────────────────────────────────────
## Each test below is annotated with which applies:
##   [常駐敏感度證明] = a companion [code]test_sensitivity_proof_*[/code] below
##                       proves the detection technique catches the injected
##                       defect (mutant subclass, [code]set_script()[/code]
##                       BEFORE [method Node.add_child] — matching this
##                       project's established Case A convention, verified
##                       safe in [code]prototypes/u007-focus-navigation-probe-2026-09-17/probe_set_script_timing.gd[/code]).
##   [直接因果 — 不需另建突變] = the causal chain from cause to assertion is
##                       already a single, un-intermediated step — a mutant
##                       would prove the same fact a second way, not a new one.
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"

# Same resolution sets `tests/unit/ui/menu/battle_menu_layout_test.gd` (U-007)
# already established for this scene — duplicated here rather than shared
# (this project's existing convention: GDScript test suites do not share
# private helpers/constants across files).
const RESOLUTIONS_WITH_MIN_WINDOW: Dictionary = {
	"960x540": Vector2i(960, 540),
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

const RESOLUTIONS: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}


# ── Fixtures ────────────────────────────────────────────────────────────────


func _instantiate() -> BattleMenu:
	return auto_free(load(SCENE_PATH).instantiate())


func _real_key_event(action: StringName) -> InputEventKey:
	# Same convention as battle_menu_layout_test.gd's / battle_menu_gating_test.gd's
	# own helpers of the same shape: pull the REAL InputMap-bound event rather
	# than hand-guessing a keycode.
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var dup: InputEventKey = (event as InputEventKey).duplicate()
			dup.pressed = true
			return dup
	fail("PRECONDITION: no real InputEventKey bound to %s in this engine's InputMap." % action)
	return null


func _return_row(instance: Node) -> Button:
	return instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")


func _quit_row(instance: Node) -> Button:
	return instance.get_node("Panel/ContentMargin/Rows/QuitRow")


func _m1_panel(instance: Node) -> Control:
	return instance.get_node("Panel")


func _cancel_button(instance: Node) -> Button:
	return instance.get_node("LeaveConfirm/Panel/ContentMargin/Content/Buttons/CancelButton")


func _leave_button(instance: Node) -> Button:
	return instance.get_node("LeaveConfirm/Panel/ContentMargin/Content/Buttons/LeaveButton")


func after_test() -> void:
	# Defensive, matching battle_menu_gating_test.gd's own established rigor:
	# guarantee no test in this file can leave the REAL shared SceneTree /
	# CursorStateHost suspended for whatever runs next, even if an assertion
	# above failed mid-test before this file's own close()-cleanup line ran
	# (GdUnit4 assertions do not abort the test function on failure).
	get_tree().paused = false
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	if host != null:
		host.set(&"_arbitration_suspended", false)


# ═══════════════════════════════════════════════════════════════════════════
# AC-M6 (BLOCKING) — 預設焦點在「取消」;連按兩次確認遊戲未關.
# ═══════════════════════════════════════════════════════════════════════════


## AC-M6 first half. [直接因果 — 不需另建突變]: [method
## BattleMenu.open_leave_confirm]'s [code]_leave_cancel_button.grab_focus()[/code]
## call is a single, unintermediated statement.
func test_selecting_quit_row_opens_leave_confirm_with_default_focus_on_cancel() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	assert_int(instance.open()).append_failure_message(
		"PRECONDITION: open() must succeed for this test to exercise anything."
	).is_equal(BattleMenu.OpenResult.OPENED)

	# Act — "選定「離開遊戲」" (headless cannot simulate a real ui_accept
	# activating a focused Button — see this file's header — so this fires
	# QuitRow's real pressed signal directly, proving the WIRING, not the
	# physical keypress).
	_quit_row(instance).pressed.emit()

	# Assert
	assert_bool(instance.is_leave_confirm_open()).append_failure_message(
		"selecting 離開遊戲 must open M4."
	).is_true()
	assert_bool(_cancel_button(instance).has_focus()).append_failure_message(
		"AC-M6: M4 must default focus to 取消, not 離開 or whatever was " +
		"focused last time."
	).is_true()

	# Cleanup
	instance.close()


## AC-M6's core claim — 自「離開遊戲」列連按兩次確認 → 遊戲未關閉.
##
## 🔴 [b]Decision-layer only[/b] — see this file's header on the headless
## Button.pressed limitation. "連按兩次同一個實體按鍵" cannot be simulated
## headless at all; what CAN be proven headless is the decision this AC
## depends on: the control that receives the SECOND activation (whatever is
## focused right after the first) is Cancel, not Leave — proven by firing
## each row/button's real [signal BaseButton.pressed] directly. The physical
## "press the same key twice" scenario needs manual/windowed verification —
## registered honestly, not silently treated as proven.
func test_double_confirm_from_leave_game_row_does_not_quit_decision_layer() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	# 🔴 Array[int] capture cell per this project's documented lambda
	# capture-by-value trap (see tests/unit/cursor/shared_types_test.gd:170-174
	# / tests/unit/ui/device_authority_test.gd): a bare int local would make
	# the closure mutate its OWN copy, leaving this outer variable at 0
	# forever regardless of whether quit_callable was ever invoked — a
	# false-negative that would make this test pass even on a broken
	# implementation. Found by actually running this test, not assumed —
	# it read 0 even after real invocations before this fix.
	var quit_calls: Array[int] = [0]
	instance.quit_callable = func() -> void: quit_calls[0] += 1
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)

	# Act (i) — "第一次確認": select 離開遊戲.
	_quit_row(instance).pressed.emit()

	# Assert (i) — M4 opened, default focus on Cancel, nothing quit yet.
	assert_bool(instance.is_leave_confirm_open()).is_true()
	assert_bool(_cancel_button(instance).has_focus()).append_failure_message(
		"PRECONDITION: default focus must be Cancel for the second press " +
		"below to mean anything."
	).is_true()
	assert_int(quit_calls[0]).is_equal(0)

	# Act (ii) — "第二次確認" on the SAME physical key: since default focus is
	# Cancel, native activation would trigger CANCEL's pressed signal, not
	# Leave's — proven by firing Cancel's real signal directly (same headless
	# limitation as above).
	_cancel_button(instance).pressed.emit()

	# Assert (ii)
	assert_int(quit_calls[0]).append_failure_message(
		"AC-M6: pressing confirm twice starting from the 離開遊戲 row must " +
		"NOT quit — the second press activates whichever control currently " +
		"holds focus, and that must be Cancel, not Leave."
	).is_equal(0)
	assert_bool(instance.is_leave_confirm_open()).append_failure_message(
		"the second press (Cancel) must have closed M4 back to M1."
	).is_false()

	# Cleanup
	instance.close()


# ═══════════════════════════════════════════════════════════════════════════
# Implementation Note #7 — 關閉 M4 回到 M1:選定「取消」,或按 battle_cancel.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: [method BattleMenu._unhandled_input]'s
## [code]if event.is_action_pressed(&"battle_cancel")[/code] branch is a
## single, unintermediated call to [method BattleMenu.close_leave_confirm].
func test_battle_cancel_closes_m4_back_to_m1() -> void:
	# Arrange
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	instance.open_leave_confirm()
	assert_bool(instance.is_leave_confirm_open()).append_failure_message(
		"PRECONDITION: M4 must be open before battle_cancel can close it."
	).is_true()

	# Act — real simulated battle_cancel (Esc), routed through the engine's
	# own input dispatch via push_input(), not a direct method call.
	instance.get_viewport().push_input(_real_key_event(&"battle_cancel"))
	await get_tree().process_frame

	# Assert
	assert_bool(instance.is_leave_confirm_open()).append_failure_message(
		"battle_cancel must close M4 back to M1, not leave it open."
	).is_false()
	assert_bool(instance.is_open()).append_failure_message(
		"battle_cancel must NOT close the whole menu — only M4 " +
		"(Implementation Note #7: '兩者皆回到 M1,不關閉整個選單')."
	).is_true()

	# Cleanup
	instance.close()


## Complements the test above: proves [method BattleMenu._unhandled_input] is
## scoped to M4 alone, not a general-purpose menu-close path this story
## quietly introduced. [直接因果 — 不需另建突變]: the method's own early
## [code]if not _leave_confirm.visible: return[/code] guard is a single line.
func test_battle_cancel_does_nothing_while_m4_is_closed() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	assert_bool(instance.is_leave_confirm_open()).append_failure_message(
		"PRECONDITION: M4 must start closed."
	).is_false()

	instance.get_viewport().push_input(_real_key_event(&"battle_cancel"))
	await get_tree().process_frame

	assert_bool(instance.is_open()).append_failure_message(
		"battle_cancel must not close the whole menu while M4 was never open " +
		"— this method's scope is M4 only, not a general menu-close path."
	).is_true()

	instance.close()


# ═══════════════════════════════════════════════════════════════════════════
# Navigation Position / Implementation Note #2 — M4 疊在 M1 之上,M1 不消失.
# ═══════════════════════════════════════════════════════════════════════════


## [常駐敏感度證明] — ABSENCE claim ("opening M4 never touches M1's own
## visibility/rows"), companion mutant below.
func test_m4_overlays_m1_without_hiding_it() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)

	instance.open_leave_confirm()

	assert_bool(instance.is_leave_confirm_open()).is_true()
	assert_bool(_m1_panel(instance).visible).append_failure_message(
		"M1's own Panel must remain visible while M4 is open — M4 overlays " +
		"M1, it does not replace it."
	).is_true()
	assert_bool(_return_row(instance).visible).append_failure_message(
		"M1's rows must remain visible (structurally intact) while M4 is open."
	).is_true()
	assert_bool(_quit_row(instance).visible).is_true()
	assert_bool((instance.get_node("Mask") as Control).visible).append_failure_message(
		"M0's own mask must remain visible while M4 is open."
	).is_true()

	instance.close()


## Mutant for the sensitivity proof below: [method BattleMenu.open_leave_confirm]
## does everything the real one does, PLUS hides M1's Panel — the exact
## regression Implementation Note #2 exists to forbid.
class _MutantOpenLeaveConfirmAlsoHidesM1 extends BattleMenu:
	func open_leave_confirm() -> void:
		super.open_leave_confirm()
		get_node("Panel").visible = false


func test_sensitivity_proof_m1_preservation_detection_catches_a_leave_confirm_that_hides_m1() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantOpenLeaveConfirmAlsoHidesM1)
	auto_free(mutant)
	add_child(mutant)
	assert_int(mutant.open()).is_equal(BattleMenu.OpenResult.OPENED)

	mutant.open_leave_confirm()

	assert_bool((mutant.get_node("Panel") as Control).visible).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant's open_leave_confirm() deliberately " +
		"hides M1's Panel, so visible must read FALSE here — if it reads TRUE, " +
		"the real test's 'M1 stays visible' assertion cannot tell a correct " +
		"overlay from one that silently hides M1 underneath."
	).is_false()

	mutant.close()


# ═══════════════════════════════════════════════════════════════════════════
# Keyboard containment — M4's two buttons never lose focus to an M1 row.
# ═══════════════════════════════════════════════════════════════════════════


## Decision layer: [直接因果 — 不需另建突變] — an unset/default [NodePath]
## reads back as an empty string, never ".", so asserting the exact
## self-loop/cross-loop path values directly demonstrates the [method
## BattleMenu._ready] wiring is present; deleting any one of its four M4
## focus_neighbor assignment lines flips this half of the assertion
## immediately.
## Applied layer (real simulated input): [常駐敏感度證明] — this IS an
## absence claim ("directional input never escapes M4"), so a companion
## mutant proves the detection technique actually catches a broken direction
## — see [_MutantLeavesOneM4NeighborDirectionUnwired] /
## [code]test_sensitivity_proof_m4_containment_detection_catches_an_unwired_direction[/code]
## below.
func test_navigating_within_m4_does_not_escape_to_m1_rows() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)

	var cancel_btn: Button = _cancel_button(instance)
	var leave_btn: Button = _leave_button(instance)

	# Decision layer — set in _ready(), asserted directly here.
	assert_str(String(cancel_btn.focus_neighbor_top)).is_equal(".")
	assert_str(String(cancel_btn.focus_neighbor_bottom)).is_equal(".")
	assert_str(String(cancel_btn.focus_neighbor_left)).is_equal(String(cancel_btn.get_path_to(leave_btn)))
	assert_str(String(cancel_btn.focus_neighbor_right)).is_equal(String(cancel_btn.get_path_to(leave_btn)))
	assert_str(String(leave_btn.focus_neighbor_top)).is_equal(".")
	assert_str(String(leave_btn.focus_neighbor_bottom)).is_equal(".")
	assert_str(String(leave_btn.focus_neighbor_left)).is_equal(String(leave_btn.get_path_to(cancel_btn)))
	assert_str(String(leave_btn.focus_neighbor_right)).is_equal(String(leave_btn.get_path_to(cancel_btn)))

	# Applied layer — real simulated input, menu genuinely open.
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	instance.open_leave_confirm()
	assert_bool(cancel_btn.has_focus()).append_failure_message(
		"PRECONDITION: default focus must be Cancel."
	).is_true()

	for action: StringName in [&"ui_up", &"ui_down"]:
		instance.get_viewport().push_input(_real_key_event(action))
		await get_tree().process_frame
		assert_bool(cancel_btn.has_focus()).append_failure_message(
			"pressing an up/down action while Cancel is focused inside M4 " +
			"must not move focus anywhere (self-loop wiring)."
		).is_true()

	instance.get_viewport().push_input(_real_key_event(&"ui_right"))
	await get_tree().process_frame
	assert_bool(leave_btn.has_focus()).append_failure_message(
		"pressing ui_right from Cancel must move focus to Leave."
	).is_true()

	# 🔴 Corrected during this fix (not the original assumption): this file's
	# own [method BattleMenu._ready] wires BOTH horizontal directions on BOTH
	# M4 buttons to point to "the other one" (see that method's own comment,
	# "Cancel <-> Leave in both left/right directions") — a deliberate 2-item
	# ping-pong, not a self-loop on the rightmost item. The line this replaces
	# asserted the opposite ("must stay on Leave") and was simply wrong about
	# what this file's own production code does; it was never a containment
	# defect (focus never left M4 either way — see the broadened check below,
	# which covers all three M1 rows, not just QuitRow).
	instance.get_viewport().push_input(_real_key_event(&"ui_right"))
	await get_tree().process_frame
	assert_bool(cancel_btn.has_focus()).append_failure_message(
		"pressing ui_right again from Leave must ping-pong back to Cancel " +
		"(both buttons' focus_neighbor_left/right point at the other one)."
	).is_true()
	for m1_row: Button in [_return_row(instance), _quit_row(instance), instance.get_node(
		"Panel/ContentMargin/Rows/EndPhaseRow"
	)]:
		assert_bool(m1_row.has_focus()).append_failure_message(
			"focus must never land on ANY M1 row (%s) while M4 is open." % m1_row.name
		).is_false()

	instance.close()


## Mutant for the sensitivity proof below: real [method BattleMenu._ready]
## runs first (so every OTHER wiring — M1's rows, signal connections, the
## OTHER three M4 neighbor directions — is untouched), then this mutant
## deliberately clears [member _leave_quit_button]'s
## [member Control.focus_neighbor_right] back to an empty [NodePath] —
## simulating "this one direction was never explicitly wired" and letting
## Godot's automatic geometric focus-neighbor search take over for that one
## direction. This is the actual regression shape the containment test above
## depends on NOT happening: automatic search has no notion of "stay inside
## M4" and is free to route focus anywhere it judges geometrically closest.
class _MutantLeavesOneM4NeighborDirectionUnwired extends BattleMenu:
	func _ready() -> void:
		super._ready()
		var leave_btn: Button = get_node(
			"LeaveConfirm/Panel/ContentMargin/Content/Buttons/LeaveButton"
		)
		leave_btn.focus_neighbor_right = NodePath()


## [常駐敏感度證明] for [code]test_navigating_within_m4_does_not_escape_to_m1_rows[/code]
## above — proves the detection technique (checking WHERE focus ends up after
## a directional press) actually distinguishes "explicitly wired" from
## "silently fell back to automatic search", rather than passing regardless.
func test_sensitivity_proof_m4_containment_detection_catches_an_unwired_direction() -> void:
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantLeavesOneM4NeighborDirectionUnwired)
	auto_free(mutant)
	add_child(mutant)

	var leave_btn: Button = mutant.get_node(
		"LeaveConfirm/Panel/ContentMargin/Content/Buttons/LeaveButton"
	)
	assert_str(String(leave_btn.focus_neighbor_right)).append_failure_message(
		"PRECONDITION: mutant must have actually cleared focus_neighbor_right " +
		"back to empty, or this proof is vacuous."
	).is_equal("")

	assert_int(mutant.open()).is_equal(BattleMenu.OpenResult.OPENED)
	mutant.open_leave_confirm()
	leave_btn.grab_focus()
	assert_bool(leave_btn.has_focus()).append_failure_message(
		"PRECONDITION: could not focus Leave to begin with."
	).is_true()

	mutant.get_viewport().push_input(_real_key_event(&"ui_right"))
	await get_tree().process_frame

	assert_bool(leave_btn.has_focus()).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant deliberately clears " +
		"focus_neighbor_right on Leave, so pressing ui_right must NOT " +
		"leave focus on Leave here (the explicit wiring that would keep it " +
		"contained inside M4 is gone, so whatever automatic search does " +
		"instead must be reachable by this assertion) — if it still reads " +
		"TRUE, the real containment test's detection technique cannot tell " +
		"correctly-wired M4 focus from a direction that silently fell back " +
		"to unconstrained automatic search."
	).is_false()

	mutant.close()


# ═══════════════════════════════════════════════════════════════════════════
# Top-level open()/close() cycle hygiene — M4 must never leak across cycles.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: [method BattleMenu.open]'s own added line
## ([code]_leave_confirm.visible = false[/code]) is a single, unconditional
## assignment — deleting it flips this assertion immediately.
func test_reopening_top_level_menu_resets_m4_to_hidden() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	instance.open_leave_confirm()
	assert_bool(instance.is_leave_confirm_open()).append_failure_message(
		"PRECONDITION: M4 must be open before closing/reopening the whole menu."
	).is_true()

	instance.close()
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)

	assert_bool(instance.is_leave_confirm_open()).append_failure_message(
		"re-opening the whole menu must not leak M4's visibility from the " +
		"previous open/close cycle — a fresh open() must always start with " +
		"M4 hidden."
	).is_false()

	instance.close()


# ═══════════════════════════════════════════════════════════════════════════
# quit_callable — the irreversible action, and the deliberate asymmetry
# in its unset default. See this file's header safety warning before editing.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: whether [signal BaseButton.pressed] on the
## Leave button is connected to [method BattleMenu._on_leave_confirmed_pressed]
## at all is a binary fact.
func test_leave_button_calls_injected_quit_callable_instead_of_real_quit() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	# 🔴 Array[int] capture cell — same documented lambda capture-by-value
	# trap as test_double_confirm_from_leave_game_row_does_not_quit_decision_layer
	# above (see tests/unit/cursor/shared_types_test.gd:170-174). Found by
	# actually running this test, not assumed: with a bare int this read 0
	# even after a real invocation, which would have made this test pass
	# regardless of whether the wiring existed at all.
	var quit_calls: Array[int] = [0]
	instance.quit_callable = func() -> void: quit_calls[0] += 1
	assert_bool(instance.diagnostic_would_call_real_quit()).append_failure_message(
		"once a Callable is injected, the diagnostic must report FALSE — " +
		"otherwise this test cannot tell 'the real quit path was bypassed' " +
		"from 'it was never checked'."
	).is_false()

	_leave_button(instance).pressed.emit()

	assert_int(quit_calls[0]).append_failure_message(
		"pressing 離開 must call the injected quit_callable exactly once."
	).is_equal(1)


## 🔴 Pins the DELIBERATE asymmetry in [member BattleMenu.quit_callable]
## (documented at its own declaration site): unlike [member
## BattleMenu.authoritative_write_in_progress_check] / [member
## BattleMenu.forced_discard_in_progress_check], where "unset" means "inert",
## an unset [member BattleMenu.quit_callable] means "call the REAL
## SceneTree.quit()". This test does NOT prove the menu "works" — it proves
## that a reader who "fixes" this into looking like the other two Callables
## (unset = inert) would be introducing a real production defect (a leave
## button that silently does nothing), not fixing one. It never invokes the
## real path — see [method BattleMenu.diagnostic_would_call_real_quit]'s own
## doc comment for why a read-only getter is what makes that possible.
func test_uninjected_quit_callable_would_call_real_quit_by_design() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)

	assert_bool(instance.diagnostic_would_call_real_quit()).append_failure_message(
		"a fresh, UNINJECTED BattleMenu must be wired to fall back to the " +
		"real SceneTree.quit() call in production — checked via a read-only " +
		"diagnostic getter specifically so this test never has to invoke the " +
		"irreversible action itself. If this assertion goes RED: someone " +
		"changed quit_callable's unset default to be inert (matching this " +
		"file's OTHER two injectable Callables) — that would make the leave " +
		"button silently do nothing in production, which is the DEFECT this " +
		"asymmetry exists to prevent, not a bug this test is wrongly " +
		"flagging. Read quit_callable's own doc comment before 'fixing' this " +
		"back without a fresh design decision."
	).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# AC-M7 (ADVISORY) — 離開確認的文字明確說出「進度會消失」.
# ═══════════════════════════════════════════════════════════════════════════


func test_leave_confirm_body_states_progress_will_be_lost() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)

	assert_str(BattleMenu.LEAVE_CONFIRM_BODY).append_failure_message(
		"AC-M7: M4's body text must literally state the consequence " +
		"('進度會消失'), not a generic '確定要離開嗎?'."
	).contains("進度會消失")

	assert_str(instance.get_node(
		"LeaveConfirm/Panel/ContentMargin/Content/BodyLabel"
	).text).append_failure_message(
		"the BodyLabel actually displayed must be set from LEAVE_CONFIRM_BODY, " +
		"not a separate, potentially-drifted copy."
	).is_equal(BattleMenu.LEAVE_CONFIRM_BODY)


# ═══════════════════════════════════════════════════════════════════════════
# Position-half regression for [method BattleMenu.leave_confirm_rect].
# [method BattleMenu.leave_confirm_size] (SIZE half) already has its own
# regression test in tests/unit/ui/menu/battle_menu_layout_test.gd (U-007) —
# not touched here (not this story's file lock). This section covers only
# the POSITION half this story adds. [不可證 - 類 A] (static pure function).
# ═══════════════════════════════════════════════════════════════════════════


func test_leave_confirm_rect_matches_hud_layout_derived_centering_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS_WITH_MIN_WINDOW:
		var window_size: Vector2i = RESOLUTIONS_WITH_MIN_WINDOW[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var size: Vector2 = BattleMenu.leave_confirm_size(window_size)
		var expected_pos: Vector2 = safe.position + (safe.size - size) / 2.0
		var rect: Rect2 = BattleMenu.leave_confirm_rect(window_size)
		assert_vector(rect.position).append_failure_message(
			"%s: leave_confirm_rect() position %s != HudLayout-derived expectation %s" % [
				label, rect.position, expected_pos
			]
		).is_equal_approx(expected_pos, Vector2(0.01, 0.01))
		assert_vector(rect.size).append_failure_message(
			"%s: leave_confirm_rect() size %s != leave_confirm_size() %s" % [
				label, rect.size, size
			]
		).is_equal_approx(size, Vector2(0.01, 0.01))


func test_leave_confirm_rect_stays_within_safe_rect_at_every_defined_resolution() -> void:
	for label: String in RESOLUTIONS:
		var window_size: Vector2i = RESOLUTIONS[label]
		var safe: Rect2 = HudLayout.safe_rect(window_size)
		var rect: Rect2 = BattleMenu.leave_confirm_rect(window_size)
		assert_bool(safe.encloses(rect)).append_failure_message(
			"%s: leave_confirm_rect() %s is not fully enclosed by safe_rect() %s" % [
				label, rect, safe
			]
		).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# Scene structure [不可證 - 類 C] — mirrors battle_menu_layout_test.gd's own
# established category, applied to THIS story's new LeaveConfirm subtree.
# ═══════════════════════════════════════════════════════════════════════════


func test_leave_confirm_node_resolves_as_control_hidden_by_default() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	var node: Node = instance.get_node("LeaveConfirm")
	assert_object(node).is_not_null()
	assert_bool(node is Control).is_true()
	assert_bool((node as Control).visible).append_failure_message(
		"M4 must start hidden — a freshly instantiated menu must never show " +
		"the leave-confirmation dialog by default."
	).is_false()


func test_leave_confirm_blocker_covers_full_rect_and_stops_mouse() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	var blocker: Node = instance.get_node("LeaveConfirm/Blocker")
	assert_object(blocker).is_not_null()
	assert_bool(blocker is ColorRect).is_true()
	var control: Control = blocker as Control
	assert_float(control.anchor_right).is_equal(1.0)
	assert_float(control.anchor_bottom).is_equal(1.0)
	assert_int(control.mouse_filter).append_failure_message(
		"the M1-click blocker must be MOUSE_FILTER_STOP, or clicks would " +
		"pass through to M1's rows while M4 is open."
	).is_equal(Control.MOUSE_FILTER_STOP)


func test_leave_confirm_buttons_resolve_with_focus_mode_all() -> void:
	var instance: BattleMenu = _instantiate()
	add_child(instance)
	for path in [
		"LeaveConfirm/Panel/ContentMargin/Content/Buttons/CancelButton",
		"LeaveConfirm/Panel/ContentMargin/Content/Buttons/LeaveButton",
	]:
		var btn: Node = instance.get_node(path)
		assert_object(btn).append_failure_message("missing node: %s" % path).is_not_null()
		assert_bool(btn is Button).append_failure_message("%s is not a Button" % path).is_true()
		assert_int((btn as Button).focus_mode).append_failure_message(
			"%s.focus_mode should be FOCUS_ALL" % path
		).is_equal(Control.FOCUS_ALL)
