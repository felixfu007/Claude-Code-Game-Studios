extends RefCounted
# C1 — R7E-13 safe subset: find_key/string-index/values().has() with VALID
# inputs, plus find_key() with a non-existent VALUE (999 -- a bad VALUE, not
# a bad KEY). Deliberately isolated from the invalid-string-KEY tests (see
# c2_*.gd / c3_*.gd): the first draft of this probe put the bad-literal-key
# test in this SAME file, and it turned out to be a compile-time Parse Error
# -- which fails reload() for the WHOLE FILE and silently blocked C1/C2/C3/C5
# too. That is exactly the "known-to-fail load() must not sit mid-report"
# pitfall this round was told to avoid; splitting the file is the fix.

static func test_find_key_valid() -> String:
	print("      >> test_find_key_valid: entering")
	var k = AffinityTypes.Pair.find_key(0)
	print("      >> test_find_key_valid: call done, about to return")
	return "REACHED END k=%s typeof(k)=%d" % [str(k), typeof(k)]

static func test_string_index_valid() -> String:
	print("      >> test_string_index_valid: entering")
	var v = AffinityTypes.Pair["C1_C2"]
	print("      >> test_string_index_valid: call done, about to return")
	return "REACHED END v=%s typeof(v)=%d" % [str(v), typeof(v)]

static func test_values_has() -> String:
	print("      >> test_values_has: entering")
	var has: bool = AffinityTypes.Pair.values().has(0)
	print("      >> test_values_has: call done, about to return")
	return "REACHED END has=%s" % str(has)

static func test_find_key_invalid_value() -> String:
	print("      >> test_find_key_invalid_value: entering")
	var k = AffinityTypes.Pair.find_key(999)
	print("      >> test_find_key_invalid_value: call done, about to return")
	return "REACHED END k=%s typeof(k)=%d" % [str(k), typeof(k)]
