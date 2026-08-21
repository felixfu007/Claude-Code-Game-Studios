class_name Pre4Outer
extends RefCounted
# PRE-4:規格逐字要求 `class SerializeResult extends RefCounted:` 內部類別,
# 且欄位 `rejection: PayloadRejection = PayloadRejection.NONE`
# —— 即「內部類別的型別化欄位參照外層類別的 enum」。
# GDScript 的內部類別能否解析外層作用域的 enum,是本專案未查證的形狀。

enum PayloadRejection { NONE, FORBIDDEN_TYPE, DEPTH_EXCEEDED }

const SOME_CONST: int = 4242

class SerializeResult extends RefCounted:
	var buffer: PackedByteArray = PackedByteArray()
	var rejection: PayloadRejection = PayloadRejection.NONE
	var offending_path: String = ""
	var borrowed_const: int = SOME_CONST

static func make() -> SerializeResult:
	var r := SerializeResult.new()
	r.rejection = PayloadRejection.DEPTH_EXCEEDED
	r.offending_path = "payload[\"x\"]"
	return r

func probe() -> String:
	var a := SerializeResult.new()
	print("      default rejection = %d (expect NONE=%d), borrowed outer const = %d"
		% [a.rejection, PayloadRejection.NONE, a.borrowed_const])
	var b := make()
	print("      set rejection = %d (expect DEPTH_EXCEEDED=%d), path = %s"
		% [b.rejection, PayloadRejection.DEPTH_EXCEEDED, b.offending_path])
	print("      typed field assignment of wrong enum family is a separate question (not tested here)")
	return "PRE4-REACHED-END"
