extends Node2D
## Board render/input spike root.
##
## Builds a 13x6 terrain grid + 10 placeholder pieces inside WorldViewport, wires up a
## click -> highlight + coordinate readout for interactive use, and — when
## `run_measurement_on_ready` is true (the default) — runs a fully automated,
## engine-driven coordinate-conversion measurement pass across several window sizes,
## prints the results to the console, and quits. That printed log is the evidence
## `README.md`'s numbers table is built from; nothing in the log is hand-reasoned.

const BoardCoords := preload("res://scripts/board_coords.gd")

const TERRAIN_ROWS: Array[String] = [
	".............",
	".....,,......",
	"....,##,.....",
	"....,##,.....",
	".....,,......",
	".............",
]

const ALLY_CELLS: Array[Vector2i] = [
	Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(0, 5),
]
const ENEMY_CELLS: Array[Vector2i] = [
	Vector2i(10, 0), Vector2i(11, 1), Vector2i(9, 4), Vector2i(7, 5), Vector2i(11, 5),
]

## Window sizes probed by the measurement pass. The first three are the ones the spike
## brief asked for (all exactly 16:9, so "keep" aspect never letterboxes them). 800x600
## is added so the letterbox/black-bar case actually gets exercised at least once.
const MEASURE_SIZES: Array[Vector2i] = [
	Vector2i(480, 270),
	Vector2i(960, 540),
	Vector2i(1440, 810),
	Vector2i(800, 600),
]

@export var run_measurement_on_ready: bool = true

@onready var world_viewport_container: SubViewportContainer = $WorldViewportContainer
@onready var world_viewport: SubViewport = $WorldViewportContainer/WorldViewport

var _board_root: Node2D
var _highlight: Sprite2D
var _readout_label: Label

var _window_to_canvas: Transform2D = Transform2D.IDENTITY
var _canvas_to_window: Transform2D = Transform2D.IDENTITY


func _ready() -> void:
	_sync_container_size_workaround()
	get_tree().root.size_changed.connect(_sync_container_size_workaround)
	_build_terrain()
	_build_pieces()
	_build_ui()
	if run_measurement_on_ready:
		await _run_measurement_pass()
		get_tree().quit()


## WORKAROUND for a confirmed Godot 4.7.1 engine finding (see README): a Control's
## anchor-based auto-resize does not propagate through a Node2D parent.
## WorldViewportContainer.size (and therefore WorldViewport.size, since stretch=true
## mirrors container size into the SubViewport) stays stuck at its tiny (0,0)/(2,2)
## default forever unless synced manually — confirmed in real windowed execution with a
## real GPU, not just headless. Re-parenting WorldViewportContainer to not sit directly
## under a Node2D (e.g. under a CanvasLayer or plain Node instead) also fixes it, but that
## would change the production GameRoot.tscn shape this spike was told to mirror, so this
## spike works around it in script instead and reports the finding for the shape itself
## to be fixed upstream.
func _sync_container_size_workaround() -> void:
	world_viewport_container.size = get_tree().root.get_visible_rect().size


func _build_terrain() -> void:
	_board_root = Node2D.new()
	_board_root.name = "Board"
	world_viewport.add_child(_board_root)

	var tex_ground: Texture2D = load("res://assets/terrain_ground.png")
	var tex_bush: Texture2D = load("res://assets/terrain_bush.png")
	var tex_rubble: Texture2D = load("res://assets/terrain_rubble.png")

	for row in range(TERRAIN_ROWS.size()):
		var line: String = TERRAIN_ROWS[row]
		for col in range(line.length()):
			var tex: Texture2D = tex_ground
			match line[col]:
				",":
					tex = tex_bush
				"#":
					tex = tex_rubble
				_:
					tex = tex_ground
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = true
			sprite.position = BoardCoords.grid_to_local_center(Vector2i(col, row))
			_board_root.add_child(sprite)

	_highlight = Sprite2D.new()
	_highlight.name = "Highlight"
	_highlight.texture = load("res://assets/highlight_move.png")
	_highlight.centered = true
	_highlight.visible = false
	_board_root.add_child(_highlight)


func _build_pieces() -> void:
	var ally_textures: Array[Texture2D] = [
		load("res://assets/piece_ally_01.png"),
		load("res://assets/piece_ally_02.png"),
		load("res://assets/piece_ally_03.png"),
		load("res://assets/piece_ally_04.png"),
		load("res://assets/piece_ally_05.png"),
	]
	var enemy_texture: Texture2D = load("res://assets/piece_enemy_01.png")

	for i in range(ALLY_CELLS.size()):
		var sprite := Sprite2D.new()
		sprite.texture = ally_textures[i]
		sprite.centered = true
		sprite.position = BoardCoords.grid_to_local_center(ALLY_CELLS[i])
		_board_root.add_child(sprite)

	for cell in ENEMY_CELLS:
		var sprite := Sprite2D.new()
		sprite.texture = enemy_texture
		sprite.centered = true
		sprite.position = BoardCoords.grid_to_local_center(cell)
		_board_root.add_child(sprite)


func _build_ui() -> void:
	var ui_layer: CanvasLayer = $UILayer
	_readout_label = Label.new()
	_readout_label.name = "Readout"
	_readout_label.position = Vector2(4, 4)
	_readout_label.text = "Click a cell..."
	ui_layer.add_child(_readout_label)


## Refresh the live window->canvas / canvas->window transforms from the engine.
## Called every frame in interactive mode, and once per size in the measurement pass.
func _refresh_transforms() -> void:
	var win: Window = get_tree().root
	_canvas_to_window = win.get_final_transform()
	_window_to_canvas = _canvas_to_window.affine_inverse()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_refresh_transforms()
		var cell: Vector2i = BoardCoords.window_to_grid(
			event.position, _window_to_canvas, world_viewport_container.global_position
		)
		if BoardCoords.is_in_bounds(cell):
			_highlight.visible = true
			_highlight.position = BoardCoords.grid_to_local_center(cell)
		else:
			_highlight.visible = false
		_readout_label.text = "Screen: %s  ->  Grid: %s%s" % [
			event.position, cell, "" if BoardCoords.is_in_bounds(cell) else " (out of bounds)"
		]


## Print-and-quit measurement pass. Uses DisplayServer.window_set_size() (the real
## native-driver resize path) rather than assigning Window.size directly, and waits
## several process frames per size before reading anything back — Control anchor
## layout resolves on a deferred notification, not synchronously.
func _run_measurement_pass() -> void:
	print("")
	print("========== BOARD COORD MEASUREMENT PASS ==========")
	print("BoardCoords.BOARD_ORIGIN (WorldViewport-local, board top-left): ", BoardCoords.BOARD_ORIGIN)
	print("Board size: %dx%d cells, %dx%d px" % [
		BoardCoords.BOARD_COLS, BoardCoords.BOARD_ROWS,
		BoardCoords.BOARD_COLS * BoardCoords.CELL_SIZE, BoardCoords.BOARD_ROWS * BoardCoords.CELL_SIZE,
	])

	var test_cells: Dictionary = {
		"top_left": Vector2i(0, 0),
		"top_right": Vector2i(BoardCoords.BOARD_COLS - 1, 0),
		"bottom_left": Vector2i(0, BoardCoords.BOARD_ROWS - 1),
		"bottom_right": Vector2i(BoardCoords.BOARD_COLS - 1, BoardCoords.BOARD_ROWS - 1),
		"center": Vector2i(BoardCoords.BOARD_COLS / 2, BoardCoords.BOARD_ROWS / 2),
	}

	for size in MEASURE_SIZES:
		DisplayServer.window_set_size(size)
		for i in range(5):
			await get_tree().process_frame

		var win: Window = get_tree().root
		_refresh_transforms()

		print("")
		print("--- window size requested = ", size, " ---")
		print("DisplayServer.window_get_size() (actual): ", DisplayServer.window_get_size())
		print("win.get_visible_rect().size (base canvas, should stay 480x270): ", win.get_visible_rect().size)
		print("WorldViewportContainer.size: ", world_viewport_container.size)
		print("WorldViewportContainer.global_position (canvas-space origin): ", world_viewport_container.global_position)
		print("WorldViewport.size: ", world_viewport.size)
		print("get_final_transform() (base-canvas -> window px): ", _canvas_to_window)

		# Derive the on-screen pixel edge length of one board cell from the transform's
		# X-basis-vector length, rather than assuming "scale factor" means anything in
		# particular — this is measured, not asserted.
		var cell_edge_px: float = _canvas_to_window.x.length() * BoardCoords.CELL_SIZE
		print("Measured on-screen edge length of one 32x32 cell: %.3f px" % cell_edge_px)

		var board_topleft_window: Vector2 = _canvas_to_window * (
			BoardCoords.BOARD_ORIGIN + world_viewport_container.global_position
		)
		print("Board top-left corner, in window/screen pixels: ", board_topleft_window)

		# Round-trip: grid -> window -> grid, for 4 corners + center. Must return to the
		# original cell exactly, or this transform chain cannot be trusted for clicks.
		for label in test_cells:
			var cell: Vector2i = test_cells[label]
			var window_pos: Vector2 = BoardCoords.grid_to_window(
				cell, _canvas_to_window, world_viewport_container.global_position
			)
			var round_trip_cell: Vector2i = BoardCoords.window_to_grid(
				window_pos, _window_to_canvas, world_viewport_container.global_position
			)
			var ok: bool = round_trip_cell == cell
			print("  round-trip %-12s cell=%s -> window=%s -> cell=%s  %s" % [
				label, cell, window_pos, round_trip_cell, "OK" if ok else "MISMATCH"
			])

		# Letterbox probe: click at the physical window's top-left corner (0,0). If the
		# displayed canvas is centered with black bars, (0,0) sits inside the bar for any
		# window size where scale*480 < window.x or scale*270 < window.y.
		var corner_cell: Vector2i = BoardCoords.window_to_grid(
			Vector2.ZERO, _window_to_canvas, world_viewport_container.global_position
		)
		var corner_canvas: Vector2 = _window_to_canvas * Vector2.ZERO
		print("  window (0,0) -> base-canvas=%s -> grid=%s  in_bounds=%s" % [
			corner_canvas, corner_cell, BoardCoords.is_in_bounds(corner_cell)
		])

	print("")
	print("========== END MEASUREMENT PASS ==========")
