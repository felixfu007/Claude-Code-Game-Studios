# Test Evidence — Story 010: 專屬游標 `CanvasLayer` + 圖層變換恆等防護測試

**Story**: `production/epics/cursor-highlight-state/story-010-idle-indicator-host.md`
**Story Type**: UI (per that file's Test Evidence section) — gate level ADVISORY
**Governing ADR**: ADR-0005, 機制十二, Validation Criteria #20
**Date**: 2026-09-04
**Evidence form**: automated GdUnit4 suite (not a manual screenshot walkthrough —
this story renders nothing yet; see "Out of Scope" in the story file). The
automated suite is the stronger form of evidence available for a structural/
transform claim, and satisfies the ADR's own requirement that Validation
Criteria #20 "必須寫成一條會執行的自動化測試,不得只靠紀律".

---

## What was built

`src/ui/cursor/cursor_state_host.gd` now builds a dedicated `CanvasLayer`
(`_cursor_layer`, node name `"CursorLayer"`, `layer = 100`) as a child of the
`CursorStateHost` Autoload in `_ready()`. No content is added to it — per the
story's own scope, the self-drawn cursor and hover detector are Story 011.

## What was tested

New file: `tests/unit/cursor/cursor_layer_transform_test.gd`, 11 test cases.

| # | Test | Purpose |
|---|---|---|
| 1 | `test_environment_sanity_root_transform_is_non_identity_when_resized` | Proves resizing `get_tree().root.size` inside a GdUnit4 test runtime actually engages content-scale — not just in the throwaway probe script. Without this, the identity tests below could be vacuously true. |
| 2 | `test_layer_parented_under_host_matches_layer_parented_directly_under_root` | Coordinator's explicit ask: verify empirically (not by reasoning) whether parenting the layer under the Autoload `Node` vs. directly under `/root` changes `get_final_transform()`. |
| 3–6 | `test_ac_s010a_cursor_layer_transform_is_identity_at_{1080p,2k,4k,ultrawide}` | AC-S010-a — the real `_cursor_layer`'s transform is `Transform2D.IDENTITY` at all four resolutions the story's AC text names. |
| 7 | `test_sensitivity_canary_scaled_shared_layer_is_not_identity` | Mandatory sensitivity check — a throwaway `CanvasLayer` built with the real failure shape (scale 2.667, matching a layer merged into a scaled UI layer) must measure as NOT identity. |
| 8 | `test_sensitivity_canary_offset_only_layer_is_not_identity` | Second failure shape (pure offset, no scale) — proves the same identity comparison catches this shape too, without a separate assertion technique. |
| 9–11 | `test_ac_s010b_*` | AC-S010-b (narrowed, see below) — the layer is a distinct node parented directly under `CursorStateHost`, has zero children today, and its `layer` (draw order) is a different value from the host's `process_priority` (update order), per Implementation Notes #3. |

## Results

**Isolated suite run** (`prototypes/story-010-implementation-2026-09-04/logs/sensitivity_injection_reverted_green_output.txt`):
11 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | exit 0

**Full project suite** (`prototypes/story-010-implementation-2026-09-04/logs/full_suite_final_run.txt`):
356 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans | 27 suites | exit 100
— delta from the pre-existing baseline (345/0/1/0/0/0/26/exit100) is exactly
+11 test cases and +1 suite; the 1 failure is the pre-existing, already-approved
red `affinity_phi_provider` test, unrelated to this story.

## Sensitivity proof (the assertion was actually made to go red)

To prove the identity assertion is not a false green, the real failure shape was
injected directly into production code — not just into the canary tests — and
the suite was run against it.

### Round 1 (implementer) — proved ONE of the eleven tests catches it

1. Temporarily added `_cursor_layer.scale = Vector2(2.6666667, 2.6666667)` to
   `cursor_state_host.gd`'s `_ready()`.
2. Ran `tests/unit/cursor/cursor_layer_transform_test.gd`. Result:
   `test_layer_parented_under_host_matches_layer_parented_directly_under_root`
   **FAILED**, reporting `real=(x=(2.666667, 0.0) y=(0.0, 2.666667) o=(0.0, 0.0))`
   — the injected scale was correctly detected. Full output:
   `prototypes/story-010-implementation-2026-09-04/logs/sensitivity_injection_red_output.txt`.
3. Reverted the injection; re-ran; green again. Full output:
   `.../logs/sensitivity_injection_reverted_green_output.txt`.

🔴 **That run observed 2 of this file's 11 tests, not 11.** Its own log says
`2 test cases`. The cause is a behaviour this project has already documented in
`.claude/docs/coding-standards.md`: **a failing test aborts the remaining tests
in its own suite.** Test 1 passed, test 2 failed, tests 3–11 never executed.

⚠️ **The four tests that actually carry AC-S010-a are tests 3–6 — none of them
ran under injection in round 1.** "The injection made the suite go red" is
literally true and materially misleading: it invites the reader to conclude the
AC-bearing assertions were proven sensitive, when what was proven is that one
supporting test was.

### Round 2 (coordinator review, 2026-09-04) — each of the four measured individually

**逐字量測 log**: `prototypes/story-010-implementation-2026-09-04/logs/coordinator_round2_per_test_injection.txt`

Re-injected the same break, then progressively renamed the preceding test
functions out of GdUnit4's collection (`test_` prefix removed) so execution
could reach each AC test in turn. Every one was **observed** red, not inferred:

| Test | Under injection |
|---|---|
| `test_ac_s010a_..._at_1080p` | **FAILED** |
| `test_ac_s010a_..._at_2k` | **FAILED** |
| `test_ac_s010a_..._at_4k` | **FAILED** |
| `test_ac_s010a_..._at_ultrawide` | **FAILED** |

All temporary edits (the production injection and the four renames) were then
reverted, verified by `grep` returning nothing and `git diff` on the production
file showing only the intended Story 010 additions, and the full project suite
was re-run clean: **356 tests / 0 errors / 1 failures / 0 orphans / 27 suites**
(the one failure is the pre-existing approved-red `affinity_phi_provider` test).

📌 **Why this round was necessary, recorded for the next person**: the
suite-abort behaviour means an injection run can only ever prove the sensitivity
of tests up to and including the first one that fails. **Proving a test file is
sensitive requires one run per assertion you want to prove**, or a run ordering
that reaches it. A single red run is not evidence that every test in the file
would have caught the fault.

**A real bug was found and fixed during this exercise**: the first red run also
surfaced a GDScript string-formatting error (`+` binds looser than `%`, so
`"a" + "b" % [x]` applies `%` to `"b"` alone) in `_get_cursor_layer()`'s failure
message. It did not cause a false pass (Godot logs the malformed-format error
and continues), but it would have produced a garbled, useless failure message
had that assertion ever actually failed for a real reason. Fixed by grouping
the concatenation in parentheses before applying `%`.

## AC coverage

- **AC-S010-a (transform identity)**: fully covered. Tests 3–6 above assert
  identity on the real `_cursor_layer` at all four named resolutions
  (1080p/2K/4K/ultrawide — one more than ADR-0005 Validation Criteria #20's own
  three, per the story's own AC text). Test 2 additionally answers the
  coordinator's specific question about Autoload-vs-root parenting: **no
  difference found** — both measured transforms were identical at 2K.
- **AC-S010-b (exclusivity)**: partially covered, narrowed by design (see the
  test file's class doc comment and `state_host_test.gd`'s established
  narrowing convention for this system). What IS verified: the layer is a
  distinct node, parented directly under `CursorStateHost` (not shared with or
  reachable through any other node), currently has zero children, and its
  draw-order value is independent of the host's process-priority value. What
  is NOT verified: the full behavioral claim ("only cursor-system content,
  ever") cannot be exercised until Story 011 adds real children — there is
  nothing to test it against yet.

## Two judgment calls raised, and the manager's rulings on them (2026-09-04)

Both were flagged by the implementer rather than silently decided, and both were
put to the manager during coordinator review the same day. **The rulings are
recorded in `production/session-state/active.md`'s 2026-09-04 batch** — this
section is a pointer, not a second authority.

### 1. Headless test instead of the windowed integration test the ADR describes

ADR-0005 Validation Criteria #20's narrative suggests 「有視窗的整合測試」. This
suite instead runs headless and reassigns `get_tree().root.size` directly.

✅ **Ruled: accept the headless test.** Reasoning given to the manager: a headless
test runs automatically on every push, a windowed one has to be run by hand and
therefore decays into nobody running it; and this story's own probe
(`prototypes/story-010-headless-resolution-probe-2026-09-04/`) measured the
headless numbers to be identical to the 2026-09-01 non-headless, real-GPU spike.

🔴 **The ruling came with an obligation, not a dismissal**: the thing headless
cannot catch is "only visible once something is actually drawn". **Story 010
draws nothing, so nothing is lost here — Story 011 is where drawing starts, and
a real windowed look-at-the-screen check is now a requirement of that story.**
That obligation has been written into
`production/epics/cursor-highlight-state/story-011-native-cursor-suppression.md`;
it is deliberately not left as a note in this closed story's evidence file,
because this project has a documented failure mode of obligations recorded only
in already-closed artifacts and therefore never executed.

### 2. `CURSOR_LAYER_DRAW_ORDER = 100`

ADR-0005 says 「高 layer 值」 but pins no number. The implementer chose 100 (the
project's only other `CanvasLayer`, `GameRoot.tscn`'s `UILayer`, sits at the
engine default `1`) and documented it in the class doc comment as its own
engineering judgment call rather than a cited requirement.

✅ **Ruled: leave it as is; do not promote it into ADR-0005.** The in-code
annotation already lets a later reader tell "this was chosen" from "this was
mandated", which is the property that matters. Amending an Accepted ADR was
judged not worth it — that file has been revised six times this year and the
project's process-dosage rule caps revisions at two.

## Known limitations (honestly registered)

- **This entire suite runs headless.** What that cannot catch is any fault only
  visible once something is actually drawn. Not a gap for this story (it draws
  nothing); it becomes one at Story 011 — see the ruling section above and that
  story's own requirement. ⚠️ **Do not restate the ruling here** — the previous
  wording of this bullet said the question was "flagged as an open question for
  the architecture owner", and within one edit it was contradicting the ruling
  section three paragraphs above it. Same fact, two hand-copies, one updated:
  the exact failure mode `docs/consistency-failures.md` calls 模式 C.
- **AC-S010-b is narrowed**, and stays narrowed until Story 011 supplies real
  children to test against — see the AC coverage section above for what is and
  is not verified.
- **The sensitivity proof cost one engine run per assertion proven.** If this
  file grows more AC-bearing tests, proving them sensitive is not free and is
  not covered by re-running the suite once. See the sensitivity section above.

---

## 🔴 後續變更通知(2026-09-04 同日稍晚,screen-scaling Story 001)

**本文件上方的內容是 Story 010 結案當下的紀錄,未經竄改。以下是同日稍晚發生、會改變上方結論解讀方式的事。**

`screen-scaling` Story 001 把 `project.godot` 的 `window/stretch/mode` 由 `"canvas_items"`
切換為 `"disabled"`(2026-09-01 管理者裁決的執行)。連帶:

1. **本文件引用的 `test_environment_sanity_root_transform_is_non_identity_when_resized`
   已改名並改寫為** `test_environment_reality_check_root_transform_is_identity_under_disabled_stretch_mode`。
   它現在斷言相反的事:根視窗變換**恆等**,因為引擎不再做任何縮放。
   **本文件上方保留舊名,因為那是當時的事實** —— 但查現行程式碼時要用新名。

2. 🔴 **上方「AC-S010-a 完整涵蓋」這個判定仍然成立,但它證明的東西變弱了。**
   當時的論證是「環境可證明為非恆等,所以圖層逃出它才有意義」。
   `disabled` 下**任何一顆沒被動過的 `CanvasLayer` 都會回報恆等**,不需要任何隔離努力 ——
   **那四條斷言目前不再構成「隔離紀律有在發揮作用」的證據。**

   ✅ **四條測試保留而非刪除**,理由引用 ADR-0005 Validation Criteria #20 已寫下的推理
   (①畫面設定還會再改 ②Story 002 的 HUD 縮放可能重新引入共用節點風險,屆時**不改一行**
   就恢復鑑別力)。**兩條靈敏度測試不受影響** —— 它們自建合成的縮放/位移圖層,不依賴真實環境。

📌 **本節刻意寫成「後續通知」而非就地修改上方文字** —— 上方是已結案工作的證據紀錄,
改它等於竄改當時的事實。**要現行狀態請看 `production/epics/screen-scaling/story-001-manual-world-scaling.md` 的結案紀錄。**
