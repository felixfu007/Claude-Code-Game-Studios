## Pure rule functions for 丙類 (permanent affinity write) cards —
## [code]production/epics/skill-card-system/story-004-permanent-write-port.md[/code].
## Two independent concerns, each a stateless [code]static func[/code] with
## no side effects, mirroring [CardModifierRules]'s shape
## ([code]src/gameplay/cards/card_modifier_rules.gd[/code]):
##
## 1. [method legal_pairs] / [method is_legal_target] — which pairs a 丙類
##    card could legally target right now (a query; GDD Core Rules 一之三
##    界線 3/4 + the Edge Cases 陣亡配對 row).
## 2. [method play] — actually writing one card's own baked-in pair through
##    an [AffinityWritePort] (GDD Formula 三).
##
## [b]2026-09-10 manager ruling — the pair is now chosen by the player, not
## read off the card.[/b] (design/ux/skill-card-play.md S2p/S2q): S2p offers
## every ally with an existing canon relationship line who is alive; S2q
## then restricts to whichever of THAT ally's partners share a line with
## them (typically 1 in the vertical slice). [method play] therefore takes
## the target pair as caller-supplied parameters — it no longer reads
## [member Card.affinity_character_a] / [member Card.affinity_character_b]
## at all (those fields are now card-face flavor only; see their own doc
## comments in [code]card.gd[/code]). This opened a NEW bypass path this
## file did not have to defend before: a caller could hand [method play] a
## pair with no canon relationship line whatsoever (e.g. one involving 戊),
## which the real future pool would happily accept — GDD 界線 4 says the
## pool has zero awareness of narrative canon. [method play] therefore now
## checks [method has_canon_link] itself, BEFORE ever calling [param port],
## and returns [constant AffinityWritePort.Rejection.INVALID_PAIR] without
## making that call at all if it fails.
##
## [b]These two concerns are still deliberately split, and NOT fused into
## one "play if legal" function — but the split line moved.[/b] [method play]
## now performs exactly ONE pre-check of its own ([method has_canon_link] —
## canon existence, ignoring liveness), and nothing else. It still does
## [b]not[/b] check liveness itself: AC-7b requires proving that a bypass
## call carrying a canon pair with a DEAD member is rejected BY THE PORT,
## not intercepted upstream by this file, because the real future pool DOES
## have that awareness (ADR-0002's [code]t_death()[/code] /
## [code]DEAD_PAIR_COMBAT_CARD_FORBIDDEN[/code]) and this story's test needs
## to prove that defense line actually exists at the port level. Canon
## existence and liveness are therefore checked in two different places on
## purpose: the pool structurally CANNOT defend canon existence (so this
## file must), and the pool DOES defend liveness (so this file must not
## pre-empt it, per AC-7b). [method legal_pairs] still exists purely to
## constrain what a SELECTION UI (Story 005, out of this story's scope)
## offers the player for S2p/S2q — it combines BOTH canon existence AND
## liveness, because a selection list should never offer a dead ally in the
## first place; [method has_canon_link] is the narrower, liveness-blind
## check [method play] itself uses.
class_name PermanentAffinityWriteRules
extends RefCounted


## Returns the subset of [param links] where BOTH units are currently
## alive, per [param is_alive] ([code]func(unit_id: int) -> bool[/code],
## deliberately a [Callable] rather than requiring a full [Unit]/
## [BattleState] graph — this function only ever needs a yes/no per roster
## id, and a [Callable] keeps it testable without constructing either).
##
## The legal set is DERIVED from [param links], never enumerated as "all 10
## combinatorial pairs minus a blocklist". This is what makes GDD 界線 3
## ("合法配對隨劇情推進自動擴大") true without this file changing when a new
## relationship line is added to
## [code]assets/data/affinity/vs01_affinity_links.txt[/code]: a pair with no
## entry in [param links] (e.g. anything involving 戊/roster id 5 in the
## vertical slice) can never appear in the result, by construction — no
## separate 界線 4 check is needed here. See this class's own header comment
## and GDD Core Rules 一之三 for why 界線 4's only defense is exactly this
## derivation (the affinity data pool itself has zero awareness of
## [code]characters.md[/code]'s relationship lines).
##
## [param links] is expected to come from
## [method AffinityLink.links_from_text] / [method AffinityPhiProvider.links]
## — the same authority [AffinityRules] already reads Φ from. This function
## never reads a file itself.
static func legal_pairs(links: Array[AffinityLink], is_alive: Callable) -> Array[AffinityLink]:
	var result: Array[AffinityLink] = []
	for link: AffinityLink in links:
		if is_alive.call(link.unit_a) and is_alive.call(link.unit_b):
			result.append(link)
	return result


## Convenience membership check built on [method legal_pairs]: is the pair
## ([param character_a], [param character_b]) currently a legal 丙類 target
## (i.e. a candidate a SELECTION UI should offer — both canon-linked AND
## alive)? Order-independent — matches [method AffinityLink.involves]'s own
## order-independence.
static func is_legal_target(
	links: Array[AffinityLink], is_alive: Callable, character_a: int, character_b: int
) -> bool:
	for link: AffinityLink in legal_pairs(links, is_alive):
		if link.involves(character_a) and link.involves(character_b):
			return true
	return false


## Returns [code]true[/code] if [param character_a] and [param character_b]
## have an existing relationship line in [param links] AT ALL — deliberately
## ignoring whether either unit is currently alive (see this class's own
## header comment for why liveness is checked by [param port] instead, not
## here). This is the ONLY legality check [method play] performs itself.
static func has_canon_link(
	links: Array[AffinityLink], character_a: int, character_b: int
) -> bool:
	for link: AffinityLink in links:
		if link.involves(character_a) and link.involves(character_b):
			return true
	return false


## Writes the pair ([param character_a], [param character_b]) — chosen by
## the player on the board (design/ux/skill-card-play.md S2p/S2q), NOT read
## off [param card] — with [param card]'s own magnitude
## ([member Card.affinity_magnitude]) through [param port], using
## [constant AffinityWritePort.SOURCE_COMBAT_CARD] as the source (GDD
## Formula 三).
##
## [param card] must be [constant Card.Category.PERMANENT_AFFINITY_WRITE] —
## asserted, not silently ignored, since calling this on a 甲類 card would
## silently forward its "unset" [code]affinity_magnitude[/code] sentinel
## ([code]0[/code] — see [Card]'s own doc comment on that field) as if it
## were a real write amount.
##
## Checks [method has_canon_link] first and returns
## [constant AffinityWritePort.Rejection.INVALID_PAIR] WITHOUT calling
## [param port] at all if it fails (see this class's own header comment for
## why this is the one pre-check this function is allowed to make). If the
## pair passes that check, returns whatever [param port] returns,
## unmodified — this function still does not pre-validate [param m]
## (including [code]m == 0[/code]) or liveness; those rejection decisions
## belong to [param port].
static func play(
	card: Card, character_a: int, character_b: int, links: Array[AffinityLink], port: AffinityWritePort
) -> AffinityWritePort.Rejection:
	assert(
		card.category == Card.Category.PERMANENT_AFFINITY_WRITE,
		"PermanentAffinityWriteRules.play: card '%s' is not a PERMANENT_AFFINITY_WRITE card"
		% card.id
	)
	if not has_canon_link(links, character_a, character_b):
		return AffinityWritePort.Rejection.INVALID_PAIR
	return port.append_record(
		character_a,
		character_b,
		card.affinity_magnitude,
		AffinityWritePort.SOURCE_COMBAT_CARD
	)
