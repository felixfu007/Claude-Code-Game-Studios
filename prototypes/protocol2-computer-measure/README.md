# protocol2-computer-measure

Status: TOOL READY (written 2026-10-30; vs01 NOT run -- coordinator runs it after unlock conditions in spec 4.1)

## Hypothesis / purpose
Spec: `docs/reviews/protocol2-threshold-locked-2026-10-30.md` (locked at H = commit 20e0854). Two arms
(ignore / use affinity) x 8 variants (v0~v7 = K1*4+K2*2+K3), 12-round cap. This tool only emits raw
per-game RESULT lines; the verdict is qa-lead's, per spec 2.3. Prototype: not for src/.

## Files
- `p2_decision.gd`   decision function (copy of autoplay_v2 `_decide_cautious/_threat/_can_hit/_focus_pick`), the structural-audit target.
- `protocol2_runner.gd`  runner + measurement (near-death scan, phi_avg, RESULT lines).
- `boundary_probe.gd` + `boundary_probe_output.txt`  12-round boundary probe (fixture).
- `run_output_vs02_toolcheck.txt`  tool-check run on vs02 (engine exit 0). Not evidence for protocol 2.

## How to run (headless)
```
"C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" --headless --path . -s res://prototypes/protocol2-computer-measure/protocol2_runner.gd -- --level=1 > out.txt 2>&1
echo ENGINE_EXIT=$?
```
Args after `--`: `--level=<row of campaign_sequence.txt>` (default **2**, never 1), `--arms=ignore,use`,
`--variants=0,...,7`, `--max-rounds=12`, `--terrain= --roster= --affinity=` (explicit res:// paths, override level).
Output: `HEADER` (build commit, engine, paths), 16 `RESULT arm=<ignore|use> v=<n> outcome=<VICTORY|DEFEAT|TIMEOUT> rounds=<n> neardeath=<n> phi_avg=<x> ...` lines, `DONE`.
Script ends with `quit()`. Check `DONE` present AND engine exit code (do not just grep).

## Implementation notes / interpretations (disclosed)
- Step order per spec 3.1: (1) K1 pool [fallback lowest threat] -> K3 sort -> (2) use-arm only: keep max `bonus_for_at` tiles, positions snapshot taken before the unit moves -> (3) focus-fire narrowing + existing tile comparison (`GreedyTacticalAI._is_better_tile`) -> (4) first in K3 order wins ties.
  **Interpretation**: the focus-target union and narrowing (step 3) are computed on the pool *after* step 2, i.e. affinity is a hard first priority and can cost an attack opportunity. The spec's "第一優先" wording was read literally. The old `aff != caff` tie-branch was dropped because after step 2 all pool tiles have equal affinity (equivalent).
- Focus fire (`focus_on`) is a separate flag, true in both arms. Engine Phi damage (`phi_cb` -> `AffinityPhiProvider.phi`) is on in both arms; it lives in the runner, not the decision file.
- Outcome: VICTORY only if raw VICTORY, not aborted, rounds<=max; raw DEFEAT -> DEFEAT; everything else (aborted ONGOING) -> TIMEOUT.
- Near-death (spec 2.2): player HP scanned at the start of every `decide` call (= state after the previous action's attack resolved) plus once after `run()`, so every attack result is seen. Per unit: lowest HP seen; counted if `3*minhp <= hp_max` and `minhp > 0`. DEFEAT/TIMEOUT games record neardeath = number of player units.
- phi_avg: sampled once per round at the first ENEMY action (all player units done), plus a final sample for non-aborted games that end in the player phase; sum over living player units of `AffinityRules.bonus_for_at(id, pos, positions, links)`; mean over samples. Operational check only.
- **bonus_for_at vs the Phi-ceiling verification**: `design/quick-specs/unit-stats-provisional.md` "覆算結果" says its spike called `AffinityRules.bonus_for()` / `bonus_for_at()` / `manhattan_distance()` (the +10 team ceiling was computed with `bonus_for` on a single positions snapshot). So `bonus_for_at` is **one of the functions that verification used**, and per `affinity_rules.gd` doc comment `bonus_for_at` is implemented through the same breakdown path as `bonus_for`. I did not re-run that spike. Engine Phi damage uses `AffinityPhiProvider.phi` -> `AffinityRules.bonus_for`.
- Affinity seeding copied from autoplay_v2 (links file, AMP_EXPECTED, Source.STORY_EVENT).
- Fixture finding: `test_fixture_terrain.txt` is 5x3, but `BattleState.create` requires a 13x6 board (`Board.from_ascii: row 1 has length 5, expected 13`), so the fixture cannot be loaded as-is. Roster fixture is compatible with the terrain fixture (ENEMY at (4,2) is inside 5x3). The runner pads short rows/rows with `.` (never triggers on real 13x6 levels).

## 12-round boundary (measured, fixture terrain padded; roster fixture with PLAYER atk 1->20 and ENEMY hp edited in memory so a kill is possible; both sides GreedyTacticalAI) -- `boundary_probe_output.txt`
Victory in round R: `run(R+1)` and `run(R)` both return `VICTORY rounds=R aborted=false`; `run(R-1)` returns `ONGOING rounds=R-1 aborted=true reason=max_rounds_reached` (checked for R=3,5,7).
=> victory achieved inside round 12 counts (run(12) with victory at round 12 returns normally); a victory that would occur in round 13 is never reached (cap check happens when the round counter hits 13, before any action). Note: an aborted run reports `rounds=max_rounds` (not 13).

## Structural audit (spec 3.2 point 4)
`grep -n "AffinityRules\|prov\.\(links\|positions\|phi\)" prototypes/protocol2-computer-measure/p2_decision.gd` raw output:
```
112:		var pos: Dictionary[int, Vector2i] = prov.positions()  # snapshot BEFORE this unit moves
113:		var lk: Array[AffinityLink] = prov.links()
117:			var b: int = AffinityRules.bonus_for_at(id, t, pos, lk)
```
Line-by-line: all three lines are inside the `if use_affinity:` block that opens at line 111 (the "Step 2" block) and closes before the "Step 3" comment; no other line in the file touches them. The ignore arm additionally receives `prov = null` (constructor sets `prov = p_prov if p_use_affinity else null`), so even a stray call would crash rather than silently read. `prov.phi` has zero hits in this file: the engine Phi damage callback (both arms on, the spec'd exception) is built in `protocol2_runner.gd`, and the runner's own `bonus_for_at` / `prov.links()` uses are measurement-only (phi_avg).

## Findings
vs02 tool check ran (engine exit 0, 16 RESULT lines + DONE). No interpretation offered here; see raw output file.
