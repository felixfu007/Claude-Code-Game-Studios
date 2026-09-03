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


## Story 004 (機制四之二,TR-cursor-004): navigation-class [code]ui_*[/code]
## InputMap actions. Only [constant CursorTypes.ActionClass.NAVIGATION]
## actions are eligible to claim device authority (機制六) — see
## [method classify_action].
const NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_up", &"ui_down", &"ui_left", &"ui_right",
]

## Story 004 (機制四之二): confirm-class [code]ui_*[/code] InputMap actions.
## Confirm-class actions are structurally excluded from device-authority
## arbitration (GDD Core Rules #3 「確認類動作與裝置權威的關係」) — see
## [method classify_action].
const CONFIRM_ACTIONS: Array[StringName] = [
	&"ui_accept", &"ui_cancel",
]

## Story 004 (機制四之二,R4-5): every other [code]ui_*[/code] action this
## project has hand-reviewed and confirmed is NOT navigation-class. This list
## exists so 機制七 (c)'s load-time completeness validator (Story 006) has a
## "hand-reviewed, confirmed non-navigation" allowlist to diff against — it is
## NOT consulted by [method classify_action] itself (that function already
## falls through to [constant CursorTypes.ActionClass.OTHER] for anything not
## in [constant NAVIGATION_ACTIONS] or [constant CONFIRM_ACTIONS]).
## [br]
## ADR-0005 明文警告這份清單「值為參考起點,實作時須以實際 InputMap 內容補齊」——
## 本專案 [code]project.godot[/code] 的 [code][input][/code] 節只自訂
## [code]battle_confirm[/code]/[code]battle_end_phase[/code](非 [code]ui_*[/code]),
## 故全部 [code]ui_*[/code] action 皆來自 Godot 4.7.1 引擎內建預設,已用
## [code]prototypes/story-004-ui-action-probe-2026-09-03/[/code] 的 headless
## 探針對本專案實際載入的 InputMap 逐一核對過(而非憑訓練資料印象列出)。
## 探針輸出:[code]prototypes/story-004-ui-action-probe-2026-09-03/logs/probe_output.txt[/code]。
## Probe-confirmed 2026-09-03: this engine registers 91 total [code]ui_*[/code]
## actions (built-in defaults; this project's [code]project.godot[/code] only
## customizes [code]battle_confirm[/code]/[code]battle_end_phase[/code]).
## These 8 plus [constant NAVIGATION_ACTIONS]' 4 plus [constant
## CONFIRM_ACTIONS]' 2 (14 total) are the ones this project has actually
## hand-reviewed against real InputMap contents. The remaining 77 — almost
## entirely [code]LineEdit[/code]/[code]TextEdit[/code]/[code]FileDialog[/code]/
## [code]GraphEdit[/code]/[code]ColorPicker[/code] editor-control actions this
## project's gameplay does not use — are deliberately left unclassified here.
## That is not an oversight: 機制七 (c)'s load-time completeness validator
## (Story 006, not this story) is the mechanism that surfaces them by name so
## a human decides case by case, per R4-5's "no silent OTHER" rule. See
## [code]prototypes/story-004-ui-action-probe-2026-09-03/logs/probe_output.txt[/code]
## for the full 77-item list handed off to that story.
const ACKNOWLEDGED_OTHER_ACTIONS: Array[StringName] = [
	&"ui_focus_next", &"ui_focus_prev", &"ui_page_up", &"ui_page_down",
	&"ui_home", &"ui_end", &"ui_select", &"ui_menu",
]


## Story 004 (機制四,TR-cursor-004): classifies a raw [InputEvent] into which
## device family it structurally belongs to, by [InputEvent] subclass ONLY.
## [b]Never reads [member InputEvent.device][/b] — this is this system's
## structural immunity to Godot 4.7's keyboard/mouse device ID renumbering
## (see [code]docs/engine-reference/godot/breaking-changes.md[/code]), not
## merely a coding convention. Registered forbidden pattern
## [code]reading_input_event_device_id[/code] (control manifest).
## [br]
## This is the "classification means" layer (機制四's 第二層). The separate
## "authority gate" layer (機制四's 第一層 — whether the event actually maps
## to a [code]ui_*[/code] action at all) lives in [method classify_action]
## and in 機制八's reclaim-threshold check for mouse; [method classify] alone
## does not gate anything.
static func classify(event: InputEvent) -> Authority:
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Authority.KEYBOARD_GAMEPAD
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		return Authority.MOUSE
	return Authority.UNINITIALIZED


## Story 004 (機制四之二,N1,TR-cursor-004): classifies a [code]ui_*[/code]
## action's coarse semantics bucket. See [constant NAVIGATION_ACTIONS] /
## [constant CONFIRM_ACTIONS] for what is hand-classified into each bucket;
## anything matching neither falls through to [constant ActionClass.OTHER]
## (this includes every [InputEventMouseMotion], which
## [method InputMap.event_is_action] is documented to always reject, and any
## [code]ui_*[/code] action this project has not hand-reviewed — see
## [constant ACKNOWLEDGED_OTHER_ACTIONS]).
## [br]
## 🔴 [b]Echo filtering is a hard obligation that took effect the moment
## ADR-0005 was Accepted[/b] (ADR-0005 Status block, 2026-09-01), not an
## optional refinement. [method InputMap.event_is_action] does
## [b]NOT[/b] filter [member InputEventKey.echo] — measured directly against
## this engine (`event_is_action(pressed=true, echo=true, ui_up)` and
## `echo=false` both return [code]true[/code]), evidence at
## [code]prototypes/adr0005-engine-probes-2026-09-01/logs/probe13_and_3_headless.txt[/code].
## Without this filter, holding down a directional key would have every
## repeat-echo frame classified as [constant ActionClass.NAVIGATION] — i.e.
## asserting device authority every single frame.
## [br]
## ⚠️ [b]This deviates from the illustrative code block in ADR-0005's 機制四之二
## section[/b], which reads "此處不預先加過濾" (echo handling deferred pending
## the frozen mouse-reclaim sub-mechanism). That sentence predates VR #13's
## verification and the Status block's approval obligation — it is stale
## prose, not the governing contract. The Status block's approval obligation
## (line 22) and VR #13's verified conclusion (line 113) supersede it. This
## comment exists so the next reader comparing this file against the ADR body
## does not mistake this filter for an unauthorized deviation.
static func classify_action(event: InputEvent) -> ActionClass:
	# Hard obligation, applied before any InputMap lookup: a held-down key
	# generates repeat InputEventKey instances with echo == true, and
	# InputMap.event_is_action() does not filter them out on its own
	# (measured — see doc comment above). Filtering here, and not only for
	# NAVIGATION, keeps this function's output shape simple (one gate, not
	# one gate per bucket) — CONFIRM does not grant device authority either
	# way, so filtering it too costs nothing and avoids a second special case.
	if event is InputEventKey and (event as InputEventKey).echo:
		return ActionClass.OTHER

	for action in NAVIGATION_ACTIONS:
		if InputMap.event_is_action(event, action):
			return ActionClass.NAVIGATION
	for action in CONFIRM_ACTIONS:
		if InputMap.event_is_action(event, action):
			return ActionClass.CONFIRM
	return ActionClass.OTHER


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
