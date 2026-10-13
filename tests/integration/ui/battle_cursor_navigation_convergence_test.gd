## Story 008 (`production/epics/tactical-combat/story-008-cursor-navigation-convergence.md`)
## — convergence of the normal move/attack cursor path onto [CursorStateHost].
##
## ═══════════════════════════════════════════════════════════════════════════
## 🔴 ENGINE-VERIFIED FINDINGS (this session, real BattleScreen.tscn / real
## CursorStateHost Autoload / real CursorState — see each test's own body).
## Coordinator ruling (2026-10-13): register/unregister anchor moves from
## `unit_selected`/`selection_cleared` (prework, now acknowledged wrong) to
## the `CardPlaySession` open/closed boundary — but "the old plan was wrong"
## does not make "the new plan is right" automatically true (2026-10-12
## registered failure shape: right verdict, wrong reasoning, acted on without
## re-checking). The three items below are that re-check, in the ordered
## priority the coordinator specified.
## ═══════════════════════════════════════════════════════════════════════════
##
## 1. "一次走兩格" (one press moves the cursor twice) — CONFIRMED, engine-run.
##    See `test_registering_board_tile_on_normal_path_causes_two_independent_cursor_movements_per_press`.
##    One real `ui_right` InputEventKey, delivered once to the screen's own
##    `_input()` and once to the real `CursorStateHost` Autoload's real
##    `_input()`/`_process()`/`flush_buffered_navigation()` (both "the same
##    event reaches two nodes" per ADR-0005's own "dispatch order is TREE
##    order" note — simulated as two direct calls here, not a real engine
##    event-loop tick), moves BOTH `instance._cursor_cell` (via
##    `_handle_directional()`'s own untouched `clamp_cursor_move()`) AND the
##    Autoload's own `_state.get_current_target()` (via
##    `apply_buffered_navigation()` calling the just-registered
##    `cursor_navigate()`) by exactly one cell EACH, independently, from the
##    SAME single keypress. Confirms the hypothesis exactly as worded: two
##    separate, uncoordinated state variables each move once — not one
##    variable moving by two. This is reproducible TODAY, with zero production
##    code changes, purely by adding the registration the story's AC-1 already
##    asks for.
##
## 2. "未選取任何單位時,游標還能不能動" — CONFIRMED (today's behavior, before
##    any refactor), engine-run. See
##    `test_directional_navigation_can_select_a_non_default_unit_before_any_selection_exists_today`.
##    Using the real `vs01_roster.txt` fixture (`id 1` 甲 at `(0,2)` is the
##    `_ready()`-seeded default; `id 2` 乙 sits one row below at `(0,3)`), one
##    `ui_down` press + one `battle_confirm` press — with
##    `_controller.selected_unit() == -1` the entire time beforehand — moves
##    the cursor onto 乙's tile and selects 乙, not 甲. This is today's
##    UNMODIFIED behavior (`_handle_directional()`'s own direct write, no
##    `CursorStateHost` involvement at all) and is the capability this file's
##    register/unregister-anchor reasoning (§ below) argues must not be lost —
##    this test is the regression lock: if a future change ties BOARD_TILE
##    registration to `unit_selected`/`selection_cleared` as the coordinator's
##    prework originally proposed, THIS test goes red, with a message that
##    says exactly why.
##
## 3. 手把搖桿去抖動 (gamepad stick debounce gap) — PARTIALLY CONFIRMED,
##    engine-run, with one explicit unverified premise. See
##    `test_apply_buffered_navigation_has_no_builtin_debounce_for_repeated_joypad_motion_events`.
##    Feeding the SAME real, InputMap-bound `InputEventJoypadMotion` (bound to
##    a `CursorTypes.NAVIGATION_ACTIONS` entry in this engine's actual
##    InputMap — the test fails loud rather than assuming if none is bound)
##    through `CursorState.arbitrate_device_authority()` +
##    `apply_buffered_navigation()` TWICE in a row (simulating two
##    consecutive frames) moves the target TWICE — confirmed, by direct
##    engine run, that `apply_buffered_navigation()` has NO built-in
##    "already moved this direction, don't move again" debounce the way
##    `_handle_directional()`'s own `_direction_just_pressed()` /
##    `_direction_was_pressed` Dictionary provides for the screen's own path.
##    🔴 UNVERIFIED PREMISE, explicitly not tested here: whether the real
##    engine actually DELIVERS a fresh `InputEventJoypadMotion` for a held
##    stick on every single frame (vs. only on a value change). If it does,
##    this is a real, user-visible bug once the normal path hands
##    `_handle_directional()`'s debounce duty over to the host's pipeline —
##    the cursor would race across the board while a stick is held. If it
##    does not, this code-level gap may never actually manifest. Confirming
##    delivery frequency needs a WINDOWED, non-headless engine probe (an
##    actual joypad or a synthetic `Input.joy_connection_changed` + polling
##    probe) — out of scope for what could be verified this session.
##    🔴 FLAGGED PER THE COORDINATOR'S OWN FRAMING: if the unverified premise
##    holds, this is a gap in ADR-0005 itself (机制四之二 only filters
##    `InputEventKey.echo`), not merely an implementation detail of this
##    story — do not silently patch it inside `battle_screen.gd` alone
##    without flagging ADR-0005's owner.
##    🔴 **2026-10-13 coordinator ruling: this item is MOVED OUT of story-008's
##    scope.** Registered as a candidate gap in ADR-0005 itself, owner not yet
##    assigned — confirming the unverified delivery-frequency premise needs a
##    windowed, non-headless probe, which is a separate work order. No patch
##    code for this item belongs in this story. It DOES still constrain unit
##    3b below (stripping `_handle_directional()`'s self-movement): if the
##    host has no equivalent debounce and the real engine delivers
##    `InputEventJoypadMotion` every held-stick frame, deleting
##    `_direction_just_pressed()` wholesale would make a held gamepad stick
##    race the cursor across the board. Unit 3b must choose EITHER to keep
##    `_direction_just_pressed()`'s debounce (gating whether the event reaches
##    the host's pipeline at all) and delete only the direct `_cursor_cell`
##    WRITE, or to delete the debounce wholesale with an explicit, written
##    reason why the risk above does not apply — whichever is chosen must be
##    stated explicitly in that change, not left implicit.
##
## ═══════════════════════════════════════════════════════════════════════════
## Register/unregister anchor plan (unchanged from last round, still NOT
## implemented — coordinator ruling was "your plan is accepted provisionally,
## verify first", items 1-3 above are that verification; item 4 below,
## `_TargetRetargetActor` reuse for `_handle_mouse_button()`, is explicitly
## QUEUED NEXT, not yet investigated this round per the coordinator's stated
## priority order).
## ═══════════════════════════════════════════════════════════════════════════
##
## `CardPlaySession`'s `_step` state machine (`src/gameplay/cards/
## card_play_session.gd`) makes `is_card_play_in_progress()` change at
## exactly THREE call sites inside `battle_screen.gd`:
##   - FALSE -> TRUE: `_handle_open_hand_pressed()`'s `_controller.open_hand()`
##     success branch (S0 -> S1).
##   - TRUE -> FALSE, site A: same function's `_controller.cancel()` success
##     branch, reached only while `_card_selecting_from_hand` is true
##     (S1 -> S0).
##   - TRUE -> FALSE, site B: `_apply_pending_card_confirm()`'s
##     `_controller.confirm()` success branch (S3 -> S0, a card was played).
## Proposed anchor for the normal path (still unimplemented):
##   - Register BOARD_TILE once in `_ready()`, right after `_controller` is
##     built, seeding the host's target from `_state.position_of(player_ids[0])`
##     — this is what test #2 above locks in as required behavior.
##   - Unregister BOARD_TILE at the FALSE->TRUE site (hand off to card-play
##     BEFORE `_confirm_selected_card()`'s own register call runs later —
##     `CursorSurfaceRegistry.register()` hard-fails `DUPLICATE_TAG_REJECTED`
##     even for the SAME node re-registering an occupied tag, read directly
##     from `cursor_surface_registry.gd:100-106`).
##   - Re-register BOARD_TILE at BOTH TRUE->FALSE sites (reclaim from
##     card-play once it fully closes).
## The existing 4 card-play register/unregister call sites are UNCHANGED by
## this plan.
##
## 🔴 STILL NOT IMPLEMENTED IN `battle_screen.gd`. No production code has
## been touched this session either — this file remains the only artifact.
##
## ═══════════════════════════════════════════════════════════════════════════
## 4. `_handle_mouse_button()`'s R5-2 constraint — QUEUED, NOT YET READ THIS
##    ROUND (explicitly deprioritized behind items 1-3 above by the
##    coordinator's own ordering).
## ═══════════════════════════════════════════════════════════════════════════
## `CursorState.set_target()`'s doc comment (`cursor_state_host.gd:566-573`)
## requires callers to invoke it from their OWN node's `_process()` at a
## process_priority strictly between -100 and -25 (R5-2), never from
## `_input()`. `_handle_mouse_button()` runs inside `_input()`'s dispatch, so
## it cannot call `set_target()` directly once mouse clicks need to move the
## host's authoritative target. This file already has `_TargetRetargetActor`
## (process_priority -60) built for an analogous deferred-apply need
## (card-play's "jump to next/prev legal target"), but its exact contract —
## whether it can be reused for "set to an arbitrary clicked cell" or whether
## a second deferred actor is needed — has NOT been read yet. If the answer
## turns out to be "needs a new actor", that is a scope expansion to report
## back, not to build silently (coordinator's explicit instruction).
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"

var _original_arbitration_suspended: bool
var _original_target: CursorTarget
var _original_device_authority: int


func before_test() -> void:
	# Same save convention as tests/integration/ui/menu/battle_menu_gating_test.gd's
	# before_test()/after_test() pair — CursorStateHost is a shared Autoload
	# singleton across every test file in this engine process; its mutable
	# state must be restored, not merely reset to a guessed default.
	var host: Node = _host()
	_original_arbitration_suspended = host.get(&"_arbitration_suspended")
	var state: CursorState = host.get(&"_state")
	_original_target = state.get_current_target()
	_original_device_authority = state.get_device_authority()


func after_test() -> void:
	var host: Node = _host()
	host.set(&"_arbitration_suspended", _original_arbitration_suspended)
	host.set(&"_frame_events", [])
	var state: CursorState = host.get(&"_state")
	state.set(&"_target", _original_target)
	state.set(&"_device_authority", _original_device_authority)
	# Unconditional, idempotent cleanup for this file's own BOARD_TILE
	# registration (test #1 below) — harmless UNREGISTERED_NOT_FOUND on every
	# other test in this file, which never registers anything under this tag.
	var registry: CursorSurfaceRegistry = host.get(&"_registry")
	registry.unregister(CursorTypes.SurfaceType.BOARD_TILE)
	Input.action_release(&"ui_right")
	Input.action_release(&"ui_down")


func _host() -> Node:
	var host: Node = get_tree().root.get_node_or_null("CursorStateHost")
	assert_object(host).append_failure_message(
		"CursorStateHost autoload not found at /root -- is it still " +
		"registered in project.godot's [autoload] section?"
	).is_not_null()
	return host


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


func _test_mouse_position() -> Vector2:
	return Vector2.ZERO


func test_suite_file_parses_and_collects() -> void:
	assert_bool(true).is_true()


# ═══════════════════════════════════════════════════════════════════════════
# Finding #1 — "一次走兩格"
# ═══════════════════════════════════════════════════════════════════════════

func test_board_cursor_has_two_independent_writers_until_handle_directional_stops_self_moving() -> void:
	# Arrange — 🔴 2026-10-13: renamed and Arrange rewritten after Story 008
	# unit 3a landed (AC-1 wiring). BattleScreen._ready() now registers
	# BOARD_TILE -> self on its own, so a manual registration attempt from
	# here correctly gets DUPLICATE_TAG_REJECTED, not REGISTERED -- this is
	# used as a precondition proof that _ready()'s own registration fired,
	# not treated as a failure.
	var instance: BattleScreen = _fresh_instance()
	var host: Node = _host()
	var cursor_cell_before: Vector2i = instance._cursor_cell
	var state: CursorState = host.get(&"_state")
	var host_cell_before: Vector2i = CursorTypes.decode_tile(
		state.get_current_target().id, BoardCoords.BOARD_COLS
	)

	assert_int(CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, instance)) \
		.append_failure_message(
			"precondition: _ready() should already own BOARD_TILE for a freshly " +
			"built BattleScreen -- if this is REGISTERED instead of " +
			"DUPLICATE_TAG_REJECTED, unit 3a's _ready() registration regressed."
		).is_equal(CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED)

	# Act — ONE real ui_right press, delivered to both the screen's own
	# _input() (today's unmodified _handle_directional() path) and the real
	# Autoload's real _input()/_process()/flush_buffered_navigation(), matching
	# tests/integration/ui/menu/battle_menu_gating_test.gd's established
	# convention for driving the Autoload deterministically as plain direct
	# method calls.
	var nav_event: InputEventKey = _real_pressed_event(&"ui_right")
	Input.action_press(&"ui_right")
	instance._input(nav_event)
	host._input(nav_event)
	host._process(0.0)
	host.flush_buffered_navigation()
	Input.action_release(&"ui_right")

	# Assert — 🔴 NARRATIVE (coordinator instruction, 2026-10-13): these two
	# assertions currently document the STILL-PRESENT "一次走兩格" bug (both
	# writers move independently) and are EXPECTED TO KEEP PASSING AS WRITTEN
	# through unit 3a (wiring only, already landed) — they are NOT meant to
	# flip to the opposite behavior until unit 3b (stripping
	# _handle_directional()'s own _cursor_cell write) lands. When unit 3b
	# lands, THIS WHOLE TEST must be REWRITTEN to assert the converged
	# invariant (single authoritative source, no independent _cursor_cell
	# write) — it will not simply "turn green" as currently worded; if either
	# assertion below starts failing before that rewrite happens, re-derive
	# whether _handle_directional() already stopped self-writing before
	# concluding this is a regression versus the fix landing early.
	assert_vector(instance._cursor_cell).append_failure_message(
		"_handle_directional()'s own clamp_cursor_move() still moves " +
		"_cursor_cell by one cell on its own (unit 3a, wiring only, does not " +
		"touch this) -- if this fails, _handle_directional() already stopped " +
		"self-writing, which likely means unit 3b's stripping already " +
		"happened elsewhere; check before treating this as broken."
	).is_equal(cursor_cell_before + Vector2i.RIGHT)

	var host_cell_after: Vector2i = CursorTypes.decode_tile(
		state.get_current_target().id, BoardCoords.BOARD_COLS
	)
	assert_vector(host_cell_after).append_failure_message(
		"CONFIRMS the '一次走兩格' finding is STILL LIVE after unit 3a: " +
		"CursorStateHost's own flush_buffered_navigation() independently " +
		"moves its target by one cell from the SAME single keypress that " +
		"also moved _cursor_cell above -- two writers, not coordinated. " +
		"Expected to keep passing (bug still present) until unit 3b removes " +
		"_handle_directional()'s own write."
	).is_equal(host_cell_before + Vector2i.RIGHT)


# ═══════════════════════════════════════════════════════════════════════════
# Finding #2 — cursor must stay movable before any unit is selected
# ═══════════════════════════════════════════════════════════════════════════

func test_directional_navigation_can_select_a_non_default_unit_before_any_selection_exists_today() -> void:
	# Arrange — vs01_roster.txt: unit id 1 (甲) at (0,2) is _ready()'s seeded
	# default cursor position; unit id 2 (乙) sits one row below at (0,3).
	var instance: BattleScreen = _fresh_instance()
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"precondition: nothing should be selected yet"
	).is_equal(-1)
	var second_unit_cell: Vector2i = instance._cursor_cell + Vector2i.DOWN

	# Act — one ui_down press (today's _handle_directional() path only, no
	# card play, no CursorStateHost registration involved at all), then
	# confirm at the new cursor position.
	Input.action_press(&"ui_down")
	instance._input(_real_pressed_event(&"ui_down"))
	Input.action_release(&"ui_down")
	assert_vector(instance._cursor_cell).append_failure_message(
		"precondition: one ui_down press should move the cursor exactly one " +
		"row down onto unit id 2's tile"
	).is_equal(second_unit_cell)
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"方向鍵+確認應能在完全沒有單位被選取的情況下，選到游標當下所在的單位，" +
		"而非只能選到 _ready() 預設的那一個。若本 story 把 register/unregister " +
		"錨點掛在 unit_selected/selection_cleared（協調者前置檔的原始建議）而非 " +
		"從 _ready() 起就註冊 BOARD_TILE，這條測試預期會變紅。"
	).is_not_equal(-1)


# ═══════════════════════════════════════════════════════════════════════════
# Finding #3 — gamepad stick debounce gap in CursorState's own pipeline
# ═══════════════════════════════════════════════════════════════════════════

class _CountingSurface extends Node:
	var call_count: int = 0

	func cursor_navigate(from_id: int, _direction: Vector2i) -> Variant:
		call_count += 1
		return from_id + 1


func test_apply_buffered_navigation_has_no_builtin_debounce_for_repeated_joypad_motion_events() -> void:
	# Arrange — find a REAL InputEventJoypadMotion actually bound to a
	# NAVIGATION-class ui_* action in this engine's InputMap. Fails loud
	# rather than assuming one exists, per this project's own discipline
	# against unverified engine-behavior assumptions.
	var joy_event: InputEventJoypadMotion = null
	for action: StringName in CursorTypes.NAVIGATION_ACTIONS:
		if joy_event != null:
			break
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				joy_event = (event as InputEventJoypadMotion).duplicate()
				break
	if joy_event == null:
		fail(
			"PRECONDITION FAILED: no InputEventJoypadMotion is bound to any " +
			"CursorTypes.NAVIGATION_ACTIONS entry in this engine's real " +
			"InputMap -- cannot test the gamepad-stick debounce hypothesis " +
			"against a real bound event. This does not confirm OR refute the " +
			"hypothesis; it means this test could not run."
		)
		return

	var registry: CursorSurfaceRegistry = CursorSurfaceRegistry.new()
	var counting_surface: _CountingSurface = auto_free(_CountingSurface.new())
	assert_int(registry.register(CursorTypes.SurfaceType.BOARD_TILE, counting_surface)) \
		.is_equal(CursorSurfaceRegistry.RegisterResult.REGISTERED)
	var state: CursorState = CursorState.new(
		null, registry, Callable(self, "_test_mouse_position")
	)

	# Act — "frame 1": arbitrate (claims KEYBOARD_GAMEPAD authority) then
	# apply, using the SAME bound event object both times to simulate the
	# engine re-delivering it on a later frame while the stick stays held
	# (delivery-frequency itself is NOT verified here -- see header finding
	# #3's explicit caveat).
	state.arbitrate_device_authority([joy_event])
	state.apply_buffered_navigation([joy_event])
	var id_after_frame_1: int = state.get_current_target().id

	# "frame 2" -- identical event, fed again.
	state.arbitrate_device_authority([joy_event])
	state.apply_buffered_navigation([joy_event])
	var id_after_frame_2: int = state.get_current_target().id

	# Assert
	assert_int(counting_surface.call_count).append_failure_message(
		"CONFIRMS the debounce-gap hypothesis AT THE CODE LEVEL: " +
		"apply_buffered_navigation() called cursor_navigate() twice for two " +
		"separate buffered-event batches containing the identical joypad " +
		"motion event, with no 'already pressed last frame' suppression -- " +
		"unlike _handle_directional()'s own _direction_just_pressed() debounce. " +
		"Whether the real engine actually delivers InputEventJoypadMotion " +
		"every frame while a stick is held is NOT verified by this test -- " +
		"see this file's header finding #3."
	).is_equal(2)
	assert_int(id_after_frame_2).append_failure_message(
		"target id should have advanced on BOTH frames if there is truly no " +
		"debounce in this pipeline"
	).is_not_equal(id_after_frame_1)
