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

## Roster id of the first unit of the pair. Also the perspective used by
## [method AffinityRules.board_lines] when deciding suppression.
var unit_a: int

## Roster id of the second unit of the pair.
var unit_b: int

## POSITIVE or NEGATIVE relationship.
var polarity: Polarity

## Multiplier applied to the base delta. The prototype always used 1.
var amp: int


## Parses a single pairing-table line into an [AffinityLink]. Field order is
## fixed: [code]unit_a,unit_b,polarity,amp[/code].
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
	link.polarity = _polarity_from_string(fields[2])
	link.amp = int(fields[3])
	assert(
		link.unit_a != link.unit_b,
		"AffinityLink.from_csv_line: a unit cannot be paired with itself: %s" % line
	)
	return link


## Parses an entire pairing-table text blob (as read from an affinity data
## file) into an array of [AffinityLink]s, one per non-skipped line. Blank
## lines and lines starting with [code]#[/code] are skipped.
static func links_from_text(text: String) -> Array[AffinityLink]:
	var links: Array[AffinityLink] = []
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		links.append(AffinityLink.from_csv_line(line))
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


## Maps the data file's polarity string to a [enum Polarity] value. Uses a
## [code]match[/code] rather than an enum-name subscript, which would abort the
## calling function on an unknown name (forbidden pattern
## [code]raw_enum_name_subscript_from_untrusted_string[/code]).
static func _polarity_from_string(value: String) -> Polarity:
	match value:
		"POSITIVE":
			return Polarity.POSITIVE
		"NEGATIVE":
			return Polarity.NEGATIVE
		_:
			assert(false, "AffinityLink._polarity_from_string: unknown polarity '%s'" % value)
			return Polarity.POSITIVE
