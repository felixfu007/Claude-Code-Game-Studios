## Data-driven tuning resource for [SelfDrawnReclaimCursor]'s presentation
## smoother (ADR-0005 機制十三 F3/R4-3, Story 011, GDD Tuning Knobs
## `reclaim_visual_convergence_max_frames`).
##
## 🔴 [b]PROVISIONAL VALUE — an acknowledged gap, not a design decision.[/b]
## GDD Tuning Knobs states explicitly for this knob: 目前建議起始值「待垂直
## 切片階段校準」— no number is on record anywhere in this project (unlike
## [MouseReclaimThresholdConfig]'s threshold table, which at least has one
## human-observed reference range from a 2026-08-05 spike; this knob has none
## at all).
##
## [b]The mathematical floor is [constant MIN_LEGAL_MAX_FRAMES] = 2[/b]
## (ADR-0005 機制十三 R4-3 修法, restated in this story's dispatch): a value of
## 1 means "converge within 0 frames", i.e. an instantaneous single-frame
## snap — self-contradictory with the GDD's own "已顯示的透明度不得瞬間跳變"
## requirement for reset triggers (a)(b)(c) (only trigger (d) is allowed to
## snap, see [enum CursorTypes.ResetTrigger.VETOED_SAME_FRAME] and AC-41b).
##
## [b][member reclaim_visual_convergence_max_frames]'s default below is THIS
## STORY'S OWN interim placeholder[/b] — a coordinator-level engineering
## judgment call recorded in this story's report, explicitly NOT a manager
## ruling and NOT a calibrated value. It is chosen only to sit comfortably
## above [constant MIN_LEGAL_MAX_FRAMES] so a default-constructed instance is
## at least internally consistent. [b]Do not write production logic or tests
## that depend on this default equalling any particular number[/b] — inject an
## explicit [CursorReclaimVisualConfig] with fixture values instead, exactly
## the discipline [code]tests/unit/cursor/mouse_reclaim_test.gd[/code] already
## established for [MouseReclaimThresholdConfig]'s own provisional defaults.
##
## [b]No `.tres` asset exists for this resource today[/b] — same interim
## decision as [MouseReclaimThresholdConfig] (see that file's own class doc
## comment: "not done by this story"). See this story's report for the full
## reasoning on why constructing via [method RefCounted.new] rather than a
## hand-authored `.tres` was chosen for the initial wiring.
class_name CursorReclaimVisualConfig
extends Resource

## Mathematical floor, not a calibrated minimum — see class doc comment.
const MIN_LEGAL_MAX_FRAMES: int = 2

@export var reclaim_visual_convergence_max_frames: int = 6
