extends Node
# Probe for the claim under review in Story 003 (cursor_surface_registry.gd /
# ADR-0005 機制三): for a statically Control-typed parameter, does passing an
# already-freed (non-null) object trip a SCRIPT ERROR at the CALL BOUNDARY
# itself — aborting the CALLER and never entering the callee's body — as
# opposed to the callee's body running and its own is_instance_valid() guard
# catching it?
#
# Hypothesis under test (from cursor_surface_registry.gd's doc comment):
# "an already-freed (non-null) argument never reaches this method's body at
# all — GDScript's typed-parameter boundary check rejects it ... and aborts
# the CALLER, one level higher than the C2/F-10 finding" (F-10 tested
# Callable.call() on a freed object's own bound method, not this).
#
# Judgment rule, same as the 2026-08-20 xcheck spikes: each risky call is
# wrapped in its own function ending with "REACHED END" right before its
# return. The runner invokes each wrapper through a Callable's .call(), which
# safely absorbs an abort one level down. If a wrapper aborts partway, .call()
# yields the zero value for its declared return type ("" for -> String) and
# this line never printed inside the callee: "ENTERED BODY".

const ProbeTests := preload("res://scripts/probe_tests.gd")


func _run_str(label: String, c: Callable) -> void:
	print("    >> %s : calling..." % label)
	var r: String = c.call()
	if r == "":
		print("    << %s : returned EMPTY STRING -- ABORTED (zero value for -> String)" % label)
	else:
		print("    << %s : returned [%s]" % [label, r])


func _ready() -> void:
	print("=== ADR-0005 Story 003 freed-Control call-boundary probe / Godot %s ===" % str(Engine.get_version_info().get("string")))

	# ── Case A: immediate .free() (synchronous, not deferred) ──────────────
	print("")
	print("--- Case A: Control freed via immediate .free() (synchronous) ---")
	var control_a := Control.new()
	var freed_ref_a: Variant = control_a
	control_a.free()
	print("  after .free(): is_instance_valid(freed_ref_a)=%s  freed_ref_a==null:%s" % [
		str(is_instance_valid(freed_ref_a)), str(freed_ref_a == null)
	])
	_run_str(
		"Case A -> Callee.typed_control_param(freed_ref_a) [typed Control param]",
		ProbeTests.test_typed_control_param_with_freed_object.bind(freed_ref_a)
	)
	_run_str(
		"Case A -> Callee.typed_node_param(freed_ref_a) [typed Node param]",
		ProbeTests.test_typed_node_param_with_freed_object.bind(freed_ref_a)
	)
	_run_str(
		"Case A -> Callee.untyped_variant_param(freed_ref_a) [untyped Variant param, control case]",
		ProbeTests.test_untyped_variant_param_with_freed_object.bind(freed_ref_a)
	)

	# ── Case B: queue_free() while in the tree, awaited across 2 frames ────
	print("")
	print("--- Case B: Control in the SceneTree, queue_free()'d, awaited 2 process frames ---")
	var control_b := Control.new()
	add_child(control_b)
	var freed_ref_b: Variant = control_b
	control_b.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("  after queue_free()+2 frames: is_instance_valid(freed_ref_b)=%s  freed_ref_b==null:%s" % [
		str(is_instance_valid(freed_ref_b)), str(freed_ref_b == null)
	])
	_run_str(
		"Case B -> Callee.typed_control_param(freed_ref_b) [typed Control param]",
		ProbeTests.test_typed_control_param_with_freed_object.bind(freed_ref_b)
	)

	# ── Control group 1: still-valid Control, same wrapper shape ────────────
	print("")
	print("--- Control group: still-VALID Control through the same typed-param call ---")
	var control_c := Control.new()
	_run_str(
		"Control group -> Callee.typed_control_param(valid_control) [typed Control param, NOT freed]",
		ProbeTests.test_typed_control_param_with_valid_object.bind(control_c)
	)
	control_c.free()

	# ── Control group 2: literal null (the case cursor_surface_registry.gd's
	#    own test already covers, included here for a side-by-side comparison
	#    in the same run) ─────────────────────────────────────────────────
	print("")
	print("--- Control group: literal null through the same typed-param call ---")
	_run_str(
		"Control group -> Callee.typed_control_param(null) [typed Control param, literal null]",
		ProbeTests.test_typed_control_param_with_null.bind(null)
	)

	print("")
	print("=== PROBE COMPLETE ===")
	get_tree().quit()
