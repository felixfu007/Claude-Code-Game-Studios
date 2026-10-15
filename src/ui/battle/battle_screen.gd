## Wires the presentation layer ([BoardView]) to the interaction layer
## ([BattleController]) — the only class in the project that is allowed to
## know about both. Per [code].claude/rules/ui-code.md[/code] ("UI must
## NEVER own or directly modify game state"): [BoardView] never sees a
## [BattleState] reference and [BattleController] never sees a node, so this
## screen is the translator in both directions — player input becomes
## [method BattleController.click_tile] calls, and [BattleController]'s
## signals become [BoardView] render calls.
##
## Owns [BattleState], [TurnOrder], and [BattleController] directly; the two
## nodes it drives ([BoardView] inside the world [SubViewport], and a
## status/result [Label] pair in [code]UILayer[/code]) are the entire node
## tree this script touches.
##
## [b]Input discipline (ADR-0005 forbidden patterns, binding per
## [code]docs/registry/architecture.yaml[/code] even while that ADR is
## [code]Proposed[/code]):[/b] every input decision happens in [method _input]
## — never [method Node._unhandled_input] — and [code]InputEvent.device[/code]
## is never read. Device authority is the single judgment point for "whose
## cursor is this", and (as of story-009, 2026-10-13) it is answered
## ENTIRELY by [method CursorStateHost.get_device_authority] — arbitrated by
## that Autoload's own [method Node._input] (which buffers every engine
## [InputEvent] independently of this screen) and [method
## CursorState.arbitrate_device_authority] at
## [code]process_priority = -100[/code]. [b]This screen used to own a SECOND,
## separate device-authority tracker[/b] (a class named
## [code]DeviceAuthority[/code], formerly
## [code]src/ui/battle/device_authority.gd[/code], fed by ~17 manually placed
## [code]note_pad_input()[/code]/[code]note_mouse_motion()[/code] calls) —
## that class has been fully retired (story-009; EPIC.md M6 收斂表 #2) and no
## longer exists anywhere in this project; do not reintroduce a second
## tracker if a future change seems to need one.
##
## [b]Mouse coordinate handling — measured, not assumed (2026-08-27,
## SUPERSEDED 2026-09-04, see below):[/b] a real windowed probe confirmed
## that under the then-current [code]window/stretch/mode = "canvas_items"[/code],
## [InputEventMouseMotion]/[InputEventMouseButton] positions arriving at
## [method _input] were [b]already[/b] in 480x270 base-canvas space — Godot
## applied the [code]canvas_items[/code] stretch transform before delivery.
## This screen therefore used to convert mouse positions with
## [method BoardCoords.local_to_grid] directly
## ([code]event.position - world_viewport_canvas_origin[/code]), never
## [method BoardCoords.window_to_grid], since the latter would have
## re-applied the same transform a second time.
##
## [b]2026-09-04 (Story 001, screen-scaling epic) — this premise is now
## false, and the code below was rewritten accordingly.[/b]
## [code]window/stretch/mode[/code] is [code]"disabled"[/code]: the engine no
## longer transforms [InputEvent] positions before delivery at all, so
## [InputEventMouseMotion]/[InputEventMouseButton] positions arriving at
## [method _input] are now raw OS window-physical pixels — exactly the case
## [method BoardCoords.window_to_grid] exists for. Every mouse-position call
## site in this file now goes through [method _window_pos_to_cell], the
## single place this screen constructs the [WorldLayout] transform and calls
## [method BoardCoords.window_to_grid] — per [WorldLayout]'s own doc comment,
## no call site may re-derive the scale/offset math itself, so this file
## does not either.
class_name BattleScreen
extends Node

## Level terrain source, read once in [method _ready] via [method
## Board.from_ascii] (through [method BattleState.create]).
const TERRAIN_PATH: String = "res://assets/data/levels/vs01_terrain.txt"

## Roster source, read once in [method _ready] via [method Unit.roster_from_text]
## (through [method BattleState.create]).
const ROSTER_PATH: String = "res://assets/data/units/vs01_roster.txt"

## Affinity pairing table, read once in [method _ready] via
## [method AffinityLink.links_from_text] and wired into [member _phi]. Unlike
## [constant TERRAIN_PATH] / [constant ROSTER_PATH], a file that parses to
## zero links is a legal, expressible design state (see [method _ready]) —
## [constant LoadFailure.MISSING], [constant LoadFailure.UNREADABLE], and (as
## of the 2026-09-16 second manager ruling) [constant LoadFailure.PARSE_ERROR]
## block the load for this path; a legal empty result does not.
const AFFINITY_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"

## Card mechanics table source (Story U-003), read once in [method _ready]
## via [method Card.cards_from_text] and used to build the [CardDeck] passed
## into [BattleController]. Same MISSING/UNREADABLE gating discipline as
## [constant TERRAIN_PATH] / [constant ROSTER_PATH] / [constant AFFINITY_PATH]
## (ships with the game; absence is a packaging defect) — but unlike terrain/
## roster, a file that parses CLEANLY to zero cards is a legal, expressible
## design state (GDD Edge Cases "卡池張數少於開局手牌數"; [CardDeck]'s own doc
## comment on empty-pool handling), never escalated to [method _fail_load].
## A CORRUPT row ([method Card.cards_from_text] returning [code]null[/code] —
## that method's own 2026-09-16 manager ruling for this table) IS a load
## failure, distinguished from the legal-empty case via
## [method classify_card_parse], mirroring [constant AFFINITY_PATH]'s
## [method classify_affinity_parse] null/array distinction.
const CARDS_PATH: String = "res://assets/data/cards/vs01_cards.txt"

## Card-face flavor text table (Story U-003), read once in [method _ready]
## via [method CardText.flavor_texts_from_text]. Only ever gated by
## [constant LoadFailure.MISSING] / [constant LoadFailure.UNREADABLE] — that
## parser has no [code]null[/code]/failure return path (see its own doc
## comment, "placeholder, deliberately undecided" for a malformed row), so
## there is no analogous parse-error classification for this path the way
## there is for [constant CARDS_PATH] / [constant AFFINITY_PATH].
const CARD_TEXT_PATH: String = "res://assets/data/cards/vs01_card_text.txt"

## Classification of why loading terrain/roster/affinity data failed, checked
## independently per file in [method _ready]. Ordered from "never got to open
## the file" through "opened it but the content was useless" so a single
## failing file always maps to exactly one value — see [method
## classify_file_access], [method classify_content], and (affinity-only)
## [method classify_affinity_parse] for how each value is reached.
##
## [constant PARSE_ERROR] is appended at the tail rather than inserted among
## the content-related values above it, as a general convention for adding
## enum members — not, as of this correction, because label lookups depend on
## ordinal position. [method _fail_load] and the affinity zero-links
## diagnostic both used to look up a value's name via
## [code]LoadFailure.keys()[value][/code], which reads a value out of the
## KEY-ORDER array by treating it as if it were indexed by VALUE — exactly the
## registered project-forbidden pattern
## [code]enum_value_positional_string_conversion[/code]
## ([code]docs/registry/architecture.yaml[/code]) — a real hazard for any enum
## with explicit/non-sequential ordinals, and fragile even here where the
## ordinals happen to be sequential from 0. Both call sites now use
## [code]LoadFailure.find_key(value)[/code] instead, which does a reverse
## value→name lookup and is therefore correct regardless of where in the
## declaration a member sits.
enum LoadFailure {
	NONE,
	MISSING,
	UNREADABLE,
	EMPTY_CONTENT,
	PARSED_EMPTY,
	PARSE_ERROR,
}

# Developer-facing log line only (never shown to the player) — deliberately
# not one of the TEXT_* UI-string constants below, since push_error() output
# is not user-facing text under .claude/rules/ui-code.md's localization rule.
const _LOG_LOAD_FAILURE_FORMAT: String = "BattleScreen: failed to load %s (%s)"

# Developer-facing log line for the affinity table's zero-links case, which is
# a legal design state and therefore never blocks the load (see _ready()) —
# push_warning() rather than push_error(), and never routed through
# _fail_load(). The second slot is a LoadFailure name (EMPTY_CONTENT or
# PARSED_EMPTY) borrowed purely as a diagnostic label so a truly empty file is
# distinguishable in the log from a file containing only comments/blank lines.
const _LOG_AFFINITY_ZERO_LINKS_FORMAT: String = "BattleScreen: %s parsed to zero affinity links (%s) — proceeding with no pairings"

# Developer-facing log line for the card table's zero-cards case (Story
# U-003 Implementation Notes #2) — a legal design state (GDD Edge Cases "卡池
# 張數少於開局手牌數"), so this never blocks the load and is never routed
# through _fail_load(), mirroring _LOG_AFFINITY_ZERO_LINKS_FORMAT's own
# never-a-failure discipline.
const _LOG_CARDS_ZERO_PARSED_FORMAT: String = "BattleScreen: %s parsed to zero cards — proceeding with an empty CardDeck"

## UI-facing display string KEYS (not literal text) — Story-002 migration
## (`production/epics/localization-infrastructure/story-002-migrate-existing-hardcoded-strings.md`).
## This block used to hold the literal Traditional Chinese strings directly;
## per this comment's own prior wording ("when a localization system exists,
## each constant becomes a [method tr] call and this is the only block that
## has to change") — that system now exists ([Loc], Story-001) and this is
## that change. Every constant below is a [StringName] key into
## `assets/data/locales/strings.csv`, never a display string itself; every
## read site wraps the constant in [method Loc.localize] to get the actual
## text — matching [code].claude/rules/ui-code.md[/code]'s "all UI text must
## go through the localization system" rule, now enforced rather than
## deferred.
const TEXT_STATUS_FORMAT: StringName = &"battle.hud.status_format"
const TEXT_FACTION_PLAYER: StringName = &"battle.hud.faction_player"
const TEXT_FACTION_ENEMY: StringName = &"battle.hud.faction_enemy"
const TEXT_RESULT_VICTORY: StringName = &"battle.hud.result_victory"
const TEXT_RESULT_DEFEAT: StringName = &"battle.hud.result_defeat"

## [member _info_label] text for the cursor preview (see [method _refresh_view]'s
## Mode A/B/C). [constant TEXT_AFFINITY_PREVIEW_FORMAT] is Mode A ("if I move
## here"); [constant TEXT_AFFINITY_CURRENT_FORMAT] is Mode B (cursor resting on
## a linked unit, no move in progress); [constant TEXT_DAMAGE_PREVIEW_FORMAT] is
## Mode C (cursor on an attackable enemy). Measured against [member _info_label]'s
## 288px width at font size 16 — see the task report for the longest formatted
## string's measured pixel width. 🔴 Story-002: these three are now
## [StringName] keys (see the TEXT_* block's own doc comment above) — [method
## format_affinity_preview] / [method format_affinity_current] / [method
## format_damage_preview] each resolve their own via [method Loc.localize]
## before applying [code]%[/code] formatting; the measured pixel width above
## was measured against the Traditional Chinese value these keys resolve to
## today (`assets/data/locales/strings.csv`), not re-measured against the key
## strings themselves.
const TEXT_AFFINITY_PREVIEW_FORMAT: StringName = &"battle.hud.affinity_preview_format"
const TEXT_AFFINITY_CURRENT_FORMAT: StringName = &"battle.hud.affinity_current_format"
const TEXT_DAMAGE_PREVIEW_FORMAT: StringName = &"battle.hud.damage_preview_format"

## Story 012 (格位資訊面板) — key block for the new always-on tile-info panel
## (distinct from the three-way affinity/damage preview above, per
## `design/ux/tactical-combat-screen.md` 5.3(b): that label never showed
## terrain/occupant data at all). See [method build_tile_info_text] for how
## these are composed and [method _update_tile_info_panel] for the one call
## site that writes them to screen.
const TEXT_TILE_INFO_UNRESOLVED: StringName = &"battle.tile_info.unresolved"
const TEXT_TILE_INFO_TERRAIN_LINE_FORMAT: StringName = &"battle.tile_info.terrain_line_format"
const TEXT_TILE_INFO_TERRAIN_OPEN: StringName = &"battle.tile_info.terrain_open"
const TEXT_TILE_INFO_TERRAIN_BRUSH: StringName = &"battle.tile_info.terrain_brush"
const TEXT_TILE_INFO_TERRAIN_FALLEN_LOG: StringName = &"battle.tile_info.terrain_fallen_log"
const TEXT_TILE_INFO_TERRAIN_UNKNOWN: StringName = &"battle.tile_info.terrain_unknown"
const TEXT_TILE_INFO_COST_LINE_FORMAT: StringName = &"battle.tile_info.cost_line_format"
const TEXT_TILE_INFO_COST_UNKNOWN: StringName = &"battle.tile_info.cost_unknown"
const TEXT_TILE_INFO_CONCEALMENT_YES: StringName = &"battle.tile_info.concealment_yes"
const TEXT_TILE_INFO_CONCEALMENT_NO: StringName = &"battle.tile_info.concealment_no"
const TEXT_TILE_INFO_OCCUPANT_NONE: StringName = &"battle.tile_info.occupant_none"
const TEXT_TILE_INFO_FACTION_PLAYER: StringName = &"battle.tile_info.faction_player"
const TEXT_TILE_INFO_FACTION_ENEMY: StringName = &"battle.tile_info.faction_enemy"
const TEXT_TILE_INFO_FACTION_LINE_FORMAT: StringName = &"battle.tile_info.faction_line_format"
const TEXT_TILE_INFO_HP_LINE_FORMAT: StringName = &"battle.tile_info.hp_line_format"
const TEXT_TILE_INFO_STATE_NONE_USED: StringName = &"battle.tile_info.state_none_used"
const TEXT_TILE_INFO_STATE_ATTACK_ONLY: StringName = &"battle.tile_info.state_attack_only"
const TEXT_TILE_INFO_STATE_MOVE_ONLY: StringName = &"battle.tile_info.state_move_only"
const TEXT_TILE_INFO_STATE_DONE: StringName = &"battle.tile_info.state_done"
const TEXT_TILE_INFO_STATE_NOT_FOUND: StringName = &"battle.tile_info.state_not_found"
const TEXT_TILE_INFO_STATE_LINE_FORMAT: StringName = &"battle.tile_info.state_line_format"
const TEXT_TILE_INFO_WEAPON_RANGE_LINE_FORMAT: StringName = &"battle.tile_info.weapon_range_line_format"
const TEXT_TILE_INFO_MP_LINE_FORMAT: StringName = &"battle.tile_info.mp_line_format"

## Message template shown on [member _load_error_label] when terrain or
## roster data fails to load. Slot 1 is one of the TEXT_LOAD_REASON_*
## constants below; slot 2 is the failing file's [code]res://[/code] path.
## Kept to 6 lines including the two blank separators so the full formatted
## message (reason + path, each on their own line, plus this template's own
## 4 lines) fits within the capacity of [member _load_error_label].
##
## Measured 2026-08-28 against the control's current size, 464x254px
## ([code]offset_left/top/right/bottom[/code] 8/8/472/262 in
## [code]BattleScreen.tscn[/code]): line height is 26px at
## [code]ThemeDB.fallback_font[/code] size 16 (480x270 base resolution;
## measured from a 960x540 screenshot at ~52px line spacing, halved for the
## 2x scale), giving a capacity of 254 / 26 ≈ 9 lines. The formatted message
## actually renders as 8 lines (these 6 plus the path wrapping to 2) — a
## ~208px text block that, vertically centered, leaves ~23px of margin top
## and bottom. That 1 line of headroom exists because path length varies:
## the probe path
## [code]res://assets/data/levels/vs01_terrain_MISSING_PROBE.txt[/code]
## (55 chars) is what was measured, and it wraps to 2 lines cleanly; the
## longest real path in this file, [constant TERRAIN_PATH] (41 chars), is
## 14 chars shorter, so its worst case falls inside the verified range.
##
## The control was previously 456x192px, which was too small — a screenshot
## proved the 208px text block overflowed the 192px box and the last line
## ("回報問題時請附上這個畫面。", the one line this message can least afford to
## lose) ended up covered by ControlsHintBg. See [method _fail_load] for the
## rest of that fix — enlarging the control alone was not enough; hiding
## ControlsHintBg was the other half.
##
## 🔴 Story-002: this and the five TEXT_LOAD_REASON_* constants below are now
## [StringName] keys (see the TEXT_* block's own doc comment above), resolved
## via [method Loc.localize] in [method load_failure_message]. The pixel
## measurements above were taken against the literal Traditional Chinese text
## these keys resolve to today (`assets/data/locales/strings.csv`) — verified
## byte-for-byte identical post-migration (commas and embedded [code]\n[/code]
## line breaks survive the CSV round-trip; see this story's own CSV-import
## probe) — not re-measured against the key strings themselves.
const TEXT_LOAD_FAILURE_FORMAT: StringName = &"battle.load_error.failure_format"
## Reason text for [constant LoadFailure.MISSING].
const TEXT_LOAD_REASON_MISSING: StringName = &"battle.load_error.reason_missing"
## Reason text for [constant LoadFailure.UNREADABLE].
const TEXT_LOAD_REASON_UNREADABLE: StringName = &"battle.load_error.reason_unreadable"
## Reason text for [constant LoadFailure.EMPTY_CONTENT].
const TEXT_LOAD_REASON_EMPTY_CONTENT: StringName = &"battle.load_error.reason_empty_content"
## Reason text for [constant LoadFailure.PARSED_EMPTY].
const TEXT_LOAD_REASON_PARSED_EMPTY: StringName = &"battle.load_error.reason_parsed_empty"
## Reason text for [constant LoadFailure.PARSE_ERROR].
const TEXT_LOAD_REASON_PARSE_ERROR: StringName = &"battle.load_error.reason_parse_error"

## Always-on control hint, drawn in the bottom margin strip below the board
## (board occupies y=[39,231) per [member BoardCoords.BOARD_ORIGIN] and its
## 192px height — this strip starts at y=231, so it can never overlap a
## board tile no matter what the text says). Deliberately a panel covering
## all input devices rather than a togglable full panel: a toggle would need
## its own input action bound on both keyboard and gamepad, and a
## 2026-08-27 [InputMap] probe against this exact project found no built-in
## action with both bindings that isn't already claimed by
## [code]battle_confirm[/code] (the only keyboard+gamepad-bound candidate,
## [code]ui_select[/code], shares its Space keybinding with
## [code]battle_confirm[/code] — reusing it would fire both actions on the
## same keypress).
##
## 🔴 Story U-016 (2026-09-24) rewrote this from one line to two.
## `"結束回合 Esc/B"` is removed — ending the turn is no longer any single
## keypress (AC-U12/AC-M1: it is a menu row now, reached via
## [code]battle_menu[/code]) — and the epic's other four newly-bound actions
## (`battle_cancel`/`battle_open_hand`/`battle_next_target`+`battle_prev_target`/
## `battle_menu`) are added. EPIC.md 陷阱十 measured the OLD one-line string at
## 452px against a ~464px usable width (12px of margin) BEFORE any of these
## five actions existed — fitting five more captions on that one line was
## never going to work, and this story's own Implementation Note 4 names two
## rejected alternatives before landing on two lines:
## [br]
## - A paged/togglable hint panel — needs its own input action bound on both
##   devices, and (per the paragraph above) no such unclaimed built-in action
##   exists; inventing a new custom one adds a SIXTH action to memorize.
## [br]
## - Shrinking the font size — directly collides with this project's
##   accessibility commitment (`design/ux/accessibility-requirements.md`,
##   Standard tier: 字級可調 75%~150%); this HUD text already scales with
##   [method HudLayout.font_size], and shrinking it further at the SAME N
##   would be a second, uncoordinated scale factor layered on top of that one.
## [br]
## Two lines needs neither: no new input action, no font-size change. 🔴 This
## split (not a page system, not a smaller font) is this story's own call per
## its Implementation Note 4 ("未經覆核、可被實作者推翻") — not a design
## decision handed down by any spec. Both lines' actual rendered width are
## measured against the REAL engine font in
## [code]tests/integration/ui/end_phase_unbind_test.gd[/code]'s
## [code]test_controls_hint_bar_fits_within_available_width_with_all_new_actions[/code]
## (not eyeballed — this story's own text explicitly forbids that), which is
## also where a numeric width finding, if any, belongs — not duplicated here
## to avoid the exact "same number copied in two places, one goes stale"
## failure this project has hit before.
##
## 🔴 Story-002: now a [StringName] key (see the TEXT_* block's own doc
## comment above), resolved via [method Loc.localize] at its one read site
## ([method _ready]). The width measurement this comment references above was
## taken against the literal text this key resolves to today — verified
## byte-for-byte identical post-migration, including the embedded [code]\n[/code]
## line break, via this story's own CSV-import probe.
const TEXT_CONTROLS_HINT: StringName = &"battle.hud.controls_hint"

## Keyboard/gamepad directional actions this screen listens for, mapped to the
## grid delta they apply to the pad-tracked cursor cell. All four are Godot's
## built-in [code]ui_*[/code] actions — verified (2026-08-27, headless
## [InputMap] query against this exact project) to already carry both
## keyboard (arrow keys) and gamepad (D-pad + left-stick axis) bindings by
## default, so no [code]project.godot[/code] change was needed for movement.
const _DIRECTION_VECTORS: Dictionary = {
	&"ui_up": Vector2i.UP,
	&"ui_down": Vector2i.DOWN,
	&"ui_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT,
}

## Story U-013 — S1's card-browsing actions (Interaction Map step 2:
## "← → ... 該卡上浮") mapped to [method HandBar.move_cursor]'s delta.
## Deliberately left/right only; up/down are not part of hand navigation.
const _HAND_DIRECTION_DELTAS: Dictionary = {
	&"ui_left": -1,
	&"ui_right": 1,
}

## story-018-enemy-phase-stepped-playback.md: how long to pause between two
## consecutive [method BattleController.step_enemy_phase] calls in [method
## _end_faction_phase_pressed] below — a PRESENTATION-layer timing value, not
## gameplay data, which is why it lives here and not in
## [code]battle_controller.gd[/code] (that story's Implementation Note #2
## draws this line explicitly). [code]0.3[/code] sits inside the story's
## suggested 0.25-0.4s band; proposed by this implementer, not separately
## playtested — a designer wanting a different pace only has to change this
## one constant, nothing in [BattleController].
const ENEMY_STEP_PAUSE_SECONDS: float = 0.3

## 2026-09-04 (Story 001): [code]_world_viewport_container[/code] used to be
## kept as a member here for [code].global_position[/code] in the mouse
## coordinate math — removed because that math now goes entirely through
## [method _window_pos_to_cell] / [WorldLayout], which need no node
## reference at all (see class doc comment's correction note). Deliberately
## not re-added: a live reference to this node that ISN'T used for anything
## would be exactly the kind of stale, misleading state this project's own
## registered failure patterns warn about.
@onready var _board_view: BoardView = $WorldViewportContainer/WorldViewport/BoardView
@onready var _status_label: Label = $UILayer/StatusLabel
## Right-aligned readout for the affinity/damage cursor preview — see
## [method _refresh_view]'s Mode A/B/C. Narrowed [member _status_label] from
## its old x=8..472 span to x=8..180 to make room for this at x=184..472.
@onready var _info_label: Label = $UILayer/InfoLabel
## Story 012 (格位資訊面板) — backing translucent panel + label, newly added to
## [code]BattleScreen.tscn[/code] under [code]UILayer[/code] by this story.
## Deliberately NOT a reuse of [member _info_label] (see that member's doc
## comment and `design/ux/tactical-combat-screen.md` 5.3(b)): this is new
## always-on tile/occupant data, not the three-way affinity/damage preview.
## Positioned/sized at runtime by [method _apply_tile_info_panel_layout]
## rather than the [code].tscn[/code]'s baked numbers — same
## "unconditionally overwritten on [method Node._ready]" convention
## [code]hud_layout_scaler.gd[/code] already documents for its own five HUD
## nodes, kept here instead of there because this story's file lock does not
## include that file (coordinator dispatch, 2026-10-15).
@onready var _tile_info_panel_bg: ColorRect = $UILayer/TileInfoPanelBg
@onready var _tile_info_panel_label: Label = $UILayer/TileInfoPanelBg/TileInfoPanelLabel
@onready var _result_label: Label = $UILayer/ResultLabel
@onready var _controls_hint_label: Label = $UILayer/ControlsHintBg/ControlsHintLabel
## Backing bar for [member _controls_hint_label] — only referenced directly
## (rather than through the label) so [method _fail_load] can hide the whole
## bar, not just its text. See [method _fail_load] for why.
@onready var _controls_hint_bg: ColorRect = $UILayer/ControlsHintBg
## Failure-mode message box — hidden by default in the scene
## ([code]BattleScreen.tscn[/code]), shown only when [method _fail_load] runs.
@onready var _load_error_label: Label = $UILayer/LoadErrorLabel
## Z1 手牌縮圖帶(Story U-011,`hand_bar.gd`)— fed by [method _refresh_view]
## from [method BattleState.card_deck]/[method BattleController.phase] via
## [method hand_bar_slot_kinds]/[method availability_for] below. [HandBar]
## itself has zero [Card]/[CardDeck] dependency (see its own class doc
## comment) — this screen is the one class allowed to know both sides,
## exactly as it already is for [BoardView]/[method line_tone_for].
@onready var _hand_bar: HandBar = $UILayer/HandBar

## Story U-016 — [BattleMenu] 實例,node path [code]$UILayer/BattleMenu[/code]
## (見 [code]BattleScreen.tscn[/code] 的 [code]BattleMenu[/code] 節點,
## instance 自 [code]res://src/ui/menu/BattleMenu.tscn[/code])。本畫面只負責
## 「讓它在場景樹裡存在,並在 battle_menu 動作觸發時呼叫它既有的 open()」——
## U-007~U-010 已交付選單自己的閘控/結束回合列/離開確認,本畫面不重寫選單
## 自己的行為。
## [br]
## 接線全在 [method _ready] 完成,只設定/連接一次:[member BattleMenu.controller]
## 與兩個 in_progress_check [Callable] 於此賦值;[signal
## BattleMenu.end_faction_phase_confirmed] 連到 [method
## _end_faction_phase_pressed],[signal BattleMenu.open_rejected] 連到 [method
## _on_battle_menu_open_rejected]。觸發路徑(何時呼叫 [method BattleMenu.open])
## 見 [method _handle_battle_menu_pressed] 自己的 doc comment。
@onready var _battle_menu: BattleMenu = $UILayer/BattleMenu

## S3 確認面板(Story U-014,`card_confirm_panel.gd`)— fed by [method
## _open_card_confirm_panel] from [method BattleController.selected_card]/
## [method BattleController.selected_target_a]/[method
## BattleController.selected_target_b] (2026-09-24 "消除重複" ruling — this
## screen no longer keeps its own copies of that data) and [member
## _card_flavor_texts]. [CardConfirmPanel]
## itself has zero [Card]/[Unit] dependency (see its own class doc comment) —
## this screen is the one class allowed to know both sides, exactly as it
## already is for [BoardView]/[HandBar].
@onready var _card_confirm_panel: CardConfirmPanel = $UILayer/CardConfirmPanel

## Story 013（攻擊確認面板,二段確認)— fed by [method _open_attack_confirm_panel]
## from [method BattleController.selected_unit] + the cursor's attack target
## (via [method _cursor_attack_target_id]) and [method
## BattleState.preview_damage_breakdown]. [AttackConfirmPanel] itself has zero
## [Unit]/[BattleState]/[BattleController] dependency (see its own class doc
## comment) — this screen is the one class allowed to know both, exactly as
## it already is for [BoardView]/[HandBar]/[CardConfirmPanel].
@onready var _attack_confirm_panel: AttackConfirmPanel = $UILayer/AttackConfirmPanel

## Injectable override for [constant TERRAIN_PATH]. Empty string (the
## default) means "no override — read [constant TERRAIN_PATH] exactly as
## before"; this screen's default-path behavior for every existing caller
## (production, and any prior test/tool that never sets this) is unchanged.
## Exists purely so a test can point this screen at a different terrain
## fixture without hand-rebuilding the node subtree [method _ready] already
## builds — see 2026-09-23 task note (Story evidence gap): a scene-load probe
## found no injection point here and had to reconstruct a partial [BoardView]
## subtree by hand instead, which is exactly the "measurement script silently
## re-implements behavior instead of exercising the real one" failure mode
## [code].claude/docs/technical-preferences.md[/code]'s "(A) 的精確定義"
## section names.
## [b]Timing contract:[/b] must be set after [method PackedScene.instantiate]
## and before [method Node.add_child] — [method _ready] reads this exactly
## once, and [method Node._ready] does not run until this node enters the
## tree via [method Node.add_child].
var terrain_path_override: String = ""

## Injectable override for [constant ROSTER_PATH]. Same contract as
## [member terrain_path_override] — see its doc comment.
var roster_path_override: String = ""

## Injectable override for [constant AFFINITY_PATH]. Same contract as
## [member terrain_path_override] — see its doc comment. 2026-09-23 manager
## ruling ("五個一次做完"): added alongside the other four data-path
## overrides in the same pass rather than deferred, after this implementer
## flagged that this table's MISSING/UNREADABLE/PARSE_ERROR gating is
## unaffected by which path string it runs against — the override only
## changes WHICH file is opened, never the classify_affinity_parse() /
## legal-empty-links judgment applied to what comes back.
var affinity_path_override: String = ""

## Injectable override for [constant CARDS_PATH]. Same contract as
## [member terrain_path_override] — see its doc comment.
var cards_path_override: String = ""

## Injectable override for [constant CARD_TEXT_PATH]. Same contract as
## [member terrain_path_override] — see its doc comment.
var card_text_path_override: String = ""

var _state: BattleState
var _order: TurnOrder
var _controller: BattleController

## Owning instance of the affinity data pool for this battle (ADR-0002
## mechanism one — a general, non-Autoload object constructed once and
## injected by reference; the forbidden pattern
## `autoload_singleton_for_testable_data_layers` in
## [code]docs/registry/architecture.yaml[/code] is why this is a member here
## rather than a singleton). Story U-003 (合流自
## story-009-wiring.md) judged [BattleScreen] the appropriate holder in this
## vertical slice, since no campaign-level node exists above it yet — see
## that story's Implementation Notes #4 for the reasoning and its explicit
## caveat that this is a slice-level judgment call, not a permanent
## architectural home. Kept as a member (rather than a local in
## [method _ready]) purely so the ownership decision is visible at the class
## level; [member BattleController._card_play_session] holding an
## [AffinityPoolWritePort] that holds this instance would keep it alive even
## as a local; see [member _phi]'s doc comment for the one case in this file
## where a local WOULD be a bug (an unset [Callable]) — this is not that
## case, since a plain object reference (not a [Callable] bound to one) keeps
## its normal [RefCounted] refcount.
var _affinity_pool: AffinityDataPool

## Injected Φ provider for [member _controller]'s [code]phi_provider: Callable[/code]
## constructor argument. [b]MUST stay a member field — never a local variable
## in [method _ready].[/b] [method BattleController._compute_phi] re-checks
## [method Callable.is_valid] immediately before every single attack rather
## than caching the result, and a [Callable] bound to a [RefCounted] instance
## method does NOT keep that instance alive on its own (it does not increment
## the bound object's reference count) — see
## [code]docs/engine-reference/godot/modules/scripting-typing.md[/code]
## section 6 ("`Callable` 綁定 `RefCounted` 實例方法的生命週期") for the
## measured engine behavior. If this were a local, it would go out of scope
## the moment [method _ready] returns, [member _controller]'s bound
## [Callable] would silently go invalid, and Φ would silently degrade to a
## constant 0 forever — no error, no failing test, just wrong numbers on
## screen. Keeping the reference here is what keeps [AffinityPhiProvider]
## alive for [member _controller]'s entire lifetime.
var _phi: AffinityPhiProvider

## Last cell rendered into the preview by [method _refresh_view] — compared
## against [member _cursor_cell] in [method _update_cursor_visual] so a full
## [method _refresh_view] rebuild only happens on an actual cell change, not
## once per frame. See [method _update_cursor_visual] for the gating logic.
var _rendered_cursor_cell: Vector2i = Vector2i(-1, -1)

## Whether the cursor currently has a valid on-board position — false while
## mouse authority holds the pointer off the board (see
## [method _update_cursor_visual]). Distinct from [member _cursor_cell]
## staying at its last valid value: this flag is what lets the preview logic
## in [method _refresh_view] tell "cursor really is here" apart from "cursor
## is nowhere, this is just a stale coordinate".
var _cursor_active: bool = false

## Story 012 (格位資訊面板) — [method CursorStateHost.is_current_target_valid]
## captured ONCE per frame in [method _process] at [code]process_priority =
## 100[/code] (see that method's own comment block for why — ADR-0005 機制六
## ⑥'s "下游讀取方必須在 process_priority 100 讀" obligation applies to every
## reader of the arbitrated state, not only the pre-existing
## [member _pending_target_confirm_press] consumer). [method
## _update_tile_info_panel] reads ONLY this cached field, never
## [CursorStateHost] directly — that method also runs synchronously from
## several [method _input]-triggered [method _refresh_view] call sites, and
## the AC for this story is explicit that the validity read itself must never
## happen inside input handling.
var _tile_info_cursor_valid: bool = false

## Last [member _cursor_active] value rendered into the preview — the second
## half of the [member _rendered_cursor_cell] gating pair. See
## [method _update_cursor_visual].
var _rendered_cursor_active: bool = false

## Set once in [method _ready] if terrain or roster data failed to load.
## Checked at the top of [method _process] and [method _input] as a second
## guard even though both are also disabled there via [method
## Node.set_process] / [method Node.set_process_input] — see [method
## _fail_load].
var _load_failed: bool = false

## Pad-authority cursor cell — moved one tile per directional press, clamped
## to the board. Also doubles as the last-known cell under mouse authority
## (kept in sync by [method _update_cursor_visual]) so a device switch never
## has to guess a starting cell.
var _cursor_cell: Vector2i = Vector2i.ZERO

## Last mouse position seen in [method _input], in raw OS window-physical
## pixels — see the class doc comment (2026-09-04 correction) for why this is
## no longer base-canvas space. Converted to a board cell on demand via
## [method _window_pos_to_cell], never stored pre-converted, so there is
## exactly one call site for the [WorldLayout] transform. Starts at a value
## far outside any window's bounds so the cursor stays hidden under mouse
## authority until a real mouse-motion event has actually arrived — this
## stays true at every supported resolution because [method
## _window_pos_to_cell] maps it to a deeply negative board-local coordinate
## regardless of the current window's scale/offset (both bounded: scale >= 1,
## centering offset is at most a few hundred pixels — see [WorldLayout]).
var _last_mouse_window_pos: Vector2 = Vector2(-1000.0, -1000.0)

## Edge-detection state for [member _DIRECTION_VECTORS], keyed by action name.
## Needed because [method InputEvent.is_action_pressed] on a raw event does
## not by itself debounce a held gamepad stick — [InputEventJoypadMotion] is
## re-delivered every frame while the axis stays past the deadzone, and
## without this the cursor would race across the board instead of moving one
## tile per press. Tracked manually via [method Input.is_action_pressed]
## polling rather than [method Input.is_action_just_pressed] so the edge
## logic is self-contained and easy to verify by reading this file alone.
var _direction_was_pressed: Dictionary = {}

## Story U-013 — same edge-detection discipline as [member
## _direction_was_pressed] (see that field's own doc comment for why a raw
## event's [method InputEvent.is_action_pressed] is not enough by itself for
## a held gamepad stick), but a SEPARATE [Dictionary] for [method
## _handle_hand_navigation]'s S1 hand cursor. Kept distinct on purpose — the
## board cursor and the hand cursor are two independent debounce states, and
## sharing one tracker between them would let a held direction on one bleed
## into the other's edge detection.
var _hand_direction_was_pressed: Dictionary = {}

## Story U-013 connective tissue — presentation-local mirror of "is [S1,
## [constant CardPlaySession.Step.SELECTING_CARD]] the step this screen most
## recently drove [BattleController]'s card-play session into", used ONLY to
## route [code]ui_left[/code]/[code]ui_right[/code]/[code]battle_confirm[/code]
## between [method HandBar.move_cursor]/[method _confirm_selected_card] and
## the pre-existing board move/attack path in [method _input].
##
## 🔴 [b]Deliberately NOT a full mirror of [enum CardPlaySession.Step][/b] —
## [BattleController] exposes [method BattleController.is_card_play_in_progress]
## (a bool) but no query for the session's EXACT step. Adding one (e.g.
## [code]card_play_step() -> CardPlaySession.Step[/code], mirroring [method
## BattleController.is_card_play_in_progress]'s own null-check-then-forward
## shape) would touch [code]src/gameplay/battle/battle_controller.gd[/code],
## which is outside this story's file lock ([code]battle_screen.gd[/code] +
## [code]board_view.gd[/code] only) — flagged to the coordinator, not added
## unilaterally.
##
## [b]Why this field tracks only ONE boundary, not the whole state
## machine[/b]: re-deriving [CardPlaySession]'s full SELECTING_TARGET /
## SELECTING_TARGET_B / CONFIRMING transition table here — in particular
## [method CardPlaySession.cancel]'s branch on the selected card's category —
## would be exactly this project's own registered failure pattern, the same
## formula implemented twice, agreeing only "today" (the same discipline
## [WorldLayout]/[HudLayout] already enforce elsewhere in this codebase:
## "呼叫端不得自行重刻"). This field is written ONLY from the return value of
## a call THIS screen itself just made ([method BattleController.open_hand] /
## [method BattleController.select_card] / [method BattleController.cancel]),
## never re-derived independently.
##
## ✅ [b]2026-09-22 (U-013 下半, CursorStateHost 整合) — 原本這裡登記的缺口已
## 關閉[/b]: cancelling out of target selection (S2 -> S1) now DOES flip this
## back to [code]true[/code] — see [method _handle_target_selection_cancel_transition],
## called from the [member _card_selecting_target] branch of [method _input]
## on every [code]battle_cancel[/code] press while target selection is
## active. The missing-accessor problem this paragraph used to describe is
## sidestepped, not solved: rather than adding
## [code]card_play_step() -> CardPlaySession.Step[/code] to
## [code]battle_controller.gd[/code] (still outside this story's file lock),
## [method _handle_target_selection_cancel_transition] infers the destination
## purely from [method BattleController.legal_targets]'s OWN return value
## immediately after the [method BattleController.cancel] call — empty means
## SELECTING_CARD (the only other place [method CardPlaySession.cancel] can
## land from SELECTING_TARGET), non-empty means SELECTING_TARGET (arrived from
## SELECTING_TARGET_B). This holds specifically because [method
## CardPlaySession.cancel]'s SELECTING_TARGET/SELECTING_TARGET_B branches never
## transition to CONFIRMING (only the reverse direction does) — read from that
## method's own code, not re-derived independently.
##
## 🔴 [b]A DIFFERENT, still-open gap this story's own scope does not close[/b]:
## cancelling OUT of CONFIRMING (S3) back into SELECTING_TARGET_B/
## SELECTING_TARGET does not re-register [constant CursorTypes.SurfaceType.BOARD_TILE]
## or restore [member _card_selecting_target] — see [method
## _after_target_selection_advanced]'s doc comment. S3 has no built UI yet
## (U-014), so this path is not reachable through anything this story wires
## end to end; recorded here so it is not silently inherited once S3 lands.
var _card_selecting_from_hand: bool = false

## Story U-013 — mirrors [member _card_selecting_from_hand]'s own "ONE
## boundary, written only from this screen's own return values" discipline
## (see that field's doc comment), applied to the SELECTING_TARGET /
## SELECTING_TARGET_B boundary instead of SELECTING_CARD. True from a
## successful [method BattleController.select_card] call (S1 -> S2/S2p) until
## either a successful [method BattleController.select_target] / [method
## BattleController.select_second_target] call moves the session past target
## selection into CONFIRMING ([method _after_target_selection_advanced]), or
## [method BattleController.cancel] returns it all the way to SELECTING_CARD
## ([method _handle_target_selection_cancel_transition]). Also gates whether
## [constant CursorTypes.SurfaceType.BOARD_TILE] is currently registered on
## [code]CursorStateHost[/code] — the two are set/cleared together at every
## call site, never independently.
var _card_selecting_target: bool = false

## Story U-014 (S3 確認面板) — presentation-local mirror of "is CONFIRMING
## (S3) the step this screen most recently drove [CardPlaySession] into".
## Gates the [method _input] branch that dispatches
## [code]battle_confirm[/code]/[code]battle_cancel[/code] to the S3 confirm
## panel instead of the S2/S2q target-selection branch.
##
## 🔴 2026-09-24 manager ruling ("消除重複") — this field is now the ONLY
## piece of S3 state this screen still keeps a local copy of. It could not be
## replaced by a direct [method BattleController.selected_card] read the way
## [member _card_confirm_card]/[member _card_confirm_target_a]/[member
## _card_confirm_target_b] were (see this file's own git history for those —
## removed in this same ruling): [code]selected_card() != null[/code] is true
## from [constant CardPlaySession.Step.SELECTING_TARGET] onward, not only at
## CONFIRMING, so it cannot distinguish "still picking a target" from "ready
## to confirm" the way this flag's OWN name requires. This flag is still
## written ONLY from this screen's own successful call return values (never
## re-derived from [CardPlaySession]'s transition table) — same discipline
## [member _card_selecting_from_hand]/[member _card_selecting_target] already
## establish for the other two S3-adjacent booleans.
var _card_confirming: bool = false

## Story U-014 (AC-U11) — deferred confirm-press flag, same shape as [member
## _pending_target_confirm_press] (see that field's own doc comment for the
## general pattern this mirrors): a [code]battle_confirm[/code] press while
## [member _card_confirming] is true is captured here, never acted on inside
## [method _input], so that N input events dispatched within the SAME frame
## (e.g. keyboard Enter AND gamepad A, AC-U11's literal scenario) collapse
## into exactly one [method BattleController.confirm] call in [method _process]
## — see [method _apply_pending_card_confirm]'s own doc comment for why acting
## synchronously inside [method _input] would misroute a same-frame second
## event once the first one already closes the session (is_card_play_in_progress()
## flips to false mid-frame, which would otherwise route straight into the
## board's own move/attack click path).
var _card_confirm_pending_press: bool = false

## Story U-014 — card-id -> flavor-text lookup, captured from the [CardText]
## table this screen's own [method _ready] already parses via [method
## CardText.flavor_texts_from_text] (see [constant CARD_TEXT_PATH]'s own doc
## comment: before this story, that parsed result was read once purely to
## prove the table loads cleanly, then discarded — "no screen in this slice
## consumes flavor text yet"). This story is the first consumer.
var _card_flavor_texts: Dictionary[String, String] = {}

## Story 013（攻擊確認面板,T2')— true while the attack confirm panel is open:
## a [code]battle_confirm[/code] press at a legal attack target opens this
## panel INSTEAD OF calling [method BattleController.click_tile] immediately
## (ADR-0001: opening the panel is a read-only operation — zero write, must
## not bump [member BattleState.combat_state_version]). Mirrors [member
## _card_confirming]'s own "written only from this screen's own call sites"
## discipline. Gates [method _input]'s keyboard/gamepad dispatch (highest
## priority — see that method's own comment) and [method _handle_mouse_button]
## (mouse clicks do nothing while this is true).
var _attack_confirming: bool = false

## Story 013 — deferred confirm-press flag, same shape as [member
## _card_confirm_pending_press] (see that field's own doc comment for the
## general pattern: a [code]battle_confirm[/code] press while [member
## _attack_confirming] is true is captured here, never acted on inside
## [method _input], so N input events dispatched within the SAME frame
## collapse into exactly one [method BattleController.click_tile] call in
## [method _process] — AC「同幀鍵盤+手把各送一次確認的去重保護」).
var _attack_confirm_pending_press: bool = false

## Story 013 — the exact board cell [method _confirm_at_cursor] was pointed
## at when the attack confirm panel opened, captured once at open time rather
## than re-read from [member _cursor_cell] at confirm time. Cursor movement is
## already rejected while T2' is open (see [method _input]'s
## [member _attack_confirming] branch, checked before [method
## _handle_directional] can run), but freezing this explicitly removes any
## dependency on that other guard staying correct — the write this field
## feeds ([method BattleController.click_tile]) is the one ADR-0001 obligation
## this whole story exists to gate correctly.
var _attack_confirm_target_cell: Vector2i = Vector2i(-1, -1)

## Story U-014 — injectable seam for the confirm panel's 丙類「好感度數值
## (現值 → 打完後)」欄位(`skill-card-play.md` UX-13:`combat_strength_read`
## 在 src/ 尚無實作)。Signature: [code]func(target_a_id: int, target_b_id: int)
## -> Dictionary[/code],預期回傳 [code]{"available": bool, "current": int,
## "projected": int}[/code]。🔴 [b]2026-09-24 管理者裁決「維持留白＋提示」
## ——本 story 刻意不注入任何真正的 Callable[/b],未設定(預設值)是唯一今天
## 存在的狀態,與本專案既有「未設 Callable = 安全預設」慣例相同(見
## [member _phi_provider]/[member _decide]/
## [member _authoritative_write_in_progress_check] 各自的 doc comment)——
## 這剛好也是今天唯一站得住腳的真實答案,因為沒有任何呼叫端能算出真值。
## 日後若要接上 S-007 的 `combat_strength_read`,只需要在這裡注入一個真正的
## Callable,本 story 的其餘程式碼不必變動。
var card_confirm_strength_provider: Callable = Callable()

## Story U-013 (ADR-0005 機制六②) — a pending "move CursorStateHost's target"
## request queued synchronously from [method _input] (jump keys) or this
## screen's own state-transition helpers (entering/re-entering target
## selection), consumed by [_TargetRetargetActor]'s own [method Node._process]
## at [code]process_priority = -60[/code] — the architecture-mandated open
## interval strictly between -100 and -25 (ADR-0005 R5-2; see
## [_TargetRetargetActor]'s own doc comment for why -60 specifically and why
## this cannot simply run inside THIS node's own [method _process]).
## [member _target_jump_forward] is only meaningful while this is
## [code]true[/code].
var _target_jump_requested: bool = false
var _target_jump_forward: bool = true

## Story U-013 (ADR-0005 機制六⑥) — a pending "read CursorStateHost's
## arbitrated state and, if valid, select the unit under the cursor" request,
## queued synchronously from a [code]battle_confirm[/code] press in
## [method _input] while [member _card_selecting_target] is true, consumed by
## [method _process] — see this story's Implementation Note #1 (quoted
## verbatim in that method's own comment) for why the actual read of
## [method CursorStateHost.get_current_target] /
## [method CursorStateHost.is_current_target_valid] must happen there and
## never in [method _input] itself.
var _pending_target_confirm_press: bool = false

## Story U-013 — dedicated child [Node] for ADR-0005 機制六② (see
## [_TargetRetargetActor]'s own doc comment for why this cannot be folded
## onto this screen's own [method _process]). Built once in [method _ready],
## never reassigned.
var _target_retarget_actor: Node

## story-018-enemy-phase-stepped-playback.md AC-E3 — QA/test-only diagnostic
## surface, mirroring this project's existing `diagnostic_*` convention (e.g.
## [method MouseReclaimPolicy.diagnostic_seed_position]); no gameplay code
## reads this. Counts [method _process] calls observed while [method
## BattleController.phase] is [constant BattleController.Phase.ENEMY_ACTING],
## reset to 0 at the start of every [method _end_faction_phase_pressed] call
## that actually proceeds past its phase guard. A real, engine-driven proxy
## for "did the enemy phase actually span more than one frame", since no
## other externally-observable signal answers that question directly.
var _diagnostic_enemy_acting_process_frame_count: int = 0

## See [member _diagnostic_enemy_acting_process_frame_count].
func diagnostic_enemy_acting_process_frame_count() -> int:
	return _diagnostic_enemy_acting_process_frame_count

## story-018-enemy-phase-stepped-playback.md AC-E4 — QA/test-only diagnostic
## surface, same convention as [member _diagnostic_enemy_acting_process_frame_count].
## Counts calls to [method BattleController.step_enemy_phase] made by [method
## _end_faction_phase_pressed], reset alongside the frame counter above.
## [b]Why this exists rather than reading [method
## TurnOrder.units_with_flags_remaining]'s size as a proxy[/b]: that count
## conflates "visited" with "done" — a unit that spends only one of its two
## flags in a single [method BattleController._process_enemy_unit] call stays
## in that list (it is not yet done), so the list's size does not shrink by
## one per call the way a naive reading would assume. This counter measures
## the thing AC-E4's re-entrancy tests actually need — how many times this
## screen invoked [method BattleController.step_enemy_phase] — without that
## ambiguity.
var _diagnostic_step_enemy_phase_call_count: int = 0

## See [member _diagnostic_step_enemy_phase_call_count].
func diagnostic_step_enemy_phase_call_count() -> int:
	return _diagnostic_step_enemy_phase_call_count


## story-u015-forced-discard.md, Implementation Note 2 ("拒絕須可觀測") —
## QA/test-only diagnostic surface, same convention as [member
## _diagnostic_enemy_acting_process_frame_count]. Counts every
## [code]battle_cancel[/code] press this screen has specifically intercepted
## and swallowed while [method BattleController.has_pending_discard] was
## true — distinct from [HandBar]'s persistent [constant
## HandBar.TEXT_FORCED_DISCARD] caption (which is visible the whole time S4 is
## active, regardless of whether cancel was ever pressed): this counter proves
## the REJECTION BRANCH specifically executed for a given press, not merely
## that "nothing happened because no other branch matched".
var _diagnostic_forced_discard_cancel_rejected_count: int = 0

## See [member _diagnostic_forced_discard_cancel_rejected_count].
func diagnostic_forced_discard_cancel_rejected_count() -> int:
	return _diagnostic_forced_discard_cancel_rejected_count

## story-u016-unbind-end-phase-and-hint-bar.md (AC-M16) — QA/test-only
## diagnostic surface, same convention as
## [member _diagnostic_forced_discard_cancel_rejected_count]. Records the
## most recent [signal BattleMenu.open_rejected] this screen observed (see
## [method _on_battle_menu_open_rejected]), proving the rejection path
## (forced discard / authoritative write) actually reaches this screen —
## 🔴 NOT a claim that the message is displayed anywhere on screen; see this
## story's task report for that disclosed gap.
var _diagnostic_last_menu_rejection_result: BattleMenu.OpenResult = BattleMenu.OpenResult.OPENED
var _diagnostic_last_menu_rejection_message: String = ""

## See [member _diagnostic_last_menu_rejection_result].
func diagnostic_last_menu_rejection_result() -> BattleMenu.OpenResult:
	return _diagnostic_last_menu_rejection_result

## See [member _diagnostic_last_menu_rejection_message].
func diagnostic_last_menu_rejection_message() -> String:
	return _diagnostic_last_menu_rejection_message

## story-011-input-gaps.md (U-T7, M1 audit 2026-09-29) — QA/test-only
## diagnostic surface, same convention as
## [member _diagnostic_last_menu_rejection_result]. Records the
## [code]action[/code] field of the most recent [method
## BattleController.click_tile] call this screen made (from either the mouse
## or the keyboard/gamepad confirm path — see
## [method _handle_click_tile_result]), proving that dispatch actually ran
## instead of the return value being silently discarded (the M1 audit's own
## finding: 「`&"none"` 這個 action 值沒有任何一處消費它」).
## 🔴 NOT a claim that a rejection is displayed anywhere on screen — same
## disclosed gap as [member _diagnostic_last_menu_rejection_message] above;
## a visible rejection indicator is new UI surface this story's Out of Scope
## section does not ask for.
## ⚠️ [code]&"none"[/code] has THREE distinct internal causes inside [method
## BattleController.click_tile] (wrong phase / clicked somewhere irrelevant
## while nothing is selected / [method BattleController._apply_attack] or
## [method BattleController._apply_move]'s own internal re-check failing) —
## this diagnostic cannot and does not distinguish which of the three
## produced a given [code]&"none"[/code]; it only proves the branch ran.
var _diagnostic_last_click_tile_action: StringName = &""

## Counts every [method BattleController.click_tile] call whose returned
## [code]action[/code] came back [code]&"none"[/code] — distinct from
## [member _diagnostic_last_click_tile_action], which only remembers the
## single most recent action and would be overwritten by the very next
## legal click.
var _diagnostic_click_tile_rejected_count: int = 0

## See [member _diagnostic_last_click_tile_action].
func diagnostic_last_click_tile_action() -> StringName:
	return _diagnostic_last_click_tile_action

## See [member _diagnostic_click_tile_rejected_count].
func diagnostic_click_tile_rejected_count() -> int:
	return _diagnostic_click_tile_rejected_count

## story-011-input-gaps.md (U-T8) — QA/test-only diagnostic surface, same
## convention as [member _diagnostic_click_tile_rejected_count] above. Counts
## every [code]battle_end_unit_turn[/code] press this screen dispatched to
## [method BattleController.end_unit_turn] whose return value came back
## [code]false[/code] (no unit selected, wrong phase, unit already done, or a
## forced discard owed — see that method's own doc comment for the full list
## of rejection causes) — proving the return value is actually consumed
## rather than discarded, per this project's established "never drop a
## bool/Dictionary result" discipline (see [method _handle_click_tile_result]'s
## own doc comment for the U-T7 precedent this mirrors).
var _diagnostic_end_unit_turn_rejected_count: int = 0

## See [member _diagnostic_end_unit_turn_rejected_count].
func diagnostic_end_unit_turn_rejected_count() -> int:
	return _diagnostic_end_unit_turn_rejected_count


## Story U-013 (ADR-0005 機制六⑥, R4-7's own suggested split for a system
## that is simultaneously role ② and role ⑥ — see [_TargetRetargetActor]'s
## doc comment for role ②'s side of the split) — [b]this node's own
## [member Node.process_priority] is 100, not the engine default 0[/b].
##
## R4-1's table pins role ⑥ ("下游讀取方(含確認動作判讀)") at EXACTLY 100; this
## screen becomes role ⑥ the moment [method _apply_target_confirm_from_cursor_state]
## exists (called from THIS node's own [method _process], see that method's
## body). R4-7 explicitly names "戰棋系統同時是②...與⑥幾乎是必然" and forbids
## folding both roles onto one node at one priority (② needs a value strictly
## less than -25; ⑥ needs exactly 100 — no single [member Node.process_priority]
## value satisfies both), then gives its own suggested fix verbatim: "主節點
## 設 100 承擔⑥,另建一個極薄的子節點設 −60 承擔②" (ADR-0005, R4-7 section) —
## literally what this file does: [_TargetRetargetActor] (below) is that thin
## child node.
##
## [b]Side effect, disclosed rather than silent[/b]: this ALSO moves this
## screen's own pre-existing, CursorState-unrelated per-frame work ([method
## _update_cursor_visual], the enemy-phase diagnostic counter — neither reads
## or writes [code]CursorStateHost[/code] directly; [method _update_cursor_visual]
## only READS [method CursorStateHost.get_device_authority] /
## [method CursorStateHost.get_current_target], it does not write them) from
## the engine default priority (0) to 100. [b]Story 009 (2026-10-13)[/b] — a
## third item used to live in this list, [code]DeviceAuthority.resolve_frame()[/code]
## on this screen's own now-fully-retired [code]_device[/code] tracker; it is
## removed from this sentence because the method and the tracker it ran on no
## longer exist, not because the historical claim about U-013's own moment was
## ever wrong. Nothing else in this scene currently orders itself
## against this node's own [member Node.process_priority] (no sibling/child
## node in this slice declares one of its own, other than the cursor system's
## own Autoload children), so this is expected to be behavior-preserving for
## that unrelated work — confirmed by this story's full test-suite run, not
## merely reasoned about; see this story's task report if that run ever
## regresses.
func _init() -> void:
	process_priority = 100


## Story U-013 (ADR-0005 機制六②, R5-2's open interval, R4-7's suggested
## "thin child node" split — see [method _init]'s own doc comment for why
## this screen cannot just do role ② inside its own [method _process]).
## Mirrors [code]cursor_navigation_applier.gd[/code]'s [CursorNavigationApplier]
## shape exactly: bare owner reference, [member Node.process_priority] set in
## its OWN [method Node._init] before [method Node.add_child] (R6-12).
##
## [b]Story 009 (2026-10-13) — now forwards to TWO methods, not one[/b]: the
## mouse-path retirement of [code]battle_screen.gd[/code]'s own
## [code]DeviceAuthority[/code] tracker added [method
## BattleScreen._apply_mouse_target_if_authoritative] as a second per-frame
## call from [method Node._process] below, alongside the pre-existing [method
## BattleScreen._apply_pending_target_jump]. Both belong on this same node for
## the SAME reason (ADR-0005 R5-2's open interval — [method
## CursorStateHost.set_target] may only be called from strictly between -100
## and -25), so splitting them across two nodes would buy nothing; the
## "single responsibility" this comment used to claim was about forwarding
## rather than owning any logic itself, not about call count — the line has
## been corrected rather than left to describe a shape this class no longer
## has (this project's own registered failure mode: prose describing
## architecture drifting from the code once the code changes under it).
##
## [b]Deliberately an inner class, not a new file[/b] — this story's file
## lock is explicit: "本 story 修改兩個既有檔案(累加修改,不新建)"
## ([code]production/epics/card-play-interface/story-u013-target-selection-and-highlight.md[/code]
## 第 20-22 行, section "🔴 本 story 決定的原始碼目錄路徑"). A new top-level
## class would need its own [code].gd[/code] file, which that line forbids;
## an inner class stays inside [code]battle_screen.gd[/code] while still
## satisfying ADR-0005's own node-splitting requirement ("process_priority 是
## 逐節點屬性,同一節點不可能同時位於 −100 與 −25,故 GDD 四步序列的步驟一與
## 步驟三必須落在兩個節點上", R4-1 row for actor ③) — [b]U-013 is the FIRST
## caller of this exact pattern anywhere in this codebase[/b] (R4-1's table
## marks its own "零命中" for this mechanism); flagged here so the next
## caller of this pattern has a precedent to point at.
##
## [b]-60, not some other value in (-100, -25)[/b]: the ADR's own reference
## value for role ②, used verbatim rather than picking a different in-range
## number (R5-2, "修法兩點" 第一點: "② 的參考值由 −50 改為 −60...取 −60 而非
## −50,是為了與兩端都留出安全間距 —— 下游若因為別的理由微調這個值,±10 的
## 漂移不會撞到任何一端"). No reason was found to deviate from the
## architecture's own documented choice.
class _TargetRetargetActor extends Node:
	var _owner: BattleScreen

	func _init(owner: BattleScreen) -> void:
		process_priority = -60
		_owner = owner

	func _process(_delta: float) -> void:
		_owner._apply_pending_target_jump()
		_owner._apply_mouse_target_if_authoritative()


func _ready() -> void:
	_controls_hint_label.text = Loc.localize(TEXT_CONTROLS_HINT)

	var terrain_text: String = ""
	var terrain_rows: PackedStringArray = PackedStringArray()
	var terrain_path: String = TERRAIN_PATH if terrain_path_override.is_empty() else terrain_path_override
	var terrain_failure: LoadFailure = classify_file_access(terrain_path)
	if terrain_failure == LoadFailure.NONE:
		terrain_text = FileAccess.get_file_as_string(terrain_path)
		terrain_rows = _parse_terrain_rows(terrain_text)
		terrain_failure = classify_content(terrain_text, terrain_rows.size())

	var roster_text: String = ""
	var roster_units: Array[Unit] = []
	var roster_path: String = ROSTER_PATH if roster_path_override.is_empty() else roster_path_override
	var roster_failure: LoadFailure = classify_file_access(roster_path)
	if roster_failure == LoadFailure.NONE:
		roster_text = FileAccess.get_file_as_string(roster_path)
		roster_units = Unit.roster_from_text(roster_text)
		roster_failure = classify_content(roster_text, roster_units.size())

	# Affinity table load — deliberately a DIFFERENT policy from terrain/roster
	# above. classify_file_access() still gates this file the same way
	# (MISSING / UNREADABLE): it ships with the game, so its absence is a
	# packaging defect, not a design choice — the same class of bug fixed
	# earlier when a data file was not packed into the .exe and the game
	# silently drew an empty board while 151 tests stayed green.
	#
	# 2026-09-16 (second manager ruling): a row that fails to parse now ALSO
	# gates this file, via classify_affinity_parse() — AffinityLink
	# .links_from_text() returns null (not []) on a parse failure specifically
	# so this branch can tell it apart from a legal empty table. Before this
	# change, both cases returned [], and this file could not distinguish
	# "a row is corrupt" from "nobody is paired by design" — see
	# links_from_text()'s doc comment for the full history.
	#
	# But a file that PARSES CLEANLY to zero links is still never escalated to
	# a load failure: it is a legal, expressible design state meaning "nobody
	# is paired" (unit 5, 戊, deliberately has no links, and a test pins that)
	# — blocking it would make "remove all pairings" impossible to express.
	# classify_content() still runs in that case, but purely to pick a
	# diagnostic label for the push_warning() below (EMPTY_CONTENT vs
	# PARSED_EMPTY, so a truncated file stays distinguishable from a
	# comments-only file in the log) — its result is never written back into
	# affinity_failure, so it can never reach _fail_load() on its own.
	# affinity_failure therefore carries MISSING / UNREADABLE / PARSE_ERROR /
	# NONE forward (never EMPTY_CONTENT / PARSED_EMPTY — those two remain
	# diagnostic-only for this path).
	var affinity_text: String = ""
	var links: Array[AffinityLink] = []
	var affinity_path: String = AFFINITY_PATH if affinity_path_override.is_empty() else affinity_path_override
	var affinity_failure: LoadFailure = classify_file_access(affinity_path)
	if affinity_failure == LoadFailure.NONE:
		affinity_text = FileAccess.get_file_as_string(affinity_path)
		var parsed_links: Variant = AffinityLink.links_from_text(affinity_text)
		affinity_failure = classify_affinity_parse(parsed_links)
		if affinity_failure == LoadFailure.NONE:
			links = parsed_links
			if links.is_empty():
				var diagnostic: LoadFailure = classify_content(affinity_text, links.size())
				push_warning(
					_LOG_AFFINITY_ZERO_LINKS_FORMAT % [affinity_path, LoadFailure.find_key(diagnostic)]
				)

	# Card mechanics table load (Story U-003) — same MISSING/UNREADABLE
	# file-access gating as terrain/roster/affinity above. Unlike those, a
	# CORRUPT row (Card.cards_from_text() returning null) is ALSO a load
	# failure here, via classify_card_parse() — mirroring the affinity
	# table's null/legal-empty-array distinction. A file that parses CLEANLY
	# to zero cards is legal (Story U-003 Implementation Notes #2: "卡池張數
	# 少於開局手牌數" is an existing, documented CardDeck edge case) and only
	# ever produces a push_warning(), never reaching _fail_load().
	var cards: Array[Card] = []
	var cards_path: String = CARDS_PATH if cards_path_override.is_empty() else cards_path_override
	var cards_failure: LoadFailure = classify_file_access(cards_path)
	if cards_failure == LoadFailure.NONE:
		var cards_text: String = FileAccess.get_file_as_string(cards_path)
		var parsed_cards: Variant = Card.cards_from_text(cards_text)
		cards_failure = classify_card_parse(parsed_cards)
		if cards_failure == LoadFailure.NONE:
			cards = parsed_cards
			if cards.is_empty():
				push_warning(_LOG_CARDS_ZERO_PARSED_FORMAT % cards_path)

	# Card flavor-text table load (Story U-003) — file-access gating only;
	# CardText.flavor_texts_from_text() has no null/failure return path (see
	# its own doc comment), so there is no analogous parse-error branch to
	# classify here. Parsed purely to prove the table loads cleanly — no
	# screen in this slice consumes flavor text yet (U-009+, out of scope for
	# this story), so the result is not retained past this call.
	var card_text_path: String = CARD_TEXT_PATH if card_text_path_override.is_empty() else card_text_path_override
	var card_text_failure: LoadFailure = classify_file_access(card_text_path)
	if card_text_failure == LoadFailure.NONE:
		var card_text_text: String = FileAccess.get_file_as_string(card_text_path)
		# Story U-014 — the first consumer of this parsed table (see
		# CARD_TEXT_PATH's own doc comment history: previously read once and
		# discarded). Kept in _card_flavor_texts so _open_card_confirm_panel()
		# can show the confirm panel's "卡名與牌面文字" field.
		_card_flavor_texts = CardText.flavor_texts_from_text(card_text_text)

	if (
		terrain_failure != LoadFailure.NONE
		or roster_failure != LoadFailure.NONE
		or affinity_failure != LoadFailure.NONE
		or cards_failure != LoadFailure.NONE
		or card_text_failure != LoadFailure.NONE
	):
		_fail_load({
			terrain_path: terrain_failure,
			roster_path: roster_failure,
			affinity_path: affinity_failure,
			cards_path: cards_failure,
			card_text_path: card_text_failure,
		})
		return

	_state = BattleState.create(terrain_rows, roster_text)

	var player_ids: Array[int] = []
	var enemy_ids: Array[int] = []
	for unit: Unit in _state.units_of(Unit.Faction.PLAYER):
		player_ids.append(unit.id)
	for unit: Unit in _state.units_of(Unit.Faction.ENEMY):
		enemy_ids.append(unit.id)
	_order = TurnOrder.new(player_ids, enemy_ids)
	# story-005 (affinity-position-chain) — _affinity_pool must exist BEFORE
	# _phi is constructed: _phi now queries it fresh on every phi()/links()
	# call instead of reading a static pairing-table file once (see
	# AffinityPhiProvider's own header comment). This moves the
	# AffinityDataPool.new() call that used to sit right before the
	# BattleController.new() call (Story U-003) up to here — nothing else
	# about its construction changed, only its position in _ready().
	_affinity_pool = AffinityDataPool.new()

	# story-005 追加裁決(2026-10-15 管理者裁決,
	# production/epics/affinity-position-chain/story-005-seeding-ruling-2026-10-15.md)
	# —— 暫代灌入:開局依已解析完成的 `links`(來自 AFFINITY_PATH 的那份
	# Array[AffinityLink])逐條對 _affinity_pool 寫入一筆記錄。沒有這段,
	# AffinityDataPool._init() 預填的全部 10 對配對開局都是空記錄串列
	# (n_pair=0),Φ 會恆為 0、棋盤開局一條關係線都不畫,直到劇情卡牌寫入
	# 或存檔系統(ADR-0004,維持 Proposed)落地為止 —— 那兩者都還沒實作。
	#
	# 🔴 這是明文登記的暫代品,不是設計(裁決檔第二節第 3 點)。未來劇情卡牌
	# 或存檔能真的寫入池子時,這段灌入要被換掉,不是再疊一層。
	#
	# 數值大小刻意不具意義(裁決檔第二節第 2 點):AffinityPhiProvider
	# ._link_for_pair() 只取 combat_strength_read() 結果的 value 正負號
	# (OQ-3 裁決),amp 恆為 AffinityLink.AMP_EXPECTED,故任何同號數值都會
	# 得到完全相同的 Φ。這裡用 ±AMP_EXPECTED(= 1.0),與效能基準腳本
	# tests/perf/affinity_query_perf_benchmark.gd 既有的植入慣例一致
	# (該腳本為同一件事已選用 Source.STORY_EVENT + 同量級數值)。
	for link: AffinityLink in links:
		var character_a_variant: Variant = (
			AffinityRosterCharacterMapper.character_for_roster_id(link.unit_a)
		)
		var character_b_variant: Variant = (
			AffinityRosterCharacterMapper.character_for_roster_id(link.unit_b)
		)
		# 對映失敗(null)時跳過,不得當成合法配對寫入 —— 靜態檔理論上只會
		# 出現主角 id(1~5),但解析層本身不保證這一點
		# (AffinityRosterCharacterMapper.character_for_roster_id 的 null 回傳
		# 已經自行 push_error 記錄了失敗原因,這裡不重複記一次 error,只用
		# warning 標出「因此被跳過」這個後果)。
		if character_a_variant == null or character_b_variant == null:
			push_warning(
				(
					"BattleScreen._ready: skipping opening affinity seed for link "
					+ "%d-%d -- at least one roster id failed to map to a Character "
					+ "(see the error logged by "
					+ "AffinityRosterCharacterMapper.character_for_roster_id above)."
				) % [link.unit_a, link.unit_b]
			)
			continue
		var character_a: AffinityTypes.Character = character_a_variant
		var character_b: AffinityTypes.Character = character_b_variant
		var pair: AffinityTypes.Pair = AffinityTypes.pair_of(character_a, character_b)
		var seed_value: float = (
			float(AffinityLink.AMP_EXPECTED)
			if link.polarity == AffinityLink.Polarity.POSITIVE
			else -float(AffinityLink.AMP_EXPECTED)
		)
		# append_record() 的拒絕碼必須檢查、不得丟掉(本專案已登記「靜默吞掉
		# 失敗」是重複發作的失效形狀)。這裡選 push_error() 而非
		# push_warning():靜態檔只有 2 條、兩個合法配對,正常路徑下這個呼叫
		# 不應該被拒絕 —— 若真的被拒,代表灌入邏輯本身有錯(例如重複寫入同一
		# 對、或 pair/source 序數算錯),是工程錯誤而非合法的遊戲狀態,比照
		# AffinityPhiProvider._link_for_pair() 對 ReadRejection 的既有慣例
		# (該方法對「結構上不該發生」的拒絕一律用 push_error)。刻意不用
		# assert() —— 依 .claude/docs/coding-standards.md 的 2026-09-15 條目,
		# assert() 失敗會讓函式回傳列舉序數 0,而 WriteRejection 的序數 0 正是
		# NONE(成功),會讓失敗的寫入被靜默當成成功。
		var seed_rejection: AffinityDataPool.WriteRejection = _affinity_pool.append_record(
			pair, seed_value, AffinityTypes.Source.STORY_EVENT
		)
		if seed_rejection != AffinityDataPool.WriteRejection.NONE:
			push_error(
				(
					"BattleScreen._ready: opening affinity seed for link %d-%d "
					+ "(pair ordinal %d) was REJECTED with WriteRejection code %d -- "
					+ "the opening board state will NOT reflect this static "
					+ "relationship. This should never happen for the current "
					+ "2-row static table; see story-005-seeding-ruling-2026-10-15.md."
				) % [link.unit_a, link.unit_b, pair, seed_rejection]
			)

	# _phi is stored as a member (see its own doc comment on why a local here
	# would be a bug) so BattleController's bound Callable stays valid for the
	# controller's entire lifetime. The enemy attack path is untouched:
	# BattleState.resolve_attack() already forces phi to 0 for ENEMY
	# attackers by design, regardless of what this provider returns.
	#
	# story-005 — _phi no longer takes the static `links` pairing table read
	# from AFFINITY_PATH above; it now takes _affinity_pool and queries it
	# fresh per call (see AffinityPhiProvider.links()). `links` itself is
	# NOT retired by this change: BattleController still needs it below for
	# PermanentAffinityWriteRules' canon-relationship-line check (丙類 card
	# legality, GDD 界線 3/4) -- a completely separate concern from Φ's
	# numeric strength data, which now lives in _affinity_pool instead.
	_phi = AffinityPhiProvider.new(_state, _affinity_pool)

	# Story U-003 — the two halves this story's merge exists to wire: a real
	# CardDeck (rng=null here means production, time-seeded
	# shuffling — see _build_card_deck()'s own doc comment for why tests call
	# it directly with a fixed-seed RNG instead of going through this path),
	# and a real AffinityDataPool wrapped in AffinityPoolWritePort in place of
	# the NullAffinityWritePort BattleController._init() would otherwise
	# substitute. _affinity_pool is this battle's single instance (ADR-0002
	# mechanism one — see that member's own doc comment for why it is owned
	# here).
	var card_deck: CardDeck = _build_card_deck(cards)
	var write_port: AffinityPoolWritePort = AffinityPoolWritePort.new(_affinity_pool)

	_controller = BattleController.new(
		_state, _order, Callable(_phi, "phi"), Callable(), card_deck, links, write_port
	)

	_controller.unit_selected.connect(func(_id: int) -> void: _refresh_view())
	_controller.selection_cleared.connect(func() -> void: _refresh_view())
	_controller.unit_moved.connect(func(_id: int, _from: Vector2i, _to: Vector2i) -> void: _refresh_view())
	_controller.attack_resolved.connect(
		func(_attacker_id: int, _target_id: int, _damage: int, _target_died: bool) -> void:
			_refresh_view()
	)
	_controller.phase_changed.connect(func(_new_phase: BattleController.Phase) -> void: _update_status_label())
	_controller.battle_ended.connect(_on_battle_ended)

	_board_view.render_terrain(terrain_rows)
	# Story 008 (cursor navigation convergence) — registers the normal
	# move/attack path's ownership of BOARD_TILE the moment this screen is
	# ready, mirroring the card-play path's existing register/unregister
	# discipline (_confirm_selected_card() etc. below). 🔴 Wiring only
	# (AC-1): _cursor_cell below is NOT yet converted to read from
	# CursorStateHost (that is a separate, later change) — until then,
	# CursorStateHost's own per-frame pipeline and this screen's
	# _handle_directional() independently move two separate state variables
	# from the same keypress (engine-verified,
	# tests/integration/ui/battle_cursor_navigation_convergence_test.gd's
	# finding #1). Handed off to card-play at _handle_open_hand_pressed()'s
	# open_hand() success branch, reclaimed at both
	# _handle_open_hand_pressed()'s cancel-success branch and
	# _apply_pending_card_confirm()'s confirm-success branch.
	var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
	if register_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
		push_error(
			"BattleScreen: CursorStateHost.register_surface(BOARD_TILE) returned %s instead of REGISTERED at _ready() -- normal move/attack cursor navigation will not work this session."
			% register_result
		)
	# Story 008 — 🔴 SAFETY NET, found by running the full suite after adding
	# the registration above: Table 1 of CursorSurfaceRegistry (ADR-0005
	# 機制三) deliberately has NO automatic cleanup -- "lifecycle managed via
	# explicit unregister calls" (cursor_surface_registry.gd's own class doc
	# comment). Many EXISTING tests across this project instantiate
	# BattleScreen.tscn for reasons unrelated to the cursor system (card deck
	# wiring, hand bar wiring, mouse coords, etc.) and free it via
	# auto_free() with no reason, before this story, to ever call
	# CursorStateHost.unregister_surface(BOARD_TILE) themselves. Without this
	# connection, a freed BattleScreen instance is left dangling in the
	# registry, and CursorStateHost's own always-running
	# CursorNavigationApplier._process() (Autoload, never torn down between
	# tests) calls CursorSurfaceRegistry.get_surface() on it from a LATER,
	# wholly unrelated test -- engine-verified failure, repeatable:
	# "SCRIPT ERROR: Trying to return a previously freed instance" at
	# cursor_surface_registry.gd's get_surface(), observed breaking
	# tests/unit/ui/menu/battle_menu_layout_test.gd's own directional-input
	# tests purely from execution ORDER, zero relation to this story. Safe to
	# call unconditionally on exit regardless of which path (normal vs
	# card-play) currently owns the tag — both register the SAME `self`
	# reference, never a different node, so this either removes this
	# instance's own registration or no-ops as UNREGISTERED_NOT_FOUND if
	# something already released it (e.g. mid-handoff to card-play).
	tree_exited.connect(func() -> void: CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE))
	# Story 008 unit 3b (point 1/4, AC-2) — seeds CursorStateHost's target
	# instead of writing _cursor_cell directly, then reads it back: the
	# registration above already landed on this same node, so set_target()
	# should not reject with SURFACE_NOT_REGISTERED. Calling set_target() here
	# (not _input()/_process()) is safe: this runs during _ready(), before
	# this node's own _process() (priority 100, see _init()) has ever ticked,
	# and the CursorStateHost Autoload's _ready() has already run (Autoloads
	# initialize before the main scene) — none of R5-2's per-frame ordering
	# concerns about _input()/_process() apply to a one-time construction-time
	# seed. _cursor_cell below is now a CACHE of the host's target, refreshed
	# from it, not an independently computed value.
	if not player_ids.is_empty():
		var initial_cell: Vector2i = _state.position_of(player_ids[0])
		var initial_tile_id: int = CursorTypes.encode_tile(initial_cell, BoardCoords.BOARD_COLS)
		var seed_result: CursorState.SetTargetResult = CursorStateHost.set_target(
			CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, initial_tile_id)
		)
		if seed_result != CursorState.SetTargetResult.APPLIED:
			push_error(
				"BattleScreen: CursorStateHost.set_target() returned %s instead of APPLIED while seeding the initial cursor position at _ready()."
				% seed_result
			)
		var seeded_target: CursorTarget = CursorStateHost.get_current_target()
		if seeded_target != null and seeded_target.surface == CursorTypes.SurfaceType.BOARD_TILE:
			_cursor_cell = CursorTypes.decode_tile(seeded_target.id, BoardCoords.BOARD_COLS)
		else:
			_cursor_cell = initial_cell

	# Story U-013 (機制六②) — process_priority (-60) set in its own _init(),
	# before add_child() (R6-12), same convention this file's own
	# CursorStateHost dependency already establishes for
	# CursorNavigationApplier/SelfDrawnReclaimCursor/NativePointerVisibilityArbiter.
	_target_retarget_actor = _TargetRetargetActor.new(self)
	add_child(_target_retarget_actor)

	# Story U-016 — wires the standalone BattleMenu (delivered by U-007~U-010,
	# never previously instantiated into a live battle — EPIC.md's own gap
	# finding: `grep -rn "BattleMenu.tscn" src/` hit only the scene file
	# itself before this story) into this real battle. Both Callables use
	# this project's established "unset means never blocked" idiom (see
	# CardPlaySession._authoritative_write_in_progress_check's own doc
	# comment for the same shape) — here both are always valid, bound
	# straight to BattleController's own real queries, never a screen-local
	# mirror of either.
	# 🔴 A freshly-instantiated BattleMenu defaults to Control.visible == true
	# (BattleMenu.tscn's root Control never sets visible = false, and this
	# project's own battle_menu_gating_test.gd hit the identical gotcha —
	# "it was red until this line was added", fixed there with an explicit
	# close() before the first open()). Without this line, EVERY real battle
	# would start with the menu fully visible over the board from frame one.
	# Deliberately NOT calling BattleMenu.close() here — that method also
	# calls get_tree().paused = false and CursorStateHost.resume_arbitration(),
	# and this menu was never actually opened yet (no matching
	# suspend_arbitration() has ever run for it), so calling its resume half
	# unpaired would be exactly the kind of un-paired call ADR-0005's own
	# suspend/resume discipline exists to catch. A direct visibility write is
	# the minimal, correct fix for what is actually a node-default problem,
	# not a state-machine one.
	_battle_menu.visible = false
	_battle_menu.controller = _controller
	_battle_menu.authoritative_write_in_progress_check = Callable()
	_battle_menu.forced_discard_in_progress_check = Callable(_controller, "has_pending_discard")
	# BattleMenu._on_end_phase_row_pressed() already calls
	# BattleController.end_faction_phase() itself before emitting this signal
	# (see that method's own doc comment: "the ONE place that can correctly
	# pick 'call the SAME driver _end_faction_phase_pressed() already uses'"
	# — this connection IS that pick). _end_faction_phase_pressed()'s own
	# 2026-09-24 guard update tolerates being entered with phase() already
	# ENEMY_ACTING for exactly this caller.
	_battle_menu.end_faction_phase_confirmed.connect(_end_faction_phase_pressed)
	# Story U-016 — proves the rejection path this screen's dispatch relies on
	# (AC-M16: pressing battle_menu during forced discard must NOT silently
	# do nothing) actually reaches this screen. 🔴 Disclosed gap, not silently
	# covered: this connection only RECORDS the rejection (see
	# diagnostic_last_menu_rejection_message() below) — it does not display
	# REJECTION_MESSAGE_FORCED_DISCARD/REJECTION_MESSAGE_AUTHORITATIVE_WRITE
	# anywhere on screen. Building a visible rejection banner is new UI
	# surface this story's four concrete actions do not list; see this
	# story's task report for why that was left as an explicit open item
	# rather than self-expanded into scope.
	_battle_menu.open_rejected.connect(_on_battle_menu_open_rejected)

	# Story 012 (格位資訊面板) — same "apply once, then re-apply on every
	# resize" discipline hud_layout_scaler.gd's own _ready() already
	# establishes for the rest of UILayer; see _apply_tile_info_panel_layout()'s
	# own doc comment for why this screen owns it directly rather than that
	# file.
	_apply_tile_info_panel_layout()
	get_window().size_changed.connect(_apply_tile_info_panel_layout)

	_refresh_view()


func _process(_delta: float) -> void:
	if _load_failed:
		return

	# Story 012 (格位資訊面板) — captured unconditionally, every frame,
	# regardless of phase: see [member _tile_info_cursor_valid]'s own doc
	# comment for why this read must happen here and nowhere else.
	_tile_info_cursor_valid = CursorStateHost.is_current_target_valid()

	if _controller.phase() == BattleController.Phase.ENEMY_ACTING:
		_diagnostic_enemy_acting_process_frame_count += 1
		# Story 011 (U-T6) -- M1 audit
		# (docs/reviews/tactical-combat-m1-current-state-audit-2026-09-29.md):
		# "BattleState 本身不會被敵方回合中的輸入改動,但游標仍會照常隨滑鼠/
		# 方向鍵移動". _update_cursor_visual() below is the ONE place in this
		# file that calls _board_view.set_cursor() (see that method's own
		# body) -- not calling it here, every _process() frame phase() reads
		# ENEMY_ACTING (not just once when the phase is entered), is what
		# makes "cursor position does not change" hold for the whole stepped
		# enemy playback rather than only its first frame.
		#
		# This is also the ONLY fix in this file that covers the
		# KEYBOARD/GAMEPAD case: _input()'s own ENEMY_ACTING guard below stops
		# this screen's OWN dispatch, but it cannot stop CursorStateHost's
		# target from moving, because CursorNavigationApplier is a separate
		# Autoload-owned node that receives the same raw InputEvent
		# independently (see _handle_directional()'s own doc comment --
		# "two separate nodes receiving the same raw InputEvent"). Skipping
		# the call below freezes the DRAWN cursor regardless of what
		# CursorStateHost's internal target does underneath, which is the
		# only thing this screen is positioned to guarantee without editing
		# that Autoload.
	else:
		_update_cursor_visual()

	# Story U-013 (ADR-0005 機制六⑥, Implementation Note #1 quoted verbatim
	# below) — this screen's own [member Node.process_priority] is 100 (see
	# [method _init]), so this is the ONLY place in this file allowed to read
	# CursorStateHost.get_current_target() / is_current_target_valid() /
	# get_device_authority(). The battle_confirm KEY PRESS itself is captured
	# in _input() (see the _card_selecting_target branch there) only as a
	# pending flag, never acted on there:
	#
	#   "打牌確認若要讀「游標系統裁定後的狀態」(當前選了哪張卡、哪個目標、哪個
	#   裝置持權威),該讀取不得放在按鍵處理(_input / _unhandled_input)裡,
	#   必須放在 _process(priority=100)。"
	#   (story-u013-target-selection-and-highlight.md, Implementation Note #1)
	if _pending_target_confirm_press:
		_pending_target_confirm_press = false
		_apply_target_confirm_from_cursor_state()

	# Story U-014 (AC-U11) — same deferred-to-_process discipline as the block
	# above, for the exact same reason: collapse every battle_confirm press
	# dispatched within this one frame into a single BattleController.confirm()
	# call. See _card_confirm_pending_press's own doc comment.
	if _card_confirm_pending_press:
		_card_confirm_pending_press = false
		_apply_pending_card_confirm()

	# Story 013 — same deferred-to-_process discipline as the two blocks
	# above, for the exact same reason (AC「同幀鍵盤+手把各送一次確認的去重
	# 保護」): collapse every battle_confirm press dispatched within this one
	# frame into a single BattleController.click_tile() call. See
	# _attack_confirm_pending_press's own doc comment.
	if _attack_confirm_pending_press:
		_attack_confirm_pending_press = false
		_apply_pending_attack_confirm()


func _input(event: InputEvent) -> void:
	if _load_failed:
		return
	if _controller.phase() == BattleController.Phase.FINISHED:
		return

	# Story 011 (U-T6) -- ENEMY_ACTING freezes mouse tracking too, not only the
	# keyboard/gamepad dispatch guarded below: _last_mouse_window_pos is what
	# _apply_mouse_target_if_authoritative() (_TargetRetargetActor, every
	# frame) and _update_cursor_visual()'s own MOUSE branch both read. Letting
	# it keep advancing during the enemy's turn would not move the drawn
	# cursor (that is frozen separately by _process()'s own ENEMY_ACTING
	# branch, see its doc comment), but it WOULD make the cursor jump the
	# instant PLAYER_INPUT resumes, to wherever the mouse happened to end up
	# mid-playback -- freezing the raw position here keeps both consistent.
	if event is InputEventMouseMotion:
		if _controller.phase() != BattleController.Phase.ENEMY_ACTING:
			_last_mouse_window_pos = (event as InputEventMouseMotion).position
		return

	if event is InputEventMouseButton:
		# Story 011 (U-T6) -- a click during the enemy's turn must not reach
		# _handle_mouse_button() at all. BattleController.click_tile()'s own
		# deeper phase guard already rejects the GAMEPLAY effect (M1 audit),
		# but _handle_mouse_button() ALSO writes _last_mouse_window_pos as its
		# first statement -- same freeze reasoning as the motion branch above.
		if _controller.phase() != BattleController.Phase.ENEMY_ACTING:
			_handle_mouse_button(event as InputEventMouseButton)
		return

	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Story 013（T2' 攻擊確認面板)— highest priority among every
		# keyboard/gamepad branch below, including battle_menu: the story's AC
		# requires "面板開啟期間,游標移動/開手牌/開選單皆須被拒絕". This
		# screen's allowed-file list for this story does not include
		# battle_menu.gd, so there is no in_progress_check Callable this story
		# can wire for an OBSERVABLE rejection message the way Story U-016 did
		# for battle_menu during forced discard — instead this uses the same
		# "swallow everything" shape _controller.phase() == ENEMY_ACTING
		# already uses below. The panel's own continued visibility is the
		# observable trace of the rejection (same "persistent trace beats a
		# one-off message" judgment this file already applies in
		# _handle_forced_discard_input()'s own doc comment for
		# battle_cancel during S4).
		if _attack_confirming:
			if event.is_action_pressed(&"battle_confirm"):
				# Captured as a pending flag ONLY — see
				# _apply_pending_attack_confirm()'s own doc comment for where
				# this is actually read (never here).
				_attack_confirm_pending_press = true
				return
			if event.is_action_pressed(&"battle_cancel"):
				_handle_attack_confirm_cancel_transition()
				return
			return

		# Story U-016 — battle_menu is checked BEFORE even the S4 (forced
		# discard) branch below, deliberately: AC-M16 requires that pressing
		# battle_menu DURING forced discard still produce an OBSERVABLE
		# rejection ("請先完成棄牌", distinguishable from AC-M8's authoritative-
		# write rejection) — not silence. That rejection message is
		# BattleMenu.open()'s OWN responsibility (it checks
		# forced_discard_in_progress_check/authoritative_write_in_progress_check
		# internally and emits open_rejected with the right message — wired in
		# _ready()), so this screen must let the press REACH open() in every
		# state, rather than the S4 branch below silently swallowing it the
		# way it already silently swallows battle_open_hand during S4 (that
		# one IS meant to be a silent no-op — Z2 is already forced open, there
		# is nothing to reject; battle_menu is different, because opening the
		# menu is a real, distinct action S4 must explicitly refuse, not just
		# ignore).
		if event.is_action_pressed(&"battle_menu"):
			_handle_battle_menu_pressed()
			return

		# Story 011 (U-T6) -- M1 audit
		# (docs/reviews/tactical-combat-m1-current-state-audit-2026-09-29.md):
		# "_input(event) 頂部只擋 _load_failed 與 phase()==FINISHED,沒有對
		# ENEMY_ACTING 的頂層檢查". Deliberately placed AFTER the battle_menu
		# check immediately above, not before it: Story U-016 already
		# established (see that check's own doc comment) that opening the
		# menu is a real, distinct action that must reach BattleMenu.open()
		# and be explicitly accepted or rejected BY IT in every phase -- and
		# _end_faction_phase_pressed() already tolerates being re-entered
		# while phase() is ALREADY ENEMY_ACTING (its own 2026-09-24 comment),
		# so battle_menu reaching open() mid-enemy-playback is existing,
		# tested behavior this guard must not break.
		#
		# Everything below this line, by contrast -- forced discard,
		# battle_open_hand, the board move/attack path, hand/target
		# navigation, card confirm/cancel -- is board or card interaction
		# with no equivalent "let it through so it can reject itself" design.
		# Returning here before any of it runs is what keeps the visual
		# freeze _process()'s own ENEMY_ACTING branch enforces (see that
		# method) from being undone by a stray write the same frame a
		# keyboard/gamepad event arrives; it does not change gameplay
		# outcomes either way, since BattleController.click_tile()'s own
		# deeper phase guard already rejected them (M1 audit), but it closes
		# the "cursor moves anyway" visible gap that guard does not cover.
		if _controller.phase() == BattleController.Phase.ENEMY_ACTING:
			return

		# Story U-015 (強制棄牌 S4) — takes priority over EVERYTHING else in
		# this dispatch, including battle_open_hand (Z2 is already forced
		# open by _refresh_view()'s own HandBar.render() call — this key does
		# nothing) and the normal board move/attack path below (blocked
		# entirely, matching card-play's own AC-14 precedent: "永遠可以選擇
		# 不打" vs "強制棄牌是阻塞的" — the player can refuse to PLAY a card,
		# never to DISCARD one). Polls BattleController.has_pending_discard()
		# directly rather than a screen-local mirror — per this story's own
		# explicit instruction not to build a second flag alongside the
		# existing CardDeck._pending_discard -> BattleController chain.
		if _controller.has_pending_discard():
			_handle_forced_discard_input(event)
			return

		# Story U-013 — `battle_open_hand` (S0<->S1) is checked before anything
		# else regardless of card-play state, mirroring the Interaction Map's
		# own framing of it as a toggle rather than a step-scoped action.
		if event.is_action_pressed(&"battle_open_hand"):
			_handle_open_hand_pressed()
			return

		# AC-14 (`card_play_session.gd`'s own class doc comment, point 2: "打牌
		# 介面開啟中不得發起攻擊") — the pre-existing board move/attack path
		# below is reachable ONLY while no card-play session is open. This is
		# the first caller to actually close that documented gap; before this
		# story nothing in src/ gated BattleController.click_tile() on
		# is_card_play_in_progress() at all.
		if not _controller.is_card_play_in_progress():
			_handle_directional(event)
			if event.is_action_pressed(&"battle_confirm"):
				_confirm_at_cursor()
				return
			# Story 011 (U-T8, M1 audit 2026-09-29) — "主動結束單一單位" had no
			# player-triggerable path at all (distinct from `battle_end_phase`'s
			# own dead-action history immediately below: that one ends the WHOLE
			# faction's turn and was deliberately moved to a menu row per
			# `design/ux/battle-menu.md`'s own stated reason, "免得太容易被玩家
			# 誤觸,白白浪費一回合" — ending a SINGLE unit's turn is lower-stakes
			# and, per `tactical-combat-screen.md` 7.1's Interaction Map, grouped
			# with the other direct-key per-unit actions (move/confirm/cancel/
			# jump-target), not with the menu-gated whole-phase action. Reusing
			# the already-dead, zero-bound `battle_end_phase` action for this
			# different meaning was deliberately NOT done — that action's fate
			# is `battle-menu.md`'s own BM-1, owned by 戰棋系統(#4)/
			# `lead-programmer`, not decided by this story). Gated inside this
			# `is_card_play_in_progress()`-guarded block for the same reason
			# `battle_confirm`'s board-attack path is: AC-14 already forbids
			# initiating a board action while a card-play interaction is open.
			# [method BattleController.end_unit_turn] is called with whatever
			# [method BattleController.selected_unit] returns right now
			# (`-1` when nothing is selected) rather than this screen caching a
			# separate `_selected_unit_id` field — [TurnOrder]'s own
			# `_is_actionable()` already treats `-1` as "not actionable" and
			# rejects cleanly (see [method _handle_end_unit_turn_result]'s doc
			# comment), so there is no separate "nothing selected" guard to
			# duplicate here.
			if event.is_action_pressed(&"battle_end_unit_turn"):
				_handle_end_unit_turn_result(_controller.end_unit_turn(_controller.selected_unit()))
				return
			# Story U-016 — the battle_end_phase keypress dispatch that used to
			# live here is removed (project.godot's battle_end_phase action
			# keeps existing with zero bindings, per Implementation Note 1 —
			# see [method _handle_open_hand_pressed]'s neighboring [method
			# _handle_battle_menu_pressed] doc comment for the new path:
			# ending the turn is now exclusively a menu row, reached via
			# battle_menu -> BattleMenu.open() -> native row navigation/press
			# -> [signal BattleMenu.end_faction_phase_confirmed] ->
			# [method _end_faction_phase_pressed] (connected in [method _ready]).
			return

		if _card_selecting_from_hand:
			_handle_hand_navigation(event)
			if event.is_action_pressed(&"battle_confirm"):
				_confirm_selected_card()
				return
			if event.is_action_pressed(&"battle_cancel"):
				if _controller.cancel():
					_card_selecting_from_hand = false
					_refresh_view()
				return
			return

		# Story U-013 (ADR-0005 機制六) — S2/S2p/S2q target-selection input.
		# Directional ui_up/ui_down/ui_left/ui_right are DELIBERATELY not
		# matched anywhere in this branch: those are NAVIGATION-class ui_*
		# actions (CursorTypes.NAVIGATION_ACTIONS), so CursorStateHost's own
		# _input()/機制六①③ pipeline already buffers and applies them via
		# this screen's own cursor_navigate() (registered in
		# _confirm_selected_card() below) — battle_screen.gd must not also
		# consume them here, or the event would never reach CursorStateHost's
		# _input() at all (both are separate nodes receiving the same raw
		# InputEvent; nothing here calls accept_event()/set_input_as_handled(),
		# so simply not matching the event is enough to let it propagate).
		if _card_selecting_target:
			if event.is_action_pressed(&"battle_next_target"):
				_target_jump_requested = true
				_target_jump_forward = true
				return
			if event.is_action_pressed(&"battle_prev_target"):
				_target_jump_requested = true
				_target_jump_forward = false
				return
			if event.is_action_pressed(&"battle_confirm"):
				# Implementation Note #1 — captured as a pending flag ONLY;
				# see _process()'s own comment for where this is actually
				# read (never here).
				_pending_target_confirm_press = true
				return
			if event.is_action_pressed(&"battle_cancel"):
				_controller.cancel()
				_handle_target_selection_cancel_transition()
				_refresh_view()
				return
			return

		# Story U-014 — S3 (CONFIRMING). Confirm and cancel both dispatch
		# here; AC-U5 (全手把路徑): both battle_confirm/battle_cancel already
		# carry keyboard+gamepad bindings, and neither this branch nor
		# _handle_mouse_button() wires any mouse interaction for S3, so there
		# is no mouse-only path to close off.
		if _card_confirming:
			if event.is_action_pressed(&"battle_confirm"):
				# AC-U11 — captured as a pending flag ONLY; see
				# _apply_pending_card_confirm()'s own doc comment for why
				# this must not call _controller.confirm() synchronously here.
				_card_confirm_pending_press = true
				return
			if event.is_action_pressed(&"battle_cancel"):
				_controller.cancel()
				_handle_card_confirm_cancel_transition()
				_refresh_view()
				return
			return


## Pure, node-independent helper: clamps [param cell] moved by [param delta]
## to stay inside the board. Extracted as a [code]static[/code] function per
## the task brief ("若能把任何一段邏輯抽成不依賴節點的純函式,請抽出來並補測試")
## so directional-cursor clamping is testable headless without a live window
## or [InputEvent] — see [code]tests/unit/ui/battle_screen_cursor_test.gd[/code].
static func clamp_cursor_move(cell: Vector2i, delta: Vector2i) -> Vector2i:
	var moved: Vector2i = cell + delta
	return Vector2i(
		clampi(moved.x, 0, BoardCoords.BOARD_COLS - 1),
		clampi(moved.y, 0, BoardCoords.BOARD_ROWS - 1)
	)


## Story U-013, AC-U3 (`design/ux/skill-card-play.md` Interaction Map: 「跳到
## 上/下一個合法目標」)— orders [param unit_ids] by board position, ascending
## row ([code]y[/code]) first, then ascending column ([code]x[/code]) within a
## row ("先列後行"). Pure and node-independent: [param positions] is an
## already-resolved lookup (built by the caller from whatever source it has —
## a live [BattleState] in production, a hand-built [Dictionary] in a test),
## never a live [BattleState] reference itself, so this is testable without a
## scene or node.
##
## 🔴 [b]Determinism comes from the sort key, never from [param unit_ids]'s
## own incoming order[/b] — this project has a registered failure pattern for
## mistaking a container's traversal/hash order for a stable enumeration
## order ([code]relying_on_container_iteration_order[/code],
## [code]docs/registry/architecture.yaml[/code]). Two calls with the same ids
## in a DIFFERENT starting order produce the IDENTICAL result, because every
## id is re-keyed by its own board position before any comparison happens —
## see [code]tests/integration/ui/card_target_selection_test.gd[/code]'s
## [code]test_jump_order_identical_across_repeated_runs[/code] for the
## executed proof, not merely this comment's claim.
##
## [b]The sort key is (y, x, id) — [param unit_ids] itself as the tertiary
## tiebreaker — not just (y, x)[/b]. Two units can never legally share a board
## cell (occupancy is an enforced invariant elsewhere in this codebase), so a
## (y, x) collision cannot occur for a real [method
## BattleController.legal_targets] result today; adding [code]id[/code] as a
## third key costs nothing for that case (never consulted, since y/x alone
## already decide it) and removes the one input shape — a caller passing two
## entries at an identical position, e.g. malformed test data — where a
## (y, x)-only comparator would have to declare them "equal" and hand the
## outcome to [method Array.sort_custom]'s own internal tie-breaking, which
## this project does not treat as a documented, reasoned-about contract.
static func sort_targets_by_position(
	unit_ids: Array[int], positions: Dictionary[int, Vector2i]
) -> Array[int]:
	var sorted_ids: Array[int] = unit_ids.duplicate()
	sorted_ids.sort_custom(
		func(a: int, b: int) -> bool:
			var pos_a: Vector2i = positions[a]
			var pos_b: Vector2i = positions[b]
			if pos_a.y != pos_b.y:
				return pos_a.y < pos_b.y
			if pos_a.x != pos_b.x:
				return pos_a.x < pos_b.x
			return a < b
	)
	return sorted_ids


## Story U-013, AC-U3 — steps one entry forward ([param forward] true,
## [code]Tab[/code]/RB) or backward ([param forward] false,
## [code]Shift+Tab[/code]/LB) through [param sorted_ids] (already ordered by
## [method sort_targets_by_position]), wrapping around at either end so the
## 6th forward jump from a 5-target set returns to the 1st. Returns
## [code]-1[/code] if [param sorted_ids] is empty (nothing to jump to).
##
## [param current_id] not being found in [param sorted_ids] (e.g. the cursor
## has not landed on any target yet) is treated as "start from the first
## entry going forward, or the last entry going backward" rather than an
## error — this is a legitimate first-press case, not a caller mistake.
static func next_target_id(current_id: int, sorted_ids: Array[int], forward: bool) -> int:
	if sorted_ids.is_empty():
		return -1
	var index: int = sorted_ids.find(current_id)
	if index == -1:
		return sorted_ids[0] if forward else sorted_ids[sorted_ids.size() - 1]
	var step: int = 1 if forward else -1
	var next_index: int = posmod(index + step, sorted_ids.size())
	return sorted_ids[next_index]


## Returns every cell of [param source] that does not appear in
## [param excluded], preserving [param source]'s existing order. Static and
## public purely so it is unit-testable without standing up a whole screen.
##
## Used by [method _refresh_view] to keep the three highlight layers
## mutually exclusive — see the comment there for why the layers are made
## disjoint rather than stacked. This is a display-composition helper, not a
## rules query: it never asks what is legal, it only partitions arrays that
## [BattleController] already decided the contents of.
##
## [param excluded] is loaded into a [Dictionary] used as a set, so this is
## O(n+m) rather than O(n*m); [param source]'s order is taken from the
## caller and never re-sorted here, which is what makes the result stay in
## [BattleController]'s documented ascending (y, x) order.
static func cells_excluding(
	source: Array[Vector2i], excluded: Array[Vector2i]
) -> Array[Vector2i]:
	var excluded_set: Dictionary = {}
	for cell: Vector2i in excluded:
		excluded_set[cell] = true

	var result: Array[Vector2i] = []
	for cell: Vector2i in source:
		if not excluded_set.has(cell):
			result.append(cell)
	return result


## Story U-013 — partitions every unit's position (both factions) into the
## two arrays [method BoardView.set_card_target_highlights] expects: every id
## in [param legal_ids] becomes "legal" (outline only); every OTHER id present
## in [param unit_positions] becomes "illegal" (outline+X); an empty tile
## (no entry in [param unit_positions] at all) is the third, undrawn state,
## simply never emitted — matches that method's own "absence of any mark IS
## that state" convention. Presentation composition only, same contract as
## [method cells_excluding] immediately above: [param legal_ids] is decided
## by [method BattleController.legal_targets], never re-derived here.
static func card_target_highlight_cells(
	legal_ids: Array[int], unit_positions: Dictionary[int, Vector2i]
) -> Dictionary:
	var legal_set: Dictionary = {}
	for id: int in legal_ids:
		legal_set[id] = true

	var legal_cells: Array[Vector2i] = []
	var illegal_cells: Array[Vector2i] = []
	for id: int in unit_positions:
		if legal_set.has(id):
			legal_cells.append(unit_positions[id])
		else:
			illegal_cells.append(unit_positions[id])
	return {"legal": legal_cells, "illegal": illegal_cells}


## Maps an [enum AffinityLineStatus.State] to the display-only [enum
## BoardView.LineTone] vocabulary [method BoardView.set_affinity_lines]
## expects. [BoardView] deliberately does not know about
## [AffinityLineStatus] (see that class's own doc comment on why it keeps its
## own enum), so this screen — the one class allowed to know both sides — is
## where the mapping lives. A [code]match[/code] rather than an index cast:
## the two enums are not guaranteed to share ordinal order, and a cast would
## silently produce the wrong tone (or a range error) the moment either enum
## gains or reorders a value.
static func line_tone_for(state: AffinityLineStatus.State) -> BoardView.LineTone:
	match state:
		AffinityLineStatus.State.POSITIVE:
			return BoardView.LineTone.POSITIVE
		AffinityLineStatus.State.NEGATIVE:
			return BoardView.LineTone.NEGATIVE
		AffinityLineStatus.State.NEUTRAL:
			return BoardView.LineTone.MUTED
		_:
			return BoardView.LineTone.MUTED


## Story U-011 — maps [param category] to the display-only
## [enum HandBar.SlotKind] Z1 needs. Mirrors [method line_tone_for]'s existing
## mapping-function placement convention immediately above: this class is the
## one allowed to know both the gameplay enum ([enum Card.Category]) and the
## UI enum ([enum HandBar.SlotKind]); [HandBar] itself never references
## [Card] (see that file's own class doc comment).
##
## 🔴 [b]2026-09-17 coordinator review finding, addressed here[/b]: both of
## [enum Card.Category]'s CURRENT values are matched explicitly rather than
## letting a bare [code]_:[/code] wildcard cover the second one — [Card]'s own
## class doc comment explicitly anticipates a THIRD category (乙類) being
## added later ("Adding it later means adding a third [enum Category] value
## and its own fields"). The wildcard branch is unreachable today ([enum
## Card.Category] only has two members, so this is a forward-looking fix, not
## a fix to an active bug) but exists so that day does not silently draw an
## unrecognized category as 甲類 with zero signal — the same failure SHAPE
## (an unexpected input silently producing a plausible-looking output) as the
## `.claude/docs/coding-standards.md` 2026-09-15 `assert()` ruling, though not
## the same mechanism: unlike that ruling's enum (where ordinal 0 doubles as
## a real rejection code), [enum HandBar.SlotKind] has no "rejection" value to
## accidentally masquerade as — a display fallback to 甲類's shape is a
## reasonable degraded choice for a UI component that must never crash or
## block the game thread. What must not happen is for that fallback to stay
## SILENT once a third category exists, so [method push_error] fires before
## returning it — loud in logs, not loud enough to block rendering.
static func hand_bar_slot_kind_for(category: Card.Category) -> HandBar.SlotKind:
	match category:
		Card.Category.TEMPORARY_STAT_MODIFIER:
			return HandBar.SlotKind.TEMPORARY_MODIFIER
		Card.Category.PERMANENT_AFFINITY_WRITE:
			return HandBar.SlotKind.PERMANENT_WRITE
		_:
			push_error(
				"BattleScreen.hand_bar_slot_kind_for: unmapped Card.Category %s -- Z1 falls back to 甲類's shape, but this is now logged rather than silent"
				% category
			)
			return HandBar.SlotKind.TEMPORARY_MODIFIER


## Story U-011 — maps an entire hand (as returned by [method CardDeck.hand])
## to the [code]Array[HandBar.SlotKind][/code] [method HandBar.render]
## expects, preserving [param hand]'s order. [method CardDeck.hand]'s own doc
## comment guarantees the array it returns is already a fresh copy, never a
## live reference, so no further defensive copy is needed here.
static func hand_bar_slot_kinds(hand: Array[Card]) -> Array[HandBar.SlotKind]:
	var result: Array[HandBar.SlotKind] = []
	for card: Card in hand:
		result.append(hand_bar_slot_kind_for(card.category))
	return result


## Story U-011 — maps [param phase] to the display-only
## [enum HandBar.Availability] Z1's S5 channel needs.
## [constant BattleController.Phase.FINISHED] folding into
## [constant HandBar.Availability.LOCKED] — not just
## [constant BattleController.Phase.ENEMY_ACTING] — is a 2026-09-17
## [b]coordinator[/b] ruling (not a manager ruling — this project
## distinguishes the two explicitly), grounded in
## [code]design/ux/skill-card-play.md[/code]'s own S5 row wording: "不可用 ——
## 現在不是你的回合/結算中". "結算中" already covers more than
## [constant BattleController.Phase.ENEMY_ACTING] alone in the spec's own
## text, so folding FINISHED in here is not a widening of the literal S5
## definition — a FINISHED battle displaying its hand as usable would be a
## plain error regardless of how S5 is scoped.
static func availability_for(phase: BattleController.Phase) -> HandBar.Availability:
	if phase == BattleController.Phase.PLAYER_INPUT:
		return HandBar.Availability.NORMAL
	return HandBar.Availability.LOCKED


## Converts a list of [AffinityLineStatus] into the
## [code]{"from": Vector2i, "to": Vector2i, "tone": int}[/code] dictionaries
## [method BoardView.set_affinity_lines] expects, reading both endpoints from
## [param positions] — deliberately NOT from any live [BattleState]. This is
## what lets a caller pass a hypothetical layout (e.g.
## [method AffinityPhiProvider.positions_with]) and get preview lines back
## that reflect a move that has not actually happened yet (see
## [method _refresh_view]'s Mode A). A status whose [member
## AffinityLineStatus.unit_id] or [member AffinityLineStatus.partner_id] is
## absent from [param positions] is silently skipped — matches
## [AffinityRules]'s own "absence means dead or off the board" convention,
## and a caller building [param positions] from a live snapshot can never
## produce such a status in the first place, so this only guards a
## caller-constructed [param positions] that omits an entry.
static func affinity_line_dicts(
	statuses: Array[AffinityLineStatus], positions: Dictionary[int, Vector2i]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for status: AffinityLineStatus in statuses:
		if not positions.has(status.unit_id) or not positions.has(status.partner_id):
			continue
		result.append({
			"from": positions[status.unit_id],
			"to": positions[status.partner_id],
			"tone": line_tone_for(status.state),
		})
	return result


## Projected HP after taking [param damage], floored at 0 — the same floor
## [method CombatRules.damage] itself already applies to the damage value, so
## this can never disagree with the number the settlement path will actually
## produce.
static func projected_hp(current_hp: int, damage: int) -> int:
	return maxi(0, current_hp - damage)


## Formats [constant TEXT_AFFINITY_PREVIEW_FORMAT] for Mode A of
## [method _refresh_view] — "if I move here, my bonus changes from X to Y".
static func format_affinity_preview(current_bonus: int, preview_bonus: int) -> String:
	return Loc.localize(TEXT_AFFINITY_PREVIEW_FORMAT) % [current_bonus, preview_bonus]


## Formats [constant TEXT_AFFINITY_CURRENT_FORMAT] for Mode B of
## [method _refresh_view] — cursor resting on a linked unit, no move in
## progress.
static func format_affinity_current(bonus: int) -> String:
	return Loc.localize(TEXT_AFFINITY_CURRENT_FORMAT) % bonus


## Formats [constant TEXT_DAMAGE_PREVIEW_FORMAT] for Mode C of
## [method _refresh_view] — cursor on an attackable enemy.
static func format_damage_preview(damage: int, target_hp: int, target_hp_after: int) -> String:
	return Loc.localize(TEXT_DAMAGE_PREVIEW_FORMAT) % [damage, target_hp, target_hp_after]


## Story 012 (格位資訊面板) — terrain-character display name. Falls back to
## [constant TEXT_TILE_INFO_TERRAIN_UNKNOWN] for any character not in
## [constant Board.TERRAIN_TABLE] — [Board] itself already [method push_error]s
## for an unregistered character ([method Board.get_terrain] /
## [method Board.get_move_cost]'s own doc comments); this function still has
## to produce SOME localized text rather than crash the panel.
static func terrain_display_name(terrain_char: String) -> String:
	match terrain_char:
		Board.TERRAIN_OPEN:
			return Loc.localize(TEXT_TILE_INFO_TERRAIN_OPEN)
		Board.TERRAIN_BRUSH:
			return Loc.localize(TEXT_TILE_INFO_TERRAIN_BRUSH)
		Board.TERRAIN_FALLEN_LOG:
			return Loc.localize(TEXT_TILE_INFO_TERRAIN_FALLEN_LOG)
		_:
			return Loc.localize(TEXT_TILE_INFO_TERRAIN_UNKNOWN)


## Story 012 — maps [enum TurnOrder.ActionState] to its localized display
## label (story-004's four states plus the defensive [constant
## TurnOrder.ActionState.NOT_FOUND] fifth value — see that enum's own doc
## comment). [constant TurnOrder.ActionState.NOT_FOUND] should never actually
## reach this function for an occupant resolved via [method BattleState.unit_at]
## (same forward-looking-wildcard discipline as [method hand_bar_slot_kind_for]
## above), but is mapped explicitly rather than falling through silently.
static func action_state_display_name(state: TurnOrder.ActionState) -> String:
	match state:
		TurnOrder.ActionState.NONE_USED:
			return Loc.localize(TEXT_TILE_INFO_STATE_NONE_USED)
		TurnOrder.ActionState.ATTACK_ONLY:
			return Loc.localize(TEXT_TILE_INFO_STATE_ATTACK_ONLY)
		TurnOrder.ActionState.MOVE_ONLY:
			return Loc.localize(TEXT_TILE_INFO_STATE_MOVE_ONLY)
		TurnOrder.ActionState.DONE:
			return Loc.localize(TEXT_TILE_INFO_STATE_DONE)
		_:
			return Loc.localize(TEXT_TILE_INFO_STATE_NOT_FOUND)


## [constant Board.MOVE_COST_UNKNOWN_TERRAIN] (-1) is an explicit-failure
## sentinel, never a legitimate cost (coordinator dispatch, 2026-10-15) — this
## line must never print "-1" to the player as if it were a real cost.
static func format_tile_info_cost_line(cost: int) -> String:
	if cost == Board.MOVE_COST_UNKNOWN_TERRAIN:
		return Loc.localize(TEXT_TILE_INFO_COST_UNKNOWN)
	return Loc.localize(TEXT_TILE_INFO_COST_LINE_FORMAT) % cost


static func format_tile_info_terrain_line(terrain_char: String) -> String:
	return Loc.localize(TEXT_TILE_INFO_TERRAIN_LINE_FORMAT) % terrain_display_name(terrain_char)


## Visual/Audio §1.4 orthogonality — this is its own line, never merged with
## [method format_tile_info_cost_line] into one "special terrain" field. See
## [method Board.blocks_sight]'s own doc comment: sight-blocking and
## passability/cost are two independent terrain properties recorded in two
## independent tables, and this panel's layout mirrors that independence.
static func format_tile_info_concealment_line(blocks_sight: bool) -> String:
	if blocks_sight:
		return Loc.localize(TEXT_TILE_INFO_CONCEALMENT_YES)
	return Loc.localize(TEXT_TILE_INFO_CONCEALMENT_NO)


static func format_tile_info_faction_line(faction: Unit.Faction) -> String:
	var name: String = (
		Loc.localize(TEXT_TILE_INFO_FACTION_PLAYER) if faction == Unit.Faction.PLAYER
		else Loc.localize(TEXT_TILE_INFO_FACTION_ENEMY)
	)
	return Loc.localize(TEXT_TILE_INFO_FACTION_LINE_FORMAT) % name


static func format_tile_info_hp_line(hp: int, hp_max: int) -> String:
	return Loc.localize(TEXT_TILE_INFO_HP_LINE_FORMAT) % [hp, hp_max]


static func format_tile_info_state_line(state: TurnOrder.ActionState) -> String:
	return Loc.localize(TEXT_TILE_INFO_STATE_LINE_FORMAT) % action_state_display_name(state)


static func format_tile_info_weapon_range_line(min_range: int, max_range: int) -> String:
	return Loc.localize(TEXT_TILE_INFO_WEAPON_RANGE_LINE_FORMAT) % [min_range, max_range]


static func format_tile_info_mp_line(mp: int) -> String:
	return Loc.localize(TEXT_TILE_INFO_MP_LINE_FORMAT) % mp


## Story 012 — composes the full, multi-line tile-info panel text from
## already-resolved plain data. Deliberately takes no [BattleState]/[Board]/
## node reference — every value is extracted by the caller first (see
## [method _update_tile_info_panel]) — so this function is directly
## unit-testable headless, mirroring [method format_damage_preview] et al.'s
## existing "pure formatter" convention in this file.
##
## [param has_occupant] gates whether the five occupant-only lines (faction/
## HP/four-state/weapon-range/MP) are appended at all: GDD UI Requirements §1
## only requires those fields "若有" (if an occupant exists); an empty tile
## shows [constant TEXT_TILE_INFO_OCCUPANT_NONE] in their place instead of
## five lines of placeholder values.
static func build_tile_info_text(
	terrain_char: String,
	cost: int,
	blocks_sight: bool,
	has_occupant: bool,
	occupant_faction: Unit.Faction,
	occupant_hp: int,
	occupant_hp_max: int,
	occupant_state: TurnOrder.ActionState,
	occupant_min_range: int,
	occupant_max_range: int,
	occupant_mp: int
) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(format_tile_info_terrain_line(terrain_char))
	lines.append(format_tile_info_cost_line(cost))
	lines.append(format_tile_info_concealment_line(blocks_sight))
	if has_occupant:
		lines.append(format_tile_info_faction_line(occupant_faction))
		lines.append(format_tile_info_hp_line(occupant_hp, occupant_hp_max))
		lines.append(format_tile_info_state_line(occupant_state))
		lines.append(format_tile_info_weapon_range_line(occupant_min_range, occupant_max_range))
		lines.append(format_tile_info_mp_line(occupant_mp))
	else:
		lines.append(Loc.localize(TEXT_TILE_INFO_OCCUPANT_NONE))
	return "\n".join(lines)


## Classifies whether [param path] can even be opened, independent of its
## content: [constant LoadFailure.MISSING] if the file does not exist,
## [constant LoadFailure.UNREADABLE] if it exists but [method FileAccess.open]
## still fails (permissions, locked file, etc.), or [constant LoadFailure.NONE]
## if the file opened cleanly. Uses [method FileAccess.file_exists] rather
## than inferring absence from an empty read — [method
## FileAccess.get_file_as_string] silently returns [code]""[/code] for a
## missing file, which is indistinguishable from a genuinely empty one unless
## existence is checked separately first. Pure and node-independent so it can
## be unit tested without starting this scene — see
## [code]tests/unit/ui/battle_screen_load_guard_test.gd[/code].
static func classify_file_access(path: String) -> LoadFailure:
	if not FileAccess.file_exists(path):
		return LoadFailure.MISSING
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return LoadFailure.UNREADABLE
	file.close()
	return LoadFailure.NONE


## Classifies an already-read file's content: [constant
## LoadFailure.EMPTY_CONTENT] if [param text] is empty once [method
## String.strip_edges] removes surrounding whitespace, [constant
## LoadFailure.PARSED_EMPTY] if the text was non-empty but its parser
## ([method Board.from_ascii] / [method Unit.roster_from_text], counted by
## the caller into [param parsed_count]) still produced zero usable entries
## (e.g. a roster file containing only comment/blank lines), or [constant
## LoadFailure.NONE] otherwise.
static func classify_content(text: String, parsed_count: int) -> LoadFailure:
	if text.strip_edges().is_empty():
		return LoadFailure.EMPTY_CONTENT
	if parsed_count == 0:
		return LoadFailure.PARSED_EMPTY
	return LoadFailure.NONE


## Classifies [method AffinityLink.links_from_text]'s [code]Variant[/code]
## result: [constant LoadFailure.PARSE_ERROR] if [param parsed] is
## [code]null[/code] (a row failed to parse), [constant LoadFailure.NONE]
## otherwise — including when [param parsed] is a legally empty array,
## which is NOT a failure (see [constant AFFINITY_PATH]'s doc comment and
## [method links_from_text]'s own doc comment on why an empty result is not
## the same thing as a failed one). Deliberately separate from
## [method classify_content], which the affinity path also calls but only to
## pick a diagnostic label for the zero-links [method push_warning] in
## [method _ready] — that call's result is never allowed to reach
## [member _fail_load], whereas this function's result is what [method _ready]
## actually assigns into [code]affinity_failure[/code]. Pure and
## node-independent, mirroring [method classify_file_access] /
## [method classify_content], so the affinity table's null/array distinction
## is unit-testable without instantiating [code]BattleScreen.tscn[/code] — see
## [code]tests/unit/ui/battle_screen_load_guard_test.gd[/code].
static func classify_affinity_parse(parsed: Variant) -> LoadFailure:
	if parsed == null:
		return LoadFailure.PARSE_ERROR
	return LoadFailure.NONE


## Classifies [method Card.cards_from_text]'s [code]Variant[/code] result:
## [constant LoadFailure.PARSE_ERROR] if [param parsed] is [code]null[/code]
## (a row failed to parse — that method's own 2026-09-16 manager ruling for
## THIS table, transcribed in its doc comment: a partially-valid card table
## must abort loudly, naming the line, not be used as if fully valid),
## [constant LoadFailure.NONE] otherwise — including when [param parsed] is a
## legally empty array, which per Story U-003's Implementation Notes #2 is
## NOT a failure ("卡池張數少於開局手牌數" is an existing, documented
## [CardDeck] edge case, not a packaging defect). Structurally identical to
## [method classify_affinity_parse] — see that method's doc comment for the
## same null/legal-empty-array distinction, applied to the sibling table.
static func classify_card_parse(parsed: Variant) -> LoadFailure:
	if parsed == null:
		return LoadFailure.PARSE_ERROR
	return LoadFailure.NONE


## Builds a [CardDeck] from [param cards], forwarding [param rng] straight to
## [method CardDeck._init]. Extracted as a [code]static[/code], node-
## independent method (Story U-003 Implementation Notes #3) purely so a test
## can call it directly with a fixed-seed [RandomNumberGenerator] and get a
## reproducible opening hand for screenshot/greyscale-diff evidence — [method
## _ready] always calls this with [param rng] left at its default
## [code]null[/code] (production behavior unchanged: time-seeded, genuinely
## random shuffling, matching [CardDeck]'s own documented default). Card-face
## randomness itself is legal here — the project's `rng_in_combat_settlement`
## ban covers the settlement path, not which card comes up on a draw (GDD
## Core Rules 三, [CardDeck]'s own class doc comment).
static func _build_card_deck(cards: Array[Card], rng: RandomNumberGenerator = null) -> CardDeck:
	return CardDeck.new(cards, rng)


## Builds the on-screen message for [param failure] at [param path] from
## [constant TEXT_LOAD_FAILURE_FORMAT]. Never called with [constant
## LoadFailure.NONE] — callers check for [constant LoadFailure.NONE] before
## reaching the failure-display path (see [method _fail_load]).
static func load_failure_message(failure: LoadFailure, path: String) -> String:
	var reason: String = ""
	match failure:
		LoadFailure.MISSING:
			reason = Loc.localize(TEXT_LOAD_REASON_MISSING)
		LoadFailure.UNREADABLE:
			reason = Loc.localize(TEXT_LOAD_REASON_UNREADABLE)
		LoadFailure.EMPTY_CONTENT:
			reason = Loc.localize(TEXT_LOAD_REASON_EMPTY_CONTENT)
		LoadFailure.PARSED_EMPTY:
			reason = Loc.localize(TEXT_LOAD_REASON_PARSED_EMPTY)
		LoadFailure.PARSE_ERROR:
			reason = Loc.localize(TEXT_LOAD_REASON_PARSE_ERROR)
	return Loc.localize(TEXT_LOAD_FAILURE_FORMAT) % [reason, path]


# Parses already-read terrain text into the PackedStringArray Board.from_ascii()
# (via BattleState.create()) expects: one row per line, blank lines dropped.
# Strips \r defensively in case the file is ever saved with CRLF endings. Split
# from file-reading (previously _read_terrain_rows(path)) so _ready() can read
# the file once and reuse the same text for classify_content().
static func _parse_terrain_rows(text: String) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.replace("\r", "")
		if line.is_empty():
			continue
		rows.append(line)
	return rows


# Called from _ready() once at least one of terrain/roster/affinity failed.
# Logs every failing file (all three, if all three failed) but only ever
# shows one on screen — terrain checked before roster before affinity — since
# _load_error_label's fixed 464x254px area only fits a single message. Never
# constructs _state/_order/_controller/_phi: BattleState.create() is
# skipped entirely, so there is no half-built battle for anything downstream
# to touch. set_process(false) / set_process_input(false) are the primary
# guard; _load_failed is the second guard _process()/_input() check directly,
# in case processing is ever re-enabled from outside this script.
#
# affinity_failure arrives here as MISSING, UNREADABLE, or (2026-09-16 second
# manager ruling) PARSE_ERROR — never EMPTY_CONTENT or PARSED_EMPTY. See
# _ready()'s affinity-loading block for why a table that parses CLEANLY to
# zero links is never escalated to a failure and therefore never reaches this
# method, while a table with a corrupt row now does.
#
# Also hides _controls_hint_bg, for two reasons (measured 2026-08-28): (a)
# BattleScreen.tscn's LoadErrorLabel was enlarged to y=8..262 so the full
# failure message fits without clipping, and that bottom edge now overlaps
# ControlsHintBg's y=231 start — left visible, the hint bar would paint over
# the message's last line ("回報問題時請附上這個畫面。"), the one line this
# message exists to make sure the player can act on; (b) the battle hasn't
# started (BattleState was never built), so a hint about moving/confirming/
# ending a turn on an empty board would be actively misleading.
#
# Also hides _info_label: LoadErrorLabel spans y=8..262, which fully overlaps
# InfoLabel's y=8..32 — left visible, InfoLabel's stale/empty text would sit
# on top of the failure message.
#
# Story U-003: signature extended from three named LoadFailure parameters to
# a single Dictionary[String, LoadFailure] keyed by res:// path — the shape
# the story's own Implementation Notes #2 explicitly left to this
# implementer's judgment ("擴充方式由實作時判斷"), on the condition that
# existing enum semantics and existing call-site behavior stay unchanged.
# [param failures] is iterated in insertion order (GDScript Dictionary
# preserves it) for BOTH the push_error() loop below AND the "which one gets
# shown on screen" choice — this preserves the exact precedence the old
# positional signature had (terrain, then roster, then affinity all still
# come first in the caller's literal below) while extending cleanly to the
# two new paths this story adds (CARDS_PATH, CARD_TEXT_PATH) without a
# growing positional parameter list.
func _fail_load(failures: Dictionary[String, LoadFailure]) -> void:
	for path: String in failures:
		var failure: LoadFailure = failures[path]
		if failure != LoadFailure.NONE:
			push_error(_LOG_LOAD_FAILURE_FORMAT % [path, LoadFailure.find_key(failure)])

	var display_failure: LoadFailure = LoadFailure.NONE
	var display_path: String = ""
	for path: String in failures:
		var failure: LoadFailure = failures[path]
		if failure != LoadFailure.NONE:
			display_failure = failure
			display_path = path
			break
	_load_error_label.text = load_failure_message(display_failure, display_path)
	_load_error_label.visible = true
	_status_label.visible = false
	_info_label.visible = false
	_controls_hint_bg.visible = false

	_load_failed = true
	set_process(false)
	set_process_input(false)


# Left-click handling: computes the clicked cell directly from the event's
# own (raw window-pixel, per the class doc comment's 2026-09-04 correction)
# position rather than waiting for the next _process() cursor refresh, so the
# click always resolves against the exact tile the player saw the cursor on
# when they clicked.
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	_last_mouse_window_pos = event.position
	# Story 009 — DeviceAuthority.note_mouse_motion() call removed along with
	# this screen's own retired _device tracker (see this file's story-009
	# implementation notes in
	# tests/integration/ui/battle_cursor_navigation_convergence_test.gd for
	# the full reasoning). CursorStateHost's own Autoload _input() already
	# buffers EVERY engine InputEvent (including this one) into its own
	# _frame_events independently of this screen, and mouse device-authority
	# arbitration there reads a LIVE position each frame rather than this
	# flag, so removing this call changes nothing the host observes.
	#
	# Story U-013, AC-14 — see the matching guard in _input()'s keyboard/
	# gamepad branch for why this must not act while card play is open. Mouse
	# is not wired for any card-play interaction (S1/S2+ are keyboard/gamepad
	# only, matching this Interaction Map's own table and U-011/U-012's
	# precedent — HandBar has zero mouse wiring), so while a session is open
	# the only correct behavior for a click is to do nothing.
	#
	# story-u015-forced-discard.md — same "do nothing" rule extends to S4:
	# mouse is not wired for discard either (S4 shares Z2's keyboard/gamepad-
	# only navigation, see _handle_forced_discard_input()), and the board
	# itself must not be clickable while a discard is owed (mirrors AC-14's
	# own reasoning exactly — the S4 branch in _input() already blocks every
	# keyboard/gamepad path into board interaction; this is the mouse side of
	# the same guarantee).
	# Story 013 — _attack_confirming added alongside the two pre-existing
	# guards: mouse is not wired for any interaction while the T2' attack
	# confirm panel is open (same "do nothing" rule this guard already applies
	# to card play / forced discard — see this method's own doc comment).
	if _controller.is_card_play_in_progress() or _controller.has_pending_discard() or _attack_confirming:
		return
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	var cell: Vector2i = _window_pos_to_cell(event.position)
	if not BoardCoords.is_in_bounds(cell):
		return
	# Story 009 — _cursor_cell / _board_view.set_cursor(cell) direct writes
	# removed. The cursor's VISUAL target write now happens exclusively
	# through _apply_mouse_target_if_authoritative() (_TargetRetargetActor,
	# process_priority -60), which reads the SAME _last_mouse_window_pos set
	# above (already current for this frame — _input() dispatch runs before
	# any _process() priority this frame) and writes
	# CursorStateHost.set_target(); _update_cursor_visual() (process_priority
	# 100, later this same frame) reads it back. This click's own GAME-LOGIC
	# effect (click_tile below) is unrelated to that visual pipeline and still
	# resolves synchronously against the exact `cell` computed above from the
	# raw event position, unaffected by this change.
	#
	# Story 011 (U-T7, M1 audit 2026-09-29) — the return value used to be
	# discarded here (click_tile()'s &"none" rejection had no consumer
	# anywhere in this file). Now routed through _handle_click_tile_result()
	# — see that method's own doc comment for the three-way dispatch.
	_handle_click_tile_result(_controller.click_tile(cell))


# Sole call site in this file for converting a raw OS window-pixel mouse
# position into a board cell (2026-09-04, Story 001 screen-scaling epic —
# see the class doc comment's correction note). Both _handle_mouse_button()
# and _update_cursor_visual() go through this one function rather than each
# constructing the WorldLayout transform themselves, per WorldLayout's own
# doc comment ("no call site may re-derive the scale/rect/transform math
# itself"). world_viewport_canvas_origin is Vector2.ZERO because
# WorldLayout's transform already folds the centering offset in — see
# BoardCoords.window_to_grid's doc comment.
func _window_pos_to_cell(window_pos: Vector2) -> Vector2i:
	var window_to_canvas: Transform2D = WorldLayout.window_to_canvas_transform(get_window().size)
	return BoardCoords.window_to_grid(window_pos, window_to_canvas, Vector2.ZERO)


## story-011-input-gaps.md (U-T7, M1 audit 2026-09-29) — sole call site for
## dispatching on [method BattleController.click_tile]'s return value. Both
## [method _handle_mouse_button] and [method _confirm_at_cursor] route
## through here rather than discarding the Dictionary, matching
## [method click_tile]'s own doc comment's three-way distinction:
##
## - [code]&"none"[/code] — REJECTED. Bumps
##   [member _diagnostic_click_tile_rejected_count] so the rejection is
##   observable. 🔴 Does NOT distinguish &"none"'s three internal causes —
##   see [member _diagnostic_last_click_tile_action]'s own doc comment.
## - [code]&"blocked_pending_discard"[/code] — the EXISTING deliberate
##   silence this screen already applies during S4 forced discard (mirrors
##   [code]battle_open_hand[/code]'s own silent swallow while a discard is
##   owed — nothing to reject because the player cannot act at all right
##   now). Handled as its OWN branch, not merged into the &"none" count
##   above — that mixing is exactly what this story's AC calls out by name.
##   🔴 Believed unreachable from either call site today:
##   [method _handle_mouse_button]'s own
##   [code]is_card_play_in_progress() or has_pending_discard()[/code] guard,
##   and [method _input]'s keyboard/gamepad branch (has_pending_discard()
##   checked FIRST, dispatching to [method _handle_forced_discard_input]
##   instead), both already return before [method click_tile] is ever
##   called while a discard is owed. Handled explicitly anyway, in case a
##   future guard-ordering change ever lets it through.
## - Every other value ([code]&"selected"[/code], [code]&"deselected"[/code],
##   [code]&"moved"[/code], [code]&"attacked"[/code]) is a legitimate action.
##   No work needed beyond recording it: [BattleController]'s own
##   [signal unit_selected]/[signal selection_cleared]/[signal unit_moved]/
##   [signal attack_resolved] (all connected in [method _ready]) already
##   drive [method _refresh_view] for these.
## - Any OTHER value is a programmer error, not a gap this screen should
##   swallow quietly — per coding-standards.md's rule against asserting on
##   believed-unreachable branches, this uses push_error() rather than
##   assert(), so it stays loud in both debug and release builds.
func _handle_click_tile_result(result: Dictionary) -> void:
	var action: StringName = result.get("action", &"none")
	_diagnostic_last_click_tile_action = action
	match action:
		&"none":
			_diagnostic_click_tile_rejected_count += 1
		&"blocked_pending_discard", &"selected", &"deselected", &"moved", &"attacked":
			pass
		_:
			push_error("BattleScreen: BattleController.click_tile() returned unrecognized action %s" % action)


## story-011-input-gaps.md (U-T8, M1 audit 2026-09-29: "`end_unit_turn(id)` 全專案
## 只有兩個呼叫端 ... `src/ui/` 底下零命中") — sole call site for dispatching on
## [method BattleController.end_unit_turn]'s return value, mirroring
## [method _handle_click_tile_result]'s own "never drop the result" discipline
## (U-T7, same story) rather than discarding the bool the way the M1 audit
## found every pre-existing [method BattleController.click_tile] call site
## doing.
##
## [param ended] is [code]false[/code] for any of [method
## BattleController.end_unit_turn]'s documented rejection causes — no unit
## selected ([method BattleController.selected_unit] returns [code]-1[/code],
## which [method TurnOrder.is_done]/[method TurnOrder._is_actionable] both
## treat as "not actionable", not a crash), wrong phase, the selected unit
## already done, or a forced discard owed. This screen does not need to
## distinguish which cause produced a given [code]false[/code] — same
## one-counter-for-every-cause shape [member _diagnostic_click_tile_rejected_count]
## already uses for [code]&"none"[/code]'s three internal causes, not a new
## convention invented here.
func _handle_end_unit_turn_result(ended: bool) -> void:
	if not ended:
		_diagnostic_end_unit_turn_rejected_count += 1


# Edge-triggered directional cursor movement — see _direction_was_pressed's
# doc comment for why this cannot just be event.is_action_pressed(). Shared
# debounce logic lives in _direction_just_pressed().
#
# 🔴 Story 008 unit 3b (point 3/4, AC-3) — this method no longer moves the
# board cursor itself. CursorStateHost's own per-frame pipeline
# (CursorNavigationApplier, process_priority -25) now does that automatically
# every frame BOARD_TILE is registered to this screen and device authority is
# KEYBOARD_GAMEPAD, via the SAME raw InputEvent this screen's own _input()
# also receives (two separate nodes, one event, per ADR-0005's "dispatch
# order is TREE order" note) — calling apply_buffered_navigation() again from
# here, as AC-3's literal wording suggested, would be a SECOND, redundant
# application on top of the host's own automatic one (confirmed by engine
# run, see tests/integration/ui/battle_cursor_navigation_convergence_test.gd's
# finding #1 — "一次走兩格"). The correct fix is for this method to stop
# writing _cursor_cell at all, not to call that method itself.
#
# 🔴 Story 009 (2026-10-13) — the paragraph above this one used to describe
# _device.note_pad_input() bookkeeping here; that call is retired, not left
# to drift (this project's own registered failure shape: prose describing
# architecture outliving the code it described). Unit 2 switched
# _update_cursor_visual()'s gate to CursorStateHost.get_device_authority();
# unit 3a then removed all ~17 note_*()/resolve_frame() call sites (this one
# included). The directional branch below therefore now does genuinely
# NOTHING on an edge-triggered press — see its own body comment for why that
# `pass` is deliberate rather than an oversight.
#
# ⚠️ As of unit 3a, _device ITSELF (the field, its construction call, and the
# DeviceAuthority class file) was still a fully dead, never-read,
# never-written object graph (constructed once, nothing called any method on
# it). Unit 3b (this change) deleted the field, its construction call, the
# test file, and the DeviceAuthority class file itself; see this story's
# implementation notes (檔尾 of
# tests/integration/ui/battle_cursor_navigation_convergence_test.gd).
#
# The debounce loop and gate (_direction_just_pressed(), _direction_was_pressed)
# are KEPT ANYWAY, inert, rather than deleted alongside _device — collapsing
# this shape is this story's own Out of Scope item, explicitly left to
# story-010 (方向鍵去抖收斂). This is NOT a mitigation for CursorStateHost's
# own gamepad-stick debounce gap (that gap lives entirely inside CursorState's
# pipeline, which this screen's debounce has no mechanism to influence at all
# — the Autoload receives the SAME raw engine event independently of whatever
# this function does with its own copy). That gap remains genuinely open and
# is tracked separately (see this file's own test suite header, finding #3) —
# not something this change claims to fix.
func _handle_directional(_event: InputEvent) -> void:
	for action: StringName in _DIRECTION_VECTORS:
		if _direction_just_pressed(action, _direction_was_pressed):
			# Story 009, unit 3 — the sole statement this branch used to run
			# (_device.note_pad_input(), DeviceAuthority bookkeeping) is
			# retired along with that class (see this function's own doc
			# comment above). Nothing replaces it: CursorStateHost's own
			# pipeline already moves the board cursor automatically (same doc
			# comment), and this edge-trigger result has no other consumer.
			# `pass` only, rather than deleting the loop/if entirely —
			# collapsing this debounce shape is this story's own Out of Scope
			# item, explicitly left to story-010 (方向鍵去抖收斂).
			pass


# Story U-013 — S1's card-browsing input (Interaction Map step 2). Shares
# _direction_just_pressed()'s edge-detection discipline with
# _handle_directional() (see that method's own doc comment for why a raw
# event's is_action_pressed() is not enough by itself for a held gamepad
# stick) but tracks its OWN pressed-state Dictionary
# (_hand_direction_was_pressed) so this cursor's debounce state never leaks
# into the board cursor's, or vice versa.
func _handle_hand_navigation(_event: InputEvent) -> void:
	for action: StringName in _HAND_DIRECTION_DELTAS:
		if _direction_just_pressed(action, _hand_direction_was_pressed):
			_hand_bar.move_cursor(_HAND_DIRECTION_DELTAS[action])


# Shared by _handle_directional() (board cursor) and _handle_hand_navigation()
# (S1 hand cursor) — see _direction_was_pressed's doc comment for why a raw
# event's is_action_pressed() is not enough by itself for a held gamepad
# stick. `tracker` is the CALLER's own Dictionary (never shared between the
# two cursors) so one consumer's debounce state cannot leak into the other's.
func _direction_just_pressed(action: StringName, tracker: Dictionary) -> bool:
	var pressed_now: bool = Input.is_action_pressed(action)
	var was_pressed: bool = tracker.get(action, false)
	tracker[action] = pressed_now
	return pressed_now and not was_pressed


# Story U-013 connective tissue — `battle_open_hand` (S0<->S1 per
# design/ux/skill-card-play.md's Interaction Map row 1 and its "選擇不打" row:
# the SAME key both opens the hand from S0 and closes it back from S1,
# "不需要專屬按鍵,它就是收起"). Deeper steps (S2+) do not respond to this key
# at all — the Interaction Map only defines this toggle for S0<->S1; backing
# out of S2+ is battle_cancel's job (see _input()'s per-branch dispatch), not
# this key's. See _card_selecting_from_hand's own doc comment for why S2+
# cannot even reliably ask "am I still just one step past SELECTING_CARD"
# without the accessor this story flagged but did not add.
func _handle_open_hand_pressed() -> void:
	if not _controller.is_card_play_in_progress():
		if _controller.open_hand():
			# Story 008 — hands BOARD_TILE off to the card-play path the
			# instant it opens (S0 -> S1), BEFORE _confirm_selected_card()
			# tries to register it again later (S1 -> S2):
			# CursorSurfaceRegistry.register() hard-fails
			# DUPLICATE_TAG_REJECTED even for the identical node
			# re-registering an occupied tag (cursor_surface_registry.gd),
			# so the two owners of BOARD_TILE can never both hold it at once.
			var unregister_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)
			if unregister_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
				push_error(
					"BattleScreen: CursorStateHost.unregister_surface(BOARD_TILE) returned %s instead of REGISTERED while opening the hand -- was it already unregistered by something else?"
					% unregister_result
				)
			_card_selecting_from_hand = true
			_refresh_view()
		return
	if _card_selecting_from_hand:
		if _controller.cancel():
			_card_selecting_from_hand = false
			# Story 008 — CardPlaySession.cancel() only reaches Step.CLOSED
			# from Step.SELECTING_CARD, which is exactly this branch: card
			# play just fully closed back to S0 without playing a card.
			# Reclaim BOARD_TILE for the normal move/attack path.
			var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
			if register_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
				push_error(
					"BattleScreen: CursorStateHost.register_surface(BOARD_TILE) returned %s instead of REGISTERED while cancelling the hand back to S0."
					% register_result
				)
			_refresh_view()


## Story U-016 — 呼叫既有 [method BattleMenu.open](U-007~U-010 已交付,本檔
## 不重寫其行為/其閘控/其結束回合列/其離開確認)。[member BattleMenu.controller]
## 與兩個 in_progress_check Callable 皆在 [method _ready] 注入一次,不在這裡
## 重複設定。Guard 防止對已開啟的選單重複呼叫 open()(該方法本身的雙開行為
## 未經本 story 驗證,保守起見不去試探它)。
func _handle_battle_menu_pressed() -> void:
	if _battle_menu.is_open():
		return
	_battle_menu.open()


## story-u015-forced-discard.md — S4's entire input surface. Called ONLY from
## [method _input]'s top-priority [code]BattleController.has_pending_discard()[/code]
## branch (see that call site's own comment for why this pre-empts every
## other branch, including [code]battle_open_hand[/code]). Reuses [method
## _handle_hand_navigation] verbatim for browsing — S4 shares Z2's card
## navigation with ordinary S1 (Implementation Note 1: "與一般的 S1...共用 Z2
## 的展示邏輯"), the only differences are the entry trigger (system-detected,
## not a keypress) and what [code]battle_confirm[/code]/[code]battle_cancel[/code]
## do once inside it.
func _handle_forced_discard_input(event: InputEvent) -> void:
	_handle_hand_navigation(event)
	if event.is_action_pressed(&"battle_confirm"):
		_confirm_forced_discard()
		return
	if event.is_action_pressed(&"battle_cancel"):
		# Implementation Note 2 (`skill-card-play.md` quoted verbatim in the
		# story): "可以拒絕「打出」,不可以拒絕「棄掉」...而它必須讓玩家看得出
		# 來自己不是按錯(拒絕須可觀測,P-F2)". The press is swallowed here —
		# CardPlaySession.cancel()/BattleController.cancel() are never called,
		# there is nothing to step back out of — and its rejection is made
		# observable two ways: [HandBar]'s persistent [constant
		# HandBar.TEXT_FORCED_DISCARD] caption is already visible the whole
		# time S4 is active (not a transient flash a distracted player could
		# miss — the same "persistent trace beats transient flash" judgment
		# this project already applied to modifier-expiry feedback), and this
		# counter proves THIS press specifically hit the rejection branch.
		_diagnostic_forced_discard_cancel_rejected_count += 1
		return


## story-u015-forced-discard.md — the ONLY way S4 resolves: maps the hand
## bar's cursor index to a real [Card] (mirrors [method _confirm_selected_card]'s
## own index-lookup shape exactly) and calls [method
## BattleController.resolve_forced_discard] — the existing entry point this
## story reads rather than rewrites (`card_deck.gd`'s [method
## CardDeck.discard_card], not [method CardDeck.play_card]: GDD Edge Cases
## "不得由系統代選" — this method always names the exact card the player's
## cursor was on, never picks one itself). On success,
## [method BattleController.has_pending_discard] becomes false and the next
## [method _refresh_view] call renders [HandBar] back in its normal state.
func _confirm_forced_discard() -> void:
	var hand: Array[Card] = _state.card_deck().hand()
	var index: int = _hand_bar.diagnostic_cursor_index()
	if index < 0 or index >= hand.size():
		return
	if _controller.resolve_forced_discard(hand[index]):
		_refresh_view()


# Story U-013 connective tissue — the S1->S2 handoff the previous batch
# flagged as at risk of falling between U-012 and U-013:
# [HandBar]'s own cursor index (kept entirely inside that file, per its class
# doc comment) has no game-data meaning by itself; this screen is the one
# class allowed to know both [HandBar] and [Card]/[CardDeck] (mirrors the
# existing hand_bar_slot_kind_for() mapping convention), so the index -> Card
# lookup happens here, nowhere else. Bounds-checked defensively for S7 (empty
# hand): diagnostic_cursor_index() clamps to 0 even with zero slots, and
# hand.size() would then also be 0, so the out-of-range check below is what
# keeps an empty-hand confirm a safe no-op rather than an out-of-bounds read.
func _confirm_selected_card() -> void:
	var hand: Array[Card] = _state.card_deck().hand()
	var index: int = _hand_bar.diagnostic_cursor_index()
	if index < 0 or index >= hand.size():
		return
	if _controller.select_card(hand[index]):
		_card_selecting_from_hand = false
		# Story U-014 (2026-09-24 "消除重複" ruling) — no local mirror to
		# write here anymore; _open_card_confirm_panel() reads
		# BattleController.selected_card() directly once CONFIRMING is
		# reached.
		# Story U-013 (下半) — S1 -> S2/S2p. Registers this screen itself as
		# the BOARD_TILE CursorSurface (see cursor_navigate() below for the
		# Option E contract this satisfies) and queues an initial seed onto
		# the first legal target — see _apply_pending_target_jump()'s own
		# comment for why "queue a forward jump with no prior target" IS the
		# correct seeding mechanism (next_target_id()'s own documented
		# "not found" fallback already lands on the first entry).
		_card_selecting_target = true
		# Kept on ONE line deliberately (not wrapped the way the rest of this
		# file wraps long calls): the U-013 下半 register/unregister call
		# sites are what frame_buffer_ordering_test.gd's line-based scanner
		# greps for, and it checks for the "BOARD_TILE" substring on the SAME
		# line as the call — see that file's own
		# test_board_tile_registration_in_battle_screen_is_found_by_the_scanner
		# doc comment. A wrapped call would put the enum literal on a
		# different source line than the registration call and silently
		# defeat that scanner (found by actually running it, not reasoned
		# about — and this very sentence had to be reworded once already
		# because writing the literal method-name substring out here, even
		# inside a comment, tripped the SAME scanner it is describing).
		var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
		if register_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
			push_error(
				"BattleScreen: CursorStateHost.register_surface(BOARD_TILE) returned %s instead of REGISTERED -- target-selection cursor navigation will not work this session."
				% register_result
			)
		_target_jump_requested = true
		_target_jump_forward = true
		_refresh_view()


## Story U-013 (ADR-0005 機制六③ Option E contract —
## [constant CursorState.NAVIGATE_METHOD_NAME]) — the duck-typed navigation
## entry [CursorNavigationApplier] calls (via [method Object.call] on the
## [Node] registered under [constant CursorTypes.SurfaceType.BOARD_TILE]).
## [param from_id] and the return value are board-tile ids
## ([method CursorTypes.encode_tile]/[method CursorTypes.decode_tile]), never
## unit ids — mirrors [code]tests/integration/cursor/frame_buffer_ordering_test.gd[/code]'s
## own [code]_BoardBackedSurface[/code] test fixture almost exactly (this IS
## the production adapter that fixture's own doc comment said did not exist
## yet in this project).
##
## Returns [code]null[/code] — "no legal target this direction" — only when
## [param direction] leaves the board ([method BoardCoords.is_in_bounds]
## rejects the destination). [b]Deliberately does NOT constrain the
## destination to [method BattleController.legal_targets][/b] — Implementation
## Note #3 requires every on-board tile to be reachable by directional
## navigation regardless of whether the unit standing there (if any) is a
## legal target; only confirm is gated on legality (see
## [method _apply_target_confirm_from_cursor_state]).
func cursor_navigate(from_id: int, direction: Vector2i) -> Variant:
	var from_cell: Vector2i = CursorTypes.decode_tile(from_id, BoardCoords.BOARD_COLS)
	var to_cell: Vector2i = from_cell + direction
	if not BoardCoords.is_in_bounds(to_cell):
		return null
	return CursorTypes.encode_tile(to_cell, BoardCoords.BOARD_COLS)


## Story U-013 (ADR-0005 機制六②) — consumed by [_TargetRetargetActor]'s own
## [method Node._process] at [code]process_priority = -60[/code]. No-op if no
## jump was queued, if target selection is no longer active (a stale request
## from before this screen left target selection — [member _card_selecting_target]
## became false in between the request and this call, e.g. a same-frame
## cancel), or if the current legal-target set is empty.
##
## [b]"Queue a forward jump with no prior target" IS the seeding
## mechanism[/b] — deliberately not a separate code path. [method next_target_id]'s
## own documented contract: a [param current_id] not found in [param sorted_ids]
## (which is exactly what happens here the FIRST time this runs after
## entering/re-entering target selection, since the cursor's current board
## tile generally has no unit standing on it, or a unit not in THIS step's
## legal set) is treated as "start from the first entry going forward" — so
## every call site that wants "land on the first legal target" (S1->S2 in
## [method _confirm_selected_card], the S2p->S2q / S2q->S2p transitions in
## [method _after_target_selection_advanced] / [method
## _handle_target_selection_cancel_transition]) simply queues
## [code]_target_jump_forward = true[/code] — the SAME request a real
## [code]battle_next_target[/code] press queues.
##
## [b]Reading [method CursorStateHost.get_current_target] from THIS priority
## (-60), not 100[/b] — a deliberate reading of ADR-0005's own text, flagged
## in this story's report as this implementer's own judgment call rather than
## something the ADR spells out for this exact case: the "must read at
## priority 100" obligation ([method CursorStateHost.get_current_target]'s
## own doc comment) is stated for "callers belonging to 機制六⑥(下游讀取方)"
## — readers that need the FULLY SETTLED per-frame value, after ③'s own
## write. Role ② is not such a reader: it runs BEFORE ③ by architecture
## design (that is the entire point of the (-100,-25) window), and here it
## reads the pre-③ value purely to establish ITS OWN basis for computing a
## new target, which becomes part of what ③/⑥ later observe as settled — not
## a claim about the settled value itself.
func _apply_pending_target_jump() -> void:
	if not _target_jump_requested:
		return
	_target_jump_requested = false
	if not _card_selecting_target:
		return

	var forward: bool = _target_jump_forward
	var legal_ids: Array[int] = _controller.legal_targets()
	if legal_ids.is_empty():
		return
	var positions: Dictionary[int, Vector2i] = {}
	for id: int in legal_ids:
		positions[id] = _state.position_of(id)
	var sorted_ids: Array[int] = sort_targets_by_position(legal_ids, positions)

	var current_unit_id: int = -1
	var current: CursorTarget = CursorStateHost.get_current_target()
	if current != null and current.surface == CursorTypes.SurfaceType.BOARD_TILE:
		var current_cell: Vector2i = CursorTypes.decode_tile(current.id, BoardCoords.BOARD_COLS)
		var current_unit: Unit = _state.unit_at(current_cell)
		if current_unit != null:
			current_unit_id = current_unit.id

	var next_id: int = next_target_id(current_unit_id, sorted_ids, forward)
	if next_id == -1:
		return
	var tile_id: int = CursorTypes.encode_tile(positions[next_id], BoardCoords.BOARD_COLS)
	CursorStateHost.set_target(CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, tile_id))


## Story 009 (moved from story-008's scope by 2026-10-13 manager ruling; full
## five-option evaluation in
## [code]docs/architecture/cursor-device-authority-for-board-tile-2026-10-13.md[/code])
## — mouse-path counterpart to [method _apply_pending_target_jump] above,
## consumed by the SAME [_TargetRetargetActor]'s [method Node._process] at
## [code]process_priority = -60[/code] (ADR-0005 R5-2's open interval — [method
## CursorStateHost.set_target] may only be called from strictly between -100
## and -25).
##
## [b]Unconditional per frame, not request-flag-gated[/b] — unlike [method
## _apply_pending_target_jump] (a discrete "jump" queued from an edge-
## triggered key press), the mouse has no discrete-event concept here: it is
## continuous tracking, mirroring [method _update_cursor_visual]'s own MOUSE
## branch below (which independently recomputes the same cell from the same
## [member _last_mouse_window_pos] for ITS OWN purpose — see that method's
## doc comment). Both call sites go through the shared [method
## _window_pos_to_cell] helper (that helper's own doc comment: "no call site
## may re-derive the scale/rect/transform math itself"), so there is exactly
## ONE cell-computation rule, just two call sites — not the "two trackers"
## shape this story exists to retire.
##
## [b]Gate order, structured as early-return rejects first[/b]:
## 1. Card play / forced discard in progress — mouse is not wired for either
##    path (mirrors [method _handle_mouse_button]'s own identical guard; see
##    that method's own doc comment for why).
## 2. [method CursorStateHost.get_device_authority] is not
##    [constant CursorTypes.Authority.MOUSE] — device authority belongs to
##    keyboard/gamepad this frame, so a stale mouse position must not
##    overwrite [CursorStateHost]'s target (this read happens at [code]-60[/code],
##    strictly after [code]CursorStateHost[/code]'s own arbitration at
##    [code]-100[/code] — structurally zero staleness, per the architecture
##    opinion doc's 第零節 frame-ordering table).
## 3. [method _window_pos_to_cell] of [member _last_mouse_window_pos] lands
##    out of board bounds — an off-board mouse must not write a target
##    (mirrors [method _handle_mouse_button]'s own bounds check).
##
## [b][method CursorStateHost.set_target]'s return value is checked[/b] —
## [constant CursorState.SetTargetResult.REJECTED_REENTRANT] (another write
## mid-flight) is the only documented way this call can fail; per this
## project's own registered failure shape (an unchecked enum return silently
## degrading into "nothing happened" — [constant
## CursorSurfaceRegistry.RegisterResult.DUPLICATE_TAG_REJECTED] is the
## precedent), a failure is reported rather than swallowed, mirroring [method
## Node._ready]'s own identical check when it seeds the initial target.
##
## ⚠️ [b]Known, accepted behavior changes (2026-10-13 manager ruling, written
## into this story's Acceptance Criteria)[/b]: reclaiming board-cursor
## authority from keyboard/gamepad back to mouse now requires
## [member MouseReclaimThresholdConfig.board_tile_threshold_px] (currently a
## PROVISIONAL 75px) of accumulated net displacement rather than any motion at
## all; and E1 (holding a directional input can indefinitely veto mouse
## reclaim — a frozen, registered, 100% reproducible defect) becomes reachable
## from this, the main board path, for the first time. Neither is this
## method's bug to fix — see the architecture opinion doc cited above for the
## full analysis.
func _apply_mouse_target_if_authoritative() -> void:
	if _controller.is_card_play_in_progress() or _controller.has_pending_discard():
		return
	if CursorStateHost.get_device_authority() != CursorTypes.Authority.MOUSE:
		return
	var cell: Vector2i = _window_pos_to_cell(_last_mouse_window_pos)
	if not BoardCoords.is_in_bounds(cell):
		return
	var tile_id: int = CursorTypes.encode_tile(cell, BoardCoords.BOARD_COLS)
	var result: CursorState.SetTargetResult = CursorStateHost.set_target(
		CursorTarget.make(CursorTypes.SurfaceType.BOARD_TILE, tile_id)
	)
	if result != CursorState.SetTargetResult.APPLIED:
		push_error(
			"BattleScreen: CursorStateHost.set_target() returned %s instead of APPLIED while tracking mouse-authoritative cursor position."
			% result
		)


## Story U-013 (ADR-0005 機制六⑥) — called from [method _process] only (see
## that method's own comment), never from [method _input]. Reads
## CursorStateHost's per-frame-arbitrated state and, if the target is valid
## and a unit stands on its cell, tries [method BattleController.select_target]
## then (only if that was rejected) [method BattleController.select_second_target]
## — trying both rather than tracking which step the session is at avoids
## re-deriving [CardPlaySession]'s own step (both methods are safe, side-
## effect-free no-ops when their own leading step-gate does not match — see
## [method CardPlaySession.select_target] / [method
## CardPlaySession.select_second_target]'s own code), the same "never
## re-derive the transition table" discipline [member _card_selecting_from_hand]'s
## own doc comment already establishes for this file.
##
## 不合法的格子仍然走得到(見 [method cursor_navigate]),但這裡是唯一會真的
## 拒絕的地方 —— [param unit] 為 null(空格)或兩個 select_* 呼叫都回傳
## [code]false[/code](不合法目標)時直接不動作,游標留在原地,可以繼續移動
## 再按一次確認(Implementation Note #3)。
func _apply_target_confirm_from_cursor_state() -> void:
	if not _card_selecting_target:
		return
	if not CursorStateHost.is_current_target_valid():
		return
	var target: CursorTarget = CursorStateHost.get_current_target()
	if target == null or target.surface != CursorTypes.SurfaceType.BOARD_TILE:
		return
	var cell: Vector2i = CursorTypes.decode_tile(target.id, BoardCoords.BOARD_COLS)
	var unit: Unit = _state.unit_at(cell)
	if unit == null:
		return

	# Story U-014 (2026-09-24 "消除重複" ruling) — no local target mirrors to
	# write here anymore; _open_card_confirm_panel() reads
	# BattleController.selected_target_a()/selected_target_b() directly once
	# CONFIRMING is reached.
	var advanced: bool = _controller.select_target(unit.id)
	if not advanced:
		advanced = _controller.select_second_target(unit.id)
	if advanced:
		_after_target_selection_advanced()


## Story U-013 — shared tail for both successful [method
## _apply_target_confirm_from_cursor_state] branches. [method
## BattleController.legal_targets]'s OWN return value (not a re-derivation of
## [CardPlaySession]'s step table) decides which happened: empty means the
## session moved past target selection entirely into CONFIRMING (S3, for
## either 甲類's single pick or 丙類's second pick — [method
## CardPlaySession.legal_targets] only returns non-empty at SELECTING_TARGET/
## SELECTING_TARGET_B); non-empty means a 丙類 first pick just landed the
## session at SELECTING_TARGET_B (S2q), still target selection.
##
## 🔴 Known, disclosed gap — see [member _card_selecting_from_hand]'s own doc
## comment's "still-open gap" paragraph: reaching CONFIRMING here unregisters
## [constant CursorTypes.SurfaceType.BOARD_TILE], and cancelling back OUT of
## CONFIRMING does not currently re-register it. S3 has no built UI yet
## (U-014), so this is not reachable through anything this story wires end to
## end.
func _after_target_selection_advanced() -> void:
	var legal: Array[int] = _controller.legal_targets()
	if legal.is_empty():
		_card_selecting_target = false
		# Kept on ONE line — see _confirm_selected_card()'s matching comment
		# for why (frame_buffer_ordering_test.gd's scanner is line-based).
		var unregister_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)
		if unregister_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
			push_error(
				"BattleScreen: CursorStateHost.unregister_surface(BOARD_TILE) returned %s instead of REGISTERED -- was it already unregistered by something else?"
				% unregister_result
			)
		# Story U-014 — legal_targets() empty here means CONFIRMING (S3) was
		# just reached (see this method's own doc comment for why that
		# reading is unambiguous at this call site). This closes the
		# previously disclosed gap: S3 now has a real UI.
		_open_card_confirm_panel()
	else:
		_target_jump_requested = true
		_target_jump_forward = true
	_refresh_view()


## Story U-014 — builds every value the S3 confirm panel needs, reading the
## selected card/targets straight from [method BattleController.selected_card]/
## [method BattleController.selected_target_a]/[method
## BattleController.selected_target_b] (2026-09-24 "消除重複" ruling — no
## screen-local copy of any of this exists anymore), plus [member _state] and
## [member _card_flavor_texts], and hands it to [CardConfirmPanel]'s
## display-only API. Called exactly once, from [method
## _after_target_selection_advanced] the moment [CardPlaySession] reaches
## CONFIRMING — see that method's own doc comment.
##
## 🔴 [member card_confirm_strength_provider] is left unset by every call site
## in this file today (2026-09-24 manager ruling — see that field's own doc
## comment: "維持留白＋提示", not wired to any real data source this story).
## [method CardConfirmPanel.show_permanent_write_confirmation] is called with
## [code]strength_available = false[/code] whenever the Callable is unset,
## which is unconditionally true today.
func _open_card_confirm_panel() -> void:
	# Story U-014 (2026-09-24 "消除重複" ruling) — reads directly from
	# BattleController's new read-only forwarders instead of a screen-local
	# mirror. Structurally, [method BattleController.selected_card] cannot be
	# null here: this method is only ever reached from
	# [method _after_target_selection_advanced], which is only ever reached
	# after a successful [method BattleController.select_target] / [method
	# BattleController.select_second_target] call — and neither of those can
	# return [code]true[/code] unless [CardPlaySession] already moved past
	# [constant CardPlaySession.Step.SELECTING_CARD] (which is the ONLY step
	# transition that sets [member CardPlaySession._selected_card]).
	#
	# 🔴 The null check below is kept anyway as defense in depth, not because
	# a reachable trigger is known — the trigger this project actually hit
	# (an existing test calling [method BattleController.select_card] directly,
	# bypassing this screen's own [method _confirm_selected_card]) no longer
	# applies: that direct call still sets [CardPlaySession]'s own real
	# [code]_selected_card[/code], which [method BattleController.selected_card]
	# now reads straight from — there is no more screen-local copy that call
	# path could leave out of sync. Verified unreachable through this project's
	# own state machine (every path to CONFIRMING/SELECTING_TARGET/
	# SELECTING_TARGET_B requires [CardPlaySession._selected_card] non-null —
	# see [code]tests/integration/ui/card_confirm_panel_test.gd[/code]'s own
	# derivation, same file). This guard's only remaining test coverage is a
	# deliberately adversarial spy [CardPlaySession] subclass that overrides
	# [method CardPlaySession.selected_card] to lie — see that test file's
	# [code]_MutantCardPlaySessionLiesAboutSelectedCard[/code] — not a
	# naturally-reachable production scenario.
	var card: Card = _controller.selected_card()
	if card == null:
		push_error(
			"BattleScreen: _open_card_confirm_panel() reached CONFIRMING with "
			+ "BattleController.selected_card() == null -- the confirm panel "
			+ "cannot be shown. This should be structurally unreachable; see "
			+ "this method's own doc comment."
		)
		return
	_card_confirming = true
	var flavor_text: String = _card_flavor_texts.get(card.id, "")
	var target_a_id: int = _controller.selected_target_a()
	var target_b_id: int = _controller.selected_target_b()

	if card.category == Card.Category.TEMPORARY_STAT_MODIFIER:
		var target: Unit = _state.unit_by_id(target_a_id)
		var existing: Array[Dictionary] = []
		for modifier: CardModifier in target.active_modifiers():
			existing.append({
				"source_name": modifier.source_name,
				"atk_delta": modifier.atk_delta,
				"def_delta": modifier.def_delta,
				"remaining_turns": modifier.remaining_turns,
			})
		# Preview of ATK_eff/DEF_eff AFTER this card applies — confirm() has
		# not run yet at S3, so target.effective_atk()/effective_def() still
		# reflect the CURRENT (pre-card) value. This calls the SAME real
		# CardModifierRules functions Unit.effective_atk()/effective_def()
		# themselves call (per that file's own doc comment: base + clamped
		# sum, then floored at 0) against a hypothetical modifier list, rather
		# than approximating with target.effective_atk() + card.delta_atk —
		# the clamp is non-linear near its bounds, so a plain addition could
		# silently disagree with what confirm() will actually produce.
		var hypothetical: Array[CardModifier] = target.active_modifiers()
		hypothetical.append(
			CardModifier.new(card.id, card.delta_atk, card.delta_def, card.duration_rounds)
		)
		var preview_atk: int = CardModifierRules.effective_atk(target.atk, hypothetical)
		var preview_def: int = CardModifierRules.effective_def(target.def, hypothetical)
		_card_confirm_panel.show_temporary_modifier_confirmation(
			card.id, flavor_text, target.code_name,
			card.delta_atk, card.delta_def, card.duration_rounds,
			existing, preview_atk, preview_def
		)
	else:
		var target_a: Unit = _state.unit_by_id(target_a_id)
		var target_b: Unit = _state.unit_by_id(target_b_id)
		var strength_result: Dictionary = {"available": false, "current": 0, "projected": 0}
		if card_confirm_strength_provider.is_valid():
			strength_result = card_confirm_strength_provider.call(target_a_id, target_b_id)
		_card_confirm_panel.show_permanent_write_confirmation(
			card.id, flavor_text, target_a.code_name, target_b.code_name,
			bool(strength_result.get("available", false)),
			int(strength_result.get("current", 0)),
			int(strength_result.get("projected", 0))
		)


## Story U-014 (AC-U11) — consumed once per frame from [method _process],
## never from [method _input] (see [member _card_confirm_pending_press]'s own
## doc comment). No-op if [member _card_confirming] is already false — e.g. a
## same-frame confirm-then-cancel race, or this screen having left CONFIRMING
## through some other path before this ran. [method CardPlaySession.confirm]'s
## own [constant CardPlaySession.Step.CLOSED] structural guard is what makes
## calling [method BattleController.confirm] here safe even if this were ever
## reached more than once for the same confirmation — this early-out is what
## keeps that from ever actually happening.
func _apply_pending_card_confirm() -> void:
	if not _card_confirming:
		return
	if _controller.confirm():
		_card_confirming = false
		# Story U-014 (2026-09-24 "消除重複" ruling) — no local mirrors to
		# clear here anymore; CardPlaySession's own _reset_to_closed() (called
		# internally by a successful confirm()) already clears its real
		# _selected_card/_selected_target_a/_selected_target_b.
		_card_confirm_panel.hide_panel()
		# Story 008 — CardPlaySession.confirm() always closes back to S0 on
		# success: reclaim BOARD_TILE for the normal move/attack path.
		var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
		if register_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
			push_error(
				"BattleScreen: CursorStateHost.register_surface(BOARD_TILE) returned %s instead of REGISTERED after confirming a card play."
				% register_result
			)
		# AC-U1 — Implementation Note 5: confirm() already mutated the
		# target's modifiers (甲類) or wrote to the affinity pool (丙類);
		# Unit.effective_atk()/effective_def() and BattleState.preview_damage()
		# are both live, uncached queries, so the next _refresh_view() call is
		# what makes the change observable. This story does not compute or
		# cache the new damage number itself.
		# 🔴 2026-10-12:preview_damage() 現在回傳 [PreviewDamageResult] —— 上面
		# 「live, uncached」描述的性質不變,只是傷害數字改讀回傳物件的 .damage 欄位。
		_refresh_view()


## Story U-014 — closes the gap [member _card_selecting_from_hand]'s own doc
## comment flagged as "still open" once S3 got a real UI: cancelling OUT of
## CONFIRMING must re-register [constant CursorTypes.SurfaceType.BOARD_TILE]
## and restore [member _card_selecting_target], mirroring [method
## _handle_target_selection_cancel_transition]'s own "S2q -> S2p" branch.
##
## 🔴 2026-09-24 "消除重複" ruling simplified this method considerably. Before
## this ruling, this screen kept its own copies of the selected targets
## ([code]_card_confirm_target_a[/code]/[code]_card_confirm_target_b[/code])
## and had to branch on the card's category here purely to decide WHICH of
## its two local copies [method CardPlaySession.cancel] would have cleared —
## mirroring that method's own CONFIRMING branch (丙類 clears its internal
## [code]_selected_target_b[/code]; 甲類 clears [code]_selected_target_a[/code]).
## Now that this screen holds no such copies at all (see [method
## _open_card_confirm_panel]'s own doc comment), there is nothing left to
## mirror — [CardPlaySession] already did the real clearing internally the
## instant [method BattleController.cancel] (below) returned, and the next
## [method _open_card_confirm_panel] call (if the player re-enters CONFIRMING)
## will read whatever is left over straight from
## [method BattleController.selected_target_a]/[method
## BattleController.selected_target_b]. The category branch, and the null
## guard an independent review previously required around it, are both gone
## because there is no longer a local field for either to protect.
func _handle_card_confirm_cancel_transition() -> void:
	_card_confirming = false
	_card_confirm_panel.hide_panel()
	_card_selecting_target = true
	var register_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.register_surface(CursorTypes.SurfaceType.BOARD_TILE, self)
	if register_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
		push_error(
			"BattleScreen: CursorStateHost.register_surface(BOARD_TILE) returned %s instead of REGISTERED while cancelling out of the S3 confirm panel."
			% register_result
		)
	_target_jump_requested = true
	_target_jump_forward = true


## Story U-013 — called from the [member _card_selecting_target] branch of
## [method _input] immediately after a [code]battle_cancel[/code] press calls
## [method BattleController.cancel]. Distinguishes the two destinations
## [method CardPlaySession.cancel] can reach FROM SELECTING_TARGET/
## SELECTING_TARGET_B purely from [method BattleController.legal_targets]'s
## OWN post-call return value — see [member _card_selecting_from_hand]'s doc
## comment for why an empty result is unambiguous here specifically (never
## re-deriving [CardPlaySession]'s full transition table): [method
## CardPlaySession.cancel]'s SELECTING_TARGET branch only ever steps to
## SELECTING_CARD, and its SELECTING_TARGET_B branch only ever steps to
## SELECTING_TARGET — CONFIRMING is never a destination from either, only ever
## a source (see that method's own code) — so within this call site
## specifically, "legal_targets() is empty" unambiguously means SELECTING_CARD
## (S1), never CONFIRMING.
func _handle_target_selection_cancel_transition() -> void:
	var legal: Array[int] = _controller.legal_targets()
	if legal.is_empty():
		# S2/S2p -> S1 (SELECTING_CARD). 2026-09-24 "消除重複" ruling: no
		# local mirrors left to clear here — CardPlaySession.cancel()'s
		# SELECTING_TARGET branch already clears its own real _selected_card
		# AND _selected_target_a internally; the next _confirm_selected_card()
		# call (S1 -> S2 again) reads whatever is current straight from
		# BattleController.
		_card_selecting_target = false
		_card_selecting_from_hand = true
		# Kept on ONE line — see _confirm_selected_card()'s matching comment
		# for why (frame_buffer_ordering_test.gd's scanner is line-based).
		var unregister_result: CursorSurfaceRegistry.RegisterResult = CursorStateHost.unregister_surface(CursorTypes.SurfaceType.BOARD_TILE)
		if unregister_result != CursorSurfaceRegistry.RegisterResult.REGISTERED:
			push_error(
				"BattleScreen: CursorStateHost.unregister_surface(BOARD_TILE) returned %s instead of REGISTERED -- was it already unregistered by something else?"
				% unregister_result
			)
	else:
		# S2q -> S2p (SELECTING_TARGET) — stays registered, reseed onto the
		# (now S2p) legal set's first entry. No local mirror to clear (see
		# the "legal.is_empty()" branch's own comment above).
		_target_jump_requested = true
		_target_jump_forward = true


# Confirm action bound to the project-level "battle_confirm" input action
# (project.godot [input]: keyboard Enter/KP-Enter/Space, gamepad Bottom
# Action button — Xbox A / Sony Cross / Switch B). Added 2026-08-27 because
# no built-in ui_* action alone covers both devices for a confirm/select
# semantic: ui_accept has no default gamepad binding, and ui_select's only
# gamepad binding is the Top Action button (Y/Triangle/X), an unusual choice
# for "confirm" — see the class doc comment / task report for the full
# measured InputMap gap this closed.
func _confirm_at_cursor() -> void:
	if not BoardCoords.is_in_bounds(_cursor_cell):
		return
	# Story 013（攻擊確認面板,二段確認)— a press that would resolve to an
	# attack opens the confirm panel (T2', zero write) instead of calling
	# click_tile() immediately. _cursor_attack_target_id() is the EXISTING
	# public-query-backed helper _refresh_view() already uses to answer this
	# same "is the cursor on a legal attack target" question for the
	# damage-preview text (BattleController.attack_targets(), not a private
	# method) — reused here rather than re-deriving range/LOS legality a
	# second time in this UI layer, per this project's registered "same rule
	# implemented twice, only coincidentally agreeing today" failure mode.
	var attack_target_id: int = _cursor_attack_target_id()
	if attack_target_id != -1:
		_open_attack_confirm_panel(attack_target_id)
		return
	# Story 011 (U-T7, M1 audit 2026-09-29) — same gap and same fix as the
	# matching call in _handle_mouse_button(): the return value used to be
	# discarded. See _handle_click_tile_result()'s own doc comment.
	_handle_click_tile_result(_controller.click_tile(_cursor_cell))


## Story 013 — builds every value the T2' attack confirm panel needs, reading
## ATK/DEF/Φ/damage from the SAME breakdown query the settlement path itself
## is built on ([method BattleState.preview_damage_breakdown] — see that
## method's own doc comment: delegates to the same private helper
## [method BattleState._compute_attack_damage] uses, a structural guarantee
## against "same formula implemented twice, only coincidentally agreeing
## today" drift, not merely a convention followed today). Called from
## [method _confirm_at_cursor] the moment a press resolves to a legal attack
## target. Zero write — no [method BattleState.commit_authoritative_change]
## call anywhere on this path, matching ADR-0001's requirement that opening
## this panel must not bump [member BattleState.combat_state_version].
func _open_attack_confirm_panel(target_id: int) -> void:
	var attacker_id: int = _controller.selected_unit()
	var attacker: Unit = _state.unit_by_id(attacker_id)
	var target: Unit = _state.unit_by_id(target_id)
	# Φ 一律經由 _phi.phi() 取得,與 _refresh_view() Mode C 的既有呼叫點相同
	# （見該方法自己的註解)——傷害預覽與這裡的確認面板不可能對 Φ 的輸入值有分歧。
	var phi: int = _phi.phi(attacker_id, target_id)
	var breakdown_result: DamageBreakdownResult = _state.preview_damage_breakdown(
		attacker_id, target_id, phi
	)
	# preview_damage_breakdown() 回傳 null(非歸零拆解)時代表 attacker_id/
	# target_id 有一個無法解析——依該方法自己的 doc comment,這是刻意的區分設計
	# （全零的拆解會跟「真的造成 0 傷害的攻擊」無法分辨)。結構上應該不可達
	# （attack_target_id 來自 _cursor_attack_target_id(),已先核對過
	# attack_targets().cells 與 faction),但比照 _open_card_confirm_panel() 的
	# 既有防禦性判斷紀律,仍然檢查並拒絕開面板,而非讓面板顯示假資料。
	if breakdown_result == null:
		push_error(
			"BattleScreen: _open_attack_confirm_panel() could not resolve attacker_id=%d/target_id=%d -- preview_damage_breakdown() returned null. Panel not opened."
			% [attacker_id, target_id]
		)
		return
	var breakdown: Dictionary = breakdown_result.breakdown

	_attack_confirming = true
	_attack_confirm_target_cell = _cursor_cell
	_attack_confirm_panel.show_attack_confirmation(
		attacker.code_name, target.code_name,
		int(breakdown["atk"]), int(breakdown["def"]),
		int(breakdown["phi"]), int(breakdown["phi_input"]),
		int(breakdown["damage"]),
		target.hp, int(breakdown["target_hp_after"])
	)


## Story 013（同 AC-U11 的去重紀律)— consumed once per frame from [method
## _process], never from [method _input] (see [member
## _attack_confirm_pending_press]'s own doc comment). No-op if [member
## _attack_confirming] is already false — e.g. a same-frame confirm-then-
## cancel race. Calls the EXISTING [method BattleController.click_tile] /
## [method _handle_click_tile_result] path at the frozen target cell captured
## when the panel opened ([member _attack_confirm_target_cell]) — this is the
## single authoritative write this story's whole ADR-0001 obligation exists to
## gate the TIMING of, not the call shape of (`click_tile()`/`_apply_attack()`
## themselves are unchanged — UX spec "不影響 battle_controller.gd 的公開介面").
func _apply_pending_attack_confirm() -> void:
	if not _attack_confirming:
		return
	_attack_confirming = false
	var cell: Vector2i = _attack_confirm_target_cell
	_attack_confirm_target_cell = Vector2i(-1, -1)
	_attack_confirm_panel.hide_panel()
	_handle_click_tile_result(_controller.click_tile(cell))


## Story 013 — cancel out of T2' back to T2 (attack target still visible),
## zero write (mirrors `P-N3` / [method _handle_card_confirm_cancel_transition]'s
## own shape — no [BattleController] call at all, since nothing was ever
## written while the panel was open).
func _handle_attack_confirm_cancel_transition() -> void:
	_attack_confirming = false
	_attack_confirm_target_cell = Vector2i(-1, -1)
	_attack_confirm_panel.hide_panel()


# "End my faction phase" — invoked via
# [signal BattleMenu.end_faction_phase_confirmed], connected in _ready() (see
# that connection, and _handle_battle_menu_pressed()'s neighboring doc
# comment for the full menu -> signal -> here path). This function is no
# longer reached by a direct keypress.
#
# History: originally (2026-08-27) bound directly to the project-level
# "battle_end_phase" input action (project.godot [input]: keyboard Escape,
# gamepad Right Action button — Xbox B / Sony Circle / Switch A), added
# alongside battle_confirm because the built-in ui_cancel this used to be
# bound to has no default gamepad binding, which would otherwise have left a
# gamepad-only player unable to ever hand the turn to the enemy. Story U-016
# (2026-09-24) removed that keypress dispatch in favor of the menu row above
# — the battle_end_phase action itself still exists in project.godot but now
# keeps zero bindings (see the "Story U-016" comment near
# _unhandled_input()'s battle_confirm handling, where the removed dispatch
# used to live).
#
# story-018-enemy-phase-stepped-playback.md: REWRITTEN from a single
# synchronous run_enemy_phase() call into a cross-frame loop over
# BattleController.step_enemy_phase() — see that method's own doc comment for
# why it, not run_enemy_phase(), is the entry point a presentation layer must
# drive (run_enemy_phase()'s signature and behavior are unchanged; the two
# are parallel drivers over the same shared per-unit rule, never calling each
# other). battle_controller.gd itself stays fully synchronous end to end (no
# await anywhere in step_enemy_phase()'s own call chain) — every await below
# is this function's own, never anything battle_controller.gd does.
#
# 🔴 PAUSE PLACEMENT (binds even though the flag itself is not implemented
# yet): ADR-0001 mechanism 二's deadlock detection requires
# authoritative_write_in_progress to never remain true across two consecutive
# _process frames. That flag has NO field anywhere in src/ today (see
# step_enemy_phase()'s own doc comment and this story's AC-E1 section) — but
# the pause point below must already sit on the correct side of that future
# check, not be retrofitted later. The await is placed STRICTLY BETWEEN two
# step_enemy_phase() calls, never inside one: each call commits and returns
# fully synchronously, so at the moment this function suspends, no
# authoritative write is or ever could be in progress. Whoever eventually
# builds the real flag does not need to re-derive this — the placement is
# already on the correct side of it.
#
# 🔴 CORRECTED 2026-10-13 — "That flag has NO field anywhere in src/
# today" (the PAUSE PLACEMENT paragraph above) is now FALSE. As of
# 2026-10-12 (stories 003b / 003c / 017) authoritative_write_in_progress is
# a real guarded read-only property on BattleState, internally a depth
# counter rather than a bool (ADR-0001, 2026-10-05 ruling on nested
# commits). Check it with a line-start anchor so this very comment cannot
# match itself:
#   grep -rn "^var authoritative_write_in_progress" src/ --include=*.gd
#
# This comment cited step_enemy_phase()'s doc comment in
# battle_controller.gd, which in turn cited CardPlaySession's. The ROOT was
# corrected first; these two citers were not, and stayed stale — found
# 2026-10-13 by the coordinator, both corrected under the same manager
# approval. Correcting a root claim does not propagate to the prose citing
# it; that is this project's most-registered failure shape.
#
# WHAT DOES NOT CHANGE: the pause placement reasoning above is unaffected
# and still correct — it was deliberately written to sit on the right side
# of a check that did not exist yet, and that check now exists. The await
# is still STRICTLY BETWEEN two step_enemy_phase() calls, so ADR-0001
# mechanism 二's requirement (the flag must never stay true across two
# consecutive _process frames) is satisfied by the real flag exactly as it
# would have been by the planned one. No code change is required here —
# only the premise sentence was stale.
#
# 🔴 Re-entrancy (AC-E4): the SAME phase-guard below is what keeps this
# function from double-driving the phase if it is invoked again while a
# stepped playback is already running. BattleController.phase() stays
# ENEMY_ACTING for the entire loop below (it only becomes PLAYER_INPUT on the
# call that finalizes the phase), so a second invocation arriving mid-playback
# sees ENEMY_ACTING (not PLAYER_INPUT) and falls straight through to the loop
# condition below, which is ALSO already false-for-a-second-caller in
# practice — see this function's 2026-09-24 doc update (Story U-016) for why
# the only real caller left after that story never fires twice concurrently.
# This is proven by a real test, not assumed by inspection — see
# tests/integration/ui/battle/battle_screen_enemy_phase_playback_test.gd
# (placed alongside this file's other integration tests under
# tests/integration/ui/battle/, mirroring src/ui/battle/ — this story's own
# text suggested tests/integration/gameplay/battle/, which does not match
# where this screen's existing integration tests already live) — because
# this function is now a coroutine: a second call starts running "at the
# same time" as the first from the caller's point of view, which is a
# meaningfully different situation from the old synchronous version this
# exact guard used to protect.
#
# 🔴 Host lifecycle (ADR-0001 line 262, cross-frame coroutine obligation):
# this coroutine's host is this BattleScreen node itself, whose lifetime
# spans the entire battle (it is this screen's own script, not a transient
# child panel) — not a temporary node that could be queue_free()'d out from
# under a suspended await. Every await below is followed by an
# is_instance_valid(self) guard before touching any member state, so a screen
# teardown mid-playback (e.g. returning to a menu) aborts the loop instead of
# resuming into a freed instance.
#
# 🔴 Story U-016 (2026-09-24) — this function's NAME and its PLAYER_INPUT-
# entry behavior are both kept byte-for-byte unchanged (existing spy
# subclasses in battle_screen_enemy_phase_playback_test.gd override this
# exact method name and existing call sites there always invoke it from
# PLAYER_INPUT — rewriting either would mean rewriting that whole test file,
# not a change this story's scope calls for). What changed is additive only:
# the top guard now also tolerates being invoked when phase() is ALREADY
# ENEMY_ACTING, skipping the (now redundant) end_faction_phase() call and
# going straight to the drain loop. This is what lets
# [signal BattleMenu.end_faction_phase_confirmed] connect DIRECTLY to this
# same method (see _ready()) without a second, duplicate copy of the loop
# below — BattleMenu._on_end_phase_row_pressed() already calls
# BattleController.end_faction_phase() itself before emitting that signal
# (see that method's own doc comment: "the ONE place that can correctly pick
# 'call the SAME driver _end_faction_phase_pressed() already uses'" — this IS
# that place). Calling this from any OTHER phase (FINISHED) still no-ops.
func _end_faction_phase_pressed() -> void:
	if _controller.phase() == BattleController.Phase.PLAYER_INPUT:
		_controller.end_faction_phase()
	elif _controller.phase() != BattleController.Phase.ENEMY_ACTING:
		return
	_diagnostic_enemy_acting_process_frame_count = 0
	_diagnostic_step_enemy_phase_call_count = 0

	while _controller.phase() == BattleController.Phase.ENEMY_ACTING:
		_controller.step_enemy_phase()
		_diagnostic_step_enemy_phase_call_count += 1
		# story-018: rebuild after EVERY step, not once at the end — otherwise
		# the cross-frame pause below has nothing new to show and the whole
		# point of stepping is lost. _refresh_view()'s own doc comment already
		# discloses the ~50-node rebuild cost per call; paying it once per
		# enemy step (not once per _process frame) is the same known,
		# deliberate trade-off this story's Implementation Note #4 calls for.
		_refresh_view()
		if _controller.phase() != BattleController.Phase.ENEMY_ACTING:
			return
		await get_tree().create_timer(ENEMY_STEP_PAUSE_SECONDS).timeout
		if not is_instance_valid(self):
			return


# Repositions/toggles the self-drawn cursor sprite based on current device
# authority — never native Control hover/focus, per the class doc comment.
#
# Also owns the preview's refresh gating. _refresh_view() rebuilds every
# piece, highlight and line node on the board, so calling it once per frame
# would free and re-create ~50 nodes every frame for no reason. Instead the
# resolved (cell, active) pair is compared against the pair _refresh_view()
# recorded the last time it ran, and a rebuild happens only when that pair
# actually changed.
#
# _cursor_active is the "cursor is nowhere" flag. Under mouse authority the
# pointer can sit off the board entirely, and that is a genuinely different
# state from "cursor is still on its last cell": the preview has to clear
# rather than keep showing a projection for a tile the player is no longer
# pointing at.
func _update_cursor_visual() -> void:
	# Story 009 — gate switched from this screen's own (now-retired)
	# DeviceAuthority tracker to CursorStateHost's equivalent query. Each
	# branch's BODY is unchanged: this one still independently recomputes the
	# cell from _last_mouse_window_pos (see _apply_mouse_target_if_authoritative()'s
	# own doc comment for why that duplication is the shared-helper pattern,
	# not the "two trackers" problem this story retires), and the else branch
	# already read CursorStateHost.get_current_target() before this change
	# (Story 008).
	if CursorStateHost.get_device_authority() == CursorTypes.Authority.MOUSE:
		var cell: Vector2i = _window_pos_to_cell(_last_mouse_window_pos)
		if BoardCoords.is_in_bounds(cell):
			_cursor_cell = cell
			_cursor_active = true
			_board_view.set_cursor(cell)
		else:
			_cursor_active = false
			_board_view.clear_cursor()
	else:
		# Story 008 unit 3b (point 4/4, AC-2) — _handle_directional() no
		# longer writes _cursor_cell (point 3/4, see that method's own doc
		# comment), so this branch can no longer assume _cursor_cell is
		# already current. Reads CursorStateHost's per-frame-arbitrated
		# target instead — safe here specifically because THIS screen's own
		# _process() runs at process_priority 100 (_init()'s own doc comment:
		# "the engine default priority (0) to 100"), which is exactly the
		# priority ADR-0005 mandates for 機制六⑥ "下游讀取方" callers of
		# get_current_target(). A null/non-BOARD_TILE target (e.g. transient
		# mid-handoff to card-play) leaves _cursor_cell at its last known
		# value rather than snapping to a decoded garbage cell.
		var target: CursorTarget = CursorStateHost.get_current_target()
		if target != null and target.surface == CursorTypes.SurfaceType.BOARD_TILE:
			_cursor_cell = CursorTypes.decode_tile(target.id, BoardCoords.BOARD_COLS)
		_cursor_active = true
		_board_view.set_cursor(_cursor_cell)

	if _cursor_cell != _rendered_cursor_cell or _cursor_active != _rendered_cursor_active:
		_refresh_view()


# Full redraw from BattleState — the cursor preview first, then pieces, then
# highlights for whatever is currently selected. Simpler and safer than
# incremental patching for a 13x6 board with 10 units: every signal
# BattleController emits (select/deselect/move/attack) triggers this, as does
# a cursor cell change (see _update_cursor_visual), so there is exactly one
# code path that can ever go stale.
func _refresh_view() -> void:
	# 游標預覽必須先算,因為棋子的血量數字要吃 hp_preview。
	#
	# 三種模式互斥,依序判定:
	#   A 移動預覽 —— 選了單位、游標停在它走得到的格(或它自己腳下)。
	#     線的兩端改從假設座標取,所以游標一移動,線就當場跟著甩過去。
	#     管理者的原話是「我無法得知如何移動才能增加角色能力值」——
	#     線會跟著游標動就是這句話的答案,只畫現況等於沒做。
	#   C 傷害預覽 —— 選了單位、游標停在打得到的敵人身上。
	#   B 其餘 —— 畫現況;游標停在有關係線的單位上時,順帶報它目前的加成。
	var positions: Dictionary[int, Vector2i] = _phi.positions()
	var links: Array[AffinityLink] = _phi.links()
	var selected: int = _controller.selected_unit()

	var line_positions: Dictionary[int, Vector2i] = positions
	var line_statuses: Array[AffinityLineStatus] = AffinityRules.board_lines(positions, links)
	var info_text: String = ""
	var preview_target_id: int = -1
	var preview_target_hp: int = -1

	var attack_target_id: int = -1
	if selected != -1 and _cursor_active:
		attack_target_id = _cursor_attack_target_id()

	if selected != -1 and _cursor_active and _is_move_preview_cell(selected):
		var hypo: Dictionary[int, Vector2i] = _phi.positions_with(selected, _cursor_cell)
		line_positions = hypo
		line_statuses = AffinityRules.board_lines(hypo, links)
		info_text = format_affinity_preview(
			AffinityRules.bonus_for(selected, positions, links),
			AffinityRules.bonus_for_at(selected, _cursor_cell, hypo, links)
		)
	elif attack_target_id != -1:
		# Φ 一律經由 _phi.phi() 取得,傷害本身一律經由 _state.preview_damage()
		# 取得 —— 兩者都是結算路徑(resolve_attack())內部呼叫的同一批函式,
		# 不是另外推導一次。呼叫點相同,是「畫面上的預覽數字不可能跟實際傷害
		# 對不上」的結構性保證 —— 這句話現在對 Φ、ATK、DEF 三個輸入都成立,
		# 不再只對 Φ 成立(2026-09-09 之前這裡曾直接呼叫 CombatRules.damage()
		# 重算一次,只有 Φ 走共用路徑,ATK/DEF 沒有)。
		var target: Unit = _state.unit_by_id(attack_target_id)
		var phi: int = _phi.phi(selected, attack_target_id)
		# 🔴 2026-10-12:preview_damage() 已遷移為回傳 [PreviewDamageResult]
		# (ADR-0001 契約型別,見 docs/architecture/query-result-scope-boundary-2026-10-12.md)。
		# 🔴 本筆【不】併入下方 move/attack/threat 那組 assert_same_version() 合併顯示核對。
		# 理由(實作者裁決,協調者核可):①assert_same_version() 的契約是「少於 2 筆恆成立」,
		# 而此處此刻只有這一筆 —— 三支疊圖查詢要等 selected != -1 分支才呼叫;②真要湊出
		# 可比對的 ≥2 筆,得把那三支的呼叫時機提前到這裡,等於為了一個檢查搬動既有控制流;
		# ③即使搬了,傷害預覽文字與三層高亮在語意上不是「同一次合併疊圖」—— 後三者疊在
		# 同一張棋盤上、彼此必須一致,而這筆是獨立產生的 info_text,沒有「彼此」可言。
		# 本分支內無 await / 權威寫入 / call_deferred,故它與下方三支「同屬這一次
		# _refresh_view() 執行」仍是結構保證。
		var damage_result: PreviewDamageResult = _state.preview_damage(selected, attack_target_id, phi)
		var damage: int = damage_result.damage
		preview_target_id = attack_target_id
		preview_target_hp = projected_hp(target.hp, damage)
		info_text = format_damage_preview(damage, target.hp, preview_target_hp)
	elif _cursor_active:
		var hovered: Unit = _state.unit_at(_cursor_cell)
		if hovered != null and _unit_has_link(hovered.id, links):
			info_text = format_affinity_current(
				AffinityRules.bonus_for(hovered.id, positions, links)
			)

	_info_label.text = info_text
	_board_view.set_affinity_lines(affinity_line_dicts(line_statuses, line_positions))

	# 只有「選取中的單位」與「游標指著的那一格」會顯示精確數字,其餘只有血條。
	# 理由是量出來的,不是偏好:五名我方單位開局全部直向並排在第 0 欄,
	# 每人都掛一組數字時,每個數字都壓在下一個人的頭上,整欄不可讀
	# (2026-08-28 截圖實測)。下棋要用的兩個數字反而是最讀不到的。
	# 綁在游標而非滑鼠 hover:游標由鍵盤/手把/滑鼠三種裝置共同驅動
	# (CursorStateHost),所以主機端沒有指標也一樣看得到。
	var focus_cell: Vector2i = _cursor_cell if _cursor_active else Vector2i(-1, -1)

	# HP 讀出對比度修復(design/art/hp-readout-contrast-fix.md 第二節,2026-09-23
	# 管理者裁決「讀法一:整條黑底一起變深」)。提前算出這個畫格的合法目標 id
	# 集合,讓下面 pieces 迴圈能一併帶出「是否為不合法目標」旗標交給
	# board_view.gd —— 這是複用 _controller.legal_targets() 同一份答案,不是
	# 另外重新判斷合法性。下方 Story U-013 既有的 card-play 高亮區塊改為直接
	# 重用這裡算好的 card_target_legal_ids,不再自己重複呼叫 legal_targets()
	# ——兩處必須讀同一份答案,不是各自問一次。
	# 2026-09-23 修正:原本的三元運算式 `x if cond else []` 讓 `else` 分支的
	# 裸 `[]` 把整個運算式的推論型別退化成未型別化 Array,賦值給
	# Array[int] 在 parse 期不會報錯、只在執行期炸(協調者實測 451 次
	# SCRIPT ERROR、35 支測試連帶變紅)。改成先宣告型別化空陣列、
	# 再用 if 覆寫,語意不變(_card_selecting_target 為真才取
	# legal_targets(),否則維持空陣列)。
	var card_target_legal_ids: Array[int] = []
	if _card_selecting_target:
		card_target_legal_ids = _controller.legal_targets()
	var card_target_legal_set: Dictionary = {}
	for legal_id: int in card_target_legal_ids:
		card_target_legal_set[legal_id] = true

	var pieces: Array[Dictionary] = []
	for unit: Unit in _state.units_of(Unit.Faction.PLAYER):
		pieces.append({
			"cell": _state.position_of(unit.id),
			"faction": "PLAYER",
			# Roster ids 1-5 are exactly the five player units in order, so
			# id-1 lines up with ALLY_SPRITE_PATHS' 0-4 index. Clamped
			# defensively in case the roster data ever changes shape.
			"sprite_index": clampi(unit.id - 1, 0, 4),
			"hp": unit.hp,
			"hp_max": unit.hp_max,
			"hp_preview": -1,
			"show_hp_text": unit.id == selected or _state.position_of(unit.id) == focus_cell,
			"card_target_illegal": (
				_card_selecting_target and not card_target_legal_set.has(unit.id)
			),
		})
	for unit: Unit in _state.units_of(Unit.Faction.ENEMY):
		pieces.append({
			"cell": _state.position_of(unit.id),
			"faction": "ENEMY",
			"sprite_index": 0,
			"hp": unit.hp,
			"hp_max": unit.hp_max,
			"hp_preview": preview_target_hp if unit.id == preview_target_id else -1,
			"show_hp_text": _state.position_of(unit.id) == focus_cell,
			"card_target_illegal": (
				_card_selecting_target and not card_target_legal_set.has(unit.id)
			),
		})
	_board_view.render_pieces(pieces)

	if selected != -1:
		var move_result: MoveTargetsResult = _controller.move_targets()
		var attack_result: AttackTargetsResult = _controller.attack_targets()
		var threat_result: ThreatTargetsResult = _controller.threat_targets()

		# ADR-0001 merged-display 版本核對
		# (docs/architecture/query-result-scope-boundary-2026-10-12.md):下面三層
		# 高亮是這三支查詢結果的合併顯示,ADR-0001 要求合併顯示前核對版本號一致。
		# _refresh_view() 單次執行內沒有 await、沒有權威寫入、也沒有
		# call_deferred(本檔案體內可 grep 驗證),所以三者「同版本」今天是結構
		# 保證,下面這個檢查理論上恆為 true —— 它守的是日後有人往這個函式裡加
		# await 或提交呼叫,而那件事今天沒有任何東西擋著。
		# 🔴 故意不用 assert() 守衛這個分支 —— coding-standards.md 已記載
		# assert() 失敗會中止呼叫端;_refresh_view() 雖然不回傳 enum,但中止會
		# 連帶跳過下面與這三支查詢無關的手牌列/狀態列重繪,所以改用
		# push_error() + 顯式 if/else,絕不中止函式。
		var versions_consistent: bool = QueryResult.assert_same_version(
			[move_result, attack_result, threat_result]
		)
		var any_stale: bool = (
			move_result.is_stale() or attack_result.is_stale() or threat_result.is_stale()
		)
		if not versions_consistent or any_stale:
			push_error(
				"merged-display 查詢結果版本不一致或已過期於 _refresh_view() 執行期間"
				+ " —— 本格跳過 move/attack/threat 高亮疊圖"
			)
			_board_view.set_move_highlights([])
			_board_view.set_threat_highlights([])
			_board_view.set_attack_highlights([])
		else:
			var move_cells: Array[Vector2i] = move_result.cells
			var attack_cells: Array[Vector2i] = attack_result.cells

			# 三層高亮刻意互斥,每一格最多只帶一種標記。這是純粹的呈現取捨
			# (哪一層畫哪些格),不是規則判斷 —— 三個查詢的答案都由
			# BattleController 決定,這裡只決定畫面怎麼排。
			#
			# 威脅範圍要扣掉三種格:
			#   1. move_cells —— 已經有藍色外框了,再疊黃斜線只會讓兩者都難認。
			#   2. attack_cells —— 已經有紅色角標了,那是更強的資訊(現在就打得到)。
			#   3. 我方單位所在格 —— threat_targets() 依設計回傳的是「射程涵蓋範圍」,
			#      包含友軍站的格;但畫面上在自己人身上標「打得到這裡」會被讀成
			#      「可以攻擊隊友」。這一格的排除只在呈現層做,查詢本身維持純幾何。
			var ally_cells: Array[Vector2i] = []
			for ally: Unit in _state.units_of(Unit.Faction.PLAYER):
				ally_cells.append(_state.position_of(ally.id))
			var threat_excluded: Array[Vector2i] = []
			threat_excluded.append_array(move_cells)
			threat_excluded.append_array(attack_cells)
			threat_excluded.append_array(ally_cells)

			_board_view.set_move_highlights(move_cells)
			_board_view.set_threat_highlights(
				cells_excluding(threat_result.cells, threat_excluded)
			)
			_board_view.set_attack_highlights(attack_cells)
	else:
		_board_view.set_move_highlights([])
		_board_view.set_threat_highlights([])
		_board_view.set_attack_highlights([])

	# Story U-013 (下半) — card-play target-selection 3-state highlight
	# overlay (board_view.gd's set_card_target_highlights(), already built by
	# the first half of this story; this is that method's first production
	# call site). Legal = every unit in _controller.legal_targets(); illegal =
	# every OTHER unit on the board (either faction); an empty tile is the
	# third, undrawn state — see that method's own doc comment.
	# 🔴 HP 對比度修復批次(2026-09-23)起,合法目標 id 陣列已在上面 pieces
	# 迴圈前算好(card_target_legal_ids),這裡直接重用,不再另外呼叫一次
	# _controller.legal_targets() —— 兩處是同一份答案。
	if _card_selecting_target:
		var unit_positions: Dictionary[int, Vector2i] = {}
		for player_unit: Unit in _state.units_of(Unit.Faction.PLAYER):
			unit_positions[player_unit.id] = _state.position_of(player_unit.id)
		for enemy_unit: Unit in _state.units_of(Unit.Faction.ENEMY):
			unit_positions[enemy_unit.id] = _state.position_of(enemy_unit.id)
		var target_partition: Dictionary = card_target_highlight_cells(
			card_target_legal_ids, unit_positions
		)
		_board_view.set_card_target_highlights(target_partition["legal"], target_partition["illegal"])
	else:
		_board_view.set_card_target_highlights([], [])

	# Story U-011 — Z1 手牌縮圖帶。_state.card_deck() is never null in this
	# slice (_ready() always builds one via _build_card_deck(), even for a
	# cleanly-empty card table — see that method's doc comment), but the null
	# check mirrors every other card_deck-optional call site in this project
	# ([method BattleState.has_pending_discard] etc.) rather than assuming it.
	var hand: Array[Card] = _state.card_deck().hand() if _state.card_deck() != null else []
	# Story U-013 — `expanded` now reflects S1 (_card_selecting_from_hand, see
	# that field's own doc comment) OR'd with S4 (Story U-015 — see below).
	# `card_faces` is left at its [] default: Z2/Z3's flavor-text/effect-summary
	# content needs the parsed CardText table — U-014 now stores this in
	# _card_flavor_texts, but wiring it into HandBar's own card_faces shape is
	# still out of scope for whichever story picks it up next: Z2 will render
	# correctly-shaped, correctly-selectable slots with blank Z3 text until
	# that happens.
	#
	# Story U-015 — `forced_discard` (the new last param) polls
	# BattleController.has_pending_discard() directly, the same query
	# _input()'s top-priority S4 branch and _handle_mouse_button()'s guard
	# both use — one source of truth, not a fourth screen-local mirror of it.
	# OR'd into `expanded` too: HandBar.render() would already enforce this
	# internally (see that method's own "forced_discard structurally implies
	# expanded" comment), but passing it explicitly here keeps this call site
	# honest about what state it is actually asking for, rather than relying
	# on a callee-side correction the reader would have to go find.
	_hand_bar.render(
		hand_bar_slot_kinds(hand),
		CardDeck.HAND_SIZE_LIMIT,
		availability_for(_controller.phase()),
		_card_selecting_from_hand or _controller.has_pending_discard(),
		[],
		_controller.has_pending_discard()
	)

	_update_status_label()
	_update_tile_info_panel()

	# 記錄這次畫的是哪一格 —— _update_cursor_visual() 的閘門靠這一對值判斷
	# 「游標真的變了嗎」,少了這兩行就會變成每畫格重建一次整個棋盤。
	_rendered_cursor_cell = _cursor_cell
	_rendered_cursor_active = _cursor_active


# True when the cursor is resting on a tile the selected unit could legally
# move to this turn, or on its own current tile ("stay put" is a real option
# and its affinity consequence is worth previewing too). Drives Mode A of
# _refresh_view(). Not static: it asks BattleController and BattleState what
# is legal rather than deciding anything itself.
func _is_move_preview_cell(selected: int) -> bool:
	if _cursor_cell == _state.position_of(selected):
		return true
	return _controller.move_targets().cells.has(_cursor_cell)


# Id of the enemy under the cursor that the selected unit can attack right
# now, or -1. Drives Mode C of _refresh_view(). The faction re-check is
# defence in depth: attack_targets() already only returns enemies, but a
# damage projection painted onto an ally would be a serious misread and this
# costs one comparison.
func _cursor_attack_target_id() -> int:
	if not _controller.attack_targets().cells.has(_cursor_cell):
		return -1
	var target: Unit = _state.unit_at(_cursor_cell)
	if target == null or target.faction != Unit.Faction.ENEMY:
		return -1
	return target.id


# True when unit_id appears on at least one link in the pairing table. Used
# by Mode B to stay quiet about units that have no relationships at all —
# unit 5 (戊) is deliberately unpaired, so reporting "好感度 +0" on him would
# imply a line exists that never will.
static func _unit_has_link(unit_id: int, links: Array[AffinityLink]) -> bool:
	for link: AffinityLink in links:
		if link.involves(unit_id):
			return true
	return false


func _update_status_label() -> void:
	var faction_text: String = Loc.localize(TEXT_FACTION_PLAYER) if _order.current_faction() == TurnOrder.Side.PLAYER else Loc.localize(TEXT_FACTION_ENEMY)
	_status_label.text = Loc.localize(TEXT_STATUS_FORMAT) % [_order.round_number(), faction_text]


## Story 012 (格位資訊面板) — writes [member _tile_info_panel_label] every
## [method _refresh_view] call. Gates on BOTH [member _cursor_active] AND
## [member _tile_info_cursor_valid] before showing anything resolved:
## [member _tile_info_cursor_valid] alone is not enough, because [method
## _apply_mouse_target_if_authoritative] simply returns (leaving
## [CursorStateHost]'s target at its last on-board value) the instant the
## mouse goes out of bounds — so the host's target can stay "valid" while the
## cursor is genuinely nowhere. [member _cursor_active] is this screen's own
## existing flag for exactly that "cursor is nowhere right now" case (see its
## own doc comment). Either being false means an explicit, distinct
## unresolved state — never the previous tile's leftover content (Player
## Fantasy's named failure mode "狀態轉換造成的資訊斷裂").
func _update_tile_info_panel() -> void:
	if not _cursor_active or not _tile_info_cursor_valid:
		_tile_info_panel_label.text = Loc.localize(TEXT_TILE_INFO_UNRESOLVED)
		return

	var terrain_char: String = _state.board.get_terrain(_cursor_cell)
	var cost: int = _state.board.get_move_cost(_cursor_cell)
	var blocks_sight: bool = _state.board.blocks_sight(_cursor_cell)
	var occupant: Unit = _state.unit_at(_cursor_cell)

	if occupant != null:
		_tile_info_panel_label.text = build_tile_info_text(
			terrain_char, cost, blocks_sight,
			true, occupant.faction, occupant.hp, occupant.hp_max,
			_controller.unit_action_state(occupant.id),
			occupant.min_range, occupant.max_range, occupant.mp
		)
	else:
		_tile_info_panel_label.text = build_tile_info_text(
			terrain_char, cost, blocks_sight,
			false, Unit.Faction.PLAYER, 0, 0, TurnOrder.ActionState.NOT_FOUND, 0, 0, 0
		)


## Story 012 — positions/sizes [member _tile_info_panel_bg] (and, via its
## [code]anchors_preset = 15[/code] fill in [code]BattleScreen.tscn[/code],
## [member _tile_info_panel_label] along with it) every time the window size
## changes. Calls the SAME [HudLayout] static functions
## [code]hud_layout_scaler.gd[/code] uses for the rest of [code]UILayer[/code]
## ([method HudLayout.safe_rect] / [method HudLayout.font_size] /
## [method HudLayout.status_label_rect]) rather than re-deriving any of that
## math — this project's registered "same formula, two implementations"
## failure mode — but is NOT added to [code]hud_layout_scaler.gd[/code]
## itself: this story's file lock (coordinator dispatch, 2026-10-15) is
## [code]battle_screen.gd[/code] + its own [code].tscn[/code] only. Flagged in
## the task report as a seam a follow-up pass may want to fold into that file.
##
## [b]The width fraction / line count constants below are this implementer's
## own placeholder judgment call, not a pixel-measured spike result[/b] like
## [constant HudLayout.STATUS_LABEL_WIDTH_FRACTION]'s own spike-backed
## constant — disclosed rather than presented as measured.
const _TILE_INFO_PANEL_WIDTH_FRACTION: float = 0.4
const _TILE_INFO_PANEL_LINE_COUNT: int = 8
const _TILE_INFO_PANEL_LINE_HEIGHT_MULTIPLIER: float = 1.2
const _TILE_INFO_PANEL_PADDING_MULTIPLIER: float = 0.8

func _apply_tile_info_panel_layout() -> void:
	var window_size: Vector2i = get_window().size
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var status: Rect2 = HudLayout.status_label_rect(window_size)
	var fpx: float = float(HudLayout.font_size(window_size))
	var gap: float = fpx
	var width: float = safe.size.x * _TILE_INFO_PANEL_WIDTH_FRACTION
	var height: float = fpx * (
		_TILE_INFO_PANEL_LINE_HEIGHT_MULTIPLIER * _TILE_INFO_PANEL_LINE_COUNT
		+ _TILE_INFO_PANEL_PADDING_MULTIPLIER
	)
	var left: float = safe.position.x + safe.size.x - width
	var top: float = status.position.y + status.size.y + gap

	_tile_info_panel_bg.offset_left = left
	_tile_info_panel_bg.offset_top = top
	_tile_info_panel_bg.offset_right = left + width
	_tile_info_panel_bg.offset_bottom = top + height

	_tile_info_panel_label.add_theme_font_override(&"font", HudLayoutScaler.HUD_FONT)
	_tile_info_panel_label.add_theme_font_size_override(&"font_size", int(fpx))


func _on_battle_ended(outcome: BattleState.Outcome) -> void:
	_result_label.visible = true
	_result_label.text = Loc.localize(TEXT_RESULT_VICTORY) if outcome == BattleState.Outcome.VICTORY else Loc.localize(TEXT_RESULT_DEFEAT)


## story-u016-unbind-end-phase-and-hint-bar.md (AC-M16) — see
## [member _diagnostic_last_menu_rejection_result]'s own doc comment for what
## this does and does not prove.
func _on_battle_menu_open_rejected(result: BattleMenu.OpenResult, message: String) -> void:
	_diagnostic_last_menu_rejection_result = result
	_diagnostic_last_menu_rejection_message = message
