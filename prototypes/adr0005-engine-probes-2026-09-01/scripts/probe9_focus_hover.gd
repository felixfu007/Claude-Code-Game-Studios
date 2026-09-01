extends Node
# ADR-0005 Probe #9 —— focus_mode = FOCUS_NONE 是否也排除 Control 主題的滑鼠 hover 繪製。
# 需要非 headless(真實視窗)—— GUI hover 判定走 Viewport 的輸入路徑。

func _ready() -> void:
	print("=".repeat(78))
	print("ADR-0005 PROBE #9 —— focus_mode = FOCUS_NONE 是否也排除 Control 主題的滑鼠 hover 繪製")
	print("Godot: %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	print("=".repeat(78))

	var btn := Button.new()
	btn.text = "TestButton"
	btn.focus_mode = Control.FOCUS_NONE
	btn.position = Vector2(100, 100)
	btn.size = Vector2(200, 60)
	add_child(btn)

	await get_tree().process_frame
	await get_tree().process_frame

	print("btn.focus_mode = %d  (Control.FOCUS_NONE = %d)" % [btn.focus_mode, Control.FOCUS_NONE])
	print("")
	print("── 模擬滑鼠移動到按鈕中心之前 ──")
	print("  is_hovered()    = %s" % str(btn.is_hovered()))
	print("  get_draw_mode() = %d" % btn.get_draw_mode())

	var rect: Rect2 = btn.get_global_rect()
	var center: Vector2 = rect.position + rect.size * 0.5
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	get_viewport().push_input(motion)

	await get_tree().process_frame
	await get_tree().process_frame

	print("")
	print("── 模擬滑鼠移動到按鈕中心之後(get_viewport().push_input(InputEventMouseMotion)) ──")
	var hovered: bool = btn.is_hovered()
	var draw_mode: int = btn.get_draw_mode()
	print("  is_hovered()    = %s" % str(hovered))
	print("  get_draw_mode() = %d   (NORMAL=0 PRESSED=1 HOVER=2 DISABLED=3 HOVER_PRESSED=4)" % draw_mode)
	print("")

	if hovered and draw_mode == BaseButton.DRAW_HOVER:
		print("判定:FOCUS_NONE【不】排除滑鼠 hover 主題繪製 —— is_hovered()=true 且 draw_mode=HOVER。")
		print("      機制十四僅靠 focus_mode 只封住『鍵盤/手把焦點環』這一條管線;")
		print("      滑鼠 hover 主題繪製是結構上獨立的第二條管線,FOCUS_NONE 管不到它。")
		print("      ADR-0005 VR #9 由『godot-specialist 判斷大概率不排除』轉為『已查證:確實不排除』。")
	elif not hovered:
		print("判定:模擬滑鼠移動沒有被按鈕偵測為 hover(is_hovered()=false)。")
		print("      無法從本次量測直接回答 VR #9 —— 可能是 push_input() 的模擬方式在本情境下")
		print("      未能觸發 GUI hover 判定(常見原因:視窗未取得 OS 焦點、或事件座標系不符)。")
		print("      需要換一種輸入模擬方式或改用真人操作重測。")
	else:
		print("判定:is_hovered()=true 但 draw_mode 非 HOVER(=%d)—— 需人工檢視,可能有其他狀態疊加" % draw_mode)
		print("      (例如同時處於 disabled 或 pressed)。")

	print("")
	get_tree().quit()
