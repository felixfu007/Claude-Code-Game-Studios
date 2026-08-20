extends Node
# ROUND7 Probe D — closes README "殘留未查證項" #1 (values().has() on
# out-of-range-but-legal-int input) and #2 (keys().has() symmetry with
# values().has(), for both a valid name, an invalid literal name, and an
# invalid dynamically-built name). Follows the exact compile-check-then-call
# discipline established by runner_c.gd: every file is compile-checked via
# ResourceLoader + `.reload()`'s Error return (NEVER a bare `load()`) before
# anything in it is called, and any test with unknown/compile-risk sits in
# its own file so a Parse Error in one cannot silently block the others.

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
	print("=== ROUND7 Probe D / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- D0: compile-check ALL THREE files BEFORE calling anything into any of them ---")
	var d1_check: Dictionary = _load_checked("d1_pair_ops_safe.gd")
	print("  [%s]  d1_pair_ops_safe.gd (values().has(-1)/(999), keys().has(valid))" % d1_check["status"])
	var d2_check: Dictionary = _load_checked("d2_keys_has_invalid_literal.gd")
	print("  [%s]  d2_keys_has_invalid_literal.gd (keys().has() invalid literal)" % d2_check["status"])
	var d3_check: Dictionary = _load_checked("d3_keys_has_invalid_dynamic.gd")
	print("  [%s]  d3_keys_has_invalid_dynamic.gd (keys().has() invalid dynamic)" % d3_check["status"])

	if d1_check["ok"]:
		var d1 = d1_check["script"]
		print("")
		print("--- D1a: Pair.values().has(-1) -- out-of-range but legal int ---")
		_run_str("AffinityTypes.Pair.values().has(-1)", d1.test_values_has_negative_one)
		print("")
		print("--- D1b: Pair.values().has(999) -- out-of-range but legal int ---")
		_run_str("AffinityTypes.Pair.values().has(999)", d1.test_values_has_999)
		print("")
		print("--- D1c: Pair.keys().has(\"C1_C2\") -- valid member name, literal ---")
		_run_str("AffinityTypes.Pair.keys().has(\"C1_C2\")", d1.test_keys_has_valid_literal)
	else:
		print("  D1a/D1b/D1c SKIPPED -- d1_pair_ops_safe.gd failed to compile, see status above")

	print("")
	print("--- D2: Pair.keys().has(\"NO_SUCH_PAIR\") -- invalid name, STATIC LITERAL ---")
	if d2_check["ok"]:
		_run_str("AffinityTypes.Pair.keys().has(\"NO_SUCH_PAIR\") (literal)", d2_check["script"].test_keys_has_invalid_literal)
	else:
		print("  COMPILE FAILED (status above)")

	print("")
	print("--- D3: Pair.keys().has(bad_key) -- invalid name, built at RUNTIME ---")
	if d3_check["ok"]:
		_run_str("AffinityTypes.Pair.keys().has(bad_key) (dynamic, not constant-foldable)", d3_check["script"].test_keys_has_invalid_dynamic)
	else:
		print("  COMPILE FAILED (status above)")

	print("")
	print("=== ROUND7 Probe D COMPLETE ===")
	get_tree().quit()
