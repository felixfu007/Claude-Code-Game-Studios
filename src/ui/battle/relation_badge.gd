## 關係三態 / 騎牆 徽記(story-021;畫法:docs/reviews/card-rework-ui-art-2026-11-17.md 第 1、8 節)。
##
## 純繪製元件:只依 [member kind] 決定形狀,不判斷任何關係(三態只來自 AffinityRelation.state_of,
## 由呼叫端傳入)。形狀通道不依賴顏色:白色圖元 + 1 源像素深描邊,所有徽記同色。
## [member unit_px] = 每個源像素放大成幾個螢幕像素(呼叫端以 HudLayout 倍率整數傳入,nearest、不補間)。
class_name RelationBadge
extends Control

enum Kind { POS, NEG, NONE, STRADDLE_ON, STRADDLE_OFF }

const FILL_COLOR: Color = Color("FFFFFF")
const OUTLINE_COLOR: Color = Color("0E0F14")

## 三態詞鍵 —— 全專案唯一一份(strings.csv 已有,020a 加入;不得在 UI 內另寫字面中文)。
const STATE_TEXT_KEYS: Dictionary = {
	AffinityRelation.RelationState.POS: &"battle.relation.state.pos",
	AffinityRelation.RelationState.NONE: &"battle.relation.state.none",
	AffinityRelation.RelationState.NEG: &"battle.relation.state.neg",
}

## 各形狀的源像素(x, y);外框 1 源像素描邊另加。
const _PIXELS_POS: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1),
]
const _PIXELS_NEG: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 1),
	Vector2i(4, 0), Vector2i(5, 1), Vector2i(6, 2),
]
const _PIXELS_NONE: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
	Vector2i(0, 1), Vector2i(4, 1), Vector2i(0, 2), Vector2i(4, 2), Vector2i(0, 3), Vector2i(4, 3),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
]

## 圖元大小(源像素,不含描邊)。
const _SIZE_POS: Vector2i = Vector2i(7, 3)
const _SIZE_NEG: Vector2i = Vector2i(7, 3)
const _SIZE_NONE: Vector2i = Vector2i(5, 5)
const _SIZE_SHIELD: Vector2i = Vector2i(7, 7)

var kind: Kind = Kind.NONE:
	set(value):
		kind = value
		_refresh_size()
		queue_redraw()

var unit_px: int = 2:
	set(value):
		unit_px = maxi(1, value)
		_refresh_size()
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_size()


## 三態 -> 徽記種類。非三態值回 NONE 形(最安全預設,與 RelationState 第 0 值一致)。
static func kind_for_state(state: int) -> Kind:
	match state:
		AffinityRelation.RelationState.POS:
			return Kind.POS
		AffinityRelation.RelationState.NEG:
			return Kind.NEG
		_:
			return Kind.NONE


## 三態 -> 詞鍵;非三態值回 &""。
static func text_key_for_state(state: int) -> StringName:
	return STATE_TEXT_KEYS.get(state, &"") as StringName


## 本形狀的源像素集合(測試與繪製共用,形狀通道的可觀測出口)。
static func pixels_of(p_kind: Kind) -> Array[Vector2i]:
	match p_kind:
		Kind.POS:
			return _PIXELS_POS
		Kind.NEG:
			return _PIXELS_NEG
		Kind.NONE:
			return _PIXELS_NONE
		Kind.STRADDLE_ON:
			return _shield_pixels(true)
		_:
			return _shield_pixels(false)


static func size_of(p_kind: Kind) -> Vector2i:
	match p_kind:
		Kind.POS:
			return _SIZE_POS
		Kind.NEG:
			return _SIZE_NEG
		Kind.NONE:
			return _SIZE_NONE
		_:
			return _SIZE_SHIELD


static func _shield_pixels(solid: bool) -> Array[Vector2i]:
	var rows: Array[String] = [
		"1111111", "1111111", "1111111", "1111111", "0111110", "0011100", "0001000",
	]
	var hollow_rows: Array[String] = [
		"1111111", "1000001", "1000001", "1000001", "0100010", "0010100", "0001000",
	]
	var source: Array[String] = rows if solid else hollow_rows
	var result: Array[Vector2i] = []
	for y: int in range(source.size()):
		for x: int in range(source[y].length()):
			if source[y][x] == "1":
				result.append(Vector2i(x, y))
	if not solid:
		# 失效 = 空心輪廓 + 左下到右上一條 1px 斜線。
		for i: int in range(7):
			var cell: Vector2i = Vector2i(i, 6 - i)
			if not result.has(cell):
				result.append(cell)
	return result


## 固定保留區(源像素,不含描邊):一律 7x7,不論形狀高矮(art-director 2026-11-19 待辦:
## 三態徽記以 7x7 為固定保留區垂直置中,切換三態時旁邊 2 字文字不跳位)。
const RESERVED_SIZE: Vector2i = Vector2i(7, 7)


## 形狀在保留區內的垂直偏移(源像素,整數;垂直置中,水平靠左)。
static func vertical_offset_of(p_kind: Kind) -> int:
	return (RESERVED_SIZE.y - size_of(p_kind).y) / 2


func _refresh_size() -> void:
	custom_minimum_size = Vector2(
		float(RESERVED_SIZE.x + 2) * unit_px, float(RESERVED_SIZE.y + 2) * unit_px
	)
	size = custom_minimum_size


func _draw() -> void:
	draw_badge(self, Vector2.ZERO, kind, unit_px)


## 在 [param canvas] 的 [param origin](保留區左上角含描邊)畫出 [param p_kind] 徽記,
## 關係圖詳情區與本元件自己共用(單一畫法)。
static func draw_badge(canvas: CanvasItem, origin: Vector2, p_kind: Kind, p_unit_px: int) -> void:
	var cells: Array[Vector2i] = pixels_of(p_kind)
	var fill: Dictionary = {}
	for c: Vector2i in cells:
		fill[c] = true
	var u: float = float(p_unit_px)
	var shift: Vector2i = Vector2i.ONE + Vector2i(0, vertical_offset_of(p_kind))
	# 先畫描邊(每個像素向八鄰域擴張 1),再畫白色本體;偏移 1 源像素容納描邊。
	for c: Vector2i in cells:
		for dy: int in range(-1, 2):
			for dx: int in range(-1, 2):
				var n: Vector2i = c + Vector2i(dx, dy)
				if not fill.has(n):
					canvas.draw_rect(Rect2(origin + Vector2(n + shift) * u, Vector2(u, u)), OUTLINE_COLOR)
	for c: Vector2i in cells:
		canvas.draw_rect(Rect2(origin + Vector2(c + shift) * u, Vector2(u, u)), FILL_COLOR)
