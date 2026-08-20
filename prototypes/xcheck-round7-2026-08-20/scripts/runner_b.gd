extends Node
# ROUND7 Probe B (HIGHEST PRIORITY) — closes R7E-4. ADR-0002 mechanism four's
# `INVALID_SOURCE`/`INVALID_PAIR` rejection codes, and mechanism four-of-three's
# "type errors abort the whole caller function, so the rejection-code machinery
# doesn't need to (and can't) cover type errors" argument, were only tested
# against ONE type (String) in the prior XCHECK-4 spike. `pair`/`source`/
# `character` are all enums (backed by int). This probe tests float, float
# (integer-valued), String, bool, and two OUT-OF-RANGE-BUT-LEGAL-int values
# against both an enum parameter and a bare int parameter.
#
# Judgment rule: same "REACHED END" / empty-string-means-aborted convention as
# Probe A and prior xcheck rounds.

const S := "res://scripts/"

func _run_str(label: String, c: Callable) -> void:
	print("    >> %s : calling..." % label)
	var r: String = c.call()
	if r == "":
		print("    << %s : returned EMPTY STRING -- ABORTED (zero value for -> String)" % label)
	else:
		print("    << %s : returned [%s]" % [label, r])

func _ready() -> void:
	print("=== ROUND7 Probe B / Godot %s ===" % str(Engine.get_version_info().get("string")))
	var b1 = load(S + "b1_enum_param.gd")

	print("")
	print("--- B1: f(p: AffinityTypes.Pair) called via Variant smuggling ---")
	_run_str("f(Variant holding 3.7 float, IN-RANGE ordinal magnitude)", b1.call_f_with.bind(3.7))
	_run_str("f(Variant holding 3.0 float, IN-RANGE, integer-valued)", b1.call_f_with.bind(3.0))
	_run_str("f(Variant holding \"3\" String)", b1.call_f_with.bind("3"))
	_run_str("f(Variant holding true Bool)", b1.call_f_with.bind(true))
	_run_str("f(Variant holding -1 int, LEGAL int / ILLEGAL enum ordinal)", b1.call_f_with.bind(-1))
	_run_str("f(Variant holding 999 int, LEGAL int / ILLEGAL enum ordinal)", b1.call_f_with.bind(999))

	print("")
	print("--- B2 (CONTROL GROUP): g(n: int) called with the SAME values, bare int parameter ---")
	_run_str("g(Variant holding 3.7 float)", b1.call_g_with.bind(3.7))
	_run_str("g(Variant holding 3.0 float)", b1.call_g_with.bind(3.0))
	_run_str("g(Variant holding \"3\" String)", b1.call_g_with.bind("3"))
	_run_str("g(Variant holding true Bool)", b1.call_g_with.bind(true))
	_run_str("g(Variant holding -1 int)", b1.call_g_with.bind(-1))
	_run_str("g(Variant holding 999 int)", b1.call_g_with.bind(999))

	print("")
	print("=== ROUND7 Probe B COMPLETE ===")
	get_tree().quit()
