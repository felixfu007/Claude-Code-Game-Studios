extends RefCounted
# 驗證 D:manifest-only 路徑真的沒解碼任何區塊 —— 用計數器證明,不是「應該沒有」。
# SaveFormat._decode() 是全骨架唯一的 bytes_to_var() 呼叫點。

const RECORDS: int = 30

func t_d_counter_proof() -> String:
	var fx := SkelFixture.new()
	var wr := fx.build(RECORDS)
	if not wr.ok():
		return "D-ABORT-WRITER-FAILED"
	var n_blocks: int = fx.writer_input(RECORDS).size()
	print("      區塊數 = %d" % n_blocks)

	SaveFormat.reset_decode_calls()
	var r1 = fx.reader().read_manifest_only(wr.buffer, SkelFixture.GAME_RULESET_VERSION)
	var c1: int = SaveFormat.decode_calls()
	print("      read_manifest_only : status=%d decode_calls=%d blocks_decoded=%d"
		% [r1.status, c1, r1.blocks_decoded])
	print("        manifest 讀到了嗎: ruleset_version=%d, 條目數=%d, ids=%s"
		% [r1.ruleset_version, r1.manifest.size(), str(_ids(r1.manifest))])
	print("        payloads 是空的嗎: size=%d" % r1.payloads.size())
	print("        期望 decode_calls = 1(只有外層信封)-> %s" % str(c1 == 1))

	SaveFormat.reset_decode_calls()
	var r2 = fx.reader().read_full(wr.buffer, SkelFixture.GAME_RULESET_VERSION)
	var c2: int = SaveFormat.decode_calls()
	print("      read_full          : status=%d decode_calls=%d blocks_decoded=%d"
		% [r2.status, c2, r2.blocks_decoded])
	print("        期望 decode_calls = 1 + %d = %d -> %s"
		% [n_blocks, 1 + n_blocks, str(c2 == 1 + n_blocks)])

	# 分層結構本身:外層解碼後,blocks 的值是不是「還沒被解讀的位元組」
	var env = SaveFormat.deserialize_manifest(wr.buffer)
	var blocks: Dictionary = env.payload["blocks"]
	for sid in blocks:
		print("        blocks['%s'] typeof=%d (PACKED_BYTE_ARRAY=%d) size=%d"
			% [str(sid), typeof(blocks[sid]), TYPE_PACKED_BYTE_ARRAY,
				(blocks[sid] as PackedByteArray).size()])
	return "D-REACHED-END"

func _ids(manifest: Array) -> Array:
	var out: Array = []
	for e in manifest:
		out.append((e as Dictionary)["source_id"])
	return out
