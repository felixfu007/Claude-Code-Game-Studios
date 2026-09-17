# BattleScreen 的「敵方階段逐步演出」跨幀驅動整合測試——
# story-018-enemy-phase-stepped-playback.md AC-E3 / AC-E4。
#
# 📌 本檔落點是 tests/integration/ui/battle/(鏡射 src/ui/battle/),與這支螢幕
# 既有的整合測試 battle_screen_card_deck_wiring_test.gd 同一個目錄 —— 工作單本文
# 原寫 tests/integration/gameplay/battle/,但那個路徑鏡射的是 src/gameplay/battle/
# (BattleController 的家),不是這支檔案(src/ui/battle/battle_screen.gd)的既有
# 整合測試慣例。落點以「與既有同類測試同目錄」為準,已在 battle_screen.gd 的
# _end_faction_phase_pressed() 註解裡註記這個落點差異。
#
# 🔴 本檔案 I/O 使用揭露(.claude/rules/test-standards.md「單元測試不得碰檔案系統」
# 節,2026-09-16 管理者裁決的甲/乙兩類明文例外;本檔屬 Integration 型,主動比照其
# 揭露義務):
#
#   甲類(讀 assets/data/ 底下已進版控的真實資料檔)—— 每一條測試都
#   load()/instantiate() 真實的 BattleScreen.tscn,其 _ready() 會讀
#   vs01_terrain.txt / vs01_roster.txt / vs01_affinity_links.txt / vs01_cards.txt /
#   vs01_card_text.txt。唯讀,不寫入任何檔案,沿用
#   battle_screen_card_deck_wiring_test.gd 既有同名手法的先例。理由同該檔:這是
#   本專案唯一能觀察「_ready() 完整效果」的方式,純函式測試無法涵蓋節點樹的
#   建構結果。vs01 名冊有 5 個敵方單位(見 assets/data/units/vs01_roster.txt),
#   足以滿足 AC-E3「敵方單位 ≥ 2」的前提,且 GreedyTacticalAI 決策為確定性
#   (無 RNG,見專案級禁令 rng_in_combat_settlement),同一份資料檔每次執行結果
#   一致。
#
# ⚠️ 本檔的整合測試涉及真實的 get_tree().create_timer() 暫停(battle_screen.gd
# 的 ENEMY_STEP_PAUSE_SECONDS = 0.3 秒),因此涉及跨幀等待的測試會花費真實秒數
# 的執行時間(vs01 五個敵人,粗估數秒)——這是測試「真的跨幀播放」這件事本身
# 無法迴避的代價,不是效能缺陷。
#
# 不建立額外 Node(除了場景本身的節點樹)。每個實例都用 auto_free() +
# add_child(),GdUnit4 會在測試結束後自動釋放,不留孤兒節點。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"


# ---- 突變子類別(僅供下方 test_sensitivity_proof_* 使用,Case A:進樹前換腳本,
# 已由 2026-09-17 探針驗證安全 —— 見 tests/unit/ui/menu/battle_menu_layout_test.gd
# 既有的同技巧先例)----------------------------------------------------------

# 模擬「story-018 之前的舊寫法」:一次跑完 run_enemy_phase(),完全同步、不含任何
# await —— 用來證明 AC-E3 的跨幀斷言真的會抓到「敵方階段其實在同一格畫面內跑完」
# 這個 story 本身要修的問題。
class _MutantSynchronousEnemyPhase extends BattleScreen:
	func _end_faction_phase_pressed() -> void:
		if _controller.phase() != BattleController.Phase.PLAYER_INPUT:
			return
		_diagnostic_enemy_acting_process_frame_count = 0
		_controller.end_faction_phase()
		_controller.run_enemy_phase()
		_refresh_view()


# 模擬「相位守衛被拿掉」的重入防護缺陷。注意:_controller.end_faction_phase()
# 自己在 BattleController 內已有 no-op 防呆(不是 PLAYER_INPUT 就不做事),
# 所以這支間諜要證明的不是「TurnOrder 被異常呼叫兩次」,而是「兩個逐步迴圈同時
# 對同一個 controller 跑」——後者才是這支螢幕自己的相位守衛真正在擋的東西。
# 刻意保留 _diagnostic_step_enemy_phase_call_count 的遞增(與真正版本同一行為),
# 只拿掉相位守衛本身,這樣兩者才是「只有一個變因不同」的乾淨對照。
class _MutantSkipsPhaseGuard extends BattleScreen:
	func _end_faction_phase_pressed() -> void:
		_controller.end_faction_phase()
		while _controller.phase() == BattleController.Phase.ENEMY_ACTING:
			_controller.step_enemy_phase()
			_diagnostic_step_enemy_phase_call_count += 1
			_refresh_view()
			if _controller.phase() != BattleController.Phase.ENEMY_ACTING:
				return
			await get_tree().create_timer(BattleScreen.ENEMY_STEP_PAUSE_SECONDS).timeout
			if not is_instance_valid(self):
				return


# ---- AC-E3: 敵方階段跨越 >= 2 個 _process 幀 -----------------------------------

func test_stepped_enemy_phase_spans_at_least_two_process_frames() -> void:
	# Arrange
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)

	# Act — 等整個逐步播放跑完(await 一個內部含 await 的方法會等到它完全結束,
	# 包含它自己每一次 get_tree().create_timer(...).timeout 的暫停)
	await instance._end_faction_phase_pressed()

	# Assert
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.PLAYER_INPUT)
	assert_int(instance.diagnostic_enemy_acting_process_frame_count()).is_greater_equal(2)


# 敏感度證明——用「完全同步、一次跑完」的間諜子類別,證明上面那條測試的斷言
# (跨幀數 >= 2)真的會抓到「敵方階段其實在同一格畫面內跑完」這個 story 本身
# 要修的問題。
func test_sensitivity_proof_frame_span_test_catches_a_synchronous_mutant() -> void:
	# Arrange
	var instance: BattleScreen = load(_SCENE_PATH).instantiate()
	instance.set_script(_MutantSynchronousEnemyPhase)
	auto_free(instance)
	add_child(instance)

	# Act — 間諜版本完全同步,呼叫端的 await 不會真的讓出任何一幀
	await instance._end_faction_phase_pressed()

	# Assert — 與真正版本(>= 2)相反:舊寫法完全沒有跨幀機會
	assert_int(instance.diagnostic_enemy_acting_process_frame_count()).is_equal(0)


# ---- AC-E4: 敵方階段進行中重複按結束回合鍵不造成第二次階段推進(可重入防護)----

func test_reentrant_end_phase_press_immediately_after_first_is_a_noop() -> void:
	# Arrange
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)

	# Act — 不 await 第一次呼叫(比照 _input() 實際呼叫方式——見該函式呼叫端,
	# _input() 本身不是 async,不可能 await 這個呼叫)。第一次呼叫會同步跑到
	# 它自己的第一個 await 之前才讓出控制權:此時 _controller.end_faction_phase()
	# 與第一個 step_enemy_phase() 都已經同步執行完畢
	instance._end_faction_phase_pressed()
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).is_equal(1)

	# 立刻同步再呼叫一次,模擬「敵方階段跨幀播放中,玩家又按了一次結束回合」
	instance._end_faction_phase_pressed()

	# Assert — 第二次呼叫被相位守衛擋下(這時 phase() 已經是 ENEMY_ACTING,
	# 不是 PLAYER_INPUT):step_enemy_phase() 沒有被多呼叫一次。
	# 🔴 刻意不用 order.units_with_flags_remaining().size() 當觀察量——撰寫本檔
	# 過程中實測證明那個量在這裡不可靠:一個單位只花掉一個旗標時仍會留在
	# 「還有旗標」清單裡,即使它已經被 _process_enemy_unit() 呼叫過。
	assert_int(instance.diagnostic_step_enemy_phase_call_count()).is_equal(1)
	assert_int(instance._controller.phase()).is_equal(BattleController.Phase.ENEMY_ACTING)


# 敏感度證明——用「拿掉相位守衛」的間諜子類別,證明上面那條測試的斷言
# (第二次呼叫不會多推進任何單位)真的會抓到「兩個逐步迴圈同時對同一個 controller
# 跑」這個重入缺陷。兩個完全獨立的場景實例(真正版 / 間諜版)各自「同一幀內按
# 兩次結束回合鍵」,比較各自剩餘未推進的敵方單位數。
func test_sensitivity_proof_reentrancy_test_catches_a_mutant_that_skips_the_phase_guard() -> void:
	# Arrange
	var real_instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(real_instance)

	var mutant_instance: BattleScreen = load(_SCENE_PATH).instantiate()
	mutant_instance.set_script(_MutantSkipsPhaseGuard)
	auto_free(mutant_instance)
	add_child(mutant_instance)

	# Act — 兩個實例都各自「同一幀內按兩次結束回合鍵」,都不 await
	real_instance._end_faction_phase_pressed()
	real_instance._end_faction_phase_pressed()
	mutant_instance._end_faction_phase_pressed()
	mutant_instance._end_faction_phase_pressed()

	# Assert — 用 diagnostic_step_enemy_phase_call_count() 而非
	# units_with_flags_remaining().size():後者曾在本測試撰寫過程中被實測證明是
	# 錯的觀察量——一個單位在單次 _process_enemy_unit() 只花掉一個旗標時仍會
	# 留在「還有旗標」清單裡,所以「剩餘數量」量不出「呼叫過幾次」。
	# 正常版只有一個逐步迴圈在跑,兩次按鍵後 step_enemy_phase() 只被呼叫 1 次;
	# 間諜版兩個迴圈同時在跑,兩次按鍵後被呼叫 2 次。
	assert_int(real_instance.diagnostic_step_enemy_phase_call_count()).is_equal(1)
	assert_int(mutant_instance.diagnostic_step_enemy_phase_call_count()).is_equal(2)
