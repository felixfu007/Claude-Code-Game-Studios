## One-way conversion: a roster id from `assets/data/units/vs01_roster.txt`
## (1-based; player characters 1~5 correspond to 甲乙丙丁戊, enemies occupy
## 6~10) into the [enum AffinityTypes.Character] ordinal (0-based) that
## [AffinityDataPool] / [method AffinityTypes.pair_of] actually understand.
##
## Story: production/epics/affinity-position-chain/
## story-004-affinity-pool-instance-and-id-mapping.md (deliverable P-2). This
## is the ONLY thing this story delivers on the mapping side — the story's
## "實作決定" section records why [AffinityDataPool] instance wiring (the
## remainder of P-1: giving [AffinityPhiProvider] or its replacement a
## constructor-injected reference to the pool) is left for story-005 instead
## of being built here.
##
## Governing ADR: docs/architecture/adr-0002-affinity-data-pool-data-structure-and-concurrency-contract.md,
## Mechanism 四之四 — every ordinal entering [method AffinityTypes.pair_of]
## must be validated first via [method AffinityTypes.is_valid_character].
##
## 🔴 [b]Shared-constant decision[/b] (this story's explicit obligation — pick
## one, name the trade-off): the roster-id offset is NOT redefined here. It is
## read directly from
## [constant AffinityPoolWritePort.ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET]
## (`src/gameplay/cards/affinity_pool_write_port.gd`), the write-side adapter
## that already validated this exact mapping in production (story-008). That
## constant was promoted from a leading-underscore (convention-only private)
## name to a public one as part of THIS story, specifically so this file
## could reference it instead of copying its value.
##
## [b]Why extraction over duplication, for this constant specifically[/b]:
## this project has registered "the same rule implemented twice, agreeing
## only by coincidence today" as its most-repeated failure shape (see
## `.claude/docs/technical-preferences.md` and the structural guard test
## `tests/unit/gameplay/affinity/affinity_manhattan_implementation_count_test.gd`,
## which exists precisely because a black-box comparison of outputs cannot
## tell "one shared implementation" apart from "two that happen to agree
## today"). Manhattan distance was deliberately kept as TWO independent
## copies because the GDD has an explicit decoupling rationale for that case
## ([method AffinityRules.manhattan_distance]'s own doc comment — merging
## would couple the Gameplay affinity module to the combat module). No such
## rationale exists for this offset: it is a single scalar constant with no
## architectural reason to diverge between the read and write sides. Sharing
## it costs one cross-reference from this file (filed under
## `src/gameplay/affinity/`) into a file physically filed under the
## card-system directory (`src/gameplay/cards/`) — that coupling is judged
## cheaper than the risk of the two sides silently drifting apart, which a
## black-box comparison of their outputs could never distinguish from "always
## agreed on purpose".
##
## 🔴 [b]Single direction only — does NOT guard `a == b`.[/b] This class
## answers "what Character does this roster id map to", nothing more. It
## never builds an [enum AffinityTypes.Pair] and therefore never exercises
## [method AffinityTypes.pair_of]'s OTHER undefined-input case: that
## function's own doc comment states that passing the SAME
## [enum AffinityTypes.Character] for both arguments ("a == b — not a valid
## pairing") is undefined input too, and the caller must reject it BEFORE
## calling [method AffinityTypes.pair_of] — exactly what
## [method AffinityPoolWritePort.append_record] does with its own
## `character_a == character_b` check, immediately after performing the same
## two roster-id conversions this file performs.
## [b]Calling this mapper twice and feeding both results into
## [method AffinityTypes.pair_of] does NOT make that check unnecessary.[/b]
## A future caller that builds a pair this way (expected to be story-005)
## must perform its own equality check on the two converted
## [enum AffinityTypes.Character] values first. This class deliberately does
## not do that here — this story has no caller that builds a pair yet, and
## guessing at story-005's exact interface would be inventing scope nobody
## asked for.
class_name AffinityRosterCharacterMapper
extends RefCounted


## Converts [param roster_id] to its [enum AffinityTypes.Character] ordinal,
## or returns [code]null[/code] (after logging via
## [method @GlobalScope.push_error]) when [param roster_id] is not one of the
## five player roster ids (1~5). Enemy roster ids (6~10) and any other
## out-of-range input are rejected the same way, before anything is handed to
## [method AffinityTypes.pair_of].
##
## Returns [Variant] rather than a bare [enum AffinityTypes.Character] on
## purpose, following this project's existing convention for "may fail"
## conversions ([method AffinityLink.links_from_text], guarded by
## `affinity_link_no_direct_return_test.gd`): a failed conversion must be
## distinguishable from a legitimately-valid result, never silently coerced
## into one. [b]Callers must check for [code]null[/code] before using the
## result — do not cast it directly.[/b]
##
## 🔴 Deliberately does NOT use [code]assert()[/code] to guard this branch.
## Per `.claude/docs/coding-standards.md`'s "絕不用 assert() 守衛會回傳 enum
## 的分支" rule: an [code]assert()[/code] failure aborts the calling function
## and yields ordinal 0 of the declared return type — and ordinal 0 of
## [enum AffinityTypes.Character] is
## [constant AffinityTypes.Character.CHARACTER_1], a perfectly legal
## character. Using [code]assert()[/code] here would make an out-of-range
## roster id silently read back as "甲" instead of "conversion failed" the
## moment a caller only inspects the return value.
static func character_for_roster_id(roster_id: int) -> Variant:
	var character: AffinityTypes.Character = (
		roster_id - AffinityPoolWritePort.ROSTER_ID_TO_CHARACTER_ORDINAL_OFFSET
	)
	if not AffinityTypes.is_valid_character(character):
		push_error(
			(
				"AffinityRosterCharacterMapper.character_for_roster_id: roster_id %d is out of "
				+ "range (valid player roster ids are 1~5; 6~10 are enemy ids and never map to a "
				+ "Character)."
			) % roster_id
		)
		return null
	return character
