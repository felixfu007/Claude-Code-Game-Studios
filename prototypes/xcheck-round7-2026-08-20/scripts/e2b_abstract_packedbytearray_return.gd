@abstract
class_name SpikeBarePackedByteArray extends RefCounted
# ROUND7 Probe E — E2b。@abstract func 裸簽章 `-> PackedByteArray` 是否編譯。
# PackedByteArray 是本專案存檔系統(ADR-0003/0004)序列化路徑的主力型別,而
# 2026-08-20 spike 已測的 `Array[T]` 是型別化容器、不是打包陣列,兩者不等價,
# 不能用 Array[T] 的結果外推。獨立成檔,理由同 e1_abstract_variant_return.gd 檔頭。

@abstract
func get_bytes() -> PackedByteArray
