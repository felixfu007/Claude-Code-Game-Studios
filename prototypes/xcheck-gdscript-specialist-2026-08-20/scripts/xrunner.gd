extends Node

const S := "res://scripts/"

func _compile_check(filename: String) -> String:
	var path := S + filename
	var res = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		return "FAILED (load->null)"
	if not (res is GDScript):
		return "FAILED (not GDScript)"
	var err: int = res.reload()
	if err != OK:
		return "FAILED (reload=%s)" % error_string(err)
	return "COMPILED OK"

func _pd(d: Dictionary, indent: String = "      ") -> void:
	for k in d.keys():
		print("%s%-30s = %s" % [indent, str(k), str(d[k])])

func _try(label: String, c: Callable) -> void:
	print("    >> %s : calling..." % label)
	var r = c.call()
	print("    << %s : returned %s (NOT aborted)" % [label, str(r)])

func _ready() -> void:
	print("=== XCHECK / Godot %s ===" % str(Engine.get_version_info().get("string")))

	print("")
	print("--- X1  compile-time enum FAMILY crossing (static, literal) ---")
	print("  [%s]  X1  Dictionary[Pair,int] indexed with Character.CHARACTER_1" % _compile_check("x1_static_wrong_family_key.gd"))
	print("  [%s]  X1b var p: Pair = Character.CHARACTER_1" % _compile_check("x1b_static_assign_crossfamily.gd"))
	print("  [%s]  X1c Dictionary[Character,int] assigned to Dictionary[Pair,int]" % _compile_check("x1c_static_dict_crossfamily.gd"))

	print("")
	print("--- X5  _compile_check reliability on a class_name'd broken script ---")
	print("  [%s]  X5  @abstract func WITH body, in a class_name'd file" % _compile_check("x5_broken_with_classname.gd"))

	print("")
	print("--- X8  does CACHE_MODE_IGNORE+reload() really re-read from DISK? ---")
	print("  [%s]  X8 before overwrite (source is valid)" % _compile_check("x8_mutable.gd"))
	var f := FileAccess.open(S + "x8_mutable.gd", FileAccess.WRITE)
	if f == null:
		print("  !! cannot write x8: %s" % error_string(FileAccess.get_open_error()))
	else:
		f.store_string("class_name XMutableProbe extends RefCounted\nfunc broken( -> void:\n\tpass\n")
		f.close()
		print("  [%s]  X8 after overwriting SAME PATH with a syntax error" % _compile_check("x8_mutable.gd"))

	print("")
	print("--- X4  container introspection API existence in 4.7.1 ---")
	print("  [%s]  x4_dict_introspect.gd (is_typed_key/get_typed_key_builtin)" % _compile_check("x4_dict_introspect.gd"))
	var p4 = load(S + "x4_dict_introspect.gd")
	if p4 is GDScript and p4.reload() == OK:
		_pd(p4.run())
	print("  [%s]  x4b_array_introspect.gd (get_typed_class_name/get_typed_script)" % _compile_check("x4b_array_introspect.gd"))
	var p4b = load(S + "x4b_array_introspect.gd")
	if p4b is GDScript and p4b.reload() == OK:
		_pd(p4b.run())

	print("")
	print("--- X3  option (d) two-layer type retention, actually probed ---")
	var p3 = load(S + "x3_wrapper_two_layer.gd")
	print("  [%s]  x3_wrapper_two_layer.gd" % _compile_check("x3_wrapper_two_layer.gd"))
	_pd(p3.inspect())

	print("")
	print("--- X7  does a bare-Array value slot preserve an inner typed Array? ---")
	var p7 = load(S + "x7_typed_inner_in_bare_slot.gd")
	_pd(p7.run())

	print("")
	print("=== hostile runtime writes below: engine errors expected ===")

	print("")
	print("--- X2  runtime enum FAMILY crossing into a typed Dictionary ---")
	var p2 = load(S + "x2_runtime_crossfamily.gd")
	_try("Dictionary[Pair,int][Character.CHARACTER_3] = 99", p2.try_wrong_family_key)

	print("")
	print("--- X3r  outer layer: wrong OBJECT class into Dictionary[Pair,AffinityRecordList] ---")
	_try("d[Pair.C1_C2] = XOtherClass.new()", p3.try_outer_wrong_object)

	print("")
	print("--- X3r  inner layer: wrong element appended to Array[AffinityRecord] ---")
	_try("list.items.append(XOtherClass.new())", p3.try_inner_wrong_element)

	print("")
	print("--- X6  what does the CALLER receive after a callee aborts mid-way? ---")
	var p6 = load(S + "x6_abort_return.gd")
	var got = p6.aborts_midway()
	print("    caller got: typeof=%s  type_string=%s  str=%s" % [str(typeof(got)), type_string(typeof(got)), str(got)])
	print("    got is Dictionary = %s" % str(got is Dictionary))
	print("    got == null       = %s" % str(got == null))
	_pd_typed(got)

	print("")
	print("=== XCHECK COMPLETE ===")
	get_tree().quit()

func _pd_typed(d: Dictionary) -> void:
	print("    _print_dict-style callee with typed param d: Dictionary -> size=%d" % d.size())
	for k in d.keys():
		print("      %s = %s" % [str(k), str(d[k])])
