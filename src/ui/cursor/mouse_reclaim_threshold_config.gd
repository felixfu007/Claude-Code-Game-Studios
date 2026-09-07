## Data-driven tuning table for [ThresholdMouseReclaimPolicy] (GDD Tuning Knobs
## `mouse_reclaim_threshold_px_by_surface_type`, `design/gdd/cursor-highlight-state.md`).
## One [annotation @export] field per [enum CursorTypes.SurfaceType] member —
## Resource Pattern per project coding standards ("Use custom Resource
## subclasses for data definitions... instead of dictionaries for structured
## data"), editable in the Inspector without touching GDScript once this is
## wired into a saved [code].tres[/code] asset (not done by this story — see
## [code]threshold_mouse_reclaim_policy.gd[/code]'s class doc comment for why).
##
## 🔴 [b]PROVISIONAL VALUES — an acknowledged gap, not a design decision.[/b]
## GDD Tuning Knobs states explicitly: 各表面類型的初始建議值**待垂直切片階段實測**
## ("initial per-surface-type values await vertical-slice measurement"). The
## ONLY measurement on record is
## [code]prototypes/cursor-reclaim-godot-spike-2026-08-05/[/code] Test 2
## Procedure C — a human-observed result on a SINGLE synthetic test surface:
## "50-100px 區間手感自然" (feels natural in the 50-100px range). It is not
## per-surface-type data, not automated, and explicitly flagged in the GDD
## itself as "非最終值,亦未依表面類型分別測試" (not final, not tested per
## surface type).
## [br]
## All four fields below default to the midpoint of that one range (75.0)
## because there is NO per-surface-type data to differentiate them — not
## because the four surfaces are believed to need an identical threshold.
## [b]Do not write production logic or tests that depend on this default
## equalling any particular number[/b] — construct an explicit
## [MouseReclaimThresholdConfig] with fixture values instead (every test in
## [code]tests/unit/cursor/mouse_reclaim_test.gd[/code] does this).
class_name MouseReclaimThresholdConfig
extends Resource

@export var board_tile_threshold_px: float = 75.0
@export var relation_minimap_node_threshold_px: float = 75.0
@export var card_slot_threshold_px: float = 75.0
@export var dialogue_choice_threshold_px: float = 75.0


## Looks up [code]reclaim_threshold_px[/code] for [param surface] (GDD
## Formulas: `reclaim_threshold_px = mouse_reclaim_threshold_px_by_surface_type[surface_type]`).
##
## [b]The two [method assert] guards below are debug-time defensive coding
## only — NOT a substitute for AC-46 / AC-46b's system-level startup
## rejection.[/b] That validator is Story 006's [code]CursorStartupValidator[/code]
## (ADR-0005 機制七), unbuilt as of this file — see that story's own
## 2026-09-04 note that its AC-46/AC-46b definition domain was empty until
## this table existed. [method assert] may be stripped from release export
## builds (project tech-debt register, unverified on this machine); Story 006
## still owns making an illegal value loud and non-silent in every build
## configuration. This method's asserts exist only so a debug/editor run
## fails loudly and immediately rather than silently producing the two
## documented failure modes (GDD Formulas 邊界值): a 0 threshold divides by
## zero, and a negative threshold clamps [method
## ThresholdMouseReclaimPolicy.reclaim_progress] to a permanent [code]0.0[/code]
## — the mouse can never reclaim authority on that surface, with no exception
## raised anywhere.
##
## 🔴 2026-09-07 measured (not inferred): what this assert actually does to
## a negative value, in an editor/debug build, is worse than "loud" — it is
## loud AND it changes the value. Godot 4.7.1, throwaway
## [code]--headless --script[/code] probes (nested-function variant, not
## committed to the repo): a failed [method Object.assert] aborts only the
## function it is declared in — it does NOT propagate the abort to the
## caller, and the caller resumes normally on the next line after the call
## returns. Because this method's abort happens BEFORE its own
## [code]return value[/code] line, GDScript hands the caller this method's
## declared return type's zero-value default instead — [code]0.0[/code] for
## [code]-> float[/code] — NOT the negative number that was actually
## configured. Concretely: call this method with a negative
## [member board_tile_threshold_px]-style field in an editor/debug run, and
## [method ThresholdMouseReclaimPolicy.evaluate] receives [code]0.0[/code],
## never the negative value — so it observes the ZERO-threshold failure mode
## (see that method's own doc comment), not the negative one GDD line 144
## describes. Only an export-release build, where [method Object.assert] is
## stripped entirely, lets a configured negative value reach the caller
## unaltered. [code]tests/unit/cursor/mouse_reclaim_test.gd[/code]'s
## negative-threshold test therefore bypasses this method with a test
## double rather than constructing a real [MouseReclaimThresholdConfig] —
## see that test's own comment for why.
func threshold_for_surface(surface: CursorTypes.SurfaceType) -> float:
	var value: float
	match surface:
		CursorTypes.SurfaceType.BOARD_TILE:
			value = board_tile_threshold_px
		CursorTypes.SurfaceType.RELATION_MINIMAP_NODE:
			value = relation_minimap_node_threshold_px
		CursorTypes.SurfaceType.CARD_SLOT:
			value = card_slot_threshold_px
		CursorTypes.SurfaceType.DIALOGUE_CHOICE:
			value = dialogue_choice_threshold_px
		_:
			# GDD Formulas 邊界值 "表面類型列舉新增成員但查表未同步" — a lookup
			# miss, distinct from an illegal-but-present value below. Every
			# CursorTypes.SurfaceType member has a matching field above as of
			# this writing; reaching here means the enum grew without this
			# table growing with it in the same atomic change (see Formulas'
			# atomic-sync rule). Story 006 (AC-46b) owns the non-debug-build
			# detection of this; this assert is the debug-time trip-wire only.
			assert(
				false,
				(
					"MouseReclaimThresholdConfig.threshold_for_surface(): " +
					"unmapped CursorTypes.SurfaceType %d — every enum member " +
					"needs a matching @export field (GDD Formulas 邊界值 " +
					"atomic-sync rule)."
				) % surface
			)
			return 1.0

	assert(
		value > 0.0,
		(
			"MouseReclaimThresholdConfig.threshold_for_surface(): threshold " +
			"for surface %d must be > 0, got %f (GDD Formulas 邊界值 — 0 " +
			"divides by zero, negative permanently clamps reclaim_progress " +
			"to 0.0)."
		) % [surface, value]
	)
	return value
