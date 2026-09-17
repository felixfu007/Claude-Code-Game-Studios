## Z1 手牌縮圖帶 — Story U-011(`production/epics/card-play-interface/story-u011-hand-bar-thumbnails.md`)。
## 常駐於玩家回合期間,顯示「有幾張、各是什麼類別」,並讓 S0(常態)/S5(不可用)/
## S7(空手牌)三態在灰階下仍可互相區分(`design/ux/skill-card-play.md` States &
## Variants,`P-F3` 無例外)。
##
## [b]This node owns zero game state and makes zero rule decisions[/b] — mirrors
## [BoardView]'s discipline (per [code].claude/rules/ui-code.md[/code], "UI must
## NEVER own or directly modify game state — display only"): it never
## references [Card] / [CardDeck] / [BattleController], and defines its own
## display-only vocabulary ([enum SlotKind], [enum Availability]) rather than
## the gameplay [enum Card.Category] it is ultimately fed from.
## [code]battle_screen.gd[/code] — the one class allowed to know both sides,
## exactly as its own doc comment already establishes for [BoardView] — is
## where the [Card.Category] -> [enum SlotKind] mapping lives
## ([code]hand_bar_slot_kind_for()[/code]), mirroring that file's existing
## [code]line_tone_for()[/code] pattern precisely.
##
## [b]U-012 / U-015 will keep extending this same file[/b] (EPIC.md's
## serialization-point table: [code]hand_bar.gd[/code] is the file U-011/
## U-012/U-015 all grow, not three separate files) — Z2 expand/Z3 detail/S1
## selection (U-012) and S4 forced-discard (U-015) are explicitly out of scope
## here.
##
## [b]Placeholder art, not final art[/b] (Story U-011 Out of Scope: card face
## pixel size/color count/outline/font is `art-director` + `/art-bible`'s job,
## UX-3 — "不得沿用 128×128 立繪"). Every slot is composed from plain engine
## primitives ([Panel] + [StyleBoxFlat], [ColorRect]) — no custom [code]_draw()[/code]
## anywhere in this file, matching [BoardView]'s own "compose from primitive
## nodes" convention rather than introducing a new raw-draw technique into this
## codebase. 甲(temporary modifier) is an unrotated square outline; 丙
## (permanent write) is the exact same [Panel] rotated 45° — one visual
## technique reused for both the shape channel and the icon-mark channel
## (`Component Inventory`: 類別靠「形狀+圖示」區分,非顏色). This is a
## deliberate, disclosed judgment call about placeholder geometry, not a design
## decision handed down by any spec — the spec only fixes the slot's overall
## [i]size[/i] (`Layout Zones` Z1 row), never its shape vocabulary.
##
## [b]Z1 geometry is composed entirely from existing [HudLayout] functions[/b]
## ([method HudLayout.safe_rect], [method HudLayout.font_size],
## [method HudLayout.controls_hint_bg_rect]) — per this project's registered
## failure pattern (the same formula re-implemented twice, only agreeing
## "today"), [method slot_bar_rect] never re-derives any of those three
## functions' own math; it only combines their already-computed results with
## the Z1-specific arithmetic the UX spec defines (bar width/height in fpx
## multiples, bottom edge pinned half an fpx above the control-hint bar's top
## edge — EPIC.md 陷阱十一: "Z1 必須在操作提示橫條上方,不是螢幕底部").
##
## [b]"決定" vs "套用" split[/b] (`.claude/docs/coding-standards.md`'s
## headless-UI-testing rule, EPIC.md 陷阱十三): every [code]diagnostic_*[/code]
## getter below is a pure state read, verifiable headless without a real
## window; the actual pixel outcome (are the three S5 channels, or the two
## category shapes, genuinely visually distinguishable) can only be confirmed
## from a real windowed capture — see
## [code]production/qa/evidence/story-u011-hand-bar-evidence.md[/code].
class_name HandBar
extends Control

## Which of [Card]'s two MVP categories a filled slot represents — this
## project's own display vocabulary, not [enum Card.Category] itself (see the
## class doc comment). [code]battle_screen.gd[/code]'s
## [code]hand_bar_slot_kind_for()[/code] is the sole mapping point.
enum SlotKind { TEMPORARY_MODIFIER, PERMANENT_WRITE }

## Whether the whole bar is currently usable. [constant LOCKED] covers S5
## (enemy turn) — see [code]battle_screen.gd[/code]'s
## [code]availability_for()[/code] for exactly which
## [enum BattleController.Phase] values map to which value here (a
## 2026-09-17 coordinator ruling, not decided by this file).
enum Availability { NORMAL, LOCKED }

## Placeholder shape vocabulary for a filled slot's category — see the class
## doc comment's "placeholder art, not final art" note.
enum IconShape { SQUARE, DIAMOND }

const HUD_FONT: FontFile = preload("res://assets/fonts/Cubic_11.ttf")

## Z1 `Layout Zones` row, verbatim: "單卡 2×3 fpx,間距 0.5 fpx(合計 12 fpx 寬)".
const SLOT_WIDTH_FPX_MULTIPLIER: float = 2.0
const SLOT_HEIGHT_FPX_MULTIPLIER: float = 3.0
const SLOT_GAP_FPX_MULTIPLIER: float = 0.5

## Z1 `Layout Zones` row, verbatim: "下緣 = 操作提示橫條上緣再往上 0.5 fpx".
const BAR_BOTTOM_MARGIN_FPX_MULTIPLIER: float = 0.5

## Count-label geometry — not a spec number, this file's own placeholder
## layout judgment (the spec only fixes the card-slot area itself; see the
## class doc comment).
const COUNT_LABEL_WIDTH_FPX_MULTIPLIER: float = 4.0
const COUNT_LABEL_GAP_FPX_MULTIPLIER: float = 0.5

## Lock-glyph / unavailable-caption geometry — same "this file's own
## placeholder judgment" caveat as the count-label constants above. Both sit
## ABOVE the slot row (negative local Y), which only ever grows the bar's
## visual footprint away from [method HudLayout.controls_hint_bg_rect] — never
## toward it — so EPIC.md 陷阱十一's "must stay above the hint bar" constraint
## cannot be violated by adding this row.
const CAPTION_HEIGHT_FPX_MULTIPLIER: float = 1.5
const CAPTION_GAP_FPX_MULTIPLIER: float = 0.3
const LOCK_GLYPH_SIZE_FPX_MULTIPLIER: float = 1.2
const LOCK_GLYPH_GAP_FPX_MULTIPLIER: float = 0.3

## Icon-mark (category-shape child inside a filled slot) geometry.
const ICON_MARK_SIZE_FPX_MULTIPLIER: float = 0.7
const ICON_MARK_MARGIN_FPX_MULTIPLIER: float = 0.25

## S5's "降對比" channel — a multiplier applied directly to each element's OWN
## alpha (slot borders, icon marks, the count label's font colour), never to
## [member CanvasItem.modulate] / [member CanvasItem.self_modulate]. 🔴 That
## exclusion is deliberate, not stylistic: `tests/unit/cursor/
## cursor_modulate_alpha_single_writer_test.gd` enforces ADR-0005 R6-8 —
## [code]modulate.a[/code] anywhere under [code]res://src[/code] must have
## exactly one writer, [code]SelfDrawnReclaimCursor[/code], because
## [member CanvasItem.modulate] is a PER-NODE property two independent
## systems could never safely share even by coincidence. A first draft of
## this file wrote [code]modulate.a = ...[/code] here and that governance
## test caught it immediately (2026-09-17) — dimming this bar's own child
## element colours achieves the same "降對比" channel without touching a
## property this project has reserved exclusively for the cursor system.
## One of S5's three non-color channels (`States & Variants`); the other two
## are the lock glyph and [member _unavailable_label]'s caption.
const LOCKED_DIM_FACTOR: float = 0.4

## Slot outline colour. Deliberately the SAME colour for every category and
## for the empty case — per `Component Inventory` ("類別...靠形狀+圖示區分,
## 非顏色", `P-F3` 無例外), only alpha (filled vs empty) and shape/rotation
## (甲 vs 丙) may differ; hue never carries meaning here.
const SLOT_OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0)
const FILLED_SLOT_BORDER_ALPHA: float = 0.9
const EMPTY_SLOT_BORDER_ALPHA: float = 0.3

const TEXT_COUNT_FORMAT: String = "%d/%d"
## S5 caption text — one of its three non-color channels. Centralized as a
## constant per [code].claude/rules/ui-code.md[/code]'s "all UI text must go
## through the localization system, no hardcoded strings" rule, matching
## [code]battle_screen.gd[/code]'s existing [code]TEXT_*[/code] convention
## (this project has no localization system yet — building one is out of
## scope here, exactly as that file's own doc comment already states for its
## own [code]TEXT_*[/code] block).
const TEXT_UNAVAILABLE: String = "不可用"

@onready var _count_label: Label = $CountLabel
@onready var _unavailable_label: Label = $UnavailableLabel

## Slot [Panel] nodes currently built by [method _rebuild_slots] — cleared and
## rebuilt on every [method render] call, mirroring [method BoardView._clear_children]'s
## "one throwaway subtree per render" convention.
var _slot_nodes: Array[Panel] = []

## The lock glyph is two small [ColorRect]s (body + shackle bridge) built once
## lazily and toggled via [member CanvasItem.visible] — unlike the slots, its
## shape never depends on render() inputs, so it does not need to be rebuilt
## every call.
var _lock_glyph: Control = null

var _slot_kinds: Array[SlotKind] = []
var _max_slots: int = 0
var _availability: Availability = Availability.NORMAL


func _ready() -> void:
	_ensure_lock_glyph()
	_apply_layout()
	get_window().size_changed.connect(_apply_layout)


## Redraws the entire bar from [param slot_kinds] (one entry per card
## currently in hand, in the same order [method CardDeck.hand] returned them),
## [param max_slots] (the caller's [constant CardDeck.HAND_SIZE_LIMIT] — never
## hardcoded here, see the class doc comment on why this file has zero
## [CardDeck] dependency), and [param availability]. Slots
## [code]0..slot_kinds.size()-1[/code] render filled (icon per category);
## the remaining [code]slot_kinds.size()..max_slots-1[/code] render as an
## empty outline — this is S7's definition when [param slot_kinds] is empty
## (AC-U4 前半: "空槽輪廓與 0/5").
func render(slot_kinds: Array[SlotKind], max_slots: int, availability: Availability) -> void:
	_slot_kinds = slot_kinds.duplicate()
	_max_slots = maxi(0, max_slots)
	_availability = availability

	_rebuild_slots()
	_count_label.text = count_text(_slot_kinds.size(), _max_slots)
	_count_label.add_theme_color_override(&"font_color", Color(1.0, 1.0, 1.0, _current_dim_factor()))
	_unavailable_label.text = TEXT_UNAVAILABLE
	_unavailable_label.visible = availability == Availability.LOCKED
	_ensure_lock_glyph()
	_lock_glyph.visible = availability == Availability.LOCKED

	_apply_layout()


# ─── diagnostic_* — headless-testable "decision" surface (陷阱十三) ─────────


## True if slot [param index] is currently rendered filled (has a card) —
## i.e. [code]index < 目前手牌張數[/code]. Out-of-range [param index] (>=
## [method diagnostic_max_slots]) is meaningless and returns false.
func diagnostic_slot_is_filled(index: int) -> bool:
	return index < _slot_kinds.size()


## Number of filled slots — always equal to the [param slot_kinds] array size
## passed to the most recent [method render] call.
func diagnostic_slot_count() -> int:
	return _slot_kinds.size()


## The most recent [method render] call's [param max_slots].
func diagnostic_max_slots() -> int:
	return _max_slots


## The most recent [method render] call's [param availability].
func diagnostic_availability() -> Availability:
	return _availability


## True while the lock glyph (one of S5's three non-color channels) is
## visible.
func diagnostic_lock_glyph_visible() -> bool:
	return _lock_glyph != null and _lock_glyph.visible


## True while [member _unavailable_label]'s caption (a second S5 channel) is
## visible.
func diagnostic_caption_visible() -> bool:
	return _unavailable_label.visible


## Current dim factor (1.0 normal, [constant LOCKED_DIM_FACTOR] when locked)
## — the third S5 channel ("降對比"), applied directly to element alpha
## rather than [member CanvasItem.modulate] (see [constant LOCKED_DIM_FACTOR]'s
## own doc comment for why).
func diagnostic_dim_factor() -> float:
	return _current_dim_factor()


## Exact text currently shown by the count label — lets a test assert the
## label actually reflects the [param slot_kinds] array [method render] was
## given, not merely that SOME render happened.
func diagnostic_count_label_text() -> String:
	return _count_label.text


# ─── pure static functions — geometry/vocabulary, no node needed ───────────


## Placeholder shape vocabulary for [param kind] — see the class doc comment.
## Distinct return values for the two categories is the whole point this
## function exists to prove (white-box groundwork for U-012's AC-U6, per this
## story's own Test Evidence section).
static func icon_shape_for(kind: SlotKind) -> IconShape:
	match kind:
		SlotKind.PERMANENT_WRITE:
			return IconShape.DIAMOND
		_:
			return IconShape.SQUARE


## Formats the [constant TEXT_COUNT_FORMAT] "n/max" readout.
static func count_text(count: int, max_slots: int) -> String:
	return TEXT_COUNT_FORMAT % [count, max_slots]


## Z1's card-slot rect for [param window_size] at [param max_slots] slots —
## see the class doc comment for why this composes [HudLayout]'s existing
## functions rather than re-deriving any of their math. Horizontally centered
## in [method HudLayout.safe_rect]; bottom edge sits
## [constant BAR_BOTTOM_MARGIN_FPX_MULTIPLIER] fpx above
## [method HudLayout.controls_hint_bg_rect]'s top edge (EPIC.md 陷阱十一).
static func slot_bar_rect(window_size: Vector2i, max_slots: int) -> Rect2:
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var fpx: float = float(HudLayout.font_size(window_size))
	var hint_bg: Rect2 = HudLayout.controls_hint_bg_rect(window_size)

	var width: float = _slots_total_width_fpx(max_slots) * fpx
	var height: float = SLOT_HEIGHT_FPX_MULTIPLIER * fpx
	var margin: float = BAR_BOTTOM_MARGIN_FPX_MULTIPLIER * fpx

	var left: float = safe.position.x + (safe.size.x - width) / 2.0
	var bottom: float = hint_bg.position.y - margin
	var top: float = bottom - height
	return Rect2(Vector2(left, top), Vector2(width, height))


## Individual slot [param index]'s rect, in the same local space
## [method slot_bar_rect]'s returned rect's top-left corner would map to
## (0,0) — i.e. this is what a caller adds to [method slot_bar_rect]'s
## [code]position[/code] to get a window-space rect, and exactly what
## [method _position_slots] assigns to each slot [Panel]'s own
## [code]position[/code]/[code]size[/code] (which are already relative to
## this control's own top-left, since this control's own [code]position[/code]
## is set from [method slot_bar_rect] in [method _apply_layout]).
static func slot_rect(index: int, window_size: Vector2i) -> Rect2:
	var fpx: float = float(HudLayout.font_size(window_size))
	var slot_w: float = SLOT_WIDTH_FPX_MULTIPLIER * fpx
	var slot_h: float = SLOT_HEIGHT_FPX_MULTIPLIER * fpx
	var gap: float = SLOT_GAP_FPX_MULTIPLIER * fpx
	return Rect2(Vector2(float(index) * (slot_w + gap), 0.0), Vector2(slot_w, slot_h))


## Total slot-row width in fpx multiples for [param max_slots] slots —
## [code]max_slots[/code] card widths plus [code]max_slots - 1[/code] gaps.
## At [param max_slots] = 5 this is exactly 12 fpx, matching the spec's stated
## total ("合計 12 fpx 寬") — but the formula itself is not hardcoded to 5, so
## it stays correct if [constant CardDeck.HAND_SIZE_LIMIT] is ever retuned by
## a future ruling.
static func _slots_total_width_fpx(max_slots: int) -> float:
	if max_slots <= 0:
		return 0.0
	var gap_count: int = max_slots - 1
	return SLOT_WIDTH_FPX_MULTIPLIER * float(max_slots) + SLOT_GAP_FPX_MULTIPLIER * float(gap_count)


# ─── node mutation — never called from a pure/static context ──────────────


# Applies HandBar's own rect ([method slot_bar_rect]) to this Control, then
# repositions every child that depends on window size / _max_slots. Called
# from _ready() (before the first real render(), using whatever _max_slots
# currently is — 0 by default, a harmless zero-width rect since no slot
# children exist yet) and again at the end of every render() call (the point
# _max_slots first becomes a real value, and the point most likely to
# coincide with a resize in a live game).
func _apply_layout() -> void:
	var window_size: Vector2i = get_window().size
	var rect: Rect2 = slot_bar_rect(window_size, _max_slots)
	position = rect.position
	size = rect.size

	var fpx: float = float(HudLayout.font_size(window_size))
	_position_slots(window_size, fpx)
	_position_count_label(fpx)
	_position_caption_and_lock_glyph(fpx)


func _position_slots(window_size: Vector2i, fpx: float) -> void:
	for i in range(_slot_nodes.size()):
		var panel: Panel = _slot_nodes[i]
		var r: Rect2 = slot_rect(i, window_size)
		panel.position = r.position
		panel.size = r.size
		panel.pivot_offset = panel.size / 2.0

		var filled: bool = i < _slot_kinds.size()
		var is_diamond: bool = filled and icon_shape_for(_slot_kinds[i]) == IconShape.DIAMOND
		panel.rotation_degrees = 45.0 if is_diamond else 0.0

		if panel.get_child_count() > 0:
			var icon_mark: ColorRect = panel.get_child(0)
			var icon_size: float = ICON_MARK_SIZE_FPX_MULTIPLIER * fpx
			var icon_margin: float = ICON_MARK_MARGIN_FPX_MULTIPLIER * fpx
			icon_mark.size = Vector2(icon_size, icon_size)
			icon_mark.position = Vector2(icon_margin, icon_margin)


func _position_count_label(fpx: float) -> void:
	var slots_width: float = _slots_total_width_fpx(_max_slots) * fpx
	var gap: float = COUNT_LABEL_GAP_FPX_MULTIPLIER * fpx
	var slot_h: float = SLOT_HEIGHT_FPX_MULTIPLIER * fpx

	_count_label.position = Vector2(slots_width + gap, 0.0)
	_count_label.size = Vector2(COUNT_LABEL_WIDTH_FPX_MULTIPLIER * fpx, slot_h)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_override(&"font", HUD_FONT)
	_count_label.add_theme_font_size_override(&"font_size", int(fpx))


func _position_caption_and_lock_glyph(fpx: float) -> void:
	var caption_h: float = CAPTION_HEIGHT_FPX_MULTIPLIER * fpx
	var caption_gap: float = CAPTION_GAP_FPX_MULTIPLIER * fpx
	var glyph_size: float = LOCK_GLYPH_SIZE_FPX_MULTIPLIER * fpx
	var glyph_gap: float = LOCK_GLYPH_GAP_FPX_MULTIPLIER * fpx

	var caption_top: float = -(caption_gap + caption_h)
	_unavailable_label.position = Vector2(0.0, caption_top)
	_unavailable_label.size = Vector2(_slots_total_width_fpx(_max_slots) * fpx, caption_h)
	_unavailable_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unavailable_label.add_theme_font_override(&"font", HUD_FONT)
	_unavailable_label.add_theme_font_size_override(&"font_size", int(fpx))

	if _lock_glyph != null:
		_lock_glyph.size = Vector2(glyph_size, glyph_size)
		_lock_glyph.position = Vector2(-(glyph_size + glyph_gap), caption_top)


# Clears and rebuilds _slot_nodes for the current _max_slots / _slot_kinds —
# same "one throwaway subtree per render" shape as BoardView's render_*()
# methods. A filled slot gets one ColorRect icon-mark child (index 0); an
# empty slot gets none — that child's presence/absence is itself a third,
# non-color cue separating "empty" from "filled" beyond the border alpha
# difference.
func _rebuild_slots() -> void:
	for panel: Panel in _slot_nodes:
		remove_child(panel)
		panel.free()
	_slot_nodes.clear()

	for i in range(_max_slots):
		var panel: Panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override(&"panel", _slot_style(i))
		add_child(panel)
		_slot_nodes.append(panel)

		if i < _slot_kinds.size():
			var icon_mark: ColorRect = ColorRect.new()
			icon_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_mark.color = Color(
				SLOT_OUTLINE_COLOR.r, SLOT_OUTLINE_COLOR.g, SLOT_OUTLINE_COLOR.b,
				FILLED_SLOT_BORDER_ALPHA * _current_dim_factor()
			)
			panel.add_child(icon_mark)


# S5's "降對比" multiplier — see LOCKED_DIM_FACTOR's own doc comment for why
# this is applied to individual element alpha rather than
# CanvasItem.modulate/self_modulate.
func _current_dim_factor() -> float:
	return LOCKED_DIM_FACTOR if _availability == Availability.LOCKED else 1.0


# Outline-only StyleBoxFlat for slot `index` — transparent fill, border alpha
# is the sole difference between a filled and an empty slot's OWN box (the
# icon-mark child is the other, see _rebuild_slots()). Hue never differs
# (SLOT_OUTLINE_COLOR is the same white for every case) — only alpha and,
# for filled slots, the panel's rotation (see _position_slots()). Alpha is
# further scaled by _current_dim_factor() for S5's "降對比" channel.
func _slot_style(index: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(1)
	var filled: bool = index < _slot_kinds.size()
	var base_alpha: float = FILLED_SLOT_BORDER_ALPHA if filled else EMPTY_SLOT_BORDER_ALPHA
	style.border_color = Color(
		SLOT_OUTLINE_COLOR.r, SLOT_OUTLINE_COLOR.g, SLOT_OUTLINE_COLOR.b,
		base_alpha * _current_dim_factor()
	)
	return style


# Builds the lock glyph once (a body ColorRect + a thinner "shackle" ColorRect
# bridging its top edge — a placeholder padlock silhouette, deliberately a
# different shape from either card-category icon mark). Idempotent: a second
# call is a no-op if _lock_glyph already exists, since its shape never depends
# on render() inputs (only its .visible toggles, in render()).
func _ensure_lock_glyph() -> void:
	if _lock_glyph != null:
		return
	var root: Control = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false

	var body: ColorRect = ColorRect.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.color = SLOT_OUTLINE_COLOR
	body.anchor_top = 0.4
	body.anchor_bottom = 1.0
	body.anchor_left = 0.0
	body.anchor_right = 1.0
	root.add_child(body)

	var shackle: ColorRect = ColorRect.new()
	shackle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shackle.color = SLOT_OUTLINE_COLOR
	shackle.anchor_top = 0.0
	shackle.anchor_bottom = 0.4
	shackle.anchor_left = 0.3
	shackle.anchor_right = 0.7
	root.add_child(shackle)

	add_child(root)
	_lock_glyph = root
