extends Node
# ROUND7 Probe A — closes R7E-1 (enum-key + custom-class-value Dictionary as a
# CLASS MEMBER, both without and with a `= {}` initializer -- a type
# combination NOT covered by the 2026-08-20 spike's four candidates) and
# R7E-2 (missing-key subscript read behavior on a typed Dictionary, for both
# the AffinityRecordList-valued form used by `_records` and the int-valued
# form used by `_death_marks`).
#
# Judgment rule (same trap as prior xcheck rounds -- see
# prototypes/xcheck-gdscript-specialist-2026-08-20/README.md): every risky
# test function is declared `-> String` and ends with an explicit "REACHED
# END" print immediately before its return. If a test aborts partway through,
# the "REACHED END" print never fires and the caller receives "" (the zero
# value for String) -- that is the ONLY reliable signal for abort-vs-not, not
# any printed label. Compile checks NEVER use a bare `load()` on a script that
# might fail to parse -- see `_load_checked()`: it uses
# ResourceLoader.load(..., CACHE_MODE_IGNORE) + `.reload()`'s Error return,
# and the SAME resource object is reused for instantiation (never re-`load()`d)
# so a known-bad script can never be placed mid-report and block a debugger.

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
	print("=== ROUND7 Probe A / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- A1 (R7E-1 Q1): class member `Dictionary[Pair, AffinityRecordList]`, NO initializer -- does it compile? ---")
	var a1_check: Dictionary = _load_checked("a1_member_no_init.gd")
	print("  [%s]  a1_member_no_init.gd" % a1_check["status"])

	print("")
	print("--- A2 (R7E-1 Q2): class member `Dictionary[Pair, AffinityRecordList]`, WITH '= {}' initializer -- does it compile? ---")
	var a2_check: Dictionary = _load_checked("a2_member_with_init.gd")
	print("  [%s]  a2_member_with_init.gd" % a2_check["status"])

	print("")
	print("--- A3 (R7E-1 Q3): after storing a value into each member form, is items.is_typed() true? (functional, reuses the SAME checked resource -- never re-load()s a script whose compile status is unknown) ---")
	if a1_check["ok"]:
		var a1_inst = a1_check["script"].new()
		_run_str("a1 (no-init member) .try_store_and_check(C1_C2)", a1_inst.try_store_and_check.bind(AffinityTypes.Pair.C1_C2))
	else:
		print("    SKIPPED a1 functional test -- compile failed, see A1 status above")

	if a2_check["ok"]:
		var a2_inst = a2_check["script"].new()
		_run_str("a2 (with-init member) .try_store_and_check(C1_C2)", a2_inst.try_store_and_check.bind(AffinityTypes.Pair.C1_C2))
	else:
		print("    SKIPPED a2 functional test -- compile failed, see A2 status above")

	print("")
	print("--- A4 (R7E-2): reading a NEVER-WRITTEN key from a typed Dictionary -- what actually happens? ---")
	var a4_check: Dictionary = _load_checked("a4_missing_key.gd")
	if a4_check["ok"]:
		var a4 = a4_check["script"]
		_run_str("d[Pair.C1_C3] on Dictionary[Pair, AffinityRecordList], key never written", a4.read_missing_pair_key)
		_run_str("d[Character.CHARACTER_3] on Dictionary[Character, int], key never written", a4.read_missing_character_key)
	else:
		print("  [%s]  a4_missing_key.gd -- SKIPPED, would not have compiled" % a4_check["status"])

	print("")
	print("=== ROUND7 Probe A COMPLETE ===")
	get_tree().quit()
