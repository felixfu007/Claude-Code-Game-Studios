## Integration tests for Story U-009 — 「結束回合」列接上控制器,與既有查詢共用
## 單一判斷式 (src/ui/menu/battle_menu.gd's [member BattleMenu.controller] /
## [method BattleMenu.can_end_faction_phase] / [method
## BattleMenu.end_faction_phase_disabled_reason] / [method
## BattleMenu._on_end_phase_row_pressed]).
##
## Covers AC-M4 / AC-M5 / AC-M12 from
## [code]production/epics/card-play-interface/story-u009-end-turn-menu-item-wiring.md[/code]
## (AC-M5 / AC-M12 BLOCKING, AC-M4 ADVISORY), plus a decision-layer pass at
## AC-M2 (see the dedicated header note below on what that test does and does
## not prove).
##
## Placed under [code]tests/integration/ui/menu/[/code] to match this
## project's EXISTING directory for [code]battle_menu.gd[/code] integration
## tests ([code]battle_menu_gating_test.gd[/code] already lives here) — the
## story's own Test Evidence section names a flat
## [code]tests/integration/ui/battle_menu_end_turn_wiring_test.gd[/code] path
## with no [code]menu/[/code] subdirectory, which does not match precedent.
## Flagged as a dispatch/story inaccuracy rather than followed silently.
##
## ─── 🔴 Headless engine limitation found while writing this file (not
## assumed, measured) ───────────────────────────────────────────────────────
## [Button.pressed] cannot be made to fire from ANY simulated activation in
## this engine's [code]--headless[/code] mode — not a raw
## [InputEventKey]-based [code]ui_accept[/code] press+release pair via
## [method Viewport.push_input], not [method Input.action_press] /
## [method Input.action_release], and not even a simulated mouse click
## (button-down + button-up inside the control's rect). All three were tried,
## including an UNPAUSED baseline, and all four measurements read
## [code]pressed_count = 0[/code]. See
## [code]prototypes/u009-menu-pause-input-probe-2026-09-22/[/code] for the
## probe scripts and raw output this finding is based on. Directional FOCUS
## navigation (ui_up/ui_down moving [method Control.has_focus]) is UNAFFECTED
## — that already works headless (this project's own
## [code]battle_menu_layout_test.gd[/code] already relies on it, and the
## probe above reconfirms it independently, both paused and unpaused).
##
## Consequence for this file: any test below that needs to prove "selecting
## this row does X" fires the row's real [signal BaseButton.pressed] signal
## DIRECTLY ([code]row.pressed.emit()[/code]) rather than via a simulated key
## event — this proves the WIRING behind the signal is correct (decision
## layer), never that a real gamepad/keyboard press actually reaches that
## signal in production (applied layer). That applied-layer gap is registered
## honestly in each such test's own doc comment and in this story's report,
## not silently treated as covered — matching this project's established
## decision/applied split (EPIC.md 陷阱十三, coding-standards.md's Screenshot
## Evidence Rules Category B disclosure obligation).
##
## ─── Sensitivity-proof coverage (`.claude/rules/test-standards.md`,
## 2026-09-16 manager ruling) ───
## Each test below is annotated with which applies:
##   [常駐敏感度證明] = a companion [code]test_sensitivity_proof_*[/code] below
##                       proves the detection technique catches the injected
##                       defect (spy/mutant subclass, [code]set_script()[/code]
##                       BEFORE [method Node.add_child] — Case A, measured safe
##                       in [code]prototypes/u007-focus-navigation-probe-2026-09-17/probe_set_script_timing.gd[/code]).
##   [直接因果 — 不需另建突變] = the causal chain from cause to assertion is
##                       already a single, un-intermediated step (e.g. "signal
##                       connected or not") — a mutant would prove the same
##                       thing a second way, not a new way.
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"


# ── Fixtures ────────────────────────────────────────────────────────────────
# Roster/deck helpers deliberately mirror
# tests/unit/gameplay/battle/battle_controller_test.gd's own
# _build()/_build_with_deck()/_make_temp_cards() rather than importing them
# (GDScript test suites do not share private helpers across files in this
# project's existing convention) — same roster lines, proven "far apart, no
# incidental combat resolution" by that file's own comment and by
# tests/integration/gameplay/cards/card_battle_wiring_test.gd's use of the
# identical two lines across end_faction_phase()/run_enemy_phase() round trips.


func _far_apart_roster() -> Array[String]:
	return [
		"1,P1,PLAYER,20,5,3,0,1,1,0,0",
		"2,E1,ENEMY,20,5,3,0,1,1,12,5",
	]


func _build_controller(deck: CardDeck = null) -> BattleController:
	var state: BattleState = BattleState.create(PackedStringArray(), "\n".join(_far_apart_roster()))
	var order: TurnOrder = TurnOrder.new([1], [2])
	return BattleController.new(state, order, Callable(), Callable(), deck)


func _make_temp_cards(count: int) -> Array[Card]:
	var cards: Array[Card] = []
	for i: int in range(count):
		cards.append(Card.new_temporary_stat_modifier("c%d" % i, 1, 0, 1))
	return cards


func _instantiate() -> BattleMenu:
	return auto_free(load(SCENE_PATH).instantiate())


func _real_ui_key_event(action: StringName) -> InputEventKey:
	# Same convention as battle_menu_layout_test.gd's _real_ui_key_event() —
	# pull the REAL InputMap-bound event rather than hand-guessing a keycode.
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var dup: InputEventKey = (event as InputEventKey).duplicate()
			dup.pressed = true
			return dup
	fail("PRECONDITION: no real InputEventKey bound to %s in this engine's InputMap." % action)
	return null


func _end_phase_row(instance: Node) -> Button:
	return instance.get_node("Panel/ContentMargin/Rows/EndPhaseRow")


func _reason_label(instance: Node) -> Label:
	return instance.get_node("Panel/ContentMargin/Rows/EndPhaseReasonLabel")


func _return_row(instance: Node) -> Button:
	return instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")


func _quit_row(instance: Node) -> Button:
	return instance.get_node("Panel/ContentMargin/Rows/QuitRow")


# ═══════════════════════════════════════════════════════════════════════════
# AC-M5 (BLOCKING) — shared-predicate requirement. The two tests below are
# this story's core: change ground truth on BattleController, expect the row
# to follow with ZERO edits to battle_menu.gd.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: [member BattleMenu.controller] starts unset on a
## fresh instance (never injected by anything else in this test), so a
## disabled row here could only come from [method BattleMenu.can_end_faction_phase]
## itself misreading a freshly-constructed, still-PLAYER_INPUT controller.
func test_end_turn_item_enabled_by_default_while_phase_is_player_input() -> void:
	# Arrange
	var controller: BattleController = _build_controller()
	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame

	# Assert
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"row must start ENABLED while BattleController.phase() == PLAYER_INPUT."
	).is_false()
	assert_bool(_reason_label(instance).visible).append_failure_message(
		"M3 reason label must be hidden while the row is enabled."
	).is_false()


## AC-M5's core claim, half one: flipping [method BattleController.phase] away
## from PLAYER_INPUT must disable the row with ZERO edits to battle_menu.gd —
## proven here by actually calling [method BattleController.end_faction_phase]
## (the real ADR-0001 write path), not a test double.
func test_end_turn_item_disabled_when_phase_is_not_player_input() -> void:
	# Arrange
	var controller: BattleController = _build_controller()
	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"PRECONDITION: row must start enabled."
	).is_false()

	# Act
	controller.end_faction_phase()
	await get_tree().process_frame

	# Assert
	assert_int(controller.phase()).append_failure_message(
		"PRECONDITION: end_faction_phase() should have left PLAYER_INPUT."
	).is_equal(BattleController.Phase.ENEMY_ACTING)
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"AC-M5: BattleController.phase() left PLAYER_INPUT but the row is still enabled."
	).is_true()
	assert_bool(_reason_label(instance).visible).is_true()
	assert_str(_reason_label(instance).text).append_failure_message(
		"AC-M4: reason text must be player-readable plain language, not a field/error code."
	).is_equal("✕ " + BattleMenu.REASON_NOT_PLAYER_TURN)


## AC-M5's core claim, half two — the one `design/ux/battle-menu.md` itself
## calls out as "本節最不像 UX 驗收的一條,而它是最重要的": the row must
## RE-ENABLE once phase() returns to PLAYER_INPUT, with no menu-side code
## change. This is what distinguishes "reads the live query every time" from
## "read it once and cached the answer" — the exact drift AC-M5 exists to
## catch (`battle-menu.md`: "把共用改成各記一份,它必須轉紅").
func test_end_turn_item_enabled_reverts_when_phase_becomes_player_input() -> void:
	# Arrange
	var controller: BattleController = _build_controller()
	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame

	controller.end_faction_phase()
	await get_tree().process_frame
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"PRECONDITION: row must be disabled while ENEMY_ACTING."
	).is_true()

	# Act — drive the single far-apart enemy unit's entire pass to completion.
	controller.run_enemy_phase()
	await get_tree().process_frame

	# Assert
	assert_int(controller.phase()).append_failure_message(
		"PRECONDITION: run_enemy_phase() should have returned control to PLAYER_INPUT."
	).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"AC-M5: phase() returned to PLAYER_INPUT but the row did not re-enable — " +
		"this is the exact \"each side keeps its own copy\" failure AC-M5 exists to forbid."
	).is_false()
	assert_bool(_reason_label(instance).visible).append_failure_message(
		"M3 reason label must hide again once the row re-enables."
	).is_false()


## Mutant for the sensitivity proof below: reads [method
## BattleMenu.can_end_faction_phase] exactly ONCE (the first time [method
## BattleMenu._refresh_end_phase_row] runs) and never re-reads
## [member BattleMenu.controller] again — the "each side keeps its own copy"
## regression shape AC-M5 exists to forbid, reintroduced deliberately.
class _MutantCachesEndPhaseJudgementOnce extends BattleMenu:
	var _cached: bool = false
	var _cached_value: bool = true
	func _refresh_end_phase_row() -> void:
		if not _cached:
			_cached_value = BattleMenu.can_end_faction_phase(controller)
			_cached = true
		_end_phase_row.disabled = not _cached_value


## [常駐敏感度證明] for both AC-M5 tests above — proves the detection
## technique (assert [code]disabled[/code] right after flipping [method
## BattleController.phase]) actually catches a menu that stopped sharing the
## predicate and cached its own copy instead.
func test_sensitivity_proof_shared_predicate_detection_catches_a_menu_side_cache() -> void:
	# Arrange
	var controller: BattleController = _build_controller()
	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantCachesEndPhaseJudgementOnce)
	mutant.controller = controller
	auto_free(mutant)
	add_child(mutant)
	await get_tree().process_frame
	assert_bool(_end_phase_row(mutant).disabled).append_failure_message(
		"PRECONDITION: mutant's row must start enabled (cached value defaults true)."
	).is_false()

	# Act
	controller.end_faction_phase()
	await get_tree().process_frame

	# Assert
	assert_bool(_end_phase_row(mutant).disabled).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant deliberately caches the judgement " +
		"after the first read, so the row must have STAYED enabled here even " +
		"though phase() left PLAYER_INPUT — if it reads disabled=true, the " +
		"real AC-M5 tests' detection technique cannot tell a live shared " +
		"predicate from a stale per-menu cache."
	).is_false()


# ═══════════════════════════════════════════════════════════════════════════
# AC-M4 (ADVISORY) — card-play-in-progress and pending-discard causes.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: [method BattleController.is_card_play_in_progress]
## is a real forward to [CardPlaySession.is_open] (story-008), not a value
## this test fakes — [method BattleController.open_hand] is the real call that
## flips it.
func test_end_turn_item_disabled_when_card_play_in_progress() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_temp_cards(10), RandomNumberGenerator.new())
	var controller: BattleController = _build_controller(deck)
	assert_bool(controller.open_hand()).append_failure_message(
		"PRECONDITION: open_hand() must succeed to put card play in progress."
	).is_true()

	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame

	# Assert
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"AC-M4: row must be disabled while is_card_play_in_progress() is true."
	).is_true()
	assert_bool(_reason_label(instance).visible).is_true()
	assert_str(_reason_label(instance).text).append_failure_message(
		"AC-M4 wireframe wording (`design/ux/battle-menu.md`'s N2 mockup)."
	).is_equal("✕ " + BattleMenu.REASON_CARD_PLAY_IN_PROGRESS)


## Reflection write on [CardDeck]'s private [code]_pending_discard[/code]
## field — same established convention this project's own
## [code]battle_menu_gating_test.gd[/code] already uses against
## [CursorStateHost]'s private fields. Isolates "if
## [method BattleController.has_pending_discard] is ever true, does this row
## disable" from the realistic mechanism that actually produces a pending
## discard (hand-overflow after [method CardDeck.draw_for_turn], already
## covered by [code]tests/integration/gameplay/cards/card_battle_wiring_test.gd[/code]).
## [直接因果 — 不需另建突變]: single-field flip, single assertion.
func test_end_turn_item_disabled_when_pending_discard() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_temp_cards(10), RandomNumberGenerator.new())
	var controller: BattleController = _build_controller(deck)
	deck.set(&"_pending_discard", true)
	assert_bool(controller.has_pending_discard()).append_failure_message(
		"PRECONDITION: reflection write on CardDeck._pending_discard did not take."
	).is_true()

	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame

	# Assert
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"row must be disabled while has_pending_discard() is true (belt-and-" +
		"suspenders conjunct — see can_end_faction_phase()'s own doc comment " +
		"on why this branch should be structurally unreachable in practice)."
	).is_true()
	assert_str(_reason_label(instance).text).is_equal(
		"✕ " + BattleMenu.REJECTION_MESSAGE_FORCED_DISCARD
	)


# ═══════════════════════════════════════════════════════════════════════════
# AC-M12 (BLOCKING) — M3 reason text persists regardless of where focus is.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: [member Label.visible] is driven purely by
## [method BattleMenu.can_end_faction_phase]'s result, never by
## [member Control.has_focus] on any row — moving focus is the only variable
## changed here.
func test_reason_text_persists_when_focus_moves_off_end_turn_row() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_temp_cards(10), RandomNumberGenerator.new())
	var controller: BattleController = _build_controller(deck)
	assert_bool(controller.open_hand()).is_true()

	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame
	assert_bool(_reason_label(instance).visible).append_failure_message(
		"PRECONDITION: reason label must be visible with card play in progress."
	).is_true()

	# Act — move focus to QuitRow (neither ReturnToBattleRow nor EndPhaseRow).
	_quit_row(instance).grab_focus()
	await get_tree().process_frame

	# Assert
	assert_bool(_quit_row(instance).has_focus()).append_failure_message(
		"PRECONDITION: focus did not actually move to QuitRow."
	).is_true()
	assert_bool(_reason_label(instance).visible).append_failure_message(
		"AC-M12: M3 reason text must remain visible even though focus moved " +
		"off EndPhaseRow onto QuitRow — this is the 常駐不隨焦點 requirement, " +
		"not \"only shown while the disabled row itself is focused\"."
	).is_true()
	assert_str(_reason_label(instance).text).is_equal("✕ " + BattleMenu.REASON_CARD_PLAY_IN_PROGRESS)


## Companion to the test above, using ReturnToBattleRow instead of QuitRow —
## `design/ux/battle-menu.md` AC-M12 explicitly names EITHER row.
func test_reason_text_persists_when_focus_is_on_return_to_battle_row() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_temp_cards(10), RandomNumberGenerator.new())
	var controller: BattleController = _build_controller(deck)
	assert_bool(controller.open_hand()).is_true()

	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame

	# Act — ReturnToBattleRow is ALREADY the default focus (U-007/AC-M13), so
	# this asserts the label is visible without moving focus away at all.
	assert_bool(_return_row(instance).has_focus()).append_failure_message(
		"PRECONDITION: default focus must be on ReturnToBattleRow."
	).is_true()

	# Assert
	assert_bool(_reason_label(instance).visible).append_failure_message(
		"AC-M12: M3 reason text must be visible while focus sits on ReturnToBattleRow."
	).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# Navigation skip — battle-menu.md's "① 不可選項目——游標跳過" (States &
# Variants N2/N3 row; not a separately numbered AC, but the behavior this
# story's row-disable judgement is required to produce). Fully headless-
# provable: only focus movement is involved, never Button activation.
# ═══════════════════════════════════════════════════════════════════════════


## [常駐敏感度證明] — see the companion mutant/test below.
func test_navigating_down_from_return_row_skips_disabled_end_phase_row() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_temp_cards(10), RandomNumberGenerator.new())
	var controller: BattleController = _build_controller(deck)
	assert_bool(controller.open_hand()).is_true()

	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"PRECONDITION: EndPhaseRow must be disabled for this to test anything."
	).is_true()
	assert_bool(_return_row(instance).has_focus()).is_true()

	# Act — real simulated ui_down, same technique battle_menu_layout_test.gd
	# already establishes as headless-provable for this engine version.
	instance.get_viewport().push_input(_real_ui_key_event(&"ui_down"))
	await get_tree().process_frame

	# Assert
	assert_bool(_quit_row(instance).has_focus()).append_failure_message(
		"pressing down from ReturnToBattleRow while EndPhaseRow is disabled " +
		"must skip straight to QuitRow, not land on the disabled row."
	).is_true()
	assert_bool(_end_phase_row(instance).has_focus()).append_failure_message(
		"the disabled row must never receive focus via directional navigation."
	).is_false()


## Mutant for the sensitivity proof below: [method BattleMenu._refresh_end_phase_row]'s
## disabled-branch neighbor rewiring is disabled — the row's [code]disabled[/code]
## flag and reason text still update correctly, but the focus-neighbor graph
## keeps its ENABLED-state wiring even when the row is disabled. This
## reproduces exactly the failure `design/ux/battle-menu.md` warns is an
## untested engine assumption if skipped: navigation lands on the disabled row.
class _MutantNeverSkipsDisabledRow extends BattleMenu:
	func _refresh_end_phase_row() -> void:
		var can_end: bool = BattleMenu.can_end_faction_phase(controller)
		var end_row: Button = get_node("Panel/ContentMargin/Rows/EndPhaseRow")
		var reason_label: Label = get_node("Panel/ContentMargin/Rows/EndPhaseReasonLabel")
		end_row.disabled = not can_end
		reason_label.visible = not can_end
		if not can_end:
			reason_label.text = "✕ " + BattleMenu.end_faction_phase_disabled_reason(controller)
		# 🔴 Deliberately DOES NOT rewire focus_neighbor_* to skip the disabled
		# row — the regression this test exists to catch.


func test_sensitivity_proof_navigation_skip_detection_catches_missing_neighbor_rewiring() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_temp_cards(10), RandomNumberGenerator.new())
	var controller: BattleController = _build_controller(deck)
	assert_bool(controller.open_hand()).is_true()

	var mutant: Control = load(SCENE_PATH).instantiate()
	mutant.set_script(_MutantNeverSkipsDisabledRow)
	mutant.controller = controller
	auto_free(mutant)
	add_child(mutant)
	await get_tree().process_frame
	assert_bool(_end_phase_row(mutant).disabled).append_failure_message(
		"PRECONDITION: mutant's row must still report disabled=true (only the " +
		"neighbor rewiring is suppressed, not the disabled flag itself)."
	).is_true()

	# Act
	mutant.get_viewport().push_input(_real_ui_key_event(&"ui_down"))
	await get_tree().process_frame

	# Assert
	assert_bool(_end_phase_row(mutant).has_focus()).append_failure_message(
		"SENSITIVITY PROOF FAILED: mutant deliberately keeps the ENABLED-state " +
		"neighbor wiring even while disabled, so focus must have landed on the " +
		"disabled row here — if it did not, the real test's detection " +
		"technique (assert focus skipped to QuitRow) cannot tell correctly-" +
		"rewired navigation from navigation that still walks into a disabled row."
	).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# Row activation — see this file's header comment on the headless Button.
# pressed limitation. Both tests below fire the signal directly.
# ═══════════════════════════════════════════════════════════════════════════


## [直接因果 — 不需另建突變]: whether [signal BaseButton.pressed] is connected
## to [method BattleMenu._on_end_phase_row_pressed] at all is a binary
## fact — either [method BattleController.end_faction_phase] gets called or
## it does not; there is no intermediate state a mutant would add coverage
## for that this assertion does not already exercise directly.
##
## 🔴 Renamed from the story's own planned
## [code]test_selecting_end_turn_calls_end_faction_phase_then_run_enemy_phase[/code]
## — see [method BattleMenu._on_end_phase_row_pressed]'s doc comment for why
## this row deliberately does NOT call [method BattleController.run_enemy_phase]
## (that name described [code]battle_screen.gd[/code]'s PRE-U-018 behavior,
## since rewritten into a stepped coroutine this file cannot and must not
## re-drive). This test proves the actual contract: the mutating half
## ([method BattleController.end_faction_phase]) happens, and
## [signal BattleMenu.end_faction_phase_confirmed] fires so a future screen-
## level wiring can drain the enemy phase itself.
func test_selecting_end_turn_calls_end_faction_phase_and_emits_confirmation_signal() -> void:
	# Arrange
	var controller: BattleController = _build_controller()
	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	monitor_signals(instance)
	await get_tree().process_frame
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"PRECONDITION: row must be enabled to press it."
	).is_false()

	# Act — fires the real signal directly (see file header: Button.pressed
	# cannot be driven from simulated input headlessly in this engine version).
	_end_phase_row(instance).pressed.emit()

	# Assert
	assert_int(controller.phase()).append_failure_message(
		"selecting 結束回合 must call BattleController.end_faction_phase()."
	).is_equal(BattleController.Phase.ENEMY_ACTING)
	await assert_signal(instance).is_emitted("end_faction_phase_confirmed")


## [直接因果 — 不需另建突變]: defense-in-depth re-check inside
## [method BattleMenu._on_end_phase_row_pressed] itself — proven by forcing a
## press signal through while [member Button.disabled] is true (which native
## [Button] would normally have refused to ever emit in the first place; this
## test isolates the HANDLER's own guard from whatever [Button] itself does).
func test_pressing_end_turn_while_disabled_does_not_advance_phase() -> void:
	# Arrange
	var deck: CardDeck = CardDeck.new(_make_temp_cards(10), RandomNumberGenerator.new())
	var controller: BattleController = _build_controller(deck)
	assert_bool(controller.open_hand()).is_true()

	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)
	await get_tree().process_frame
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"PRECONDITION: row must be disabled (card play in progress)."
	).is_true()

	# Act — force the signal through despite disabled=true.
	_end_phase_row(instance).pressed.emit()

	# Assert
	assert_int(controller.phase()).append_failure_message(
		"_on_end_phase_row_pressed()'s own re-check must have refused to call " +
		"end_faction_phase() while can_end_faction_phase() is false."
	).is_equal(BattleController.Phase.PLAYER_INPUT)


# ═══════════════════════════════════════════════════════════════════════════
# AC-M2 (BLOCKING, `P-I2`) — 全程不接滑鼠、只用手把.
#
# 🔴 Decision-layer only (navigation half) — see file header. The confirm
# half is registered as an open gap, not silently covered.
# ═══════════════════════════════════════════════════════════════════════════


func test_gamepad_only_path_completes_open_menu_to_end_turn() -> void:
	# Arrange
	var controller: BattleController = _build_controller()
	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)

	# Act (i) — "開選單". [method BattleMenu.open] is a plain method call here
	# (this scene is not yet wired to the battle_menu/Start action anywhere in
	# src/ — U-007's own class doc comment; that wiring is a future story's
	# job), matching how battle_menu_gating_test.gd's own AC-M3/M8/M9 tests
	# already call open() directly rather than simulating a Start press.
	var result: BattleMenu.OpenResult = instance.open()
	assert_int(result).append_failure_message(
		"PRECONDITION: open() must succeed for this test to exercise anything."
	).is_equal(BattleMenu.OpenResult.OPENED)
	assert_bool(_return_row(instance).has_focus()).append_failure_message(
		"PRECONDITION: default focus must start on ReturnToBattleRow."
	).is_true()

	# Act (ii) — "結束回合": real simulated gamepad-equivalent ui_down
	# navigation (headless-provable, see file header) to reach EndPhaseRow.
	instance.get_viewport().push_input(_real_ui_key_event(&"ui_down"))
	await get_tree().process_frame

	# Assert
	assert_bool(_end_phase_row(instance).has_focus()).append_failure_message(
		"gamepad-equivalent ui_down did not move focus to EndPhaseRow — the " +
		"navigation half of AC-M2's 開選單→結束回合 path failed."
	).is_true()
	assert_bool(_end_phase_row(instance).disabled).append_failure_message(
		"PRECONDITION: EndPhaseRow must be enabled (no card play in progress, " +
		"no controller state changed) for a confirm press to be meaningful."
	).is_false()

	# 🔴 The CONFIRM half (a real ui_accept/gamepad-A press actually
	# activating the focused Button) is NOT exercised here via real input —
	# see this file's header comment. The wiring behind activation is already
	# proven by test_selecting_end_turn_calls_end_faction_phase_and_emits_
	# confirmation_signal above; this test stops at the navigation boundary
	# rather than faking coverage with a direct .pressed.emit() dressed up as
	# "gamepad-only". Registered as an open applied-layer gap needing a real
	# windowed screenshot/manual confirmation (coding-standards.md Screenshot
	# Evidence Rules), not silently treated as covered.

	# Cleanup — instance.open() paused the REAL shared SceneTree.
	instance.close()
	get_tree().paused = false


func test_gamepad_only_path_completes_open_menu_to_close() -> void:
	# Arrange
	var controller: BattleController = _build_controller()
	var instance: BattleMenu = _instantiate()
	instance.controller = controller
	add_child(instance)

	# Act (i) — "開選單".
	assert_int(instance.open()).is_equal(BattleMenu.OpenResult.OPENED)
	assert_bool(_return_row(instance).has_focus()).append_failure_message(
		"PRECONDITION: default focus must start on ReturnToBattleRow — no " +
		"navigation input is even needed for the close path, since the " +
		"default-focused row IS the close row."
	).is_true()

	# Act (ii) — "關閉": fires the real pressed signal directly (see file
	# header on why real ui_accept cannot be simulated headless) —
	# ReturnToBattleRow.pressed is connected straight to close() (U-008).
	_return_row(instance).pressed.emit()

	# Assert
	assert_bool(instance.is_open()).append_failure_message(
		"pressing 回到遊戲 (via its real pressed signal) must close the menu."
	).is_false()
	assert_bool(get_tree().paused).is_false()
