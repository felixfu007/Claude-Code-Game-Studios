# Story 011 (`production/epics/tactical-combat/story-011-input-gaps.md`) --
# input-dispatch gap coverage for `battle_screen.gd`, per the M1 audit
# (`docs/reviews/tactical-combat-m1-current-state-audit-2026-09-29.md`).
#
# Coverage in THIS file: U-T6 (敵方回合拒絕是否逐幀生效 -- the visual cursor
# side-effect must freeze every _process() frame while
# BattleController.phase() == ENEMY_ACTING, not just once when the phase is
# entered), U-T7 (click_tile() 回傳值分派與拒絕回饋 -- both call sites in
# battle_screen.gd now route BattleController.click_tile()'s return value
# through _handle_click_tile_result() instead of discarding it; see that
# method's own doc comment for the three-way &"none" / &"blocked_pending_
# discard" / legal-action dispatch), AND U-T8 (結束單一單位行動的新輸入路徑 --
# a new `battle_end_unit_turn` project.godot action, keyboard Q + gamepad
# Back/Select, dispatches to BattleController.end_unit_turn(selected_unit())
# via _handle_end_unit_turn_result(), mirroring U-T7's own "never drop the
# result" discipline).
#
# 🔴 本檔案 I/O 使用揭露(.claude/rules/test-standards.md 甲類例外,2026-09-16
# 管理者裁決):每一條測試都 load()/instantiate() 真實的 BattleScreen.tscn,其
# _ready() 會讀 vs01_terrain.txt / vs01_roster.txt / vs01_affinity_links.txt /
# vs01_cards.txt / vs01_card_text.txt。唯讀,不寫入任何檔案,沿用
# battle_screen_enemy_phase_playback_test.gd 既有同名手法的先例 -- vs01 名冊有
# 5 個敵方單位,足以讓 _end_faction_phase_pressed() 的一次(不 await 的)呼叫
# 讓 phase() 停在 ENEMY_ACTING(GreedyTacticalAI 決策為確定性,無 RNG,見專案級
# 禁令 rng_in_combat_settlement,同一份資料檔每次執行結果一致)。
#
# 不建立額外 Node(除了場景本身的節點樹)。每個實例都用 auto_free() + add_child(),
# GdUnit4 會在測試結束後自動釋放,不留孤兒節點。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


# ---- 突變子類別(僅供 test_sensitivity_proof_* 使用;Case A:進樹前換腳本,已由
# 2026-09-17 探針驗證安全,見 .claude/rules/test-standards.md)------------------

# 還原這個 story 修之前,_input() 對滑鼠移動的行為:_last_mouse_window_pos 無條件
# 跟著每個 InputEventMouseMotion 更新,不管 phase() 是不是 ENEMY_ACTING。其餘事件
# 類型原封不動交給真正的 _input()(super)處理,所以這支間諜只改動本 story 新增的
# 這一條凍結邏輯,不影響其他分支。
class _MutantAlwaysTracksMouseMotion extends BattleScreen:
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			if _load_failed:
				return
			if _controller.phase() == BattleController.Phase.FINISHED:
				return
			_last_mouse_window_pos = (event as InputEventMouseMotion).position
			return
		super._input(event)


# 還原這個 story 修之前,_process() 的行為:無條件呼叫 _update_cursor_visual(),
# 不管 phase() 是不是 ENEMY_ACTING。額外覆寫 _update_cursor_visual() 本身只是為了
# 加一個呼叫次數計數器(委派給 super 做真正的工作)-- 這讓下面的敏感度證明直接讀
# 「這一幀有沒有被呼叫」,不必依賴 CursorStateHost 當下的裝置權威是滑鼠還是鍵盤/
# 手把(那是全專案共用的 Autoload 全域狀態,逐條測試之間不保證乾淨,見
# battle_cursor_navigation_convergence_test.gd 自己的揭露)才能判斷游標格子有沒有
# 跟著變動。
class _MutantAlwaysCallsUpdateCursorVisual extends BattleScreen:
	var update_cursor_visual_call_count: int = 0

	func _update_cursor_visual() -> void:
		update_cursor_visual_call_count += 1
		super._update_cursor_visual()

	func _process(_delta: float) -> void:
		if _load_failed:
			return
		_update_cursor_visual()


# U-T7 regression mutant -- reproduces the exact pre-story behavior the M1
# audit found: both call sites read BattleController.click_tile()'s return
# Dictionary and threw it away. Overriding _handle_click_tile_result() as a
# no-op is the minimal change that puts that behavior back without touching
# anything else.
class _MutantDiscardsClickTileResult extends BattleScreen:
	func _handle_click_tile_result(_result: Dictionary) -> void:
		pass


# U-T8 regression mutant -- same shape as _MutantDiscardsClickTileResult
# immediately above, for the OTHER result this story stops discarding:
# BattleController.end_unit_turn()'s bool return value.
class _MutantDiscardsEndUnitTurnResult extends BattleScreen:
	func _handle_end_unit_turn_result(_ended: bool) -> void:
		pass


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


# U-T8 (P-I2 全手把對等) -- same technique as _real_pressed_event() above, but
# for the GAMEPAD side of an action's binding, so a test can prove the
# gamepad path reaches the exact same production dispatch as the keyboard
# path, not merely that project.godot DECLARES a gamepad binding exists.
func _real_pressed_joy_event(action: StringName) -> InputEventJoypadButton:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var duplicated: InputEventJoypadButton = (event as InputEventJoypadButton).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


# Same technique as battle_screen_card_play_wiring_test.gd's own
# _click_event_at_cell() (that file's AC-14 tests) -- converts a board cell
# into a raw window-pixel InputEventMouseButton via the real
# WorldLayout/BoardCoords transforms, the same pair _window_pos_to_cell()
# itself uses, rather than hand-picking a pixel position.
func _click_event_at_cell(instance: BattleScreen, cell: Vector2i) -> InputEventMouseButton:
	var window_size: Vector2i = instance.get_window().size
	var canvas_to_window: Transform2D = WorldLayout.canvas_to_window_transform(window_size)
	var raw_pos: Vector2 = BoardCoords.grid_to_window(cell, canvas_to_window, Vector2.ZERO)
	var click_event: InputEventMouseButton = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = raw_pos
	return click_event


# 讓 instance 同步進入 ENEMY_ACTING,比照
# battle_screen_enemy_phase_playback_test.gd 自己的
# test_reentrant_end_phase_press_immediately_after_first_is_a_noop 先例:
# _end_faction_phase_pressed() 真正的呼叫端(_input())不可能 await 它,所以這裡
# 同樣不 await -- 呼叫會同步跑到它自己第一個
# `await get_tree().create_timer(...)` 之前才讓出控制權,而 vs01 的 5 個敵方單位
# 保證那一刻 phase() 還停在 ENEMY_ACTING。
func _enter_enemy_acting(instance: BattleScreen) -> void:
	instance._end_faction_phase_pressed()
	assert_int(instance._controller.phase()).append_failure_message(
		"precondition: vs01's 5 enemy units should keep phase() at ENEMY_ACTING after one synchronous call"
	).is_equal(BattleController.Phase.ENEMY_ACTING)


func test_suite_file_parses_and_collects() -> void:
	assert_bool(true).is_true()


# ---- U-T6: 敵方回合視覺副作用凍結 -------------------------------------------

func test_mouse_motion_during_enemy_acting_does_not_move_last_mouse_position() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)  # PLAYER_INPUT baseline sync
	_enter_enemy_acting(instance)
	var frozen_pos: Vector2 = instance._last_mouse_window_pos

	# Act -- mouse moves to a clearly different window position while
	# ENEMY_ACTING is in progress
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = frozen_pos + Vector2(123.0, 45.0)
	instance._input(motion)

	# Assert -- _input()'s own ENEMY_ACTING guard (see its doc comment) must
	# not let the new position through
	assert_vector(instance._last_mouse_window_pos).append_failure_message(
		"U-T6: _last_mouse_window_pos must stay frozen while ENEMY_ACTING -- " +
		"letting it advance would move the cursor the instant PLAYER_INPUT resumes"
	).is_equal(frozen_pos)


func test_mouse_click_during_enemy_acting_does_not_update_last_mouse_position() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	_enter_enemy_acting(instance)
	var frozen_pos: Vector2 = instance._last_mouse_window_pos

	# Act -- a left click at a different position while ENEMY_ACTING is in
	# progress. BattleController.click_tile()'s own deeper phase guard already
	# rejects the GAMEPLAY effect of a click here (M1 audit); this test covers
	# the SEPARATE visual side effect _handle_mouse_button() would otherwise
	# cause as its first statement.
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = frozen_pos + Vector2(80.0, 10.0)
	instance._input(click)

	# Assert
	assert_vector(instance._last_mouse_window_pos).append_failure_message(
		"U-T6: a click during ENEMY_ACTING must not reach _handle_mouse_button() " +
		"(which would overwrite _last_mouse_window_pos as its first statement)"
	).is_equal(frozen_pos)


func test_board_cursor_does_not_move_across_multiple_frames_during_enemy_acting() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)  # PLAYER_INPUT baseline sync
	var cell_before: Vector2i = instance._cursor_cell
	var sprite_pos_before: Vector2 = instance._board_view._cursor_sprite.position

	_enter_enemy_acting(instance)

	# Act -- feed a directional key AND a mouse motion event, then drive THREE
	# separate _process() frames (not one) -- this is the AC's own "每一幀皆
	# 須生效(不得只在演出開始時擋一次)" requirement.
	var nav_event: InputEventKey = _real_pressed_event(&"ui_right")
	assert_object(nav_event).append_failure_message(
		"precondition: ui_right must have a real InputEventKey bound in this engine's InputMap"
	).is_not_null()

	var frame_counts_seen: Array[int] = []
	for i in range(3):
		instance._input(nav_event)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = Vector2(200.0 + i * 10.0, 150.0 + i * 10.0)
		instance._input(motion)
		instance._process(0.0)
		frame_counts_seen.append(instance.diagnostic_enemy_acting_process_frame_count())

	# Assert -- _process() genuinely observed ENEMY_ACTING on all 3 calls
	# (frame_counts_seen is [1, 2, 3], not stuck at 0 from a phase that
	# silently already ended), and the cursor _board_view actually draws never
	# moved across any of them.
	assert_array(frame_counts_seen).append_failure_message(
		"precondition: diagnostic counter should advance once per _process() call while still ENEMY_ACTING"
	).is_equal([1, 2, 3])
	assert_vector(instance._cursor_cell).append_failure_message(
		"U-T6: board cursor cell must not change on any frame during ENEMY_ACTING"
	).is_equal(cell_before)
	assert_vector(instance._board_view._cursor_sprite.position).append_failure_message(
		"U-T6: _board_view's drawn cursor sprite position must not change on any frame during ENEMY_ACTING"
	).is_equal(sprite_pos_before)


# ---- battle_menu 在 ENEMY_ACTING 期間仍可開啟的既有先例回歸鎖 -----------------
# Story U-016 既有設計:開選單是真實動作,必須能明確拒絕,不得被這個 story 新增的
# ENEMY_ACTING 守衛連帶靜默吞掉 -- 這也是 U-T6 的守衛刻意插在 battle_menu 判斷
# "之後"而不是"之前"的理由(見 _input() 該守衛自己的 doc comment)。
# _end_faction_phase_pressed() 自己的 2026-09-24 註解已明文容忍在 phase() 已是
# ENEMY_ACTING 時被重入呼叫 -- 本測試鎖住「battle_menu 按鍵本身也能在同一狀態下
# 穿透到 open()」這個相鄰但不同的既有保證,不被本 story 新增的守衛連帶破壞。
func test_battle_menu_press_still_reaches_open_during_enemy_acting() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	_enter_enemy_acting(instance)
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"precondition: menu should start closed"
	).is_false()

	# Act
	var menu_event: InputEventKey = _real_pressed_event(&"battle_menu")
	assert_object(menu_event).append_failure_message(
		"precondition: battle_menu must have a real InputEventKey bound in this engine's InputMap"
	).is_not_null()
	instance._input(menu_event)

	# Assert -- U-T6's new top-level ENEMY_ACTING guard is placed AFTER the
	# battle_menu check, deliberately, so this must still open
	assert_bool(instance._battle_menu.is_open()).append_failure_message(
		"U-T6's new ENEMY_ACTING guard must not block battle_menu -- Story U-016 already " +
		"established that opening the menu must reach BattleMenu.open() in every phase"
	).is_true()


# ---- U-T7: click_tile() 回傳值分派與拒絕回饋 ----------------------------------
#
# vs01 roster (assets/data/units/vs01_roster.txt): unit 1 (甲) starts at
# (0,2). (0,0) and (12,5) are both open ground (vs01_terrain.txt row 1/6 are
# all '.') with no occupant and, with nothing selected, outside any unit's
# move/attack range -- i.e. a click there falls through
# BattleController.click_tile()'s final `return {"action": &"none"}` branch
# (M1 audit: this is "拒絕" in the story's sense, not
# &"blocked_pending_discard", which is covered separately below).

func test_mouse_click_on_empty_tile_with_nothing_selected_records_rejection() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)  # PLAYER_INPUT baseline sync
	var click: InputEventMouseButton = _click_event_at_cell(instance, Vector2i(12, 5))

	# Act
	instance._handle_mouse_button(click)

	# Assert -- the &"none" rejection is now observable instead of silently
	# discarded (M1 audit's own finding before this story)
	assert_that(instance.diagnostic_last_click_tile_action()).append_failure_message(
		"U-T7: a click on an empty, irrelevant tile must be recorded as the &\"none\" rejection"
	).is_equal(&"none")
	assert_int(instance.diagnostic_click_tile_rejected_count()).append_failure_message(
		"U-T7: the rejection counter must bump for a &\"none\" result"
	).is_equal(1)


func test_rejection_counter_accumulates_across_multiple_rejected_clicks() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	var click: InputEventMouseButton = _click_event_at_cell(instance, Vector2i(12, 5))

	# Act -- two separate rejected clicks
	instance._handle_mouse_button(click)
	instance._handle_mouse_button(click)

	# Assert -- not merely a boolean flag; it counts
	assert_int(instance.diagnostic_click_tile_rejected_count()).append_failure_message(
		"U-T7: the rejection counter must accumulate, not just latch to 1"
	).is_equal(2)


func test_confirm_at_cursor_routes_through_the_same_rejection_dispatch_as_mouse_click() -> void:
	# Arrange -- the DECLARED default for _cursor_cell is Vector2i.ZERO, but
	# _ready() re-seeds it onto the first PLAYER unit's own position (0,2) --
	# clicking THAT would select unit 1, not fall through to &"none" (this
	# was caught by a first run of this exact test: it failed with "Expecting
	# 'none' but was 'selected'" because of that re-seed, which is why the
	# cell is set explicitly here rather than trusting the field's class-body
	# default). (12,5) is the same open/unoccupied/out-of-range tile the
	# mouse-click test above uses, reached via the OTHER call site this story
	# fixes.
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	instance._cursor_cell = Vector2i(12, 5)

	# Act
	instance._confirm_at_cursor()

	# Assert
	assert_that(instance.diagnostic_last_click_tile_action()).append_failure_message(
		"U-T7: _confirm_at_cursor() must route through the same dispatch as _handle_mouse_button()"
	).is_equal(&"none")
	assert_int(instance.diagnostic_click_tile_rejected_count()).is_equal(1)


func test_click_on_own_unit_records_selected_action_without_bumping_rejected_count() -> void:
	# Arrange -- unit 1 (甲) at (0,2), PLAYER faction, current faction is
	# PLAYER at battle start
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	var click: InputEventMouseButton = _click_event_at_cell(instance, Vector2i(0, 2))

	# Act
	instance._handle_mouse_button(click)

	# Assert -- a legal action is recorded (proving the dispatch ran), but it
	# is NOT a rejection
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"precondition: clicking own unit with nothing selected should select it"
	).is_equal(1)
	assert_that(instance.diagnostic_last_click_tile_action()).append_failure_message(
		"U-T7: a legal &\"selected\" action must be recorded, distinct from &\"none\""
	).is_equal(&"selected")
	assert_int(instance.diagnostic_click_tile_rejected_count()).append_failure_message(
		"U-T7: a legal action must NOT bump the rejection counter"
	).is_equal(0)


# &"blocked_pending_discard" is believed unreachable from either real call
# site today (see _handle_click_tile_result()'s own doc comment: both guards
# already return before click_tile() is ever called while a discard is
# owed) -- this project has no fixture that can legitimately reach S4 forced
# discard AND still have click_tile() invoked past both guards. This test
# therefore drives the dispatch method directly with a hand-built result
# Dictionary, exactly mirroring the real shape
# BattleController.click_tile() documents for that branch
# (battle_controller.gd:781), to prove the dispatch keeps it fully separate
# from both &"none" and the legal-action branches -- the exact mixing this
# story's AC calls out by name.
func test_blocked_pending_discard_is_recorded_distinctly_and_does_not_bump_rejected_count() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)

	# Act
	instance._handle_click_tile_result({"action": &"blocked_pending_discard"})

	# Assert -- distinct from &"none": recorded, but NOT counted as a
	# rejection
	assert_that(instance.diagnostic_last_click_tile_action()).append_failure_message(
		"U-T7: &\"blocked_pending_discard\" must be recorded as itself, not folded into &\"none\""
	).is_equal(&"blocked_pending_discard")
	assert_int(instance.diagnostic_click_tile_rejected_count()).append_failure_message(
		"U-T7: &\"blocked_pending_discard\" is the EXISTING deliberate silence -- it must not " +
		"inflate the &\"none\" rejection counter"
	).is_equal(0)


# ---- U-T8: 結束單一單位行動的新輸入路徑 ---------------------------------------
#
# vs01 roster: unit 1 (甲), PLAYER faction, starts at (0,2), alive, actionable
# at battle start (same fixture fact test_click_on_own_unit_records_selected_
# action_without_bumping_rejected_count above already relies on).

func test_end_unit_turn_action_ends_selected_actionable_units_turn() -> void:
	# Arrange -- select unit 1 via the real mouse-click path (same helper the
	# U-T7 tests above already use), then confirm the precondition this test
	# actually needs: unit 1 selected AND still actionable.
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	instance._handle_mouse_button(_click_event_at_cell(instance, Vector2i(0, 2)))
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"precondition: clicking unit 1's own tile should select it"
	).is_equal(1)
	assert_array(instance._controller.selectable_units()).append_failure_message(
		"precondition: unit 1 should still be actionable before ending its turn"
	).contains([1])

	# Act -- real keyboard binding for the new action
	var end_turn_event: InputEventKey = _real_pressed_event(&"battle_end_unit_turn")
	assert_object(end_turn_event).append_failure_message(
		"precondition: battle_end_unit_turn must have a real InputEventKey bound in this engine's InputMap"
	).is_not_null()
	instance._input(end_turn_event)

	# Assert -- real production state changed (not a diagnostic shadow): this
	# is only possible if BattleController.end_unit_turn(1) genuinely ran.
	# [method BattleController.end_unit_turn]'s own doc comment: "Clears the
	# selection if id was selected."
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"U-T8: ending the selected unit's own turn must clear the selection"
	).is_equal(-1)
	assert_array(instance._controller.selectable_units()).append_failure_message(
		"U-T8: unit 1 must no longer be selectable after its turn was actively ended"
	).not_contains([1])
	assert_int(instance.diagnostic_end_unit_turn_rejected_count()).append_failure_message(
		"U-T8: a successful end_unit_turn() must NOT bump the rejection counter"
	).is_equal(0)


# P-I2 (全手把對等) -- same scenario as the keyboard test above, but fired via
# the REAL gamepad binding from InputMap, proving the gamepad path reaches the
# identical production dispatch rather than merely proving project.godot
# declares a gamepad event exists for this action.
func test_end_unit_turn_action_is_reachable_via_the_real_gamepad_binding() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	instance._handle_mouse_button(_click_event_at_cell(instance, Vector2i(0, 2)))
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"precondition: clicking unit 1's own tile should select it"
	).is_equal(1)

	# Act
	var end_turn_joy_event: InputEventJoypadButton = _real_pressed_joy_event(&"battle_end_unit_turn")
	assert_object(end_turn_joy_event).append_failure_message(
		"precondition: battle_end_unit_turn must have a real InputEventJoypadButton bound in this engine's InputMap (P-I2)"
	).is_not_null()
	instance._input(end_turn_joy_event)

	# Assert
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"U-T8/P-I2: the gamepad binding must reach the exact same dispatch as the keyboard binding"
	).is_equal(-1)
	assert_array(instance._controller.selectable_units()).not_contains([1])


func test_end_unit_turn_action_with_nothing_selected_is_rejected_and_recorded() -> void:
	# Arrange -- nothing selected (selected_unit() defaults to -1;
	# BattleController.end_unit_turn()'s own TurnOrder layer treats -1 as
	# "not actionable" and rejects cleanly, see _handle_end_unit_turn_result()'s
	# own doc comment)
	var instance: BattleScreen = _fresh_instance()
	instance._process(0.0)
	assert_int(instance._controller.selected_unit()).append_failure_message(
		"precondition: nothing should be selected at battle start"
	).is_equal(-1)

	# Act
	var end_turn_event: InputEventKey = _real_pressed_event(&"battle_end_unit_turn")
	instance._input(end_turn_event)

	# Assert
	assert_int(instance.diagnostic_end_unit_turn_rejected_count()).append_failure_message(
		"U-T8: pressing battle_end_unit_turn with nothing selected must be recorded as a rejection"
	).is_equal(1)


# ---- 敏感度證明 --------------------------------------------------------------

# 證明 test_mouse_motion_during_enemy_acting_does_not_move_last_mouse_position
# 的斷言真的會抓到這個 story 本身要修的缺口,而不是巧合通過。
func test_sensitivity_proof_mouse_freeze_test_catches_a_mutant_that_always_tracks() -> void:
	# Arrange
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantAlwaysTracksMouseMotion)
	auto_free(instance)
	add_child(instance)
	instance._process(0.0)
	_enter_enemy_acting(instance)
	var frozen_pos: Vector2 = instance._last_mouse_window_pos

	# Act
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = frozen_pos + Vector2(123.0, 45.0)
	instance._input(motion)

	# Assert -- the mutant's unconditional tracking should have let the new
	# position through, proving the real guard (not this absence) is what
	# keeps the real test's assertion green.
	assert_vector(instance._last_mouse_window_pos).append_failure_message(
		"sensitivity proof failed: mutant should have let the new mouse position " +
		"through during ENEMY_ACTING, but it did not"
	).is_not_equal(frozen_pos)


# 證明「_process() 在 ENEMY_ACTING 期間不得呼叫 _update_cursor_visual()」這道
# 守衛本身是真的在擋東西,而不是沒有任何一條測試會因為拿掉它而改變結果。
#
# ⚠️ 範圍揭露:本證明讀的是呼叫次數(update_cursor_visual_call_count),不是
# _cursor_cell 或 _board_view 的實際畫面輸出 -- 刻意避開依賴 CursorStateHost 當下
# 的裝置權威(全專案共用的 Autoload 全域狀態,逐條測試之間不保證哪個分支會被走到,
# 見 battle_cursor_navigation_convergence_test.gd 自己對這個共用狀態的揭露),
# 否則這支證明本身會變成不確定地通過或失敗。「_update_cursor_visual() 被呼叫會
# 讓游標畫面跟著移動」這件事本身不是本 story 新增的邏輯,是
# battle_cursor_navigation_convergence_test.gd 既有的大量測試已經覆蓋的既定行為 --
# 本證明只需要證明「這個 story 新增的守衛真的擋下了那次呼叫」。
func test_sensitivity_proof_process_guard_test_catches_a_mutant_that_always_calls_update() -> void:
	# Arrange
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantAlwaysCallsUpdateCursorVisual)
	auto_free(instance)
	add_child(instance)
	instance._process(0.0)
	_enter_enemy_acting(instance)
	var count_before: int = instance.update_cursor_visual_call_count

	# Act
	instance._process(0.0)
	instance._process(0.0)

	# Assert -- the mutant calls _update_cursor_visual() every frame
	# regardless of phase, proving the real production code's ENEMY_ACTING
	# branch (which does NOT call it) is load-bearing, not a no-op that
	# happened to pass.
	assert_int(instance.update_cursor_visual_call_count).append_failure_message(
		"sensitivity proof failed: mutant should call _update_cursor_visual() " +
		"every _process() frame regardless of phase, but it did not"
	).is_equal(count_before + 2)


# 證明 test_mouse_click_on_empty_tile_with_nothing_selected_records_rejection
# 真的會抓到這個 story 本身要修的缺口(回傳值被丟棄),而不是巧合通過。
func test_sensitivity_proof_rejection_dispatch_test_catches_a_mutant_that_discards_the_result() -> void:
	# Arrange
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantDiscardsClickTileResult)
	auto_free(instance)
	add_child(instance)
	instance._process(0.0)
	var click: InputEventMouseButton = _click_event_at_cell(instance, Vector2i(12, 5))
	var count_before: int = instance.diagnostic_click_tile_rejected_count()

	# Act
	instance._handle_mouse_button(click)

	# Assert -- the mutant reproduces the pre-story behavior (reads the
	# Dictionary, throws it away), proving the real _handle_click_tile_result()
	# dispatch -- not some unrelated side effect -- is what makes the real
	# test's counter advance.
	assert_int(instance.diagnostic_click_tile_rejected_count()).append_failure_message(
		"sensitivity proof failed: mutant should have discarded the &\"none\" result " +
		"without bumping the rejection counter, but the counter advanced anyway"
	).is_equal(count_before)


# 證明 test_end_unit_turn_action_with_nothing_selected_is_rejected_and_recorded
# 真的會抓到這個 story 本身要修的缺口(end_unit_turn() 的 bool 回傳值被丟棄),
# 而不是巧合通過 -- same shape as
# test_sensitivity_proof_rejection_dispatch_test_catches_a_mutant_that_discards_the_result
# immediately above, for U-T8's own result instead of U-T7's.
func test_sensitivity_proof_end_unit_turn_rejection_test_catches_a_mutant_that_discards_the_result() -> void:
	# Arrange
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantDiscardsEndUnitTurnResult)
	auto_free(instance)
	add_child(instance)
	instance._process(0.0)
	var end_turn_event: InputEventKey = _real_pressed_event(&"battle_end_unit_turn")
	var count_before: int = instance.diagnostic_end_unit_turn_rejected_count()

	# Act -- nothing selected, so the real BattleController.end_unit_turn(-1)
	# call underneath would return false; the mutant discards that bool
	# instead of recording it.
	instance._input(end_turn_event)

	# Assert -- the mutant reproduces pre-story behavior (calls end_unit_turn(),
	# reads the bool, throws it away), proving the real
	# _handle_end_unit_turn_result() dispatch -- not some unrelated side effect
	# -- is what makes the real test's counter advance.
	assert_int(instance.diagnostic_end_unit_turn_rejected_count()).append_failure_message(
		"sensitivity proof failed: mutant should have discarded the false result " +
		"without bumping the rejection counter, but the counter advanced anyway"
	).is_equal(count_before)
