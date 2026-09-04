extends Node
## Verification driver. Resizes the real window to the four AC-S001 target
## resolutions and checks:
## 1. ProjectSettings behavior for aspect/scale_mode keys removed from
##    project.godot entirely (does get_setting() return an engine default,
##    or something else?).
## 2. WorldViewport.size stays exactly (480, 270) at every resolution even
##    though WorldViewportContainer is resized/repositioned and given a
##    non-1 stretch_shrink — this combination (manual position+size AND
##    stretch_shrink>1 together, under content_scale_mode=DISABLED) is not
##    covered by either the 2026-08-27 or 2026-09-01 spikes.
## 3. Content painted in WorldViewport-local (480x270) space actually lands
##    on screen at the mathematically expected, correctly-scaled, correctly-
##    centered position, sampled from a real captured frame.
## 4. WorldLayout's own transform round-trips (canvas -> window -> canvas).

const WorldLayout := preload("res://scripts/world_layout.gd")

const SIZES: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2K": Vector2i(2560, 1440),
	"4K": Vector2i(3840, 2160),
	"ultrawide": Vector2i(3440, 1440),
}

@onready var world_container: SubViewportContainer = $WorldViewportContainer
@onready var world_viewport: SubViewport = $WorldViewportContainer/WorldViewport


func _ready() -> void:
	print("")
	print("--- ProjectSettings removed-key probe ---")
	print("aspect has_setting=%s value=%s" % [
		ProjectSettings.has_setting("display/window/stretch/aspect"),
		ProjectSettings.get_setting("display/window/stretch/aspect")
	])
	print("scale_mode has_setting=%s value=%s" % [
		ProjectSettings.has_setting("display/window/stretch/scale_mode"),
		ProjectSettings.get_setting("display/window/stretch/scale_mode")
	])
	print("content_scale_mode (dynamic get on root Window) = ", get_tree().root.get("content_scale_mode"))

	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(480, 270)
	bg.color = Color(0, 1, 0)
	world_viewport.add_child(bg)

	var top_left_marker := ColorRect.new()
	top_left_marker.position = Vector2(0, 0)
	top_left_marker.size = Vector2(4, 4)
	top_left_marker.color = Color(1, 0, 0)
	world_viewport.add_child(top_left_marker)

	var bottom_right_marker := ColorRect.new()
	bottom_right_marker.position = Vector2(476, 266)
	bottom_right_marker.size = Vector2(4, 4)
	bottom_right_marker.color = Color(0, 0, 1)
	world_viewport.add_child(bottom_right_marker)

	await _run_pass()
	get_tree().quit()


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for i in range(5):
		await get_tree().process_frame


func _in_image(img: Image, pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < img.get_width() and pos.y < img.get_height()


func _run_pass() -> void:
	for label: String in SIZES:
		var size: Vector2i = SIZES[label]
		await _resize_and_settle(size)

		var expected_scale: int = WorldLayout.compute_scale(size)
		var expected_rect: Rect2i = WorldLayout.compute_rect(size)

		print("")
		print("=== %s window=%s ===" % [label, size])
		print("  expected scale=%d rect=%s" % [expected_scale, expected_rect])
		print("  actual   viewport.size=%s container.global_position=%s container.size=%s stretch_shrink=%d" % [
			world_viewport.size, world_container.global_position, world_container.size,
			world_container.stretch_shrink
		])
		print("  viewport.size matches BASE 480x270 exactly = %s" % [
			world_viewport.size == Vector2i(480, 270)
		])

		var img: Image = get_viewport().get_texture().get_image()
		print("  captured image size=%s (window=%s match=%s)" % [
			img.get_size(), size, img.get_size() == Vector2i(size)
		])

		var tl_sample_pos: Vector2i = Vector2i(expected_rect.position) + Vector2i(2, 2)
		var tl_color: Color = img.get_pixelv(tl_sample_pos) if _in_image(img, tl_sample_pos) else Color(-1, -1, -1)
		print("  sample top-left marker at %s -> %s (expect ~red 1,0,0)" % [tl_sample_pos, tl_color])

		var br_local_topleft: Vector2 = Vector2(476, 266) * expected_scale
		var br_sample_pos: Vector2i = Vector2i(expected_rect.position) + Vector2i(br_local_topleft) + Vector2i(2, 2)
		var br_color: Color = img.get_pixelv(br_sample_pos) if _in_image(img, br_sample_pos) else Color(-1, -1, -1)
		print("  sample bottom-right marker at %s -> %s (expect ~blue 0,0,1)" % [br_sample_pos, br_color])

		var mid_local: Vector2 = Vector2(240, 135) * expected_scale
		var mid_sample_pos: Vector2i = Vector2i(expected_rect.position) + Vector2i(mid_local)
		var mid_color: Color = img.get_pixelv(mid_sample_pos) if _in_image(img, mid_sample_pos) else Color(-1, -1, -1)
		print("  sample background mid at %s -> %s (expect ~green 0,1,0)" % [mid_sample_pos, mid_color])

		if expected_rect.position.x > 0:
			var margin_sample: Vector2i = Vector2i(expected_rect.position.x - 5, size.y / 2)
			var margin_color: Color = img.get_pixelv(margin_sample) if _in_image(img, margin_sample) else Color(-1, -1, -1)
			print("  sample left margin at %s -> %s (expect NOT green/red/blue)" % [margin_sample, margin_color])
		else:
			print("  (no margin at this resolution — zero-margin case, nothing to sample)")

		var c2w: Transform2D = WorldLayout.canvas_to_window_transform(size)
		var w2c: Transform2D = WorldLayout.window_to_canvas_transform(size)
		var test_points: Array[Vector2] = [Vector2(0, 0), Vector2(479, 269), Vector2(240, 135)]
		for p: Vector2 in test_points:
			var window_p: Vector2 = c2w * p
			var back: Vector2 = w2c * window_p
			print("  roundtrip canvas=%s -> window=%s -> canvas=%s (match=%s)" % [
				p, window_p, back, back.is_equal_approx(p)
			])
