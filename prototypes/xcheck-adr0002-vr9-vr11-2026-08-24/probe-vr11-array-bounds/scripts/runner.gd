extends Node
# Probe VR#11 (ADR-0002 VR table item 11, 2026-08-24): typed Array boundary-
# read behavior. AffinityRecordList.get_at(index) (ADR-0002 mechanism two)
# needs to know whether a typed Array subscript read at/beyond the bound
# (a) aborts the calling function, (b) prints an error but lets the function
# keep running, or (c) does neither and just misbehaves silently. The four
# existing ADR-0002 probes only ever tested typed Dictionary missing-key
# reads (aborts the calling function) -- typed Array has zero coverage.
#
# Discipline: every risky read lives in its own dedicated function, and that
# SAME function prints an AFTER_READ line immediately after the read. If
# AFTER_READ is missing from the log, the read aborted that function. The
# caller (_ready) always prints a RETURNED_TO_READY line right after calling
# each case function, to separately confirm whether an abort (if any) stays
# scoped to the one function or propagates further up -- this is exactly the
# distinction the task calls out as previously confused in this project.
#
# `.get()` existence on a typed Array is a compile-time question, so it is
# checked via ResourceLoader.load(..., CACHE_MODE_IGNORE) + reload()'s Error
# return (probe_get_method.gd), never via `load() != null`, consistent with
# this project's standing probe discipline.

func _case_one_past_end_int(arr: Array[int]) -> void:
	print("  BEFORE_READ [one_past_end_int] size=%d index=%d" % [arr.size(), arr.size()])
	var v = arr[arr.size()]
	print("  AFTER_READ [one_past_end_int] v=%s (function did NOT abort here)" % str(v))

func _case_far_out_of_bounds_int(arr: Array[int]) -> void:
	print("  BEFORE_READ [far_out_of_bounds_int] size=%d index=999" % arr.size())
	var v = arr[999]
	print("  AFTER_READ [far_out_of_bounds_int] v=%s (function did NOT abort here)" % str(v))

func _case_negative_one_nonempty_int(arr: Array[int]) -> void:
	print("  BEFORE_READ [negative_one_nonempty_int] size=%d index=-1" % arr.size())
	var v = arr[-1]
	print("  AFTER_READ [negative_one_nonempty_int] v=%s last_element_via_size_minus_1=%s (function did NOT abort here)" % [str(v), str(arr[arr.size() - 1])])

func _case_negative_one_empty_int(arr: Array[int]) -> void:
	print("  BEFORE_READ [negative_one_empty_int] size=%d index=-1" % arr.size())
	var v = arr[-1]
	print("  AFTER_READ [negative_one_empty_int] v=%s (function did NOT abort here)" % str(v))

func _case_deep_negative_nonempty_int(arr: Array[int]) -> void:
	print("  BEFORE_READ [deep_negative_nonempty_int] size=%d index=-999" % arr.size())
	var v = arr[-999]
	print("  AFTER_READ [deep_negative_nonempty_int] v=%s (function did NOT abort here)" % str(v))

func _case_empty_read_zero_int(arr: Array[int]) -> void:
	print("  BEFORE_READ [empty_read_zero_int] size=%d index=0" % arr.size())
	var v = arr[0]
	print("  AFTER_READ [empty_read_zero_int] v=%s (function did NOT abort here)" % str(v))

func _case_one_past_end_dict(arr: Array[Dictionary]) -> void:
	print("  BEFORE_READ [one_past_end_dict] size=%d index=%d" % [arr.size(), arr.size()])
	var v = arr[arr.size()]
	print("  AFTER_READ [one_past_end_dict] v=%s (function did NOT abort here)" % str(v))

func _case_negative_one_nonempty_dict(arr: Array[Dictionary]) -> void:
	print("  BEFORE_READ [negative_one_nonempty_dict] size=%d index=-1" % arr.size())
	var v = arr[-1]
	print("  AFTER_READ [negative_one_nonempty_dict] v=%s (function did NOT abort here)" % str(v))

func _case_get_method_one_past_end_int(arr: Array[int]) -> void:
	print("  BEFORE_READ [get_method_one_past_end_int] size=%d index=%d" % [arr.size(), arr.size()])
	var v = arr.get(arr.size())
	print("  AFTER_READ [get_method_one_past_end_int] v=%s (function did NOT abort here)" % str(v))

func _load_checked(res_path: String) -> Dictionary:
	var res = ResourceLoader.load(res_path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return {"ok": false, "status": "FAILED (load->null)"}
	if not (res is GDScript):
		return {"ok": false, "status": "FAILED (not GDScript)"}
	var err: int = res.reload()
	if err != OK:
		return {"ok": false, "status": "FAILED (reload=%s)" % error_string(err)}
	return {"ok": true, "status": "COMPILED OK"}

func _ready() -> void:
	print("=== VR11 probe: typed Array boundary reads / Godot %s ===" % str(Engine.get_version_info().get("string")))

	var int_arr: Array[int] = [10, 20, 30]
	var empty_int_arr: Array[int] = []
	var dict_arr: Array[Dictionary] = [{"a": 1}, {"b": 2}]

	print("")
	print("--- 1: Array[int], read at index == size() (one past end) ---")
	_case_one_past_end_int(int_arr)
	print("RETURNED_TO_READY after case 1")

	print("")
	print("--- 2: Array[int], read at index >> size() (999) ---")
	_case_far_out_of_bounds_int(int_arr)
	print("RETURNED_TO_READY after case 2")

	print("")
	print("--- 3: Array[int] (non-empty), read at index -1 ---")
	_case_negative_one_nonempty_int(int_arr)
	print("RETURNED_TO_READY after case 3")

	print("")
	print("--- 4: Array[int] (EMPTY), read at index -1 ---")
	_case_negative_one_empty_int(empty_int_arr)
	print("RETURNED_TO_READY after case 4")

	print("")
	print("--- 5: Array[int] (non-empty), read at index -999 (deep negative) ---")
	_case_deep_negative_nonempty_int(int_arr)
	print("RETURNED_TO_READY after case 5")

	print("")
	print("--- 6: Array[int] (EMPTY), read at index 0 ---")
	_case_empty_read_zero_int(empty_int_arr)
	print("RETURNED_TO_READY after case 6")

	print("")
	print("--- 7: Array[Dictionary], read at index == size() (one past end) ---")
	_case_one_past_end_dict(dict_arr)
	print("RETURNED_TO_READY after case 7")

	print("")
	print("--- 8: Array[Dictionary] (non-empty), read at index -1 ---")
	_case_negative_one_nonempty_dict(dict_arr)
	print("RETURNED_TO_READY after case 8")

	print("")
	print("--- 9: does a statically-typed Array[int] even have a `.get()` method? (compile-check via reload()) ---")
	var get_check := _load_checked("res://scripts/probe_get_method.gd")
	print("  [%s]" % get_check["status"])

	if get_check["ok"]:
		print("")
		print("--- 9b: `.get()` compiled -- testing its one-past-end runtime behavior for comparison with [] ---")
		_case_get_method_one_past_end_int(int_arr)
		print("RETURNED_TO_READY after case 9b")
	else:
		print("  -> .get() does not compile on a typed Array in this engine version; 9b runtime comparison skipped (nothing to compare).")

	print("")
	print("=== PROBE VR11 COMPLETE ===")
	get_tree().quit()
