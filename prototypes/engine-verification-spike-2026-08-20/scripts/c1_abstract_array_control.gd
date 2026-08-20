# C1 對照組 —— 這是 docs/engine-reference/godot/current-best-practices.md 第 41-49 行
# 唯一有範例的形式(Array[T] 回傳型別)。若連這一檔都失敗,問題出在 spike 本身而非 @abstract。
@abstract
class_name SpikeAbstractArray extends RefCounted

@abstract
func get_items() -> Array[AffinityRecord]:
	pass
