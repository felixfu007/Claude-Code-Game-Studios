## battle_screen_battle_outcome_test.gd
##
## Story 018(production/epics/tactical-combat/story-018-battle-outcome-end-to-end.md)
## — 勝負結算全專案 0 命中(grep "VICTORY\|outcome()\|TEXT_RESULT" 於
## tests/integration/ui/ 與 tests/unit/ui/ 零命中),本檔補上第一條走過
## BattleState.outcome() → BattleController.battle_ended → BattleScreen.
## _on_battle_ended() → ResultLabel 這條鏈的測試。
##
## 真實場景載入,比照 tests/integration/ui/battle/battle_screen_enemy_phase_playback_test.gd
## 的既有範本:load() res://src/ui/battle/BattleScreen.tscn,不自組替身節點鏈
## (2026-09-22 教訓:自組替身鏈曾報 194 格假違規,走真實管線複驗是 0)。
##
## 🔴 headless 下引擎不送任何 InputEvent(--ignoreHeadlessMode 存在的理由),所以
## 走鍵盤/滑鼠路徑的測試會靜默什麼都不做。本檔直接驅動 instance._controller ——
## 它就是畫面持有的那一顆真實 BattleController,battle_ended 訊號已經連到
## instance._on_battle_ended(),所以結果標籤照樣會更新。這仍然是端到端,只是
## 跳過引擎在 headless 下本來就不會送的那一層輸入事件。
##
## ## 檔案 I/O 使用揭露(.claude/rules/test-standards.md「單元測試不得碰檔案系統」
## 節,2026-09-16 管理者裁決的甲/乙兩類明文例外)
##
## 甲類(讀 assets/data/ 底下已進版控的真實資料檔)—— 每一條測試都 load()/
## instantiate() 真實的 BattleScreen.tscn,透過既有的 terrain_path_override /
## roster_path_override 注入點(instantiate() 之後、add_child() 之前,唯一正確
## 時機窗 —— _ready() 只讀一次且要進樹才跑)餵入三份新夾具:
##   - assets/data/levels/test_fixture_terrain_duel.txt
##   - assets/data/units/test_fixture_roster_duel.txt   (AC-1/AC-2/AC-4)
##   - assets/data/units/test_fixture_roster_doomed.txt (AC-3)
## 唯讀,不寫入任何檔案。affinity_path_override 刻意不覆寫,沿用預設
## vs01_affinity_links.txt —— 已查證 AffinityPhiProvider.links() 的配對迴圈只在
## PLAYER 陣營「兩個以上」單位間才會產生配對(本夾具皆只有 1 個 PLAYER 單位),
## 故本檔全部攻擊的 phi 保證為 0,不受預設好感度檔內容影響。
##
## 揭露:本檔不證明窮盡性 —— 只驗證 AC-1~AC-6 列出的具體路徑與本檔夾具組合,
## 不代表涵蓋 outcome() 以外的所有勝負情境(例如多單位混戰、多回合拉鋸)。
##
## AC 對照(見 story-018 的 Acceptance Criteria 節):
##   test_game_start_does_not_falsely_report_outcome      -> AC-4
##   test_victory_when_all_enemies_defeated                -> AC-1 + AC-2(同一條測試)
##   test_defeat_when_any_player_unit_dies                  -> AC-3
##   test_sensitivity_proof_*                                -> AC-5
##
## ## AC-5 涵蓋範圍 + 一項誠實登記的「證明不了」(test-standards.md 的兩項義務)
##
## 可證(三條常駐 mutant 敏感度證明,見下方 _MutantSwapsResultText /
## _MutantSkipsResultLabelVisibility 與三條 test_sensitivity_proof_*):
##   - AC-2/AC-3 的文字斷言(VICTORY/DEFEAT 文字是否正確)
##   - AC-2/AC-3 的可見性斷言(_result_label.visible 是否真的被翻成 true)
##
## 🔴 證明不了,逐條寫下(test-standards.md「已知證明不了的五類」之 D 類 ——
## 「唯一有意義的注入點在受限範圍外」):
##   - **AC-1「battle_ended 恰好發出一次」這個保證本身**,其實作是
##     src/gameplay/battle/battle_controller.gd 的 _check_outcome_and_finish()
##     (以 Phase.FINISHED 判斷式擋下重複 emit)。本 story 的 Affected Files 只
##     授權在 battle_screen.gd 新增 diagnostic_* 唯讀 getter,不授權修改
##     battle_controller.gd 的既有行為 —— 要注入「重複 emit」的缺陷,唯一有意義
##     的位置就是改寫 _check_outcome_and_finish() 本身,那正是 D 類定義的情境。
##     本檔仍然斷言這個值(見 test_victory_when_all_enemies_defeated 內
##     battle_ended_count 的斷言)以便抓到未來的真實退步,但**它沒有、也不可能有
##     一個留在本檔案範圍內的常駐 mutant 證明這個斷言會紅**。真正能證明它的位置
##     是 tests/unit/gameplay/battle/battle_controller_test.gd(若該檔已涵蓋
##     _check_outcome_and_finish() 的重複呼叫防呆,那份測試才是這個保證的真正
##     敏感度證明擁有者)。

extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _TERRAIN_DUEL_PATH: String = "res://assets/data/levels/test_fixture_terrain_duel.txt"
const _ROSTER_DUEL_PATH: String = "res://assets/data/units/test_fixture_roster_duel.txt"
const _ROSTER_DOOMED_PATH: String = "res://assets/data/units/test_fixture_roster_doomed.txt"


## 間諜子類別(僅供下方 test_sensitivity_proof_*_text_swap_is_caught 使用)——
## 把 _on_battle_ended() 的 VICTORY/DEFEAT 文字三元運算子刻意寫反。set_script()
## 一律在 add_child() 之前呼叫(Case A,已由 2026-09-17 探針驗證安全 ——
## 見 .claude/rules/test-standards.md 「C 類」更正段落),不在進樹之後換腳本
## (Case B,已驗證不安全)。
##
## 🔴 查證記錄(2026-10-16):第一版把 set_script() 寫在兩個 override 屬性賦值
## 【之後】。跑起來三條敏感度證明測試全部看起來「文字不對」,而實際原因與文字
## 內容無關 —— 加一行 `print("after set_script: terrain=", instance.
## terrain_path_override, " roster=", instance.roster_path_override)` 查證,
## 印出來的是空字串,不是夾具路徑。亦即 set_script() 會重建腳本實例、把先前寫入
## 的 override 屬性重設回宣告時的預設值(""),於是 _ready() 讀到的是空字串 ->
## 退回常數 TERRAIN_PATH/ROSTER_PATH(真實 vs01 資料),不是本檔的決鬥/戰敗夾具。
## 攻擊因此打在錯誤的棋盤上,battle_ended 從未以本檔期待的方式發出,
## _result_label.text 停在預設空字串。**修法是把 set_script() 移到兩個 override
## 賦值【之前】**——下方三條測試皆已採用這個順序。
##
## 🔴 連帶記錄(避免下一個人被同一份 log 騙):GdUnit4 的字串斷言失敗報告在
## 「實際值是空字串」時,「Expecting: / but was:」兩行**印出來的文字視覺上完全
## 相同**(兩行都顯示期望值本身)——色碼(ANSI 深紅底色)標示「實際值缺少的字
## 元」,但色碼一旦被篩掉(例如存檔或用 sed 去 ANSI),看起來就像「兩個相同的
## 字串被判定不相等」。遇到這個情況,不要照字面信任那兩行的文字內容,要另外印出
## `.length()` 或直接比較 `==` 來查證實際值是否真的是空字串。
class _MutantSwapsResultText extends BattleScreen:
	func _on_battle_ended(outcome: BattleState.Outcome) -> void:
		_result_label.visible = true
		_result_label.text = (
			Loc.localize(TEXT_RESULT_DEFEAT) if outcome == BattleState.Outcome.VICTORY
			else Loc.localize(TEXT_RESULT_VICTORY)
		)


## 間諜子類別(僅供 test_sensitivity_proof_result_label_visibility_skip_is_caught
## 使用)—— 只設文字、刻意不翻 _result_label.visible,證明 AC-2/AC-3 的可見性
## 斷言真的會抓到「文字對了但畫面沒顯示」這種退步。
class _MutantSkipsResultLabelVisibility extends BattleScreen:
	func _on_battle_ended(outcome: BattleState.Outcome) -> void:
		_result_label.text = (
			Loc.localize(TEXT_RESULT_VICTORY) if outcome == BattleState.Outcome.VICTORY
			else Loc.localize(TEXT_RESULT_DEFEAT)
		)


## Shared Arrange step for every test in this file: loads the REAL
## BattleScreen.tscn, injects the two data-path overrides (instantiate() ->
## override -> add_child(), the only correct injection window — see this
## file's header), and hands back the live instance. Does not touch
## affinity_path_override — see header disclosure for why that is safe here.
func _load_battle_screen(terrain_path: String, roster_path: String) -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	instance.terrain_path_override = terrain_path
	instance.roster_path_override = roster_path
	add_child(instance)
	return instance


# ---- AC-4: 開局不得誤報 ---------------------------------------------------

func test_game_start_does_not_falsely_report_outcome() -> void:
	# Arrange / Act — 載入真實場景,注入夾具,不做任何玩家操作
	var instance: BattleScreen = _load_battle_screen(_TERRAIN_DUEL_PATH, _ROSTER_DUEL_PATH)

	# Assert — 防的是「結果標籤一開場就亮著」這種恆真通過
	assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.ONGOING)
	assert_bool(instance._result_label.visible).is_false()


# ---- AC-1 + AC-2: 勝利路徑與勝利的畫面後果(同一條測試,見工作單「兩個都要斷言」)----

func test_victory_when_all_enemies_defeated() -> void:
	# Arrange
	var instance: BattleScreen = _load_battle_screen(_TERRAIN_DUEL_PATH, _ROSTER_DUEL_PATH)
	# 🔴 查證記錄(2026-10-16):第一版把這個計數器宣告成 `var battle_ended_count: int = 0`
	# 並在 lambda 內寫 `battle_ended_count += 1` —— 跑起來後計數恆為 0,即使
	# outcome()==VICTORY 的斷言(在它之前,且沒有失敗)已經證明攻擊與訊號都確實發生。
	# 這不是遊戲的 bug,是本專案已經登記過的 GDScript 語意:lambda 對捕捉到的區域
	# `int`/`bool` 變數是「值捕捉」,lambda 內的賦值不會寫回外層局部變數 —— 見
	# src/gameplay/battle/battle_controller.gd `_apply_attack()` 的既有 doc comment:
	# 「GDScript lambdas do not write back to a captured outer int/bool local, but a
	# captured Dictionary/Array is a shared reference, so mutating its entries is
	# visible after the call returns.」改用單元素 Array(參考型別)後,lambda 內對
	# `battle_ended_count[0]` 的賦值會正確反映到外層,下方斷言通過。
	var battle_ended_count: Array = [0]
	instance._controller.battle_ended.connect(
		func(_outcome: BattleState.Outcome) -> void: battle_ended_count[0] += 1
	)

	# Act — 走真實 BattleController.click_tile() 入口(headless 下引擎不送
	# InputEvent,見本檔檔頭),先選我方單位所在格,再點擊敵方單位所在格觸發攻擊。
	# 每一步都斷言回傳的 action,不假設它成功了。
	var select_result: Dictionary = instance._controller.click_tile(Vector2i(0, 0))
	assert_that(select_result["action"]).is_equal(&"selected")

	var attack_result: Dictionary = instance._controller.click_tile(Vector2i(1, 0))
	assert_that(attack_result["action"]).is_equal(&"attacked")

	# Assert — AC-1: outcome() == VICTORY,且 battle_ended 恰好發出一次
	assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.VICTORY)
	assert_int(battle_ended_count[0]).is_equal(1)

	# Assert — AC-2: 勝利的畫面後果。訊號發出不等於畫面有變,兩者都要斷言
	assert_bool(instance._result_label.visible).is_true()
	assert_str(instance._result_label.text).is_equal(Loc.localize(BattleScreen.TEXT_RESULT_VICTORY))


# ---- AC-3: 戰敗路徑 --------------------------------------------------------

func test_defeat_when_any_player_unit_dies() -> void:
	# Arrange
	var instance: BattleScreen = _load_battle_screen(_TERRAIN_DUEL_PATH, _ROSTER_DOOMED_PATH)
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)

	# Act — 敵方 AI(GreedyTacticalAI,無 RNG,見 src/ai/greedy_tactical_ai.gd)
	# 一擊必殺我方唯一單位。走既有範本同一個入口:_end_faction_phase_pressed()
	# 會等到整個逐步播放跑完(含它自己的計時器暫停 ENEMY_STEP_PAUSE_SECONDS)。
	await instance._end_faction_phase_pressed()

	# Assert — outcome() == DEFEAT。依 battle_state.gd outcome() 的 doc comment,
	# 任一我方單位死亡即成立,不要求我方全滅 —— 本夾具只有 1 個敵方單位,
	# DEFEAT 在它殺死我方唯一單位的當下立即成立。
	assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.DEFEAT)
	assert_bool(instance._result_label.visible).is_true()
	assert_str(instance._result_label.text).is_equal(Loc.localize(BattleScreen.TEXT_RESULT_DEFEAT))


# ---- AC-5: 敏感度證明 -------------------------------------------------------
# 涵蓋範圍與一項「證明不了」的誠實登記見本檔檔頭「AC-5 涵蓋範圍」節。

func test_sensitivity_proof_victory_text_swap_is_caught() -> void:
	# Arrange — 間諜版本把 VICTORY/DEFEAT 文字寫反,載入「勝利」夾具。
	# 🔴 set_script() 必須在兩個 override 賦值之前呼叫 —— 見上方
	# _MutantSwapsResultText 的查證記錄:順序顛倒會讓 override 被 set_script()
	# 重設回空字串,靜默退回真實 vs01 資料。
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantSwapsResultText)
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH
	auto_free(instance)
	add_child(instance)

	# Act
	instance._controller.click_tile(Vector2i(0, 0))
	instance._controller.click_tile(Vector2i(1, 0))

	# Assert — 真正版本在同樣操作下顯示「勝利」(見
	# test_victory_when_all_enemies_defeated);間諜版本刻意寫反,這裡斷言它
	# 確實顯示「戰敗」文字,證明 AC-2 的文字斷言若遇到這個退步真的會抓到(FAILED,
	# 不是靜默一起通過)。
	assert_str(instance._result_label.text).is_equal(Loc.localize(BattleScreen.TEXT_RESULT_DEFEAT))


func test_sensitivity_proof_defeat_text_swap_is_caught() -> void:
	# Arrange — 同一個間諜類別,改載「戰敗」夾具,證明 AC-3 的文字斷言同樣敏感。
	# set_script() 順序同上一條(必須在 override 賦值之前)。
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantSwapsResultText)
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DOOMED_PATH
	auto_free(instance)
	add_child(instance)

	# Act
	await instance._end_faction_phase_pressed()

	# Assert — 間諜版本刻意寫反,DEFEAT 應顯示「戰敗」卻顯示「勝利」文字
	assert_str(instance._result_label.text).is_equal(Loc.localize(BattleScreen.TEXT_RESULT_VICTORY))


func test_sensitivity_proof_result_label_visibility_skip_is_caught() -> void:
	# Arrange — 間諜版本只設文字、刻意不翻 visible。set_script() 順序同上
	# (必須在 override 賦值之前)。
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantSkipsResultLabelVisibility)
	instance.terrain_path_override = _TERRAIN_DUEL_PATH
	instance.roster_path_override = _ROSTER_DUEL_PATH
	auto_free(instance)
	add_child(instance)

	# Act
	instance._controller.click_tile(Vector2i(0, 0))
	instance._controller.click_tile(Vector2i(1, 0))

	# Assert — 文字仍然正確(間諜只動 visible 這一行,其餘不變),但 visible
	# 保持預設 false,證明 AC-2/AC-3 的可見性斷言真的會抓到這種「文字對了但畫面
	# 沒顯示」的退步。
	assert_str(instance._result_label.text).is_equal(Loc.localize(BattleScreen.TEXT_RESULT_VICTORY))
	assert_bool(instance._result_label.visible).is_false()
