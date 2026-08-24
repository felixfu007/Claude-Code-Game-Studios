class_name SaveEnvelope extends RefCounted
# X-CYCLE probe, file B of the mutual-reference pair under test (ADR-0003 M4).
#
# 對應 draft-v2.md 的 SaveEnvelope:ShapeCheckResult.rejection 的型別標註引用
# SaveFormat.ReadRejection(另一個 class_name 腳本的 enum),check_shape() 內部
# 也直接引用 SaveFormat.HASH_LEN(常數)——這是造成 (b) 雙向引用的另一半。
# 探針 x4(save-format-skeleton-2026-08-21)只測過「腳本 A 引用腳本 B 的
# enum/內部類別」這一個方向;本檔加上 save_format.gd 才構成雙向。

class ShapeCheckResult extends RefCounted:
	var rejection: SaveFormat.ReadRejection = SaveFormat.ReadRejection.NONE
	var detail: String = ""
	func ok() -> bool:
		return rejection == SaveFormat.ReadRejection.NONE

static func check_shape(envelope: Dictionary) -> ShapeCheckResult:
	var res := ShapeCheckResult.new()
	if not envelope.has("ruleset_version"):
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "信封缺少鍵 ruleset_version"
		return res
	if typeof(envelope["ruleset_version"]) != TYPE_INT:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "ruleset_version 應為 int"
		return res
	var hash_val: Variant = envelope.get("top_level_hash", PackedByteArray())
	if typeof(hash_val) != TYPE_PACKED_BYTE_ARRAY or (hash_val as PackedByteArray).size() != SaveFormat.HASH_LEN:
		res.rejection = SaveFormat.ReadRejection.DATA_CORRUPTED
		res.detail = "top_level_hash 型別或長度不符"
		return res
	return res
