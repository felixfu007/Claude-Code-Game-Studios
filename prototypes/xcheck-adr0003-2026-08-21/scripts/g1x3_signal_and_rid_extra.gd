# ============================================================================
# G-1x3 —— 隔離檔:Signal.get_object_id() 與 Resource.get_rid()
# ============================================================================
# Resource.get_rid() 是 G-1e 的**備援 RID 來源** —— 它不需要手動釋放,
# 但也可能回傳 invalid RID。放在隔離檔是因為它的存在性我沒查證過。
extends RefCounted

static func probe_signal_objid() -> String:
	var t := GProbeTarget.new()
	var sg: Signal = t.pinged
	print("      Signal.get_object_id() = %d  (來源物件 get_instance_id=%d)" % [
		sg.get_object_id(), t.get_instance_id()])
	return "S-G1x3sig-REACHED-END"

static func probe_resource_get_rid() -> String:
	var r := Resource.new()
	var rid: RID = r.get_rid()
	print("      Resource.get_rid() -> typeof=%d  is_valid=%s  get_id=%d" % [
		typeof(rid), str(rid.is_valid()), rid.get_id()])
	return "S-G1x3rid-REACHED-END"
