extends Node
## One-off debug probe (round 2): round 1 confirmed the captured viewport image at
## 2560x1440 is only (2400,1350) — i.e. `get_viewport().get_texture().get_image()` only
## ever contains the INNER "keep"-fitted rectangle, never the letterbox margin, regardless
## of what any CanvasLayer's `.transform` is set to. This round checks whether switching
## `Window.content_scale_mode` to disabled at runtime makes the render target cover the
## full physical window instead — i.e. whether the margin is a stretch-mode artifact that
## goes away without it, or something deeper.

@onready var ui_layer: CanvasLayer = $UILayer


func _probe(label: String) -> void:
	for i in range(6):
		await get_tree().process_frame
	var ft: Transform2D = get_tree().root.get_final_transform()
	var img: Image = get_viewport().get_texture().get_image()
	print("[%s] final_transform scale=%s offset=%s | DisplayServer size=%s | captured image size=%s" % [
		label, ft.get_scale(), ft.get_origin(), DisplayServer.window_get_size(), img.get_size()
	])


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(2560, 1440))
	await _probe("canvas_items (project default), 2560x1440")

	var win: Window = get_tree().root
	var mode_probe: Variant = win.get("content_scale_mode")
	print("content_scale_mode current value (enum int): ", mode_probe)

	# Try disabled (enum value 0 per Godot 4 Window.ContentScaleMode: DISABLED=0,
	# CANVAS_ITEMS=1, VIEWPORT=2). Confirmed via this dynamic set() rather than assumed.
	win.set("content_scale_mode", 0)
	await _probe("content_scale_mode set to 0 (expected DISABLED), 2560x1440")

	# Also re-check the world's own container-driven pixel scale in this mode, and whether
	# a CanvasLayer transform can now legitimately reach the full window, by placing a
	# marker at literal window pixel (2500, 1400) — deep inside what used to be margin.
	ui_layer.transform = Transform2D.IDENTITY
	var marker := ColorRect.new()
	marker.position = Vector2(2500, 1400)
	marker.size = Vector2(50, 30)
	marker.color = Color.RED
	ui_layer.add_child(marker)
	for i in range(6):
		await get_tree().process_frame
	var img2: Image = get_viewport().get_texture().get_image()
	print("marker at absolute window pixel (2500,1400)-(2550,1430), image size=%s" % [img2.get_size()])
	if img2.get_width() > 2510 and img2.get_height() > 1410:
		print("  sample at (2510,1410): ", img2.get_pixel(2510, 1410))
	else:
		print("  (2510,1410) is out of the captured image's bounds -> still unreachable")

	get_tree().quit()
