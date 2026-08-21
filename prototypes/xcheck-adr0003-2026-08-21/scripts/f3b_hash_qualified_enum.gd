# F3b —— 完整路徑形式 HashingContext.HashType.HASH_SHA256 是否可用。
# ADR-0003 第 20 行 VR#3 明文問「HashingContext.HASH_SHA256,或完整路徑
# HashingContext.HashType.HASH_SHA256」哪一個(或兩個都)可用。
# 單獨一檔:若此形式不存在則為 parse error,不可拖累 f3a/f3d。
extends RefCounted

static func probe() -> String:
	var v := HashingContext.HashType.HASH_SHA256
	print("      HashingContext.HashType.HASH_SHA256 = %s (typeof=%d)" % [str(v), typeof(v)])
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HashType.HASH_SHA256)
	ctx.update("abc".to_utf8_buffer())
	print("      以完整路徑形式 start() 之後 finish() = %s" % ctx.finish().hex_encode())
	return "F3b-REACHED-END"
