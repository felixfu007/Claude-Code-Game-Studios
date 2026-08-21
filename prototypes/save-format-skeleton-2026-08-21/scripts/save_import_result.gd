class_name SaveImportResult
extends RefCounted
# 語意驗證器的回傳型別。
# (c) 類發現:ADR-0003 機制六寫「validator: Callable(Dictionary) -> ImportResult」,
# 而 ImportResult 的欄位從未在任何一份 ADR 定義過(ADR-0002 只出現名字)。
# 本骨架自行定案為 ok + errors,並刻意改名 SaveImportResult 以免與未來 ADR-0002
# 真正定義的 ImportResult 撞名。

var ok: bool = true
var errors: PackedStringArray = PackedStringArray()

func add(msg: String) -> void:
	ok = false
	errors.append(msg)

func first_error() -> String:
	if errors.size() == 0:
		return ""
	return errors[0]
