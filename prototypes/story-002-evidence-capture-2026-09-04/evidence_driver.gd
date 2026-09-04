extends Node
## Throwaway AC-S002-d evidence capture driver.
##
## Loads the REAL production scene (res://src/ui/battle/BattleScreen.tscn) as
## a child of the root Window — not a copy, not a re-implementation — and
## captures the actual rendered frame at TWO window sizes (1920x1080 and
## 2560x1440, per the dispatch's AC-S002-d requirement) after HudLayoutScaler
## has applied its window-size-driven positioning, to prove the 6 previously
## degraded UILayer nodes now sit in their intended regions instead of all
## being shrunk into the top-left corner.
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

const TARGETS: Array[Dictionary] = [
	{"size": Vector2i(1920, 1080), "path": "res://production/qa/evidence/adaptive-font-scale-1080p-2026-09-04.png"},
	{"size": Vector2i(2560, 1440), "path": "res://production/qa/evidence/adaptive-font-scale-2k-2026-09-04.png"},
]


func _ready() -> void:
	# root is still busy setting up ITS OWN children (this driver included)
	# during this callback — a synchronous add_child() on root here fails
	# with "Parent node is busy setting up children" (same trap documented in
	# prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/evidence_driver.gd).
	# Deferring one frame is the fix the engine's own error message recommends.
	await get_tree().process_frame
	var battle_scene: Node = load("res://src/ui/battle/BattleScreen.tscn").instantiate()
	get_tree().root.add_child(battle_scene)
	await get_tree().process_frame

	# Force a load-failure-free run: BattleScreen._ready() only builds the
	# board/units from the real data files, which already exist in this repo
	# — nothing to fake here, this really is the same scene players see.

	var overall_ok: bool = true
	for target: Dictionary in TARGETS:
		var ok: bool = await _capture_one(target["size"], target["path"])
		overall_ok = overall_ok and ok

	get_tree().quit(0 if overall_ok else 1)


func _capture_one(size: Vector2i, out_path: String) -> bool:
	await _resize_and_settle(size)

	var img: Image = get_viewport().get_texture().get_image()
	var actual_size: Vector2i = img.get_size()
	var size_matches: bool = actual_size == size

	print("=== AC-S002-d evidence capture: ", size, " ===")
	print("target window size = ", size)
	print("captured image size = ", actual_size)
	print("dimensions match = ", size_matches)

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
	var distinct_samples: int = color_counts.size()
	print("12-point sample distinct colors = ", distinct_samples, " (rule requires >= 3)")

	# Dominant color share over the FULL captured image — rule #3.
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

	var dir_err: int = DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	print("ensure output dir exists, err=", dir_err, " (0 or ERR_ALREADY_EXISTS(38) both fine)")
	var save_err: int = img.save_png(out_path)
	print("save_png(", out_path, ") err=", save_err, " (0 == OK)")
	print("")

	var checks_passed: bool = (
		size_matches
		and distinct_samples >= 3
		and dominant_share <= 0.80
		and save_err == 0
	)
	return checks_passed


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	for i in range(15):
		await get_tree().process_frame
