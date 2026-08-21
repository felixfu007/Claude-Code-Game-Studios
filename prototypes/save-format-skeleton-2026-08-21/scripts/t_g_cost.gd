extends RefCounted
# 驗證 G:量成本。典型單槽(約 500 筆記錄)存檔/讀檔各花多少毫秒,閘門佔多少。

const RECORDS: int = 500
const SLOT: String = "user://slot_g.sav"

func _ms(usec: int) -> String:
	return "%.3f ms" % (float(usec) / 1000.0)

func t_g_cost() -> String:
	var src := FakeAffinitySource.new()
	var t0: int = Time.get_ticks_usec()
	var payload: Dictionary = src.export_state(RECORDS)
	var t_gen: int = Time.get_ticks_usec() - t0

	t0 = Time.get_ticks_usec()
	var rej = SaveFormat.validate_payload_types(payload)
	var t_gate: int = Time.get_ticks_usec() - t0

	t0 = Time.get_ticks_usec()
	var buf: PackedByteArray = var_to_bytes(payload)
	var t_encode: int = Time.get_ticks_usec() - t0

	t0 = Time.get_ticks_usec()
	var bh: PackedByteArray = SaveFormat.compute_block_hash(buf)
	var t_hash: int = Time.get_ticks_usec() - t0

	print("      記錄數=%d  編碼後區塊大小=%d bytes (%.1f KB)"
		% [RECORDS, buf.size(), float(buf.size()) / 1024.0])
	print("      產生 payload        : %s" % _ms(t_gen))
	print("      型別閘門(單獨)     : %s   rejection=%d" % [_ms(t_gate), rej])
	print("      var_to_bytes(單獨)  : %s" % _ms(t_encode))
	print("      SHA-256(單獨)       : %s   digest=%s" % [_ms(t_hash), bh.hex_encode().substr(0, 16)])

	var fx := SkelFixture.new()
	t0 = Time.get_ticks_usec()
	var wr := fx.build(RECORDS)
	var t_build: int = Time.get_ticks_usec() - t0
	print("      SaveWriter.build 全程: %s  (2 區塊,含兩層雜湊 + 信封)  信封=%d bytes"
		% [_ms(t_build), wr.buffer.size()])

	t0 = Time.get_ticks_usec()
	SkelFixture.write_file(SLOT, wr.buffer)
	var t_fw: int = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var back := SkelFixture.read_file(SLOT)
	var t_fr: int = Time.get_ticks_usec() - t0
	print("      檔案寫入            : %s" % _ms(t_fw))
	print("      檔案讀取            : %s" % _ms(t_fr))

	var rd := fx.reader()
	t0 = Time.get_ticks_usec()
	var r1 = rd.read_manifest_only(back, SkelFixture.GAME_RULESET_VERSION)
	var t_mo: int = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var r2 = rd.read_full(back, SkelFixture.GAME_RULESET_VERSION)
	var t_full: int = Time.get_ticks_usec() - t0
	print("      read_manifest_only  : %s   status=%d" % [_ms(t_mo), r1.status])
	print("      read_full           : %s   status=%d blocks=%d"
		% [_ms(t_full), r2.status, r2.blocks_decoded])

	# 讀取側閘門佔 read_full 多少
	var decoded: Dictionary = r2.payloads[FakeAffinitySource.SOURCE_ID]
	t0 = Time.get_ticks_usec()
	SaveFormat.validate_payload_types(decoded)
	var t_rgate: int = Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	var ir: SaveImportResult = src.validate_semantics(decoded)
	var t_sem: int = Time.get_ticks_usec() - t0
	print("      其中讀取側型別閘門  : %s  (%.1f%% of read_full)"
		% [_ms(t_rgate), 100.0 * float(t_rgate) / float(max(t_full, 1))])
	print("      其中語意驗證器      : %s  (%.1f%% of read_full)  ok=%s"
		% [_ms(t_sem), 100.0 * float(t_sem) / float(max(t_full, 1)), str(ir.ok)])
	print("      存檔合計(產生+閘門+編碼+雜湊+信封+檔案) 約 %s"
		% _ms(t_gen + t_build + t_fw))
	print("      讀檔合計(檔案+read_full) 約 %s" % _ms(t_fr + t_full))
	return "G-REACHED-END"
