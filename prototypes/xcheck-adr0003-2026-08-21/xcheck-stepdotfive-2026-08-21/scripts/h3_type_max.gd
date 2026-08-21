extends RefCounted
# H-3: TYPE_MAX 哨兵值是否存在、值為何。
# 存在性未經查證 → 隔離在本檔(編譯失敗本身就是答案)。
func probe() -> String:
	print("      H3: TYPE_MAX = %d" % TYPE_MAX)
	print("      H3: TYPE_OBJECT=%d TYPE_CALLABLE=%d TYPE_SIGNAL=%d TYPE_RID=%d" % [
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID])
	print("      H3: TYPE_NIL=%d TYPE_DICTIONARY=%d TYPE_ARRAY=%d TYPE_PACKED_BYTE_ARRAY=%d" % [
		TYPE_NIL, TYPE_DICTIONARY, TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY])
	return "H3-REACHED-END"
