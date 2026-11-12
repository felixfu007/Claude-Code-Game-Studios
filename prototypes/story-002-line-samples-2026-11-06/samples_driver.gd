extends Node
## story-002 (relation-minimap) sample-sheet driver, samples A, C, D, E.
## See README.md in this folder. 🔴 MUST be run by a human in a windowed session
## on private time; under --headless it logs structure only, then refuses to
## write any image and exits non-zero (a dummy renderer cannot give pixels).
##
## Rules followed (technical-preferences "item 5" + coding-standards screenshot rules):
##  - loads the REAL res://src/ui/battle/BattleScreen.tscn; order is
##    instantiate() -> set overrides -> call_deferred add_child on root -> wait frames.
##    No stand-in node chain, no set_script().
##  - evidence log lines carry the real host chain's own measured values
##    (WorldViewportContainer position/size/stretch_shrink, WorldViewport.size).
##  - validate before writing: dimensions == requested window size, >=3 distinct
##    colours in 12 spread points, dominant colour share <= 80% (stride-sampled).
##    On failure after retries: write NOTHING for that shot, count a failure.
##  - captures the root Window viewport only (never the desktop).
##
## Usage (user args after --):  --only=A_solid,C   restricts the shot list.

const BATTLE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const DIR: String = "res://prototypes/story-002-line-samples-2026-11-06/"
const FIX: String = DIR + "fixtures/"
const TERRAIN: String = FIX + "terrain_open.txt"
const OUT_DIR_NAME: String = "out"
const SETTLE_FRAMES: int = 12
const CAPTURE_RETRIES: int = 5
const SAMPLE_STRIDE: int = 5
const DOMINANT_MAX: float = 0.80
const MIN_DISTINCT: int = 3
const WATCHDOG_SEC: float = 240.0

const SIZE_960: Vector2i = Vector2i(960, 540)
const SIZE_1080: Vector2i = Vector2i(1920, 1080)
const SIZE_2160: Vector2i = Vector2i(3840, 2160)

## One entry per scenario instance. "sizes" = window sizes captured in turn.
## "setup" selects the post-load action (see _apply_setup).
const SHOTS: Array[Dictionary] = [
	{"name": "A_solid", "roster": "A", "links": "A_solid", "sizes": [SIZE_960, SIZE_1080], "setup": "none", "gray": true},
	{"name": "A_zigzag", "roster": "A", "links": "A_zigzag", "sizes": [SIZE_960, SIZE_1080], "setup": "none", "gray": true},
	{"name": "C_overlay", "roster": "C", "links": "C", "sizes": [SIZE_1080], "setup": "select_2", "gray": false},
	{"name": "D_same_sign", "roster": "D", "links": "D_same", "sizes": [SIZE_960, SIZE_1080], "setup": "none", "gray": true},
	{"name": "D_opposite_sign", "roster": "D", "links": "D_opp", "sizes": [SIZE_960, SIZE_1080], "setup": "none", "gray": true},
	{"name": "D_covered_by_piece_hp", "roster": "Dcover", "links": "Dcover", "sizes": [SIZE_1080], "setup": "hover_2", "gray": true},
	{"name": "E_minimap", "roster": "E", "links": "E", "sizes": [SIZE_960, SIZE_1080, SIZE_2160], "setup": "open_minimap", "gray": false},
]

var _failures: int = 0
var _pixels_unavailable: bool = false
var _out_dir_abs: String = ""


func _ready() -> void:
	var only: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr("--only=".length()).split(",")
	# self-timeout watchdog (2026-11-12): force quit(3) if the run exceeds WATCHDOG_SEC
	get_tree().create_timer(WATCHDOG_SEC, true, false, true).timeout.connect(_on_watchdog)
	print("=== SAMPLES DRIVER START display=", DisplayServer.get_name(), " ===")
	_out_dir_abs = ProjectSettings.globalize_path(DIR + OUT_DIR_NAME)
	for shot: Dictionary in SHOTS:
		if not only.is_empty() and not (shot["name"] in only):
			continue
		await _run_shot(shot)
	if _pixels_unavailable:
		print("RESULT: headless / no pixel access -- NO image file was written. Structure log above is the only output.")
		get_tree().quit(2)
		return
	print("RESULT: failures=", _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _on_watchdog() -> void:
	print("WATCHDOG: exceeded ", WATCHDOG_SEC, "s -- forcing quit(3); shots so far failures=", _failures)
	get_tree().quit(3)


func _run_shot(shot: Dictionary) -> void:
	var name: String = shot["name"]
	var roster_path: String = FIX + "roster_%s.txt" % shot["roster"]
	var links_path: String = FIX + "links_%s.txt" % shot["links"]
	print("--- SHOT ", name, " roster=", roster_path, " links=", links_path)
	if not _fixtures_compatible(roster_path, links_path):
		_failures += 1
		return

	var packed: PackedScene = load(BATTLE_PATH)
	var battle: Node = packed.instantiate()
	# overrides: after instantiate(), before add_child() (their only legal window)
	battle.terrain_path_override = TERRAIN
	battle.roster_path_override = roster_path
	battle.affinity_path_override = links_path
	get_tree().root.call_deferred("add_child", battle)
	await get_tree().process_frame
	await get_tree().process_frame
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	if not battle.is_inside_tree() or battle.get("_load_failed") == true:
		print("FAIL: ", name, " BattleScreen not running (inside_tree=", battle.is_inside_tree(), " _load_failed=", battle.get("_load_failed"), ")")
		_failures += 1
		battle.queue_free()
		return

	_apply_setup(battle, shot["setup"])
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	_log_board_structure(name, battle)

	for size: Vector2i in shot["sizes"]:
		await _capture(battle, name, size, shot["gray"])

	battle.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


# ---- fixtures -------------------------------------------------------------------

func _fixtures_compatible(roster_path: String, links_path: String) -> bool:
	var terrain_rows: Array[String] = []
	for line: String in FileAccess.get_file_as_string(TERRAIN).split("\n"):
		if not line.strip_edges().is_empty():
			terrain_rows.append(line.strip_edges())
	var width: int = terrain_rows[0].length() if not terrain_rows.is_empty() else 0
	var ok: bool = true
	for row: String in terrain_rows:
		if row.length() != width:
			ok = false
	var units: Array[Unit] = Unit.roster_from_text(FileAccess.get_file_as_string(roster_path))
	var ids: Dictionary = {}
	var cells: Dictionary = {}
	for unit: Unit in units:
		ids[unit.id] = true
		var cell: Vector2i = unit.start_pos
		var inside: bool = cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < terrain_rows.size()
		if not inside or cells.has(cell):
			ok = false
			print("COMPAT-BAD unit ", unit.id, " start=", cell, " inside_terrain=", inside, " duplicate=", cells.has(cell))
		cells[cell] = true
	var link_count: int = 0
	for line: String in FileAccess.get_file_as_string(links_path).split("\n"):
		if line.strip_edges().is_empty() or line.begins_with("#"):
			continue
		link_count += 1
		var f: PackedStringArray = line.split(",")
		for k: int in range(2):
			if not ids.has(int(f[k])):
				ok = false
				print("COMPAT-BAD link ", line, " references unit not in roster")
	print("COMPAT terrain=", width, "x", terrain_rows.size(), " units=", units.size(), " links=", link_count, " compatible=", ok)
	return ok and units.size() > 0


# ---- scenario setup ---------------------------------------------------------------

func _apply_setup(battle: Node, setup: String) -> void:
	match setup:
		"select_2":
			var selected: bool = battle._controller.select_unit(2)
			battle._cursor_cell = battle._state.position_of(2)
			battle._cursor_active = true
			battle._refresh_view()
			print("SETUP select_unit(2)=", selected, " cursor=", battle._cursor_cell)
		"hover_2":
			battle._cursor_cell = battle._state.position_of(2)
			battle._cursor_active = true
			battle._refresh_view()
			print("SETUP hover unit 2 at ", battle._cursor_cell, " (HP text shows for the focused cell)")
		"open_minimap":
			battle._toggle_relation_minimap()
			battle._refresh_view()
			print("SETUP relation minimap visible=", battle.diagnostic_relation_minimap_visible())
		_:
			pass


func _log_board_structure(name: String, battle: Node) -> void:
	var board_view: Node = battle._board_view
	var layer: Node = board_view._affinity_line_layer
	var strokes: int = 0
	var zigzag_lines: int = 0
	var plaques: int = 0
	for child: Node in layer.get_children():
		if child is Line2D:
			strokes += 1
			if (child as Line2D).points.size() > 2:
				zigzag_lines += 1
		else:
			plaques += 1
	print("STRUCT ", name, " line2d_nodes=", strokes, " zigzag_line2d=", zigzag_lines, " plaques=", plaques,
		" minimap_lines=", battle.diagnostic_relation_minimap_lines().size())
	var minimap: Array[Dictionary] = battle.diagnostic_relation_minimap_lines()
	for d: Dictionary in minimap:
		print("STRUCT   minimap ", d["a"], "-", d["b"], " state=", d["state"], " shape=", d["shape"], " plaque=", d["has_plaque"])
	print("STRUCT ", name, " move_hl=", board_view._move_highlight_layer.get_child_count(),
		" threat_hl=", board_view._threat_highlight_layer.get_child_count(),
		" attack_hl=", board_view._attack_highlight_layer.get_child_count())
	var scaled: int = _count_scaled_world_nodes(battle.get_node("WorldViewportContainer/WorldViewport"))
	if scaled == 0:
		print("STRUCT ", name, " Check 4 (integer-scale grid): no measurable target (N/A) -- 0 world nodes with scale != (1,1); NOT written as 'passed'")
	else:
		print("STRUCT ", name, " Check 4: ", scaled, " world nodes with scale != (1,1); measure from WorldViewport.get_texture() with aligned positions")


func _count_scaled_world_nodes(root: Node) -> int:
	var count: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node2D and (n as Node2D).scale != Vector2.ONE:
			count += 1
		elif n is Control and (n as Control).scale != Vector2.ONE:
			count += 1
		stack.append_array(n.get_children())
	return count


# ---- capture ----------------------------------------------------------------------

func _capture(battle: Node, name: String, size: Vector2i, gray: bool) -> void:
	var window: Window = get_window()
	window.mode = Window.MODE_WINDOWED
	window.size = size
	window.position = Vector2i(0, 0)
	for _i in range(SETTLE_FRAMES):
		await get_tree().process_frame
	_log_host_chain(name, battle, size)

	var tex: ViewportTexture = get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		print("CAPTURE ", name, " ", size, ": get_image() is null -- headless cannot read pixels; no image file written")
		_pixels_unavailable = true
		return

	var valid: bool = false
	var reason: String = ""
	for attempt: int in range(CAPTURE_RETRIES):
		reason = _validate(img, size)
		if reason.is_empty():
			valid = true
			break
		print("CAPTURE ", name, " ", size, " attempt ", attempt + 1, " rejected: ", reason)
		await get_tree().process_frame
		await get_tree().process_frame
		img = get_viewport().get_texture().get_image()
	if not valid:
		print("FAIL ", name, " ", size, ": validation failed after ", CAPTURE_RETRIES, " tries (", reason, ") -- NOTHING written")
		_failures += 1
		return

	DirAccess.make_dir_recursive_absolute(_out_dir_abs)
	var base: String = "%s/sample-%s-%dx%d" % [_out_dir_abs, name, size.x, size.y]
	var err: int = img.save_png(base + ".png")
	print("CAPTURE ", name, " ", size, " saved ", base, ".png err=", err, " (0=OK)")
	if err != OK:
		_failures += 1
	if gray:
		var g: Image = img.duplicate()
		g.convert(Image.FORMAT_L8)
		var gerr: int = g.save_png(base + "-gray.png")
		print("CAPTURE ", name, " ", size, " saved ", base, "-gray.png err=", gerr, " (0=OK)")
		if gerr != OK:
			_failures += 1


func _log_host_chain(name: String, battle: Node, requested: Vector2i) -> void:
	var container: Node = battle.get_node_or_null("WorldViewportContainer")
	var viewport: SubViewport = battle.get_node_or_null("WorldViewportContainer/WorldViewport")
	print("EVIDENCE ", name, " requested_window=", requested, " window.size=", get_window().size,
		" root_viewport.size=", get_viewport().size)
	if container != null:
		print("EVIDENCE ", name, " WorldViewportContainer.position=", container.position,
			" size=", container.size, " stretch_shrink=", container.stretch_shrink)
	if viewport != null:
		print("EVIDENCE ", name, " WorldViewport.size=", viewport.size)


## Returns "" if the image passes Category A checks 1-3, else the reason.
func _validate(img: Image, expected: Vector2i) -> String:
	if img.get_size() != expected:
		return "dimensions %s != requested %s (check window was not clamped by the screen size)" % [img.get_size(), expected]
	var w: int = img.get_width()
	var h: int = img.get_height()
	var distinct: Dictionary = {}
	for iy: int in range(3):
		for ix: int in range(4):
			var p: Vector2i = Vector2i(int(w * (ix + 0.5) / 4.0), int(h * (iy + 0.5) / 3.0))
			distinct[img.get_pixelv(p).to_html()] = true
	if distinct.size() < MIN_DISTINCT:
		return "12-point sampling found %d distinct colours (< %d)" % [distinct.size(), MIN_DISTINCT]
	var counts: Dictionary = {}
	var total: int = 0
	for y: int in range(0, h, SAMPLE_STRIDE):
		for x: int in range(0, w, SAMPLE_STRIDE):
			var key: String = img.get_pixel(x, y).to_html()
			counts[key] = int(counts.get(key, 0)) + 1
			total += 1
	var top: int = 0
	for key: String in counts:
		top = maxi(top, int(counts[key]))
	var share: float = float(top) / float(maxi(1, total))
	if share > DOMINANT_MAX:
		return "dominant colour share %.2f%% > %.0f%% (stride-%d sample)" % [share * 100.0, DOMINANT_MAX * 100.0, SAMPLE_STRIDE]
	return ""
