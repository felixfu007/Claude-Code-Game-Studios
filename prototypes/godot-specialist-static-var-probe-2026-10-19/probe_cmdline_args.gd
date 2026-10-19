extends SceneTree

func _init() -> void:
	print("get_cmdline_args() = ", OS.get_cmdline_args())
	print("get_cmdline_user_args() = ", OS.get_cmdline_user_args())
	quit()
