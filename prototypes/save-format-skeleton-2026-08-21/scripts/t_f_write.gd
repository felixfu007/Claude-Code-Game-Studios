extends RefCounted
# 驗證 F(第一半,行程 1):刻意把毒藥寫進真實檔案,給行程 2 讀。
# 這一項關掉探針 F 未查證 #5 / 探針 G 未查證 #1:
# 存檔裡的 Signal ObjectID / EncodedObjectAsID 在「新行程」裡變成什麼?

const PATH_WITH_OBJECTS: String = "user://f_with_objects.bin"
const PATH_PLAIN: String = "user://f_plain.bin"
const PATH_IDS: String = "user://f_ids.txt"

func t_f_write() -> String:
	var target := SkelPoisonTarget.new()
	var oid: int = target.get_instance_id()
	print("      行程 1 的 SkelPoisonTarget instance_id = %d" % oid)
	print("      marker 欄位值 = %d" % target.marker)

	var poison: Dictionary = {
		"marker_str": "F-CROSS-PROCESS-MARKER",
		"obj": target,
		"sig": target.pinged,
		"cb": target.noop,
	}

	var b_wo: PackedByteArray = var_to_bytes_with_objects(poison)
	var b_pl: PackedByteArray = var_to_bytes(poison)
	print("      var_to_bytes_with_objects -> %d bytes" % b_wo.size())
	print("      var_to_bytes (plain)      -> %d bytes" % b_pl.size())

	var e1 := SkelFixture.write_file(PATH_WITH_OBJECTS, b_wo)
	var e2 := SkelFixture.write_file(PATH_PLAIN, b_pl)
	if e1 != "" or e2 != "":
		print("      write error: %s %s" % [e1, e2])
		return "F-WRITE-ABORT-FILE"

	var f := FileAccess.open(PATH_IDS, FileAccess.WRITE)
	if f == null:
		return "F-WRITE-ABORT-IDS"
	f.store_line(str(oid))
	f.store_line(str(target.marker))
	f.close()
	print("      sidecar 寫入 %s(第一行 = instance_id)" % PATH_IDS)

	# 同行程對照:證明這些位元組在「本行程」是活的(探針 F/G 已測,此處只是基準線)
	var back_wo = bytes_to_var_with_objects(b_wo)
	print("      同行程 with_objects 解碼:typeof=%d" % typeof(back_wo))
	if back_wo is Dictionary:
		var d: Dictionary = back_wo
		print("        obj typeof=%d  sig typeof=%d  cb typeof=%d"
			% [typeof(d.get("obj")), typeof(d.get("sig")), typeof(d.get("cb"))])
		var o = d.get("obj")
		if o is SkelPoisonTarget:
			print("        obj 是 SkelPoisonTarget,marker=%d instance_id=%d(來源 %d)"
				% [(o as SkelPoisonTarget).marker, (o as Object).get_instance_id(), oid])
	var back_pl = bytes_to_var(b_pl)
	print("      同行程 plain 解碼:typeof=%d" % typeof(back_pl))
	if back_pl is Dictionary:
		var d2: Dictionary = back_pl
		print("        obj typeof=%d class=%s" % [typeof(d2.get("obj")),
			str((d2.get("obj") as Object).get_class()) if d2.get("obj") is Object else "n/a"])
	print("      (target 在本函式結束後會被回收 —— 這正是行程 2 要問的前提)")
	return "F-WRITE-REACHED-END"
