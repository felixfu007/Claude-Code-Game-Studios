extends Node
# ============================================================================
# 存檔格式設計骨架 —— 階段 1(行程 1)
# ============================================================================
# 這不是探針。這是把「設計規格」整套寫成可執行的骨架,然後看它會不會裂。
# 交付重點在驗證 A~G,見 README。
#
# 執行順序 = 風險遞增,且 F 的寫檔一定要在會中止的測項之前跑完
# (F 的第二半在行程 2,靠 user:// 的檔案接力)。
# 紀律:
#   * 先把每一個檔案各自 compile-check 過(CACHE_MODE_IGNORE + reload 的 Error),
#     再呼叫其中任何一個。編譯失敗只損失該檔,而「編譯失敗」本身就是該項的答案。
#   * 每個測函式宣告 -> String;呼叫端收到 "" 即為「中止」的可靠證據。
# ============================================================================

const S := "res://scripts/"

var _files: Array = [
	"save_format.gd", "save_import_result.gd", "save_block_registry.gd",
	"fake_affinity_source.gd", "save_writer.gd", "save_reader.gd",
	"skel_fixture.gd", "skel_poison_target.gd",
	"x4_cross_class_enum.gd",
	"t_self_and_e.gd", "t_a_roundtrip.gd", "t_d_manifest_only.gd",
	"t_b_injection.gd", "t_c_poison.gd", "t_f_write.gd", "t_f_write_rid.gd",
	"t_g_cost.gd", "t_h_callable_lifetime.gd",
]

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
	print("=== SAVE FORMAT SKELETON / RUN 1 / Godot %s ==="
		% str(Engine.get_version_info().get("string")))
	print("=== user data dir = %s ===" % OS.get_user_data_dir())

	print("")
	print("--- 階段 1 之 0:先逐檔 compile-check(呼叫任何東西之前)---")
	var all_ok := true
	for f in _files:
		var h := _load_checked(f)
		print("  [%-28s]  %s" % [h["status"], f])
		if not h["ok"]:
			all_ok = false
	print("  全部編譯通過 = %s" % str(all_ok))

	_stage("X-4 未查證的型別標註形狀(骨架自己用到)", "x4_cross_class_enum.gd", ["probe"])
	_stage("驗證 E:白名單完整性斷言", "t_self_and_e.gd",
		["t_self_check", "t_e_remove_one_type", "t_e_sum_correct_but_hole",
		 "t_e_gate_is_not_injectable"])
	_stage("驗證 A:完整往返走真實檔案", "t_a_roundtrip.gd", ["t_roundtrip_through_real_file"])
	_stage("驗證 D:manifest-only 沒解碼區塊(計數器證明)", "t_d_manifest_only.gd",
		["t_d_counter_proof"])
	_stage("驗證 B:失敗注入", "t_b_injection.gd",
		["t_b1_block_content_flipped", "t_b2_manifest_metadata_changed",
		 "t_b3_manifest_entry_removed", "t_b3b_blocks_entry_removed",
		 "t_b4_version_too_new", "t_b5_validator_unregistered",
		 "t_b6_validator_range_violation", "t_b7_shape_attack_before_hash"])
	_stage("驗證 C:毒藥向量 x 兩側", "t_c_poison.gd",
		["t_c_write_side", "t_c_write_side_depth", "t_c_write_side_circular",
		 "t_c_read_side"])
	_stage("驗證 F(第一半):寫出跨行程毒檔", "t_f_write.gd", ["t_f_write"])
	_stage("驗證 F 的 RID 分支(第一半)", "t_f_write_rid.gd", ["t_f_write_rid"])
	_stage("驗證 G:量成本", "t_g_cost.gd", ["t_g_cost"])
	print("")
	print("############################################################")
	print("### 以下為風險段:可能中止呼叫函式(dangling Callable)")
	print("### 上方所有結果已因 flush_stdout_on_print=true 落地。")
	print("############################################################")
	_stage("額外:驗證器 Callable 的生命期", "t_h_callable_lifetime.gd",
		["t_h_validator_lifetime", "t_h_read_with_dangling_validator", "t_h_double_register"])

	print("")
	print("=== RUN 1 COMPLETE ===")
	get_tree().quit()
