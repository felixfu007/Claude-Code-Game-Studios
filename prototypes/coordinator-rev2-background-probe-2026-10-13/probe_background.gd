extends SceneTree
## 量測 rev2 四張圖的「邊界是否為洋紅 #FF00FF」,以便與第一輪的 0/8 直接對比。
##
## 🔴 來源等級自述:引擎執行了【解碼】(Image.load_from_file),但「什麼算洋紅」
## 「哪些像素算邊界」這兩條規則是本腳本自行實作的,不是呼叫家用端 ai_art_postprocess
## 的真實程式碼。依 .claude/docs/technical-preferences.md「(A) 的精確定義」,
## 這兩條規則屬 (C) 級,不得當成既定事實。
## 刻意對齊家用端交付報告 3.3 節的判準以求可比:距 #FF00FF 的 RGB 歐氏距離 <= 64/255*sqrt(3)
## 近似為「各通道距離平方和開根號 <= 0.251」(他們用 0~255 尺度的 64)。
## 未計入:alpha(來源無 alpha 通道)、角色本身可能含洋紅色的情形。

const KEY := Color(1.0, 0.0, 1.0)
const TOL := 64.0 / 255.0  # 家用端預設容許誤差 64(0~255 尺度)

func _dist(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for path in args:
		var img := Image.load_from_file(path)
		if img == null:
			print("LOAD FAILED: ", path)
			continue
		var w := img.get_width()
		var h := img.get_height()
		var border_total := 0
		var border_key := 0
		for x in range(w):
			for y in [0, h - 1]:
				border_total += 1
				if _dist(img.get_pixel(x, y), KEY) <= TOL:
					border_key += 1
		for y in range(1, h - 1):
			for x in [0, w - 1]:
				border_total += 1
				if _dist(img.get_pixel(x, y), KEY) <= TOL:
					border_key += 1
		var corners := [
			img.get_pixel(0, 0), img.get_pixel(w - 1, 0),
			img.get_pixel(0, h - 1), img.get_pixel(w - 1, h - 1),
			img.get_pixel(w / 2, 0), img.get_pixel(w / 2, h - 1),
			img.get_pixel(0, h / 2), img.get_pixel(w - 1, h / 2),
		]
		var hexes := PackedStringArray()
		for c: Color in corners:
			hexes.append(c.to_html(false))
		print("%s  %dx%d  邊界洋紅 %d/%d (%.2f%%)  四角+四邊中點: %s" % [
			path.get_file(), w, h, border_key, border_total,
			100.0 * float(border_key) / float(border_total), ", ".join(hexes)
		])
	quit()
