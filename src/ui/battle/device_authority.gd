## Single-authority arbiter for who owns the cursor: mouse or gamepad.
## Decides by "whoever acted most recently", per the manager's ruling
## recorded in [code]production/session-state/active.md[/code] 第十七批
## 管理者裁決(游標裝置權威 = 最後動作者優先): mouse motion claims
## authority, pad input claims authority, and if both happen within the
## same resolved frame, [b]PAD wins the tie[/b]. The tie-break direction was
## reversed by a later ruling — search [code]production/session-state/
## active.md[/code] for "2026-09-02 管理者裁決:平手時" for the full text.
## The original 第十七批 tie-break had mouse winning; that clause is
## superseded. The other two rules from 第十七批 are unchanged: mouse
## motion claims authority, pad input claims authority.
## [br]
## [b]The pad-wins clause is a tie-break, not a steady-state.[/b] It only
## applies when both devices report activity within the same frame.
## Implementing this as "pad always has authority" would make the mouse
## unusable whenever a gamepad reports any input, which breaks
## [code]technical-preferences.md[/code]'s requirement that keyboard/mouse
## remain the primary PC input method. The scenario this class exists to
## fix: a player sets the mouse down and picks up the gamepad — the mouse
## never moves again, so authority must still transfer to PAD on the next
## pad input, not stay stuck on MOUSE forever.
## [br]
## Deliberately a two-phase pattern: callers call [method note_mouse_motion]
## and [method note_pad_input] from wherever they translate raw
## [InputEvent]s, then call [method resolve_frame] exactly once per frame to
## decide and clear the flags. A single [InputEvent] can never represent
## "both devices acted this frame" by itself — the tie-break can only be
## evaluated once a whole frame's worth of activity is known. This class
## touches no [Input], [InputEvent], or node, and never reads
## [code]InputEvent.device[/code] — classifying an event as mouse-motion or
## pad-input is entirely the caller's job, per ADR-0005's registered
## forbidden pattern [code]reading_input_event_device_id[/code]. Keeping
## that classification out of this class is also what lets it be
## constructed with a bare [code]new()[/code] and tested fully headless.
## [br]
## [b]Pending consolidation — do not extend.[/b] [enum Device] has only two
## values ([code]MOUSE[/code] / [code]PAD[/code]) and no keyboard entry.
## ADR-0005's [code]CursorTypes.Authority[/code] has three
## ([code]UNINITIALIZED[/code] / [code]MOUSE[/code] /
## [code]KEYBOARD_GAMEPAD[/code], treating keyboard and gamepad as a single
## authority). The two representations will converge into one at Story 005
## ([code]production/epics/cursor-highlight-state/
## story-005-frame-buffer-ordering.md[/code]). Until that story lands, this
## class keeps running as-is — the battle screen depends on it and there is
## nothing to replace it with yet — but it must not gain new states, new
## devices, or new call sites beyond what already exists.
class_name DeviceAuthority
extends RefCounted

## The two devices that can hold cursor authority.
enum Device { MOUSE, PAD }

## Emitted exactly once per call to [method resolve_frame] that changes
## authority. Never emitted when authority does not change.
signal authority_changed(new_device: Device)

var _current: Device
var _mouse_moved_this_frame: bool = false
var _pad_input_this_frame: bool = false


## Constructs with [param initial] as the starting authority (defaults to
## MOUSE, matching a fresh scene where no input has happened yet).
func _init(initial: Device = Device.MOUSE) -> void:
	_current = initial


## Returns the device that currently holds cursor authority.
func current() -> Device:
	return _current


## Records that mouse motion happened this frame. Only sets a flag — does
## NOT resolve authority itself; see [method resolve_frame].
func note_mouse_motion() -> void:
	_mouse_moved_this_frame = true


## Records that gamepad/d-pad input happened this frame. Only sets a flag —
## does NOT resolve authority itself; see [method resolve_frame].
func note_pad_input() -> void:
	_pad_input_this_frame = true


## Call exactly once per frame (from [method Node._process] or equivalent).
## Resolves authority from this frame's recorded flags, then clears both
## flags regardless of outcome — so the next frame always starts from a
## clean slate. If both flags are set, PAD wins (the manager's 2026-09-02
## tie-break ruling — see class doc). If neither flag is set, authority is
## left unchanged and nothing is emitted. Returns [code]true[/code] if
## authority changed as a result of this call (in which case
## [signal authority_changed] fires exactly once), [code]false[/code]
## otherwise.
func resolve_frame() -> bool:
	var next: Device = _current
	if _pad_input_this_frame:
		next = Device.PAD
	elif _mouse_moved_this_frame:
		next = Device.MOUSE

	_mouse_moved_this_frame = false
	_pad_input_this_frame = false

	return _set_current(next)


# The only place _current is ever assigned — resolve_frame() is this
# class's sole public write entry, so there is no second public entry for
# it to call into (and no signal handler of this class's own signal exists
# to write back through). Keeps "only emit on a real change" in one spot.
func _set_current(next: Device) -> bool:
	if next == _current:
		return false
	_current = next
	authority_changed.emit(next)
	return true
