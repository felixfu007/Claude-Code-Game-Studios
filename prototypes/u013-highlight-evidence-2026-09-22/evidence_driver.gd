extends Node
## Throwaway evidence capture driver for Story U-013's board_view.gd
## set_card_target_highlights() three-state highlight (legal outline / illegal
## outline+X / no mark) -- the "AC needs a real GPU frame + human eyes" item
## flagged in production/session-state/active.md's 2026-09-22 handoff table.
##
## Loads the REAL production scene (res://src/ui/battle/BoardView.tscn) as a
## child of the root Window -- not a copy, not a re-implementation -- and
## calls its real public methods (render_terrain / render_pieces /
## set_card_target_highlights) exactly as battle_screen.gd would.
##
## Non-headless (real GPU window), same command shape as
## prototypes/u007-battle-menu-evidence-capture-2026-09-17/README.md:
##   "<godot path>" --path . prototypes/u013-highlight-evidence-2026-09-22/EvidenceDriver.tscn
##
## Real terrain data (not a hand-typed fixture): assets/data/levels/vs01_terrain.txt.
##
## 🔴 3RD REVISION (2026-09-22, after 2nd coordinator review) -- SCALE/POSITION
## FIX: the 1st and 2nd revisions scaled the instance by a hardcoded, made-up
## "SCALE_FACTOR = 4" and left its position at the default (0,0) -- NEITHER
## number came from the project's actual scaling authority. technical-
## preferences.md is explicit that world-layer scale "必須呼叫
## src/ui/battle/world_layout.gd 的 compute_scale(),不得自行計算,不得複製
## 公式" ("MUST be obtained by calling world_layout.gd's compute_scale() --
## never self-computed, never a copied formula"). This revision calls
## [WorldLayout]'s real [method WorldLayout.compute_scale] / [method
## WorldLayout.compute_rect] instead, and positions the instance at the
## computed centered rect exactly as production code would. For a 1280x720
## window this yields scale=2 (NOT the old driver's invented 4), position
## =(160,90) (NOT the old driver's implicit (0,0)) -- see the printed
## "CENTERING ANSWER" line at startup for the exact numbers from THIS run.
## This was the coordinator's explicit priority item: whether the earlier
## "board looks off-center" observation was (a) a real board_view.gd/
## production defect or (b) an artifact of this throwaway driver never having
## used the real centering authority in the first place. Answer, from this
## run's own printed output: it was (b) -- this driver's own prior omission,
## not a src/ defect. src/ is unmodified either way.
##
## SCENARIO DESIGN (2nd revision after 1st coordinator review): all three
## demo cells use the IDENTICAL piece (PLAYER faction, sprite_index 0) on the
## IDENTICAL terrain tile ("." plain ground, row 0). This means any measured
## pixel difference between the three cells' highlight zones can ONLY be
## caused by set_card_target_highlights() itself, never by a difference in
## piece art or terrain.
##
## COORDINATE DISCLOSURE: the exact cells fed to set_card_target_highlights()
## are printed to stdout (see run_output.txt) -- LEGAL_CELL=(3,0),
## ILLEGAL_CELL=(5,0), NEUTRAL_CELL=(7,0), all on terrain row 0 (all "."
## plain ground per assets/data/levels/vs01_terrain.txt).
##
## OCCLUSION FINDING (1st coordinator review): board_view.gd's own documented
## layer order draws StatsLayer (HP bar + HP text panel) ABOVE
## CardTargetHighlightLayer. The HP text panel is a FULL-CELL-WIDTH box
## sitting at y=[HP_TEXT_TOP_MARGIN, HP_TEXT_TOP_MARGIN+HP_TEXT_HEIGHT) from
## the cell's top edge, which overlaps and hides the outline's top border.
## Diagnosed via prototypes/u013-highlight-evidence-2026-09-22/
## diag_scan_column.gd (a headless pixel-readback probe against an
## already-saved PNG). Fix: sample the LEFT border strip in the vertical band
## BELOW the HP text panel and ABOVE the HP bar (both real BoardView
## constants) -- board_view.gd's own geometry guarantees neither reaches
## that band.
##
## CLASSIFICATION: this driver produces TWO images with two different
## classifications per coding-standards.md's "Screenshot classification"
## section -- the crop (does not match full window -> Category C) and the
## full-window context capture (matches full window -> Category A).
##
## VALIDATE-BEFORE-WRITE (2nd coordinator review confirmed this is now
## correctly wired): production/qa/evidence/ only ever receives a file if
## ALL of that category's checks pass, independently per image, after
## retrying up to MAX_ATTEMPTS times. On exhaustion, nothing is written
## there and any stale file at that exact path is deleted.
##
## 🔴 DIAGNOSTIC COPIES (2nd coordinator review, explicit instruction): in
## ADDITION to the gated production/qa/evidence/ writes above, this revision
## ALWAYS also writes a copy of the last attempt's two images into THIS
## prototype directory (never production/qa/evidence/), with the filename
## itself stating whether Check 4 (integer-scale grid) passed or failed for
## that image. These are diagnostic material for a human to inspect while
## judging whether the still-open Check 4 finding (see run_output.txt) is a
## real board_view.gd defect or a check-applicability question -- that
## judgment is NOT made by this script. Per coding-standards.md's Category C
## Check 2 discipline ("a check that fails on a real screen does not get
## replaced by a metric ... because it looks reasonable at the time"), this
## revision does NOT invent an exclusion region to make Check 4 pass; the
## number is reported as measured, unmodified, for a human to judge.
##
## 🔴 RETRY-LOOP FINDING (2nd coordinator review flagged this explicitly):
## the 2nd revision's 5 retry attempts produced BYTE-IDENTICAL numbers
## (482 violations, 0.4594 dominant share, 4 distinct blind-sample colors)
## on every single attempt. Rendering here is deterministic and there is no
## async content (no animation, no font streaming observed across attempts)
## -- retrying the SAME static scene 5 times cannot change the outcome, only
## cost wall-clock time. This is not a defect in this driver, but it is a
## real cost future capture-tool authors should know about before assuming a
## retry loop buys anything against a check that is failing for a structural
## (non-timing) reason.

const PROD_OUTPUT_DIR: String = "res://production/qa/evidence/"
const DIAG_OUTPUT_DIR: String = "res://prototypes/u013-highlight-evidence-2026-09-22/"
const BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"
const TERRAIN_DATA_PATH: String = "res://assets/data/levels/vs01_terrain.txt"
const MAX_ATTEMPTS: int = 5
const TARGET_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)

const CROP_FILENAME: String = "u013-card-target-highlight-2026-09-22.png"
const CONTEXT_FILENAME: String = "u013-card-target-highlight-CONTEXT-full-window-2026-09-22.png"

const LEGAL_CELL: Vector2i = Vector2i(3, 0)
const ILLEGAL_CELL: Vector2i = Vector2i(5, 0)
const NEUTRAL_CELL: Vector2i = Vector2i(7, 0)

var _instance: Node2D
# Set once in _ready() from WorldLayout.compute_scale()/compute_rect() --
# NEVER computed by this file's own formula (technical-preferences.md's
# hard requirement). Every window<->local conversion below reads these two,
# not a local constant.
var _scale: int = 1
var _world_rect: Rect2i = Rect2i()


func _ready() -> void:
	await get_tree().process_frame

	DisplayServer.window_set_size(TARGET_WINDOW_SIZE)
	await get_tree().process_frame

	# ── CENTERING ANSWER (coordinator's required item #4) ──
	# Calling the project's real, sole-source-of-truth scaling authority --
	# not re-deriving the formula -- exactly as technical-preferences.md
	# requires.
	_scale = WorldLayout.compute_scale(TARGET_WINDOW_SIZE)
	_world_rect = WorldLayout.compute_rect(TARGET_WINDOW_SIZE)
	print("CENTERING ANSWER -- WorldLayout.compute_scale(", TARGET_WINDOW_SIZE, ") = ", _scale)
	print("CENTERING ANSWER -- WorldLayout.compute_rect(", TARGET_WINDOW_SIZE, ") = ", _world_rect)
	print("CENTERING ANSWER -- this means the world layer at this window size is ", _world_rect.size, " centered with margins ", _world_rect.position, " on each side (left==right and top==bottom being the definition of centered, per WorldLayout.compute_rect's own doc comment)")

	_instance = load(BOARD_VIEW_SCENE_PATH).instantiate()
	get_tree().root.add_child(_instance)
	_instance.scale = Vector2(_scale, _scale)
	_instance.position = Vector2(_world_rect.position)
	await get_tree().process_frame

	var terrain_rows: PackedStringArray = _load_terrain_rows()
	print("terrain rows loaded: ", terrain_rows.size(), " rows, first row length = ", (terrain_rows[0].length() if terrain_rows.size() > 0 else -1))
	_instance.render_terrain(terrain_rows)

	print("COORDINATE DISCLOSURE: LEGAL_CELL=", LEGAL_CELL, " ILLEGAL_CELL=", ILLEGAL_CELL, " NEUTRAL_CELL=", NEUTRAL_CELL, " (all row 0, all \".\" plain ground)")

	var pieces: Array[Dictionary] = [
		{"cell": LEGAL_CELL, "faction": "PLAYER", "sprite_index": 0, "hp": 5, "hp_max": 5, "show_hp_text": true},
		{"cell": ILLEGAL_CELL, "faction": "PLAYER", "sprite_index": 0, "hp": 5, "hp_max": 5, "show_hp_text": true},
		{"cell": NEUTRAL_CELL, "faction": "PLAYER", "sprite_index": 0, "hp": 5, "hp_max": 5, "show_hp_text": true},
	]
	_instance.render_pieces(pieces)
	var legal_cells: Array[Vector2i] = [LEGAL_CELL]
	var illegal_cells: Array[Vector2i] = [ILLEGAL_CELL]
	_instance.set_card_target_highlights(legal_cells, illegal_cells)
	# NEUTRAL_CELL deliberately appears in NEITHER array -- that IS the third
	# state (board_view.gd's own doc comment: "S2's third state... drawn as
	# nothing; absence of any mark IS that state").

	# Each of the two images is validated and gated INDEPENDENTLY for the
	# production/qa/evidence/ write -- see class doc comment.
	var attempt: int = 0
	var crop_ok: bool = false
	var context_ok: bool = false
	var crop_image: Image = null
	var context_image: Image = null
	var last_report: Dictionary = {}
	var attempts_identical: bool = true
	var first_signature: String = ""

	while attempt < MAX_ATTEMPTS and not (crop_ok and context_ok):
		attempt += 1
		for i in range(10):
			await get_tree().process_frame
		var report: Dictionary = await _run_all_checks()
		last_report = report
		var signature: String = str(report["failures"]) + "|" + str(report["diagnostics"])
		if attempt == 1:
			first_signature = signature
		elif signature != first_signature:
			attempts_identical = false
		print("=== attempt ", attempt, "/", MAX_ATTEMPTS, " -- crop_ok=", report["crop_ok"], " context_ok=", report["context_ok"], " ===")
		if not report["failures"].is_empty():
			print("  failures this attempt: ", report["failures"])
		if report["crop_ok"] and not crop_ok:
			crop_ok = true
			crop_image = report["crop_image"]
		if report["context_ok"] and not context_ok:
			context_ok = true
			context_image = report["context_image"]

	print("RETRY-LOOP FINDING: all ", attempt, " attempts produced byte-identical failures+diagnostics = ", attempts_identical, " (deterministic static scene -- see class doc comment)")

	if crop_ok:
		_save(crop_image, PROD_OUTPUT_DIR, CROP_FILENAME)
		print("VALIDATE-BEFORE-WRITE (Category C crop, production/qa/evidence/): checks passed -- file written.")
	else:
		_delete_if_exists(PROD_OUTPUT_DIR, CROP_FILENAME)
		print("VALIDATE-BEFORE-WRITE (Category C crop, production/qa/evidence/): exhausted ", MAX_ATTEMPTS, " attempts, checks never passed. Wrote nothing; deleted any stale file.")

	if context_ok:
		_save(context_image, PROD_OUTPUT_DIR, CONTEXT_FILENAME)
		print("VALIDATE-BEFORE-WRITE (Category A context, production/qa/evidence/): checks passed -- file written.")
	else:
		_delete_if_exists(PROD_OUTPUT_DIR, CONTEXT_FILENAME)
		print("VALIDATE-BEFORE-WRITE (Category A context, production/qa/evidence/): exhausted ", MAX_ATTEMPTS, " attempts, checks never passed. Wrote nothing; deleted any stale file.")

	# Diagnostic copies -- ALWAYS written, into the prototype dir, never
	# production/qa/evidence/. Uses the LAST attempt's images (available even
	# when a category never fully passed). Filename states Check 4's pass/
	# fail status explicitly per coordinator instruction.
	var crop_check4_status: String = "PASSED" if last_report.get("crop_check4_ok", false) else "FAILED"
	var context_check4_status: String = "PASSED" if last_report.get("context_check4_ok", false) else "FAILED"
	_save(last_report["crop_image"], DIAG_OUTPUT_DIR, "diagnostic-crop-2026-09-22-CHECK4-%s.png" % crop_check4_status)
	_save(last_report["context_image"], DIAG_OUTPUT_DIR, "diagnostic-context-full-window-2026-09-22-CHECK4-%s.png" % context_check4_status)
	print("DIAGNOSTIC COPIES written to ", DIAG_OUTPUT_DIR, " regardless of pass/fail (per coordinator instruction) -- NOT evidence, NOT in production/qa/evidence/.")

	print("Final (last attempt's) failure list: ", last_report.get("failures", []))
	print("Final (last attempt's) diagnostics: ", last_report.get("diagnostics", {}))
	get_tree().quit(0 if (crop_ok and context_ok) else 1)


func _load_terrain_rows() -> PackedStringArray:
	var rows: PackedStringArray = []
	var f: FileAccess = FileAccess.open(TERRAIN_DATA_PATH, FileAccess.READ)
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.length() > 0:
			rows.append(line)
	f.close()
	return rows


func _delete_if_exists(dir: String, filename: String) -> void:
	var abs_path: String = dir.path_join(filename)
	if FileAccess.file_exists(abs_path):
		var err: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(abs_path))
		print("removed stale file ", abs_path, " err=", err)


func _save(img: Image, dir: String, filename: String) -> int:
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join(filename)
	var err: int = img.save_png(path)
	print("save_png(", path, ") err=", err, " (0 == OK)")
	return err


# Bounding rect (WorldViewport-local 480x270-space pixels) over [param cells],
# computed ONLY from BoardCoords.grid_to_local()/CELL_SIZE -- the real
# production coordinate function, not re-derived -- plus a fixed local-space
# margin for visual context around the highlighted cells.
func _local_bounding_rect(cells: Array[Vector2i], margin: float) -> Rect2:
	var min_pt: Vector2 = Vector2(INF, INF)
	var max_pt: Vector2 = Vector2(-INF, -INF)
	for cell: Vector2i in cells:
		var tl: Vector2 = BoardCoords.grid_to_local(cell)
		var br: Vector2 = tl + Vector2(BoardCoords.CELL_SIZE, BoardCoords.CELL_SIZE)
		min_pt.x = min(min_pt.x, tl.x)
		min_pt.y = min(min_pt.y, tl.y)
		max_pt.x = max(max_pt.x, br.x)
		max_pt.y = max(max_pt.y, br.y)
	min_pt -= Vector2(margin, margin)
	max_pt += Vector2(margin, margin)
	return Rect2(min_pt, max_pt - min_pt)


# Local (480x270-space) point -> window-pixel point, using THIS RUN'S real
# _scale/_world_rect (from WorldLayout, never self-derived).
func _local_to_window(p: Vector2) -> Vector2:
	return p * _scale + Vector2(_world_rect.position)


# The vertical band, in WHOLE-CELL-LOCAL coordinates, that board_view.gd's
# own geometry guarantees is clear of BOTH the HP text panel (y <
# HP_TEXT_TOP_MARGIN + HP_TEXT_HEIGHT) and the HP bar (y >= CELL_SIZE -
# HP_BAR_BOTTOM_MARGIN - HP_BAR_HEIGHT, x in [6,26) of 32 -- narrower than
# the cell, so the LEFT/RIGHT outline border strips at x=[3,5) and x=[27,29)
# are never inside the bar's x-range regardless of y). All constants used
# are BoardView's own public consts -- not re-derived.
func _left_border_clear_zone_window(cell: Vector2i) -> Rect2i:
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var x0: float = cell_top_left.x + BoardView.CARD_TARGET_OUTLINE_INSET
	var x1: float = x0 + BoardView.CARD_TARGET_OUTLINE_WIDTH
	var y0: float = cell_top_left.y + BoardView.HP_TEXT_TOP_MARGIN + BoardView.HP_TEXT_HEIGHT
	var y1: float = cell_top_left.y + BoardCoords.CELL_SIZE - BoardView.HP_BAR_BOTTOM_MARGIN - BoardView.HP_BAR_HEIGHT
	var local_rect: Rect2 = Rect2(Vector2(x0, y0), Vector2(x1 - x0, y1 - y0))
	return Rect2i(
		Vector2i(_local_to_window(local_rect.position).round()),
		Vector2i((local_rect.size * _scale).round())
	)


func _max_brightness_in_rect(img: Image, rect: Rect2i) -> float:
	var best: float = -1.0
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var c: Color = img.get_pixel(x, y)
			var brightness: float = (c.r + c.g + c.b) / 3.0
			if brightness > best:
				best = brightness
	return best


# Category A / C shared: pixel-art integer-scale grid integrity, restricted
# to [param exclude_rects] (window-space rects to SKIP -- the HP text
# Label's antialiased glyphs, same documented exception coding-standards.md
# already carves out for this project's antialiased Chinese UI font). This
# measures against the actual _scale used THIS run (from WorldLayout), never
# a hardcoded factor. 🔴 Per coordinator instruction, this function does NOT
# exclude the illegal-mark's diagonal-line region -- the raw number is
# reported as measured, for a human to judge whether it is a real defect or
# a check-applicability question. Blocks whose window-space origin falls
# outside the image bounds are skipped (relevant when _world_rect leaves a
# non-board margin at the image edge that is not exactly divisible by
# _scale).
func _integer_grid_violations(img: Image, exclude_rects: Array[Rect2i]) -> Dictionary:
	var size: Vector2i = img.get_size()
	var violations: int = 0
	var total_blocks: int = 0
	var blocks_x: int = size.x / _scale
	var blocks_y: int = size.y / _scale
	for by in range(blocks_y):
		for bx in range(blocks_x):
			var block_rect: Rect2i = Rect2i(bx * _scale, by * _scale, _scale, _scale)
			var excluded: bool = false
			for ex: Rect2i in exclude_rects:
				if ex.intersects(block_rect):
					excluded = true
					break
			if excluded:
				continue
			total_blocks += 1
			var origin: Color = img.get_pixel(bx * _scale, by * _scale)
			for dy in range(_scale):
				for dx in range(_scale):
					var c: Color = img.get_pixel(bx * _scale + dx, by * _scale + dy)
					if not c.is_equal_approx(origin):
						violations += 1
						break
	return {"violations": violations, "total_blocks": total_blocks}


func _hp_text_panel_rect_window(cell: Vector2i) -> Rect2i:
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var local_rect: Rect2 = Rect2(
		Vector2(cell_top_left.x, cell_top_left.y + BoardView.HP_TEXT_TOP_MARGIN),
		Vector2(BoardCoords.CELL_SIZE, BoardView.HP_TEXT_HEIGHT)
	)
	return Rect2i(
		Vector2i(_local_to_window(local_rect.position).round()),
		Vector2i((local_rect.size * _scale).round())
	)


func _run_all_checks() -> Dictionary:
	var failures_a: Array[String] = []
	var failures_c: Array[String] = []
	var diagnostics: Dictionary = {}

	await get_tree().process_frame
	var full_img: Image = get_viewport().get_texture().get_image()
	var full_size: Vector2i = full_img.get_size()

	# ============================================================
	# Category A checks -- full-window CONTEXT image
	# ============================================================
	print("Category A Check 1 -- dimensions: actual=", full_size, " target=", TARGET_WINDOW_SIZE)
	if full_size != TARGET_WINDOW_SIZE:
		failures_a.append("Category A Check 1 FAILED: dimensions %s != target %s" % [full_size, TARGET_WINDOW_SIZE])

	var blind_points: Array[Vector2i] = []
	for i in range(4):
		for j in range(3):
			blind_points.append(Vector2i(
				int((float(i) + 0.5) / 4.0 * full_size.x),
				int((float(j) + 0.5) / 3.0 * full_size.y)
			))
	var blind_colors: Dictionary = {}
	for p: Vector2i in blind_points:
		var c: Color = full_img.get_pixelv(p)
		blind_colors[c.to_html(false)] = true
	print("Category A Check 2 -- blind 12-point distinct colors = ", blind_colors.size(), " (rule requires >= 3)")
	if blind_colors.size() < 3:
		failures_a.append("Category A Check 2 FAILED: blind 12-point distinct colors = %d < 3" % blind_colors.size())

	var histogram: Dictionary = {}
	var sampled_total: int = 0
	for y in range(0, full_size.y, 4):
		for x in range(0, full_size.x, 4):
			var key: String = full_img.get_pixel(x, y).to_html(false)
			histogram[key] = histogram.get(key, 0) + 1
			sampled_total += 1
	var dominant_count: int = 0
	for key: String in histogram:
		if histogram[key] > dominant_count:
			dominant_count = histogram[key]
	var dominant_ratio: float = float(dominant_count) / float(sampled_total)
	print("Category A Check 3 -- dominant color share = %.4f (rule requires <= 0.80)" % dominant_ratio)
	if dominant_ratio > 0.80:
		failures_a.append("Category A Check 3 FAILED: dominant share %.4f > 0.80" % dominant_ratio)

	var context_exclude_rects: Array[Rect2i] = [
		_hp_text_panel_rect_window(LEGAL_CELL),
		_hp_text_panel_rect_window(ILLEGAL_CELL),
		_hp_text_panel_rect_window(NEUTRAL_CELL),
	]
	var context_grid: Dictionary = _integer_grid_violations(full_img, context_exclude_rects)
	print("Category A Check 4 -- integer-scale grid violations (world layer only, HP text panels excluded per coding-standards.md's antialiased-text carve-out; illegal-mark diagonal region NOT excluded, per coordinator instruction) = ", context_grid["violations"], " / ", context_grid["total_blocks"])
	var context_check4_ok: bool = context_grid["violations"] == 0
	if not context_check4_ok:
		failures_a.append("Category A Check 4 FAILED: %d/%d blocks violate integer-scale grid outside excluded HP text panels" % [context_grid["violations"], context_grid["total_blocks"]])
	diagnostics["context_grid_violations"] = context_grid["violations"]
	diagnostics["context_grid_total_blocks"] = context_grid["total_blocks"]

	# ============================================================
	# Category C checks -- cropped image
	# ============================================================
	var bounding_cells: Array[Vector2i] = [LEGAL_CELL, ILLEGAL_CELL, NEUTRAL_CELL]
	var local_rect: Rect2 = _local_bounding_rect(bounding_cells, 8.0)
	var window_pos: Vector2 = _local_to_window(local_rect.position)
	var window_size: Vector2 = local_rect.size * _scale
	var crop_rect: Rect2i = Rect2i(window_pos.round(), window_size.round())
	var clamped: Rect2i = crop_rect.intersection(Rect2i(Vector2i.ZERO, full_size))
	print("Category C Check 1 -- crop rect from BoardCoords.grid_to_local()/CELL_SIZE via WorldLayout.compute_scale()/compute_rect() = ", crop_rect, " clamped=", clamped)
	if clamped != crop_rect:
		failures_c.append("Category C Check 1 FAILED: crop rect %s got clamped to %s by window bounds" % [crop_rect, clamped])

	var cropped: Image = full_img.get_region(clamped)

	var outline_color: Color = BoardView.CARD_TARGET_OUTLINE_COLOR
	var brightness_threshold: float = 0.75  # disclosed threshold, see doc comment above _left_border_clear_zone_window

	var legal_zone: Rect2i = _left_border_clear_zone_window(LEGAL_CELL)
	var illegal_zone: Rect2i = _left_border_clear_zone_window(ILLEGAL_CELL)
	var neutral_zone: Rect2i = _left_border_clear_zone_window(NEUTRAL_CELL)
	var legal_max: float = _max_brightness_in_rect(full_img, legal_zone)
	var illegal_max: float = _max_brightness_in_rect(full_img, illegal_zone)
	var neutral_max: float = _max_brightness_in_rect(full_img, neutral_zone)
	print("Category C Check 2 -- left-border clear-zone max brightness: legal=", legal_max, " (zone ", legal_zone, ") illegal=", illegal_max, " (zone ", illegal_zone, ") neutral=", neutral_max, " (zone ", neutral_zone, ") -- outline color is ", outline_color, ", threshold=", brightness_threshold)
	if legal_max < brightness_threshold:
		failures_c.append("Category C Check 2 FAILED: legal cell's clear-zone max brightness %.4f < threshold %.2f -- outline not detected" % [legal_max, brightness_threshold])
	if illegal_max < brightness_threshold:
		failures_c.append("Category C Check 2 FAILED: illegal cell's clear-zone max brightness %.4f < threshold %.2f -- outline not detected" % [illegal_max, brightness_threshold])
	if neutral_max >= brightness_threshold:
		failures_c.append("Category C Check 2 FAILED: neutral cell's clear-zone max brightness %.4f >= threshold %.2f -- unexpected outline-like pixel in the 3rd-state cell" % [neutral_max, brightness_threshold])

	var legal_center_window: Vector2i = Vector2i(_local_to_window(BoardCoords.grid_to_local_center(LEGAL_CELL)).round())
	var illegal_center_window: Vector2i = Vector2i(_local_to_window(BoardCoords.grid_to_local_center(ILLEGAL_CELL)).round())
	var legal_center_brightness: float = _pixel_brightness(full_img, legal_center_window)
	var illegal_center_brightness: float = _pixel_brightness(full_img, illegal_center_window)
	print("Category C Check 3(b) -- center-pixel brightness (X mark crosses center for illegal only): legal=", legal_center_brightness, " at ", legal_center_window, "; illegal=", illegal_center_brightness, " at ", illegal_center_window)
	if illegal_center_brightness < brightness_threshold:
		failures_c.append("Category C Check 3(b) FAILED: illegal cell's center brightness %.4f < threshold %.2f -- X mark not detected at center" % [illegal_center_brightness, brightness_threshold])
	if legal_center_brightness >= brightness_threshold:
		failures_c.append("Category C Check 3(b) FAILED: legal cell's center brightness %.4f >= threshold %.2f -- unexpected mark at center of a LEGAL (should be hollow) outline" % [legal_center_brightness, brightness_threshold])

	var crop_exclude_rects: Array[Rect2i] = []
	for cell: Vector2i in bounding_cells:
		var panel: Rect2i = _hp_text_panel_rect_window(cell)
		crop_exclude_rects.append(Rect2i(panel.position - clamped.position, panel.size))
	var crop_grid: Dictionary = _integer_grid_violations(cropped, crop_exclude_rects)
	print("Category C Check 4 -- integer-scale grid violations (world layer only, HP text panels excluded; illegal-mark diagonal region NOT excluded, per coordinator instruction) = ", crop_grid["violations"], " / ", crop_grid["total_blocks"])
	var crop_check4_ok: bool = crop_grid["violations"] == 0
	if not crop_check4_ok:
		failures_c.append("Category C Check 4 FAILED: %d/%d blocks violate integer-scale grid outside excluded HP text panels" % [crop_grid["violations"], crop_grid["total_blocks"]])
	diagnostics["crop_grid_violations"] = crop_grid["violations"]
	diagnostics["crop_grid_total_blocks"] = crop_grid["total_blocks"]

	var all_failures: Array[String] = []
	all_failures.append_array(failures_a)
	all_failures.append_array(failures_c)
	return {
		"crop_ok": failures_c.is_empty(),
		"context_ok": failures_a.is_empty(),
		"crop_check4_ok": crop_check4_ok,
		"context_check4_ok": context_check4_ok,
		"failures": all_failures,
		"diagnostics": diagnostics,
		"crop_image": cropped,
		"context_image": full_img,
	}


func _pixel_brightness(img: Image, p: Vector2i) -> float:
	var c: Color = img.get_pixelv(p)
	return (c.r + c.g + c.b) / 3.0
