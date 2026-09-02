# Probe: freed-but-non-null object at a statically `Control`-typed call boundary

**Status**: Concluded, 2026-09-02.

## Hypothesis under test

Claim from `src/ui/cursor/cursor_surface_registry.gd`'s doc comment on
`register_native_pointer_exception(node: Control)` (Story 003,
`production/epics/cursor-highlight-state/story-003-surface-registry.md`):

> for a statically `Control`-typed parameter, an already-freed (non-null)
> argument never reaches this method's body at all — GDScript's
> typed-parameter boundary check rejects it with a script error
> ("previously freed... not a subclass of the expected argument class") and
> aborts the CALLER, one level higher than the C2/F-10 finding
> (`prototypes/engine-verification-spike-2026-08-20/`, which tested
> `Callable.call()` on a freed object's own bound method, not a typed
> parameter boundary).

This has a direct consequence for the production code under review: if true,
`register_native_pointer_exception()`'s `is_instance_valid(node)` guard can
only ever observe `INVALID_NODE` for a literal `null` argument — never for a
freed-but-non-null reference, because the function body would never run for
that case at all.

This claim had **no executable probe file** anywhere in the repository prior
to this one — only prose in `cursor_surface_registry.gd` and
`tests/unit/cursor/surface_registry_test.gd`'s comments. The closest existing
evidence, `prototypes/engine-verification-spike-2026-08-20`'s C2/F-10 finding,
tested a **different** operation: calling `Callable.call()` on a freed
object's own bound method. It does not test what happens when a freed object
is passed as an **argument** to a function whose **parameter** is statically
typed to a concrete class.

## What was measured

Four scenarios, each routed through a wrapper function (own file,
`scripts/probe_tests.gd`) invoked via `Callable.call()` from the runner
(`scripts/runner.gd`) — the same isolation technique already established in
`prototypes/xcheck-gdscript-specialist-2026-08-20/scripts/x11c_typed_boundary_assign.gd`:
wrapping a risky call in its own function lets an abort be observed (via the
zero-value return and the absence of the "REACHED END" / "ENTERED BODY"
print) without crashing the whole probe run.

1. **Case A** — a `Control` freed via immediate, synchronous `.free()`, then
   passed to `Callee.typed_control_param(c: Control)`, `Callee.typed_node_param(n: Node)`,
   and `Callee.untyped_variant_param(v: Variant)` (`scripts/callee.gd`).
2. **Case B** — a `Control` added to the tree, `queue_free()`'d, with two
   `await get_tree().process_frame` before use (matching how a freed node
   would actually disappear via the deferred path, not just immediate
   `.free()`), then passed to the same typed-`Control` callee.
3. **Control group 1** — a still-valid (not freed) `Control` through the
   identical typed-`Control` callee, to confirm the wrapper shape itself
   works normally.
4. **Control group 2** — a literal `null` through the identical typed-`Control`
   callee, matching the case
   `tests/unit/cursor/surface_registry_test.gd`'s
   `test_register_native_pointer_exception_null_node_returns_invalid_node`
   already covers, for a side-by-side comparison in the same run.

## Files this probe actually executed (the (A)-level evidence trail)

- `prototypes/adr0005-story003-freed-control-boundary-probe-2026-09-02/project.godot`
- `prototypes/adr0005-story003-freed-control-boundary-probe-2026-09-02/scenes/Probe.tscn`
  (main scene, root node's script is `runner.gd`)
- `prototypes/adr0005-story003-freed-control-boundary-probe-2026-09-02/scripts/runner.gd`
- `prototypes/adr0005-story003-freed-control-boundary-probe-2026-09-02/scripts/probe_tests.gd`
- `prototypes/adr0005-story003-freed-control-boundary-probe-2026-09-02/scripts/callee.gd`

## How to run

```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path .
```

Run 2026-09-02, Godot Engine v4.7.1.stable.official.a13da4feb, exit code **0**.
Full unfiltered stdout/stderr: `logs/run.txt` (reproduced verbatim below).

## Verbatim output

```
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

=== ADR-0005 Story 003 freed-Control call-boundary probe / Godot 4.7.1-stable (official) ===

--- Case A: Control freed via immediate .free() (synchronous) ---
  after .free(): is_instance_valid(freed_ref_a)=false  freed_ref_a==null:true
    >> Case A -> Callee.typed_control_param(freed_ref_a) [typed Control param] : calling...
      >> wrapper entering. is_instance_valid=false  ==null:true
SCRIPT ERROR: Invalid type in function 'typed_control_param' in base 'GDScript'. The Object-derived class of argument 1 (previously freed) is not a subclass of the expected argument class.
   at: test_typed_control_param_with_freed_object (res://scripts/probe_tests.gd:26)
   GDScript backtrace (most recent call first):
       [0] test_typed_control_param_with_freed_object (res://scripts/probe_tests.gd:26)
       [1] _run_str (res://scripts/runner.gd:27)
       [2] _ready (res://scripts/runner.gd:46)
    << Case A -> Callee.typed_control_param(freed_ref_a) [typed Control param] : returned EMPTY STRING -- ABORTED (zero value for -> String)
    >> Case A -> Callee.typed_node_param(freed_ref_a) [typed Node param] : calling...
      >> wrapper entering. is_instance_valid=false  ==null:true
SCRIPT ERROR: Invalid type in function 'typed_node_param' in base 'GDScript'. The Object-derived class of argument 1 (previously freed) is not a subclass of the expected argument class.
   at: test_typed_node_param_with_freed_object (res://scripts/probe_tests.gd:35)
   GDScript backtrace (most recent call first):
       [0] test_typed_node_param_with_freed_object (res://scripts/probe_tests.gd:35)
       [1] _run_str (res://scripts/runner.gd:27)
       [2] _ready (res://scripts/runner.gd:50)
    << Case A -> Callee.typed_node_param(freed_ref_a) [typed Node param] : returned EMPTY STRING -- ABORTED (zero value for -> String)
    >> Case A -> Callee.untyped_variant_param(freed_ref_a) [untyped Variant param, control case] : calling...
      >> wrapper entering. is_instance_valid=false  ==null:true
      >> untyped_variant_param: ENTERED BODY, param is_instance_valid()=false
      >> wrapper: call returned [REACHED END untyped_variant_param], about to return
    << Case A -> Callee.untyped_variant_param(freed_ref_a) [untyped Variant param, control case] : returned [REACHED END wrapper result=[REACHED END untyped_variant_param]]

--- Case B: Control in the SceneTree, queue_free()'d, awaited 2 process frames ---
  after queue_free()+2 frames: is_instance_valid(freed_ref_b)=false  freed_ref_b==null:true
    >> Case B -> Callee.typed_control_param(freed_ref_b) [typed Control param] : calling...
      >> wrapper entering. is_instance_valid=false  ==null:true
SCRIPT ERROR: Invalid type in function 'typed_control_param' in base 'GDScript'. The Object-derived class of argument 1 (previously freed) is not a subclass of the expected argument class.
   at: test_typed_control_param_with_freed_object (res://scripts/probe_tests.gd:26)
   GDScript backtrace (most recent call first):
       [0] test_typed_control_param_with_freed_object (res://scripts/probe_tests.gd:26)
       [1] _run_str (res://scripts/runner.gd:27)
       [2] _ready (res://scripts/runner.gd:71)
    << Case B -> Callee.typed_control_param(freed_ref_b) [typed Control param] : returned EMPTY STRING -- ABORTED (zero value for -> String)

--- Control group: still-VALID Control through the same typed-param call ---
    >> Control group -> Callee.typed_control_param(valid_control) [typed Control param, NOT freed] : calling...
      >> wrapper entering (control case: still-valid object). is_instance_valid=true
      >> typed_control_param: ENTERED BODY, param is_instance_valid()=true
      >> wrapper: call returned [REACHED END typed_control_param], about to return
    << Control group -> Callee.typed_control_param(valid_control) [typed Control param, NOT freed] : returned [REACHED END wrapper result=[REACHED END typed_control_param]]

--- Control group: literal null through the same typed-param call ---
    >> Control group -> Callee.typed_control_param(null) [typed Control param, literal null] : calling...
      >> wrapper entering (control case: literal null)
      >> typed_control_param: ENTERED BODY, param is_instance_valid()=false
      >> wrapper: call returned [REACHED END typed_control_param], about to return
    << Control group -> Callee.typed_control_param(null) [typed Control param, literal null] : returned [REACHED END wrapper result=[REACHED END typed_control_param]]

=== PROBE COMPLETE ===
```

## Findings

1. **The claim is CONFIRMED, for both a synchronous `.free()` and a
   `queue_free()`+2-frame deferred free.** In both Case A and Case B, calling
   a function with a statically `Control`-typed parameter (also reproduced
   for `Node`) with a freed-but-previously-valid reference produces
   `SCRIPT ERROR: Invalid type in function '...'. The Object-derived class of
   argument 1 (previously freed) is not a subclass of the expected argument
   class`, and the callee's body is **never entered** — no "ENTERED BODY"
   print appears for either case, in contrast to both control groups where it
   does. The abort happens in the **calling** function (here, the wrapper in
   `probe_tests.gd`) and does not propagate past it — `_run_str` and `_ready`
   continue normally afterward, matching the "aborts the immediate caller
   only, does not propagate upward" shape already established by
   `engine-verification-spike-2026-08-20`'s C2/F-10 finding for a different
   operation (`Callable.call()`).

2. **This is a genuinely distinct mechanism from C2/F-10, not a restatement
   of it.** F-10 showed that *calling a method on* a freed object aborts the
   function that made that call. This probe shows the abort can happen one
   step earlier and for a different reason: at *argument passing* into a
   statically-typed parameter, before the callee's body is entered at all —
   the callee is never on the stack when the error fires (see the
   backtraces above: the abort's frame `[0]` is always the **wrapper**,
   never `typed_control_param`/`typed_node_param` themselves).

3. **The check is NOT limited to a statically `Control`-typed variable at the
   call site.** `freed_ref_a` and `freed_ref_b` are both declared `Variant`
   in `runner.gd`, yet the same abort occurred. The relevant static type for
   this check is the **callee's declared parameter type**, not the caller's
   variable type — this makes the finding apply to
   `register_native_pointer_exception(node: Control)` regardless of how the
   as-yet-unwritten downstream caller happens to type its own local
   variable.

4. **A freed-but-non-null reference is treated differently from a literal
   `null` by this specific check, despite `== null` reporting `true` for
   both.** `freed_ref_a == null` printed `true` (Godot's equality operator on
   an `Object`-typed `Variant` appears to normalize a freed instance to
   compare equal to `null`), yet passing that same reference into a typed
   `Control` parameter does **not** get the same lenient treatment a literal
   `null` gets — literal `null` enters the callee body normally (bottom control
   group: "ENTERED BODY, param is_instance_valid()=false"), while the freed
   reference never reaches the body at all. Equality-comparison normalization
   and argument type-checking are evidently two different code paths inside
   the engine, and only one of them treats a freed instance as
   null-equivalent.

5. **Consequence for the production code under review**
   (`src/ui/cursor/cursor_surface_registry.gd`,
   `register_native_pointer_exception(node: Control)` /
   `unregister_native_pointer_exception(node: Control)`): the internal
   `is_instance_valid(node)` guard is reachable and correct for a literal
   `null` argument (already covered by
   `tests/unit/cursor/surface_registry_test.gd`'s
   `test_register_native_pointer_exception_null_node_returns_invalid_node`),
   but **cannot ever observe a freed-but-non-null argument** — any caller
   that does that will never reach this function's body; the caller itself
   takes the `SCRIPT ERROR` and its own execution aborts at that call
   statement. The `INVALID_NODE` return value is reachable in practice only
   through the `null` path, exactly as the production doc comment claims.
   This does not make the guard wrong to keep (it is correct, cheap, and
   still catches the only case it *can* catch), but the doc comment's
   characterization of the freed-non-null branch as unreachable dead code is
   accurate and should stay documented rather than being read as "the
   `is_instance_valid()` check is unnecessary."

## Evidence level

**(A)** per `.claude/docs/technical-preferences.md`'s three-tier rule — this
measurement ran the project's actual engine (Godot 4.7.1.stable) against
GDScript files written for exactly this question, not a reimplementation of
Godot's type-checking rules in another language. Files executed are listed
above under "Files this probe actually executed".
