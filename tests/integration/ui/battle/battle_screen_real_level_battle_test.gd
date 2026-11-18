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
##
## ## 🔴 Story 020(2026-10-16)—— 加了安全過濾器,但真正撞到的是一個無人踩過的凍結點
##
## story-019 量到的「第 1 回合就死」,成因確實是測試的我方打法直接用未經過濾的
## GreedyTacticalAI,把最脆的丙推進了敵人殺傷範圍 —— 本 story 在
## [method _apply_safety_filter] 加了一道 AC-1/AC-2 要求的「不自殺」規則(完整規則
## 文字見該方法的 doc comment),效果如預期:加了過濾器之後,真正的遊戲回合 1
## 不再有任何單位死亡(見下方座標證據)。
##
## 🔴 但加完過濾器之後,round_count 一度【仍然】卡在上限(10),outcome() 仍是
## ONGOING —— 而根因與我方打法完全無關,是一個本 story 事前完全沒有預期到、
## 先前任何一支測試都從未踩過的系統閘門:
##
## [b]真正發生的事(逐回合診斷輸出的座標行是直接證據,不是推論)[/b]:遊戲內部的
## 真回合 1 完全正常進行 —— 敵我雙方都真的移動了(例如戊從 (0,5) 移到 (2,1),
## E1 從 (10,0) 移到 (4,0),E4/E5 等敵方單位同樣大幅推進),雙方都還沒有進入能
## 互相攻擊的距離,沒有人受傷。到這裡為止,過濾器做的事完全正確。
##
## 緊接著,當遊戲內部推進到真回合 2 開始時([method
## BattleState.begin_player_turn] 的「每個玩家回合開始」鉤子第一次真正觸發 ——
## 真回合 1 依 [method BattleState.deal_opening_hand] 的 doc comment 說明,
## [b]刻意[/b]跳過這個鉤子,只在開局發一次手牌),[CardDeck] 的強制棄牌規則
## (story-007-forced-discard-gate.md)第一次被滿足:開局手牌已經是
## [constant CardDeck.HAND_SIZE_LIMIT],真回合 2 的補牌把手牌推過上限,
## [method CardDeck.has_pending_discard] 從此恆為 true。
##
## 🔴 這個閘門鎖死的範圍比「我方選不到單位」大得多 —— 它連
## [method BattleController.end_faction_phase] 本身都會擋下(見該方法原始碼的
## [code]if _state.has_pending_discard(): return[/code])。[b]不只我方,連敵方的
## production 路徑都無法再推進一步[/b] —— 直到這個閘門被解除為止。
## story-019 從未踩到它,純粹是因為那場戰鬥在真回合 1 就已經結束
## (在閘門第一次有機會觸發之前)。
##
## ✅ 本 story 最終沒有把這個凍結點留著回報了事,而是用遊戲【已經提供的正式
## 入口】解除它:[method _resolve_any_pending_discard] 每回合開始前呼叫
## [method BattleController.resolve_forced_discard](永遠棄 [code]hand[0][/code],
## 決定性選擇,不隨機)—— 這正是 [BattleLoop] 自己的 [code]discard_policy[/code]
## 路徑也會走到的同一個 production 呼叫([method
## BattleController.resolve_forced_discard] 的 doc comment 原文:「the human-driven
## and simulation-driven paths converge on one discard implementation」),
## 不是測試側繞過閘門的捷徑。加上這一步之後,實測
## [b]round_count == 2,outcome() == DEFEAT[/b](2026-10-16 本機 Godot 4.7.1
## headless,獨立連跑兩次逐字相同,僅 elapsed_msec 不同 —— 完全決定性)。
## 真回合 2 裡乙陣亡 —— 查座標證據:此時敵方已大幅推進到 x=1~7(對照真回合 1
## 的 x=4~9),乙本身這一整局都沒有移動過,顯然是【站在原地被圍上來的敵人打死】,
## 不是本 story 過濾器允許的「移動進危險格」—— 完全落在
## [method _apply_safety_filter] 自己揭露的範圍限制內(該方法 doc comment:
## 「若單位這回合根本沒打算移動,這道過濾器不介入,即使它當前的格子已經被威脅」)。
##
## 🔴 誠實揭露(AC-7,以下五點是本次收尾逐條核對過的,不是寫意的摘要):
##
##   1. 這仍然不是人類打法。[method _apply_safety_filter] 的規則目的是「讓
##      雙方撐久一點、不要一碰面就死」,不是「打得好」—— 它不選擇最優的攻擊
##      位置,只排除明顯自殺的那一種。不證明平衡性、不證明這個關卡「可不可
##      破」、不證明好不好玩,也不證明乙在真回合 2 的死亡本身是否「合理」
##      (過濾器刻意不介入「原地不動」的情境,但沒有驗證過不介入是不是正確
##      設計)。
##   2. 這個打法是【測試裝置】,僅供這支測試驅動真實關卡用,不是對遊戲 AI
##      的建議或替代。
##   3. 🔴 本測試揭露了一個先前無人踩到的凍結點:強制棄牌未解決時,
##      [method BattleController.click_tile] 全部回傳
##      [code]&"blocked_pending_discard"[/code]、[method
##      BattleController.end_faction_phase] 直接不做事 —— 玩家與敵方階段
##      【雙雙】停擺。story-019 因為第 1 回合就結束,從未觸及。這個洞一直
##      存在,只是先前沒有任何東西跑得夠久去踩到。
##   4. 本次新涵蓋到什麼(以下皆為本次實際觀測到的,不是推測):
##      [method _apply_safety_filter] 描述的「不自殺」規則本身已被證明有效
##      (真回合 1 零死亡,對照 story-019 的「第 1 回合就死一人」)；
##      [method BattleController.end_unit_turn] 第一次被這支測試實際呼叫並
##      驗證;[method BattleController.resolve_forced_discard] 第一次被這支
##      測試實際呼叫並驗證,棋局因此第一次真正跨越回合 1/回合 2 的邊界 ——
##      跨回合的行動旗標重置([method TurnOrder.advance_faction])與回合順序
##      遞迴這兩條,在這個真回合 2 裡第一次被實際執行到;真回合 2 裡敵方確實
##      開始推進(E1 從開局 (10,0) 走到 (4,0) 再走到 (1,0)),我方也第一次真
##      的打中敵人(E4 32→21,掉 11 點 —— 對照 story-019 全程敵方零受傷);
##      [method _play_faction_turn_via_ai] 原本「不管有沒有真的做事都當作有
##      進度」的舊 bug 已修正(見該方法自己的 doc comment)。
##   5. 仍然沒涵蓋什麼:只走了 2 個回合,仍遠低於
##      [code]design/gdd/vertical-slice-level-01.md[/code] Tuning Knobs 表
##      「預期回合數」列自己訂的 4~6(該列原文:「若實測明顯偏離,先調敵方
##      數值/地圖尺寸,而非判定為玩家技術問題」)—— 更長的對局仍然沒有被
##      測過。長局才會出現的狀態累積(CardModifier 的 remaining_turns 多次
##      遞減、好感度池累積多回合的變化、是否會再次撞上強制棄牌並正確連續
##      解決多次)仍是零防線 —— [method _resolve_any_pending_discard] 目前
##      只被實際驗證「解決一次」這個情境。
extends GdUnitTestSuite


var _host_snap: CursorHostSnapshot = null


func before_test() -> void:
	_host_snap = CursorHostSnapshot.capture()


func after_test() -> void:
	# Restore shared CursorStateHost Autoload state; see tests/helpers/cursor_host_snapshot.gd
	_host_snap.restore()


## AC-2 的上限 —— 刻意遠大於下方「實測」段落記下的真實量測值(見
## test_real_level_battle_reaches_a_terminal_outcome() 內的 AC-1+AC-2 斷言註解),
## 不是用猜的。觸發這個上限時,下方 AC-1+AC-2 的斷言會明確 FAILED(outcome() 仍是
## ONGOING),不會讓迴圈默默跑完後測試照樣綠燈。
##
## 🔴 2026-10-16 收尾:story-020 最終實測 round_count == 2,10 是刻意保留的餘裕 ——
## 不要把它改小貼著 2,那樣會讓這道「上限真的能攔到異常」的把關名存實亡。
const _ROUND_CAP: int = 10


## story-062:全套內「卡死」把關的常駐 mutant。覆寫 [method BattleScreen._end_faction_phase_pressed]
## 為什麼都不做 —— 模擬「敵我雙方都無法再推進」(檔頭記載過的強制棄牌閘門卡死那類缺陷)。
## 宣告在本檔而非 helper 內,因為它只服務下方的敏感度證明。
class _MutantNeverAdvancesPhase extends BattleScreen:
	func _end_faction_phase_pressed() -> void:
		pass


func test_real_level_battle_reaches_a_terminal_outcome() -> void:
	# Arrange
	var driver: RealBattleDriver = RealBattleDriver.new(self)
	var instance: BattleScreen = driver.load_battle_screen_real()

	# Assert — 開局防誤報:真實 vs01 名冊是 5 對 5(grep -v "^#"
	# assets/data/units/vs01_roster.txt | awk -F, '{print $3}' | sort | uniq -c),
	# 且還沒有人採取任何行動前,outcome() 不得已經不是 ONGOING。
	driver.assert_opening_state(instance)

	# Act — 逐回合推進(story-062:迴圈本體已移到共用驅動 RealBattleDriver.run_battle(),
	# 與效能檢查呼叫同一份)。我方全部透過 AC-3 要求的真實入口 click_tile() 驅動;敵方透過
	# AC-4 要求的真實畫面入口 _end_faction_phase_pressed() 驅動。
	var result: Dictionary = await driver.run_battle(instance, _ROUND_CAP)
	var round_count: int = result["round_count"]
	var elapsed_msec: int = result["elapsed_msec"]
	var player_units_at_start: Array[Unit] = result["player_units"]
	var enemy_units_at_start: Array[Unit] = result["enemy_units"]

	# 🔴 診斷輸出 —— 管理者 2026-10-16 要求「第 1 回合到底發生了什麼」必須留得下來
	# 查證,不得只留結論。刻意保留在檔案裡,不要刪:逐人 code_name + HP + 存活狀態、
	# 最終 round_count、最終 outcome()。
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
	# 判定函式與敏感度證明共用同一個 RealBattleDriver.is_terminal_outcome()。
	#
	# 🔴 story-020 最終實測結果(2026-10-16,零 RNG 故完全決定性):乙在真回合 2 陣亡,
	# 座標證據顯示乙全程未移動,是被推進到近身的敵人打死,完全落在
	# _apply_safety_filter() 自己揭露的範圍限制內(見該方法 doc comment,現於
	# tests/helpers/real_battle_driver.gd)。(後來內容成長,同一場戰鬥現為 6 回合。)
	#
	# 🔴 中途曾有版本卡在 round_count == 10 == _ROUND_CAP、outcome() 仍是 ONGOING ——
	# 根因是 CardDeck 強制棄牌閘門鎖死敵我雙方,靠 _resolve_any_pending_discard()
	# 呼叫遊戲【已經提供】的 BattleController.resolve_forced_discard() 解除。
	assert_bool(RealBattleDriver.is_terminal_outcome(instance._controller.outcome())).is_true()

	# story-062:原本此處有一條牆鐘耗時上限斷言(story-019/020 AC-5)。它量的是真實牆鐘,
	# 耗時隨機器時段 2~3 倍浮動,使全套無故變紅,故已移到 tests/perf/
	# (manager ruling 2026-11-17,方案 A)。elapsed_msec 仍印在上方診斷輸出供看趨勢。
	# 卡死偵測不依賴時間:由 _ROUND_CAP + 上方 outcome 斷言 + 下方敏感度證明把關。


## story-062 AC5 —— 常駐敏感度證明:移除牆鐘斷言後,「戰鬥卡死」仍會被抓到。
## 證明的是【判定函式本身】(RealBattleDriver.is_terminal_outcome)抓得到卡死,不是在測 mutant。
## 不依賴任何時間。
##
## 🔴 不可證項(逐條寫理由):perf 檔的 30000 ms 中位數門檻【無法】在全套內做敏感度證明 ——
## 證明需要刻意放慢戰鬥,只能靠真實等待(拖慢全套)或假時鐘(改動被測物),屬
## test-standards 類 D「唯一有意義的注入點在受限範圍外」。該門檻的有效性改由
## tests/perf/README.md 的基準值與一次性手動驗證佐證,不算常駐證明。
func test_sensitivity_proof_stuck_battle_is_caught() -> void:
	# Arrange — set_script() 先於 add_child() 與任何屬性設定(test-standards 陷阱一)
	var driver: RealBattleDriver = RealBattleDriver.new(self)
	var instance: BattleScreen = driver.load_battle_screen_real(_MutantNeverAdvancesPhase)
	driver.assert_opening_state(instance)

	# Act
	var result: Dictionary = await driver.run_battle(instance, _ROUND_CAP, false)

	# Assert
	assert_int(result["round_count"]).is_equal(_ROUND_CAP)
	assert_int(result["outcome"]).is_equal(BattleState.Outcome.ONGOING)
	assert_bool(RealBattleDriver.is_terminal_outcome(result["outcome"])).is_false()
