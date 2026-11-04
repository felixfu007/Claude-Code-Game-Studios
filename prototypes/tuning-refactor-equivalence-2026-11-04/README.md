# tuning-refactor-equivalence-2026-11-04 —— 數值搬資料檔「零行為變更」對照

**假說**:tuning-data story-001~005(`27fadd0`~`be3f438`)只搬位置、不改任何遊戲行為。
**狀態**:已結案(concluded)。協調者執行,未改任何工具。

## 對照一:停損考試量測工具(protocol2-computer-measure-v3,vs01,`--level=1 --r2=yes`)
- 搬家前:乾淨 worktree `C:/tmp/p2run_v` checkout `d6cb022`(今日開工 HEAD)+ `--import` → `run93_p2_before.txt`
- 搬家後:主工作目錄 `aecaba7` → `run93_p2_after.txt`
- 兩次 ENGINE EXIT = 0、RESULT 16、DONE 1、FATAL 0;去掉 HEADER/引擎標頭後 21 行 `diff` 為空。

## 對照二:難度量測電腦代打(difficulty-ai-formation-2026-11-03,vs03,兩開關皆關)
- 昨日原始輸出 `../difficulty-ai-formation-2026-11-03/run_vs03_off.txt`(build `dd2da1a`)vs 今日 `run93_vs03_off_after.txt`
- ENGINE EXIT = 0;RESULT 8 行逐字相同;去掉 HEADER/引擎標頭後全部逐步紀錄(TPOS/TPACT…)`diff` 為空。
- ⚠️ 此對照跨越 `dd2da1a`→`aecaba7` 之間所有提交,不只搬家;結論是「這段期間整體對第 3 場電腦對局零影響」。

**執行**:`<godot> --headless --path . -s res://prototypes/protocol2-computer-measure-v3/protocol2_runner.gd -- --level=1 --r2=yes`
