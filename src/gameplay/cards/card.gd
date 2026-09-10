## Data definition for a single skill card (好感度對話卡牌) — the value type
## Story 003 (卡池/手牌/已用區), Story 001 (甲類有效值計算,
## [code]card_modifier.gd[/code]), Story 002 (甲類存續/到期), and Story 004
## (丙類合法配對與寫入埠) all share.
##
## Pure data holder — no effect execution lives here. Applying a
## [constant Category.TEMPORARY_STAT_MODIFIER] card's Δatk/Δdef to a [Unit]
## as a [CardModifier], tracking its remaining-rounds countdown, and
## clamping the accumulated total is Story 001/002's responsibility.
## Validating and writing a [constant Category.PERMANENT_AFFINITY_WRITE]
## card into the affinity data pool is Story 004's responsibility. This
## class only carries the numbers a card's face defines; it never decides
## whether they are legal, applies them, or writes anything.
##
## 乙類(暫時性關係極性覆蓋)is deliberately not modeled here —
## [code]design/gdd/skill-card-system.md[/code] Core Rules 一 defines it but
## the MVP does not implement it, and it needs an injection point into
## [code]affinity_rules.gd[/code] that does not exist yet (GDD OQ-10).
## Adding it later means adding a third [enum Category] value and its own
## fields, not repurposing either of the two below.
class_name Card
extends RefCounted

## Which of the two MVP-implemented effect classes this card belongs to.
## [constant TEMPORARY_STAT_MODIFIER] (甲類) uses [member delta_atk],
## [member delta_def], [member duration_rounds] and never touches the
## affinity data pool. [constant PERMANENT_AFFINITY_WRITE] (丙類) uses
## [member affinity_character_a], [member affinity_character_b],
## [member affinity_magnitude] and carries no duration — it is a single
## fire-and-forget write, not an ongoing effect. See the class doc comment
## for why 乙類 has no entry here.
enum Category { TEMPORARY_STAT_MODIFIER, PERMANENT_AFFINITY_WRITE }

## Stable identifier for this card's definition (e.g. a future card-table
## row key). Not yet tied to any card table format — GDD OQ-6 (卡表本體) is
## unresolved — but every [CardDeck] caller needs *some* way to refer to
## "this specific card definition" for logging and debugging. Two [Card]
## instances with the same [member id] are two copies of the same card
## definition, not the same physical card in a player's deck — [CardDeck]
## tracks physical cards by object reference (Godot's default [RefCounted]
## equality), never by this field.
var id: String = ""

## Which effect class this card is. Determines which of the two field
## groups below are meaningful; the other group is left at its default and
## must be ignored by readers.
var category: Category = Category.TEMPORARY_STAT_MODIFIER

## 甲類 only — signed ATK delta this card applies while active (GDD Formula
## 一's [code]Δatkⱼ[/code]). Non-zero by GDD convention, but this class does
## not enforce that; validating a specific card's numbers against the
## tuning knobs in [code]design/quick-specs/unit-stats-provisional.md[/code]
## §7-4 is not this class's job.
var delta_atk: int = 0

## 甲類 only — signed DEF delta (GDD Formula 一's [code]Δdefⱼ[/code]). See
## [member delta_atk] for the same caveats.
var delta_def: int = 0

## 甲類 only — the remaining-rounds countdown a [CardModifier] built from
## this card starts with, [code]r ∈ {1, 2}[/code] per GDD Formula 二. This
## is the card's fixed definition value, not a live counter — [CardDeck]
## never reads or decrements it; Story 001/002's [CardModifier] copies it
## out once (as its own, separately-mutable [code]remaining_turns[/code])
## when the card is played, and owns it from that point on.
var duration_rounds: int = 0

## 丙類 only — first character of the affected pair, as a roster/unit id
## (same convention as [member AffinityLink.unit_a] — see that class for
## why characters are addressed by roster id rather than by name string).
## -1 is the "unset" sentinel for a [constant Category.TEMPORARY_STAT_MODIFIER]
## card, where this field is meaningless.
var affinity_character_a: int = -1

## 丙類 only — second character of the affected pair (see
## [member affinity_character_a]).
var affinity_character_b: int = -1

## 丙類 only — signed write magnitude, GDD Formula 三's [code]m[/code],
## nominal value domain [code]{−3,−2,−1,+1,+2,+3}[/code]. 0 is the "unset"
## sentinel here for a [constant Category.TEMPORARY_STAT_MODIFIER] card —
## note this collides with the domain's own hard rule that a real 丙類
## card's [code]m[/code] must never be 0 (GDD Formula 三, enforced by
## Story 004's write port, AC-9). This class does not itself reject
## [code]m == 0[/code] on a real 丙類 card; that rejection belongs to the
## write port, which sees the value at the moment it would be written, not
## at card-authoring time.
var affinity_magnitude: int = 0


## Builds a 甲類 (temporary stat modifier) card. [param p_duration_rounds]
## is not validated against [code]{1, 2}[/code] here — see the class doc
## comment on why this class does not enforce card-table-level legality.
static func new_temporary_stat_modifier(
	p_id: String, p_delta_atk: int, p_delta_def: int, p_duration_rounds: int
) -> Card:
	var card: Card = Card.new()
	card.id = p_id
	card.category = Category.TEMPORARY_STAT_MODIFIER
	card.delta_atk = p_delta_atk
	card.delta_def = p_delta_def
	card.duration_rounds = p_duration_rounds
	return card


## Builds a 丙類 (permanent affinity write) card. [param p_magnitude] is not
## validated against being non-zero or against any legal-pairing table here
## — see [member affinity_magnitude]'s doc comment; that validation is
## Story 004's write port's job, checked at write time.
static func new_permanent_affinity_write(
	p_id: String, p_character_a: int, p_character_b: int, p_magnitude: int
) -> Card:
	var card: Card = Card.new()
	card.id = p_id
	card.category = Category.PERMANENT_AFFINITY_WRITE
	card.affinity_character_a = p_character_a
	card.affinity_character_b = p_character_b
	card.affinity_magnitude = p_magnitude
	return card
