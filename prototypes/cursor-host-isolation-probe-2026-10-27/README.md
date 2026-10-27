# cursor-host-isolation-probe-2026-10-27 (throwaway, status: INCOMPLETE)

Purpose: show what shared Autoload CursorStateHost state a test file leaves behind.
Method: run `-a <test file> -a <this dir>`; suites run in argument order (verified);
zz_host_state_probe_test.gd prints one `ISOPROBE` line (registry, authority, target,
suspended flag, frame_events, tree paused) at suite start. Reads only.
Done: baseline (probe alone) and ONE pair (battle_screen_scene_test.gd). Raw output: run_output.txt.
NOT done: all other test files (each pair run takes ~52 s here). To continue, repeat per file.
Assumption: the probe is the last suite, so it sees the state the previous file left.
Not an (A)-level proof of order dependence: it shows residue, not a flipped test result.

## 2026-10-27 後續
修正已落地(管理者裁決「修測試端」):`tests/helpers/cursor_host_snapshot.gd` 套到 41 支測試,
收尾檢查 `tests/integration/zz_cursor_host_final_state_test.gd` 已進正式測試線。
修之前收尾檢查實跑為紅,訊息原文:
`CursorStateHost left dirty by earlier suites: registry._guard_verdicts={ 0: 0, 1: 0, 2: 0, 3: 0 }, target=BOARD_TILE/26/valid=true, authority=KEYBOARD_GAMEPAD`
(暫放本目錄的驗證器副本已刪除,以 tests/ 那份為準。)
