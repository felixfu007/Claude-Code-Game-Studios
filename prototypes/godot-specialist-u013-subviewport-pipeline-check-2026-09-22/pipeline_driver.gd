extends Node
## Throwaway probe (godot-specialist, 2026-09-22).
##
## HYPOTHESIS being tested: prototypes/u013-highlight-evidence-2026-09-22's
## evidence_driver.gd instantiated the real res://src/ui/battle/BoardView.tscn
## DIRECTLY under the root Window and applied WorldLayout's scale/position by
## hand (`_instance.scale = Vector2(_scale, _scale)`). That is NOT how
## production actually renders BoardView: src/ui/battle/BattleScreen.tscn puts
## BoardView inside a real SubViewport, and the real production script
## res://src/ui/battle/world_viewport_scaler.gd drives the enclosing
## SubViewportContainer's stretch_shrink/position/size from WorldLayout.
## Per SubViewportContainer's own stretch_shrink semantics (Godot docs) and
## the story-001-manual-scaling-verification-2026-09-04 spike this project
## already ran, that means the SubViewport's INTERNAL render resolution is
## ALWAYS exactly WorldLayout.BASE_WIDTH x BASE_HEIGHT (480x270), regardless
## of window size -- the container then upscales that FIXED low-res texture
## using nearest-neighbour filtering (BattleScreen.tscn sets
## WorldViewportContainer.texture_filter = 1, i.e. NEAREST). If that is
## right, board_view.gd's Line2D diagonal is rasterized ONCE at native
## 480x270 (an honest per-source-pixel decision, since Line2D.antialiased is
## already false), and the SAME clean-block guarantee that makes Sprite2D
## textures always pass Check 4 would ALSO apply to the X mark and the
## outline -- NOT because Check 4 is being exempted for vector primitives,
## but because THIS specific pipeline makes vector and texture content
## equally block-safe. The u013 spike's 194/178 violations would then be an
## artifact of its own driver skipping the SubViewport, not a real
## board_view.gd defect.
##
## THIS PROBE builds the REAL WorldViewportContainer/WorldViewport/BoardView
## subtree -- same node types, same real world_viewport_scaler.gd script,
## same texture_filter=1/stretch=true BattleScreen.tscn itself ships with
## (see that file) -- and re-runs the IDENTICAL Check-4 measurement
## u013's evidence_driver.gd used, on the SAME three-cell scenario. This is
## NOT a copy of BattleScreen.tscn's full node tree (no UILayer/HandBar/etc
## -- those are irrelevant to this specific question and would only add
## unrelated failure surface); it is the minimal real subtree the open
## question is actually about.

const TARGET_WINDOW_SIZE: Vector2i = Vector2i(1280, 720)
const BOARD_VIEW_SCENE_PATH: String = "res://src/ui/battle/BoardView.tscn"
const WORLD_SCALER_SCRIPT_PATH: String = "res://src/ui/battle/world_viewport_scaler.gd"
const TERRAIN_DATA_PATH: String = "res://assets/data/levels/vs01_terrain.txt"
const OUT_DIR: String = "res://prototypes/godot-specialist-u013-subviewport-pipeline-check-2026-09-22/"

const LEGAL_CELL: Vector2i = Vector2i(3, 0)
const ILLEGAL_CELL: Vector2i = Vector2i(5, 0)
const NEUTRAL_CELL: Vector2i = Vector2i(7, 0)

var _board_view: Node2D
var _scale: int
var _world_rect: Rect2i


func _ready() -> void:
	await get_tree().process_frame
	DisplayServer.window_set_size(TARGET_WINDOW_SIZE)
	await get_tree().process_frame

	# Build the REAL production subtree: SubViewportContainer (real script,
	# same texture_filter/stretch BattleScreen.tscn ships with) ->
	# SubViewport -> BoardView (real scene, unmodified).
	var container: SubViewportContainer = SubViewportContainer.new()
	container.texture_filter = 1  # NEAREST -- matches BattleScreen.tscn's WorldViewportContainer
	container.stretch = true      # matches BattleScreen.tscn
	container.set_script(load(WORLD_SCALER_SCRIPT_PATH))

	var sub_viewport: SubViewport = SubViewport.new()
	_board_view = load(BOARD_VIEW_SCENE_PATH).instantiate()
	sub_viewport.add_child(_board_view)
	container.add_child(sub_viewport)

	get_tree().root.add_child(container)  # fires world_viewport_scaler.gd's _ready() -> _apply_layout()
	await get_tree().process_frame
	await get_tree().process_frame

	_scale = WorldLayout.compute_scale(TARGET_WINDOW_SIZE)
	_world_rect = WorldLayout.compute_rect(TARGET_WINDOW_SIZE)
	print("PIPELINE PROBE -- WorldLayout.compute_scale(", TARGET_WINDOW_SIZE, ") = ", _scale)
	print("PIPELINE PROBE -- WorldLayout.compute_rect(", TARGET_WINDOW_SIZE, ") = ", _world_rect)
	print("PIPELINE PROBE -- SubViewportContainer.position/size = ", container.position, " / ", container.size)
	print("PIPELINE PROBE -- SubViewportContainer.stretch_shrink = ", container.stretch_shrink)
	print("PIPELINE PROBE -- SubViewport.size (should be exactly BASE_WIDTHxBASE_HEIGHT = 480x270 if the stretch_shrink hypothesis is right) = ", sub_viewport.size)

	var terrain_rows: PackedStringArray = _load_terrain_rows()
	_board_view.render_terrain(terrain_rows)
	var pieces: Array[Dictionary] = [
		{"cell": LEGAL_CELL, "faction": "PLAYER", "sprite_index": 0, "hp": 5, "hp_max": 5, "show_hp_text": true},
		{"cell": ILLEGAL_CELL, "faction": "PLAYER", "sprite_index": 0, "hp": 5, "hp_max": 5, "show_hp_text": true},
		{"cell": NEUTRAL_CELL, "faction": "PLAYER", "sprite_index": 0, "hp": 5, "hp_max": 5, "show_hp_text": true},
	]
	_board_view.render_pieces(pieces)
	var legal_cells: Array[Vector2i] = [LEGAL_CELL]
	var illegal_cells: Array[Vector2i] = [ILLEGAL_CELL]
	_board_view.set_card_target_highlights(legal_cells, illegal_cells)

	for i in range(10):
		await get_tree().process_frame

	var full_img: Image = get_viewport().get_texture().get_image()
	print("PIPELINE PROBE -- full window image size = ", full_img.get_size())
	_save(full_img, OUT_DIR, "pipeline-probe-full-window-2026-09-22.png")

	# Also grab the SubViewport's OWN internal texture directly -- this is
	# the actual 480x270-or-whatever-it-really-is image BEFORE the
	# container's nearest upscale, which is the most direct possible check
	# of the stretch_shrink hypothesis.
	var sub_img: Image = sub_viewport.get_texture().get_image()
	print("PIPELINE PROBE -- SubViewport's OWN internal texture size = ", sub_img.get_size())
	_save(sub_img, OUT_DIR, "pipeline-probe-subviewport-internal-2026-09-22.png")

	var hp_text_excludes: Array[Rect2i] = [
		_hp_text_panel_rect_window(LEGAL_CELL),
		_hp_text_panel_rect_window(ILLEGAL_CELL),
		_hp_text_panel_rect_window(NEUTRAL_CELL),
	]
	var result: Dictionary = _integer_grid_violations_single_count(full_img, hp_text_excludes)
	print("PIPELINE PROBE -- Check 4 (corrected single-count algorithm) on REAL SubViewport pipeline, full window = ", result["violations"], " / ", result["total_blocks"])

	print("PIPELINE PROBE DONE")
	get_tree().quit(0)


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


func _load_terrain_rows() -> PackedStringArray:
	var rows: PackedStringArray = []
	var f: FileAccess = FileAccess.open(TERRAIN_DATA_PATH, FileAccess.READ)
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.length() > 0:
			rows.append(line)
	f.close()
	return rows


func _save(img: Image, dir: String, filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join(filename)
	var err: int = img.save_png(path)
	print("save_png(", path, ") err=", err, " (0 == OK)")


# Single-count-per-block version (fixes the double-count bug found in
# evidence_driver.gd's own _integer_grid_violations -- see
# prototypes/godot-specialist-u013-check4-decomposition-2026-09-22/README.md).
func _integer_grid_violations_single_count(img: Image, exclude_rects: Array[Rect2i]) -> Dictionary:
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
			var is_violation: bool = false
			for dy in range(_scale):
				for dx in range(_scale):
					var c: Color = img.get_pixel(bx * _scale + dx, by * _scale + dy)
					if not c.is_equal_approx(origin):
						is_violation = true
						break
				if is_violation:
					break
			if is_violation:
				violations += 1
	return {"violations": violations, "total_blocks": total_blocks}
