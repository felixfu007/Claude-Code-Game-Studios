extends SceneTree
## 產生 assets/art/placeholder/ 底下的佔位美術 PNG。
## 執行方式: godot --headless --script tools/asset-pipeline/generate_placeholder_art.gd
##
## 規格來源: art-director 交付的佔位規格(2026-08-26)。
## 刻意不在棋子 PNG 上畫編號 1~5 —— 顏色會換，編號不會換，且編號是色弱玩家的
## 唯一保障，理由見呼叫此腳本的對話紀錄。改用 Label/RichTextLabel 之類的節點
## 在執行期疊字，不烙進美術檔案本身。
##
## 敵方棋子顏色選「黑紫」而非規格給的另一個選項「深紅」：本專案我方棋子第 5 色
## 是「深綠」，若敵方選深紅，會重新製造出規格本身要求避開的「紅綠對比」問題
## （只是換成敵我對抗，而非兩個我方棋子之間）。這是本腳本作者（godot-specialist）
## 的判斷，不是 art-director 原始規格的字面規定，需要 art-director 確認或推翻。

const OUT_DIR: String = "res://assets/art/placeholder"

func _fill_flat(w: int, h: int, color: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

func _fill_bordered(w: int, h: int, fill_color: Color, border_color: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill_color)
	for x in range(w):
		for y in range(h):
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				img.set_pixel(x, y, border_color)
	return img

func _save(img: Image, filename: String) -> void:
	var path: String = OUT_DIR + "/" + filename
	var err: int = img.save_png(path)
	print("save_png(%s) error = %d (0 == OK), size = %s" % [filename, err, img.get_size()])
	assert(err == 0)

func _initialize() -> void:
	print("=== GENERATE placeholder art START ===")

	var mkdir_err: int = DirAccess.make_dir_recursive_absolute(OUT_DIR)
	print("make_dir_recursive_absolute error = ", mkdir_err, " (0 == OK, or already exists)")

	# --- 地形 (32x32) ---
	_save(_fill_flat(32, 32, Color8(74, 56, 32, 255)), "terrain_ground.png")      # 可通行地面：深綠棕
	_save(_fill_flat(32, 32, Color8(79, 143, 82, 255)), "terrain_bush.png")       # 灌木叢：中綠，移動成本2
	_save(_fill_flat(32, 32, Color8(59, 70, 82, 255)), "terrain_rubble.png")      # 倒木/巨石堆：深灰帶藍，成本3、遮蔽視線

	# --- 游標與範圍高亮 (32x32) ---
	_save(_fill_bordered(32, 32, Color(1, 1, 1, 0.15), Color(1, 1, 1, 1)), "cursor_outline.png")       # 白色細框 + 半透明底
	_save(_fill_flat(32, 32, Color(0.2, 0.45, 0.95, 0.35)), "highlight_move.png")                      # 半透明藍
	_save(_fill_flat(32, 32, Color(0.95, 0.35, 0.15, 0.35)), "highlight_attack.png")                    # 半透明橘紅

	# --- 我方棋子 x5 (32x40)：刻意避開紅綠對比 ---
	_save(_fill_flat(32, 40, Color8(60, 110, 220, 255)), "piece_ally_01.png")   # 藍
	_save(_fill_flat(32, 40, Color8(230, 140, 40, 255)), "piece_ally_02.png")   # 橘
	_save(_fill_flat(32, 40, Color8(230, 200, 40, 255)), "piece_ally_03.png")   # 黃
	_save(_fill_flat(32, 40, Color8(150, 70, 200, 255)), "piece_ally_04.png")   # 紫
	_save(_fill_flat(32, 40, Color8(40, 110, 70, 255)), "piece_ally_05.png")    # 深綠

	# --- 敵方棋子 x1 (32x40) ---
	_save(_fill_flat(32, 40, Color8(45, 15, 55, 255)), "piece_enemy_01.png")    # 黑紫（見檔頭說明，非字面規格，待確認）

	print("=== GENERATE placeholder art END ===")
	quit(0)
