# C1-signal —— ADR-0005 機制八在 @abstract 類別內同時宣告 signal。
# 第五輪把「@abstract 類別 + signal + 多種回傳型別的組合」標為印象-中、未查證。
@abstract
class_name SpikeAbstractWithSignal extends RefCounted

signal reset_triggered(trigger: int)

@abstract
func evaluate(current_mouse_position: Vector2) -> bool:
	pass

@abstract
func diagnostic_seed_position() -> Vector2:
	pass
