extends Node
# Step 5.5 (godot-specialist) review probe for ADR-0002, 2026-08-24.
# Question: ADR-0002's Key Interfaces reading note says implementers should
# put AffinityReadResult in its own file (affinity_read_result.gd), separate
# from AffinityDataPool (affinity_data_pool.gd). But mechanism five writes
# `var rejection: ReadRejection = ReadRejection.NONE` as a BARE reference,
# and ReadRejection is stated elsewhere in the ADR (mechanism two) to be
# nested inside AffinityDataPool. This probe tests, in isolation, whether a
# bare cross-file reference to a nested enum compiles -- exactly the failure
# mode the ADR itself already documented and fixed once for Pair/Character/
# Source (hence the AffinityTypes wrapper). Discipline: compile-check every
# file via ResourceLoader + .reload()'s Error return before calling anything,
# never a bare load(), consistent with runner_c.gd/runner_d.gd precedent.

const S := "res://scripts/"

func _load_checked(filename: String) -> Dictionary:
	var res = ResourceLoader.load(S + filename, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return {"ok": false, "status": "FAILED (load->null)"}
	if not (res is GDScript):
		return {"ok": false, "status": "FAILED (not GDScript)"}
	var err: int = res.reload()
	if err != OK:
		return {"ok": false, "status": "FAILED (reload=%s)" % error_string(err)}
	return {"ok": true, "status": "COMPILED OK"}

func _ready() -> void:
	print("=== ADR-0002 review probe / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- outer_holder.gd (class_name OuterHolder, nested enum MyEnum) ---")
	var oh := _load_checked("outer_holder.gd")
	print("  [%s]" % oh["status"])

	print("")
	print("--- bare_ref_other_file.gd (BARE `MyEnum` reference from a DIFFERENT file) ---")
	var br := _load_checked("bare_ref_other_file.gd")
	print("  [%s]" % br["status"])

	print("")
	print("--- qualified_ref_other_file.gd (QUALIFIED `OuterHolder.MyEnum`, control group) ---")
	var qr := _load_checked("qualified_ref_other_file.gd")
	print("  [%s]" % qr["status"])

	print("")
	print("=== PROBE COMPLETE ===")
	get_tree().quit()
