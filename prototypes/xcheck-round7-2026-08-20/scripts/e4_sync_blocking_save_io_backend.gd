class_name SyncBlockingSaveIOBackend extends SaveIOBackend
# ROUND7 Probe E — E4。具體子類別完整實作 SaveIOBackend 全部五個抽象方法(其中
# read_file() 覆寫 -> Variant,依旗標回傳 PackedByteArray 或 null),用來確認:
#   (a) 編譯是否成功(尤其 read_file() 對 -> Variant 的多型覆寫)
#   (b) 可否 .new() 實例化
#   (c) read_file() 回傳 PackedByteArray 與回傳 null 兩種情形,在執行期是否都
#       正常運作(不只是編譯得過)
# 另外提供 read_via_base_type():把子類別實例經由靜態型別為 SaveIOBackend
# (抽象基底)的參數呼叫 read_file(),確認透過基底型別的多型呼叫路徑也正常。
#
# ⚠️ 這一行對 SaveIOBackend 的靜態型別引用刻意留在「本檔自己」裡,不放進
# runner_e.gd —— 本檔已經 `extends SaveIOBackend`,所以這個引用不會讓 runner
# 承擔額外的編譯期風險:SaveIOBackend(e3)若編譯失敗,本檔本身也一併編譯失敗,
# E0 的逐檔編譯檢查會照實反映該失敗,不會讓 runner_e.gd 自己的 parse 被拖垮。
#
# 沿用 runner_a.gd/runner_d.gd 的 REACHED END 慣例:每個測試函式宣告
# `-> String`,在函式最後一行印出「about to return」之後才 return,呼叫端若收到
# 空字串就代表函式中途中止 —— 這是唯一可靠的中止判讀依據。

var _should_return_null: bool = false

func write_temp(_path: String, _buffer: PackedByteArray) -> bool:
	return true

func rename_file(_from_path: String, _to_path: String) -> bool:
	return true

func delete_file(_path: String) -> bool:
	return true

func file_exists(_path: String) -> bool:
	return true

func read_file(_path: String) -> Variant:
	if _should_return_null:
		return null
	return PackedByteArray([1, 2, 3])

func set_should_return_null(value: bool) -> void:
	_should_return_null = value

static func read_via_base_type(backend: SaveIOBackend, path: String) -> Variant:
	return backend.read_file(path)

# ── 測試函式(static,-> String,REACHED END 慣例)────────────────────────

static func test_instantiate_only() -> String:
	print("      >> test_instantiate_only: entering")
	var inst := SyncBlockingSaveIOBackend.new()
	print("      >> test_instantiate_only: instance created, about to return")
	return "REACHED END inst=%s typeof=%d global_name=%s" % [str(inst), typeof(inst), str(inst.get_script().get_global_name())]

static func test_instantiate_and_read_bytes() -> String:
	print("      >> test_instantiate_and_read_bytes: entering")
	var inst := SyncBlockingSaveIOBackend.new()
	inst.set_should_return_null(false)
	var r = inst.read_file("res://fake/path.bin")
	print("      >> test_instantiate_and_read_bytes: call done, about to return")
	return "REACHED END r=%s typeof=%d is_PackedByteArray=%s" % [str(r), typeof(r), str(r is PackedByteArray)]

static func test_instantiate_and_read_null() -> String:
	print("      >> test_instantiate_and_read_null: entering")
	var inst := SyncBlockingSaveIOBackend.new()
	inst.set_should_return_null(true)
	var r = inst.read_file("res://fake/missing.bin")
	print("      >> test_instantiate_and_read_null: call done, about to return")
	return "REACHED END r=%s typeof=%d is_null=%s" % [str(r), typeof(r), str(r == null)]

static func test_read_via_base_typed_param_bytes() -> String:
	print("      >> test_read_via_base_typed_param_bytes: entering")
	var inst := SyncBlockingSaveIOBackend.new()
	inst.set_should_return_null(false)
	var r = read_via_base_type(inst, "res://fake/via_base_type.bin")
	print("      >> test_read_via_base_typed_param_bytes: call done, about to return")
	return "REACHED END r=%s typeof=%d is_PackedByteArray=%s" % [str(r), typeof(r), str(r is PackedByteArray)]

static func test_read_via_base_typed_param_null() -> String:
	print("      >> test_read_via_base_typed_param_null: entering")
	var inst := SyncBlockingSaveIOBackend.new()
	inst.set_should_return_null(true)
	var r = read_via_base_type(inst, "res://fake/via_base_type_missing.bin")
	print("      >> test_read_via_base_typed_param_null: call done, about to return")
	return "REACHED END r=%s typeof=%d is_null=%s" % [str(r), typeof(r), str(r == null)]
