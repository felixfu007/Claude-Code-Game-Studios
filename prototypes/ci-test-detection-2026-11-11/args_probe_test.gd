extends GdUnitTestSuite
func test_dump_args() -> void:
	print("ARGPROBE args=", OS.get_cmdline_args(), " display=", DisplayServer.get_name(), " cur=", get_tree().current_scene)
	assert_bool(true).is_true()
