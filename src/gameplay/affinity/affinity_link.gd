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
