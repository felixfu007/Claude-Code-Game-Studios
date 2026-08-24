extends Node
# ============================================================================
# X-CYCLE —— 兩個 class_name 腳本互相引用(bidirectional class_name reference)
# ============================================================================
# 問題來源:ADR-0003 draft-v2.md M4(b)。骨架(save-format-skeleton-2026-08-21)
# 把型別閘門包在單一 SaveFormat 腳本內,只有單向引用,「從未編譯過」三腳本拆分
# 後互相呼叫的形狀。本次修訂把它拆成 SaveTypeGate / SaveEnvelope / SaveFormat
# 三個 class_name 腳本,若 SaveFormat.deserialize_manifest() 呼叫
# SaveEnvelope.check_shape(),而 SaveEnvelope.ShapeCheckResult 的欄位型別又
# 引用 SaveFormat.ReadRejection,兩個 class_name 腳本會互相引用對方。
#
# 探針 x4(prototypes/save-format-skeleton-2026-08-21/scripts/x4_cross_class_enum.gd)
# 已驗證「腳本 A 引用腳本 B 的 enum / 內部類別」單方向成立,但**只測過單向**。
# 本探針補測雙向:save_format.gd 與 save_envelope.gd 互相引用對方的 class_name、
# 內部類別、enum、常數。
#
# 紀律(沿用既有探針慣例):
#   * 一律先用 ResourceLoader.load(..., CACHE_MODE_IGNORE) + reload() 的 Error
#     判編譯是否成功,絕不用「load() != null」。
#   * 編譯成功後才實際呼叫,驗證不只是「parse 過關」,而是執行期也真的能解析
#     到對方腳本的靜態方法/常數/enum 值。
#   * 全程只用 1 引數 bytes_to_var()/var_to_bytes()(探針 F 已定案的呼叫形狀)。
# ============================================================================

func _load_checked(filename: String) -> Dictionary:
	var res = ResourceLoader.load("res://scripts/" + filename, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return {"ok": false, "status": "FAILED (load->null)"}
	if not (res is GDScript):
		return {"ok": false, "status": "FAILED (not GDScript)"}
	var err: int = res.reload()
	if err != OK:
		return {"ok": false, "status": "FAILED (reload=%s)" % error_string(err)}
	return {"ok": true, "status": "COMPILED OK"}

func _ready() -> void:
	print("=== X-CYCLE / Godot %s ===" % str(Engine.get_version_info().get("string")))
	print("")
	print("--- Step 1: compile-check both files independently ---")
	var a := _load_checked("save_format.gd")
	print("  [%s]  save_format.gd   (class_name SaveFormat, 引用 SaveEnvelope)" % a["status"])
	var b := _load_checked("save_envelope.gd")
	print("  [%s]  save_envelope.gd (class_name SaveEnvelope, 引用 SaveFormat)" % b["status"])

	if not a["ok"] or not b["ok"]:
		print("")
		print("!!! 編譯失敗 —— 後續步驟 SKIPPED。編譯失敗本身即為本探針的結果。")
		print("=== X-CYCLE DONE (compile failure) ===")
		return

	print("")
	print("--- Step 2: 透過全域 class_name 直接呼叫,驗證雙向引用在執行期也成立 ---")
	print("  嘗試呼叫 SaveFormat.deserialize_manifest() -- 其內部呼叫 SaveEnvelope.check_shape() --")

	# Case 1: 合法信封 -> 應該 ok() == true,且必須真的走到 SaveEnvelope.check_shape()
	# 內部才能確認雙向解析成立(不是只有其中一個方向被用到)。
	var good_envelope: Dictionary = {
		"ruleset_version": 3,
		"top_level_hash": _fake_hash(),
	}
	var good_buf: PackedByteArray = var_to_bytes(good_envelope)
	var r1: SaveFormat.DeserializeResult = SaveFormat.deserialize_manifest(good_buf)
	print("  [Case 1: 合法信封] ok=%s detail='%s' (預期 ok=true)" % [str(r1.ok()), r1.detail])

	# Case 2: 缺少 ruleset_version -> 由 SaveEnvelope.check_shape() 判定,
	# 錯誤訊息應來自 SaveEnvelope(證明 SaveFormat 真的呼叫過去了,不是本地判斷)。
	var missing_key_envelope: Dictionary = {"top_level_hash": _fake_hash()}
	var buf2: PackedByteArray = var_to_bytes(missing_key_envelope)
	var r2: SaveFormat.DeserializeResult = SaveFormat.deserialize_manifest(buf2)
	print("  [Case 2: 缺少 ruleset_version] ok=%s rejection=%d detail='%s' (預期 ok=false, detail 含 'ruleset_version')"
		% [str(r2.ok()), r2.rejection, r2.detail])

	# Case 3: top_level_hash 長度錯誤 -> 驗證 SaveEnvelope 內部真的讀到了
	# SaveFormat.HASH_LEN 這個常數(不是寫死的字面量,雖然探針裡為了單純用了字面量
	# 32 對照,但常數本身確實跨檔被引用並參與判斷邏輯)。
	var bad_hash_envelope: Dictionary = {
		"ruleset_version": 3,
		"top_level_hash": PackedByteArray([1, 2, 3]),  # 長度 3,不等於 SaveFormat.HASH_LEN(32)
	}
	var buf3: PackedByteArray = var_to_bytes(bad_hash_envelope)
	var r3: SaveFormat.DeserializeResult = SaveFormat.deserialize_manifest(buf3)
	print("  [Case 3: hash 長度錯誤] ok=%s rejection=%d detail='%s' (預期 ok=false, detail 含 'top_level_hash')"
		% [str(r3.ok()), r3.rejection, r3.detail])

	# Case 4: decoded 根本不是 Dictionary -> 這一步應該完全不觸碰 SaveEnvelope,
	# 純粹驗證 SaveFormat 自己的分支不會因為引用了 SaveEnvelope 而受影響。
	var buf4: PackedByteArray = PackedByteArray()
	var r4: SaveFormat.DeserializeResult = SaveFormat.deserialize_manifest(buf4)
	print("  [Case 4: 空 buffer] ok=%s rejection=%d detail='%s' (預期 ok=false, DATA_CORRUPTED)"
		% [str(r4.ok()), r4.rejection, r4.detail])

	# 直接引用對方的 enum 值與常數本身(不透過方法呼叫),再次確認符號解析成立。
	print("")
	print("--- Step 3: 直接存取跨檔符號(不經方法呼叫)---")
	print("  SaveFormat.HASH_LEN = %d (預期 32)" % SaveFormat.HASH_LEN)
	print("  SaveFormat.ReadRejection.DATA_CORRUPTED = %d" % SaveFormat.ReadRejection.DATA_CORRUPTED)
	var direct_result := SaveEnvelope.ShapeCheckResult.new()
	print("  SaveEnvelope.ShapeCheckResult.new().rejection (預設值) = %d (預期等於 SaveFormat.ReadRejection.NONE = 0)"
		% direct_result.rejection)

	print("")
	print("=== X-CYCLE DONE ===")

func _fake_hash() -> PackedByteArray:
	var h := PackedByteArray()
	h.resize(32)
	return h
