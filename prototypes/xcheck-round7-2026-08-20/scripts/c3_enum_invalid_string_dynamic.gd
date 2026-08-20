extends RefCounted
# C4-dynamic — R7E-13: the SAME invalid key as c2_*.gd, but built at RUNTIME
# (not a literal) so the GDScript compiler cannot constant-fold it and reject
# the file at parse time. This is the shape that actually matters for
# ADR-0002 mechanism eight's `from_dict()` persistence path: an untrusted
# `Pair` name arrives as DATA read from a Dictionary (e.g. a corrupted or
# hand-edited save file), not as source code the compiler can see in advance.

static func test_string_index_invalid_dynamic() -> String:
	print("      >> test_string_index_invalid_dynamic: entering")
	var parts: Array[String] = ["NO_SUCH", "_PAIR"]
	var bad_key: String = "".join(parts)  # not constant-foldable
	print("      >> test_string_index_invalid_dynamic: bad_key built = %s" % bad_key)
	var v = AffinityTypes.Pair[bad_key]
	print("      >> test_string_index_invalid_dynamic: subscript done, about to return")
	return "REACHED END v=%s typeof(v)=%d" % [str(v), typeof(v)]
