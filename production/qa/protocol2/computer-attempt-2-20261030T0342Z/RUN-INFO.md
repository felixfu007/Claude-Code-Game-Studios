# 協議 2 電腦對照 attempt-2(探針關 vs01)

- H(門檻鎖定):`20e0854`;H2(attempt-2 登記):`1275bfa`
- S(規則程式):`908708a`;S'(lone_guard_if_at):`b3a7aa7`
- V2(工具):`7412fa12a75dc37c84022f75574dab903057d8ea`(旋鈕驗證 vs02 兩臂各 8/8,未替換)
- 中間另有 `23acffc`(僅畫面文字列,不影響規則;為 V2 的祖先)
- 執行版本:乾淨 worktree 於 V2(`git checkout -f --detach`),先 `--import`(exit 0)
- 引擎:Godot 4.7.1-stable(official),headless
- 指令:`<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v2/protocol2_runner.gd -- --level=1 --r2=yes`
- **ENGINE EXIT = 0**;`RESULT` 行 16;`DONE` 存在;無 `FATAL`;`GUARDSUM guard_events=113 guard_nonzero=53`;`SIGSUM` 兩臂各 8 of 8
- 執行時間(UTC):2026-10-30T03:42Z
- 執行者:協調者。判定:qa-lead(判定前協調者未讀 RESULT 內容)
