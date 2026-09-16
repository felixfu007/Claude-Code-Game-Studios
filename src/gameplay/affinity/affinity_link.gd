## One row of the affinity pairing table: two units, the polarity of their
## relationship, and an amplitude multiplier.
##
## Pure data holder — no affinity math lives here. The distance-to-bonus rule
## is owned by [AffinityRules] ([code]src/gameplay/affinity/affinity_rules.gd[/code]);
## this class only parses and stores the pairing table that rule consumes.
##
## Parsing is deliberately split from file reading (this class never touches
## [FileAccess]) so every branch is unit-testable, mirroring
## [method Unit.roster_from_text].
##
## Two different authorities, deliberately kept apart. The table's SHAPE (a
## pair of units, a polarity, a multiplier) is ported from the prototype's
## [code]state.pairs[/code]. The table's CONTENT — which characters actually
## like or dislike each other — comes from
## [code]design/narrative/characters.md[/code] section 3 (Canon level:
## Established) and lives in
## [code]assets/data/affinity/vs01_affinity_links.txt[/code]. The prototype's
## own A~E pairs are abstract placeholders and must NOT be copied in.
class_name AffinityLink
extends RefCounted

## Whether the two units like each other (positive) or not (negative).
enum Polarity { POSITIVE, NEGATIVE }

## Number of comma-separated fields expected per table line, in fixed order:
## unit_a,unit_b,polarity,amp
const FIELD_COUNT: int = 4

## Roster id of the first unit of the pair. Also the perspective
## [method AffinityRules.board_lines] evaluates from — but see R8 in
## [code]design/gdd/affinity-position-chain.md[/code]: since R4 removed
## suppression, a line's contribution is identical from either endpoint, so
## which unit is treated as "first" no longer changes any result.
var unit_a: int

## Roster id of the second unit of the pair.
var unit_b: int

## POSITIVE or NEGATIVE relationship.
var polarity: Polarity

## Multiplier applied to the base delta. The prototype always used 1, and
## every row in the current static table format is documented to carry
## exactly [constant AMP_EXPECTED] (see this class's own header comment and
## [code]assets/data/affinity/vs01_affinity_links.txt[/code]'s header
## comment). Reserved for a future dialogue-card multiplier effect whose
## legal range is not yet decided (OQ-3 in
## [code]design/gdd/affinity-position-chain.md[/code] — deciding it now
## would be a guess owned by system #6). Not clamped or rejected here; a
## value other than [constant AMP_EXPECTED] is used exactly as parsed and
## only logged — see [method from_csv_line].
var amp: int

## The only [member amp] value the current static table format documents as
## legal (see [code]assets/data/affinity/vs01_affinity_links.txt[/code]'s own
## header comment: "amp:倍率,目前一律 1"). [method from_csv_line] flags any
## row that deviates from this documented invariant.
const AMP_EXPECTED: int = 1

## [method push_warning] format for a row whose [member amp] deviates from
## [constant AMP_EXPECTED]. See that constant's doc comment for why this is
## a warning, not an abort.
const _LOG_AMP_OUT_OF_RANGE_FORMAT: String = (
	"AffinityLink.from_csv_line: amp %d for pair %d-%d is outside the " +
	"documented current value (amp == %d) -- likely a data-entry typo per " +
	"design/gdd/affinity-position-chain.md Edge Cases, not a deliberate " +
	"tuning value. The link is still used exactly as parsed; Formula 三's " +
	"Phi clamp (AffinityRules.PHI_MIN/PHI_MAX) bounds the eventual total " +
	"regardless."
)


## Parses a single pairing-table line into an [AffinityLink], or returns
## [code]null[/code] if [param line]'s polarity field is not a recognized
## [enum Polarity] name. Field order is fixed:
## [code]unit_a,unit_b,polarity,amp[/code].
##
## 🔴 Returns [code]null[/code] rather than asserting on an unrecognized
## polarity string — per [code].claude/docs/coding-standards.md[/code]'s
## 2026-09-15 entry, an [code]assert()[/code] on that branch would abort and
## silently yield ordinal 0 of [enum Polarity] ([constant Polarity.POSITIVE]),
## which is indistinguishable from a genuine match and would (in a release
## build, where asserts are stripped entirely) silently treat a data-entry
## typo as a real, legal pairing. [method links_from_text] is the caller that
## turns a [code]null[/code] result here into a loud, whole-table parse
## failure — see that method's doc comment.
static func from_csv_line(line: String) -> AffinityLink:
	var fields: PackedStringArray = line.split(",")
	assert(
		fields.size() == FIELD_COUNT,
		"AffinityLink.from_csv_line: expected %d fields, got %d in line: %s"
		% [FIELD_COUNT, fields.size(), line]
	)

	var link: AffinityLink = AffinityLink.new()
	link.unit_a = int(fields[0])
	link.unit_b = int(fields[1])
	var polarity: Variant = _polarity_from_string(fields[2])
	if polarity == null:
		push_error(
			"AffinityLink.from_csv_line: unknown polarity '%s' in line: %s" % [fields[2], line]
		)
		return null
	link.polarity = polarity
	link.amp = int(fields[3])
	assert(
		link.unit_a != link.unit_b,
		"AffinityLink.from_csv_line: a unit cannot be paired with itself: %s" % line
	)
	# amp 超出合法值域是資料錯誤(design/gdd/affinity-position-chain.md Edge
	# Cases),但這不是中止解析的理由——中止會讓呼叫端連同其餘合法列一起讀不
	# 到,比記錄後繼續讀還要糟。log-and-continue:仍照原樣使用解析到的值
	# (Φ 的夾限,見 AffinityRules.bonus_for_at,會在總和層擋住任何後果),只
	# 留下一筆可觀測的診斷紀錄,讓寫錯的資料列日後被人發現、而不是永遠沉默。
	if link.amp != AMP_EXPECTED:
		push_warning(
			_LOG_AMP_OUT_OF_RANGE_FORMAT % [link.amp, link.unit_a, link.unit_b, AMP_EXPECTED]
		)
	return link


## Parses an entire pairing-table text blob (as read from an affinity data
## file) into an array of [AffinityLink]s, one per non-skipped line. Blank
## lines and lines starting with [code]#[/code] are skipped.
##
## 🔴 If any non-skipped line fails to parse (currently: an unrecognized
## polarity string — see [method from_csv_line]), the [b]entire[/b] result is
## discarded and an empty array is returned, after logging the 1-based line
## number of the offending row via [method @GlobalScope.push_error]. This is
## deliberate, matching the 2026-09-16 manager ruling for this failure ("響亮
## 地停" — loud stop, not skip-and-continue): a table that is partially valid
## must not be used as if it were fully valid, since which row was corrupt is
## exactly the information a silent partial load would throw away.
##
## ⚠️ The caller of this method ([code]src/ui/battle/battle_screen.gd[/code])
## currently treats an empty result from this method as the pre-existing
## legal "no pairings configured" design state (a [method push_warning], not
## a load failure — see that file's [code]_ready()[/code] doc comment) and
## therefore still lets the battle start. Making a corrupted-row result
## actually block the battle (as the ruling intends) requires that caller to
## be able to distinguish "genuinely zero rows" from "a row failed to parse",
## which this method's return value alone cannot carry — that is an
## out-of-scope change to [code]battle_screen.gd[/code], flagged rather than
## made. Until that lands, a corrupted affinity row is at least never
## silently used as if it were valid data (the defect this change fixes),
## but it does not yet stop the game from starting.
static func links_from_text(text: String) -> Array[AffinityLink]:
	var links: Array[AffinityLink] = []
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var link: AffinityLink = AffinityLink.from_csv_line(line)
		if link == null:
			push_error(
				"AffinityLink.links_from_text: aborting -- invalid data at line %d: %s"
				% [line_number, line]
			)
			return []
		links.append(link)
	return links


## Returns [code]true[/code] if [param unit_id] is one of the two units on
## this link.
func involves(unit_id: int) -> bool:
	return unit_id == unit_a or unit_id == unit_b


## Returns the id of the other unit on this link. [param unit_id] must be one
## of the two units — check with [method involves] first.
func partner_of(unit_id: int) -> int:
	assert(
		involves(unit_id),
		"AffinityLink.partner_of: unit %d is not on link %d-%d" % [unit_id, unit_a, unit_b]
	)
	return unit_b if unit_id == unit_a else unit_a


## Maps the data file's polarity string to a [enum Polarity] value, or
## returns [code]null[/code] if [param value] is not a recognized name. Uses a
## [code]match[/code] rather than an enum-name subscript, which would abort the
## calling function on an unknown name (forbidden pattern
## [code]raw_enum_name_subscript_from_untrusted_string[/code]).
##
## 🔴 Returns [code]null[/code] on the unknown branch instead of
## [code]assert(false, ...)[/code] — see [method from_csv_line]'s doc comment
## for why an assert here is exactly the pattern
## [code].claude/docs/coding-standards.md[/code] banned on 2026-09-15: it
## would abort and silently return ordinal 0 of [enum Polarity]
## ([constant Polarity.POSITIVE]), making an unknown string indistinguishable
## from a genuine [code]"POSITIVE"[/code] match. [method from_csv_line] is the
## sole caller and is responsible for turning [code]null[/code] into a loud
## failure; this method itself never logs or aborts.
static func _polarity_from_string(value: String) -> Variant:
	match value:
		"POSITIVE":
			return Polarity.POSITIVE
		"NEGATIVE":
			return Polarity.NEGATIVE
		_:
			return null
