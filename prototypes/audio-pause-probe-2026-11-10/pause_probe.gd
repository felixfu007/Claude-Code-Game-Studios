extends SceneTree
## 探針:tree.paused 對 AudioStreamPlayer / Tween / signal 回呼的影響。headless + Dummy 音訊驅動。
## 不引用任何 production 程式碼。

var _signal_hits: int = 0

func _stream() -> AudioStreamWAV:
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = 8000
	var d: PackedByteArray = PackedByteArray()
	d.resize(8000 * 20) # 20 秒
	s.data = d
	return s

func _pos(p: AudioStreamPlayer) -> String:
	return "playing=%s stream_paused=%s pos=%.4f" % [p.playing, p.stream_paused, p.get_playback_position()]

func _wait_real(sec: float) -> void:
	await create_timer(sec, true).timeout

func _make(parent: Node, mode: Node.ProcessMode, name_: String) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = name_
	p.process_mode = mode
	p.stream = _stream()
	parent.add_child(p)
	return p

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	print("PROBE engine=", Engine.get_version_info()["string"], " audio_driver=", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "n/a")
	var holder: Node = Node.new()
	root.add_child(holder)
	var inh: AudioStreamPlayer = _make(holder, Node.PROCESS_MODE_INHERIT, "Inherit")
	var alw: AudioStreamPlayer = _make(holder, Node.PROCESS_MODE_ALWAYS, "Always")
	inh.play(); alw.play()
	await _wait_real(0.5)
	print("T0 baseline unpaused INHERIT: ", _pos(inh))
	print("T0 baseline unpaused ALWAYS : ", _pos(alw))
	paused = true
	await process_frame
	print("T1 just paused INHERIT: ", _pos(inh))
	print("T1 just paused ALWAYS : ", _pos(alw))
	var i0: float = inh.get_playback_position(); var a0: float = alw.get_playback_position()
	await _wait_real(0.5)
	print("T1 +0.5s paused INHERIT: ", _pos(inh), " delta=", inh.get_playback_position() - i0)
	print("T1 +0.5s paused ALWAYS : ", _pos(alw), " delta=", alw.get_playback_position() - a0)

	# T3 在暫停中對 INHERIT / ALWAYS 播放器呼叫 play()
	var inh2: AudioStreamPlayer = _make(holder, Node.PROCESS_MODE_INHERIT, "Inherit2")
	var alw2: AudioStreamPlayer = _make(holder, Node.PROCESS_MODE_ALWAYS, "Always2")
	inh2.play(); alw2.play()
	await _wait_real(0.5)
	print("T3 play() while paused INHERIT: ", _pos(inh2))
	print("T3 play() while paused ALWAYS : ", _pos(alw2))

	# T4 Tween 綁節點,暫停中推進?
	var ti: AudioStreamPlayer = _make(holder, Node.PROCESS_MODE_INHERIT, "TweenInherit")
	var ta: AudioStreamPlayer = _make(holder, Node.PROCESS_MODE_ALWAYS, "TweenAlways")
	ti.volume_db = -40.0; ta.volume_db = -40.0
	var tw_i: Tween = ti.create_tween()
	tw_i.tween_property(ti, "volume_db", 0.0, 0.2)
	var tw_a: Tween = ta.create_tween()
	tw_a.tween_property(ta, "volume_db", 0.0, 0.2)
	await _wait_real(1.0)
	print("T4 tween under pause INHERIT-bound: volume_db=", ti.volume_db, " running=", tw_i.is_running())
	print("T4 tween under pause ALWAYS-bound : volume_db=", ta.volume_db, " running=", tw_a.is_running())

	# T5 signal 回呼在暫停中是否仍觸發(連到 INHERIT 節點的方法)
	var btn: Button = Button.new()
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	holder.add_child(btn)
	btn.pressed.connect(func() -> void: _signal_hits += 1)
	btn.pressed.emit()
	print("T5 signal callback while paused: hits=", _signal_hits)

	# T6 解除暫停後 INHERIT 是否續播
	paused = false
	await _wait_real(0.5)
	print("T6 unpaused again INHERIT: ", _pos(inh), " (pos before pause ~", i0, ")")
	print("T6 unpaused again INHERIT2(play during pause): ", _pos(inh2))
	quit()
