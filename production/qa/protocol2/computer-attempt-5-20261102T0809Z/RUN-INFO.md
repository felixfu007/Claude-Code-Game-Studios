# 協議 2 電腦對照 attempt-5(探針關 vs01)

- H `20e0854`(門檻)/ **H5 `7a6172b`**(本輪登記)
- **S5 `2f82109`**(丙最大射程 4→6,vs01~05)
- 工具:**V3 `47465aa` 不變**(依 H5「V5 = V3 不變」;於 S5 能編譯能跑)
- 旋鈕再驗:`production/qa/protocol2/knob-verify-vs02-attempt5-20261102T0808Z/`(S5 乾淨 worktree,兩臂 8/8,ENGINE EXIT 0)
- 執行版本:乾淨 worktree `C:/tmp/p2run_v` 於 S5(`git checkout -f --detach`),先 `--import`(exit 0)
- 指令:`<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v3/protocol2_runner.gd -- --level=1 --r2=yes`
- **ENGINE EXIT = 0**;`RESULT` 16;`DONE`;無 `FATAL`;`GUARDSUM guard_events=110 guard_nonzero=80`;`SIGSUM` 兩臂 8 of 8
- 執行時間(UTC):2026-11-02T08:09Z;執行者:協調者;判定:qa-lead(協調者判定前未讀 RESULT)
