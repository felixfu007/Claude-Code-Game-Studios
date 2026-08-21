extends Node
# ============================================================================
# 探針 G —— 關閉兩項至今仍押在訓練資料上的宣稱
# ============================================================================
# G-1:E1 的斷言(architecture-review-2026-08-18-round2.md:188)——
#      Callable/Signal/RID 不受 allow_objects 管控,bytes_to_var 仍會把它還原。
#      懸置三輪、從未實機驗證,來源與探針 F 剛推翻的 N-1 假設相同。
# G-2:registry architecture.yaml:1558-1559 —— 把 raw Resource 交給存檔寫入路徑
#      「would fail to serialize at all」。探針 F 的 F2-f 測的是 RefCounted,
#      不是 Resource,故此句仍未驗證。
#
# 紀律(沿用 runner_f.gd):
#   * 一律 ResourceLoader.load(..., CACHE_MODE_IGNORE) + reload() 的 Error 判編譯,
#     絕不用「load() != null」
#   * 所有測試函式宣告 -> String;呼叫端收到 "" 即代表中止
#   * 全部測項一律用 1 引數的 bytes_to_var(b) / var_to_bytes(v)
#     —— 兩引數形狀已由探針 F 階段 1 實測為 Parse Error
#   * 執行順序 = 風險遞增。所有純量測先跑完(flush_stdout_on_print 讓它們落地),
#     再跑「呼叫還原物」的風險段,instance_from_id 排在整支探針最後。
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
	print("=== ADR-0003 Probe G / Godot %s ===" % str(Engine.get_version_info().get("string")))
	print("=== G-1: Callable/Signal/RID 型別閘門(E1) / G-2: plain var_to_bytes 對 Resource(registry:1558) ===")

	print("")
	print("--- G-0: compile-check EVERY file BEFORE calling into any of them ---")
	var g1 := _load_checked("g1_callable_signal_rid.gd")
	print("  [%s]  g1_callable_signal_rid.gd   G-1a..G-1f" % g1["status"])
	var g2 := _load_checked("g2_resource_payload.gd")
	print("  [%s]  g2_resource_payload.gd      G-2a..G-2d" % g2["status"])
	var gt := _load_checked("g_probe_target.gd")
	print("  [%s]  g_probe_target.gd           class_name GProbeTarget(G-1 的可觀測受害者)" % gt["status"])
	var gr := _load_checked("g_custom_res.gd")
	print("  [%s]  g_custom_res.gd             class_name GCustomRes(G-2 的帶值 Resource)" % gr["status"])

	if not g1["ok"]:
		print("")
		print("!!! g1 編譯失敗 —— G-1 全數 SKIPPED。編譯失敗本身即為一項結果,見上方 status。")
	else:
		var s1 = g1["script"]

		print("")
		print("============ G-1f 對照組 —— NodePath / StringName(先證明測試方法本身有效)============")
		_run("g1.t_1f_control_nodepath_stringname()", s1.t_1f_control_nodepath_stringname)

		print("")
		print("============ G-1a —— Callable 能否被編碼 ============")
		print("  -- (i) 綁定到活體物件的方法參照 --")
		_run("g1.t_1a_encode_bound_method()", s1.t_1a_encode_bound_method)
		print("")
		print("  -- (ii) lambda --")
		_run("g1.t_1a2_encode_lambda()", s1.t_1a2_encode_lambda)
		print("")
		print("  -- (iii) 空 Callable(基準線)--")
		_run("g1.t_1a3_encode_empty_callable()", s1.t_1a3_encode_empty_callable)

		print("")
		print("============ G-1b —— 解碼:回傳什麼 / 是否 ERR_UNAUTHORIZED / 是否中止 ============")
		_run("g1.t_1b_decode_bound_method()", s1.t_1b_decode_bound_method)
		print("")
		_run("g1.t_1b2_decode_lambda()", s1.t_1b2_decode_lambda)

		print("")
		print("============ G-1d —— Signal(編碼 / 解碼 / 內省)============")
		_run("g1.t_1d_signal_encode_decode()", s1.t_1d_signal_encode_decode)

		print("")
		print("============ G-1e —— RID(編碼 / 解碼 / is_valid / get_id)============")
		_run("g1.t_1e_rid_encode_decode()", s1.t_1e_rid_encode_decode)

	if not g2["ok"]:
		print("")
		print("!!! g2 編譯失敗 —— G-2 全數 SKIPPED。")
	else:
		var s2 = g2["script"]
		print("")
		print("============ G-2a / G-2b —— 自訂 class_name Resource,plain var_to_bytes ============")
		print("  (registry:1558 宣稱這裡會 fail to serialize at all)")
		_run("g2.t_2ab_custom_resource_plain()", s2.t_2ab_custom_resource_plain)
		print("")
		print("  -- 頂層直接是 Resource --")
		_run("g2.t_2a2_bare_toplevel_resource_plain()", s2.t_2a2_bare_toplevel_resource_plain)
		print("")
		print("============ G-2c —— 內建 Resource.new() 與自訂子類別是否一致 ============")
		_run("g2.t_2c_builtin_resource_plain()", s2.t_2c_builtin_resource_plain)
		print("")
		print("============ G-2c2 —— 上限對照組:with_objects 兩側(界定「資料真的帶過去」長什麼樣)============")
		_run("g2.t_2c2_with_objects_both_sides()", s2.t_2c2_with_objects_both_sides)

	print("")

	# ---- G-1x:隔離出來的內省測項(RUN-A 教訓:不確定的 API 各自一檔)----
	print("")
	print("============ G-1x —— 隔離檔的內省測項(各自一檔,編譯失敗只損失該檔)============")
	var x1 := _load_checked("g1x1_callable_arity.gd")
	print("  [%s]  g1x1_callable_arity.gd        Callable.get_argument_count/get_bound_arguments_count" % x1["status"])
	if x1["ok"]:
		_run("g1x1.probe()", x1["script"].probe)
	var x2 := _load_checked("g1x2_callable_kind.gd")
	print("  [%s]  g1x2_callable_kind.gd         Callable.is_standard/is_custom/get_object_id" % x2["status"])
	if x2["ok"]:
		_run("g1x2.probe()", x2["script"].probe)
	var x3 := _load_checked("g1x3_signal_and_rid_extra.gd")
	print("  [%s]  g1x3_signal_and_rid_extra.gd  Signal.get_object_id / Resource.get_rid(G-1e 備援 RID 來源)" % x3["status"])
	if x3["ok"]:
		_run("g1x3.probe_signal_objid()", x3["script"].probe_signal_objid)
		_run("g1x3.probe_resource_get_rid()", x3["script"].probe_resource_get_rid)
	print("############################################################")
	print("### 以下為風險段:實際呼叫 / emit / 復活還原物。")
	print("### 上方所有量測結果已因 flush_stdout_on_print=true 落地。")
	print("############################################################")

	if g1["ok"]:
		var s1b = g1["script"]
		print("")
		print("============ G-1c(安全關鍵)—— 還原出來的 Callable 還能被呼叫嗎 ============")
		print("  判準:GProbeTarget.call_count 是否真的遞增。")
		print("  『還原出一個失效空殼』與『還原出仍綁著物件、仍可呼叫的 Callable』")
		print("  對存檔系統的威脅模型是兩件完全不同的事。")
		_run("g1.t_1c_invoke_restored_bound()", s1b.t_1c_invoke_restored_bound)
		print("")
		_run("g1.t_1c2_invoke_restored_lambda()", s1b.t_1c2_invoke_restored_lambda)
		print("")
		print("============ G-1d2 —— 還原出來的 Signal 還能 connect / emit 嗎 ============")
		_run("g1.t_1d2_emit_restored_signal()", s1b.t_1d2_emit_restored_signal)

	if g2["ok"]:
		var s2b = g2["script"]
		print("")
		print("============ G-2d(整支探針最後)—— instance_from_id() 能否復活那個 ID ============")
		_run("g2.t_2d_instance_from_id()", s2b.t_2d_instance_from_id)
		print("")
		print("  -- 最後一項:不存在的 id(比上一項更可能崩,故排在其後)--")
		_run("g2.t_2d2_instance_from_bogus_id()", s2b.t_2d2_instance_from_bogus_id)

	print("")
	print("=== PROBE G COMPLETE ===")
	get_tree().quit()
