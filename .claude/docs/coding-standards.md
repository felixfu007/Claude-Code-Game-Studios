# Coding Standards

- All game code must include doc comments on public APIs
- Write an architecture decision record in `docs/architecture/` **only for cross-system contracts**.
  A single system's internal technical detail belongs in that system's design document.
  > 🔴 **Changed 2026-09-01 (manager ruling).** This line previously read *"Every system must have a
  > corresponding architecture decision record"* — which **directly contradicted** the process-dosage
  > rule of 2026-08-25 (`production/milestones/one-year-plan.md` §6②, summarised in
  > `technical-preferences.md`), and **both files are auto-loaded every session**. Whoever read this
  > one first would write six more ADRs; the dosage rule expects **0–1** more for the remaining six
  > systems. The dosage ruling is the newer decision and wins.
  > `docs/WORKFLOW-GUIDE.md`'s "minimum 3 Foundation ADRs" gate wording is the third copy of this
  > rule and is **still unreconciled** — registered in `docs/reviews/doc-audit-2026-09-01.md`.
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.
- 🔴 **Never use `assert()` to guard an "unreachable" branch in a function that returns an enum.**
  Measured 2026-09-15 by the coordinator (own probe, engine-executed, Godot 4.7.1 headless):
  when an `assert()` fails it aborts the calling function, and the function yields
  **ordinal 0 of its declared return type**. For the near-universal convention where the
  success value is listed first (`enum R { NONE = 0, ... }`), that means
  **a failed assertion silently returns "success"** — the exact opposite of what the
  assertion was written to prevent. Use `push_error()` followed by an explicit `return`
  of a deliberately non-success value instead.

  Reproduce (self-contained — no need to trust this entry; save and run it):

  ```gdscript
  extends SceneTree
  enum R { NONE = 0, BAD_A = 1, BAD_B = 2 }
  func _fails_assert() -> R:
      assert(false, "deliberate probe failure")
      return R.BAD_B
  func _init() -> void:
      print("returned = ", _fails_assert(), "  is NONE? ", _fails_assert() == R.NONE)
      quit()
  ```
  ```
  godot --headless --path . -s <that file>
  ```
  Measured output: `returned = 0  is NONE? true`, alongside
  `SCRIPT ERROR: Assertion failed: deliberate probe failure`.

  ⚠️ **The error message is printed, so this is loud in a terminal and silent in a return
  value.** A caller that only inspects the returned rejection code sees `NONE` and proceeds
  as if the write succeeded. This was found during Story S-008 (affinity write-port adapter)
  by the implementer, who had been about to use `assert()` for exactly this purpose and
  probed it first; the coordinator then re-verified it independently rather than taking the
  report at face value.

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

## Screenshot Evidence Rules

A screenshot must prove it is **the thing it claims to be** — not merely that it is not
blank. These rules exist because on 2026-08-31 a Godot **boot splash screen** was written
into `production/qa/evidence/` as evidence of the exported build. It was caught, but not
by any rule that existed at the time.

🔴 **"Count the distinct colours to prove it is not blank" does not work.** Measured on the
two images that day:

| | Real gameplay frame | Godot boot splash |
|---|---|---|
| Dimensions | 960×540 ✅ correct | 960×540 ✅ correct |
| Distinct colours | 247 | **493** |

The splash has **more** colours than the real frame, because a logo's antialiased gradients
produce more distinct values than a pixel-art scene's large flat fills. **"More colours reads
as more real" points the wrong way.** The colour count only rules out a uniformly blank
frame, which is the narrow case it was written for.

### Screenshot classification — decide the category before applying any check

**2026-09-17 addition.** The five checks below were written against one shape of screenshot
(a full-window gameplay frame) and were then applied unmodified to two other shapes in the
same batch of work, on the same day, by two different implementers, from two different
directions:

| | Screen | Check it hit | Measured |
|---|---|---|---|
| U-007 | **Forced-response overlay/mask** (translucent scrim covers the entire window, small panel centred inside it) | Check 3, dominant colour share ≤ 80% | **91.6% / 92.7%** at 1920×1080 / 2560×1440 — `prototypes/u007-battle-menu-evidence-capture-2026-09-17/README.md`, `production/qa/evidence/battle-menu-layout-evidence.md` |
| U-011 | **Thin-line UI crop** (hand-bar strip, cropped from a full-window capture) | Check 2, 12-point sampling ≥ 3 colours | first attempt (wide-margin crop) measured **4 / 1** distinct colours, dominant share **53.26%–63.32% / 99.19%–99.60%** — `prototypes/story-u011-hand-bar-evidence-2026-09-17/README.md` and its `run_output.txt` |

🔴 **The most informative thing that happened is not the two failures above — it is what the
U-011 implementer reached for next.** Facing Check 2's failure, the first instinct was to
switch the metric to **whole-image distinct-colour count**. That is the exact metric the table
at the top of this section already names as pointing **backwards** (boot splash 493 colours >
real frame 247 colours) — a reviewer caught it before it shipped (see
`production/qa/evidence/story-u011-hand-bar-evidence.md`, section "第二次嘗試(已捨棄)").
**When a check does not fit the screen in front of you, the replacement invented on the spot
is not automatically safer than the check it's replacing — on this project, it has already
turned out to be the exact thing this section was written to ban.**

**Conclusion for this rule set: no category gets a "use your judgement" escape hatch.** Every
screenshot is classified into exactly one of three categories below, by an objective test that
does not depend on the capturer's self-description, and each category has its own fixed,
fully-specified checks.

#### Classification test (apply in this order — first match wins)

1. **Category C — cropped / partial capture.** Test: **the image's dimensions do not equal
   the full target window size** for the resolution under test. (This reuses Check 1's
   dimension measurement — classification and Check 1 read the same number.)
2. **Category B — full-window overlay/mask screen.** Test: dimensions **do** match the full
   window, **and** the screen's own real layout function — the one production code actually
   calls (e.g. `panel_rect()`), not a re-derivation of it — reports a content rect whose area
   is **less than 50% of the full window's area** at that resolution, with the remaining area
   an intentional single-colour scrim/mask. (Threshold chosen to unambiguously separate cases
   like U-007's ~8.9% panel coverage from an ordinary partial-window widget; changing it is a
   fresh decision, not a silent adjustment.)
   🔴 **A claim of "this is a modal" with no named rect-function call behind it does not
   qualify.** It stays Category A and inherits Category A's checks — which it will then
   correctly fail. The escape hatch is the rect call, not the assertion.
3. **Category A — full gameplay/world frame.** Everything not caught by 1 or 2 — the shape the
   original five checks were written for. They apply to it unchanged.

### Category A checks — full gameplay/world frame (the original five checks; one disclosure clause added to Check 4 on 2026-09-17 for symmetry with B/C, see below)

1. **Dimensions** match the expected window size exactly.
2. **Multi-point sampling** — sample at least 12 spread coordinates; require **≥ 3 distinct
   colours** among them. (Splash: all 12 identical. Real frame: 7 distinct.)
3. **Dominant colour share ≤ 80%** of all pixels. (Splash: 94.62%. Real frame: 43.06%.)
4. **Pixel-art integer-scale grid integrity** — each source pixel must map to a clean
   N×N block of identical colour, proving no resampling occurred.
   ⚠️ **Measure the world layer only.** Whole-image measurement is *inverted* here and will
   judge backwards: the project deliberately renders body text in a normal Chinese font
   rather than a pixel font (`design/art/art-direction.md`), and that antialiased text
   produces more grid violations in a real frame (3.157%) than the splash logo does (1.748%).
   Restricted to the board region the signal is clean: real frame 0 of 66300 blocks,
   splash 2265. **If the screen has no world layer at all, say so explicitly; do not silently
   omit the check without a stated reason** — this is the same disclosure obligation Category
   B and C's Check 4 state below; Category A never needed it in practice (a full gameplay/world
   frame has a world layer by definition), but the obligation itself applies uniformly to every
   category, not just the two where it currently matters. Stating it only under B/C invited the
   wrong inference — that A is exempt from disclosure rather than merely exempt, so far, from
   ever triggering it.
5. 🔴 **A human opens the image and confirms it shows what it claims.** The checks above are
   a filter, not a substitute. Every visual defect found on this project so far was found by
   a person opening the file; the automated suite has never caught one.

### Category B checks — full-window overlay/mask screens

**Why Check 3 as written points backwards here**: a modal's entire design intent is "one
translucent colour covers most of the frame, plus a small panel." A dominant-share ceiling
built to catch "this frame is suspiciously blank" will **always** fire on a correctly-rendered
modal — U-007 measured 91.6%/92.7%, both confirmed complete and correct by human review
(`production/qa/evidence/battle-menu-layout-evidence.md`). Applying Check 3 unmodified here
does not detect a defect; it detects the design.

1. **Dimensions** — unchanged, still required.
2. **Sampling** — run the original blind grid **and keep its result on the record even if it
   comes back with only 1 distinct colour** (expected, not a failure to hide — see U-007's own
   disclosure of this exact result). **Add** sample points derived from the screen's real
   content-rect function (the same one used for classification above); require **≥ 3 distinct
   colours across the combined blind + targeted set**.
3. **Dominant colour share ≤ 80% does not apply.** Replace it with an **edge/corner mask
   coverage check**: sample the 4 corners and 4 edge midpoints of the full window and confirm
   every one matches the intended overlay colour, with no gap. This targets the actual defect
   this screen shape can have — an incompletely-covered scrim leaving a bright, un-masked strip
   at the window edge (the risk `design/art/screen-architecture.md` names for non-16:9
   windows) — instead of testing for a property (low dominant-colour share) the design
   deliberately does not have.
4. **Integer-scale grid** — same carve-out as Category A: world layer only. If the screen has
   no world layer at all, say so explicitly; do not silently omit the check without a stated
   reason.
5. 🔴 **Human review — mandatory, unchanged.** See "why Check 5 survives every category" below.

### Category C checks — cropped / partial UI captures

**Why Check 2 as written points backwards here**: a blind 12-point grid assumes content is
spread across the frame. A crop of a thin-line UI element (borders, a count label) is mostly
empty space between lines at typical UI scale — U-011's first attempt measured 1 distinct
colour among 12 blind points on a correctly-rendered crop
(`prototypes/story-u011-hand-bar-evidence-2026-09-17/run_output.txt`). The grid tests "is
content spread out," and a thin-line crop's honest answer is "no," independent of whether it
is correct.

1. **Dimensions** — must equal the crop rect as computed by the real layout function used to
   produce it (name the function, e.g. `slot_bar_rect()` / `slot_rect()`), not the full window.
2. **Blind sampling is replaced by directional/oriented sampling.** Coordinates must be
   derived by calling the same real layout function that produced the crop — placed at
   "should have a drawn edge here" positions and at "known interior, no edge" positions —
   never at random or evenly-spaced coordinates chosen independently of that function.
   🔴 **Explicitly banned substitute: whole-image distinct-colour count.** This was tried on
   this project and withdrawn before shipping
   (`production/qa/evidence/story-u011-hand-bar-evidence.md`, section "第二次嘗試(已捨棄)")
   for the same reason the table at the top of this section exists: colour count points
   backwards (more antialiasing → more colours → a boot splash beats a real frame). **A check
   that fails on a real screen does not get replaced by a metric this document has already
   named as unreliable, regardless of who proposes it or how reasonable it looks at the time.**
3. **Dominant colour share ≤ 80% does not universally apply** — an isolated widget crop on an
   otherwise-blank test backdrop is mostly one colour by design (U-011's isolated-widget crop
   measured 99.6% and was correct). Use whichever of the following fits the evidence being
   produced:
   - **(a) Structural-difference check**, when two crops are being compared against each other
     (e.g. two states of the same component): per-pixel luminance difference, requiring the
     **standard deviation** of that difference to clear a threshold — this proves the
     difference is not just a uniform brightness/contrast shift across the whole crop.
   - **(b) Positive-presence check**, when there is no second crop to diff against: a named
     region must be measurably brighter or darker than a named reference background point.
4. **Integer-scale grid** — same carve-out as Category A/B: world layer only. Most UI crops
   have no world-layer content at all (this project renders UI text in an antialiased Chinese
   font, not a pixel font); state that explicitly rather than silently skipping the check.
5. 🔴 **Human review — mandatory, and carries more weight here than in the other two
   categories**, because checks 2 and 3 are, by construction, the most structurally weakened
   of the three categories here — see below.

### Why Check 5 is not replaced by anything above, in any category

Check 5 was never "the automated checks, plus a human as a backstop for cases automation can't
reach" — the original rule states it as **the only check that has ever actually caught a
defect on this project**: "Every visual defect found on this project so far was found by a
person opening the file; the automated suite has never caught one." Categories B and C exist
*because* the mechanical checks calibrated for Category A misfire by construction on those
shapes — which means, for exactly those two categories, automation's share of the detection
burden is smaller than it is for Category A, not larger. **The category with the weakest
mechanical coverage is never allowed to also have the weakest human coverage.**

⚠️ **This classification framework has no automated check of its own**, consistent with the
rest of this section — it buys "a screenshot's category and the reasoning behind it are
written down and checkable by a second reader," not "no one will misclassify a screenshot."

### Rules for capture tooling

- **Validate before writing.** Capture, check, retry while the check fails, and on exhaustion
  **error out and write nothing**. A tool that can emit false evidence is worse than no tool,
  because false evidence is trusted.
- **Never capture the full screen**, even intending to crop afterwards — the developer's
  desktop contains private content. Crop in memory or capture the window directly.
- **Window existence ≠ content drawn.** Waiting for a visible window is not waiting for the
  game; the boot splash satisfies that condition. This is a race, not a rare event: the same
  script captured gameplay and the splash nine minutes apart.
- Current tool: `tools/build/capture_window.ps1` (Godot exported builds on Windows). Its
  header records four traps in detail; read it before writing another capture tool.

## Automated Test Rules

- **Naming**: `[system]_[feature]_test.[ext]` for files; `test_[scenario]_[expected]` for functions
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use in-test constants, factory functions, or — **only via
  the two registered exceptions named in the next bullet** — read-only version-controlled data
  files. Never inline magic numbers. **Do not invent a third kind of file access to satisfy this
  bullet.** (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or **write to any filesystem
  location** — use dependency injection. **Two narrow, registered read-only exceptions exist**;
  their exact scope and two attached obligations (declare the exception in the test file's header;
  disclose that it does not prove exhaustiveness) are in `.claude/rules/test-standards.md` —
  **this line deliberately does not restate them**:
  1. reading real, version-controlled fixture data under `assets/data/` — **this is what the
     "constant files" wording in the bullet above actually means in practice**
  2. reading `src/**/*.gd` / `tests/**/*.gd` source text to assert a static code-discipline rule

  **All other file I/O remains prohibited.**
  > ✅ **2026-09-17 管理者裁決:上面兩行已改寫,矛盾解除。**
  > **原文的形狀**:上一條要求「Test fixtures use constant files」,下一條禁止「file I/O」——
  > **照上一條做就必然違反下一條**,而兩條相隔兩行、同在這份每次開場載入的文件裡。
  > 2026-09-16 管理者已裁決那 10 支違反者為明文例外,**但裁決的是「准不准」,不是「這兩行怎麼重寫」**,
  > 於是矛盾又原封不動留了一天,直到 2026-09-17 才補上這次改寫。
  > 🔴 **改寫刻意不重新推翻 9/16 那次裁決** —— 它只是把第一條的「constant files」明確指向
  > 該次核准的例外範圍,讓兩條停止互相否定。**例外的範圍一個字都沒有變動。**
  > ⚠️ **仍然沒有任何自動檢查會攔第三種檔案存取。** 上面那句「Do not invent a third kind」
  > 是紀律要求,不是閘門 —— 與本專案其餘同類規則一樣,**遵守與否目前不可觀測**。

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- 🔴 **Anything whose engine-side write is a no-op headless.** Verified 2026-09-07 (Story 011):
  `Input.mouse_mode = MOUSE_MODE_HIDDEN` **does nothing** under `--headless` — the value reads
  back `0` (VISIBLE) forever, whatever the code did. **The failure directions are asymmetric and
  the dangerous one is silent**: a test asserting HIDDEN (`1`) always fails (loud), while a test
  asserting VISIBLE (`0`) **always passes regardless of the production code**. ADR-0005's own
  Validation Criteria #17 asks for `Input.mouse_mode` assertions, and AC-60's exception case
  asserts VISIBLE — taken literally headless, that pair yields one permanently-red and one
  permanently-green test, **neither touching the code**.
  **Split the target**: assert the component's *decision* headless (a `diagnostic_*` read-only
  getter), and assert the engine *applied* it in a windowed run. Both, not either.
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
    - 🔴 **`godot` is not on PATH in the local Git Bash shell, and the failure is silent.**
      The command above works in CI because the action supplies the engine. Locally it does
      not resolve, and if the invocation is piped into `grep`/`sed` the `command not found`
      message is consumed — leaving an **empty result in about one second**, which is
      indistinguishable from a clean pass. Verified 2026-08-31; only the implausibly short
      runtime gave it away. **An empty result is not a passing result — check the exit code
      of the engine itself, not of the pipeline.**
      Local invocation needs the full path to the engine binary (machine-specific — the
      value below is this development machine's, not a project constant):
      `"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . ...`
    - ⚠️ **A failing test aborts the remaining tests in its own suite.** Verified 2026-08-31:
      a suite of 5 reported `4 test cases` when the 4th failed — the 5th never ran.
      **"1 failure" never means "one thing is broken".** Re-run after fixing.
      🔴 **Second consequence, found 2026-09-04 (Story 010): this caps what an injected
      fault can prove.** Break the production code on purpose to check a test really goes
      red, and the suite stops at the *first* test that catches it — every assertion after
      that point is never executed and is therefore **unproven, not proven**. On Story 010
      the implementer's injection run reported `2 test cases` in an 11-test file; the four
      tests actually carrying the acceptance criterion were tests 3–6 and none of them ran.
      "The injection made it go red" was literally true and materially misleading.
      **Proving a test file is sensitive costs one run per assertion you want to prove** —
      reach the later ones by temporarily renaming the earlier `test_` functions out of
      collection, then revert. Budget for that before promising a sensitivity proof.
    - 🔴 **`-a <file>:<test_name>` is NOT valid filter syntax, and getting it wrong exits 0.**
      Verified 2026-09-04 while trying to run a single test case: GdUnit4 prints
      `Given directory or file does not exists: ...` followed by
      `No test cases found, abort test run!` and then reports **`Exit code: 0`**.
      **A typo'd filter therefore means zero tests executed and CI reporting success** —
      the same shape as the argument-ordering trap above, from a different direction.
      CI does not currently use filtering, so this is latent rather than live; it becomes
      live the moment anyone adds a filter to the test line. If filtering is ever needed,
      **assert on the executed-test count, not on the exit code alone.**
    - Direct invocation, if the runner is ever bypassed:
      `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/unit -a tests/integration`
      🔴 **`-a tests/unit` 單獨一項是不夠的,而且不夠的方式不會報錯。** 2026-09-04
      (Story 009,本專案第一張把測試放進 `tests/integration/` 的工作單)實測:
      runner 當時寫死只掃 `tests/unit`,新增 5 條整合測試後回報
      **386 條、1 個既有失敗、exit 100 —— 與新增之前逐字相同**,那 5 條的名字
      一次都沒出現在輸出裡。**測試存在、看起來全綠、實際一條都沒跑。**
      ⚠️ **CI 從來沒有這個問題**(`tests.yml` 的 `paths:` 本就同時列了兩者),
      所以壞掉的是**本機比 CI 寬鬆**這個方向 —— 而本機是大多數人唯一會跑的地方。
      `-a` 可重複給:GdUnit4 的 `add_test_suites()` 是 `append_array()` 不是覆寫。
      📌 **日後新增任何測試層級(例:`tests/smoke/`)必須同時加進 `tests/gdunit4_runner.gd`
      的 `FORCED_ARGS`**,否則會重演同一件事。
      `--ignoreHeadlessMode` is mandatory (without it: `Headless mode is not supported!`,
      exit 103) because the engine delivers no `InputEvent`s headless, so UI-interaction tests
      would silently do nothing.
    - 🔴 **`Overall Summary`'s `failures` counts FAILED ASSERTIONS, not failed test cases.**
      Verified 2026-09-07 (Story 011): a single test looping 10 frames with one assertion per
      iteration reported **`11 failures`** in the summary while naming only **2** tests as
      `FAILED` (the looping one plus the pre-existing red). Fixing that one test dropped the
      count from 11 to 1. **"11 failures" did not mean eleven things were broken, and the
      arithmetic gap is the only hint** — so never size the damage from the summary number.
      **Grep the log for ` FAILED` and count the named tests instead.** This is the fifth
      distinct way this test line misleads (argument ordering, silent PATH miss, filter-typo
      exit 0, exit 101, and this).
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
