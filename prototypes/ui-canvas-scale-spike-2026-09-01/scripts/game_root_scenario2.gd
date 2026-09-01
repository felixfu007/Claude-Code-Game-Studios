extends Node
## Scenario 2: `Window.content_scale_mode` forced to DISABLED (0) at runtime, discovered
## necessary by `debug_margin_probe.gd` — under the project's current default
## (`canvas_items`, matching `technical-preferences.md`), `get_viewport().get_texture()
## .get_image()` at 2560x1440 came back sized (2400, 1350), NOT (2560, 1440): the render
## target only ever covers the inner "keep+integer"-fitted rectangle. The ~160x90px margin
## band is composited by the OS window layer OUTSIDE that texture — no CanvasItem or
## CanvasLayer, regardless of `.transform`, can ever draw into it. Switching
## `content_scale_mode` to DISABLED at runtime was confirmed (same probe, round 2) to make
## the render target immediately cover the full physical window instead, and content placed
## at an absolute pixel deep inside the old margin band rendered correctly.
##
## This script re-runs the Q1 (world magnification)/Q2 (positioning)/Q3 (UI design canvas +
## font sharpness) measurements under that corrected mode, where the margin is genuinely
## reachable and can legitimately be handed to UI. Everything here is manual (no automatic
## stretch of any kind exists once content_scale_mode=DISABLED) — world sizing/position and
## the UI reference-canvas fit are both driven directly in absolute window-pixel space.

const UiCanvasTransform := preload("res://scripts/ui_canvas_transform.gd")
const PixelGridCheck := preload("res://scripts/pixel_grid_check.gd")

const MARGIN_SIZES: Array[Vector2i] = [Vector2i(2560, 1440), Vector2i(3440, 1440)]
const FONT_SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const FIXED_DESIGN_SIZE: Vector2 = Vector2(1920.0, 1080.0)

@onready var world_viewport_container: SubViewportContainer = $WorldViewportContainer
@onready var ui_reference_layer: CanvasLayer = $UIReferenceLayer

var _checker_sprite: Sprite2D


func _ready() -> void:
	var win: Window = get_tree().root
	win.set("content_scale_mode", 0) # DISABLED — confirmed by dynamic get()/set() probe

	world_viewport_container.set_anchors_preset(Control.PRESET_TOP_LEFT)

	_checker_sprite = Sprite2D.new()
	_checker_sprite.texture = PixelGridCheck.make_checkerboard_texture(11)
	_checker_sprite.centered = false
	_checker_sprite.texture_filter = 1
	_checker_sprite.scale = Vector2(2.0, 2.0)
	_checker_sprite.position = Vector2(50.0, 50.0)
	ui_reference_layer.add_child(_checker_sprite)

	await _run_measurement_pass()
	get_tree().quit()


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for i in range(5):
		await get_tree().process_frame


func _run_measurement_pass() -> void:
	print("")
	print("========== SCENARIO 2: content_scale_mode=DISABLED, fully manual ==========")

	# ---------------------------------------------------------------
	# Sanity re-check: render target now covers the FULL window at every size, including
	# the two with a nonzero margin under canvas_items.
	# ---------------------------------------------------------------
	print("")
	print("--- SANITY: captured image size == full window size at every target resolution? ---")
	for size in [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160), Vector2i(3440, 1440)]:
		await _resize_and_settle(size)
		var img: Image = get_viewport().get_texture().get_image()
		print("  window=%s  captured image size=%s  matches_full_window=%s" % [
			size, img.get_size(), img.get_size() == size
		])

	# ---------------------------------------------------------------
	# Q1 x Q2 — world magnification (4x vs 5x, both now freely chooseable, no auto pick)
	# crossed with positioning strategy, at the two sizes where 480x270 doesn't divide
	# evenly (2K and the ultrawide boundary case). All computed directly in absolute
	# window-pixel space now — no auto_scale division needed, canvas == window 1:1.
	# ---------------------------------------------------------------
	print("")
	print("--- Q1 x Q2: world magnification x positioning, margin now genuinely usable ---")
	for size in MARGIN_SIZES:
		await _resize_and_settle(size)
		var win_size: Vector2 = Vector2(size)
		for target_multiplier in [4.0, 5.0]:
			var container_size: Vector2 = Vector2(480.0, 270.0) * target_multiplier
			world_viewport_container.size = container_size
			for strategy in ["center", "edge_right", "dynamic_aspect"]:
				var pos: Vector2
				match strategy:
					"center":
						pos = (win_size - container_size) * 0.5
					"edge_right":
						pos = Vector2(win_size.x - container_size.x, (win_size.y - container_size.y) * 0.5)
					"dynamic_aspect":
						var aspect: float = win_size.x / win_size.y
						if aspect > (16.0 / 9.0) + 0.01:
							pos = Vector2(0.0, (win_size.y - container_size.y) * 0.5)
						else:
							pos = (win_size - container_size) * 0.5
				world_viewport_container.position = pos
				for i in range(3):
					await get_tree().process_frame
				var top_left: Vector2 = world_viewport_container.global_position
				var bottom_right: Vector2 = top_left + container_size
				print("  window=%s target=%.0fx strategy=%-14s rect=[%s .. %s]  margins(L,T,R,B)=(%.1f,%.1f,%.1f,%.1f)  cell_edge_px=%.1f" % [
					size, target_multiplier, strategy, top_left, bottom_right,
					top_left.x, top_left.y, win_size.x - bottom_right.x, win_size.y - bottom_right.y,
					target_multiplier * 32.0
				])

	# Spot-check: place a marker in what WOULD be dead margin under canvas_items (right of a
	# 4x-centered world at 2560x1440: world occupies x in [320,2240], so x=2300 was margin
	# under canvas_items' 5x auto-fit reasoning, and is now inside the addressable window).
	await _resize_and_settle(Vector2i(2560, 1440))
	world_viewport_container.size = Vector2(480.0, 270.0) * 4.0
	world_viewport_container.position = (Vector2(2560, 1440) - world_viewport_container.size) * 0.5
	for i in range(3):
		await get_tree().process_frame
	var spot_marker := ColorRect.new()
	spot_marker.position = Vector2(2300, 700)
	spot_marker.size = Vector2(20, 20)
	spot_marker.color = Color.RED
	ui_reference_layer.add_child(spot_marker)
	for i in range(6):
		await get_tree().process_frame
	var spot_img: Image = get_viewport().get_texture().get_image()
	print("  spot-check: marker placed at (2300,700) (dead margin under canvas_items' 5x pick) -> sampled color=%s" % [spot_img.get_pixel(2310, 710)])
	spot_marker.queue_free()

	# ---------------------------------------------------------------
	# Q3 — UI reference-canvas transform, re-derived under disabled mode. Since
	# final_transform is now always identity, `canvas_layer_transform_for()` degenerates to
	# `design_to_window_transform()` directly; kept as the same call for consistency.
	# ---------------------------------------------------------------
	print("")
	print("--- Q3: UI reference-canvas transform under disabled mode ---")
	var design_options: Dictionary = {"NATIVE": null, "FIXED_1920x1080": FIXED_DESIGN_SIZE}
	for size in FONT_SIZES:
		await _resize_and_settle(size)
		var ft: Transform2D = get_tree().root.get_final_transform()
		for option_name in design_options:
			var design_size: Vector2 = design_options[option_name] if design_options[option_name] != null else Vector2(size)
			var layer_transform: Transform2D = UiCanvasTransform.canvas_layer_transform_for(design_size, Vector2(size), ft)
			print("  window=%s option=%-16s design_size=%s  layer.transform scale=%.4f offset=%s  is_identity=%s" % [
				size, option_name, design_size, layer_transform.get_scale().x, layer_transform.get_origin(),
				layer_transform.is_equal_approx(Transform2D.IDENTITY)
			])

	# ---------------------------------------------------------------
	# Font sharpness (Cubic-11 stand-in), re-run clean (no margin exclusion possible now).
	# ---------------------------------------------------------------
	print("")
	print("--- Font sharpness re-check (2x-scaled 11x11 checkerboard), disabled mode ---")
	for size in FONT_SIZES:
		await _resize_and_settle(size)
		var ft: Transform2D = get_tree().root.get_final_transform()
		for option_name in design_options:
			var design_size: Vector2 = design_options[option_name] if design_options[option_name] != null else Vector2(size)
			var d2w: Transform2D = UiCanvasTransform.design_to_window_transform(design_size, Vector2(size))
			ui_reference_layer.transform = UiCanvasTransform.canvas_layer_transform_for(design_size, Vector2(size), ft)
			for i in range(6):
				await get_tree().process_frame

			var combined_scale: float = d2w.get_scale().x * _checker_sprite.scale.x
			var is_integer: bool = absf(combined_scale - roundf(combined_scale)) < 0.0005
			var sprite_topleft: Vector2 = d2w.get_origin() + d2w.get_scale() * _checker_sprite.position
			var img: Image = get_viewport().get_texture().get_image()
			var sample_x: int = int(floor(sprite_topleft.x))
			var sample_y: int = int(floor(sprite_topleft.y + combined_scale * 5.5))
			var sample_width: int = int(ceil(combined_scale * 11.0)) + 4
			var runs: Array = PixelGridCheck.measure_row_run_lengths(img, sample_x, sample_y, sample_width)
			var clean: bool = PixelGridCheck.is_grid_clean(runs)

			print("  window=%s option=%-16s combined_2x_scale=%.4f  is_integer=%s  grid_clean(measured)=%s  runs=%s" % [
				size, option_name, combined_scale, is_integer, clean, runs
			])

	print("")
	print("========== END SCENARIO 2 ==========")
