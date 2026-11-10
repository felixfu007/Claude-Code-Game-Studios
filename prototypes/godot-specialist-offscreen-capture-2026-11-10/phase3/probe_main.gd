extends Node
func _flags() -> String:
	var out: PackedStringArray = []
	for n in ClassDB.class_get_integer_constant_list("DisplayServer"):
		if n.begins_with("WINDOW_FLAG_") and n != "WINDOW_FLAG_MAX":
			out.append("%s=%d" % [n, ClassDB.class_get_integer_constant("DisplayServer", n)])
	return ", ".join(out)
func _ready() -> void:
	var w: int = DisplayServer.MAIN_WINDOW_ID
	var args: PackedStringArray = OS.get_cmdline_user_args()
	print("FLAG_ENUMS: ", _flags())
	print("AUDIO_SERVER_DRIVER=", AudioServer.call("get_driver_name"))
	print("POS_T0=", DisplayServer.window_get_position(w), " SIZE_T0=", DisplayServer.window_get_size(w), " FOCUS_T0=", DisplayServer.window_is_focused(w), " NOFOCUS_FLAG_T0=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, w))
	if "--pre" in args:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, w)
		print("PRE_RESET done FOCUS=", DisplayServer.window_is_focused(w))
	DisplayServer.window_set_position(Vector2i(-5000, -5000), w)
	print("AFTER_POS FOCUS=", DisplayServer.window_is_focused(w))
	DisplayServer.window_set_size(Vector2i(960, 540), w)
	print("AFTER_SIZE FOCUS=", DisplayServer.window_is_focused(w))
	if "--post" in args:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, w)
		print("POST_RESET NOFOCUS_FLAG=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, w), " FOCUS=", DisplayServer.window_is_focused(w))
	if "--alt" in args:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true, w)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_POPUP_WM_HINT, true, w)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true, w)
		print("ALT_FLAGS set FOCUS=", DisplayServer.window_is_focused(w))
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
	print("POS_END=", DisplayServer.window_get_position(w), " SIZE_END=", DisplayServer.window_get_size(w), " FOCUS_END=", DisplayServer.window_is_focused(w))
	get_tree().quit()
