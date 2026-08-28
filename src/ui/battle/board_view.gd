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
##
## [b]Layer order is deliberate and asymmetric[/b] (child order in
## [code]BoardView.tscn[/code], which is what Node2D draws in): TerrainLayer,
## MoveHighlightLayer, PiecesLayer, AffinityLineLayer, ThreatHighlightLayer,
## AttackHighlightLayer, StatsLayer, CursorSprite. The move layer sits BELOW
## the pieces while the threat and attack layers sit ABOVE them, for a
## measured reason: the placeholder piece textures are fully opaque 32x40
## blocks (verified 2026-08-28 by reading their pixels —
## [code]piece_enemy_01.png[/code] is a single solid color across all 1280
## pixels), and a piece is anchored to cover its whole 32x32 cell plus an 8px
## overhang. Anything drawn under a piece on an occupied cell is therefore
## completely invisible.
## [br]
## Move-range cells can never be occupied ([method Board.reachable_tiles]
## excludes occupied tiles), so that layer loses nothing by staying below.
## Threat-range and attack-range cells are the opposite case — the whole
## point of both is to mark cells that enemies are standing on — so they
## must draw on top or they mark nothing the player can see. This is not
## hypothetical: before 2026-08-28 the attack layer was below the pieces and
## its highlight was 100% hidden behind the enemy sprite on every cell it
## ever drew.
## [br]
## AffinityLineLayer draws above PiecesLayer for the same reason: an affinity
## line is drawn between two units' cells, so it must be visible even when
## both endpoints are occupied by opaque pieces — see
## [method set_affinity_lines] for the dark-backing-stroke technique this
## forces. StatsLayer draws above the two highlight layers so a piece's HP
## bar/text is never painted over by a threat or attack highlight — this was
## a known, logged defect when the stat block lived inside PiecesLayer.
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

## Threat-range highlight — a hollow yellow ring, unlike the two solid
## translucent fills above. The shape difference is load-bearing, not
## decorative: this layer draws ABOVE [code]PiecesLayer[/code] (see the
## class doc comment's layer-order note), so a solid fill would hide the
## piece art underneath. It is also the non-color channel that keeps the
## three highlight kinds distinguishable for a colorblind player — ring vs
## fill survives any hue confusion between yellow and orange.
const THREAT_HIGHLIGHT_PATH: String = "res://assets/art/placeholder/highlight_threat.png"

const CURSOR_PATH: String = "res://assets/art/placeholder/cursor_outline.png"

## Colour vocabulary for [method set_affinity_lines]. Deliberately BoardView's
## own enum rather than [code]AffinityLineStatus.State[/code]: this node must
## not gain a gameplay dependency (same reason [constant TERRAIN_TEXTURE_PATHS]
## duplicates [code]Board[/code]'s terrain characters as string literals). The
## caller ([code]battle_screen.gd[/code], the one class allowed to know both
## sides) does the [code]AffinityLineStatus.State[/code] -> [enum LineTone]
## mapping.
enum LineTone { POSITIVE, NEGATIVE, MUTED }

## [method set_affinity_lines] stroke colours, keyed by [enum LineTone].
const AFFINITY_LINE_COLOR_POSITIVE: Color = Color(0.30, 0.90, 0.35)
const AFFINITY_LINE_COLOR_NEGATIVE: Color = Color(1.0, 0.32, 0.32)
const AFFINITY_LINE_COLOR_MUTED: Color = Color(0.74, 0.74, 0.74, 0.9)

## Dark backing stroke drawn under every affinity line — see
## [method set_affinity_lines] for why it exists.
const AFFINITY_LINE_BACKING_COLOR: Color = Color(0.0, 0.0, 0.0, 0.72)
const AFFINITY_LINE_BACKING_WIDTH: float = 3.0
const AFFINITY_LINE_STROKE_WIDTH: float = 1.0

## Piece sprite height in pixels. Measured 2026-08-27 (see task evidence):
## the placeholder pieces are 32x40 — 8px taller than a 32x32 cell, by
## design (per the task brief, "比格子高，會超出格子上緣"). Pieces are
## anchored so their sprite bottom sits on the cell's bottom edge, not
## centered in the cell, so the extra height overhangs the top.
const PIECE_SPRITE_HEIGHT: int = 40

## HP bar geometry, in pixels — a two-rect bar centered horizontally on the
## cell, its bottom edge [constant HP_BAR_BOTTOM_MARGIN] above the cell's own
## bottom edge. Deliberately anchored to the cell rather than to the piece sprite
## (contrast [constant PIECE_SPRITE_HEIGHT]'s overhang): the stat block must
## stay entirely inside the 32x32 cell so it never pokes into the status bar
## above row-0 pieces — see [method render_pieces].
const HP_BAR_WIDTH: int = 20
const HP_BAR_HEIGHT: int = 3
const HP_BAR_BOTTOM_MARGIN: int = 3

## HP text readout geometry/colour, in pixels — a dark strip across the
## cell's bottom edge with a centered [Label] on top. See [method render_pieces]
## for the normal-vs-preview colour rule.
const HP_TEXT_HEIGHT: int = 10
const HP_TEXT_TOP_MARGIN: int = 1
const HP_TEXT_FONT_SIZE: int = 8
const HP_TEXT_BG_COLOR: Color = Color(0.0, 0.0, 0.0, 0.72)
const HP_TEXT_COLOR_NORMAL: Color = Color.WHITE
const HP_TEXT_COLOR_PREVIEW: Color = Color(1.0, 0.78, 0.28)

@onready var _terrain_layer: Node2D = $TerrainLayer
@onready var _move_highlight_layer: Node2D = $MoveHighlightLayer
@onready var _attack_highlight_layer: Node2D = $AttackHighlightLayer
## Threat-range layer. Sits ABOVE [code]PiecesLayer[/code] in
## [code]BoardView.tscn[/code] — see the class doc comment's layer-order
## note for why that asymmetry with [member _move_highlight_layer] is
## deliberate.
@onready var _threat_highlight_layer: Node2D = $ThreatHighlightLayer
@onready var _pieces_layer: Node2D = $PiecesLayer
## Affinity connection-line layer. Sits above [member _pieces_layer] — see
## the class doc comment's layer-order note and [method set_affinity_lines].
@onready var _affinity_line_layer: Node2D = $AffinityLineLayer
## Per-piece HP bar/text layer. Sits above both highlight layers — see the
## class doc comment's layer-order note and [method render_pieces].
@onready var _stats_layer: Node2D = $StatsLayer
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
##     "show_hp_text": bool,   # OPTIONAL — draw the exact "hp/hp_max"
##                              # readout for this piece. Absent = false.
##                              # Only the selected unit and whatever the
##                              # cursor is pointing at should set it: the
##                              # five player units start stacked in one
##                              # column, and a number on every piece made
##                              # the whole column unreadable (measured
##                              # 2026-08-28 from a screenshot).
##     "hp_preview": int,      # OPTIONAL — projected HP after a previewed
##                              # attack. Absent, or -1, means no preview.
## }
## [/codeblock]
## Replaces whatever pieces were previously rendered. This method does not
## know or care whether the data came from a live [code]Unit[/code] roster
## or a test fixture — it only reads the dictionary shape above.
##
## Splits its output across two layers: the piece sprite goes to
## [member _pieces_layer]; the HP bar and HP text go to [member _stats_layer]
## (see the class doc comment's layer-order note for why — a stat block
## living inside [member _pieces_layer] was a known, logged defect: it got
## painted over by the threat/attack highlight layers). All stat-block
## geometry stays entirely inside the piece's own 32x32 cell — unlike the
## piece sprite, which is allowed to overhang the cell's top edge (see
## [constant PIECE_SPRITE_HEIGHT]), a stat block that also overhung would
## paint into the status bar above row-0 cells.
func render_pieces(pieces: Array[Dictionary]) -> void:
	_clear_children(_pieces_layer)
	_clear_children(_stats_layer)
	for data: Dictionary in pieces:
		var cell: Vector2i = data["cell"]
		var faction: String = data.get("faction", "PLAYER")
		var sprite_index: int = data.get("sprite_index", 0)
		var hp: int = data.get("hp", 1)
		var hp_max: int = data.get("hp_max", 1)
		var hp_preview: int = data.get("hp_preview", -1)
		var show_hp_text: bool = data.get("show_hp_text", false)

		var path: String = ENEMY_SPRITE_PATH
		if faction == "PLAYER":
			var clamped_index: int = clampi(sprite_index, 0, ALLY_SPRITE_PATHS.size() - 1)
			path = ALLY_SPRITE_PATHS[clamped_index]

		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = true
		sprite.position = _piece_anchor(cell)
		_pieces_layer.add_child(sprite)

		_stats_layer.add_child(
			_build_stat_block(cell, hp, hp_max, hp_preview, show_hp_text)
		)


## Replaces the affinity connection lines drawn in [member _affinity_line_layer].
## Each entry of [param lines] is a [Dictionary]:
## [codeblock]
## { "from": Vector2i, "to": Vector2i, "tone": int }  # tone is a LineTone
## [/codeblock]
## Pass an empty array to clear.
##
## Draws TWO [Line2D]s per entry — a dark backing stroke first, then the
## coloured stroke on top. [b]Why the backing exists:[/b] this layer draws
## above [member _pieces_layer] (see the class doc comment's layer-order
## note), and the placeholder pieces are fully opaque solid-colour blocks. A
## 1px line alone would be lost against a similarly-bright piece. A 3px total
## band is the smallest thing that still reads, and unlike a filled highlight
## it leaves the terrain underneath legible — the previous batch of highlight
## work was sent back for review once precisely because a fill swallowed the
## terrain, so this must not widen that band. Both strokes use
## [code]antialiased = false[/code]: this is a pixel-art project at 480x270 —
## antialiasing would produce off-palette fringe pixels.
func set_affinity_lines(lines: Array[Dictionary]) -> void:
	_clear_children(_affinity_line_layer)
	for entry: Dictionary in lines:
		var from_cell: Vector2i = entry["from"]
		var to_cell: Vector2i = entry["to"]
		var tone: LineTone = entry["tone"]
		var points: PackedVector2Array = PackedVector2Array([
			BoardCoords.grid_to_local_center(from_cell),
			BoardCoords.grid_to_local_center(to_cell),
		])

		var backing: Line2D = Line2D.new()
		backing.points = points
		backing.width = AFFINITY_LINE_BACKING_WIDTH
		backing.default_color = AFFINITY_LINE_BACKING_COLOR
		backing.antialiased = false
		_affinity_line_layer.add_child(backing)

		var stroke: Line2D = Line2D.new()
		stroke.points = points
		stroke.width = AFFINITY_LINE_STROKE_WIDTH
		stroke.default_color = _line_color_for_tone(tone)
		stroke.antialiased = false
		_affinity_line_layer.add_child(stroke)


## Replaces the set of highlighted move-range cells. Pass an empty array to
## clear all move highlights.
func set_move_highlights(cells: Array[Vector2i]) -> void:
	_render_highlight_layer(_move_highlight_layer, cells, MOVE_HIGHLIGHT_PATH)


## Replaces the set of highlighted attack-range cells. Pass an empty array
## to clear all attack highlights.
func set_attack_highlights(cells: Array[Vector2i]) -> void:
	_render_highlight_layer(_attack_highlight_layer, cells, ATTACK_HIGHLIGHT_PATH)


## Replaces the set of highlighted threat-range cells — the cells this unit
## could attack this turn if it moves first, as opposed to
## [method set_attack_highlights]'s "can be hit from where it stands right
## now". Pass an empty array to clear all threat highlights.
##
## The caller decides which cells to pass; this method draws exactly what it
## is given and makes no rule decision of its own (same contract as every
## other method on this node). [BattleScreen] passes the threat envelope
## minus the move cells minus the currently-attackable cells, so the three
## highlight kinds never overlap on screen.
func set_threat_highlights(cells: Array[Vector2i]) -> void:
	_render_highlight_layer(_threat_highlight_layer, cells, THREAT_HIGHLIGHT_PATH)


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


# Groups the HP bar and HP text for one piece under a single Node2D so
# render_pieces() can add exactly one child per piece to _stats_layer (kept
# consistent with _clear_children()'s "one throwaway subtree per render"
# shape used elsewhere in this file). cell is the piece's board cell — every
# child's geometry is derived from BoardCoords.grid_to_local(cell), never
# from the piece sprite's anchor, so the stat block cannot inherit the
# sprite's top-edge overhang.
func _build_stat_block(
	cell: Vector2i, hp: int, hp_max: int, hp_preview: int, show_text: bool
) -> Node2D:
	var root: Node2D = Node2D.new()
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	root.add_child(_build_hp_bar(cell_top_left, hp, hp_max))
	if show_text:
		root.add_child(_build_hp_text(cell_top_left, hp, hp_max, hp_preview))
	return root


# Builds a minimal two-rect HP bar (dark background + proportional fill),
# centered horizontally on the cell with its top edge HP_BAR_TOP_MARGIN below
# cell_top_left.y — see the HP_BAR_* constants' doc comment for why this is
# anchored to the cell rather than the piece sprite.
func _build_hp_bar(cell_top_left: Vector2, hp: int, hp_max: int) -> Node2D:
	var bar_root: Node2D = Node2D.new()
	var center_x: float = cell_top_left.x + BoardCoords.CELL_SIZE * 0.5
	var bar_center_y: float = (
		cell_top_left.y + BoardCoords.CELL_SIZE - HP_BAR_BOTTOM_MARGIN - HP_BAR_HEIGHT * 0.5
	)
	bar_root.position = Vector2(center_x, bar_center_y)

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


# Builds the HP text readout: a dark ColorRect backing the cell's TOP
# strip with a centered Label on top. Top, not bottom: at the bottom the
# glyphs of row-5 pieces were sliced in half by the controls-hint bar at
# y=231, and the sliced number included the damage projection, which is the
# single number this whole readout exists to show. Normal text is "hp/hp_max" in white; a
# preview (hp_preview >= 0) instead renders "hp→hp_preview" in amber, so the
# colour change itself signals "this is a projection, not the current value"
# (see render_pieces()'s doc comment). The Label is a Control parented under
# a Node2D, so it gets no automatic layout — position and size are set
# explicitly on both the background and the Label.
func _build_hp_text(cell_top_left: Vector2, hp: int, hp_max: int, hp_preview: int) -> Node2D:
	var root: Node2D = Node2D.new()
	var strip_top: float = cell_top_left.y + HP_TEXT_TOP_MARGIN
	root.position = Vector2(cell_top_left.x, strip_top)

	var background: ColorRect = ColorRect.new()
	background.color = HP_TEXT_BG_COLOR
	background.position = Vector2.ZERO
	background.size = Vector2(BoardCoords.CELL_SIZE, HP_TEXT_HEIGHT)
	root.add_child(background)

	var label: Label = Label.new()
	label.position = Vector2.ZERO
	label.size = Vector2(BoardCoords.CELL_SIZE, HP_TEXT_HEIGHT)
	label.add_theme_font_size_override("font_size", HP_TEXT_FONT_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hp_preview >= 0:
		label.text = "%d→%d" % [hp, hp_preview]
		label.add_theme_color_override("font_color", HP_TEXT_COLOR_PREVIEW)
	else:
		label.text = "%d/%d" % [hp, hp_max]
		label.add_theme_color_override("font_color", HP_TEXT_COLOR_NORMAL)
	root.add_child(label)

	return root


# Maps LineTone -> stroke colour for set_affinity_lines().
func _line_color_for_tone(tone: LineTone) -> Color:
	match tone:
		LineTone.POSITIVE:
			return AFFINITY_LINE_COLOR_POSITIVE
		LineTone.NEGATIVE:
			return AFFINITY_LINE_COLOR_NEGATIVE
		_:
			return AFFINITY_LINE_COLOR_MUTED


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
