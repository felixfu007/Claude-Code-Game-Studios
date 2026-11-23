## campfire_write_port_test.gd
##
## 實作依據:production/epics/campfire/story-002-campfire-write-port.md
## AC1(10 組各關心一次、跨多輪)、AC2(質問 -m、冷淡區 NONE -> NEG)、AC3(拒絕零寫入、
## 換輪可再選)、AC6(來源值 SUPPORT_CONVERSATION、同輪順序 = 確認順序)、
## AC7(敏感度證明)。AC4/AC5 在 tests/integration/gameplay/campfire/。
##
## 檔案存取:僅 test_data_file_* 一條讀 assets/data/campfire/campfire_knobs.txt
## (註冊例外 1:唯讀、版控內的真實資料檔;不證明窮盡性)。其餘純記憶體。
##
## 敏感度證明:常駐 test_sensitivity_proof_*,每個 mutant 一條、各自獨立;
## mutant 為 CampfireWritePort 子類別覆寫其受保護覆寫點,與真品共用同一個情境函式。
extends GdUnitTestSuite

const _KNOB_TEXT: String = "m,0.5\ncamp_actions_per_round,3\n"
const _NEUTRAL_BAND: float = 0.3
const _C := AffinityTypes.Character


# ---- mutants(僅供敏感度證明)------------------------------------------------

## ① 誤用丙類 legal_pairs():只有靜態關係檔列出的組才可寫。
class _MutantLegalPairsFilter extends CampfireWritePort:
	func _is_pair_writable(pair: AffinityTypes.Pair) -> bool:
		var parsed: Variant = AffinityLink.links_from_text("1,2,POSITIVE,1\n3,4,NEGATIVE,1\n")
		var links: Array[AffinityLink] = parsed
		var alive: Callable = func(_id: int) -> bool: return true
		for link: AffinityLink in PermanentAffinityWriteRules.legal_pairs(links, alive):
			var off: int = AffinityPoolWritePort.ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET
			if AffinityTypes.pair_of(link.unit_a - off, link.unit_b - off) == pair:
				return true
		return false


## ② 質問寫成 +m。
class _MutantQuestionPositive extends CampfireWritePort:
	func _signed_amount(_action: CampfireWritePort.Action) -> float:
		return _knobs.m()


## ③ 次數檢查拿掉。
class _MutantNoBudgetCheck extends CampfireWritePort:
	func _round_budget_left() -> int:
		return 999


## ④ 同組不重複檢查拿掉。
class _MutantNoRepeatCheck extends CampfireWritePort:
	func _is_repeat_this_round(_pair: AffinityTypes.Pair) -> bool:
		return false


## ⑤ 來源值改 COMBAT_CARD。
class _MutantCombatCardSource extends CampfireWritePort:
	func _source_value() -> AffinityTypes.Source:
		return AffinityTypes.Source.COMBAT_CARD


# ---- helpers -----------------------------------------------------------------

func _knobs() -> CampfireKnobs:
	var knobs: CampfireKnobs = CampfireKnobs.from_text(_KNOB_TEXT)
	assert_object(knobs).is_not_null()
	return knobs


func _port(ledger: CampaignAffinityLedger) -> CampfireWritePort:
	return CampfireWritePort.new(ledger, _knobs())


func _all_pairs() -> Array:
	var result: Array = []
	for a: int in range(5):
		for b: int in range(a + 1, 5):
			result.append([a, b])
	return result


func _ok(r: CampfireWritePort.Rejection) -> bool:
	return r == CampfireWritePort.Rejection.NONE


# ---- 情境函式(真品與 mutant 共用;回 true = 情境成立)---------------------------

## AC1 麥子健(CHARACTER_5)四組皆能寫進 ledger(每輪 3 次,跨兩輪)。
func _scenario_mai_pairs_writable(port: CampfireWritePort, ledger: CampaignAffinityLedger) -> bool:
	var care: CampfireWritePort.Action = CampfireWritePort.Action.CARE
	var ok: bool = true
	port.begin_round()
	ok = _ok(port.confirm(_C.CHARACTER_1, _C.CHARACTER_5, care)) and ok
	ok = _ok(port.confirm(_C.CHARACTER_2, _C.CHARACTER_5, care)) and ok
	ok = _ok(port.confirm(_C.CHARACTER_3, _C.CHARACTER_5, care)) and ok
	port.begin_round()
	ok = _ok(port.confirm(_C.CHARACTER_4, _C.CHARACTER_5, care)) and ok
	return ok and ledger.records().size() == 4


## AC2 質問寫入的 m 為負。
func _scenario_question_is_negative(port: CampfireWritePort, ledger: CampaignAffinityLedger) -> bool:
	port.begin_round()
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, CampfireWritePort.Action.QUESTION)
	return _ok(r) and ledger.records().size() == 1 and ledger.records()[0].m < 0.0


## AC3 本輪第 4 次被拒、零寫入。
func _scenario_fourth_action_rejected(port: CampfireWritePort, ledger: CampaignAffinityLedger) -> bool:
	var care: CampfireWritePort.Action = CampfireWritePort.Action.CARE
	port.begin_round()
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, care)
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_3, care)
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_4, care)
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_2, _C.CHARACTER_3, care)
	return r == CampfireWritePort.Rejection.NO_ACTIONS_LEFT and ledger.records().size() == 3


## AC3 同輪重複同一組(含換方向、換動作)被拒、零寫入。
func _scenario_repeat_pair_rejected(port: CampfireWritePort, ledger: CampaignAffinityLedger) -> bool:
	port.begin_round()
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, CampfireWritePort.Action.CARE)
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_2, _C.CHARACTER_1, CampfireWritePort.Action.QUESTION)
	return r == CampfireWritePort.Rejection.PAIR_ALREADY_CHOSEN and ledger.records().size() == 1


## AC6 來源值為 SUPPORT_CONVERSATION。
func _scenario_source_is_support_conversation(port: CampfireWritePort, ledger: CampaignAffinityLedger) -> bool:
	port.begin_round()
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, CampfireWritePort.Action.CARE)
	return ledger.records().size() == 1 and ledger.records()[0].source == AffinityTypes.Source.SUPPORT_CONVERSATION


# ---- AC1 ---------------------------------------------------------------------

func test_care_each_of_ten_pairs_adds_m_and_one_record_across_rounds() -> void:
	# Arrange
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var port: CampfireWritePort = _port(ledger)
	var m: float = _knobs().m()
	var pairs: Array = _all_pairs()
	# Act -- 每輪 3 次,10 組跨 4 輪
	for i: int in range(pairs.size()):
		if i % 3 == 0:
			port.begin_round()
		var r: CampfireWritePort.Rejection = port.confirm(pairs[i][0], pairs[i][1], CampfireWritePort.Action.CARE)
		assert_int(r).append_failure_message("pair index %d: %s" % [i, CampfireWritePort.rejection_text(r)]).is_equal(CampfireWritePort.Rejection.NONE)
	var pool: AffinityDataPool = port.rebuild_pool()
	# 較舊的記錄會隨後續寫入衰減(池的既有行為),故同一序列下的 v 以「直接依序寫池」的
	# 參考池為準;「單筆寫入 v == m」另在下一條測試逐組驗證。
	var reference: AffinityDataPool = AffinityDataPool.new()
	for pair_info: Array in pairs:
		reference.append_record(AffinityTypes.pair_of(pair_info[0], pair_info[1]), m, AffinityTypes.Source.SUPPORT_CONVERSATION)
	# Assert
	for pair_info: Array in pairs:
		var pair: AffinityTypes.Pair = AffinityTypes.pair_of(pair_info[0], pair_info[1])
		var read: AffinityDataPool.AffinityReadResult = pool.combat_strength_read(pair)
		var expected: AffinityDataPool.AffinityReadResult = reference.combat_strength_read(pair)
		assert_int(read.n_pair).append_failure_message("pair %d n_pair" % pair).is_equal(1)
		assert_float(read.value).append_failure_message("pair %d v" % pair).is_equal_approx(expected.value, 0.0001)


func test_single_care_write_reads_back_exactly_m_for_each_of_ten_pairs() -> void:
	var m: float = _knobs().m()
	for pair_info: Array in _all_pairs():
		var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
		var port: CampfireWritePort = _port(ledger)
		port.begin_round()
		assert_int(port.confirm(pair_info[0], pair_info[1], CampfireWritePort.Action.CARE)).is_equal(CampfireWritePort.Rejection.NONE)
		var read: AffinityDataPool.AffinityReadResult = port.rebuild_pool().combat_strength_read(AffinityTypes.pair_of(pair_info[0], pair_info[1]))
		assert_int(read.n_pair).is_equal(1)
		assert_float(read.value).is_equal_approx(m, 0.0001)


func test_mai_four_pairs_are_writable_without_legal_pairs_filter() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	assert_bool(_scenario_mai_pairs_writable(_port(ledger), ledger)).is_true()


# ---- AC2 ---------------------------------------------------------------------

func test_question_writes_negative_m() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	assert_bool(_scenario_question_is_negative(_port(ledger), ledger)).is_true()
	assert_float(ledger.records()[0].m).is_equal_approx(-_knobs().m(), 0.0001)


func test_question_inside_neutral_band_crosses_to_neg() -> void:
	# Arrange -- 先有一筆小的正向記錄,使該組 v 落在冷淡區內(NONE)
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	ledger.append(AffinityTypes.Pair.C1_C2, 0.1, AffinityTypes.Source.STORY_EVENT)
	var port: CampfireWritePort = _port(ledger)
	var before: AffinityRelation.RelationState = AffinityRelation.state_of(port.rebuild_pool(), AffinityTypes.Pair.C1_C2, _NEUTRAL_BAND)
	assert_int(before).is_equal(AffinityRelation.RelationState.NONE)
	# Act
	port.begin_round()
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, CampfireWritePort.Action.QUESTION)
	# Assert
	assert_int(r).is_equal(CampfireWritePort.Rejection.NONE)
	var after: AffinityRelation.RelationState = AffinityRelation.state_of(port.rebuild_pool(), AffinityTypes.Pair.C1_C2, _NEUTRAL_BAND)
	assert_int(after).is_equal(AffinityRelation.RelationState.NEG)


# ---- AC3 ---------------------------------------------------------------------

func test_same_character_rejected_with_zero_write() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var port: CampfireWritePort = _port(ledger)
	port.begin_round()
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_3, _C.CHARACTER_3, CampfireWritePort.Action.CARE)
	assert_int(r).is_equal(CampfireWritePort.Rejection.SAME_CHARACTER)
	assert_int(ledger.records().size()).is_equal(0)
	assert_int(port.actions_left()).append_failure_message("拒絕不得消耗次數").is_equal(3)
	assert_str(CampfireWritePort.rejection_text(r)).is_not_empty()


func test_invalid_character_rejected_with_zero_write() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var port: CampfireWritePort = _port(ledger)
	port.begin_round()
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_1, 7 as AffinityTypes.Character, CampfireWritePort.Action.CARE)
	assert_int(r).is_equal(CampfireWritePort.Rejection.INVALID_CHARACTER)
	assert_int(ledger.records().size()).is_equal(0)


func test_fourth_action_in_a_round_rejected_with_zero_write() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	assert_bool(_scenario_fourth_action_rejected(_port(ledger), ledger)).is_true()


func test_repeat_pair_in_same_round_rejected_with_zero_write() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	assert_bool(_scenario_repeat_pair_rejected(_port(ledger), ledger)).is_true()


func test_same_pair_allowed_again_after_new_round_and_budget_resets() -> void:
	var care: CampfireWritePort.Action = CampfireWritePort.Action.CARE
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var port: CampfireWritePort = _port(ledger)
	port.begin_round()
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, care)
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_3, care)
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_4, care)
	assert_int(port.actions_left()).is_equal(0)
	port.begin_round()
	assert_int(port.actions_left()).is_equal(3)
	var r: CampfireWritePort.Rejection = port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, care)
	assert_int(r).is_equal(CampfireWritePort.Rejection.NONE)
	assert_int(ledger.records().size()).is_equal(4)


# ---- AC6 ---------------------------------------------------------------------

func test_source_is_support_conversation() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	assert_bool(_scenario_source_is_support_conversation(_port(ledger), ledger)).is_true()


func test_two_writes_in_a_round_keep_confirmation_order_no_reordering() -> void:
	# 刻意用「較大的 pair 序數先確認」,若有人排序/重排,順序會反過來。
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var port: CampfireWritePort = _port(ledger)
	port.begin_round()
	port.confirm(_C.CHARACTER_4, _C.CHARACTER_5, CampfireWritePort.Action.QUESTION)
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, CampfireWritePort.Action.CARE)
	var records: Array[CampaignAffinityLedger.Entry] = ledger.records()
	assert_int(records.size()).is_equal(2)
	assert_int(records[0].pair).is_equal(AffinityTypes.Pair.C4_C5)
	assert_float(records[0].m).is_less(0.0)
	assert_int(records[1].pair).is_equal(AffinityTypes.Pair.C1_C2)
	assert_float(records[1].m).is_greater(0.0)


func test_each_confirm_writes_immediately_not_batched() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var port: CampfireWritePort = _port(ledger)
	port.begin_round()
	port.confirm(_C.CHARACTER_1, _C.CHARACTER_2, CampfireWritePort.Action.CARE)
	assert_int(ledger.records().size()).append_failure_message("確認後須立即在 ledger 中").is_equal(1)


# ---- 資料檔與旋鈕解析 ----------------------------------------------------------

func test_data_file_loads_and_m_not_above_one_support_conversation_write() -> void:
	var knobs: CampfireKnobs = CampfireKnobs.from_file()
	assert_object(knobs).is_not_null()
	assert_float(knobs.m()).is_greater(0.0)
	assert_float(knobs.m()).is_less_equal(SupportConversationRules.MAGNITUDE_ABS)
	assert_int(knobs.actions_per_round()).is_equal(3)


func test_knobs_from_text_rejects_bad_input() -> void:
	assert_object(CampfireKnobs.from_text("m,0.5\n")).is_null()
	assert_object(CampfireKnobs.from_text("m,0.5\nm,0.5\ncamp_actions_per_round,3\n")).is_null()
	assert_object(CampfireKnobs.from_text("m,0.5\ncamp_actions_per_round,3\nfoo,1\n")).is_null()
	assert_object(CampfireKnobs.from_text("m,2.0\ncamp_actions_per_round,3\n")).is_null()
	assert_object(CampfireKnobs.from_text("m,0.5\ncamp_actions_per_round,0\n")).is_null()
	assert_object(CampfireKnobs.from_text("m,abc\ncamp_actions_per_round,3\n")).is_null()


# ---- AC7 敏感度證明(每個 mutant 一條,獨立)--------------------------------------

func test_sensitivity_proof_legal_pairs_filter_is_detected() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var mutant: CampfireWritePort = _MutantLegalPairsFilter.new(ledger, _knobs())
	assert_bool(_scenario_mai_pairs_writable(mutant, ledger)).is_false()


func test_sensitivity_proof_question_written_as_positive_is_detected() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var mutant: CampfireWritePort = _MutantQuestionPositive.new(ledger, _knobs())
	assert_bool(_scenario_question_is_negative(mutant, ledger)).is_false()


func test_sensitivity_proof_missing_budget_check_is_detected() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var mutant: CampfireWritePort = _MutantNoBudgetCheck.new(ledger, _knobs())
	assert_bool(_scenario_fourth_action_rejected(mutant, ledger)).is_false()


func test_sensitivity_proof_missing_repeat_check_is_detected() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var mutant: CampfireWritePort = _MutantNoRepeatCheck.new(ledger, _knobs())
	assert_bool(_scenario_repeat_pair_rejected(mutant, ledger)).is_false()


func test_sensitivity_proof_combat_card_source_is_detected() -> void:
	var ledger: CampaignAffinityLedger = CampaignAffinityLedger.new()
	var mutant: CampfireWritePort = _MutantCombatCardSource.new(ledger, _knobs())
	assert_bool(_scenario_source_is_support_conversation(mutant, ledger)).is_false()
