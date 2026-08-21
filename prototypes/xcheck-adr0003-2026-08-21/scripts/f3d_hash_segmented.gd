# F3d —— (1) ClassDB 對 HashingContext 的真實簽章內省(HashingContext 是登記類別,
#            與 F1 的全域工具函式不同,ClassDB 內省在此可用);
#        (2) F3b 分段一致性:update() 分兩段 vs 一次餵入完整緩衝區;
#        (3) 對照已知的 SHA-256("abc") 標準答案,獨立確認演算法真的是 SHA-256。
# 本檔刻意「不指派」start()/update() 的回傳值,故不受回傳型別是否為 void 影響。
extends RefCounted

const KNOWN_SHA256_ABC := "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"

static func probe_classdb() -> String:
	print("      ClassDB.class_exists('HashingContext') = %s" % str(ClassDB.class_exists("HashingContext")))
	for m in ClassDB.class_get_method_list("HashingContext", true):
		print("        method: %s" % str(m))
	print("      -- enum constants --")
	for e in ClassDB.class_get_enum_list("HashingContext", true):
		print("        enum %s -> %s" % [str(e), str(ClassDB.class_get_enum_constants("HashingContext", e, true))])
	print("      -- integer constants --")
	for c in ClassDB.class_get_integer_constant_list("HashingContext", true):
		print("        const %s = %s" % [str(c), str(ClassDB.class_get_integer_constant("HashingContext", c))])
	return "F3d-classdb-REACHED-END"

static func _sha256_oneshot(buf: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(buf)
	return ctx.finish()

static func _sha256_segmented(parts: Array) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for p in parts:
		ctx.update(p)
	return ctx.finish()

static func probe_known_answer() -> String:
	var got := _sha256_oneshot("abc".to_utf8_buffer()).hex_encode()
	print("      SHA-256('abc') got      = %s" % got)
	print("      SHA-256('abc') expected = %s" % KNOWN_SHA256_ABC)
	print("      MATCHES KNOWN ANSWER    = %s" % str(got == KNOWN_SHA256_ABC))
	return "F3d-known-REACHED-END"

static func probe_segmented() -> String:
	var whole := "hello world, this is the affinity delta log payload".to_utf8_buffer()
	var p1 := "hello world, ".to_utf8_buffer()
	var p2 := "this is the affinity delta log payload".to_utf8_buffer()
	var one := _sha256_oneshot(whole).hex_encode()
	var seg2 := _sha256_segmented([p1, p2]).hex_encode()
	var seg_many := _sha256_segmented([
		"hello ".to_utf8_buffer(), "world, ".to_utf8_buffer(),
		"this is the ".to_utf8_buffer(), "affinity delta log payload".to_utf8_buffer(),
	]).hex_encode()
	print("      one-shot      = %s" % one)
	print("      2-segment     = %s   same=%s" % [seg2, str(seg2 == one)])
	print("      4-segment     = %s   same=%s" % [seg_many, str(seg_many == one)])
	return "F3d-segmented-REACHED-END"

static func probe_convenience_equivalence(pba_ok: bool, str_ok: bool) -> String:
	# 由 runner 依 f3c1/f3c2 的編譯結果決定是否呼叫;此處只做三段式的基準值。
	var buf := "abc".to_utf8_buffer()
	print("      HashingContext 三段式 SHA-256('abc') = %s" % _sha256_oneshot(buf).hex_encode())
	print("      (便利方法的輸出見 F3c 各項;pba_ok=%s str_ok=%s)" % [str(pba_ok), str(str_ok)])
	return "F3d-conv-REACHED-END"

static func probe_empty_input() -> String:
	# 空輸入的 SHA-256 標準答案
	var got := _sha256_oneshot(PackedByteArray()).hex_encode()
	print("      SHA-256(empty) = %s" % got)
	print("      expected       = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	print("      match = %s" % str(got == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
	return "F3d-empty-REACHED-END"
