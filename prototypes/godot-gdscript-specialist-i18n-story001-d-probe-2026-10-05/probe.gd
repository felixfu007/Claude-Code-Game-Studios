# Story 001 (localization-infrastructure), D 節實機驗證探針。
#
# 不重跑 godot-specialist 已完成的 Q1 探針（CSV 匯入器行為、project.godot 鍵名）——
# 那些材料直接引用，見 prototypes/godot-specialist-i18n-locale-probe-2026-09-29/README.md。
#
# 本探針只回答工作單 D 節明文交辦、尚未有人測過的兩題：
#   1. tr() 對階層式 dot-notation key（例如 "battle.hud.status_format"）能不能正確查找，
#      會不會因為句點字元被截斷或誤判成巢狀路徑。
#   2. 對一個「完全不存在於任何已註冊語系」的 key 呼叫 tr()，預設回傳值是什麼。
#
# 從正式專案根目錄啟動（--path .），project.godot 的 [internationalization] 區塊
# 會在引擎啟動時自動載入 assets/data/locales/strings.zh_TW.translation 並設 fallback=zh_TW，
# 不需要本腳本自己 load()/add_translation() —— 這樣量到的才是 production 實際會發生的狀況，
# 不是探針自己組出來的替身。
#
# 執行方式：
#   <godot> --headless --path . -s prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/probe.gd
extends SceneTree


func _init() -> void:
	print("=== Story 001 D 節探針 ===")

	print("Q_setup: TranslationServer.get_locale() = ", TranslationServer.get_locale())
	print("Q_setup: TranslationServer.get_loaded_locales() = ", TranslationServer.get_loaded_locales())
	print("Q_setup: OS.is_debug_build() = ", OS.is_debug_build())

	# --- 題目一:既有 CSV 裡本來就有的 dot-notation key,直接查 ---------------
	var dot_key_1: StringName = &"battle.hud.status_format"
	var dot_result_1: String = tr(dot_key_1)
	print("Q1a: tr(&\"battle.hud.status_format\") = [", dot_result_1, "]")
	print(
		"Q1a: matches CSV value verbatim? = ",
		dot_result_1 == "第 %d 回合．%s"
	)

	var dot_key_2: StringName = &"battle.menu.leave_confirm_title"
	var dot_result_2: String = tr(dot_key_2)
	print("Q1b: tr(&\"battle.menu.leave_confirm_title\") = [", dot_result_2, "]")
	print("Q1b: matches CSV value verbatim? = ", dot_result_2 == "離開遊戲?")

	# --- 題目二:完全不存在的 key(含句點,排除「是句點導致查找失敗」這個混淆變因)---
	var missing_key: StringName = &"this.key.does.not.exist.anywhere"
	var missing_result: String = tr(missing_key)
	print("Q2: tr(&\"this.key.does.not.exist.anywhere\") = [", missing_result, "]")
	print(
		"Q2: result == key string itself (bare-key echo)? = ",
		missing_result == String(missing_key)
	)
	print("Q2: result.is_empty() = ", missing_result.is_empty())

	# --- 題目三:不含句點的 key 也查一次,確認句點不是唯一變因 -------------------
	var missing_key_no_dot: StringName = &"nonexistentkeynodot"
	var missing_result_no_dot: String = tr(missing_key_no_dot)
	print("Q3: tr(&\"nonexistentkeynodot\") = [", missing_result_no_dot, "]")
	print(
		"Q3: result == key string itself (bare-key echo)? = ",
		missing_result_no_dot == String(missing_key_no_dot)
	)

	# --- 題目四:TranslationServer 有沒有獨立於 Object.tr() 的對等方法 ------------
	# 動機:若要寫一個名叫 tr() 的靜態包裝方法，而 Loc extends RefCounted（繼承自
	# Object，Object 本身就定義了 tr()），同名覆寫會在方法內部呼叫 tr(key) 時遞迴
	# 呼叫自己，而不是呼叫到真正的引擎翻譯邏輯。查 TranslationServer 是否有獨立方法
	# 可以繞開這個遮蔽陷阱，而不是先寫了才發現炸裂。
	print("Q4: TranslationServer.has_method(\"translate\") = ", TranslationServer.has_method("translate"))
	if TranslationServer.has_method("translate"):
		var via_translation_server: Variant = TranslationServer.call("translate", dot_key_1)
		print("Q4: TranslationServer.translate(&\"battle.hud.status_format\") = [", via_translation_server, "]")
		print("Q4: typeof result = ", typeof(via_translation_server))

	# --- 題目五:缺字情境下，TranslationServer.translate() 是否與 tr() 行為一致 ----
	# 動機:Loc.tr() 實作選擇呼叫 TranslationServer.translate()（避開題目四發現的
	# 同名覆寫遞迴陷阱），必須確認它對缺字 key 的行為與 Object.tr() 一致（原樣回傳
	# key），而不是另一套行為（例如回傳空字串），否則題目二/三量到的結論套用錯方法。
	var missing_via_ts: Variant = TranslationServer.call("translate", missing_key)
	print("Q5: TranslationServer.translate(&\"this.key.does.not.exist.anywhere\") = [", missing_via_ts, "]")
	print("Q5: result == key string itself (bare-key echo)? = ", String(missing_via_ts) == String(missing_key))

	print("=== 探針結束 ===")
	quit(0)
