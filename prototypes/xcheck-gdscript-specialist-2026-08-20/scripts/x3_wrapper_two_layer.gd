extends RefCounted

static func inspect() -> Dictionary:
	var d: Dictionary[AffinityTypes.Pair, AffinityRecordList] = {}
	var list := AffinityRecordList.new()
	list.items.append(AffinityRecord.new())
	d[AffinityTypes.Pair.C1_C2] = list

	var v: Variant = d[AffinityTypes.Pair.C1_C2]
	var o: Object = v
	var scr: Variant = o.get_script()
	var out := {}
	out["get_class()"] = o.get_class()
	out["script.get_global_name()"] = str(scr.get_global_name()) if scr != null else "<no script>"
	out["v is AffinityRecordList"] = str(v is AffinityRecordList)
	out["inner.items.is_typed()"] = str(list.items.is_typed())
	return out

static func try_outer_wrong_object() -> String:
	var d: Dictionary[AffinityTypes.Pair, AffinityRecordList] = {}
	var sneaky: Variant = XOtherClass.new()
	d[AffinityTypes.Pair.C1_C2] = sneaky
	return "NOT ABORTED size=%d" % d.size()

static func try_inner_wrong_element() -> String:
	var list := AffinityRecordList.new()
	var sneaky: Variant = XOtherClass.new()
	list.items.append(sneaky)
	return "NOT ABORTED items.size=%d" % list.items.size()
