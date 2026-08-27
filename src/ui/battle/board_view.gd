## Pure presentation of the battle board: terrain, pieces, move/attack
## highlights, and a cursor sprite. Renders whatever it is told to render and
## nothing else.
##
## [b]This node owns zero game state and makes zero rule decisions.[/b] Per
## [code].claude/rules/ui-code.md[/code] ("UI must NEVER own or directly
## modify game state — display only"): it never holds a
## [code]BattleState[/code] reference, never calls [code]move_unit()[/code]
## or [code]resolve_attack()[/code], and never decides what is legal. Every
## public method here is a pure "draw this data" call — callers (the future
## battle controller) own the state and push snapshots of it in.
##
## Per ADR-0005's already-registered forbidden patterns (still binding even
## though the ADR itself is [code]Proposed[/code] — see
## [code]docs/registry/architecture.yaml[/code]): this node never reads
## [code]InputEvent.device[/code], never drives anything from
## [code]_unhandled_input()[/code], and never relies on native [Control]
## hover/focus for its highlight or cursor visuals — everything here is
## self-drawn from explicit calls, so it works identically for mouse and
## gamepad callers. This batch wires no input at all; that is deliberate
## (see the task brief) and left for the controller that consumes this view.
class_name BoardView
extends Node2D

## Terrain character (as used by [code]Board.TERRAIN_*[/code] /
## [code]Board.from_ascii()[/code]) -> placeholder texture path. Duplicated
## as string literals rather than importing [code]Board[/code]'s constants,
## for the same reason [BoardCoords] duplicates the board dimensions: this
## is presentation code and must not depend on gameplay code.
const TERRAIN_TEXTURE_PATHS: Dictionary = {
	".": "res://assets/art/placeholder/terrain_ground.png",
	",": "res://assets/art/placeholder/terrain_bush.png",
	"#": "res://assets/art/placeholder/terrain_rubble.png",
}

## Ally piece textures, indexed by [code]sprite_index[/code] (0-4) from the
## dictionaries passed to [method render_pieces].
const ALLY_SPRITE_PATHS: Array[String] = [
	"res://assets/art/placeholder/piece_ally_01.png",
	"res://assets/art/placeholder/piece_ally_02.png",
	"res://assets/art/placeholder/piece_ally_03.png",
	"res://assets/art/placeholder/piece_ally_04.png",
	"res://assets/art/placeholder/piece_ally_05.png",
]

## Single enemy piece texture — the placeholder set only has one; there is
## no per-enemy sprite_index distinction to make yet.
const ENEMY_SPRITE_PATH: String = "res://assets/art/placeholder/piece_enemy_01.png"

const MOVE_HIGHLIGHT_PATH: String = "res://assets/art/placeholder/highlight_move.png"
const ATTACK_HIGHLIGHT_PATH: String = "res://assets/art/placeholder/highlight_attack.png"
const CURSOR_PATH: String = "res://assets/art/placeholder/cursor_outline.png"

## Piece sprite height in pixels. Measured 2026-08-27 (see task evidence):
## the placeholder pieces are 32x40 — 8px taller than a 32x32 cell, by
## design (per the task brief, "比格子高，會超出格子上緣"). Pieces are
## anchored so their sprite bottom sits on the cell's bottom edge, not
## centered in the cell, so the extra height overhangs the top.
const PIECE_SPRITE_HEIGHT: int = 40

## HP bar geometry, in pixels, drawn above each piece's head.
const HP_BAR_WIDTH: int = 20
const HP_BAR_HEIGHT: int = 3
const HP_BAR_GAP_ABOVE_PIECE: int = 4

@onready var _terrain_layer: Node2D = $TerrainLayer
@onready var _move_highlight_layer: Node2D = $MoveHighlightLayer
@onready var _attack_highlight_layer: Node2D = $AttackHighlightLayer
@onready var _pieces_layer: Node2D = $PiecesLayer
@onready var _cursor_sprite: Sprite2D = $CursorSprite


## Renders the terrain layer from [param terrain_rows]: [code]rows[y][/code]
## is the row for that y coordinate, one character per x — same ASCII
## convention as [code]Board.from_ascii()[/code]. Replaces whatever terrain
## was previously rendered.
func render_terrain(terrain_rows: PackedStringArray) -> void:
	_clear_children(_terrain_layer)
	for y: int in range(terrain_rows.size()):
		var row: String = terrain_rows[y]
		for x: int in range(row.length()):
			var terrain_char: String = row.substr(x, 1)
			var path: String = TERRAIN_TEXTURE_PATHS.get(terrain_char, TERRAIN_TEXTURE_PATHS["."])
			var sprite: Sprite2D = Sprite2D.new()
			sprite.texture = load(path)
			sprite.centered = true
			sprite.position = BoardCoords.grid_to_local_center(Vector2i(x, y))
			_terrain_layer.add_child(sprite)


## Renders every piece on the board from [param pieces]. Each entry is a
## [Dictionary] with:
## [codeblock]
## {
##     "cell": Vector2i,       # board position
##     "faction": String,      # "PLAYER" or "ENEMY" (matches the roster
##                              # data file's faction field convention)
##     "sprite_index": int,    # which ALLY_SPRITE_PATHS entry (0-4);
##                              # ignored for "ENEMY" (only one enemy sprite)
##     "hp": int,
##     "hp_max": int,
## }
## [/codeblock]
## Replaces whatever pieces were previously rendered. This method does not
## know or care whether the data came from a live [code]Unit[/code] roster
## or a test fixture — it only reads the dictionary shape above.
func render_pieces(pieces: Array[Dictionary]) -> void:
	_clear_children(_pieces_layer)
	for data: Dictionary in pieces:
		var cell: Vector2i = data["cell"]
		var faction: String = data.get("faction", "PLAYER")
		var sprite_index: int = data.get("sprite_index", 0)
		var hp: int = data.get("hp", 1)
		var hp_max: int = data.get("hp_max", 1)

		var path: String = ENEMY_SPRITE_PATH
		if faction == "PLAYER":
			var clamped_index: int = clampi(sprite_index, 0, ALLY_SPRITE_PATHS.size() - 1)
			path = ALLY_SPRITE_PATHS[clamped_index]

		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = true
		sprite.position = _piece_anchor(cell)
		_pieces_layer.add_child(sprite)

		_pieces_layer.add_child(_build_hp_bar(sprite.position, hp, hp_max))


## Replaces the set of highlighted move-range cells. Pass an empty array to
## clear all move highlights.
func set_move_highlights(cells: Array[Vector2i]) -> void:
	_render_highlight_layer(_move_highlight_layer, cells, MOVE_HIGHLIGHT_PATH)


## Replaces the set of highlighted attack-range cells. Pass an empty array
## to clear all attack highlights.
func set_attack_highlights(cells: Array[Vector2i]) -> void:
	_render_highlight_layer(_attack_highlight_layer, cells, ATTACK_HIGHLIGHT_PATH)


## Shows the cursor outline centered on [param cell].
func set_cursor(cell: Vector2i) -> void:
	_cursor_sprite.visible = true
	_cursor_sprite.position = BoardCoords.grid_to_local_center(cell)


## Hides the cursor outline.
func clear_cursor() -> void:
	_cursor_sprite.visible = false


# Returns the sprite anchor position (centered sprite) for a PIECE_SPRITE_HEIGHT-tall
# piece standing in cell, with its sprite bottom aligned to the cell's bottom edge
# rather than the cell's vertical center — the piece art is taller than one tile and
# is meant to overhang the top, not straddle the tile boundary evenly.
func _piece_anchor(cell: Vector2i) -> Vector2:
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var cell_bottom_y: float = cell_top_left.y + BoardCoords.CELL_SIZE
	var center_x: float = cell_top_left.x + BoardCoords.CELL_SIZE * 0.5
	return Vector2(center_x, cell_bottom_y - PIECE_SPRITE_HEIGHT * 0.5)


# Builds a minimal two-rect HP bar (dark background + proportional fill),
# positioned just above a piece anchored at piece_anchor_pos.
func _build_hp_bar(piece_anchor_pos: Vector2, hp: int, hp_max: int) -> Node2D:
	var bar_root: Node2D = Node2D.new()
	var bar_center_y: float = (
		piece_anchor_pos.y - PIECE_SPRITE_HEIGHT * 0.5 - HP_BAR_GAP_ABOVE_PIECE
	)
	bar_root.position = Vector2(piece_anchor_pos.x, bar_center_y)

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1, 1.0)
	background.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	background.position = Vector2(-HP_BAR_WIDTH * 0.5, -HP_BAR_HEIGHT * 0.5)
	bar_root.add_child(background)

	var fraction: float = 0.0
	if hp_max > 0:
		fraction = clampf(float(hp) / float(hp_max), 0.0, 1.0)
	var fill: ColorRect = ColorRect.new()
	fill.color = Color(0.2, 0.8, 0.2, 1.0) if fraction > 0.25 else Color(0.8, 0.2, 0.2, 1.0)
	fill.size = Vector2(HP_BAR_WIDTH * fraction, HP_BAR_HEIGHT)
	fill.position = Vector2(-HP_BAR_WIDTH * 0.5, -HP_BAR_HEIGHT * 0.5)
	bar_root.add_child(fill)

	return bar_root


# Renders a set of cells onto highlight_layer using texture_path, replacing
# whatever was there before. Shared by set_move_highlights() / set_attack_highlights().
func _render_highlight_layer(
	highlight_layer: Node2D, cells: Array[Vector2i], texture_path: String
) -> void:
	_clear_children(highlight_layer)
	var texture: Texture2D = load(texture_path)
	for cell: Vector2i in cells:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = texture
		sprite.centered = true
		sprite.position = BoardCoords.grid_to_local_center(cell)
		highlight_layer.add_child(sprite)


# Frees every child of layer immediately. Safe to call synchronously here —
# these calls happen outside any signal callback or node-iteration context
# that queue_free()'s deferred removal exists to protect; an immediate free()
# keeps a render call's result fully visible by the very next frame instead
# of leaving one stale frame with both old and new sprites present.
func _clear_children(layer: Node2D) -> void:
	for child: Node in layer.get_children():
		layer.remove_child(child)
		child.free()
