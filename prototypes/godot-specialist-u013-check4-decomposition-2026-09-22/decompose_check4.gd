extends SceneTree
## Throwaway headless diagnostic (godot-specialist, 2026-09-22).
##
## HYPOTHESIS: prototypes/u013-highlight-evidence-2026-09-22's Check-4 count
## (194 violations) is entirely caused by the illegal-mark's diagonal Line2D
## X, NOT by the outline's axis-aligned ColorRect border strips (which are
## drawn on the SAME layer, at integer local-space positions, and are shared
## by both the legal cell (border only) and the illegal cell (border + X)).
##
## METHOD: pure Image API read-back of the ALREADY-RENDERED real diagnostic
## PNG (produced by a genuine non-headless engine run of the real
## res://src/ui/battle/BoardView.tscn scene via evidence_driver.gd on
## 2026-09-22 -- this script does not render anything itself). Reading pixels
## back out of a saved file needs no rendering pipeline, so headless is fine
## for this -- same justification prototypes/u013-highlight-evidence-2026-09-22
## /diag_scan_column.gd already gave for the same technique.
##
## WHAT IS REAL (A) vs WHAT IS REPRODUCED ARITHMETIC (disclosed, not (A)):
## - The rendered image itself: (A) -- real engine, real BoardView, real GPU.
## - Vertex-source-of-truth: window size (1280x720), scale (2), and the
##   world-layer rect ((160,90)-(960,540)) are obtained by CALLING
##   WorldLayout.compute_scale()/compute_rect() for that window size, exactly
##   as technical-preferences.md requires ("必須呼叫 compute_scale(),不得自行
##   計算") -- NOT hardcoded, NOT re-derived.
## - The grid-violation counting algorithm (_integer_grid_violations) is
##   copied verbatim from evidence_driver.gd's own function of the same name
##   -- not reimplemented independently -- so this script's "SANITY CHECK"
##   total must reproduce run_output.txt's 194 exactly before any breakdown
##   is trusted.
## - The border-strip / X-mark bounding rects ARE this script's own
##   arithmetic (NOT engine-executed) -- built from BoardView's own public
##   consts (CARD_TARGET_OUTLINE_INSET/WIDTH, CARD_TARGET_ILLEGAL_MARK_INSET/
##   WIDTH) and BoardCoords' own public consts (CELL_SIZE, grid_to_local),
##   applying the SAME arithmetic board_view.gd's own
##   _build_card_target_outline()/_build_card_target_illegal_mark() use to
##   place these primitives in the first place, only in reverse (building an
##   inspection rect instead of a drawn rect). This is the same shape of
##   thing evidence_driver.gd's own _left_border_clear_zone_window() /
##   _hp_text_panel_rect_window() already do. Per technical-preferences.md's
##   (A)-definition rule, this reproduced arithmetic is explicitly NOT claimed
##   as (A) -- it is disclosed here as (B): real constants, this script's own
##   composition of them.
## - Border region and X-mark region are geometrically guaranteed
##   non-overlapping (outline inset+width = 3+2 = 5 local px < illegal-mark
##   inset = 7 local px, a 2-local-px gap between them), so no block can be
##   double-counted between the two buckets.

const CONTEXT_IMG_PATH: String = "res://prototypes/u013-highlight-evidence-2026-09-22/diagnostic-context-full-window-2026-09-22-CHECK4-FAILED.png"
const WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
const LEGAL_CELL: Vector2i = Vector2i(3, 0)
const ILLEGAL_CELL: Vector2i = Vector2i(5, 0)
const NEUTRAL_CELL: Vector2i = Vector2i(7, 0)

var _scale: int
var _world_rect: Rect2i


func _init() -> void:
	var img: Image = Image.load_from_file(CONTEXT_IMG_PATH)
	print("loaded image size = ", img.get_size())

	_scale = WorldLayout.compute_scale(WINDOW_SIZE)
	_world_rect = WorldLayout.compute_rect(WINDOW_SIZE)
	print("WorldLayout.compute_scale(", WINDOW_SIZE, ") = ", _scale)
	print("WorldLayout.compute_rect(", WINDOW_SIZE, ") = ", _world_rect)

	# Same HP-text-panel exclusion evidence_driver.gd's Category A Check 4
	# already applies -- reproduced so this script's total reproduces
	# run_output.txt's 194 exactly before decomposing it.
	var hp_text_excludes: Array[Rect2i] = [
		_hp_text_panel_rect_window(LEGAL_CELL),
		_hp_text_panel_rect_window(ILLEGAL_CELL),
		_hp_text_panel_rect_window(NEUTRAL_CELL),
	]

	var total: Dictionary = _integer_grid_violations(img, hp_text_excludes)
	print("SANITY CHECK -- total violations (must reproduce run_output.txt's 194/229440) = ", total["violations"], " / ", total["total_blocks"])

	var legal_border_rects: Array[Rect2i] = _outline_border_rects_window(LEGAL_CELL)
	var illegal_border_rects: Array[Rect2i] = _outline_border_rects_window(ILLEGAL_CELL)
	var illegal_x_bbox: Rect2i = _illegal_mark_bbox_window(ILLEGAL_CELL)

	print("REGION -- legal border rects (window space) = ", legal_border_rects)
	print("REGION -- illegal border rects (window space) = ", illegal_border_rects)
	print("REGION -- illegal X bbox (window space, superset of the two diagonals) = ", illegal_x_bbox)

	var legal_border_result: Dictionary = _violations_in_regions(img, legal_border_rects, hp_text_excludes)
	var illegal_border_result: Dictionary = _violations_in_regions(img, illegal_border_rects, hp_text_excludes)
	var illegal_x_result: Dictionary = _violations_in_regions(img, [illegal_x_bbox], hp_text_excludes)

	var accounted: int = (
		int(legal_border_result["violations"])
		+ int(illegal_border_result["violations"])
		+ int(illegal_x_result["violations"])
	)

	print("DECOMPOSITION -- legal-cell border-strip-only violations   = ", legal_border_result["violations"], " (", legal_border_result["total_blocks"], " blocks checked in that region)")
	print("DECOMPOSITION -- illegal-cell border-strip-only violations = ", illegal_border_result["violations"], " (", illegal_border_result["total_blocks"], " blocks checked in that region)")
	print("DECOMPOSITION -- illegal-cell X-bbox-only violations       = ", illegal_x_result["violations"], " (", illegal_x_result["total_blocks"], " blocks checked in that region)")
	print("DECOMPOSITION -- sum of the three buckets above            = ", accounted)
	print("DECOMPOSITION -- vs SANITY CHECK total (194)               = compare printed lines above; remainder (if any) is neither border nor X -- e.g. HP bar ColorRects, terrain/piece sprite edges, or measurement gaps")

	# Follow-up: dump every violating block's window-space top-left, since the
	# three-bucket decomposition above left a remainder unaccounted for. This
	# does not classify further -- it just lists WHERE the unaccounted blocks
	# actually are so they can be mapped back to a cause by hand.
	_dump_all_violating_blocks(img, hp_text_excludes, legal_border_rects, illegal_border_rects, illegal_x_bbox)

	quit()


func _dump_all_violating_blocks(
	img: Image,
	exclude_rects: Array[Rect2i],
	legal_border_rects: Array[Rect2i],
	illegal_border_rects: Array[Rect2i],
	illegal_x_bbox: Rect2i
) -> void:
	var size: Vector2i = img.get_size()
	var blocks_x: int = size.x / _scale
	var blocks_y: int = size.y / _scale
	var count: int = 0
	var bucket_counts: Dictionary = {"legal_border": 0, "illegal_border": 0, "illegal_x": 0, "other": 0}
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
			var origin: Color = img.get_pixel(bx * _scale, by * _scale)
			var is_violation: bool = false
			for dy in range(_scale):
				for dx in range(_scale):
					var c: Color = img.get_pixel(bx * _scale + dx, by * _scale + dy)
					if not c.is_equal_approx(origin):
						is_violation = true
						break
				if is_violation:
					break
			if not is_violation:
				continue
			count += 1
			var bucket: String = "other"
			for r: Rect2i in legal_border_rects:
				if r.intersects(block_rect):
					bucket = "legal_border"
			for r: Rect2i in illegal_border_rects:
				if r.intersects(block_rect):
					bucket = "illegal_border"
			if illegal_x_bbox.intersects(block_rect):
				bucket = "illegal_x"
			bucket_counts[bucket] = int(bucket_counts[bucket]) + 1
			if count <= 250:
				print("VIOLATION #", count, " block window-topleft=", block_rect.position, " bucket=", bucket, " origin_color=", origin)
	print("VIOLATING BLOCK BUCKET TOTALS (all ", count, " violations, re-bucketed with wider per-block classification) = ", bucket_counts)


func _local_to_window(p: Vector2) -> Vector2:
	return p * _scale + Vector2(_world_rect.position)


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


# Four thin border-strip window rects for ONE cell -- same top/bottom/left/
# right layout as board_view.gd's own _build_card_target_outline().
func _outline_border_rects_window(cell: Vector2i) -> Array[Rect2i]:
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var top_left: Vector2 = cell_top_left + Vector2.ONE * BoardView.CARD_TARGET_OUTLINE_INSET
	var side: float = BoardCoords.CELL_SIZE - BoardView.CARD_TARGET_OUTLINE_INSET * 2.0
	var w: float = BoardView.CARD_TARGET_OUTLINE_WIDTH
	var local_rects: Array[Rect2] = [
		Rect2(top_left, Vector2(side, w)),                             # top
		Rect2(top_left + Vector2(0.0, side - w), Vector2(side, w)),    # bottom
		Rect2(top_left, Vector2(w, side)),                             # left
		Rect2(top_left + Vector2(side - w, 0.0), Vector2(w, side)),    # right
	]
	var out: Array[Rect2i] = []
	for r: Rect2 in local_rects:
		out.append(Rect2i(
			Vector2i(_local_to_window(r.position).round()),
			Vector2i((r.size * _scale).round())
		))
	return out


# Bounding box (superset of the two diagonal strokes) for the illegal-mark X
# -- same inset/side as board_view.gd's own _build_card_target_illegal_mark().
func _illegal_mark_bbox_window(cell: Vector2i) -> Rect2i:
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var top_left: Vector2 = cell_top_left + Vector2.ONE * BoardView.CARD_TARGET_ILLEGAL_MARK_INSET
	var side: float = BoardCoords.CELL_SIZE - BoardView.CARD_TARGET_ILLEGAL_MARK_INSET * 2.0
	return Rect2i(
		Vector2i(_local_to_window(top_left).round()),
		Vector2i((Vector2(side, side) * _scale).round())
	)


# Copied verbatim (same algorithm) from evidence_driver.gd's
# _integer_grid_violations() -- not reimplemented independently.
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


# Same test, restricted to blocks that intersect at least one rect in
# only_regions (in addition to the same HP-text exclude filter above).
func _violations_in_regions(img: Image, only_regions: Array[Rect2i], exclude_rects: Array[Rect2i]) -> Dictionary:
	var size: Vector2i = img.get_size()
	var violations: int = 0
	var total_blocks: int = 0
	var blocks_x: int = size.x / _scale
	var blocks_y: int = size.y / _scale
	for by in range(blocks_y):
		for bx in range(blocks_x):
			var block_rect: Rect2i = Rect2i(bx * _scale, by * _scale, _scale, _scale)
			var inside: bool = false
			for r: Rect2i in only_regions:
				if r.intersects(block_rect):
					inside = true
					break
			if not inside:
				continue
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
