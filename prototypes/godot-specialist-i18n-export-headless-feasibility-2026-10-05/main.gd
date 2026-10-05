extends Node

func _ready() -> void:
	print("FEASIBILITY OS.get_locale() = ", OS.get_locale())
	print("FEASIBILITY OS.get_locale_language() = ", OS.get_locale_language())
	print("FEASIBILITY TranslationServer.get_locale() = ", TranslationServer.get_locale())
	print("FEASIBILITY tr(test_key) = ", tr("test_key"))
	print("FEASIBILITY DONE")
	get_tree().quit()
