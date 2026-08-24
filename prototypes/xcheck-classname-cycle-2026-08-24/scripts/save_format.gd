class_name SaveFormat extends RefCounted
# X-CYCLE probe, file A of the mutual-reference pair under test (ADR-0003 M4).
#
# 對應 draft-v2.md 的 SaveFormat:定義 ReadRejection、DeserializeResult,
# 並在 deserialize_manifest() 內呼叫 SaveEnvelope.check_shape() —— 這一行
# 是 M4(a) 裁決「誰呼叫 check_shape()」之後,實際落地的呼叫點。
# 型別閘門(SaveTypeGate)本身不是本探針的測試對象,故省略,只留下會造成
# 雙向 class_name 引用的最小骨架。

const HASH_LEN: int = 32

enum ReadRejection {
	NONE,
	DATA_CORRUPTED,
	VERSION_TOO_NEW,
}

class DeserializeResult extends RefCounted:
	var payload: Dictionary = {}
	var rejection: ReadRejection = ReadRejection.NONE
	var detail: String = ""
	func ok() -> bool:
		return rejection == ReadRejection.NONE

# 唯一的受測呼叫點:SaveFormat -> SaveEnvelope(另一個 class_name 腳本)。
static func deserialize_manifest(buffer: PackedByteArray) -> DeserializeResult:
	var res := DeserializeResult.new()
	var decoded: Variant = bytes_to_var(buffer)
	if not (decoded is Dictionary):
		res.rejection = ReadRejection.DATA_CORRUPTED
		res.detail = "decoded typeof=%d, not a Dictionary" % typeof(decoded)
		return res
	var shape: SaveEnvelope.ShapeCheckResult = SaveEnvelope.check_shape(decoded)
	if not shape.ok():
		res.rejection = ReadRejection.DATA_CORRUPTED
		res.detail = shape.detail
		return res
	res.payload = decoded
	return res
