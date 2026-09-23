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
## AttackHighlightLayer, CardTargetHighlightLayer, StatsLayer, CursorSprite.
## [b]Story U-013[/b] adds [code]CardTargetHighlightLayer[/code] — see
## [method set_card_target_highlights]'s own doc comment for why it sits
## above [code]AttackHighlightLayer[/code] (same "must draw above occupied
## cells" reasoning as that layer) and below [code]StatsLayer[/code] (HP bar/
## text must never be painted over, matching every other highlight layer's
## existing relationship to it).
## [br]
## The move layer sits BELOW the pieces while the threat and attack layers
## sit ABOVE them, for a measured reason: the placeholder piece textures are
## fully opaque 32x40
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

## Story U-013 — S2/S2p/S2q target-selection highlight. See [method
## set_card_target_highlights]'s own doc comment for why this is composed
## from primitives ([ColorRect] / [Line2D]) rather than loaded [Texture2D]s
## like every other highlight layer in this file: unlike move/attack/threat,
## no placeholder art exists yet for this state, and this project's own
## precedent for exactly that situation (`hand_bar.gd`'s lock glyph / category
## icon shapes) is to compose from primitives rather than block on an art
## asset. Deliberately the SAME colour for the outline AND the illegal mark —
## per `design/ux/skill-card-play.md`'s Component Inventory ("合法/不合法須
## 拆出成因") and this project's `P-F3` discipline ("無例外"), the outline vs
## outline+X shape difference is what separates legal from illegal, not hue.
const CARD_TARGET_OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
## Distance, in pixels, the outline is inset from the cell's own edge —
## leaves a visible gap from [constant PIECE_SPRITE_HEIGHT]'s top overhang and
## from any adjacent cell's own outline.
const CARD_TARGET_OUTLINE_INSET: float = 3.0
const CARD_TARGET_OUTLINE_WIDTH: float = 2.0
## The illegal-only X mark is inset further than the outline (drawn INSIDE
## it, not on top of it) so the two remain visually separable as two distinct
## strokes rather than merging into one shape at their corners.
const CARD_TARGET_ILLEGAL_MARK_INSET: float = 7.0
const CARD_TARGET_ILLEGAL_MARK_WIDTH: float = 2.0

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

## HP readout contrast fix (`design/art/hp-readout-contrast-fix.md` §2,
## 2026-09-23 manager ruling — "讀法一:整條黑底一起變深"). When a cell's HP
## text is shown WHILE that cell is also the "illegal target" state of
## card-play target selection (S2/S2p/S2q), the ENTIRE [constant
## HP_TEXT_HEIGHT]-tall backing strip uses this value instead of [constant
## HP_TEXT_BG_COLOR] — same RGB, alpha only, no new hue. Deliberately named
## without any word implying the HP VALUE itself changed (one of the three
## obligations attached to the ruling): this is a target-legality indicator,
## not a health effect. [b]Never touch[/b] [constant CARD_TARGET_OUTLINE_COLOR]
## / [constant CARD_TARGET_ILLEGAL_MARK_INSET] or any other X-mark constant to
## "fix" this further — the ruling explicitly keeps the X's size, position,
## colour, alpha and symmetry untouched; this constant is the only thing this
## fix is allowed to change.
const HP_TEXT_BG_COLOR_TARGET_ILLEGAL: Color = Color(0.0, 0.0, 0.0, 0.90)

@onready var _terrain_layer: Node2D = $TerrainLayer
@onready var _move_highlight_layer: Node2D = $MoveHighlightLayer
@onready var _attack_highlight_layer: Node2D = $AttackHighlightLayer
## Story U-013 — S2/S2p/S2q legal/illegal target highlight. Sits above
## [member _pieces_layer] (same reason as [member _threat_highlight_layer] /
## [member _attack_highlight_layer]) and below [member _stats_layer] — see
## [method set_card_target_highlights]'s own doc comment.
@onready var _card_target_highlight_layer: Node2D = $CardTargetHighlightLayer
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
##     "card_target_illegal": bool,  # OPTIONAL — this cell is the "illegal
##                              # target" state of card-play target selection
##                              # while its HP text is shown. Absent = false.
##                              # When true AND show_hp_text is true, the HP
##                              # text background uses
##                              # HP_TEXT_BG_COLOR_TARGET_ILLEGAL instead of
##                              # HP_TEXT_BG_COLOR — see that constant's own
##                              # doc comment. The caller (battle_screen.gd)
##                              # derives this from the SAME legal/illegal
##                              # partition it already computes for
##                              # set_card_target_highlights(), never
##                              # re-derived here — this node makes no rule
##                              # decisions, matching every other flag on this
##                              # dictionary.
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
		var card_target_illegal: bool = data.get("card_target_illegal", false)

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
			_build_stat_block(cell, hp, hp_max, hp_preview, show_hp_text, card_target_illegal)
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


## Story U-013 — replaces the card-play target-selection highlight layer.
## [param legal_cells] gets a hollow square outline; [param illegal_cells]
## gets the SAME outline PLUS an X mark drawn across it — see
## [constant CARD_TARGET_OUTLINE_COLOR]'s own doc comment for why the shape
## difference, not colour, is what separates the two (`P-F3` 無例外). A cell
## that appears in NEITHER array (S2's third state, "不可達或未涉及" — no unit
## stands there at all) is drawn as nothing; absence of any mark IS that
## state, the same convention [code]battle_screen.gd[/code]'s
## [method _refresh_view] already uses to keep the move/attack/threat
## highlight layers mutually exclusive. Pass two empty arrays to clear.
##
## The outline is hollow (never filled) for the same reason [method
## set_threat_highlights]'s ring is hollow (see the class doc comment's
## layer-order note): this layer draws above [member _pieces_layer], and a
## filled highlight would hide whatever piece is standing on the cell.
##
## [b]Caller obligation — this method does not enforce it[/b]: [param
## legal_cells] and [param illegal_cells] must be disjoint. Passing the same
## cell in both draws both an outline and an outline+X stacked on each other,
## which is a caller bug this method has no way to detect (it does not know
## which unit occupies which cell, or which cells are even legally
## meaningful — it only draws exactly what it is given, matching every other
## method on this node).
func set_card_target_highlights(
	legal_cells: Array[Vector2i], illegal_cells: Array[Vector2i]
) -> void:
	_clear_children(_card_target_highlight_layer)
	for cell: Vector2i in legal_cells:
		_card_target_highlight_layer.add_child(_build_card_target_outline(cell))
	for cell: Vector2i in illegal_cells:
		_card_target_highlight_layer.add_child(_build_card_target_outline(cell))
		_card_target_highlight_layer.add_child(_build_card_target_illegal_mark(cell))


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
# sprite's top-edge overhang. card_target_illegal is passed straight through
# to _build_hp_text() — see HP_TEXT_BG_COLOR_TARGET_ILLEGAL's doc comment;
# it never affects the HP bar, only the HP text background.
func _build_stat_block(
	cell: Vector2i, hp: int, hp_max: int, hp_preview: int, show_text: bool,
	card_target_illegal: bool
) -> Node2D:
	var root: Node2D = Node2D.new()
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	root.add_child(_build_hp_bar(cell_top_left, hp, hp_max))
	if show_text:
		root.add_child(
			_build_hp_text(cell_top_left, hp, hp_max, hp_preview, card_target_illegal)
		)
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
# explicitly on both the background and the Label. card_target_illegal swaps
# the WHOLE strip to HP_TEXT_BG_COLOR_TARGET_ILLEGAL (see that constant's own
# doc comment for why the entire strip, not just the rows the X-mark overlaps
# — 2026-09-23 manager ruling, "讀法一").
func _build_hp_text(
	cell_top_left: Vector2, hp: int, hp_max: int, hp_preview: int, card_target_illegal: bool
) -> Node2D:
	var root: Node2D = Node2D.new()
	var strip_top: float = cell_top_left.y + HP_TEXT_TOP_MARGIN
	root.position = Vector2(cell_top_left.x, strip_top)

	var background: ColorRect = ColorRect.new()
	background.color = (
		HP_TEXT_BG_COLOR_TARGET_ILLEGAL if card_target_illegal else HP_TEXT_BG_COLOR
	)
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


# Story U-013 — shared by set_card_target_highlights() for BOTH legal and
# illegal cells: four thin ColorRects forming a hollow square border, inset
# CARD_TARGET_OUTLINE_INSET px from the cell's own edge. See that constant's
# doc comment for why this is composed from primitives.
func _build_card_target_outline(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var top_left: Vector2 = BoardCoords.grid_to_local(cell) + Vector2.ONE * CARD_TARGET_OUTLINE_INSET
	var side: float = BoardCoords.CELL_SIZE - CARD_TARGET_OUTLINE_INSET * 2.0
	var border_width: float = CARD_TARGET_OUTLINE_WIDTH

	var top: ColorRect = ColorRect.new()
	top.color = CARD_TARGET_OUTLINE_COLOR
	top.position = top_left
	top.size = Vector2(side, border_width)
	root.add_child(top)

	var bottom: ColorRect = ColorRect.new()
	bottom.color = CARD_TARGET_OUTLINE_COLOR
	bottom.position = top_left + Vector2(0.0, side - border_width)
	bottom.size = Vector2(side, border_width)
	root.add_child(bottom)

	var left: ColorRect = ColorRect.new()
	left.color = CARD_TARGET_OUTLINE_COLOR
	left.position = top_left
	left.size = Vector2(border_width, side)
	root.add_child(left)

	var right: ColorRect = ColorRect.new()
	right.color = CARD_TARGET_OUTLINE_COLOR
	right.position = top_left + Vector2(side - border_width, 0.0)
	right.size = Vector2(border_width, side)
	root.add_child(right)

	return root


# Story U-013 — the illegal-only X mark: two diagonal Line2Ds, drawn INSIDE
# the outline built by _build_card_target_outline() (see
# CARD_TARGET_ILLEGAL_MARK_INSET's own doc comment for why it is inset
# further, not the same amount). antialiased = false matches
# set_affinity_lines()'s own pixel-art discipline at this project's 480x270
# base resolution.
func _build_card_target_illegal_mark(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var top_left: Vector2 = (
		BoardCoords.grid_to_local(cell) + Vector2.ONE * CARD_TARGET_ILLEGAL_MARK_INSET
	)
	var side: float = BoardCoords.CELL_SIZE - CARD_TARGET_ILLEGAL_MARK_INSET * 2.0
	var top_right: Vector2 = top_left + Vector2(side, 0.0)
	var bottom_left: Vector2 = top_left + Vector2(0.0, side)
	var bottom_right: Vector2 = top_left + Vector2(side, side)

	var diagonal_a: Line2D = Line2D.new()
	diagonal_a.points = PackedVector2Array([top_left, bottom_right])
	diagonal_a.width = CARD_TARGET_ILLEGAL_MARK_WIDTH
	diagonal_a.default_color = CARD_TARGET_OUTLINE_COLOR
	diagonal_a.antialiased = false
	root.add_child(diagonal_a)

	var diagonal_b: Line2D = Line2D.new()
	diagonal_b.points = PackedVector2Array([top_right, bottom_left])
	diagonal_b.width = CARD_TARGET_ILLEGAL_MARK_WIDTH
	diagonal_b.default_color = CARD_TARGET_OUTLINE_COLOR
	diagonal_b.antialiased = false
	root.add_child(diagonal_b)

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
