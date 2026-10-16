# EffectGuessTracker（src/ui/battle/effect_guess_tracker.gd）的單元測試。
#
# battle-hud Story 001(production/epics/battle-hud/story-001-effect-guess-tracker.md）。
# 規格權威：design/quick-specs/battle-hud-prediction-marker.md 第 3 節（判定定義）與
# 第 6 節（驗收條件,編號沿用該節）。
#
# 純邏輯測試，不碰場景樹、不需要真實視窗，不呼叫 AffinityRules —— 與
# tests/unit/ui/world_layout_test.gd / hud_layout_test.gd 同一慣例（RefCounted，非節點）。
#
# 🔴 乙類明文例外（.claude/rules/test-standards.md「單元測試不得碰檔案系統」節）：
# 本檔下方 AC14 區塊的結構守衛測試會用 DirAccess/FileAccess 唯讀掃描
# res://src/**/*.gd 的原始碼文字，斷言「存檔相關檔案沒有參照 EffectGuessTracker」。
# 斷言的對象就是原始碼文字本身，不掃檔案這條斷言就不存在——與
# tests/unit/cursor/cursor_modulate_alpha_single_writer_test.gd 同一類（乙類），
# 不寫入任何檔案，只唯讀 res://src。
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# AC5 — 判定純函式：delta -> EffectDirection。三分支皆覆蓋。
# ---------------------------------------------------------------------------

func test_classify_delta_positive_when_delta_above_zero() -> void:
	# Arrange / Act
	var result: EffectGuessTracker.EffectDirection = EffectGuessTracker.classify_delta(3)

	# Assert
	assert_int(result).is_equal(EffectGuessTracker.EffectDirection.POSITIVE)


func test_classify_delta_negative_when_delta_below_zero() -> void:
	# Arrange / Act
	var result: EffectGuessTracker.EffectDirection = EffectGuessTracker.classify_delta(-2)

	# Assert
	assert_int(result).is_equal(EffectGuessTracker.EffectDirection.NEGATIVE)


func test_classify_delta_neutral_when_delta_is_zero() -> void:
	# Arrange / Act
	var result: EffectGuessTracker.EffectDirection = EffectGuessTracker.classify_delta(0)

	# Assert
	assert_int(result).is_equal(EffectGuessTracker.EffectDirection.NEUTRAL)


# ---------------------------------------------------------------------------
# AC6 — 一格一次(鎖定語意的狀態機部分)。顯示不在本 story 範圍內。
# ---------------------------------------------------------------------------

func test_record_guess_locks_the_cell_it_was_recorded_for() -> void:
	# Arrange
	var tracker := EffectGuessTracker.new()
	var cell := Vector2i(1, 2)
	tracker.begin_move_selection()

	# Act
	tracker.record_guess(cell, EffectGuessTracker.EffectDirection.POSITIVE)

	# Assert
	assert_bool(tracker.has_locked_guess(cell)).is_true()
	assert_int(tracker.get_locked_guess(cell)).is_equal(EffectGuessTracker.EffectDirection.POSITIVE)


func test_record_guess_second_call_on_already_locked_cell_does_not_change_value() -> void:
	# Arrange
	var tracker := EffectGuessTracker.new()
	var cell := Vector2i(1, 2)
	tracker.begin_move_selection()
	tracker.record_guess(cell, EffectGuessTracker.EffectDirection.POSITIVE)

	# Act — second guess for the SAME cell in the SAME move-selection process.
	tracker.record_guess(cell, EffectGuessTracker.EffectDirection.NEGATIVE)

	# Assert — the originally locked value survives, unchanged.
	assert_int(tracker.get_locked_guess(cell)).is_equal(EffectGuessTracker.EffectDirection.POSITIVE)


func test_begin_move_selection_resets_all_cells_to_not_yet_guessed() -> void:
	# Arrange
	var tracker := EffectGuessTracker.new()
	var cell := Vector2i(1, 2)
	tracker.begin_move_selection()
	tracker.record_guess(cell, EffectGuessTracker.EffectDirection.POSITIVE)
	assert_bool(tracker.has_locked_guess(cell)).is_true()

	# Act — "取消選取 / 重新選取棋子" opens a brand new move-selection process.
	tracker.begin_move_selection()

	# Assert — cell A is back to "not yet guessed" in the new process.
	assert_bool(tracker.has_locked_guess(cell)).is_false()
	assert_int(tracker.get_locked_guess(cell)).is_equal(EffectGuessTracker.NO_GUESS)


func test_get_locked_guess_returns_no_guess_sentinel_for_untouched_cell() -> void:
	# Arrange
	var tracker := EffectGuessTracker.new()
	tracker.begin_move_selection()

	# Act / Assert — never recorded, never confirmed: must read as "no guess".
	assert_int(tracker.get_locked_guess(Vector2i(9, 9))).is_equal(EffectGuessTracker.NO_GUESS)


# ---------------------------------------------------------------------------
# AC7 — 只有「已鎖定猜測 + 已確認移動」才計分。共同規則，非兩套判斷。
# ---------------------------------------------------------------------------

func test_confirm_move_with_locked_correct_guess_counts_as_match() -> void:
	# Arrange
	var tracker := EffectGuessTracker.new()
	var cell := Vector2i(1, 2)
	tracker.begin_move_selection()
	tracker.record_guess(cell, EffectGuessTracker.EffectDirection.POSITIVE)

	# Act
	tracker.confirm_move(cell, 5)

	# Assert
	assert_int(tracker.get_scored_total()).is_equal(1)
	assert_int(tracker.get_scored_correct()).is_equal(1)


func test_confirm_move_with_locked_incorrect_guess_counts_as_mismatch() -> void:
	# Arrange
	var tracker := EffectGuessTracker.new()
	var cell := Vector2i(1, 2)
	tracker.begin_move_selection()
	tracker.record_guess(cell, EffectGuessTracker.EffectDirection.POSITIVE)

	# Act — actual delta classifies to NEGATIVE, guess was POSITIVE.
	tracker.confirm_move(cell, -5)

	# Assert — scored (denominator N), but not a match (numerator M).
	assert_int(tracker.get_scored_total()).is_equal(1)
	assert_int(tracker.get_scored_correct()).is_equal(0)


func test_ac7a_confirm_move_on_different_cell_than_guessed_does_not_score() -> void:
	# Arrange — guess locked on cell A, player ends up confirming cell B instead.
	var tracker := EffectGuessTracker.new()
	var cell_a := Vector2i(1, 2)
	var cell_b := Vector2i(3, 4)
	tracker.begin_move_selection()
	tracker.record_guess(cell_a, EffectGuessTracker.EffectDirection.POSITIVE)

	# Act
	tracker.confirm_move(cell_b, 5)

	# Assert — cell A's locked guess never counted toward the denominator or numerator.
	assert_int(tracker.get_scored_total()).is_equal(0)
	assert_int(tracker.get_scored_correct()).is_equal(0)


func test_ac7b_confirm_move_on_never_guessed_cell_does_not_score() -> void:
	# Arrange — cell A confirmed without ever recording a guess for it (skipped).
	var tracker := EffectGuessTracker.new()
	var cell_a := Vector2i(1, 2)
	tracker.begin_move_selection()

	# Act
	tracker.confirm_move(cell_a, 5)

	# Assert
	assert_int(tracker.get_scored_total()).is_equal(0)
	assert_int(tracker.get_scored_correct()).is_equal(0)


# ---------------------------------------------------------------------------
# AC8 — 不可灌水。本 story 最重要的一條。(a)/(b) 兩款各自獨立測試，不合併。
# ---------------------------------------------------------------------------

func test_ac8a_cannot_change_guess_after_reveal_without_cancelling_selection() -> void:
	# Arrange — guess "POSITIVE" on cell A; actual outcome will classify NEGATIVE,
	# i.e. the guess was wrong the instant it was revealed and locked.
	var tracker := EffectGuessTracker.new()
	var cell_a := Vector2i(1, 2)
	tracker.begin_move_selection()
	tracker.record_guess(cell_a, EffectGuessTracker.EffectDirection.POSITIVE)

	# Act — attempt to "change the guess to the now-known-correct answer" without
	# cancelling the move-selection process in between. Per AC6/AC8 this must be a no-op.
	tracker.record_guess(cell_a, EffectGuessTracker.EffectDirection.NEGATIVE)
	tracker.confirm_move(cell_a, -5)

	# Assert — the record must still read as a mismatch, not retroactively "fixed".
	assert_int(tracker.get_scored_total()).is_equal(1)
	assert_int(tracker.get_scored_correct()).is_equal(0)


func test_ac8b_moving_out_and_back_in_does_not_reopen_guessing() -> void:
	# Arrange — guess "POSITIVE" on cell A (actual will be NEGATIVE), then simulate the
	# cursor moving away to cell B and back to cell A, attempting a fresh guess each time
	# it revisits A — none of this may be able to reopen A's lock.
	var tracker := EffectGuessTracker.new()
	var cell_a := Vector2i(1, 2)
	var cell_b := Vector2i(3, 4)
	tracker.begin_move_selection()
	tracker.record_guess(cell_a, EffectGuessTracker.EffectDirection.POSITIVE)

	# Act — cursor moves out to cell B (a guess there is independent and irrelevant)...
	tracker.record_guess(cell_b, EffectGuessTracker.EffectDirection.NEGATIVE)
	# ...then back onto cell A, attempting to re-guess now that A is "known" to be NEGATIVE.
	tracker.record_guess(cell_a, EffectGuessTracker.EffectDirection.NEGATIVE)
	tracker.confirm_move(cell_a, -5)

	# Assert — cell A's original guess (POSITIVE) survived the round trip; still a mismatch.
	assert_int(tracker.get_scored_total()).is_equal(1)
	assert_int(tracker.get_scored_correct()).is_equal(0)


# ---------------------------------------------------------------------------
# AC9 — 一致率計算：M/N。N == 0 的回傳值是本類別自訂的契約（-1.0 哨兵），
# 必須有測試釘住，否則下一個人改成 0.0 不會有任何東西變紅。
# ---------------------------------------------------------------------------

func test_get_consistency_rate_returns_m_over_n_for_three_of_four() -> void:
	# Arrange — 3 correct out of 4 scored confirmations across 4 separate
	# move-selection processes. Deliberately NOT 1/1 or 0/1 — a rate that happened to
	# always compute 1.0 would be indistinguishable from "this always returns 1.0".
	var tracker := EffectGuessTracker.new()

	tracker.begin_move_selection()
	tracker.record_guess(Vector2i(0, 0), EffectGuessTracker.EffectDirection.POSITIVE)
	tracker.confirm_move(Vector2i(0, 0), 5)  # actual POSITIVE -> match

	tracker.begin_move_selection()
	tracker.record_guess(Vector2i(0, 1), EffectGuessTracker.EffectDirection.NEGATIVE)
	tracker.confirm_move(Vector2i(0, 1), -5)  # actual NEGATIVE -> match

	tracker.begin_move_selection()
	tracker.record_guess(Vector2i(0, 2), EffectGuessTracker.EffectDirection.NEUTRAL)
	tracker.confirm_move(Vector2i(0, 2), 0)  # actual NEUTRAL -> match

	tracker.begin_move_selection()
	tracker.record_guess(Vector2i(0, 3), EffectGuessTracker.EffectDirection.POSITIVE)
	tracker.confirm_move(Vector2i(0, 3), -5)  # actual NEGATIVE -> mismatch

	# Act
	var rate: float = tracker.get_consistency_rate()

	# Assert — 3/4 = 0.75
	assert_int(tracker.get_scored_total()).is_equal(4)
	assert_int(tracker.get_scored_correct()).is_equal(3)
	assert_float(rate).is_equal_approx(0.75, 0.0001)


func test_get_consistency_rate_returns_sentinel_when_n_is_zero() -> void:
	# Arrange — no confirmations have ever been scored.
	var tracker := EffectGuessTracker.new()
	tracker.begin_move_selection()

	# Act
	var rate: float = tracker.get_consistency_rate()

	# Assert — AC9's N == 0 case: this class's own documented contract is the sentinel
	# -1.0, deliberately distinct from 0.0 (which would be indistinguishable from
	# "every guess so far was wrong"). This test is what makes that contract load-bearing —
	# without it, a future edit to 0.0 would not turn anything red.
	assert_int(tracker.get_scored_total()).is_equal(0)
	assert_float(rate).is_equal(-1.0)


# ---------------------------------------------------------------------------
# AC14 — 不持久化：EffectGuessTracker 不得出現在任何存檔讀寫路徑。
#
# 乙類結構守衛測試（原始碼文字掃描），宣告見本檔檔頭。做法與
# tests/unit/cursor/cursor_modulate_alpha_single_writer_test.gd 相同：唯讀掃描
# res://src/**/*.gd 的文字，不執行、不內省任何場景樹或執行期狀態。
#
# 🔴 本區塊這支測試證明得了什麼、證明不了什麼（讀這段再信任綠燈）：
# - 證明得了：**今天**的 res://src 原始碼裡，檔案路徑含 "save"/"serializ"/"persist"
#   （不分大小寫）關鍵字的 .gd 檔，文字中沒有出現 "EffectGuessTracker"。
# - 證明不了：
#   1. 「未來不會有人加」——這是一條回歸守衛，不是對未來的保證。下一個人若新增存檔
#      系統程式碼並在裡面參照本類別，這支測試會抓到（前提是檔案路徑命中上述關鍵字），
#      但在那之前它只能證明「現在沒有」。
#   2. **本專案目前 `src/` 底下完全沒有存檔系統程式碼**（ADR-0004 仍是 Proposed，
#      依管理者裁決「不在最短路徑上，維持 Proposed，不要再投入」）。也就是說，本次
#      執行若命中 0 個「存檔相關檔案」，那是因為**沒有東西可掃**，不是「掃過了、很
#      乾淨」——兩者字面上可能呈現相同的「0 違規」，但意義不同（與
#      `.claude/docs/coding-standards.md` Check 4「沒有可測對象時必須寫 N/A，
#      不得寫『通過』」是同一個紀律，此處用 print() 把這個區別印進執行紀錄，
#      而不是讓它安靜地看起來像「驗證了,很乾淨」）。
#   3. 關鍵字清單是本測試自訂的（"save"/"serializ"/"persist"），不是存檔系統的任何
#      正式命名規範——本專案目前還沒有這類規範可以對齊。未來正式存檔系統若使用其他
#      命名（例如縮寫或中文拼音），且不含這三個關鍵字，本掃描會**漏看**（false
#      negative）。
#   4. 只掃 `.gd` 檔文字；反射存取（`load("res://ui/battle/effect_guess_tracker.gd")`
#      之類的字串路徑而非符號參照）、`.tres`/`.tscn` 資源參照、或透過
#      `get_script().get_path()` 間接取得都在掃描視野之外。
#   5. 跳過以 `#` 開頭（去除前後空白後）的整行——與
#      `cursor_modulate_alpha_single_writer_test.gd` 同一理由：避免文件/註解裡用
#      散文解釋這條規則時，literal 文字反過來誤判成違規本身。

## 乙類例外存取：唯讀 res://src（不含本測試檔自身所在的 res://tests）。
const _SRC_ROOT: String = "res://src"
const _CLASS_UNDER_TEST_NAME: String = "EffectGuessTracker"
const _SAVE_PATH_KEYWORDS: PackedStringArray = ["save", "serializ", "persist"]


func test_ac14_effect_guess_tracker_does_not_appear_in_any_save_related_file() -> void:
	# Arrange
	var save_related_files: Array = _find_save_related_files(_SRC_ROOT)
	# 誠實揭露：0 個命中檔案代表「沒有東西可掃」，不是「掃過了、乾淨」——見本區塊
	# 開頭的說明與 coding-standards.md 的 Check 4 N/A 原則。
	print(
		"AC14 guard: matched %d save-related file(s) under %s via keywords %s " % [
			save_related_files.size(), _SRC_ROOT, str(_SAVE_PATH_KEYWORDS)
		] + "(0 means 'nothing to scan yet' — src/ has no save-system code pending " +
		"ADR-0004 — NOT 'scanned and clean')."
	)

	# Act
	var violations: Array = _find_class_references(save_related_files, _CLASS_UNDER_TEST_NAME)

	# Assert
	assert_int(violations.size()).append_failure_message(
		_ac14_violation_message(violations)
	).is_equal(0)


func test_sensitivity_proof_ac14_detector_catches_planted_class_reference() -> void:
	# Arrange — synthetic in-memory text standing in for a hypothetical save-system
	# line; written nowhere to disk (test-standards.md 禁止測試寫入檔案系統，見本檔
	# 檔頭的乙類宣告：本檔只唯讀 res://src，不新增任何檔案)。Exercises the SAME
	# detection primitive (`_line_references_class`) the real AC14 scan above calls,
	# not a reimplementation of it.
	var planted_reference: String = "var tracker: EffectGuessTracker = EffectGuessTracker.new()"
	var planted_comment_only: String = "# 不得參照 EffectGuessTracker"
	var unrelated_line: String = "var pool: AffinityDataPool = AffinityDataPool.new()"

	# Act / Assert
	assert_bool(
		_line_references_class(planted_reference, _CLASS_UNDER_TEST_NAME)
	).append_failure_message(
		"Sensitivity proof failed: a planted live-code reference to %s was NOT detected " % [
			_CLASS_UNDER_TEST_NAME
		] + "— the AC14 guard above would be silently blind to a real violation shaped like this."
	).is_true()

	assert_bool(
		_line_references_class(unrelated_line, _CLASS_UNDER_TEST_NAME)
	).append_failure_message(
		"False positive: an unrelated line was flagged as referencing %s." % [
			_CLASS_UNDER_TEST_NAME
		]
	).is_false()

	# Disclosed, not silently assumed: a comment-only line mentioning the class name
	# (e.g. explaining the rule in prose) is deliberately NOT flagged — same rationale as
	# cursor_modulate_alpha_single_writer_test.gd skipping `#`-prefixed lines, and the
	# exact self-match trap coding-standards.md warns about (a rule-explaining comment
	# must not count as its own violation).
	assert_bool(
		_line_references_class(planted_comment_only, _CLASS_UNDER_TEST_NAME)
	).append_failure_message(
		"A comment-only line was flagged — this would make the guard self-matching on " +
		"its own explanatory prose, the exact trap coding-standards.md documents."
	).is_false()


func _is_save_related_path(path: String) -> bool:
	var lower_path: String = path.to_lower()
	for keyword in _SAVE_PATH_KEYWORDS:
		if lower_path.contains(keyword):
			return true
	return false


func _find_save_related_files(root: String) -> Array:
	var results: Array = []
	_collect_save_related_files(root, results)
	return results


func _collect_save_related_files(dir_path: String, results: Array) -> void:
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
			_collect_save_related_files(full_path, results)
		elif entry.ends_with(".gd") and _is_save_related_path(full_path):
			results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()


## 真正的偵測原語：單行文字是否「參照」目標類別名稱。`#` 開頭的整行（去除前後空白後）
## 視為註解，不計入——理由見本區塊開頭的自我匹配陷阱說明。
func _line_references_class(line_text: String, class_name_to_find: String) -> bool:
	var trimmed: String = line_text.strip_edges()
	if trimmed.begins_with("#"):
		return false
	return trimmed.find(class_name_to_find) != -1


func _find_class_references(files: Array, class_name_to_find: String) -> Array:
	var results: Array = []
	for file_path in files:
		var f: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var line_number: int = 0
		while not f.eof_reached():
			var raw_line: String = f.get_line()
			line_number += 1
			if _line_references_class(raw_line, class_name_to_find):
				results.append({
					"path": file_path, "line": line_number, "text": raw_line.strip_edges()
				})
	return results


func _ac14_violation_message(violations: Array) -> String:
	var lines: Array = []
	for v in violations:
		lines.append("  %s:%d: %s" % [v["path"], v["line"], v["text"]])
	return (
		"AC14: EffectGuessTracker must not appear in any save read/write path " +
		"(2026-10-16 manager ruling — stats are memory-only, never persisted). " +
		"Found %d reference(s) in save-related file(s):\n%s" % [
			violations.size(), "\n".join(lines)
		]
	)
