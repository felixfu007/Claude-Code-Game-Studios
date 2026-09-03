## Unit tests for Story 004 (裝置分類 + 動作語意分類,含 echo 過濾):
## [code]CursorTypes.classify()[/code] and [code]CursorTypes.classify_action()[/code]
## in [code]src/ui/cursor/cursor_types.gd[/code].
##
## Both functions under test are pure/static with no node, Input, or
## file-I/O dependency — every test below constructs [InputEvent]s directly
## with [code]new()[/code] and calls the static functions, headless, no
## random seed, no time dependency.
##
## [b]Why several tests read [code]InputMap.action_get_events()[/code]
## instead of hand-building every InputEvent[/b]: NAVIGATION/CONFIRM
## classification depends on the actual keycode/button/axis mapping matching
## a real [code]ui_*[/code] action (per [method InputMap.event_is_action]).
## This project's [code]project.godot[/code] does not declare [code]ui_*[/code]
## actions itself (only [code]battle_confirm[/code]/[code]battle_end_phase[/code]) —
## they are Godot 4.7.1's own built-in defaults (confirmed via
## [code]prototypes/story-004-ui-action-probe-2026-09-03/logs/probe_output.txt[/code]).
## Reading the actually-registered event via [code]InputMap[/code] and calling
## the production function on it is what this project's evidence-grade
## standard (technical-preferences.md's "來源等級三分法") calls for — it
## exercises the real engine mapping instead of a hand-guessed keycode that
## could silently be wrong for this engine version. This is deterministic:
## the engine's built-in [code]ui_*[/code] defaults do not change between
## runs of the same engine binary, and nothing in this test suite mutates
## [code]InputMap[/code].
##
## Coverage map (see final report for what each AC does/does not cover at
## this story's layer — full arbitration/persistence behaviour is Story 005):
##   AC-6   -> test_classify_action_returns_other_for_event_not_mapped_to_any_ui_action
##   AC-7   -> test_classify_ignores_device_id_for_keyboard_gamepad_events
##             + test_classify_ignores_device_id_for_mouse_events
##   AC-8   -> test_classify_action_returns_other_for_synthetic_mouse_event_not_bound_to_ui_action
##   AC-9   -> test_classify_action_is_stateless_across_many_repeated_calls
##             (supplementary only — see class doc comment on that test)
##   AC-34  -> test_classify_action_returns_navigation_for_keyboard_and_gamepad_button_nav_actions
##   AC-34b -> test_classify_action_returns_navigation_for_joypad_motion_nav_action
##   AC-35  -> test_classify_action_returns_confirm_not_navigation_for_confirm_actions
extends GdUnitTestSuite


# ─── classify(): device-family classification by InputEvent subclass ───────

func test_classify_keyboard_event_returns_keyboard_gamepad() -> void:
	# Arrange
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE

	# Act / Assert
	assert_int(CursorTypes.classify(event)).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)


func test_classify_joypad_button_event_returns_keyboard_gamepad() -> void:
	# Arrange
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A

	# Act / Assert
	assert_int(CursorTypes.classify(event)).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)


func test_classify_joypad_motion_event_returns_keyboard_gamepad() -> void:
	# Arrange
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = 0.9

	# Act / Assert
	assert_int(CursorTypes.classify(event)).is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)


func test_classify_mouse_motion_event_returns_mouse() -> void:
	# Arrange
	var event := InputEventMouseMotion.new()
	event.position = Vector2(10, 20)

	# Act / Assert
	assert_int(CursorTypes.classify(event)).is_equal(CursorTypes.Authority.MOUSE)


func test_classify_mouse_button_event_returns_mouse() -> void:
	# Arrange
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true

	# Act / Assert
	assert_int(CursorTypes.classify(event)).is_equal(CursorTypes.Authority.MOUSE)


func test_classify_unrecognized_event_subclass_returns_uninitialized() -> void:
	# Arrange — a bare InputEventAction is neither a keyboard/gamepad nor a
	# mouse InputEvent subclass; classify() only recognizes the five concrete
	# device subclasses named in 機制四, everything else falls to
	# UNINITIALIZED ("不參與裁定").
	var event := InputEventAction.new()
	event.action = &"ui_up"

	# Act / Assert
	assert_int(CursorTypes.classify(event)).is_equal(CursorTypes.Authority.UNINITIALIZED)


# ─── AC-7: classify() must ignore InputEvent.device entirely ───────────────

func test_classify_ignores_device_id_for_keyboard_gamepad_events() -> void:
	# Arrange — wildly different .device values simulate Godot 4.7 keyboard/
	# mouse device ID renumbering (TR-cursor-004's structural-immunity claim:
	# classify() must never branch on .device, only on InputEvent subclass).
	var device_ids: Array[int] = [-1, 0, 1, 16, 999]

	for device_id in device_ids:
		var key_event := InputEventKey.new()
		key_event.keycode = KEY_A
		key_event.device = device_id

		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = JOY_BUTTON_A
		joy_event.device = device_id

		# Act / Assert — same Authority regardless of .device
		assert_int(CursorTypes.classify(key_event)) \
			.is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)
		assert_int(CursorTypes.classify(joy_event)) \
			.is_equal(CursorTypes.Authority.KEYBOARD_GAMEPAD)


func test_classify_ignores_device_id_for_mouse_events() -> void:
	# Arrange — same check for the MOUSE branch, including the documented
	# -1 sentinel some synthetic mouse events may carry (机制四's explicit
	# downstream warning item).
	var device_ids: Array[int] = [-1, 0, 1, 999]

	for device_id in device_ids:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.device = device_id

		# Act / Assert
		assert_int(CursorTypes.classify(event)).is_equal(CursorTypes.Authority.MOUSE)


# ─── classify_action(): action-semantics bucket ─────────────────────────────

func test_classify_action_returns_navigation_for_keyboard_and_gamepad_button_nav_actions() -> void:
	# AC-34: real registered events for all four navigation actions, both
	# InputEventKey and InputEventJoypadButton forms — both device families
	# named in AC-34's text must classify as NAVIGATION.
	#
	# 🔴 Pin the constant's exact contents BEFORE looping over it. If
	# NAVIGATION_ACTIONS were ever emptied or its members swapped out, the
	# `for` loop below would silently execute zero times — every assertion
	# inside it is skipped, not failed, and GdUnit4 has no "zero assertions
	# ran" failure mode (confirmed against addons/gdUnit4/src). This
	# assertion is what turns that into a loud, named failure instead.
	assert_array(CursorTypes.NAVIGATION_ACTIONS).contains_exactly(
		&"ui_up", &"ui_down", &"ui_left", &"ui_right"
	)

	for action in CursorTypes.NAVIGATION_ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var key_event: InputEventKey = null
		var joy_button_event: InputEventJoypadButton = null
		for event in events:
			if event is InputEventKey and key_event == null:
				key_event = event
			elif event is InputEventJoypadButton and joy_button_event == null:
				joy_button_event = event

		assert_object(key_event).append_failure_message(
			"expected a real InputEventKey bound to %s in this engine's InputMap" % action
		).is_not_null()
		assert_object(joy_button_event).append_failure_message(
			"expected a real InputEventJoypadButton bound to %s in this engine's InputMap" % action
		).is_not_null()

		# Act / Assert
		assert_int(CursorTypes.classify_action(key_event)) \
			.append_failure_message("action=%s (InputEventKey)" % action) \
			.is_equal(CursorTypes.ActionClass.NAVIGATION)
		assert_int(CursorTypes.classify_action(joy_button_event)) \
			.append_failure_message("action=%s (InputEventJoypadButton)" % action) \
			.is_equal(CursorTypes.ActionClass.NAVIGATION)


func test_classify_action_returns_navigation_for_joypad_motion_nav_action() -> void:
	# AC-34b: real registered InputEventJoypadMotion for a navigation action.
	# Probe-confirmed 2026-09-03: this engine's built-in ui_up/down/left/right
	# defaults already include an InputEventJoypadMotion (left analog stick),
	# so this is a real registered mapping, not a hand-built guess.
	#
	# 🔴 Same zero-assertions-if-emptied risk as the test above — pin the
	# constant's exact contents before looping over it (see that test's
	# comment for the full reasoning).
	assert_array(CursorTypes.NAVIGATION_ACTIONS).contains_exactly(
		&"ui_up", &"ui_down", &"ui_left", &"ui_right"
	)

	for action in CursorTypes.NAVIGATION_ACTIONS:
		var motion_event: InputEventJoypadMotion = null
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				motion_event = event
				break

		assert_object(motion_event).append_failure_message(
			"expected a real InputEventJoypadMotion bound to %s in this engine's InputMap" % action
		).is_not_null()

		# Act / Assert
		assert_int(CursorTypes.classify_action(motion_event)) \
			.append_failure_message("action=%s (InputEventJoypadMotion)" % action) \
			.is_equal(CursorTypes.ActionClass.NAVIGATION)


func test_classify_action_returns_confirm_not_navigation_for_confirm_actions() -> void:
	# AC-35: real registered events for ui_accept/ui_cancel must classify as
	# CONFIRM, and explicitly NOT NAVIGATION — this is the assertion that
	# would catch someone accidentally widening NAVIGATION_ACTIONS to swallow
	# a confirm-class action.
	#
	# 🔴 Same zero-assertions-if-emptied risk as the two tests above — pin
	# the constant's exact contents before looping over it.
	assert_array(CursorTypes.CONFIRM_ACTIONS).contains_exactly(&"ui_accept", &"ui_cancel")
	#
	# ⚠️ Coverage gap, honestly disclosed rather than papered over: AC-35's
	# text says "鍵盤或手把" (keyboard OR gamepad) produces a confirm-class
	# action. Probe-confirmed 2026-09-03
	# (prototypes/story-004-ui-action-probe-2026-09-03/logs/probe_output.txt):
	# this engine's built-in ui_accept/ui_cancel defaults are bound ONLY to
	# InputEventKey — no InputEventJoypadButton/InputEventJoypadMotion event
	# exists in this InputMap for either action. `events[0]` below therefore
	# always resolves to a keyboard event; the gamepad half of AC-35's text
	# is NEVER exercised by this test, on either engine run.
	# This is accepted as-is rather than faked with a hand-built
	# InputEventJoypadButton, because classify_action() has no
	# device-specific branch for CONFIRM — the same
	# `InputMap.event_is_action(event, action)` check runs regardless of
	# which InputEvent subclass is passed in, so a real keyboard-bound event
	# and a hypothetical gamepad-bound one would exercise the identical code
	# path (unlike the NAVIGATION case above, which is the reason a separate
	# gamepad check does add value there). If a future engine version or a
	# project-level InputMap override binds a gamepad event to ui_accept/
	# ui_cancel, this test starts covering it automatically since it reads
	# InputMap.action_get_events() at run time rather than hardcoding a
	# keyboard-only assumption.
	for action in CursorTypes.CONFIRM_ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		assert_array(events).append_failure_message(
			"expected %s to have at least one bound event in this engine's InputMap" % action
		).is_not_empty()
		var event: InputEvent = events[0]

		# Act
		var result: CursorTypes.ActionClass = CursorTypes.classify_action(event)

		# Assert
		assert_int(result).append_failure_message("action=%s" % action) \
			.is_equal(CursorTypes.ActionClass.CONFIRM)
		assert_int(result).append_failure_message(
			"action=%s must not be classified as NAVIGATION" % action
		).is_not_equal(CursorTypes.ActionClass.NAVIGATION)


func test_classify_action_filters_out_echoed_key_events() -> void:
	# 🔴 Hard obligation (ADR-0005 approval, VR #13): a held-down key produces
	# repeat InputEventKey instances with echo == true. InputMap.event_is_action()
	# does NOT filter these on its own (measured, see cursor_types.gd doc
	# comment) — classify_action() must. This test proves the filter is what
	# makes the difference: same event, echo flipped, different result. If
	# someone deletes the "event is InputEventKey and event.echo" guard, this
	# test goes red because the echo=true branch would then also return
	# NAVIGATION.
	var real_key_event: InputEventKey = null
	for event in InputMap.action_get_events(&"ui_up"):
		if event is InputEventKey:
			real_key_event = event
			break
	assert_object(real_key_event).append_failure_message(
		"expected a real InputEventKey bound to ui_up in this engine's InputMap"
	).is_not_null()

	var non_echo_event: InputEventKey = real_key_event.duplicate()
	non_echo_event.pressed = true
	non_echo_event.echo = false

	var echo_event: InputEventKey = real_key_event.duplicate()
	echo_event.pressed = true
	echo_event.echo = true

	# Act / Assert — the non-echo press is a normal, eligible NAVIGATION event
	assert_int(CursorTypes.classify_action(non_echo_event)) \
		.is_equal(CursorTypes.ActionClass.NAVIGATION)
	# Act / Assert — the exact same mapping, but echo=true, must be filtered
	assert_int(CursorTypes.classify_action(echo_event)) \
		.is_not_equal(CursorTypes.ActionClass.NAVIGATION)
	assert_int(CursorTypes.classify_action(echo_event)) \
		.is_equal(CursorTypes.ActionClass.OTHER)


func test_classify_action_returns_other_for_event_not_mapped_to_any_ui_action() -> void:
	# AC-6: an event that does not correspond to any ui_* action mapping at
	# all must not be eligible for NAVIGATION or CONFIRM. button_index 999
	# is far outside any real controller's button range and is not bound to
	# anything in this project's InputMap (verified against the probe's full
	# 91-action dump — no action lists a button_index anywhere near this).
	var event := InputEventJoypadButton.new()
	event.button_index = 999
	event.pressed = true

	# Act / Assert
	assert_int(CursorTypes.classify_action(event)).is_equal(CursorTypes.ActionClass.OTHER)


func test_classify_action_returns_other_for_synthetic_mouse_event_not_bound_to_ui_action() -> void:
	# AC-8: a synthetic mouse event (e.g. Steam Input / touchpad emulation)
	# that does not actually trigger a mapped ui_* action must not be
	# eligible to claim device authority via the action-classification route.
	# Probe-confirmed 2026-09-03: zero ui_* actions in this engine/project
	# are bound to any mouse-typed event (see probe_output.txt's "Mouse-bound
	# ui_* actions check" — empty list), so both mouse InputEvent subclasses
	# structurally fall through to OTHER regardless of injection source.
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = Vector2(50, 60)

	var button_event := InputEventMouseButton.new()
	button_event.button_index = MOUSE_BUTTON_LEFT
	button_event.pressed = true

	# Act / Assert
	assert_int(CursorTypes.classify_action(motion_event)).is_equal(CursorTypes.ActionClass.OTHER)
	assert_int(CursorTypes.classify_action(button_event)).is_equal(CursorTypes.ActionClass.OTHER)


func test_classify_action_is_stateless_across_many_repeated_calls() -> void:
	# AC-9, supplementary only — NOT full AC-9 coverage. The actual "device
	# authority persists indefinitely, no timeout" behaviour this AC is
	# about lives in Story 002/005's CursorState authority field, which this
	# story does not touch. Primary verification for AC-9 at this story's
	# layer is the code-review fact stated below, not this loop.
	#
	# 🔴 2026-09-03 simplified from an earlier 10,000-iteration version per
	# independent review: classify_action() is a pure static function with
	# zero member state, no Timer, no frame counter, and no branch
	# conditioned on elapsed time or call count. Given that, the review
	# correctly pointed out that call #2 through call #10,000 provide no
	# information call #2 didn't already provide — a stateless function
	# either drifts on the very next call or never drifts, so iterating into
	# the thousands added runtime without adding detection power. This test
	# now asserts the same thing with a handful of repeats (enough to prove
	# "not just one lucky call", not enough to imply a false sense of
	# statistical confidence a call-count loop can't actually provide for a
	# pure function). The real guarantee is structural, confirmed by reading
	# cursor_types.gd: no state to drift.
	var real_key_event: InputEventKey = null
	for event in InputMap.action_get_events(&"ui_up"):
		if event is InputEventKey:
			real_key_event = event
			break
	assert_object(real_key_event).is_not_null()

	var probe_event: InputEventKey = real_key_event.duplicate()
	probe_event.pressed = true
	probe_event.echo = false

	for i in range(5):
		assert_int(CursorTypes.classify_action(probe_event)) \
			.append_failure_message("drifted at iteration %d" % i) \
			.is_equal(CursorTypes.ActionClass.NAVIGATION)
