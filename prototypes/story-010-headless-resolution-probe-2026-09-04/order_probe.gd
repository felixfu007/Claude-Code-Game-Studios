## 順序探針:切換 stretch/mode 會不會改變「游標系統看到的滑鼠座標空間」?
## 若會改變,Story 011(自繪游標)就必須排在 screen-scaling 001 之後,
## 否則會照著一個我們已經決定要放棄的座標空間去做。
extends SceneTree

const SIZES: Array[Vector2i] = [Vector2i(1920,1080), Vector2i(2560,1440), Vector2i(3840,2160)]

func _run(label: String) -> void:
	print("--- ", label, " ---")
	for s in SIZES:
		root.size = s
		var vis: Rect2 = root.get_visible_rect()
		print("  視窗 %s → get_visible_rect()=%s  (游標系統讀到的座標上限)" % [s, vis.size])

func _initialize() -> void:
	print("專案設定 stretch/mode = ", ProjectSettings.get_setting("display/window/stretch/mode"))
	_run("現行設定(canvas_items)")
	# 執行期切成 disabled,看座標空間變不變
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run("切成 disabled 之後")
	quit()
