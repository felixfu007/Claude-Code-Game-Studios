# 本地化字串遷移的端到端內容驗證 —— Story 002
# （production/epics/localization-infrastructure/story-002-migrate-existing-hardcoded-strings.md）。
#
# 🔴 本檔不是 loc_localize_test.gd 的覆蓋或重複。loc_localize_test.gd（story-001）測的是
# [Loc] 這支 API 本身（dot-notation 查找、缺字 fallback、debug/release 兩分支）；本檔測的是
# story-002 實際搬遷的「每一個 key，查出來的內容是不是跟遷移前的字面值逐字一樣」——
# 兩份檔案驗的是不同的事實，故意不合併。
#
# 涵蓋 `assets/data/locales/strings.csv` 目前全部 40 筆 key：
#   - 30 筆：story-002 第一批（battle_screen.gd 15、hand_bar.gd 4、card_confirm_panel.gd 5、
#     battle_menu.gd 6），含 2 筆 story-001 已先遷移的既有 key。
#   - 10 筆：story-002 優先序 2 追加（原本內嵌於函式本體、不是 `const` 宣告，因此沒有被
#     「零殘留」grep 抓到的格式化字串——card_confirm_panel.gd 8 筆、hand_bar.gd 1 筆、
#     battle_menu.gd 1 筆）。
#
# 本檔正式化自一支拋棄式探針（scratchpad/probe_csv_import.gd，不在版控內，已在同一次任務中
# 對原始 30 筆逐一 `TranslationServer.translate()` 核對，全數 OK=true）——這 30 筆的期望值
# 直接複製自該次驗證；新增的 10 筆是本檔第一次透過正式測試驗證（CSV 新增時未另外重跑探針，
# 見本檔頭「未查證」段落）。
#
# 🔴 甲類/乙類例外判斷（.claude/rules/test-standards.md 2026-09-16 裁決）：本檔完全不碰
# 檔案系統——不讀 strings.csv、不呼叫 FileAccess/DirAccess。期望字面值是 in-test 常數
# （本檔自己的 _EXPECTED_* 字典），資料來源是 project.godot 的 [internationalization] 設定
# 於引擎啟動時自動載入成 Translation 資源（與 loc_localize_test.gd 檔頭說明的機制相同），
# 不屬於甲/乙任何一類，也不需要援引該例外。
#
# 🔴 敏感度證明：本檔斷言「Loc.localize(key) 的回傳值」對照「寫死在測試裡的期望字面值」，
# 屬 test-standards.md 已登記的「類 A′：斷言對象是真實資料檔內容，沒有類別可注入錯誤版本」
# ——如果 strings.csv 某一列被改錯字或整列被刪除，本檔對應那一條測試會直接失敗，這就是
# 它存在的理由；沒有「間諜子類別」可做，也不需要。
extends GdUnitTestSuite


## 共用斷言 helper——逐一走訪 [param mapping]（key -> 期望字面值），對每一筆呼叫
## [method Loc.localize] 並比對，失敗訊息點名是哪一個 key 對不上，而不是只說「這組斷言
## 失敗」。不提前 return：同一次呼叫把整組裡所有不對的 key 都報出來，不是抓到第一個就停。
func _assert_keys_resolve_to_expected(mapping: Dictionary[StringName, String]) -> void:
	for key: StringName in mapping.keys():
		var expected: String = mapping[key]
		var actual: String = Loc.localize(key)
		assert_str(actual).append_failure_message(
			"key \"%s\" 應該查到「%s」，實得「%s」" % [String(key), expected, actual]
		).is_equal(expected)


# ---- battle_screen.gd 的 15 個 key（含 2 個 story-001 既有 key）-------------------------

const _EXPECTED_BATTLE_SCREEN: Dictionary[StringName, String] = {
	&"battle.hud.status_format": "第 %d 回合．%s",
	&"battle.hud.faction_player": "我方行動",
	&"battle.hud.faction_enemy": "敵方行動",
	&"battle.hud.result_victory": "勝利",
	&"battle.hud.result_defeat": "戰敗",
	&"battle.hud.affinity_preview_format": "好感度 %+d→%+d",
	&"battle.hud.affinity_current_format": "好感度 %+d",
	&"battle.hud.damage_preview_format": "打擊 %d　血量 %d→%d",
	&"battle.load_error.failure_format": (
		"遊戲資料載入失敗,無法開始戰鬥。\n\n%s\n檔案:%s\n\n請重新下載完整的安裝檔案。\n回報問題時請附上這個畫面。"
	),
	&"battle.load_error.reason_missing": "找不到必要的資料檔案。",
	&"battle.load_error.reason_unreadable": "資料檔案存在,但無法讀取。",
	&"battle.load_error.reason_empty_content": "資料檔案是空的。",
	&"battle.load_error.reason_parsed_empty": "資料檔案沒有可用的內容。",
	&"battle.load_error.reason_parse_error": "資料檔案內容格式錯誤,其中一列資料無法辨識。",
	&"battle.hud.controls_hint": (
		"移動 方向鍵/十字鍵/滑鼠　確認 Enter/A/左鍵　取消 Esc/B\n開/收手牌 C/X　跳目標 Tab/RB　選單 M/Start"
	),
}

func test_battle_screen_migrated_keys_resolve_to_original_literals() -> void:
	_assert_keys_resolve_to_expected(_EXPECTED_BATTLE_SCREEN)


# ---- hand_bar.gd 的 5 個 key(4 個原始 + 1 個優先序 2 追加)----------------------------

const _EXPECTED_HAND_BAR: Dictionary[StringName, String] = {
	&"battle.hand_bar.count_format": "%d/%d",
	&"battle.hand_bar.unavailable": "不可用",
	&"battle.hand_bar.permanent_mark": "永久",
	&"battle.hand_bar.forced_discard": "手牌已滿，請選一張棄掉",
	&"battle.hand_bar.temporary_effect_summary_format": "ATK%s · DEF%s · 剩%d回合",
}

func test_hand_bar_migrated_keys_resolve_to_original_literals() -> void:
	_assert_keys_resolve_to_expected(_EXPECTED_HAND_BAR)


# ---- card_confirm_panel.gd 的 13 個 key(5 個原始 + 8 個優先序 2 追加)------------------

const _EXPECTED_CARD_CONFIRM_PANEL: Dictionary[StringName, String] = {
	&"battle.card_confirm.permanent_warning": "⚠ 永久效果，無法復原",
	&"battle.card_confirm.narrative": "敘事影響小於戰場影響",
	&"battle.card_confirm.strength_unavailable": "（好感度數值尚未提供 — 見 UX-13）",
	&"battle.card_confirm.no_existing_modifiers": "（此對象目前無生效中修正）",
	&"battle.card_confirm.arrow_glyph": " → ",
	&"battle.card_confirm.target_format_single": "作用對象：%s",
	&"battle.card_confirm.delta_atk_format": "ΔATK：%s",
	&"battle.card_confirm.delta_def_format": "ΔDEF：%s",
	&"battle.card_confirm.duration_format": "存續回合：%d",
	&"battle.card_confirm.existing_modifier_line_format": "%s：ATK %s／DEF %s，剩 %d 回合",
	&"battle.card_confirm.effective_format": "合併後：ATK_eff %d／DEF_eff %d",
	&"battle.card_confirm.target_format_pair": "作用對象：%s ↔ %s",
	&"battle.card_confirm.strength_label_format": "好感度：%s",
}

func test_card_confirm_panel_migrated_keys_resolve_to_original_literals() -> void:
	_assert_keys_resolve_to_expected(_EXPECTED_CARD_CONFIRM_PANEL)


# ---- battle_menu.gd 的 7 個 key(6 個原始,含 1 個 story-001 既有 key + 1 個優先序 2 追加)--

const _EXPECTED_BATTLE_MENU: Dictionary[StringName, String] = {
	&"battle.menu.leave_confirm_title": "離開遊戲?",
	&"battle.menu.leave_confirm_body": "目前沒有存檔功能,離開後這場\n戰鬥的進度會消失。",
	&"battle.menu.rejection_authoritative_write": "（權威寫入進行中，暫時無法開啟選單）",
	&"battle.menu.rejection_forced_discard": "請先完成棄牌",
	&"battle.menu.reason_card_play_in_progress": "請先完成或取消打牌",
	&"battle.menu.reason_not_player_turn": "現在不是你的回合",
	&"battle.menu.disabled_row_prefix_glyph": "✕ ",
}

func test_battle_menu_migrated_keys_resolve_to_original_literals() -> void:
	_assert_keys_resolve_to_expected(_EXPECTED_BATTLE_MENU)


# ---- 總筆數守衛 —— 證明上面 4 組字典合計真的是 40,不是手滑漏算 --------------------------

func test_total_migrated_key_count_is_forty() -> void:
	var total: int = (
		_EXPECTED_BATTLE_SCREEN.size()
		+ _EXPECTED_HAND_BAR.size()
		+ _EXPECTED_CARD_CONFIRM_PANEL.size()
		+ _EXPECTED_BATTLE_MENU.size()
	)
	assert_int(total).append_failure_message(
		"四組字典合計應為 40(15+5+13+7)，實得 %d——若改了任何一組的筆數，這裡要一起改，" % total +
		"不然這條測試本身的「40」就是一句謊言"
	).is_equal(40)
