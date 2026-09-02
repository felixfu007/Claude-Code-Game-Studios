## Pure-logic dependency-injection core for the cursor/highlight-state system
## (ADR-0005 機制一). Constructible with [method RefCounted.new] outside any
## scene tree — unit tests build one directly against test-double
## collaborators, with no global state to set up or tear down.
##
## Holds exactly the three top-level state fields GDD Core Rules #1 /
## [code]TR-cursor-001[/code] require, with no undocumented fourth:
## [member _target], [member _device_authority], [member _reclaim]. See each
## field's own doc comment for why [member CursorTarget.is_valid] does not
## count as an independent fourth field.
##
## [b]Two more collaborators are ALSO stored as fields[/b] — [member _registry]
## and [member _mouse_position_provider] — because ADR-0005's frozen "Key
## Interfaces" contract section lists both by name in [method _init]'s
## signature. They are injected wiring the DI core needs to do its job in
## later stories (機制十's [code]_validate_target_writable()[/code] and the
## mouse-reclaim evaluation path), not undeclared/hidden GDD state — AC-1's
## own source text (2026-08-04 第五輪修訂,
## [code]production/epics/cursor-highlight-state/story-002-state-host.md[/code])
## says it verifies "no undocumented fourth field", not "at most three
## declared variables total". [b]No manager ruling exists on this question —
## do not cite one.[/b] The reading above is this story's own argument from
## AC-1's text, independently checked during the 2026-09-02 three-way review
## (both the GDScript-quality and Engine/ADR-contract reviewers verified it
## against the source text before this comment was corrected).
## [code]tests/unit/cursor/state_host_test.gd[/code]'s AC-1 test
## operationalizes this distinction and excludes both by name.
##
## [b]This story (002) is the constructor + field shape only[/b] — nothing
## else on this class exists yet:
## - Story 005 adds the frame-buffered arbitration timing.
## - Story 007 adds the seven gated public write entries AND the read queries
##   ([method get_current_target] / [method get_device_authority] /
##   [method is_current_target_valid] / [method reclaim_progress] do not exist
##   yet — [code]TR-cursor-014[/code] and 機制十's read half are that story's
##   scope, confirmed against its own work order, not this one's).
## - Story 014 adds the concrete [MouseReclaimPolicy] subclass; until then
##   [code]CursorStateHost[/code] constructs this class with [param reclaim]
##   [code]null[/code] (see that file's doc comment) — nothing built so far
##   ever calls a method on [member _reclaim], so a null collaborator is safe
##   here. This is not a decision about the reclaim submechanism itself,
##   which remains user-frozen (Story 014's own "凍結區" notice).
##
## See [code]tests/unit/cursor/state_host_test.gd[/code]'s header doc comment
## for exactly which half of each Acceptance Criterion is verified at this
## layer versus deferred to a later story.
class_name CursorState
extends RefCounted

## Exact [method @GlobalScope.push_error] message [method _init] emits when
## [param mouse_position_provider] is not a valid [Callable] (ADR-0005
## Negative Consequences, line ~1530: "`_init()` 內對
## `mouse_position_provider.is_valid()` 斷言,失敗即立刻爆而非在第一次滑鼠移動
## 時才顯現" — fail immediately and visibly, not deferred to the first
## mouse-move call site). Kept as a named constant, not an inline literal, so
## [code]tests/unit/cursor/state_host_test.gd[/code] can assert on it without
## hand-duplicating the string.
const ERR_INVALID_MOUSE_POSITION_PROVIDER: String = (
	"CursorState._init(): mouse_position_provider is not a valid Callable. " +
	"Construction proceeds anyway (a constructor cannot refuse to return an " +
	"object), but every later call site that invokes it will fail at that " +
	"point instead of here. Fix the caller's Callable binding now."
)

# Core Rules #1's three top-level state fields — no fourth (AC-1):
var _target: CursorTarget                      ## current cursor target; the validity flag is CursorTarget's own internal field, not a separate top-level one
var _device_authority: CursorTypes.Authority   ## UNINITIALIZED / MOUSE / KEYBOARD_GAMEPAD
var _reclaim: MouseReclaimPolicy               ## owner of the 3rd top-level field (accumulated net displacement px, 機制八); may be null until Story 014, see class doc comment

# Injected collaborators — NOT GDD state, see class doc comment above:
var _registry: CursorSurfaceRegistry           ## needed by Story 007's _validate_target_writable(); unread in this story
var _mouse_position_provider: Callable         ## sole mouse-coordinate channel for this scene-tree-less core (ADR-0005 機制一/十, 新發現 B); a NAMED method binding only, never a lambda literal (S-1) — unread in this story


## [param reclaim], [param registry] and [param mouse_position_provider] are
## the three collaborators ADR-0005's frozen Key Interfaces contract defines
## for this constructor. This story stores all three but only initializes the
## two GDD-mandated state fields: [member _target] starts invalid
## ([code]CursorTarget.new()[/code] defaults [member CursorTarget.is_valid] to
## [code]false[/code], with no need to fabricate a placeholder "from" target),
## and [member _device_authority] starts
## [constant CursorTypes.Authority.UNINITIALIZED]. No write interface exists
## yet to set a real initial target (Story 007) — GDD AC-15 explicitly makes
## setting the real initial target the calling screen's responsibility before
## it becomes interactive, not this constructor's.
func _init(
	reclaim: MouseReclaimPolicy,
	registry: CursorSurfaceRegistry,
	mouse_position_provider: Callable
) -> void:
	# ADR-0005 requires this failure to surface AT CONSTRUCTION rather than
	# on the first mouse-move call site (see ERR_INVALID_MOUSE_POSITION_PROVIDER's
	# doc comment for the exact ADR line). The ADR's own wording models this
	# as an assert(); this uses push_error() INSTEAD of assert() — not as a
	# weaker substitute, but a stricter one — because assert() preconditions
	# are documented as possibly stripped by the engine from release export
	# builds (docs/tech-debt-register.md, 2026-09-02 "Open" entry; unverified
	# on this machine, no export template installed). push_error() is not
	# compiled out of any build configuration, so this guard holds in every
	# build, not only editor/debug ones.
	if not mouse_position_provider.is_valid():
		push_error(ERR_INVALID_MOUSE_POSITION_PROVIDER)
	_reclaim = reclaim
	_registry = registry
	_mouse_position_provider = mouse_position_provider
	_device_authority = CursorTypes.Authority.UNINITIALIZED
	_target = CursorTarget.new()
