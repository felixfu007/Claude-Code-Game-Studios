class_name GameSettingsProbe
extends RefCounted

static var _egm_enabled: bool = false

static func is_egm_enabled() -> bool:
	return _egm_enabled

static func set_egm_enabled(value: bool) -> void:
	_egm_enabled = value

static func reset_for_test() -> void:
	_egm_enabled = false
