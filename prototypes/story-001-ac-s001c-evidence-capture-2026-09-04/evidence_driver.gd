extends Node
## Throwaway AC-S001-c evidence capture driver.
##
## Loads the REAL production scene (res://src/ui/battle/BattleScreen.tscn)
## as a child of the root Window — not a copy, not a re-implementation — and
## captures the actual rendered frame at 2560x1440 after the project's real
## project.godot (window/stretch/mode="disabled") took effect, to prove
## AC-S001-c: the captured image size equals the WINDOW size (2560x1440),
## not the old canvas_items-mode inner-fit rectangle (2400x1350).
##
## Run via: godot --path . <this scene>.tscn (overrides run/main_scene for
## this one invocation only — does not touch project.godot). Non-headless
## (real GPU window) — headless has no render target to capture, per
## .claude/docs/coding-standards.md.
##
## Per that same file's Screenshot Evidence Rules: this checks dimensions,
## multi-point sampling (>=3 distinct colors among 12 points), dominant-color
## share (<=80%), AND saves the PNG for a human to actually open and confirm
## — the checks are a filter, not a substitute for that last step.

const OUTPUT_PATH: String = "res://production/qa/evidence/screen-scaling-2k-window-capture-2026-09-04.png"
const TARGET_SIZE: Vector2i = Vector2i(2560, 1440)


func _ready() -> void:
	# root is still busy setting up ITS OWN children (this driver included)
	# during this callback — a synchronous add_child() on root here fails
	# with "Parent node is busy setting up children" (confirmed by hitting it
	# live on the first run of this script). Deferring one frame is the fix
	# the engine's own error message recommends.
	await get_tree().process_frame
	var battle_scene: Node = load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	get_tree().root.add_child(battle_scene)
	await get_tree().process_frame

	await _resize_and_settle(TARGET_SIZE)

	var img: Image = get_viewport().get_texture().get_image()
	var actual_size: Vector2i = img.get_size()
	var size_matches: bool = actual_size == TARGET_SIZE

	print("=== AC-S001-c evidence capture ===")
	print("target window size = ", TARGET_SIZE)
	print("captured image size = ", actual_size)
	print("AC-S001-c (captured size == window size, not the old 2400x1350 canvas_items fit) = ", size_matches)

	# Multi-point sampling — coding-standards.md Screenshot Evidence Rules #2.
	var sample_points: Array[Vector2i] = []
	for i in range(4):
		for j in range(3):
			sample_points.append(Vector2i(
				int((float(i) + 0.5) / 4.0 * actual_size.x),
				int((float(j) + 0.5) / 3.0 * actual_size.y)
			))
	var color_counts: Dictionary = {}
	for p: Vector2i in sample_points:
		var c: Color = img.get_pixelv(p)
		var key: String = c.to_html(false)
		color_counts[key] = color_counts.get(key, 0) + 1
	print("12-point sample distinct colors = ", color_counts.size(), " (rule requires >= 3)")

	# Dominant color share over the FULL captured image — rule #3.
	var total_pixels: int = actual_size.x * actual_size.y
	var histogram: Dictionary = {}
	var step: int = 4  # sample every 4th pixel in each axis for speed; still thousands of samples
	var sampled_total: int = 0
	for y in range(0, actual_size.y, step):
		for x in range(0, actual_size.x, step):
			var c: Color = img.get_pixel(x, y)
			var key: String = c.to_html(false)
			histogram[key] = histogram.get(key, 0) + 1
			sampled_total += 1
	var dominant_count: int = 0
	for key: String in histogram:
		if histogram[key] > dominant_count:
			dominant_count = histogram[key]
	var dominant_share: float = float(dominant_count) / float(sampled_total)
	print("dominant color share (subsampled every %dpx) = %.4f (rule requires <= 0.80)" % [step, dominant_share])

	var dir_err: int = DirAccess.make_dir_recursive_absolute(OUTPUT_PATH.get_base_dir())
	print("ensure output dir exists, err=", dir_err, " (0 or ERR_ALREADY_EXISTS(38) both fine)")
	var save_err: int = img.save_png(OUTPUT_PATH)
	print("save_png(", OUTPUT_PATH, ") err=", save_err, " (0 == OK)")

	get_tree().quit(0 if (size_matches and save_err == 0) else 1)


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for i in range(10):
		await get_tree().process_frame
