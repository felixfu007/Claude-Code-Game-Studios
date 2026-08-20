# 最關鍵的一檔:ADR-0005 的 R4-2(BLOCKING 修法)就是把
# diagnostic_seed_position() 改標 @abstract 並回傳 Vector2。
@abstract
class_name SpikeBareVector2 extends RefCounted

@abstract
func diagnostic_seed_position() -> Vector2
