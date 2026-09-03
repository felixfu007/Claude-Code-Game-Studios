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
## signature. They are injected wiring, not undeclared/hidden GDD state.
## [b]Where each one is actually read is stated at its own declaration and
## nowhere else.[/b] This paragraph used to carry a second copy of that fact
## ("...wiring the DI core needs to do its job in later stories"); Story 007
## made the copy false, and it is deleted rather than corrected — one place to
## keep true beats two places that agree today. On the AC-1 question, AC-1's
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
## [b]Story 002 built the constructor and the field shape; Story 007 added
## 機制十 — the seven gated public write entries, the reentrancy gate, the six
## ungated private paths, the two-query read interface and the three
## signals.[/b] What is still NOT here:
## - Story 005 adds the frame-buffered arbitration timing, and with it the
##   BODIES of [method arbitrate_device_authority] and
##   [method apply_buffered_navigation]. Story 007 owns those two entries'
##   existence, gate and diagnostics; 機制六 owns what they decide. Both carry
##   an explicitly marked seam saying exactly what belongs there.
## - Story 014 adds the concrete [MouseReclaimPolicy] subclass; until then
##   [code]CursorStateHost[/code] constructs this class with [param reclaim]
##   [code]null[/code] (see that file's doc comment). This is not a decision
##   about the reclaim submechanism itself, which remains user-frozen (Story
##   014's own "凍結區" notice).
##   🔴 [b]Story 007 invalidated what this line used to say.[/b] It read
##   "nothing built so far ever calls a method on [member _reclaim], so a null
##   collaborator is safe here" — that was true when Story 002 wrote it and is
##   now false: this class calls [member _reclaim] from six places. A null
##   [member _reclaim] is handled deliberately and uniformly (reported once at
##   construction, every call site a no-op, [method reclaim_progress] returns
##   [code]0.0[/code]) — see [constant ERR_RECLAIM_POLICY_ABSENT] for the full
##   reasoning and for the fact that ADR-0005 takes no position on it.
##   [b]The system is not broken while [param reclaim] is null, but the
##   mouse-reclaim submechanism is inert, and no test can catch that[/b]:
##   unit tests inject a working test double, so only a real run exercises the
##   null.
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

## Exact [method @GlobalScope.push_error] message
## [method arbitrate_device_authority] emits — [b]exactly once per
## [CursorState] instance[/b], guarded by [member _provider_error_reported] —
## when [member _mouse_position_provider] has gone invalid (ADR-0005 機制十,
## R6-11 + Step 5.5 B-1). Named constant, not an inline literal, so tests can
## assert on it without hand-duplicating the string.
const ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED: String = (
	"CursorState.arbitrate_device_authority(): mouse_position_provider is no " +
	"longer valid. Mouse-reclaim arbitration is DISABLED for the rest of this " +
	"CursorState's lifetime (keyboard/gamepad arbitration is unaffected). This " +
	"is reported once, not per frame; diagnostic_invalid_mouse_provider_count " +
	"keeps counting. Rebuild CursorState with a live provider binding."
)

## Exact [method @GlobalScope.push_error] message [method _init] emits when
## [param reclaim] is [code]null[/code].
##
## 🔴 [b]ADR-0005 does not define [member _reclaim] as nullable anywhere[/b] —
## its contract assumes a live [MouseReclaimPolicy]. Everything about how this
## file handles [code]null[/code] is therefore THIS FILE'S decision, not the
## ADR's, and is written down here rather than implied:
## [br]
## [b]What[/b]: report once, at construction, then treat every
## [member _reclaim] call site as a no-op ([method reclaim_progress] returns
## [code]0.0[/code]).
## [br]
## [b]Why report at construction rather than per call[/b]: a null
## [member _reclaim] is a permanent property of the instance, not a per-call
## condition. ADR-0005 (S-4) gives no runtime hot-swap channel — "replacing"
## the policy means rebuilding [CursorState] — so the answer can never change
## after this line. This mirrors what this constructor already does for an
## invalid [param mouse_position_provider] one field above.
## [br]
## [b]Why not simply let it crash[/b]: an unguarded call on [code]null[/code]
## aborts the enclosing GDScript function. Six of the seven call sites sit
## inside a raised [member _mutation_in_progress] gate, so the abort would skip
## the line that lowers it — every later public call would then return
## [code]REJECTED_REENTRANT[/code] forever. That is a loud one-off error
## followed by a permanently and silently dead system: strictly worse than
## either alternative.
## [br]
## [b]Why not stay quiet[/b]: silence here is the exact failure shape R6-11 was
## written to eliminate (a subsystem that looks alive while doing nothing).
const ERR_RECLAIM_POLICY_ABSENT: String = (
	"CursorState._init(): reclaim is null, so the mouse-reclaim submechanism " +
	"is INERT for this instance — every reset() is skipped and " +
	"reclaim_progress() returns 0.0. Cursor targeting, device-authority " +
	"reads and the handoff entries all still work. Expected while Story 014 " +
	"(concrete MouseReclaimPolicy) is unbuilt: CursorStateHost constructs " +
	"this class with null today. If you are seeing this after Story 014 " +
	"landed, the Autoload was never updated."
)


## Result of [method set_target] / [method handoff_after_mount] and of the
## shared private validation they both run ([method _validate_target_writable]).
## [b]Frozen member list[/b] — ADR-0005 機制十 defines exactly these four; do
## not add, remove or reorder. See [method _validate_target_writable] for the
## one case the ADR left without a member of its own (a [code]null[/code]
## target) and how it is mapped.
enum SetTargetResult { APPLIED, SURFACE_NOT_REGISTERED, INVALID_SURFACE_TYPE, REJECTED_REENTRANT }

## Result of [method mark_pending_reresolve] / [method handoff_before_unload]
## and of the shared private path they both run
## ([method _mark_pending_reresolve_internal]). [b]Frozen member list[/b] —
## ADR-0005 機制十 defines exactly these four.
## [br]
## [constant STALE_NOT_APPLIED] is TR-cursor-013's race guard (AC-37): the
## caller's [param expected] no longer matches what this object holds, so
## nothing is flipped. [b]Never silently ignored, never a [code]void[/code]
## return[/b] — the caller must be able to tell the two apart programmatically.
enum MarkResult { APPLIED, STALE_NOT_APPLIED, NO_CURRENT_TARGET, REJECTED_REENTRANT }

## Reset semantics for [method _write_target_internal] (ADR-0005 機制十,
## R5-1 + 專家發現 B). [b]Deliberately NOT a [code]bool[/code][/b]: GDScript
## has no call-site named arguments, so [code]_write_target_internal(t, true)[/code]
## would say nothing at the call site — and this ADR had just rejected a third
## [code]bool[/code] parameter on [method set_target] for being a boolean trap.
## Planting the same bool one layer down would have been self-contradictory.
enum TargetResetPolicy { CONDITIONAL_ON_CHANGE, UNCONDITIONAL }


## Emitted after a write has fully settled — [b]never mid-write[/b]. Carries no
## payload by design (N4): subscribers re-read via [method get_current_target] /
## [method is_current_target_valid] rather than holding a copy that can drift.
## [b][method _target_changed_from] is the single place that decides whether
## this fires[/b]; no other method makes that judgement inline.
signal target_changed()

## Emitted when [member _device_authority] changes. Payload-free for the same
## reason as [signal target_changed] — read back via
## [method get_device_authority].
## [br]
## ⚠️ [b]Nothing in THIS story emits it[/b]: device-authority arbitration is
## 機制六, i.e. Story 005's half of
## [method arbitrate_device_authority] (see that method's doc comment).
signal device_authority_changed()

## Verbatim forward of [signal MouseReclaimPolicy.reset_triggered] (R5-3).
## Exists so [member _reclaim] can stay completely private — no getter, never
## handed out — while the presentation layer (機制十三) still learns which of
## the five [enum CursorTypes.ResetTrigger] values caused a zero-out.
signal reclaim_reset_triggered(trigger: CursorTypes.ResetTrigger)


# Core Rules #1's three top-level state fields — no fourth (AC-1):
var _target: CursorTarget                      ## current cursor target; the validity flag is CursorTarget's own internal field, not a separate top-level one
var _device_authority: CursorTypes.Authority   ## UNINITIALIZED / MOUSE / KEYBOARD_GAMEPAD
var _reclaim: MouseReclaimPolicy               ## owner of the 3rd top-level field (accumulated net displacement px, 機制八); may be null until Story 014, see class doc comment

# Injected collaborators — NOT GDD state, see class doc comment above:
var _registry: CursorSurfaceRegistry           ## surface lookup used by _validate_target_writable()'s get_surface() call — read in this story, not merely stored
var _mouse_position_provider: Callable         ## sole mouse-coordinate channel for this scene-tree-less core (ADR-0005 機制一/十, 新發現 B); a NAMED method binding only, never a lambda literal (S-1). Read in this story: arbitrate_device_authority()'s up-front is_valid() check, and _safe_mouse_position()

# ─── Story 007 internal mechanism fields — NOT GDD state (AC-1) ─────────────
# 🔴 These six are mechanism, not Core Rules #1 state: a reentrancy latch, two
# latches that keep a deferred/one-shot action from repeating, one cached
# coordinate, and two QA-only counters. None of them is a "fourth top-level
# state field" in AC-1's sense (the AC's own text asks whether an undocumented
# GDD state field exists, not whether the class declares more than three
# variables — the same reading already applied to _registry /
# _mouse_position_provider in the class doc comment above).
# ⚠️ tests/unit/cursor/state_host_test.gd's AC-1 test excludes fields BY NAME.
# 🔴 That exclusion list, not this comment, is the authoritative copy — its
# contents are deliberately NOT restated here, because a restated list is a
# list that drifts. The standing rule is all this comment needs to carry: add
# a field here without adding its name there and the AC-1 test fails. That
# failure is the intended alarm, not a bug in the test.
var _mutation_in_progress: bool = false        ## N4/R4-4 reentrancy gate — the seven public entries set it on entry and clear it after all fields are written AND signals emitted
var _pending_reseed: bool = false              ## R6-10: a reseed request that arrived while the gate was up. bool, not a count — repeated reseed requests are idempotent
var _provider_error_reported: bool = false     ## R6-11: guards ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED to exactly one push_error, not one per frame
var _last_mouse_position: Vector2 = Vector2.ZERO   ## S-1: last coordinate successfully obtained from the provider; what _safe_mouse_position() returns when the provider has gone invalid

## QA/test-only (機制十五 convention, same as ADR-0002's
## [code]diagnostic_visited_count[/code]). [b]Downstream gameplay logic must
## not depend on either counter.[/b]
## [br]
## [member diagnostic_reentrant_rejection_count] exists because the three
## [code]void[/code] entries cannot return [constant
## SetTargetResult.REJECTED_REENTRANT] — without it, a reentrant call into
## them would be completely traceless. See ADR-0005 機制十's "三個回傳
## [code]void[/code] 的入口如何表達拒絕" paragraph.
var diagnostic_reentrant_rejection_count: int = 0
## Incremented every time [member _mouse_position_provider] is found invalid,
## in [method _safe_mouse_position] and in
## [method arbitrate_device_authority]'s up-front check. Unlike the
## [code]push_error[/code], this keeps counting (S-1 test vector (c)).
var diagnostic_invalid_mouse_provider_count: int = 0


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

	# R5-3: forward MouseReclaimPolicy.reset_triggered verbatim, so [member
	# _reclaim] can stay completely private and the presentation layer depends
	# on this class alone. `reclaim_reset_triggered.emit` is used directly as
	# the Callable — a pure forward with no handler method of its own.
	# Confirmed working on this engine (Godot 4.7.1, throwaway headless probe:
	# a Signal's `.emit` is a valid Callable for connect(), and the argument is
	# passed through). A named `_on_...` handler would have worked too, but it
	# would put a seventh underscore-prefixed method on a class whose
	# "exactly six private paths" count is an asserted invariant (Validation
	# Criteria #13), and a static reader would have to work out that the
	# seventh is a signal callback rather than a private path.
	#
	# ⚠️ ADR-0005 never contemplates a null [member _reclaim], so the whole
	# null branch below is this file's decision — see
	# [constant ERR_RECLAIM_POLICY_ABSENT] for what was decided and why, and
	# for the reason this is the ONE place it gets reported. CursorStateHost
	# really does construct this class with `reclaim = null` today (Story 014
	# unbuilt), so this is a live path, not a defensive formality.
	if _reclaim != null:
		_reclaim.reset_triggered.connect(reclaim_reset_triggered.emit)
	else:
		push_error(ERR_RECLAIM_POLICY_ABSENT)


# ─── Seven gated public write entries (ADR-0005 機制十) ─────────────────────
#
# 🔴 ALL SEVEN set _mutation_in_progress on entry and clear it on exit, and
#    NONE of them calls another one. That prohibition is a registered forbidden
#    pattern (public_cursor_write_entry_calling_another) and it is structural,
#    not stylistic: GDScript has no try/finally, so the only shape that
#    guarantees the latch is set and cleared exactly once per call is "one
#    entry owns the latch for its whole body". Any behaviour two entries share
#    is pushed down into one of the six ungated private paths below and called
#    from both — never borrowed by calling the other entry.


## GDD 步驟一 / 機制六 ①, run by [code]CursorStateHost[/code] at
## [code]process_priority = -100[/code]. Decides DEVICE AUTHORITY only —
## [b]never touches the target field and never clears the frame buffer[/b]
## (機制五 hands the buffer's last read to 機制六 ③).
##
## [b]Scope split with Story 005 — read this before assuming a bug[/b]: the
## arbitration itself (which events are eligible, the fixed
## KEYBOARD_GAMEPAD-beats-MOUSE priority, [method MouseReclaimPolicy.evaluate],
## and the [constant CursorTypes.ResetTrigger.AUTHORITY_TRANSFER] /
## [constant CursorTypes.ResetTrigger.VETOED_SAME_FRAME] reset calls) is
## ADR-0005 機制六, which EPIC.md assigns to Story 005. This story owns 機制十:
## the entry's existence, its reentrancy latch, its up-front provider check and
## its [method _drain_pending_reseed] obligation. The marked seam below is
## where Story 005's body goes.
##
## 🔴 [b]The seam's indentation level is itself part of the spec[/b]: only the
## mouse-displacement half of 機制六 depends on
## [member _mouse_position_provider]. Keyboard/gamepad eligibility, the
## priority resolution and the [member _device_authority] write must keep
## running when that provider is dead — exactly what
## [constant ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED] promises in writing.
## The provider check therefore yields a [b]local flag[/b] which Story 005
## must gate exactly one sub-step on; it is deliberately NOT an
## [code]if[/code] wrapped around the seam.
##
## [b]Rejection semantics[/b]: returns [code]void[/code], so it cannot report
## [constant SetTargetResult.REJECTED_REENTRANT]. On reentry it is a total
## no-op and increments [member diagnostic_reentrant_rejection_count]. ADR-0005
## permits this narrow exception to the never-silent rule because its only
## caller is this system's own [code]CursorStateHost[/code] — no downstream
## system can be misled into the wrong recovery action.
func arbitrate_device_authority(events: Array[InputEvent]) -> void:
	if _mutation_in_progress:
		diagnostic_reentrant_rejection_count += 1
		return
	_mutation_in_progress = true

	# 🔴 R6-11 / Step 5.5 B-1 — the provider check belongs HERE, not inside
	# _safe_mouse_position(). That method returns Vector2, so a caller cannot
	# tell a real coordinate from a stale fallback one; if the reclaim
	# evaluation kept polling through it, the seed would freeze at a stale
	# position, net displacement would be permanently zero, and mouse reclaim
	# would fail forever WITHOUT A SOUND. Cutting the path off up here turns
	# that silent freeze into a loud disable.
	# This does not violate S-3's "coordinates only via _safe_mouse_position()":
	# is_valid() interrogates the Callable, it does not read a coordinate.
	#
	# 🔴 The answer is carried as a LOCAL FLAG, not as an `if` wrapped around
	# the arbitration below. Nesting the arbitration inside the check would
	# disable keyboard/gamepad arbitration along with the mouse channel — see
	# the seam's own note, and the wording of the constant pushed below.
	var mouse_channel_available: bool = _mouse_position_provider.is_valid()
	if not mouse_channel_available:
		diagnostic_invalid_mouse_provider_count += 1
		if not _provider_error_reported:
			# Exactly once per instance, not once per frame — a per-frame
			# push_error() floods the log until nobody reads it, which is its
			# own kind of silence.
			_provider_error_reported = true
			push_error(ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED)

	# ─────────────────────────────────────────────────────────────────────
	# STORY 005 SEAM (ADR-0005 機制六, EPIC.md assigns it to Story 005).
	#
	# 🔴 THIS SEAM'S INDENTATION LEVEL IS ITSELF PART OF THE SPEC. It sits at
	# function-body level, NOT inside a mouse-provider check, and it must stay
	# there. A pre-review revision of this file nested it under
	# `if _mouse_position_provider.is_valid():`. Nothing failed to compile and
	# no test went red — the body is empty — but it would have handed Story 005
	# a shape in which a dead mouse channel silently disables KEYBOARD/GAMEPAD
	# arbitration too. That contradicts this file's own
	# ERR_MOUSE_PROVIDER_INVALID_RECLAIM_DISABLED ("keyboard/gamepad
	# arbitration is unaffected") and ADR-0005 L.852, which disables the
	# evaluate() PATH, not the whole arbitration. Symptom if re-nested: "the
	# gamepad stops working whenever the mouse binding dies", and the one error
	# message in the log actively points the debugger somewhere else.
	#
	# What goes here, split by whether it needs mouse coordinates:
	#
	# (i) NOT provider-dependent — runs unconditionally, including when
	#     mouse_channel_available is false:
	#       · eligibility filtering of NAVIGATION-class ui_* events from
	#         keyboard/gamepad;
	#       · the fixed KEYBOARD_GAMEPAD-beats-MOUSE priority resolution;
	#       · writing _device_authority and emitting device_authority_changed();
	#       · the AUTHORITY_TRANSFER (a) reset call.
	#
	# (ii) Provider-dependent — and ONLY this — gated on
	#      `mouse_channel_available`:
	#       · the mouse displacement test, i.e.
	#         _reclaim.evaluate(_safe_mouse_position(), surface), and the mouse
	#         candidate it produces;
	#       · the VETOED_SAME_FRAME (d) reset call, which can only arise when
	#         there was a mouse candidate to veto.
	#     When mouse_channel_available is false there is simply NO mouse
	#     candidate; (i) still runs with the keyboard/gamepad candidate alone.
	#
	# Constraints that are already settled and must not be re-litigated:
	# this entry must NOT touch _target and must NOT clear the frame buffer,
	# and it must take coordinates from _safe_mouse_position() rather than
	# digging them out of `events`.
	# ─────────────────────────────────────────────────────────────────────

	_drain_pending_reseed()
	_mutation_in_progress = false


## GDD 步驟三 / 機制六 ③, run by [code]CursorNavigationApplier[/code] at
## [code]process_priority = -25[/code] — after 步驟二 (a caller's own
## re-target at −60), which is why it cannot live on the same node as
## [method arbitrate_device_authority].
##
## [b]Scope split with Story 005[/b]: same as
## [method arbitrate_device_authority] — the navigation-application body is
## 機制六. What it must NOT do is settled here and now: it applies buffered
## navigation writes through [method _write_target_internal] with
## [constant TargetResetPolicy.CONDITIONAL_ON_CHANGE], [b]never by calling
## [method set_target][/b] (that would be rejected by this entry's own latch —
## R4-4, the original instance of the self-deadlock this file's shape exists to
## prevent).
##
## [b]Rejection semantics[/b]: [code]void[/code], same as
## [method arbitrate_device_authority].
func apply_buffered_navigation(events: Array[InputEvent]) -> void:
	if _mutation_in_progress:
		diagnostic_reentrant_rejection_count += 1
		return
	_mutation_in_progress = true

	# ─────────────────────────────────────────────────────────────────────
	# STORY 005 SEAM (ADR-0005 機制六, EPIC.md assigns it to Story 005).
	# What goes here: if _device_authority is not KEYBOARD_GAMEPAD this is a
	# no-op (the mouse never re-targets through the action path); otherwise
	# derive the new target from the buffered NAVIGATION-class ui_* events and
	# write it via
	#   _write_target_internal(target, TargetResetPolicy.CONDITIONAL_ON_CHANGE)
	# 🔴 NEVER via set_target(). That is R4-4 verbatim: the latch is already up
	# by this line, so the call would be rejected as reentrant and buffered
	# navigation would silently stop working on the normal path. Validation
	# Criteria #13 exists specifically to fail if anyone writes it that way.
	# The frame buffer is cleared by CursorStateHost.flush_buffered_navigation()
	# after this returns — not here.
	# ─────────────────────────────────────────────────────────────────────

	_drain_pending_reseed()
	_mutation_in_progress = false


## TR-cursor-012's dual-input write interface, and the 丙 handoff branch's
## entry (機制十一). [param target] is an identity only — [b]no hitbox
## geometry[/b]; GDD 第九輪 replaced every geometry query with
## surface-type-keyed fixed pixel constants, so none is needed here or per frame.
##
## Validity flips back to true implicitly: [param target] is written whole, and
## a target built by [method CursorTarget.make] is valid by construction (AC-25).
##
## [param from_ui_action] records whether this write was triggered by a device
## [code]ui_*[/code] action. [b]AC-39 is the half this story implements[/b]:
## when it is [code]false[/code], [member _device_authority] is unchanged —
## target and authority are orthogonal fields and writing one never implies
## the other. All three handoff branches (甲/乙/丙) pass [code]false[/code].
## ⚠️ [b]The [code]true[/code] half is deliberately NOT implemented here.[/b]
## ADR-0005 promises that [code]true[/code] transfers device authority but
## never says TO WHICH device, and this signature carries no device
## information to derive it from. So today [code]true[/code] and
## [code]false[/code] behave identically. 🔴 [b]Ruled 2026-09-03: explicitly
## deferred, NOT implemented.[/b] The ruling and its full reasoning are
## recorded in ADR-0005 機制十一, in the paragraph beginning
## [code]**裝置權威不隨目標交接重置**[/code] — go read it there rather than
## trusting this summary. Three facts made it unimplementable today: the ADR
## never says which device to transfer to; this signature carries no device
## information; and no caller passes [code]true[/code] at all. The parameter
## is kept rather than deleted (unlike R6-6's dangling
## [code]surface[/code]) because Story 005 is the work that will discover
## whether it is needed — deleting now and re-adding later would change a
## frozen signature twice. 🔴 [b]The ruling set a deadline: Story 005 must
## settle this on completion — implement, or delete permanently.[/b]
## Until then this is NOT a contract and nothing may be built on it.
##
## 🔴 [b]One return code means more than ADR-0005 says it does — this is an
## implementation choice, not contract.[/b]
## [constant SetTargetResult.INVALID_SURFACE_TYPE] is ALSO what a
## [code]null[/code] [param target] returns. ADR-0005 defines no code for a
## null target and [enum SetTargetResult]'s member list is frozen, so null is
## mapped onto the least-wrong existing member. Consequence for callers: this
## code does [b]not[/b] distinguish "the surface value is out of range"
## (a data problem, recoverable at runtime) from "the caller passed null"
## (a caller-side bug that no runtime retry can fix). If you need to tell them
## apart, check before calling — do not read a distinction into the code that
## is not there.
## [i]This is a summary. The full derivation lives at
## [method _validate_target_writable]; it is restated here on purpose, because
## callers of a public method do not read private ones. Change one, check the
## other.[/i]
func set_target(target: CursorTarget, from_ui_action: bool) -> SetTargetResult:
	if _mutation_in_progress:
		return SetTargetResult.REJECTED_REENTRANT
	_mutation_in_progress = true

	# Shared with handoff_after_mount() through the private path — NOT by one
	# entry calling the other, which the latch above would reject.
	var result: SetTargetResult = _validate_target_writable(target)
	if result == SetTargetResult.APPLIED:
		_write_target_internal(target, TargetResetPolicy.CONDITIONAL_ON_CHANGE)

	# ⚠️ from_ui_action IS READ — here, as a deliberate no-op branch, and this
	# comment is the reason it looks like a dangling parameter.
	# AC-39 (the only testable acceptance criterion on this parameter) governs
	# the FALSE case: device authority must be untouched. That holds by
	# construction — nothing above writes _device_authority.
	# 🔴 The TRUE case is NOT implemented, because ADR-0005 does not define it.
	# 機制十一 says only "set_target() transfers device authority when
	# from_ui_action is true" and never says TO WHICH device — and this
	# signature carries no device information to derive it from. The one
	# structurally consistent reading is that 步驟一
	# (arbitrate_device_authority, priority −100) has already settled authority
	# earlier in the same frame, before any 步驟二 caller re-target at −60, so
	# there is nothing left for this entry to transfer. Inventing a rule here
	# would be exactly the "assumption that runs clean and prints pretty
	# numbers" this project has been burned by.
	# ✅ RULED 2026-09-03: explicitly deferred, not implemented, and the
	# parameter is kept rather than deleted. Recorded in ADR-0005 機制十一,
	# paragraph "裝置權威不隨目標交接重置" — read the ruling there, not here.
	# The ruling set a deadline: Story 005 must settle it on completion
	# (implement, or delete the parameter permanently).
	# 🔴 Until then this is NOT a contract. Do not build on it.
	if from_ui_action:
		pass

	_drain_pending_reseed()
	_mutation_in_progress = false
	return result


## TR-cursor-013 / AC-37 race guard: flips the current target's validity flag
## to false ("pending re-resolve") only if [param expected] still matches what
## this object holds.
##
## 🔴 [b]Caller ordering obligation, and it is a trap[/b]: save the OLD target
## value first, write your new state, and only THEN call this — passing a
## [param expected] you re-read after your own write compares the state against
## itself and can never detect the race it exists to detect.
##
## Never silent: a mismatch returns [constant MarkResult.STALE_NOT_APPLIED]
## and changes nothing, so the caller can tell "not applied" from "applied"
## programmatically (AC-37's 2026-08-06 amendment). Authority is untouched
## either way (AC-39).
##
## [b]The other two return codes[/b]:
## [constant MarkResult.REJECTED_REENTRANT] means the call arrived while
## another public entry was mid-mutation; nothing was changed.
## 🔴 [constant MarkResult.NO_CURRENT_TARGET] is an [b]implementation choice,
## not contract[/b] — ADR-0005 names the member and never defines when it
## fires. This class fires it when there is no current [b]valid[/b] target to
## invalidate, which [b]includes[/b] the case where [param expected] does match
## but the held target is already pending re-resolve. Consequence for callers:
## you can get this code back on a call whose desired post-condition ("that
## target is pending re-resolve") is [b]already satisfied[/b], so it does not
## mean "try again" — retrying returns the same code forever.
## [i]This is a summary. The full derivation lives at
## [method _mark_pending_reresolve_internal]; it is restated here on purpose,
## because callers of a public method do not read private ones. Change one,
## check the other.[/i]
func mark_pending_reresolve(expected: CursorTarget) -> MarkResult:
	if _mutation_in_progress:
		return MarkResult.REJECTED_REENTRANT
	_mutation_in_progress = true

	# AC-39: device authority is never touched on this path either. The two
	# fields are orthogonal; writing the target never implies a transfer.
	var result: MarkResult = _mark_pending_reresolve_internal(expected)

	_drain_pending_reseed()
	_mutation_in_progress = false
	return result


## 甲 handoff branch (機制十一): called when a load flow begins, before the old
## surface is torn down. Marks the current target pending-re-resolve AND
## unconditionally reseeds the reclaim accumulator with
## [constant CursorTypes.ResetTrigger.SURFACE_HANDOFF] (GDD Core Rules #7 F2-2).
##
## 🔴 [b]This is the entry the ADR calls out as nearly deadlocking itself[/b]:
## 機制十一 says 甲 must "call [method mark_pending_reresolve]", but both are
## gated public entries — doing that literally would have 甲 rejected by the
## latch it just set, and the marking would never happen. The ADR's final fix
## (R5-1, the same shape as R4-4's [method arbitrate_device_authority] →
## [method set_target]) is to extract the shared work into the ungated private
## [method _mark_pending_reresolve_internal] and have BOTH entries call that.
## That is what this method does; it never calls [method mark_pending_reresolve].
##
## Takes no [param surface] argument. One was removed in 2026-08-21 (R6-6): it
## was read nowhere, and as a guard it was unimplementable, because no
## [enum MarkResult] member can say "wrong surface" without lying.
func handoff_before_unload() -> MarkResult:
	if _mutation_in_progress:
		return MarkResult.REJECTED_REENTRANT
	_mutation_in_progress = true

	# 🔴 The private path, NOT the public mark_pending_reresolve(). Calling the
	# public entry here is the self-deadlock the ADR spent two review rounds
	# on: the latch is already up, so 甲's marking would be rejected as
	# reentrant and would never happen — silently, since the caller would just
	# see REJECTED_REENTRANT and could not tell it was self-inflicted.
	#
	# Passing _target as `expected` cannot be stale by construction: it is the
	# very object being compared against. That is intentional — 甲's contract
	# is "mark whatever is current", not "mark what you thought was current".
	var result: MarkResult = _mark_pending_reresolve_internal(_target)

	# UNCONDITIONAL, and outside the result check: GDD Core Rules #7 F2-2
	# requires the accumulated displacement to zero on 甲 regardless of whether
	# there was anything to mark — the old surface is going away, so the old
	# seed and the surface it was anchored to stop meaning anything either way.
	# SURFACE_HANDOFF rather than TARGET_CHANGED because the target did not
	# change here; telling reset_triggered subscribers otherwise would be a lie.
	# Skipped when _reclaim is null - reported once at construction, see
	# ERR_RECLAIM_POLICY_ABSENT. This guard is this file's decision;
	# ADR-0005 has no position on a null _reclaim.
	if _reclaim != null:
		_reclaim.reset(_safe_mouse_position(), CursorTypes.ResetTrigger.SURFACE_HANDOFF)

	_drain_pending_reseed()
	_mutation_in_progress = false
	return result


## 乙 handoff branch (機制十一): called after a load succeeds and the new
## surface has mounted. Runs the SAME validation as [method set_target] (via
## the shared [method _validate_target_writable]) and then writes with
## [constant TargetResetPolicy.UNCONDITIONAL].
##
## [b]Why a dedicated entry instead of a third [method set_target] parameter[/b]
## (R5-1): 乙's reset is unconditional while the general path's is conditional.
## Hiding two semantics behind one bool is a boolean trap, and GDScript has no
## call-site named arguments — [code]set_target(t, false, true)[/code] tells a
## reader nothing. Paired with [method handoff_before_unload], the two names
## read as the two halves of a handoff lifecycle.
##
## [b]Unconditional matters[/b]: if the newly computed target happens to equal
## the current one, a conditional reset would silently skip the zeroing GDD
## Core Rules #7 F2-2 mandates.
##
## 🔴 [b]Return codes where ADR-0005 is silent[/b]: identical to
## [method set_target], because the validation is literally the same private
## path — including [constant SetTargetResult.INVALID_SURFACE_TYPE] doubling
## as the code for a [code]null[/code] [param target]. That doubling is an
## implementation choice, not contract. [b]Read [method set_target]'s note[/b];
## it is deliberately not copied a third time here.
func handoff_after_mount(target: CursorTarget) -> SetTargetResult:
	if _mutation_in_progress:
		return SetTargetResult.REJECTED_REENTRANT
	_mutation_in_progress = true

	# The SAME validation set_target() runs, reached the same way — through the
	# shared private path, not by borrowing the other public entry. Skipping it
	# to dodge the latch was the failure mode 專家發現 2b named: it would let an
	# unregistered or out-of-range surface be written in under SURFACE_HANDOFF,
	# a trust assumption nothing downstream re-checks.
	var result: SetTargetResult = _validate_target_writable(target)
	if result == SetTargetResult.APPLIED:
		# UNCONDITIONAL: 乙 must zero the accumulator even when the newly
		# computed target happens to equal the current one. Under
		# CONDITIONAL_ON_CHANGE that case would silently skip the reset GDD
		# Core Rules #7 F2-2 mandates.
		_write_target_internal(target, TargetResetPolicy.UNCONDITIONAL)

	_drain_pending_reseed()
	_mutation_in_progress = false
	return result


## Reseeds the reclaim accumulator at the current mouse position with
## [constant CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED] — GDD Core Rules #3
## trigger (c). Forwarded in one line by [code]CursorStateHost[/code]'s
## [code]resume_arbitration()[/code] and its
## [code]NOTIFICATION_APPLICATION_FOCUS_IN[/code] branch (機制九).
##
## [b]Why this is gated even though it never touches the target[/b] (專家發現 D):
## a downstream handler of [signal target_changed] calling
## [code]resume_arbitration()[/code] is a REASONABLE downstream design, not
## misuse — and signals are emitted while the latch is still up, so that call
## would land inside a half-finished write and reset [member _reclaim] a second
## time, across methods, where no single-function review would catch it. The
## forbidden pattern [code]cursor_state_write_from_own_signal_handler[/code]
## bans it by discipline; this ADR's standing position is that structure beats
## discipline.
##
## 🔴 [b]On reentry this does NOT discard the request[/b] (R6-10): it sets
## [member _pending_reseed], and whichever entry currently holds the latch
## replays it via [method _drain_pending_reseed] before clearing. Discarding
## was the original behaviour and it silently reopened the very gap this method
## was added to close — with a [code]void[/code] return, the caller could not
## even find out.
func reseed_reclaim_on_focus_regained() -> void:
	if _mutation_in_progress:
		# R6-10: record, do not discard. The counter still increments — a
		# reentrant call means this system has an unexpected internal call
		# path, and with a void return that is the only trace there is.
		_pending_reseed = true
		diagnostic_reentrant_rejection_count += 1
		return
	_mutation_in_progress = true

	# Skipped when _reclaim is null - reported once at construction, see
	# ERR_RECLAIM_POLICY_ABSENT. This guard is this file's decision;
	# ADR-0005 has no position on a null _reclaim.
	if _reclaim != null:
		_reclaim.reset(_safe_mouse_position(), CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED)

	# This entry cannot induce the reentry itself (it emits no signal), so
	# strictly it does not need the drain. ADR-0005 has all seven call it
	# anyway: the duplicated cost is one line, and "which one was the
	# exception?" is how a missing call site gets introduced later.
	_drain_pending_reseed()
	_mutation_in_progress = false


# ─── Read interface (TR-cursor-014) ─────────────────────────────────────────
#
# 🔴 TWO SEPARATE QUERIES, NOT ONE MERGED "can I confirm?" BOOLEAN — and this
#    is a correctness requirement, not an API-taste preference (GDD Core Rules
#    #3 (iv), AC-54). The two rejection causes need OPPOSITE recoveries:
#      · confirm refused because the target is pending re-resolve
#        (is_current_target_valid() == false) → wait for the owning system to
#        re-resolve it, or navigate somewhere else;
#      · mouse click refused because authority is not the mouse
#        (get_device_authority() != MOUSE) → MOVE the mouse far enough to
#        reclaim authority; clicking again will never work.
#    Merged into one boolean, a caller is STRUCTURALLY unable to produce
#    distinguishable feedback, and the player is pushed toward the wrong fix.


## Gates confirm/select actions (AC-33). A caller that reads [code]false[/code]
## must refuse to let a confirm take effect on this target. [b]This system
## guarantees only that the answer is correct[/b] — whether callers obey is each
## caller's own acceptance scope (same split as AC-50's preview consumers).
func is_current_target_valid() -> bool:
	return _target != null and _target.is_valid


## Gates mouse-click confirmation (AC-54 cause (b)). See the block comment
## above for why this is not folded into [method is_current_target_valid].
func get_device_authority() -> CursorTypes.Authority:
	return _device_authority


## Returns a freshly allocated COPY, never the internal instance (forbidden
## pattern [code]returning_internal_container_references[/code], ADR-0001).
## [CursorTarget] is a [RefCounted]: handing out the internal one would let a
## caller hold an object this system mutates underneath it. [CursorTarget] is
## designed immutable, but "immutable" is discipline; copying makes it structure.
func get_current_target() -> CursorTarget:
	if _target == null:
		return null
	# Field-by-field rather than CursorTarget.make() + a fixup, because make()
	# forces is_valid true and the whole point here is to reproduce the current
	# validity faithfully. Kept inline rather than extracted: a seventh
	# underscore-prefixed method would contradict the "exactly six private
	# paths" invariant a static reviewer is asked to check (VC #13).
	var copy: CursorTarget = CursorTarget.new()
	copy.surface = _target.surface
	copy.id = _target.id
	copy.is_valid = _target.is_valid
	return copy


## Pure forward to [method MouseReclaimPolicy.reclaim_progress] (R5-3), so the
## presentation layer never needs a reference to [member _reclaim]. Same reason
## [signal reclaim_reset_triggered] exists.
##
## 🔴 [b]A returned [code]0.0[/code] is AMBIGUOUS and downstream code cannot
## resolve it from this value alone.[/b] It means either "no reclaim attempt is
## in progress" (a real measurement from a live policy) or "no reclaim policy
## exists yet, so nothing is ever measured" ([member _reclaim] is
## [code]null[/code] — see [constant ERR_RECLAIM_POLICY_ABSENT]).
## [b]Until Story 014 lands, it is ALWAYS the second one[/b], because
## [code]CursorStateHost[/code] constructs this class with
## [code]null[/code] and the mouse-reclaim submechanism is user-frozen.
## [br]
## Consequence for downstream acceptance criteria, stated here because the
## downstream story cannot see it from this side: any criterion whose GIVEN is
## "reclaim progress is exactly 0" is satisfied unconditionally right now, and
## any criterion needing a NON-zero progress cannot be reached at all. A test
## suite written against those criteria goes green without having exercised
## what they were written to protect. Build such tests against an injected
## [MouseReclaimPolicy] test double, never against the Autoload's instance.
func reclaim_progress() -> float:
	# 0.0 when _reclaim is null - reported once at construction, see
	# ERR_RECLAIM_POLICY_ABSENT. 0.0 is chosen because it is what a live policy
	# returns when idle, so the presentation layer needs no null-aware branch.
	# Cost, recorded honestly: an inert policy is then INDISTINGUISHABLE from a
	# real "no reclaim progress" reading through this query alone.
	if _reclaim == null:
		return 0.0
	return _reclaim.reclaim_progress()


# ─── Six ungated private paths (ADR-0005 機制十, R4-4 + R5-1 + R6-7/R6-10) ───
#
# 🔴 NONE of these six checks _mutation_in_progress. They are only ever reached
#    from a public entry that has already raised it; re-checking would make
#    every one of them reject itself. That is the whole point — they are the
#    route a public entry walks instead of borrowing another public entry.


## The ONLY place [member _target] is actually overwritten.
##
## 🔴 The two reset paths are [code]if[/code] / [code]elif[/code] and
## [b]must not be written as two independent [code]if[/code]s[/b] (專家發現 A,
## forbidden pattern [code]independent_ifs_for_cursor_target_reset_policy[/code]).
## Two independent ifs make the 乙 branch's NORMAL case (unconditional AND the
## target really changed) fire [method MouseReclaimPolicy.reset] twice in one
## write, emitting two different triggers on
## [signal reclaim_reset_triggered] — at which point Validation Criteria #15
## passes or fails depending on implementation detail.
func _write_target_internal(target: CursorTarget, reset_policy: TargetResetPolicy) -> void:
	# Ordering obligation from _target_changed_from(): keep the old value,
	# write the new one, THEN compare. Comparing after the overwrite compares
	# the new value with itself.
	var old: CursorTarget = _target
	_target = target
	var changed: bool = _target_changed_from(old, target)

	# 🔴 if / elif, NEVER two independent ifs (專家發現 A). The 乙 handoff
	# branch's normal case is UNCONDITIONAL *and* a genuinely changed target;
	# with two independent ifs that case fires reset() twice in a single write
	# and puts two different triggers on the wire.
	# Skipped when _reclaim is null - reported once at construction, see
	# ERR_RECLAIM_POLICY_ABSENT. This guard is this file's decision;
	# ADR-0005 has no position on a null _reclaim.
	# The if/elif pair is wrapped WHOLE rather than guarded per branch, so the
	# two reset paths stay mutually exclusive.
	if _reclaim != null:
		if reset_policy == TargetResetPolicy.UNCONDITIONAL:
			_reclaim.reset(_safe_mouse_position(), CursorTypes.ResetTrigger.SURFACE_HANDOFF)
		elif changed:
			_reclaim.reset(_safe_mouse_position(), CursorTypes.ResetTrigger.TARGET_CHANGED)

	# Orthogonal to reset_policy, exactly as the ADR requires: whether the
	# signal fires depends only on whether the target changed, never on which
	# reset path ran above.
	if changed:
		target_changed.emit()


## The ONLY place a target is marked pending-re-resolve. Shared by the public
## [method mark_pending_reresolve] and by [method handoff_before_unload] (甲),
## which is exactly why it exists — see that method's deadlock note.
##
## Goes through [method CursorTarget.invalidated], NOT through
## [method _write_target_internal]: this is a validity flip on the same
## surface/id, not a re-target, so it must not emit a
## [constant CursorTypes.ResetTrigger.TARGET_CHANGED] reset.
func _mark_pending_reresolve_internal(expected: CursorTarget) -> MarkResult:
	# 📌 A one-paragraph summary of this boundary is repeated in the PUBLIC
	# doc comment of mark_pending_reresolve() — callers never read private
	# methods. Two copies on purpose; if this reasoning changes, change both.
	# ⚠️ BOUNDARY NOT DEFINED BY ADR-0005 — reported, not silently chosen.
	# The ADR names NO_CURRENT_TARGET in the enum and never says when it is
	# returned. [member _target] is never null after _init(), so reading it as
	# "the reference is null" would make the member permanently dead — and this
	# ADR deleted SURFACE_MISMATCH rather than keep a member nothing can reach.
	# Reading it as "there is no CURRENT (valid) target to invalidate" makes it
	# reachable and useful, and matches this project's idempotent-rejection
	# convention (CursorSurfaceRegistry.DUPLICATE_TAG_REJECTED, ADR-0002's
	# notify_death()). Checked BEFORE the staleness comparison because
	# "is the caller's belief current?" is meaningless when there is nothing
	# current to compare against.
	if _target == null or not _target.is_valid:
		return MarkResult.NO_CURRENT_TARGET

	# AC-37: the caller's expected target no longer matches what we hold — the
	# player navigated away between the caller detecting the failure and
	# calling us. Change NOTHING and say so; never silently ignore.
	# equals() is value comparison and deliberately ignores is_valid (機制三);
	# using == here would compare object identity and reject every legitimate
	# call made with a reconstructed target.
	if expected == null or not expected.equals(_target):
		return MarkResult.STALE_NOT_APPLIED

	var old: CursorTarget = _target
	_target = CursorTarget.invalidated(old)
	# Same surface and id, only is_valid flipped — so equals() sees no change
	# and ONLY _target_changed_from()'s second condition catches this. Routed
	# through that method rather than judged inline (R6-7).
	if _target_changed_from(old, _target):
		target_changed.emit()
	return MarkResult.APPLIED


## Shared pre-write validation (專家發現 2b). Returns
## [constant SetTargetResult.APPLIED] for "passes"; otherwise the specific
## failure. Called by [method set_target] and [method handoff_after_mount],
## each of which then decides for itself whether to continue.
##
## Without this, [method handoff_after_mount] had only two options, both wrong:
## borrow [method set_target]'s validation and hit the latch, or skip
## validation and let an unregistered or invalid surface be written in under
## the [constant CursorTypes.ResetTrigger.SURFACE_HANDOFF] trust assumption
## nobody checks.
func _validate_target_writable(target: CursorTarget) -> SetTargetResult:
	# 📌 A one-paragraph summary of this boundary is repeated in the PUBLIC
	# doc comment of set_target() (handoff_after_mount() points at it rather
	# than holding a third copy). Two copies on purpose; change both.
	# ⚠️ BOUNDARY NOT DEFINED BY ADR-0005 — reported, not silently chosen.
	# SetTargetResult has no member for "you passed null", and the ADR froze
	# the member list. Mapping null onto INVALID_SURFACE_TYPE is the
	# least-wrong of the three available members (a null target carries no
	# surface tag at all), NOT an ADR decision. The alternative — assert() only
	# — is unacceptable here: assert() may be stripped from release export
	# builds, and the following line would then abort this function from
	# inside a raised reentrancy gate, leaving the gate permanently up and
	# every later public call rejected. assert() is kept as well, so the
	# caller's contract violation is loud in debug.
	assert(target != null, "CursorState._validate_target_writable: target must not be null")
	if target == null:
		return SetTargetResult.INVALID_SURFACE_TYPE

	# Checked before the registry lookup: an out-of-range tag cannot
	# meaningfully be "not registered", and a GDScript enum-typed field accepts
	# any int, so this is a real reachable case rather than a formality.
	# find_key() is this project's registered way to go value → enum member
	# (forbidden pattern enum_value_positional_string_conversion, ADR-0002);
	# it returns null when the value is not a member.
	if CursorTypes.SurfaceType.find_key(target.surface) == null:
		return SetTargetResult.INVALID_SURFACE_TYPE

	if _registry.get_surface(target.surface) == null:
		return SetTargetResult.SURFACE_NOT_REGISTERED

	return SetTargetResult.APPLIED


## The ONLY place a mouse coordinate is obtained (S-3).
##
## 🔴 The [method Callable.is_valid] check is REQUIRED, not defensive padding:
## calling a [Callable] bound to a freed object [b]aborts the whole enclosing
## function[/b] (measured —
## [code]prototypes/engine-verification-spike-2026-08-20/[/code] C2 / F-10).
## Without the check, this function would abort mid-way and its caller would
## see no coordinate and no error.
##
## Contract on failure: returns the LAST SUCCESSFULLY OBTAINED coordinate
## ([constant Vector2.ZERO] initially). That is safe for the one-shot reseeding
## call sites (handoff, focus regain) — seed once with a stale value, and the
## problem disappears when the provider recovers. It is NOT safe for the
## continuously polled [method MouseReclaimPolicy.evaluate] path, which is why
## that path is cut off upstream in [method arbitrate_device_authority] instead
## of being papered over here (R6-11 / Step 5.5 B-1).
func _safe_mouse_position() -> Vector2:
	if not _mouse_position_provider.is_valid():
		diagnostic_invalid_mouse_provider_count += 1
		return _last_mouse_position
	var position: Vector2 = _mouse_position_provider.call()
	_last_mouse_position = position
	return position


## The ONLY place that decides whether [signal target_changed] fires (R6-7).
## Both callers ([method _write_target_internal] and
## [method _mark_pending_reresolve_internal]) delegate here; neither judges
## inline.
##
## 🔴 The two conditions are OR'd and both are needed.
## [method CursorTarget.equals] deliberately ignores
## [member CursorTarget.is_valid] (機制三), so a validity flip has to be
## detected by the second condition. Concretely: loading a save back onto the
## same board flips is_valid false→true with identical surface and id — before
## R6-7 that emitted nothing, so every subscribe-only downstream stayed stuck
## on the pending-re-resolve visual forever. Polling downstreams never saw it.
##
## 🔴 [b]Caller ordering obligation[/b]: save the old value, write the new one,
## THEN call this. Overwrite [member _target] first and the old value is gone.
func _target_changed_from(old: CursorTarget, new: CursorTarget) -> bool:
	# Neither argument is reachable as null on any path this class builds
	# ([member _target] is set in _init and every write is validated first),
	# but [method CursorTarget.equals] asserts its argument is non-null and
	# would abort this function — and an abort inside a gated entry leaves
	# [member _mutation_in_progress] raised forever, permanently rejecting
	# every later call. Falling back to reference comparison keeps that
	# failure mode out of reach for the cost of one branch.
	if old == null or new == null:
		return old != new
	return not old.equals(new) or old.is_valid != new.is_valid


## Replays a reseed request that [method reseed_reclaim_on_focus_regained] had
## to defer because the latch was up (R6-10). All seven public entries call
## this exactly once, immediately BEFORE clearing
## [member _mutation_in_progress].
##
## Six of them can emit a signal and therefore can induce the reentry; the
## seventh ([method reseed_reclaim_on_focus_regained]) cannot, and calls it
## anyway. ADR-0005 is explicit that all seven do it uniformly rather than six —
## the duplicated cost is one call, and "which one was the exception again?" is
## exactly how a missed call site happens.
func _drain_pending_reseed() -> void:
	if not _pending_reseed:
		return
	# Reset first, clear the flag second — the ADR's stated order, and it is
	# the right one: reset() emits reset_triggered, which this class forwards,
	# so a downstream handler can re-enter and set _pending_reseed again during
	# this very call. Clearing afterwards discards that request, which is
	# correct because it is redundant — we just reseeded, and reseeding is
	# idempotent (which is also why _pending_reseed is a bool, not a count).
	# Skipped when _reclaim is null - reported once at construction, see
	# ERR_RECLAIM_POLICY_ABSENT. This guard is this file's decision;
	# ADR-0005 has no position on a null _reclaim.
	if _reclaim != null:
		_reclaim.reset(_safe_mouse_position(), CursorTypes.ResetTrigger.FOCUS_LOST_REGAINED)
	_pending_reseed = false
