# CardConfirmPanel._apply_arrow_glyph_fallback() 的純邏輯測試 —— Story 002 補強
# （2026-10-06,協調者 review 抓到的連帶缺陷,見 card_confirm_panel.gd 該函式群組的
# doc comment)。
#
# 背景:ARROW_GLYPH 遷移成 key 之後,[method Loc.localize] 在 release 建置查無翻譯時
# 會回傳空字串（`src/core/i18n/loc.gd` 的既有設計,`_MISSING_KEY_RELEASE_VALUE`）。
# [method CardConfirmPanel.format_strength_arrow] / [method
# CardConfirmPanel.text_uses_required_arrow_format] 兩者都透過
# [method CardConfirmPanel._resolved_arrow_glyph] 取得分隔符,而後者內部呼叫的
# [method CardConfirmPanel._apply_arrow_glyph_fallback] 就是本檔要證的那段退化邏輯。
#
# 🔴 拆成接受明確字串參數的純函式,不在內部直接呼叫 Loc.localize() 的理由(同
# card_confirm_panel.gd 該函式自己的 doc comment)：本機 headless 測試環境下
# OS.is_debug_build() 恆為 true、assets/data/locales/strings.csv 又真的登記了
# battle.card_confirm.arrow_glyph 這個 key——兩個條件疊起來,Loc.localize(ARROW_GLYPH)
# 在這台機器上的任何測試執行環境裡都不可能真的回傳空字串。不拆出這個純函式的話,
# release 分支永遠測不到,這正是 .claude/docs/coding-standards.md「What NOT to
# Automate」與 loc.gd 自己 _missing_key_fallback() 已經示範過的同一個解法。
extends GdUnitTestSuite


func test_apply_arrow_glyph_fallback_empty_input_returns_single_space() -> void:
	# Arrange — 模擬 release 建置下 Loc.localize(ARROW_GLYPH) 查無翻譯的情況
	var raw_glyph: String = ""

	# Act
	var result: String = CardConfirmPanel._apply_arrow_glyph_fallback(raw_glyph)

	# Assert — 退回單一半形空格,不是空字串(否則兩個數字會無分隔符地黏在一起)
	assert_str(result).append_failure_message(
		"空字串輸入應該退回一個半形空格作為保底分隔符，實得「%s」" % result
	).is_equal(" ")


func test_apply_arrow_glyph_fallback_nonempty_input_passes_through_unchanged() -> void:
	# Arrange — 正常情況:CSV 真的登記了翻譯內容
	var raw_glyph: String = " → "

	# Act
	var result: String = CardConfirmPanel._apply_arrow_glyph_fallback(raw_glyph)

	# Assert — 不觸發退化分支,原樣傳回(逐位元組相同,含前後空白)
	assert_str(result).append_failure_message(
		"非空字串輸入不應該被改寫，應該原樣傳回，實得「%s」" % result
	).is_equal(" → ")


# ---- 敏感度證明:兩條測試互為對照組 -----------------------------------------------
#
# 若實作把 if raw_glyph.is_empty() 的判斷寫反(例如永遠回傳 raw_glyph,或永遠回傳
# " "),上面兩條測試其中一條會先紅——這就是靜態純函式在沒有可注入依賴時的標準測法
# （test-standards.md「類 A」的等效但可行寫法：純函式本身雖無法用間諜子類別覆寫，
# 但可以直接餵入會讓分支「應真」與「應假」的兩種輸入，分別斷言)。
func test_sensitivity_proof_empty_and_nonempty_branches_are_distinguishable() -> void:
	# Arrange / Act
	var empty_result: String = CardConfirmPanel._apply_arrow_glyph_fallback("")
	var nonempty_result: String = CardConfirmPanel._apply_arrow_glyph_fallback(" → ")

	# Assert — 兩個分支的輸出必須不同,否則代表判斷式失去鑑別力(例如永遠走同一分支)
	assert_str(empty_result).append_failure_message(
		"空字串分支與非空字串分支的輸出必須不同——若實作永遠回傳同一個值，" +
		"這條測試應該先抓到"
	).is_not_equal(nonempty_result)
