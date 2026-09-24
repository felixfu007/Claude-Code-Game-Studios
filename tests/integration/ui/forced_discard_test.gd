# Story U-015（`production/epics/card-play-interface/story-u015-forced-discard.md`）
# —— 強制棄牌 S4(無法收起、取消鍵無效、選單亦拒絕開啟)。
#
# 型別:Integration,證據等級 BLOCKING(依 story 自己的 Test Evidence 節)。
#
# 沿用既有慣例：真正 load()/instantiate() BattleScreen.tscn 並 add_child()（觸發真實
# _ready()),之後用「換掉 CardDeck」的既有手法（同
# tests/integration/ui/card_confirm_panel_test.gd 的 _install_session()）建立決定性
# （非隨機）的強制棄牌情境——_ready() 用 rng=null 的真實時間種子洗牌，寫死抽卡結果
# 會違反 Determinism 規則；改用一副 6 張已知牌的 CardDeck，透過真實
# CardDeck.deal_opening_hand() + CardDeck.draw_for_turn() 這兩個既有公開方法驅動
# 到 has_pending_discard()==true，不重新實作那段邏輯。
#
# AC-M16 的跨檔案驗證（手牌側觸發、選單側拒絕）另外驅動一個真正的 BattleMenu 實例，
# 把它的 forced_discard_in_progress_check 指到同一個 BattleController 的
# has_pending_discard()——這是 tests/integration/ui/menu/battle_menu_gating_test.gd
# 既有的 test_rejection_appearance_differs_between_authoritative_write_and_forced_discard
# 自己的 doc comment 點名要補的那一塊（該測試當時用假的 func() -> bool: return true，
# 自陳「U-015 has not wired a real forced-discard check yet」）。
extends GdUnitTestSuite


const _BATTLE_SCREEN_SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _BATTLE_MENU_SCENE_PATH: String = "res://src/ui/menu/BattleMenu.tscn"


func _fresh_instance() -> BattleScreen:
	var instance: BattleScreen = auto_free(load(_BATTLE_SCREEN_SCENE_PATH).instantiate())
	add_child(instance)
	return instance


func _real_pressed_event(action: StringName) -> InputEventKey:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var duplicated: InputEventKey = (event as InputEventKey).duplicate()
			duplicated.pressed = true
			return duplicated
	return null


## 建構一副 6 張已知甲類卡的牌庫——池中恰有 6 張，開局手牌 5 張
## (CardDeck.OPENING_HAND_SIZE)用掉 5 張、剩 1 張，回合開始的
## CardDeck.draw_for_turn() 再抽走最後 1 張，讓手牌恰好達到 6 張、觸發
## CardDeck._pending_discard = true。全部使用已知、非隨機的 Card 工廠函式，
## 不讀 assets/data/ 任何檔案。
func _build_six_card_deck() -> CardDeck:
	var cards: Array[Card] = []
	for i: int in range(6):
		cards.append(Card.new_temporary_stat_modifier("test_discard_card_%d" % i, 1, 0, 1))
	return CardDeck.new(cards)


## 換掉 [param instance]._state 的 CardDeck，並驅動它進入強制棄牌態——只呼叫
## CardDeck 既有的公開方法（deal_opening_hand()/draw_for_turn()），不重新實作
## GDD Core Rules 二那段判斷邏輯。回傳新換上的 CardDeck 供呼叫端進一步檢查。
func _install_forced_discard_state(instance: BattleScreen) -> CardDeck:
	var deck: CardDeck = _build_six_card_deck()
	instance._state.attach_card_deck(deck)
	deck.deal_opening_hand()
	assert_int(deck.hand_size()).append_failure_message(
		"PRECONDITION: 開局手牌應該恰好 5 張（OPENING_HAND_SIZE）"
	).is_equal(5)
	deck.draw_for_turn()
	assert_bool(deck.has_pending_discard()).append_failure_message(
		"PRECONDITION: 手牌已滿時再抽一張，應該觸發 has_pending_discard()"
	).is_true()
	assert_int(deck.hand_size()).append_failure_message(
		"PRECONDITION: 觸發強制棄牌時手牌應該是 6 張"
	).is_equal(6)
	return deck


# ─── 系統偵測 has_pending_discard() 自動開啟 Z2、無法收起 ──────────────────────


func test_hand_reaching_six_cards_forces_z2_open_and_uncollapsible() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	_install_forced_discard_state(instance)

	# Act — 系統偵測（本測試用手動呼叫 _refresh_view() 模擬「畫面下一次更新」，
	# 對應真實遊戲裡 _end_faction_phase_pressed() 的 enemy-phase 迴圈本身已經
	# 在每一步後呼叫 _refresh_view() 這件事——見任務報告）
	instance._refresh_view()

	# Assert — Z2 強制展開
	assert_bool(instance._hand_bar.diagnostic_is_expanded()).append_failure_message(
		"強制棄牌態應該讓 Z2 展開，不需要玩家按 battle_open_hand"
	).is_true()
	assert_bool(instance._hand_bar.diagnostic_is_forced_discard()).append_failure_message(
		"HandBar 應該知道自己現在是強制棄牌態，不是一般 S1 自願開手牌"
	).is_true()

	# Act — 嘗試用 battle_open_hand 收起（一般 S1 的收合鍵）
	instance._input(_real_pressed_event(&"battle_open_hand"))
	instance._refresh_view()

	# Assert — 仍然展開，無法收起
	assert_bool(instance._hand_bar.diagnostic_is_expanded()).append_failure_message(
		"強制棄牌態下按 battle_open_hand 不應該收起 Z2（🔴 無法收起）"
	).is_true()
	assert_bool(instance._controller.has_pending_discard()).append_failure_message(
		"battle_open_hand 不應該以任何方式解除強制棄牌態"
	).is_true()


## 2026-09-24 管理者裁決「補一條測試」——本 story 順手修掉的
## HandBar._rebuild_slots() 迴圈邊界 bug（原本 `for i in range(_max_slots)`
## 只建 5 個 Panel，改成 `for i in range(maxi(_max_slots, _slot_kinds.size()))`）
## 沒有專屬測試，只被 test_discarding_one_card_... 間接碰到（棄的是索引 0 那張，
## 從未觸及索引 5）。
##
## 🔴 裁決理由（管理者原話摘要，逐字寫進這裡）：**強制棄牌唯一的觸發情境就是
## 手牌剛好 6 張**——這個 bug 與 S4 不是「剛好相鄰」，是同一個情境的兩面。若
## 這個迴圈邊界複發，玩家會被迫棄牌、卻有一張（索引 5，第 6 張）選不到，
## 而 S4 的取消鍵又明文無效——沒有退路，直接卡死整場戰鬥。
##
## 🔴 為什麼既有的 diagnostic_slot_is_filled(5) 抓不到這個 bug（讀過
## hand_bar.gd 本體才知道，不是猜的）：那是純計算式
## `index < _slot_kinds.size()`，從來不檢查 [member HandBar._slot_nodes]
## 裡實際有沒有對應的 Panel 節點——即使舊的、有 bug 的迴圈邊界只建了 5 個
## Panel，對索引 5 呼叫 diagnostic_slot_is_filled(5) 依然會回報 true（純數字
## 比較，5 < 6）。本測試改用本 story 新增的 diagnostic_slot_node_count()
## （直接讀 _slot_nodes.size()）來對準這個 bug 真正的所在位置。
##
## 🔴 紅燈驗證：已實際執行（暫時把 hand_bar.gd 的 _rebuild_slots() 迴圈邊界
## 從 maxi(_max_slots, _slot_kinds.size()) 改回 _max_slots，重跑全套，本測試
## FAILED，具名輸出見任務報告；還原後重跑轉綠）。
func test_sixth_card_has_a_selectable_slot_during_forced_discard() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	_install_forced_discard_state(instance)
	instance._refresh_view()

	# Assert — 第 6 張（索引 5）真的有一個 Panel 節點，不是只有邏輯上「算作
	# 存在」。這是本測試要釘住的核心斷言——修正前這裡會量到 5，不是 6。
	assert_int(instance._hand_bar.diagnostic_slot_node_count()).append_failure_message(
		(
			"手牌 6 張時應該建出 6 個 Panel 節點，實得 %d——第 6 張若沒有節點，" +
			"玩家會看不到它、也選不到它，而強制棄牌又不能取消，直接卡死"
		) % instance._hand_bar.diagnostic_slot_node_count()
	).is_equal(6)

	# Assert — 游標真的能移動到索引 5（第 6 張），不是卡在最後一個有節點的格子
	for _i: int in range(5):
		instance._hand_bar.move_cursor(1)
	assert_int(instance._hand_bar.diagnostic_cursor_index()).append_failure_message(
		"游標應該能移動到索引 5（第 6 張），實得 %d"
		% instance._hand_bar.diagnostic_cursor_index()
	).is_equal(5)

	# Act — 端到端證明：真的能棄掉第 6 張（索引 5），不是只有游標數字對而已
	var hand_before: Array[Card] = instance._state.card_deck().hand()
	var sixth_card: Card = hand_before[5]
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert
	assert_bool(instance._controller.has_pending_discard()).append_failure_message(
		"棄掉第 6 張後應該解除強制棄牌態"
	).is_false()
	assert_bool(instance._state.card_deck().used().has(sixth_card)).append_failure_message(
		"游標停在索引 5 時按確認，被棄的應該正是第 6 張卡"
	).is_true()


# ─── 取消鍵在此狀態無效，且拒絕須可觀測 ─────────────────────────────────────


func test_cancel_key_rejected_during_forced_discard_with_observable_feedback() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	_install_forced_discard_state(instance)
	instance._refresh_view()
	var rejected_count_before: int = instance.diagnostic_forced_discard_cancel_rejected_count()

	# Act
	instance._input(_real_pressed_event(&"battle_cancel"))

	# Assert — 取消鍵完全無效：不解除棄牌狀態
	assert_bool(instance._controller.has_pending_discard()).append_failure_message(
		"取消鍵在強制棄牌態必須無效——不可以解除棄牌狀態"
	).is_true()

	# Assert — 拒絕須可觀測（P-F2），兩個獨立訊號：
	# (1) 診斷計數器證明「拒絕分支」真的執行過，不是「沒有任何分支處理這個按鍵」
	assert_int(instance.diagnostic_forced_discard_cancel_rejected_count()).append_failure_message(
		"battle_cancel 應該被明確攔截並計入拒絕次數，而非被靜默忽略"
	).is_equal(rejected_count_before + 1)
	# (2) HandBar 的持久提示文字全程可見，這是玩家看得到的那一半
	assert_bool(instance._hand_bar.diagnostic_caption_visible()).append_failure_message(
		"強制棄牌態應該持續顯示提示文字，讓玩家看得出「這不是按錯」"
	).is_true()
	assert_str(instance._hand_bar.diagnostic_caption_text()).append_failure_message(
		"提示文字應該是強制棄牌專用的文案，不是 S5 的「不可用」"
	).is_equal(HandBar.TEXT_FORCED_DISCARD)


# ─── 棄掉一張後解除強制棄牌態、回到一般流程 ─────────────────────────────────


func test_discarding_one_card_clears_pending_discard_and_returns_to_normal_flow() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	var deck: CardDeck = _install_forced_discard_state(instance)
	instance._refresh_view()
	var hand_before: Array[Card] = deck.hand()
	var cursor_index: int = instance._hand_bar.diagnostic_cursor_index()
	var card_to_discard: Card = hand_before[cursor_index]

	# Act — 游標預設停在索引 0，直接確認棄牌
	instance._input(_real_pressed_event(&"battle_confirm"))

	# Assert — 棄牌成功，強制棄牌態解除
	assert_bool(instance._controller.has_pending_discard()).append_failure_message(
		"棄掉一張後應該解除強制棄牌態"
	).is_false()
	assert_int(deck.hand_size()).append_failure_message(
		"棄牌後手牌應該回到 5 張"
	).is_equal(5)
	assert_bool(deck.used().has(card_to_discard)).append_failure_message(
		"被棄的應該是游標所在那一張，不是隨便一張——GDD Edge Cases「不得由系統代選」"
	).is_true()
	assert_bool(deck.hand().has(card_to_discard)).append_failure_message(
		"被棄的那張不應該還留在手牌裡"
	).is_false()

	# Assert — 回到一般流程：不再是強制棄牌態，Z2 應該收合回去
	instance._refresh_view()
	assert_bool(instance._hand_bar.diagnostic_is_forced_discard()).append_failure_message(
		"解除強制棄牌態後，HandBar 不應該再自認是強制棄牌態"
	).is_false()
	assert_bool(instance._hand_bar.diagnostic_is_expanded()).append_failure_message(
		"沒有任何一般 S1 選牌在進行（_card_selecting_from_hand 從未被設 true），" +
		"解除強制棄牌態後 Z2 應該收合回 Z1"
	).is_false()


# ─── AC-M16:選單拒絕開啟（跨檔案） ──────────────────────────────────────────


func test_battle_menu_rejected_during_forced_discard() -> void:
	# Arrange — 手牌側：真的達到強制棄牌態
	var instance: BattleScreen = _fresh_instance()
	_install_forced_discard_state(instance)

	# Arrange — 選單側：真正的 BattleMenu 實例，注入指向同一個 BattleController
	# 的 has_pending_discard()（不是假的 func() -> bool: return true）
	var menu: BattleMenu = auto_free(load(_BATTLE_MENU_SCENE_PATH).instantiate())
	add_child(menu)
	# 🔴 一個剛 instantiate() 的 BattleMenu 預設 visible=true（is_open() 直接讀
	# Control.visible，見 battle_menu.gd 該方法自己的 doc comment）——這與
	# tests/integration/ui/menu/battle_menu_gating_test.gd 既有的權威寫入拒絕
	# 測試撞到的同一件事完全相同（該檔逐字自陳「it was red until this line was
	# added」,解法是先呼叫一次 close() 建立已知的「關閉」前提,本測試照抄同一手法）。
	menu.close()
	menu.forced_discard_in_progress_check = Callable(instance._controller, "has_pending_discard")

	# Act
	var result: BattleMenu.OpenResult = menu.open()

	# Assert
	assert_int(result).append_failure_message(
		"強制棄牌進行中按 battle_menu，選單應該拒絕開啟（AC-M16）"
	).is_equal(BattleMenu.OpenResult.REJECTED_FORCED_DISCARD)
	assert_bool(menu.is_open()).append_failure_message(
		"被拒絕的 open() 不應該讓選單變成開啟狀態"
	).is_false()


## AC-M16 後半——拒絕外觀須與 AC-M8（權威寫入拒絕）可區分。
## 🔴 與 tests/integration/ui/menu/battle_menu_gating_test.gd 既有的
## test_rejection_appearance_differs_between_authoritative_write_and_forced_discard
## 不同:那條測試兩側都用手動注入的 func() -> bool 假 Callable,自己的 doc comment
## 明講「U-015 has not wired a real forced-discard check yet」。本測試的強制棄牌側
## 改用真正達到 has_pending_discard()==true 的 BattleController,驗證的是「真實
## 情境走到這裡,選單真的能分辨」,不是機制本身(機制已由那條既有測試證明過)。
func test_forced_discard_rejection_appearance_distinguishable_from_authoritative_write_rejection() -> void:
	# Arrange
	var instance: BattleScreen = _fresh_instance()
	_install_forced_discard_state(instance)

	var discard_menu: BattleMenu = auto_free(load(_BATTLE_MENU_SCENE_PATH).instantiate())
	add_child(discard_menu)
	discard_menu.close()  # 見 test_battle_menu_rejected_during_forced_discard 的說明
	discard_menu.forced_discard_in_progress_check = Callable(instance._controller, "has_pending_discard")

	var authoritative_menu: BattleMenu = auto_free(load(_BATTLE_MENU_SCENE_PATH).instantiate())
	add_child(authoritative_menu)
	authoritative_menu.close()
	authoritative_menu.authoritative_write_in_progress_check = func() -> bool: return true

	# Act
	var discard_result: BattleMenu.OpenResult = discard_menu.open()
	var authoritative_result: BattleMenu.OpenResult = authoritative_menu.open()

	# Assert — 可區分：不同的 enum 值、不同的訊息文字
	assert_int(discard_result).is_equal(BattleMenu.OpenResult.REJECTED_FORCED_DISCARD)
	assert_int(authoritative_result).is_equal(BattleMenu.OpenResult.REJECTED_AUTHORITATIVE_WRITE)
	assert_int(discard_result).append_failure_message(
		"強制棄牌與權威寫入兩種拒絕必須是不同的 enum 值"
	).is_not_equal(authoritative_result)
	assert_str(BattleMenu.REJECTION_MESSAGE_FORCED_DISCARD).append_failure_message(
		"兩種拒絕的訊息文字必須不同——共用同一段文字會違反 AC-M16「須可區分」的要求"
	).is_not_equal(BattleMenu.REJECTION_MESSAGE_AUTHORITATIVE_WRITE)
