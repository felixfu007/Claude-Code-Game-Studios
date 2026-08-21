extends RefCounted
# 驗證 B:失敗注入。每一種都必須落在「正確的那一關」,並印出是哪一關攔的。
# 所有注入都刻意「繞過寫入側」:直接改解碼後的信封再用 var_to_bytes 重編,
# 因為真實的損毀不會經過我們的組裝器。

const RECORDS: int = 20

func _valid(rv: int = SkelFixture.GAME_RULESET_VERSION, bad_c: bool = false) -> PackedByteArray:
	var fx := SkelFixture.new()
	var wr := fx.build(RECORDS, rv, bad_c)
	if not wr.ok():
		push_error("fixture build failed")
		return PackedByteArray()
	return wr.buffer

func _env(buf: PackedByteArray) -> Dictionary:
	var d = SaveFormat.deserialize_manifest(buf)
	if not d.ok():
		push_error("cannot decode own envelope: %s" % d.detail)
		return {}
	return d.payload

func _reencode(env: Dictionary) -> PackedByteArray:
	return var_to_bytes(env)

func _report(label: String, res) -> void:
	var names := ["OK", "DATA_CORRUPTED", "VERSION_TOO_NEW", "SEMANTIC_INVALID"]
	print("      [%s] status=%s  攔在=[%s]" % [label, names[res.status], res.stopped_at])
	print("          detail: %s" % res.detail)
	print("          blocks_decoded=%d" % res.blocks_decoded)

func t_b1_block_content_flipped() -> String:
	# 改區塊內容、不改區塊雜湊 -> 必須由「逐區塊雜湊」攔
	var env := _env(_valid())
	var sid: String = FakeAffinitySource.SOURCE_ID
	var raw: PackedByteArray = (env["blocks"] as Dictionary)[sid]
	var mid: int = raw.size() / 2
	var before: int = raw[mid]
	raw[mid] = before ^ 0xFF
	(env["blocks"] as Dictionary)[sid] = raw
	print("      翻轉 blocks['%s'][%d]: %d -> %d(manifest 的 block_hash 保持原值)"
		% [sid, mid, before, raw[mid]])
	var fx := SkelFixture.new()
	var res = fx.reader().read_full(_reencode(env), SkelFixture.GAME_RULESET_VERSION)
	_report("B1 區塊內容被改", res)
	return "B1-REACHED-END"

func t_b2_manifest_metadata_changed() -> String:
	# 改 format_version / source_id 但 payload 不動 -> 必須由「頂層雜湊」攔
	var env := _env(_valid())
	var entry: Dictionary = (env["block_manifest"] as Array)[0]
	print("      manifest[0].source_id=%s format_version %d -> 4"
		% [str(entry["source_id"]), int(entry["format_version"])])
	entry["format_version"] = 4
	var fx := SkelFixture.new()
	var res = fx.reader().read_full(_reencode(env), SkelFixture.GAME_RULESET_VERSION)
	_report("B2a format_version 被改", res)

	var env2 := _env(_valid())
	var e2: Dictionary = (env2["block_manifest"] as Array)[0]
	e2["source_id"] = "affinity_data_poo1"  # 最後一字改成數字 1
	print("      manifest[0].source_id 改成 affinity_data_poo1(blocks 的鍵不動)")
	var res2 = fx.reader().read_full(_reencode(env2), SkelFixture.GAME_RULESET_VERSION)
	_report("B2b source_id 被改", res2)
	return "B2-REACHED-END"

func t_b3_manifest_entry_removed() -> String:
	# 從 manifest 移掉整個區塊條目 -> 必須由「頂層雜湊」攔
	var env := _env(_valid())
	var m: Array = env["block_manifest"]
	print("      移除 manifest 條目 %s(blocks 裡的位元組留著)"
		% str((m[0] as Dictionary)["source_id"]))
	m.remove_at(0)
	var fx := SkelFixture.new()
	var res = fx.reader().read_full(_reencode(env), SkelFixture.GAME_RULESET_VERSION)
	_report("B3 manifest 條目被移除", res)
	return "B3-REACHED-END"

func t_b3b_blocks_entry_removed() -> String:
	# 反方向:manifest 留著,blocks 裡的位元組被移除。
	# 頂層雜湊完全涵蓋不到 blocks 的鍵集合 -> 這一項只能靠讀取器自己的守衛。
	var env := _env(_valid())
	var sid: String = FakeAffinitySource.SOURCE_ID
	(env["blocks"] as Dictionary).erase(sid)
	print("      erase blocks['%s'],manifest 條目保留" % sid)
	var fx := SkelFixture.new()
	var res = fx.reader().read_full(_reencode(env), SkelFixture.GAME_RULESET_VERSION)
	_report("B3b blocks 條目被移除", res)
	return "B3B-REACHED-END"

func t_b4_version_too_new() -> String:
	# 版本號比遊戲新 -> VERSION_TOO_NEW,且必須證明它沒有解碼任何區塊
	var buf := _valid(SkelFixture.GAME_RULESET_VERSION + 4)
	var fx := SkelFixture.new()
	SaveFormat.reset_decode_calls()
	var res = fx.reader().read_full(buf, SkelFixture.GAME_RULESET_VERSION)
	var calls: int = SaveFormat.decode_calls()
	_report("B4 版本太新", res)
	print("          bytes_to_var 呼叫次數 = %d(1 = 只解了外層信封,零區塊)" % calls)
	print("          證明:blocks_decoded=%d" % res.blocks_decoded)
	return "B4-REACHED-END"

func t_b5_validator_unregistered() -> String:
	var buf := _valid()
	var empty := SkelFixture.new(false)  # 刻意留空的登記表
	print("      registry 已登記的 id = %s" % str(empty.registry.registered_ids()))
	var res = empty.reader().read_full(buf, SkelFixture.GAME_RULESET_VERSION)
	_report("B5 驗證器未登記", res)
	return "B5-REACHED-END"

func t_b6_validator_range_violation() -> String:
	# 型別全部合法(c 是 int),只有值域不合 -> 只能由語意驗證器攔
	var buf := _valid(SkelFixture.GAME_RULESET_VERSION, true)
	var fx := SkelFixture.new()
	var res = fx.reader().read_full(buf, SkelFixture.GAME_RULESET_VERSION)
	_report("B6 值域不合(records[0].c = 99)", res)
	return "B6-REACHED-END"

func t_b7_shape_attack_before_hash() -> String:
	# 額外注入(規格沒要求,但實作時發現非做不可的那一關):
	# 把 block_manifest 換成一個 int。步驟 2 需要它才能算雜湊,
	# 所以形狀檢查必須在雜湊之前 —— 沒有 S1B 的話這裡會中止讀取函式。
	var env := _env(_valid())
	env["block_manifest"] = 12345
	var fx := SkelFixture.new()
	var res = fx.reader().read_full(_reencode(env), SkelFixture.GAME_RULESET_VERSION)
	_report("B7 block_manifest 被換成 int", res)

	var env2 := _env(_valid())
	(env2 as Dictionary).erase("top_level_hash")
	var res2 = fx.reader().read_full(_reencode(env2), SkelFixture.GAME_RULESET_VERSION)
	_report("B7b top_level_hash 整個消失", res2)

	var env3 := _env(_valid())
	var m3: Array = env3["block_manifest"]
	var dup: Dictionary = (m3[0] as Dictionary).duplicate()
	m3.append(dup)
	var res3 = fx.reader().read_full(_reencode(env3), SkelFixture.GAME_RULESET_VERSION)
	_report("B7c manifest 出現重複 source_id", res3)
	return "B7-REACHED-END"
