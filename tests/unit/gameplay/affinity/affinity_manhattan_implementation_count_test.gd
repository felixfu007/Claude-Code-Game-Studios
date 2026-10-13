## Story 007 (好感度—位置連鎖系統 Epic #5, M5): structural guard on the NUMBER of
## independent Manhattan-distance implementations in `res://src`.
##
## [b]What this guards[/b]: `design/gdd/affinity-position-chain.md` R2 deliberately allows TWO
## independent implementations — [method AffinityRules.manhattan_distance] and
## [method CombatRules._manhattan_distance] — rather than merging them into one shared
## function, because merging would couple this Gameplay-layer module to the combat module
## (see [code]affinity_rules.gd[/code]'s own doc comment on [method manhattan_distance] for the
## GDD-level rationale). The two-implementations design is only safe because a SEPARATE test
## ([code]affinity_rules_test.gd[/code]'s AC-R2 case) already proves their OUTPUT agrees. This
## test proves something a black-box output comparison structurally cannot: that today there
## are still exactly two independent implementations — not one (silently merged, which would
## mean the GDD's decoupling decision silently stopped being honoured and nobody noticed), and
## not three (a new one grew somewhere and was never wired into the AC-R2 agreement test).
##
## [b]This is a 乙類 (source-discipline scan) test per [code].claude/rules/test-standards.md[/code]
## — required disclosure per that section's 2026-09-16 ruling:[/b]
##
## 1. [b]Why this can't be replaced by dependency injection or a runtime check[/b]: the property
##    being guarded — "how many textually-independent Manhattan-distance functions exist in the
##    source tree" — is a fact about the TEXT of the codebase, not about any object's runtime
##    behavior. Two independent implementations that happen to compute the same thing are, by
##    construction, indistinguishable from the outside at runtime — calling both with the same
##    inputs yields the same outputs whether there are two independent copies or secretly one
##    function called twice through two names. There is no object to inject and no behavior to
##    assert on that would tell these two situations apart; only reading the source text can.
##
## 2. 🔴 [b]Scan root is `res://src` ONLY — deliberately narrower than the
##    [code]affinity_link_no_direct_return_test.gd[/code] precedent, which also scans
##    `res://tests`[/b]. That precedent widened to `res://tests` because every historically-known
##    instance of the bug it guards against lived in `tests/`. This guard is different: it counts
##    PRODUCTION implementations of Manhattan distance, and both known ones
##    ([method AffinityRules.manhattan_distance], [method CombatRules._manhattan_distance]) live
##    in `res://src`. Restricting the scan root to `res://src` is also what makes this file
##    STRUCTURALLY unable to match itself: this file lives under `res://tests`, so even though
##    its own header prose repeats the word "manhattan" dozens of times and its own helper
##    functions are named things like `_scan_for_manhattan_declarations`, none of that text is
##    ever inside the scanned root — there is no comment-filtering trick being relied on here to
##    keep this file's own text out of its own count; the scan never looks at this file's
##    directory at all. (Comment-line filtering is still applied in [constant _SAFE] — see
##    `_scan_file()` below — as defense in depth against false positives from production-code
##    doc comments that quote a declaration, e.g. `world_layout.gd`'s header, which references
##    "the Manhattan-distance duplication case" in prose but declares no such function itself.)
##
## [b]What this test actually checks, and its known blind spots[/b] — read this before trusting
## a green result, per this project's "定義域必須等於宣稱範圍" discipline:
##
## This is a plain-text scan of every `.gd` file under `res://src` (not `res://tests`, not
## `res://addons`). It does not execute or introspect any code. A line is skipped if its
## trimmed text begins with `#` (covers both `##` doc comments and ordinary `#` comments). Among
## the remaining lines, a line counts as ONE independent implementation if it is a single-line
## function DECLARATION (optionally `static`) whose NAME contains the substring "manhattan"
## (case-insensitive) — e.g. `static func manhattan_distance(...)`  or
## `static func _manhattan_distance(...)`. Declarations are matched by requiring the `func`
## keyword to appear immediately before the matched name; this is what structurally excludes
## CALL sites (`return AffinityRules.manhattan_distance(...)` has no `func` keyword immediately
## before the name, so it never matches) without needing a separate call-site exclusion list.
##
## Known gaps this scan does NOT close (disclosed per the story's required obligation #2,
## rather than silently assumed away):
## - [b]Rename to something that drops the substring "manhattan" entirely[/b] (e.g. renaming
##   [method CombatRules._manhattan_distance] to `_grid_distance`) would silently drop that
##   implementation from the count — the scan would then wrongly report 1, correctly FAILING the
##   "exactly 2" assertion, but the failure message would not explain that a rename (rather than
##   a deletion) is what happened. A human reading the diff is still required to tell those apart.
## - [b]Splitting into multiple helper functions that are then composed[/b] (e.g. two private
##   one-axis helpers `_dx(...)` / `_dy(...)` called from a single summing function) would be
##   counted as ONE implementation if only the composing function's name contains "manhattan",
##   or ZERO if none of the fragments do — either way the scan cannot tell "one function split
##   into helpers" apart from "an implementation quietly disappeared".
## - [b]Folding into a more general distance function[/b] (e.g. a generic
##   `static func chebyshev_or_manhattan(from, to, mode) -> int:`) is counted as a match only
##   because "manhattan" still appears in that name; a generalization named something unrelated
##   (`static func _grid_metric(...)`) would NOT be counted, silently losing this test's coverage
##   of that implementation entirely.
## - [b]Multi-line function signatures[/b] (parameters split across lines) are not matched by the
##   single-line pattern below and would not be counted at all. Both known implementations are
##   single-line today.
## - [b]A function whose name merely contains "manhattan" but whose body computes something
##   unrelated[/b] (e.g. a stub, or a renamed-but-never-updated leftover) would be wrongly
##   counted as an implementation — this scan reads names, not bodies, and makes no claim about
##   what a matched function's body actually computes.
## - [b]Zero violations found[/b] (here: "count equals exactly 2") proves this textual property
##   of `res://src` today — it is not a proof that no future change could add, remove, or hide an
##   implementation through a mechanism this scan does not recognize.
extends GdUnitTestSuite


const _SCAN_ROOT: String = "res://src"

## Matches a single-line GDScript function declaration whose name contains the substring
## "manhattan" (case-insensitive), e.g. `static func manhattan_distance(from, to) -> int:` or
## `static func _manhattan_distance(from: Vector2i, to: Vector2i) -> int:`. Requiring `func` to
## appear immediately before the captured name is what excludes call sites
## (`AffinityRules.manhattan_distance(...)`, `return CombatRules._manhattan_distance(...)`)
## without a separate exclusion list — a call site never has the literal word `func` directly
## before the identifier.
const _DECLARATION_PATTERN: String = "(?i)^\\s*(?:static\\s+)?func\\s+(\\w*manhattan\\w*)\\s*\\("


func test_manhattan_distance_implementation_count_equals_two() -> void:
	# Arrange
	var declaration_regex := RegEx.new()
	var compile_error: Error = declaration_regex.compile(_DECLARATION_PATTERN)
	assert_int(compile_error).append_failure_message(
		"This test's own declaration-matching RegEx failed to compile (error %s) — the scan "
		% error_string(compile_error)
		+ "is broken, this says nothing about the production code. Fix the pattern first."
	).is_equal(OK)

	# Act
	var matches: Array = []
	_scan_dir(_SCAN_ROOT, declaration_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(_match_message(matches)).is_equal(2)


func _match_message(matches: Array) -> String:
	var lines: Array = []
	for m in matches:
		lines.append("  %s:%d: %s" % [m["path"], m["line"], m["text"]])
	return (
		"R2 (design/gdd/affinity-position-chain.md) allows exactly TWO independent "
		+ "Manhattan-distance implementations in res://src — today's expected pair is "
		+ "AffinityRules.manhattan_distance() and CombatRules._manhattan_distance() (or a "
		+ "renamed equivalent). Found %d matching declaration(s) instead:\n%s\n"
		+ "If this is fewer than 2: one implementation was removed/merged — re-evaluate whether "
		+ "R2's decoupling decision (allow two copies, test them for agreement) still applies. "
		+ "If this is more than 2: a third independent implementation appeared — either wire it "
		+ "into the AC-R2 agreement test (affinity_rules_test.gd) or remove the redundant copy."
	) % [matches.size(), "\n".join(lines)]


func _scan_dir(dir_path: String, declaration_regex: RegEx, matches: Array) -> void:
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
			_scan_dir(full_path, declaration_regex, matches)
		elif entry.ends_with(".gd"):
			_scan_file(full_path, declaration_regex, matches)
		entry = dir.get_next()
	dir.list_dir_end()


func _scan_file(file_path: String, declaration_regex: RegEx, matches: Array) -> void:
	var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if f == null:
		push_error("affinity_manhattan_implementation_count_test: could not open '%s' for read (error %s) — counted as zero matches from this file, which could silently undercount." % [file_path, error_string(FileAccess.get_open_error())])
		return
	var line_number: int = 0
	while not f.eof_reached():
		var raw_line: String = f.get_line()
		line_number += 1
		_scan_line(file_path, line_number, raw_line, declaration_regex, matches)


## Pure, file-system-free scan of a SINGLE line, shared verbatim by [method _scan_file] (real
## files under res://src) and this file's `test_sensitivity_proof_*` cases (synthetic text) —
## the same function is exercised both ways so a sensitivity proof against synthetic text is a
## proof about the actual production scan logic, not a parallel reimplementation of it that
## could silently drift from what `_scan_file` really does.
func _scan_line(
	source_label: String,
	line_number: int,
	raw_line: String,
	declaration_regex: RegEx,
	matches: Array
) -> void:
	var trimmed: String = raw_line.strip_edges()
	if trimmed.begins_with("#"):
		return
	var m: RegExMatch = declaration_regex.search(raw_line)
	if m != null:
		matches.append({
			"path": source_label,
			"line": line_number,
			"text": trimmed,
			"name": m.get_string(1),
		})


# ---------------------------------------------------------------------------
# Sensitivity proofs — synthetic text fed to the exact same `_scan_line()` used above, per
# .claude/rules/test-standards.md's 2026-09-16 ruling. These do not touch the filesystem (the
# synthetic "source" lines are plain in-test string arrays, not fixture files), keeping this
# suite's only filesystem access confined to the single 乙類-exempt call path exercised by the
# main test above.
# ---------------------------------------------------------------------------


func test_sensitivity_proof_detects_a_third_implementation() -> void:
	# Arrange — two known-shape declarations plus an extra third one with a different name,
	# simulating the exact regression this story exists to catch ("悄悄長出了第三份").
	var declaration_regex := RegEx.new()
	declaration_regex.compile(_DECLARATION_PATTERN)
	var synthetic_lines: Array = [
		"static func manhattan_distance(from: Vector2i, to: Vector2i) -> int:",
		"static func _manhattan_distance(from: Vector2i, to: Vector2i) -> int:",
		"static func _manhattan_distance_v2(from: Vector2i, to: Vector2i) -> int:",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], declaration_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"Sensitivity proof failed: a THIRD synthetic declaration was injected and the scan did "
		+ "not detect it. The real test would have passed even with a real third implementation "
		+ "present, which is the exact regression this story guards against."
	).is_equal(3)


func test_sensitivity_proof_detects_a_missing_implementation() -> void:
	# Arrange — only ONE of the two known declarations present, simulating one being silently
	# removed/merged ("其中一份被悄悄移除或合併").
	var declaration_regex := RegEx.new()
	declaration_regex.compile(_DECLARATION_PATTERN)
	var synthetic_lines: Array = [
		"static func manhattan_distance(from: Vector2i, to: Vector2i) -> int:",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], declaration_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"Sensitivity proof failed: only ONE synthetic declaration was supplied and the scan "
		+ "reported a different count. The real test would not reliably catch a silent merge "
		+ "down to one implementation, which is the exact regression this story guards against."
	).is_equal(1)


func test_sensitivity_proof_ignores_comment_lines_mentioning_manhattan() -> void:
	# Arrange — lines that TALK ABOUT a Manhattan-distance declaration in prose (both `##` doc
	# comments and plain `#` comments), but never actually declare one. This is the exact shape
	# that caused a false positive in the affinity_link_no_direct_return_test.gd precedent
	# (comments quoting the banned literal text) and the shape flagged by this project's
	# 2026-10-12 "a verification command written inside a comment counts itself as a match" rule
	# in .claude/docs/coding-standards.md.
	var declaration_regex := RegEx.new()
	declaration_regex.compile(_DECLARATION_PATTERN)
	var synthetic_lines: Array = [
		"## See AffinityRules.manhattan_distance() and CombatRules._manhattan_distance() for",
		"## the two deliberately-separate Manhattan-distance implementations (R2).",
		"# static func manhattan_distance(from: Vector2i, to: Vector2i) -> int:  (old, removed)",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], declaration_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"Sensitivity proof failed: every synthetic line here is a COMMENT that merely mentions "
		+ "a Manhattan-distance declaration in prose. The scan must ignore all of them — "
		+ "counting any of them would mean comments can inflate the count, which is exactly the "
		+ "'a verification command written inside a comment counts itself as a match' failure "
		+ "mode registered in .claude/docs/coding-standards.md (2026-10-12)."
	).is_equal(0)


func test_sensitivity_proof_ignores_call_sites() -> void:
	# Arrange — lines that CALL the known implementations, with no `func` declaration anywhere.
	# This proves the scan counts declarations, not usages — per the story's own QA edge case:
	# "掃描不應誤把『呼叫』曼哈頓距離函式的其他程式碼...算進計數"。
	var declaration_regex := RegEx.new()
	declaration_regex.compile(_DECLARATION_PATTERN)
	var synthetic_lines: Array = [
		"\treturn AffinityRules.manhattan_distance(from, to)",
		"\tvar d: int = CombatRules._manhattan_distance(a, b)",
		"\tif AffinityRules.manhattan_distance(x, y) < 2:",
	]

	# Act
	var matches: Array = []
	for i in synthetic_lines.size():
		_scan_line("<synthetic>", i + 1, synthetic_lines[i], declaration_regex, matches)

	# Assert
	assert_int(matches.size()).append_failure_message(
		"Sensitivity proof failed: every synthetic line here CALLS a Manhattan-distance "
		+ "function; none of them DECLARE one. The scan must count zero — counting call sites "
		+ "would inflate the real implementation count arbitrarily with every new caller."
	).is_equal(0)
