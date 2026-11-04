# DeckTuning —— CardDeck 三項旋鈕的不可變設定物件。
#
# 規格:production/epics/tuning-data/story-002-card-deck-tuning.md
# 管理者 2026-11-04 裁決:「現在搬」「大聲報錯」。
#
# 數字的唯一來源:CardDeck.OPENING_HAND_SIZE / HAND_SIZE_LIMIT / CARDS_DRAWN_PER_TURN
# (story 選項 (b):常數暫留作 defaults() 來源);TuningKnobs.KNOWN_KEYS 的預設值指向它們,
# 本檔不寫任何字面數字。
#
# 驗證(失敗回 null 並 push_error,不用 assert()):
#   - 三項皆 >= 1
#   - opening_hand_size <= hand_size_limit(推導自 battle_state.gd deal_opening_hand 註解:
#     開局手牌超過上限會讓第一個動作被迫棄牌,而 deal_opening_hand 不會設
#     has_pending_discard,即「無任何規則描述的狀態」;寧可大聲拒絕)
#   - cards_drawn_per_turn 只接受 1(管理者 2026-11-04 裁決「只允許 1,寫別的就報錯」):
#     CardDeck 只以單一旗標記「欠一次棄牌」,多張抽牌支援須先改程式。
class_name DeckTuning
extends RefCounted


const SECTION: String = "deck"
const KEY_OPENING: String = "opening_hand_size"
const KEY_LIMIT: String = "hand_size_limit"
const KEY_DRAWN: String = "cards_drawn_per_turn"

var _opening_hand_size: int = 0
var _hand_size_limit: int = 0
var _cards_drawn_per_turn: int = 0


## 今日值(來自 TuningKnobs.defaults(),其預設值指向 CardDeck 常數)。
static func defaults() -> DeckTuning:
	var knobs: TuningKnobs = TuningKnobs.defaults()
	var tuning: DeckTuning = DeckTuning.new()
	tuning._opening_hand_size = knobs.get_int(SECTION, KEY_OPENING)
	tuning._hand_size_limit = knobs.get_int(SECTION, KEY_LIMIT)
	tuning._cards_drawn_per_turn = knobs.get_int(SECTION, KEY_DRAWN)
	return tuning


## 由已解析的 [TuningKnobs] 建立並驗證。失敗回 null 並 push_error。
static func from_knobs(knobs: TuningKnobs) -> Variant:
	var opening: int = knobs.get_int(SECTION, KEY_OPENING)
	var limit: int = knobs.get_int(SECTION, KEY_LIMIT)
	var drawn: int = knobs.get_int(SECTION, KEY_DRAWN)
	if opening < 1 or limit < 1 or drawn < 1:
		push_error("DeckTuning: all of deck.opening_hand_size / deck.hand_size_limit / deck.cards_drawn_per_turn must be >= 1 (got %d / %d / %d)" % [opening, limit, drawn])
		return null
	if opening > limit:
		push_error("DeckTuning: deck.opening_hand_size (%d) must be <= deck.hand_size_limit (%d)" % [opening, limit])
		return null
	if drawn != 1:
		push_error("DeckTuning: deck.cards_drawn_per_turn must be 1 (got %d): CardDeck tracks an owed discard with a single flag, so drawing more than 1 per turn needs a code change first" % drawn)
		return null
	var tuning: DeckTuning = DeckTuning.new()
	tuning._opening_hand_size = opening
	tuning._hand_size_limit = limit
	tuning._cards_drawn_per_turn = drawn
	return tuning


## 純解析便利入口:文字 -> TuningKnobs(要求鍵齊全)-> DeckTuning。任一步失敗回 null。
static func from_text(text: String) -> Variant:
	var parsed: Variant = TuningKnobs.from_text(text)
	if parsed == null:
		return null
	return from_knobs(parsed as TuningKnobs)


func opening_hand_size() -> int:
	return _opening_hand_size


func hand_size_limit() -> int:
	return _hand_size_limit


func cards_drawn_per_turn() -> int:
	return _cards_drawn_per_turn
