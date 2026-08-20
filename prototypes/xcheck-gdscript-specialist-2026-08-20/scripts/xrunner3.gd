extends Node
func _ready() -> void:
	print("=== XCHECK-3 Phase2 API assumptions / %s ===" % str(Engine.get_version_info().get("string")))
	var d: GDScript = load("res://scripts/x10_derived.gd")
	print("-- get_script_method_list() on the DERIVED script (declares only 'only_here') --")
	for m in d.get_script_method_list():
		print("   %s" % str(m.get("name")))
	print("-- does it include the inherited assert_failure/run_tests? --")
	var names := []
	for m in d.get_script_method_list():
		names.append(str(m.get("name")))
	print("   'assert_failure' present = %s" % str("assert_failure" in names))
	print("   'run_tests' present      = %s" % str("run_tests" in names))
	print("-- walking get_base_script() chain --")
	var cur: GDScript = d
	while cur != null:
		var gname := str(cur.get_global_name())
		var ms := []
		for m in cur.get_script_method_list():
			ms.append(str(m.get("name")))
		print("   [%s] %s" % [gname if gname != "" else cur.resource_path, str(ms)])
		cur = cur.get_base_script()
	print("-- Object.get_method_list() on an INSTANCE (should include inherited) --")
	var inst: Node = d.new()
	var inames := []
	for m in inst.get_method_list():
		inames.append(str(m.get("name")))
	print("   'assert_failure' present = %s" % str("assert_failure" in inames))
	print("   'run_tests' present      = %s" % str("run_tests" in inames))
	print("   total methods on instance = %d" % inames.size())
	inst.free()
	print("-- ProjectSettings.get_global_class_list() exists? --")
	var gl: Array = ProjectSettings.get_global_class_list()
	print("   entries = %d" % gl.size())
	for e in gl:
		print("   class=%-22s base=%-14s path=%s" % [str(e.get("class")), str(e.get("base")), str(e.get("path"))])
	print("=== XCHECK-3 COMPLETE ===")
	get_tree().quit()
