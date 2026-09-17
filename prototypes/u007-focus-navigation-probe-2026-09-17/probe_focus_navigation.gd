## Throwaway headless probe for Story U-007 (battle-menu.md Implementation Notes
## #3 / EPIC.md 陷阱十三): the design doc explicitly states "focus_mode /
## disabled 的實際行為本專案從未量測過" — this project must NOT assume any
## Godot 4.7.1 Control focus-navigation property combination produces the
## required "up-arrow on the first row does not wrap to the last row" behavior
## without asking the running engine first (VERSION.md: Godot 4.7 shipped after
## the model's training cutoff and this file's own warning calls out Control-
## layout changes as a high-risk area).
##
## This probe asks three separate questions, each written as its own printed
## block so a reader can see exactly which claim each answer supports:
##
##   Q1 — does Godot's AUTOMATIC (no explicit focus_neighbor_*) geometric
##        neighbor search wrap focus from the topmost focusable Control back
##        to the bottommost one when ui_up is pressed?
##   Q2 — does explicitly setting focus_neighbor_top on the topmost Control to
##        point at itself reliably pin focus on that Control regardless of Q1's
##        answer (this is the mechanism the production code will actually use,
##        so it is verified independently of the automatic-search behavior)?
##   Q3 — does automatic geometric search correctly SKIP a sibling Control whose
##        focus_mode is FOCUS_NONE (needed for the divider between "結束回合"
##        and "離開遊戲" not to interrupt normal down-navigation)?
##
## All three are tested by constructing real Control nodes under the SceneTree
## root Window and injecting real InputEventKey events via Viewport.push_input()
## — not by calling any internal/private engine method and not by re-deriving
## the focus-neighbor algorithm ourselves. This is a genuine engine measurement,
## not a re-implementation (technical-preferences.md (A)-grade discipline).
##
## Run:
##   "<godot path>" --headless --path . -s prototypes/u007-focus-navigation-probe-2026-09-17/probe_focus_navigation.gd
extends SceneTree


func _make_focusable(name_: String, y: float) -> Button:
	var b := Button.new()
	b.name = name_
	b.focus_mode = Control.FOCUS_ALL
	b.position = Vector2(0, y)
	b.size = Vector2(200, 50)
	b.text = name_
	return b


func _push_key(target: Viewport, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	target.push_input(ev)


func _initialize() -> void:
	print("=== U-007 focus-navigation probe (2026-09-17) ===")
	print("Engine version: %s" % Engine.get_version_info())
	var root: Window = get_root()

	# ── Q1: does automatic (no explicit focus_neighbor_*) search wrap? ──────
	var q1_row1: Button = _make_focusable("Q1_Row1", 0)
	var q1_row2: Button = _make_focusable("Q1_Row2", 60)
	var q1_row3: Button = _make_focusable("Q1_Row3", 120)
	root.add_child(q1_row1)
	root.add_child(q1_row2)
	root.add_child(q1_row3)
	await process_frame
	await process_frame

	q1_row1.grab_focus()
	print("\n--- Q1: automatic wrap on ui_up from topmost row? ---")
	print("Q1 initial focus: row1=%s row2=%s row3=%s" % [q1_row1.has_focus(), q1_row2.has_focus(), q1_row3.has_focus()])
	_push_key(root, KEY_UP)
	await process_frame
	print("Q1 after ui_up:    row1=%s row2=%s row3=%s" % [q1_row1.has_focus(), q1_row2.has_focus(), q1_row3.has_focus()])
	var q1_wrapped_to_last: bool = q1_row3.has_focus()
	var q1_stayed_on_first: bool = q1_row1.has_focus()
	print("Q1 RESULT: wrapped_to_last_row=%s  stayed_on_first_row=%s" % [q1_wrapped_to_last, q1_stayed_on_first])

	# Sanity check in the same tree: does normal (non-edge) ui_down navigation
	# work at all, so a "stayed on first row" result for Q1 isn't secretly
	# explained by push_input not working rather than by non-wrapping?
	q1_row1.grab_focus()
	_push_key(root, KEY_DOWN)
	await process_frame
	print("Q1 sanity — ui_down from row1 (mid-list, should move): row2 focused=%s" % q1_row2.has_focus())

	for n in [q1_row1, q1_row2, q1_row3]:
		root.remove_child(n)
		n.queue_free()
	await process_frame

	# ── Q2: does an explicit self-pointing focus_neighbor_top pin focus? ────
	var q2_row1: Button = _make_focusable("Q2_Row1", 0)
	var q2_row2: Button = _make_focusable("Q2_Row2", 60)
	var q2_row3: Button = _make_focusable("Q2_Row3", 120)
	root.add_child(q2_row1)
	root.add_child(q2_row2)
	root.add_child(q2_row3)
	await process_frame
	await process_frame

	q2_row1.focus_neighbor_top = q2_row1.get_path()
	print("\n--- Q2: explicit self-pointing focus_neighbor_top pins focus? ---")
	q2_row1.grab_focus()
	_push_key(root, KEY_UP)
	await process_frame
	print("Q2 after ui_up with focus_neighbor_top=self: row1=%s row2=%s row3=%s" % [q2_row1.has_focus(), q2_row2.has_focus(), q2_row3.has_focus()])
	var q2_pinned: bool = q2_row1.has_focus() and not q2_row2.has_focus() and not q2_row3.has_focus()
	print("Q2 RESULT: pinned_on_row1=%s" % q2_pinned)

	# Also check the bottom edge with the same mechanism (focus_neighbor_bottom
	# on the last row pointing at itself) since the design's "到底停住" principle
	# names both ends even though AC-M13 only requires the top edge.
	q2_row3.focus_neighbor_bottom = q2_row3.get_path()
	q2_row3.grab_focus()
	_push_key(root, KEY_DOWN)
	await process_frame
	print("Q2b after ui_down with focus_neighbor_bottom=self on last row: row3=%s" % q2_row3.has_focus())

	for n in [q2_row1, q2_row2, q2_row3]:
		root.remove_child(n)
		n.queue_free()
	await process_frame

	# ── Q3: does automatic search skip a FOCUS_NONE sibling (the divider)? ──
	var q3_row1: Button = _make_focusable("Q3_Row1", 0)
	var q3_row2: Button = _make_focusable("Q3_Row2", 60)
	var q3_divider := Control.new()
	q3_divider.name = "Q3_Divider"
	q3_divider.focus_mode = Control.FOCUS_NONE
	q3_divider.position = Vector2(0, 120)
	q3_divider.size = Vector2(200, 10)
	var q3_row3: Button = _make_focusable("Q3_Row3", 140)
	root.add_child(q3_row1)
	root.add_child(q3_row2)
	root.add_child(q3_divider)
	root.add_child(q3_row3)
	await process_frame
	await process_frame

	print("\n--- Q3: automatic search skips a FOCUS_NONE divider sibling? ---")
	q3_row2.grab_focus()
	_push_key(root, KEY_DOWN)
	await process_frame
	print("Q3 after ui_down from row2 (divider between row2/row3): row3 focused=%s" % q3_row3.has_focus())
	var q3_skipped_divider: bool = q3_row3.has_focus()
	print("Q3 RESULT: skipped_divider_reached_row3=%s" % q3_skipped_divider)

	for n in [q3_row1, q3_row2, q3_divider, q3_row3]:
		root.remove_child(n)
		n.queue_free()
	await process_frame

	print("\n=== Probe complete ===")
	print("Q1 (automatic wrap on up from first row) = %s" % q1_wrapped_to_last)
	print("Q1 (automatic stays on first row without any explicit config) = %s" % q1_stayed_on_first)
	print("Q2 (explicit focus_neighbor_top=self pins focus on up-from-first) = %s" % q2_pinned)
	print("Q3 (FOCUS_NONE divider correctly skipped by automatic search) = %s" % q3_skipped_divider)
	quit()
