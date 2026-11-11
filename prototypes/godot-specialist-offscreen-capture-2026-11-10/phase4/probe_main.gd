extends Node
func _ready() -> void:
	var w: int = DisplayServer.MAIN_WINDOW_ID
	var args: PackedStringArray = OS.get_cmdline_user_args()
	print("AUDIO_SERVER_DRIVER=", AudioServer.call("get_driver_name"))
	print("POS_T0=", DisplayServer.window_get_position(w), " SIZE_T0=", DisplayServer.window_get_size(w), " FOCUS_T0=", DisplayServer.window_is_focused(w), " POPUP_T0=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_POPUP, w))
	if "--before" in args:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_POPUP, true, w)
		print("POPUP_SET_BEFORE flag=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_POPUP, w), " FOCUS=", DisplayServer.window_is_focused(w))
	DisplayServer.window_set_position(Vector2i(-5000, -5000), w)
	DisplayServer.window_set_size(Vector2i(960, 540), w)
	if "--after" in args:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_POPUP, true, w)
		print("POPUP_SET_AFTER flag=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_POPUP, w), " FOCUS=", DisplayServer.window_is_focused(w))
	var trace: String = ""
	var trues: int = 0
	for i in range(60):
		await get_tree().process_frame
		var f: bool = DisplayServer.window_is_focused(w)
		trace += "1" if f else "0"
		if f:
			trues += 1
	print("FOCUS_TRACE_60=", trace, " TRUE_COUNT=", trues)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	print("IMAGE_IS_NULL=", img == null)
	if img != null:
		print("IMG_SIZE=", img.get_size(), " left=", img.get_pixel(240, 270), " right=", img.get_pixel(720, 270))
	print("POS_END=", DisplayServer.window_get_position(w), " SIZE_END=", DisplayServer.window_get_size(w), " FOCUS_END=", DisplayServer.window_is_focused(w), " POPUP_END=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_POPUP, w))
	get_tree().quit()
