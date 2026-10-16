## Story 019 — 真實關卡(vs01,5 對 5)端到端打到終局.
##
## 與 story-018 的 battle_screen_battle_outcome_test.gd 不同:本測試【不】注入任何
## *_path_override 合成夾具 —— 全程使用真實 assets/data/ 下的 vs01 關卡資料。
## 目的是證明真實內容量級(5 對 5,而非 story-018 的小型合成夾具)也能在畫面側打到終局。
##
## 若本測試顯示真實關卡打不完、或任一方卡住 —— 這是本 story 的核心價值所在,應如實回報，
## 不得為了讓測試變綠而去修改 src/ai/ 或 src/gameplay/ 的遊戲邏輯。
##
## ## 🔴 實測結果與設計文件對照(2026-10-16):第 1 回合就 DEFEAT 不是 bug
##
## 本測試實測 round_count == 1、outcome() == DEFEAT(逐字輸出與逐人 HP/存活狀態見
## test_real_level_battle_reaches_a_terminal_outcome() 內的 print() 區塊,交付報告
## 一併貼了同一次執行的原始 log)。這完全符合設計文件明文的勝敗條件,不是程式壞掉:
##
##   design/gdd/vertical-slice-level-01.md「勝敗條件」節,逐字:
##   「失敗:依 C2,五名主角中任一人 HP 歸零即關卡失敗(非全滅才算輸)。」
##
##   design/quick-specs/unit-stats-provisional.md 關卡段落,逐字:
##   「失敗條件:五名主角任一人 HP 歸零即失敗(非全滅)。」
##
## src/gameplay/battle/battle_state.gd 的 outcome() 本身也是這樣寫的(DEFEAT 比
## VICTORY 優先判定——只要任一 PLAYER 單位死亡,即使同時所有 ENEMY 單位也死了,
## 結果仍是 DEFEAT)。這是不對稱的勝負條件:我方死一個就輸,敵方要死光才算贏。
## 用同一支零 RNG 的 GreedyTacticalAI 同時驅動雙方(敵方 step_enemy_phase() 在沒有
## 覆寫 _decide 時,生產路徑本來就預設呼叫同一個 GreedyTacticalAI.decide() —— 見
## src/gameplay/battle/battle_controller.gd 的 _decide_for()),在這個不對稱規則下,
## 只要敵方任何一次攻擊先命中致命一擊,整場戰鬥就立刻結束。
##
## 🔴 另一個對照,放大這個落差的意義:design/gdd/vertical-slice-level-01.md 自己的
## Acceptance Criteria 第 6 條寫「回合數落在 4~6:明顯偏離代表數值或地圖需調整,
## 非玩家技術問題」——那是對【人類玩家】的期待值。本測試量到的是 1 回合,與設計
## 期待的 4~6 回合差了 4~6 倍。這個落差本身就是下面 AC-6 揭露要強調的重點:貪婪 AI
## 的打法與人類玩家的打法不是同一回事,不能把本測試的「1 回合」讀成「這個關卡只需要
## 1 回合」或「這個關卡打不贏」——兩者都不是本測試能回答的問題。
##
## ## AC-6 誠實揭露:本測試證明了什麼、沒有證明什麼
##
## 證明了:真實 5 對 5 規模的戰鬥,從開局到 outcome() 離開 ONGOING,整條鏈
## (BattleScreen → BattleController.click_tile() / _end_faction_phase_pressed() →
## BattleState)在畫面側跑得動,不會卡死、不會崩潰。
##
## 🔴 沒有證明、而且必須被下一個人知道的事:
##   - 用同一支貪婪 AI(GreedyTacticalAI)驅動我方,不是人類的打法。本測試
##     不證明平衡性、不證明這個關卡「可不可破」、不證明好不好玩。
##   - 🔴 本測試實際只走完 1 個回合就結束(outcome() 在第 1 回合的敵方階段就變成
##     DEFEAT)。_ROUND_CAP = 10 這個上限【從未被接近】。因此本測試完全沒有涵蓋:
##     跨回合的行動旗標重置(TurnOrder.advance_faction())、多回合的回合順序遞迴、
##     長局才會出現的狀態累積(好感度池、卡片/棄牌、CardModifier 的
##     remaining_turns 遞減等)。這些目前仍然是零防線——不要把本測試讀成「真實關卡
##     打完一整場」已經被涵蓋,它只打完了「開局到第一次死亡」這一小段。
##   - 本測試的「我方」決策完全由 GreedyTacticalAI 決定,包含它會不會主動把單位
##     移動到暴露於多個敵人攻擊範圍內的格子——這正是本次量測中造成單回合即敗的
##     直接行為,但本測試不斷言、也不佐證這個移動選擇本身是否「合理」,只佐證
##     click_tile() 確實接受並執行了它。
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


## Shared Arrange step — loads the REAL BattleScreen.tscn with ZERO path
## overrides, so _ready() reads the production constants (TERRAIN_PATH /
## ROSTER_PATH / etc.), i.e. the real vs01 5-vs-5 level. This is the one
## deliberate difference from story-018's _load_battle_screen() helper,
## which always injects terrain_path_override / roster_path_override.
func _load_battle_screen_real() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


## Stage C — drives a single unit's turn through the REAL BattleController
## input entry point (click_tile()), never a BattleState mutator directly
## (AC-3). The move/attack decision itself comes from GreedyTacticalAI.decide()
## (faction-agnostic — see src/ai/greedy_tactical_ai.gd's own doc comment),
## fed the can_move/can_attack flags derived from this unit's CURRENT
## TurnOrder.ActionState so the AI never tries to spend a flag already spent.
##
## 🔴 ActionState direction, confirmed by reading turn_order.gd's own doc
## comment plus the TEXT_TILE_INFO_STATE_ATTACK_ONLY / _STATE_MOVE_ONLY
## caption constants in battle_screen.gd (named for what the player can STILL
## do): ATTACK_ONLY means "attack remains, move already spent"; MOVE_ONLY
## means "move remains, attack already spent".
##
## A unit may legally move THEN attack in the same call (dispatch brief trap
## note) — click_tile()'s own _apply_move() never clears _selected_unit_id
## (read from battle_controller.gd:1493-1505), so after the move click the
## same unit is still selected and the attack click targets its NEW position's
## legal targets, not a re-selection.
func _play_unit_turn_via_ai(instance: BattleScreen, unit_id: int) -> void:
	var action_state: TurnOrder.ActionState = instance._controller.unit_action_state(unit_id)
	if (
		action_state == TurnOrder.ActionState.DONE
		or action_state == TurnOrder.ActionState.NOT_FOUND
	):
		return
	var can_move: bool = (
		action_state == TurnOrder.ActionState.NONE_USED
		or action_state == TurnOrder.ActionState.MOVE_ONLY
	)
	var can_attack: bool = (
		action_state == TurnOrder.ActionState.NONE_USED
		or action_state == TurnOrder.ActionState.ATTACK_ONLY
	)
	var decision: Dictionary = GreedyTacticalAI.decide(instance._state, unit_id, can_move, can_attack)

	# AC-3: select by clicking the unit's OWN current tile first.
	var origin: Vector2i = instance._state.position_of(unit_id)
	var select_result: Dictionary = instance._controller.click_tile(origin)
	assert_that(select_result["action"]).is_equal(&"selected")
	assert_int(select_result["unit_id"]).is_equal(unit_id)

	if decision["move_to"] != null:
		var move_result: Dictionary = instance._controller.click_tile(decision["move_to"])
		assert_that(move_result["action"]).is_equal(&"moved")

	var attack_target: int = decision["attack"]
	if attack_target != -1:
		var target_pos: Vector2i = instance._state.position_of(attack_target)
		var attack_result: Dictionary = instance._controller.click_tile(target_pos)
		assert_that(attack_result["action"]).is_equal(&"attacked")


## Drives every not-yet-DONE unit of faction through _play_unit_turn_via_ai(),
## repeating passes until a full pass acts on nobody (handles the "moved but
## could not then attack, still has a flag left" case — see
## _play_unit_turn_via_ai's doc comment on ActionState direction). _PASS_CAP
## bounds this independently of the outer round cap so a single stuck faction
## phase cannot itself loop forever.
const _PASS_CAP: int = 20

func _play_faction_turn_via_ai(instance: BattleScreen, faction: Unit.Faction) -> void:
	var pass_count: int = 0
	while pass_count < _PASS_CAP:
		pass_count += 1
		var acted_this_pass: bool = false
		for unit: Unit in instance._state.units_of(faction):
			var action_state: TurnOrder.ActionState = instance._controller.unit_action_state(unit.id)
			if (
				action_state == TurnOrder.ActionState.DONE
				or action_state == TurnOrder.ActionState.NOT_FOUND
			):
				continue
			_play_unit_turn_via_ai(instance, unit.id)
			acted_this_pass = true
		if not acted_this_pass:
			break


## AC-2 的上限 —— 刻意遠大於下方「實測」段落記下的真實量測值(見
## test_real_level_battle_reaches_a_terminal_outcome() 內的 AC-1+AC-2 斷言註解),
## 不是用猜的。觸發這個上限時,下方 AC-1+AC-2 的斷言會明確 FAILED(outcome() 仍是
## ONGOING),不會讓迴圈默默跑完後測試照樣綠燈。
const _ROUND_CAP: int = 10


func test_real_level_battle_reaches_a_terminal_outcome() -> void:
	# Arrange
	var instance: BattleScreen = _load_battle_screen_real()

	# Assert — 開局防誤報:真實 vs01 名冊是 5 對 5(grep -v "^#"
	# assets/data/units/vs01_roster.txt | awk -F, '{print $3}' | sort | uniq -c),
	# 且還沒有人採取任何行動前,outcome() 不得已經不是 ONGOING。
	assert_int(instance._state.units_of(Unit.Faction.PLAYER).size()).is_equal(5)
	assert_int(instance._state.units_of(Unit.Faction.ENEMY).size()).is_equal(5)
	assert_int(instance._controller.outcome()).is_equal(BattleState.Outcome.ONGOING)

	# 捕捉原始 5+5 名單的 Unit 參照(此刻全員存活)——BattleState 從不把死亡單位從
	# _units 字典移除(outcome() 自己也靠遍歷 _units.values() 判定,見其 doc comment),
	# 只標記 is_alive() == false,所以同一組參照在迴圈跑完之後讀,.hp / .is_alive()
	# 會反映最終狀態,不必另外查詢「原本是誰」。
	var player_units_at_start: Array[Unit] = instance._state.units_of(Unit.Faction.PLAYER)
	var enemy_units_at_start: Array[Unit] = instance._state.units_of(Unit.Faction.ENEMY)

	# Act — 逐回合推進。我方全部透過 AC-3 要求的真實入口 click_tile() 驅動
	# (_play_faction_turn_via_ai() -> _play_unit_turn_via_ai());敵方透過 AC-4
	# 要求的真實畫面入口 _end_faction_phase_pressed() 驅動 —— 該方法本身同時負責
	# 「結束我方回合」與「逐步播放敵方整個 ENEMY_ACTING 階段」兩件事(見其原始碼
	# src/ui/battle/battle_screen.gd:3369-3391),不是本檔自己拼湊的簡化版。
	var round_count: int = 0
	var start_msec: int = Time.get_ticks_msec()
	while instance._controller.outcome() == BattleState.Outcome.ONGOING and round_count < _ROUND_CAP:
		round_count += 1
		if instance._controller.phase() == BattleController.Phase.PLAYER_INPUT:
			_play_faction_turn_via_ai(instance, Unit.Faction.PLAYER)
		await instance._end_faction_phase_pressed()
	var elapsed_msec: int = Time.get_ticks_msec() - start_msec

	# 🔴 診斷輸出 —— 管理者 2026-10-16 要求「第 1 回合到底發生了什麼」必須留得下來
	# 查證,不得只留結論。刻意保留在檔案裡,不要刪:逐人 code_name + HP + 存活狀態、
	# 最終 round_count、最終 outcome()。這段輸出的原始文字已逐字貼進本故事的交付
	# 報告(2026-10-16 這次重跑的原文)。
	print("=== battle_screen_real_level_battle_test diagnostic (2026-10-16) ===")
	for u: Unit in player_units_at_start:
		print("  PLAYER ", u.code_name, " (id=", u.id, ") hp=", u.hp, "/", u.hp_max, " alive=", u.is_alive())
	for u: Unit in enemy_units_at_start:
		print("  ENEMY  ", u.code_name, " (id=", u.id, ") hp=", u.hp, "/", u.hp_max, " alive=", u.is_alive())
	print("  round_count=", round_count, " outcome=", instance._controller.outcome(),
		" elapsed_msec=", elapsed_msec)
	print("=== end diagnostic ===")

	# Assert — AC-1 + AC-2:結果必須是 VICTORY 或 DEFEAT,絕不是 ONGOING。這一條
	# 斷言同時是 AC-2 要求的上限把關:若 _ROUND_CAP 回合內從未脫離 ONGOING,
	# outcome() 仍是 ONGOING,本斷言會明確 FAILED —— 不是迴圈默默跑完後測試照樣通過。
	#
	# 🔴 實測結果(2026-10-16,本機 Godot 4.7.1 headless,獨立連跑兩次逐字相同,
	# 零 RNG 故完全決定性 —— 見本檔檔頭 AC-6 揭露對這個結果的解讀):
	# round_count == 1,outcome() == DEFEAT。_ROUND_CAP 設為 10 是刻意遠大於這個
	# 實測值的餘裕 —— 敵方的真實生產路徑 step_enemy_phase() 在沒有 _decide 覆寫時
	# 本就預設呼叫同一個 GreedyTacticalAI.decide()(src/gameplay/battle/battle_controller.gd:1583),
	# 所以這是「GreedyTacticalAI 對打 GreedyTacticalAI」,雙方皆無隨機性,這個對局
	# 結果不會在不同次執行間變動;10 這個數字純粹是「上限要量出來、不是用猜的」這條
	# 紀律的落實,不是因為觀測到任何變異需要容納。
	assert_bool(
		instance._controller.outcome() == BattleState.Outcome.VICTORY
		or instance._controller.outcome() == BattleState.Outcome.DEFEAT
	).is_true()

	# Assert — AC-5:耗時必須量測並揭露。🔴 實測 elapsed_msec 落在本故事交付時
	# 的最後一次乾淨重跑記錄區間內(見本檔交付報告原始輸出),遠低於 30 秒門檻,
	# 未觸發「停下來回報」。斷言只設一個遠高於實測值的安全上限,理由與 _ROUND_CAP
	# 相同:上限要存在且會在真的異常變慢時明確失敗,不是用來卡一個精確數字。
	assert_int(elapsed_msec).is_less(30000)
