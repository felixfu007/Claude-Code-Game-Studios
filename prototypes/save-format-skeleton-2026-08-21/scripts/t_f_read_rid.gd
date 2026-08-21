extends RefCounted
# 驗證 F 的 RID 分支(第二半)。獨立一檔,理由同 t_f_write_rid.gd。
# 刻意「不」把還原出來的 RID 拿去對伺服器發指令(探針 G 未查證 #3,有崩潰風險)。

const PATH_RID: String = "user://f_rid.bin"
const PATH_RID_IDS: String = "user://f_rid.txt"

func t_f_read_rid() -> String:
	var f := FileAccess.open(PATH_RID_IDS, FileAccess.READ)
	if f == null:
		return "F-RID-READ-ABORT-NO-SIDECAR"
	var saved_id: int = int(f.get_line())
	f.close()
	print("      行程 1 存下的 RID id = %d" % saved_id)

	# 本行程自己配一個,看號碼從哪裡開始 —— 若與舊號碼重疊就是最壞情況
	var fresh: RID = PhysicsServer2D.body_create()
	print("      本行程新配的 RID id = %d(與舊號碼相同嗎 %s)"
		% [fresh.get_id(), str(fresh.get_id() == saved_id)])

	var b := SkelFixture.read_file(PATH_RID)
	var v = bytes_to_var(b)
	print("      bytes_to_var typeof=%d" % typeof(v))
	if not (v is Dictionary):
		return "F-RID-READ-REACHED-END(not-dict)"
	var d: Dictionary = v
	print("      marker_str = %s" % str(d.get("marker_str")))
	var r = d.get("rid")
	print("      rid typeof=%d is_RID=%s" % [typeof(r), str(r is RID)])
	if r is RID:
		var rr: RID = r
		print("        is_valid=%s get_id=%d(與行程 1 相同嗎 %s)"
			% [str(rr.is_valid()), rr.get_id(), str(rr.get_id() == saved_id)])
		print("        == 本行程剛配的那個 RID 嗎: %s" % str(rr == fresh))
		print("        (刻意不對伺服器使用它)")
	var er = d.get("empty_rid")
	if er is RID:
		print("      empty_rid: is_valid=%s get_id=%d" % [str((er as RID).is_valid()), (er as RID).get_id()])
	var res = SaveFormat.deserialize_block(b)
	print("      SaveFormat.deserialize_block -> ok=%s detail=%s path=%s"
		% [str(res.ok()), res.detail, res.offending_path])
	return "F-RID-READ-REACHED-END"
