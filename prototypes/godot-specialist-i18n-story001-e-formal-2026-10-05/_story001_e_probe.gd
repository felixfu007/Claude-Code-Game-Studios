## 🔴 TEMPORARY — story-001 E 節正式量測專用探針，用完即刪，不是production程式碼。
## 建立/刪除時機記錄於 prototypes/godot-specialist-i18n-story001-e-formal-2026-10-05/README.md。
## 暫時頂替 run/main_scene，只為了讓匯出建置能在開機時立刻呼叫真正的 Loc.localize()
## 並印出四項 locale 量測值，然後自行 quit()。不引入任何新的查找邏輯 —— 呼叫的是
## production 的 Loc 類別本身（src/core/i18n/loc.gd），不是重新實作。
extends Node

func _ready() -> void:
	print("E_SECTION_PROBE OS.get_locale() = ", OS.get_locale())
	print("E_SECTION_PROBE OS.get_locale_language() = ", OS.get_locale_language())
	print("E_SECTION_PROBE TranslationServer.get_locale() = ", TranslationServer.get_locale())
	print("E_SECTION_PROBE Loc.localize(battle.hud.status_format) = ", Loc.localize("battle.hud.status_format"))
	print("E_SECTION_PROBE DONE")
	get_tree().quit()
