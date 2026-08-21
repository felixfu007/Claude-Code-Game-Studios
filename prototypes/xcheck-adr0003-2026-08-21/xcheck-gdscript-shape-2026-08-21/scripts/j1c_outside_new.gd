extends RefCounted
# J1c(隔離)—— 從外部檔案直接構造內部類別:JSaveFormat.SerializeResult.new()
#   以及不經 class_name、以 preload 取得內部類別。
func probe() -> String:
	var fresh: JSaveFormat.SerializeResult = JSaveFormat.SerializeResult.new()
	print("      J1c: 外部 .new() 成功 —— rejection 預設值=%d  buffer.size()=%d  offending_path=[%s]" % [fresh.rejection, fresh.buffer.size(), fresh.offending_path])
	print("      J1c: PayloadRejection.keys()=%s" % str(JSaveFormat.PayloadRejection.keys()))
	return "J1c-REACHED-END"
