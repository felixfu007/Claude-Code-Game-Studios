# Cursor surface register guard — P3 (and P1/P2) probe

**Hypothesis under test**: the contract
(`docs/reviews/cursor-surface-register-guard-contract-2026-10-15.md`, 第四節/第六節)
proposes a mechanical proxy for ADR-0005 機制十四 condition 2 ("no built-in hover
theme state") that depends entirely on **reference equality** of `StyleBox`
resources returned by `Control.get_theme_stylebox()` after
`add_theme_stylebox_override()`. This was never engine-verified (explicitly
flagged (C)-level / unverified in the contract, §四 and §六 P1–P3). This probe
runs the real engine to turn it into (A)-level evidence before the guard is
implemented against it.

Also answers P1 (default `focus_mode` of `Control.new()` / `Button.new()`) and
a slice of P2 (does an out-of-tree node answer theme-stylebox queries the same
way an in-tree one does), both needed to know what Phase 1 test T3/T4 are
actually exercising.

## How to run

```bash
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s prototypes/godot-gdscript-specialist-cursor-guard-probe-2026-10-15/probe_stylebox_reference_equality.gd
```

Headless is sufficient — this probe only reads resource references and enum
values, no pixels (per `technical-preferences.md`'s 結構/狀態 vs 像素 distinction).

## Status

Concluded 2026-10-15 — see findings below, captured from actual run output.

## Findings

See `run_output.txt` in this directory for the raw log. Summary pulled into
the implementation report delivered via this task's handback.
