# CardPlaySession.confirm() 走 ADR-0001 提交入口(路徑⑥)的測試 ——
# production/epics/skill-card-system/story-010-card-confirm-through-commit-entry.md
#
# 本檔不讀任何檔案(無 FileAccess/DirAccess),夾具全在測試內,不屬甲/乙類例外。
# AC5(Session 內只有呼叫、沒有定義第二個入口)由交付回報的 grep 原始輸出證明,
# 不在本檔以讀原始碼的方式斷言(避免新增第三種檔案存取)。
#
# 敏感度證明(常駐 test_sensitivity_proof_*):以 CardPlaySession 子類別覆寫
# confirm() 重現四種錯誤形狀,斷言本檔的預言機(combat_state_version 差、窗口觀測)
# 真的分得出來。
# 不可證的部分:AC5 為文字搜尋性質(類別 D,注入點即正式程式碼的呼叫點本身)。
extends GdUnitTestSuite


const P1: int = 1
const P2: int = 2
const ENEMY: int = 9


func _build_state() -> BattleState:
	var lines: Array[String] = [
		"%d,P1,PLAYER,20,10,3,1,1,1,0,0" % P1,
		"%d,P2,PLAYER,20,8,2,1,1,1,5,0" % P2,
		"%d,E1,ENEMY,20,5,3,1,1,1,1,0" % ENEMY,
	]
	return BattleState.create(PackedStringArray(), "\n".join(lines))


func _links() -> Array[AffinityLink]:
	var link: AffinityLink = AffinityLink.new()
	link.unit_a = P1
	link.unit_b = P2
	link.polarity = AffinityLink.Polarity.POSITIVE
	link.amp = 1
	return [link]


## 記錄型埠:記下 append_record 被呼叫當下提交窗口是否開著。
class _SpyPort extends AffinityWritePort:
	var state: BattleState
	var window_seen: Array[bool] = []
	var force_rejection: Rejection = Rejection.NONE

	func append_record(_a: int, _b: int, _m: int, _source: StringName) -> Rejection:
		window_seen.append(state.write_window_is_open())
		return force_rejection


## 記錄型牌堆:play_card 被呼叫當下記錄窗口,並對受守衛的 Unit.hp 賦值(AC3 探針)。
class _SpyDeck extends CardDeck:
	var state: BattleState
	var probe_unit_id: int = -1
	var window_seen: Array[bool] = []

	func play_card(card: Card) -> bool:
		window_seen.append(state.write_window_is_open())
		var unit: Unit = state.unit_by_id(probe_unit_id)
		unit.hp = unit.hp - 1
		return super.play_card(card)


# ---- 預言機:舊行為(不進提交)與各種錯誤形狀 mutant -----------------------

## ① 不進提交。
class _MutantNoCommit extends CardPlaySession:
	func confirm() -> bool:
		if _step != Step.CONFIRMING:
			return false
		var t: Callable = func() -> void:
			if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
				PermanentAffinityWriteRules.play(_selected_card, _selected_target_a, _selected_target_b, _links, _write_port)
			else:
				_state.unit_by_id(_selected_target_a).add_modifier(CardModifier.new(
					_selected_card.id, _selected_card.delta_atk, _selected_card.delta_def, _selected_card.duration_rounds))
		t.call()
		_deck.play_card(_selected_card)
		_reset_to_closed()
		return true


## ② 只有丙類進提交、甲類不進。
class _MutantOnlyAffinityCommits extends CardPlaySession:
	func confirm() -> bool:
		if _step != Step.CONFIRMING:
			return false
		if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
			_state.commit_authoritative_change(func() -> void:
				PermanentAffinityWriteRules.play(_selected_card, _selected_target_a, _selected_target_b, _links, _write_port)
				_deck.play_card(_selected_card))
		else:
			_state.unit_by_id(_selected_target_a).add_modifier(CardModifier.new(
				_selected_card.id, _selected_card.delta_atk, _selected_card.delta_def, _selected_card.duration_rounds))
			_deck.play_card(_selected_card)
		_reset_to_closed()
		return true


## ③ 寫入一次提交、離手再一次提交(+2)。
class _MutantTwoCommits extends CardPlaySession:
	func confirm() -> bool:
		if _step != Step.CONFIRMING:
			return false
		_state.commit_authoritative_change(func() -> void:
			if _selected_card.category == Card.Category.PERMANENT_AFFINITY_WRITE:
				PermanentAffinityWriteRules.play(_selected_card, _selected_target_a, _selected_target_b, _links, _write_port)
			else:
				_state.unit_by_id(_selected_target_a).add_modifier(CardModifier.new(
					_selected_card.id, _selected_card.delta_atk, _selected_card.delta_def, _selected_card.duration_rounds)))
		_state.commit_authoritative_change(func() -> void:
			_deck.play_card(_selected_card))
		_reset_to_closed()
		return true


## ④ 失敗路徑也遞增。
class _MutantFailureBumps extends CardPlaySession:
	func confirm() -> bool:
		if _step != Step.CONFIRMING:
			_state.commit_authoritative_change(func() -> void: pass)
			return false
		return super.confirm()


func _stat_card() -> Card:
	return Card.new_temporary_stat_modifier("atk_up_3", 3, 0, 2)


func _bond_card() -> Card:
	return Card.new_permanent_affinity_write("bond_test", P1, P2, 2)


## 走到 CONFIRMING。
func _drive_to_confirm(s: CardPlaySession, card: Card, affinity: bool) -> void:
	s.open_hand()
	s.select_card(card)
	s.select_target(P1)
	if affinity:
		s.select_second_target(P2)


func _deck_of(card: Card) -> CardDeck:
	var d: CardDeck = CardDeck.new([card] as Array[Card], RandomNumberGenerator.new())
	d.deal_opening_hand()
	return d


## 回傳 confirm 前後版本號差(-1 表示沒走到 CONFIRMING)。
func _version_delta(session_script: GDScript, card: Card, affinity: bool) -> int:
	var state: BattleState = _build_state()
	var port: _SpyPort = _SpyPort.new()
	port.state = state
	var s: CardPlaySession = session_script.new(_deck_of(card), state, _links(), port)
	_drive_to_confirm(s, card, affinity)
	var before: int = state.combat_state_version
	s.confirm()
	return state.combat_state_version - before


# ---- AC1 恰好 +1 -------------------------------------------------------------

func test_commit_entry_stat_card_confirm_bumps_version_exactly_once() -> void:
	assert_int(_version_delta(CardPlaySession, _stat_card(), false)).is_equal(1)


func test_commit_entry_affinity_card_confirm_bumps_version_exactly_once() -> void:
	assert_int(_version_delta(CardPlaySession, _bond_card(), true)).is_equal(1)


# ---- AC2 失敗不遞增 -----------------------------------------------------------

func test_commit_entry_confirm_outside_confirming_step_leaves_version_unchanged() -> void:
	var state: BattleState = _build_state()
	var card: Card = _stat_card()
	var s: CardPlaySession = CardPlaySession.new(_deck_of(card), state, _links(), _SpyPort.new())
	s.open_hand()
	s.select_card(card)  # 還在 SELECTING_TARGET
	var before: int = state.combat_state_version
	assert_bool(s.confirm()).is_false()
	assert_int(state.combat_state_version).is_equal(before)


func test_commit_entry_confirm_when_closed_leaves_version_unchanged() -> void:
	var state: BattleState = _build_state()
	var s: CardPlaySession = CardPlaySession.new(_deck_of(_stat_card()), state, _links(), _SpyPort.new())
	assert_bool(s.confirm()).is_false()
	assert_int(state.combat_state_version).is_equal(0)


func test_commit_entry_named_restriction_mismatch_never_reaches_confirm_version_unchanged() -> void:
	# 點名限制不符:select_card 就被拒(story 009),自然走不到 confirm。
	var state: BattleState = _build_state()
	var card: Card = Card.new_temporary_stat_modifier("named_dead", 3, 0, 2)
	card.named_unit_id = 77  # 不在場
	var s: CardPlaySession = CardPlaySession.new(_deck_of(card), state, _links(), _SpyPort.new())
	s.open_hand()
	assert_bool(s.select_card(card)).is_false()
	assert_bool(s.confirm()).is_false()
	assert_int(state.combat_state_version).is_equal(0)


## 登記現況(非理想):丙類被埠拒絕只有呼叫埠才知道,故在窗口內決定,
## 提交無中止機制,版本照樣 +1;但 Session 留在 CONFIRMING、牌不離手。
## 詳見交付回報的「待裁示」。
func test_commit_entry_affinity_port_rejection_keeps_session_and_card_state() -> void:
	var state: BattleState = _build_state()
	var port: _SpyPort = _SpyPort.new()
	port.state = state
	port.force_rejection = AffinityWritePort.Rejection.INVALID_PAIR
	var card: Card = _bond_card()
	var deck: CardDeck = _deck_of(card)
	var s: CardPlaySession = CardPlaySession.new(deck, state, _links(), port)
	_drive_to_confirm(s, card, true)
	assert_bool(s.confirm()).is_false()
	assert_int(s.step()).is_equal(CardPlaySession.Step.CONFIRMING)
	assert_bool(deck.hand().has(card)).is_true()
	assert_int(deck.used_size()).is_equal(0)


# ---- AC3 窗口內對受守衛 hp 賦值被接受 ------------------------------------------

func _hp_probe(card: Card, affinity: bool) -> void:
	var state: BattleState = _build_state()
	var port: _SpyPort = _SpyPort.new()
	port.state = state
	var deck: _SpyDeck = _SpyDeck.new([card] as Array[Card], RandomNumberGenerator.new())
	deck.deal_opening_hand()
	deck.state = state
	deck.probe_unit_id = P1
	var hp_before: int = state.unit_by_id(P1).hp
	var s: CardPlaySession = CardPlaySession.new(deck, state, _links(), port)
	_drive_to_confirm(s, card, affinity)
	assert_bool(state.write_window_is_open()).is_false()
	assert_bool(s.confirm()).is_true()
	assert_array(deck.window_seen).is_equal([true])
	assert_int(state.unit_by_id(P1).hp).is_equal(hp_before - 1)
	assert_bool(state.write_window_is_open()).is_false()


func test_commit_entry_hp_write_accepted_inside_stat_card_confirm() -> void:
	_hp_probe(_stat_card(), false)


func test_commit_entry_hp_write_accepted_inside_affinity_card_confirm() -> void:
	_hp_probe(_bond_card(), true)


# ---- AC4 守衛 Callable 觀察到窗口開啟 ------------------------------------------

func test_commit_entry_guard_callable_sees_window_open_during_affinity_write() -> void:
	var state: BattleState = _build_state()
	var port: _SpyPort = _SpyPort.new()
	port.state = state
	var card: Card = _bond_card()
	var guard: Callable = Callable(state, "write_window_is_open")
	var s: CardPlaySession = CardPlaySession.new(_deck_of(card), state, _links(), port, guard)
	_drive_to_confirm(s, card, true)
	assert_bool(guard.call()).is_false()
	assert_bool(s.confirm()).is_true()
	assert_array(port.window_seen).is_equal([true])
	assert_bool(guard.call()).is_false()


# ---- AC6 常駐敏感度證明 --------------------------------------------------------

func test_sensitivity_proof_no_commit_is_detected_by_ac1_and_ac4_oracles() -> void:
	assert_int(_version_delta(_MutantNoCommit, _stat_card(), false)).is_equal(0)
	assert_int(_version_delta(_MutantNoCommit, _bond_card(), true)).is_equal(0)
	# AC4 預言機:丙類埠寫入當下窗口應為關(mutant)而非開
	var state: BattleState = _build_state()
	var port: _SpyPort = _SpyPort.new()
	port.state = state
	var card: Card = _bond_card()
	var s: CardPlaySession = _MutantNoCommit.new(_deck_of(card), state, _links(), port)
	_drive_to_confirm(s, card, true)
	s.confirm()
	assert_array(port.window_seen).is_equal([false])


func test_sensitivity_proof_only_affinity_commits_is_detected_by_ac1_stat_case() -> void:
	assert_int(_version_delta(_MutantOnlyAffinityCommits, _stat_card(), false)).is_equal(0)
	assert_int(_version_delta(_MutantOnlyAffinityCommits, _bond_card(), true)).is_equal(1)


func test_sensitivity_proof_two_commits_is_detected_by_ac1() -> void:
	assert_int(_version_delta(_MutantTwoCommits, _stat_card(), false)).is_equal(2)
	assert_int(_version_delta(_MutantTwoCommits, _bond_card(), true)).is_equal(2)


func test_sensitivity_proof_failure_path_bump_is_detected_by_ac2() -> void:
	var state: BattleState = _build_state()
	var s: CardPlaySession = _MutantFailureBumps.new(_deck_of(_stat_card()), state, _links(), _SpyPort.new())
	assert_bool(s.confirm()).is_false()
	assert_int(state.combat_state_version).is_equal(1)
