class_name R7AMissingKey extends RefCounted
# A4 — R7E-2: what actually happens reading a NEVER-WRITTEN key from a typed
# Dictionary? Tested for both value shapes used by ADR-0002: enum-key +
# custom-class-value (_records), and enum-key + int-value (_death_marks).
# `read_back` is deliberately captured into a `Variant`-typed local (not an
# inferred/typed one) so static analysis cannot silently coerce or mask
# whatever the runtime subscript actually returns.

static func read_missing_pair_key() -> String:
	print("      >> read_missing_pair_key: entering")
	var d: Dictionary[AffinityTypes.Pair, AffinityRecordList] = {}
	var v: Variant = d[AffinityTypes.Pair.C1_C3]  # C1_C3 never written
	print("      >> read_missing_pair_key: subscript done, about to return")
	return "REACHED END v=%s typeof(v)=%d is_null=%s" % [str(v), typeof(v), str(v == null)]

static func read_missing_character_key() -> String:
	print("      >> read_missing_character_key: entering")
	var d: Dictionary[AffinityTypes.Character, int] = {}
	var v: Variant = d[AffinityTypes.Character.CHARACTER_3]  # never written
	print("      >> read_missing_character_key: subscript done, about to return")
	return "REACHED END v=%s typeof(v)=%d is_null=%s" % [str(v), typeof(v), str(v == null)]
