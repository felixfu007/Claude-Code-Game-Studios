## relation-minimap story-001 (design/ux/relation-minimap.md sections 3-5, 7).
## Read-only overlay: five fixed pentagon nodes + every relation line.
##
## 🔴 Stateless w.r.t. affinity: it never calls AffinityPhiProvider/AffinityRules.
## [method set_lines] receives the SAME [AffinityLineStatus] array
## BattleScreen._refresh_view() already feeds to the board lines (single
## source). It keeps that array and which ids are alive, nothing else.
##
## Not-colour-only (AC-5): POSITIVE = solid line + "+"; NEGATIVE = solid line
## + "-"; NEUTRAL (not in force) = faint dashed line + "0". No strength number
## (manager ruling 2026-10-28: amp is always 1).
## Dead character: node drawn grey + localized "dead" tag, its lines are
## skipped (statuses never contain them anyway). 「暫行」: spec s4 says the same;
## "-" is ASCII because Cubic 11 coverage of U+2212 is unverified.
class_name RelationMinimap
extends Control

const NAME_KEY_FORMAT: String = "character.name.%d"
const TEXT_TITLE: StringName = &"battle.hud.relation_map_title"
const TEXT_DEAD: StringName = &"battle.hud.relation_map_dead"
const ROSTER_IDS: Array[int] = [1, 2, 3, 4, 5]
const SYMBOL_POSITIVE: String = "+"
const SYMBOL_NEGATIVE: String = "-"
const SYMBOL_NEUTRAL: String = "0"

const COLOR_BG: Color = Color(0.05, 0.05, 0.08, 0.72)
const COLOR_POSITIVE: Color = Color(0.35, 0.85, 0.45, 1.0)
const COLOR_NEGATIVE: Color = Color(0.9, 0.3, 0.3, 1.0)
const COLOR_NEUTRAL: Color = Color(0.6, 0.6, 0.6, 0.45)
const COLOR_NODE: Color = Color(0.9, 0.9, 0.9, 1.0)
const COLOR_DEAD: Color = Color(0.45, 0.45, 0.45, 1.0)

var _statuses: Array[AffinityLineStatus] = []
var _alive_ids: Array[int] = []
var _font: Font = null
var _font_size: int = 11


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Setter for styling inputs (font + size) -- presentation only.
func configure(font: Font, font_size_px: int) -> void:
	_font = font
	_font_size = font_size_px
	queue_redraw()


## Single-source entry point. [param statuses] is the array BattleScreen already
## computed; [param alive_ids] are roster ids currently on the board.
func set_lines(statuses: Array[AffinityLineStatus], alive_ids: Array[int]) -> void:
	_statuses = statuses
	_alive_ids = alive_ids
	if visible:
		queue_redraw()


func set_open(open: bool) -> void:
	visible = open
	if open:
		queue_redraw()


## Drawn lines and their state, for tests: {"a","b": roster ids, "state": AffinityLineStatus.State}.
func diagnostic_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: AffinityLineStatus in _statuses:
		out.append({"a": s.unit_id, "b": s.partner_id, "state": s.state})
	return out


## Fixed pentagon slot for roster id 1..5, inside [param area].
static func node_position(roster_id: int, area: Rect2) -> Vector2:
	var center: Vector2 = area.position + area.size / 2.0
	var radius: float = minf(area.size.x, area.size.y) * 0.32
	var angle: float = -PI / 2.0 + TAU * float(roster_id - 1) / 5.0
	return center + Vector2(cos(angle), sin(angle)) * radius


static func symbol_for(state: AffinityLineStatus.State) -> String:
	match state:
		AffinityLineStatus.State.POSITIVE:
			return SYMBOL_POSITIVE
		AffinityLineStatus.State.NEGATIVE:
			return SYMBOL_NEGATIVE
	return SYMBOL_NEUTRAL


func _draw() -> void:
	if _font == null:
		return
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(area, COLOR_BG)
	draw_string(_font, Vector2(4, _font_size), Loc.localize(TEXT_TITLE), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, COLOR_NODE)
	var body: Rect2 = Rect2(Vector2(0, _font_size * 1.5), size - Vector2(0, _font_size * 1.5))
	var width: float = maxf(1.0, float(_font_size) / 6.0)
	for s: AffinityLineStatus in _statuses:
		if s.unit_id not in ROSTER_IDS or s.partner_id not in ROSTER_IDS:
			continue
		var from: Vector2 = node_position(s.unit_id, body)
		var to: Vector2 = node_position(s.partner_id, body)
		var color: Color = _color_for(s.state)
		if s.state == AffinityLineStatus.State.NEUTRAL:
			draw_dashed_line(from, to, color, width, width * 3.0)
		else:
			draw_line(from, to, color, width)
		var mid: Vector2 = (from + to) / 2.0
		draw_string(_font, mid - Vector2(_font_size * 0.25, -_font_size * 0.35), symbol_for(s.state),
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color.lightened(0.2))
	for id: int in ROSTER_IDS:
		var p: Vector2 = node_position(id, body)
		var alive: bool = id in _alive_ids
		var color: Color = COLOR_NODE if alive else COLOR_DEAD
		draw_circle(p, _font_size * 0.4, color)
		var label: String = Loc.localize(StringName(NAME_KEY_FORMAT % id))
		if not alive:
			label += Loc.localize(TEXT_DEAD)
		draw_string(_font, p + Vector2(-_font_size * 1.0, -_font_size * 0.7), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)


static func _color_for(state: AffinityLineStatus.State) -> Color:
	match state:
		AffinityLineStatus.State.POSITIVE:
			return COLOR_POSITIVE
		AffinityLineStatus.State.NEGATIVE:
			return COLOR_NEGATIVE
	return COLOR_NEUTRAL
