extends Node
# Probe VR#9 (ADR-0002 VR table item 9, 2026-08-24): does `match typeof(x)`
# actually land in the TYPE_NIL branch for null? Is TYPE_NIL-as-named-constant
# equivalent to the bare literal 0 as a case label? Does a `_` default placed
# BEFORE TYPE_NIL in source order swallow null? What happens with no TYPE_NIL
# case at all? And do TYPE_FLOAT/TYPE_INT/TYPE_STRING/TYPE_BOOL each land in
# their own branch and nowhere else -- ADR-0002 already found that enum-typed
# parameters silently accept float/bool/out-of-range int (scripting-typing.md
# section 3), so this checks whether `match typeof(x)` has an analogous
# leniency.
#
# Discipline: one claim per printed line, tagged "RESULT" / "CASE" so every
# conclusion in the README maps to exactly one grep-able log line. No file
# compilation is being tested here (no class_name involved anywhere in this
# probe), only match-statement runtime branch selection, so the reload()
# compile-check discipline does not apply to this probe -- see README.

func _classify_named(v: Variant) -> String:
	# TYPE_NIL / TYPE_INT / TYPE_FLOAT / TYPE_STRING / TYPE_BOOL named
	# constants, in that source order, with `_` last.
	match typeof(v):
		TYPE_NIL:
			return "TYPE_NIL"
		TYPE_INT:
			return "TYPE_INT"
		TYPE_FLOAT:
			return "TYPE_FLOAT"
		TYPE_STRING:
			return "TYPE_STRING"
		TYPE_BOOL:
			return "TYPE_BOOL"
		_:
			return "DEFAULT"

func _classify_literal_zero(v: Variant) -> String:
	# Identical structure, but the TYPE_NIL case is written as the bare
	# literal `0` instead of the named constant.
	match typeof(v):
		0:
			return "TYPE_NIL(as literal 0)"
		TYPE_INT:
			return "TYPE_INT"
		TYPE_FLOAT:
			return "TYPE_FLOAT"
		TYPE_STRING:
			return "TYPE_STRING"
		TYPE_BOOL:
			return "TYPE_BOOL"
		_:
			return "DEFAULT"

func _load_checked(res_path: String) -> Dictionary:
	# Compile-check discipline for the one sub-test whose compile outcome is
	# itself uncertain (see probe_order_test.gd's header comment):判編譯用
	# reload() 的 Error 回傳值,絕不用「load() 不是 null」。
	var res = ResourceLoader.load(res_path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return {"ok": false, "status": "FAILED (load->null)"}
	if not (res is GDScript):
		return {"ok": false, "status": "FAILED (not GDScript)"}
	var err: int = res.reload()
	if err != OK:
		return {"ok": false, "status": "FAILED (reload=%s)" % error_string(err), "script": null}
	return {"ok": true, "status": "COMPILED OK", "script": res}

func _classify_no_nil_case(v: Variant) -> String:
	# No TYPE_NIL case at all -- only TYPE_INT and `_`. Confirms null falls
	# through to `_` in the absence of a dedicated NIL branch. The ADR's
	# actual gate always has a TYPE_NIL case, so this is a baseline sanity
	# check, not a claim about the real gate shape.
	match typeof(v):
		TYPE_INT:
			return "TYPE_INT"
		_:
			return "DEFAULT"

func _run_case(label: String, v: Variant) -> void:
	var t: int = typeof(v)
	var named: String = _classify_named(v)
	var lit_raw: String = _classify_literal_zero(v)
	var lit_normalized: String = "TYPE_NIL" if lit_raw == "TYPE_NIL(as literal 0)" else lit_raw
	var agree: String = "MATCH" if named == lit_normalized else "MISMATCH"
	print("RESULT case=%-16s typeof=%-3d named_branch=%-12s literal0_branch=%-24s agree=%s" % [label, t, named, lit_raw, agree])

func _ready() -> void:
	print("=== VR9 probe: match typeof(x) branch selection / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- A: does typeof(null) actually hit the TYPE_NIL branch? ---")
	_run_case("null", null)

	print("")
	print("--- B: TYPE_NIL constant vs literal 0 as case label, across several typeof() values ---")
	print("--- (also covers required TYPE_FLOAT / TYPE_INT / TYPE_STRING, plus TYPE_BOOL/array/dict/Vector2 for extra coverage) ---")
	_run_case("null", null)
	_run_case("int_0", 0)
	_run_case("int_5", 5)
	_run_case("int_neg1", -1)
	_run_case("float_3.14", 3.14)
	_run_case("float_0.0", 0.0)
	_run_case("string_hello", "hello")
	_run_case("string_empty", "")
	_run_case("bool_true", true)
	_run_case("bool_false", false)
	_run_case("array_empty", [])
	_run_case("dict_empty", {})
	_run_case("vector2", Vector2(1, 2))

	print("")
	print("--- C: does a `_` default placed BEFORE TYPE_NIL in source order swallow null? ---")
	var order_result: String = _classify_default_before_nil(null)
	print("RESULT case=null(order_test) branch=%s" % order_result)

	print("")
	print("--- D: with no TYPE_NIL case at all, does null fall through to `_`? ---")
	var no_nil_result: String = _classify_no_nil_case(null)
	print("RESULT case=null(no_nil_case_test) branch=%s" % no_nil_result)

	print("")
	print("=== PROBE VR9 COMPLETE ===")
	get_tree().quit()
