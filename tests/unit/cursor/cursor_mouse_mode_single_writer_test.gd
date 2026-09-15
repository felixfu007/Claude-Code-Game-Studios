## Governance test — 2026-09-15 manager ruling (dispatch, this conversation): protect
## ADR-0005 Core Rules #5 / [code]NativePointerVisibilityArbiter[/code]'s own class doc
## comment ("Owns the ONLY write to [member Input.mouse_mode] in this system") with an
## EXECUTABLE test rather than a `docs/registry/architecture.yaml` `forbidden_patterns`
## entry. Reason given: that registry has no automated check today, so a new entry there
## would be one more rule that silently goes unenforced — the exact failure mode the
## manager is trying to close.
##
## [b]Why this matters if violated[/b]: [member Input.mouse_mode] is a single global engine
## property, not per-node state. A second writer would not error, crash, or log anything —
## it would silently "last write wins" against this arbiter on every frame the two
## disagree. The only visible symptom is an intermittent flicker of the OS pointer, which
## is exactly the kind of defect this project's own screenshot-evidence rules
## (`.claude/docs/coding-standards.md`) are bad at catching, because a single frame can
## still look correct.
##
## [b]What this test actually checks, and its known blind spots[/b] — read this before
## trusting a green result, per this project's "定義域必須等於宣稱範圍" discipline:
##
## This is a plain-text scan of every `.gd` file under [code]res://src[/code] (NOT
## [code]res://tests[/code] or [code]res://addons[/code]) — it does not execute or
## introspect the production code at all. A line is skipped if its trimmed text begins
## with `#`, which covers this codebase's `##` doc-comment convention. This is not a
## cosmetic choice: [code]native_pointer_visibility_arbiter.gd[/code]'s own class doc
## comment and [code]self_drawn_reclaim_cursor.gd[/code]'s own class doc comment both
## quote the literal text `Input.mouse_mode` in prose (to explain the very rule this test
## enforces) — an unfiltered scan would misreport 2+ files as writers of a property neither
## of those specific lines writes.
##
## Known gaps this scan does NOT close (disclosed rather than silently assumed away):
## - An assignment split across multiple physical lines, built via string
##   interpolation, or performed through `Callable`/`set("mouse_mode", ...)` reflection,
##   or written as `Input["mouse_mode"] = ...` (bracket/string-key access instead of dot
##   access), would not match the regex below and would go undetected (false negative).
## - A trailing inline `#` comment on the SAME line as unrelated real code is not
##   stripped before matching; if such a comment happened to contain the literal text
##   `Input.mouse_mode =`, it would be miscounted as a writer (false positive — the safer
##   direction of the two, but still a real gap).
## - [b]"single_writer" names what the assertion counts, not a proof of exhaustiveness[/b]:
##   this test proves there is exactly one DOT-ASSIGNMENT TEXT SITE matching this pattern
##   under `res://src/**/*.gd`. It does NOT prove `Input.mouse_mode` cannot be changed by
##   any other mechanism at all — a `.tscn`/`.tres` exported-property default, a
##   GDExtension/native call, or an addon script outside `src/` would all be invisible to
##   this scan and would still be a real second writer in the sense the manager's ruling
##   cares about. The gap between the two: this test is a regression guard against the
##   textual pattern this codebase actually uses today, not a structural proof that no
##   other pattern could ever exist.
## - Compound assignment (`+=`, `-=`, `*=`, `/=`) IS matched by design, since it is still
##   a write. Plain comparison (`==`, `!=`) is explicitly excluded via a negative lookahead
##   on the pattern — verified against this exact file's own `if Input.mouse_mode !=
##   desired:` line, which must NOT count as a second writer.
extends GdUnitTestSuite


const _SRC_ROOT: String = "res://src"
const _ALLOWED_WRITER: String = "res://src/ui/cursor/native_pointer_visibility_arbiter.gd"

## Matches `Input.mouse_mode =`, `Input.mouse_mode +=`, etc. The trailing `(?!=)` refuses
## a match where the matched `=` is itself immediately followed by another `=` (i.e. the
## text was actually the comparison operator `==`), and the required `=` character after
## optional whitespace already fails to align with `!=` (the `!` is not whitespace), so
## both comparison operators are excluded without needing a second lookahead.
const _PATTERN: String = "Input\\.mouse_mode\\s*[+\\-*/]?=(?!=)"


func test_only_native_pointer_visibility_arbiter_writes_input_mouse_mode() -> void:
	# Arrange
	var regex := RegEx.new()
	var compile_error: Error = regex.compile(_PATTERN)
	assert_int(compile_error).append_failure_message(
		"This test's own RegEx pattern %s failed to compile (error %s) — the scan is " % [
			_PATTERN, error_string(compile_error)
		] + "broken, this says nothing about the production code. Fix the pattern first."
	).is_equal(OK)

	# Act
	var sites: Array = _scan_for_pattern(_SRC_ROOT, regex)

	# Assert
	assert_int(sites.size()).append_failure_message(_violation_message(sites)).is_equal(1)
	if sites.size() == 1:
		assert_str(sites[0]["path"]).append_failure_message(_violation_message(sites)).is_equal(
			_ALLOWED_WRITER
		)


func _violation_message(sites: Array) -> String:
	var lines: Array = []
	for site in sites:
		lines.append("  %s:%d: %s" % [site["path"], site["line"], site["text"]])
	return (
		"ADR-0005 Core Rules #5 / NativePointerVisibilityArbiter's own class doc comment: "
		+ "this class must be the ONLY writer of Input.mouse_mode in the whole project. "
		+ "Input.mouse_mode is a single global engine property with no error on "
		+ "conflicting writes — a second writer does not crash or log anything, it "
		+ "silently 'last write wins' every frame the two disagree, and the only symptom "
		+ "is an intermittent flicker of the OS pointer. Expected exactly 1 write site, "
		+ "at %s. Found %d:\n%s" % [_ALLOWED_WRITER, sites.size(), "\n".join(lines)]
	)


func _scan_for_pattern(root: String, regex: RegEx) -> Array:
	var results: Array = []
	_scan_dir(root, regex, results)
	return results


func _scan_dir(dir_path: String, regex: RegEx, results: Array) -> void:
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
			_scan_dir(full_path, regex, results)
		elif entry.ends_with(".gd"):
			_scan_file(full_path, regex, results)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_file(file_path: String, regex: RegEx, results: Array) -> void:
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		return
	var line_number: int = 0
	while not f.eof_reached():
		var raw_line: String = f.get_line()
		line_number += 1
		var trimmed: String = raw_line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		if regex.search(raw_line) != null:
			results.append({"path": file_path, "line": line_number, "text": trimmed})
