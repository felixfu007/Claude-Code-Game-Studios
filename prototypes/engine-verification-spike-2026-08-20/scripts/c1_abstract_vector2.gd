# C1-Vector2 —— 這一項最重要:ADR-0005 的 R4-2 修法(BLOCKING)就是把
# diagnostic_seed_position() 改標 @abstract 並回傳 Vector2。若此形式不合法,R4-2 的修法不成立。
@abstract
class_name SpikeAbstractVector2 extends RefCounted

@abstract
func diagnostic_seed_position() -> Vector2:
	pass
