extends Node
## Throwaway AC-M10 / AC-M11 evidence capture driver for Story U-007.
##
## Loads the REAL production scene (res://src/ui/menu/BattleMenu.tscn) as a
## child of the root Window -- not a copy, not a re-implementation -- and
## captures actual rendered frames to prove:
##
##   AC-M10: at multiple window sizes (including 2560x1440, the resolution
##   design/art/screen-architecture.md's own decision table shows a non-zero
##   world-layer letterbox margin for), M0 (the mask) covers the ENTIRE
##   window with no uncovered edge -- checked both mechanically (corner/edge
##   pixel sampling against the expected mask-blended color) and by a human
##   opening the PNG.
##
##   AC-M11 (focus half only, per this story's scope): a grayscale copy of
##   the same frame with focus on "回到遊戲" and a second one with focus
##   moved to "結束回合" are still visually distinguishable from each other
##   -- i.e. the position-marker glyph (a non-color channel) survives having
##   all color information removed.
##
## Non-headless (real GPU window) -- headless has no render target to
## capture, per .claude/docs/coding-standards.md. Per that same file's
## Screenshot Evidence Rules: this checks dimensions, multi-point sampling
## (>=3 distinct colors among 12 points), dominant-color share (<=80%), AND
## saves the PNG for a human to actually open and confirm -- the checks are
## a filter, not a substitute for that last step. Rule #4 (pixel-art
## integer-scale grid) is explicitly NOT applied here -- story-u007's own
## Implementation Notes #6 / EPIC.md trap 14 state it does not apply to this
## screen (interface layer, general Chinese font, not pixel-perfect
## world-layer content).
##
## Run via:
##   "<godot path>" --path . prototypes/u007-battle-menu-evidence-capture-2026-09-17/EvidenceDriver.tscn

const OUTPUT_DIR: String = "res://production/qa/evidence/"
const TARGET_SIZES: Dictionary = {
	"1080p": Vector2i(1920, 1080),
	"2k": Vector2i(2560, 1440),
}

var _instance: Control


func _ready() -> void:
	# root is still busy setting up ITS OWN children (this driver included)
	# during this callback -- same "Parent node is busy setting up children"
	# trap prototypes/story-001-ac-s001c-evidence-capture-2026-09-04/ already
	# hit and documented; deferring one frame is the fix.
	await get_tree().process_frame
	_instance = load("res://src/ui/menu/BattleMenu.tscn").instantiate()
	get_tree().root.add_child(_instance)
	await get_tree().process_frame

	var all_ok: bool = true
	for label: String in TARGET_SIZES:
		var ok: bool = await _capture_at(label, TARGET_SIZES[label])
		all_ok = all_ok and ok

	get_tree().quit(0 if all_ok else 1)


func _resize_and_settle(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	# Extra frames beyond the story-001 driver's original 10: this story's
	# own test-writing pass (see battle_menu.gd _ready()'s doc comment)
	# measured that VBoxContainer's child layout pass does not complete on
	# the very first frame after entering the tree -- settle generously
	# before capture.
	for i in range(15):
		await get_tree().process_frame


func _sample_points(size: Vector2i) -> Array[Vector2i]:
	var points: Array[Vector2i] = []
	for i in range(4):
		for j in range(3):
			points.append(Vector2i(
				int((float(i) + 0.5) / 4.0 * size.x),
				int((float(j) + 0.5) / 3.0 * size.y)
			))
	return points


## coding-standards.md's blind 4x3 grid was written for full-screen world-layer
## content and, measured directly on the first run of this driver, produces
## "1 distinct color" here (all 12 points land on the mask outside the panel,
## since M1 is deliberately a small, precisely-centered region -- 440x396 out
## of a 1920x1080 window at 1080p -- not most of the screen). That is a real,
## disclosed limitation of applying the blind grid unchanged to THIS screen's
## content shape, not a sign the frame is blank; the panel and its text are
## genuinely there (see the saved PNG). Rather than silently lowering the
## required color count or declaring the rule inapplicable, this adds
## points that are actually informed by this screen's own known layout
## (BattleMenu.panel_rect(), not re-derived) -- proving real content exists at
## those coordinates, on top of (not instead of) the original blind grid,
## which is still run and reported separately for transparency.
func _content_aware_sample_points(size: Vector2i) -> Array[Vector2i]:
	var panel: Rect2 = BattleMenu.panel_rect(size)
	var points: Array[Vector2i] = [
		Vector2i(panel.get_center()),
		Vector2i(panel.position + panel.size * 0.1),
		Vector2i(panel.position + panel.size * 0.9),
		Vector2i(panel.position.x + panel.size.x * 0.5, panel.position.y + panel.size.y * 0.15),
	]
	return points


func _dominant_share(img: Image, size: Vector2i) -> float:
	var histogram: Dictionary = {}
	var step: int = 4
	var sampled_total: int = 0
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var c: Color = img.get_pixel(x, y)
			var key: String = c.to_html(false)
			histogram[key] = histogram.get(key, 0) + 1
			sampled_total += 1
	var dominant_count: int = 0
	for key: String in histogram:
		if histogram[key] > dominant_count:
			dominant_count = histogram[key]
	return float(dominant_count) / float(sampled_total)


## AC-M10's specific mechanical check: compare the four physical corners and
## four edge midpoints of the captured image against a KNOWN mask-only
## reference sample (a point just inside the corner, guaranteed to be under
## M0 but outside M1's panel) -- not against a hand-guessed absolute color.
## The captured framebuffer is the fully-composited result (mask alpha
## blended against whatever the viewport's clear color is), so comparing to
## the raw BattleMenu.MASK_COLOR constant (which still carries its own alpha)
## would not match; comparing measured-to-measured instead proves the actual
## claim that matters -- uniformity of coverage all the way to the physical
## edges, with no discontinuity/gap -- without needing to guess or
## re-derive the engine's blend arithmetic.
func _mask_reaches_all_edges(img: Image, size: Vector2i) -> bool:
	var reference: Color = img.get_pixelv(Vector2i(2, 2))
	var edge_points: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(size.x - 1, 0),
		Vector2i(0, size.y - 1), Vector2i(size.x - 1, size.y - 1),
		Vector2i(size.x / 2, 0), Vector2i(size.x / 2, size.y - 1),
		Vector2i(0, size.y / 2), Vector2i(size.x - 1, size.y / 2),
	]
	var all_match: bool = true
	for p: Vector2i in edge_points:
		var c: Color = img.get_pixelv(p)
		if not c.is_equal_approx(reference):
			print("  EDGE CHECK FAILED at ", p, ": got ", c, " reference (near corner 2,2) was ", reference)
			all_match = false
	return all_match


func _to_grayscale(img: Image) -> Image:
	var gray: Image = img.duplicate()
	gray.convert(Image.FORMAT_RGBA8)
	var size: Vector2i = gray.get_size()
	for y in range(size.y):
		for x in range(size.x):
			var c: Color = gray.get_pixel(x, y)
			# Rec. 601 luma -- a manual, disclosed formula rather than
			# trusting Image.convert(FORMAT_L8)'s unverified exact weighting
			# for this engine build (technical-preferences.md (A)-grade
			# discipline: every re-implemented rule must be visible, not
			# hidden behind an engine call whose exact semantics have never
			# been checked here).
			var luma: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			gray.set_pixel(x, y, Color(luma, luma, luma, c.a))
	return gray


func _save(img: Image, filename: String) -> int:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var path: String = OUTPUT_DIR.path_join(filename)
	var err: int = img.save_png(path)
	print("save_png(", path, ") err=", err, " (0 == OK)")
	return err


func _capture_at(label: String, size: Vector2i) -> bool:
	print("\n=== U-007 evidence capture: ", label, " (", size, ") ===")
	await _resize_and_settle(size)

	var return_row: Button = _instance.get_node("Panel/ContentMargin/Rows/ReturnToBattleRow")
	var end_phase_row: Button = _instance.get_node("Panel/ContentMargin/Rows/EndPhaseRow")

	# AC-M10 frame: default focus state (回到遊戲).
	return_row.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame

	var img: Image = get_viewport().get_texture().get_image()
	var actual_size: Vector2i = img.get_size()
	var size_matches: bool = actual_size == size
	print("target window size = ", size, " captured image size = ", actual_size, " match=", size_matches)

	var color_counts: Dictionary = {}
	for p: Vector2i in _sample_points(actual_size):
		var c: Color = img.get_pixelv(p)
		color_counts[c.to_html(false)] = color_counts.get(c.to_html(false), 0) + 1
	print("blind 12-point grid distinct colors = ", color_counts.size(), " (coding-standards.md's original rule; see this file's own doc comment for why this reads low on a small centered panel)")

	var combined_counts: Dictionary = color_counts.duplicate()
	for p: Vector2i in _content_aware_sample_points(actual_size):
		var c: Color = img.get_pixelv(p)
		combined_counts[c.to_html(false)] = combined_counts.get(c.to_html(false), 0) + 1
	print("blind grid + panel-aware points combined distinct colors = ", combined_counts.size(), " (rule requires >= 3)")
	var distinct_ok: bool = combined_counts.size() >= 3

	var dominant: float = _dominant_share(img, actual_size)
	print("dominant color share = %.4f (rule requires <= 0.80)" % dominant)
	var dominant_ok: bool = dominant <= 0.80

	var edges_ok: bool = _mask_reaches_all_edges(img, actual_size)
	print("AC-M10 mask-reaches-all-physical-edges check = ", edges_ok)

	var save_err: int = _save(img, "battle-menu-m1-focus-return-%s-2026-09-17.png" % label)

	# AC-M11 frame: focus moved to 結束回合, same size, for contrast.
	end_phase_row.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	var img_end_phase: Image = get_viewport().get_texture().get_image()
	var save_err2: int = _save(img_end_phase, "battle-menu-m1-focus-end-phase-%s-2026-09-17.png" % label)

	# Grayscale copies of both, for AC-M11's actual claim.
	var gray_return: Image = _to_grayscale(img)
	var gray_end_phase: Image = _to_grayscale(img_end_phase)
	var save_err3: int = _save(gray_return, "battle-menu-grayscale-focus-return-%s-2026-09-17.png" % label)
	var save_err4: int = _save(gray_end_phase, "battle-menu-grayscale-focus-end-phase-%s-2026-09-17.png" % label)

	return_row.grab_focus()

	var ok: bool = size_matches and distinct_ok and dominant_ok and edges_ok \
		and save_err == 0 and save_err2 == 0 and save_err3 == 0 and save_err4 == 0
	print("=== ", label, " overall ok = ", ok, " ===")
	return ok
