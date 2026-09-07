## Dedicated child node for GDD 步驟三 / 機制六③ (ADR-0005), added by
## [code]CursorStateHost[/code] in its own [method Node._ready] via
## [method Node.add_child]. Exists SOLELY because [member Node.process_priority]
## is a per-node property: 機制六①(裝置權威判定,[code]CursorStateHost[/code]
## itself, [code]process_priority = -100[/code])與機制六③(緩衝內導覽寫入,
## THIS node, [code]process_priority = -25[/code])不能共用一個節點 —— 一個
## 呼叫方自己的機制六②主動改標(架構強制落在開區間 -100 < ② < -25)必須夾在
## 兩者之間,發生在一個本 story 不擁有的第三顆節點上。
##
## [b]Discipline mirrors [code]CursorStateHost[/code]'s own shell[/b] (see
## that file's class doc comment, "Deliberately empty of logic" / forbidden
## pattern [code]logic_in_cursor_autoload_shell[/code]): this node's
## [method Node._process] is a ONE-LINE FORWARD to
## [method CursorStateHost.flush_buffered_navigation] and contains no
## arbitration logic of its own — the decision body lives entirely in
## [method CursorState.apply_buffered_navigation] (機制六, the "STORY 005
## SEAM" marked in [code]cursor_state.gd[/code]).
##
## 🔴 [b][member _host]'s type is [code]_CursorStateHostScript[/code], a
## preloaded-script constant, NOT a [code]class_name[/code]-based static
## type.[/b] ADR-0005's illustrative pseudocode (機制五 section,
## [code]var _host: CursorStateHost[/code]) does not compile as written:
## [code]cursor_state_host.gd[/code] deliberately declares NO
## [code]class_name[/code] — that file's own class doc comment records that
## [code]class_name CursorStateHost[/code] is a parse-time error here,
## because it collides with the Autoload registration of the same name
## (verified during Story 002's own first test run). Flagged for the
## architecture owner in this story's report; not corrected in the ADR
## itself (out of this story's write scope — [code]docs/architecture/[/code]
## is not one of the three directories this story is authorized to write).
## [br]
## [b]Verified this preload-as-type substitute actually compiles and behaves
## as a static type[/b] (2026-09-07, this story's own throwaway headless
## probe, run against a scratch project OUTSIDE this repository — a generic
## GDScript-language question, not a measurement of this project's data, so
## it is cited as its own thing rather than claimed as (A)-level project
## evidence): BOTH [code]const X := preload(...); var f: X[/code] AND
## [code]const X: GDScript = preload(...); var f: X[/code] constructed an
## instance through the typed field and called a method on it, exit code 0
## for both forms, output [code]RESULT:pong[/code] /
## [code]RESULT2:pong[/code] respectively. The exact spelling used below,
## [code]const _CursorStateHostScript: GDScript = preload(...)[/code],
## matches [code]tests/unit/cursor/state_host_test.gd[/code] line 82
## character-for-character — [b]that file uses the identical line only for
## [Script] identity comparison, never as a variable's static type, so this
## is NOT an existing project precedent for THIS use[/b]; it is this story's
## own choice, independently verified to compile and behave correctly by the
## probe above, not inherited from prior art.
class_name CursorNavigationApplier
extends Node

const _CursorStateHostScript: GDScript = preload("res://src/ui/cursor/cursor_state_host.gd")

var _host: _CursorStateHostScript


## [param host] is the SAME [code]CursorStateHost[/code] Autoload instance
## that constructs and [method Node.add_child]s this node from its own
## [method Node._ready] — there is exactly one, never a second.
## [member Node.process_priority] is set HERE, before [method Node.add_child]
## (ADR-0005 R6-12: the assignment must sit earlier in source order than
## every [code]add_child()[/code] call site), mirroring the same convention
## [code]self_drawn_reclaim_cursor.gd[/code] /
## [code]native_pointer_visibility_arbiter.gd[/code] already use for their
## own [code]process_priority = 50[/code].
func _init(host: _CursorStateHostScript) -> void:
	_host = host
	process_priority = -25


## GDD 步驟三 / 機制六③. One-line forward — see class doc comment for why
## nothing else belongs here.
func _process(_delta: float) -> void:
	_host.flush_buffered_navigation()
