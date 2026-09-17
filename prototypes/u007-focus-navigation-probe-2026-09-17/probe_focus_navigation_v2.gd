## Throwaway headless probe v2 for Story U-007 — v1 (probe_focus_navigation.gd)
## produced an ambiguous result (neither up NOR down moved focus between two
## interior rows, which does not match either hypothesis cleanly), so this
## version isolates variables one at a time instead of chaining three
## experiments through the same root, and cross-checks TWO different event
## injection mechanisms (Viewport.push_input vs Input.parse_input_event) plus
## explicit gui_get_focus_owner() reads after every step, to find out which
## variable actually explains v1's result before writing any production code
## on top of an unverified assumption.
##
## Run:
##   "<godot path>" --headless --path . -s prototypes/u007-focus-navigation-probe-2026-09-17/probe_focus_navigation_v2.gd
extends SceneTree


func _owner_name() -> String:
	var o: Control = get_root().gui_get_focus_owner()
	return o.name if o != null else "<none>"


func _initialize() -> void:
	print("=== U-007 focus-navigation probe v2 (2026-09-17) ===")

	# Isolate under a dedicated wrapper Control (not raw children of the
	# Window) — closer to how BattleMenu will actually be structured, and
	# rules out any interaction specific to attaching Controls straight onto
	# the base Window.
	var wrapper := Control.new()
	wrapper.name = "Wrapper"
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(wrapper)
	await process_frame

	var row1 := Button.new()
	row1.name = "Row1"
	row1.focus_mode = Control.FOCUS_ALL
	row1.position = Vector2(10, 10)
	row1.size = Vector2(200, 50)
	row1.text = "Row1"

	var row2 := Button.new()
	row2.name = "Row2"
	row2.focus_mode = Control.FOCUS_ALL
	row2.position = Vector2(10, 70)
	row2.size = Vector2(200, 50)
	row2.text = "Row2"

	var row3 := Button.new()
	row3.name = "Row3"
	row3.focus_mode = Control.FOCUS_ALL
	row3.position = Vector2(10, 130)
	row3.size = Vector2(200, 50)
	row3.text = "Row3"

	wrapper.add_child(row1)
	wrapper.add_child(row2)
	wrapper.add_child(row3)
	await process_frame
	await process_frame
	await process_frame

	print("\n--- Baseline: grab_focus() alone ---")
	row1.grab_focus()
	await process_frame
	print("owner after row1.grab_focus() = %s (row1.has_focus=%s)" % [_owner_name(), row1.has_focus()])

	print("\n--- Experiment A: Input.parse_input_event(ui_down key), interior case ---")
	var ev_down := InputEventKey.new()
	ev_down.keycode = KEY_DOWN
	ev_down.physical_keycode = KEY_DOWN
	ev_down.pressed = true
	Input.parse_input_event(ev_down)
	await process_frame
	await process_frame
	print("owner after parse_input_event(DOWN) = %s" % _owner_name())
	var ev_down_release := InputEventKey.new()
	ev_down_release.keycode = KEY_DOWN
	ev_down_release.physical_keycode = KEY_DOWN
	ev_down_release.pressed = false
	Input.parse_input_event(ev_down_release)
	await process_frame

	print("\n--- Experiment B: reset focus to row1, try push_input(ui_down) ---")
	row1.grab_focus()
	await process_frame
	print("owner before push_input(DOWN) = %s" % _owner_name())
	var ev_down2 := InputEventKey.new()
	ev_down2.keycode = KEY_DOWN
	ev_down2.pressed = true
	get_root().push_input(ev_down2)
	await process_frame
	print("owner after push_input(DOWN) = %s" % _owner_name())

	print("\n--- Experiment C: is find_valid_focus_neighbor reachable at all? Query directly ---")
	# Control.find_valid_focus_neighbor(side) exists in Godot 4 — query it
	# directly rather than going through input at all, to isolate whether the
	# geometric search itself ever finds row2 as row1's SIDE_BOTTOM neighbor.
	if row1.has_method("find_valid_focus_neighbor"):
		var neighbor: Control = row1.find_valid_focus_neighbor(SIDE_BOTTOM)
		print("row1.find_valid_focus_neighbor(SIDE_BOTTOM) = %s" % (neighbor.name if neighbor != null else "<null>"))
		var neighbor_up: Control = row1.find_valid_focus_neighbor(SIDE_TOP)
		print("row1.find_valid_focus_neighbor(SIDE_TOP) = %s" % (neighbor_up.name if neighbor_up != null else "<null>"))
		var neighbor2_bottom: Control = row2.find_valid_focus_neighbor(SIDE_BOTTOM)
		print("row2.find_valid_focus_neighbor(SIDE_BOTTOM) = %s" % (neighbor2_bottom.name if neighbor2_bottom != null else "<null>"))
	else:
		print("Control has no find_valid_focus_neighbor method in this engine build")

	print("\n--- Experiment D: explicit focus_neighbor_bottom wiring, then push_input ---")
	row1.focus_neighbor_bottom = row1.get_path_to(row2)
	row1.grab_focus()
	await process_frame
	print("owner before push_input(DOWN) with explicit wiring = %s" % _owner_name())
	var ev_down3 := InputEventKey.new()
	ev_down3.keycode = KEY_DOWN
	ev_down3.pressed = true
	get_root().push_input(ev_down3)
	await process_frame
	print("owner after push_input(DOWN) with explicit focus_neighbor_bottom = %s" % _owner_name())

	print("\n=== Probe v2 complete ===")
	quit()
