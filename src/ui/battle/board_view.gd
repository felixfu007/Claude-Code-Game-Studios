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
## ImpassableTerrainLayer, MoveHighlightLayer, PiecesLayer, MoveUnreachableLayer,
## AffinityLineLayer, ThreatHighlightLayer, AttackHighlightLayer, AttackLosBlockedLayer,
## CardTargetHighlightLayer, StatsLayer, ActionFlagLayer, CursorSprite.
## [b]Story U-013[/b] adds [code]CardTargetHighlightLayer[/code] — see
## [method set_card_target_highlights]'s own doc comment for why it sits
## above [code]AttackHighlightLayer[/code] (same "must draw above occupied
## cells" reasoning as that layer) and below [code]StatsLayer[/code] (HP bar/
## text must never be painted over, matching every other highlight layer's
## existing relationship to it).
## [br]
## [b]Story 014[/b] adds [code]MoveUnreachableLayer[/code] (the move-range
## three unreachable states — see [method set_move_unreachable_highlights])
## and [code]AttackLosBlockedLayer[/code] (the attack-range third layer — see
## [method set_attack_los_blocked_highlights]). [code]MoveUnreachableLayer[/code]
## sits ABOVE [code]PiecesLayer[/code] for the same reason
## [code]ThreatHighlightLayer[/code] does — its
## [code]blocked_by_occupancy[/code] cells are, by construction, usually
## standing on a unit. It sits BELOW [code]AttackHighlightLayer[/code] /
## [code]ThreatHighlightLayer[/code] so that an attack or threat mark (richer,
## higher-priority information — a cell can be both "I can't move here" and
## "I can attack this") visually wins on any cell both families would
## otherwise mark; [code]battle_screen.gd[/code] additionally excludes those
## cells from the arrays it passes in, so this is belt-and-suspenders, not the
## only protection. [code]AttackLosBlockedLayer[/code] sits directly above
## [code]AttackHighlightLayer[/code] (the two never share a cell by
## construction — see that method's own doc comment) and below
## [code]CardTargetHighlightLayer[/code]/[code]StatsLayer[/code], matching
## every other highlight layer's relationship to those two.
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

## Directory of the final (non-placeholder) 32x40 ally piece sprites
## (story-037; path fixed by art-director 2026-11-11). Files are
## [code]char_<code>_piece_idle_01.png[/code]. A missing file silently falls
## back to the placeholder in [constant ALLY_SPRITE_PATHS].
const FINAL_PIECE_DIR: String = "res://assets/art/characters/pieces/"

## Character codes, same index semantics as [constant ALLY_SPRITE_PATHS].
const FINAL_PIECE_CODES: Array[String] = ["jia", "yi", "bing", "ding", "wu"]

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

## 攻擊範圍的半透明紅底與斜線染色,見 [method set_threat_highlights]。
const THREAT_FILL_COLOR: Color = Color(0.85, 0.15, 0.1, 0.3)
const THREAT_STRIPE_TINT: Color = Color(1.0, 0.45, 0.4, 1.0)

## 移動範圍的亮藍半透明底與框線染色,見 [method set_move_highlights](Story 028 I)。
const MOVE_FILL_COLOR: Color = Color(0.2, 0.55, 1.0, 0.4)
const MOVE_FRAME_TINT: Color = Color(0.5, 0.8, 1.0, 1.0)

const CURSOR_PATH: String = "res://assets/art/placeholder/cursor_outline.png"

## Story 014 — move-range unreachable-state markers consumed by [method
## set_move_unreachable_highlights]. Composed from primitives ([ColorRect] /
## [Line2D]), the same precedent [constant CARD_TARGET_OUTLINE_COLOR]'s own
## doc comment already cites for this exact situation (no placeholder PNG
## exists for these three states; this project's precedent is to compose
## from primitives rather than block on an art asset) — dedicated constants
## rather than reusing [constant CARD_TARGET_OUTLINE_COLOR] so the two
## unrelated semantics (card-target legality vs. move-range reachability)
## never share one source of truth, matching the reasoning
## `technical-preferences.md`'s "(A) 的精確定義" section gives for why
## "two call sites happen to agree today" is not the same as "share one
## formula".
##
## blocked_by_occupancy (`B \ A`) is drawn as a hollow outline, no fill, no
## inner pattern — the "ring vs fill" vocabulary [constant
## THREAT_HIGHLIGHT_PATH]'s own doc comment established, reused per this
## story's own instruction rather than inventing a new one.
const MOVE_BLOCKED_OUTLINE_COLOR: Color = Color(0.85, 0.85, 0.85, 0.85)
const MOVE_BLOCKED_OUTLINE_INSET: float = 4.0
const MOVE_BLOCKED_OUTLINE_WIDTH: float = 2.0

## blocked_by_terrain (`C \ B`) additional marking, drawn INSIDE [constant
## MOVE_BLOCKED_OUTLINE_COLOR]'s outline — three short horizontal bars, a
## different pattern family from every diagonal-line mark elsewhere in this
## file ([method _build_card_target_illegal_mark]'s two-diagonal X,
## [constant ATTACK_LOS_BLOCKED_OUTLINE_COLOR]'s single diagonal slash) so
## none of the three can be mistaken for one another under `P-F3`'s
## grayscale test. 🔴 Structurally always empty today — every terrain
## character in [code]Board.TERRAIN_TABLE[/code] is currently passable (see
## [method BattleController.move_targets_breakdown]'s own doc comment) — but
## implemented in full so the visual contract exists before any impassable
## terrain data does.
const MOVE_TERRAIN_HATCH_COLOR: Color = Color(0.85, 0.85, 0.85, 0.85)
const MOVE_TERRAIN_HATCH_WIDTH: float = 2.0
const MOVE_TERRAIN_HATCH_INSET: float = 8.0

## out_of_range (`Grid \ C`) marker — deliberately the quietest of the three
## unreachable markers: a small centered dot, not a full-cell mark. This is
## overwhelmingly the most common of the four move-range states (everything
## outside walking reach), and GDD Visual/Audio §1's own preamble ranks
## Challenge over Sensation and warns against any treatment that forces a
## "re-confirm" cost on the player — painting a full-cell mark on every far
## tile would be exactly that kind of noise. A small dot is still an
## independent, non-color SHAPE (distinct in both size and form from the
## fill/outline/hatch marks used for the other three states), not a reliance
## on "nothing is drawn" the way [method set_card_target_highlights]'s third
## state works — GDD AC-13 and UX pattern `P-D1` both frame all four states
## as needing an independent marker, not three states plus a default.
## 🔴 2026-10-15 管理者裁決:**保留這個點,不要改成「不畫」。**
##
## 背景:「移動力不足」是四態裡佔格數最多的一態 —— 選取任何單位時,
## 棋盤上幾乎所有空格都屬於它。實作者當時把「畫小點 vs 完全不畫」標為
## 自己的判斷而非裁決,並誠實指出它與本作「越安靜越好」的設計傾向有衝突。
##
## **管理者選「保留」,理由不只是規格字面(AC 的「四者皆須有獨立的非色彩
## 通道視覺標記(無例外)」),而是它真的在傳達資訊**:玩家看得出
## 「這一格我有評估過,是距離不夠」與「這一格根本不在考慮範圍內」的差別。
## 🔴 **在四態互斥且窮盡的設計下,「什麼都不畫」等於悄悄引入第五種狀態**
## —— 而空白同時代表「走不到」與「根本沒選單位」,玩家分不出系統有沒有在回應他。
##
## ⚠️ **被跳過的兩個選項**:①改成不畫(代價:上述歧義)
## ②等管理者在家中複核 M4 截圖後再決定(代價:若屆時改判,那批截圖要重拍)。
## 📌 **所以:下一個人看到棋盤上一大片小灰點,那是裁決後的預期行為,不是沒清乾淨。**
const MOVE_OUT_OF_RANGE_DOT_COLOR: Color = Color(0.6, 0.6, 0.6, 0.45)
const MOVE_OUT_OF_RANGE_DOT_SIZE: float = 6.0

## Story 014 — attack-range third layer ("範圍內但視線被擋",
## [method set_attack_los_blocked_highlights]). Hollow outline (same
## technique as [constant MOVE_BLOCKED_OUTLINE_COLOR], dedicated colour so
## the move-family and attack-family outlines are never visually conflated
## even though the two are never expected on the same cell simultaneously)
## plus a single diagonal slash — distinct from [constant
## THREAT_HIGHLIGHT_PATH]'s plain ring, from [method
## _build_card_target_illegal_mark]'s two-diagonal X, and from [constant
## MOVE_TERRAIN_HATCH_COLOR]'s three horizontal bars.
const ATTACK_LOS_BLOCKED_OUTLINE_COLOR: Color = Color(1.0, 0.55, 0.15, 0.9)
const ATTACK_LOS_BLOCKED_OUTLINE_INSET: float = 4.0
const ATTACK_LOS_BLOCKED_OUTLINE_WIDTH: float = 2.0
const ATTACK_LOS_BLOCKED_SLASH_INSET: float = 8.0
const ATTACK_LOS_BLOCKED_SLASH_WIDTH: float = 2.0

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
## There is deliberately no "muted" member: a zero-effect line is not drawn on
## the board at all (design/ux/affinity-line-display.md R3).
enum LineTone { POSITIVE, NEGATIVE }

## Line shape = the RELATION (R1): SOLID for 好感, ZIGZAG for 惡感. Independent
## of [enum LineTone] (the EFFECT, R2).
enum LineShape { SOLID, ZIGZAG }

## Midpoint plaque symbol (R5), drawn from pixel rects, never a font.
enum LineSymbol { PLUS, MINUS }

## [method set_affinity_lines] stroke colours, keyed by [enum LineTone].
## (Colour-blind mode hook: a future mode swaps these two values only.)
const AFFINITY_LINE_COLOR_POSITIVE: Color = Color(0.30, 0.90, 0.35)
const AFFINITY_LINE_COLOR_NEGATIVE: Color = Color(1.0, 0.32, 0.32)

## Dark backing stroke drawn under every affinity line — see
## [method set_affinity_lines] for why it exists.
const AFFINITY_LINE_BACKING_COLOR: Color = Color(0.0, 0.0, 0.0, 0.72)
const AFFINITY_LINE_BACKING_WIDTH: float = 3.0
const AFFINITY_LINE_STROKE_WIDTH: float = 1.0

## Zigzag parameters (art-director's UNVERIFIED initial values; tune after
## the sample sheet). Amplitude is the perpendicular offset of interior
## vertices; half-period is the target along-line length of one segment.
const AFFINITY_ZIGZAG_AMPLITUDE: float = 2.0
const AFFINITY_ZIGZAG_HALF_PERIOD: float = 4.0
## Minimum segment count; 1 would be a straight line (violates R1).
const AFFINITY_ZIGZAG_MIN_SEGMENTS: int = 3
## Line2D settings that keep zigzag corners sharp and ends square.
const AFFINITY_LINE_JOINT_MODE: Line2D.LineJointMode = Line2D.LINE_JOINT_SHARP
const AFFINITY_LINE_CAP_MODE: Line2D.LineCapMode = Line2D.LINE_CAP_NONE
const AFFINITY_LINE_SHARP_LIMIT: float = 2.0

## Midpoint plaque: opaque dark tile + pixel glyph. The tile's top-left is
## [code]mid - (PLAQUE_SIZE / 2)[/code] in integer maths (7 -> 3).
const AFFINITY_PLAQUE_SIZE: int = 7
const AFFINITY_PLAQUE_GLYPH_SIZE: int = 5
const AFFINITY_PLAQUE_COLOR: Color = Color(0.05, 0.05, 0.07, 1.0)
## When a + and a - plaque share one midpoint they sit side by side: + left,
## - right, centres offset by this many px each way.
const AFFINITY_PLAQUE_SPLIT_OFFSET: int = 4

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
const HP_TEXT_HEIGHT: int = 8
const HP_TEXT_TOP_MARGIN: int = 0
const HP_TEXT_FONT_SIZE: int = 8
## story-039 棋子標記字樣式(art-director 2026-11-12;色取自色盤既有色)。
const PIECE_LABEL_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")
const PIECE_LABEL_FONT_SIZE: int = 11
const PIECE_LABEL_SIZE: Vector2 = Vector2(12, 14)
const PIECE_LABEL_TOP_OFFSET_IN_CELL: int = 8
const PIECE_LABEL_COLOR_ALLY: Color = Color("#FFFFFF")
const PIECE_LABEL_COLOR_ENEMY: Color = Color("#FF5252")
const PIECE_LABEL_OUTLINE_COLOR: Color = Color("#0E0F14")
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

## Story 015 — persistent per-unit action-economy badge ordinal consumed by
## [method render_pieces] via the OPTIONAL "action_flag" dictionary entry
## (GDD States and Transitions' "可行動" compound state — 皆未用/只剩攻擊/
## 只剩移動/已行動). Deliberately BoardView's own enum rather than
## [code]TurnOrder.ActionState[/code]: this node must not gain a gameplay
## dependency (same reason [enum LineTone] exists instead of importing
## [code]AffinityLineStatus.State[/code] directly — see that enum's own doc
## comment). The caller ([code]battle_screen.gd[/code]) does the
## [code]TurnOrder.ActionState[/code] -> [enum ActionFlag] mapping.
##
## [b]Unlike every other per-piece flag on the [method render_pieces]
## dictionary (show_hp_text, card_target_illegal), this one is never gated on
## selection or cursor focus[/b] — GDD's own requirement is "常駐於棋盤上，
## 不需要選取或開啟面板才看得到" (persistent; visible without selecting the
## unit or opening a panel). [method render_pieces] draws a marker for this
## field on every piece it is given, unconditionally.
enum ActionFlag { NONE_USED, ATTACK_ONLY, MOVE_ONLY, DONE }

## [enum ActionFlag] badge geometry — TWO small square "pips" anchored to the
## piece SPRITE's top-right corner (not the cell's — contrast [constant
## HP_BAR_WIDTH]'s doc comment, which anchors to the cell specifically so the
## HP strip never leaves the 32x32 bounds). Anchoring to the sprite instead
## deliberately places this badge in the [constant PIECE_SPRITE_HEIGHT]
## overhang zone ABOVE the cell's own top edge, so it can never overlap
## [method _build_hp_text]'s strip (which lives entirely inside the cell,
## per that method's own "glyphs sliced in half" doc comment) — the two
## persistent per-piece badges this file draws occupy disjoint vertical
## bands by construction, not by coincidence.
##
## The left pip reports MOVE availability, the right pip reports ATTACK
## availability (fixed order, see [method _build_action_flag_marker]) — HOLLOW
## (outline only) means that action is still available, FILLED (solid) means
## it has been spent. This directly encodes all four [enum ActionFlag] values
## as two independent bits rather than one opaque 4-way code, and composes
## into a shape family ("a PAIR of adjacent micro-badges, exactly one or
## both or neither filled") that does not exist anywhere else in this file —
## every other hollow-outline or solid-fill mark here is a SINGLE full-cell
## (24-28px) shape, never a pair of ~5px pips glued to a piece's corner. See
## [method _build_action_flag_marker]'s own doc comment for the full
## distinguishability argument against this file's other seven shape
## families (solid fill, ring, hollow outline, outline+3-bars, outline+
## 1-slash, outline+X, centered dot).
const ACTION_FLAG_PIP_SIZE: float = 5.0
const ACTION_FLAG_PIP_GAP: float = 1.0
const ACTION_FLAG_PIP_MARGIN: float = 1.0
const ACTION_FLAG_PIP_BORDER_WIDTH: float = 1.0
## Dedicated near-white constant rather than reusing [constant
## CARD_TARGET_OUTLINE_COLOR] — same "two unrelated semantics never share one
## source of truth" discipline [constant MOVE_BLOCKED_OUTLINE_COLOR]'s doc
## comment already establishes, even though the two colours happen to look
## similar today.
const ACTION_FLAG_PIP_COLOR: Color = Color(0.95, 0.95, 0.95, 0.95)

## Story 015 — terrain-impassability marker ([method
## Board.passable] == false) consumed by [method
## set_impassable_terrain_highlights]. A checkerboard half-fill — two
## diagonally-opposite quadrants of the cell solid, the other two left fully
## transparent so the terrain texture beneath still reads through — a shape
## family none of this file's other seven (solid fill, ring, hollow outline,
## outline+3-bars, outline+1-slash, outline+X, centered dot) uses: none of
## them alternates solid/empty QUADRANTS of the same cell. Deliberately dark
## and desaturated rather than reusing any existing highlight colour
## (`P-F3`): this is a terrain-level fact, true regardless of whose turn it
## is or what is selected, and must read as visually distinct from every
## selection-dependent overlay in this file.
const IMPASSABLE_TERRAIN_CHECKER_COLOR: Color = Color(0.05, 0.05, 0.05, 0.6)

@onready var _terrain_layer: Node2D = $TerrainLayer
## Story 015 — terrain-impassability marker layer. Sits directly above
## [member _terrain_layer] and below [member _move_highlight_layer] — a
## terrain-level fact belongs at the bottom of the stack, same reasoning
## [member _move_highlight_layer] being BELOW [member _pieces_layer] already
## establishes (see the class doc comment's layer-order note). No unit can
## ever stand on an impassable cell (a board/rule guarantee this node takes
## on faith, same as every other layer here), so this layer never competes
## with [member _pieces_layer] for the same pixels.
@onready var _impassable_terrain_layer: Node2D = $ImpassableTerrainLayer
@onready var _move_highlight_layer: Node2D = $MoveHighlightLayer
@onready var _attack_highlight_layer: Node2D = $AttackHighlightLayer
## Story 014 — attack-range third layer ("in range but LOS-blocked"). Sits
## directly above [member _attack_highlight_layer] — see the class doc
## comment's layer-order note.
@onready var _attack_los_blocked_layer: Node2D = $AttackLosBlockedLayer
## Story 014 — move-range unreachable three-state layer (blocked_by_occupancy
## / blocked_by_terrain / out_of_range). Sits above [member _pieces_layer] —
## see the class doc comment's layer-order note and
## [method set_move_unreachable_highlights].
@onready var _move_unreachable_layer: Node2D = $MoveUnreachableLayer
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
## Story 015 — persistent per-unit action-flag badge layer. Sits ABOVE
## [member _stats_layer] — the TOPMOST gameplay-info layer before
## [member _cursor_sprite] — so this badge can never be hidden behind any
## highlight overlay (move/attack/threat/card-target) or the HP bar/text,
## matching GDD's "persistent, always visible" requirement for this exact
## marker. See [constant ACTION_FLAG_PIP_SIZE]'s own doc comment for why this
## does not actually compete with [member _stats_layer]'s HP text for pixels
## despite being drawn above it.
@onready var _action_flag_layer: Node2D = $ActionFlagLayer
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


## Story 015 — replaces the set of terrain cells whose [method Board.passable]
## is false (GDD Tuning Knobs #4). Pass an empty array to clear. This is a
## property of the TERRAIN ITSELF, not a per-frame selection-dependent
## overlay — the caller is expected to compute [param cells] once (this
## project's own forbidden-pattern registry bars procedural/runtime terrain
## generation; GDD terrain is hand-authored and does not change mid-battle)
## and call this once (e.g. alongside [method render_terrain] in
## [code]_ready()[/code]), not on every refresh.
##
## 🔴 Structurally draws zero cells against the project's shipped level data
## today — [code]vs01_terrain.txt[/code]'s three registered terrain
## characters are all [code]passable=true[/code] (GDD Tuning Knobs #4
## starting recommendation) — but implemented in full so the visual contract
## exists before any impassable terrain data does, same precedent [constant
## MOVE_TERRAIN_HATCH_COLOR]'s own doc comment already establishes for
## exactly this situation.
func set_impassable_terrain_highlights(cells: Array[Vector2i]) -> void:
	_clear_children(_impassable_terrain_layer)
	for cell: Vector2i in cells:
		_impassable_terrain_layer.add_child(_build_impassable_terrain_marker(cell))


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
##     "action_flag": int,     # OPTIONAL — an [enum ActionFlag] ordinal
##                              # (皆未用/只剩攻擊/只剩移動/已行動). Absent =
##                              # NONE_USED. The caller (battle_screen.gd)
##                              # maps [code]TurnOrder.ActionState[/code] ->
##                              # [enum ActionFlag] — see that enum's own doc
##                              # comment for why this node never imports
##                              # TurnOrder itself. Unlike every other flag on
##                              # this dictionary, drawn UNCONDITIONALLY for
##                              # every piece — never gated on show_hp_text,
##                              # selection, or cursor focus (GDD: "常駐於
##                              # 棋盤上，不需要選取或開啟面板才看得到").
## }
## [/codeblock]
## Replaces whatever pieces were previously rendered. This method does not
## know or care whether the data came from a live [code]Unit[/code] roster
## or a test fixture — it only reads the dictionary shape above.
##
## Splits its output across three layers: the piece sprite goes to
## [member _pieces_layer]; the HP bar and HP text go to [member _stats_layer]
## (see the class doc comment's layer-order note for why — a stat block
## living inside [member _pieces_layer] was a known, logged defect: it got
## painted over by the threat/attack highlight layers); the action-flag badge
## goes to [member _action_flag_layer] (Story 015 — see that member's own doc
## comment for why it sits even above [member _stats_layer]). All stat-block
## geometry stays entirely inside the piece's own 32x32 cell — unlike the
## piece sprite, which is allowed to overhang the cell's top edge (see
## [constant PIECE_SPRITE_HEIGHT]), a stat block that also overhung would
## paint into the status bar above row-0 cells. The action-flag badge is the
## one exception: it is deliberately anchored to the SPRITE's overhang zone,
## not the cell — see [constant ACTION_FLAG_PIP_SIZE]'s own doc comment.
func render_pieces(pieces: Array[Dictionary]) -> void:
	_clear_children(_pieces_layer)
	_clear_children(_stats_layer)
	_clear_children(_action_flag_layer)
	var label_used: int = 0
	# Sprites are added in draw order (cell y ascending) so a lower row's piece,
	# whose head overhangs into the row above, paints over the upper piece's feet.
	for piece_index: int in piece_draw_order(pieces):
		var piece: Dictionary = pieces[piece_index]
		var piece_cell: Vector2i = piece["cell"]
		var piece_path: String = resolve_piece_sprite_path(
			piece.get("faction", "PLAYER"), piece.get("sprite_index", 0)
		)
		var piece_sprite: Sprite2D = Sprite2D.new()
		piece_sprite.texture = load(piece_path)
		piece_sprite.centered = true
		piece_sprite.position = _piece_anchor(piece_cell)
		_pieces_layer.add_child(piece_sprite)
	for data: Dictionary in pieces:
		var cell: Vector2i = data["cell"]
		var hp: int = data.get("hp", 1)
		var hp_max: int = data.get("hp_max", 1)
		var hp_preview: int = data.get("hp_preview", -1)
		var show_hp_text: bool = data.get("show_hp_text", false)
		var card_target_illegal: bool = data.get("card_target_illegal", false)
		var action_flag: ActionFlag = data.get("action_flag", ActionFlag.NONE_USED)

		_stats_layer.add_child(_build_stat_block(
			cell, hp, hp_max, hp_preview, show_hp_text, card_target_illegal
		))
		var label_text: String = data.get("label", "")
		if label_text != "":
			_apply_piece_label(
				label_used, BoardCoords.grid_to_local(cell), label_text,
				data.get("faction", "PLAYER") == "PLAYER"
			)
			label_used += 1

		_action_flag_layer.add_child(_build_action_flag_marker(cell, action_flag))
	for i: int in range(label_used, _piece_label_pool.size()):
		_piece_label_pool[i].visible = false


## Resolves which texture path a piece should use (story-037). Enemy pieces
## always use [constant ENEMY_SPRITE_PATH]. Ally [param sprite_index] is
## clamped to 0-4; the final art path is used when [param exists_fn] (a
## [Callable] taking a path and returning bool; defaults to
## [method ResourceLoader.exists]) says it exists, otherwise the placeholder.
## Never pushes errors for a missing final file.
static func resolve_piece_sprite_path(
	faction: String, sprite_index: int, exists_fn: Callable = Callable()
) -> String:
	if faction != "PLAYER":
		return ENEMY_SPRITE_PATH
	var clamped_index: int = clampi(sprite_index, 0, ALLY_SPRITE_PATHS.size() - 1)
	var final_path: String = (
		FINAL_PIECE_DIR + "char_" + FINAL_PIECE_CODES[clamped_index] + "_piece_idle_01.png"
	)
	var found: bool = (
		exists_fn.call(final_path) if exists_fn.is_valid() else ResourceLoader.exists(final_path)
	)
	if found:
		return final_path
	return ALLY_SPRITE_PATHS[clamped_index]


## Returns indices into [param pieces] in sprite draw order: cell y ascending,
## ties broken by original index (stable), so lower-row pieces paint in front.
static func piece_draw_order(pieces: Array[Dictionary]) -> Array[int]:
	var order: Array[int] = []
	for i: int in range(pieces.size()):
		order.append(i)
	order.sort_custom(
		func(a: int, b: int) -> bool:
			var ya: int = (pieces[a]["cell"] as Vector2i).y
			var yb: int = (pieces[b]["cell"] as Vector2i).y
			if ya != yb:
				return ya < yb
			return a < b
	)
	return order


## Replaces the affinity connection lines drawn in [member _affinity_line_layer].
## Each entry of [param lines] is a [Dictionary]:
## [codeblock]
## { "from": Vector2i, "to": Vector2i, "tone": int, "shape": int, "symbol": int }
## # tone = LineTone, shape = LineShape, symbol = LineSymbol
## [/codeblock]
## Pass an empty array to clear. Entries are assumed already filtered (the
## caller omits zero-effect lines); this function performs no state mapping.
##
## Draws TWO [Line2D]s per entry — a dark backing stroke first, then the
## coloured stroke on top (both follow the zigzag vertices for
## [constant LineShape.ZIGZAG]) — then, after all lines, one midpoint plaque
## per distinct midpoint/symbol (same layer, drawn above the lines).
## [b]Why the backing exists:[/b] this layer draws
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
	# midpoint (Vector2i) -> {LineSymbol: true}; midpoints are always integers
	# because grid centres are integers and cell distances are multiples of 32.
	var plaques: Dictionary[Vector2i, Dictionary] = {}
	for entry: Dictionary in lines:
		var from_center: Vector2 = BoardCoords.grid_to_local_center(entry["from"])
		var to_center: Vector2 = BoardCoords.grid_to_local_center(entry["to"])
		var tone: LineTone = entry["tone"]
		var shape: LineShape = entry["shape"]
		var symbol: LineSymbol = entry["symbol"]
		var points: PackedVector2Array = affinity_line_points(from_center, to_center, shape)

		_affinity_line_layer.add_child(
			_make_affinity_stroke(points, AFFINITY_LINE_BACKING_WIDTH, AFFINITY_LINE_BACKING_COLOR)
		)
		_affinity_line_layer.add_child(
			_make_affinity_stroke(points, AFFINITY_LINE_STROKE_WIDTH, _line_color_for_tone(tone))
		)

		var mid: Vector2i = Vector2i(((from_center + to_center) * 0.5).round())
		if not plaques.has(mid):
			plaques[mid] = {}
		plaques[mid][symbol] = tone

	for mid: Vector2i in plaques:
		var group: Dictionary = plaques[mid]
		var split: bool = group.size() > 1
		for symbol: LineSymbol in [LineSymbol.PLUS, LineSymbol.MINUS]:
			if not group.has(symbol):
				continue
			var offset_x: int = 0
			if split:
				offset_x = -AFFINITY_PLAQUE_SPLIT_OFFSET if symbol == LineSymbol.PLUS else AFFINITY_PLAQUE_SPLIT_OFFSET
			_affinity_line_layer.add_child(
				_build_affinity_plaque(mid + Vector2i(offset_x, 0), symbol, _line_color_for_tone(group[symbol]))
			)


## Vertices for one affinity line. SOLID: just the two endpoints. ZIGZAG:
## n segments (n odd, >= [constant AFFINITY_ZIGZAG_MIN_SEGMENTS], nearest to
## L / half-period, ties go larger) with interior vertices offset
## +-[constant AFFINITY_ZIGZAG_AMPLITUDE] perpendicular, alternating; both end
## vertices and (because n is odd) the exact midpoint have zero offset. Every
## vertex is rounded to whole pixels. Public + static so tests can call it.
static func affinity_line_points(
	from_pos: Vector2,
	to_pos: Vector2,
	shape: LineShape,
	amplitude: float = AFFINITY_ZIGZAG_AMPLITUDE,
	half_period: float = AFFINITY_ZIGZAG_HALF_PERIOD,
	round_vertices: bool = true
) -> PackedVector2Array:
	if shape == LineShape.SOLID:
		return PackedVector2Array([from_pos, to_pos])
	var length: float = from_pos.distance_to(to_pos)
	var segments: int = 2 * roundi((length / half_period - 1.0) / 2.0) + 1
	segments = maxi(segments, AFFINITY_ZIGZAG_MIN_SEGMENTS)
	var dir: Vector2 = (to_pos - from_pos) / length
	var normal: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments + 1):
		var p: Vector2 = from_pos.lerp(to_pos, float(i) / float(segments))
		if i > 0 and i < segments:
			var sign_value: float = 1.0 if i % 2 == 0 else -1.0
			p += normal * (sign_value * amplitude)
		points.append(p.round() if round_vertices else p)
	return points


func _make_affinity_stroke(points: PackedVector2Array, width: float, color: Color) -> Line2D:
	var line: Line2D = Line2D.new()
	line.points = points
	line.width = width
	line.default_color = color
	line.antialiased = false
	line.joint_mode = AFFINITY_LINE_JOINT_MODE
	line.sharp_limit = AFFINITY_LINE_SHARP_LIMIT
	line.begin_cap_mode = AFFINITY_LINE_CAP_MODE
	line.end_cap_mode = AFFINITY_LINE_CAP_MODE
	return line


# One plaque = a root Node2D holding a 7x7 dark ColorRect plus the glyph rects.
# Top-left = centre - (3,3), glyph top-left = tile top-left + (1,1), all int.
func _build_affinity_plaque(center: Vector2i, symbol: LineSymbol, color: Color) -> Node2D:
	var root: Node2D = Node2D.new()
	var half: int = AFFINITY_PLAQUE_SIZE / 2
	var tile_pos: Vector2 = Vector2(center - Vector2i(half, half))
	var tile: ColorRect = ColorRect.new()
	tile.color = AFFINITY_PLAQUE_COLOR
	tile.position = tile_pos
	tile.size = Vector2(AFFINITY_PLAQUE_SIZE, AFFINITY_PLAQUE_SIZE)
	root.add_child(tile)

	var glyph_origin: Vector2 = tile_pos + Vector2(1, 1)
	var g: int = AFFINITY_PLAQUE_GLYPH_SIZE
	var bar_h: ColorRect = ColorRect.new()
	bar_h.color = color
	bar_h.position = glyph_origin + Vector2(0, g / 2)
	bar_h.size = Vector2(g, 1)
	root.add_child(bar_h)
	if symbol == LineSymbol.PLUS:
		var bar_v: ColorRect = ColorRect.new()
		bar_v.color = color
		bar_v.position = glyph_origin + Vector2(g / 2, 0)
		bar_v.size = Vector2(1, g)
		root.add_child(bar_v)
	return root


## Replaces the set of highlighted move-range cells. Pass an empty array to
## clear all move highlights.
func set_move_highlights(cells: Array[Vector2i]) -> void:
	_render_highlight_layer(_move_highlight_layer, cells, MOVE_HIGHLIGHT_PATH)
	# Story 028 I:移動範圍改亮藍半透明,與攻擊範圍紅底形成「藍=走、紅=打」。
	# 貼圖(美術資源)保留,只用 modulate 染亮藍,另墊一層半透明藍底(同 set_threat_highlights 手法)。
	for sprite: Node in _move_highlight_layer.get_children():
		(sprite as Sprite2D).modulate = MOVE_FRAME_TINT
		var fill: ColorRect = ColorRect.new()
		fill.color = MOVE_FILL_COLOR
		fill.size = Vector2(BoardCoords.CELL_SIZE, BoardCoords.CELL_SIZE)
		fill.position = (sprite as Sprite2D).position - fill.size / 2.0
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_move_highlight_layer.add_child(fill)
		_move_highlight_layer.move_child(fill, 0)


## Replaces the set of highlighted attack-range cells. Pass an empty array
## to clear all attack highlights.
func set_attack_highlights(cells: Array[Vector2i]) -> void:
	_render_highlight_layer(_attack_highlight_layer, cells, ATTACK_HIGHLIGHT_PATH)


## Story 014 — replaces the attack-range third layer: cells whose distance
## from the selected unit falls within its weapon's range band but whose
## line of sight is blocked ([method
## BattleController.attack_targets_blocked_by_los]'s own set). GDD Visual/
## Audio §1.3 / Core Rules #4: this layer must never be left undrawn for
## these cells — leaving it blank would make a LOS-blocked cell look
## identical to "no overlay" (out of range entirely), and the player would
## misjudge how many cells are actually attackable. Pass an empty array to
## clear.
##
## Hollow outline + single diagonal slash — see [constant
## ATTACK_LOS_BLOCKED_OUTLINE_COLOR]'s own doc comment for why this specific
## shape (not threat's plain ring, not card-target's two-diagonal X, not
## blocked_by_terrain's three horizontal bars).
func set_attack_los_blocked_highlights(cells: Array[Vector2i]) -> void:
	_clear_children(_attack_los_blocked_layer)
	for cell: Vector2i in cells:
		_attack_los_blocked_layer.add_child(_build_attack_los_blocked_outline(cell))
		_attack_los_blocked_layer.add_child(_build_attack_los_blocked_slash(cell))


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
	# 2026-10-28 管理者試玩回饋:「腳色移動前,看不出攻擊範圍。選擇腳色後要用視覺呈現攻擊範圍」。
	# 原本只有細黃斜線,疊在黃褐色地面上幾乎看不見。每格再墊一層半透明紅底、斜線改染紅。
	# 斜線形狀保留 —— 它是「不靠顏色也分得出」的那個通道(見 THREAT_HIGHLIGHT_PATH 說明)。
	# 紅底透明度刻意低,這一層畫在棋子上方,不可把敵方棋子蓋掉。
	for sprite: Node in _threat_highlight_layer.get_children():
		(sprite as Sprite2D).modulate = THREAT_STRIPE_TINT
		var fill: ColorRect = ColorRect.new()
		fill.color = THREAT_FILL_COLOR
		fill.size = Vector2(BoardCoords.CELL_SIZE, BoardCoords.CELL_SIZE)
		fill.position = (sprite as Sprite2D).position - fill.size / 2.0
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_threat_highlight_layer.add_child(fill)
		_threat_highlight_layer.move_child(fill, 0)


## Story 014 — replaces the move-range THREE unreachable states from [method
## BattleController.move_targets_breakdown]'s four-way partition.
## [method set_move_highlights]'s own bucket (`A`, legal) is unaffected by
## this method and keeps its own call site unchanged (EPIC.md: "既有繪製
## 路徑不動") — GDD Visual/Audio §1.1 / UX pattern `P-D1` require all four
## states to be independently, exhaustively visible across the WHOLE board
## (every in-bounds cell classifies into exactly one of the four), not just
## the reachable subset.
##
## [param blocked_occupancy] is `B \ A` (would be reachable ignoring
## occupancy, but a standing unit blocks it — GDD's primary motivating case
## is an ALLY blocking the path/destination, "先移動擋路的隊友"). [param
## blocked_terrain] is `C \ B` (would be reachable ignoring occupancy AND
## passability, but impassable terrain blocks it — structurally always empty
## today, see [constant MOVE_TERRAIN_HATCH_COLOR]'s own doc comment). [param
## out_of_range] is `Grid \ C` (outside movement-point reach regardless of
## occupancy or passability).
##
## Pass three empty arrays to clear. The caller is responsible for excluding
## any cell already carrying a stronger-priority attack/threat mark from
## these three arrays before calling — this method draws exactly what it is
## given, same contract as every other method on this node.
func set_move_unreachable_highlights(
	blocked_occupancy: Array[Vector2i],
	blocked_terrain: Array[Vector2i],
	out_of_range: Array[Vector2i]
) -> void:
	_clear_children(_move_unreachable_layer)
	for cell: Vector2i in blocked_occupancy:
		_move_unreachable_layer.add_child(_build_move_blocked_outline(cell))
	for cell: Vector2i in blocked_terrain:
		_move_unreachable_layer.add_child(_build_move_blocked_outline(cell))
		_move_unreachable_layer.add_child(_build_move_terrain_hatch(cell))
	for cell: Vector2i in out_of_range:
		_move_unreachable_layer.add_child(_build_move_out_of_range_dot(cell))


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


# story-039 — 棋子姓名首字(我方)/敵兵編號(敵方)。樣式依 art-director
# docs/reviews/piece-initial-label-style-2026-11-12.md:Cubic 11 原生 11px、
# 1px 描邊、無底色塊;字框左上角在棋子圖座標 (0,16)。棋子圖頂 = 格頂 - 8
# (PIECE_SPRITE_HEIGHT 40 - CELL_SIZE 32),故字框頂 = 格頂 + 8、左緣 = 格左緣。
# 整數像素對齊:位置全為整數。
# 兩份共用的 LabelSettings(我方/敵方各一),首次用到才建。每次 render_pieces 重建
# 全部棋子標記時只指派參照,不再逐 Label 做 6 個 theme override(story-039 效能修正)。
var _piece_label_settings_ally: LabelSettings = null
var _piece_label_settings_enemy: LabelSettings = null


func _piece_label_settings(is_ally: bool) -> LabelSettings:
	if is_ally and _piece_label_settings_ally != null:
		return _piece_label_settings_ally
	if not is_ally and _piece_label_settings_enemy != null:
		return _piece_label_settings_enemy
	var settings: LabelSettings = LabelSettings.new()
	settings.font = PIECE_LABEL_FONT
	settings.font_size = PIECE_LABEL_FONT_SIZE
	settings.font_color = PIECE_LABEL_COLOR_ALLY if is_ally else PIECE_LABEL_COLOR_ENEMY
	settings.outline_color = PIECE_LABEL_OUTLINE_COLOR
	settings.outline_size = 1
	if is_ally:
		_piece_label_settings_ally = settings
	else:
		_piece_label_settings_enemy = settings
	return settings


# 常駐 Label 池(位於 StatsLayer 之後的兄弟節點,不隨 render_pieces 清除)。
# 每次重畫逐個棋子複用池中第 i 個 Label,只更新 text/position/visible,不重建:
# 實測新建 Label(Cubic 11 + 描邊)的字形整形是每次重畫的主要成本(見
# prototypes/piece-label-perf-2026-11-12/)。多餘的 Label 隱藏而非釋放。
var _piece_label_layer: Node2D = null
var _piece_label_pool: Array[Label] = []


# story-041 — 格內版面單一出處(座標相對格左上,格 32x32)。三個矩形垂直分帶:
#   HP 文字條 y[0,8) | 首字框 y[8,22) | 血條 y[26,29),兩兩不相交。
# 算術:首字底 22 到血條頂 26 只剩 4px,放不下文字條;右側 x12~32 只有 20px,
# 實測 8px 字 "22/22"=22px、"22→15"=27px 放不下。故文字條留在格頂、高度由 10 縮為 8,
# 讓出 y8~11 給首字框(首字框位置/大小一律不動)。
# _build_hp_text / _build_hp_bar / _apply_piece_label 都呼叫這三個函式定位,不另存複本。
static func hp_text_rect_in_cell() -> Rect2:
	return Rect2(0.0, HP_TEXT_TOP_MARGIN, BoardCoords.CELL_SIZE, HP_TEXT_HEIGHT)


static func piece_label_rect_in_cell() -> Rect2:
	return Rect2(Vector2(0.0, PIECE_LABEL_TOP_OFFSET_IN_CELL), PIECE_LABEL_SIZE)


static func hp_bar_rect_in_cell() -> Rect2:
	return Rect2(
		(BoardCoords.CELL_SIZE - HP_BAR_WIDTH) * 0.5,
		BoardCoords.CELL_SIZE - HP_BAR_BOTTOM_MARGIN - HP_BAR_HEIGHT,
		HP_BAR_WIDTH, HP_BAR_HEIGHT
	)


func _apply_piece_label(index: int, cell_top_left: Vector2, text: String, is_ally: bool) -> void:
	if _piece_label_layer == null:
		_piece_label_layer = Node2D.new()
		_piece_label_layer.name = "PieceLabelLayer"
		add_child(_piece_label_layer)
		move_child(_piece_label_layer, _stats_layer.get_index() + 1)
	if index >= _piece_label_pool.size():
		var created: Label = Label.new()
		# 先指派 label_settings 再設 size:Label 的最小尺寸取決於字型,size 在字型就位前
		# 設定會被預設 16px 字型的最小高度(23)撐大,使實際節點矩形偏離 PIECE_LABEL_SIZE。
		created.label_settings = _piece_label_settings(is_ally)
		created.size = PIECE_LABEL_SIZE
		created.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		created.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		created.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_piece_label_layer.add_child(created)
		_piece_label_pool.append(created)
	var label: Label = _piece_label_pool[index]
	label.text = text
	label.position = cell_top_left + piece_label_rect_in_cell().position
	var settings: LabelSettings = _piece_label_settings(is_ally)
	if label.label_settings != settings:
		label.label_settings = settings
	label.visible = true


# Builds a minimal two-rect HP bar (dark background + proportional fill),
# centered horizontally on the cell with its top edge HP_BAR_TOP_MARGIN below
# cell_top_left.y — see the HP_BAR_* constants' doc comment for why this is
# anchored to the cell rather than the piece sprite.
func _build_hp_bar(cell_top_left: Vector2, hp: int, hp_max: int) -> Node2D:
	var bar_root: Node2D = Node2D.new()
	var bar_rect: Rect2 = hp_bar_rect_in_cell()
	bar_root.position = cell_top_left + bar_rect.position

	var background: ColorRect = ColorRect.new()
	background.color = Color(0.1, 0.1, 0.1, 1.0)
	background.size = bar_rect.size
	background.position = Vector2.ZERO
	bar_root.add_child(background)

	var fraction: float = 0.0
	if hp_max > 0:
		fraction = clampf(float(hp) / float(hp_max), 0.0, 1.0)
	var fill: ColorRect = ColorRect.new()
	fill.color = Color(0.2, 0.8, 0.2, 1.0) if fraction > 0.25 else Color(0.8, 0.2, 0.2, 1.0)
	fill.size = Vector2(bar_rect.size.x * fraction, bar_rect.size.y)
	fill.position = Vector2.ZERO
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
	var text_rect: Rect2 = hp_text_rect_in_cell()
	root.position = cell_top_left + text_rect.position

	var background: ColorRect = ColorRect.new()
	background.color = (
		HP_TEXT_BG_COLOR_TARGET_ILLEGAL if card_target_illegal else HP_TEXT_BG_COLOR
	)
	background.position = Vector2.ZERO
	background.size = text_rect.size
	root.add_child(background)

	# Label 最小高度(8px 字 = 12px)大於文字條高度 8,無法縮進條內;故 Label 放進一個
	# clip_contents 的同尺寸容器,Label 垂直置中(y = (條高 - Label 高)/2,為負),
	# 可見部分被裁在條內。字型覆寫必須在設 size 之前,否則 size 會被預設字型撐大。
	var clip: Control = Control.new()
	clip.position = Vector2.ZERO
	clip.size = text_rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	var label: Label = Label.new()
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
	label.size = Vector2(text_rect.size.x, label.get_minimum_size().y)
	label.position = Vector2(0.0, (text_rect.size.y - label.size.y) * 0.5)
	clip.add_child(label)

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


# Story 014 — hollow square outline for move-range unreachable markers
# (blocked_by_occupancy / blocked_by_terrain). Same 4-ColorRect-border
# technique as _build_card_target_outline(), dedicated constants so the two
# visual vocabularies never share one source of truth (see
# MOVE_BLOCKED_OUTLINE_COLOR's own doc comment for why that separation
# matters on this project).
func _build_move_blocked_outline(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var top_left: Vector2 = BoardCoords.grid_to_local(cell) + Vector2.ONE * MOVE_BLOCKED_OUTLINE_INSET
	var side: float = BoardCoords.CELL_SIZE - MOVE_BLOCKED_OUTLINE_INSET * 2.0
	var border_width: float = MOVE_BLOCKED_OUTLINE_WIDTH

	var top: ColorRect = ColorRect.new()
	top.color = MOVE_BLOCKED_OUTLINE_COLOR
	top.position = top_left
	top.size = Vector2(side, border_width)
	root.add_child(top)

	var bottom: ColorRect = ColorRect.new()
	bottom.color = MOVE_BLOCKED_OUTLINE_COLOR
	bottom.position = top_left + Vector2(0.0, side - border_width)
	bottom.size = Vector2(side, border_width)
	root.add_child(bottom)

	var left: ColorRect = ColorRect.new()
	left.color = MOVE_BLOCKED_OUTLINE_COLOR
	left.position = top_left
	left.size = Vector2(border_width, side)
	root.add_child(left)

	var right: ColorRect = ColorRect.new()
	right.color = MOVE_BLOCKED_OUTLINE_COLOR
	right.position = top_left + Vector2(side - border_width, 0.0)
	right.size = Vector2(border_width, side)
	root.add_child(right)

	return root


# Story 014 — three short horizontal "hazard bar" strokes for
# blocked_by_terrain, drawn INSIDE _build_move_blocked_outline()'s border.
# antialiased = false matches every other Line2D in this file's pixel-art
# discipline (set_affinity_lines() / _build_card_target_illegal_mark()).
func _build_move_terrain_hatch(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var top_left: Vector2 = BoardCoords.grid_to_local(cell) + Vector2.ONE * MOVE_TERRAIN_HATCH_INSET
	var side: float = BoardCoords.CELL_SIZE - MOVE_TERRAIN_HATCH_INSET * 2.0
	var bar_fractions: Array[float] = [0.2, 0.5, 0.8]
	for fraction: float in bar_fractions:
		var bar: Line2D = Line2D.new()
		bar.points = PackedVector2Array([
			top_left + Vector2(0.0, side * fraction),
			top_left + Vector2(side, side * fraction),
		])
		bar.width = MOVE_TERRAIN_HATCH_WIDTH
		bar.default_color = MOVE_TERRAIN_HATCH_COLOR
		bar.antialiased = false
		root.add_child(bar)
	return root


# Story 014 — small centered dot for out_of_range (Grid\C), the quietest of
# the three unreachable markers — see set_move_unreachable_highlights()'s
# own doc comment and MOVE_OUT_OF_RANGE_DOT_COLOR's doc comment for why it is
# deliberately understated rather than a full-cell mark. Wrapped in a Node2D
# root even though it is a single rect, matching every other builder in this
# file's "one throwaway subtree per render" shape (see _clear_children()'s
# own doc comment) rather than adding a bare Control under a Node2D layer.
func _build_move_out_of_range_dot(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var dot: ColorRect = ColorRect.new()
	dot.color = MOVE_OUT_OF_RANGE_DOT_COLOR
	var center: Vector2 = BoardCoords.grid_to_local_center(cell)
	dot.position = center - Vector2.ONE * MOVE_OUT_OF_RANGE_DOT_SIZE * 0.5
	dot.size = Vector2.ONE * MOVE_OUT_OF_RANGE_DOT_SIZE
	root.add_child(dot)
	return root


# Story 014 — hollow square outline for the attack-range third layer
# (range内但視線被擋). Same border technique as _build_move_blocked_outline(),
# dedicated colour/inset so the attack-family mark is never visually
# conflated with the move-family one even though the two are never expected
# simultaneously on the SAME cell (attack range and move range answer
# different questions) — using the same colour for both would still read as
# "the same state" at a glance.
func _build_attack_los_blocked_outline(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var top_left: Vector2 = (
		BoardCoords.grid_to_local(cell) + Vector2.ONE * ATTACK_LOS_BLOCKED_OUTLINE_INSET
	)
	var side: float = BoardCoords.CELL_SIZE - ATTACK_LOS_BLOCKED_OUTLINE_INSET * 2.0
	var border_width: float = ATTACK_LOS_BLOCKED_OUTLINE_WIDTH

	var top: ColorRect = ColorRect.new()
	top.color = ATTACK_LOS_BLOCKED_OUTLINE_COLOR
	top.position = top_left
	top.size = Vector2(side, border_width)
	root.add_child(top)

	var bottom: ColorRect = ColorRect.new()
	bottom.color = ATTACK_LOS_BLOCKED_OUTLINE_COLOR
	bottom.position = top_left + Vector2(0.0, side - border_width)
	bottom.size = Vector2(side, border_width)
	root.add_child(bottom)

	var left: ColorRect = ColorRect.new()
	left.color = ATTACK_LOS_BLOCKED_OUTLINE_COLOR
	left.position = top_left
	left.size = Vector2(border_width, side)
	root.add_child(left)

	var right: ColorRect = ColorRect.new()
	right.color = ATTACK_LOS_BLOCKED_OUTLINE_COLOR
	right.position = top_left + Vector2(side - border_width, 0.0)
	right.size = Vector2(border_width, side)
	root.add_child(right)

	return root


# Story 014 — single diagonal slash drawn INSIDE
# _build_attack_los_blocked_outline()'s border, distinguishing this mark from
# a plain outline (move-range blocked_by_occupancy) and from a two-diagonal X
# (card-target illegal mark).
func _build_attack_los_blocked_slash(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var top_left: Vector2 = (
		BoardCoords.grid_to_local(cell) + Vector2.ONE * ATTACK_LOS_BLOCKED_SLASH_INSET
	)
	var side: float = BoardCoords.CELL_SIZE - ATTACK_LOS_BLOCKED_SLASH_INSET * 2.0
	var slash: Line2D = Line2D.new()
	slash.points = PackedVector2Array([
		top_left + Vector2(0.0, side),
		top_left + Vector2(side, 0.0),
	])
	slash.width = ATTACK_LOS_BLOCKED_SLASH_WIDTH
	slash.default_color = ATTACK_LOS_BLOCKED_OUTLINE_COLOR
	slash.antialiased = false
	root.add_child(slash)
	return root


# Story 015 — persistent per-unit action-flag badge: two adjacent pips
# anchored to the piece SPRITE's top-right corner (see ACTION_FLAG_PIP_SIZE's
# own doc comment for why the sprite, not the cell, and for the full
# distinguishability argument). Left pip = move availability, right pip =
# attack availability — this fixed order is the only place that mapping is
# defined; _action_flag_for_state() callers (battle_screen.gd) never need to
# know it, they only pick an ActionFlag ordinal.
#
# flag -> (move_used, attack_used), derived directly from TurnOrder's own
# naming (ATTACK_ONLY means "only attack is LEFT", i.e. move has been used;
# MOVE_ONLY means "only move is LEFT", i.e. attack has been used):
#   NONE_USED    -> move available,  attack available  (both pips hollow)
#   ATTACK_ONLY  -> move used,       attack available  (left filled, right hollow)
#   MOVE_ONLY    -> move available,  attack used        (left hollow, right filled)
#   DONE         -> move used,       attack used        (both pips filled)
func _build_action_flag_marker(cell: Vector2i, flag: ActionFlag) -> Node2D:
	var root: Node2D = Node2D.new()
	var cell_top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var sprite_top: float = (
		cell_top_left.y + BoardCoords.CELL_SIZE - PIECE_SPRITE_HEIGHT
	)
	var sprite_right: float = cell_top_left.x + BoardCoords.CELL_SIZE
	var badge_top: float = sprite_top + ACTION_FLAG_PIP_MARGIN
	var attack_pip_left: float = sprite_right - ACTION_FLAG_PIP_MARGIN - ACTION_FLAG_PIP_SIZE
	var move_pip_left: float = attack_pip_left - ACTION_FLAG_PIP_GAP - ACTION_FLAG_PIP_SIZE

	var move_used: bool = flag == ActionFlag.ATTACK_ONLY or flag == ActionFlag.DONE
	var attack_used: bool = flag == ActionFlag.MOVE_ONLY or flag == ActionFlag.DONE

	root.add_child(_build_action_flag_pip(Vector2(move_pip_left, badge_top), move_used))
	root.add_child(_build_action_flag_pip(Vector2(attack_pip_left, badge_top), attack_used))
	return root


# Story 015 — a single ACTION_FLAG_PIP_SIZE square pip, either FILLED (solid,
# a used action) or HOLLOW (4-ColorRect border, same technique as
# _build_card_target_outline()/_build_move_blocked_outline(), an available
# action). top_left is the pip's own top-left corner in BoardView-local
# coordinates.
func _build_action_flag_pip(top_left: Vector2, filled: bool) -> Node2D:
	var root: Node2D = Node2D.new()
	if filled:
		var fill: ColorRect = ColorRect.new()
		fill.color = ACTION_FLAG_PIP_COLOR
		fill.position = top_left
		fill.size = Vector2(ACTION_FLAG_PIP_SIZE, ACTION_FLAG_PIP_SIZE)
		root.add_child(fill)
		return root

	var side: float = ACTION_FLAG_PIP_SIZE
	var border_width: float = ACTION_FLAG_PIP_BORDER_WIDTH

	var top: ColorRect = ColorRect.new()
	top.color = ACTION_FLAG_PIP_COLOR
	top.position = top_left
	top.size = Vector2(side, border_width)
	root.add_child(top)

	var bottom: ColorRect = ColorRect.new()
	bottom.color = ACTION_FLAG_PIP_COLOR
	bottom.position = top_left + Vector2(0.0, side - border_width)
	bottom.size = Vector2(side, border_width)
	root.add_child(bottom)

	var left: ColorRect = ColorRect.new()
	left.color = ACTION_FLAG_PIP_COLOR
	left.position = top_left
	left.size = Vector2(border_width, side)
	root.add_child(left)

	var right: ColorRect = ColorRect.new()
	right.color = ACTION_FLAG_PIP_COLOR
	right.position = top_left + Vector2(side - border_width, 0.0)
	right.size = Vector2(border_width, side)
	root.add_child(right)

	return root


# Story 015 — checkerboard half-fill for an impassable terrain cell: the
# top-left and bottom-right quadrants solid, the other two left transparent.
# See IMPASSABLE_TERRAIN_CHECKER_COLOR's own doc comment for why this shape
# family (alternating quadrants) is used instead of any of this file's other
# seven.
func _build_impassable_terrain_marker(cell: Vector2i) -> Node2D:
	var root: Node2D = Node2D.new()
	var top_left: Vector2 = BoardCoords.grid_to_local(cell)
	var half: float = BoardCoords.CELL_SIZE * 0.5

	var top_left_quadrant: ColorRect = ColorRect.new()
	top_left_quadrant.color = IMPASSABLE_TERRAIN_CHECKER_COLOR
	top_left_quadrant.position = top_left
	top_left_quadrant.size = Vector2(half, half)
	root.add_child(top_left_quadrant)

	var bottom_right_quadrant: ColorRect = ColorRect.new()
	bottom_right_quadrant.color = IMPASSABLE_TERRAIN_CHECKER_COLOR
	bottom_right_quadrant.position = top_left + Vector2(half, half)
	bottom_right_quadrant.size = Vector2(half, half)
	root.add_child(bottom_right_quadrant)

	return root


# Maps LineTone -> stroke colour for set_affinity_lines().
func _line_color_for_tone(tone: LineTone) -> Color:
	match tone:
		LineTone.POSITIVE:
			return AFFINITY_LINE_COLOR_POSITIVE
		_:
			return AFFINITY_LINE_COLOR_NEGATIVE


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
