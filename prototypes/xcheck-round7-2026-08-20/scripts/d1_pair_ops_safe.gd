extends RefCounted
# D1 — closes README "殘留未查證項" #1 and half of #2. Safe subset: out-of-range
# but legal-int values().has() calls, plus keys().has() with a VALID literal
# name. Deliberately isolated from the invalid-string-name keys().has() tests
# (see d2_*.gd / d3_*.gd) following the exact same discipline that c1/c2/c3
# established: even though `.has(string_literal)` is a plain Array method call
# (not the special-cased enum-as-Dictionary literal subscript that caused
# c2's Parse Error), we do NOT assume that difference is safe until measured
# -- keep it split regardless.

static func test_values_has_negative_one() -> String:
	print("      >> test_values_has_negative_one: entering")
	var has: bool = AffinityTypes.Pair.values().has(-1)
	print("      >> test_values_has_negative_one: call done, about to return")
	return "REACHED END has=%s" % str(has)

static func test_values_has_999() -> String:
	print("      >> test_values_has_999: entering")
	var has: bool = AffinityTypes.Pair.values().has(999)
	print("      >> test_values_has_999: call done, about to return")
	return "REACHED END has=%s" % str(has)

static func test_keys_has_valid_literal() -> String:
	print("      >> test_keys_has_valid_literal: entering")
	var has: bool = AffinityTypes.Pair.keys().has("C1_C2")
	print("      >> test_keys_has_valid_literal: call done, about to return")
	return "REACHED END has=%s" % str(has)
