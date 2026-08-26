# Coding Standards

- All game code must include doc comments on public APIs
- Every system must have a corresponding architecture decision record in `docs/architecture/`
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.

# Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- Documents must include these 8 required sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

# Testing Standards

## Test Evidence by Story Type

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY |
| **UI** (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `production/qa/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

## Automated Test Rules

- **Naming**: `[system]_[feature]_test.[ext]` for files; `test_[scenario]_[expected]` for functions
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use constant files or factory functions, not inline magic numbers
  (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or file I/O — use dependency injection

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- Full gameplay sessions (covered by playtesting, not automation)

## CI/CD Rules

- Automated test suite runs on every push to main and every PR
- No merge if tests fail — tests are a blocking gate in CI
- Never disable or skip failing tests to make CI pass — fix the underlying issue
- Engine-specific CI commands:
  - **Godot**: `godot --headless --path . -s tests/gdunit4_runner.gd`
    - The runner wraps GdUnit4's own CLI entry point and supplies the mandatory flags, so CI
      does not have to remember them. Verified 2026-08-26: 9 tests, 0 failures, 0 orphans,
      exit 0, against GdUnit4 v6.2.1 / Godot 4.7.1.
    - 🔴 **The failure mode to watch for is a false green light.** GdUnit4 discards every
      argument before the token containing `GdUnitCmdTool.gd`; omit that token and it silently
      degrades to printing help text and exiting **0** — tests never ran, and CI reports pass.
      This was hit live while rewriting the runner. A test line that cannot fail is worse than
      one that fails.
    - Direct invocation, if the runner is ever bypassed:
      `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/unit`
      `--ignoreHeadlessMode` is mandatory (without it: `Headless mode is not supported!`,
      exit 103) because the engine delivers no `InputEvent`s headless, so UI-interaction tests
      would silently do nothing.
    - ⚠️ **Exit code 101 means PASSED WITH WARNINGS, not failure.** Read from GdUnit4 source:
      `errors + failures > 0` → 100; `orphan_count > 0` → **101**; otherwise → 0. A run that
      reports `0 failures` can still exit 101 purely because a test leaked nodes.
      **The fix is to stop leaking nodes — never to treat 101 as success, and never to stop
      checking the exit code.** That check is the only place the whole test line is enforced.
    - History, because "never executed" is how it survived: this row's original command used
      `--script` against a runner that called a `run_tests()` method GdUnit4 does not have.
      It was written before GdUnit4 had ever been installed, so it could never have worked,
      and nothing revealed that until the suite was first actually run on 2026-08-26. The
      runner has since been rewritten against the real entry point.
    - 🔴 **A fresh checkout must run `godot --headless --path . --import` once before the runner.**
      Verified 2026-08-26, the day the first `class_name`-declaring scripts entered the repo
      (`Board`, `LineOfSight`): without it the runner fails with
      `Parse Error: Identifier "Board" not declared in the current scope`, because
      `.godot/global_script_class_cache.cfg` does not exist yet. Two specialists hit this
      independently, and it was reproduced on a throwaway clone in the scratchpad: no import →
      fails/hangs; import first → 25 tests, 0 failures, exit 0. The import is idempotent and
      one-time per working copy; it is a prerequisite, not a change to the test command.
      ✅ **Verified 2026-08-26: the action performs the import itself.** CI checks the repo out
      from scratch every run, so had it not, the `class_name`-declaring scripts could not have
      parsed — instead the first real green run (`380472b`) reported `51 passed, 0 failed and
      0 skipped`. The import prerequisite above therefore binds local working copies only, not
      CI. The action reference moved to `godot-gdunit-labs/gdUnit4-action@v1` in the same
      commit, matching the addon's own move; the old `MikeSchulze` path 301s to it.
      🔴 **Getting to that first green meant reading the log, not the tests.** Every run from
      the day GdUnit4 was installed was red — never on a test, always inside the action's own
      `dorny/test-reporter` step, which needs `checks: write` to create a check run and was
      handed a read-only token. The suite was running and reporting into the void, and the
      workflow's own comment pointed the next reader at the wrong suspect (4.7.1 support).
      **A red CI is unread until its actual failing step is named. The failing step is not
      always the tests.**
  - **Unity**: `game-ci/unity-test-runner@v4` (GitHub Actions)
  - **Unreal**: headless runner with `-nullrhi` flag
