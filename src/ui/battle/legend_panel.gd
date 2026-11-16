## story-047 圖例面板:疊在棋盤上方的唯讀說明層,列出 [BoardView] 實際會畫的每一種標記
## (圖示 + 名稱 + 一句話)。
##
## 🔴 [b]圖示不得另畫一份[/b]:每個圖示都是 [method BoardView.build_legend_sample] 的輸出,
## 面板只負責縮放(整數倍)與擺位,不改任何顏色/形狀。
## 項目集合由 [constant ENTRIES] 決定,[method entry_kinds] 與 [method BoardView.legend_marker_kinds]
## 必須相等(測試 AC1)。
##
## 本節點不持有遊戲狀態、不做規則判斷。開關由 [code]battle_screen.gd[/code] 呼叫
## [method open] / [method close];輸入攔截也在 battle_screen 的 [code]_input[/code] 最頂端
## (面板不自己處理遊戲輸入)。版面全部由 [method apply_layout] 依視窗尺寸算出,
## 字級走 [method HudLayout.font_size](點陣字專用整數倍規則),
## 版面為兩欄九列,疊在安全區內,不佔側邊固定欄。
class_name LegendPanel
extends Control

## 面板關閉時發出(任何途徑)。
signal closed()

## 圖例項目:[code]kind[/code] 為 [enum BoardView.MarkerKind],[code]key[/code] 為字串鍵前綴
## (實際鍵為 [code]key + ".name"[/code] 與 [code]key + ".desc"[/code])。順序即顯示順序(先填左欄)。
const ENTRIES: Array[Dictionary] = [
	{"kind": BoardView.MarkerKind.MOVE_RANGE, "key": "battle.legend.move_range"},
	{"kind": BoardView.MarkerKind.ATTACK_RANGE, "key": "battle.legend.attack_range"},
	{"kind": BoardView.MarkerKind.ATTACK_LOS_BLOCKED, "key": "battle.legend.attack_los_blocked"},
	{"kind": BoardView.MarkerKind.THREAT_RANGE, "key": "battle.legend.threat_range"},
	{"kind": BoardView.MarkerKind.MOVE_BLOCKED_OCCUPANCY, "key": "battle.legend.move_blocked_occupancy"},
	{"kind": BoardView.MarkerKind.MOVE_OUT_OF_RANGE, "key": "battle.legend.move_out_of_range"},
	{"kind": BoardView.MarkerKind.CARD_TARGET_LEGAL, "key": "battle.legend.card_target_legal"},
	{"kind": BoardView.MarkerKind.CARD_TARGET_ILLEGAL, "key": "battle.legend.card_target_illegal"},
	{"kind": BoardView.MarkerKind.AFFINITY_SOLID_PLUS, "key": "battle.legend.affinity_solid_plus"},
	{"kind": BoardView.MarkerKind.AFFINITY_SOLID_MINUS, "key": "battle.legend.affinity_solid_minus"},
	{"kind": BoardView.MarkerKind.AFFINITY_ZIGZAG_PLUS, "key": "battle.legend.affinity_zigzag_plus"},
	{"kind": BoardView.MarkerKind.AFFINITY_ZIGZAG_MINUS, "key": "battle.legend.affinity_zigzag_minus"},
	{"kind": BoardView.MarkerKind.CURSOR, "key": "battle.legend.cursor"},
	{"kind": BoardView.MarkerKind.ACTION_MOVED, "key": "battle.legend.action_moved"},
	{"kind": BoardView.MarkerKind.ACTION_ATTACKED, "key": "battle.legend.action_attacked"},
	{"kind": BoardView.MarkerKind.UNIT_DONE, "key": "battle.legend.unit_done"},
]

const TITLE_KEY: StringName = &"battle.legend.title"
const CLOSE_KEY: StringName = &"battle.legend.close"
const COLUMNS: int = 2
const MASK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.78)

var _mask: ColorRect = null
var _title: Label = null
var _close_button: Button = null
## kind -> 圖示根節點(BoardView.build_legend_sample 的輸出,縮放後掛在圖示區)。
var _icons: Dictionary = {}
var _name_labels: Dictionary = {}
var _desc_labels: Dictionary = {}
var _holders: Dictionary = {}
var _content_rect: Rect2 = Rect2()


func _init() -> void:
	name = "LegendPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mask = ColorRect.new()
	_mask.name = "Mask"
	_mask.color = MASK_COLOR
	_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_mask)
	_title = _make_label("Title")
	add_child(_title)
	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.add_theme_font_override(&"font", HudLayoutScaler.HUD_FONT)
	_close_button.pressed.connect(close)
	add_child(_close_button)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for entry: Dictionary in ENTRIES:
		var kind: int = entry["kind"]
		var holder: Control = Control.new()
		holder.name = "Icon%d" % kind
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(holder)
		var sample: Node2D = BoardView.build_legend_sample(kind)
		holder.add_child(sample)
		_icons[kind] = sample
		_holders[kind] = holder
		var name_label: Label = _make_label("Name%d" % kind)
		add_child(name_label)
		_name_labels[kind] = name_label
		var desc_label: Label = _make_label("Desc%d" % kind)
		add_child(desc_label)
		_desc_labels[kind] = desc_label
	_refresh_texts()


## 圖例項目的 kind 全集(AC1 與 [method BoardView.legend_marker_kinds] 比對)。
static func entry_kinds() -> Array[int]:
	var out: Array[int] = []
	for entry: Dictionary in ENTRIES:
		out.append(entry["kind"])
	return out


func is_open() -> bool:
	return visible


func open(window_size: Vector2i) -> void:
	_refresh_texts()
	apply_layout(window_size)
	visible = true
	_close_button.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	_close_button.release_focus()
	closed.emit()


## 圖示根節點(測試 AC2 用)。
func icon_for(kind: int) -> Node2D:
	return _icons.get(kind) as Node2D


func name_label_for(kind: int) -> Label:
	return _name_labels.get(kind) as Label


func desc_label_for(kind: int) -> Label:
	return _desc_labels.get(kind) as Label


func close_button() -> Button:
	return _close_button


## 面板內容區(視窗座標);滑鼠點在其外視為點遮罩。
func content_rect() -> Rect2:
	return _content_rect


## 整數倍:圖示縮放 = max(1, N/2),N = HUD 倍率([method HudLayout.font_size] / 11)。
static func icon_scale_for(window_size: Vector2i) -> int:
	return maxi(1, WorldLayout.compute_scale(window_size) >> 1)


func apply_layout(window_size: Vector2i) -> void:
	position = Vector2.ZERO
	size = Vector2(window_size)
	_mask.position = Vector2.ZERO
	_mask.size = Vector2(window_size)
	var safe: Rect2 = HudLayout.safe_rect(window_size)
	var fpx: float = float(HudLayout.font_size(window_size))
	var iscale: int = icon_scale_for(window_size)
	var rows: int = ceili(float(ENTRIES.size()) / float(COLUMNS))
	var top_h: float = fpx * 1.5
	var row_h: float = maxf(fpx * 2.0, BoardView.LEGEND_SAMPLE_SIZE.y * float(iscale))
	var total_h: float = top_h + row_h * float(rows)
	var top: float = safe.position.y + maxf((safe.size.y - total_h) * 0.5, 0.0)
	_content_rect = Rect2(safe.position.x, top, safe.size.x, total_h)
	_title.position = Vector2(safe.position.x, top)
	_title.size = Vector2(safe.size.x * 0.5, top_h)
	_title.add_theme_font_size_override(&"font_size", int(fpx))
	var btn_w: float = fpx * 4.0
	_close_button.position = Vector2(safe.position.x + safe.size.x - btn_w, top)
	_close_button.size = Vector2(btn_w, top_h)
	_close_button.add_theme_font_size_override(&"font_size", int(fpx))
	var col_w: float = safe.size.x / float(COLUMNS)
	var icon_w: float = BoardView.LEGEND_SAMPLE_SIZE.x * float(iscale)
	for i: int in range(ENTRIES.size()):
		var kind: int = ENTRIES[i]["kind"]
		var col: int = floori(float(i) / float(rows))
		var row: int = i % rows
		var x: float = safe.position.x + col_w * float(col)
		var y: float = top + top_h + row_h * float(row)
		var holder: Control = _holders[kind]
		holder.position = Vector2(x, y)
		holder.size = BoardView.LEGEND_SAMPLE_SIZE * float(iscale)
		var sample: Node2D = _icons[kind]
		sample.scale = Vector2(iscale, iscale)
		sample.position = BoardView.LEGEND_SAMPLE_ORIGIN * float(iscale)
		var text_x: float = x + icon_w + fpx * 0.5
		var text_w: float = col_w - icon_w - fpx
		var name_label: Label = _name_labels[kind]
		name_label.position = Vector2(text_x, y)
		name_label.size = Vector2(text_w, fpx)
		name_label.add_theme_font_size_override(&"font_size", int(fpx))
		var desc_label: Label = _desc_labels[kind]
		desc_label.position = Vector2(text_x, y + fpx)
		desc_label.size = Vector2(text_w, fpx)
		desc_label.add_theme_font_size_override(&"font_size", int(fpx))


func _refresh_texts() -> void:
	_title.text = Loc.localize(TITLE_KEY)
	_close_button.text = Loc.localize(CLOSE_KEY)
	for entry: Dictionary in ENTRIES:
		var kind: int = entry["kind"]
		var key: String = entry["key"]
		(_name_labels[kind] as Label).text = Loc.localize(StringName(key + ".name"))
		(_desc_labels[kind] as Label).text = Loc.localize(StringName(key + ".desc"))


func _make_label(node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override(&"font", HudLayoutScaler.HUD_FONT)
	return label
