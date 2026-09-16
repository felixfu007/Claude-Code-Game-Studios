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
## [member affinity_magnitude] as the mechanically-read write amount;
## [member affinity_character_a] / [member affinity_character_b] are
## card-face flavor only as of the 2026-09-10 manager ruling (see their own
## doc comments) — the actual write target is chosen by the player on the
## board and passed to [code]PermanentAffinityWriteRules.play()[/code]
## separately. 丙類 carries no duration — it is a single fire-and-forget
## write, not an ongoing effect. See the class doc comment for why 乙類 has
## no entry here.
enum Category { TEMPORARY_STAT_MODIFIER, PERMANENT_AFFINITY_WRITE }

## Number of comma-separated fields expected per card-table line, in fixed
## order: [code]id,category,delta_atk,delta_def,duration_rounds,
## affinity_character_a,affinity_character_b,affinity_magnitude[/code]. See
## [code]assets/data/cards/vs01_cards.txt[/code]'s header for the field
## definitions and Story U-001
## ([code]production/epics/card-play-interface/story-u001-card-table-parser.md[/code])
## for why a single [Card] constructor cannot consume all 8 columns directly
## (the two existing constructors each take 4 of them, split by [enum Category]).
const FIELD_COUNT: int = 8

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

## 丙類 only — [b]NARRATIVE / CARD-FACE ONLY as of the 2026-09-10 manager
## ruling (design/ux/skill-card-play.md S2p/S2q) — the MECHANICAL target
## pair is chosen by the player on the board at play time, NOT read off
## this field.[/b] [code]PermanentAffinityWriteRules.play()[/code] (Story
## 004) takes the actual pair as caller-supplied parameters instead. This
## field remains so a card's face can still name specific characters (GDD's
## own hard rule: "每一張 MVP 卡牌的牌面都必須是一組具名角色之間的互動",
## e.g. flavor text like "甲對乙說了句話") independent of which pair the
## player ultimately selects — the two are no longer required to match.
## Same roster-id convention as [member AffinityLink.unit_a] when it IS
## used for flavor. -1 is the "unset" sentinel for a
## [constant Category.TEMPORARY_STAT_MODIFIER] card, where this field is
## meaningless.
var affinity_character_a: int = -1

## 丙類 only — second character named on the card's face (see
## [member affinity_character_a] for why this is narrative-only and not
## read by [code]PermanentAffinityWriteRules.play()[/code]).
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


## Parses a single card-table line into a [Card], or returns [code]null[/code]
## if [param line]'s [code]category[/code] field is not a recognized [enum
## Category] name. Field order is fixed: [code]id,category,delta_atk,
## delta_def,duration_rounds,affinity_character_a,affinity_character_b,
## affinity_magnitude[/code] (see [constant FIELD_COUNT]).
##
## Reads [code]category[/code] first and dispatches to exactly one of
## [method new_temporary_stat_modifier] / [method new_permanent_affinity_write]
## — this class's two constructors each take 4 of the 8 columns, split by
## category, so all 8 fields are always read from the line but only 4 are ever
## passed to the constructor actually used (Story U-001, Implementation Note 1).
## The other group's columns are still present in [param line] (per
## [code]vs01_cards.txt[/code]'s convention of filling the unused group with
## its documented sentinel/default) but are never read here — the constructor
## itself already defaults those fields.
##
## 🔴 Returns [code]null[/code] rather than asserting on an unrecognized
## category string — per [code].claude/docs/coding-standards.md[/code]'s
## 2026-09-15 entry, an [code]assert()[/code] on that branch would abort and
## silently yield ordinal 0 of [enum Category] ([constant
## Category.TEMPORARY_STAT_MODIFIER]), making an unknown string
## indistinguishable from a genuine [code]"TEMPORARY_STAT_MODIFIER"[/code]
## match — the exact failure shape that rule and this project's 2026-09-16
## rulings on [method Unit.from_csv_line] / [method AffinityLink.from_csv_line]
## both exist to prevent. [method cards_from_text] is the caller that turns a
## [code]null[/code] result here into a loud, whole-table parse failure — see
## that method's doc comment.
static func from_csv_line(line: String) -> Card:
	var fields: PackedStringArray = line.split(",")
	assert(
		fields.size() == FIELD_COUNT,
		"Card.from_csv_line: expected %d fields, got %d in line: %s"
		% [FIELD_COUNT, fields.size(), line]
	)

	var id: String = fields[0]
	var category: Variant = _category_from_string(fields[1])
	if category == null:
		push_error(
			"Card.from_csv_line: unknown category '%s' in line: %s" % [fields[1], line]
		)
		return null
	if category == Category.TEMPORARY_STAT_MODIFIER:
		return new_temporary_stat_modifier(id, int(fields[2]), int(fields[3]), int(fields[4]))
	return new_permanent_affinity_write(id, int(fields[5]), int(fields[6]), int(fields[7]))


## Parses an entire card-table text blob (as read from a card data file) into
## an array of [Card]s, one per non-skipped line. Blank lines and lines
## starting with [code]#[/code] are skipped, matching [method
## Unit.roster_from_text] / [method AffinityLink.links_from_text].
##
## 🔴 Returns [code]null[/code] — [b]not[/b] an empty array — if any
## non-skipped line fails to parse (currently: an unrecognized
## [code]category[/code] string — see [method from_csv_line]), after logging
## the 1-based line number of the offending row via [method
## @GlobalScope.push_error]. This is the 2026-09-16 manager ruling for THIS
## data table (card-play-interface Story U-001, "停下來,指出第幾行"): a card
## table that is partially valid must not be used as if it were fully valid,
## matching [method Unit.roster_from_text]'s "響亮地停" behavior exactly
## (whole-batch abort, not skip-and-continue) rather than [method
## AffinityLink.links_from_text]'s "genuinely zero rows can be legal" nuance —
## a card table parsing to zero cards is not a meaningful game state the way
## an affinity table parsing to zero links is, so there is no analogous
## empty-but-legal case to preserve here.
##
## 🔴 **This ruling covers card tables only — it is NOT a general project
## rule.** The manager's own 2026-09-16 ruling on this story explicitly kept
## the "A vs B" choice a per-data-table decision rather than adopting a single
## policy for every data file; do not cite this method as precedent for a
## different data table's failure-handling shape without a ruling for that
## table specifically.
##
## Return type is [code]Variant[/code] rather than [code]Array[Card][/code]
## purely to make [code]null[/code] expressible. 🔴 A caller must NEVER
## `return` this method's result directly from a function declared with a
## concrete return type (e.g. [code]-> Array[Card][/code]) — per this
## project's 2026-09-16 measured engine behavior (see
## [code]tests/unit/gameplay/affinity/affinity_link_no_direct_return_test.gd[/code]),
## doing so silently coerces a [code]null[/code] failure back into an empty
## array at the call boundary. Capture the [code]Variant[/code] result in a
## local and branch on [code]null[/code] first, exactly as [method
## AffinityLink.links_from_text]'s callers already do.
static func cards_from_text(text: String) -> Variant:
	var cards: Array[Card] = []
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var card: Card = Card.from_csv_line(line)
		if card == null:
			push_error(
				"Card.cards_from_text: aborting -- invalid data at line %d: %s"
				% [line_number, line]
			)
			return null
		cards.append(card)
	return cards


## Maps the card-table file's category string to a [enum Category] value, or
## returns [code]null[/code] if [param value] is not a recognized name. Uses a
## [code]match[/code] rather than an enum-name subscript, which would abort the
## calling function on an unknown name (forbidden pattern
## [code]raw_enum_name_subscript_from_untrusted_string[/code],
## [code]docs/registry/architecture.yaml[/code]).
##
## 🔴 Returns [code]null[/code] on the unknown branch instead of
## [code]assert(false, ...)[/code] — see [method from_csv_line]'s doc comment
## for why an assert here is exactly the pattern
## [code].claude/docs/coding-standards.md[/code] banned on 2026-09-15: it would
## abort and silently return ordinal 0 of [enum Category] ([constant
## Category.TEMPORARY_STAT_MODIFIER]), making an unknown string
## indistinguishable from a genuine match. [method from_csv_line] is the sole
## caller and is responsible for turning [code]null[/code] into a loud
## failure; this method itself never logs or aborts.
static func _category_from_string(value: String) -> Variant:
	match value:
		"TEMPORARY_STAT_MODIFIER":
			return Category.TEMPORARY_STAT_MODIFIER
		"PERMANENT_AFFINITY_WRITE":
			return Category.PERMANENT_AFFINITY_WRITE
		_:
			return null
