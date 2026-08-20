# A1-(a) ADR-0002 的 _death_marks 形式:Dictionary[enum, int],**非巢狀**。
extends RefCounted

static func build() -> Dictionary:
	var d: Dictionary[AffinityTypes.Character, int] = {}
	d[AffinityTypes.Character.CHARACTER_1] = 7
	return d
