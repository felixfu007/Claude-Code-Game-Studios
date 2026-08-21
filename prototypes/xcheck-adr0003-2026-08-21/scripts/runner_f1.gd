extends Node
# ============================================================================
# 探針 F / 階段 1 —— ADR-0003 Verification Required 第 1 項(簽章)
# ============================================================================
# 目標檔:docs/architecture/adr-0003-save-system-serialization-format-and-type-safety.md
#
# ADR-0003 第 20 行 VR#1 逐字寫:
#     var_to_bytes(value: Variant) -> PackedByteArray
#     bytes_to_var(bytes: PackedByteArray, allow_objects: bool = false) -> Variant
# 且機制一/二/三、Key Interfaces、Architecture Diagram 全文一律寫成
# `bytes_to_var(buffer, false)` —— 兩個引數。
#
# 本階段先單獨量這件事,因為它是階段 2(F2/F4')所有測試碼「該怎麼寫」的前提:
# 若 4.7.1 的 bytes_to_var 只吃一個引數,階段 2 若照 ADR 寫法下筆會整檔 Parse Error
# 而一項都跑不出來 —— 那正是本專案探針 C 第一版踩過的坑。
#
# 紀律(沿用 prototypes/xcheck-round7-2026-08-20/scripts/runner_e.gd):
#   * 每個有編譯風險的呼叫形狀各自一個檔案,絕不同檔混裝
#   * 一律 ResourceLoader.load(..., CACHE_MODE_IGNORE) + reload() 的 Error 回傳值
#     判定編譯成功,絕不用「load() != null」(load() 對 parse error 不回 null)
#   * 所有可能中止的測試函式宣告 -> String,呼叫端收到 "" 即代表中止
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

func _run_str(label: String, c: Callable) -> void:
	print("    >> %s : calling..." % label)
	var r: String = c.call()
	if r == "":
		print("    << %s : returned EMPTY STRING -- ABORTED (zero value for -> String)" % label)
	else:
		print("    << %s : returned [%s]" % [label, r])

func _ready() -> void:
	print("=== ADR-0003 Probe F / STAGE 1 (F1 signatures) / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- F1-0: compile-check EVERY file BEFORE calling into any of them ---")
	var a := _load_checked("f1a_bytes_to_var_1arg.gd")
	print("  [%s]  f1a_bytes_to_var_1arg.gd    bytes_to_var(b)          <- 1 個引數" % a["status"])
	var b := _load_checked("f1b_bytes_to_var_2arg.gd")
	print("  [%s]  f1b_bytes_to_var_2arg.gd    bytes_to_var(b, false)   <- ADR-0003 全文採用的形狀" % b["status"])
	var c := _load_checked("f1c_var_to_bytes_1arg.gd")
	print("  [%s]  f1c_var_to_bytes_1arg.gd    var_to_bytes(v)          <- 1 個引數" % c["status"])
	var d := _load_checked("f1d_var_to_bytes_2arg.gd")
	print("  [%s]  f1d_var_to_bytes_2arg.gd    var_to_bytes(v, false)   <- 2 個引數" % d["status"])
	var e := _load_checked("f1e_with_objects.gd")
	print("  [%s]  f1e_with_objects.gd         *_with_objects 變體是否存在" % e["status"])
	var f := _load_checked("f1f_introspect.gd")
	print("  [%s]  f1f_introspect.gd           ClassDB 內省嘗試" % f["status"])

	print("")
	print("--- F1-1 判讀:哪一個 arity 編譯得過 ---")
	print("  bytes_to_var, 1 arg : [%s]" % a["status"])
	print("  bytes_to_var, 2 arg : [%s]   <<< ADR-0003 逐字寫法" % b["status"])
	print("  var_to_bytes, 1 arg : [%s]" % c["status"])
	print("  var_to_bytes, 2 arg : [%s]" % d["status"])

	print("")
	print("--- F1-2:實際呼叫(只呼叫編譯得過的) ---")
	if a["ok"]:
		_run_str("f1a.probe()", a["script"].probe)
	else:
		print("    -- f1a SKIPPED (編譯失敗)")
	if b["ok"]:
		_run_str("f1b.probe()", b["script"].probe)
	else:
		print("    -- f1b SKIPPED (編譯失敗) —— 若此行出現,ADR-0003 全文的呼叫形狀在 4.7.1 不成立")
	if c["ok"]:
		_run_str("f1c.probe()", c["script"].probe)
	else:
		print("    -- f1c SKIPPED (編譯失敗)")
	if d["ok"]:
		_run_str("f1d.probe()", d["script"].probe)
	else:
		print("    -- f1d SKIPPED (編譯失敗)")

	print("")
	print("--- F1-3:*_with_objects 變體 ---")
	if e["ok"]:
		_run_str("f1e.probe_encode()", e["script"].probe_encode)
		_run_str("f1e.probe_decode()", e["script"].probe_decode)
	else:
		print("    -- f1e SKIPPED (編譯失敗) —— 表示 _with_objects 變體不存在,")
		print("       則階段 2 需要另尋「製造本應解碼出 Object 的位元組」的手段")

	print("")
	print("--- F1-4:ClassDB 內省(測不到就明說未查證) ---")
	if f["ok"]:
		_run_str("f1f.probe()", f["script"].probe)
	else:
		print("    -- f1f SKIPPED (編譯失敗)")

	print("")
	print("=== STAGE 1 COMPLETE ===")
	get_tree().quit()
