extends Node
## UI canvas-scale spike root. Print-and-quit measurement pass — no interactive mode (this
## spike is about resolution-dependent transforms, not click/board interaction, which the
## 2026-08-27 spike already covers). Runs six phases across real window sizes driven by
## `DisplayServer.window_set_size()` (the real native-driver resize path, not `Window.size`
## assignment), non-headless, waiting several `process_frame`s per size before reading
## anything back.

const UiCanvasTransform := preload("res://scripts/ui_canvas_transform.gd")
const PixelGridCheck := preload("res://scripts/pixel_grid_check.gd")

const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),  # 1080p
	Vector2i(2560, 1440),  # 2K / QHD — the odd one out, not an exact multiple of 480x270
	Vector2i(3840, 2160),  # 4K / UHD
	Vector2i(3440, 1440),  # ultrawide 21:9 boundary case
]

const FIXED_DESIGN_SIZE: Vector2 = Vector2(1920.0, 1080.0)

@onready var world_viewport_container: SubViewportContainer = $WorldViewportContainer
@onready var world_viewport: SubViewport = $WorldViewportContainer/WorldViewport
@onready var ui_reference_layer: CanvasLayer = $UIReferenceLayer

var _cursor_layer_sim: CanvasLayer
var _checker_sprite: Sprite2D


func _ready() -> void:
	_cursor_layer_sim = get_node("/root/CursorLayerSim")
	_checker_sprite = Sprite2D.new()
	_checker_sprite.name = "CheckerSpriteCubic11Stand-in"
	_checker_sprite.texture = PixelGridCheck.make_checkerboard_texture(11)
	_checker_sprite.centered = false
	_checker_sprite.texture_filter = 1  # CanvasItem.TEXTURE_FILTER_NEAREST, explicit
	_checker_sprite.scale = Vector2(2.0, 2.0)  # "放大 2 倍使用" (art-direction.md 第五節)
	_checker_sprite.position = Vector2(50.0, 50.0)
	ui_reference_layer.add_child(_checker_sprite)

	await _run_measurement_pass()
	get_tree().quit()


func _get_final_transform() -> Transform2D:
	return get_tree().root.get_final_transform()


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for i in range(5):
		await get_tree().process_frame


func _run_measurement_pass() -> void:
	print("")
	print("========== UI CANVAS SCALE MEASUREMENT PASS ==========")

	# ---------------------------------------------------------------
	# Phase A — auto full-canvas world stretch (default anchors, root type Node — the
	# 2026-08-27 spike's confirmed-working shape, no manual-size workaround needed here).
	# ---------------------------------------------------------------
	print("")
	print("--- PHASE A: auto integer stretch scale per target resolution (world layer) ---")
	var auto_scale_by_size: Dictionary = {}
	for size in WINDOW_SIZES:
		await _resize_and_settle(size)
		var ft: Transform2D = _get_final_transform()
		var scale: float = ft.get_scale().x
		auto_scale_by_size[size] = scale
		print("  window=%s  WorldViewportContainer.size=%s  get_final_transform scale=%.4f offset=%s" % [
			size, world_viewport_container.size, scale, ft.get_origin()
		])

	# ---------------------------------------------------------------
	# Phase B — does Window.content_scale_factor override the auto integer pick? Probed at
	# 2560x1440 (auto scale 5) only. Uses dynamic get()/set() rather than typed property
	# access, because this project's engine-reference docs do not document this API for
	# 4.7.1 and this agent's training data confidence on it post-cutoff is not high enough
	# to risk a parse-time property-name error.
	# ---------------------------------------------------------------
	print("")
	print("--- PHASE B: does Window.content_scale_factor override the auto integer pick? ---")
	await _resize_and_settle(Vector2i(2560, 1440))
	var win: Window = get_tree().root
	var probe_value: Variant = win.get("content_scale_factor")
	if probe_value == null:
		print("  content_scale_factor: property NOT FOUND via get() on Window in this engine build — cannot probe")
	else:
		var original: float = probe_value
		print("  content_scale_factor property exists, default=%s" % probe_value)
		for factor in [0.8, 0.75, 1.25]:
			win.set("content_scale_factor", factor)
			for i in range(5):
				await get_tree().process_frame
			var ft2: Transform2D = _get_final_transform()
			print("  content_scale_factor=%.2f -> get_final_transform scale=%.4f offset=%s" % [
				factor, ft2.get_scale().x, ft2.get_origin()
			])
		win.set("content_scale_factor", original)
		for i in range(5):
			await get_tree().process_frame

	# ---------------------------------------------------------------
	# Phase C — manual world-magnification override (Q1: 4x vs auto-5x at 2K) crossed with
	# three container-positioning strategies (Q2). Clears WorldViewportContainer's anchors
	# to PRESET_TOP_LEFT first so manual size/position isn't fought by the anchor system.
	# ---------------------------------------------------------------
	print("")
	print("--- PHASE C: manual world magnification (Q1) x positioning strategy (Q2) ---")
	for size in WINDOW_SIZES:
		await _resize_and_settle(size)
		var ft: Transform2D = _get_final_transform()
		var auto_scale: float = ft.get_scale().x
		var target_multiplier: float = 4.0 if auto_scale > 4.0 else auto_scale
		var container_logical_size: Vector2 = Vector2(480.0, 270.0) * (target_multiplier / auto_scale)

		world_viewport_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
		world_viewport_container.size = container_logical_size

		var win_size: Vector2 = Vector2(size)
		var canvas_size: Vector2 = win_size  # base-canvas extent in canvas units == window size / auto_scale, but easier: use final_transform directly below

		for strategy in ["center", "edge_right", "dynamic_aspect"]:
			var canvas_pos: Vector2
			match strategy:
				"center":
					var full_canvas: Vector2 = win_size / auto_scale
					canvas_pos = (full_canvas - container_logical_size) * 0.5
				"edge_right":
					var full_canvas2: Vector2 = win_size / auto_scale
					canvas_pos = Vector2(full_canvas2.x - container_logical_size.x, (full_canvas2.y - container_logical_size.y) * 0.5)
				"dynamic_aspect":
					var full_canvas3: Vector2 = win_size / auto_scale
					var aspect: float = win_size.x / win_size.y
					if aspect > (16.0 / 9.0) + 0.01:
						canvas_pos = Vector2(0.0, (full_canvas3.y - container_logical_size.y) * 0.5)
					else:
						canvas_pos = (full_canvas3 - container_logical_size) * 0.5

			world_viewport_container.position = canvas_pos
			for i in range(3):
				await get_tree().process_frame

			var ft_now: Transform2D = _get_final_transform()
			var top_left_screen: Vector2 = ft_now * world_viewport_container.global_position
			var bottom_right_screen: Vector2 = ft_now * (world_viewport_container.global_position + world_viewport_container.size)
			var cell_edge_px: float = ft_now.get_scale().x * 32.0
			print("  window=%s strategy=%-14s target=%.1fx  screen_rect=[%s .. %s]  margins(L,T,R,B)=(%.1f,%.1f,%.1f,%.1f)  cell_edge_px=%.4f" % [
				size, strategy, target_multiplier, top_left_screen, bottom_right_screen,
				top_left_screen.x, top_left_screen.y,
				win_size.x - bottom_right_screen.x, win_size.y - bottom_right_screen.y,
				cell_edge_px
			])

	# Restore full-canvas anchors for the remaining phases (D/E/F assume the default shape).
	world_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_viewport_container.anchor_right = 1.0
	world_viewport_container.anchor_bottom = 1.0
	world_viewport_container.position = Vector2.ZERO

	# ---------------------------------------------------------------
	# Phase D — UI reference-canvas counter-transform (Q3): NATIVE (design=window, 1:1) vs
	# FIXED 1920x1080. Assigns UIReferenceLayer.transform for real, reads the property back.
	# ---------------------------------------------------------------
	print("")
	print("--- PHASE D: UI reference-canvas CanvasLayer.transform, per Q3 option ---")
	var design_options: Dictionary = {"NATIVE": null, "FIXED_1920x1080": FIXED_DESIGN_SIZE}
	for size in WINDOW_SIZES:
		await _resize_and_settle(size)
		var ft: Transform2D = _get_final_transform()
		for option_name in design_options:
			var design_size: Vector2 = design_options[option_name] if design_options[option_name] != null else Vector2(size)
			var layer_transform: Transform2D = UiCanvasTransform.canvas_layer_transform_for(design_size, Vector2(size), ft)
			ui_reference_layer.transform = layer_transform
			for i in range(2):
				await get_tree().process_frame
			var read_back: Transform2D = ui_reference_layer.transform
			var is_identity: bool = read_back.is_equal_approx(Transform2D.IDENTITY)
			print("  window=%s option=%-16s design_size=%s  layer.transform scale=%.4f offset=%s  is_identity=%s" % [
				size, option_name, design_size, read_back.get_scale().x, read_back.get_origin(), is_identity
			])

	# ---------------------------------------------------------------
	# Phase E — CursorLayerSim identity check + round-trip + "what if it shared the UI
	# reference layer's transform instead" deviation cost.
	# ---------------------------------------------------------------
	print("")
	print("--- PHASE E: CursorLayerSim identity check, get_viewport() root claim, deviation cost ---")
	for size in WINDOW_SIZES:
		await _resize_and_settle(size)
		var ft: Transform2D = _get_final_transform()

		var cl_transform: Transform2D = _cursor_layer_sim.transform
		var cl_is_identity: bool = cl_transform.is_equal_approx(Transform2D.IDENTITY)
		var viewport_is_root: bool = _cursor_layer_sim.get_viewport() == get_tree().root

		# Set UIReferenceLayer to the FIXED_1920x1080 option for the "what if shared" test.
		var wrong_layer_transform: Transform2D = UiCanvasTransform.canvas_layer_transform_for(FIXED_DESIGN_SIZE, Vector2(size), ft)
		ui_reference_layer.transform = wrong_layer_transform
		for i in range(2):
			await get_tree().process_frame

		var test_points: Array[Vector2] = [
			Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), Vector2(size),
			Vector2(size) * 0.5,
		]
		print("  window=%s  CursorLayerSim.transform=identity:%s  get_viewport()==root:%s" % [size, cl_is_identity, viewport_is_root])
		for test_point in test_points:
			# Correct path: identity layer. canvas_pos = ft^-1 * window_pos; marker.position
			# = canvas_pos; final screen pos = ft * (cl_transform * marker.position).
			var canvas_pos: Vector2 = ft.affine_inverse() * test_point
			var correct_screen_pos: Vector2 = ft * (cl_transform * canvas_pos)
			var correct_error: float = correct_screen_pos.distance_to(test_point)

			# Wrong path: same canvas_pos value, but drawn as if it were a LOCAL position
			# under the non-identity UI reference layer instead of the identity cursor layer.
			var wrong_screen_pos: Vector2 = ft * (wrong_layer_transform * canvas_pos)
			var wrong_error: float = wrong_screen_pos.distance_to(test_point)

			print("    test_point=%-18s correct_screen=%-18s err=%.4fpx | if-shared-with-UI-layer screen=%-18s err=%.2fpx" % [
				test_point, correct_screen_pos, correct_error, wrong_screen_pos, wrong_error
			])

	# Restore UIReferenceLayer to identity before phase F re-derives it per option.
	ui_reference_layer.transform = Transform2D.IDENTITY

	# ---------------------------------------------------------------
	# Phase F — Cubic-11-stand-in pixel-grid integrity at "2x" under each Q3 option, at
	# 1080p / 2K / 4K (skips the ultrawide case — aspect doesn't change this measurement,
	# only overall scale does, which the three canonical sizes already cover).
	# ---------------------------------------------------------------
	print("")
	print("--- PHASE F: 2x-scaled 11x11 checkerboard (Cubic-11 stand-in) pixel-grid integrity ---")
	var font_test_sizes: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
	for size in font_test_sizes:
		await _resize_and_settle(size)
		var ft: Transform2D = _get_final_transform()
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

			print("  window=%s option=%-16s design_to_window_scale=%.4f  combined_2x_scale=%.4f  is_integer=%s  grid_clean(measured)=%s  runs=%s" % [
				size, option_name, d2w.get_scale().x, combined_scale, is_integer, clean, runs
			])

	print("")
	print("========== END MEASUREMENT PASS ==========")
