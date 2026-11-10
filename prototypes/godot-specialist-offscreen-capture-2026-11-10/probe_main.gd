extends Node
func _ready() -> void:
	var w: int = DisplayServer.MAIN_WINDOW_ID
	print("DS_NAME=", DisplayServer.get_name())
	print("SETTING no_focus=", ProjectSettings.get_setting("display/window/size/no_focus"), " init_pos=", ProjectSettings.get_setting("display/window/size/initial_position"), " type=", ProjectSettings.get_setting("display/window/size/initial_position_type"))
	print("SCREEN_COUNT=", DisplayServer.get_screen_count(), " primary_rect=", DisplayServer.screen_get_position(0), DisplayServer.screen_get_size(0))
	print("AUDIO_SETTING driver=", ProjectSettings.get_setting("audio/driver/driver", "n/a"))
	if OS.has_method("get_audio_driver_name"):
		print("AUDIO_OS_DRIVER=", OS.call("get_audio_driver_name", 0), " count=", OS.call("get_audio_driver_count"))
	if AudioServer.has_method("get_driver_name"):
		print("AUDIO_SERVER_DRIVER=", AudioServer.call("get_driver_name"))
	print("AUDIO_OUTPUT_DEVICE=", AudioServer.output_device, " list=", AudioServer.get_output_device_list(), " mix_rate=", AudioServer.get_mix_rate())
	if "--setpos" in OS.get_cmdline_user_args():
		DisplayServer.window_set_position(Vector2i(-5000, -5000), w)
		print("SETPOS_CALLED")
	print("POS_T0=", DisplayServer.window_get_position(w), " FOCUS_T0=", DisplayServer.window_is_focused(w), " MODE=", DisplayServer.window_get_mode(w))
	for i in range(10):
		await get_tree().process_frame
		if i == 0 or i == 4 or i == 9:
			print("POS_F", i, "=", DisplayServer.window_get_position(w), " FOCUS=", DisplayServer.window_is_focused(w))
	await RenderingServer.frame_post_draw
	print("POST_DRAW_REACHED")
	var img: Image = get_viewport().get_texture().get_image()
	print("IMAGE_IS_NULL=", img == null)
	if img != null:
		print("IMG_SIZE=", img.get_size(), " left=", img.get_pixel(40, 90), " right=", img.get_pixel(240, 90))
	print("POS_END=", DisplayServer.window_get_position(w), " FOCUS_END=", DisplayServer.window_is_focused(w))
	get_tree().quit()
