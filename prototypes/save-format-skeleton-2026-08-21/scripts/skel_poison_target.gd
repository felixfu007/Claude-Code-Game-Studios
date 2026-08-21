class_name SkelPoisonTarget
extends RefCounted
# 毒藥向量的可觀測受害者(沿用探針 G 的 GProbeTarget 作法)。
# 跨行程測試(F)要問的是:存進檔案的 Signal / ObjectID / RID,
# 在「新行程」裡指向什麼。

signal pinged(v: int)

var ping_count: int = 0
var marker: int = 987654321

func _init() -> void:
	pinged.connect(_on_pinged)

func _on_pinged(_v: int) -> void:
	ping_count += 1

func noop(_x: int) -> void:
	pass
