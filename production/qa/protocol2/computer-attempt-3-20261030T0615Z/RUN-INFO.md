# 協議 2 電腦對照 attempt-3(探針關 vs01)

- H `20e0854`(門檻)/ H2 `1275bfa` / **H3 `286a313`**(本輪登記)
- **S3 `e7751fc`**(戊出手旗標 + 負向進位)
- **V3 `47465aa`**(工具;相對 V2 程式改動 8 行,協調者審 diff)
- 旋鈕再驗:`production/qa/protocol2/knob-verify-vs02-v3-20261030T0615Z/`(於已提交 V3 的乾淨 worktree,兩臂 8/8,ENGINE EXIT 0)
- 執行版本:乾淨 worktree 於 V3,先 `--import`(exit 0)
- 指令:`<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v3/protocol2_runner.gd -- --level=1 --r2=yes`
- **ENGINE EXIT = 0**;`RESULT` 16;`DONE`;無 `FATAL`;`GUARDSUM guard_events=116 guard_nonzero=80`;`SIGSUM` 兩臂 8 of 8
- 執行時間(UTC):2026-10-30T06:15Z;執行者:協調者;判定:qa-lead(協調者判定前未讀 RESULT)
