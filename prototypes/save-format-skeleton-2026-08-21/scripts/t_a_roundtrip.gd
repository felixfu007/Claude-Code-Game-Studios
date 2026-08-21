extends RefCounted
# 驗證 A:完整往返走真實檔案。寫 user:// -> close() -> 重新開檔讀回 -> 逐欄位比對。

const SLOT: String = "user://slot_a.sav"
const RECORDS: int = 60

func t_roundtrip_through_real_file() -> String:
	var fx := SkelFixture.new()
	var wr := fx.build(RECORDS)
	print("      writer status=%d stopped_at=[%s] buffer=%d bytes"
		% [wr.status, wr.stopped_at, wr.buffer.size()])
	if not wr.ok():
		return "A-ABORT-WRITER-FAILED"

	var werr := SkelFixture.write_file(SLOT, wr.buffer)
	if werr != "":
		print("      %s" % werr)
		return "A-ABORT-FILEWRITE-FAILED"
	print("      wrote %s ; file_exists=%s"
		% [SLOT, str(FileAccess.file_exists(SLOT))])

	var back := SkelFixture.read_file(SLOT)
	print("      read back %d bytes ; byte-identical to in-memory buffer = %s"
		% [back.size(), str(back == wr.buffer)])
	if back.size() == 0:
		return "A-ABORT-FILEREAD-FAILED"

	var rd := fx.reader()
	var res := rd.read_full(back, SkelFixture.GAME_RULESET_VERSION)
	print("      read_full status=%d stopped_at=[%s] detail=[%s] blocks_decoded=%d"
		% [res.status, res.stopped_at, res.detail, res.blocks_decoded])
	if not res.ok():
		return "A-ABORT-READ-FAILED"
	print("      manifest 正規順序 = %s" % str(_ids(res.manifest)))

	# 逐欄位比對:期望值由同一個決定性產生器重新產生
	var expected: Dictionary = FakeAffinitySource.new().export_state(RECORDS)
	var actual: Dictionary = res.payloads[FakeAffinitySource.SOURCE_ID]
	var report := _compare_affinity(expected, actual)
	print("      逐欄位比對: %s" % ("ALL FIELDS IDENTICAL" if report == "" else report))
	print("      (整體 == 比較,僅作參考) %s" % str(expected == actual))

	var tact: Dictionary = res.payloads[SkelFixture.TACTICAL_ID]
	print("      第二區塊 tactical_board = %s" % str(tact))
	return "A-REACHED-END"

func _ids(manifest: Array) -> Array:
	var out: Array = []
	for e in manifest:
		out.append((e as Dictionary)["source_id"])
	return out

func _compare_affinity(exp: Dictionary, act: Dictionary) -> String:
	for k in exp.keys():
		if not act.has(k):
			return "缺少頂層鍵 %s" % str(k)
	if act.size() != exp.size():
		return "頂層鍵數不同 %d vs %d" % [act.size(), exp.size()]
	var er: Array = exp["records"]
	if typeof(act["records"]) != TYPE_ARRAY:
		return "records typeof=%d" % typeof(act["records"])
	var ar: Array = act["records"]
	if er.size() != ar.size():
		return "records 筆數 %d vs %d" % [ar.size(), er.size()]
	for i in er.size():
		var e: Dictionary = er[i]
		var a: Dictionary = ar[i]
		for f in FakeAffinitySource.RECORD_KEYS:
			if not a.has(f):
				return "records[%d] 缺欄位 %s" % [i, f]
			if typeof(a[f]) != typeof(e[f]):
				return "records[%d].%s typeof %d vs %d" % [i, f, typeof(a[f]), typeof(e[f])]
			if a[f] != e[f]:
				return "records[%d].%s 值不同 %s vs %s" % [i, f, str(a[f]), str(e[f])]
	var em: Array = exp["campaign_tick_marks"]
	var am: Array = act["campaign_tick_marks"]
	if em.size() != am.size():
		return "campaign_tick_marks 長度 %d vs %d" % [am.size(), em.size()]
	for i in em.size():
		if am[i] != em[i] or typeof(am[i]) != typeof(em[i]):
			return "campaign_tick_marks[%d] %s vs %s" % [i, str(am[i]), str(em[i])]
	if am.is_typed() != em.is_typed():
		return "campaign_tick_marks is_typed %s vs %s" % [str(am.is_typed()), str(em.is_typed())]
	var ed: Dictionary = exp["death_marks"]
	var ad: Dictionary = act["death_marks"]
	if ed.size() != ad.size():
		return "death_marks 大小 %d vs %d" % [ad.size(), ed.size()]
	for k in ed:
		if not ad.has(k):
			return "death_marks 缺鍵 %s" % str(k)
		if ad[k] != ed[k] or typeof(ad[k]) != typeof(ed[k]):
			return "death_marks[%s] %s vs %s" % [str(k), str(ad[k]), str(ed[k])]
	return ""
