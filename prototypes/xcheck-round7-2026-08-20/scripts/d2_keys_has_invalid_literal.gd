extends RefCounted
# D2 — closes the other half of README "殘留未查證項" #2. Statically-known-bad
# STRING LITERAL passed to `.has()` on the keys() Array (NOT a bracket
# subscript into the enum-as-Dictionary -- that shape is c2_*.gd's territory
# and already known to be a Parse Error). Isolated in its own file per the
# round's standing discipline: never assume a literal bad-name test is safe
# to co-locate with passing tests until it has been compile-checked in
# isolation via ResourceLoader + `.reload()`'s Error return.

static func test_keys_has_invalid_literal() -> String:
	print("      >> test_keys_has_invalid_literal: entering")
	var has: bool = AffinityTypes.Pair.keys().has("NO_SUCH_PAIR")
	print("      >> test_keys_has_invalid_literal: call done, about to return")
	return "REACHED END has=%s" % str(has)
