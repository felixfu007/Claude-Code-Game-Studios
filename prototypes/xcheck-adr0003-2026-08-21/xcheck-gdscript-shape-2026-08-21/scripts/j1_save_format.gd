# J1 —— ADR-0003 修訂草案 3b 的「逐字」形狀:
#   class_name 純靜態工具集 + 檔案層 enum + 內部類別(欄位型別為外層 enum)
#   + 靜態函式回傳該內部類別。
class_name JSaveFormat extends RefCounted

enum PayloadRejection { NONE, FORBIDDEN_TYPE }

class SerializeResult extends RefCounted:
	var buffer: PackedByteArray
	var rejection: PayloadRejection
	var offending_path: String

static func serialize_block(payload: Dictionary) -> SerializeResult:
	var r := SerializeResult.new()
	if payload.has("poison"):
		r.rejection = PayloadRejection.FORBIDDEN_TYPE
		r.offending_path = "poison"
		return r
	r.buffer = var_to_bytes(payload)
	return r
