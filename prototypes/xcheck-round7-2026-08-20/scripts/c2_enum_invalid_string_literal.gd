extends RefCounted
# C4-literal — R7E-13: statically-known-bad STRING LITERAL subscript into the
# enum-as-dictionary (`AffinityTypes.Pair["NO_SUCH_PAIR"]`). Isolated in its
# OWN file on purpose: the runner MUST compile-check this file via
# ResourceLoader + `.reload()`'s Error return (see `_load_checked()` in
# runner_c.gd) BEFORE calling into it -- never a bare `load()` -- because this
# function is EXPECTED to possibly fail to even parse.

static func test_string_index_invalid_literal() -> String:
	print("      >> test_string_index_invalid_literal: entering")
	var v = AffinityTypes.Pair["NO_SUCH_PAIR"]
	print("      >> test_string_index_invalid_literal: call done, about to return")
	return "REACHED END v=%s typeof(v)=%d" % [str(v), typeof(v)]
