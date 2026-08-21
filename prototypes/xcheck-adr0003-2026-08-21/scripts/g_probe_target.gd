class_name GProbeTarget extends RefCounted
# ============================================================================
# 探針 G 的「可觀測受害者」—— 給 G-1 用的活體物件
# ============================================================================
# 存在理由:G-1c / G-1d 要回答的不是「Callable/Signal 還原得出來嗎」,而是
# 「還原出來的東西還能不能真的動」。因此被綁定的方法與被連接的訊號處理函式
# 必須在真的被執行時留下**無法被誤讀的**痕跡(!!!! 標記 + 計數器)。
# 若 log 裡出現 "ACTUALLY EXECUTED",那就是還原物仍具備執行能力的直接證據;
# 若沒出現,則是「空殼」的證據。兩者對存檔系統的威脅模型完全不同。

signal pinged(v: int)

var call_count: int = 0
var emit_count: int = 0
var last_arg: int = -1
var tag: String = "GPT-DEFAULT"

func ping(v: int) -> String:
	call_count += 1
	last_arg = v
	print("      !!!! GProbeTarget.ping() ACTUALLY EXECUTED  v=%d  call_count=%d  tag=%s !!!!" % [v, call_count, tag])
	return "PING-EXECUTED-%d" % v

func on_pinged(v: int) -> void:
	emit_count += 1
	print("      !!!! GProbeTarget.on_pinged() ACTUALLY EXECUTED  v=%d  emit_count=%d !!!!" % [v, emit_count])
