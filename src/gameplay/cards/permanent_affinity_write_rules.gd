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
## [b]These two are deliberately NOT fused into one "play if legal"
## function.[/b] [method play] performs no legality pre-check of its own —
## it is a pure pass-through to [param port]. This is load-bearing, not a
## style choice: AC-7b requires proving a bypass call (skipping the
## selection UI entirely, e.g. a corrupted save or a future UI bug) is
## rejected BY THE PORT, not intercepted upstream by this file. If
## [method play] pre-filtered dead pairs itself, no test could ever tell
## "the port's own defense works" apart from "this file's defense works" —
## and the day a real [code]AffinityDataPool[/code] replaces the injected
## port, nobody would know which side the dead-pair check actually lives
## on. [method legal_pairs] exists purely to constrain what a SELECTION UI
## (Story 005, out of this story's scope) offers the player; it has no
## effect on what [method play] itself will accept.
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
## ([param character_a], [param character_b]) currently a legal 丙類 target?
## Order-independent — matches [method AffinityLink.involves]'s own
## order-independence.
static func is_legal_target(
	links: Array[AffinityLink], is_alive: Callable, character_a: int, character_b: int
) -> bool:
	for link: AffinityLink in legal_pairs(links, is_alive):
		if link.involves(character_a) and link.involves(character_b):
			return true
	return false


## Writes [param card]'s own baked-in pair ([member Card.affinity_character_a]/
## [member Card.affinity_character_b]) and magnitude
## ([member Card.affinity_magnitude]) through [param port], with
## [constant AffinityWritePort.SOURCE_COMBAT_CARD] as the source (GDD
## Formula 三).
##
## [param card] must be [constant Card.Category.PERMANENT_AFFINITY_WRITE] —
## asserted, not silently ignored, since calling this on a 甲類 card would
## silently forward that category's "unset" sentinel values
## ([code]-1[/code], [code]-1[/code], [code]0[/code] — see [Card]'s own doc
## comments on those fields) as if they were a real target and magnitude.
##
## Returns whatever [param port] returns, unmodified. See this class's own
## header comment for why this function must not pre-validate [param m]
## (including [code]m == 0[/code]) or the pair's legality itself — every
## rejection decision belongs to [param port].
static func play(card: Card, port: AffinityWritePort) -> AffinityWritePort.Rejection:
	assert(
		card.category == Card.Category.PERMANENT_AFFINITY_WRITE,
		"PermanentAffinityWriteRules.play: card '%s' is not a PERMANENT_AFFINITY_WRITE card"
		% card.id
	)
	return port.append_record(
		card.affinity_character_a,
		card.affinity_character_b,
		card.affinity_magnitude,
		AffinityWritePort.SOURCE_COMBAT_CARD
	)
