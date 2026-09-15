## Governance test — 2026-09-15 manager ruling (dispatch, this conversation): protect
## ADR-0005 R6-8 (2026-08-21, "hover 判定器是 CanvasLayer 底下的一個獨立節點…不是與機制十三
## 的自繪載體同一節點") with an EXECUTABLE test rather than a `docs/registry/architecture.yaml`
## `forbidden_patterns` entry, for the same reason as this file's sibling
## [code]cursor_mouse_mode_single_writer_test.gd[/code]: that registry has no automated
## check today, so a new entry there would be one more rule that silently goes unenforced.
##
## [b]Why this matters if violated[/b]: [member CanvasItem.modulate] (and its `.a` alpha
## channel) is a PER-NODE property, not a value [SelfDrawnReclaimCursor] and
## [NativePointerVisibilityArbiter] could ever share safely even if merged onto one node.
## [SelfDrawnReclaimCursor]'s own class doc comment and R6-8 both spell out the concrete
## failure: if the mouse-reclaim fade-alpha write ever lands on the SAME node as the
## native-pointer hover suppression, that node's visibility would be dragged along with
## the reclaim fade — the hover suppression would intermittently fade out and back in for
## reasons having nothing to do with hover state. This is a behavioral bug, not a style
## preference (both source files say so explicitly).
##
## 🔴 [b]This test closes a gap the existing structural test does NOT cover[/b] —
## [code]cursor_layer_transform_test.gd[/code]'s
## [code]test_ac_s010b_cursor_layer_has_exactly_the_two_story_011_presentation_nodes()[/code]
## asserts there are exactly 2 children of the correct CLASSES under `_cursor_layer`. That
## catches "the two got merged into one node" but does NOT catch "still two nodes, but the
## `modulate.a` WRITE got moved onto [NativePointerVisibilityArbiter]'s node instead of
## staying on [SelfDrawnReclaimCursor]'s" — which is the actual R6-8 hazard. This test
## targets the write site directly instead of the node count.
##
## [b]What this test actually checks, and its known blind spots[/b] — read this before
## trusting a green result, per this project's "定義域必須等於宣稱範圍" discipline:
##
## This is a plain-text scan of every `.gd` file under [code]res://src[/code] (NOT
## [code]res://tests[/code] or [code]res://addons[/code]) — it does not execute or
## introspect the production code, and it does not touch the scene tree at all. A line is
## skipped if its trimmed text begins with `#`, which covers this codebase's `##`
## doc-comment convention. This is not a cosmetic choice: at least three files in
## `src/ui/cursor/` (`cursor_state_host.gd`, `mouse_reclaim_policy.gd`,
## `native_pointer_visibility_arbiter.gd`) quote the literal text `modulate.a` in prose
## specifically to explain this exact rule — an unfiltered scan would misreport all of
## them as writers of a property none of those lines actually write.
##
## Known gaps this scan does NOT close (disclosed rather than silently assumed away):
## - An assignment split across multiple physical lines, or performed through
##   `Callable`/`set("modulate", ...)`/`set("a", ...)` reflection on the `Color`, would not
##   match the regex below and would go undetected (false negative). Writing through
##   `self.modulate = Color(r, g, b, new_alpha)` (replacing the whole `Color`, not just
##   `.a`) would ALSO be a false negative — this scan only recognizes the `.a`-suffixed
##   spelling actually used today, not every way alpha could be mutated.
## - A trailing inline `#` comment on the SAME line as unrelated real code is not
##   stripped before matching; if such a comment happened to contain the literal text
##   `modulate.a =`, it would be miscounted as a writer (false positive — the safer
##   direction of the two, but still a real gap).
## - Bracket/string-key access (`get_node("...")["modulate"]`-style or
##   `set_indexed("modulate:a", ...)`) would also go undetected — same shape of gap as
##   the sibling test's `Input["mouse_mode"]` case.
## - [b]"single_writer" names what the assertion counts, not a proof of exhaustiveness[/b]:
##   this test proves there is exactly one DOT-ASSIGNMENT TEXT SITE matching this pattern
##   under `res://src/**/*.gd`. It does NOT prove `modulate.a` cannot be changed by any
##   other mechanism — a `.tscn` animation track, a shader-driven visual property, or an
##   addon script outside `src/` would all be invisible to this scan. The gap between the
##   two: this is a regression guard against the textual pattern this codebase actually
##   uses today, not a structural proof that no other pattern could ever exist.
## - Compound assignment (`+=`, `-=`, `*=`, `/=`) IS matched by design, since it is still a
##   write. Plain comparison (`==`) is explicitly excluded via a negative lookahead —
##   verified against this exact system's own `# expressed purely through modulate.a ==
##   0.0` comment line (already excluded as a whole-line comment) and would additionally be
##   excluded by the lookahead even if it were not.
extends GdUnitTestSuite


const _SRC_ROOT: String = "res://src"
const _ALLOWED_WRITER: String = "res://src/ui/cursor/self_drawn_reclaim_cursor.gd"

## Matches `modulate.a =`, `modulate.a +=`, etc., excluding the comparison `==` via the
## trailing negative lookahead (same technique and same rationale as the sibling test's
## `Input.mouse_mode` pattern — see that file for the full derivation).
const _PATTERN: String = "modulate\\.a\\s*[+\\-*/]?=(?!=)"


func test_only_self_drawn_reclaim_cursor_writes_modulate_alpha() -> void:
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
		"ADR-0005 R6-8 (2026-08-21): SelfDrawnReclaimCursor and " +
		"NativePointerVisibilityArbiter must be two separate nodes specifically because " +
		"CanvasItem.modulate is a PER-NODE property — if the modulate.a write ever lands " +
		"on, or moves to, any node other than SelfDrawnReclaimCursor, that node's own " +
		"visibility gets dragged along with the mouse-reclaim fade animation, which for " +
		"NativePointerVisibilityArbiter's node means the native-pointer hover suppression " +
		"would intermittently fade for reasons unrelated to hover state — a real " +
		"behavioral bug per that class's own doc comment, not a style concern. Expected " +
		"exactly 1 write site, at %s. Found %d:\n%s" % [
			_ALLOWED_WRITER, sites.size(), "\n".join(lines)
		]
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
