# CardPlaySession（src/gameplay/cards/card_play_session.gd）的整合測試 ——
# Story 005:打牌四步流程的資料層（取消零寫入 + 預覽串接）。
#
# production/epics/skill-card-system/story-005-play-session.md：把 Story
# 001（甲類/CardModifier）、003（CardDeck）、004（丙類/PermanentAffinityWriteRules/
# AffinityWritePort）串成一次完整的打牌：開手牌 → 選牌 → 選對象 → 確認,
# 第 2~4 步任一時點取消都不留任何痕跡。
#
# 放在 tests/integration/ 而非 tests/unit/ 是刻意的（本檔跨越 CardDeck +
# BattleState/Unit + PermanentAffinityWriteRules 三個既有子系統,且 AC-14 的
# 攻擊阻擋測試還額外構造了真正的 BattleController/TurnOrder）——符合
# coding-standards.md 的 Integration 分類。tests/gdunit4_runner.gd 的
# FORCED_ARGS 已同時列 tests/unit 與 tests/integration（Story 009 修畢），
# 動手前已依工作單指示重新確認過。
#
# 🔴 兩項本檔刻意不驗、且明文登記的限制（見 story-005 工作單「兩件會影響設計、
# 而且不會報錯的事」與 EPIC.md）：
# ① authoritative_write_in_progress 在 src/ 裡零實作 —— CardPlaySession.open_hand()
#   接受一個注入的布林述詞當替身,本檔驗的是「閘門有接、拒絕同步可觀測」,
#   不是「旗標真的會變真」。
# ② 「打牌介面開啟中不得發起攻擊」的另一半 —— CardPlaySession.is_open() 是這條
#   規則的權威訊號,但 src/gameplay/battle/battle_controller.gd 目前完全不查詢
#   它。本檔證明「若呼叫端在打真正的攻擊路徑前遵守 not session.is_open() 這個
#   契約,攻擊真的被擋下」,但沒有把這個查詢接進 BattleController 本身 ——
#   那是未來介面/整合 story 的工作,與 CardDeck 尚未接進戰鬥迴圈是同一種
#   「已登記、非靜默」的缺口,不計入本 story 完成度。
#
# 全鏈路（Card/CardDeck/CardModifier/Unit/BattleState/AffinityLink/
# PermanentAffinityWriteRules/AffinityWritePort/TurnOrder/BattleController/
# CardPlaySession)都是 RefCounted,不建立任何 Node,不會留下孤兒節點。
extends GdUnitTestSuite


# ---- 共用測試資料 -----------------------------------------------------------

const P1: int = 1  # 甲 — atk 10 / def 3,S2p 的合法起點之一（連 P2）
const P2: int = 2  # 乙 — S2p 的合法起點,連 P1 與 P3 兩條線
const P3: int = 3  # 丙 — S2p 的合法起點之一（連 P2）
const ENEMY: int = 9


func _roster_lines() -> Array[String]:
	return [
		"%d,P1,PLAYER,20,10,3,1,1,1,0,0" % P1,
		"%d,P2,PLAYER,20,8,2,1,1,1,5,0" % P2,
		"%d,P3,PLAYER,20,8,2,1,1,1,6,0" % P3,
		"%d,E1,ENEMY,20,5,3,1,1,1,1,0" % ENEMY,
	]


func _build_state() -> BattleState:
	return BattleState.create(PackedStringArray(), "\n".join(_roster_lines()))


func _make_link(a: int, b: int, polarity: AffinityLink.Polarity) -> AffinityLink:
	var link: AffinityLink = AffinityLink.new()
	link.unit_a = a
	link.unit_b = b
	link.polarity = polarity
	link.amp = 1
	return link


# P1-P2 與 P2-P3 各一條關係線;P1、P3 彼此沒有直接連線 —— 用來驗 S2q 的窄化
# （design/ux/skill-card-play.md:「垂直切片通常僅 1 個」)。
func _default_links() -> Array[AffinityLink]:
	return [
		_make_link(P1, P2, AffinityLink.Polarity.POSITIVE),
		_make_link(P2, P3, AffinityLink.Polarity.NEGATIVE),
	]


func _build_deck(cards: Array[Card]) -> CardDeck:
	var deck: CardDeck = CardDeck.new(cards, RandomNumberGenerator.new())
	deck.deal_opening_hand()
	return deck


## 記錄型測試替身,滿足 AffinityWritePort 的 @abstract 契約 —— 沿用
## tests/unit/gameplay/cards/card_permanent_write_test.gd 的既有慣例（calls +
## accepted_count 兩個計數器分開,理由同該檔)。額外加一個 force_rejection,
## 供「confirm() 在埠拒絕時不消耗卡片」那條測試模擬埠拒絕。
class _FakeAffinityWritePort extends AffinityWritePort:
	var calls: Array[Dictionary] = []
	var accepted_count: int = 0
	var force_rejection: Rejection = Rejection.NONE

	func append_record(character_a: int, character_b: int, m: int, source: StringName) -> Rejection:
		calls.append({
			"character_a": character_a,
			"character_b": character_b,
			"m": m,
			"source": source,
		})
		if force_rejection != Rejection.NONE:
			return force_rejection
		accepted_count += 1
		return Rejection.NONE


# ---- AC-5:打出 +3 攻擊增益後,BattleState.preview_damage() 較打牌前 +3 -----

func test_ac5_playing_temporary_stat_modifier_increases_preview_damage_by_card_delta() -> void:
	# Arrange — atk10 - def3 + phi0 = 7,不觸及 max(0,...) 下限,+3 之後應是 10
	var state: BattleState = _build_state()
	var atk_card: Card = Card.new_temporary_stat_modifier("atk_up_3", 3, 0, 2)
	var deck: CardDeck = _build_deck([atk_card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	var damage_before: int = state.preview_damage(P1, ENEMY, 0)

	# Act — 完整四步流程,中間不插入任何額外操作
	assert_bool(session.open_hand()).is_true()
	assert_bool(session.select_card(atk_card)).is_true()
	assert_bool(session.select_target(P1)).is_true()
	assert_bool(session.confirm()).is_true()
	var damage_after: int = state.preview_damage(P1, ENEMY, 0)

	# Assert — 與結算共用同一個私有 helper 的那個查詢,差值逐字為 +3
	assert_int(damage_after).is_equal(damage_before + 3)


# ---- AC-13:確認前取消 → 零寫入(三個取消時點各一條) -------------------------

func test_ac13_cancel_after_selecting_card_leaves_zero_writes() -> void:
	# Arrange — 丙類卡,只選了牌,連第一個對象都還沒選（S1 -> S2p)
	var state: BattleState = _build_state()
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var bond_card: Card = Card.new_permanent_affinity_write("bond_test", P1, P2, 2)
	var deck: CardDeck = _build_deck([bond_card])
	var session: CardPlaySession = CardPlaySession.new(deck, state, _default_links(), write_port)
	session.open_hand()
	assert_bool(session.select_card(bond_card)).is_true()

	# Act — 選牌後取消
	session.cancel()

	# Assert — 零寫入:好感度寫入筆數不變、無任何甲類修正
	assert_int(write_port.calls.size()).is_equal(0)
	for id: int in [P1, P2, P3]:
		assert_int(state.unit_by_id(id).active_modifiers().size()).is_equal(0)
	assert_bool(deck.hand().has(bond_card)).is_true()
	assert_int(deck.used_size()).is_equal(0)


func test_ac13_cancel_after_selecting_first_affinity_target_leaves_zero_writes() -> void:
	# Arrange — 已選第一個對象（S2p -> S2q)
	var state: BattleState = _build_state()
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var bond_card: Card = Card.new_permanent_affinity_write("bond_test", P1, P2, 2)
	var deck: CardDeck = _build_deck([bond_card])
	var session: CardPlaySession = CardPlaySession.new(deck, state, _default_links(), write_port)
	session.open_hand()
	session.select_card(bond_card)
	assert_bool(session.select_target(P1)).is_true()

	# Act — 選對象後取消（第一個已選,尚未選第二個）
	session.cancel()

	# Assert
	assert_int(write_port.calls.size()).is_equal(0)
	assert_int(deck.used_size()).is_equal(0)
	assert_bool(deck.hand().has(bond_card)).is_true()


func test_ac13_cancel_at_confirmation_screen_leaves_zero_writes() -> void:
	# Arrange — 兩個對象都選定,已進入確認畫面（S2q -> S3)
	var state: BattleState = _build_state()
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var bond_card: Card = Card.new_permanent_affinity_write("bond_test", P1, P2, 2)
	var deck: CardDeck = _build_deck([bond_card])
	var session: CardPlaySession = CardPlaySession.new(deck, state, _default_links(), write_port)
	session.open_hand()
	session.select_card(bond_card)
	session.select_target(P1)
	assert_bool(session.select_second_target(P2)).is_true()

	# Act — 確認畫面上取消
	session.cancel()

	# Assert
	assert_int(write_port.calls.size()).is_equal(0)
	assert_int(deck.used_size()).is_equal(0)
	assert_bool(deck.hand().has(bond_card)).is_true()


func test_ac13_cancel_variant_temporary_stat_modifier_leaves_zero_writes() -> void:
	# Arrange — 甲類卡的對照組:選對象後直接進入確認畫面（甲類只有一個目標,
	# 「選對象後」與「確認畫面上」是同一個狀態),確認 AC-13 不是丙類專屬行為。
	var state: BattleState = _build_state()
	var atk_card: Card = Card.new_temporary_stat_modifier("atk_up_3", 3, 0, 2)
	var deck: CardDeck = _build_deck([atk_card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	session.open_hand()
	session.select_card(atk_card)
	assert_bool(session.select_target(P1)).is_true()

	# Act
	session.cancel()

	# Assert
	assert_int(state.unit_by_id(P1).active_modifiers().size()).is_equal(0)
	assert_int(deck.used_size()).is_equal(0)
	assert_bool(deck.hand().has(atk_card)).is_true()


# ---- AC-14(第一半):權威寫入進行中 → 開手牌同步拒絕 --------------------------

func test_ac14_authoritative_write_in_progress_blocks_open_hand_synchronously() -> void:
	# Arrange — 注入的述詞恆真,模擬「權威寫入進行中」（真正的旗標不存在,見檔頭）
	var state: BattleState = _build_state()
	var deck: CardDeck = _build_deck([Card.new_temporary_stat_modifier("c", 1, 0, 1)])
	var write_in_progress: Callable = func() -> bool: return true
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new(), write_in_progress
	)

	# Act
	var opened: bool = session.open_hand()

	# Assert — 呼叫的下一行即可斷言,不依賴逾時
	assert_bool(opened).is_false()
	assert_bool(session.is_open()).is_false()


func test_ac14_open_hand_succeeds_when_no_write_in_progress() -> void:
	# Arrange — 控制組:不注入述詞（預設 Callable()),應正常開啟
	var state: BattleState = _build_state()
	var deck: CardDeck = _build_deck([Card.new_temporary_stat_modifier("c", 1, 0, 1)])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)

	# Act
	var opened: bool = session.open_hand()

	# Assert
	assert_bool(opened).is_true()
	assert_bool(session.is_open()).is_true()


# ---- AC-14(另一半):打牌介面開啟中不得發起攻擊 ------------------------------
#
# 見檔頭限制②:本測試證明「若呼叫端在打真正的攻擊路徑前遵守
# not session.is_open()」,攻擊真的被擋下(HP 逐字不變),取消後同一次點擊
# 又真的能命中 BattleController 的真實攻擊路徑(HP 真的下降)——但 BattleController
# 本身尚未內建這道查詢,這一點在檔頭與完成報告都會重申,不算作已完整接線。

func test_hand_open_blocks_a_gate_honoring_caller_from_attacking_and_unblocks_after_cancel() -> void:
	# Arrange — P1(0,0)與敵人(1,0)相鄰,距離 1 落在射程 [1,1] 內
	var state: BattleState = _build_state()
	var order: TurnOrder = TurnOrder.new([P1, P2, P3], [ENEMY])
	var controller: BattleController = BattleController.new(state, order)
	var deck: CardDeck = _build_deck([Card.new_temporary_stat_modifier("c", 1, 0, 1)])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	controller.select_unit(P1)
	var enemy_pos: Vector2i = state.position_of(ENEMY)
	var hp_before: int = state.unit_by_id(ENEMY).hp

	# 這個 lambda 代表「一個遵守本規則契約的呼叫端」——它不是本類別自己的程式碼,
	# 是本測試模擬未來整合層應該怎麼做。
	var attempt_attack: Callable = func() -> Dictionary:
		if session.is_open():
			return {"action": &"blocked_by_card_play_session"}
		return controller.click_tile(enemy_pos)

	# Act 1 — 開手牌;遵守閘門的呼叫端被擋下
	assert_bool(session.open_hand()).is_true()
	var blocked_result: Dictionary = attempt_attack.call()

	# Assert 1 — 真正的攻擊路徑從未被觸及:HP 逐字不變
	assert_that(blocked_result["action"]).is_equal(&"blocked_by_card_play_session")
	assert_int(state.unit_by_id(ENEMY).hp).is_equal(hp_before)

	# Act 2 — 取消關閉 session,同一次點擊這次真的打到 BattleController
	session.cancel()
	assert_bool(session.is_open()).is_false()
	var real_result: Dictionary = attempt_attack.call()

	# Assert 2 — 真實生產路徑確實解算了攻擊
	assert_that(real_result["action"]).is_equal(&"attacked")
	assert_int(state.unit_by_id(ENEMY).hp).is_less(hp_before)


# ---- 補測:打牌不消耗移動/攻擊旗標 -------------------------------------------

func test_supplementary_playing_a_card_does_not_consume_move_or_attack_flags() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var order: TurnOrder = TurnOrder.new([P1, P2, P3], [ENEMY])
	var atk_card: Card = Card.new_temporary_stat_modifier("atk_up", 2, 0, 1)
	var deck: CardDeck = _build_deck([atk_card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	assert_bool(order.can_move(P1)).is_true()  # sanity check before the act
	assert_bool(order.can_attack(P1)).is_true()  # sanity check before the act

	# Act — 完整打出一張甲類卡（CardPlaySession 完全不持有 TurnOrder 參照）
	session.open_hand()
	session.select_card(atk_card)
	session.select_target(P1)
	assert_bool(session.confirm()).is_true()

	# Assert — 兩個旗標逐字不變
	assert_bool(order.can_move(P1)).is_true()
	assert_bool(order.can_attack(P1)).is_true()


# ---- 補測:每回合出牌數不限 ---------------------------------------------------

func test_supplementary_playing_three_cards_in_the_same_turn_all_succeed() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var cards: Array[Card] = [
		Card.new_temporary_stat_modifier("c1", 1, 0, 1),
		Card.new_temporary_stat_modifier("c2", 1, 0, 1),
		Card.new_temporary_stat_modifier("c3", 1, 0, 1),
	]
	var deck: CardDeck = _build_deck(cards)
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)

	# Act — 連打三張,每張都要重新開手牌（確認後 session 自動收合回 S0)
	for card: Card in cards:
		assert_bool(session.open_hand()).is_true()
		assert_bool(session.select_card(card)).is_true()
		assert_bool(session.select_target(P1)).is_true()
		assert_bool(session.confirm()).is_true()

	# Assert — 沒有任何張數上限擋下第三張
	assert_int(deck.used_size()).is_equal(3)
	assert_int(state.unit_by_id(P1).active_modifiers().size()).is_equal(3)


# ---- 補測:確認去重 -----------------------------------------------------------

func test_confirm_dedup_calling_confirm_twice_only_applies_once() -> void:
	# Arrange — 同一次選取(丙類,較長的鏈路),走到確認畫面
	var state: BattleState = _build_state()
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var bond_card: Card = Card.new_permanent_affinity_write("bond_dup", P1, P2, 2)
	var deck: CardDeck = _build_deck([bond_card])
	var session: CardPlaySession = CardPlaySession.new(deck, state, _default_links(), write_port)
	session.open_hand()
	session.select_card(bond_card)
	session.select_target(P1)
	session.select_second_target(P2)

	# Act — 同一次選取,連續呼叫兩次確認（模擬鍵盤+手把同幀各送一次)
	var first_result: bool = session.confirm()
	var second_result: bool = session.confirm()

	# Assert — 第一次成功、第二次無效,只留下一筆記錄
	assert_bool(first_result).is_true()
	assert_bool(second_result).is_false()
	assert_int(write_port.accepted_count).is_equal(1)
	assert_int(write_port.calls.size()).is_equal(1)


# ---- 額外(非工作單列出的 AC/補測,但屬 confirm() 自身設計的必要保護) ----------
# confirm() 若讓埠拒絕,不應該把卡片消耗掉、也不應該關閉 session —— 否則玩家
# 會在毫無 UI 回饋的情況下平白損失一張牌。這條不在工作單的驗收清單裡,
# 但直接對應 confirm() 文件註解裡承諾的行為,故補一條測試釘住它。

func test_extra_confirm_does_not_consume_card_when_port_rejects_the_write() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	write_port.force_rejection = AffinityWritePort.Rejection.DEAD_PAIR_FORBIDDEN
	var bond_card: Card = Card.new_permanent_affinity_write("bond_reject", P1, P2, 2)
	var deck: CardDeck = _build_deck([bond_card])
	var session: CardPlaySession = CardPlaySession.new(deck, state, _default_links(), write_port)
	session.open_hand()
	session.select_card(bond_card)
	session.select_target(P1)
	session.select_second_target(P2)

	# Act
	var result: bool = session.confirm()

	# Assert — 沒有真的完成,卡片還在手上,session 留在確認畫面
	assert_bool(result).is_false()
	assert_int(write_port.accepted_count).is_equal(0)
	assert_bool(deck.hand().has(bond_card)).is_true()
	assert_int(deck.used_size()).is_equal(0)
	assert_int(session.step()).is_equal(CardPlaySession.Step.CONFIRMING)


# ---- 甲類確認的正面控制組:CardModifier 欄位逐字對應卡面 ----------------------

func test_confirming_temporary_stat_modifier_attaches_a_card_modifier_with_expected_fields() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var card: Card = Card.new_temporary_stat_modifier("atk_up_encourage", 3, -1, 2)
	var deck: CardDeck = _build_deck([card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	session.open_hand()
	session.select_card(card)
	session.select_target(P2)

	# Act
	assert_bool(session.confirm()).is_true()

	# Assert — source_name=卡片 id,remaining_turns=卡片的 duration_rounds,
	# ATK/DEF 逐字照抄
	var modifiers: Array[CardModifier] = state.unit_by_id(P2).active_modifiers()
	assert_int(modifiers.size()).is_equal(1)
	assert_str(modifiers[0].source_name).is_equal("atk_up_encourage")
	assert_int(modifiers[0].atk_delta).is_equal(3)
	assert_int(modifiers[0].def_delta).is_equal(-1)
	assert_int(modifiers[0].remaining_turns).is_equal(2)


# ---- 丙類確認的正面控制組:play() 收到的是玩家選定的配對,不是卡面欄位 --------

func test_confirming_permanent_affinity_write_calls_the_port_with_selected_pair_and_card_magnitude() -> void:
	# Arrange — 卡面敘事欄位故意填 (P1, P3)(牌面說「甲對丙」),但玩家在棋盤上
	# 實際選的是 (P2, P3) —— play() 必須送出玩家選的那對,不是卡面欄位
	var state: BattleState = _build_state()
	var write_port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var card: Card = Card.new_permanent_affinity_write("bond_reach_out", P1, P3, -2)
	var deck: CardDeck = _build_deck([card])
	var session: CardPlaySession = CardPlaySession.new(deck, state, _default_links(), write_port)
	session.open_hand()
	session.select_card(card)
	session.select_target(P2)          # 玩家先選 P2(合法起點)
	session.select_second_target(P3)   # 再選 P2 的合法夥伴 P3

	# Act
	var result: bool = session.confirm()

	# Assert
	assert_bool(result).is_true()
	assert_int(write_port.calls.size()).is_equal(1)
	assert_int(write_port.calls[0]["character_a"]).is_equal(P2)
	assert_int(write_port.calls[0]["character_b"]).is_equal(P3)
	assert_int(write_port.calls[0]["m"]).is_equal(-2)
	assert_that(write_port.calls[0]["source"]).is_equal(AffinityWritePort.SOURCE_COMBAT_CARD)


# ---- legal_targets():甲類 = 全體我方存活單位 ---------------------------------

func test_legal_targets_for_temporary_stat_modifier_is_every_alive_player_unit() -> void:
	# Arrange
	var state: BattleState = _build_state()
	var card: Card = Card.new_temporary_stat_modifier("c", 1, 0, 1)
	var deck: CardDeck = _build_deck([card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	session.open_hand()
	session.select_card(card)

	# Act
	var targets: Array[int] = session.legal_targets()
	targets.sort()

	# Assert
	assert_array(targets).contains_exactly([P1, P2, P3])


# ---- legal_targets():丙類 S2p/S2q 的窄化與陣亡排除 ---------------------------

func test_legal_targets_for_permanent_affinity_write_excludes_a_dead_ally() -> void:
	# Arrange — P3 陣亡,P2-P3 那條線因此從合法集合消失,只剩 P1-P2
	var state: BattleState = _build_state()
	state.unit_by_id(P3).take_damage(9999)
	assert_bool(state.unit_by_id(P3).is_alive()).is_false()  # sanity check
	var card: Card = Card.new_permanent_affinity_write("bond_y", P1, P2, 1)
	var deck: CardDeck = _build_deck([card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	session.open_hand()
	session.select_card(card)

	# Act
	var targets: Array[int] = session.legal_targets()

	# Assert
	assert_bool(targets.has(P3)).is_false()
	assert_bool(targets.has(P2)).is_true()
	assert_bool(targets.has(P1)).is_true()


func test_select_second_target_rejects_a_unit_that_is_not_a_partner_of_the_first_choice() -> void:
	# Arrange — P1 唯一的合法夥伴是 P2(P1-P3 沒有直接連線)
	var state: BattleState = _build_state()
	var card: Card = Card.new_permanent_affinity_write("bond_x", P1, P2, 1)
	var deck: CardDeck = _build_deck([card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	session.open_hand()
	session.select_card(card)
	assert_bool(session.select_target(P1)).is_true()

	# Act — 嘗試選一個不是 P1 夥伴的單位
	var accepted: bool = session.select_second_target(P3)

	# Assert — 被拒絕,且停留在 S2q,不是靜默通過
	assert_bool(accepted).is_false()
	assert_int(session.step()).is_equal(CardPlaySession.Step.SELECTING_TARGET_B)


func test_select_target_rejects_a_unit_id_with_no_relationship_line_at_all() -> void:
	# Arrange — 999 不是任何關係線裡的成員,甚至不是真正的花名冊 id
	var state: BattleState = _build_state()
	var card: Card = Card.new_permanent_affinity_write("bond_no_line", P1, P3, 1)
	var deck: CardDeck = _build_deck([card])
	var session: CardPlaySession = CardPlaySession.new(
		deck, state, _default_links(), _FakeAffinityWritePort.new()
	)
	session.open_hand()
	session.select_card(card)

	# Act
	var accepted: bool = session.select_target(999)

	# Assert
	assert_bool(accepted).is_false()
	assert_int(session.step()).is_equal(CardPlaySession.Step.SELECTING_TARGET)
