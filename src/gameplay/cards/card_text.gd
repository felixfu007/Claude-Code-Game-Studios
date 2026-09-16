## Card-face flavor text table: parses `id,flavor_text` rows (as read from
## `assets/data/cards/vs01_card_text.txt`) into an `id -> flavor_text` lookup a caller can
## query alongside [Card]'s mechanical data.
##
## Deliberately separate from [Card] (2026-09-15 manager ruling, transcribed in
## `vs01_card_text.txt`'s header): [Card] has no field for display text and this class
## never writes one into a [Card] instance. The file header's own suggested seam is for a
## future loader (not yet implemented — U-003 is the first place both tables are loaded
## together) to parse both tables independently and look each one up by [code]id[/code]
## separately.
##
## Parsing is deliberately split from file reading (this class never touches
## [FileAccess]) — mirrors [method Unit.roster_from_text] and
## [method AffinityLink.links_from_text] so every branch is unit-testable.
class_name CardText
extends RefCounted

## Number of comma-separated fields a parsed line must resolve to: id, flavor_text.
## Unlike [Unit] / [AffinityLink]'s per-line parsers, this format has no enum field to
## validate — the only structural failure this checks is a missing separator (a line with
## no comma at all resolves to 1 field, not 2). [code]assert()[/code] is used here
## deliberately to match the SAME idiom [Unit.from_csv_line] / [AffinityLink.from_csv_line]
## already use for THEIR field-count checks (as opposed to the push_error+null idiom those
## two use for an unrecognized enum string) — there is no enum string in this format for
## that second idiom to apply to.
##
## ⚠️ Known project-level caveat, registered rather than fixed here (2026-09-16, per
## coordinator instruction): [code]assert()[/code] calls are stripped entirely from release
## exports — this field-count guard is a debug-build-only safety net. A malformed line
## (missing comma) reaching this code in a release export would fall through to
## [code]fields[1][/code] on a 1-element array, an out-of-bounds access, not a caught error.
## This is an existing project-wide property of every [code]assert()[/code]-based
## field-count check ([Unit.from_csv_line], [AffinityLink.from_csv_line] included), not
## something introduced by this file — flagged here per instruction, not remediated here.
const FIELD_COUNT: int = 2


## Parses an entire card-text-table blob into a [code]Dictionary[String, String][/code]
## keyed by card [code]id[/code], one entry per non-skipped line. Blank lines and lines
## starting with [code]#[/code] are skipped.
##
## Splits each line on the FIRST comma only ([code]split(",", true, 1)[/code]), never on
## every comma — per [code]vs01_card_text.txt[/code]'s own header warning that
## [code]flavor_text[/code] content is not guaranteed comma-free (no quote-escaping
## convention exists in this table format). Limiting the split means a stray comma inside
## [code]flavor_text[/code] degrades to "the comma stayed in the text, no third field", not
## a silently-truncated string or a thrown exception.
##
## 🔴 [b]Placeholder — deliberately undecided, do not infer an answer from this method's
## current behavior (2026-09-16 coordinator instruction).[/b] What should happen when a
## row's [code]id[/code] duplicates an earlier row's [code]id[/code], or a row is otherwise
## malformed in a way [code]assert()[/code] does not already catch (release-build silence
## included, see [constant FIELD_COUNT]'s doc comment) has NOT been ruled on for this table.
## The manager ruled the SAME DAY that [code]vs01_cards.txt[/code] (this table's sibling —
## [Card]'s own data file) gets "one bad row aborts the whole table, loudly, naming the
## line" (the same discipline already applied to [method Unit.roster_from_text] and
## [method AffinityLink.links_from_text]) — but in the SAME ruling explicitly declined to
## generalize that to a project-wide rule, deciding case-by-case instead. This table's case
## has NOT been decided and is queued for a future ruling. It may or may not land on the
## same answer as [code]vs01_cards.txt[/code]: a bad row in the mechanics table changes what
## a drawn card DOES (a gameplay-legality question); a bad row here only changes what a
## card's face SAYS (a cosmetic question) — the two tables' stakes differ, so their answers
## are not assumed to match. Whoever implements that future ruling: this method currently
## silently overwrites on a duplicate [code]id[/code] (last row wins) and currently has no
## abort-the-whole-table path at all — treat both as accidental byproducts of "not yet
## decided", not as an endorsed design.
static func flavor_texts_from_text(text: String) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",", true, 1)
		assert(
			fields.size() == FIELD_COUNT,
			(
				"CardText.flavor_texts_from_text: expected %d fields (a line with no comma "
				+ "at all?), got %d in line: %s"
			) % [FIELD_COUNT, fields.size(), line]
		)
		result[fields[0]] = fields[1]
	return result
