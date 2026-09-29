extends SceneTree

func _init() -> void:
	print("################################################################")
	print("# Q1: ProjectSettings internationalization/* -- real property list")
	print("################################################################")
	var props: Array = ProjectSettings.get_property_list()
	var found_any := false
	for p in props:
		var pname: String = p.get("name", "")
		if pname.begins_with("internationalization"):
			found_any = true
			print("PROP name=", pname,
				" type=", p.get("type"),
				" hint=", p.get("hint"),
				" hint_string=", p.get("hint_string"),
				" usage=", p.get("usage"))
			print("  get_setting() -> ", ProjectSettings.get_setting(pname))
	if not found_any:
		print("NO internationalization/* keys appear in get_property_list() at all")

	print("")
	print("=== Q1b: has_setting probe for candidate keys ===")
	var candidates: Array = [
		"internationalization/locale/translations",
		"internationalization/locale/translation_remaps",
		"internationalization/locale/fallback",
		"internationalization/locale/locale_filter_mode",
		"internationalization/locale/locale_filter",
		"internationalization/locale/include_text_server_data",
		"internationalization/locale/test",
		"internationalization/rendering/root_node_layout_direction",
		"internationalization/rendering/root_node_auto_translate",
	]
	for c in candidates:
		var has: bool = ProjectSettings.has_setting(c)
		var val = ProjectSettings.get_setting(c, "UNSET_DEFAULT_SENTINEL")
		print(c, " | has_setting=", has, " | get_setting(default=SENTINEL)=", val)

	print("")
	print("################################################################")
	print("# ClassDB introspection -- real API surface, not guessed from memory")
	print("################################################################")
	print("--- TranslationServer methods ---")
	var ts_methods: Array = ClassDB.class_get_method_list("TranslationServer", true)
	for m in ts_methods:
		print("TS METHOD ", m.get("name"))

	print("--- Translation resource class properties ---")
	var tr_props: Array = ClassDB.class_get_property_list("Translation", true)
	for p in tr_props:
		print("TRANSLATION PROP ", p.get("name"), " type=", p.get("type"))

	print("--- Translation resource class methods ---")
	var tr_methods: Array = ClassDB.class_get_method_list("Translation", true)
	for m in tr_methods:
		print("TRANSLATION METHOD ", m.get("name"))

	print("")
	print("################################################################")
	print("# Q2: zh_TW vs zh_Hant")
	print("################################################################")

	print("--- Q2b: TranslationServer.set_locale() round-trip / normalization ---")
	print("BEFORE any set_locale, get_locale() = ", TranslationServer.get_locale())
	TranslationServer.set_locale("zh_TW")
	print("after set_locale(zh_TW)        -> get_locale() = ", TranslationServer.get_locale())
	TranslationServer.set_locale("zh_Hant")
	print("after set_locale(zh_Hant)      -> get_locale() = ", TranslationServer.get_locale())
	TranslationServer.set_locale("zh_TW")
	print("after set_locale(zh_TW) again  -> get_locale() = ", TranslationServer.get_locale())
	TranslationServer.set_locale("zh_Hant_TW")
	print("after set_locale(zh_Hant_TW)   -> get_locale() = ", TranslationServer.get_locale())
	TranslationServer.set_locale("zh_HANT_tw")
	print("after set_locale(zh_HANT_tw) mixed case -> get_locale() = ", TranslationServer.get_locale())

	print("")
	print("--- Q2c: TranslationServer.standardize_locale() ---")
	if TranslationServer.has_method("standardize_locale"):
		print("standardize_locale(zh_TW)      = ", TranslationServer.standardize_locale("zh_TW"))
		print("standardize_locale(zh_Hant)    = ", TranslationServer.standardize_locale("zh_Hant"))
		print("standardize_locale(zh_Hant_TW) = ", TranslationServer.standardize_locale("zh_Hant_TW"))
		print("standardize_locale(zh_HANT_tw) = ", TranslationServer.standardize_locale("zh_HANT_tw"))
		print("standardize_locale(zh)         = ", TranslationServer.standardize_locale("zh"))
		print("standardize_locale(zh_CN)      = ", TranslationServer.standardize_locale("zh_CN"))
		print("standardize_locale(zh_Hans)    = ", TranslationServer.standardize_locale("zh_Hans"))
	else:
		print("standardize_locale method NOT FOUND on TranslationServer (see ClassDB list above)")

	print("")
	print("--- Q2d: TranslationServer.compare_locales() (match/fallback scoring) ---")
	if TranslationServer.has_method("compare_locales"):
		print("compare_locales(zh_TW,zh_Hant)   = ", TranslationServer.compare_locales("zh_TW", "zh_Hant"))
		print("compare_locales(zh_TW,zh_TW)     = ", TranslationServer.compare_locales("zh_TW", "zh_TW"))
		print("compare_locales(zh_TW,zh_CN)     = ", TranslationServer.compare_locales("zh_TW", "zh_CN"))
		print("compare_locales(zh_Hant,zh_Hans) = ", TranslationServer.compare_locales("zh_Hant", "zh_Hans"))
		print("compare_locales(zh_Hant,zh_TW)   = ", TranslationServer.compare_locales("zh_Hant", "zh_TW"))
	else:
		print("compare_locales method NOT FOUND on TranslationServer (see ClassDB list above)")

	print("")
	print("--- Q2e: TranslationServer.get_locale_name() ---")
	if TranslationServer.has_method("get_locale_name"):
		print("get_locale_name(zh_TW)   = ", TranslationServer.get_locale_name("zh_TW"))
		print("get_locale_name(zh_Hant) = ", TranslationServer.get_locale_name("zh_Hant"))
	else:
		print("get_locale_name method NOT FOUND on TranslationServer")

	print("")
	print("--- Q2f: engine known language/script/country lists ---")
	if TranslationServer.has_method("get_all_languages"):
		var langs: PackedStringArray = TranslationServer.get_all_languages()
		print("get_all_languages contains zh? ", langs.has("zh"), " total=", langs.size())
	else:
		print("get_all_languages NOT FOUND")
	if TranslationServer.has_method("get_all_scripts"):
		var scripts: PackedStringArray = TranslationServer.get_all_scripts()
		print("get_all_scripts contains Hant? ", scripts.has("Hant"), " contains Hans? ", scripts.has("Hans"), " total=", scripts.size())
	else:
		print("get_all_scripts NOT FOUND")
	if TranslationServer.has_method("get_all_countries"):
		var countries: PackedStringArray = TranslationServer.get_all_countries()
		print("get_all_countries contains TW? ", countries.has("TW"), " total=", countries.size())
	else:
		print("get_all_countries NOT FOUND")

	print("")
	print("################################################################")
	print("# Q2g: REAL CSV-IMPORTED Translation resources -- locale field + fallback")
	print("# loads the actual .translation files the import pipeline produced")
	print("# from test_translations.csv, header row: keys,zh_TW,zh_Hant,en")
	print("################################################################")

	var res_zh_tw = load("res://test_translations.zh_TW.translation")
	var res_zh_hant = load("res://test_translations.zh_Hant.translation")
	var res_en = load("res://test_translations.en.translation")

	print("loaded zh_TW.translation   -> ", res_zh_tw, " class=", (res_zh_tw.get_class() if res_zh_tw else "NULL"))
	print("loaded zh_Hant.translation -> ", res_zh_hant, " class=", (res_zh_hant.get_class() if res_zh_hant else "NULL"))
	print("loaded en.translation      -> ", res_en, " class=", (res_en.get_class() if res_en else "NULL"))

	if res_zh_tw:
		print("res_zh_tw.locale (verbatim from CSV header zh_TW) = ", res_zh_tw.locale)
		print("res_zh_tw.get_message(test_key) = ", res_zh_tw.get_message("test_key"))
	if res_zh_hant:
		print("res_zh_hant.locale (verbatim from CSV header zh_Hant) = ", res_zh_hant.locale)
		print("res_zh_hant.get_message(test_key) = ", res_zh_hant.get_message("test_key"))

	print("")
	print("--- Case A: ONLY zh_TW translation registered, active locale forced to zh_Hant ---")
	TranslationServer.clear()
	TranslationServer.add_translation(res_zh_tw)
	TranslationServer.set_locale("zh_Hant")
	print("get_locale() = ", TranslationServer.get_locale())
	print("tr(test_key) = [", tr("test_key"), "]  -- empty or literal test_key echoed back means FALLBACK FAILED; seeing the zh_TW string means FALLBACK SUCCEEDED")

	print("")
	print("--- Case B: ONLY zh_Hant translation registered, active locale forced to zh_TW ---")
	TranslationServer.clear()
	TranslationServer.add_translation(res_zh_hant)
	TranslationServer.set_locale("zh_TW")
	print("get_locale() = ", TranslationServer.get_locale())
	print("tr(test_key) = [", tr("test_key"), "]  -- empty or literal test_key echoed back means FALLBACK FAILED; seeing the zh_Hant string means FALLBACK SUCCEEDED")

	print("")
	print("--- Case C control: zh_TW registered, locale = zh_TW exact match ---")
	TranslationServer.clear()
	TranslationServer.add_translation(res_zh_tw)
	TranslationServer.set_locale("zh_TW")
	print("get_locale() = ", TranslationServer.get_locale())
	print("tr(test_key) = [", tr("test_key"), "]  -- sanity check, tr plumbing works at all")

	print("")
	print("--- Case D control: zh_Hant registered, locale = zh_Hant exact match ---")
	TranslationServer.clear()
	TranslationServer.add_translation(res_zh_hant)
	TranslationServer.set_locale("zh_Hant")
	print("get_locale() = ", TranslationServer.get_locale())
	print("tr(test_key) = [", tr("test_key"), "]  -- sanity check, tr plumbing works at all")

	print("")
	print("--- Q2h: get_loaded_locales() with BOTH zh_TW and zh_Hant registered ---")
	TranslationServer.clear()
	TranslationServer.add_translation(res_zh_tw)
	TranslationServer.add_translation(res_zh_hant)
	TranslationServer.add_translation(res_en)
	print("get_loaded_locales() = ", TranslationServer.get_loaded_locales())

	print("")
	print("--- Case E: both zh_TW and zh_Hant registered, active locale = zh_Hant_TW ---")
	TranslationServer.set_locale("zh_Hant_TW")
	print("get_locale() = ", TranslationServer.get_locale())
	print("tr(test_key) = [", tr("test_key"), "]  -- which one wins when both loaded and locale is the combined form?")

	print("")
	print("=== DONE ===")
	quit()
