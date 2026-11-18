# tests/perf

效能檢查,**刻意不在全套自動收集範圍內**(story-062,管理者 2026-11-17 裁決方案 A)。

## 為什麼不在全套

真實關卡整場戰鬥的牆鐘耗時隨機器時段 2~3 倍浮動(歷來實測 15.9~50.4 秒,同一場 6 回合、結果相同)。
放在全套會讓全套無故變紅。全套內只驗「打得完」(`tests/integration/ui/battle/battle_screen_real_level_battle_test.gd`),
耗時移到這裡。調查報告:`docs/reviews/timing-test-full-suite-red-2026-11-17.md`。

🔴 `tests/perf/` **刻意沒有**加進 `tests/gdunit4_runner.gd` 的 `FORCED_ARGS`。這是對
「新增測試層級必須加進 FORCED_ARGS」那條規則的刻意反用,**不是漏加,請勿補上**。

## 怎麼跑(手動、機器閒置時)

```bash
"<Godot 4.7.1 console 執行檔>" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/perf
```

- 不走 `run_tests_with_import.sh`(它綁定全套)。剛改過資料檔先自行 `--import` 一次。
- 🔴 看輸出的 `Executed test cases : (1/1)`,不要只看 exit code(路徑或篩選打錯時 GdUnit4 會 `No test cases found` 卻 exit 0)。
- 輸出會有一行 `PERF real_level_battle times_msec=[...] median_msec=... round_counts=[...]`。

## 檢查內容

連跑 3 場整場戰鬥(每場各自 `load()` 真實 `BattleScreen.tscn`),**中位數 < 30000 ms**,且 3 場 `round_count` 必須相等。
共用驅動在 `tests/helpers/real_battle_driver.gd`,與全套測試呼叫同一份。

## 何時該跑

⚠️ **沒有任何排程、CI 或機制保證有人會跑**(管理者在知情下選的方案 A 的明文缺點)。請在下列改動後手動跑一次:
改動戰鬥迴圈、卡牌/代價結算、敵方回合播放、`BattleScreen` 啟動流程之後;或全套整體變慢時。

## 基準值(2026-11-18,worktree 內量,機器【非】全閒置:量測前 `tasklist` 有 2 個 godot 行程)

```
PERF real_level_battle times_msec=[21282, 18348, 21190] median_msec=21190 round_counts=[6, 6, 6] threshold_msec=30000
```

協調者應在機器閒置時重量並更新此節。

## 門檻有效性(一次性手動驗證,**不是常駐敏感度證明**)

30000 ms 門檻本身無法在全套內做常駐敏感度證明(需要刻意放慢戰鬥:真實等待會拖慢全套、假時鐘會改動被測物)。
替代佐證:2026-11-18 暫把門檻改成 1 ms 跑一次,結果 `1 failures`、`Exit code: 100`
(`times_msec=[17595, 17946, 18500] median_msec=17946 threshold_msec=1`),隨即還原為 30000。
