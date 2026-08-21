extends Node
# ============================================================================
# Step 5.5 覆核用探針 H (2026-08-21) —— godot-specialist
# 覆核對象:ADR-0003 修訂草案(尚未寫入)
# 紀律沿用 prototypes/xcheck-adr0003-2026-08-21/scripts/runner_f1.gd:
#   * 每個存在性/arity 未查證的呼叫各自一檔
#   * 一律用 ResourceLoader.load(CACHE_MODE_IGNORE) + reload() 的 Error 判編譯
#   * 測試函式宣告 -> String,回傳 "" 即代表中止
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

func _run(label: String, s) -> void:
	print("    >> %s : calling..." % label)
	var inst = s.new()
	var r: String = inst.probe()
	if r == "":
		print("    << %s : EMPTY STRING -- ABORTED" % label)
	else:
		print("    << %s : [%s]" % [label, r])

func _ready() -> void:
	print("=== Step 5.5 Probe H / Godot %s ===" % str(Engine.get_version_info().get("string")))
	var files := {
		"h1_fileaccess_introspect.gd": "H1 FileAccess.get_var/store_var 真實簽章",
		"h2_type_enum.gd": "H2 完整 Variant 型別列舉 (type_string)",
		"h3_type_max.gd": "H3 TYPE_MAX 哨兵值",
		"h4_object_as_dict_key.gd": "H4 Object 當 Dictionary 鍵 / Array 元素 / 型別化 Array",
		"h6_gate_cost.gd": "H6 遞迴型別閘門的 GDScript 成本 + 毒藥/邊界型別",
		"h8_empty_and_depth.gd": "H8 空容器編碼長度 + 引擎遞迴深度門檻",
		"h7_naked_recursive_gate.gd": "H7 草案逐字寫法(無深度上限/無已訪集合)對循環 payload",
	}
	print("")
	print("--- H-0: 先編譯全部,再呼叫任何一個 ---")
	var loaded := {}
	for f in files:
		var r := _load_checked(f)
		loaded[f] = r
		print("  [%s]  %s   %s" % [r["status"], f, files[f]])
	print("")
	print("--- H-1..H-4 執行 ---")
	for f in files:
		if loaded[f]["ok"]:
			print("  ## %s" % files[f])
			_run(f, loaded[f]["script"])
		else:
			print("  -- %s SKIPPED(編譯失敗 —— 這本身就是該項的答案)" % f)
	print("")
	print("=== PROBE H COMPLETE ===")
	get_tree().quit()
