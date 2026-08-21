extends Node
# ROUND7 Probe E — 量測 ADR-0004 機制一目前屬「外推」的語法事實。2026-08-20
# spike 已測的 @abstract 裸簽章五種回傳型別(Array[T]/bool/float/void/Vector2,
# 見 prototypes/engine-verification-spike-2026-08-20/scripts/c1_bare_*.gd)不含
# `-> Variant`,而 ADR-0004 機制一第 91 行的 read_file() 恰好用了它。本探針補測:
#   E1(核心)     @abstract func f(...) -> Variant 裸簽章是否編譯
#   E2            順帶測掉 -> String 與 -> PackedByteArray(成本為零)
#   E3(最高價值)  完整 SaveIOBackend 逐字組合(bool x4 + Variant x1,同檔含
#                 @abstract + class_name/extends)是否編譯
#   E4            具體子類別完整實作五方法,read_file() -> Variant 的多型實作
#                 在執行期是否真的可用(不只是編譯得過)
# 加碼(額外發現,非硬性要求):@abstract 類別本身被 .new() 時的確切行為。
#
# 沿用 runner_a.gd/runner_d.gd 的紀律:每個有編譯風險的測項各自一個檔案,一律用
# ResourceLoader.load(..., CACHE_MODE_IGNORE) + `.reload()` 的 Error 回傳值做編譯
# 檢查(絕不用裸 load()),所有可能中止的測試函式一律宣告 `-> String` 並在函式
# 最後一行印出「about to return」之後才 return "REACHED END ..." —— 中止時呼叫端
# 收到的是 String 的零值 `""`,這是唯一可靠的「有沒有中止」判讀依據,不是任何
# 印出來的標籤。

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
	print("=== ROUND7 Probe E / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- E0: compile-check EVERY file BEFORE calling anything into any of them ---")
	var e1_check: Dictionary = _load_checked("e1_abstract_variant_return.gd")
	print("  [%s]  e1_abstract_variant_return.gd  (@abstract func f() -> Variant, 裸簽章, 單獨一項)" % e1_check["status"])
	var e2a_check: Dictionary = _load_checked("e2a_abstract_string_return.gd")
	print("  [%s]  e2a_abstract_string_return.gd  (-> String)" % e2a_check["status"])
	var e2b_check: Dictionary = _load_checked("e2b_abstract_packedbytearray_return.gd")
	print("  [%s]  e2b_abstract_packedbytearray_return.gd  (-> PackedByteArray)" % e2b_check["status"])
	var e3_check: Dictionary = _load_checked("e3_save_io_backend.gd")
	print("  [%s]  e3_save_io_backend.gd  (ADR-0004 機制一逐字組合: bool x4 + Variant x1, class_name SaveIOBackend)" % e3_check["status"])
	var e4_check: Dictionary = _load_checked("e4_sync_blocking_save_io_backend.gd")
	print("  [%s]  e4_sync_blocking_save_io_backend.gd  (SyncBlockingSaveIOBackend extends SaveIOBackend, 完整實作五方法)" % e4_check["status"])
	var bonus_check: Dictionary = _load_checked("e_bonus_abstract_instantiation.gd")
	print("  [%s]  e_bonus_abstract_instantiation.gd  (加碼: .new() 對 @abstract 類別本身)" % bonus_check["status"])

	print("")
	print("--- E1(核心)判讀:@abstract func f(...) -> Variant 裸簽章是否編譯 ---")
	print("  直接讀上一節 e1_abstract_variant_return.gd 那一行的 [%s]。" % e1_check["status"])
	print("  本項無需呼叫任何東西 -- 編譯結果本身就是答案,這是已測五種型別之外的第六種。")

	print("")
	print("--- E2 判讀:-> String / -> PackedByteArray 是否編譯 ---")
	print("  -> String            : [%s]" % e2a_check["status"])
	print("  -> PackedByteArray   : [%s]" % e2b_check["status"])

	print("")
	print("--- E3(最高價值)判讀:ADR-0004 機制一 SaveIOBackend 逐字組合是否編譯 ---")
	print("  直接讀上面 e3_save_io_backend.gd 那一行的 [%s]。" % e3_check["status"])
	print("  這是 bool x4 + Variant x1 混合、且 @abstract 標記與 class_name/extends 同檔的")
	print("  完整組合 -- 單獨測各型別(E1/E2)不等於測這個組合。")

	print("")
	print("--- E4 判讀:具體子類別對 -> Variant 的多型實作,執行期是否真的可用 ---")
	if e4_check["ok"]:
		var e4 = e4_check["script"]
		print("")
		print("  -- E4a: .new() 是否可實例化 --")
		_run_str("SyncBlockingSaveIOBackend.new() 後立即回報", e4.test_instantiate_only)
		print("")
		print("  -- E4b: read_file() 回傳 PackedByteArray 的分支 --")
		_run_str("inst.read_file(...) with _should_return_null=false", e4.test_instantiate_and_read_bytes)
		print("")
		print("  -- E4c: read_file() 回傳 null 的分支 --")
		_run_str("inst.read_file(...) with _should_return_null=true", e4.test_instantiate_and_read_null)
		print("")
		print("  -- E4d: 透過靜態型別為 SaveIOBackend(抽象基底)的參數呼叫 read_file(), PackedByteArray 分支 --")
		_run_str("read_via_base_type(inst, ...) -> PackedByteArray branch", e4.test_read_via_base_typed_param_bytes)
		print("")
		print("  -- E4e: 同上, null 分支 --")
		_run_str("read_via_base_type(inst, ...) -> null branch", e4.test_read_via_base_typed_param_null)
	else:
		print("  SKIPPED -- e4_sync_blocking_save_io_backend.gd 編譯失敗(或其依賴的 e3 編譯失敗),見 E0 狀態")

	print("")
	print("--- 加碼(額外發現):@abstract 類別本身被 .new() 時的確切行為 ---")
	if bonus_check["ok"]:
		var b = bonus_check["script"]
		print("")
		print("  -- bonus-a: SpikeBareVariant.new()(單一 @abstract func -> Variant 的最小類別) --")
		_run_str("SpikeBareVariant.new()", b.test_new_on_bare_variant_abstract)
		print("")
		print("  -- bonus-b: SaveIOBackend.new()(完整 ADR 形狀的抽象基底) --")
		_run_str("SaveIOBackend.new()", b.test_new_on_save_io_backend_abstract)
	else:
		print("  SKIPPED -- e_bonus_abstract_instantiation.gd 編譯失敗(依賴 e1 與/或 e3),見 E0 狀態")

	print("")
	print("=== ROUND7 Probe E COMPLETE ===")
	get_tree().quit()
