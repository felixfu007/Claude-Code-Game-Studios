# Story 001 — `@abstract` Compile Probe (2026-09-02)

## Hypothesis

Story 001 (`production/epics/cursor-highlight-state/story-001-shared-types.md`,
AC-S001-c) requires `MouseReclaimPolicy` to have:

1. A shape where 1 `signal` + 4 `@abstract func` with **four different return
   types** (`bool` / `float` / `void` / `Vector2`) coexist in one file and
   compile.
2. A subclass that implements only 3 of the 4 abstract methods to **fail at
   compile time**, with an error message that **names the specific missing
   method**.

`prototypes/engine-verification-spike-2026-08-20/` already verified `@abstract`
basics (bare-signature form, no `pass` body, one-method-missing = compile
error) but only tested **one abstract method missing at a time in isolation**,
not the full 4-method + signal shape that is the actual `MouseReclaimPolicy`
contract. This probe closes that gap for Story 001's specific AC.

## How to Run

This was run in a throwaway Godot project in the system temp scratchpad
directory (not committed — only `scripts/`, `logs/`, and this README are
preserved here, per this repo's prototype standards). To reproduce:

1. Copy `scripts/*.gd` into a fresh empty Godot 4.7.1 project directory,
   alongside a minimal `project.godot`.
2. Additionally create `incomplete_subclass_probe.gd` in that same directory
   with the exact contents quoted in the "Check (3) source" section below.
   **This file is deliberately not checked into this repo** — it does not
   compile, and this story's own instructions forbid placing a
   non-compiling `.gd` file anywhere under the project (prototypes/ included:
   the project-wide `--import` step parses every `.gd` file's header to scan
   for `class_name` declarations, and a broken file sitting there is an
   avoidable risk even though it was empirically confirmed not to break that
   scan — see the retry note below).
3. Run the import step once (builds `.godot/global_script_class_cache.cfg`,
   required for `class_name` cross-file resolution — same prerequisite
   documented in `.claude/docs/coding-standards.md` for the main test suite):
   ```
   godot --headless --path <project> --import
   ```
4. Run the probe:
   ```
   godot --headless --path <project> -s runner.gd
   ```

Engine used: `Godot_v4.7.1-stable_win64_console.exe` (matches this project's
pinned version, `docs/engine-reference/godot/VERSION.md`).

## Status

Concluded.

## Findings

Full output: `logs/probe-output.log`. Engine exit code: `0` (script ran to
completion; the probe's own asserted expectations are read from the printed
results, not from process exit code, since a deliberately-failing compile
does not crash the runner — see methodology note below).

| Check | Result |
|---|---|
| (1) 4 return types (`bool`/`float`/`void`/`Vector2`) + `signal` in one `@abstract` class, compiled directly | `COMPILED OK` |
| (2) Control group: concrete subclass implementing all 4 methods | `COMPILED OK` |
| (3) Concrete subclass implementing only 3 of 4 (omits `diagnostic_seed_position()`) | `FAILED (reload=Parse error)` |

Check (3)'s actual engine error message:

```
SCRIPT ERROR: Parse Error: Class "incomplete_subclass_probe.gd" must implement
"ProbeMouseReclaimPolicy.diagnostic_seed_position()" and other inherited
abstract methods or be marked as "@abstract".
```

**Both halves of AC-S001-c confirmed**: the message names the specific
missing method (`diagnostic_seed_position()`) by qualified name, not a
generic "incomplete class" error — the "must name which one" requirement in
the AC text holds.

### Check (3) source — `incomplete_subclass_probe.gd` (not checked in, see below)

```gdscript
# Probe (3): a concrete subclass that deliberately implements only 3 of the
# 4 @abstract methods (omits diagnostic_seed_position()). Question being
# answered: does this fail at compile time, and does the engine's error
# message name the specific missing method?
extends ProbeMouseReclaimPolicy

func evaluate(_current_mouse_position: Vector2, _surface: int) -> bool:
	return false

func reclaim_progress() -> float:
	return 0.0

func reset(_seed_position: Vector2, _trigger: int) -> void:
	pass
# diagnostic_seed_position() deliberately NOT implemented
```

This file is quoted here rather than committed as a real `.gd` file:
`scripts/` only holds the three files that compile cleanly
(`mouse_reclaim_policy_probe.gd`, `complete_subclass_probe.gd`, `runner.gd`).
`runner.gd`'s own `_report("incomplete_subclass_probe.gd")` call references
this filename by string only — it is inert unless the file above is
recreated alongside it per step 2, so keeping `runner.gd` as-is does not
reintroduce a non-compiling script into this repo.

### Methodology note (carried over from `engine-verification-spike-2026-08-20`)

`runner.gd` uses `ResourceLoader.load(path, "Script", CACHE_MODE_IGNORE)`
followed by `.reload()` and checking the returned `Error`, **not**
`load(path) != null`. That earlier spike found `load()` returns a non-null
*invalid* resource object on parse failure rather than `null`, so a naive
null-check would silently misreport every compile failure in this probe as
success. This probe reuses that already-verified check rather than
re-deriving it.

### One retry needed during this run

The first attempt at running `runner.gd` against a brand-new scratchpad
project failed all three checks with `Could not find base class
"ProbeMouseReclaimPolicy"` — not a real finding, just the same
`global_script_class_cache.cfg`-does-not-exist-yet prerequisite documented in
`.claude/docs/coding-standards.md` for the main repo's own test runner,
reproduced here in a fresh project for the first time outside that context.
Running `--import` once (step 2 above) resolved it; the results in the table
above are from the post-import run.

### Real-type re-verification (2026-09-02, second pass)

**The two checks above (1)–(3) all ran against `ProbeMouseReclaimPolicy` — a
placeholder base class using `int` for what the real contract types as
`CursorTypes.SurfaceType` / `CursorTypes.ResetTrigger`.** Per the (A)/(B)/(C)
source-tier test in `.claude/docs/technical-preferences.md` ("this measurement
— did it run the project's own code, or reimplement a copy?"), a passing
result against a reimplemented stand-in does not establish that the *actual*
`MouseReclaimPolicy` contract in `src/ui/cursor/` behaves the same way. The
first pass's own "Direct confirmation" note below described a same-day smoke
check against the real files, but that check was exploratory and uncommitted
— nothing backed the claim with a reproducible artifact.

This second pass closes that gap by re-running the same two checks directly
against the project's real files, with nothing reimplemented:

1. Copied `src/ui/cursor/cursor_types.gd`, `cursor_target.gd`, and
   `mouse_reclaim_policy.gd` **verbatim** (unmodified) into a fresh throwaway
   Godot 4.7.1 project in the system scratchpad directory.
2. Added `complete_real_subclass.gd` — a concrete subclass of the real
   `MouseReclaimPolicy`, implementing all 4 `@abstract` methods with the real
   `CursorTypes.SurfaceType` / `CursorTypes.ResetTrigger` parameter types
   (control group, expected to compile).
3. Added a second subclass, `incomplete_real_subclass.gd`, implementing only
   3 of the 4 methods (omits `diagnostic_seed_position()`) — same structure
   as check (3) above, but subclassing the real `MouseReclaimPolicy` instead
   of the placeholder. Ran the import step, then the runner, then **deleted
   the deliberately non-compiling file immediately** — per this repo's rule
   that a non-compiling `.gd` file must never be left anywhere under the
   project (this scratchpad project is outside the repo entirely, but the
   same discipline was followed as a matter of habit).

Full output: `logs/real-type-probe-output.log`. Engine: same pinned
`Godot_v4.7.1-stable_win64_console.exe`. Runner exit code: `0`.

| Check | Result |
|---|---|
| Real `mouse_reclaim_policy.gd` compiles standalone | `COMPILED OK` |
| Control group: complete subclass of the real `MouseReclaimPolicy`, real enum param types | `COMPILED OK` |
| Subclass of the real `MouseReclaimPolicy` implementing only 3 of 4 (omits `diagnostic_seed_position()`) | `FAILED (reload=Parse error)` |

Engine error message (real class, not the placeholder):

```
SCRIPT ERROR: Parse Error: Class "incomplete_real_subclass.gd" must implement
"MouseReclaimPolicy.diagnostic_seed_position()" and other inherited abstract
methods or be marked as "@abstract".
```

**Both halves of AC-S001-c now confirmed against the actual production
contract**, not a reimplemented stand-in: the message names the specific
missing method by qualified name (`MouseReclaimPolicy.diagnostic_seed_position()`),
matching the placeholder probe's result exactly except for the class name.

Committed artifacts for this pass: `scripts/real-type-verification/runner.gd`
and `scripts/real-type-verification/complete_real_subclass.gd`. The
deliberately non-compiling `incomplete_real_subclass.gd` is, as with check (3)
above, not checked in anywhere — quoted here for reproducibility instead:

```gdscript
# Deliberately non-compiling: subclass of the REAL MouseReclaimPolicy
# implementing only 3 of its 4 @abstract methods (omits
# diagnostic_seed_position()). This file must never be left in a compiling
# state anywhere under the main repo -- it lives only in this throwaway
# scratchpad project and is deleted immediately after the probe run.
extends MouseReclaimPolicy

func evaluate(_current_mouse_position: Vector2, _surface: CursorTypes.SurfaceType) -> bool:
	return false

func reclaim_progress() -> float:
	return 0.0

func reset(_seed_position: Vector2, _trigger: CursorTypes.ResetTrigger) -> void:
	pass
# diagnostic_seed_position() deliberately NOT implemented
```

To reproduce: same steps as the main "How to Run" section above, except copy
the three real files from `src/ui/cursor/` instead of writing the placeholder
`ProbeMouseReclaimPolicy`, and use `real-type-verification/runner.gd` in place
of the top-level `runner.gd`.

### Direct confirmation on the actual production file shape (first pass, superseded above)

In addition to the isolated int-typed probe above, the three production
files written for Story 001
(`src/ui/cursor/cursor_types.gd`, `cursor_target.gd`,
`mouse_reclaim_policy.gd`) were also smoke-tested in the same scratchpad
project — including a complete inner-class subclass of the real
`MouseReclaimPolicy` (typed `CursorTypes.SurfaceType` / `ResetTrigger`
parameters, not the probe's placeholder `int`). All compiled and behaved as
expected: enum member sets/order, `CursorTarget.equals()`'s three cases, and
the full `MouseReclaimPolicy` contract (all 4 methods + signal) all matched
expectations on the actual production-shaped code, not just the placeholder
probe. This smoke check was exploratory (no committed script) — **the negative
half (missing-method compile failure) was never actually reproduced against
the real class**, only asserted by description. The "Real-type
re-verification" section above supersedes this note with a committed,
reproducible artifact covering both halves. `tests/unit/cursor/shared_types_test.gd`
separately covers the positive half only (see that file's own AC-S001-c scope
note) under GdUnit4 as part of this repo's test suite.
