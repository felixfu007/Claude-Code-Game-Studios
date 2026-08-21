extends Node
# ============================================================================
# 存檔格式設計骨架 —— 階段 0:先量規格逐字要求的 GDScript 形狀,再下筆寫骨架
# ============================================================================
# 為何先跑這一階段(沿用探針 F/G 的教訓,見
# prototypes/xcheck-adr0003-2026-08-21/README.md 判讀陷阱第 8 項):
# GDScript 的未知識別字是「整檔 Parse Error」。骨架的 save_format.gd 會同時用到
#   (1) 39 個 TYPE_* 識別字、(2) static var、(3) const Dictionary 以 enum 常數當鍵、
#   (4) 內部類別的型別化欄位參照外層 enum
# 這四項若有任何一項不成立,整個 SaveFormat 會一個測項都跑不出來,
# 而失敗形狀是「整段沒有輸出」,不是「那一項失敗」。
#
# 紀律:一律 ResourceLoader.load(CACHE_MODE_IGNORE) + reload() 的 Error 判編譯;
#       絕不用 load() != null;每個測函式宣告 -> String,收到 "" 即為中止的證據。
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

func _stage(filename: String, note: String, fns: Array) -> void:
	var h := _load_checked(filename)
	print("")
	print("--- [%s]  %s  --- %s" % [h["status"], filename, note])
	if not h["ok"]:
		print("    !!! 編譯失敗本身即為該項的答案。SKIPPED。")
		return
	var inst = h["script"].new()
	for fn in fns:
		_run(inst, fn)

func _ready() -> void:
	print("=== SAVE FORMAT SKELETON / STAGE 0 (shape pre-flight) / Godot %s ==="
		% str(Engine.get_version_info().get("string")))
	_stage("pre1_type_constants.gd", "39 個 TYPE_* 識別字 + TYPE_MAX", ["probe"])
	_stage("pre2_static_var.gd", "static var(D 的解碼計次器需要它)", ["probe"])
	_stage("pre3_file_close.gd", "FileAccess open/store_buffer/close/get_buffer(驗證 A 需要)", ["probe"])
	_stage("pre4_inner_class_enum.gd", "內部類別的型別化欄位參照外層 enum(規格逐字要求的形狀)", ["probe"])
	_stage("pre5_const_dict.gd", "const Dictionary 以 TYPE_* 當鍵 + has()/size() + 手工可變副本", ["probe"])
	_stage("pre6_dup_of_const.gd", "隔離:const Dictionary.duplicate() 是否可變", ["probe"])
	_stage("x1_typed_array.gd", "型別化陣列往返後是否仍型別化(可能中止,故三函式分開)",
		["probe_is_typed", "probe_assign_untyped_into_typed", "probe_assign_via_helper"])
	_stage("x2_stringname_key.gd", "StringName 鍵往返後能否以 String 查到", ["probe"])
	_stage("x3_dict_key_order.gd", "var_to_bytes 是否隨 Dictionary 鍵插入順序改變", ["probe"])
	print("")
	print("=== STAGE 0 COMPLETE ===")
	get_tree().quit()
