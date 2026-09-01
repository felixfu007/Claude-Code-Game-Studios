extends Node
# ADR-0005 Probe #10 —— NOTIFICATION_APPLICATION_FOCUS_IN/_OUT 相對 process_priority 的時序。
# 本檔只負責記錄與逾時結束;真實的 OS 焦點切換由外部腳本(PowerShell alt-tab 模擬)負責,
# 本檔絕不自己呼叫 notification() 模擬 —— 那樣就只是在測自己的程式碼,不是測引擎。

const Recorder := preload("res://scripts/probe10_recorder.gd")

const MAX_FRAMES := 720   # ~12s @60fps 安全逾時,足以涵蓋外部腳本的 alt-tab 排程

var _log: Array = []
var _seq: int = 0


func _ready() -> void:
	get_window().title = "AdrProbe10Window"
	print("=".repeat(78))
	print("ADR-0005 PROBE #10 —— NOTIFICATION_APPLICATION_FOCUS_IN/_OUT 相對 process_priority 的時序")
	print("Godot: %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	print("視窗標題已設為: %s" % get_window().title)
	print("=".repeat(78))
	print("本視窗只負責記錄與逾時(%d 影格)自動結束 —— 需要外部腳本製造真實 OS 焦點切換" % MAX_FRAMES)
	print("(alt-tab away / back),本檔不主動模擬焦點事件(那樣就只是在測自己的程式碼)。")
	print("")

	var priorities := [-100, -60, -25, 0, 100]
	for i in priorities.size():
		var r = Recorder.new()
		r.label = "R(%d)" % priorities[i]
		r.main = self
		r.process_priority = priorities[i]
		add_child(r)


func log_event(msg: String) -> void:
	var f := Engine.get_process_frames()
	_log.append({"seq": _seq, "frame": f, "msg": msg})
	_seq += 1
	print("%04d  frame=%06d  %s" % [_seq - 1, f, msg])


func log_event_silent(msg: String) -> void:
	var f := Engine.get_process_frames()
	_log.append({"seq": _seq, "frame": f, "msg": msg})
	_seq += 1


func _process(_delta: float) -> void:
	if Engine.get_process_frames() >= MAX_FRAMES:
		_finish()


func _finish() -> void:
	print("")
	print("── FINISH,已跑滿 %d 影格,開始分析 ──" % MAX_FRAMES)
	_analyze()
	get_tree().quit()


func _analyze() -> void:
	var focus_events: Array = []
	for entry in _log:
		var d: Dictionary = entry
		var msg: String = d["msg"]
		if msg.begins_with("FOCUS_OUT") or msg.begins_with("FOCUS_IN"):
			focus_events.append(d)

	if focus_events.size() == 0:
		print("判定:全程沒有偵測到任何 NOTIFICATION_APPLICATION_FOCUS_IN/_OUT。")
		print("      可能原因:外部焦點切換腳本沒有成功執行、時機沒對上視窗存活期間,")
		print("      或本機環境的視窗管理器沒有送出該通知。做不到就是做不到 —— 本次無結果。")
		return

	print("── 偵測到的全部 FOCUS 事件(%d 筆)──" % focus_events.size())
	for entry in focus_events:
		var d: Dictionary = entry
		print("  seq=%04d  frame=%06d  %s" % [d["seq"], d["frame"], d["msg"]])
	print("")

	var by_frame: Dictionary = {}
	for entry in _log:
		var d: Dictionary = entry
		var frame: int = d["frame"]
		if not by_frame.has(frame):
			by_frame[frame] = {"focus_seqs": [], "process_seqs": []}
		var msg: String = d["msg"]
		if msg.begins_with("FOCUS_OUT") or msg.begins_with("FOCUS_IN"):
			by_frame[frame]["focus_seqs"].append(d["seq"])
		elif msg.begins_with("PROCESS"):
			by_frame[frame]["process_seqs"].append(d["seq"])

	print("── 逐影格分析(僅列有 FOCUS 事件的影格)──")
	var frames: Array = by_frame.keys()
	frames.sort()
	for frame in frames:
		var bucket: Dictionary = by_frame[frame]
		var focus_seqs: Array = bucket["focus_seqs"]
		if focus_seqs.size() == 0:
			continue
		var process_seqs: Array = bucket["process_seqs"]
		var min_focus: int = _min_of(focus_seqs)
		var max_focus: int = _max_of(focus_seqs)
		var min_process: int = _min_of(process_seqs) if process_seqs.size() > 0 else -1
		var max_process: int = _max_of(process_seqs) if process_seqs.size() > 0 else -1
		print("  frame=%06d  FOCUS 命中數=%d/5  focus_seq範圍=[%d,%d]  process_seq範圍=[%s,%s]" % [
			frame, focus_seqs.size(), min_focus, max_focus, str(min_process), str(max_process)])
		if process_seqs.size() > 0:
			if max_focus < min_process:
				print("    => 該影格內,全部 FOCUS 通知先於全部 PROCESS —— 乾淨的『先通知後處理』")
			elif min_focus > max_process:
				print("    => 該影格內,全部 FOCUS 通知晚於全部 PROCESS —— 該影格的 _process() 都用舊狀態")
			else:
				print("    => 【交錯】該影格內 FOCUS 通知與 PROCESS 呼叫交錯 —— 部分 recorder 的")
				print("       _process() 在通知抵達前執行、部分在之後,證實 ADR VR #10 的疑慮:")
				print("       同一影格內下游可能讀到新舊混合的視覺狀態。")
	print("")


func _max_of(arr: Array) -> int:
	var m: int = int(arr[0])
	for v in arr:
		if int(v) > m:
			m = int(v)
	return m


func _min_of(arr: Array) -> int:
	var m: int = int(arr[0])
	for v in arr:
		if int(v) < m:
			m = int(v)
	return m
