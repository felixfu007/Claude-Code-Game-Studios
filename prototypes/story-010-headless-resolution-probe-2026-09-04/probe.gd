## Story 010 開工前探針 —— 問題只有一個:
## 「游標圖層 transform 恆等」這條防護測試,在 headless(CI/本機測試套件跑的模式)下
## 到底驗不驗得到東西?
##
## 分三題,第三題才是重點:
##   Q1 headless 下改得動視窗/根視窗尺寸嗎?(改不動 → 四種解析度根本模擬不出來)
##   Q2 專屬 CanvasLayer 在四種尺寸下 get_final_transform() 是否恆等?(該綠時綠)
##   Q3 故意做出「與介面圖層共用、被縮放」的失效態,測試會不會紅?(該紅時紅)
##      🔴 Q3 沒過 = 這條測試是假警報器,不能寫。
##   Q4 headless 到底有沒有套用 content scale?沒套用的話 Q2 的恆等是「環境本來就沒縮放」,
##      不是「圖層被正確隔離」—— 兩者在斷言上長得一模一樣。
extends SceneTree

const SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
	Vector2i(3440, 1440),
]


func _fmt(t: Transform2D) -> String:
	return "x=%s y=%s o=%s" % [t.x, t.y, t.origin]


func _initialize() -> void:
	print("=== 環境 ===")
	print("DisplayServer name: ", DisplayServer.get_name())
	print("headless?: ", DisplayServer.get_name() == "headless")

	var r: Window = root

	# --- 建立兩顆圖層:一顆專屬(正確做法),一顆模擬「與介面共用且被縮放」(失效態) ---
	var cursor_layer := CanvasLayer.new()
	cursor_layer.name = "CursorLayerDedicated"
	r.add_child(cursor_layer)

	var shared_layer := CanvasLayer.new()
	shared_layer.name = "SharedWithUILayer"
	r.add_child(shared_layer)

	print()
	print("=== Q1 / Q2 / Q4:四種解析度 ===")
	for s in SIZES:
		# 兩種改法都試,看哪一種在 headless 有效
		DisplayServer.window_set_size(s)
		r.size = s

		var ds_size: Vector2i = DisplayServer.window_get_size()
		var root_size: Vector2i = r.size
		var vis: Rect2 = r.get_visible_rect()
		var win_final: Transform2D = r.get_final_transform()
		var layer_final: Transform2D = cursor_layer.get_final_transform()

		print("--- 目標 %s ---" % s)
		print("  Q1 DisplayServer.window_get_size() = ", ds_size, "  root.size = ", root_size)
		print("  Q4 root.get_visible_rect()         = ", vis)
		print("  Q4 root.get_final_transform()      = ", _fmt(win_final),
			"   是否恆等=", win_final.is_equal_approx(Transform2D.IDENTITY))
		print("  Q2 cursor_layer.get_final_transform() = ", _fmt(layer_final),
			"   是否恆等=", layer_final.is_equal_approx(Transform2D.IDENTITY))

	print()
	print("=== Q3 靈敏度:故意做出失效態,測試該紅嗎? ===")
	# 失效態的真實形狀:游標圖層被併進介面圖層,而介面圖層帶著縮放。
	shared_layer.scale = Vector2(2.6666667, 2.6666667)
	var bad: Transform2D = shared_layer.get_final_transform()
	print("  失效態圖層 final transform = ", _fmt(bad),
		"   是否恆等=", bad.is_equal_approx(Transform2D.IDENTITY))
	print("  → 恆等斷言會紅嗎? ", not bad.is_equal_approx(Transform2D.IDENTITY))

	# 換算成玩家看得到的後果:滑鼠在畫面右下角時,游標會被畫到哪裡
	for s in SIZES:
		var pt := Vector2(s.x, s.y)
		var drawn: Vector2 = bad * pt
		print("    %s: 滑鼠在 %s → 游標畫在 %s,偏差 %.0f px"
			% [s, pt, drawn, (drawn - pt).length()])

	# --- Q3b:另一種失效態 —— 圖層本身乾淨,但被 offset 推開 ---
	var offset_layer := CanvasLayer.new()
	offset_layer.name = "OffsetLayer"
	offset_layer.offset = Vector2(80, 45)
	r.add_child(offset_layer)
	var off: Transform2D = offset_layer.get_final_transform()
	print("  Q3b offset 失效態 = ", _fmt(off),
		"   是否恆等=", off.is_equal_approx(Transform2D.IDENTITY))

	quit()
