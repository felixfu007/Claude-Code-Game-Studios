# ============================================================================
# G-1x1 —— 隔離檔:Callable 的引數數量內省(arity 不確定)
# ============================================================================
# 隔離理由(本探針 RUN-A 的實付代價):
#   G-1 第一版把 PhysicsServer2D.body_free() 寫在 g1_callable_signal_rid.gd 裡。
#   該方法在 4.7.1 不存在 -> **整檔 Parse Error** -> G-1a~G-1f 十個測項
#   一項都沒跑到,失敗形狀是「什麼都沒印出來」而不是「那一項失敗」。
#   因此凡是我沒有查證過存在性/arity 的呼叫,一律各自一檔:
#   編譯失敗只損失這一檔,而「編譯失敗」本身就是該項的答案。
extends RefCounted

static func probe() -> String:
	var t := GProbeTarget.new()
	var cb := Callable(t, "ping")
	print("      get_argument_count() = %d" % cb.get_argument_count())
	print("      get_bound_arguments_count() = %d" % cb.get_bound_arguments_count())
	return "S-G1x1-REACHED-END"
