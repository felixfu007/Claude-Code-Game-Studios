# cursor-host-isolation-probe-2026-10-27 (throwaway, status: INCOMPLETE)

Purpose: show what shared Autoload CursorStateHost state a test file leaves behind.
Method: run `-a <test file> -a <this dir>`; suites run in argument order (verified);
zz_host_state_probe_test.gd prints one `ISOPROBE` line (registry, authority, target,
suspended flag, frame_events, tree paused) at suite start. Reads only.
Done: baseline (probe alone) and ONE pair (battle_screen_scene_test.gd). Raw output: run_output.txt.
NOT done: all other test files (each pair run takes ~52 s here). To continue, repeat per file.
Assumption: the probe is the last suite, so it sees the state the previous file left.
Not an (A)-level proof of order dependence: it shows residue, not a flipped test result.
