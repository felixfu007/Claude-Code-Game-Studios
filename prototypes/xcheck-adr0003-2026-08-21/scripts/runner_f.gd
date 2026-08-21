extends Node
# ============================================================================
# 探針 F / 階段 2 —— ADR-0003 的 F2 / F3 / F4' / F5
# ============================================================================
# 目標檔:docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md
#
# 階段 1(scenes/F1.tscn,logs/probeF1-signatures-unfiltered.txt)已實測:
#   bytes_to_var(b, false) 與 var_to_bytes(v, false) 在 4.7.1 皆為
#   「Parse Error: Too many arguments ... Expected at most 1 but received 2.」
# 因此本階段全部改用實際存在的 1 引數形式,並以 *_with_objects 變體製造
# 「本應解碼出 Object 的位元組」。這不是對 ADR 的美化,是 ADR 寫法根本不編譯。
#
# 紀律(沿用 prototypes/xcheck-round7-2026-08-20/scripts/runner_e.gd):
#   * 每個有編譯風險的構造各自一個檔案(f3a/f3b/f3c1/f3c2/f3c3 皆為此故拆開)
#   * 一律 ResourceLoader.load(..., CACHE_MODE_IGNORE) + reload() 的 Error 判編譯,
#     絕不用「load() != null」
#   * 所有可能中止的測試函式宣告 -> String;呼叫端收到 "" 即代表中止
#   * F5(可能吃光記憶體)一律排在最後,前面所有結果已因 flush_stdout_on_print 落地
# ============================================================================

const S := "res://scripts/"

func _load_checked(filename: String) -> Dictionary:
	var res = ResourceLoader.load(S + filename, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return {"ok": false, "status": "FAILED (load->null)", "script": null}
	if not (res is GDScript):
		return {"ok": false, "status": "FAILED (not GDScript)", "script": null}
	var err: int = res.reload()
	if err != OK:
		return {"ok": false, "status": "FAILED (reload=%s)" % error_string(err), "script": null}
	return {"ok": true, "status": "COMPILED OK", "script": res}

func _run(label: String, c: Callable) -> void:
	print("    >> %s : calling..." % label)
	var r: String = c.call()
	if r == "":
		print("    << %s : returned EMPTY STRING -- ABORTED (zero value for -> String)" % label)
	else:
		print("    << %s : returned [%s]" % [label, r])

func _ready() -> void:
	print("=== ADR-0003 Probe F / STAGE 2 / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- F-0: compile-check EVERY file BEFORE calling into any of them ---")
	var f2 := _load_checked("f2_object_decode.gd")
	print("  [%s]  f2_object_decode.gd           F2-a/b/c/f/g" % f2["status"])
	var f2e := _load_checked("f2e_bad_bytes.gd")
	print("  [%s]  f2e_bad_bytes.gd              F2-e 非 Object 的壞位元組" % f2e["status"])
	var f4 := _load_checked("f4_manifest_layering.gd")
	print("  [%s]  f4_manifest_layering.gd       F4-a / F4-b" % f4["status"])
	var f4c := _load_checked("f4c_float_fidelity.gd")
	print("  [%s]  f4c_float_fidelity.gd         F4-c 浮點位元保真" % f4c["status"])
	var f4c2 := _load_checked("f4c2_float_from_bits.gd")
	print("  [%s]  f4c2_float_from_bits.gd       F4-c 補測:由位元樣式構造 double,繞開常數池" % f4c2["status"])
	var f4c3 := _load_checked("f4c3_zero_order.gd")
	print("  [%s]  f4c3_zero_order.gd            F4-c 補測之二:零值 float 常數的順序相依性" % f4c3["status"])
	var f3a := _load_checked("f3a_hash_ctx_returns.gd")
	print("  [%s]  f3a_hash_ctx_returns.gd       F3 回傳型別(指派回傳值;void 會整檔 parse error)" % f3a["status"])
	var f3b := _load_checked("f3b_hash_qualified_enum.gd")
	print("  [%s]  f3b_hash_qualified_enum.gd    F3 HashingContext.HashType.HASH_SHA256 完整路徑形式" % f3b["status"])
	var f3c1 := _load_checked("f3c1_pba_sha256_buffer.gd")
	print("  [%s]  f3c1_pba_sha256_buffer.gd     F3a PackedByteArray.sha256_buffer()" % f3c1["status"])
	var f3c2 := _load_checked("f3c2_string_sha256_buffer.gd")
	print("  [%s]  f3c2_string_sha256_buffer.gd  F3a String.sha256_buffer()" % f3c2["status"])
	var f3c3 := _load_checked("f3c3_string_sha256_text.gd")
	print("  [%s]  f3c3_string_sha256_text.gd    F3a String.sha256_text()" % f3c3["status"])
	var f3d := _load_checked("f3d_hash_segmented.gd")
	print("  [%s]  f3d_hash_segmented.gd         F3 ClassDB 內省 / 已知答案 / 分段一致性" % f3d["status"])
	var f5 := _load_checked("f5_large_buffer.gd")
	print("  [%s]  f5_large_buffer.gd            F5 大緩衝區" % f5["status"])

	# ======================= F2 =======================
	print("")
	print("============ F2 -- bytes_to_var() 對本應解碼出 Object 的輸入(ADR VR#2,最高優先)============")
	if f2["ok"]:
		var s = f2["script"]
		print("")
		print("  -- 對照組:完全乾淨的 payload --")
		_run("f2.t_control_clean()", s.t_control_clean)
		print("")
		print("  -- F2-a:頂層就是 Object。三個 sentinel 判『回傳 null』vs『中止』 --")
		_run("f2.t_a_toplevel_object()", s.t_a_toplevel_object)
		print("")
		print("  -- F2-b:原子性 -- 3 個合法鍵 + 1 個 Object 值 --")
		_run("f2.t_b_atomicity()", s.t_b_atomicity)
		print("")
		print("  -- F2-c:深層巢狀 Dict -> Array -> Object(第三層) --")
		_run("f2.t_c_deep_nested()", s.t_c_deep_nested)
		print("")
		print("  -- F2-f:寫入側 -- var_to_bytes()(不帶 _with_objects)碰到 Object --")
		_run("f2.t_f_write_side_plain()", s.t_f_write_side_plain)
		print("")
		print("  -- F2-f2:同上,但頂層直接就是 Object --")
		_run("f2.t_f2_write_side_toplevel()", s.t_f2_write_side_toplevel)
		print("")
		print("  -- F2-g:三種 Object 種類是否一致 --")
		_run("f2.t_g_builtin_refcounted()", s.t_g_builtin_refcounted)
		_run("f2.t_g_custom_refcounted()", s.t_g_custom_refcounted)
		_run("f2.t_g_custom_resource()", s.t_g_custom_resource)
	else:
		print("  SKIPPED -- f2_object_decode.gd 編譯失敗,見 F-0")

	print("")
	print("  -- F2-e:非 Object 的壞位元組 --")
	if f2e["ok"]:
		var s2 = f2e["script"]
		_run("f2e.t_empty()", s2.t_empty)
		_run("f2e.t_truncated_half()", s2.t_truncated_half)
		_run("f2e.t_truncated_header_only()", s2.t_truncated_header_only)
		_run("f2e.t_garbage_fixed_pattern()", s2.t_garbage_fixed_pattern)
		_run("f2e.t_valid_header_bogus_length()", s2.t_valid_header_bogus_length)
		_run("f2e.t_all_zero()", s2.t_all_zero)
	else:
		print("  SKIPPED -- f2e_bad_bytes.gd 編譯失敗,見 F-0")

	# ======================= F4' =======================
	print("")
	print("============ F4 -- manifest 分層(ADR 機制二,整條 manifest-only 路徑的前提)============")
	if f4["ok"]:
		var s3 = f4["script"]
		print("")
		print("  -- F4-a:外層解碼是否『不遞迴』進區塊,且區塊逐位元組相同 --")
		_run("f4.t_a_no_recursion()", s3.t_a_no_recursion)
		print("")
		print("  -- F4-b(殺手鐧):含 Object 的區塊塞進外層,外層還解得開嗎 --")
		_run("f4.t_b_poison_block()", s3.t_b_poison_block)
		print("")
		print("  -- F4-b2:對照組 -- Alternative 3 的扁平巢狀寫法 --")
		_run("f4.t_b2_flat_contrast()", s3.t_b2_flat_contrast)
	else:
		print("  SKIPPED -- f4_manifest_layering.gd 編譯失敗,見 F-0")

	print("")
	print("  -- F4-c:浮點位元保真(拒絕 JSON 的理由之一 / GDD AC-24 依賴此) --")
	if f4c["ok"]:
		var s4 = f4c["script"]
		_run("f4c.t_roundtrip()", s4.t_roundtrip)
		_run("f4c.t_int_float_distinction()", s4.t_int_float_distinction)
	else:
		print("  SKIPPED -- f4c_float_fidelity.gd 編譯失敗,見 F-0")

	print("")
	print("  -- F4-c 補測:字面量常數池異常,以及由位元樣式構造的向量 --")
	print("     背景:上一項 f4c.t_roundtrip() 的 `+0.0` 與 `5e-324` 兩列,bits_in 與 `-0.0`")
	print("     那一列完全相同 -> 那兩個測試向量在進入序列化之前就已經不是預期的值。")
	print("     以下用 PackedByteArray.decode_double() 從明確位元組樣式構造,不經任何浮點字面量。")
	if f4c2["ok"]:
		var s4b = f4c2["script"]
		_run("f4c2.t_literal_constant_pool_anomaly()", s4b.t_literal_constant_pool_anomaly)
		_run("f4c2.t_from_bits_roundtrip()", s4b.t_from_bits_roundtrip)
	else:
		print("  SKIPPED -- f4c2_float_from_bits.gd 編譯失敗,見 F-0")

	print("")
	print("  -- F4-c 補測之二:判別「同檔內先出現的零值 float 常數勝」假說 --")
	if f4c3["ok"]:
		var s4c = f4c3["script"]
		_run("f4c3.probe()", s4c.probe)
		_run("f4c3.probe_signbit_visible()", s4c.probe_signbit_visible)
	else:
		print("  SKIPPED -- f4c3_zero_order.gd 編譯失敗,見 F-0")

	# ======================= F3 =======================
	print("")
	print("============ F3 -- HashingContext(ADR VR#3 / #3a)============")
	print("")
	print("  -- F3-0:哪些形式編譯得過(編譯結果本身就是答案) --")
	print("     HashingContext.HASH_SHA256 短形式 (f3a)         : [%s]" % f3a["status"])
	print("     HashingContext.HashType.HASH_SHA256 完整 (f3b)  : [%s]" % f3b["status"])
	print("     PackedByteArray.sha256_buffer()      (f3c1)     : [%s]" % f3c1["status"])
	print("     String.sha256_buffer()               (f3c2)     : [%s]" % f3c2["status"])
	print("     String.sha256_text()                 (f3c3)     : [%s]" % f3c3["status"])
	print("     註:f3a 之所以能編譯,即代表 start()/update()/finish() 三者皆非 void")
	print("        (回傳 void 的函式其回傳值不可指派,GDScript 會在 parse 階段擋下)。")

	if f3d["ok"]:
		var s5 = f3d["script"]
		print("")
		print("  -- F3:ClassDB 對 HashingContext 的真實簽章內省 --")
		_run("f3d.probe_classdb()", s5.probe_classdb)
	else:
		print("  SKIPPED -- f3d_hash_segmented.gd 編譯失敗,見 F-0")

	print("")
	print("  -- F3:回傳型別實測 --")
	if f3a["ok"]:
		_run("f3a.probe()", f3a["script"].probe)
		print("")
		print("  -- F3:未 start 就 update/finish 的失敗模式 --")
		_run("f3a.probe_error_paths()", f3a["script"].probe_error_paths)
	else:
		print("  SKIPPED -- f3a 編譯失敗(若失敗原因是 void 回傳,那本身即是答案)")

	print("")
	print("  -- F3:完整路徑 enum 形式 --")
	if f3b["ok"]:
		_run("f3b.probe()", f3b["script"].probe)
	else:
		print("  SKIPPED -- f3b 編譯失敗 -> 完整路徑形式不可用")

	print("")
	print("  -- F3a:一次性便利方法 --")
	if f3c1["ok"]:
		_run("f3c1.probe()", f3c1["script"].probe)
	else:
		print("    f3c1 SKIPPED -> PackedByteArray.sha256_buffer() 不存在")
	if f3c2["ok"]:
		_run("f3c2.probe()", f3c2["script"].probe)
	else:
		print("    f3c2 SKIPPED -> String.sha256_buffer() 不存在")
	if f3c3["ok"]:
		_run("f3c3.probe()", f3c3["script"].probe)
	else:
		print("    f3c3 SKIPPED -> String.sha256_text() 不存在")

	if f3d["ok"]:
		var s5b = f3d["script"]
		print("")
		print("  -- F3:對照已知 SHA-256 標準答案(獨立確認演算法身分) --")
		_run("f3d.probe_known_answer()", s5b.probe_known_answer)
		_run("f3d.probe_empty_input()", s5b.probe_empty_input)
		print("")
		print("  -- F3b:分段一致性(ADR 機制四用逐段 update()) --")
		_run("f3d.probe_segmented()", s5b.probe_segmented)
		print("")
		print("  -- F3a:三段式基準值,供與便利方法輸出比對 --")
		_run("f3d.probe_convenience_equivalence()", s5b.probe_convenience_equivalence.bind(f3c1["ok"], f3c2["ok"]))

	# ======================= F5(最後,可能吃記憶體)=======================
	print("")
	print("============ F5 -- 大緩衝區(排最後:前面結果已因 flush_stdout_on_print 落地)============")
	if f5["ok"]:
		var s6 = f5["script"]
		_run("f5.t_realistic_slot()", s6.t_realistic_slot)
		_run("f5.t_raw_buffer(32MB)", s6.t_raw_buffer.bind(32))
		_run("f5.t_raw_buffer(64MB)", s6.t_raw_buffer.bind(64))
		_run("f5.t_many_records(100k)", s6.t_many_records.bind(100000))
		_run("f5.t_many_records(500k)", s6.t_many_records.bind(500000))
	else:
		print("  SKIPPED -- f5_large_buffer.gd 編譯失敗,見 F-0")

	print("")
	print("=== STAGE 2 COMPLETE ===")
	get_tree().quit()
