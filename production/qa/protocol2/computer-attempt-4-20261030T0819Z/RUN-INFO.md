# 協議 2 電腦對照 attempt-4(探針關 vs01)

- H `20e0854`(門檻)/ **H4 `2355c6a`**(本輪登記)
- **S4 `ace389b`**(戊騎牆 + 留一手)
- 工具:**V3 `47465aa` 不變**(依 H4「V4 = V3 不變、只重跑」;於 S4 能編譯能跑)
- 旋鈕再驗:`production/qa/protocol2/knob-verify-vs02-attempt4-20261030T0818Z/`(S4 乾淨 worktree,兩臂 8/8,ENGINE EXIT 0)
- 執行版本:乾淨 worktree 於 S4(`git checkout -f --detach`),先 `--import`(exit 0)
- 指令:`<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v3/protocol2_runner.gd -- --level=1 --r2=yes`
- **ENGINE EXIT = 0**;`RESULT` 16;`DONE`;無 `FATAL`;`GUARDSUM guard_events=120 guard_nonzero=92`;`SIGSUM` 兩臂 8 of 8
- 執行時間(UTC):2026-10-30T08:19Z;執行者:協調者;判定:qa-lead(協調者判定前未讀 RESULT)
