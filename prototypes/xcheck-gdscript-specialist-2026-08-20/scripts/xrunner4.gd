extends Node
# XCHECK-4 — closes ADR-0002 §A14 BLOCKING item: does validate_semantics()
# need to check TYPE before DOMAIN, and is append_record()'s `m: float`
# typed-parameter boundary actually safe against a Variant-smuggled wrong type?
#
# Judgment rule (same trap as XCHECK-1/2/3): every risky test function is
# declared `-> String` and ends with an explicit "REACHED END" print
# immediately before its return. If a test aborts partway through, the
# "REACHED END" print never fires and the caller receives "" (the zero value
# for String) — that is the ONLY reliable signal, not any printed label.

const S := "res://scripts/"

func _compile_check(filename: String) -> String:
	var res = ResourceLoader.load(S + filename, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return "FAILED (load->null)"
	if not (res is GDScript):
		return "FAILED (not GDScript)"
	var err: int = res.reload()
	if err != OK:
		return "FAILED (reload=%s)" % error_string(err)
	return "COMPILED OK"

func _run_str(label: String, c: Callable) -> void:
	print("    >> %s : calling..." % label)
	var r: String = c.call()
	if r == "":
		print("    << %s : returned EMPTY STRING -- ABORTED (zero value for -> String)" % label)
	else:
		print("    << %s : returned [%s]" % [label, r])

func _ready() -> void:
	print("=== XCHECK-4 type-vs-domain ordering / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- X11a  is_finite()/is_nan()/is_inf() given a Variant that is actually a String ---")
	var p11a = load(S + "x11a_builtin_fn_wrong_type.gd")
	_run_str("is_finite(Variant holding \"abc\")", p11a.test_is_finite_abc)
	_run_str("is_finite(Variant holding \"1.5\")", p11a.test_is_finite_numeric_string)
	_run_str("is_nan(Variant holding \"abc\")", p11a.test_is_nan_abc)
	_run_str("is_inf(Variant holding \"abc\")", p11a.test_is_inf_abc)
	_run_str("is_finite(\"abc\") called via a WRAPPER (propagation check)", p11a.test_is_finite_abc_wrapped)

	print("")
	print("--- X11b  m == 0.0 / t >= 1 comparison OPERATORS given wrong-typed Variant ---")
	var p11b = load(S + "x11b_domain_compare.gd")
	_run_str("(Variant \"abc\") == 0.0", p11b.test_eq_zero_string_abc)
	_run_str("(Variant \"0.0\") == 0.0", p11b.test_eq_zero_string_zero)
	_run_str("(Variant 1.5) >= 1", p11b.test_ge_one_float)
	_run_str("(Variant \"abc\") >= 1", p11b.test_ge_one_string_abc)
	_run_str("(Variant \"5\") >= 1", p11b.test_ge_one_string_numeric)

	print("")
	print("--- X11c  typed LOCAL VAR assignment from an untyped Dictionary value (from_dict() shape) ---")
	var p11c = load(S + "x11c_typed_boundary_assign.gd")
	_run_str("var m: float = {\"m\":\"abc\"}[\"m\"]", p11c.test_assign_float_var_from_dict_string_abc)
	_run_str("var m: float = {\"m\":\"1.5\"}[\"m\"]", p11c.test_assign_float_var_from_dict_string_numeric)
	_run_str("var t: int = {\"t\":1.5}[\"t\"]", p11c.test_assign_int_var_from_dict_float)
	_run_str("var t: int = {\"t\":\"abc\"}[\"t\"]", p11c.test_assign_int_var_from_dict_string)

	print("")
	print("--- X11c  CALLING a typed `m: float` parameter with a Variant smuggled at runtime (append_record() shape) ---")
	_run_str("_append_like(0, Variant(\"abc\"), 0)", p11c.test_call_typed_param_with_variant_string_abc)
	_run_str("_append_like(0, Variant(\"1.5\"), 0)", p11c.test_call_typed_param_with_variant_string_numeric)

	print("")
	print("--- X11d  STATICALLY visible wrong-type argument to typed `m: float` param (control, literal not Variant) ---")
	print("  [%s]  X11d _append_like(0, \"abc\", 0) -- literal String where float expected" % _compile_check("x11d_static_bad_call.gd"))

	print("")
	print("=== XCHECK-4 COMPLETE ===")
	get_tree().quit()
