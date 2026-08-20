extends RefCounted
# X11c — the actual mechanism this ADR relies on for "type safety at the
# boundary": (1) assigning a Dictionary[String,Variant]-sourced value into a
# statically-typed `float`/`int` local (the exact shape `AffinityRecord.from_dict()`
# would use), and (2) calling a function with a statically-typed `float`
# parameter (the exact shape `append_record(pair, m: float, source)` uses)
# but passing a Variant that actually holds a String at the call site (not
# visible to static analysis, same "smuggle via Variant" technique as X3r).
#
# This directly tests the coordinator's question: is append_record()'s `m: float`
# parameter actually safe because layer one (static typing) catches bad calls,
# or does something silently coerce the wrong-typed Variant into a float
# (e.g. String "abc" -> 0.0) without any error at all?

# ── (1) typed LOCAL VARIABLE assignment from an untyped Dictionary value ──
# mirrors: var m: float = data["m"]  inside AffinityRecord.from_dict()

static func test_assign_float_var_from_dict_string_abc() -> String:
	print("      >> test_assign_float_var_from_dict_string_abc: entering")
	var d: Dictionary = {"m": "abc"}
	var m: float = d["m"]
	print("      >> test_assign_float_var_from_dict_string_abc: assignment done, about to return")
	return "REACHED END m=%s typeof(m)=%d" % [str(m), typeof(m)]

static func test_assign_float_var_from_dict_string_numeric() -> String:
	print("      >> test_assign_float_var_from_dict_string_numeric: entering")
	var d: Dictionary = {"m": "1.5"}
	var m: float = d["m"]
	print("      >> test_assign_float_var_from_dict_string_numeric: assignment done, about to return")
	return "REACHED END m=%s typeof(m)=%d" % [str(m), typeof(m)]

static func test_assign_int_var_from_dict_float() -> String:
	print("      >> test_assign_int_var_from_dict_float: entering")
	var d: Dictionary = {"t": 1.5}
	var t: int = d["t"]
	print("      >> test_assign_int_var_from_dict_float: assignment done, about to return")
	return "REACHED END t=%s typeof(t)=%d" % [str(t), typeof(t)]

static func test_assign_int_var_from_dict_string() -> String:
	print("      >> test_assign_int_var_from_dict_string: entering")
	var d: Dictionary = {"t": "abc"}
	var t: int = d["t"]
	print("      >> test_assign_int_var_from_dict_string: assignment done, about to return")
	return "REACHED END t=%s typeof(t)=%d" % [str(t), typeof(t)]

# ── (2) CALLING a typed-parameter function with a Variant smuggled bad value ──
# mirrors: append_record(pair: Pair, m: float, source: Source) called with
# m sourced from a Variant that is not actually a float at runtime.

static func _append_like(pair_id: int, m: float, source_id: int) -> String:
	return "received: m=%s typeof(m)=%d" % [str(m), typeof(m)]

static func test_call_typed_param_with_variant_string_abc() -> String:
	print("      >> test_call_typed_param_with_variant_string_abc: entering")
	var smuggled: Variant = "abc"
	var r: String = _append_like(0, smuggled, 0)
	print("      >> test_call_typed_param_with_variant_string_abc: call returned, about to return")
	return "REACHED END callee_said=[%s]" % r

static func test_call_typed_param_with_variant_string_numeric() -> String:
	print("      >> test_call_typed_param_with_variant_string_numeric: entering")
	var smuggled: Variant = "1.5"
	var r: String = _append_like(0, smuggled, 0)
	print("      >> test_call_typed_param_with_variant_string_numeric: call returned, about to return")
	return "REACHED END callee_said=[%s]" % r

# ── (3) STATICALLY visible bad call (literal, not through Variant) ──
# expected: caught at compile time like x1b/x1c, proving layer one only
# helps when the bad type is visible to the compiler, not when it arrives
# through a Variant/Dictionary at runtime. This function is loaded+reloaded
# by the runner via ResourceLoader, same technique as x1b/x1c/x9 series.
