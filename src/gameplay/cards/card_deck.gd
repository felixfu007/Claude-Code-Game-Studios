## Owns the three positions a [Card] can occupy during a single battle, and
## the movement rules between them (GDD States and Transitions ①):
## [code]卡池(pool) → 手牌(hand) →(打出|棄掉)→ 已用區(used) →(戰鬥結束)→ 卡池[/code].
##
## The used pile exists to satisfy two promises the GDD makes at the same
## time (see [code]design/gdd/skill-card-system.md[/code] States and
## Transitions ①): a played/discarded card must not be immediately
## re-drawable within the same battle (Formula 四's "pool > 11 → no
## repeats" guarantee is a mathematical guarantee, not a probability, and
## only holds if a used card is unreachable until battle end), and it must
## not leave the pool forever either (cards are never destroyed). Sending a
## used card to a third bucket that only empties back into the pool at
## battle end is the only reading that satisfies both at once — see
## [method return_all_to_pool].
##
## The draw source is an injected [RandomNumberGenerator], never a call to
## the engine's global RNG functions ([code]randi()[/code] /
## [code]randi_range()[/code] at [code]@GlobalScope[/code] scope) — this is
## what makes [method deal_opening_hand] and [method draw_for_turn]
## reproducible under a fixed seed, which
## [code].claude/docs/coding-standards.md[/code]'s determinism rule
## requires. This does not conflict with the project-level ban on RNG in
## the settlement path ([code]rng_in_combat_settlement[/code]): which card
## comes up on a draw is the one place the GDD explicitly allows randomness
## (Core Rules 三) — the card's own contents, once drawn, are fully
## determined and never re-rolled.
##
## This class does not own a card table (GDD OQ-6, not yet designed) — the
## caller supplies the full pool of [Card] instances a specific battle
## starts with, the same way [method Unit.roster_from_text] separates
## parsing from a caller-supplied blob rather than owning file I/O itself.
class_name CardDeck
extends RefCounted

## Cards dealt at the start of a battle, before the first turn (GDD Core
## Rules 二).
const OPENING_HAND_SIZE: int = 5

## Maximum number of cards a hand may hold without triggering a forced
## discard (GDD Core Rules 二 / Edge Cases).
const HAND_SIZE_LIMIT: int = 5

## Cards drawn at the start of every player turn (GDD Core Rules 二). A
## Tuning Knob, not an incidental constant — the GDD explicitly warns that
## raising this to 2 would reverse the "scarcity is temporal" design
## decision, so [method draw_for_turn] honors this constant rather than
## hardcoding a single draw.
const CARDS_DRAWN_PER_TURN: int = 1

# Cards not currently in the player's hand or the used pile. Order carries
# no gameplay meaning — only membership does.
var _pool: Array[Card] = []

# Cards currently in the player's hand.
var _hand: Array[Card] = []

# Cards played or discarded this battle, not yet returned to the pool. See
# the class doc comment for why this bucket must exist rather than either
# card returning to _pool immediately or never returning at all.
var _used: Array[Card] = []

# Injected draw source — see class doc comment on why this must never be
# the engine's global RNG.
var _rng: RandomNumberGenerator

# True from the moment a draw_for_turn() call grows an already-full hand
# past HAND_SIZE_LIMIT, until discard_card() is called to bring the hand
# back down. Edge Cases: the discard choice belongs to the player — this
# class never picks a card to discard on its own; it only exposes that a
# choice is owed, via has_pending_discard().
var _pending_discard: bool = false


## Builds a deck for one battle. [param cards] becomes the starting pool —
## no cards start in hand or the used pile; call [method deal_opening_hand]
## to deal the opening 5. [param rng] must be supplied by the caller for any
## code path that needs deterministic draws (tests, or anything replaying a
## fixed seed); if omitted, a freshly-constructed, unseeded
## [RandomNumberGenerator] is used, matching the engine's own default
## (time-seeded) behavior.
func _init(cards: Array[Card], rng: RandomNumberGenerator = null) -> void:
	_pool.append_array(cards)
	_rng = rng if rng != null else RandomNumberGenerator.new()


## Deals up to [constant OPENING_HAND_SIZE] cards into the hand. If the pool
## has fewer cards than that, deals as many as exist and stops — Edge Cases:
## "卡池張數少於開局手牌數" is legal and must not error.
func deal_opening_hand() -> void:
	for _i: int in range(OPENING_HAND_SIZE):
		if not _draw_one_into_hand():
			break


## The start-of-turn draw (GDD Core Rules 二: [constant CARDS_DRAWN_PER_TURN]
## card(s), every player turn). If the hand was already at
## [constant HAND_SIZE_LIMIT] before this call and at least one card was
## actually drawn, [method has_pending_discard] becomes true and stays true
## until [method discard_card] resolves it — the caller (the turn/round
## driver, outside this story's scope) is responsible for blocking further
## turn progression while it is true.
##
## Asserts the caller resolved any previous pending discard first — calling
## this again while [method has_pending_discard] is already true would let
## the hand grow past [constant HAND_SIZE_LIMIT] + 1, which no rule in the
## GDD describes.
func draw_for_turn() -> void:
	assert(
		not _pending_discard,
		"CardDeck.draw_for_turn: called while a forced discard is still " +
		"pending -- resolve it with discard_card() first"
	)
	var was_full: bool = _hand.size() >= HAND_SIZE_LIMIT
	var drew_any: bool = false
	for _i: int in range(CARDS_DRAWN_PER_TURN):
		if _draw_one_into_hand():
			drew_any = true
	if drew_any and was_full:
		_pending_discard = true


## True while the player owes a forced discard (a [method draw_for_turn]
## call grew an already-full hand). This class never picks the card itself
## — Edge Cases: "不得由系統代選". The caller is expected to poll this to
## decide whether to block turn progression (AC-10's logic half).
func has_pending_discard() -> bool:
	return _pending_discard


## Moves [param card] from hand to the used pile — one of the two ways a
## card leaves the hand (the other is [method discard_card]). Returns
## [code]false[/code] and changes nothing if [param card] is not currently
## in hand. Deliberately does NOT clear [method has_pending_discard]: GDD
## Detailed Rules 二 requires the pending discard specifically be resolved
## by discarding ("強制玩家棄一張"), not by playing a card away.
func play_card(card: Card) -> bool:
	return _move_hand_card_to_used(card)


## Moves [param card] from hand to the used pile, and — if a forced discard
## was pending — clears that flag. Returns [code]false[/code] and changes
## nothing if [param card] is not currently in hand.
func discard_card(card: Card) -> bool:
	if not _move_hand_card_to_used(card):
		return false
	_pending_discard = false
	return true


## Battle-end half of AC-11 (AC-11b): every card still in hand or the used
## pile returns to the pool, and any still-pending forced discard is
## cleared — a discard owed in a battle that just ended has nothing left to
## resolve against. Story 002's card-modifier counterpart (clearing 甲類
## modifiers on battle end) is a separate call the battle-end driver must
## also make; this method only ever touches card position, never any
## modifier state.
func return_all_to_pool() -> void:
	_pool.append_array(_hand)
	_pool.append_array(_used)
	_hand.clear()
	_used.clear()
	_pending_discard = false


## Copy of the cards currently in the pool. A fresh array each call — safe
## to mutate without affecting deck state — but the [Card] elements
## themselves are shared references, not copies (identity is how
## [method play_card] / [method discard_card] find "this exact card"
## again).
func pool() -> Array[Card]:
	var copy: Array[Card] = []
	copy.append_array(_pool)
	return copy


## Copy of the cards currently in hand. See [method pool] for the copy's
## semantics.
func hand() -> Array[Card]:
	var copy: Array[Card] = []
	copy.append_array(_hand)
	return copy


## Copy of the cards currently in the used pile. See [method pool] for the
## copy's semantics.
func used() -> Array[Card]:
	var copy: Array[Card] = []
	copy.append_array(_used)
	return copy


## Number of cards currently in the pool.
func pool_size() -> int:
	return _pool.size()


## Number of cards currently in hand.
func hand_size() -> int:
	return _hand.size()


## Number of cards currently in the used pile.
func used_size() -> int:
	return _used.size()


## Sum of pool + hand + used sizes — the invariant AC-12 requires to stay
## constant across any sequence of draws, plays, and discards within a
## battle (cards are never created or destroyed, only moved between the
## three buckets this class owns).
func total_card_count() -> int:
	return _pool.size() + _hand.size() + _used.size()


# Draws one card from the pool at a random index (via the injected _rng)
# into the hand. Returns false and changes nothing if the pool is empty —
# Edge Cases: "卡池抽空" must not crash, and this is the one place that
# guarantee is enforced.
func _draw_one_into_hand() -> bool:
	if _pool.is_empty():
		return false
	var index: int = _rng.randi_range(0, _pool.size() - 1)
	var card: Card = _pool[index]
	_pool.remove_at(index)
	_hand.append(card)
	return true


# Shared by play_card() / discard_card(): removes card from hand and
# appends it to the used pile. Returns false and changes nothing if card is
# not currently in hand.
func _move_hand_card_to_used(card: Card) -> bool:
	var hand_index: int = _hand.find(card)
	if hand_index == -1:
		return false
	_hand.remove_at(hand_index)
	_used.append(card)
	return true
