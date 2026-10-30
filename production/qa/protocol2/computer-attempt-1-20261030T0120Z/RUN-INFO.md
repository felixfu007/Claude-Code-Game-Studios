# 協議 2 電腦對照 attempt-1(探針關 vs01)

- H(鎖定):`20e0854`
- V(工具):`6b6f1c20e7d6b1356b915e49bee48595899223b5`
- 執行版本:乾淨 worktree 於 V(`git worktree add --detach`),先 `--import`(exit 0)
- 引擎:Godot 4.7.1-stable(official),headless
- 指令:`<godot> --headless --path . -s res://prototypes/protocol2-computer-measure/protocol2_runner.gd -- --level=1 > raw_stdout.txt 2>&1`
- **ENGINE EXIT = 0**;`RESULT` 行 16;`DONE` 存在
- 執行時間(UTC):2026-10-30T01:20Z
- 執行者:協調者。判定:qa-lead 依鎖定文件(判定前協調者未讀 RESULT 內容)
