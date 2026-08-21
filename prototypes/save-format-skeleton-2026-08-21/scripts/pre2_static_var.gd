class_name Pre2StaticVar
extends RefCounted
# PRE-2:規格要求 SaveFormat 是「純靜態工具集」,而驗證 D(manifest-only 未解碼)
# 要求一個 bytes_to_var 計次器。計次器必須是 static var 才能活在靜態工具集裡。
static var _calls: int = 0

static func bump() -> int:
	_calls += 1
	return _calls

static func calls() -> int:
	return _calls

static func reset() -> void:
	_calls = 0

func probe() -> String:
	reset()
	bump()
	bump()
	bump()
	print("      after 3 bumps, calls() = %d" % calls())
	reset()
	print("      after reset,   calls() = %d" % calls())
	return "PRE2-REACHED-END"
