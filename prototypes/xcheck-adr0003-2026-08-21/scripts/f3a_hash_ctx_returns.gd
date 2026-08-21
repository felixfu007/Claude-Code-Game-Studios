# F3a —— HashingContext 三段式的實際回傳型別。用「把回傳值指派給變數」測 ——
# 若某方法回傳 void,GDScript 會在 parse 階段就報錯,整檔編譯失敗,那本身即是答案。
# 因此本檔刻意與 f3d(功能性測試,不指派回傳值)分開,避免整檔封鎖。
# 本檔使用「短形式」HashingContext.HASH_SHA256。
extends RefCounted

static func probe() -> String:
	var ctx := HashingContext.new()
	var r_start = ctx.start(HashingContext.HASH_SHA256)
	print("      start(HashingContext.HASH_SHA256) -> typeof=%d value=%s  (2=TYPE_INT/Error, 0=TYPE_NIL)" % [typeof(r_start), str(r_start)])
	var r_update = ctx.update("hello".to_utf8_buffer())
	print("      update(PackedByteArray)           -> typeof=%d value=%s" % [typeof(r_update), str(r_update)])
	var r_finish = ctx.finish()
	print("      finish()                          -> typeof=%d size=%d hex=%s" % [typeof(r_finish), (r_finish as PackedByteArray).size(), (r_finish as PackedByteArray).hex_encode()])
	print("      HashingContext.HASH_SHA256 常數值 = %s" % str(HashingContext.HASH_SHA256))
	return "F3a-REACHED-END"

static func probe_error_paths() -> String:
	# 未 start 就 update / finish 的行為(fail-loud 還是靜默?)
	var ctx := HashingContext.new()
	print("      [S1] 未 start 就 update:")
	var e1 = ctx.update("x".to_utf8_buffer())
	print("      [S2] update 回傳 typeof=%d value=%s" % [typeof(e1), str(e1)])
	print("      [S3] 未 start 就 finish:")
	var e2 = ctx.finish()
	print("      [S4] finish 回傳 typeof=%d size=%d" % [typeof(e2), (e2 as PackedByteArray).size()])
	return "F3a-errpath-REACHED-END"
