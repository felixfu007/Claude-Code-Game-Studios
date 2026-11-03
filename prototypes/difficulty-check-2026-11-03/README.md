# difficulty-check-2026-11-03

Status: CONCLUDED(只量不改;未改任何既有檔,未新增腳本 —— 現行腳本原樣可用)
假設:以現行規則(V3 = 現行 V5 工具、build_commit c20ac96)+ 現行電腦打法,vs02~vs05 的「運用好感度」臂在 8 組旋鈕下誰難誰易。
護欄遵守:未跑 vs01、未讀 production/qa/protocol2/、未改 prototypes/protocol2-computer-measure* 與 src/ assets/。與協議 2 無關,不構成 attempt。

## 執行的命令(逐字,每場一次,exit 皆為引擎自己的)
```
G="C:/Users/felixfu007/Downloads/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
timeout 600 "$G" --headless --path . -s res://prototypes/protocol2-computer-measure-v3/protocol2_runner.gd -- --level=N --arms=use > run_vs0N.txt 2>&1
```
N = 2,3,4,5。程式 diff:無(直接用 v3 的 `--level=` 與 `--arms=use`)。只跑「運用好感度」(use)臂;未跑 ignore 臂(任務只要求 use 臂)。
ENGINE EXIT:level=2 -> 0;level=3 -> 0;level=4 -> 0;level=5 -> 0。每份 log 都有 `GUARDSUM ... guard_nonzero>0`、無 FATAL、`DONE`。
原始 log:本目錄 `run_vs02.txt` ~ `run_vs05.txt`。
注意:規格 8 組旋鈕 = v0..v7(K1 開局動作/K2 出手順序/K3 首回合是否禁移動的組合,見 v2 README),每組一局,共 8 局/場。

## 結果總表(use 臂)
| 場 | 勝/8 | 回合數(各組 v0..v7) | 敗局 |
|---|---|---|---|
| vs02 | 8/8 | 4,4,5,4,6,5,6,5 | 無 |
| vs03 | **6/8** | 4,3(敗),4,5,6,4(敗),5,6 | v=1(第 3 回合)、v=5(第 4 回合) |
| vs04 | 8/8 | 4,4,5,5,4,4,5,5 | 無 |
| vs05 | 8/8 | 4,5,5,5,5,5,5,5 | 無 |

近死(neardeath,勝局中曾降到 HP 1/3 以下且未倒的我方人數,越多越險):vs02 = 1,1,0,0,1,1,0,0;vs03 勝局 = 0,1,0,1,1,2(敗局欄的 5 是規格 2.2「未通關算全員」,不是真數);vs04 = 1,0,0,1,0,0,0,0;vs05 = 0,1,0,0,1,0,0,0。
勝局中最低單位剩餘 HP(看 final_hp 末態,僅供參考):vs03 v=7 出現 3、1;vs02 v=4 出現 2、v=1 出現 4;vs04 最低 6;vs05 最低 7。

## 敗局中第一個倒下的是誰
**拿不到。** 此工具只印「各我方單位的最終 HP」(final_hp,依單位 id 升序、倒下者不列),沒有記錄「誰先倒、哪一回合倒」。
可得的間接資訊:vs03 v=1 結束時剩 4 人 HP 30,15,22,30;v=5 結束時剩 4 人 HP 11,20,26,14 —— 即各缺 1 人,但缺哪一位(id)工具沒印,不猜。要查需複製工具加一行追蹤(本次依「只量不改」未做)。

## 原始 RESULT 行(貼原文)

### vs02
```
RESULT arm=use v=0 outcome=VICTORY rounds=4 neardeath=1 phi_avg=8.000 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=30,18,22,20,5 first_round=1 guard_events=7 guard_nonzero=4
RESULT arm=use v=1 outcome=VICTORY rounds=4 neardeath=1 phi_avg=5.500 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=27,21,22,4,24 first_round=1 guard_events=6 guard_nonzero=4
RESULT arm=use v=2 outcome=VICTORY rounds=5 neardeath=0 phi_avg=7.600 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=30,26,11,13,23 first_round=1 guard_events=5 guard_nonzero=5
RESULT arm=use v=3 outcome=VICTORY rounds=4 neardeath=0 phi_avg=4.500 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=30,12,16,26,30 first_round=1 guard_events=3 guard_nonzero=3
RESULT arm=use v=4 outcome=VICTORY rounds=6 neardeath=1 phi_avg=5.667 raw_outcome=VICTORY aborted=false reason= phi_samples=6 final_hp=24,18,2,19,22 first_round=1 guard_events=9 guard_nonzero=8
RESULT arm=use v=5 outcome=VICTORY rounds=5 neardeath=1 phi_avg=4.000 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=6,26,22,19,22 first_round=1 guard_events=7 guard_nonzero=7
RESULT arm=use v=6 outcome=VICTORY rounds=6 neardeath=0 phi_avg=4.333 raw_outcome=VICTORY aborted=false reason= phi_samples=6 final_hp=11,26,17,19,13 first_round=1 guard_events=8 guard_nonzero=5
RESULT arm=use v=7 outcome=VICTORY rounds=5 neardeath=0 phi_avg=7.200 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=23,21,22,13,23 first_round=1 guard_events=6 guard_nonzero=6
SIGSUM arm=use distinct=8 of 8
GUARDSUM guard_events=51 guard_nonzero=42
```

### vs03
```
RESULT arm=use v=0 outcome=VICTORY rounds=4 neardeath=0 phi_avg=8.500 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=30,26,22,13,11 first_round=1 guard_events=6 guard_nonzero=4
RESULT arm=use v=1 outcome=DEFEAT rounds=3 neardeath=5 phi_avg=4.000 raw_outcome=DEFEAT aborted=false reason= phi_samples=3 final_hp=30,15,22,30 first_round=1 guard_events=6 guard_nonzero=4
RESULT arm=use v=2 outcome=VICTORY rounds=4 neardeath=1 phi_avg=5.000 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=8,26,14,26,30 first_round=1 guard_events=5 guard_nonzero=5
RESULT arm=use v=3 outcome=VICTORY rounds=5 neardeath=0 phi_avg=8.800 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=17,26,11,12,26 first_round=1 guard_events=9 guard_nonzero=9
RESULT arm=use v=4 outcome=VICTORY rounds=6 neardeath=1 phi_avg=7.667 raw_outcome=VICTORY aborted=false reason= phi_samples=6 final_hp=24,20,22,13,8 first_round=1 guard_events=9 guard_nonzero=6
RESULT arm=use v=5 outcome=DEFEAT rounds=4 neardeath=5 phi_avg=3.500 raw_outcome=DEFEAT aborted=false reason= phi_samples=4 final_hp=11,20,26,14 first_round=1 guard_events=11 guard_nonzero=7
RESULT arm=use v=6 outcome=VICTORY rounds=5 neardeath=1 phi_avg=6.000 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=2,10,16,26,23 first_round=1 guard_events=9 guard_nonzero=7
RESULT arm=use v=7 outcome=VICTORY rounds=6 neardeath=2 phi_avg=3.000 raw_outcome=VICTORY aborted=false reason= phi_samples=6 final_hp=3,1,22,26,23 first_round=1 guard_events=9 guard_nonzero=3
SIGSUM arm=use distinct=8 of 8
GUARDSUM guard_events=64 guard_nonzero=45
```

### vs04
```
RESULT arm=use v=0 outcome=VICTORY rounds=4 neardeath=1 phi_avg=6.500 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=30,26,16,6,19 first_round=1 guard_events=6 guard_nonzero=4
RESULT arm=use v=1 outcome=VICTORY rounds=4 neardeath=0 phi_avg=8.500 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=30,20,22,20,23 first_round=1 guard_events=4 guard_nonzero=4
RESULT arm=use v=2 outcome=VICTORY rounds=5 neardeath=0 phi_avg=7.200 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=30,26,10,11,18 first_round=1 guard_events=6 guard_nonzero=5
RESULT arm=use v=3 outcome=VICTORY rounds=5 neardeath=1 phi_avg=5.200 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=24,26,16,6,12 first_round=1 guard_events=8 guard_nonzero=6
RESULT arm=use v=4 outcome=VICTORY rounds=4 neardeath=0 phi_avg=6.500 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=23,20,16,20,27 first_round=1 guard_events=5 guard_nonzero=5
RESULT arm=use v=5 outcome=VICTORY rounds=4 neardeath=0 phi_avg=6.500 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=23,26,22,26,16 first_round=1 guard_events=4 guard_nonzero=2
RESULT arm=use v=6 outcome=VICTORY rounds=5 neardeath=0 phi_avg=5.600 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=17,15,22,17,30 first_round=1 guard_events=5 guard_nonzero=5
RESULT arm=use v=7 outcome=VICTORY rounds=5 neardeath=0 phi_avg=4.400 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=19,26,22,13,19 first_round=1 guard_events=6 guard_nonzero=4
SIGSUM arm=use distinct=8 of 8
GUARDSUM guard_events=44 guard_nonzero=35
```

### vs05
```
RESULT arm=use v=0 outcome=VICTORY rounds=4 neardeath=0 phi_avg=9.000 raw_outcome=VICTORY aborted=false reason= phi_samples=4 final_hp=27,15,16,26,20 first_round=1 guard_events=6 guard_nonzero=5
RESULT arm=use v=1 outcome=VICTORY rounds=5 neardeath=1 phi_avg=8.800 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=30,21,22,26,8 first_round=1 guard_events=5 guard_nonzero=2
RESULT arm=use v=2 outcome=VICTORY rounds=5 neardeath=0 phi_avg=10.000 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=30,15,22,13,22 first_round=1 guard_events=6 guard_nonzero=6
RESULT arm=use v=3 outcome=VICTORY rounds=5 neardeath=0 phi_avg=6.000 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=30,20,16,13,23 first_round=1 guard_events=5 guard_nonzero=5
RESULT arm=use v=4 outcome=VICTORY rounds=5 neardeath=1 phi_avg=7.200 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=14,20,16,26,7 first_round=1 guard_events=9 guard_nonzero=5
RESULT arm=use v=5 outcome=VICTORY rounds=5 neardeath=0 phi_avg=8.800 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=30,21,16,26,22 first_round=1 guard_events=4 guard_nonzero=4
RESULT arm=use v=6 outcome=VICTORY rounds=5 neardeath=0 phi_avg=7.600 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=21,12,22,13,23 first_round=1 guard_events=7 guard_nonzero=7
RESULT arm=use v=7 outcome=VICTORY rounds=5 neardeath=0 phi_avg=6.400 raw_outcome=VICTORY aborted=false reason= phi_samples=5 final_hp=15,26,16,26,23 first_round=1 guard_events=5 guard_nonzero=3
SIGSUM arm=use distinct=8 of 8
GUARDSUM guard_events=47 guard_nonzero=37
```

## 歷史對照(只讀 `docs/reviews/difficulty-analysis-2026-10-28.md`、`docs/reviews/vs04-s1-layout-review-2026-10-29.md`)
- 10/28 紙上分析:數值表只算過「我方多快打倒敵人」,敵方 2~3 人同回合齊攻就能殺掉乙/丁/丙;敗北規則是「任一人倒即敗」。該分析稱 vs02~vs05 的 10 個單位數值逐欄與 vs01 相同、只有座標不同,所以場與場之間的差別主要來自座標/地形。
- 10/29 vs04 S1 站位審查:vs04 敵方改為後排退到 x=11~12、E1 守門,第 1 回合集火被拆掉(診斷只剩 E1 打甲 6 傷);審查自承「診斷已自承偏易(8/8)」,且全文為讀檔推理、無引擎量測。
- 本次量測與它一致:vs04 在 S1 站位下 8/8 勝、近死很少,與「偏易」判斷同向。

## 白話結論
- **第 4 場(vs04)以電腦打法看,不偏難,反而是四場裡偏易的一場**:8 組全勝、回合 4~5、近死只有 1 組(最低剩 HP 6),與 vs05 一樣穩,比 vs02(有兩局剩 HP 2~4)還穩。
- **四場裡唯一出現敗局的是第 3 場(vs03)**:8 組輸 2 組、勝局裡還有 HP 剩 1~3 的險局,是最難的一場。第 2 場(vs02)居中(全勝但險勝較多)。
- 若管理者想問「第 4 場是否該調難」:這份證據支持「現在偏易、不是過難」;若要拉難度,從數字看 vs04 比 vs03 容易的差距最明顯。
- **證據強度:弱到中等。** ①這是電腦規則化打法(固定的「運用好感度」決策),不是真人;真人可能更差(不會算站位)也可能更好(會預判)。②每場只有 8 局,且 8 組旋鈕只改開局細節、彼此不獨立,「8/8」不等於勝率 100%,「6/8」不等於 75%。③只跑了 use 臂,沒對照不用好感度的臂。④敗局誰先倒拿不到,無法說明 vs03 為何難(是哪個單位被集火)。⑤此工具是為「停損考試」寫的決策,不是為難度調校設計的。結論可當「相對排序的線索」,不可當定案數字。
