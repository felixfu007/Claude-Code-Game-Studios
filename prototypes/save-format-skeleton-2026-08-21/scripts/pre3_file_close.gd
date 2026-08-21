extends RefCounted
# PRE-3:驗證 A 要求「寫進 user://、關掉檔案、再讀回來」。
# FileAccess.close() 的存在性與 store_buffer/get_buffer 的 arity 若有誤,
# 會讓驗證 A 那一整檔 parse error。隔離先測。
func probe() -> String:
	print("      user data dir = %s" % OS.get_user_data_dir())
	var path := "user://pre3.bin"
	var payload := PackedByteArray([1, 2, 3, 250, 0, 77])
	var fw := FileAccess.open(path, FileAccess.WRITE)
	if fw == null:
		print("      OPEN-WRITE FAILED err=%d" % FileAccess.get_open_error())
		return "PRE3-REACHED-END(open-write-failed)"
	fw.store_buffer(payload)
	fw.close()
	print("      wrote %d bytes, is_open_after_close = %s" % [payload.size(), str(fw.is_open())])
	var fr := FileAccess.open(path, FileAccess.READ)
	if fr == null:
		print("      OPEN-READ FAILED err=%d" % FileAccess.get_open_error())
		return "PRE3-REACHED-END(open-read-failed)"
	var n := fr.get_length()
	var back := fr.get_buffer(n)
	fr.close()
	print("      read back %d bytes, identical = %s" % [back.size(), str(back == payload)])
	print("      file_exists = %s" % str(FileAccess.file_exists(path)))
	return "PRE3-REACHED-END"
