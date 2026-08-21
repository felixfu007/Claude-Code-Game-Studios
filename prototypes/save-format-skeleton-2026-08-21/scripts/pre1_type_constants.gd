extends RefCounted
# PRE-1:規格要求「逐一列名 0-22 與 27-38」。若其中任何一個識別字在 4.7.1 不存在,
# 整個 SaveFormat 會 parse error。先在隔離檔證明 39 個識別字全部可編譯。
func probe() -> String:
	print("      TYPE_MAX = %d" % TYPE_MAX)
	var allowed_ids: Array = [
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_RECT2, TYPE_RECT2I,
		TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_TRANSFORM2D,
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_PLANE, TYPE_QUATERNION,
		TYPE_AABB, TYPE_BASIS, TYPE_TRANSFORM3D, TYPE_PROJECTION,
		TYPE_COLOR, TYPE_STRING_NAME, TYPE_NODE_PATH,
		TYPE_DICTIONARY, TYPE_ARRAY,
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	]
	var rejected_ids: Array = [TYPE_RID, TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL]
	print("      allowed count = %d  -> %s" % [allowed_ids.size(), str(allowed_ids)])
	print("      rejected count = %d -> %s" % [rejected_ids.size(), str(rejected_ids)])
	print("      allowed+rejected = %d ; TYPE_MAX = %d ; equal = %s"
		% [allowed_ids.size() + rejected_ids.size(), TYPE_MAX,
		   str(allowed_ids.size() + rejected_ids.size() == TYPE_MAX)])
	return "PRE1-REACHED-END"
