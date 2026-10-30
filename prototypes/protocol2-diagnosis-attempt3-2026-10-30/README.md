# Protocol 2 attempt-3 事後診斷(2026-10-30)

不改判定、不改任何既有檔。只複製 v3 腳本並加一行追蹤列印。

## 問題
attempt-3 工具無逐單位紀錄 -> 戊(名冊第 12 欄 lone_guard=1)獨行減傷實際生效幾次不可得。

## 方法
- `p2_decision.gd`、`protocol2_runner.gd` = v3 複製,唯一差異為 preload 路徑(一行)。
- `protocol2_runner_traced.gd` = 上者 + 在「敵方即將攻擊我方」處多印 `HIT` 行(3 行新增,純列印,不入決策)。
- 指令:`<godot> --headless --path . -s res://prototypes/protocol2-diagnosis-attempt3-2026-10-30/<腳本> -- --level=1 --r2=yes > <輸出> 2>&1`
- 輸出:`copy_untraced_stdout.txt`(未追蹤複製版)、`traced_stdout.txt`(追蹤版)。
- 範圍:HIT = 每次敵方決定攻擊我方單位(與工具 guard_events 同口徑)。

## 發現
1. 複製不改行為:未追蹤版 ENGINE_EXIT=0,16 行 RESULT 與 `production/qa/protocol2/computer-attempt-3-20261030T0615Z/raw_stdout.txt` 逐字相同(`diff` 無輸出,印 IDENTICAL_RESULTS)。追蹤版亦逐字相同(IDENTICAL),ENGINE_EXIT=0。
2. HIT 共 116 行 = `GUARDSUM guard_events=116`(追蹤版 stdout)。
3. 戊(lone_flag=true)受擊:

| 臂 | 受擊 | lone>0 | lone<0 | lone=0 | 其中因出手歸零 | 其中因距離 2 |
|---|---|---|---|---|---|---|
| ignore | 15 | **0** | 5 | 10 | 6 | 4 |
| use | 13 | **0** | 5 | 8 | 3 | 5 |

   - 兩臂 lone>0 皆 0 次:正向 +2 從未實際減傷。「因出手歸零」= 原本會是 +2 卻因出手被取消(raw_lone>0 且 attacked=true),ignore 6 次、use 3 次;未出手而 +2 的情況 0 次(raw_lone>0 的 6/3 次全都已出手)。
   - lone<0(-1,鄰接友軍,反而多受 1 傷)兩臂各 5 次,共 10 行,見 `grep 'lone_flag=true' traced_stdout.txt | grep -v 'lone_guard=0'`。
   - 分類 zero_other=0:全部 0 皆可歸因於上述兩因。
4. 甲乙丙丁(lone_flag=false)`guard_phi`:

| 臂 | 受擊 | guard_phi 非零次數 | guard_phi 總點數 |
|---|---|---|---|
| ignore | 51 | 35 | -9 |
| use | 37 | 35 | +21 |

   - ignore 臂淨值為負(多受傷),use 臂為正(淨減傷 21 點),但 use 臂受擊次數也少 14 次(37 vs 51)。

原始行例:`HIT arm=use v=3 round=3 target=5 name=戊 lone_flag=true ... lone_guard=-1 raw_lone=-1 guard=-1 damage=7 attacked=true`;`GUARDSUM guard_events=116 guard_nonzero=80`。

## 未驗證
- HIT 於敵方決策時記錄,假設該攻擊隨後執行(與工具 guard_events 同假設;116=116 一致但未逐筆核對 HP 變化)。
- 僅 vs01、8 變體、單次執行(確定性,未重複跑)。
- 「因出手歸零」以 raw_lone(同位置 will_attack=false 重算)推導,非引擎直接輸出。
- 未評估這些數字對判定門檻的因果影響(本任務不改判定)。

## 白話摘要(給管理者)
- 複製的工具跑出的結果與正式那次逐字相同,所以這份診斷可信。
- 「戊」落單時的額外減傷(+2)在 16 場裡一次都沒真正發揮作用。
- 原因:戊一落單,多半已經出手攻擊(出手就取消加成),或剛好離隊友 2 格(沒加成)。
- 相反地,戊緊貼隊友時會多挨 1 點傷,兩臂各發生 5 次。
- 甲乙丙丁的好感度減傷有效:有用好感度那臂淨減傷 21 點,不用那臂反而多挨 9 點。
- 所以通過判定主要來自甲乙丙丁的減傷,不是戊的獨行機制。
