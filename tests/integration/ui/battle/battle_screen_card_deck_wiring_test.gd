# BattleScreen 卡表/牌組接線的整合測試——
# production/epics/card-play-interface/story-u003-battle-screen-deck-wiring.md
# (U-003)卡牌線半部。涵蓋 U-003 自訂驗收基準（無對應 AC-U/AC-M，理由同
# U-001/U-002）。
#
# 大部分受測函式是 static、不依賴節點或場景樹（見 battle_screen.gd 的 doc
# comment），沿用 tests/unit/ui/battle_screen_load_guard_test.gd 的「pipeline」
# 測試手法：串起 _ready() 實際呼叫的真實函式，不 load()/instantiate() 場景。
# 只有「_controller 的 BattleController.new() 呼叫點確實補上三個參數」這條，
# 必須真正 load()/instantiate() BattleScreen.tscn 才能觀察 _ready() 的完整效果
# ——沿用 tests/unit/ui/battle_screen_scene_test.gd 的既有慣例（GdUnit4
# add_child() 進測試套件自己的節點樹）。
extends GdUnitTestSuite


const _SCENE_PATH: String = "res://src/ui/battle/BattleScreen.tscn"
const _MISSING_CARDS_PATH: String = "res://assets/data/cards/does_not_exist.txt"


# ---- classify_card_parse() ---------------------------------------------------

func test_classify_card_parse_null_returns_parse_error() -> void:
	# Arrange
	var parsed: Variant = null

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_card_parse(parsed)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.PARSE_ERROR)


func test_classify_card_parse_empty_array_returns_none() -> void:
	# Arrange — 合法的「這批卡池是空的」（GDD Edge Cases「卡池張數少於開局手牌數」
	# 的極端情形），不可被誤判為失敗
	var parsed: Array[Card] = []

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_card_parse(parsed)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


func test_classify_card_parse_nonempty_array_returns_none() -> void:
	# Arrange
	var parsed: Array[Card] = [Card.new_temporary_stat_modifier("c1", 1, 0, 1)]

	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_card_parse(parsed)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


# ---- 載入管線：檔案不存在 -> MISSING ------------------------------------------

func test_card_load_pipeline_missing_path_yields_missing() -> void:
	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_file_access(_MISSING_CARDS_PATH)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.MISSING)


func test_card_load_pipeline_real_cards_path_returns_none() -> void:
	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_file_access(BattleScreen.CARDS_PATH)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


func test_card_load_pipeline_real_card_text_path_returns_none() -> void:
	# Act
	var result: BattleScreen.LoadFailure = BattleScreen.classify_file_access(
		BattleScreen.CARD_TEXT_PATH
	)

	# Assert
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


# ---- 載入管線：一列打錯字 -> PARSE_ERROR（不是靜默的 0 張）---------------------
#
# 2026-09-15 管理者裁決（card.gd 的 cards_from_text() 文件註解轉錄）：卡表一列
# 解析失敗，整份作廢並響亮地停，不是「跳過該列繼續」。這裡鎖住 _ready() 實際
# 呼叫的兩個真實函式（Card.cards_from_text() 與 classify_card_parse()）串起來
# 的結果，同 battle_screen_load_guard_test.gd 對 roster/affinity 的既有先例。

func test_card_load_pipeline_corrupt_row_yields_parse_error() -> void:
	# Arrange — category 欄故意打錯字，前後各放一個合法列
	var text: String = (
		"card_a,TEMPORARY_STAT_MODIFIER,1,0,1,-1,-1,0\n"
		+ "card_bad,BADCATEGORY,0,0,0,-1,-1,0\n"
		+ "card_c,PERMANENT_AFFINITY_WRITE,0,0,0,1,2,2\n"
	)

	# Act — 與 battle_screen.gd _ready() 完全相同的兩步：先解析，再分類
	var parsed: Variant = Card.cards_from_text(text)
	var result: BattleScreen.LoadFailure = BattleScreen.classify_card_parse(parsed)

	# Assert
	assert_object(parsed).is_null()
	assert_int(result).is_equal(BattleScreen.LoadFailure.PARSE_ERROR)
	assert_int(result).is_not_equal(BattleScreen.LoadFailure.NONE)


# ---- 載入管線：內容非空但解析出 0 張 -> 只警告，不失敗（U-003 裁決）------------

func test_card_load_pipeline_zero_parsed_cards_yields_none_not_a_failure() -> void:
	# Arrange — 只有註解/空白行，內容非空但合法解析出 0 張
	var text: String = "# only comments\n\n"

	# Act
	var parsed: Variant = Card.cards_from_text(text)
	var result: BattleScreen.LoadFailure = BattleScreen.classify_card_parse(parsed)

	# Assert — 這正是「不進 _fail_load()」的判斷依據：NONE，即使解析出 0 張
	assert_object(parsed).is_not_null()
	assert_int((parsed as Array[Card]).size()).is_equal(0)
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)


func test_card_load_pipeline_real_vs01_file_yields_none_and_eight_cards() -> void:
	# Arrange
	var text: String = FileAccess.get_file_as_string(BattleScreen.CARDS_PATH)

	# Act
	var parsed: Variant = Card.cards_from_text(text)
	var result: BattleScreen.LoadFailure = BattleScreen.classify_card_parse(parsed)

	# Assert
	assert_object(parsed).is_not_null()
	assert_int(result).is_equal(BattleScreen.LoadFailure.NONE)
	assert_int((parsed as Array[Card]).size()).is_equal(8)


# ---- _build_card_deck()：固定種子可重現 --------------------------------------

func test_build_card_deck_with_fixed_seed_rng_is_reproducible_across_two_calls() -> void:
	# Arrange
	var cards: Array[Card] = []
	for i: int in range(10):
		cards.append(Card.new_temporary_stat_modifier("c%d" % i, 1, 0, 1))

	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 42
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_b.seed = 42

	# Act
	var deck_a: CardDeck = BattleScreen._build_card_deck(cards, rng_a)
	deck_a.deal_opening_hand()
	var deck_b: CardDeck = BattleScreen._build_card_deck(cards, rng_b)
	deck_b.deal_opening_hand()

	var hand_ids_a: Array[String] = []
	for c: Card in deck_a.hand():
		hand_ids_a.append(c.id)
	var hand_ids_b: Array[String] = []
	for c: Card in deck_b.hand():
		hand_ids_b.append(c.id)

	# Assert
	assert_array(hand_ids_a).is_equal(hand_ids_b)


func test_build_card_deck_default_rng_is_still_a_random_number_generator() -> void:
	# Arrange / Act — rng 省略時（production 呼叫方式）仍能正常建構、正常發牌，
	# 不崩潰——見 CardDeck._init() 本身「rng 省略時使用未加種子的
	# RandomNumberGenerator」的既有預設行為
	var cards: Array[Card] = [Card.new_temporary_stat_modifier("c0", 1, 0, 1)]
	var deck: CardDeck = BattleScreen._build_card_deck(cards)
	deck.deal_opening_hand()

	# Assert
	assert_int(deck.hand_size()).is_equal(1)


# ---- 缺一個檔案 -> 進入 _fail_load() 的失敗集合（透過場景真正跑一次 _ready()）--
#
# 🔴 這一條之所以要真正 load()/instantiate() 場景，而不是只呼叫靜態函式：AC 要
# 驗證的是「_fail_load() 被呼叫、畫面顯示失敗訊息」這個整體行為，而不僅是
# classify_file_access() 這個純函式的回傳值（後者已經被上面幾條 pipeline 測試
# 涵蓋）。real CARDS_PATH/CARD_TEXT_PATH 在這個專案裡真實存在，所以這裡改為
# 直接驗證 _fail_load() 本身的合約：任一個檔案分類非 NONE 時，_load_error_label
# 可見且非空、_load_failed 為 true——不依賴讓真正的 cards 資料檔在磁碟上消失
# （那會是 test-standards.md 禁止的「依賴檔案系統外部狀態」）。
func test_fail_load_dictionary_signature_sets_error_label_when_any_entry_fails() -> void:
	# Arrange
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)

	# Act — 直接呼叫 _fail_load()（GDScript 底線前綴僅為命名慣例，非語言層私有）
	# 驗證其新簽章（Dictionary[String, LoadFailure]）：五個路徑中僅
	# CARDS_PATH 一項失敗
	instance._fail_load({
		BattleScreen.TERRAIN_PATH: BattleScreen.LoadFailure.NONE,
		BattleScreen.ROSTER_PATH: BattleScreen.LoadFailure.NONE,
		BattleScreen.AFFINITY_PATH: BattleScreen.LoadFailure.NONE,
		BattleScreen.CARDS_PATH: BattleScreen.LoadFailure.MISSING,
		BattleScreen.CARD_TEXT_PATH: BattleScreen.LoadFailure.NONE,
	})

	# Assert — 顯示了失敗訊息（CARDS_PATH 那一項），且畫面進入失敗模式
	var load_error_label: Label = instance.get_node("UILayer/LoadErrorLabel")
	assert_bool(load_error_label.visible).is_true()
	assert_str(load_error_label.text).contains(BattleScreen.TEXT_LOAD_REASON_MISSING)
	assert_str(load_error_label.text).contains(BattleScreen.CARDS_PATH)
	assert_bool(instance._load_failed).is_true()


func test_fail_load_dictionary_signature_all_none_never_called_in_practice_but_stays_inert() -> void:
	# Arrange — 防禦性檢查：五項全 NONE 時（理論上 _ready() 不會走到這個呼叫，
	# 見該函式的呼叫端條件式），_fail_load() 本身不應該假設至少一項非 NONE
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)
	var load_error_label: Label = instance.get_node("UILayer/LoadErrorLabel")
	var was_visible_before: bool = load_error_label.visible

	# Act
	instance._fail_load({
		BattleScreen.TERRAIN_PATH: BattleScreen.LoadFailure.NONE,
		BattleScreen.ROSTER_PATH: BattleScreen.LoadFailure.NONE,
		BattleScreen.AFFINITY_PATH: BattleScreen.LoadFailure.NONE,
		BattleScreen.CARDS_PATH: BattleScreen.LoadFailure.NONE,
		BattleScreen.CARD_TEXT_PATH: BattleScreen.LoadFailure.NONE,
	})

	# Assert — 不崩潰；顯示的訊息會是 load_failure_message(NONE, "") 的字面結果
	# （沒有任何合法呼叫端會產生這個輸入，這裡只確認不中止呼叫函式）
	assert_bool(load_error_label.visible).is_true()
	assert_bool(was_visible_before).is_false()


# ---- 呼叫點本身：BattleController.new() 三個參數確實非預設值 ------------------

func test_battle_controller_new_call_site_passes_card_deck_affinity_links_and_write_port() -> void:
	# Arrange — 真實場景、真實資料檔（本專案自己的 vs01_* 資料表）
	var instance: BattleScreen = auto_free(load(_SCENE_PATH).instantiate())
	add_child(instance)

	var state: BattleState = instance._state
	var controller: BattleController = instance._controller

	# Assert — card_deck 確實被傳入（不是 BattleController.new() 的預設 null）
	# ——AC-P6：card_deck == null 時 state.card_deck() 會是 null
	assert_object(state.card_deck()).is_not_null()

	# Assert — card_deck != null 正是 BattleController._init() 決定要不要建構
	# CardPlaySession 的唯一條件（見該方法文件註解）——這裡若還是 null，代表
	# 呼叫點沒有真的傳 card_deck
	assert_object(controller._card_play_session).is_not_null()

	# Assert — write_port 是真實轉接器（AffinityPoolWritePort），不是
	# BattleController._init() 在 write_port 參數留預設 null 時會代入的
	# NullAffinityWritePort，且它包的正是這個畫面自己持有的 _affinity_pool
	# （不是另一個不相干的池實例）
	var write_port: AffinityWritePort = controller._card_play_session._write_port
	assert_bool(write_port is AffinityPoolWritePort).is_true()
	assert_object((write_port as AffinityPoolWritePort)._pool).is_same(instance._affinity_pool)

	# Assert — affinity_links 確實被傳入（與 _phi 使用的同一份 links，而不是
	# 一份空陣列）——_phi.links() 是這份資料在畫面上已經驗證過非空的既有讀法
	var expected_links: Array[AffinityLink] = instance._phi.links()
	assert_int(controller._card_play_session._links.size()).is_equal(expected_links.size())
	assert_bool(expected_links.size() > 0).is_true()
