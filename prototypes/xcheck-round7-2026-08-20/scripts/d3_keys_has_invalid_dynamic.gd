extends RefCounted
# D3 — same invalid name as d2_*.gd, but built at RUNTIME (not a literal) so
# the compiler cannot constant-fold it and reject the file at parse time.
# This is the shape that actually matters for ADR-0002 mechanism eight's
# from_dict()/validate_semantics() path: an untrusted Pair name arrives as
# DATA read from a save file, not as source code the compiler can see in
# advance. Mirrors c3_enum_invalid_string_dynamic.gd's non-constant-foldable
# construction technique exactly.

static func test_keys_has_invalid_dynamic() -> String:
	print("      >> test_keys_has_invalid_dynamic: entering")
	var parts: Array[String] = ["NO_SUCH", "_PAIR"]
	var bad_key: String = "".join(parts)  # not constant-foldable
	print("      >> test_keys_has_invalid_dynamic: bad_key built = %s" % bad_key)
	var has: bool = AffinityTypes.Pair.keys().has(bad_key)
	print("      >> test_keys_has_invalid_dynamic: call done, about to return")
	return "REACHED END has=%s" % str(has)
