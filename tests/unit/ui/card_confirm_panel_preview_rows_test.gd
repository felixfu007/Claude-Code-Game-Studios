# Story 020d 第 3 項:確認面板「固定雙人合併後兩行」與「補血 回復：HP 前 → 後」。
# 檔案存取:無。直接 new 面板並餵資料(面板只負責格式化,數值由呼叫端從引擎取得)。
# 敏感度證明(常駐):mutant 讓補血預覽忽略 capped 旗標,capped 情境必變 false。
# 證明不了的:呼叫端(battle_screen)把引擎值餵進面板的接線,由整合測試/全套另行覆蓋,本檔不含。
extends GdUnitTestSuite


class _MutantIgnoresCapped extends CardConfirmPanel:
	func show_heal_preview(hp_before: int, hp_after: int, _capped: bool) -> void:
		super(hp_before, hp_after, false)


func _panel(script: GDScript = null) -> CardConfirmPanel:
	var panel: CardConfirmPanel = CardConfirmPanel.new()
	if script != null:
		panel.set_script(script)
	auto_free(panel)
	add_child(panel)
	var mods: Array[Dictionary] = []
	panel.show_temporary_modifier_confirmation("x", "flavor", "甲", 2, 1, 2, mods, 0, 0, null, false, false)
	return panel


func _scn_capped(script: GDScript = null) -> bool:
	var panel: CardConfirmPanel = _panel(script)
	panel.show_heal_preview(12, 20, true)
	return panel.diagnostic_effective_text() == Loc.localize(&"battle.card_confirm.heal_preview_capped_format") % [12, 20]


func test_heal_preview_uncapped_text() -> void:
	var panel: CardConfirmPanel = _panel()
	panel.show_heal_preview(12, 18, false)
	assert_str(panel.diagnostic_effective_text()).is_equal("回復：HP 12 → 18")


func test_heal_preview_capped_text() -> void:
	assert_bool(_scn_capped()).is_true()
	assert_str(_panel().diagnostic_effective_text()).is_not_equal("回復：HP 12 → 20")


func test_pair_effective_rows_one_line_per_person_in_order() -> void:
	var panel: CardConfirmPanel = _panel()
	var rows: Array[Dictionary] = [
		{"name": "甲", "atk": 7, "def": 4},
		{"name": "乙", "atk": 6, "def": 5},
	]
	panel.show_pair_effective_rows(rows)
	assert_str(panel.diagnostic_effective_text()).is_equal("甲　合併後：ATK 7／DEF 4\n乙　合併後：ATK 6／DEF 5")


func test_sensitivity_proof_capped_flag_mutant_is_caught() -> void:
	assert_bool(_scn_capped()).is_true()
	assert_bool(_scn_capped(_MutantIgnoresCapped)).append_failure_message("mutant 忽略 capped,應被抓出").is_false()
