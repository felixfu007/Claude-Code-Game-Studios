extends Node
# Probe VR#12 (ADR-0002 VR table item 12, 2026-08-25): var_to_bytes() /
# bytes_to_var() round-trip type fidelity for int and float.
#
# Why this matters (see docs/architecture/adr-0002-...-contract.md line 642,
# R7E-10): mechanism eight's validate_semantics() REJECTS a restored `m` field
# unless typeof(m) == TYPE_FLOAT(3) exactly -- TYPE_INT(2) is rejected even
# though the numeric value could be identical (e.g. 2.0 vs 2). The rule's
# stated justification is "var_to_bytes() preserves Variant type" -- this
# probe is the first time that premise is actually measured instead of
# assumed. Symmetric claim for t/c (must be strictly TYPE_INT) is tested too.
#
# Discipline: one RESULT-prefixed, grep-able line per conclusion. No case is
# a boundary/abort risk (round-tripping a Variant through these two global
# functions is not documented anywhere in this project's reference library
# as an abort risk), so the BEFORE_READ/AFTER_READ scaffolding from the VR#11
# probe is not needed here -- but every comparison still prints its own
# self-contained RESULT line so nothing is inferred from an absence of output.

func _typeof_str(t: int) -> String:
	return "%d(%s)" % [t, type_string(t)]

func _double_hex(x: float) -> String:
	var pba := PackedByteArray()
	pba.resize(8)
	pba.encode_double(0, x)
	return pba.hex_encode()

func _int64_hex(x: int) -> String:
	var pba := PackedByteArray()
	pba.resize(8)
	pba.encode_s64(0, x)
	return pba.hex_encode()

# --- 1: float round-trip, integer-valued (the most suspicious group: 2.0
#        is numerically equal to int 2) ---
func _case_float_integer_valued() -> void:
	var values: Array[float] = [2.0, 0.0, -1.0, 1e10]
	for v in values:
		var bytes := var_to_bytes(v)
		var back = bytes_to_var(bytes)
		var t_after: int = typeof(back)
		var same_value: bool = (back == v)
		var same_bits: bool = (_double_hex(back) == _double_hex(v))
		print("RESULT float_integer_valued value=%s typeof_before=%s typeof_after=%s value_equal=%s bit_equal=%s hex_before=%s hex_after=%s" % [
			str(v), _typeof_str(typeof(v)), _typeof_str(t_after), str(same_value), str(same_bits),
			_double_hex(v), _double_hex(back)
		])

# --- 2: float round-trip, non-integer values (incl. extreme magnitudes) ---
func _case_float_non_integer() -> void:
	var values: Array[float] = [3.14, 0.1, 1.7976931348623157e308, 4.9406564584124654e-324]
	for v in values:
		var bytes := var_to_bytes(v)
		var back = bytes_to_var(bytes)
		var t_after: int = typeof(back)
		var same_value: bool = (back == v)
		var same_bits: bool = (_double_hex(back) == _double_hex(v))
		print("RESULT float_non_integer value=%s typeof_before=%s typeof_after=%s value_equal=%s bit_equal=%s hex_before=%s hex_after=%s" % [
			str(v), _typeof_str(typeof(v)), _typeof_str(t_after), str(same_value), str(same_bits),
			_double_hex(v), _double_hex(back)
		])

# --- 2b: follow-up isolation, spawned mid-run. Case 2 logged value=0.0 /
#         hex=all-zero for literal 4.9406564584124654e-324 (textbook smallest
#         positive double). That was true BEFORE var_to_bytes() was even
#         called (typeof(v)/hex_before already showed it), so if it's a real
#         underflow, it happened at GDScript float-literal parse time, not
#         inside the round-trip this probe exists to test. Isolate that here
#         with zero var_to_bytes()/bytes_to_var() calls -- pure literal parsing.
func _case_denormal_literal_isolation() -> void:
	var subnormal_min: float = 4.9406564584124654e-324
	var normal_min: float = 2.2250738585072014e-308
	var subnormal_mid: float = 1.0e-310

	print("RESULT literal_parse_subnormal_min literal=4.9406564584124654e-324 typeof=%s value=%s hex=%s is_zero=%s" % [
		_typeof_str(typeof(subnormal_min)), str(subnormal_min), _double_hex(subnormal_min), str(subnormal_min == 0.0)
	])
	print("RESULT literal_parse_normal_min literal=2.2250738585072014e-308 typeof=%s value=%s hex=%s is_zero=%s" % [
		_typeof_str(typeof(normal_min)), str(normal_min), _double_hex(normal_min), str(normal_min == 0.0)
	])
	print("RESULT literal_parse_subnormal_mid literal=1.0e-310 typeof=%s value=%s hex=%s is_zero=%s" % [
		_typeof_str(typeof(subnormal_mid)), str(subnormal_mid), _double_hex(subnormal_mid), str(subnormal_mid == 0.0)
	])

# --- 3: int round-trip, incl. beyond-32-bit magnitudes ---
func _case_int_roundtrip() -> void:
	var values: Array[int] = [0, 1, -1, 9007199254740993]
	for v in values:
		var bytes := var_to_bytes(v)
		var back = bytes_to_var(bytes)
		var t_after: int = typeof(back)
		var same_value: bool = (back == v)
		var same_bits: bool = (_int64_hex(back) == _int64_hex(v))
		print("RESULT int_roundtrip value=%s typeof_before=%s typeof_after=%s value_equal=%s bit_equal=%s hex_before=%s hex_after=%s" % [
			str(v), _typeof_str(typeof(v)), _typeof_str(t_after), str(same_value), str(same_bits),
			_int64_hex(v), _int64_hex(back)
		])

# --- 4: the actual export_state() container shape from ADR-0002/ADR-0003 ---
func _case_container_shape() -> void:
	var original: Dictionary = {
		"records": [{"pair": "C1_C2", "m": 2.0, "t": 10, "c": 3, "source": "combat_card"}],
		"campaign_tick_marks": [1, 2, 3],
		"death_marks": {"CHARACTER_A": 5}
	}

	var bytes := var_to_bytes(original)
	var back = bytes_to_var(bytes)

	print("RESULT container_top_level typeof_before=%s typeof_after=%s" % [
		_typeof_str(typeof(original)), _typeof_str(typeof(back))
	])

	if not (back is Dictionary):
		print("RESULT container_ABORT_TOP_LEVEL_NOT_DICTIONARY typeof_after=%s" % _typeof_str(typeof(back)))
		return

	var rec_back: Dictionary = back["records"][0]
	var rec_orig: Dictionary = original["records"][0]

	print("RESULT container_field_m typeof_before=%s typeof_after=%s value_before=%s value_after=%s value_equal=%s bit_equal=%s" % [
		_typeof_str(typeof(rec_orig["m"])), _typeof_str(typeof(rec_back["m"])),
		str(rec_orig["m"]), str(rec_back["m"]), str(rec_back["m"] == rec_orig["m"]),
		str(_double_hex(rec_back["m"]) == _double_hex(rec_orig["m"])) if typeof(rec_back["m"]) == TYPE_FLOAT else "N/A(typeof mismatch, see line above)"
	])

	print("RESULT container_field_t typeof_before=%s typeof_after=%s value_before=%s value_after=%s value_equal=%s" % [
		_typeof_str(typeof(rec_orig["t"])), _typeof_str(typeof(rec_back["t"])),
		str(rec_orig["t"]), str(rec_back["t"]), str(rec_back["t"] == rec_orig["t"])
	])

	print("RESULT container_field_c typeof_before=%s typeof_after=%s value_before=%s value_after=%s value_equal=%s" % [
		_typeof_str(typeof(rec_orig["c"])), _typeof_str(typeof(rec_back["c"])),
		str(rec_orig["c"]), str(rec_back["c"]), str(rec_back["c"] == rec_orig["c"])
	])

	print("RESULT container_field_pair typeof_before=%s typeof_after=%s value_equal=%s" % [
		_typeof_str(typeof(rec_orig["pair"])), _typeof_str(typeof(rec_back["pair"])),
		str(rec_back["pair"] == rec_orig["pair"])
	])

	print("RESULT container_field_source typeof_before=%s typeof_after=%s value_equal=%s" % [
		_typeof_str(typeof(rec_orig["source"])), _typeof_str(typeof(rec_back["source"])),
		str(rec_back["source"] == rec_orig["source"])
	])

	var ctm_back: Array = back["campaign_tick_marks"]
	var ctm_orig: Array = original["campaign_tick_marks"]
	print("RESULT container_field_campaign_tick_marks typeof_array_before=%s typeof_array_after=%s elem0_typeof_before=%s elem0_typeof_after=%s value_equal=%s" % [
		_typeof_str(typeof(ctm_orig)), _typeof_str(typeof(ctm_back)),
		_typeof_str(typeof(ctm_orig[0])), _typeof_str(typeof(ctm_back[0])),
		str(ctm_back == ctm_orig)
	])

	var dm_back: Dictionary = back["death_marks"]
	var dm_orig: Dictionary = original["death_marks"]
	print("RESULT container_field_death_marks typeof_before=%s typeof_after=%s key_typeof_before=%s key_typeof_after=%s value_typeof_before=%s value_typeof_after=%s value_equal=%s" % [
		_typeof_str(typeof(dm_orig)), _typeof_str(typeof(dm_back)),
		_typeof_str(typeof(dm_orig.keys()[0])), _typeof_str(typeof(dm_back.keys()[0])),
		_typeof_str(typeof(dm_orig["CHARACTER_A"])), _typeof_str(typeof(dm_back["CHARACTER_A"])),
		str(dm_back == dm_orig)
	])

	# Direct verdict lines for the two ADR rules under test.
	var m_is_strict_float: bool = typeof(rec_back["m"]) == TYPE_FLOAT
	print("RESULT VERDICT_m_strict_TYPE_FLOAT_after_container_roundtrip = %s" % str(m_is_strict_float))

	var t_is_strict_int: bool = typeof(rec_back["t"]) == TYPE_INT
	var c_is_strict_int: bool = typeof(rec_back["c"]) == TYPE_INT
	print("RESULT VERDICT_t_strict_TYPE_INT_after_container_roundtrip = %s" % str(t_is_strict_int))
	print("RESULT VERDICT_c_strict_TYPE_INT_after_container_roundtrip = %s" % str(c_is_strict_int))

# --- 5: special float values (INF/-INF/NAN) round-trip, and whether the
#        is_finite()/is_nan()/is_inf() checks mechanism eight relies on
#        still behave correctly on the round-tripped value ---
func _case_special_values() -> void:
	var inf_bytes := var_to_bytes(INF)
	var inf_back = bytes_to_var(inf_bytes)
	print("RESULT special_INF typeof_before=%s typeof_after=%s value_equal=%s is_inf_after=%s is_finite_after=%s" % [
		_typeof_str(typeof(INF)), _typeof_str(typeof(inf_back)), str(inf_back == INF),
		str(is_inf(inf_back)), str(is_finite(inf_back))
	])

	var neg_inf_bytes := var_to_bytes(-INF)
	var neg_inf_back = bytes_to_var(neg_inf_bytes)
	print("RESULT special_NEG_INF typeof_before=%s typeof_after=%s value_equal=%s is_inf_after=%s is_finite_after=%s" % [
		_typeof_str(typeof(-INF)), _typeof_str(typeof(neg_inf_back)), str(neg_inf_back == -INF),
		str(is_inf(neg_inf_back)), str(is_finite(neg_inf_back))
	])

	var nan_bytes := var_to_bytes(NAN)
	var nan_back = bytes_to_var(nan_bytes)
	# NAN != NAN by IEEE754 definition -- do not use `==` as the fidelity
	# check here, use is_nan() instead, and log both.
	print("RESULT special_NAN typeof_before=%s typeof_after=%s is_nan_after=%s naive_equal_would_be=%s is_finite_after=%s" % [
		_typeof_str(typeof(NAN)), _typeof_str(typeof(nan_back)), str(is_nan(nan_back)),
		str(nan_back == NAN), str(is_finite(nan_back))
	])

func _ready() -> void:
	print("=== VR12 probe: var_to_bytes()/bytes_to_var() int/float round-trip fidelity / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- 1: float round-trip, integer-valued ---")
	_case_float_integer_valued()

	print("")
	print("--- 2: float round-trip, non-integer / extreme magnitude ---")
	_case_float_non_integer()

	print("")
	print("--- 2b: follow-up isolation -- is the smallest-magnitude literal already 0.0 at parse time? ---")
	_case_denormal_literal_isolation()

	print("")
	print("--- 3: int round-trip, incl. beyond-32-bit ---")
	_case_int_roundtrip()

	print("")
	print("--- 4: container shape matching export_state() (Dictionary[Array[Dictionary], Array[int], Dictionary]) ---")
	_case_container_shape()

	print("")
	print("--- 5: special float values (INF/-INF/NAN) ---")
	_case_special_values()

	print("")
	print("=== PROBE VR12 COMPLETE ===")
	get_tree().quit()
