## Namespace wrapper for the cursor/highlight-state system's shared enums
## (ADR-0005 機制二). [b]Never instantiated[/b] — pure namespace. GDScript
## enums declared at file scope are not visible across files, so any enum
## shared between cursor-system scripts must live inside a wrapping class.
## Follows the same precedent as [code]AffinityTypes[/code] (ADR-0002).
##
## [b]Persistence discipline[/b]: if any of these enums are ever persisted,
## use [code]enum.find_key(value)[/code] / [code]enum[name_string][/code] —
## never [code]keys()[value][/code] (positional index). Registered forbidden
## pattern: [code]enum_value_positional_string_conversion[/code] (ADR-0002).
class_name CursorTypes
extends RefCounted

## UI surface types the cursor/highlight-state system can target. Adding a
## new mounted UI surface means adding a member here AND a matching constant
## in 機制七's threshold table — a UI surface not registered here falls
## outside this system's jurisdiction (GDD Core Rules #7, AC-60).
enum SurfaceType { BOARD_TILE, RELATION_MINIMAP_NODE, CARD_SLOT, DIALOGUE_CHOICE }

## Which device currently holds cursor authority.
enum Authority { UNINITIALIZED, MOUSE, KEYBOARD_GAMEPAD }

## Coarse action-semantics bucket for a [code]ui_*[/code] InputMap action
## (機制四之二). Only [constant NAVIGATION] actions are eligible to claim
## device authority (see 機制六).
enum ActionClass { NAVIGATION, CONFIRM, OTHER }

## Named triggers for the reclaim-accumulator reset points. The first four
## are GDD Core Rules #3 (a)(b)(c)(d); [constant SURFACE_HANDOFF] was added
## in ADR-0005's fourth revision (R4) and is NOT a fifth Core Rules #3
## trigger — its source is Core Rules #7 F2-2's separate obligation (see
## 機制十一). Both [method MouseReclaimPolicy.reset] and
## [signal MouseReclaimPolicy.reset_triggered] communicate via this enum.
enum ResetTrigger {
	AUTHORITY_TRANSFER,   # (a) device authority transfers, either direction
	TARGET_CHANGED,       # (b) the current highlighted target changes
	FOCUS_LOST_REGAINED,  # (c) suspended for the whole unfocused span, reseeded on refocus
	VETOED_SAME_FRAME,    # (d) threshold crossed same frame but vetoed by a NAVIGATION-class
	                       #     keyboard/gamepad action — the only trigger allowed to make the
	                       #     presentation layer snap to zero within a single frame (AC-41b)
	SURFACE_HANDOFF,       # surface unload handoff (機制十一) — presentation layer treats this
	                       # like (a)(b)(c): converges, does not snap (only (d) snaps)
}


## Encodes a board grid coordinate to an [int] for use as [member
## CursorTarget.id]. Bijective with [method decode_tile] for any [param cell]
## with [code]0 <= cell.x < board_width[/code] and [code]cell.y >= 0[/code],
## given a positive [param board_width]. [b]Precondition-checked with
## [code]assert()[/code] on all three bounds[/b], matching this project's
## existing convention for caller-contract preconditions (see
## [code]AffinityLink.partner_of[/code] /
## [code]AffinityLink.from_csv_line[/code] in
## [code]src/gameplay/affinity/affinity_link.gd[/code]) — an out-of-domain
## call fails loudly in debug builds instead of silently producing a
## colliding or garbage id (or dividing by zero, if [param board_width] is
## [code]0[/code]).
##
## [param board_width] is a caller-supplied parameter rather than a constant
## declared in this file. [b]This two-argument signature is what ADR-0005's
## "Key Interfaces" section defines as the frozen contract[/b] (that section
## states its signatures are the ones implementation must not deviate from in
## meaning) — it only differs from an earlier, illustrative single-argument
## mention of [code]encode_tile[/code]/[code]decode_tile[/code] in the ADR's
## "機制三:目標識別為值型別 + 表面註冊表" section, which is descriptive prose,
## not the definitive shape. The board width (13) already
## lives in [code]Board.BOARD_WIDTH[/code]
## ([code]src/gameplay/board/board.gd[/code]) and
## [code]BoardCoords.BOARD_COLS[/code]
## ([code]src/ui/battle/board_coords.gd[/code]); adding a third copy here
## would be exactly the duplicated-constant drift this project has already
## been burned by. This file declares no board-dimension constant of its
## own — callers pass whichever of the two existing constants fits their layer.
static func encode_tile(cell: Vector2i, board_width: int) -> int:
	assert(
		board_width > 0,
		"CursorTypes.encode_tile: board_width must be positive, got %d" % board_width
	)
	assert(
		cell.x >= 0 and cell.x < board_width,
		"CursorTypes.encode_tile: cell.x %d out of range [0, %d)" % [cell.x, board_width]
	)
	assert(
		cell.y >= 0,
		"CursorTypes.encode_tile: cell.y must be non-negative, got %d" % cell.y
	)
	return cell.y * board_width + cell.x


## Inverse of [method encode_tile]. See that method's doc comment for the
## [param board_width] rationale. Legal domain: [code]board_width > 0[/code]
## and [code]id >= 0[/code], both precondition-checked with [code]assert()[/code]
## (same convention as [method encode_tile]).
static func decode_tile(id: int, board_width: int) -> Vector2i:
	assert(
		board_width > 0,
		"CursorTypes.decode_tile: board_width must be positive, got %d" % board_width
	)
	assert(
		id >= 0,
		"CursorTypes.decode_tile: id must be non-negative, got %d" % id
	)
	return Vector2i(id % board_width, id / board_width)
