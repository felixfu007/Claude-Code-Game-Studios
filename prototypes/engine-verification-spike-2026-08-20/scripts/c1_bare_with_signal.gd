# ADR-0005 機制八在 @abstract 類別內同時宣告 signal,且有多個 @abstract func。
# 這是 MouseReclaimPolicy 的實際形狀。
@abstract
class_name SpikeBareWithSignal extends RefCounted

signal reset_triggered(trigger: int)

@abstract
func evaluate(current_mouse_position: Vector2) -> bool

@abstract
func diagnostic_seed_position() -> Vector2
