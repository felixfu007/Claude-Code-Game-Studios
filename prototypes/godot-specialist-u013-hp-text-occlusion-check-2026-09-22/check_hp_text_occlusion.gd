extends SceneTree
## Throwaway headless diagnostic (godot-specialist, 2026-09-22).
##
## QUESTION (coordinator, not this script's to judge): does the illegal cell's
## HP text ("5/5") actually get obscured by the illegal-mark X, or does it
## look that way by eye but is actually still drawn correctly? The coordinator
## explicitly asked for pixel measurement, not visual inspection.
##
## METHOD: pure Image API read-back of the ALREADY-ACCEPTED real evidence PNG
## (production/qa/evidence/u013-card-target-highlight-CONTEXT-full-window-
## 2026-09-22.png, produced this session by a genuine non-headless engine run
## of the real res://src/ui/battle/BoardView.tscn through the real
## SubViewport pipeline). This script does not render anything itself and
## does not open the image visually -- it reads raw pixel bytes and compares
## them numerically.
##
## The two HP-text-panel window rects below are NOT re-derived math dressed
## up as fact -- they are built from BoardView's own public consts
## (HP_TEXT_TOP_MARGIN, HP_TEXT_HEIGHT) and BoardCoords' own public consts
## (CELL_SIZE, grid_to_local), run through the SAME WorldLayout.compute_
## scale()/compute_rect() calls (not hardcoded) the evidence driver itself
## used for this exact run (TARGET_WINDOW_SIZE=1280x720, confirmed by this
## run's own run_output.txt: "CENTERING ANSWER -- WorldLayout.compute_scale(
## (1280, 720)) = 2" / "compute_rect(...) = [P: (160, 90), S: (960, 540)]").
## Disclosed as (B): real constants and real WorldLayout calls, but the rect-
## building arithmetic itself is this script's own, not engine-executed --
## same disclosure shape as the two prior u013 sub-investigations today.
##
## KEY FACT THAT MAKES "IS IT TEXT COLOUR OR X COLOUR" NOT ANSWERABLE BY A
## SINGLE PIXEL'S RGB ALONE: HP_TEXT_COLOR_NORMAL is Color.WHITE (1,1,1,1)
## and CARD_TARGET_OUTLINE_COLOR (used for both the outline AND the X) is
## (1.0, 1.0, 1.0, 0.9) -- both are white/near-white. A lone bright pixel
## could be either. This script therefore does NOT rely on "is this pixel
## white" -- it compares the WHOLE HP-text-panel region between the legal
## cell (no X present at all -- clean baseline) and the illegal cell
## (X present) at IDENTICAL relative offsets, pixel-by-pixel, and reports
## WHERE and HOW MANY pixels differ, plus prints both regions as raw
## brightness grids so the diff pattern (if any) is visible as DATA, not as
## an opened image.

const IMG_PATH: String = "res://production/qa/evidence/u013-card-target-highlight-CONTEXT-full-window-2026-09-22.png"
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
const LEGAL_CELL: Vector2i = Vector2i(3, 0)
const ILLEGAL_CELL: Vector2i = Vector2i(5, 0)

var _scale: int
var _world_rect: Rect2i


func _init() -> void:
	var img: Image = Image.load_from_file(IMG_PATH)
	print("loaded image size = ", img.get_size())

	_scale = WorldLayout.compute_scale(WINDOW_SIZE)
	_world_rect = WorldLayout.compute_rect(WINDOW_SIZE)
	print("WorldLayout.compute_scale(", WINDOW_SIZE, ") = ", _scale)
	print("WorldLayout.compute_rect(", WINDOW_SIZE, ") = ", _world_rect)

	var legal_rect: Rect2i = _hp_text_panel_rect_window(LEGAL_CELL)
	var illegal_rect: Rect2i = _hp_text_panel_rect_window(ILLEGAL_CELL)
	print("HP text panel window rect -- legal cell (3,0)   = ", legal_rect)
	print("HP text panel window rect -- illegal cell (5,0) = ", illegal_rect)
	print("Sanity: same size? ", legal_rect.size == illegal_rect.size, "  (must be true for a fair pixel-aligned diff)")

	# ── Q2a: exact colour at the CENTRE of the panel (roughly mid-glyph
	# height) for both cells, printed raw, no interpretation. ──
	var legal_mid: Vector2i = legal_rect.position + legal_rect.size / 2
	var illegal_mid: Vector2i = illegal_rect.position + illegal_rect.size / 2
	print("Q2a -- raw pixel at legal cell panel centre   ", legal_mid, " = ", img.get_pixel(legal_mid.x, legal_mid.y))
	print("Q2a -- raw pixel at illegal cell panel centre ", illegal_mid, " = ", img.get_pixel(illegal_mid.x, illegal_mid.y))
	print("Q2a -- for reference, board_view.gd's HP_TEXT_COLOR_NORMAL = Color.WHITE = (1,1,1,1); CARD_TARGET_OUTLINE_COLOR (outline AND X) = (1.0, 1.0, 1.0, 0.9) -- both are white/near-white, so a single pixel's colour alone cannot distinguish text stroke from X stroke. See the pixel-by-pixel diff below instead.")

	# ── Q2b: whole-panel pixel-by-pixel diff, legal vs illegal, same relative
	# offset. This is the actual answer to "is the pixel data different in
	# the illegal cell's panel, and if so where". ──
	var w: int = legal_rect.size.x
	var h: int = legal_rect.size.y
	var diff_count: int = 0
	var total: int = w * h
	var diff_map: Array[String] = []
	for y in range(h):
		var row: String = ""
		for x in range(w):
			var lc: Color = img.get_pixel(legal_rect.position.x + x, legal_rect.position.y + y)
			var ic: Color = img.get_pixel(illegal_rect.position.x + x, illegal_rect.position.y + y)
			if lc.is_equal_approx(ic):
				row += "."
			else:
				diff_count += 1
				row += "D"
		diff_map.append(row)
	print("Q2b -- pixel-by-pixel diff, legal panel vs illegal panel at identical relative offsets = ", diff_count, " / ", total, " pixels differ")
	print("Q2b -- diff map (one row per pixel row, '.' = identical colour, 'D' = differs; panel is ", w, "x", h, " px):")
	for row: String in diff_map:
		print("  ", row)

	# ── Q2c: for every differing pixel, print BOTH raw colours so the actual
	# values (not just "differs") are on the record. ──
	print("Q2c -- every differing pixel's raw colour pair (legal vs illegal):")
	var printed: int = 0
	for y in range(h):
		for x in range(w):
			var lc: Color = img.get_pixel(legal_rect.position.x + x, legal_rect.position.y + y)
			var ic: Color = img.get_pixel(illegal_rect.position.x + x, illegal_rect.position.y + y)
			if not lc.is_equal_approx(ic):
				printed += 1
				if printed <= 400:
					print("  (dx=", x, ",dy=", y, ")  legal=", lc, "  illegal=", ic)

	quit()


func _hp_text_panel_rect_window(cell: Vector2i) -> Rect2i:
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var local_rect: Rect2 = Rect2(
		Vector2(cell_top_left.x, cell_top_left.y + BoardView.HP_TEXT_TOP_MARGIN),
		Vector2(BoardCoords.CELL_SIZE, BoardView.HP_TEXT_HEIGHT)
	)
	return Rect2i(
		Vector2i((local_rect.position * _scale + Vector2(_world_rect.position)).round()),
		Vector2i((local_rect.size * _scale).round())
	)
