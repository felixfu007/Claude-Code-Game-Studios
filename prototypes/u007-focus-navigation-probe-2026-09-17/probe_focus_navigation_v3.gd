## Throwaway headless probe v3 for Story U-007 — final confirmation run using
## the ACTUAL planned production structure (a wrapper [Control] containing
## Row1/Row2/Divider(FOCUS_NONE)/Row3, matching what [code]battle_menu.tscn[/code]
## will contain), after v1 (raw children of the base [Window]) produced a
## confusing result and v2 isolated the cause: automatic focus-neighbor
## geometric search only worked correctly once the buttons were parented under
## a dedicated [Control] rather than added directly to [code]SceneTree.root[/code]
## (a [Window]). This run re-verifies, on the corrected structure, the three
## claims Story U-007 / EPIC.md 陷阱十三 requires be measured rather than
## assumed, plus the production mechanism (explicit self-pointing
## [member Control.focus_neighbor_top]) this story's implementation will
## actually rely on.
##
## Run:
##   "<godot path>" --headless --path . -s prototypes/u007-focus-navigation-probe-2026-09-17/probe_focus_navigation_v3.gd
extends SceneTree


func _owner_name(from: Control) -> String:
	var o: Control = from.get_viewport().gui_get_focus_owner()
	return o.name if o != null else "<none>"


func _push_key(target: Viewport, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.physical_keycode = keycode
	ev.pressed = true
	target.push_input(ev)


func _initialize() -> void:
	print("=== U-007 focus-navigation probe v3 — production-shaped structure (2026-09-17) ===")

	var wrapper := Control.new()
	wrapper.name = "BattleMenuLike"
	wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_root().add_child(wrapper)

	var row1 := Button.new()
	row1.name = "ReturnToBattleRow"
	row1.focus_mode = Control.FOCUS_ALL
	row1.position = Vector2(10, 10)
	row1.size = Vector2(200, 40)
	row1.text = "回到遊戲"

	var row2 := Button.new()
	row2.name = "EndPhaseRow"
	row2.focus_mode = Control.FOCUS_ALL
	row2.position = Vector2(10, 55)
	row2.size = Vector2(200, 40)
	row2.text = "結束回合"

	var divider := Control.new()
	divider.name = "Divider"
	divider.focus_mode = Control.FOCUS_NONE
	divider.position = Vector2(10, 100)
	divider.size = Vector2(200, 6)

	var row3 := Button.new()
	row3.name = "QuitRow"
	row3.focus_mode = Control.FOCUS_ALL
	row3.position = Vector2(10, 115)
	row3.size = Vector2(200, 40)
	row3.text = "離開遊戲"

	wrapper.add_child(row1)
	wrapper.add_child(row2)
	wrapper.add_child(divider)
	wrapper.add_child(row3)
	await process_frame
	await process_frame
	await process_frame

	# ── Claim 1: automatic search does not wrap (no explicit config at all) ──
	print("\n--- Claim 1: automatic search, top row, no explicit focus_neighbor config ---")
	print("row1.find_valid_focus_neighbor(SIDE_TOP)    = %s" % (row1.find_valid_focus_neighbor(SIDE_TOP).name if row1.find_valid_focus_neighbor(SIDE_TOP) else "<null>"))
	row1.grab_focus()
	_push_key(wrapper.get_viewport(), KEY_UP)
	await process_frame
	print("after ui_up from row1 (automatic, unconfigured) -> focus owner = %s" % _owner_name(row1))
	var claim1_no_wrap: bool = _owner_name(row1) == "ReturnToBattleRow"

	# ── Claim 2: production mechanism — explicit self-pointing neighbor ─────
	print("\n--- Claim 2: production mechanism, focus_neighbor_top = self ---")
	row1.focus_neighbor_top = row1.get_path_to(row1)
	row1.grab_focus()
	_push_key(wrapper.get_viewport(), KEY_UP)
	await process_frame
	print("after ui_up from row1 (focus_neighbor_top=self) -> focus owner = %s" % _owner_name(row1))
	var claim2_pinned: bool = _owner_name(row1) == "ReturnToBattleRow"

	# ── Claim 3: automatic search skips the FOCUS_NONE divider ──────────────
	print("\n--- Claim 3: down-navigation from row2 skips FOCUS_NONE divider, reaches row3 ---")
	print("row2.find_valid_focus_neighbor(SIDE_BOTTOM) = %s" % (row2.find_valid_focus_neighbor(SIDE_BOTTOM).name if row2.find_valid_focus_neighbor(SIDE_BOTTOM) else "<null>"))
	row2.grab_focus()
	_push_key(wrapper.get_viewport(), KEY_DOWN)
	await process_frame
	print("after ui_down from row2 -> focus owner = %s" % _owner_name(row2))
	var claim3_skips_divider: bool = _owner_name(row2) == "QuitRow"

	# ── Bonus: bottom edge symmetry (not required by AC-M13, informative) ──
	print("\n--- Bonus: bottom edge, automatic search (no explicit config) ---")
	print("row3.find_valid_focus_neighbor(SIDE_BOTTOM) = %s" % (row3.find_valid_focus_neighbor(SIDE_BOTTOM).name if row3.find_valid_focus_neighbor(SIDE_BOTTOM) else "<null>"))

	print("\n=== SUMMARY ===")
	print("Claim 1 (automatic search does not wrap top->bottom)      = %s" % claim1_no_wrap)
	print("Claim 2 (focus_neighbor_top=self pins focus, production)  = %s" % claim2_pinned)
	print("Claim 3 (FOCUS_NONE divider skipped by automatic search)  = %s" % claim3_skips_divider)
	quit()
