# 通過案例存檔——證明改名 localize()/is_missing() 不與 Object/RefCounted 繼承鏈衝突。
class_name ShadowProbeLocPassed
extends RefCounted

static func localize(key: StringName) -> String:
	return String(TranslationServer.translate(key))

static func is_missing(key: StringName, result: String) -> bool:
	return result == String(key)
