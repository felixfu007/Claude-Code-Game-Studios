# AffinityWritePort / PermanentAffinityWriteRules
# （src/gameplay/cards/affinity_write_port.gd, permanent_affinity_write_rules.gd）
# 的單元測試 —— Story 004：丙類的合法配對集合與寫入埠。
#
# production/epics/skill-card-system/story-004-permanent-write-port.md：
# 好感度數值池（ADR-0002，Accepted）零實作，本 story 定義一個窄寫入埠並注入。
# 本檔只驗到埠這一層——「記錄真的落在池裡」的端到端驗證待 #1 實作，不計入本檔完成度。
#
# 純資料/純函式測試——AffinityWritePort、PermanentAffinityWriteRules、Card、
# AffinityLink 全部是 RefCounted，不建立任何 Node，也不需要 tear-down，不會留下
# 孤兒節點。命名慣例沿用既有先例 tests/unit/gameplay/cards/card_deck_test.gd 的
# test_[scenario]_[expected]。每個測試自建自拆，不共用可變狀態。
#
# 真實關係線資料（assets/data/affinity/vs01_affinity_links.txt）以 FileAccess 讀入
# ——這是本專案既有慣例（tests/unit/gameplay/affinity/affinity_link_test.gd、
# affinity_phi_provider_test.gd 皆同做法），理由是合法配對集合「必須從關係線資料推導，
# 不得寫死兩對」（界線 3：隨劇情推進自動擴大），故測試也不應該自己合成一份配對表，
# 而要走與生產程式碼相同的權威來源。
extends GdUnitTestSuite

const VS01_LINKS_PATH: String = "res://assets/data/affinity/vs01_affinity_links.txt"

# 花名冊 id（見 vs01_affinity_links.txt 檔頭與 assets/data/units/vs01_roster.txt）：
# 1=甲 2=乙 3=丙 4=丁 5=戊。甲乙合作（POSITIVE）、丙丁對立（NEGATIVE）、
# 戊沒有任何配對——這是刻意的，不是漏寫。
const JIA: int = 1
const YI: int = 2
const BING: int = 3
const DING: int = 4
const WU: int = 5


## 記錄型測試替身，滿足 [AffinityWritePort] 的 @abstract 契約。
##
## 兩個計數器刻意分開，對應完成判準要逐條斷言的兩件不同的事：
## - [member calls]：每一次「呼叫確實送到埠」的證據（不論被接受或拒絕）——
##   AC-7b 需要證明陣亡配對的寫入呼叫真的送達這裡，而不是被上游攔截。
## - [member accepted_count]：只有真正被接受的寫入才會遞增，是「池的記錄筆數」
##   的替身——AC-7b/AC-9 需要證明拒絕時這個數字不動，AC-8b 需要證明它 +1。
##
## [member dead_pairs] 是本測試替身自己對 ADR-0002 `t_death()`/`_death_marks`
## 機制的簡化：真正的池會從自己的陣亡標記表判斷，這裡直接由測試指定，因為
## 這個替身本來就沒有一個真正的戰鬥狀態可查。
class _FakeAffinityWritePort extends AffinityWritePort:
	var calls: Array[Dictionary] = []
	var accepted_count: int = 0
	var dead_pairs: Array[Vector2i] = []

	func append_record(character_a: int, character_b: int, m: int, source: StringName) -> Rejection:
		calls.append({
			"character_a": character_a,
			"character_b": character_b,
			"m": m,
			"source": source,
		})
		if m == 0:
			return Rejection.ZERO_MAGNITUDE
		if _is_dead_pair(character_a, character_b):
			return Rejection.DEAD_PAIR_FORBIDDEN
		accepted_count += 1
		return Rejection.NONE

	func _is_dead_pair(a: int, b: int) -> bool:
		for pair: Vector2i in dead_pairs:
			if (pair.x == a and pair.y == b) or (pair.x == b and pair.y == a):
				return true
		return false


func _vs01_links() -> Array[AffinityLink]:
	var text: String = FileAccess.get_file_as_string(VS01_LINKS_PATH)
	return AffinityLink.links_from_text(text)


func _all_alive(_unit_id: int) -> bool:
	return true


# ---- AC-6：打出丙類 → 埠收到一次呼叫，source=combat_card、幅度為卡定義值 ------

func test_ac6_playing_permanent_card_reaches_port_with_combat_card_source_and_card_magnitude() -> void:
	# Arrange
	var port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var card: Card = Card.new_permanent_affinity_write("bond_up_1", JIA, YI, 2)

	# Act
	var result: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(card, port)

	# Assert — 只驗到埠：恰好一次呼叫，內容逐字等於卡片定義值
	assert_int(port.calls.size()).is_equal(1)
	assert_int(port.calls[0]["character_a"]).is_equal(JIA)
	assert_int(port.calls[0]["character_b"]).is_equal(YI)
	assert_int(port.calls[0]["m"]).is_equal(2)
	assert_that(port.calls[0]["source"]).is_equal(AffinityWritePort.SOURCE_COMBAT_CARD)
	assert_int(result).is_equal(AffinityWritePort.Rejection.NONE)


# ---- AC-7：配對成員已陣亡 → 不出現在合法作用對象集合中 ------------------------

func test_ac7_pair_with_dead_member_excluded_from_legal_set() -> void:
	# Arrange — 丙(3) 陣亡；真實配對表裡丙丁(3,4,NEGATIVE) 是既有關係線
	var links: Array[AffinityLink] = _vs01_links()
	var is_alive: Callable = func(unit_id: int) -> bool: return unit_id != BING

	# Act
	var legal: Array[AffinityLink] = PermanentAffinityWriteRules.legal_pairs(links, is_alive)

	# Assert — 丙丁不在合法集合裡；集合中沒有任何一條牽涉到丙
	assert_bool(PermanentAffinityWriteRules.is_legal_target(links, is_alive, BING, DING)).is_false()
	for link: AffinityLink in legal:
		assert_bool(link.involves(BING)).is_false()


# ---- AC-7b：繞過選擇介面直接以陣亡配對呼叫寫入 → 埠拒絕，記錄筆數不變 ----------

func test_ac7b_bypassing_selection_with_dead_pair_is_rejected_by_the_port_not_upstream() -> void:
	# Arrange — 卡片本身鎖定丙丁配對；埠被告知這對已陣亡。刻意完全不呼叫
	# legal_pairs()/is_legal_target()，模擬繞過選擇介面直接打出。
	var port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	port.dead_pairs.append(Vector2i(BING, DING))
	var card: Card = Card.new_permanent_affinity_write("bond_dead_pair", BING, DING, -2)

	# Act
	var result: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(card, port)

	# Assert ① — 呼叫確實送到了埠（不是被本系統提前攔下）：埠的呼叫紀錄裡
	# 恰好多了一筆，且參數就是這張卡的陣亡配對本身
	assert_int(port.calls.size()).is_equal(1)
	assert_int(port.calls[0]["character_a"]).is_equal(BING)
	assert_int(port.calls[0]["character_b"]).is_equal(DING)
	# Assert ② — 且是被埠拒絕的（不是 NONE）
	assert_int(result).is_equal(AffinityWritePort.Rejection.DEAD_PAIR_FORBIDDEN)
	# Assert ③ — 記錄筆數（埠的接受計數器）沒有被這次呼叫推進
	assert_int(port.accepted_count).is_equal(0)


# ---- AC-8a：對無關係線的配對作用（含戊）→ 不在合法集合中 -----------------------

func test_ac8a_pair_without_any_relationship_line_is_not_in_legal_set_including_wu() -> void:
	# Arrange — 全員存活；真實配對表只有兩條（甲乙、丙丁），戊(5) 與其餘任何
	# 未登記的組合皆無關係線
	var links: Array[AffinityLink] = _vs01_links()

	# Act / Assert — 逐一確認含戊的配對皆不合法
	assert_bool(PermanentAffinityWriteRules.is_legal_target(links, _all_alive, JIA, WU)).is_false()
	assert_bool(PermanentAffinityWriteRules.is_legal_target(links, _all_alive, YI, WU)).is_false()
	assert_bool(PermanentAffinityWriteRules.is_legal_target(links, _all_alive, BING, WU)).is_false()
	assert_bool(PermanentAffinityWriteRules.is_legal_target(links, _all_alive, DING, WU)).is_false()
	# 補一個不含戊、但同樣沒有關係線的配對（甲丙），確認界線不是「只排戊」
	assert_bool(PermanentAffinityWriteRules.is_legal_target(links, _all_alive, JIA, BING)).is_false()

	# Assert — 合法集合本身沒有任何一條牽涉到戊
	var legal: Array[AffinityLink] = PermanentAffinityWriteRules.legal_pairs(links, _all_alive)
	for link: AffinityLink in legal:
		assert_bool(link.involves(WU)).is_false()
	assert_int(legal.size()).is_equal(2)  # 真實資料只有兩條：甲乙、丙丁


# ---- AC-8b：正面控制組 —— 甲乙可選定、寫入成功、筆數 +1、極性不變 --------------

func test_ac8b_existing_relationship_pair_is_selectable_and_write_succeeds_polarity_unchanged() -> void:
	# Arrange
	var links: Array[AffinityLink] = _vs01_links()
	# sanity check —— 若這一步就是 false，代表 AC-8a 排除的是「全部」而非「只排戊」，
	# AC-8a 的訊號就不可信
	assert_bool(PermanentAffinityWriteRules.is_legal_target(links, _all_alive, JIA, YI)).is_true()

	var port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var card: Card = Card.new_permanent_affinity_write("bond_up_jia_yi", JIA, YI, 1)

	# Act
	var result: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(card, port)

	# Assert — 寫入成功，記錄筆數 +1
	assert_int(result).is_equal(AffinityWritePort.Rejection.NONE)
	assert_int(port.accepted_count).is_equal(1)

	# Assert — 極性不變：寫入路徑從未修改 AffinityLink 本身，甲乙關係線的極性
	# 在寫入前後逐字相同（界線 1：不得翻轉任何角色設定的正負號）
	var jia_yi_link: AffinityLink = null
	for link: AffinityLink in links:
		if link.involves(JIA) and link.involves(YI):
			jia_yi_link = link
	assert_object(jia_yi_link).is_not_null()
	assert_int(jia_yi_link.polarity).is_equal(AffinityLink.Polarity.POSITIVE)


# ---- AC-9：m=0 → 拒絕並拋驗證錯誤，不靜默糾正、不產生記錄、計數器不遞增 --------

func test_ac9_zero_magnitude_is_rejected_not_silently_corrected() -> void:
	# Arrange
	var port: _FakeAffinityWritePort = _FakeAffinityWritePort.new()
	var card: Card = Card.new_permanent_affinity_write("bond_zero", JIA, YI, 0)

	# Act
	var result: AffinityWritePort.Rejection = PermanentAffinityWriteRules.play(card, port)

	# Assert — 拒絕碼正確；呼叫送達時 m 仍是字面 0（沒有被本系統偷偷改成 ±1
	# 再轉送出去）；記錄筆數（接受計數器）沒有遞增
	assert_int(result).is_equal(AffinityWritePort.Rejection.ZERO_MAGNITUDE)
	assert_int(port.calls.size()).is_equal(1)
	assert_int(port.calls[0]["m"]).is_equal(0)
	assert_int(port.accepted_count).is_equal(0)
