extends Node
func _ready() -> void:
	var w: int = DisplayServer.MAIN_WINDOW_ID
	print("TICKS_AT_READY_MS=", Time.get_ticks_msec())
	print("SETTING borderless=", ProjectSettings.get_setting("display/window/size/borderless"), " no_focus=", ProjectSettings.get_setting("display/window/size/no_focus"), " w_override=", ProjectSettings.get_setting("display/window/size/window_width_override"))
	print("MIN_SIZE=", DisplayServer.window_get_min_size(w), " BORDERLESS_FLAG=", DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, w))
	print("AUDIO_SERVER_DRIVER=", AudioServer.call("get_driver_name"))
	print("POS_T0=", DisplayServer.window_get_position(w), " SIZE_T0=", DisplayServer.window_get_size(w), " VP_T0=", get_viewport().size, " FOCUS_T0=", DisplayServer.window_is_focused(w))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--poswonly" in args:
		DisplayServer.window_set_position(Vector2i(-5000, -5000), w)
	elif "--sizefirst" in args:
		DisplayServer.window_set_size(Vector2i(960, 540), w)
		print("MID POS=", DisplayServer.window_get_position(w), " FOCUS=", DisplayServer.window_is_focused(w))
		DisplayServer.window_set_position(Vector2i(-5000, -5000), w)
	else:
		DisplayServer.window_set_position(Vector2i(-5000, -5000), w)
		DisplayServer.window_set_size(Vector2i(960, 540), w)
	print("AFTER_SET POS=", DisplayServer.window_get_position(w), " SIZE=", DisplayServer.window_get_size(w))
	for i in range(60):
		await get_tree().process_frame
		if i in [0, 1, 5, 30, 59]:
			print("F", i, " POS=", DisplayServer.window_get_position(w), " SIZE=", DisplayServer.window_get_size(w), " VP=", get_viewport().size, " FOCUS=", DisplayServer.window_is_focused(w))
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	print("IMAGE_IS_NULL=", img == null)
	if img != null:
		print("IMG_SIZE=", img.get_size(), " left=", img.get_pixel(240, 270), " right=", img.get_pixel(720, 270))
	print("POS_END=", DisplayServer.window_get_position(w), " SIZE_END=", DisplayServer.window_get_size(w), " FOCUS_END=", DisplayServer.window_is_focused(w), " TICKS_END_MS=", Time.get_ticks_msec())
	get_tree().quit()
