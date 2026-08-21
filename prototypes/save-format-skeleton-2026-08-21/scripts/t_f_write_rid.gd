extends RefCounted
# 驗證 F 的 RID 分支 —— 刻意獨立一檔:PhysicsServer2D 的方法名是
# 探針 G RUN-A 整檔 Parse Error 的成因家族(body_free 不存在)。
# body_create() 已由探針 G 實測可用,但仍不與 t_f_write 同居。
# 刻意不釋放該 RID(理由同探針 G:猜釋放方法名等於再賭一次整檔編譯失敗)。

const PATH_RID: String = "user://f_rid.bin"
const PATH_RID_IDS: String = "user://f_rid.txt"

func t_f_write_rid() -> String:
	var rid: RID = PhysicsServer2D.body_create()
	print("      行程 1 的 RID: is_valid=%s get_id=%d" % [str(rid.is_valid()), rid.get_id()])
	var payload: Dictionary = {"marker_str": "F-RID-MARKER", "rid": rid, "empty_rid": RID()}
	var b: PackedByteArray = var_to_bytes(payload)
	print("      var_to_bytes -> %d bytes" % b.size())
	var e := SkelFixture.write_file(PATH_RID, b)
	if e != "":
		print("      %s" % e)
		return "F-RID-ABORT"
	var f := FileAccess.open(PATH_RID_IDS, FileAccess.WRITE)
	if f == null:
		return "F-RID-ABORT-IDS"
	f.store_line(str(rid.get_id()))
	f.close()
	print("      sidecar 寫入 %s" % PATH_RID_IDS)
	return "F-WRITE-RID-REACHED-END"
