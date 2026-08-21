extends RefCounted
# X-4(隔離):兩個未查證的型別標註形狀。骨架的 save_writer/save_reader 用到其中一個,
# 若不成立會整檔 parse error。隔離量,編譯失敗只損失這一格。
#   (i)  內部類別的欄位型別標註參照「另一個 class_name」的 enum
#   (ii) 區域變數型別標註參照「另一個 class_name」的內部類別

class Holder extends RefCounted:
	var rejection: SaveFormat.PayloadRejection = SaveFormat.PayloadRejection.NONE

func probe() -> String:
	var h := Holder.new()
	print("      (i)  inner-class field typed as SaveFormat.PayloadRejection = %d" % h.rejection)
	var ser: SaveFormat.SerializeResult = SaveFormat.serialize_block({"a": 1})
	print("      (ii) local typed as SaveFormat.SerializeResult -> buffer size %d, ok=%s"
		% [ser.buffer.size(), str(ser.ok())])
	return "X4-REACHED-END"
