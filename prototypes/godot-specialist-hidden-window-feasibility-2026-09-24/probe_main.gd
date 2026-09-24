extends Node2D

# Throwaway hidden-window feasibility probe.
# Draws ONLY abstract colour blocks (no project content, no text, no asset files).
# Answers Q1 (off-screen position clamping), Q2 (NO_FOCUS timing gap),
# Q3 (are the pixels the engine hands back real), and attempts Q4 (taskbar icon,
# expected to be inconclusive from GDScript alone).

const RED := Color(1, 0, 0, 1)
const GREEN := Color(0, 1, 0, 1)
const BLUE := Color(0, 0, 1, 1)
const YELLOW := Color(1, 1, 0, 1)
const MARKER := Color(1, 0, 1, 1) # magenta corner marker

var _t_init_usec: int = -1
var _no_focus_at_init: bool = false

func _init() -> void:
	# Earliest point ANY GDScript can run. If display/window/size/no_focus is a
	# project setting, the native window was already created with the flag set
	# before this line ever executes -- so if this prints true, there is no
	# GDScript-observable gap at all (unlike calling window_set_flag() at runtime,
	# which necessarily happens AFTER window creation).
	_t_init_usec = Time.get_ticks_usec()
	_no_focus_at_init = DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS)
	print("Q2_INIT_TIME_USEC=", _t_init_usec)
	print("Q2_NO_FOCUS_FLAG_AT_SCRIPT_INIT=", _no_focus_at_init)

func _ready() -> void:
	print("Q1_WINDOW_POSITION=", DisplayServer.window_get_position())
	print("Q1_WINDOW_SIZE=", DisplayServer.window_get_size())
	print("Q2_NO_FOCUS_FLAG_AT_READY=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS))
	print("Q2_BORDERLESS_FLAG_AT_READY=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS))
	print("Q2_WINDOW_IS_FOCUSED=", DisplayServer.window_is_focused())
	print("Q4_NATIVE_HANDLE=", DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE))

	_draw_test_pattern()

	# Let rendering actually happen before reading pixels back.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	_verify_and_report()

	get_tree().quit()

func _draw_test_pattern() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var half: Vector2 = vp_size / 2.0

	var tl := ColorRect.new()
	tl.color = RED
	tl.position = Vector2(0, 0)
	tl.size = half
	add_child(tl)

	var tr := ColorRect.new()
	tr.color = GREEN
	tr.position = Vector2(half.x, 0)
	tr.size = half
	add_child(tr)

	var bl := ColorRect.new()
	bl.color = BLUE
	bl.position = Vector2(0, half.y)
	bl.size = half
	add_child(bl)

	var br := ColorRect.new()
	br.color = YELLOW
	br.position = half
	br.size = half
	add_child(br)

	# Corner markers, 2x2px, drawn after (on top of) the quadrants.
	var corners: Array[Vector2] = [
		Vector2(0, 0),
		Vector2(vp_size.x - 2, 0),
		Vector2(0, vp_size.y - 2),
		Vector2(vp_size.x - 2, vp_size.y - 2),
	]
	for c in corners:
		var m := ColorRect.new()
		m.color = MARKER
		m.position = c
		m.size = Vector2(2, 2)
		add_child(m)

func _verify_and_report() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		print("Q3_RESULT=FAIL image_is_null")
		return

	var vp_size: Vector2 = get_viewport_rect().size
	var checks := [
		{"name": "TL_quadrant_center", "pos": Vector2i(int(vp_size.x * 0.25), int(vp_size.y * 0.25)), "expect": RED},
		{"name": "TR_quadrant_center", "pos": Vector2i(int(vp_size.x * 0.75), int(vp_size.y * 0.25)), "expect": GREEN},
		{"name": "BL_quadrant_center", "pos": Vector2i(int(vp_size.x * 0.25), int(vp_size.y * 0.75)), "expect": BLUE},
		{"name": "BR_quadrant_center", "pos": Vector2i(int(vp_size.x * 0.75), int(vp_size.y * 0.75)), "expect": YELLOW},
		{"name": "corner_TL_marker", "pos": Vector2i(0, 0), "expect": MARKER},
		{"name": "corner_TR_marker", "pos": Vector2i(int(vp_size.x) - 1, 0), "expect": MARKER},
		{"name": "corner_BL_marker", "pos": Vector2i(0, int(vp_size.y) - 1), "expect": MARKER},
		{"name": "corner_BR_marker", "pos": Vector2i(int(vp_size.x) - 1, int(vp_size.y) - 1), "expect": MARKER},
	]

	var all_pass := true
	for chk in checks:
		var p: Vector2i = chk["pos"]
		var expect: Color = chk["expect"]
		var actual: Color = img.get_pixel(p.x, p.y)
		var ok: bool = actual.is_equal_approx(expect)
		if not ok:
			all_pass = false
		print("Q3_CHECK name=", chk["name"], " pos=", p, " expect=", expect, " actual=", actual, " pass=", ok)

	print("Q3_RESULT=", "PASS" if all_pass else "FAIL")

	var save_path := "res://probe_screenshot.png"
	var err := img.save_png(save_path)
	print("Q3_SAVE_PNG_ERR=", err, " path=", ProjectSettings.globalize_path(save_path))
