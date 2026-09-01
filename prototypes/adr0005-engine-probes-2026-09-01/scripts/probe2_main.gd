extends Node
# ADR-0005 Probe #2 —— `_input()` 是否於整幀派發完畢後才進 `_process()` 鏈。
# 場景根節點腳本。詳見 README.md「探針 #2 的設計」。

const Recorder := preload("res://scripts/probe2_recorder.gd")
const Injector := preload("res://scripts/probe2_injector.gd")

var _log: Array = []   # Array of Dictionary {seq:int, frame:int, msg:String}
var _seq: int = 0
var _done := false
var _grace_frames := 0
const GRACE_FRAME_LIMIT := 30
const SAFETY_FRAME_LIMIT := 3000


func _ready() -> void:
	print("=".repeat(78))
	print("ADR-0005 PROBE #2 —— _input() 是否於整幀派發完畢後才進 _process() 鏈")
	print("Godot: %s" % str(Engine.get_version_info().get("string", "<unknown>")))
	print("=".repeat(78))
	print("方法:5 個 recorder(process_priority = -100/-60/-25/0/100,對照機制六六行為者的")
	print("實際排布),每個都有 _input() 與 _process() 覆寫,寫進同一份單執行緒的序列 log。")
	print("1 個 injector,每 0.35 秒呼叫一次 Input.parse_input_event() 注入 KEY_UP 按下事件,")
	print("共注入 6 次。判定方式:比對 log 的**序列位置**(單執行緒下即嚴格執行順序,不靠時間戳),")
	print("檢查『偵測到事件的那一影格』內,5 個 recorder 的 INPUT 紀錄是否全部早於")
	print("5 個 recorder 的 PROCESS 紀錄。")
	print("")

	var priorities := [-100, -60, -25, 0, 100]
	for i in priorities.size():
		var r = Recorder.new()
		r.label = "R(%d)" % priorities[i]
		r.main = self
		r.process_priority = priorities[i]
		add_child(r)

	var inj = Injector.new()
	inj.main = self
	add_child(inj)


func log_event(msg: String) -> void:
	var f := Engine.get_process_frames()
	_log.append({"seq": _seq, "frame": f, "msg": msg})
	_seq += 1


func on_injections_done() -> void:
	_done = true


func _process(_delta: float) -> void:
	if _done:
		_grace_frames += 1
		if _grace_frames > GRACE_FRAME_LIMIT:
			_finish()
	elif Engine.get_process_frames() > SAFETY_FRAME_LIMIT:
		print("!! 安全逾時(%d 影格)仍未完成注入序列,強制結束。" % SAFETY_FRAME_LIMIT)
		_finish()


func _finish() -> void:
	print("── 完整 log(%d 筆,依序列順序)──" % _log.size())
	for entry in _log:
		var d: Dictionary = entry
		print("%04d  frame=%06d  %s" % [d["seq"], d["frame"], d["msg"]])
	print("")
	_analyze()
	get_tree().quit()


func _analyze() -> void:
	var by_frame: Dictionary = {}
	for entry in _log:
		var d: Dictionary = entry
		var frame: int = d["frame"]
		if not by_frame.has(frame):
			by_frame[frame] = {"input_seqs": [], "process_seqs": []}
		var msg: String = d["msg"]
		if msg.begins_with("INPUT"):
			by_frame[frame]["input_seqs"].append(d["seq"])
		elif msg.begins_with("PROCESS"):
			by_frame[frame]["process_seqs"].append(d["seq"])

	print("── 逐影格分析(僅列有 INPUT 紀錄的影格)──")
	var pass_count := 0
	var fail_count := 0
	var frames: Array = by_frame.keys()
	frames.sort()
	for frame in frames:
		var bucket: Dictionary = by_frame[frame]
		var input_seqs: Array = bucket["input_seqs"]
		var process_seqs: Array = bucket["process_seqs"]
		if input_seqs.size() == 0:
			continue
		var max_input: int = _max_of(input_seqs)
		var min_process: int = _min_of(process_seqs) if process_seqs.size() > 0 else -1
		var ok: bool = (process_seqs.size() == 0) or (max_input < min_process)
		print("  frame=%06d  INPUT 命中數=%d/5  max(INPUT seq)=%d  min(PROCESS seq)=%s  => %s" % [
			frame, input_seqs.size(), max_input, str(min_process), ("PASS" if ok else "FAIL")])
		if ok:
			pass_count += 1
		else:
			fail_count += 1

	print("")
	print("總結:有 INPUT 紀錄的影格數=%d  PASS=%d  FAIL=%d" % [pass_count + fail_count, pass_count, fail_count])
	print("")
	if pass_count > 0 and fail_count == 0:
		print("判定:實測支持 ADR-0005 VR #2 的前提 —— 該影格全部 _input() 已派發完畢")
		print("(所有 recorder 的 INPUT 紀錄序號皆小於該影格全部 PROCESS 紀錄序號),才進入")
		print("_process() 鏈。機制六『process_priority = -100 的裁定者必然早於任何讀取方』")
		print("的定序基礎在本次測試的 %d 次獨立注入下皆成立、可重現。" % pass_count)
	elif fail_count > 0:
		print("判定:發現至少 %d 次注入違反『_input() 全數完成後才進 _process()』的前提 ——" % fail_count)
		print("機制六的定序基礎需要重新檢視,見上方逐影格明細找出是哪個 recorder 在哪個時點例外。")
	else:
		print("判定:0 次注入產生任何 INPUT 命中 —— Input.parse_input_event() 在本執行模式下")
		print("似乎沒有觸發 _input()(可能是 headless 模式的限制)。本結果不能用來回答 VR #2,")
		print("需要切換到非 headless(真實視窗)模式重跑。")


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
