# ============================================================================
# G-1x2 —— 隔離檔:Callable 的種類/物件 ID 內省(存在性不確定)
# ============================================================================
# 隔離理由同 g1x1_callable_arity.gd:RUN-A 的 body_free() 教訓 ——
# 一個用錯的 API 名稱會讓整檔 Parse Error,同檔其他測項全部測不到。
extends RefCounted

static func probe() -> String:
	var t := GProbeTarget.new()
	var cb := Callable(t, "ping")
	print("      bound method : is_standard=%s  is_custom=%s  get_object_id=%d" % [
		str(cb.is_standard()), str(cb.is_custom()), cb.get_object_id()])
	var lam := func(x: int) -> int: return x
	print("      lambda       : is_standard=%s  is_custom=%s  get_object_id=%d" % [
		str(lam.is_standard()), str(lam.is_custom()), lam.get_object_id()])
	return "S-G1x2-REACHED-END"
