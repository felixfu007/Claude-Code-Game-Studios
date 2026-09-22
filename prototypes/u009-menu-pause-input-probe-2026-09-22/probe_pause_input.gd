extends SceneTree

# Throwaway probe (U-009). Two questions this settles before U-009 relies on
# either answer:
#
# Q1: once get_tree().paused = true (which BattleMenu.open() already sets —
#     U-008), does a Control node with the ENGINE DEFAULT process_mode
#     (PROCESS_MODE_INHERIT) still receive directional focus-navigation input
#     (ui_down) and Button activation (ui_accept)? battle-menu.md warns
#     "focus_mode 的實際行為本專案從未量測過" for a DIFFERENT question
#     (disabled/skip) — the pause-vs-input question is not covered by that
#     warning and is a separate hypothesis.
#
# Q2: does a real ui_accept InputEventKey pushed via Viewport.push_input()
#     actually fire Button.pressed at all (baseline, unpaused)? No existing
#     test in this project's suite exercises this (grep confirms every
#     existing ui_accept-simulation test target is CursorState/device
#     classification, never a native Button.pressed signal) — so this is
#     checked as its own baseline before attributing any negative result to
#     pausing specifically.
#
# Fix for v1's "!is_inside_tree()" errors: this version awaits a process_frame
# after add_child before calling grab_focus()/push_input() at all.

func _init() -> void:
	await process_frame
	var root: Window = get_root()

	var a := Button.new()
	a.text = "A"
	a.focus_mode = Control.FOCUS_ALL
	root.add_child(a)

	var b := Button.new()
	b.text = "B"
	b.focus_mode = Control.FOCUS_ALL
	root.add_child(b)

	await process_frame

	a.focus_neighbor_bottom = a.get_path_to(b)
	b.focus_neighbor_top = b.get_path_to(a)

	var a_pressed_count := 0
	var b_pressed_count := 0
	a.pressed.connect(func() -> void: a_pressed_count += 1)
	b.pressed.connect(func() -> void: b_pressed_count += 1)

	var down_events: Array = InputMap.action_get_events(&"ui_down")
	var accept_events: Array = InputMap.action_get_events(&"ui_accept")

	# ── Baseline (Q2): unpaused, does ui_accept fire Button.pressed at all? ──
	a.grab_focus()
	await process_frame
	print("BASELINE (unpaused): a.has_focus() = ", a.has_focus())

	for event in accept_events:
		if event is InputEventKey:
			var dup: InputEventKey = (event as InputEventKey).duplicate()
			dup.pressed = true
			root.push_input(dup)
			break
	await process_frame
	await process_frame
	print("BASELINE (unpaused): after ui_accept on focused Button A, a_pressed_count = ", a_pressed_count)

	# ── Q1, part 1: paused, default process_mode (INHERIT) ──
	paused = true
	print("paused = ", paused, "; a.process_mode = ", a.process_mode, " (0 = INHERIT)")

	for event in down_events:
		if event is InputEventKey:
			var dup2: InputEventKey = (event as InputEventKey).duplicate()
			dup2.pressed = true
			root.push_input(dup2)
			break
	await process_frame
	await process_frame
	print("PAUSED / default process_mode: after ui_down, b.has_focus() = ", b.has_focus())

	b_pressed_count = 0
	for event in accept_events:
		if event is InputEventKey:
			var dup3: InputEventKey = (event as InputEventKey).duplicate()
			dup3.pressed = true
			root.push_input(dup3)
			break
	await process_frame
	await process_frame
	print("PAUSED / default process_mode: after ui_accept, b_pressed_count = ", b_pressed_count)

	# ── Q1, part 2: paused, process_mode = ALWAYS on both ──
	paused = false
	await process_frame
	a.process_mode = Node.PROCESS_MODE_ALWAYS
	b.process_mode = Node.PROCESS_MODE_ALWAYS
	a.grab_focus()
	await process_frame
	paused = true
	b_pressed_count = 0

	for event in down_events:
		if event is InputEventKey:
			var dup4: InputEventKey = (event as InputEventKey).duplicate()
			dup4.pressed = true
			root.push_input(dup4)
			break
	await process_frame
	await process_frame
	print("PAUSED / process_mode=ALWAYS: after ui_down, b.has_focus() = ", b.has_focus())

	for event in accept_events:
		if event is InputEventKey:
			var dup5: InputEventKey = (event as InputEventKey).duplicate()
			dup5.pressed = true
			root.push_input(dup5)
			break
	await process_frame
	await process_frame
	print("PAUSED / process_mode=ALWAYS: after ui_accept, b_pressed_count = ", b_pressed_count)

	paused = false
	quit()
