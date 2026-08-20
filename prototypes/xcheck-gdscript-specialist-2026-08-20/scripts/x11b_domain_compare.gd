extends RefCounted
# X11b — ADR-0002 mechanism-four steps 2/3 comparison operators, fed a
# wrong-typed Variant, to see whether comparison OPERATORS behave the same
# as the builtin FUNCTIONS tested in x11a (abort) or differently (silent
# false/coercion). This is the evidence for "can the type-check scope be
# narrowed" — GDD step 2 is `m == 0.0`, step 3 is `is_nan(m) or is_inf(m)`.

static func test_eq_zero_string_abc() -> String:
	print("      >> test_eq_zero_string_abc: entering")
	var m: Variant = "abc"
	var r = (m == 0.0)
	print("      >> test_eq_zero_string_abc: comparison evaluated, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

static func test_eq_zero_string_zero() -> String:
	print("      >> test_eq_zero_string_zero: entering")
	var m: Variant = "0.0"
	var r = (m == 0.0)
	print("      >> test_eq_zero_string_zero: comparison evaluated, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

static func test_ge_one_float() -> String:
	print("      >> test_ge_one_float: entering")
	var t: Variant = 1.5
	var r = (t >= 1)
	print("      >> test_ge_one_float: comparison evaluated, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

static func test_ge_one_string_abc() -> String:
	print("      >> test_ge_one_string_abc: entering")
	var t: Variant = "abc"
	var r = (t >= 1)
	print("      >> test_ge_one_string_abc: comparison evaluated, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]

static func test_ge_one_string_numeric() -> String:
	print("      >> test_ge_one_string_numeric: entering")
	var t: Variant = "5"
	var r = (t >= 1)
	print("      >> test_ge_one_string_numeric: comparison evaluated, about to return")
	return "REACHED END r=%s typeof(r)=%d" % [str(r), typeof(r)]
