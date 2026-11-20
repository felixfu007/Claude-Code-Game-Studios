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
## in the pentagon; the detail area below it lists every living pair with its
## word (story-021, UX AC-11: cold pairs get text there too, since they have no
## line) -- rows are handed in already built by BattleScreen
## ([method set_detail_rows]); this class never judges a relation.
## Dead character: node drawn grey + localized "dead" tag, its lines are
## skipped (statuses never contain them anyway).
class_name RelationMinimap
extends Control

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
var _detail_rows: Array[Dictionary] = []
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


## story-021: detail rows, each {"kind": RelationBadge.Kind, "text": String}
## (pair names + relation word, or the straddle row). Pure presentation input.
func set_detail_rows(rows: Array[Dictionary]) -> void:
	_detail_rows = rows
	if visible:
		queue_redraw()


## 詳情字級:宿主傳入(HudLayout.small_font_size(視窗)),本節點不含任何字級公式。
var _detail_font_px: int = HudLayout.GLYPH_PX


func set_detail_font_size(px: int) -> void:
	_detail_font_px = maxi(1, px)
	queue_redraw()


func _detail_font_size() -> int:
	return _detail_font_px


func _detail_row_height() -> float:
	return float(maxi(_detail_font_size() + 1, (RelationBadge.RESERVED_SIZE.y + 2) * _detail_badge_unit()))


## 徽記倍率 = 宿主傳入的 _scale_n(WorldLayout.compute_scale 的結果),不自算。
func _detail_badge_unit() -> int:
	return _scale_n


## 詳情文字區左緣(本節點座標)。
func _detail_text_left() -> float:
	var badge_side: float = float(RelationBadge.RESERVED_SIZE.x + 2) * float(_detail_badge_unit())
	return _detail_rect.position.x + 4.0 + badge_side + float(_detail_badge_unit())


## 第 [param i] 列文字右緣(以實際字寬量,供方向詞固定欄與測試使用)。
func detail_text_right(i: int) -> float:
	var w: float = _font.get_string_size(String(_detail_rows[i]["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, _detail_font_size()).x
	return _detail_text_left() + w


## 方向詞固定欄 x:最寬那列文字右緣 + 一個字級間隙,讓詞緊貼各列而非飄到卡右緣。
func detail_effect_x() -> float:
	var right: float = _detail_text_left()
	for i: int in range(_detail_rows.size()):
		right = maxf(right, detail_text_right(i))
	return right + float(_detail_font_size())


## Extra panel height the detail area needs; the host adds it to the base panel height.
func detail_height_px() -> float:
	return float(_detail_rows.size()) * _detail_row_height()


## For tests: the detail rows currently handed in.
func diagnostic_detail_rows() -> Array[Dictionary]:
	return _detail_rows


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
	if detail_height_px() > 0.0:
		_draw_detail_card()
	var body_center_y: float = body.position.y + body.size.y / 2.0
	for id: int in ROSTER_IDS:
		var p: Vector2 = node_position(id, body)
		var alive: bool = id in _alive_ids
		var color: Color = COLOR_NODE if alive else COLOR_DEAD
		draw_circle(p, _font_size * 0.4, color)
		var label: String = Loc.character_name(id)
		if not alive:
			label += Loc.localize(TEXT_DEAD)
		# 名字以點為中心水平置中;下半部的點把名字畫在點的下方,避免與上方的線和符號擠在一起。
		var label_w: float = _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var baseline_y: float = p.y + _font_size * 1.4 if p.y > body_center_y else p.y - _font_size * 0.7
		draw_string(_font, Vector2(p.x - label_w / 2.0, baseline_y), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)


func _draw_detail(top: float) -> void:
	var row_h: float = _detail_row_height()
	var fsize: int = _detail_font_size()
	var unit: int = _detail_badge_unit()
	var badge_side: float = float(RelationBadge.RESERVED_SIZE.x + 2) * float(unit)
	var ox: float = _detail_rect.position.x
	var effect_x: float = detail_effect_x()
	var effect_w_max: float = _detail_rect.end.x - effect_x - 4.0
	for i: int in range(_detail_rows.size()):
		var y: float = top + float(i) * row_h
		var baseline: float = y + (row_h + float(fsize)) / 2.0 - 1.0
		RelationBadge.draw_badge(self, Vector2(ox + 4.0, y + (row_h - badge_side) / 2.0),
				int(_detail_rows[i]["kind"]) as RelationBadge.Kind, unit)
		var text_w: float = maxf(1.0, _detail_rect.end.x - _detail_text_left() - 4.0)
		draw_string(_font, Vector2(_detail_text_left(), baseline),
				String(_detail_rows[i]["text"]), HORIZONTAL_ALIGNMENT_LEFT, text_w, fsize, COLOR_NODE)
		# 「目前效果」方向詞(加成/懲罰/無)放固定欄,緊貼文字;冷淡列與騎牆列的 "effect" 為空 → 不畫。
		var effect: String = String(_detail_rows[i].get("effect", ""))
		if effect != "":
			draw_string(_font, Vector2(effect_x, baseline), effect,
					HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, effect_w_max), fsize, COLOR_NODE)


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


## 詳情浮出卡的矩形(本節點區域座標;宿主以 HudLayout.relation_detail_rect 換算後傳入)。
## 卡片畫在圖本體右側,不在左欄疊高(管理者 2026-11-20 裁決)。
var _detail_rect: Rect2 = Rect2()

func set_detail_rect(local_rect: Rect2) -> void:
	_detail_rect = local_rect
	queue_redraw()


func _draw_detail_card() -> void:
	draw_rect(_detail_rect, COLOR_BG)
	_draw_detail(_detail_rect.position.y)


## For tests: the detail font px and badge unit actually in effect.
func diagnostic_detail_metrics() -> Dictionary:
	return {"font": _detail_font_size(), "unit": _detail_badge_unit()}
