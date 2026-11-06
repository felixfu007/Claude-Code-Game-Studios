## relation-minimap story-001 (design/ux/relation-minimap.md sections 3-5, 7).
## Read-only overlay: five fixed pentagon nodes + every relation line.
##
## 🔴 Stateless w.r.t. affinity: it never calls AffinityPhiProvider/AffinityRules.
## [method set_lines] receives the SAME [AffinityLineStatus] array
## BattleScreen._refresh_view() already feeds to the board lines (single
## source). It keeps that array and which ids are alive, nothing else.
##
## Not-colour-only (AC-5, story-002): shape = the relation (solid / zigzag), colour
## + midpoint plaque = the effect. Every relation is drawn, including zero-effect
## ones (node colour at ZERO_EFFECT_ALPHA, no plaque, no dashes, no "0").
## Shape comes from BattleScreen.line_shape_for, tone/symbol from
## BattleScreen.line_style_for (single source with the board, AC-P7); colours
## are BoardView's own constants (R2). No strength number (manager ruling
## 2026-10-28: amp is always 1). The word for the relation itself is not shown
## here (no detail area in this story).
## Dead character: node drawn grey + localized "dead" tag, its lines are
## skipped (statuses never contain them anyway).
class_name RelationMinimap
extends Control

const NAME_KEY_FORMAT: String = "character.name.%d"
const TEXT_TITLE: StringName = &"battle.hud.relation_map_title"
const TEXT_DEAD: StringName = &"battle.hud.relation_map_dead"
const ROSTER_IDS: Array[int] = [1, 2, 3, 4, 5]

## Zero-effect line opacity (art answer 7: about 0.6, unverified initial value).
const ZERO_EFFECT_ALPHA: float = 0.6
## Zigzag proportions relative to line width (art answer 2, unverified).
const ZIGZAG_AMPLITUDE_PER_WIDTH: float = 2.0
const ZIGZAG_HALF_PERIOD_PER_WIDTH: float = 4.0

const COLOR_BG: Color = Color(0.05, 0.05, 0.08, 0.72)
const COLOR_NODE: Color = Color(0.9, 0.9, 0.9, 1.0)
const COLOR_DEAD: Color = Color(0.45, 0.45, 0.45, 1.0)

var _statuses: Array[AffinityLineStatus] = []
var _alive_ids: Array[int] = []
var _font: Font = null
var _font_size: int = 11
## World-layer integer scale N, handed in by BattleScreen (which gets it from
## WorldLayout.compute_scale). This class never computes it. Plaque = 7N x 7N.
var _scale_n: int = 1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Setter for styling inputs (font + size) -- presentation only.
func configure(font: Font, font_size_px: int, scale_n: int = 1) -> void:
	_font = font
	_font_size = font_size_px
	_scale_n = maxi(1, scale_n)
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
		out.append({
			"a": s.unit_id, "b": s.partner_id, "state": s.state,
			"shape": BattleScreen.line_shape_for(s),
			"has_plaque": not BattleScreen.line_style_for(s).is_empty(),
		})
	return out


## Line width in px for [param font_size_px]; one value for every line (AC-P9).
static func line_width_px(font_size_px: int) -> float:
	return maxf(1.0, float(font_size_px) / 6.0)


## Plaque top-left for a line midpoint: (mid - size/2) rounded (art answer 3).
static func plaque_top_left(mid: Vector2, scale_n: int) -> Vector2:
	var side: float = float(BoardView.AFFINITY_PLAQUE_SIZE * scale_n)
	return (mid - Vector2(side, side) / 2.0).round()


## Fixed pentagon slot for roster id 1..5, inside [param area].
## 2026-10-29 試玩:原本用同一個半徑畫正五邊形,面板偏扁時底下兩點靠太近、名字疊在一起;
## 改為依面板寬高各自取半徑(橢圓),把點攤開到整個面板。
static func node_position(roster_id: int, area: Rect2) -> Vector2:
	var center: Vector2 = area.position + area.size / 2.0
	var radius: Vector2 = Vector2(area.size.x * 0.34, area.size.y * 0.30)
	var angle: float = -PI / 2.0 + TAU * float(roster_id - 1) / 5.0
	return center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)


func _draw() -> void:
	if _font == null:
		return
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(area, COLOR_BG)
	draw_string(_font, Vector2(4, _font_size), Loc.localize(TEXT_TITLE), HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, COLOR_NODE)
	var body: Rect2 = Rect2(Vector2(0, _font_size * 1.5), size - Vector2(0, _font_size * 1.5))
	var width: float = line_width_px(_font_size)
	var plaques: Array[Dictionary] = []
	for s: AffinityLineStatus in _statuses:
		if s.unit_id not in ROSTER_IDS or s.partner_id not in ROSTER_IDS:
			continue
		var from: Vector2 = node_position(s.unit_id, body)
		var to: Vector2 = node_position(s.partner_id, body)
		var style: Dictionary = BattleScreen.line_style_for(s)
		var color: Color = COLOR_NODE
		color.a = ZERO_EFFECT_ALPHA
		if not style.is_empty():
			color = _tone_color(style["tone"])
			plaques.append({"mid": (from + to) / 2.0, "symbol": style["symbol"], "color": color})
		var points: PackedVector2Array = BoardView.affinity_line_points(
			from, to, BattleScreen.line_shape_for(s),
			width * ZIGZAG_AMPLITUDE_PER_WIDTH, width * ZIGZAG_HALF_PERIOD_PER_WIDTH, false
		)
		draw_polyline(points, color, width, false)
	for plaque: Dictionary in plaques:
		_draw_plaque(plaque["mid"], plaque["symbol"], plaque["color"])
	var body_center_y: float = body.position.y + body.size.y / 2.0
	for id: int in ROSTER_IDS:
		var p: Vector2 = node_position(id, body)
		var alive: bool = id in _alive_ids
		var color: Color = COLOR_NODE if alive else COLOR_DEAD
		draw_circle(p, _font_size * 0.4, color)
		var label: String = Loc.localize(StringName(NAME_KEY_FORMAT % id))
		if not alive:
			label += Loc.localize(TEXT_DEAD)
		# 名字以點為中心水平置中;下半部的點把名字畫在點的下方,避免與上方的線和符號擠在一起。
		var label_w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var baseline_y: float = p.y + _font_size * 1.4 if p.y > body_center_y else p.y - _font_size * 0.7
		draw_string(_font, Vector2(p.x - label_w / 2.0, baseline_y), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)


static func _tone_color(tone: BoardView.LineTone) -> Color:
	if tone == BoardView.LineTone.POSITIVE:
		return BoardView.AFFINITY_LINE_COLOR_POSITIVE
	return BoardView.AFFINITY_LINE_COLOR_NEGATIVE


# 7N x 7N opaque tile + 5N x 5N glyph (bars N thick), drawn from rects, no font.
func _draw_plaque(mid: Vector2, symbol: BoardView.LineSymbol, color: Color) -> void:
	var n: float = float(_scale_n)
	var top_left: Vector2 = plaque_top_left(mid, _scale_n)
	var side: float = float(BoardView.AFFINITY_PLAQUE_SIZE) * n
	draw_rect(Rect2(top_left, Vector2(side, side)), BoardView.AFFINITY_PLAQUE_COLOR)
	var glyph: float = float(BoardView.AFFINITY_PLAQUE_GLYPH_SIZE) * n
	var origin: Vector2 = top_left + Vector2(n, n)
	var half: float = floorf(float(BoardView.AFFINITY_PLAQUE_GLYPH_SIZE) / 2.0) * n
	draw_rect(Rect2(origin + Vector2(0, half), Vector2(glyph, n)), color)
	if symbol == BoardView.LineSymbol.PLUS:
		draw_rect(Rect2(origin + Vector2(half, 0), Vector2(n, glyph)), color)
