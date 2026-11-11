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
## no comma at all resolves to 1 field, not 2).
##
## 2026-11-11 管理者裁決(story-038):欄數檢查改為 push_error + 整表拒絕,發行版也有效
## (assert 在 release 匯出會被整條移除,檢查會消失)。見
## production/epics/tactical-combat/story-038-release-safe-data-parsing.md。
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
## 🔴 [b]壞列的處置已決(2026-11-11 管理者裁決,見 story-038):整表拒絕。[/b]
## 任何一列缺逗號 -> [code]push_error()[/code](含行號)後回傳 [b]空字典[/b],整張表不採用
## (比照 [method Unit.roster_from_text] / [method AffinityLink.links_from_text])。本方法回傳
## 具型別 [code]Dictionary[/code],無法表達 null,故以空字典表示失敗;接收端
## (battle_screen.gd 的 [code]_card_flavor_texts[/code])對缺牌面文字本來就以 [code]""[/code]
## 退回,所以不需改動。
##
## 🔴 重複 [code]id[/code] 仍【未裁決】:目前後者覆蓋前者,屬「尚未決定」的副產品,
## 不是背書的設計。
static func flavor_texts_from_text(text: String) -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	var line_number: int = 0
	for raw_line: String in text.split("\n"):
		line_number += 1
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields: PackedStringArray = line.split(",", true, 1)
		if fields.size() != FIELD_COUNT:
			push_error(
				(
					"CardText.flavor_texts_from_text: aborting -- expected %d fields (a line "
					+ "with no comma at all?), got %d at line %d: %s"
				) % [FIELD_COUNT, fields.size(), line_number, line]
			)
			return {}
		result[fields[0]] = fields[1]
	return result
