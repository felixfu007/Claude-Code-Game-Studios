## 開工前查核:引擎載得動 Cubic 11 嗎?它有我們現在畫面上用到的字嗎?
## ⚠️ 本檔改過三次 —— font_style_name 與 get_glyph_list(1 arg) 都是憑記憶寫錯的 API,
##    實際不存在 / 簽章不符。留此註記作為「參考庫要查、不要憑印象」的又一個實例。
extends SceneTree
func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	var f: FontFile = load("res://assets/fonts/Cubic_11.ttf")
	print("載入耗時 ", Time.get_ticks_msec() - t0, " ms;結果=", f != null)
	if f == null:
		print("🔴 載入失敗"); quit(); return
	print("font_name = ", f.font_name)
	print("fixed_size(點陣字應非 0) = ", f.fixed_size)
	var missing: Array[String] = []
	for s in ["第","回","合","我","方","行","動","移","確","認","結","束","向","鍵","滑","鼠","勝","利"]:
		if not f.has_char(s.unicode_at(0)):
			missing.append(s)
	print("現行畫面用到的 18 個字,缺字數 = ", missing.size(), "  缺:", missing)
	quit()
