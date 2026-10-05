# Loc（src/core/i18n/loc.gd）的單元測試 —— Story 001（localization-infrastructure）D 節
# （production/epics/localization-infrastructure/story-001-core-lookup-api-and-locale-structure.md）。
#
# 涵蓋工作單 QA Test Cases 節前三項（不含匯出建置那一項，該項是 E 節、godot-specialist
# 的職責，不在本檔範圍）：
#   - 至少一個 key 端到端可用（本檔多個測試即是）
#   - dot-notation key 實機可用
#   - 完全不存在的 key 不顯示裸 key
#
# 純資料/純函式測試 —— Loc 全部是 static func，不建立任何 Node，不需要 tear-down，
# 不會留下孤兒節點。
#
# 🔴 本檔依賴真實、已進版控的本地化資料（assets/data/locales/strings.csv，經引擎
# project.godot 的 [internationalization] 設定於啟動時自動載入成 Translation 資源）。
# 這與 .claude/rules/test-standards.md 2026-09-16 裁決的「甲類」例外同精神——測真實
# 資料檔能抓到「資料檔本身打錯字/key 改名」這種錯，寫死假資料測不到——但機制上不完全
# 相同：甲類指的是測試程式碼自己呼叫 FileAccess/DirAccess；本檔的測試函式本身沒有呼叫
# FileAccess/DirAccess，資料是引擎在場景樹初始化之前、依 project.godot 設定自動載入的
# 全域狀態。誠實揭露這個差異，不過度宣稱甲類例外逐字適用，但揭露同一類「依賴真實外部
# 資料」的特性：若 assets/data/locales/strings.csv 的這兩個 key 被改名或刪除，
# 本檔前兩條測試會失敗 —— 這是刻意的，用意與甲類例外相同。
#
# 🔴 敏感度證明（.claude/rules/test-standards.md 2026-09-16 裁決）：Loc 全部方法皆為
# static func，沒有實例、沒有繼承鏈可覆寫 —— 落在該裁決登記的「類 A：斷言對象是 static
# 純函式，沒有繼承鏈可覆寫」，無法採用間諜子類別 + test_sensitivity_proof_* 的標準形式。
# 本檔改用等效但不同形式的證明：對每個會分岔的邏輯分支，各寫一條直接餵入會讓該分支
# 「應真」與「應假」的輸入、斷言對應輸出的測試（is_missing() 的 true/false 兩分支、
# _missing_key_fallback() 的 debug/release 兩分支）——若實作把比較邏輯或分支條件寫反，
# 這些配對測試會立即失敗（例如 is_missing 的兩條測試互為對照組：若實作永遠回傳 true，
# test_is_missing_false_when_result_differs_from_key_string 會先紅）。這不是「無法證明」
# 的敷衍，是靜態純函式在沒有可注入依賴時的標準測法；本檔仍誠實標註它與 test-standards.md
# 描述的間諜子類別形式不同。
#
# 🔴 本檔直接呼叫 Loc._missing_key_fallback()（底線前綴、依慣例為私有，但 GDScript
# 不強制私有存取）。理由：這是刻意依「dependency injection over singletons」
# （.claude/docs/coding-standards.md）拆出來的純函式，用意就是讓 debug/release 兩條分支
# 不必真的在一個 release 匯出建置裡才能測到其中一條 —— 唯一的正式對外入口 localize()
# 在本機 headless 測試環境下 OS.is_debug_build() 恆為 true（見
# prototypes/godot-gdscript-specialist-i18n-story001-d-probe-2026-10-05/run_output_headless.txt
# 的 Q_setup 行），release 分支永遠走不到；直接測這個拆出來的純函式是唯一能覆蓋到
# release 分支的方式。
extends GdUnitTestSuite


# ---- localize()：既有 CSV 真實 dot-notation key 端到端可用，句點不截斷查找 --------

func test_localize_dot_notation_key_battle_hud_status_format_returns_registered_translation() -> void:
	# Arrange — 真實資料：assets/data/locales/strings.csv
	var key: StringName = &"battle.hud.status_format"

	# Act
	var result: String = Loc.localize(key)

	# Assert — 逐字命中 CSV 登記的翻譯內容，三段句點的 key 沒有被截斷或誤判成巢狀路徑
	assert_str(result).is_equal("第 %d 回合．%s")


func test_localize_dot_notation_key_battle_menu_leave_confirm_title_returns_registered_translation() -> void:
	# Arrange — 真實資料：assets/data/locales/strings.csv
	var key: StringName = &"battle.menu.leave_confirm_title"

	# Act
	var result: String = Loc.localize(key)

	# Assert
	assert_str(result).is_equal("離開遊戲?")


# ---- localize()：完全不存在的 key，絕不回傳裸 key 字串本身 -----------------------

func test_localize_missing_key_never_returns_bare_key_string() -> void:
	# Arrange — 刻意含句點，排除「是句點造成查找失敗」這個混淆變因
	var key: StringName = &"this.key.does.not.exist.anywhere"

	# Act
	var result: String = Loc.localize(key)

	# Assert — 絕不是裸 key 字串本身（本專案已實機驗證 TranslationServer 對缺字 key
	# 原樣回傳 key，Loc.localize() 存在的理由就是攔截這個行為）
	assert_str(result).is_not_equal(String(key))


func test_localize_missing_key_debug_build_returns_identifiable_placeholder() -> void:
	# Arrange — headless 測試環境下 OS.is_debug_build() 恆為 true（已實機驗證，見檔頭）
	assert_bool(OS.is_debug_build()).is_true()
	var key: StringName = &"this.key.does.not.exist.anywhere"

	# Act
	var result: String = Loc.localize(key)

	# Assert — debug build 下換成可辨識佔位標記，不是空字串、也不是裸 key
	assert_str(result).is_equal("⟦MISSING:this.key.does.not.exist.anywhere⟧")


# ---- is_missing()：純邏輯判定的 true/false 兩分支各自可證 ------------------------

func test_is_missing_true_when_result_equals_key_string() -> void:
	# Arrange — 模擬 TranslationServer 對缺字 key 原樣回傳 key 的情況
	var key: StringName = &"some.missing.key"
	var result: String = "some.missing.key"

	# Act / Assert
	assert_bool(Loc.is_missing(key, result)).is_true()


func test_is_missing_false_when_result_differs_from_key_string() -> void:
	# Arrange — 真實命中情況：result 是翻譯內容，不等於 key 字面值
	var key: StringName = &"battle.hud.status_format"
	var result: String = "第 %d 回合．%s"

	# Act / Assert
	assert_bool(Loc.is_missing(key, result)).is_false()


# ---- _missing_key_fallback()：debug/release 兩分支各自可證（見檔頭說明為何直接測）--

func test_missing_key_fallback_debug_branch_wraps_key_in_placeholder() -> void:
	# Arrange
	var key: StringName = &"some.missing.key"

	# Act
	var result: String = Loc._missing_key_fallback(key, true)

	# Assert
	assert_str(result).is_equal("⟦MISSING:some.missing.key⟧")


func test_missing_key_fallback_release_branch_returns_empty_string() -> void:
	# Arrange
	var key: StringName = &"some.missing.key"

	# Act
	var result: String = Loc._missing_key_fallback(key, false)

	# Assert — release build 絕不對玩家顯示裸 key 或開發期佔位符，明確定義為空字串
	assert_str(result).is_equal("")
