extends Node
const S := "res://scripts/"
func _cc(fn: String) -> String:
	var res = ResourceLoader.load(S + fn, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null: return "FAILED (load->null)"
	if not (res is GDScript): return "FAILED (not GDScript)"
	var e: int = res.reload()
	return "COMPILED OK" if e == OK else "FAILED (reload=%s)" % error_string(e)
func _ready() -> void:
	print("=== XCHECK-2 exact ADR-0002 forms / Godot %s ===" % str(Engine.get_version_info().get("string")))
	print("  [%s]  X9  class MEMBER, no initializer (ADR-0002 line 114 verbatim)" % _cc("x9_adr_member_exact.gd"))
	print("  [%s]  X9b same type as a function PARAMETER" % _cc("x9b_adr_param.gd"))
	print("  [%s]  X9c same type as a RETURN type" % _cc("x9c_adr_return.gd"))
	print("  [%s]  X9d option (d) as class MEMBER, no initializer" % _cc("x9d_wrapper_member.gd"))
	var p = load(S + "x9d_wrapper_member.gd")
	print("        %s" % str(p.probe()))
	print("  [%s]  X9e ADR-0002 VR#5 subscript-assign inference" % _cc("x9e_subscript_infer.gd"))
	var q = load(S + "x9e_subscript_infer.gd")
	for k in q.run().keys():
		print("        %s = %s" % [k, str(q.run()[k])])
	print("=== XCHECK-2 COMPLETE ===")
	get_tree().quit()
