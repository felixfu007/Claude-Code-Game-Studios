extends RefCounted
# X11a — is_finite()/is_nan()/is_inf() called with a Variant that actually
# holds a String, mimicking validate_semantics() reading an undecoded field
# straight out of a Dictionary produced by bytes_to_var().
#
# Each test function is self-contained and ends with an explicit "REACHED END"
# print + a non-empty String return. If the risky call aborts the function,
# the "REACHED END" line will NOT appear and the caller will receive "" (the
# zero value for -> String) — same abort-detection convention as X3r/X6.

static func test_is_finite_abc() -> String:
	print("      >> test_is_finite_abc: entering")
	var v: Variant = "abc"
	var r = is_finite(v)
	print("      >> test_is_finite_abc: is_finite() returned, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

static func test_is_finite_numeric_string() -> String:
	print("      >> test_is_finite_numeric_string: entering")
	var v: Variant = "1.5"
	var r = is_finite(v)
	print("      >> test_is_finite_numeric_string: is_finite() returned, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

static func test_is_nan_abc() -> String:
	print("      >> test_is_nan_abc: entering")
	var v: Variant = "abc"
	var r = is_nan(v)
	print("      >> test_is_nan_abc: is_nan() returned, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

static func test_is_inf_abc() -> String:
	print("      >> test_is_inf_abc: entering")
	var v: Variant = "abc"
	var r = is_inf(v)
	print("      >> test_is_inf_abc: is_inf() returned, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

# Propagation check: does an abort inside the risky call escape past THIS
# wrapper too, or is it contained to the function that directly calls the
# builtin? Mirrors X6's aborts_midway/caller pattern but for is_finite().
static func test_is_finite_abc_wrapped() -> String:
	print("      >> test_is_finite_abc_wrapped: entering, calling test_is_finite_abc()")
	var inner: String = test_is_finite_abc()
	print("      >> test_is_finite_abc_wrapped: inner call returned '%s', about to return" % inner)
	return "WRAPPER REACHED END inner=[%s]" % inner
