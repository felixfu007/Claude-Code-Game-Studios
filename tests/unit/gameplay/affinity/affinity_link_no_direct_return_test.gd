## Governance test — 2026-09-16 manager ruling (second review pass, this conversation):
## protect the contract [method AffinityLink.links_from_text]'s doc comment describes
## (returns [code]null[/code] on a parse failure, an [code]Array[AffinityLink][/code] —
## possibly empty and LEGAL — otherwise) with an EXECUTABLE test rather than relying on
## code review alone to keep catching it.
##
## [b]Why this matters if violated[/b]: a function declared with a concrete, non-Variant
## return type (e.g. [code]-> Array[AffinityLink][/code]) that does
## [code]return AffinityLink.links_from_text(...)[/code] directly hits a real, measured
## engine behavior — confirmed by an independent reviewer's own headless Godot 4.7.1
## probe — where returning [code]null[/code] from such a function prints
## [code]SCRIPT ERROR: Trying to return a value of type "Nil" from a function whose
## return type is "Array[AffinityLink]".[/code] and the CALLER silently receives an empty
## array, not [code]null[/code] and not a crash. That silently re-collapses the exact
## ambiguity ("a row failed to parse" vs. "there are genuinely zero rows") the 2026-09-16
## ruling(s) exist to remove — through a different entry point than the one already fixed
## in [code]src/ui/battle/battle_screen.gd[/code]. And the printed [code]SCRIPT ERROR[/code]
## is not guaranteed to register as a GdUnit4 test failure — the same "loud in a terminal,
## silent in the return value" shape already registered in
## [code].claude/docs/coding-standards.md[/code]'s 2026-09-15 [code]assert()[/code] entry.
##
## [b]This is a 乙類 (source-discipline scan) test per [code].claude/rules/test-standards.md[/code]
## — required disclosure per that section's 2026-09-16 ruling:[/b]
##
## 1. [b]Why this can't be replaced by dependency injection or a runtime check[/b]: the
##    defect this guards against is a TEXT-LEVEL authoring mistake in caller code — writing
##    `return AffinityLink.links_from_text(...)` instead of capturing the `Variant` result
##    and branching on `null` first. There is no object to inject and no runtime behavior to
##    assert on the CALLEE ([method links_from_text] itself is already covered by
##    [code]affinity_link_test.gd[/code]) — the thing that needs to never exist is a specific
##    SOURCE PATTERN in caller code, wherever that caller happens to live. Scanning the text
##    is the only way to assert "this pattern is absent" rather than "this pattern, when
##    exercised, behaves a certain way".
##
## 2. 🔴 [b]Scan roots deliberately include `res://tests`, not just `res://src`[/b] — this is
##    WIDER than the literal boundary text in `.claude/rules/test-standards.md`'s 乙類 table
##    ("唯讀 `src/**/*.gd` 的文字"). Flagged rather than silently done: every currently-known
##    instance of this exact anti-pattern (four call sites, fixed in this same batch of
##    changes — see `affinity_phi_provider_test.gd`, `affinity_rules_test.gd`,
##    `card_permanent_write_test.gd`, `affinity_pool_write_port_test.gd`) lived in `tests/`,
##    not `src/`. A scan restricted to `res://src` would find zero violations both before and
##    after any future regression of this exact bug, because `src/` never called
##    `links_from_text()` this way in the first place — it would provide no protection
##    against the specific regression this test exists to catch. This test proceeds on the
##    dispatching coordinator's explicit instruction to cover both roots; the discrepancy
##    with the written 乙類 boundary is not resolved here and should be reconciled in
##    `.claude/rules/test-standards.md` directly (either by widening that table's boundary
##    text to match, or by the manager deciding this test should be narrowed instead).
##    `res://addons` is still never scanned, matching the existing 乙類 precedent exactly.
##
## [b]What this test actually checks, and its known blind spots[/b] — read this before
## trusting a green result, per this project's "定義域必須等於宣稱範圍" discipline:
##
## This is a plain-text scan of every `.gd` file under `res://src` and `res://tests` (NOT
## `res://addons`) — it does not execute or introspect any code, and it does not touch the
## scene tree. A line is skipped if its trimmed text begins with `#`, covering both this
## codebase's `##` doc-comment convention and ordinary `#` line comments — every one of the
## four fixed call sites above now explains itself in a comment that quotes the literal
## banned text `return AffinityLink.links_from_text(...)` in prose; an unfiltered scan would
## misreport all four as violations of the very rule their comments explain.
##
## The scan tracks, per file, the MOST RECENTLY SEEN `func` line's declared return type by
## matching `func NAME(...) -> TYPE:` (optionally `static func`), and treats every
## subsequent line up to the next `func` line as "inside a function declared to return
## TYPE". A `return AffinityLink.links_from_text(` line is a violation only if the tracked
## TYPE is present and is neither `Variant` nor `void` (a `void`-returning function cannot
## legally `return` a value at all, so this case does not arise in valid GDScript, but is
## excluded defensively).
##
## Known gaps this scan does NOT close (disclosed rather than silently assumed away):
## - Multi-line `func` signatures (parameters split across lines inside the parentheses)
##   would not match the signature regex below and would leave the PREVIOUS function's
##   tracked return type in effect for the new function's body — a false negative if the
##   new function also has a non-Variant return type, or a false positive if it does not
##   and the previous one did. Every `func` in this codebase today is single-line.
## - A lambda (`func(...): ...`) declared INSIDE a tracked function's body does not reset
##   or independently track its own return type; `return AffinityLink.links_from_text(...)`
##   written inside such a lambda would be misattributed to the ENCLOSING named function's
##   declared return type rather than the lambda's own (usually absent/Variant) one. No
##   lambda in this codebase currently calls `links_from_text()`.
## - Storing the call result in an intermediate variable typed as the SAME concrete type
##   (e.g. `var x: Array[AffinityLink] = AffinityLink.links_from_text(...)` — a different bug
##   from the one this test targets, since a typed VARIABLE assignment behaves differently
##   from a typed FUNCTION RETURN under this reviewer's probe) is NOT matched and NOT a
##   violation by this test's definition; that hazard is a separate, not-yet-registered
##   concern this test makes no claim about.
## - Bracket/string-key access or reflection-based returns (`return call("links_from_text")`,
##   `Callable(...).call()`) would not match the regex and would go undetected.
## - A trailing inline `#` comment on the SAME line as the banned call is not stripped before
##   matching; a false positive is possible in that shape but has not been observed.
## - [b]Zero violations found proves the pattern is absent from TEXT under the two scanned
##   roots today — it is not a proof that no caller anywhere in the project could ever
##   reintroduce this bug through a mechanism this scan does not recognize.[/b]
extends GdUnitTestSuite


const _SCAN_ROOTS: Array[String] = ["res://src", "res://tests"]

## Matches a single-line GDScript function signature and captures its declared return type,
## e.g. `func _links(text: String) -> Array[AffinityLink]:` captures `Array[AffinityLink]`,
## and `static func links_from_text(text: String) -> Variant:` captures `Variant`. A
## trailing same-line comment after the final `:` is tolerated (non-capturing) since it does
## not change the declared type.
const _FUNC_SIGNATURE_PATTERN: String = "^\\s*(?:static\\s+)?func\\s+\\w+\\s*\\(.*\\)\\s*->\\s*(.+?)\\s*:(?:\\s*#.*)?$"

## Matches the common multi-line signature continuation this codebase actually uses when a
## parameter list is split across lines — the closing `)` and `-> TYPE:` alone on their own
## line, e.g. `battle_screen.gd`'s `_fail_load()`:
##     func _fail_load(
##         terrain_failure: LoadFailure, roster_failure: LoadFailure, affinity_failure: LoadFailure
##     ) -> void:
## Added specifically because this file's OWN `_scan_dir()` / `_scan_file()` below are written
## in exactly this multi-line style, and without this second pattern the scan would silently
## mis-track their return type from whatever function happened to be seen last — see this
## file's header, blind-spot #1. Still does NOT close every multi-line shape (e.g. the arrow
## and type on a line separate from the closing paren) — narrower gaps of the same kind
## remain and are disclosed there rather than chased indefinitely.
const _FUNC_SIGNATURE_CONTINUATION_PATTERN: String = "^\\s*\\)\\s*->\\s*(.+?)\\s*:(?:\\s*#.*)?$"

## Matches `return AffinityLink.links_from_text(` — the exact banned shape. Deliberately
## does NOT match a `var x = AffinityLink.links_from_text(...)` assignment (a different
## question this test makes no claim about — see this file's header, blind-spot #3).
const _BANNED_RETURN_PATTERN: String = "^\\s*return\\s+AffinityLink\\.links_from_text\\s*\\("

## Declared return types that are always SAFE regardless of match — `Variant` can already
## legally hold `null`, and `void` cannot syntactically appear here in valid GDScript
## (excluded defensively per this file's header note).
const _SAFE_RETURN_TYPES: Array[String] = ["Variant", "void"]


func test_no_typed_return_function_directly_returns_links_from_text() -> void:
	# Arrange
	var signature_regex := RegEx.new()
	var signature_compile_error: Error = signature_regex.compile(_FUNC_SIGNATURE_PATTERN)
	assert_int(signature_compile_error).append_failure_message(
		"This test's own function-signature RegEx failed to compile (error %s) — the scan "
		% error_string(signature_compile_error)
		+ "is broken, this says nothing about the production/test code. Fix the pattern first."
	).is_equal(OK)

	var continuation_regex := RegEx.new()
	var continuation_compile_error: Error = continuation_regex.compile(
		_FUNC_SIGNATURE_CONTINUATION_PATTERN
	)
	assert_int(continuation_compile_error).append_failure_message(
		"This test's own signature-continuation RegEx failed to compile (error %s) — the "
		% error_string(continuation_compile_error)
		+ "scan is broken, this says nothing about the production/test code. Fix the pattern first."
	).is_equal(OK)

	var return_regex := RegEx.new()
	var return_compile_error: Error = return_regex.compile(_BANNED_RETURN_PATTERN)
	assert_int(return_compile_error).append_failure_message(
		"This test's own banned-return RegEx failed to compile (error %s) — the scan is "
		% error_string(return_compile_error)
		+ "broken, this says nothing about the production/test code. Fix the pattern first."
	).is_equal(OK)

	# Act
	var violations: Array = []
	for root: String in _SCAN_ROOTS:
		_scan_dir(root, signature_regex, continuation_regex, return_regex, violations)

	# Assert
	assert_int(violations.size()).append_failure_message(_violation_message(violations)).is_equal(0)


func _violation_message(violations: Array) -> String:
	var lines: Array = []
	for v in violations:
		lines.append("  %s:%d: %s  [enclosing return type: %s]" % [
			v["path"], v["line"], v["text"], v["return_type"]
		])
	return (
		"AffinityLink.links_from_text() returns null on a parse failure and a legal "
		+ "(possibly empty) Array[AffinityLink] otherwise (2026-09-16 second manager "
		+ "ruling). A function declared with a concrete, non-Variant return type that "
		+ "does `return AffinityLink.links_from_text(...)` directly lets a `null` parse "
		+ "failure get silently coerced back into an empty array by the engine — the "
		+ "exact ambiguity this project's two 2026-09-16 rulings exist to remove, "
		+ "reopened through a different entry point. Capture the result in a `Variant` "
		+ "local, branch on `null`, and fail loudly (never `assert()`) instead. Found %d "
		+ "violation(s):\n%s"
	) % [violations.size(), "\n".join(lines)]


func _scan_dir(
	dir_path: String,
	signature_regex: RegEx,
	continuation_regex: RegEx,
	return_regex: RegEx,
	violations: Array
) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_scan_dir(full_path, signature_regex, continuation_regex, return_regex, violations)
		elif entry.ends_with(".gd"):
			_scan_file(full_path, signature_regex, continuation_regex, return_regex, violations)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_file(
	file_path: String,
	signature_regex: RegEx,
	continuation_regex: RegEx,
	return_regex: RegEx,
	violations: Array
) -> void:
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	var line_number: int = 0
	var current_return_type: String = ""
	while not f.eof_reached():
		var raw_line: String = f.get_line()
		line_number += 1
		var trimmed: String = raw_line.strip_edges()
		if trimmed.begins_with("#"):
			continue

		var signature_match: RegExMatch = signature_regex.search(raw_line)
		if signature_match != null:
			current_return_type = signature_match.get_string(1).strip_edges()
			continue

		var continuation_match: RegExMatch = continuation_regex.search(raw_line)
		if continuation_match != null:
			current_return_type = continuation_match.get_string(1).strip_edges()
			continue

		if return_regex.search(raw_line) != null:
			if not current_return_type.is_empty() and not _SAFE_RETURN_TYPES.has(current_return_type):
				violations.append({
					"path": file_path,
					"line": line_number,
					"text": trimmed,
					"return_type": current_return_type,
				})
