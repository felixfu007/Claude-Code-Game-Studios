extends SceneTree
func _init() -> void:
	var pl := AudioStreamPlayer.new()
	root.add_child(pl)
	pl.volume_db = -40.0
	var tw := create_tween()
	tw.tween_property(pl, "volume_db", 0.0, 0.3)
	print("Q3 start volume_db=", pl.volume_db)
	var t0 := Time.get_ticks_msec()
	var frames := 0
	while tw.is_running() and frames < 600:
		await process_frame
		frames += 1
		if frames in [1, 5, 10]:
			print("Q3 frame ", frames, " volume_db=", pl.volume_db)
	print("Q3 end frames=", frames, " ms=", Time.get_ticks_msec() - t0, " volume_db=", pl.volume_db, " running=", tw.is_running())
	# node-bound tween
	var pl2 := AudioStreamPlayer.new()
	root.add_child(pl2)
	pl2.volume_db = 0.0
	var tw2 := pl2.create_tween()
	tw2.tween_property(pl2, "volume_db", -40.0, 0.2)
	await create_timer(0.4).timeout
	print("Q3 node-bound tween final volume_db=", pl2.volume_db)
	quit()
