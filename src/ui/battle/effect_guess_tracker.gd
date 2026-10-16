class_name EffectGuessTracker
extends RefCounted

## Tracks a player's pre-move guesses about the direction (positive / negative / no
## effect) a candidate move will have on affinity, locks each cell's guess the moment
## it is recorded, and accumulates a guess-vs-actual consistency rate across guesses
## that were both locked-in AND later confirmed via an actual move (battle-hud
## Story 001; see `design/quick-specs/battle-hud-prediction-marker.md` sections 3 & 6).
##
## Pure logic only: no scene nodes, no save/load I/O (AC14), and no call into
## `AffinityRules` — callers supply the already-computed `delta` for a cell; this
## class only classifies and scores it.
##
## Lifecycle (one "move-selection process" = one pick-up-a-piece-and-look-at-
## candidate-cells cycle):
##   1. [code]begin_move_selection()[/code] — call when the player picks up a piece.
##   2. [code]record_guess(cell, guess)[/code] — call the instant the player locks in
##      a guess for a candidate cell. Each cell accepts exactly one guess per
##      move-selection process (AC6); further calls for an already-guessed cell are
##      silently ignored, regardless of what the cursor did in between (AC8).
##   3. [code]confirm_move(cell, delta)[/code] — call when the player commits to
##      actually moving to [code]cell[/code]. Scores the outcome against the locked
##      guess for that exact cell, if one exists (AC7), then ends the process.
##   4. [code]cancel_move_selection()[/code] — call if the player abandons the move
##      without confirming. Discards any locked guesses without scoring them.

## The three directions a `delta` classifies to (AC5).
## Ordinals are assigned explicitly rather than left to declaration order on purpose:
## this project forbids guarding "unreachable" branches of an enum-returning function
## with `assert()`, because a failed assertion silently returns ordinal 0 of the
## function's declared return type (`.claude/docs/coding-standards.md`).
## `classify_delta()` below is fully exhaustive over `int` (always >0, <0, or ==0) so
## it never needs such a guard — but no member here sits at ordinal 0, so a future
## edit cannot accidentally make "it went silent" look like a specific valid answer.
enum EffectDirection {
	POSITIVE = 1,
	NEGATIVE = 2,
	NEUTRAL = 3,
}

## Sentinel returned by [method get_locked_guess] for a cell with no recorded guess.
## Deliberately not 0 or any [enum EffectDirection] ordinal (1-3), so "no guess" can
## never be confused with a real guessed value.
const NO_GUESS: int = -1

## Guesses locked during the current move-selection process.
## Key: Vector2i cell -> EffectDirection (int) guess. A missing key means "no guess
## was recorded for that cell this process" (AC6/AC7) — there is no sentinel enum
## member for "no guess" on purpose, so "guessed NEUTRAL" can never collide with
## "never guessed".
var _locked_guesses: Dictionary = {}

## Total confirmed moves that had a locked guess for the confirmed cell (AC9 denominator N).
var _scored_total: int = 0

## Of `_scored_total`, how many matched the actual outcome (AC9 numerator M).
var _scored_correct: int = 0

## Classifies an already-computed affinity delta into an [enum EffectDirection] (AC5).
## Pure function: no side effects, does not touch instance state.
## `delta > 0` -> POSITIVE, `delta < 0` -> NEGATIVE, `delta == 0` -> NEUTRAL.
static func classify_delta(delta: int) -> EffectDirection:
	if delta > 0:
		return EffectDirection.POSITIVE
	if delta < 0:
		return EffectDirection.NEGATIVE
	return EffectDirection.NEUTRAL

## Starts a new move-selection process, clearing any guesses locked by a previous
## one. Call this when the player picks up a piece to move.
func begin_move_selection() -> void:
	_locked_guesses.clear()

## Abandons the current move-selection process without scoring anything. Call this
## if the player deselects the piece without confirming a move.
func cancel_move_selection() -> void:
	_locked_guesses.clear()

## Records a guess for `cell` during the current move-selection process (AC6).
## If `cell` already has a locked guess this process, this call is a no-op — the
## existing value is never overwritten, no matter how many times this is called or
## what happened to the cursor in between (AC8).
func record_guess(cell: Vector2i, guess: EffectDirection) -> void:
	if _locked_guesses.has(cell):
		return
	_locked_guesses[cell] = guess

## True if `cell` already has a guess locked in during the current move-selection process.
func has_locked_guess(cell: Vector2i) -> bool:
	return _locked_guesses.has(cell)

## Returns the [enum EffectDirection] (as int) locked for `cell` this process, or
## [constant NO_GUESS] if `cell` has no locked guess. Check [method has_locked_guess]
## first if the distinction matters to the caller.
func get_locked_guess(cell: Vector2i) -> int:
	if not _locked_guesses.has(cell):
		return NO_GUESS
	return _locked_guesses[cell]

## Call when the player commits to actually moving to `cell`. If `cell` has a locked
## guess for this process, scores it against the actual direction of `delta` (AC7) —
## otherwise this confirm is not scored at all (covers both "confirmed a different
## cell than the one guessed" and "confirmed without ever guessing", as one shared
## rule). Ends the move-selection process either way.
func confirm_move(cell: Vector2i, delta: int) -> void:
	if _locked_guesses.has(cell):
		var guess: int = _locked_guesses[cell]
		var actual: EffectDirection = classify_delta(delta)
		_scored_total += 1
		if guess == actual:
			_scored_correct += 1
	_locked_guesses.clear()

## Total confirmed moves that counted toward the consistency rate (AC9 denominator N).
func get_scored_total() -> int:
	return _scored_total

## Of [method get_scored_total], how many guesses matched the actual outcome (AC9 numerator M).
func get_scored_correct() -> int:
	return _scored_correct

## Consistency rate M / N (AC9). Returns -1.0 when N == 0 (no scored confirmations
## yet) — a deliberate choice over returning 0.0, which would be indistinguishable
## from "every guess so far was wrong". Callers must check for this sentinel before
## formatting a percentage.
func get_consistency_rate() -> float:
	if _scored_total == 0:
		return -1.0
	return float(_scored_correct) / float(_scored_total)
