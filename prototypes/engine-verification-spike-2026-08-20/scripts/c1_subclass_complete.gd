# ADR-0004 VR #6a 的對照組:完整實作全部抽象方法的具體子類別。
# 這一檔若編譯成功而 c1_subclass_incomplete.gd 失敗,就證明「漏實作」是**編譯期**錯誤。
class_name SpikeSubclassComplete extends SpikeBareWithSignal

func evaluate(_current_mouse_position: Vector2) -> bool:
	return true

func diagnostic_seed_position() -> Vector2:
	return Vector2.ZERO
