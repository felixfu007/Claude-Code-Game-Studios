# 失敗案例存檔,不是可執行的正式檔案——證明「靜態方法命名為 tr() 會 parse error」。
class_name ShadowProbeLocFailed
extends RefCounted

static func tr(key: StringName) -> String:
	return String(TranslationServer.translate(key))
