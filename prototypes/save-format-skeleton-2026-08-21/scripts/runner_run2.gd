extends Node
# ============================================================================
# 存檔格式設計骨架 —— 階段 2(行程 2,獨立行程)
# ============================================================================
# 唯一的重點是驗證 F 的第二半:行程 1 寫進 user:// 的那些夾帶記憶體號碼的型別,
# 在一個「全新的行程」裡變成什麼。行程 1 的物件早已不存在。
# 追加:I(閘門成本歸因 + 熱檔案 I/O),因為 Run 1 的 G 量到閘門是最大單項成本。
#
# F 排在最前面(它是本階段存在的理由,且不可被後面的測項污染);
# F 內部再依風險遞增排序,最後才 connect/emit。
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

func _run(obj: Object, fn: String) -> void:
	print("    >> %s() : calling..." % fn)
	var r: String = obj.call(fn)
	if r == "":
		print("    << %s() : returned EMPTY STRING -- ABORTED" % fn)
	else:
		print("    << %s() : returned [%s]" % [fn, r])

func _stage(title: String, filename: String, fns: Array) -> void:
	print("")
	print("================================================================")
	print("=== %s   (%s)" % [title, filename])
	print("================================================================")
	var h := _load_checked(filename)
	if not h["ok"]:
		print("  [%s] --- 編譯失敗本身即為該項的答案。SKIPPED。" % h["status"])
		return
	var inst = h["script"].new()
	for fn in fns:
		_run(inst, fn)

func _ready() -> void:
	print("=== SAVE FORMAT SKELETON / RUN 2 (獨立行程) / Godot %s ==="
		% str(Engine.get_version_info().get("string")))
	print("=== user data dir = %s ===" % OS.get_user_data_dir())
	print("=== 本行程新建物件的 instance_id 起點 = %d ==="
		% SkelPoisonTarget.new().get_instance_id())
	for p in ["user://f_ids.txt", "user://f_plain.bin", "user://f_with_objects.bin",
			"user://f_rid.bin", "user://f_rid.txt"]:
		print("    %s exists=%s" % [p, str(FileAccess.file_exists(p))])

	_stage("驗證 F(第二半):跨行程的記憶體號碼", "t_f_read.gd",
		["t_f1_ids_and_pre_churn_lookup", "t_f2_post_churn_lookup",
		 "t_f3_plain_file", "t_f4_with_objects_file",
		 "t_f5_signal_inspect", "t_f6_signal_connect_emit"])
	_stage("驗證 F 的 RID 分支(第二半)", "t_f_read_rid.gd", ["t_f_read_rid"])
	_stage("追加 I:閘門成本歸因 + 熱檔案 I/O", "t_i_gate_cost.gd",
		["t_i_gate_attribution", "t_i_warm_file_io"])

	print("")
	print("=== RUN 2 COMPLETE ===")
	get_tree().quit()
