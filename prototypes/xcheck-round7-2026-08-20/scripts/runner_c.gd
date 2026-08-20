extends Node
# ROUND7 Probe C — closes R7E-13. REVISED after the first draft's C4 test
# (a STATIC STRING LITERAL bad key, `AffinityTypes.Pair["NO_SUCH_PAIR"]`)
# turned out to be a Parse Error, which failed the ENTIRE FILE's reload() and
# blocked every other test sharing that file -- exactly the "known-to-fail
# load() must not sit mid-report" pitfall this round was told to avoid. Fixed
# by: (a) isolating the literal-bad-key test into its own file (c2_*.gd),
# compile-checked via `_load_checked()` (ResourceLoader + reload()'s Error
# return, NEVER a bare `load()`) before any attempt to call into it; (b)
# adding a DYNAMIC (non-constant-foldable) bad-key variant (c3_*.gd) to
# answer the question that actually matters for ADR-0002's from_dict() path:
# an untrusted STRING key arriving as DATA (not source code) cannot possibly
# be a compile error -- so is it a silent value, or a runtime abort?

const S := "res://scripts/"

func _load_checked(filename: String) -> Dictionary:
	var res = ResourceLoader.load(S + filename, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return {"ok": false, "status": "FAILED (load->null)", "script": null}
	if not (res is GDScript):
		return {"ok": false, "status": "FAILED (not GDScript)", "script": null}
	var err: int = res.reload()
	if err != OK:
		return {"ok": false, "status": "FAILED (reload=%s)" % error_string(err), "script": null}
	return {"ok": true, "status": "COMPILED OK", "script": res}

func _run_str(label: String, c: Callable) -> void:
	print("    >> %s : calling..." % label)
	var r: String = c.call()
	if r == "":
		print("    << %s : returned EMPTY STRING -- ABORTED (zero value for -> String)" % label)
	else:
		print("    << %s : returned [%s]" % [label, r])

func _ready() -> void:
	print("=== ROUND7 Probe C / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- C0: compile-check ALL THREE files BEFORE calling anything into any of them ---")
	var c1_check: Dictionary = _load_checked("c1_enum_ops.gd")
	print("  [%s]  c1_enum_ops.gd (C1/C2/C3/C5 -- valid-input subset)" % c1_check["status"])
	var c2_check: Dictionary = _load_checked("c2_enum_invalid_string_literal.gd")
	print("  [%s]  c2_enum_invalid_string_literal.gd (C4-literal)" % c2_check["status"])
	var c3_check: Dictionary = _load_checked("c3_enum_invalid_string_dynamic.gd")
	print("  [%s]  c3_enum_invalid_string_dynamic.gd (C4-dynamic)" % c3_check["status"])

	if c1_check["ok"]:
		var c1 = c1_check["script"]
		print("")
		print("--- C1: Pair.find_key(0) -- valid ordinal ---")
		_run_str("AffinityTypes.Pair.find_key(0)", c1.test_find_key_valid)
		print("")
		print("--- C2: Pair[\"C1_C2\"] -- valid string subscript ---")
		_run_str("AffinityTypes.Pair[\"C1_C2\"]", c1.test_string_index_valid)
		print("")
		print("--- C3: Pair.values().has(0) ---")
		_run_str("AffinityTypes.Pair.values().has(0)", c1.test_values_has)
		print("")
		print("--- C5: Pair.find_key(999) -- value does not exist ---")
		_run_str("AffinityTypes.Pair.find_key(999)", c1.test_find_key_invalid_value)
	else:
		print("  C1/C2/C3/C5 SKIPPED -- c1_enum_ops.gd failed to compile, see status above")

	print("")
	print("--- C4-literal: Pair[\"NO_SUCH_PAIR\"] as a STATIC STRING LITERAL ---")
	if c2_check["ok"]:
		_run_str("AffinityTypes.Pair[\"NO_SUCH_PAIR\"] (literal)", c2_check["script"].test_string_index_invalid_literal)
	else:
		print("  COMPILE FAILED (status above) -- the bad literal key is caught as a PARSE ERROR, never even reaches runtime")

	print("")
	print("--- C4-dynamic: Pair[bad_key] where bad_key is built at RUNTIME, not a literal ---")
	if c3_check["ok"]:
		_run_str("AffinityTypes.Pair[bad_key] (dynamic, not constant-foldable)", c3_check["script"].test_string_index_invalid_dynamic)
	else:
		print("  COMPILE FAILED (status above)")

	print("")
	print("=== ROUND7 Probe C COMPLETE ===")
	get_tree().quit()
