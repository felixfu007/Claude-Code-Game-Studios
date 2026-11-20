class_name HandKindIcon
extends Control

## story-030:手牌縮圖的卡類別圖示。照 7x7 像素遮罩逐格用 [method CanvasItem.draw_rect]
## 自繪(每格一個 [member cell_px] 邊長的實心方塊,最近鄰、無旋轉、無半像素)。
## 遮罩字元:[code]#[/code] 實心、[code].[/code] 透明。遮罩資料見
## [method HandBar.icon_mask_for](權威來源 `docs/reviews/hand-thumbnail-shapes-art-spec-2026-11-20.md` 第 1 節)。

## 遮罩列(每列等長字串)。
var mask: PackedStringArray = PackedStringArray()
## 遮罩一格的螢幕像素邊長(整數倍;= N × 縮放)。
var cell_px: int = 1
## 繪製色(含透明度與暗化)。
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


## 設定遮罩與格邊長,並把控制項尺寸設為整張遮罩大小。
func configure(new_mask: PackedStringArray, new_cell_px: int) -> void:
	mask = new_mask
	cell_px = maxi(1, new_cell_px)
	var rows: int = mask.size()
	var cols: int = 0 if rows == 0 else mask[0].length()
	size = Vector2(cols * cell_px, rows * cell_px)
	queue_redraw()


## 實際會被畫出的實心方塊矩形(圖示本地座標,像素)。[method _draw] 與測試共用同一份。
func filled_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	for y: int in range(mask.size()):
		var row: String = mask[y]
		for x: int in range(row.length()):
			if row[x] == "#":
				rects.append(Rect2i(x * cell_px, y * cell_px, cell_px, cell_px))
	return rects


func _draw() -> void:
	for r: Rect2i in filled_rects():
		draw_rect(Rect2(r), color, true)
