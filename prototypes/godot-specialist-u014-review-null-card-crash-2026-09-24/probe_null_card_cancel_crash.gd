## Independent-review probe (godot-specialist, 2026-09-24) — NOT part of Story
## U-014's own deliverable. Verifies a specific concern raised during review of
## battle_screen.gd's _open_card_confirm_panel() defensive null-card guard:
##
## Hypothesis: _card_confirming is set to true BEFORE the null check in
## _open_card_confirm_panel(). If that guard's null branch is hit (as
## tests/integration/ui/card_target_selection_test.gd's
## test_sensitivity_proof_illegal_tile_confirm_legality_check_skipped_regression_detected
## does today, by design — it bypasses _confirm_selected_card() and calls
## BattleController.select_card() directly, so _card_confirm_card is never
## set), _card_confirming is left true while _card_confirm_card stays null.
## A subsequent battle_cancel press would then route into
## _handle_card_confirm_cancel_transition(), which dereferences
## _card_confirm_card.category with no null guard.
##
## This script reproduces exactly that sequence against the REAL
## BattleScreen.tscn / battle_screen.gd / card_play_session.gd — no
## reimplementation of any rule, per technical-preferences.md's (A)-grade
## discipline.
extends SceneTree


func _initialize() -> void:
	var instance: BattleScreen = load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	root.add_child(instance)

	var card: Card = Card.new_temporary_stat_modifier("probe_card", 1, 0, 1)
	var cards: Array[Card] = [card]
	var deck: CardDeck = CardDeck.new(cards)
	deck.deal_opening_hand()
	instance._state.attach_card_deck(deck)
	instance._controller._card_play_session = CardPlaySession.new(
		deck, instance._state, [], NullAffinityWritePort.new()
	)

	print("STEP open_hand() = ", instance._controller.open_hand())
	# Bypass _confirm_selected_card() on purpose -- this is the exact bypass
	# card_target_selection_test.gd's sensitivity-proof test already performs.
	# _card_confirm_card is deliberately left at its default (null).
	print("STEP select_card() [bypassing _confirm_selected_card()] = ", instance._controller.select_card(card))
	print("PRECONDITION _card_confirm_card == null ? ", instance._card_confirm_card == null)

	var player_units: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var target: Unit = player_units[0]
	var advanced: bool = instance._controller.select_target(target.id)
	print("STEP select_target() = ", advanced)
	if advanced:
		instance._card_confirm_target_a = target.id
		instance._after_target_selection_advanced()

	print("STATE _card_confirming = ", instance._card_confirming)
	print("STATE _card_confirm_card == null ? ", instance._card_confirm_card == null)
	print("STATE session.step() = ", instance._controller._card_play_session.step())

	if not instance._card_confirming:
		print("RESULT: hypothesis NOT reproduced -- _card_confirming is false, cancel dispatch not reached. Probe inconclusive.")
		quit()
		return

	# Now dispatch a REAL battle_cancel InputEventKey through the REAL _input()
	# method, exactly as tests/integration/ui/card_confirm_panel_test.gd's
	# _real_pressed_event() helper does.
	var cancel_event: InputEventKey = null
	for event: InputEvent in InputMap.action_get_events(&"battle_cancel"):
		if event is InputEventKey:
			cancel_event = (event as InputEventKey).duplicate()
			cancel_event.pressed = true
			break

	print("STEP dispatching real battle_cancel _input() event now...")
	instance._input(cancel_event)
	print("RESULT: no crash -- _input(battle_cancel) returned normally. _card_confirming now = ", instance._card_confirming)
	quit()
