---
name: project-cursor-highlight-state-review
description: 《盲目於微光》cursor-highlight-state.md reached Approved at round 16 (2026-08-13); the two mouse-reclaim defects were deliberately downgraded from blocking to advisory by user decision, not fixed — D-pad/analog remain fully untested. Read this before trusting any older summary of this doc as still-blocked.
metadata:
  type: project
---

**STATUS CORRECTION (2026-08-31)**: `design/gdd/cursor-highlight-state.md` is **Approved** per `systems-index.md`
(round 16, 2026-08-13, user-decided convergence). An earlier version of this memory described it as
still gated at round 12 with a hard "cannot mark Approved" gate tied to two confirmed defects — that
gate was **explicitly lifted by user decision at round 12 itself** (2026-08-11), not by fixing the
defects. Reasoning on record in the doc's "Known Confirmed Defects" section: this is turn-based
tactics, not real-time action, so the mouse-reclaim handoff glitch's feel-impact is judged low-stakes
enough to downgrade to an advisory backlog item rather than a blocker. Do not re-flag "still gated" —
check the doc's own status header / `systems-index.md` before asserting this project's approval state.

**What's still actually true (unchanged by the Approved status)**:
1. **Lock defect** (analog stick, E1/spike-confirmed): held-direction input permanently denies mouse
   reclaim. Candidate fix (`InputEventKey.echo` filtering) was formally abandoned mid-cycle —
   `InputEventJoypadMotion` has no `.echo` concept, so the fix is architecturally inapplicable to the
   only spike-confirmed case.
2. **Snap-back defect** (keyboard path, E2/verbal-observation only): reclaim briefly succeeds then is
   immediately reversed by a *different* rule (reverse zero-threshold exemption), same root cause
   (held/repeat input treated as fresh discrete intent), confirmed architecturally distinct code path
   from defect 1 — same fix does not touch it. See [[feedback_root_cause_sibling_sweep]].
3. **D-pad (both modes) and analog stick under the candidate fix remain 100% untested** — registered
   as a standing, non-blocking backlog item ("手把硬體取得": user has no gamepad hardware). The doc is
   explicit: "不得假設「未測 = 沒問題」." Sub-mechanism redesign is formally paused, not resolved.
4. Core Rule #7 (應用範圍一般化) makes this system's device-authority cursor the single mechanism for
   **every** hover/cursor-target surface project-wide, explicitly naming the affinity relationship
   mini-map as a consumer — this is real, current, and correctly cited by
   `design/gdd/affinity-position-chain.md`.

**New consumer risk (found 2026-08-31, affinity-position-chain.md review)**: this system is no longer
just generic infrastructure with no urgent consumer. `affinity-position-chain.md` (#5) is the first
system whose entire UI payload — a frequently-refreshing, itemized numeric readout the player is told
to trust completely — depends on d-pad/analog cursor movement working smoothly, not merely correctly
at authority-handoff boundaries. Neither doc's Open Questions currently reflects this elevated stakes;
flagged as BLOCKING-NOW in that review. See [[project_affinity_position_chain_review]].

**Accessibility linkage (still open)**: `design/ux/accessibility-requirements.md`'s Motor Accessibility
table predates the snap-back discovery and only names the lock symptom — still needs the snap-back
symptom added, since switch-scanning/tremor-driven input is a plausible real-world trigger for it too.
